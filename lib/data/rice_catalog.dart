part of 'uzbek_food_catalog.dart';

// Representative food groups, not laboratory measurements for each cultivar.
// Reference: https://www.fao.org/4/y4875e/y4875e02.pdf
// Cultivar names: https://releasedvarieties.irri.org/
const _riceVarieties = <(String, String, String, bool)>[
  ('Oq', 'Белый', 'White', false),
  ('Uzun donli', 'Длиннозёрный', 'Long grain', false),
  ('Dumaloq donli', 'Круглозёрный', 'Short grain', false),
  ('O‘rta donli', 'Среднезёрный', 'Medium grain', false),
  ('Jigarrang', 'Бурый', 'Brown', true),
  ('Qizil', 'Красный', 'Red', true),
  ('Qora', 'Чёрный', 'Black', true),
  ('Binafsha', 'Фиолетовый', 'Purple', true),
  ('Basmati', 'Басмати', 'Basmati', false),
  ('Jigarrang basmati', 'Бурый басмати', 'Brown basmati', true),
  ('Jasmin', 'Жасмин', 'Jasmine', false),
  ('Jigarrang jasmin', 'Бурый жасмин', 'Brown jasmine', true),
  ('Devzira', 'Девзира', 'Devzira', false),
  ('Lazer', 'Лазер', 'Lazer', false),
  ('Alanga', 'Аланга', 'Alanga', false),
  ('Chungara', 'Чунгара', 'Chungara', false),
  ('Dastor-sariq', 'Дастар-сарык', 'Dastor saryk', false),
  ('Kora-koltak', 'Кора-колтак', 'Kora koltak', false),
  ('Kenja', 'Кенджа', 'Kenja', false),
  ('Avangard', 'Авангард', 'Avangard', false),
  ('Nukus-2', 'Нукус-2', 'Nukus 2', false),
  ('Arborio', 'Арборио', 'Arborio', false),
  ('Carnaroli', 'Карнароли', 'Carnaroli', false),
  ('Vialone Nano', 'Виалоне Нано', 'Vialone Nano', false),
  ('Baldo', 'Бальдо', 'Baldo', false),
  ('Bomba', 'Бомба', 'Bomba', false),
  ('Calasparra', 'Каласпарра', 'Calasparra', false),
  ('Valensiya', 'Валенсия', 'Valencia', false),
  ('Sushi', 'Для суши', 'Sushi', false),
  ('Koshihikari', 'Косихикари', 'Koshihikari', false),
  ('Sasanishiki', 'Сасанисики', 'Sasanishiki', false),
  ('Akitakomachi', 'Акитакомати', 'Akitakomachi', false),
  ('Hitomebore', 'Хитомэборэ', 'Hitomebore', false),
  ('Calrose', 'Калроуз', 'Calrose', false),
  ('Nishiki', 'Нишики', 'Nishiki', false),
  ('Yopishqoq (glutinous)', 'Клейкий', 'Sticky glutinous', false),
  ('Qora yopishqoq', 'Чёрный клейкий', 'Black sticky', true),
  ('Thai Hom Mali', 'Тайский Хом Мали', 'Thai Hom Mali', false),
  ('Sona Masoori', 'Сона Масури', 'Sona Masoori', false),
  ('Ponni', 'Понни', 'Ponni', false),
  ('Samba', 'Самба', 'Samba', false),
  ('Jeeraga Samba', 'Джирага Самба', 'Jeeraga Samba', false),
  ('Gobindobhog', 'Гобиндобхог', 'Gobindobhog', false),
  ('Kalijira', 'Калиджира', 'Kalijira', false),
  ('IR64', 'ИР64', 'IR64', false),
  ('IR8', 'ИР8', 'IR8', false),
  ('IR841', 'ИР841', 'IR841', false),
  ('Sella (parboiled)', 'Селла пропаренный', 'Sella parboiled', false),
  ('Kamolino', 'Камолино', 'Camolino', false),
  ('Osmancik', 'Османджик', 'Osmancik', false),
];

const _riceForms = <(String, String, String)>[
  ('xom, quruq', 'сырой, сухой', 'raw dry'),
  ('qaynatilgan', 'варёный', 'boiled'),
  ('bug‘da pishirilgan', 'на пару', 'steamed'),
  ('qovurilgan', 'жареный', 'fried'),
];

final List<UzbekDish> _riceDishes = [
  for (var variety = 0; variety < _riceVarieties.length; variety++)
    for (var form = 0; form < _riceForms.length; form++)
      _riceDish(variety, form),
];

UzbekDish _riceDish(int varietyIndex, int formIndex) {
  final (uz, ru, en, wholegrain) = _riceVarieties[varietyIndex];
  final (formUz, formRu, formEn) = _riceForms[formIndex];
  final dry = formIndex == 0;
  final fried = formIndex == 3;
  // Cooked yield assumption: 100 g dry rice + 180 g retained water.
  // Fried recipe: 95 g cooked rice + 5 g vegetable oil per 100 g.
  final scale = (dry ? 1.0 : 1 / 2.8) * (fried ? .95 : 1);
  final protein = (wholegrain ? 7.5 : 7.1) * scale;
  final fat = (wholegrain ? 2.7 : .7) * scale + (fried ? 5 : 0);
  final carbs = (wholegrain ? 76.2 : 80.0) * scale;
  final fiber = (wholegrain ? 3.4 : 1.0) * scale;
  final water = dry ? 12.0 : (192 / 2.8) * (fried ? .95 : 1);
  return UzbekDish(
    nutrition: FoodNutrition(
      fdcId: -10000 - varietyIndex * 10 - formIndex,
      name: '$en rice, $formEn',
      calories: protein * 4 + fat * 9 + carbs * 4,
      protein: protein,
      fat: fat,
      carbohydrates: carbs,
      fiber: fiber,
      water: water,
      productType: 'RICE / $formEn',
      dataSource: 'Retsept bo‘yicha taxminiy hisob',
      ingredients: fried
          ? '95 g pishirilgan $uz guruch + 5 g o‘simlik yog‘i. Tuzsiz.'
          : dry
          ? '100% $uz guruch, quruq.'
          : '$uz guruch va suv. Yog‘siz, tuzsiz.',
      labelDetails:
          '100 g uchun taxminiy qiymatlar. Bu navga xos laboratoriya tahlili emas; '
          '${wholegrain ? 'butun donli' : 'oq'} guruch guruhi asosida hisoblangan. '
          'Quruq guruchning pishgandagi vazni 2,8 baravar deb olingan. '
          'Qovurilgan holatda 100 g taomga 5 g yog‘ hisoblangan. '
          'Suv, yog‘, nav va retseptga qarab qiymatlar o‘zgaradi. '
          'Asos: https://www.fao.org/4/y4875e/y4875e02.pdf',
    ),
    nameUz: '$uz guruch ($formUz)',
    nameRu: '$ru рис ($formRu)',
    nameEn: '$en rice ($formEn)',
    region: 'Guruchlar',
    meals: _allMeals,
  );
}
