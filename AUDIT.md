# MyFit tekshiruv hisoboti

Sana: 2026-09-24.

## Loyiha tarkibi

| Qism | Hozirgi holat |
| --- | --- |
| Flutter ilova | Material 3, `lib/main.dart` orqali ishga tushadi |
| Kirish | Firebase Auth, telefon raqami, SMS kodi va avtomatik tasdiqlash |
| Profil | Ism, familiya, jins, yosh, bo'y, vazn, faollik, maqsad va til; Firestore |
| Bosh sahifa | Kunlik kaloriya va oziq moddalar yig'indisi, tezkor amallar |
| Ovqatlar | 5 mahal, gramm bilan porsiya, o'chirish, haftalik kaloriya ko'rinishi |
| Mahalliy katalog | O'zbek taomlari, meva, sabzavot, go'sht qismlari, qo'shimchalar |
| Internet qidiruvi | FatSecret Cloud Function, USDA va Open Food Facts zaxira manbalari |
| Shtrix-kod | Mobile Scanner va Open Food Facts |
| Rasmni aniqlash | ML Kit yorliqlari asosida taxminiy mahsulot qidiruvi |
| Kalkulyatorlar | Kunlik kaloriya/BMR, tana yog'i, suv |
| Mashqlar | Katalog, toifa/qidiruv, vaqt va sarflangan kaloriya |
| Tillar | O'zbek, rus, ingliz; barcha ekranlar hali bir xil darajada tarjima qilinmagan |
| Backend | `functions/index.js`, FatSecret tokeni va qidiruvi; Firestore/Storage qoidalari |
| Platformalar | Android, iOS, web, Windows va Linux papkalari bor; Firebase faqat Android/web uchun sozlangan |

## Tuzatilgan muammolar

1. `FoodNutrition.forGrams`: avval 150 g porsiyani 200 g ga aylantirish qiymatni yana 100 g bazadan ko'paytirardi. Endi joriy porsiya og'irligiga nisbatan hisoblanadi; vitamin/minerallar ham bir xil miqyosda qoladi.
2. Porsiya modelida nol, manfiy, NaN va cheksiz qiymatlar rad etiladi.
3. Kaloriya, tana yog'i, suv va profil son maydonlarida finite tekshiruvi qo'shildi.
4. Ovqat tanlash va skaner ekranlarida noto'g'ri gramm qiymatlari cheklangan. Juda katta qiymat natijani ko'rsatish bosqichida ham cheksiz songa aylantirilmaydi.
5. USDA noto'g'ri JSON yoki noto'g'ri tuzilma qaytarsa, xato xizmat xatosiga aylantirilib zaxira qidiruviga o'tadi.
6. USDA oziq moddalarida aniq ID qisman nom mosligidan ustun: to'yingan yog' umumiy yog' o'rniga olinmaydi.
7. USDA yozuvida suv bo'lmasa, `hasWaterData` endi yolg'on tarzda true bo'lmaydi.
8. Open Food Facts aniq ko'rsatilgan 0 kaloriyali mahsulotlarni qabul qiladi; tarkib ma'lumoti yo'q mahsulotlar chiqarib tashlanadi.
9. Qidiruvda kech kelgan eski javob yangi natijalarni almashtirmaydi.
10. Qidiruv keshi asl so'rovni ham hisobga oladi, bir xil inglizcha tarjimaga ega turli so'rovlar natijasi aralashmaydi.
11. Avtomatik SMS tasdiqlash muvaffaqiyatli bo'lsa, OTP oynasi yopiladi.
12. `AuthGate` qayta chizilganda auth/profil oqimlari qayta yaratilmaydi; foydalanuvchi yoki xizmat almashsa oqim yangilanadi.
13. Kundalik yuklanishi tugamaguncha ovqat qo'shish sahifasiga kirish cheklangan; yuklangan eski ro'yxat yangi qo'shilgan yozuvni almashtirib yubormaydi.
14. Yopilgan ekranlarga kechikib keladigan ayrim callbacklar uchun `mounted` tekshiruvi qo'shildi.
15. Rasm orqali topilgan mahsulotning qo'shimcha oziq tarkibi va metadata maydonlari saqlanadi.
16. Android release kalit fayli bo'lmasa, nullable qiymatni majburiy String ga aylantirish debug konfiguratsiyasini buzmaydi. Release uchun haqiqiy imzo sozlamalari baribir kerak.

## Tekshiruvlar

- Dastlabki `flutter analyze --no-pub`: muammo yo'q.
- Dastlabki testlar: 63/63 o'tdi.
- Yangi regression testlarning dastlabki ishga tushirilishi 6 ta xatoni qayta ko'rsatdi.
- Yakuniy `flutter analyze --no-pub`: muammo yo'q.
- Yakuniy `flutter test --no-pub`: 75/75 o'tdi (12 ta yangi test).
- `git diff --check`: o'tdi.
- `flutter doctor -v`: Flutter/Android vositalari tekshiruvi o'tdi.
- Android debug APK: muvaffaqiyatli yig'ildi — `build/app/outputs/flutter-apk/app-debug.apk`.
- Build uchun NDK 28.2.13676358 va Android SDK Platform 34/36 o'rnatildi. Yangi Android CLI paketi `android sdk install ndk/28.2.13676358` ko'rinishida qabul qilindi.
- Buildda uchinchi tomon plaginlarining KGP/eskirgan API ogohlantirishlari mavjud; ular ushbu debug buildni to'xtatmadi.
- Backend: `functions/test/fatsecret.test.js` dagi 2/2 test o'tdi; `index.js` sintaksis tekshiruvi o'tdi. Alohida `node` buyrug'i bo'lmagani uchun VS Code ichidagi Node runtime `ELECTRON_RUN_AS_NODE=1` bilan ishlatildi.
- Haqiqiy telefon, SMS, kamera, Firestore/Storage va deploy qilingan FatSecret funksiyasi bilan end-to-end sinov o'tkazilmadi.

## Yetishmayotgan yoki alohida yakunlash kerak bo'lgan qismlar

- Mashq yozuvlari faqat `HomePage` xotirasida; ilova qayta ochilganda saqlanmaydi.
- iOS, Windows va Linux uchun Firebase konfiguratsiyasi yo'q. Papka mavjudligi platforma tayyorligini anglatmaydi.
- Web uchun Firebase konfiguratsiyasi mavjud, lekin telefon kirishi va kamera/ML Kit oqimlari webga moslashtirilishi hamda browserda tekshirilishi kerak.
- Mashqlar ekranida va katalogida tarjimasiz matnlar mavjud.
- `ProfileService.uploadProfilePhoto` bor, ammo hozirgi profil ekranida surat yuklash oqimi ulanmagan.
- Mahsulotni suratdan aniqlash taomni taxmin qiladi; porsiya og'irligini rasmning o'zidan o'lchamaydi.
- USDA shaxsiy kaliti bo'lmasa `DEMO_KEY` ishlatiladi. FatSecret uchun server secretlari va deploy zarur; ularning jonli holati tekshirilmagan.
- Release imzo fayli lokal muhitda yo'q; ilovani do'konga chiqarish uchun kerak.
- README hali Flutter shabloni. Alohida ishga tushirish/deploy yo'riqnomasi va CI/integration testlari yetishmaydi.
- Kundalik saqlash xatolari hozir UI da ko'rsatilmaydi; offline va kun almashishi oqimlari uchun qo'shimcha integration tekshiruv zarur.

Ushbu natijalar kod va avtomatik testlar doirasida. Ular barcha qurilmalar va jonli xizmatlarda xato yo'qligi kafolati emas.
