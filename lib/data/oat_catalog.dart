part of 'uzbek_food_catalog.dart';

// Product existence sources are separate from verified nutrition labels.
// Do not apply a brand's label to its other products.
class _OatProduct {
  const _OatProduct(
    this.brand,
    this.uz,
    this.ru,
    this.en,
    this.source, {
    this.label,
  });
  final String brand;
  final String uz;
  final String ru;
  final String en;
  final String source;
  // kcal, protein, fat, carbohydrate, fibre per 100 g dry product.
  final (double, double, double, double, double)? label;
}

const _oatProducts = [
  _OatProduct('', 'Yirik yorma', 'Крупные хлопья', 'Thick rolled oats', ''),
  _OatProduct('', 'Mayda yorma', 'Мелкие хлопья', 'Fine rolled oats', ''),
  _OatProduct(
    '',
    'Tezpishar',
    'Быстрого приготовления',
    'Quick cooking oats',
    '',
  ),
  _OatProduct(
    '',
    'Bir zumda tayyorlanadigan',
    'Моментальные',
    'Instant oats',
    '',
  ),
  _OatProduct('', 'Butun donli', 'Цельнозерновые', 'Wholegrain oats', ''),
  _OatProduct('', 'Kesilgan suli', 'Резаный овёс', 'Steel cut oats', ''),
  _OatProduct(
    '',
    'Shotlandcha maydalangan suli',
    'Шотландская молотая овсянка',
    'Scottish oatmeal',
    '',
  ),
  _OatProduct('', 'Ekstra №1', 'Экстра №1', 'Extra No. 1 oats', ''),
  _OatProduct('', 'Ekstra №2', 'Экстра №2', 'Extra No. 2 oats', ''),
  _OatProduct('', 'Ekstra №3', 'Экстра №3', 'Extra No. 3 oats', ''),
  _OatProduct(
    'Quaker',
    'Old Fashioned',
    'Old Fashioned',
    'Old Fashioned',
    'https://www.quakeroats.com/sites/quakeroats.com/themes/quakeroats/docs/the_quaker_portfolio.pdf',
  ),
  _OatProduct(
    'Quaker',
    'Quick 1-Minute',
    'Quick 1-Minute',
    'Quick 1-Minute',
    'https://www.quakeroats.com/sites/quakeroats.com/themes/quakeroats/docs/the_quaker_portfolio.pdf',
  ),
  _OatProduct(
    'Quaker',
    'Steel Cut',
    'Steel Cut',
    'Steel Cut',
    'https://www.quakeroats.com/sites/quakeroats.com/themes/quakeroats/docs/the_quaker_portfolio.pdf',
  ),
  _OatProduct(
    'Quaker',
    'Gluten Free Original Instant',
    'Gluten Free Original Instant',
    'Gluten Free Original Instant',
    'https://www.quakeroats.com/sites/quakeroats.com/themes/quakeroats/docs/the_quaker_portfolio.pdf',
  ),
  _OatProduct(
    'Bob’s Red Mill',
    'Old Fashioned Rolled Oats',
    'Old Fashioned Rolled Oats',
    'Old Fashioned Rolled Oats',
    'https://www.bobsredmill.com/all-about-oats',
  ),
  _OatProduct(
    'Bob’s Red Mill',
    'Quick Cooking Rolled Oats',
    'Quick Cooking Rolled Oats',
    'Quick Cooking Rolled Oats',
    'https://www.bobsredmill.com/all-about-oats',
  ),
  _OatProduct(
    'Bob’s Red Mill',
    'Steel Cut Oats',
    'Steel Cut Oats',
    'Steel Cut Oats',
    'https://www.bobsredmill.com/all-about-oats',
  ),
  _OatProduct(
    'Bob’s Red Mill',
    'Quick Cooking Steel Cut Oats',
    'Quick Cooking Steel Cut Oats',
    'Quick Cooking Steel Cut Oats',
    'https://www.bobsredmill.com/all-about-oats',
  ),
  _OatProduct(
    'Bob’s Red Mill',
    'Extra Thick Rolled Oats',
    'Extra Thick Rolled Oats',
    'Extra Thick Rolled Oats',
    'https://www.bobsredmill.com/all-about-oats',
  ),
  _OatProduct(
    'Bob’s Red Mill',
    'Instant Oats',
    'Instant Oats',
    'Instant Oats',
    'https://www.bobsredmill.com/all-about-oats',
  ),
  _OatProduct(
    'Bob’s Red Mill',
    'Scottish Oats',
    'Scottish Oats',
    'Scottish Oats',
    'https://www.bobsredmill.com/all-about-oats',
  ),
  _OatProduct(
    'Русский Продукт',
    'An’anaviy',
    'Традиционный',
    'Traditional',
    'https://online.rusprod.ru/products/',
  ),
  _OatProduct(
    'Ясно Солнышко',
    '№1',
    '№1',
    '№1',
    'https://www.yasnosolnyshko.ru/',
  ),
  _OatProduct(
    'Ясно Солнышко',
    '№2',
    '№2',
    '№2',
    'https://www.yasnosolnyshko.ru/',
  ),
  _OatProduct(
    'Ясно Солнышко',
    '№3',
    '№3',
    '№3',
    'https://www.yasnosolnyshko.ru/',
  ),
  _OatProduct(
    'Myllyn Paras',
    '1928 yirik yorma',
    '1928 крупные хлопья',
    '1928 thick rolled oats',
    'https://www.myllynparas.ru/product/1928_xlopya-gerkules-krupnie',
    label: (350, 12, 6, 62, 6),
  ),
  _OatProduct(
    'Myllyn Paras',
    '1928 kesilgan suli',
    '1928 резаный овёс',
    '1928 steel cut oats',
    'https://www.myllynparas.ru/products/khlopya-1928',
  ),
  _OatProduct(
    'Nordic',
    'Suli yormasi',
    'Овсяные хлопья',
    'Oat flakes',
    'https://online.metro-cc.ru/products/khlopya-ovsyanyye-nordic-500g-373527',
  ),
  _OatProduct(
    'Увелка',
    'Gerkules',
    'Геркулес',
    'Hercules oat flakes',
    'https://intermarkt24.de/Hlopja_ovsyanie_russkaja_kasha',
  ),
  _OatProduct(
    'Flahavan’s',
    'Irish Rolled Oats',
    'Irish Rolled Oats',
    'Irish Rolled Oats',
    'https://www.flahavans.com/products/',
  ),
  _OatProduct(
    'Flahavan’s',
    'Pinhead Oatmeal',
    'Pinhead Oatmeal',
    'Pinhead Oatmeal',
    'https://www.flahavans.ie/product/flahavans-pinhead-oatmeal-1kg/',
  ),
  _OatProduct(
    'McCann’s',
    'Traditional Steel Cut',
    'Traditional Steel Cut',
    'Traditional Steel Cut',
    'https://mccanns.com/products/',
  ),
  _OatProduct(
    'Kölln',
    'Delicate',
    'Нежные',
    'Delicate',
    'https://www.koelln.com/products/delicate-koelln-oat-flakes',
    label: (361, 14, 6.7, 56, 11),
  ),
  _OatProduct(
    'Kölln',
    'Regular Rolled',
    'Крупные',
    'Regular Rolled',
    'https://www.koelln.com/collections/oat-flakes',
  ),
  _OatProduct(
    'Kölln',
    'Gluten-Free Delicate',
    'Нежные без глютена',
    'Gluten-Free Delicate',
    'https://www.koelln.com/collections/oat-flakes',
  ),
  _OatProduct(
    'Kölln',
    'Gluten-Free Regular Rolled',
    'Крупные без глютена',
    'Gluten-Free Regular Rolled',
    'https://www.koelln.com/collections/oat-flakes',
  ),
  _OatProduct(
    'Mornflake',
    'Superfast Oats',
    'Superfast Oats',
    'Superfast Oats',
    'https://www.mornflake.com/shop/porridge-oats/',
  ),
  _OatProduct(
    'Mornflake',
    'Jumbo Oats',
    'Jumbo Oats',
    'Jumbo Oats',
    'https://www.mornflake.com/shop/porridge-oats/',
  ),
  _OatProduct(
    'Mornflake',
    'Organic Oats',
    'Organic Oats',
    'Organic Oats',
    'https://www.mornflake.com/shop/porridge-oats/',
  ),
  _OatProduct(
    'Mornflake',
    'Gluten Free Oats',
    'Gluten Free Oats',
    'Gluten Free Oats',
    'https://www.mornflake.com/shop/porridge-oats/',
  ),
  _OatProduct(
    'Mornflake',
    'Scottish Oats',
    'Scottish Oats',
    'Scottish Oats',
    'https://www.mornflake.com/shop/porridge-oats/',
  ),
  _OatProduct(
    'Nairn’s',
    'Gluten Free Scottish Porridge Oats',
    'Gluten Free Scottish Porridge Oats',
    'Gluten Free Scottish Porridge Oats',
    'https://nairns.com/',
  ),
];

const _oatForms = [
  ('quruq', 'сухие', 'dry'),
  ('suvda pishirilgan', 'на воде', 'cooked with water'),
  ('sutda pishirilgan', 'на молоке', 'cooked with milk'),
];

final List<UzbekDish> _oatDishes = [
  for (var product = 0; product < _oatProducts.length; product++)
    for (var form = 0; form < _oatForms.length; form++) _oatDish(product, form),
];

UzbekDish _oatDish(int productIndex, int formIndex) {
  final product = _oatProducts[productIndex];
  final (uz, ru, en) = _oatForms[formIndex];
  final dry = formIndex == 0;
  final milk = formIndex == 2;
  // Generic plain oats proxy: Myllyn Paras 1928 Hercules label.
  // Prepared recipes: 25 g dry oats + 75 g retained liquid per 100 g.
  final (kcal, protein, fat, carbs, fiber) =
      product.label ?? (350.0, 12.0, 6.0, 62.0, 6.0);
  final scale = dry ? 1.0 : .25;
  final verifiedDry = dry && product.label != null;
  final latinBrand =
      const {
        'Русский Продукт': 'Russkiy Produkt',
        'Ясно Солнышко': 'Yasno Solnyshko',
        'Увелка': 'Uvelka',
        'Kölln': 'Kolln (Kölln)',
      }[product.brand] ??
      product.brand;
  final brand = latinBrand.isEmpty ? '' : '$latinBrand ';
  final russianBrand = product.brand.isEmpty ? '' : '${product.brand} ';
  return UzbekDish(
    nutrition: FoodNutrition(
      fdcId: -12000 - productIndex * 10 - formIndex,
      name: '$brand${product.en} oatmeal, $en',
      calories: kcal * scale + (milk ? 52 * .75 : 0),
      protein: protein * scale + (milk ? 3 * .75 : 0),
      fat: fat * scale + (milk ? 2.5 * .75 : 0),
      carbohydrates: carbs * scale + (milk ? 4.7 * .75 : 0),
      fiber: fiber * scale,
      water: 0,
      hasWaterData: false,
      missingNutrients: const {'water'},
      knownNutrients: const {
        'calories',
        'protein',
        'fat',
        'carbohydrates',
        'fiber',
      },
      productType: 'OATS / $en',
      dataSource: verifiedDry
          ? 'Ishlab chiqaruvchi yorlig‘i'
          : 'Mahalliy katalog — tarkib asosida hisoblangan',
      ingredients: dry
          ? 'Oddiy, qo‘shimchasiz suli yormasi.'
          : milk
          ? '25 g quruq suli + 75 g 2,5% sut (tayyor taom vazni 100 g).'
          : '25 g quruq suli + 75 g suv (tayyor taom vazni 100 g).',
      labelDetails:
          'Qiymatlar 100 g ${dry ? 'quruq mahsulot' : 'tayyor bo‘tqa'} uchun. '
          '${product.label != null ? 'Quruq mahsulot qiymatlari ishlab chiqaruvchi sahifasidan.' : 'Aynan shu mahsulot yorlig‘i tasdiqlanmagan. Oddiy suli uchun Myllyn Paras 1928 Gerkules qiymatlari namuna sifatida ishlatilgan; bu brendning aniq oziq qiymati emas.'} '
          '${dry ? '' : 'Retsept bo‘yicha taxmin: 25 g suli va 75 g saqlanib qolgan suyuqlik. Sut uchun 100 g da 52 kcal, 3 g oqsil, 2,5 g yog‘ va 4,7 g uglevod qabul qilingan. '}'
          'Shakar, sariyog‘, meva va boshqa qo‘shimchalar hisoblanmagan. '
          'Suv miqdori haqida ma’lumot yo‘q. '
          'Qadoqdagi qiymatlar farq qilishi mumkin. '
          'Mahsulot manbasi: ${product.source.isEmpty ? 'umumiy suli turi' : product.source}. '
          'Namuna: https://www.myllynparas.ru/product/1928_xlopya-gerkules-krupnie',
    ),
    nameUz: '$brand${product.uz} gerkules (suli, $uz)',
    nameRu: '$russianBrand${product.ru} геркулес (овсянка, $ru)',
    nameEn: '$brand${product.en} oats (oatmeal, $en)',
    region: 'Gerkules va suli',
    meals: _allMeals,
  );
}
