# Dars videolari: Cloudflare Worker + R2

Darslar ("Darslar" tab) videolari Cloudflare R2'da saqlanadi va ochiq URL orqali ko'rsatiladi.
Yuklash API'si Cloudflare Worker'da (`workers/video`). **Firebase Blaze va Cloud Functions kerak emas.**
Firebase Authentication, Firestore, Storage (profil rasmlari) va FatSecret o'zgarmaydi.

## Arxitektura

```
Flutter ──(Firebase ID token)──▶ Worker POST /createVideoUpload
                                   ├─ ID token: Google JWKS (RS256), iss, aud, exp, iat, auth_time, sub
                                   ├─ Firestore REST: admins/{uid} bormi → video_uploads/{id} (pending)
                                   └─ presigned PUT (15 daq.; kalit + content-type + content-length imzolangan)
Flutter ──(PUT, stream)──────────▶ R2 (to'g'ridan-to'g'ri; Worker orqali emas, token yuborilmaydi)
Flutter ──(Firebase ID token)──▶ Worker POST /finalizeVideoUpload
                                   ├─ R2 binding head(): hajm va Content-Type
                                   ├─ R2 binding get(range): MP4 box'lari → H.264 (avc1/avc3)
                                   └─ Firestore tranzaksiyasi: courses/{cat}/lessons/{id} + sessiya "completed"
Flutter ──▶ Firestore (darslarni o'qish), Firebase Auth — avvalgidek
```

- UID faqat tekshirilgan tokendagi `sub` dan olinadi; so'rovdagi `uid` e'tiborsiz.
- Admin har so'rovda `admins/{uid}` orqali tekshiriladi (olib tashlash darhol ta'sir qiladi).
- Rad etilgan yuklashda (HEVC, QuickTime, hajm mos emas) faqat shu sessiya obyekti o'chiriladi.
- Hech qanday mavjud video avtomatik ko'chirilmaydi yoki o'chirilmaydi.

## Firestore

| Yo'l | Ilova o'qiydi | Kim yozadi |
|---|---|---|
| `admins/{uid}` | faqat o'zinikini | faqat Firebase Console |
| `courses/{categoryId}/lessons/{lessonId}` | tizimga kirgan har kim | faqat Worker |
| `video_uploads/{uploadId}` | yo'q | faqat Worker |

Dars hujjati (avvalgi tuzilma bilan bir xil):

```
order, title, description, durationMinutes, durationSeconds, videoUrl, thumbnailUrl,
storageProvider: "r2", objectKey, sizeBytes, contentType: "video/mp4", videoCodec,
uploadedBy, uploadId, createdAt
```

**`firestore.rules` Firebase'ga deploy qilinishi shart** (`admins` va `courses/*/lessons` bloklari).
Deploy qilinmasa, ilova `admins/{uid}` ni o'qiy olmaydi (permission-denied) va yuklash tugmasi chiqmaydi.
Spark rejasida ishlaydi: `firebase deploy --only firestore:rules` yoki Console → Firestore → Rules → Publish.
Worker service account bilan ishlaydi va qoidalarni chetlab o'tadi; barcha tekshiruvlar Worker kodida.

## Bir martalik sozlash

### 1. R2 API token (presigned URL imzolash uchun)
Cloudflare → R2 → **Manage R2 API Tokens** → **Create API token**:
- Permission: **Object Read & Write**, Specify bucket: **myfit-videos**, TTL: ixtiyoriy.

### 2. Google service account (Firestore uchun, billing shart emas)
1. https://console.cloud.google.com/iam-admin/serviceaccounts?project=myfit-d6275
2. **Create service account** → nomi: `myfit-video-worker`.
3. Rol: **Cloud Datastore User** (`roles/datastore.user`). Boshqa rol bermang.
4. Account → **Keys** → **Add key** → **JSON**. Fayl yuklanadi.

Kalitni hech qayerga yubormang va repository'ga qo'shmang. Yaratish taqiqlangan desa
(`iam.disableServiceAccountKeyCreation`), Organization Policy'da shu loyiha uchun ruxsat bering.

### 3. Worker deploy (o'z kompyuteringizda)

```bash
cd workers/video
npm ci
npm run check                      # tsc + testlar + dry-run build
npx wrangler login
npx wrangler secret put R2_ACCESS_KEY_ID
npx wrangler secret put R2_SECRET_ACCESS_KEY
npx wrangler secret put FIREBASE_SERVICE_ACCOUNT < /path/to/service-account.json
npx wrangler deploy
```

Deploy qilingan manzil: `https://myfit-video.myfit-app.workers.dev`.

`wrangler.jsonc` dagi ochiq sozlamalar (maxfiy emas):

| O'zgaruvchi | Qiymat |
|---|---|
| `FIREBASE_PROJECT_ID` | `myfit-d6275` |
| `R2_ENDPOINT` | `https://7d6c72f2d7ccf971e52c251086f2bfa1.r2.cloudflarestorage.com` |
| `R2_BUCKET` | `myfit-videos` (+ `VIDEOS` binding) |
| `R2_PUBLIC_BASE_URL` | `https://pub-32dc4a48be774882aaf3dd1d07697a5b.r2.dev` |
| `ALLOWED_ORIGINS` | web versiya uchun ruxsat etilgan originlar |

O'z domeningizga o'tganda `R2_PUBLIC_BASE_URL` ni o'zgartirib `npx wrangler deploy` qiling.
Yangi URL faqat yangi darslarga yoziladi.

### 4. Ilovadagi Worker manzili
Manzil bitta joyda: `lib/config/app_config.dart` → `kVideoApiBaseUrl`
(`https://myfit-video.myfit-app.workers.dev`). Android va iOS bir xil manzildan foydalanadi;
`--dart-define` yoki Codemagic o'zgaruvchisi kerak emas. Domen o'zgarsa, faqat shu qatorni yangilang.

### 5. Admin qo'shish
Firebase Console → Authentication → foydalanuvchi **UID** → Firestore → `admins` kolleksiyasi →
Document ID = UID, maydon masalan `role: "admin"`.

## CORS
- Android/iOS uchun kerak emas.
- Web versiya: Worker `ALLOWED_ORIGINS` ni ishlatadi. R2 bucket → Settings → CORS Policy:

```json
[
  {
    "AllowedOrigins": ["https://myfit-d6275.web.app", "https://myfit-d6275.firebaseapp.com"],
    "AllowedMethods": ["PUT", "GET", "HEAD"],
    "AllowedHeaders": ["content-type"],
    "ExposeHeaders": ["ETag"],
    "MaxAgeSeconds": 3600
  }
]
```

## Videoni tayyorlash
Faqat **H.264 MP4**, 2 GB gacha:

```bash
ffmpeg -i input.mov -c:v libx264 -preset slow -crf 23 -c:a aac -b:a 128k -movflags +faststart output.mp4
```

## Limitlar (Workers Free, 2026-11)
- 100 000 so'rov/kun, 10 ms CPU, 128 MB xotira, 50 subrequest/so'rov.
- Worker'ga kiruvchi so'rov tanasi 100 MB — shuning uchun video Worker orqali emas, presigned URL bilan to'g'ridan-to'g'ri R2'ga yuklanadi.
- R2: bitta PUT 5 GiB gacha; presigned URL 1 soniya – 7 kun.
- finalize ≈ 10–15 subrequest (Firestore 5–6, R2 2–4, birinchi so'rovda JWKS/OAuth).

## Xato sabablari (`error.reason`)

| reason | HTTP | Ma'nosi |
|---|---|---|
| `sign-in-required`, `invalid-token`, `token-expired` | 401 | token yo'q/yaroqsiz (ilova bir marta yangilab qayta urinadi) |
| `not-admin`, `not-owner` | 403 | admin emas / boshqa adminning yuklashi |
| `unsupported-format`, `not-h264`, `too-large`, `empty-file`, `size-mismatch` | 400 | fayl talabga mos emas |
| `object-missing`, `upload-expired`, `upload-rejected` | 409 | yuklash tugamagan / eskirgan / rad etilgan |
| `upload-not-found` | 404/400 | sessiya topilmadi |
| `auth-unavailable`, `database-unavailable`, `storage-unavailable` | 503 | Google/R2 vaqtincha ishlamayapti |

## Testlar
- `cd workers/video && npm test` — token xavfsizligi, Firestore REST, MP4, presign, yuklash, HTTP.
- `flutter test` — ilova tomoni (Worker klienti, progress, bekor qilish, xatolar, pleyer).

## Profil rasmlari (R2, Firebase Storage'siz)

Endpointlar (shu Worker, admin shart emas):

| Endpoint | So'rov | Javob |
|---|---|---|
| `POST /profile/upload?uid=<o'z UID>` | `Authorization: Bearer <ID token>`, `Content-Type: image/jpeg\|png\|webp`, tana: rasm baytlari (≤ 5 MB) | `{ url, objectKey, contentType, sizeBytes }` |
| `POST /profile/delete` | JSON `{ "uid": "<o'z UID>" }` (ixtiyoriy) | `{ deleted }` |

- UID faqat tekshirilgan tokendan olinadi; `uid` boshqa bo'lsa 403 `not-owner`.
- Kalit server tomonida yaratiladi: `profile-images/{uid}/{vaqt}-{tasodifiy}.{ext}`.
  Yangi rasm yuklangach, shu foydalanuvchining eski rasmlari o'chiriladi (boshqa papkalarga tegilmaydi).
- Tur `Content-Type` va fayl boshidagi magic baytlar bo'yicha tekshiriladi (JPEG/PNG/WebP).
- URL Firestore'dagi avvalgi maydonga yoziladi: `users/{uid}.photoUrl` (ilova yozadi, o'z hujjatiga).
- Rasm ochiq `R2_PUBLIC_BASE_URL` orqali ko'rsatiladi (URL'ni bilgan kishi ko'ra oladi, avvalgidek).

Xatolar: 401 token yo'q/yaroqsiz · 403 `not-owner` · 413 `too-large` · 415 `unsupported-format` ·
400 `empty-file` · 503 `storage-unavailable`.

Yangi endpointlar ishlashi uchun Worker'ni qayta deploy qiling: Actions → **Deploy video Worker** → Run workflow.

## SMS orqali kirish (DevSMS, Firebase Phone Auth'siz)

SMS kodni Worker yaratadi va [DevSMS](https://devsms.uz/docs/api) "Universal OTP" orqali yuboradi
(oldindan tasdiqlangan shablon: *"MyService tizimi: MyFit xizmatiga kirish uchun tasdiqlash kodi: …"*,
moderatsiya kerak emas). Foydalanuvchilar, telefon raqamlari va profillar Firebase'da qoladi.

| Endpoint | Tana | Javob |
|---|---|---|
| `POST /auth/sms/send` | `{ "phone": "+998901234567" }` | `{ sent, expiresInSeconds: 300, resendAfterSeconds: 60 }` |
| `POST /auth/sms/verify` | `{ "phone": "...", "code": "123456" }` | `{ customToken }` → ilova `signInWithCustomToken` |

- Kod 6 xonali, 5 daqiqa amal qiladi, bir marta ishlatiladi; Firestore'da faqat HMAC xeshi saqlanadi
  (`sms_codes/{sha256(telefon)}`, ilovadan kirish yo'q).
- Cheklovlar: bitta raqamga 60 soniyada 1 ta, kuniga 5 ta SMS; bitta IP'dan soatiga 10 ta; 5 marta noto'g'ri kod → yangi kod kerak.
- Firebase foydalanuvchisi telefon raqami bo'yicha topiladi (Identity Toolkit), shuning uchun mavjud
  foydalanuvchilar o'z UID'i va ma'lumotlari bilan kiradi; yangi raqam uchun foydalanuvchi yaratiladi.

Sozlash (bir marta):
1. Google Cloud → IAM → service account (`FIREBASE_SERVICE_ACCOUNT`) ga **Firebase Authentication Admin**
   rolini qo'shing (Cloud Datastore User ham qoladi). Kalitni almashtirish shart emas.
2. devsms.uz → API kalitlari → kalit (`sms:send` ruxsati bilan). GitHub → Secrets → `DEVSMS_API_TOKEN`.
3. Actions → **Deploy video Worker** → Run workflow.

### DevSMS shablonlari (o'zingiz yaratgan shablonlar)

1. Actions → **List DevSMS templates** → Run workflow. Run sahifasidagi Summary'da jadval chiqadi:
   ID, nomi, holati, parametrlar (`{code}`, `%d`, `#name#` …) va matn. Shablonlar faqat o'qiladi
   (`GET /api/v1/templates`), hech biri o'zgartirilmaydi yoki o'chirilmaydi. Kalitga `templates:read` ruxsati kerak.
2. SMS kod uchun tanlangan shablonni `workers/video/wrangler.jsonc` → `vars` ga yozing:
   - `DEVSMS_OTP_TEMPLATE_ID`: shablon ID;
   - `DEVSMS_OTP_CODE_PLACEHOLDER`: kod qo'yiladigan parametr (shablonda bitta parametr bo'lsa, bo'sh qoldiring);
   - `DEVSMS_OTP_TEMPLATE_VALUES`: boshqa parametrlar uchun doimiy qiymatlar, JSON (masalan `{"{app}":"MyFit"}`);
   - `DEVSMS_FROM`: DevSMS'da tasdiqlangan yuboruvchi nomi (bo'sh = standart).
3. Deploy workflow'ni ishga tushiring. Worker shablon matnini API orqali o'qiydi (10 daqiqa keshlanadi),
   kodni joyiga qo'yadi va `POST /api/v1/sms` ga `message` + `template_id` bilan yuboradi (`sms:send`).
   `DEVSMS_OTP_TEMPLATE_ID` bo'sh bo'lsa, DevSMS'ning tayyor "Universal OTP" shabloni ishlatiladi.

Barcha parametrlar to'ldirilmasa yoki shablon topilmasa, SMS yuborilmaydi (`sms-misconfigured`).
Token faqat GitHub Secret va Worker secret'ida; Flutter ilovasida yo'q.

## Calorie API (shtrix-kod va rasm skaneri)

Worker [calorieapi.com](https://calorieapi.com/docs) bilan `X-API-Key` orqali ishlaydi; kalit faqat
Worker secret'ida (`CALORIE_API_KEY`), ilovada yo'q. Ikkala endpoint ham Firebase ID token talab qiladi.

| Endpoint | Tana | Calorie API |
|---|---|---|
| `POST /food/barcode` | `{ "barcode": "5449000000996" }` | `GET /api/v1/search/barcode/{upc}` |
| `POST /food/search` | `{ "query": "egg", "limit": 5 }` | `GET /api/v1/search/foods` |

- Natijalar 100 g/ml uchun normallashtiriladi va kvotani tejash uchun 1 kun keshlanadi.
- Ilovada: shtrix-kod → avval Calorie API, keyin Open Food Facts va FatSecret (avvalgidek).
  Rasm skaneri → telefondagi ML Kit ovqat nomini aniqlaydi → nom avval Calorie API'da, keyin
  avvalgi qidiruvda izlanadi. Calorie API REST'ida rasmdan kaloriya aniqlash yo'q (faqat Enterprise).
- Sozlash: GitHub Secrets → `CALORIE_API_KEY`, so'ng Deploy workflow. Smoke test bitta haqiqiy
  shtrix-kod so'rovini tekshiradi.
- Bepul tarif: oyiga 1 000 so'rov, daqiqasiga 10, tijoriy foydalanish uchun emas (Plus tarifi kerak).
