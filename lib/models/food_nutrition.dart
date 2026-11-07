class FoodServing {
  const FoodServing({required this.description, required this.amount, this.unit = 'g', this.id = ''});
  final String id;
  final String description;
  final double amount;
  final String unit;

  Map<String, Object> toMap() => {'id': id, 'description': description, 'amount': amount, 'unit': unit};

  static List<FoodServing> read(dynamic value, String basisUnit) {
    if (value is! List) return const [];
    return value.whereType<Map>().map((item) {
      final amount = item['amount'];
      return FoodServing(
        id: item['id'] is String ? item['id'] as String : '',
        description: item['description'] is String ? item['description'] as String : '',
        amount: amount is num ? amount.toDouble() : 0,
        unit: item['unit'] == 'ml' ? 'ml' : 'g',
      );
    }).where((item) => item.description.isNotEmpty && item.amount.isFinite && item.amount > 0 && item.unit == basisUnit).toList(growable: false);
  }
}

class FoodNutrition {
  const FoodNutrition({
    required this.fdcId,
    required this.name,
    required this.calories,
    required this.protein,
    required this.fat,
    required this.carbohydrates,
    required this.water,
    this.fiber = 0,
    this.grams = 100,
    this.basisUnit = 'g',
    this.servings = const [],
    this.localName,
    this.confidence,
    this.hasWaterData = true,
    this.mealType,
    this.productType,
    this.ingredients,
    this.sugars = 0,
    this.saturatedFat = 0,
    this.monounsaturatedFat,
    this.polyunsaturatedFat,
    this.knownNutrients = const {},
    this.dataSource,
    this.missingNutrients = const {},
    this.salt = 0,
    this.sodiumMg = 0,
    this.potassiumMg = 0,
    this.ironMg = 0,
    this.calciumMg = 0,
    this.cholesterolMg = 0,
    this.labelDetails,
    this.phosphorusMg = 0,
    this.magnesiumMg = 0,
    this.vitaminEMg = 0,
    this.zincMg = 0,
    this.vitaminDMcg = 0,
    this.vitaminK2Mcg = 0,
  });

  final int fdcId;
  final String name;
  final double calories;
  final double protein;
  final double fat;
  final double carbohydrates;
  final double water;
  final double fiber;
  final double grams;
  /// Legacy `grams` stores the amount in this unit. Never infer liquid density.
  final String basisUnit;
  final List<FoodServing> servings;
  final String? localName;
  final double? confidence;
  final bool hasWaterData;
  final String? mealType;
  final String? productType;
  final String? ingredients;
  final double sugars;
  final double saturatedFat;
  final double? monounsaturatedFat;
  final double? polyunsaturatedFat;

  /// Explicitly supplied nutrients, including measured zeroes.
  final Set<String> knownNutrients;
  final String? dataSource;
  final Set<String> missingNutrients;

  bool get hasMissingCoreNutrients => const {
    'calories',
    'protein',
    'fat',
    'carbohydrates',
  }.any(missingNutrients.contains);
  final double salt;
  final double sodiumMg;
  final double potassiumMg;
  final double ironMg;
  final double calciumMg;
  final double cholesterolMg;
  final String? labelDetails;
  final double phosphorusMg;
  final double magnesiumMg;
  final double vitaminEMg;
  final double zincMg;
  final double vitaminDMcg;
  final double vitaminK2Mcg;

  String get displayName {
    final local = localName?.trim();
    if (local == null || local.isEmpty) return name;
    if (local.toLowerCase() == name.toLowerCase()) return name;
    return '$local ($name)';
  }

  String displayNameFor(String languageCode) {
    final local = localName?.trim();
    if (languageCode != 'en' && local != null && local.isNotEmpty) {
      return _localizedDetailedName(
        baseName: local,
        description: name,
        languageCode: languageCode,
      );
    }
    return name;
  }

  FoodNutrition forGrams(double grams, {String? localName}) {
    if (!grams.isFinite || grams <= 0) {
      throw ArgumentError.value(grams, 'grams', 'Must be finite and positive');
    }
    if (!this.grams.isFinite || this.grams <= 0) {
      throw StateError('The original portion must be finite and positive');
    }
    final factor = grams / this.grams;
    return FoodNutrition(
      fdcId: fdcId,
      name: name,
      calories: calories * factor,
      protein: protein * factor,
      fat: fat * factor,
      carbohydrates: carbohydrates * factor,
      water: water * factor,
      fiber: fiber * factor,
      grams: grams,
      basisUnit: basisUnit,
      servings: servings,
      localName: localName ?? this.localName,
      confidence: confidence,
      hasWaterData: hasWaterData,
      mealType: mealType,
      productType: productType,
      ingredients: ingredients,
      sugars: sugars * factor,
      saturatedFat: saturatedFat * factor,
      monounsaturatedFat: monounsaturatedFat == null
          ? null
          : monounsaturatedFat! * factor,
      polyunsaturatedFat: polyunsaturatedFat == null
          ? null
          : polyunsaturatedFat! * factor,
      knownNutrients: knownNutrients,
      dataSource: dataSource,
      missingNutrients: missingNutrients,
      salt: salt * factor,
      sodiumMg: sodiumMg * factor,
      potassiumMg: potassiumMg * factor,
      ironMg: ironMg * factor,
      calciumMg: calciumMg * factor,
      cholesterolMg: cholesterolMg * factor,
      labelDetails: labelDetails,
      phosphorusMg: phosphorusMg * factor,
      magnesiumMg: magnesiumMg * factor,
      vitaminEMg: vitaminEMg * factor,
      zincMg: zincMg * factor,
      vitaminDMcg: vitaminDMcg * factor,
      vitaminK2Mcg: vitaminK2Mcg * factor,
    );
  }

  FoodNutrition withMealType(String value) => FoodNutrition(
    fdcId: fdcId,
    name: name,
    calories: calories,
    protein: protein,
    fat: fat,
    carbohydrates: carbohydrates,
    water: water,
    fiber: fiber,
    grams: grams,
    basisUnit: basisUnit,
    servings: servings,
    localName: localName,
    confidence: confidence,
    hasWaterData: hasWaterData,
    mealType: value,
    productType: productType,
    ingredients: ingredients,
    sugars: sugars,
    saturatedFat: saturatedFat,
    monounsaturatedFat: monounsaturatedFat,
    polyunsaturatedFat: polyunsaturatedFat,
    knownNutrients: knownNutrients,
    dataSource: dataSource,
    missingNutrients: missingNutrients,
    salt: salt,
    sodiumMg: sodiumMg,
    potassiumMg: potassiumMg,
    ironMg: ironMg,
    calciumMg: calciumMg,
    cholesterolMg: cholesterolMg,
    labelDetails: labelDetails,
    phosphorusMg: phosphorusMg,
    magnesiumMg: magnesiumMg,
    vitaminEMg: vitaminEMg,
    zincMg: zincMg,
    vitaminDMcg: vitaminDMcg,
    vitaminK2Mcg: vitaminK2Mcg,
  );

  Map<String, Object?> toMap() => {
    'fdcId': fdcId,
    'name': name,
    'calories': calories,
    'protein': protein,
    'fat': fat,
    'carbohydrates': carbohydrates,
    'water': water,
    'fiber': fiber,
    'grams': grams,
    'basisUnit': basisUnit,
    'servings': servings.map((item) => item.toMap()).toList(),
    'localName': localName,
    'confidence': confidence,
    'hasWaterData': hasWaterData,
    'mealType': mealType,
    'productType': productType,
    'ingredients': ingredients,
    'sugars': sugars,
    'saturatedFat': saturatedFat,
    'monounsaturatedFat': monounsaturatedFat,
    'polyunsaturatedFat': polyunsaturatedFat,
    'knownNutrients': knownNutrients.toList(),
    'dataSource': dataSource,
    'missingNutrients': missingNutrients.toList(),
    'salt': salt,
    'sodiumMg': sodiumMg,
    'potassiumMg': potassiumMg,
    'ironMg': ironMg,
    'calciumMg': calciumMg,
    'cholesterolMg': cholesterolMg,
    'labelDetails': labelDetails,
    'phosphorusMg': phosphorusMg,
    'magnesiumMg': magnesiumMg,
    'vitaminEMg': vitaminEMg,
    'zincMg': zincMg,
    'vitaminDMcg': vitaminDMcg,
    'vitaminK2Mcg': vitaminK2Mcg,
  };

  factory FoodNutrition.fromMap(Map<String, dynamic> map) {
    return FoodNutrition(
      fdcId: (map['fdcId'] as num?)?.toInt() ?? 0,
      name: map['name'] as String? ?? 'Noma’lum ovqat',
      dataSource: map['dataSource'] as String?,
      missingNutrients:
          (map['missingNutrients'] as List?)?.whereType<String>().toSet() ??
          const {},
      calories: (map['calories'] as num?)?.toDouble() ?? 0,
      protein: (map['protein'] as num?)?.toDouble() ?? 0,
      fat: (map['fat'] as num?)?.toDouble() ?? 0,
      carbohydrates: (map['carbohydrates'] as num?)?.toDouble() ?? 0,
      water: (map['water'] as num?)?.toDouble() ?? 0,
      fiber: (map['fiber'] as num?)?.toDouble() ?? 0,
      grams: (map['grams'] as num?)?.toDouble() ?? 100,
      basisUnit: map['basisUnit'] == 'ml' ? 'ml' : 'g',
      servings: FoodServing.read(map['servings'], map['basisUnit'] == 'ml' ? 'ml' : 'g'),
      localName: map['localName'] as String?,
      confidence: (map['confidence'] as num?)?.toDouble(),
      hasWaterData: map['hasWaterData'] as bool? ?? true,
      mealType: map['mealType'] as String?,
      productType: map['productType'] as String?,
      ingredients: map['ingredients'] as String?,
      sugars: (map['sugars'] as num?)?.toDouble() ?? 0,
      saturatedFat: (map['saturatedFat'] as num?)?.toDouble() ?? 0,
      monounsaturatedFat: (map['monounsaturatedFat'] as num?)?.toDouble(),
      polyunsaturatedFat: (map['polyunsaturatedFat'] as num?)?.toDouble(),
      knownNutrients:
          (map['knownNutrients'] as List?)?.whereType<String>().toSet() ??
          const {},
      salt: (map['salt'] as num?)?.toDouble() ?? 0,
      sodiumMg: (map['sodiumMg'] as num?)?.toDouble() ?? 0,
      potassiumMg: (map['potassiumMg'] as num?)?.toDouble() ?? 0,
      ironMg: (map['ironMg'] as num?)?.toDouble() ?? 0,
      calciumMg: (map['calciumMg'] as num?)?.toDouble() ?? 0,
      cholesterolMg: (map['cholesterolMg'] as num?)?.toDouble() ?? 0,
      labelDetails: map['labelDetails'] as String?,
      phosphorusMg: (map['phosphorusMg'] as num?)?.toDouble() ?? 0,
      magnesiumMg: (map['magnesiumMg'] as num?)?.toDouble() ?? 0,
      vitaminEMg: (map['vitaminEMg'] as num?)?.toDouble() ?? 0,
      zincMg: (map['zincMg'] as num?)?.toDouble() ?? 0,
      vitaminDMcg: (map['vitaminDMcg'] as num?)?.toDouble() ?? 0,
      vitaminK2Mcg: (map['vitaminK2Mcg'] as num?)?.toDouble() ?? 0,
    );
  }
}

String _localizedDetailedName({
  required String baseName,
  required String description,
  required String languageCode,
}) {
  final source = description.toLowerCase();
  if (source == baseName.toLowerCase()) return baseName;

  final isRussian = languageCode == 'ru';
  final details = <String>[];

  void addWhen(bool condition, String uz, String ru) {
    if (condition) details.add(isRussian ? ru : uz);
  }

  // Mahsulotning shakli.
  addWhen(source.contains('juice'), 'sharbati', 'сок');
  addWhen(
    source.contains('puree') || source.contains('mashed'),
    'pyuresi',
    'пюре',
  );
  addWhen(
    source.contains('babyfood') || source.contains('baby food'),
    'bolalar ovqati',
    'детское питание',
  );
  addWhen(source.contains('toddler'), 'kichik bolalar uchun', 'для малышей');
  addWhen(source.contains('powder'), 'kukun', 'порошок');
  addWhen(source.contains('concentrate'), 'konsentrat', 'концентрат');
  addWhen(source.contains('flour'), 'uni', 'мука');
  addWhen(RegExp(r'\bpaste\b').hasMatch(source), 'pastasi', 'паста');
  addWhen(source.contains('sauce'), 'sousi', 'соус');
  addWhen(source.contains('soup'), 'sho‘rva', 'суп');
  addWhen(source.contains('salad'), 'salat', 'салат');
  addWhen(source.contains('muffin'), 'maffin', 'маффин');
  addWhen(
    source.contains('cake') || source.contains('cupcake'),
    'tort yoki keks',
    'торт или кекс',
  );
  addWhen(source.contains('bread'), 'non', 'хлеб');
  addWhen(source.contains('bagel'), 'bublik', 'бублик');
  addWhen(source.contains('pancake'), 'quymoq', 'оладьи');
  addWhen(source.contains('patty'), 'kotlet', 'котлета');
  addWhen(source.contains('biryani'), 'biriyani', 'бирьяни');
  addWhen(source.contains('guacamole'), 'guakamole', 'гуакамоле');
  addWhen(source.contains('egg white'), 'tuxum oqi', 'яичный белок');
  addWhen(source.contains('egg yolk'), 'tuxum sarig‘i', 'яичный желток');
  addWhen(source.contains('egg whole'), 'butun tuxum', 'цельное яйцо');
  addWhen(source.contains('benedict'), 'Benedikt usulida', 'Бенедикт');
  addWhen(source.contains('deviled'), 'to‘ldirilgan', 'фаршированный');
  addWhen(source.contains('creamed'), 'qaymoqli', 'сливочный');

  // Sut mahsulotlari turi va yog‘lilik darajasi.
  final isDairy = RegExp(
    r'\b(milk|yogurt|yoghurt|kefir|cheese|cream|butter|whey|casein|ghee)\b',
  ).hasMatch(source);
  if (isDairy) {
    addWhen(source.contains('cow'), 'sigir sutidan', 'из коровьего молока');
    addWhen(source.contains('goat'), 'echki sutidan', 'из козьего молока');
    addWhen(source.contains('sheep'), 'qo‘y sutidan', 'из овечьего молока');
    addWhen(source.contains('camel'), 'tuya sutidan', 'из верблюжьего молока');
    addWhen(source.contains('human milk'), 'ona suti', 'грудное молоко');
    addWhen(
      source.contains('skim') ||
          source.contains('nonfat') ||
          source.contains('fat free') ||
          source.contains('fat-free'),
      'yog‘siz',
      'обезжиренный',
    );
    addWhen(
      source.contains('lowfat') || source.contains('low fat'),
      'kam yog‘li',
      'нежирный',
    );
    addWhen(
      source.contains('reduced fat'),
      'yog‘i kamaytirilgan',
      'пониженной жирности',
    );
    addWhen(
      source.contains('light') && !source.contains('lowfat'),
      'yengil',
      'лёгкий',
    );
    addWhen(
      RegExp(r'(^|[^0-9])1%([^0-9]|$)').hasMatch(source),
      '1% yog‘li',
      'жирность 1%',
    );
    addWhen(
      RegExp(r'(^|[^0-9])2%([^0-9]|$)').hasMatch(source),
      '2% yog‘li',
      'жирность 2%',
    );
    for (final percent in [3, 4, 5, 10, 15, 20, 25, 30, 33, 35, 40]) {
      addWhen(
        RegExp('(^|[^0-9])$percent%([^0-9]|\$)').hasMatch(source),
        '$percent% yog‘li',
        'жирность $percent%',
      );
    }
    addWhen(
      source.contains('whole') || source.contains('full fat'),
      'to‘liq yog‘li',
      'цельный',
    );
    addWhen(
      source.contains('lactose free') || source.contains('lactose-free'),
      'laktozasiz',
      'без лактозы',
    );
    addWhen(source.contains('plain'), 'tabiiy', 'натуральный');
    addWhen(source.contains('greek'), 'grekcha', 'греческий');
    addWhen(source.contains('skyr'), 'Skyr turi', 'Скир');
    addWhen(source.contains('labneh'), 'Labneh turi', 'Лабне');
    addWhen(source.contains('sour cream'), 'smetana', 'сметана');
    addWhen(source.contains('creme fraiche'), 'krem-fresh', 'крем-фреш');
    addWhen(source.contains('clotted cream'), 'kaymak', 'топлёные сливки');
    addWhen(source.contains('half and half'), 'yarim qaymoq', 'сливки пополам');
    addWhen(source.contains('heavy'), 'quyuq qaymoq', 'жирные сливки');
    addWhen(source.contains('whipping'), 'ko‘pirtirish uchun', 'для взбивания');
    addWhen(source.contains('buttermilk'), 'ayron turi', 'пахта');
    addWhen(source.contains('milkshake'), 'sutli kokteyl', 'молочный коктейль');
    addWhen(
      source.contains('frozen yogurt') ||
          (source.contains('yogurt') && source.contains('frozen')),
      'muzlatilgan yogurt',
      'замороженный йогурт',
    );
    addWhen(source.contains('quark'), 'tvorog turi', 'творожный продукт');
    addWhen(source.contains('vanilla'), 'vanilli', 'ванильный');
    addWhen(source.contains('strawberry'), 'qulupnayli', 'клубничный');
    addWhen(source.contains('chocolate'), 'shokoladli', 'шоколадный');
    addWhen(source.contains('evaporated'), 'bug‘latilgan', 'концентрированный');
    addWhen(source.contains('condensed'), 'quyultirilgan', 'сгущённый');
    addWhen(
      source.contains('dry') || source.contains('powder'),
      'quruq',
      'сухой',
    );
    addWhen(source.contains('cultured'), 'achitilgan', 'кисломолочный');
    final isUltraPasteurized =
        source.contains('ultra-pasteurized') || source.contains('uht');
    addWhen(
      source.contains('pasteurized') && !isUltraPasteurized,
      'pasterizatsiyalangan',
      'пастеризованный',
    );
    addWhen(isUltraPasteurized, 'UHT', 'ультрапастеризованный');
    addWhen(source.contains('processed cheese'), 'eritilgan', 'плавленый');
    addWhen(source.contains('cheese spread'), 'surtiladigan', 'пастообразный');
    addWhen(source.contains('cottage cheese'), 'tvorog', 'творожный');
    addWhen(
      source.contains('cream cheese'),
      'qaymoqli pishloq',
      'сливочный сыр',
    );
    addWhen(source.contains('cheddar'), 'Cheddar turi', 'Чеддер');
    addWhen(source.contains('mozzarella'), 'Mozzarella turi', 'Моцарелла');
    addWhen(source.contains('parmesan'), 'Parmezan turi', 'Пармезан');
    addWhen(source.contains('swiss cheese'), 'Shveysariya turi', 'Швейцарский');
    addWhen(source.contains('monterey'), 'Monterey turi', 'Монтерей');
    addWhen(source.contains('paneer'), 'Paneer turi', 'Панир');
    addWhen(source.contains('ricotta'), 'Rikotta turi', 'Рикотта');
    addWhen(source.contains('feta'), 'Feta turi', 'Фета');
    addWhen(source.contains('shredded'), 'qirg‘ichdan chiqarilgan', 'тёртый');
    addWhen(source.contains('whipped'), 'ko‘pirtirilgan', 'взбитый');
  }

  // Ichimlik turi, brendi va retsept farqlari.
  final isBeverage = RegExp(
    r'\b(beverage|drink|soda|cola|juice|lemonade|water|tea|coffee|beer|wine|vodka|whisky|brandy|rum|gin|tequila)\b',
  ).hasMatch(source);
  if (isBeverage) {
    addWhen(source.contains('coca-cola'), 'Coca-Cola', 'Coca-Cola');
    addWhen(source.contains('pepsi'), 'Pepsi', 'Pepsi');
    addWhen(source.contains('fanta'), 'Fanta', 'Fanta');
    addWhen(source.contains('sprite'), 'Sprite', 'Sprite');
    addWhen(source.contains('mirinda'), 'Mirinda', 'Mirinda');
    addWhen(RegExp(r'\b7up\b').hasMatch(source), '7UP', '7UP');
    addWhen(source.contains('red bull'), 'Red Bull', 'Red Bull');
    addWhen(source.contains('monster'), 'Monster', 'Monster');
    addWhen(
      source.contains('zero sugar') ||
          source.contains('sugar free') ||
          source.contains('sugar-free'),
      'Zero, shakarsiz',
      'Zero, без сахара',
    );
    addWhen(RegExp(r'\bdiet\b').hasMatch(source), 'Diet', 'диетический');
    addWhen(source.contains('classic'), 'Classic', 'классический');
    addWhen(source.contains('original'), 'Original', 'оригинальный');
    addWhen(
      source.contains('caffeine free') || source.contains('caffeine-free'),
      'kofeinsiz',
      'без кофеина',
    );
    addWhen(source.contains('carbonated'), 'gazlangan', 'газированный');
    addWhen(source.contains('sparkling'), 'gazli', 'газированный');
    addWhen(RegExp(r'\bstill\b').hasMatch(source), 'gazsiz', 'негазированный');
    addWhen(source.contains('energy drink'), 'energetik', 'энергетический');
    addWhen(source.contains('sports drink'), 'sport ichimligi', 'спортивный');
    addWhen(source.contains('orange'), 'apelsinli', 'апельсиновый');
    addWhen(source.contains('lemon-lime'), 'limon-laymli', 'лимон-лайм');
    addWhen(source.contains('grape'), 'uzumli', 'виноградный');
    addWhen(source.contains('cherry'), 'gilosli', 'вишнёвый');
  }

  // Tayyorlanish holati. Aniqroq usul umumiy "pishirilgan"dan ustun.
  final hasSpecificCooking =
      source.contains('boiled') ||
      source.contains('steamed') ||
      source.contains('baked') ||
      source.contains('roasted') ||
      source.contains('fried') ||
      source.contains('grilled');
  addWhen(RegExp(r'\braw\b').hasMatch(source), 'xom', 'сырой');
  addWhen(source.contains('fresh'), 'yangi', 'свежий');
  addWhen(
    source.contains('boiled') && !source.contains('hard-boiled'),
    'qaynatilgan',
    'варёный',
  );
  addWhen(source.contains('steamed'), 'bug‘da pishirilgan', 'на пару');
  addWhen(source.contains('baked'), 'pechda pishirilgan', 'запечённый');
  addWhen(source.contains('roasted'), 'qovurib pishirilgan', 'жареный');
  addWhen(source.contains('fried'), 'yog‘da qovurilgan', 'обжаренный');
  addWhen(source.contains('grilled'), 'grilda pishirilgan', 'на гриле');
  addWhen(source.contains('stewed'), 'dimlangan', 'тушёный');
  addWhen(
    source.contains('scrambled'),
    'aralashtirib qovurilgan',
    'омлет-болтунья',
  );
  addWhen(source.contains('poached'), 'suvda pishirilgan', 'пашот');
  addWhen(source.contains('hard-boiled'), 'qattiq qaynatilgan', 'вкрутую');
  addWhen(source.contains('glazed'), 'glazur bilan', 'глазированный');
  addWhen(
    source.contains('scalloped'),
    'sousda pishirilgan',
    'запечённый в соусе',
  );
  addWhen(
    source.contains('cooked') && !hasSpecificCooking,
    'pishirilgan',
    'приготовленный',
  );
  addWhen(source.contains('unprepared'), 'pishirilmagan', 'неприготовленный');

  // Saqlash va qayta ishlash turi.
  addWhen(
    source.contains('frozen') &&
        !source.contains('frozen yogurt') &&
        !(source.contains('yogurt') && source.contains('frozen')),
    'muzlatilgan',
    'замороженный',
  );
  addWhen(source.contains('canned'), 'konservalangan', 'консервированный');
  addWhen(
    source.contains('dehydrated') || source.contains('dried'),
    'quritilgan',
    'сушёный',
  );
  addWhen(source.contains('pickled'), 'marinadlangan', 'маринованный');
  addWhen(source.contains('drained'), 'suvi to‘kilgan', 'без жидкости');
  addWhen(
    source.contains('unpeeled') || source.contains('with skin'),
    'po‘sti bilan',
    'с кожурой',
  );
  addWhen(
    source.contains('peeled') && !source.contains('unpeeled'),
    'archilgan',
    'очищенный',
  );
  addWhen(source.contains('chopped'), 'to‘g‘ralgan', 'нарезанный');
  addWhen(source.contains('sliced'), 'tilimlangan', 'ломтиками');
  addWhen(source.contains('ground'), 'qiymalangan', 'измельчённый');
  addWhen(source.contains('organic'), 'organik', 'органический');
  addWhen(source.contains('roma'), 'Roma navi', 'сорт Рома');
  addWhen(source.contains('nfs'), 'turi ko‘rsatilmagan', 'вид не указан');

  // Go‘sht va parranda qismi.
  addWhen(source.contains('breast'), 'ko‘krak qismi', 'грудка');
  addWhen(source.contains('thigh'), 'son qismi', 'бедро');
  addWhen(source.contains('wing'), 'qanot', 'крыло');
  addWhen(source.contains('drumstick'), 'boldir', 'голень');
  addWhen(source.contains('skin'), 'terisi', 'кожа');
  addWhen(source.contains('feet'), 'oyoq qismi', 'лапки');
  addWhen(RegExp(r'(^|, )back(,|$)').hasMatch(source), 'orqa qismi', 'спинка');

  // Qo‘shimchalar.
  final isSaltFree =
      source.contains('without salt') ||
      source.contains('no salt') ||
      source.contains('unsalted');
  addWhen(isSaltFree, 'tuzsiz', 'без соли');
  addWhen(
    !isSaltFree && (source.contains('with salt') || source.contains('salted')),
    'tuzli',
    'с солью',
  );
  addWhen(source.contains('unsweetened'), 'shakarsiz', 'без сахара');
  addWhen(
    source.contains('sweetened') && !source.contains('unsweetened'),
    'shakar qo‘shilgan',
    'с сахаром',
  );

  final normalizedBase = baseName.trim().toLowerCase();
  final uniqueDetails = details
      .toSet()
      .where((detail) => detail.toLowerCase() != normalizedBase)
      .toList(growable: false);
  if (uniqueDetails.isEmpty) return baseName;
  return '$baseName — ${uniqueDetails.join(', ')}';
}
