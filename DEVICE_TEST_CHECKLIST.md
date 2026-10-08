# RIZO — haqiqiy telefonda sinov ro'yxati

Fayllar: `~/Desktop/RIZO/apk/RIZO-Texnik.apk` va `RIZO-Mijoz.apk` (release kalit bilan imzolangan).
Har bir qadamni bajargach belgilang. Xato topsangiz: qaysi qadam, nima bo'ldi, ekran rasmi.

## 0. Tayyorgarlik
- [ ] Telefonda eski RIZO ilovalari bo'lsa **o'chiring** (imzo o'zgargan, ustiga o'rnatilmaydi).
- [ ] APK'ni telefonga yuboring (kabel, AirDrop emas — Android uchun Telegram/Drive/kabel), "noma'lum manbadan o'rnatish"ga ruxsat bering.
- [ ] Kamida 2 ta telefon: biri texnik (RIZO Texnik), biri mijoz (RIZO Mijoz). Admin ishlari uchun sayt: https://rizo-service-full.netlify.app
- [ ] Production bazada o'zingizning admin, texnik va mijoz akkauntingiz borligini tekshiring (demo akkauntlar production'da bo'lmasligi mumkin).
- [ ] **Birinchi so'rov ~50 soniya olishi mumkin** (Render uxlab qolgan). Xato emas, kuting.

## 1. Ikkala ilova uchun umumiy
- [ ] Ilova ochiladi, logo va splash to'g'ri ko'rinadi.
- [ ] Tilni uz → ru → en almashtiring, barcha matnlar o'zgaradi.
- [ ] Mavzu: yorug / qorong'i / tizim — hammasi o'qiladi.
- [ ] Kirish: noto'g'ri parol xato xabari beradi, to'g'ri parol kiritadi.
- [ ] Ilovani yopib qayta oching — tizimda qolasiz.
- [ ] Push: bildirishnomaga ruxsat so'raydi; ruxsat bering.

## 2. RIZO Texnik (texnik akkaunt)
- [ ] Ishlar ro'yxati (4 ustun/bo'lim) yuklanadi.
- [ ] Admin saytdan ishni shu texnikka tayinlang → **push keladi**, bosganda aynan o'sha ish ochiladi.
- [ ] "Yo'ldaman" → ETA oynasi chiqadi, vaqt tanlang; mijozga xabar boradi, ish kartasida ETA ko'rinadi.
- [ ] Ish sahifasida checklist: bandlarni belgilang; to'liq belgilanmasa yakunlash **bloklanadi**.
- [ ] Rasm qo'shish (kamera + galereya), rasm ko'rinadi. Saytda ham ko'rinadi.
- [ ] "Mening omborim": ehtiyot qismlar ro'yxati; ishda qism ishlatganda qoldiq kamayadi.
- [ ] To'xtatish (pauza) sababsiz bo'lmaydi.
- [ ] Yakunlash: rasm + xizmat + (almashtirishda) yangi mahsulot/serial talab qilinadi.
- [ ] **Offline rejim:** samolyot rejimini yoqing → ishni oching, o'zgarish qiling → rejimni o'chiring → o'zgarishlar serverga yuboriladi.
- [ ] Rolli akkaunt (agar bor): 2FA yoqilgan bo'lsa, kirishda kod so'raladi va to'g'ri kod bilan kiradi.

## 3. RIZO Mijoz (mijoz akkaunt)
- [ ] Ro'yxatdan o'tish / kirish. "Parolni unutdim" → SMS (Eskiz sozlangandan keyin) keladi.
- [ ] Yangi so'rov yaratish (ta'mirlash va o'rnatish); o'rnatish faqat manzil bilan.
- [ ] **Vizit vaqtini tanlash:** bo'sh slotlar chiqadi, band slot tanlab bo'lmaydi, ko'chirish limiti ishlaydi, bekor qilish ishlaydi.
- [ ] Texnik "yo'ldaman" bosganda ETA va **push** keladi.
- [ ] Smeta kelganda push; ilovada tasdiqlash/rad etish ishlaydi.
- [ ] Ish tugagach baho berish; 1–2 yulduz bo'lsa admin saytda ogohlantirish oladi.
- [ ] To'lov havolasi (Payme/Click ID kiritilgandan keyin): tugma chiqadi va to'g'ri sahifaga olib boradi.
- [ ] "Mening mahsulotlarim": kafolat hisoblagichi, kafolat uzaytirish rejasi so'rovi.
- [ ] Yordam markazi: maqolalar (admin avval qo'shishi kerak — hozir bo'sh).
- [ ] Sozlamalar: aloqa kanali (SMS/Telegram/ikkalasi), ma'lumotni yuklab olish, o'chirish so'rovi (**haqiqiy akkauntda bosmang**).
- [ ] Yuqoridagi qo'ng'iroqcha (bildirishnomalar) ochiladi, o'qilmaganlar hisoblanadi.

## 4. Telegram bot (agar ulangan bo'lsa)
- [ ] /start va telefon bilan bog'lash.
- [ ] Status xabarlari keladi; tugmalar: smeta tasdiqlash, baho berish, xabar yozish.

## 5. Tarmoq va chekka holatlar
- [ ] Zaif internet (2G/Wi-Fi o'chiq): ilova qotib qolmaydi, tushunarli xato ko'rsatadi.
- [ ] Katta rasm (8 MB dan kichik) yuklanadi; 8 MB dan katta rad etiladi.
- [ ] Ekranni aylantirish (planshetda gorizontal) to'g'ri ishlaydi.
- [ ] Rasmlar deploydan keyin ham saqlanib qoladi (R2 sozlangandan so'ng): Render'da "Manual Deploy" qiling, so'ng eski ish rasmini oching.

## Natija
Topilgan xatolar ro'yxatini menga yuboring — tuzataman.
