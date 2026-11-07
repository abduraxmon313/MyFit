part of 'uzbek_food_catalog.dart';

// Reviewed 2026-10-22. These are generic estimates, not cultivar assays or
// manufacturer labels. All amounts refer to 100 g, never 100 ml.
const _oliveNutritionSource =
    'https://fdc.nal.usda.gov/fdc-app.html#/food-details/171413/nutrients';
const _oliveNutritionMirror =
    'https://growables.com/information/TropicalFruit/documents/OliveUSDAnutrient2.pdf';
const _oliveDefinitions =
    'https://www.internationaloliveoil.org/olive-world/olive-oil/';
const _oliveGlossary =
    'https://www.aboutoliveoil.org/glossary-of-olive-oil-terminology-0';
const _oliveVarieties =
    'https://worldolivecatalogue.internationaloliveoil.org/en/document/module-1-varieties/varieties-table';

// English name, Uzbek description, Russian description, typical composition.
const _oliveOilTypes = [
  (
    'Extra Virgin Olive Oil',
    'ekstra virgin',
    'экстра вирджин',
    'Mexanik usulda olingan, rafinatsiya qilinmagan zaytun yog‘i.',
  ),
  (
    'Virgin Olive Oil',
    'virgin',
    'вирджин',
    'Mexanik usulda olingan virgin zaytun yog‘i.',
  ),
  (
    'Refined Olive Oil',
    'rafinatsiyalangan',
    'рафинированное',
    'Rafinatsiya qilingan zaytun yog‘i.',
  ),
  (
    'Pure Olive Oil',
    'pure',
    'pure',
    'Odatda rafinatsiyalangan va virgin zaytun yog‘lari aralashmasi.',
  ),
  (
    'Classic Olive Oil',
    'klassik',
    'классическое',
    'Odatda rafinatsiyalangan va virgin zaytun yog‘lari aralashmasi; Classic savdo nomidir.',
  ),
  (
    'Light Olive Oil',
    'light',
    'light',
    'Odatda rafinatsiyalangan yog‘ va virgin zaytun yog‘i aralashmasi. Light ta’mga tegishli; yog‘ va kaloriya kamaytirilmagan.',
  ),
  (
    'Extra Light Olive Oil',
    'extra light',
    'extra light',
    'Odatda rafinatsiyalangan yog‘ va virgin zaytun yog‘i aralashmasi. Extra Light ta’mga tegishli; yog‘ va kaloriya kamaytirilmagan.',
  ),
  (
    'Olive Pomace Oil',
    'kunjaradan olingan pomace',
    'из оливковых выжимок',
    'Iste’mol uchun rafinatsiyalangan zaytun kunjarasi yog‘i va virgin zaytun yog‘i aralashmasi.',
  ),
  (
    'Organic Extra Virgin Olive Oil',
    'organik ekstra virgin',
    'органическое экстра вирджин',
    'Organik zaytunlardan olingan ekstra virgin yog‘; organik sertifikat qadoqdan tekshiriladi.',
  ),
  (
    'Cold Pressed Olive Oil',
    'sovuq siqilgan',
    'холодного отжима',
    'Sovuq usulda olingan zaytun yog‘i; bu ishlab chiqarish usuli, alohida oziq tarkibi emas.',
  ),
  (
    'Unfiltered Olive Oil',
    'filtrlanmagan',
    'нефильтрованное',
    'Filtrlanmagan zaytun yog‘i; oz miqdorda zaytun zarrachalari va namlik qolishi mumkin.',
  ),
  (
    'First Cold Pressed Olive Oil',
    'birinchi sovuq siqilgan',
    'первого холодного отжима',
    'Birinchi sovuq siqish deb belgilangan zaytun yog‘i; aniq usul qadoqdan tekshiriladi.',
  ),
  (
    'Arbequina Olive Oil',
    'Arbequina navli',
    'сорта Arbequina',
    'Arbequina navli zaytunlardan olingan yog‘.',
  ),
  (
    'Picual Olive Oil',
    'Picual navli',
    'сорта Picual',
    'Picual navli zaytunlardan olingan yog‘.',
  ),
  (
    'Koroneiki Olive Oil',
    'Koroneiki navli',
    'сорта Koroneiki',
    'Koroneiki navli zaytunlardan olingan yog‘.',
  ),
  (
    'Hojiblanca Olive Oil',
    'Hojiblanca navli',
    'сорта Hojiblanca',
    'Hojiblanca navli zaytunlardan olingan yog‘.',
  ),
  (
    'Frantoio Olive Oil',
    'Frantoio navli',
    'сорта Frantoio',
    'Frantoio navli zaytunlardan olingan yog‘.',
  ),
  (
    'Leccino Olive Oil',
    'Leccino navli',
    'сорта Leccino',
    'Leccino navli zaytunlardan olingan yog‘.',
  ),
  (
    'Kalamata Olive Oil',
    'Kalamata',
    'Kalamata',
    'Kalamata deb sotiladigan zaytun yog‘i. Kalamata hudud yoki navga ishora qilishi mumkin; aniq navni yorliqdan tekshiring.',
  ),
  (
    'Infused Olive Oil',
    'xushbo‘ylashtirilgan infused',
    'ароматизированное infused',
    'Zaytun yog‘i va sarimsoq, ko‘kat, limon yoki ziravor kabi qo‘shimchalar; aniq tarkib qadoqqa bog‘liq.',
  ),
];

final List<UzbekDish> _oliveOilDishes = [
  for (var i = 0; i < _oliveOilTypes.length; i++) _oliveOilDish(i),
];

UzbekDish _oliveOilDish(int index) {
  final (en, uz, ru, composition) = _oliveOilTypes[index];
  final infused = index == 19;
  return UzbekDish(
    nutrition: FoodNutrition(
      fdcId: -15000 - index,
      name: en,
      calories: 884,
      protein: 0,
      fat: 100,
      carbohydrates: 0,
      water: 0,
      saturatedFat: 13.808,
      monounsaturatedFat: 72.961,
      polyunsaturatedFat: 10.523,
      sodiumMg: 2,
      potassiumMg: 1,
      calciumMg: 1,
      ironMg: .56,
      vitaminEMg: 14.35,
      // USDA total vitamin K is not vitamin K2. Do not populate K2 with it.
      knownNutrients: const {
        'calories',
        'protein',
        'fat',
        'carbohydrates',
        'water',
        'fiber',
        'sugars',
        'saturatedFat',
        'monounsaturatedFat',
        'polyunsaturatedFat',
        'sodiumMg',
        'potassiumMg',
        'calciumMg',
        'ironMg',
        'magnesiumMg',
        'phosphorusMg',
        'zincMg',
        'vitaminEMg',
        'vitaminDMcg',
        'cholesterolMg',
      },
      productType: 'OLIVE OIL',
      ingredients: composition,
      dataSource: 'USDA FoodData Central — umumiy zaytun yog‘i, taxminiy',
      labelDetails:
          '100 g uchun taxminiy qiymatlar: yog‘ ulushi ≈100%. '
          'USDA umumiy zaytun yog‘i profili ishlatilgan; aynan shu tur, nav yoki brendning laboratoriya tahlili emas. '
          'Yog‘ kislotalari, vitamin va minerallar hosil, qayta ishlash va ishlab chiqaruvchiga qarab farqlanadi. '
          '${infused ? 'Infused uchun sof yog‘ asosidagi taxmin: qo‘shimchalar hisoblanmagan. Qadoqdagi tarkib va oziq qiymatlari ustun. ' : ''}'
          '$composition '
          'Oziq qiymati: $_oliveNutritionSource ; nusxa: $_oliveNutritionMirror . '
          'Tur ta’rifi: $_oliveDefinitions ; atamalar: $_oliveGlossary . '
          '${index >= 12 && index <= 18 ? 'Navlar: $_oliveVarieties . ' : ''}'
          'Tekshirilgan sana: 2026-10-22.',
    ),
    nameUz: '$uz zaytun yog‘i (olivka yogi)',
    nameRu: 'Оливковое масло $ru',
    nameEn: en,
    region: 'Zaytun yog‘i',
    meals: _allMeals,
  );
}
