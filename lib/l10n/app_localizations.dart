import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

class AppLocalizations {
  const AppLocalizations(this.locale);

  final Locale locale;

  static const supportedLocales = [Locale('uz'), Locale('ru'), Locale('en')];

  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates = [
    _AppLocalizationsDelegate(),
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ];

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations) ??
        const AppLocalizations(Locale('uz'));
  }

  String text(String key, [Map<String, Object> values = const {}]) {
    var result =
        _translations[locale.languageCode]?[key] ??
        _translations['uz']![key] ??
        key;
    for (final entry in values.entries) {
      result = result.replaceAll('{${entry.key}}', '${entry.value}');
    }
    return result;
  }

  static const _translations = <String, Map<String, String>>{
    'uz': {},
    'ru': {
      'Sizga mos sog‘lom hayot.': 'Здоровый образ жизни в вашем ритме.',
      'Profil rasmi': 'Фото профиля',
      'Profil rasmini o‘zgartirish': 'Изменить фото профиля',
      'Kamerada suratga olish': 'Сделать фото',
      'Rasmni olib tashlash': 'Убрать фото',
      'Rasm qo‘shish': 'Добавить фото',
      'Rasmni o‘zgartirish': 'Изменить фото',
      'Rasm yuklanmoqda…': 'Загрузка фото…',
      'Profil rasmi yangilandi.': 'Фото профиля обновлено.',
      'Profil rasmi olib tashlandi.': 'Фото профиля убрано.',
      'Rasmni yangilab bo‘lmadi. Ruxsat va internetni tekshirib, qayta urinib ko‘ring.':
          'Не удалось обновить фото. Проверьте разрешения и подключение к интернету и повторите попытку.',
      'Sozlamalar': 'Настройки',
      'Hisobotlar': 'Отчёты',
      'Ovqatlanishingiz raqamlarda': 'Ваше питание в цифрах',
      'Kunlik': 'День',
      'Haftalik': 'Неделя',
      'Oylik': 'Месяц',
      'Oldingi davr': 'Предыдущий период',
      'Keyingi davr': 'Следующий период',
      'Hisobotni yuklab bo‘lmadi.': 'Не удалось загрузить отчёт.',
      'Jami kaloriya': 'Всего калорий',
      'Kunlik o‘rtacha': 'В среднем за день',
      'Yozuvli kunlar': 'Дни с записями',
      'O‘rtacha bugungacha bo‘lgan barcha kunlar bo‘yicha.':
          'Среднее по всем дням периода до сегодняшнего дня включительно.',
      'Bu davrda ovqat yozuvlari yo‘q.':
          'За этот период нет записей о питании.',
      'Kundalikka ovqat qo‘shing — hisoblar shu yerda ko‘rinadi.':
          'Добавьте еду в дневник — здесь появятся расчёты.',
      'Kaloriya dinamikasi': 'Динамика калорий',
      'Kunlik maqsad': 'Дневная цель',
      'Kunni bosib, ovqatlarni ko‘ring. Chiziq — joriy kunlik maqsad.':
          'Нажмите на день, чтобы увидеть еду. Линия — текущая дневная цель.',
      'Makronutrientlar': 'Макронутриенты',
      'Yog‘lar': 'Жиры',
      'Ulushlar oqsil va uglevod uchun 4, yog‘ uchun 9 kcal/g asosida.':
          'Доли рассчитаны по 4 ккал/г для белков и углеводов и 9 ккал/г для жиров.',
      'Ovqatlanish taqsimoti': 'По приёмам пищи',
      'Iste’mol qilingan mahsulotlar': 'Съеденные продукты',
      'ta yozuv': 'записей',
      'Hisoblar saqlangan porsiyalarga asoslangan. Yozuvsiz kun iste’mol qilinmaganini anglatmaydi. Maqsad joriy profilingizdan olinadi.':
          'Расчёты основаны на сохранённых порциях. Отсутствие записей не означает отсутствие питания. Цель взята из текущего профиля.',
      'Ayrim oziq qiymatlari yetishmaydi. ≥ — ma’lum qiymatlar yig‘indisi; ulushlar to‘liq emas.':
          'Некоторые данные отсутствуют. ≥ — сумма известных значений; доли неполные.',
      'Kelajak kun': 'Будущий день',
      'Yozuv yo‘q': 'Нет записей',
      "Yana ko‘rsatish": "Показать ещё",
      "Oziq qiymati 100 {unit} uchun": "Пищевая ценность на 100 {unit}",
      "1–5000 {unit} oralig‘ida miqdor kiriting.":
          "Введите количество от 1 до 5000 {unit}.",
      "Mahsulot bazalarda topilmadi.": "Продукт не найден в базах данных.",
      "Qiymatlar mahsulotda ko‘rsatilgan 100 g yoki 100 ml uchun.":
          "Значения указаны на 100 г или 100 мл в зависимости от продукта.",
      'Kundalikni yuklab bo‘lmadi.': 'Не удалось загрузить дневник.',
      'Qayta urinish': 'Повторить',
      'Saqlash amalga oshmadi. Qayta urinib ko‘ring.':
          'Не удалось сохранить. Повторите попытку.',
      'Kalendar': 'Календарь',
      'Ovqatlanish tarixi': 'История питания',
      'Oldingi kun': 'Предыдущий день',
      'Keyingi kun': 'Следующий день',
      'Tarixni yuklab bo‘lmadi.': 'Не удалось загрузить историю.',
      'Bu kunda ovqat saqlanmagan.': 'За этот день нет записей о питании.',
      'Oxirgi qidiruvlar': 'Недавние запросы',
      'Tozalash': 'Очистить',
      'Tarixdan o‘chirish': 'Удалить из истории',
      'Qidiruvlaringiz shu yerda saqlanadi.':
          'Ваши поисковые запросы появятся здесь.',
      'Qidiruv tarixini saqlash yoki yuklashda xatolik.':
          'Не удалось сохранить или загрузить историю поиска.',
      'Manba': 'Источник',
      'Mahalliy katalog — taxminiy qiymatlar':
          'Местный каталог — примерные значения',
      'Asosiy oziq qiymatlari to‘liq emas. Boshqa yozuvni tanlang.':
          'Основные пищевые данные неполные. Выберите другую запись.',
      'O‘rtacha dona': 'средняя штука',
      'Oziq qiymati': 'Пищевая ценность',
      'Porsiya': 'Порция',
      'Porsiyada': 'в порции',
      'Energiya qiymati': 'Энергетическая ценность',
      'To‘yingan yog‘lar': 'Насыщенные жиры',
      'Bir to‘yinmagan yog‘lar': 'Мононенасыщенные жиры',
      'Ko‘p to‘yinmagan yog‘lar': 'Полиненасыщенные жиры',
      '— ma’lumot mavjud emas': '— данные отсутствуют',
      'Shakar': 'Сахар',
      'kJ': 'кДж',
      'mg': 'мг',
      'Katta dona': 'Крупная штука',
      'Kichik dona': 'Маленькая штука',
      'O‘lchov birligi': 'Единица измерения',
      'Dona vazni taxminiy, yeyiladigan qism uchun.':
          'Примерный вес съедобной части одной штуки.',
      'Ilova ko\u2018rinishi': 'Оформление',
      'Oq rejim': 'Светлая',
      'Qora rejim': 'Тёмная',
      'Rejimni saqlab bo\u2018lmadi. Qayta urinib ko\u2018ring.':
          'Не удалось сохранить тему. Попробуйте ещё раз.',
      'Dona': 'Штуки',
      'Gramm': 'Граммы',
      'dona': 'шт.',
      '1 dona ≈ {grams} g (katta tuxum)': '1 шт. ≈ {grams} г (крупное яйцо)',
      'Profil': 'Профиль',
      'Vazn': 'Вес',
      'Bo‘y': 'Рост',
      'Shaxsiy reja': 'Личный план',
      'Maqsad': 'Цель',
      'Faollik': 'Активность',
      'Shaxsiy ma’lumotlar': 'Личные данные',
      'Yosh': 'Возраст',
      'Jins': 'Пол',
      'Telefon': 'Телефон',
      'Kiritilmagan': 'Не указан',
      'Erkak': 'Мужчина',
      'Ayol': 'Женщина',
      'Vazn tashlash': 'Снижение веса',
      'Vazn orttirish': 'Набор веса',
      'Vaznni saqlash': 'Поддержание веса',
      'Past faollik': 'Низкая активность',
      'O‘rtacha faollik': 'Средняя активность',
      'Yuqori faollik': 'Высокая активность',
      'Profilni tahrirlash': 'Редактировать профиль',
      'Akkauntdan chiqish': 'Выйти из аккаунта',
      'Til': 'Язык',
      'Ilova tili': 'Язык приложения',
      'O‘zbekcha': 'Узбекский',
      'Ruscha': 'Русский',
      'Inglizcha': 'Английский',
      'Saqlash': 'Сохранить',
      'Bekor qilish': 'Отмена',
      'Profil muvaffaqiyatli yangilandi': 'Профиль успешно обновлён',
      'Profilni saqlab bo‘lmadi. Qayta urinib ko‘ring.':
          'Не удалось сохранить профиль. Попробуйте ещё раз.',
      'Kameradan olish': 'Сделать фото',
      'Galereyadan tanlash': 'Выбрать из галереи',
      'Bosh sahifa': 'Главная',
      'Ovqatlar': 'Питание',
      'Mashqlar': 'Тренировки',
      'Xayrli tong,': 'Доброе утро,',
      'Xayrli kun,': 'Добрый день,',
      'Xayrli kech,': 'Добрый вечер,',
      'Tezkor amallar': 'Быстрые действия',
      'Ovqatni skanerlash': 'Сканировать еду',
      'Shtrix-kod skaneri': 'Сканер штрихкода',
      'Ovqat qidirish': 'Поиск еды',
      'Kalkulyator': 'Калькуляторы',
      'Mashq qo‘shish': 'Добавить тренировку',
      'Bugun qo‘shilgan ovqatlar': 'Добавленные сегодня продукты',
      'Hali ovqat qo‘shilmagan. Yuqoridan qidiring.':
          'Продукты ещё не добавлены. Воспользуйтесь поиском выше.',
      'Ovqatlanish': 'Питание',
      'Sog‘lom kuningiz shu yerdan boshlanadi':
          'Ваш здоровый день начинается здесь',
      'Bugungi menyu': 'Меню на сегодня',
      'Nonushta': 'Завтрак',
      'Tushlik (Abed)': 'Обед',
      'Kechki ovqat': 'Ужин',
      'Perekus': 'Перекус',
      'Kechki tamaddi': 'Вечерний перекус',
      'mahsulot': 'продуктов',
      'Ovqat qo‘shish': 'Добавить еду',
      'Kaloriya': 'Калории',
      'Tarkibi': 'Состав',
      'Natriy': 'Натрий',
      'Kaliy': 'Калий',
      'Temir': 'Железо',
      'Kalsiy': 'Кальций',
      'Xolesterin': 'Холестерин',
      'Fosfor': 'Фосфор',
      'Magniy': 'Магний',
      'Vitamin E': 'Витамин E',
      'Rux': 'Цинк',
      'Vitamin D': 'Витамин D',
      'Vitamin K2': 'Витамин K2',
      'Oqsil': 'Белки',
      'Uglevod': 'Углеводы',
      'Yog‘': 'Жиры',
      'Kletchatka': 'Клетчатка',
      'Suv': 'Вода',
      'Mahsulot aniqlandi': 'Продукт найден',
      'Mahsulot qidirilmoqda...': 'Ищем продукт...',
      'Shtrix-kodni ramka ichiga joylashtiring': 'Поместите штрихкод в рамку',
      'Kod avtomatik aniqlanadi': 'Код определится автоматически',
      'Qayta skanerlash': 'Сканировать снова',
      'Mahsulot og‘irligi': 'Вес продукта',
      'Ma’lumot yo‘q': 'Нет данных',
      'Hisoblash va qo‘shish': 'Рассчитать и добавить',
      'Kamida 2 ta belgi yozing.': 'Введите не менее 2 символов.',
      'Qo‘shish': 'Добавить',
      'Miqdori': 'Количество',
      'Fitness kalkulyatorlari': 'Фитнес-калькуляторы',
      'Kunlik kaloriya va BMR': 'Суточные калории и BMR',
      'Tana yog‘i foizi': 'Процент жира',
      'Kunlik suv ehtiyoji': 'Суточная потребность в воде',
      'TANA DINAMIKASI': 'ДИНАМИКА ТЕЛА',
      'Bugungi holatingiz': 'Ваше состояние сегодня',
      'Ma’lumot kutilmoqda': 'Ожидание данных',
      'Yengil tana': 'Низкий вес',
      'Muvozanatli': 'В норме',
      'Kuchli tana': 'Повышенный вес',
      'Yuqori vazn': 'Высокий вес',
      'HAFTALIK MAQSAD': 'НЕДЕЛЬНАЯ ЦЕЛЬ',
      'Bugun {calories} kcal': 'Сегодня {calories} ккал',
      '5 mahal': '5 приёмов пищи',
      'Kun davomida': 'В течение дня',
      'Kunni foydali va quvvatli boshlang': 'Начните день полезно и энергично',
      'To‘yimli va muvozanatli asosiy ovqat':
          'Сытный и сбалансированный основной приём пищи',
      'Yengil va oqsilga boy kechki ratsion':
          'Лёгкий ужин с высоким содержанием белка',
      'Ovqatlar orasidagi foydali tamaddi':
          'Полезный перекус между приёмами пищи',
      'Uyqu oldidan yengil va foydali tamaddi':
          'Лёгкий полезный перекус перед сном',
      'Maqsadingiz uchun kerakli hisob-kitobni tanlang.':
          'Выберите нужный расчёт для своей цели.',
      'Vazn saqlash, tashlash yoki olish uchun kaloriya miqdori.':
          'Калории для поддержания, снижения или набора веса.',
      'Bo‘yin, qorin/bel va son o‘lchovlari orqali yog‘ foizini hisoblash.':
          'Расчёт процента жира по обхвату шеи, живота/талии и бёдер.',
      'Vazn, mashq davomiyligi va ob-havoga qarab suv miqdori.':
          'Норма воды с учётом веса, тренировок и погоды.',
      'Kunlik suv miqdori': 'Суточная норма воды',
      'Vazn, mashq davomiyligi va ob-havoga qarab kunlik ehtiyojingizni hisoblang.':
          'Рассчитайте суточную потребность с учётом веса, тренировок и погоды.',
      'Kunlik mashq': 'Тренировка в день',
      'daqiqa': 'минут',
      'Issiq ob-havo yoki ko‘p terlash':
          'Жаркая погода или сильное потоотделение',
      'Hisoblash': 'Рассчитать',
      'Kunlik tavsiya': 'Рекомендация на день',
      'litr': 'л',
      'Vazn yoki mashq davomiyligini to‘g‘ri kiriting.':
          'Правильно укажите вес и длительность тренировки.',
      'Tana yog‘i kalkulyatori': 'Калькулятор жира',
      'U.S. Navy va BMI usullarida tana yog‘ini hisoblash.':
          'Расчёт жира по методам U.S. Navy и BMI.',
      'O‘lchov birligi: kilogramm va santimetr':
          'Единицы измерения: килограммы и сантиметры',
      'yil': 'лет',
      'Bo‘yin': 'Шея',
      'Qorin': 'Живот',
      'Bel': 'Талия',
      'Son aylanasi': 'Обхват бёдер',
      'Erkak: qorinni kindik atrofidan o‘lchang. Ayol: belning eng ingichka va sonning eng keng joyini o‘lchang.':
          'Мужчинам: измерьте живот на уровне пупка. Женщинам: измерьте самое узкое место талии и самое широкое место бёдер.',
      'Kunlik kaloriya': 'Суточные калории',
      'Calculator.net bilan bir xil BMR formulalari va faollik koeffitsiyentlari.':
          'Формулы BMR и коэффициенты активности как на Calculator.net.',
      'BMR — dam olish holati': 'BMR — состояние покоя',
      'Kamharakat: mashqsiz yoki juda kam':
          'Малоподвижный: без тренировок или очень редко',
      'Yengil: haftasiga 1–3 marta': 'Лёгкая: 1–3 раза в неделю',
      'O‘rtacha: haftasiga 4–5 marta': 'Средняя: 4–5 раз в неделю',
      'Faol: har kuni yoki haftasiga 3–4 intensiv':
          'Активный: ежедневно или 3–4 интенсивных тренировки',
      'Juda faol: haftasiga 6–7 intensiv':
          'Очень активный: 6–7 интенсивных тренировок',
      'O‘ta faol: har kuni juda intensiv/jismoniy ish':
          'Экстремально активный: тяжёлые тренировки/физическая работа',
      'BMR formulasi': 'Формула BMR',
      'Tana yog‘i': 'Жир тела',
      'BAZAL METABOLIZM': 'БАЗАЛЬНЫЙ МЕТАБОЛИЗМ',
      'Dam olish energiyasi': 'Энергия в состоянии покоя',
      'Tanangiz to‘liq dam olganda hayotiy funksiyalar uchun sarflaydigan energiya.':
          'Энергия, которую организм расходует в полном покое на жизненные функции.',
      'Yengil vazn tashlash': 'Лёгкое снижение веса',
      'Tez vazn tashlash': 'Быстрое снижение веса',
      'Yengil vazn olish': 'Лёгкий набор веса',
      'Vazn olish': 'Набор веса',
      'Tez vazn olish': 'Быстрый набор веса',
      'Vazn olish rejalarini yopish': 'Скрыть планы набора веса',
      'Vazn olish rejalarini ko‘rish': 'Показать планы набора веса',
      'Vazn tashlash natijalariga qayting':
          'Вернуться к результатам снижения веса',
      'Kaloriya maqsadlarini oching': 'Открыть цели по калориям',
      'hafta': 'неделю',
      'Chiqish': 'Выйти',
      '{food} qo‘shildi': '{food} добавлено',
      'Ovqat muvaffaqiyatli qo‘shildi': 'Продукт успешно добавлен',
      'Olib tashlash': 'Удалить',
      'Bu bo‘lim tez orada qo‘shiladi.': 'Этот раздел скоро появится.',
      'Ism': 'Имя',
      'Familiya': 'Фамилия',
      'Maydonni to‘ldiring': 'Заполните поле',
      '{min}–{max} oralig‘ida kiriting': 'Введите значение от {min} до {max}',
      'Rasm yuklash bekor qilindi.': 'Загрузка изображения отменена.',
      'Rasmni yuklab bo‘lmadi. Internetni tekshiring.':
          'Не удалось загрузить изображение. Проверьте интернет.',
      'Telefon raqamingiz bilan kiring': 'Войдите по номеру телефона',
      'Telefon raqam': 'Номер телефона',
      'To‘liq raqam kiriting (9 ta raqam)': 'Введите полный номер (9 цифр)',
      'SMS kod olish': 'Получить SMS-код',
      'Raqamingizga 6 xonali SMS kod yuboriladi':
          'Мы отправим 6-значный SMS-код',
      'SMS kod': 'SMS-код',
      '{phone} raqamiga yuborilgan\n6 xonali SMS kodni kiriting':
          'Введите 6-значный SMS-код,\nотправленный на {phone}',
      '6 xonali SMS kodni kiriting': 'Введите 6-значный SMS-код',
      'Tasdiqlash': 'Подтвердить',
      'Yuborilmoqda...': 'Отправка...',
      'Qayta yuborish ({seconds} s)': 'Повторить через {seconds} с',
      'SMS kodni qayta yuborish': 'Отправить SMS-код снова',
      'SMS kod yuborildi': 'SMS-код отправлен',
      'SMS kod yuborilmoqda...': 'SMS-код отправляется...',
      'SMS kod yuborildi. Xabarlarni tekshiring.':
          'SMS-код отправлен. Проверьте сообщения.',
      'Avval SMS kodni oling.': 'Сначала получите SMS-код.',
      'SMS kod noto‘g‘ri.': 'Неверный SMS-код.',
      'SMS kod muddati tugadi. Qayta yuboring.':
          'Срок SMS-кода истёк. Отправьте снова.',
      'Telefon raqam noto‘g‘ri.': 'Неверный номер телефона.',
      'Juda ko‘p urinish. Keyinroq qayta urinib ko‘ring.':
          'Слишком много попыток. Повторите позже.',
      'Internet aloqasi yo‘q.': 'Нет подключения к интернету.',
      'O‘zingiz haqingizda ayting.': 'Расскажите о себе',
      'Shunda MyFit sizga mos shaxsiy reja tuza oladi.':
          'MyFit создаст подходящий вам персональный план.',
      'Bo‘y, sm': 'Рост, см',
      'Vazn, kg': 'Вес, кг',
      'FAOLLIK DARAJASI': 'УРОВЕНЬ АКТИВНОСТИ',
      'O‘rtacha': 'Средняя',
      'Past': 'Низкая',
      'Yuqori': 'Высокая',
      'SIZNING MAQSADINGIZ': 'ВАША ЦЕЛЬ',
      'Vazn kamaytirish': 'Снизить вес',
      'Vazn oshirish': 'Набрать вес',
      'Vazn saqlash': 'Сохранить вес',
      'Davom etish': 'Продолжить',
      'Majburiy': 'Обязательное поле',
      'Kamida 2 harf': 'Минимум 2 буквы',
      'Kiriting': 'Введите значение',
      '1 dan 5000 grammgacha miqdor kiriting.':
          'Введите количество от 1 до 5000 граммов.',
      'AI ovqatni aniqlamoqda...': 'ИИ распознаёт блюдо...',
      'AI ovqat skaneri': 'ИИ-сканер еды',
      'Mahsulot tarkibini bir zumda biling':
          'Узнайте состав продукта за секунды',
      'Ovqatni ramka ichiga joylashtiring': 'Поместите блюдо внутрь рамки',
      'Tahlilga tayyor': 'Готово к анализу',
      'Suratga olish': 'Сделать снимок',
      'Galereya': 'Галерея',
      'Qayta olish': 'Переснять',
      'AI aniqlandi': 'Распознано ИИ',
      'Og‘irlik (g)': 'Вес (г)',
      'Bu mahsulot Open Food Facts bazasida topilmadi.':
          'Продукт не найден в базе Open Food Facts.',
      'Open Food Facts ma’lumoti': 'Данные Open Food Facts',
      'Shtrix-kod: {barcode}': 'Штрихкод: {barcode}',
      'Masalan: osh, somsa, tovuq, olma...':
          'Например: плов, самса, курица, яблоко...',
      'Ovqat topilmadi. Boshqa nom bilan yozing (masalan: tovuq, olma, guruch, non).':
          'Еда не найдена. Попробуйте другое название (например: курица, яблоко, рис, хлеб).',
      'Qiymatlar 100 gramm uchun. Kerakli ovqatni tanlab, miqdorini kiriting.':
          'Значения указаны на 100 г. Выберите продукт и введите количество.',
      'gramm': 'грамм',
      'Profilni yuklashda xatolik:\n{error}':
          'Ошибка загрузки профиля:\n{error}',
      'Profil rasmini tanlang': 'Выберите фото профиля',
      'Firebase Storage hali ishga tushirilmagan.':
          'Firebase Storage ещё не настроен.',
      'Profil rasmini yuklash uchun ruxsat berilmagan.':
          'Нет разрешения на загрузку фото профиля.',
      'Rasmni yuklab bo‘lmadi ({code}).':
          'Не удалось загрузить изображение ({code}).',
      '{meal} uchun 3 ta variant keyingi bosqichda qo‘shiladi.':
          'Три варианта для «{meal}» будут добавлены на следующем этапе.',
      'Mashqlar bo‘limi tez orada.': 'Раздел тренировок скоро появится.',
      'MyFit foydalanuvchisi': 'Пользователь MyFit',
      'Yosh 15–80 oralig‘ida bo‘lishi kerak.':
          'Возраст должен быть от 15 до 80 лет.',
      'Yosh 18–80 oralig‘ida bo‘lishi kerak.':
          'Возраст должен быть от 18 до 80 лет.',
      'Bo‘y 100–250 cm oralig‘ida bo‘lishi kerak.':
          'Рост должен быть от 100 до 250 см.',
      'Vazn 30–350 kg oralig‘ida bo‘lishi kerak.':
          'Вес должен быть от 30 до 350 кг.',
      'Faollik darajasi noto‘g‘ri.': 'Некорректный уровень активности.',
      'Katch–McArdle uchun tana yog‘ini 2–70% kiriting.':
          'Для Katch–McArdle укажите жир тела от 2 до 70%.',
      'Bo‘yin yoki bel/qorin o‘lchovini tekshiring.':
          'Проверьте измерения шеи и талии/живота.',
      'Qorin o‘lchovi bo‘yin o‘lchovidan katta bo‘lishi kerak.':
          'Обхват живота должен быть больше обхвата шеи.',
      'Ayollar uchun son o‘lchovini kiriting.':
          'Для женщин укажите обхват бёдер.',
      'O‘lchovlardan haqiqiy natija olinmadi. Qayta o‘lchang.':
          'Не удалось получить корректный результат. Повторите измерения.',
      'Ovqat turi aniq topilmadi. Boshqa burchakdan qayta suratga oling.':
          'Не удалось точно определить блюдо. Сфотографируйте под другим углом.',
      'Taom ko‘rindi, ammo unga mos oziq qiymati topilmadi.':
          'Блюдо распознано, но данные о пищевой ценности не найдены.',
      'Internetga ulanishda xatolik. Qayta urinib ko‘ring.':
          'Ошибка подключения к интернету. Попробуйте ещё раз.',
      'API kaliti noto‘g‘ri. USDA kalitini tekshiring.':
          'Неверный ключ API. Проверьте ключ USDA.',
      'kg': 'кг',
      'cm': 'см',
      'g': 'г',
      'ml': 'мл',
      'kcal': 'ккал',
      'BMI': 'ИМТ',
      'Xatolik: {error}': 'Ошибка: {error}',
      'Xatolik ({code}).': 'Ошибка ({code}).',
      'Saqlashda xatolik: {error}': 'Ошибка сохранения: {error}',
      'Hudud': 'Регион',
      'Ovqatga qo‘shish': 'Добавить к приёму пищи',
      'Milliy taomni qidiring': 'Поиск национального блюда',
      'Taom yoki mahsulotni qidiring': 'Найдите блюдо или продукт',
      'Masalan: pomidor, tuxum, osh yoki manti':
          'Например: помидор, яйцо, плов или манты',
      'Mahsulot topilmadi': 'Продукт не найден',
      'Boshqa nom bilan qayta qidiring': 'Попробуйте другое название',
      'Oziq qiymati 100 g uchun': 'Пищевая ценность на 100 г',
      'Mahsulotlarni yuklab bo‘lmadi. Qayta urinib ko‘ring.':
          'Не удалось загрузить продукты. Попробуйте ещё раз.',
      'O‘zbek milliy taomlari': 'Узбекские национальные блюда',
      'Taom topilmadi': 'Блюдо не найдено',
      'Qidiruv natijalari': 'Результаты поиска',
      'Saqlanganlar': 'Сохранённые',
      '{name} saqlandi': '{name} сохранено',
      '{count} ta mahsulot': '{count} продукт(ов)',
      'Tanlanganlar qo‘shilmadi': 'Выбранное не добавлено',
      'Saqlangan {count} ta mahsulot menyuga qo‘shilmaydi. Chiqasizmi?':
          'Сохранённые продукты ({count}) не будут добавлены в меню. Выйти?',
      'Qolish': 'Остаться',
      'Server vaqtincha ishlamayapti. Keyinroq urinib ko‘ring.':
          'Сервер временно недоступен. Попробуйте позже.',
      'Video xizmati hali sozlanmagan.': 'Видеосервис ещё не настроен.',
      'Dars nomi': 'Название урока',
      'Dars nomini kiriting (2–120 belgi).':
          'Введите название урока (2–120 символов).',
      'Darslarni yuklab bo‘lmadi. Internetni tekshiring.':
          'Не удалось загрузить уроки. Проверьте интернет.',
      'Faqat MP4 (H.264), 2 GB gacha.': 'Только MP4 (H.264), до 2 ГБ.',
      'Faqat MP4 formatidagi videolar qabul qilinadi.':
          'Принимаются только видео в формате MP4.',
      'Galereyadan MP4 video': 'MP4-видео из галереи',
      'Internet aloqasi uzildi. Qayta urinib ko‘ring.':
          'Соединение прервано. Попробуйте ещё раз.',
      'Serverda tekshirilmoqda...': 'Проверка на сервере...',
      'Tavsif (ixtiyoriy)': 'Описание (необязательно)',
      'Video H.264 kodekida bo‘lishi kerak. Videoni H.264 MP4 qilib eksport qiling.':
          'Видео должно быть в кодеке H.264. Экспортируйте его как H.264 MP4.',
      'Video fayli bo‘sh.': 'Файл видео пустой.',
      'Video hajmi 2 GB dan oshmasligi kerak.':
          'Размер видео не должен превышать 2 ГБ.',
      'Video ombori vaqtincha ishlamayapti.':
          'Хранилище видео временно недоступно.',
      'Video tekshirilmoqda...': 'Проверка видео...',
      'Video to‘liq yuklanmadi. Qayta urinib ko‘ring.':
          'Видео загрузилось не полностью. Попробуйте ещё раз.',
      'Video yuklandi': 'Видео загружено',
      'Video yuklash': 'Загрузить видео',
      'Video yuklash faqat adminlar uchun.':
          'Загружать видео могут только администраторы.',
      'Video yuklash uchun qayta kiring.':
          'Войдите снова, чтобы загрузить видео.',
      'Videoni ochib bo‘lmadi': 'Не удалось открыть видео',
      'Videoni tanlab bo‘lmadi.': 'Не удалось выбрать видео.',
      'Videoni tanlash': 'Выбрать видео',
      'Videoni yuklab bo‘lmadi. Qayta urinib ko‘ring.':
          'Не удалось загрузить видео. Попробуйте ещё раз.',
      'Yuklanmoqda...': 'Загрузка...',
      'Yuklash': 'Загрузить',
      'Yuklash bekor qilindi.': 'Загрузка отменена.',
      'Yuklash muddati tugadi. Qaytadan boshlang.':
          'Время загрузки истекло. Начните заново.',
      'Ayollar organizmiga mos ovqatlanish tavsiyalari.':
          'Рекомендации по питанию с учётом женского организма.',
      'Ayollar uchun fitnes zalda mashqlar':
          'Упражнения в фитнес-зале для женщин',
      'Ayollar uchun mashqlar': 'Упражнения для женщин',
      'Ayollar uchun to‘g‘ri ovqatlanish': 'Правильное питание для женщин',
      'Ayollar uchun trenajyor zalidagi mashg‘ulotlar.':
          'Тренировки на тренажёрах для женщин.',
      'Bo‘limlar': 'Разделы',
      'Butun tana mushaklarini bitta mashg‘ulotda ishlatish.':
          'Все группы мышц за одну тренировку.',
      'Dietada taomni mazali pishirish': 'Вкусная готовка на диете',
      'DropSet mashqlar': 'Упражнения DropSet',
      'FullBody mashqlar': 'Упражнения FullBody',
      'Haftada 3 kunlik trenirovka': 'Тренировки 3 дня в неделю',
      'Haftada 4 kunlik trenirovka': 'Тренировки 4 дня в неделю',
      'Haftada 5 kunlik trenirovka': 'Тренировки 5 дней в неделю',
      'Haftasiga 3 kun shug‘ullanish dasturi.':
          'Программа на 3 тренировки в неделю.',
      'Haftasiga 4 kun shug‘ullanish dasturi.':
          'Программа на 4 тренировки в неделю.',
      'Haftasiga 5 kun shug‘ullanish dasturi.':
          'Программа на 5 тренировок в неделю.',
      'Ikki mashqni dam olmasdan ketma-ket bajarish.':
          'Два упражнения подряд без отдыха.',
      'Og‘irlikni kamaytirib, yondashuvni davom ettirish.':
          'Снижайте вес и продолжайте подход.',
      'Orqaga': 'Назад',
      'Ozish uchun kardio mashqlar': 'Кардио для похудения',
      'Parhez taomlarini mazali tayyorlash usullari.':
          'Как вкусно готовить диетические блюда.',
      'Sport ozuqalari: qaysi biri, qachon va qancha.':
          'Спортивное питание: что, когда и сколько.',
      'SportPitlar': 'Спортпит',
      'SuperSet mashqlar': 'Упражнения SuperSet',
      'To‘g‘ri ovqatlanish | Ozish va Semirish':
          'Правильное питание | Похудение и набор веса',
      'Uyda va zalda bajariladigan mashqlar.': 'Упражнения для дома и зала.',
      'Vazn yo‘qotish va vazn olish uchun to‘g‘ri ovqatlanish.':
          'Правильное питание для похудения и набора веса.',
      'Videolar': 'Видео',
      'Videolar tez orada': 'Видео скоро появятся',
      'Videolar tez orada yuklanadi': 'Видео скоро будут загружены',
      'Yog‘ yoqish uchun kardio mashg‘ulotlari.':
          'Кардиотренировки для сжигания жира.',
      'Yuklangan videolar shu yerda tartib bilan chiqadi.':
          'Загруженные видео появятся здесь по порядку.',
      '{n} / {total} qadam': 'Шаг {n} из {total}',
      '{n} ta video': '{n} видео',
      'Asosiy harakatlarni to‘g‘ri bajarish texnikasi.':
          'Техника правильного выполнения базовых движений.',
      'Asosiy texnika': 'Базовая техника',
      'Cho‘zilish va tiklanish': 'Растяжка и восстановление',
      'Darslar': 'Уроки',
      'Darslarni haftaga taqsimlash bo‘yicha tavsiyalar.':
          'Рекомендации по распределению уроков на неделю.',
      'Faollik darajasi': 'Уровень активности',
      'Firebase Storage limiti tugagan.': 'Лимит Firebase Storage исчерпан.',
      'Firebase Storage yoqilmagan (Blaze rejasi kerak).':
          'Firebase Storage не включён (нужен тариф Blaze).',
      'Haftalik reja': 'Недельный план',
      'Har bir mashg‘ulotdan oldin bajariladigan isinish majmuasi.':
          'Комплекс разминки перед каждой тренировкой.',
      'Internet aloqasi yo‘q. Qayta urinib ko‘ring.':
          'Нет интернета. Попробуйте ещё раз.',
      'Kamera yoki galereyaga ruxsat berilmagan. Telefon sozlamalaridan ruxsat bering.':
          'Нет доступа к камере или галерее. Разрешите его в настройках телефона.',
      'Kardio va chidamlilik': 'Кардио и выносливость',
      'Keyingi': 'Следующий',
      'Kirish va xavfsizlik': 'Введение и безопасность',
      'Ko‘krak, yelka, qo‘l va orqa mushaklari uchun mashqlar.':
          'Упражнения для груди, плеч, рук и спины.',
      'Kurs tuzilishi, jihozlar va jarohatdan saqlanish qoidalari.':
          'Структура курса, инвентарь и правила профилактики травм.',
      'Maqsadingiz': 'Ваша цель',
      'Mashg‘ulotdan keyingi cho‘zilish va dam olish.':
          'Растяжка и отдых после тренировки.',
      'Murabbiy': 'Тренер',
      'Murabbiy bilan video darslar': 'Видеоуроки с тренером',
      'Murabbiy video kursi': 'Видеокурс тренера',
      'Murabbiy tomonidan tayyorlangan mashg‘ulotlar ketma-ketligi. Har bir darsni tartib bilan o‘ting.':
          'Последовательность тренировок от тренера. Проходите уроки по порядку.',
      'Oldingi': 'Предыдущий',
      'Oyoq va dumba mushaklari uchun mashqlar.':
          'Упражнения для ног и ягодиц.',
      'Pastki tana mashqlari': 'Упражнения для нижней части тела',
      'Rasm juda katta yoki noto‘g‘ri formatda.':
          'Фото слишком большое или в неверном формате.',
      'Rasm saqlashga ruxsat yo‘q: Firebase Storage qoidalari o‘rnatilmagan.':
          'Нет доступа к хранилищу: правила Firebase Storage не развернуты.',
      'Rasm yuklash uchun qayta kiring.':
          'Войдите снова, чтобы загрузить фото.',
      'Rasmni yangilab bo‘lmadi ({code}).':
          'Не удалось обновить фото ({code}).',
      'Tana o‘lchamlari': 'Параметры тела',
      'Tez orada': 'Скоро',
      'To‘g‘ri isinish': 'Правильная разминка',
      'Videolar tez orada yuklanadi. Darslar tartibi quyida.':
          'Видео скоро появятся. Порядок уроков ниже.',
      'Yuqori tana mashqlari': 'Упражнения для верхней части тела',
      'Yurak-qon tomir tizimini mustahkamlovchi mashg‘ulot.':
          'Тренировка для сердечно-сосудистой системы.',
      'daq': 'мин',
      'dars': 'уроков',
      'video yuklangan': 'видео загружено',
      '{n}-dars': 'Урок {n}',
      'Video hali yuklanmagan': 'Видео ещё не загружено',
      'Video tez orada ijro etiladi': 'Воспроизведение скоро появится',
      'Asosan o‘tirib ishlayman, mashq kam':
          'В основном сижу, тренируюсь редко',
      'Haftasiga 2–4 marta mashq qilaman': 'Тренируюсь 2–4 раза в неделю',
      'Deyarli har kuni faol harakatdaman': 'Активен почти каждый день',
      'SMS xizmati yoqilmagan: Firebase loyihasiga billing ulanmagan.':
          'SMS не включены: к проекту Firebase не подключён биллинг.',
      'Bugungi SMS limiti tugadi. Keyinroq urinib ko‘ring.':
          'Лимит SMS на сегодня исчерпан. Попробуйте позже.',
      'Telefon orqali kirish Firebase’da yoqilmagan yoki bu davlatga SMS ruxsat etilmagan.':
          'Вход по телефону не включён в Firebase или SMS в эту страну запрещены.',
      'Ilova Firebase’da tasdiqlanmagan (SHA kalitlari yoki APNs sozlanmagan).':
          'Приложение не подтверждено в Firebase (не настроены SHA или APNs).',
      'Ovqat yaratish': 'Создать блюдо',
      'Masalliq qo‘shish': 'Добавить ингредиент',
      'Masalliqlar': 'Ингредиенты',
      'Ovqat nomi': 'Название блюда',
      'Masalan: Sho‘rva': 'Например: Шурпа',
      'Ovqat nomini yozing va unga ketgan masalliqlarni miqdori bilan qo‘shing.':
          'Введите название блюда и добавьте ингредиенты с их количеством.',
      'Kamida bitta masalliq qo‘shing.': 'Добавьте хотя бы один ингредиент.',
      'Tayyor ovqat vazni (ixtiyoriy)': 'Вес готового блюда (необязательно)',
      'Bo‘sh qolsa, masalliqlar yig‘indisi olinadi. Qaynatishda suv bug‘lansa, tortib kiriting.':
          'Если пусто, берётся сумма ингредиентов. Если вода выкипела, взвесьте и введите.',
      '1–20000 g oralig‘ida kiriting.': 'Введите от 1 до 20000 г.',
      'Jami': 'Итого',
      '“{name}” yaratildi. Uni qidiruvdan topasiz.':
          '«{name}» создано. Его можно найти в поиске.',
      'Ovqatni saqlab bo‘lmadi.': 'Не удалось сохранить блюдо.',
      'Ovqat saqlanmadi': 'Блюдо не сохранено',
      'Kiritilgan ma’lumotlar o‘chadi. Chiqasizmi?':
          'Введённые данные будут потеряны. Выйти?',
      'Qoldi': 'Осталось',
      'Chiqib ketish': 'Выйти',
      'Ro‘yxatni ochish': 'Показать список',
      'Ro‘yxatni yopish': 'Скрыть список',
      'Internet bazasi': 'Онлайн-база',
      'Taom nomini yozib qidiring': 'Введите название блюда',
      'Masalan: osh, manti, somsa yoki Samarqand':
          'Например: плов, манты, самса или Самарканд',
    },
    'en': {
      'Sizga mos sog‘lom hayot.': 'Healthy living at your pace.',
      'Profil rasmi': 'Profile photo',
      'Profil rasmini o‘zgartirish': 'Change profile photo',
      'Kamerada suratga olish': 'Take a photo',
      'Rasmni olib tashlash': 'Remove photo',
      'Rasm qo‘shish': 'Add photo',
      'Rasmni o‘zgartirish': 'Change photo',
      'Rasm yuklanmoqda…': 'Uploading photo…',
      'Profil rasmi yangilandi.': 'Profile photo updated.',
      'Profil rasmi olib tashlandi.': 'Profile photo removed.',
      'Rasmni yangilab bo‘lmadi. Ruxsat va internetni tekshirib, qayta urinib ko‘ring.':
          'Could not update the photo. Check permissions and your internet connection, then try again.',
      'Sozlamalar': 'Settings',
      'Hisobotlar': 'Reports',
      'Ovqatlanishingiz raqamlarda': 'Your nutrition in numbers',
      'Kunlik': 'Day',
      'Haftalik': 'Week',
      'Oylik': 'Month',
      'Oldingi davr': 'Previous period',
      'Keyingi davr': 'Next period',
      'Hisobotni yuklab bo‘lmadi.': 'Could not load the report.',
      'Jami kaloriya': 'Total calories',
      'Kunlik o‘rtacha': 'Daily average',
      'Yozuvli kunlar': 'Days logged',
      'O‘rtacha bugungacha bo‘lgan barcha kunlar bo‘yicha.':
          'Average across all days in the period through today.',
      'Bu davrda ovqat yozuvlari yo‘q.': 'No food entries in this period.',
      'Kundalikka ovqat qo‘shing — hisoblar shu yerda ko‘rinadi.':
          'Add food to your diary to see your totals here.',
      'Kaloriya dinamikasi': 'Calorie trend',
      'Kunlik maqsad': 'Daily target',
      'Kunni bosib, ovqatlarni ko‘ring. Chiziq — joriy kunlik maqsad.':
          'Tap a day to see its food. The line is your current daily target.',
      'Makronutrientlar': 'Macronutrients',
      'Yog‘lar': 'Fat',
      'Ulushlar oqsil va uglevod uchun 4, yog‘ uchun 9 kcal/g asosida.':
          'Shares use 4 kcal/g for protein and carbs, and 9 kcal/g for fat.',
      'Ovqatlanish taqsimoti': 'Meal breakdown',
      'Iste’mol qilingan mahsulotlar': 'Foods consumed',
      'ta yozuv': 'entries',
      'Hisoblar saqlangan porsiyalarga asoslangan. Yozuvsiz kun iste’mol qilinmaganini anglatmaydi. Maqsad joriy profilingizdan olinadi.':
          'Totals use saved portions. An unlogged day does not mean no food was consumed. The target uses your current profile.',
      'Ayrim oziq qiymatlari yetishmaydi. ≥ — ma’lum qiymatlar yig‘indisi; ulushlar to‘liq emas.':
          'Some nutrient data is missing. ≥ means the sum of known values; shares are incomplete.',
      'Kelajak kun': 'Future day',
      'Yozuv yo‘q': 'No entries',
      "Yana ko‘rsatish": "Show more",
      "Oziq qiymati 100 {unit} uchun": "Nutrition per 100 {unit}",
      "1–5000 {unit} oralig‘ida miqdor kiriting.":
          "Enter an amount between 1 and 5000 {unit}.",
      "Mahsulot bazalarda topilmadi.": "Product not found in the databases.",
      "Qiymatlar mahsulotda ko‘rsatilgan 100 g yoki 100 ml uchun.":
          "Values are per 100 g or 100 ml as shown for each product.",
      'Kundalikni yuklab bo‘lmadi.': 'Could not load your diary.',
      'Qayta urinish': 'Retry',
      'Saqlash amalga oshmadi. Qayta urinib ko‘ring.':
          'Could not save. Please try again.',
      'Kalendar': 'Calendar',
      'Ovqatlanish tarixi': 'Food diary history',
      'Oldingi kun': 'Previous day',
      'Keyingi kun': 'Next day',
      'Tarixni yuklab bo‘lmadi.': 'Could not load history.',
      'Bu kunda ovqat saqlanmagan.': 'No food logged for this day.',
      'Oxirgi qidiruvlar': 'Recent searches',
      'Tozalash': 'Clear',
      'Tarixdan o‘chirish': 'Remove from history',
      'Qidiruvlaringiz shu yerda saqlanadi.': 'Your searches will appear here.',
      'Qidiruv tarixini saqlash yoki yuklashda xatolik.':
          'Could not save or load search history.',
      'Manba': 'Source',
      'Mahalliy katalog — taxminiy qiymatlar':
          'Local catalog — estimated values',
      'Asosiy oziq qiymatlari to‘liq emas. Boshqa yozuvni tanlang.':
          'Core nutrition data is incomplete. Choose another entry.',
      'O‘rtacha dona': 'medium piece',
      'Oziq qiymati': 'Nutrition facts',
      'Porsiya': 'Serving',
      'Porsiyada': 'per serving',
      'Energiya qiymati': 'Energy',
      'To‘yingan yog‘lar': 'Saturated fat',
      'Bir to‘yinmagan yog‘lar': 'Monounsaturated fat',
      'Ko‘p to‘yinmagan yog‘lar': 'Polyunsaturated fat',
      '— ma’lumot mavjud emas': '— data unavailable',
      'Shakar': 'Sugars',
      'Katta dona': 'Large piece',
      'Kichik dona': 'Small piece',
      'O‘lchov birligi': 'Unit',
      'Dona vazni taxminiy, yeyiladigan qism uchun.':
          'Approximate edible weight per piece.',
      'Ilova ko\u2018rinishi': 'Appearance',
      'Oq rejim': 'Light',
      'Qora rejim': 'Dark',
      'Rejimni saqlab bo\u2018lmadi. Qayta urinib ko\u2018ring.':
          'Could not save the theme. Please try again.',
      'Dona': 'Pieces',
      'Gramm': 'Grams',
      'dona': 'pcs',
      '1 dona ≈ {grams} g (katta tuxum)': '1 piece ≈ {grams} g (large egg)',
      'Profil': 'Profile',
      'Vazn': 'Weight',
      'Bo‘y': 'Height',
      'Shaxsiy reja': 'Personal plan',
      'Maqsad': 'Goal',
      'Faollik': 'Activity',
      'Shaxsiy ma’lumotlar': 'Personal information',
      'Yosh': 'Age',
      'Jins': 'Gender',
      'Telefon': 'Phone',
      'Kiritilmagan': 'Not provided',
      'Erkak': 'Male',
      'Ayol': 'Female',
      'Vazn tashlash': 'Lose weight',
      'Vazn orttirish': 'Gain weight',
      'Vaznni saqlash': 'Maintain weight',
      'Past faollik': 'Low activity',
      'O‘rtacha faollik': 'Moderate activity',
      'Yuqori faollik': 'High activity',
      'Profilni tahrirlash': 'Edit profile',
      'Akkauntdan chiqish': 'Sign out',
      'Til': 'Language',
      'Ilova tili': 'App language',
      'O‘zbekcha': 'Uzbek',
      'Ruscha': 'Russian',
      'Inglizcha': 'English',
      'Saqlash': 'Save',
      'Bekor qilish': 'Cancel',
      'Profil muvaffaqiyatli yangilandi': 'Profile updated successfully',
      'Profilni saqlab bo‘lmadi. Qayta urinib ko‘ring.':
          'Could not save the profile. Please try again.',
      'Kameradan olish': 'Take a photo',
      'Galereyadan tanlash': 'Choose from gallery',
      'Bosh sahifa': 'Home',
      'Ovqatlar': 'Meals',
      'Mashqlar': 'Workouts',
      'Xayrli tong,': 'Good morning,',
      'Xayrli kun,': 'Good afternoon,',
      'Xayrli kech,': 'Good evening,',
      'Tezkor amallar': 'Quick actions',
      'Ovqatni skanerlash': 'Scan food',
      'Shtrix-kod skaneri': 'Barcode scanner',
      'Ovqat qidirish': 'Search food',
      'Kalkulyator': 'Calculators',
      'Mashq qo‘shish': 'Add workout',
      'Bugun qo‘shilgan ovqatlar': 'Foods added today',
      'Hali ovqat qo‘shilmagan. Yuqoridan qidiring.':
          'No food added yet. Use the search above.',
      'Ovqatlanish': 'Nutrition',
      'Sog‘lom kuningiz shu yerdan boshlanadi': 'Your healthy day starts here',
      'Bugungi menyu': 'Today’s menu',
      'Nonushta': 'Breakfast',
      'Tushlik (Abed)': 'Lunch',
      'Kechki ovqat': 'Dinner',
      'Perekus': 'Snack',
      'Kechki tamaddi': 'Evening snack',
      'mahsulot': 'items',
      'Ovqat qo‘shish': 'Add food',
      'Kaloriya': 'Calories',
      'Tarkibi': 'Ingredients',
      'Natriy': 'Sodium',
      'Kaliy': 'Potassium',
      'Temir': 'Iron',
      'Kalsiy': 'Calcium',
      'Xolesterin': 'Cholesterol',
      'Fosfor': 'Phosphorus',
      'Magniy': 'Magnesium',
      'Vitamin E': 'Vitamin E',
      'Rux': 'Zinc',
      'Vitamin D': 'Vitamin D',
      'Vitamin K2': 'Vitamin K2',
      'Oqsil': 'Protein',
      'Uglevod': 'Carbohydrates',
      'Yog‘': 'Fat',
      'Kletchatka': 'Fiber',
      'Suv': 'Water',
      'Mahsulot aniqlandi': 'Product found',
      'Mahsulot qidirilmoqda...': 'Searching for product...',
      'Shtrix-kodni ramka ichiga joylashtiring':
          'Place the barcode inside the frame',
      'Kod avtomatik aniqlanadi': 'The code is detected automatically',
      'Qayta skanerlash': 'Scan again',
      'Mahsulot og‘irligi': 'Product weight',
      'Ma’lumot yo‘q': 'No data',
      'Hisoblash va qo‘shish': 'Calculate and add',
      'Kamida 2 ta belgi yozing.': 'Enter at least 2 characters.',
      'Qo‘shish': 'Add',
      'Miqdori': 'Amount',
      'Fitness kalkulyatorlari': 'Fitness calculators',
      'Kunlik kaloriya va BMR': 'Daily calories and BMR',
      'Tana yog‘i foizi': 'Body fat percentage',
      'Kunlik suv ehtiyoji': 'Daily water needs',
      'TANA DINAMIKASI': 'BODY PROGRESS',
      'Bugungi holatingiz': 'Your status today',
      'Ma’lumot kutilmoqda': 'Waiting for data',
      'Yengil tana': 'Underweight',
      'Muvozanatli': 'Balanced',
      'Kuchli tana': 'Overweight',
      'Yuqori vazn': 'High weight',
      'HAFTALIK MAQSAD': 'WEEKLY GOAL',
      'Bugun {calories} kcal': 'Today {calories} kcal',
      '5 mahal': '5 meals',
      'Kun davomida': 'Throughout the day',
      'Kunni foydali va quvvatli boshlang':
          'Start your day healthy and energized',
      'To‘yimli va muvozanatli asosiy ovqat':
          'A filling and balanced main meal',
      'Yengil va oqsilga boy kechki ratsion': 'A light, protein-rich dinner',
      'Ovqatlar orasidagi foydali tamaddi': 'A healthy snack between meals',
      'Uyqu oldidan yengil va foydali tamaddi':
          'A light, healthy snack before sleep',
      'Maqsadingiz uchun kerakli hisob-kitobni tanlang.':
          'Choose the calculation that matches your goal.',
      'Vazn saqlash, tashlash yoki olish uchun kaloriya miqdori.':
          'Calories for maintaining, losing, or gaining weight.',
      'Bo‘yin, qorin/bel va son o‘lchovlari orqali yog‘ foizini hisoblash.':
          'Calculate body fat from neck, waist/abdomen, and hip measurements.',
      'Vazn, mashq davomiyligi va ob-havoga qarab suv miqdori.':
          'Water needs based on weight, exercise, and weather.',
      'Kunlik suv miqdori': 'Daily water intake',
      'Vazn, mashq davomiyligi va ob-havoga qarab kunlik ehtiyojingizni hisoblang.':
          'Calculate your daily needs based on weight, exercise, and weather.',
      'Kunlik mashq': 'Daily exercise',
      'daqiqa': 'minutes',
      'Issiq ob-havo yoki ko‘p terlash': 'Hot weather or heavy sweating',
      'Hisoblash': 'Calculate',
      'Kunlik tavsiya': 'Daily recommendation',
      'litr': 'L',
      'Vazn yoki mashq davomiyligini to‘g‘ri kiriting.':
          'Enter a valid weight and exercise duration.',
      'Tana yog‘i kalkulyatori': 'Body fat calculator',
      'U.S. Navy va BMI usullarida tana yog‘ini hisoblash.':
          'Calculate body fat using U.S. Navy and BMI methods.',
      'O‘lchov birligi: kilogramm va santimetr':
          'Units: kilograms and centimeters',
      'yil': 'years',
      'Bo‘yin': 'Neck',
      'Qorin': 'Abdomen',
      'Bel': 'Waist',
      'Son aylanasi': 'Hip circumference',
      'Erkak: qorinni kindik atrofidan o‘lchang. Ayol: belning eng ingichka va sonning eng keng joyini o‘lchang.':
          'Men: measure the abdomen at the navel. Women: measure the narrowest waist and widest hips.',
      'Kunlik kaloriya': 'Daily calories',
      'Calculator.net bilan bir xil BMR formulalari va faollik koeffitsiyentlari.':
          'The same BMR formulas and activity factors as Calculator.net.',
      'BMR — dam olish holati': 'BMR — resting state',
      'Kamharakat: mashqsiz yoki juda kam': 'Sedentary: little or no exercise',
      'Yengil: haftasiga 1–3 marta': 'Light: 1–3 times per week',
      'O‘rtacha: haftasiga 4–5 marta': 'Moderate: 4–5 times per week',
      'Faol: har kuni yoki haftasiga 3–4 intensiv':
          'Active: daily or 3–4 intense sessions',
      'Juda faol: haftasiga 6–7 intensiv': 'Very active: 6–7 intense sessions',
      'O‘ta faol: har kuni juda intensiv/jismoniy ish':
          'Extra active: very intense daily exercise/physical work',
      'BMR formulasi': 'BMR formula',
      'Tana yog‘i': 'Body fat',
      'BAZAL METABOLIZM': 'BASAL METABOLISM',
      'Dam olish energiyasi': 'Resting energy',
      'Tanangiz to‘liq dam olganda hayotiy funksiyalar uchun sarflaydigan energiya.':
          'Energy your body uses at complete rest for vital functions.',
      'Yengil vazn tashlash': 'Mild weight loss',
      'Tez vazn tashlash': 'Fast weight loss',
      'Yengil vazn olish': 'Mild weight gain',
      'Vazn olish': 'Weight gain',
      'Tez vazn olish': 'Fast weight gain',
      'Vazn olish rejalarini yopish': 'Hide weight-gain plans',
      'Vazn olish rejalarini ko‘rish': 'View weight-gain plans',
      'Vazn tashlash natijalariga qayting': 'Return to weight-loss results',
      'Kaloriya maqsadlarini oching': 'Open calorie targets',
      'hafta': 'week',
      'Chiqish': 'Sign out',
      '{food} qo‘shildi': '{food} added',
      'Ovqat muvaffaqiyatli qo‘shildi': 'Food added successfully',
      'Olib tashlash': 'Remove',
      'Bu bo‘lim tez orada qo‘shiladi.': 'This section is coming soon.',
      'Ism': 'First name',
      'Familiya': 'Last name',
      'Maydonni to‘ldiring': 'Complete this field',
      '{min}–{max} oralig‘ida kiriting': 'Enter a value from {min} to {max}',
      'Rasm yuklash bekor qilindi.': 'Image upload was canceled.',
      'Rasmni yuklab bo‘lmadi. Internetni tekshiring.':
          'Could not upload the image. Check your connection.',
      'Telefon raqamingiz bilan kiring': 'Sign in with your phone number',
      'Telefon raqam': 'Phone number',
      'To‘liq raqam kiriting (9 ta raqam)': 'Enter the full number (9 digits)',
      'SMS kod olish': 'Get SMS code',
      'Raqamingizga 6 xonali SMS kod yuboriladi':
          'We will send a 6-digit SMS code',
      'SMS kod': 'SMS code',
      '{phone} raqamiga yuborilgan\n6 xonali SMS kodni kiriting':
          'Enter the 6-digit SMS code\nsent to {phone}',
      '6 xonali SMS kodni kiriting': 'Enter the 6-digit SMS code',
      'Tasdiqlash': 'Verify',
      'Yuborilmoqda...': 'Sending...',
      'Qayta yuborish ({seconds} s)': 'Resend in {seconds}s',
      'SMS kodni qayta yuborish': 'Resend SMS code',
      'SMS kod yuborildi': 'SMS code sent',
      'SMS kod yuborilmoqda...': 'Sending SMS code...',
      'SMS kod yuborildi. Xabarlarni tekshiring.':
          'SMS code sent. Check your messages.',
      'Avval SMS kodni oling.': 'Get the SMS code first.',
      'SMS kod noto‘g‘ri.': 'Incorrect SMS code.',
      'SMS kod muddati tugadi. Qayta yuboring.':
          'The SMS code has expired. Send it again.',
      'Telefon raqam noto‘g‘ri.': 'Invalid phone number.',
      'Juda ko‘p urinish. Keyinroq qayta urinib ko‘ring.':
          'Too many attempts. Try again later.',
      'Internet aloqasi yo‘q.': 'No internet connection.',
      'O‘zingiz haqingizda ayting.': 'Tell us about yourself',
      'Shunda MyFit sizga mos shaxsiy reja tuza oladi.':
          'MyFit will create a personalized plan for you.',
      'Bo‘y, sm': 'Height, cm',
      'Vazn, kg': 'Weight, kg',
      'FAOLLIK DARAJASI': 'ACTIVITY LEVEL',
      'O‘rtacha': 'Moderate',
      'Past': 'Low',
      'Yuqori': 'High',
      'SIZNING MAQSADINGIZ': 'YOUR GOAL',
      'Vazn kamaytirish': 'Lose weight',
      'Vazn oshirish': 'Gain weight',
      'Vazn saqlash': 'Maintain weight',
      'Davom etish': 'Continue',
      'Majburiy': 'Required',
      'Kamida 2 harf': 'At least 2 letters',
      'Kiriting': 'Enter a value',
      '1 dan 5000 grammgacha miqdor kiriting.':
          'Enter an amount from 1 to 5000 grams.',
      'AI ovqatni aniqlamoqda...': 'AI is identifying the food...',
      'AI ovqat skaneri': 'AI food scanner',
      'Mahsulot tarkibini bir zumda biling':
          'Discover food nutrition in seconds',
      'Ovqatni ramka ichiga joylashtiring': 'Place the food inside the frame',
      'Tahlilga tayyor': 'Ready to analyze',
      'Suratga olish': 'Take a photo',
      'Galereya': 'Gallery',
      'Qayta olish': 'Retake',
      'AI aniqlandi': 'Identified by AI',
      'Og‘irlik (g)': 'Weight (g)',
      'Bu mahsulot Open Food Facts bazasida topilmadi.':
          'This product was not found in Open Food Facts.',
      'Open Food Facts ma’lumoti': 'Open Food Facts data',
      'Shtrix-kod: {barcode}': 'Barcode: {barcode}',
      'Masalan: osh, somsa, tovuq, olma...':
          'For example: pilaf, samosa, chicken, apple...',
      'Ovqat topilmadi. Boshqa nom bilan yozing (masalan: tovuq, olma, guruch, non).':
          'Food not found. Try another name (for example: chicken, apple, rice, bread).',
      'Qiymatlar 100 gramm uchun. Kerakli ovqatni tanlab, miqdorini kiriting.':
          'Values are per 100 g. Select a food and enter the amount.',
      'gramm': 'grams',
      'Profilni yuklashda xatolik:\n{error}': 'Error loading profile:\n{error}',
      'Profil rasmini tanlang': 'Choose a profile photo',
      'Firebase Storage hali ishga tushirilmagan.':
          'Firebase Storage has not been set up yet.',
      'Profil rasmini yuklash uchun ruxsat berilmagan.':
          'Permission to upload a profile photo was denied.',
      'Rasmni yuklab bo‘lmadi ({code}).':
          'Could not upload the image ({code}).',
      '{meal} uchun 3 ta variant keyingi bosqichda qo‘shiladi.':
          'Three options for {meal} will be added in the next stage.',
      'Mashqlar bo‘limi tez orada.': 'The workouts section is coming soon.',
      'MyFit foydalanuvchisi': 'MyFit user',
      'Yosh 15–80 oralig‘ida bo‘lishi kerak.': 'Age must be between 15 and 80.',
      'Yosh 18–80 oralig‘ida bo‘lishi kerak.': 'Age must be between 18 and 80.',
      'Bo‘y 100–250 cm oralig‘ida bo‘lishi kerak.':
          'Height must be between 100 and 250 cm.',
      'Vazn 30–350 kg oralig‘ida bo‘lishi kerak.':
          'Weight must be between 30 and 350 kg.',
      'Faollik darajasi noto‘g‘ri.': 'Invalid activity level.',
      'Katch–McArdle uchun tana yog‘ini 2–70% kiriting.':
          'For Katch–McArdle, enter body fat from 2 to 70%.',
      'Bo‘yin yoki bel/qorin o‘lchovini tekshiring.':
          'Check the neck and waist/abdomen measurements.',
      'Qorin o‘lchovi bo‘yin o‘lchovidan katta bo‘lishi kerak.':
          'Abdomen circumference must be greater than neck circumference.',
      'Ayollar uchun son o‘lchovini kiriting.':
          'Enter hip circumference for women.',
      'O‘lchovlardan haqiqiy natija olinmadi. Qayta o‘lchang.':
          'The measurements did not produce a valid result. Measure again.',
      'Ovqat turi aniq topilmadi. Boshqa burchakdan qayta suratga oling.':
          'The food could not be identified. Take another photo from a different angle.',
      'Taom ko‘rindi, ammo unga mos oziq qiymati topilmadi.':
          'Food was detected, but matching nutrition data was not found.',
      'Internetga ulanishda xatolik. Qayta urinib ko‘ring.':
          'Internet connection error. Please try again.',
      'API kaliti noto‘g‘ri. USDA kalitini tekshiring.':
          'Invalid API key. Check your USDA key.',
      'kg': 'kg',
      'cm': 'cm',
      'g': 'g',
      'ml': 'mL',
      'kcal': 'kcal',
      'BMI': 'BMI',
      'Xatolik: {error}': 'Error: {error}',
      'Xatolik ({code}).': 'Error ({code}).',
      'Saqlashda xatolik: {error}': 'Save error: {error}',
      'Hudud': 'Region',
      'Ovqatga qo‘shish': 'Add to meal',
      'Milliy taomni qidiring': 'Search national dishes',
      'Taom yoki mahsulotni qidiring': 'Search dishes or products',
      'Masalan: pomidor, tuxum, osh yoki manti':
          'For example: tomato, egg, pilaf, or manti',
      'Mahsulot topilmadi': 'No products found',
      'Boshqa nom bilan qayta qidiring': 'Try another search term',
      'Oziq qiymati 100 g uchun': 'Nutrition per 100 g',
      'Mahsulotlarni yuklab bo‘lmadi. Qayta urinib ko‘ring.':
          'Could not load products. Please try again.',
      'O‘zbek milliy taomlari': 'Uzbek national dishes',
      'Taom topilmadi': 'No dishes found',
      'Qidiruv natijalari': 'Search results',
      'Saqlanganlar': 'Saved items',
      '{name} saqlandi': '{name} saved',
      '{count} ta mahsulot': '{count} items',
      'Tanlanganlar qo‘shilmadi': 'Items not added',
      'Saqlangan {count} ta mahsulot menyuga qo‘shilmaydi. Chiqasizmi?':
          '{count} saved items will not be added to the meal. Leave?',
      'Qolish': 'Stay',
      'Server vaqtincha ishlamayapti. Keyinroq urinib ko‘ring.':
          'The server is temporarily unavailable. Please try again later.',
      'Video xizmati hali sozlanmagan.':
          'The video service is not configured yet.',
      'Dars nomi': 'Lesson title',
      'Dars nomini kiriting (2–120 belgi).':
          'Enter a lesson title (2–120 characters).',
      'Darslarni yuklab bo‘lmadi. Internetni tekshiring.':
          'Could not load lessons. Check your internet connection.',
      'Faqat MP4 (H.264), 2 GB gacha.': 'MP4 (H.264) only, up to 2 GB.',
      'Faqat MP4 formatidagi videolar qabul qilinadi.':
          'Only MP4 videos are accepted.',
      'Galereyadan MP4 video': 'MP4 video from the gallery',
      'Internet aloqasi uzildi. Qayta urinib ko‘ring.':
          'The connection was lost. Please try again.',
      'Serverda tekshirilmoqda...': 'Verifying on the server...',
      'Tavsif (ixtiyoriy)': 'Description (optional)',
      'Video H.264 kodekida bo‘lishi kerak. Videoni H.264 MP4 qilib eksport qiling.':
          'The video must use the H.264 codec. Export it as an H.264 MP4.',
      'Video fayli bo‘sh.': 'The video file is empty.',
      'Video hajmi 2 GB dan oshmasligi kerak.':
          'The video must not exceed 2 GB.',
      'Video ombori vaqtincha ishlamayapti.':
          'Video storage is temporarily unavailable.',
      'Video tekshirilmoqda...': 'Checking the video...',
      'Video to‘liq yuklanmadi. Qayta urinib ko‘ring.':
          'The video did not upload completely. Please try again.',
      'Video yuklandi': 'Video uploaded',
      'Video yuklash': 'Upload video',
      'Video yuklash faqat adminlar uchun.': 'Only admins can upload videos.',
      'Video yuklash uchun qayta kiring.': 'Sign in again to upload a video.',
      'Videoni ochib bo‘lmadi': 'Could not open the video',
      'Videoni tanlab bo‘lmadi.': 'Could not pick the video.',
      'Videoni tanlash': 'Choose a video',
      'Videoni yuklab bo‘lmadi. Qayta urinib ko‘ring.':
          'Could not upload the video. Please try again.',
      'Yuklanmoqda...': 'Uploading...',
      'Yuklash': 'Upload',
      'Yuklash bekor qilindi.': 'Upload cancelled.',
      'Yuklash muddati tugadi. Qaytadan boshlang.':
          'The upload session expired. Start again.',
      'Ayollar organizmiga mos ovqatlanish tavsiyalari.':
          'Nutrition advice suited to the female body.',
      'Ayollar uchun fitnes zalda mashqlar': 'Gym workouts for women',
      'Ayollar uchun mashqlar': 'Workouts for women',
      'Ayollar uchun to‘g‘ri ovqatlanish': 'Healthy eating for women',
      'Ayollar uchun trenajyor zalidagi mashg‘ulotlar.':
          'Machine-based gym sessions for women.',
      'Bo‘limlar': 'Categories',
      'Butun tana mushaklarini bitta mashg‘ulotda ishlatish.':
          'Work every muscle group in one session.',
      'Dietada taomni mazali pishirish': 'Tasty cooking on a diet',
      'DropSet mashqlar': 'DropSet workouts',
      'FullBody mashqlar': 'FullBody workouts',
      'Haftada 3 kunlik trenirovka': '3-day weekly training',
      'Haftada 4 kunlik trenirovka': '4-day weekly training',
      'Haftada 5 kunlik trenirovka': '5-day weekly training',
      'Haftasiga 3 kun shug‘ullanish dasturi.':
          'A program with 3 sessions a week.',
      'Haftasiga 4 kun shug‘ullanish dasturi.':
          'A program with 4 sessions a week.',
      'Haftasiga 5 kun shug‘ullanish dasturi.':
          'A program with 5 sessions a week.',
      'Ikki mashqni dam olmasdan ketma-ket bajarish.':
          'Two exercises back to back without rest.',
      'Og‘irlikni kamaytirib, yondashuvni davom ettirish.':
          'Lower the weight and keep the set going.',
      'Orqaga': 'Back',
      'Ozish uchun kardio mashqlar': 'Cardio for weight loss',
      'Parhez taomlarini mazali tayyorlash usullari.':
          'How to make diet meals taste good.',
      'Sport ozuqalari: qaysi biri, qachon va qancha.':
          'Sports supplements: which, when and how much.',
      'SportPitlar': 'Sports supplements',
      'SuperSet mashqlar': 'SuperSet workouts',
      'To‘g‘ri ovqatlanish | Ozish va Semirish':
          'Healthy eating | Weight loss and gain',
      'Uyda va zalda bajariladigan mashqlar.':
          'Exercises for home and the gym.',
      'Vazn yo‘qotish va vazn olish uchun to‘g‘ri ovqatlanish.':
          'Healthy eating to lose or gain weight.',
      'Videolar': 'Videos',
      'Videolar tez orada': 'Videos coming soon',
      'Videolar tez orada yuklanadi': 'Videos will be uploaded soon',
      'Yog‘ yoqish uchun kardio mashg‘ulotlari.':
          'Cardio sessions to burn fat.',
      'Yuklangan videolar shu yerda tartib bilan chiqadi.':
          'Uploaded videos will appear here in order.',
      '{n} / {total} qadam': 'Step {n} of {total}',
      '{n} ta video': '{n} videos',
      'Asosiy harakatlarni to‘g‘ri bajarish texnikasi.':
          'Correct technique for the basic movements.',
      'Asosiy texnika': 'Basic technique',
      'Cho‘zilish va tiklanish': 'Stretching and recovery',
      'Darslar': 'Lessons',
      'Darslarni haftaga taqsimlash bo‘yicha tavsiyalar.':
          'How to spread the lessons across the week.',
      'Faollik darajasi': 'Activity level',
      'Firebase Storage limiti tugagan.': 'Firebase Storage quota is exceeded.',
      'Firebase Storage yoqilmagan (Blaze rejasi kerak).':
          'Firebase Storage is not enabled (Blaze plan required).',
      'Haftalik reja': 'Weekly plan',
      'Har bir mashg‘ulotdan oldin bajariladigan isinish majmuasi.':
          'Warm-up routine before every session.',
      'Internet aloqasi yo‘q. Qayta urinib ko‘ring.':
          'No internet connection. Please try again.',
      'Kamera yoki galereyaga ruxsat berilmagan. Telefon sozlamalaridan ruxsat bering.':
          'Camera or photo access is denied. Allow it in phone settings.',
      'Kardio va chidamlilik': 'Cardio and endurance',
      'Keyingi': 'Next',
      'Kirish va xavfsizlik': 'Introduction and safety',
      'Ko‘krak, yelka, qo‘l va orqa mushaklari uchun mashqlar.':
          'Exercises for chest, shoulders, arms and back.',
      'Kurs tuzilishi, jihozlar va jarohatdan saqlanish qoidalari.':
          'Course structure, equipment and injury-prevention rules.',
      'Maqsadingiz': 'Your goal',
      'Mashg‘ulotdan keyingi cho‘zilish va dam olish.':
          'Stretching and rest after a session.',
      'Murabbiy': 'Trainer',
      'Murabbiy bilan video darslar': 'Video lessons with a trainer',
      'Murabbiy video kursi': 'Trainer video course',
      'Murabbiy tomonidan tayyorlangan mashg‘ulotlar ketma-ketligi. Har bir darsni tartib bilan o‘ting.':
          'A sequence of sessions prepared by the trainer. Take the lessons in order.',
      'Oldingi': 'Previous',
      'Oyoq va dumba mushaklari uchun mashqlar.':
          'Exercises for legs and glutes.',
      'Pastki tana mashqlari': 'Lower-body exercises',
      'Rasm juda katta yoki noto‘g‘ri formatda.':
          'The photo is too large or in an unsupported format.',
      'Rasm saqlashga ruxsat yo‘q: Firebase Storage qoidalari o‘rnatilmagan.':
          'No storage permission: Firebase Storage rules are not deployed.',
      'Rasm yuklash uchun qayta kiring.': 'Sign in again to upload a photo.',
      'Rasmni yangilab bo‘lmadi ({code}).':
          'Could not update the photo ({code}).',
      'Tana o‘lchamlari': 'Body measurements',
      'Tez orada': 'Soon',
      'To‘g‘ri isinish': 'Proper warm-up',
      'Videolar tez orada yuklanadi. Darslar tartibi quyida.':
          'Videos are coming soon. The lesson order is below.',
      'Yuqori tana mashqlari': 'Upper-body exercises',
      'Yurak-qon tomir tizimini mustahkamlovchi mashg‘ulot.':
          'A session that strengthens the cardiovascular system.',
      'daq': 'min',
      'dars': 'lessons',
      'video yuklangan': 'videos uploaded',
      '{n}-dars': 'Lesson {n}',
      'Video hali yuklanmagan': 'Video not uploaded yet',
      'Video tez orada ijro etiladi': 'Playback is coming soon',
      'Asosan o‘tirib ishlayman, mashq kam': 'Mostly sitting, little exercise',
      'Haftasiga 2–4 marta mashq qilaman': 'I exercise 2–4 times a week',
      'Deyarli har kuni faol harakatdaman': 'Active almost every day',
      'SMS xizmati yoqilmagan: Firebase loyihasiga billing ulanmagan.':
          'SMS is not enabled: no billing account is linked to the Firebase project.',
      'Bugungi SMS limiti tugadi. Keyinroq urinib ko‘ring.':
          'Today’s SMS limit is reached. Please try later.',
      'Telefon orqali kirish Firebase’da yoqilmagan yoki bu davlatga SMS ruxsat etilmagan.':
          'Phone sign-in is disabled in Firebase or SMS to this country is not allowed.',
      'Ilova Firebase’da tasdiqlanmagan (SHA kalitlari yoki APNs sozlanmagan).':
          'The app is not verified in Firebase (SHA keys or APNs are not set up).',
      'Ovqat yaratish': 'Create dish',
      'Masalliq qo‘shish': 'Add ingredient',
      'Masalliqlar': 'Ingredients',
      'Ovqat nomi': 'Dish name',
      'Ovqat nomini yozing va unga ketgan masalliqlarni miqdori bilan qo‘shing.':
          'Enter the dish name and add its ingredients with amounts.',
      'Kamida bitta masalliq qo‘shing.': 'Add at least one ingredient.',
      'Tayyor ovqat vazni (ixtiyoriy)': 'Cooked weight (optional)',
      'Bo‘sh qolsa, masalliqlar yig‘indisi olinadi. Qaynatishda suv bug‘lansa, tortib kiriting.':
          'If empty, the ingredient total is used. If water boiled off, weigh and enter it.',
      '1–20000 g oralig‘ida kiriting.': 'Enter 1–20000 g.',
      'Jami': 'Total',
      '“{name}” yaratildi. Uni qidiruvdan topasiz.':
          '“{name}” created. You can find it in search.',
      'Ovqatni saqlab bo‘lmadi.': 'Could not save the dish.',
      'Ovqat saqlanmadi': 'Dish not saved',
      'Kiritilgan ma’lumotlar o‘chadi. Chiqasizmi?':
          'Entered data will be lost. Leave?',
      'Qoldi': 'Remaining',
      'Chiqib ketish': 'Leave',
      'Ro‘yxatni ochish': 'Show list',
      'Ro‘yxatni yopish': 'Hide list',
      'Internet bazasi': 'Online database',
      'Taom nomini yozib qidiring': 'Enter a dish name to search',
      'Masalan: osh, manti, somsa yoki Samarqand':
          'For example: plov, manti, samsa, or Samarkand',
    },
  };
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => AppLocalizations.supportedLocales.any(
    (supported) => supported.languageCode == locale.languageCode,
  );

  @override
  Future<AppLocalizations> load(Locale locale) =>
      SynchronousFuture(AppLocalizations(locale));

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

extension LocalizedBuildContext on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
  String tr(String key, [Map<String, Object> values = const {}]) =>
      l10n.text(key, values);
}
