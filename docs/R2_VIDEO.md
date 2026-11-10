# Dars videolari: Cloudflare R2

Darslar ("Darslar" tab) videolari Cloudflare R2'da saqlanadi va ochiq URL orqali ko'rsatiladi.
Firebase Authentication, Firestore va Storage (profil rasmlari) o'zgarmaydi.

## Qanday ishlaydi

```
Admin ilovada video tanlaydi
  └─ ilova: .mp4, ≤ 2 GB, H.264 tekshiruvi (faylning faqat sarlavha qismlari o'qiladi)
  └─ createVideoUploadUrl (Cloud Function, admin tekshiruvi)
       └─ video_uploads/{uploadId} sessiyasi + 15 daqiqalik presigned PUT URL
  └─ ilova faylni oqim (stream) bilan to'g'ridan-to'g'ri R2'ga PUT qiladi (foiz, bekor qilish)
  └─ finalizeVideoUpload (Cloud Function)
       └─ HeadObject: fayl bormi, hajmi va Content-Type mosmi
       └─ moov qismini o'qib H.264 ekanini tekshiradi
       └─ faqat shundan keyin courses/{categoryId}/lessons/{lessonId} yoziladi
```

Rad etilgan yuklash (masalan HEVC) uchun faqat o'sha sessiya yaratgan R2 obyekti o'chiriladi.
Boshqa hech qanday video avtomatik ko'chirilmaydi yoki o'chirilmaydi.

## Firestore tuzilmasi

| Yo'l | Kim o'qiydi | Kim yozadi |
|---|---|---|
| `admins/{uid}` | faqat o'sha foydalanuvchi | faqat Firebase Console |
| `courses/{categoryId}/lessons/{lessonId}` | tizimga kirgan har kim | faqat `finalizeVideoUpload` |
| `video_uploads/{uploadId}` | hech kim (ilova) | faqat Cloud Functions |

Dars hujjati:

```
order, title, description, durationMinutes, durationSeconds, videoUrl, thumbnailUrl,
storageProvider: "r2", objectKey, sizeBytes, contentType: "video/mp4", videoCodec,
uploadedBy, uploadId, createdAt
```

`categoryId` qiymatlari `lib/data/trainer_course.dart` dagi `kLessonCategories` bilan bir xil
(`functions/r2_video.js` → `LESSON_CATEGORY_IDS`; test ikkalasini solishtiradi).

## Bir martalik sozlash

### 1. R2 API token
Cloudflare → R2 → **Manage R2 API Tokens** → **Create API token**:
- Permission: **Object Read & Write**
- Specify bucket: **myfit-videos**

Access Key ID va Secret Access Key'ni hech qayerga yozmang (chat, GitHub, ilova kodi).

### 2. Secret'lar (o'z kompyuteringizda, loyiha papkasida)

```bash
firebase use myfit-d6275
firebase functions:secrets:set R2_ACCESS_KEY_ID
firebase functions:secrets:set R2_SECRET_ACCESS_KEY
```

### 3. Maxfiy bo'lmagan parametrlar
Standart qiymatlar kodda bor; deploy paytida CLI so'rasa, Enter bosing:

| Parametr | Standart qiymat |
|---|---|
| `R2_ENDPOINT` | `https://7d6c72f2d7ccf971e52c251086f2bfa1.r2.cloudflarestorage.com` |
| `R2_BUCKET` | `myfit-videos` |
| `R2_PUBLIC_BASE_URL` | `https://pub-32dc4a48be774882aaf3dd1d07697a5b.r2.dev` |

O'z domeningizga o'tganda `functions/.env.myfit-d6275` faylini yarating (u `.gitignore`da):

```
R2_PUBLIC_BASE_URL=https://video.myfit.uz
```

Yangi URL faqat yangi yuklangan videolarga yoziladi; eski darslar `videoUrl`i o'zgarmaydi.

### 4. Admin qo'shish
1. Firebase Console → Authentication → Users → foydalanuvchining **User UID** sini nusxalang.
2. Firestore → **Start collection** `admins` → Document ID = shu UID → istalgan maydon, masalan `role: "admin"`.

Ilovada bo'lim sahifasida o'ng yuqorida yuklash tugmasi paydo bo'ladi (sahifani qayta oching).

### 5. Deploy
Cloud Functions uchun loyiha **Blaze** rejasida bo'lishi kerak.

```bash
cd functions && npm ci && npm test && cd ..
firebase deploy --only firestore:rules,functions:createVideoUploadUrl,functions:finalizeVideoUpload
```

`firestore.rules` faylida avvalgi `users` va `food_logs` qoidalari ham bor, ular o'zgarmagan.
Bu buyruq FatSecret funksiyalariga tegmaydi.

Darslar sonini ko'rsatish uchun `lessons` collection group so'rovi ishlatiladi. Agar Firestore
"index kerak" desa, xatodagi havola orqali indeksni yarating (odatda talab qilinmaydi).

## CORS
- **Android va iOS uchun CORS kerak emas** (CORS faqat brauzerga tegishli).
- Ilovaning **web** versiyasidan yuklash kerak bo'lsa, R2 → myfit-videos → Settings → CORS Policy:

```json
[
  {
    "AllowedOrigins": [
      "https://myfit-d6275.web.app",
      "https://myfit-d6275.firebaseapp.com",
      "http://localhost:5000"
    ],
    "AllowedMethods": ["PUT", "GET", "HEAD"],
    "AllowedHeaders": ["content-type"],
    "ExposeHeaders": ["ETag"],
    "MaxAgeSeconds": 3600
  }
]
```

Web brauzerda katta fayllar xotiraga to'liq o'qilishi mumkin; katta videolarni telefondan yuklang.

## Videoni tayyorlash
Faqat **H.264 MP4** qabul qilinadi. iPhone'dagi `.mov` / HEVC videolar rad etiladi.
Tavsiya (`faststart` video ochilishini tezlashtiradi):

```bash
ffmpeg -i input.mov -c:v libx264 -preset slow -crf 23 -c:a aac -b:a 128k -movflags +faststart output.mp4
```

## Xato sabablari (`details.reason`)

| reason | Ma'nosi |
|---|---|
| `not-admin` | `admins/{uid}` yo'q |
| `unsupported-format` | MP4 emas (yoki QuickTime) |
| `not-h264` | Video kodeki H.264 emas |
| `too-large` / `empty-file` | 2 GB dan katta / bo'sh |
| `size-mismatch` / `object-missing` | Yuklash to'liq tugamagan |
| `upload-expired` | Sessiya 24 soatdan eski |
| `storage-unavailable` | R2 bilan aloqa yo'q |

## Eslatmalar
- `r2.dev` manzili sinov uchun; tezlik cheklangan. Ommaga chiqarishdan oldin o'z domeningizni ulang.
- Bekor qilingan yoki tugallanmagan yuklashlar `video_uploads` da `pending` bo'lib qoladi;
  R2'da qisman obyekt qolsa, uni qo'lda o'chirish mumkin (avtomatik o'chirilmaydi).
- Testlar: `cd functions && npm test`, `flutter test`.
