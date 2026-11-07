// Reproducible import from the public-domain USDA SR Legacy archive.
// Download: https://fdc.nal.usda.gov/download-datasets/
const fs = require('node:fs');
const crypto = require('node:crypto');
const source = 'data_sources/usda/sr-legacy/FoodData_Central_sr_legacy_food_json_2018-04.json';
const raw = fs.readFileSync(source);
const foods = new Map(JSON.parse(raw).SRLegacyFoods.map(f => [f.fdcId, f]));
// id, Uzbek name, Russian name, category. Preparation is part of identity.
const entries = [
  [172217, 'Sut 3,25%', 'Молоко 3,25%', 'Sut mahsulotlari'],
  [172205, 'Sut 2%', 'Молоко 2%', 'Sut mahsulotlari'],
  [170872, 'Sut 1% (A va D vitaminli)', 'Молоко 1% (витамины A и D)', 'Sut mahsulotlari'],
  [173432, 'Yog‘siz sut', 'Обезжиренное молоко', 'Sut mahsulotlari'],
  [170904, 'LIFEWAY oddiy kam yog‘li kefir (AQSh)', 'LIFEWAY кефир нежирный (США)', 'Sut mahsulotlari'],
  [171301, 'LIFEWAY qulupnayli kefir (AQSh)', 'LIFEWAY кефир клубничный (США)', 'Sut mahsulotlari'],
  [171284, 'Tabiiy qatiq — yogurt, to‘liq sutdan', 'Натуральная простокваша — йогурт из цельного молока', 'Sut mahsulotlari'],
  [171257, 'Smetana, achitilgan qaymoq', 'Сметана', 'Sut mahsulotlari'],
  [173443, 'Kam yog‘li smetana', 'Сметана лёгкая', 'Sut mahsulotlari'],
  [170857, 'Qaymoq, yengil', 'Сливки лёгкие', 'Sut mahsulotlari'],
  [170859, 'Qaymoq, yog‘li', 'Сливки жирные', 'Sut mahsulotlari'],
  [173410, 'Sariyog‘, tuzli', 'Масло сливочное солёное', 'Yog‘lar'],
  [173430, 'Sariyog‘, tuzsiz', 'Масло сливочное несолёное', 'Yog‘lar'],
  [171314, 'Eritilgan sariyog‘, ghee', 'Топлёное масло, гхи', 'Yog‘lar'],
  [171025, 'Kungaboqar yog‘i', 'Подсолнечное масло', 'Yog‘lar'],
  [172338, 'Yuqori oleinli kungaboqar yog‘i', 'Высокоолеиновое подсолнечное масло', 'Yog‘lar'],
  [171029, 'Makkajo‘xori yog‘i', 'Кукурузное масло', 'Yog‘lar'],
  [171411, 'Soya yog‘i', 'Соевое масло', 'Yog‘lar'],
  [173414, 'Cheddar pishlog‘i', 'Сыр чеддер', 'Pishloqlar'],
  [170845, 'Mozzarella pishlog‘i, to‘liq sutdan', 'Сыр моцарелла из цельного молока', 'Pishloqlar'],
  [170847, 'Mozzarella, kam yog‘li sutdan', 'Моцарелла из частично обезжиренного молока', 'Pishloqlar'],
  [173418, 'Qaymoqli pishloq', 'Сливочный сыр', 'Pishloqlar'],
  [173420, 'Feta pishlog‘i', 'Сыр фета', 'Pishloqlar'],
  [171251, 'Shveysariya pishlog‘i', 'Швейцарский сыр', 'Pishloqlar'],
  [170848, 'Parmezan pishlog‘i', 'Сыр пармезан', 'Pishloqlar'],
  [170853, 'Eritilgan American pishlog‘i (D vitaminli)', 'Плавленый сыр American (витамин D)', 'Pishloqlar'],
  [171952, 'Sazan baliq, xom', 'Карп, сырой', 'Baliqlar'],
  [174185, 'Sazan baliq, pechda pishirilgan', 'Карп, запечённый', 'Baliqlar'],
  [175167, 'Losos, Atlantika, fermada yetishtirilgan, xom', 'Лосось атлантический, фермерский, сырой', 'Baliqlar'],
  [175168, 'Losos, Atlantika, fermada yetishtirilgan, pishirilgan', 'Лосось атлантический, фермерский, запечённый', 'Baliqlar'],
  [173686, 'Losos, Atlantika, yovvoyi, xom', 'Лосось атлантический, дикий, сырой', 'Baliqlar'],
  [171998, 'Losos, Atlantika, yovvoyi, pishirilgan', 'Лосось атлантический, дикий, запечённый', 'Baliqlar'],
  [173687, 'Losos chinook, dudlangan', 'Лосось чавыча, копчёный', 'Baliqlar'],
  [173706, 'Tunets, ko‘k suzgichli, xom', 'Тунец голубой, сырой', 'Baliqlar'],
  [173707, 'Tunets, ko‘k suzgichli, pishirilgan', 'Тунец голубой, запечённый', 'Baliqlar'],
  [173709, 'Tunets, suvdagi konserva, suyuqligi to‘kilgan', 'Тунец в воде, консервы без жидкости', 'Baliqlar'],
  [173708, 'Tunets, yog‘dagi konserva, yog‘i to‘kilgan', 'Тунец в масле, консервы без жидкости', 'Baliqlar'],
  [173717, 'Forel, kamalak, fermada yetishtirilgan, xom', 'Форель радужная, фермерская, сырая', 'Baliqlar'],
  [173718, 'Forel, kamalak, fermada yetishtirilgan, pishirilgan', 'Форель радужная, фермерская, запечённая', 'Baliqlar'],
  [170685, 'Grechka, qovurilgan yorma, quruq', 'Гречневая крупа обжаренная, сухая', 'Garnirlar'],
  [170686, 'Grechka, qaynatilgan', 'Гречневая каша, варёная', 'Garnirlar'],
  [169736, 'Makaron, spagetti, quruq, boyitilgan', 'Макароны, спагетти, сухие, обогащённые', 'Garnirlar'],
  [169737, 'Makaron, spagetti, qaynatilgan, tuzsiz, boyitilgan', 'Макароны, спагетти, варёные без соли, обогащённые', 'Garnirlar'],
  [168927, 'Makaron, quruq, boyitilmagan', 'Макароны сухие, необогащённые', 'Garnirlar'],
  [168928, 'Makaron, qaynatilgan, tuzsiz', 'Макароны варёные без соли', 'Garnirlar'],
  [169738, 'Butun bug‘doyli makaron, quruq', 'Цельнозерновые макароны сухие', 'Garnirlar'],
  [168910, 'Butun bug‘doyli makaron, qaynatilgan', 'Цельнозерновые макароны варёные', 'Garnirlar'],
  [168899, 'Glutensiz makkajo‘xori makaroni, quruq', 'Безглютеновые кукурузные макароны сухие', 'Garnirlar'],
  [168900, 'Glutensiz makkajo‘xori makaroni, pishirilgan', 'Безглютеновые кукурузные макароны варёные', 'Garnirlar'],
  [173757, 'No‘xat, qaynatilgan, tuzsiz', 'Нут варёный без соли', 'Garnirlar'],
  [173740, 'Loviya, qaynatilgan, tuzsiz', 'Фасоль варёная без соли', 'Garnirlar'],
  [174257, 'Mosh, qaynatilgan, tuzsiz', 'Маш варёный без соли', 'Garnirlar'],
  [170567, 'Bodom, xom', 'Миндаль сырой', 'Yong‘oq va urug‘lar'],
  [170158, 'Bodom, quruq qovurilgan, tuzsiz', 'Миндаль сухой обжарки без соли', 'Yong‘oq va urug‘lar'],
  [170187, 'Yong‘oq mag‘zi', 'Грецкий орех', 'Yong‘oq va urug‘lar'],
  [172430, 'Yeryong‘oq, xom', 'Арахис сырой', 'Yong‘oq va urug‘lar'],
  [173806, 'Yeryong‘oq, quruq qovurilgan, tuzsiz', 'Арахис сухой обжарки без соли', 'Yong‘oq va urug‘lar'],
  [170184, 'Pista, xom', 'Фисташки сырые', 'Yong‘oq va urug‘lar'],
  [170185, 'Pista, qovurilgan, tuzsiz', 'Фисташки жареные без соли', 'Yong‘oq va urug‘lar'],
  [170162, 'Keshyu, xom', 'Кешью сырой', 'Yong‘oq va urug‘lar'],
  [170581, 'Funduk', 'Фундук', 'Yong‘oq va urug‘lar'],
  [170562, 'Kungaboqar urug‘i mag‘zi, quritilgan', 'Семечки подсолнечника очищенные, сушёные', 'Yong‘oq va urug‘lar'],
  [170563, 'Kungaboqar urug‘i mag‘zi, qovurilgan, tuzsiz', 'Семечки подсолнечника очищенные, жареные без соли', 'Yong‘oq va urug‘lar'],
  [170556, 'Qovoq urug‘i mag‘zi, quritilgan', 'Тыквенные семечки очищенные, сушёные', 'Yong‘oq va urug‘lar'],
  [170554, 'Chia urug‘i', 'Семена чиа', 'Yong‘oq va urug‘lar'],
  [169414, 'Zig‘ir urug‘i', 'Семена льна', 'Yong‘oq va urug‘lar'],
  [170150, 'Kunjut, quritilgan', 'Кунжут сушёный', 'Yong‘oq va urug‘lar'],
  [171890, 'Qora qahva, shakarsiz', 'Чёрный кофе без сахара', 'Ichimliklar'],
  [171891, 'Espresso, shakarsiz', 'Эспрессо без сахара', 'Ichimliklar'],
  [171889, 'Kofeinsiz qora qahva', 'Чёрный кофе без кофеина', 'Ichimliklar'],
  [174130, 'Eriydigan qahva, suvda tayyorlangan', 'Растворимый кофе на воде', 'Ichimliklar'],
  [171880, 'Sutli qahva, shirin, tayyor ichimlik', 'Кофе с молоком, сладкий, готовый напиток', 'Ichimliklar'],
  [173227, 'Qora choy, damlangan, shakarsiz', 'Чёрный чай заваренный без сахара', 'Ichimliklar'],
  [171917, 'Ko‘k choy, damlangan, shakarsiz', 'Зелёный чай заваренный без сахара', 'Ichimliklar'],
  [174156, 'Moychechak choyi, damlangan', 'Ромашковый чай заваренный', 'Ichimliklar'],
  [174852, 'Kola, oddiy gazli ichimlik', 'Кола обычная', 'Ichimliklar'],
  [175099, 'Kola, kam kaloriyali, aspartam bilan', 'Кола низкокалорийная с аспартамом', 'Ichimliklar'],
  [174854, 'Apelsinli gazli ichimlik', 'Апельсиновый газированный напиток', 'Ichimliklar'],
  [173933, 'Olma sharbati, shakar qo‘shilmagan', 'Яблочный сок без добавленного сахара', 'Ichimliklar'],
  [169098, 'Apelsin sharbati, yangi siqilgan', 'Апельсиновый сок свежевыжатый', 'Ichimliklar'],
  [175103, 'Ichimlik suv', 'Питьевая вода', 'Ichimliklar'],
  [174842, 'Gazli suv, club soda', 'Газированная вода, содовая', 'Ichimliklar'],
  [169655, 'Shakar, oq', 'Сахар белый', 'Qo‘shimchalar'],
  [168833, 'Shakar, jigarrang', 'Сахар коричневый', 'Qo‘shimchalar'],
  [169640, 'Asal', 'Мёд', 'Qo‘shimchalar'],
  [169641, 'Murabbo, jem', 'Варенье, джем', 'Qo‘shimchalar'],
  [170645, 'O‘rik murabbosi', 'Абрикосовый джем', 'Qo‘shimchalar'],
  [171009, 'Mayonez, oddiy', 'Майонез обычный', 'Souslar'],
  [173594, 'Mayonez, yengil', 'Майонез лёгкий', 'Souslar'],
  [168556, 'Ketchup', 'Кетчуп', 'Souslar'],
  [174523, 'Barbekyu sousi', 'Соус барбекю', 'Souslar'],
  [174277, 'Soya sousi, shoyu', 'Соевый соус, сёю', 'Souslar'],
  [173592, 'Ranch sousi', 'Соус ранч', 'Souslar'],
  [174527, 'Achchiq qalampir sousi', 'Острый перечный соус', 'Souslar'],
  [170693, 'Gamburger, oddiy, bitta kotletli', 'Гамбургер обычный с одной котлетой', 'Fastfud'],
  [170690, 'Chizburger, oddiy, bitta kotletli', 'Чизбургер обычный с одной котлетой', 'Fastfud'],
  [170295, 'Tovuqli sendvich, file va bodringli', 'Сэндвич с куриным филе и огурцом', 'Fastfud'],
  [170698, 'Kartoshka fri, o‘simlik yog‘ida', 'Картофель фри на растительном масле', 'Fastfud'],
  [170718, 'Tovuq bo‘laklari, panirovkada qovurilgan', 'Кусочки курицы в панировке, жареные', 'Fastfud'],
  [170317, 'Pishloqli pizza, oddiy xamir, muzlatilgandan pishirilgan', 'Пицца сырная, обычное тесто, из замороженной', 'Fastfud'],
  [170373, 'Pishloqli pizza, yupqa xamir, muzlatilgandan pishirilgan', 'Пицца сырная, тонкое тесто, из замороженной', 'Fastfud'],
  [172096, 'Pepperoni pizza, muzlatilgandan pishirilgan', 'Пицца пепперони, из замороженной', 'Fastfud'],
  [170715, 'Go‘sht va sabzavotli pizza, muzlatilgandan pishirilgan', 'Пицца мясная с овощами, из замороженной', 'Fastfud'],
  [172816, 'Pita noni, oq', 'Пита белая', 'Nonlar'],
  [174924, 'Oq non, sanoat usulida tayyorlangan', 'Белый хлеб промышленный', 'Nonlar'],
  [172796, 'Burger yoki hot-dog bulochkasi', 'Булочка для бургера или хот-дога', 'Nonlar'],
  [174614, 'Mol go‘shtli sosiska, isitilgan', 'Сосиска говяжья, разогретая', 'Fastfud'],
  [167587, 'Sutli shokolad', 'Молочный шоколад', 'Shirinliklar'],
  [170271, 'Qora shokolad, kakao 45–59%', 'Тёмный шоколад, какао 45–59%', 'Shirinliklar'],
  [170272, 'Qora shokolad, kakao 60–69%', 'Тёмный шоколад, какао 60–69%', 'Shirinliklar'],
  [170273, 'Qora shokolad, kakao 70–85%', 'Тёмный шоколад, какао 70–85%', 'Shirinliklar'],
  [174967, 'Qumoq pechenye, oddiy', 'Песочное печенье', 'Shirinliklar'],
  [172808, 'Shokoladli pechenye, sariyog‘ bilan retseptdan', 'Печенье с шоколадом, по рецепту со сливочным маслом', 'Shirinliklar'],
  [174963, 'Suli pechenyesi, mayizli', 'Овсяное печенье с изюмом', 'Shirinliklar'],
  [174934, 'Shokoladli tort, shokoladli qoplamali', 'Шоколадный торт с шоколадной глазурью', 'Shirinliklar'],
  [172704, 'Sariyog‘li keks', 'Масляный кекс', 'Shirinliklar'],
  [167575, 'Vanilli muzqaymoq', 'Ванильное мороженое', 'Shirinliklar'],
  [168809, 'Shokoladli muzqaymoq', 'Шоколадное мороженое', 'Shirinliklar'],
  [168810, 'Qulupnayli muzqaymoq', 'Клубничное мороженое', 'Shirinliklar'],
];
const fields = {1008:'calories',1003:'protein',1004:'fat',1005:'carbohydrates',1051:'water',1079:'fiber',2000:'sugars',1258:'saturatedFat',1292:'monounsaturatedFat',1293:'polyunsaturatedFat',1093:'sodiumMg',1092:'potassiumMg',1089:'ironMg',1087:'calciumMg',1253:'cholesterolMg',1091:'phosphorusMg',1090:'magnesiumMg',1109:'vitaminEMg',1095:'zincMg',1114:'vitaminDMcg'};
// These are explicit example recipes, never a restaurant or brand's label.
const recipes = [
  [900001, 'Tovuqli lavash — pita bilan namunaviy retsept', 'Лаваш с курицей — пример рецепта с питой', 'Chicken wrap — example recipe with pita', [[172816,80],[171477,100],[168409,40],[170457,40],[171009,20]]],
  [900002, 'Mol go‘shtli doner — namunaviy retsept', 'Донер с говядиной — пример рецепта', 'Beef doner — example recipe', [[172816,80],[171794,100],[168409,40],[170457,40],[171009,20]]],
  [900003, 'Hot-dog — namunaviy retsept', 'Хот-дог — пример рецепта', 'Hot dog — example recipe', [[172796,60],[174614,60],[168556,15],[171009,10]]],
];
for (const [id, uz, ru, en, components] of recipes) {
  const weight = components.reduce((sum, [, grams]) => sum + grams, 0);
  const ingredientFoods = components.map(([foodId, grams]) => ({food:foods.get(foodId), grams}));
  const combined = [];
  for (const nutrientId of Object.keys(fields).map(Number)) {
    const values = ingredientFoods.map(({food,grams}) => {
      const n = food.foodNutrients.find(n => n.nutrient.id === nutrientId);
      return n?.amount == null ? null : n.amount * grams / weight;
    });
    if (values.every(v => v != null)) combined.push({nutrient:{id:nutrientId}, amount:values.reduce((a,b) => a+b,0)});
  }
  const recipeDetails = ingredientFoods.map(({food,grams}) => `${grams} g ${food.description} (FDC ${food.fdcId})`).join('; ');
  foods.set(id, {fdcId:id,description:en,foodNutrients:combined,foodPortions:[{modifier:'porsiya / порция / serving',amount:1,gramWeight:weight}],recipeDetails,components});
  entries.push([id,uz,ru,'Fastfud']);
}
const quoted = value => JSON.stringify(value).replace(/\$/g, '\\$');
const subset = [];
let dart = "part of 'uzbek_food_catalog.dart';\n\n// GENERATED by scripts/build_everyday_catalog.cjs. Do not invent brand labels.\n// USDA SR Legacy: original preparation, nutrients and gram portions retained.\nfinal List<UzbekDish> _everydayDishes = [\n";
for (const [id, uz, ru, category] of entries) {
  const f = foods.get(id);
  if (!f) throw new Error(`Missing source ${id}`);
  const values = {};
  for (const n of f.foodNutrients) {
    const key = fields[n.nutrient.id];
    if (key && Number.isFinite(n.amount) && n.amount >= 0) values[key] = n.amount;
  }
  for (const key of ['calories','protein','fat','carbohydrates']) if (values[key] == null) throw new Error(`Missing ${key}: ${id}`);
  if (values.sodiumMg != null) values.salt = values.sodiumMg * 2.5 / 1000;
  const servings = (f.foodPortions ?? []).filter(p => p.gramWeight > 0 && (p.portionDescription || p.modifier)).map(p => ({description:p.portionDescription || `${p.amount ?? 1} ${p.modifier}`, amount:p.gramWeight, unit:'g'}));
  const url = f.recipeDetails ? 'https://fdc.nal.usda.gov/' : `https://fdc.nal.usda.gov/food-details/${id}/nutrients`;
  subset.push({fdcId:id, description:f.description, source:url, names:{uz,ru}, category, nutrients:values, servings});
  dart += `  UzbekDish(\n    nutrition: FoodNutrition(\n      fdcId: -${id},\n      name: ${quoted(f.description)},\n      dataSource: ${quoted(f.recipeDetails ? 'Retsept · USDA ingredientlari' : `USDA SR Legacy · FDC ${id}`)},\n      labelDetails: ${quoted(url + '\n100 g. Umumiy mahsulot; aniq mahalliy brend yorlig‘i emas. Retsept va ishlab chiqaruvchiga qarab farq qiladi.' + (f.recipeDetails ? '\nNamuna retsept: ' + f.recipeDetails : ''))},\n`;
  for (const [key, value] of Object.entries(values)) dart += `      ${key}: ${value},\n`;
  if (values.water == null) dart += '      water: 0,\n      hasWaterData: false,\n';
  dart += `      knownNutrients: {${Object.keys(values).map(quoted).join(', ')}},\n`;
  dart += `      servings: [${servings.map(s => `FoodServing(description: ${quoted(s.description)}, amount: ${s.amount})`).join(', ')}],\n`;
  dart += `    ),\n    nameUz: ${quoted(uz)},\n    nameRu: ${quoted(ru)},\n    nameEn: ${quoted(f.description)},\n    region: ${quoted(category)},\n    meals: _allMeals,\n  ),\n`;
}
dart += '];\n';
fs.writeFileSync('lib/data/everyday_catalog.dart', dart);
fs.writeFileSync('data_sources/everyday_catalog.json', JSON.stringify({source:'https://fdc.nal.usda.gov/fdc-datasets/FoodData_Central_sr_legacy_food_json_2018-04.zip', sha256:crypto.createHash('sha256').update(raw).digest('hex'), foods:subset}, null, 2));
console.log(`Generated ${entries.length} foods with source nutrients and portions.`);
