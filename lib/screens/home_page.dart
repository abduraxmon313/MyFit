import '../theme/app_theme.dart';
import '../widgets/app_ui.dart';
import '../widgets/profile_avatar.dart';
import 'package:flutter/material.dart';

import '../models/food_nutrition.dart';
import '../models/user_profile.dart';
import '../l10n/app_localizations.dart';
import '../services/auth_service.dart';
import '../services/food_data_service.dart';
import '../services/food_log_service.dart';
import '../services/food_vision_service.dart';
import '../services/open_food_facts_service.dart';
import '../services/profile_service.dart';
import 'barcode_scanner_page.dart';
import 'calculator_page.dart';
import 'food_scan_page.dart';
import 'recipe_builder_page.dart';
import 'meals_page.dart';
import 'food_history_page.dart';
import 'reports_page.dart';
import 'national_food_picker_page.dart';
import 'profile_page.dart';
import 'lessons_page.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    required this.authService,
    required this.profile,
    this.onLocaleChanged,
    this.onThemeChanged,
    this.foodLogService,
  });

  final AuthService authService;
  final UserProfile profile;
  final ValueChanged<String>? onLocaleChanged;
  final ValueChanged<String>? onThemeChanged;
  final FoodLogService? foodLogService;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _visionService = FoodVisionService();
  final _foodDataService = FoodDataService();
  late final _foodLogService = widget.foodLogService ?? FoodLogService();
  final _openFoodFactsService = OpenFoodFactsService();
  final _profileService = ProfileService();
  final List<FoodNutrition> _foods = [];
  Map<DateTime, double> _weekCalories = {};
  bool _loadingLog = true;
  bool _logLoadFailed = false;
  int _navIndex = 0;

  double get _calories =>
      _foods.fold(0, (total, food) => total + food.calories);
  double get _protein => _foods.fold(0, (total, food) => total + food.protein);
  double get _carbs =>
      _foods.fold(0, (total, food) => total + food.carbohydrates);
  double get _fat => _foods.fold(0, (total, food) => total + food.fat);
  double get _fiber => _foods.fold(0, (total, food) => total + food.fiber);

  String _greeting(BuildContext context) {
    final hour = DateTime.now().hour;
    if (hour < 12) return context.tr('Xayrli tong,');
    if (hour < 18) return context.tr('Xayrli kun,');
    return context.tr('Xayrli kech,');
  }

  double get _targetCalories {
    final profile = widget.profile;
    final genderOffset = profile.gender == 'male' ? 5 : -161;
    final bmr =
        10 * profile.weightKg +
        6.25 * profile.heightCm -
        5 * profile.age +
        genderOffset;
    final activity = switch (profile.activityLevel) {
      'low' => 1.2,
      'high' => 1.725,
      _ => 1.55,
    };
    final goalOffset = switch (profile.goal) {
      'lose' => -400,
      'gain' => 350,
      _ => 0,
    };
    return (bmr * activity + goalOffset).clamp(1200, 4500);
  }

  @override
  void initState() {
    super.initState();
    _loadFoods();
  }

  Future<void> _loadFoods() async {
    setState(() {
      _loadingLog = true;
      _logLoadFailed = false;
    });
    final uid = widget.authService.currentUser?.uid;
    if (uid == null) {
      setState(() => _loadingLog = false);
      return;
    }
    try {
      final results = await Future.wait([
        _foodLogService.loadToday(uid),
        _foodLogService.loadCurrentWeekCalories(uid),
      ]);
      final foods = results[0] as List<FoodNutrition>;
      final weekCalories = results[1] as Map<DateTime, double>;
      if (!mounted) return;
      setState(() {
        _foods
          ..clear()
          ..addAll(foods);
        _weekCalories = weekCalories;
        _loadingLog = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadingLog = false;
        _logLoadFailed = true;
      });
    }
  }

  Future<bool> _persistFoods() async {
    final uid = widget.authService.currentUser?.uid;
    if (uid == null) return false;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    setState(() => _weekCalories[today] = _calories);
    try {
      await _foodLogService.saveToday(uid, _foods);
      return true;
    } catch (_) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.tr('Saqlash amalga oshmadi. Qayta urinib ko‘ring.'),
          ),
          action: SnackBarAction(
            label: context.tr('Qayta urinish'),
            onPressed: _persistFoods,
          ),
        ),
      );
      return false;
    }
  }

  Future<void> _saveProfile(UserProfile profile) async {
    final uid = widget.authService.currentUser?.uid;
    if (uid == null) throw StateError('Foydalanuvchi topilmadi');
    await _profileService.saveProfile(uid, profile);
  }

  void _showFoodAddedMessage(FoodNutrition food) =>
      _showFoodsAddedMessage([food]);

  void _showFoodsAddedMessage(List<FoodNutrition> foods) {
    final messenger = ScaffoldMessenger.of(context);
    final languageCode = Localizations.localeOf(context).languageCode;
    final food = foods.first;
    final grams = foods.fold<double>(0, (sum, item) => sum + item.grams);
    final calories = foods.fold<double>(0, (sum, item) => sum + item.calories);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        padding: EdgeInsets.zero,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 92),
        duration: const Duration(seconds: 3),
        dismissDirection: DismissDirection.horizontal,
        content: _FoodAddedToast(
          foodName: foods.length == 1
              ? food.displayNameFor(languageCode)
              : context.tr('{count} ta mahsulot', {'count': foods.length}),
          details:
              '${grams.round()} ${context.tr(food.basisUnit)}  •  '
              '${calories.round()} ${context.tr('kcal')}',
          onClose: messenger.hideCurrentSnackBar,
        ),
      ),
    );
  }

  Future<void> _addFood() async {
    final food = await Navigator.push<FoodNutrition>(
      context,
      MaterialPageRoute(builder: (_) => FoodScanPage(service: _visionService)),
    );
    if (food != null && mounted) {
      setState(() => _foods.add(food));
      final saved = await _persistFoods();
      if (!mounted || !saved) return;
      _showFoodAddedMessage(food);
    }
  }

  Future<void> _createRecipe() async {
    await Navigator.push<FoodNutrition>(
      context,
      MaterialPageRoute(
        builder: (_) => RecipeBuilderPage(foodDataService: _foodDataService),
      ),
    );
  }

  Future<void> _scanBarcode() async {
    final food = await Navigator.push<FoodNutrition>(
      context,
      MaterialPageRoute(
        builder: (_) => BarcodeScannerPage(service: _openFoodFactsService),
      ),
    );
    if (food == null || !mounted) return;
    setState(() => _foods.add(food));
    final saved = await _persistFoods();
    if (!mounted || !saved) return;
    _showFoodAddedMessage(food);
  }

  Future<void> _removeFood(int index) async {
    setState(() => _foods.removeAt(index));
    await _persistFoods();
  }

  Future<void> _removeMealFood(FoodNutrition food) async {
    final index = _foods.indexOf(food);
    if (index < 0) return;
    await _removeFood(index);
  }

  Future<void> _selectMeal(MealType meal) async {
    final foods = await Navigator.push<List<FoodNutrition>>(
      context,
      MaterialPageRoute(builder: (_) => NationalFoodPickerPage(meal: meal)),
    );
    if (foods == null || foods.isEmpty || !mounted) return;
    final mealFoods = [for (final food in foods) food.withMealType(meal.name)];
    setState(() => _foods.addAll(mealFoods));
    final saved = await _persistFoods();
    if (!mounted || !saved) return;
    _showFoodsAddedMessage(mealFoods);
  }

  void _openFoodHistory(DateTime day) {
    final uid = widget.authService.currentUser?.uid;
    if (uid == null) return;
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => FoodHistoryPage(
          uid: uid,
          initialDate: day,
          service: _foodLogService,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Widget page = _navIndex == 4
        ? ReportsPage(
            uid: widget.authService.currentUser?.uid ?? '',
            service: _foodLogService,
            dailyTarget: _targetCalories,
          )
        : _loadingLog
        ? const Center(child: CircularProgressIndicator())
        : _logLoadFailed
        ? Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(LucideIcons.cloudOff, size: 40),
                  const SizedBox(height: 16),
                  Text(
                    context.tr('Kundalikni yuklab bo‘lmadi.'),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _loadFoods,
                    icon: const Icon(LucideIcons.refreshCw),
                    label: Text(context.tr('Qayta urinish')),
                  ),
                ],
              ),
            ),
          )
        : _navIndex == 1
        ? MealsPage(
            onDateSelected: _openFoodHistory,
            onMealSelected: _selectMeal,
            dailyTarget: _targetCalories,
            weekCalories: _weekCalories,
            calories: _calories,
            protein: _protein,
            carbohydrates: _carbs,
            fat: _fat,
            fiber: _fiber,
            foods: _foods,
            onFoodRemoved: _removeMealFood,
          )
        : _navIndex == 2
        ? const LessonsPage()
        : _navIndex == 3
        ? ProfilePage(
            profile: widget.profile,
            phoneNumber: widget.authService.currentUser?.phoneNumber ?? '',
            onSave: _saveProfile,
            onPhotoUpload: (bytes) {
              final uid = widget.authService.currentUser?.uid;
              if (uid == null) {
                throw StateError('Foydalanuvchi topilmadi');
              }
              return _profileService.uploadProfilePhoto(
                uid: uid,
                bytes: bytes,
                fileName: 'avatar.png',
              );
            },
            onPhotoRemove: () {
              final uid = widget.authService.currentUser?.uid;
              if (uid == null) {
                throw StateError('Foydalanuvchi topilmadi');
              }
              return _profileService.removeProfilePhoto(uid);
            },
            onSignOut: widget.authService.signOut,
            onLocaleChanged: widget.onLocaleChanged ?? (_) {},
            onThemeChanged: widget.onThemeChanged,
          )
        : _Dashboard(
            header: _HomeHeader(
              greeting: _greeting(context),
              profile: widget.profile,
              onProfileTap: () => setState(() => _navIndex = 3),
            ),
            profile: widget.profile,
            calories: _calories,
            target: _targetCalories,
            protein: _protein,
            carbs: _carbs,
            fat: _fat,
            actions: [
              _ActionCard(
                icon: LucideIcons.scanLine,
                accent: AppPalette.accentTeal,
                title: context.tr('Ovqatni skanerlash'),
                onTap: _addFood,
              ),
              _ActionCard(
                icon: LucideIcons.scanBarcode,
                accent: AppPalette.accentBlue,
                title: context.tr('Shtrix-kod skaneri'),
                onTap: _scanBarcode,
              ),
              _ActionCard(
                icon: LucideIcons.chefHat,
                accent: AppPalette.accentIndigo,
                title: context.tr('Ovqat qo‘shish'),
                onTap: _createRecipe,
              ),
              _ActionCard(
                icon: LucideIcons.calculator,
                accent: AppPalette.accentAmber,
                title: context.tr('Kalkulyator'),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => const CalculatorPage(),
                    ),
                  );
                },
              ),
            ],
          );
    // Profil pastki menyuda emas: unga bosh sahifadagi avatar orqali kiriladi.
    // _navIndex: 0 bosh sahifa, 1 ovqatlar, 2 mashqlar, 3 profil, 4 hisobotlar.
    const pageForTab = [0, 1, 2, 4];
    final destinations = [
      (LucideIcons.house, context.tr('Bosh sahifa')),
      (LucideIcons.utensils, context.tr('Ovqatlar')),
      (LucideIcons.graduationCap, context.tr('Darslar')),
      (LucideIcons.chartColumn, context.tr('Hisobotlar')),
    ];
    final selectedTab = _navIndex == 3 ? 0 : pageForTab.indexOf(_navIndex);
    final Widget body = _navIndex == 3
        ? Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
                child: Row(
                  children: [
                    TextButton.icon(
                      key: const Key('profile-back'),
                      onPressed: () => setState(() => _navIndex = 0),
                      icon: const Icon(LucideIcons.chevronLeft, size: 18),
                      label: Text(context.tr('Bosh sahifa')),
                    ),
                  ],
                ),
              ),
              Expanded(child: page),
            ],
          )
        : page;
    final wide = MediaQuery.sizeOf(context).width >= 900;
    final scheme = Theme.of(context).colorScheme;
    void select(int index) => setState(() => _navIndex = pageForTab[index]);
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: wide
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  NavigationRail(
                    selectedIndex: selectedTab,
                    onDestinationSelected: select,
                    labelType: NavigationRailLabelType.all,
                    minWidth: 88,
                    groupAlignment: -.9,
                    leading: Padding(
                      padding: const EdgeInsets.only(top: 8, bottom: 20),
                      child: AppIconTile(
                        icon: LucideIcons.activity,
                        size: 40,
                        color: scheme.onPrimary,
                        background: scheme.primary,
                      ),
                    ),
                    destinations: [
                      for (final (icon, label) in destinations)
                        NavigationRailDestination(
                          icon: Icon(icon),
                          label: Text(label),
                        ),
                    ],
                  ),
                  VerticalDivider(width: 1, color: scheme.outlineVariant),
                  Expanded(child: body),
                ],
              )
            : Column(
                children: [
                  Expanded(child: body),
                  Divider(height: 1, color: scheme.outlineVariant),
                  NavigationBar(
                    selectedIndex: selectedTab,
                    onDestinationSelected: select,
                    destinations: [
                      for (final (icon, label) in destinations)
                        NavigationDestination(icon: Icon(icon), label: label),
                    ],
                  ),
                ],
              ),
      ),
    );
  }
}

class _HomeHeader extends StatelessWidget {
  const _HomeHeader({
    required this.greeting,
    required this.profile,
    required this.onProfileTap,
  });

  final String greeting;
  final UserProfile profile;
  final VoidCallback onProfileTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final name = profile.firstName.trim().isEmpty
        ? context.tr('Profil')
        : profile.firstName.trim();
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                greeting.replaceAll(',', ''),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: scheme.onSurfaceVariant,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: scheme.onSurface,
                  fontSize: 22,
                  height: 1.15,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -.5,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Tooltip(
          message: context.tr('Profil'),
          child: Semantics(
            button: true,
            label: context.tr('Profil'),
            child: Material(
              color: Colors.transparent,
              shape: const CircleBorder(),
              child: InkWell(
                key: const Key('home-profile'),
                onTap: onProfileTap,
                customBorder: const CircleBorder(),
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: scheme.outlineVariant),
                  ),
                  child: ProfileAvatar(
                    name: profile.fullName,
                    photoUrl: profile.photoUrl,
                    size: 40,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Home tab layout. Two columns on tablets/desktop, one column on phones.
class _Dashboard extends StatelessWidget {
  const _Dashboard({
    required this.header,
    required this.profile,
    required this.calories,
    required this.target,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.actions,
  });

  final Widget header;
  final UserProfile profile;
  final double calories;
  final double target;
  final double protein;
  final double carbs;
  final double fat;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 760;
        final horizontal = constraints.maxWidth >= 1100 ? 40.0 : 20.0;
        final body = _BodyStatusCard(profile: profile);
        final today = _TodaySummaryCard(
          calories: calories,
          target: target,
          protein: protein,
          carbs: carbs,
          fat: fat,
        );
        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(horizontal, 16, horizontal, 32),
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: wide ? 1080 : 520),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  header,
                  const SizedBox(height: 20),
                  if (wide)
                    IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(child: body),
                          const SizedBox(width: 16),
                          Expanded(child: today),
                        ],
                      ),
                    )
                  else ...[
                    body,
                    const SizedBox(height: 12),
                    today,
                  ],
                  const SizedBox(height: 28),
                  AppSectionHeader(title: context.tr('Tezkor amallar')),
                  const SizedBox(height: 12),
                  GridView.count(
                    crossAxisCount: wide ? actions.length : 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    mainAxisExtent:
                        118 +
                        (MediaQuery.textScalerOf(context).scale(14) - 14) * 3,
                    children: wide || actions.length.isEven
                        ? actions
                        : actions.sublist(0, actions.length - 1),
                  ),
                  // Toq sonli amallarning oxirgisi telefonda to'liq kenglikda.
                  if (!wide && actions.length.isOdd) ...[
                    const SizedBox(height: 12),
                    actions.last,
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _BodyStatusCard extends StatelessWidget {
  const _BodyStatusCard({required this.profile});

  final UserProfile profile;

  double get _bmi {
    final heightMeters = profile.heightCm / 100;
    if (heightMeters <= 0) return 0;
    return profile.weightKg / (heightMeters * heightMeters);
  }

  String _bodyStatus(BuildContext context) {
    if (_bmi <= 0) return context.tr('Ma’lumot kutilmoqda');
    if (_bmi < 18.5) return context.tr('Yengil tana');
    if (_bmi < 25) return context.tr('Muvozanatli');
    if (_bmi < 30) return context.tr('Kuchli tana');
    return context.tr('Yuqori vazn');
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bmi = _bmi;
    final statusColor = bmi <= 0
        ? scheme.onSurfaceVariant
        : bmi < 18.5 || bmi >= 25
        ? AppPalette.warning
        : AppPalette.success;
    return AppCard(
      padding: const EdgeInsets.all(20),
      child: Semantics(
        label:
            'Bo‘y ${profile.heightCm.round()} santimetr, '
            'vazn ${profile.weightKg.toStringAsFixed(1)} kilogramm, '
            'BMI ${bmi.toStringAsFixed(1)}',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppOverline(context.tr('TANA DINAMIKASI')),
                      const SizedBox(height: 6),
                      Text(
                        context.tr('Bugungi holatingiz'),
                        style: TextStyle(
                          color: scheme.onSurface,
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -.3,
                        ),
                      ),
                    ],
                  ),
                ),
                _StatusPill(label: _bodyStatus(context), color: statusColor),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                _Metric(
                  label: context.tr('Vazn'),
                  value: profile.weightKg.toStringAsFixed(1),
                  unit: context.tr('kg'),
                ),
                _MetricDivider(),
                _Metric(
                  label: context.tr('Bo‘y'),
                  value: profile.heightCm.round().toString(),
                  unit: context.tr('cm'),
                ),
                _MetricDivider(),
                _Metric(
                  label: context.tr('BMI'),
                  value: bmi.toStringAsFixed(1),
                  unit: '',
                ),
              ],
            ),
            const SizedBox(height: 20),
            _BmiScale(bmi: bmi),
          ],
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      constraints: const BoxConstraints(maxWidth: 150),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.xs),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: scheme.onSurface,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value, required this.unit});

  final String label;
  final String value;
  final String unit;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: scheme.onSurfaceVariant,
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: value,
                    style: TextStyle(
                      color: scheme.onSurface,
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -.6,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  if (unit.isNotEmpty)
                    TextSpan(
                      text: ' $unit',
                      style: TextStyle(
                        color: scheme.onSurfaceVariant,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    width: 1,
    height: 36,
    margin: const EdgeInsets.symmetric(horizontal: 16),
    color: Theme.of(context).colorScheme.outlineVariant,
  );
}

/// WHO BMI bands (16–40 range) with a marker for the current value.
class _BmiScale extends StatelessWidget {
  const _BmiScale({required this.bmi});

  final double bmi;

  static const _min = 16.0;
  static const _max = 40.0;
  static const _bands = [
    (18.5, Color(0xFF8FB3F5)),
    (25.0, AppPalette.success),
    (30.0, AppPalette.warning),
    (_max, AppPalette.danger),
  ];

  /// Integer flex in thousandths of the 16–40 range, so bands, marker and
  /// labels all use exactly the same horizontal mapping.
  static int _flex(double from, double to) =>
      ((to.clamp(_min, _max) - from.clamp(_min, _max)) / (_max - _min) * 1000)
          .round();

  static String _label(double value) => value == value.roundToDouble()
      ? value.round().toString()
      : value.toString();

  /// Zero-width anchor: [child] is centred exactly on this point of the row.
  static Widget _anchor(Widget child, {double width = 48}) => SizedBox(
    width: 0,
    child: OverflowBox(
      minWidth: 0,
      maxWidth: width,
      alignment: Alignment.center,
      child: child,
    ),
  );

  static Widget _spacer(int flex) =>
      flex <= 0 ? const SizedBox.shrink() : Spacer(flex: flex);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final value = bmi.clamp(_min, _max);
    final labelStyle = TextStyle(
      color: scheme.onSurfaceVariant,
      fontSize: 11,
      height: 1.2,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    Text label(double v) =>
        Text(_label(v), key: Key('bmi-label-${_label(v)}'), style: labelStyle);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 18,
          child: Stack(
            children: [
              Positioned.fill(
                child: Row(
                  children: [
                    for (var i = 0; i < _bands.length; i++)
                      Expanded(
                        key: Key('bmi-band-$i'),
                        flex: _flex(
                          i == 0 ? _min : _bands[i - 1].$1,
                          _bands[i].$1,
                        ),
                        child: Container(
                          height: 6,
                          margin: const EdgeInsets.symmetric(horizontal: 1),
                          decoration: BoxDecoration(
                            color: _bands[i].$2.withValues(alpha: .85),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              if (bmi > 0)
                Positioned.fill(
                  child: Padding(
                    // Keep the 14 px marker fully visible at both ends.
                    padding: const EdgeInsets.symmetric(horizontal: 7),
                    child: Row(
                      children: [
                        _spacer(_flex(_min, value)),
                        _anchor(
                          Container(
                            key: const Key('bmi-marker'),
                            width: 14,
                            height: 14,
                            decoration: BoxDecoration(
                              color: scheme.surfaceContainerLowest,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: scheme.onSurface,
                                width: 3,
                              ),
                            ),
                          ),
                        ),
                        _spacer(_flex(value, _max)),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 14,
          child: Stack(
            children: [
              Align(alignment: Alignment.centerLeft, child: label(_min)),
              Align(alignment: Alignment.centerRight, child: label(_max)),
              // Interior boundaries are centred under the band edges.
              Positioned.fill(
                child: Row(
                  children: [
                    for (var i = 0; i < _bands.length - 1; i++) ...[
                      Spacer(
                        flex: _flex(
                          i == 0 ? _min : _bands[i - 1].$1,
                          _bands[i].$1,
                        ),
                      ),
                      _anchor(label(_bands[i].$1)),
                    ],
                    Spacer(flex: _flex(_bands[_bands.length - 2].$1, _max)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TodaySummaryCard extends StatelessWidget {
  const _TodaySummaryCard({
    required this.calories,
    required this.target,
    required this.protein,
    required this.carbs,
    required this.fat,
  });

  final double calories;
  final double target;
  final double protein;
  final double carbs;
  final double fat;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final safeTarget = target <= 0 ? 1.0 : target;
    final progress = (calories / safeTarget).clamp(0.0, 1.0);
    final remaining = (target - calories).clamp(0, double.infinity);
    Widget macro(String label, double value, Color color) => Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  context.tr(label),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: scheme.onSurfaceVariant,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${value.toStringAsFixed(value < 10 ? 1 : 0)} ${context.tr('g')}',
            style: TextStyle(
              color: scheme.onSurface,
              fontSize: 15,
              fontWeight: FontWeight.w600,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
    return AppCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppOverline(context.tr('Kaloriya')),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                calories.round().toString(),
                style: TextStyle(
                  color: scheme.onSurface,
                  fontSize: 30,
                  height: 1,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -1,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Text(
                    '/ ${target.round()} ${context.tr('kcal')}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: scheme.onSurfaceVariant,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
              Text(
                '${(progress * 100).round()}%',
                style: TextStyle(
                  color: scheme.primary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: progress),
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeOutCubic,
              builder: (_, value, _) =>
                  LinearProgressIndicator(value: value, minHeight: 6),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${context.tr('Qoldi')}: ${remaining.round()} ${context.tr('kcal')}',
            style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12.5),
          ),
          const SizedBox(height: 18),
          Divider(height: 1, color: scheme.outlineVariant),
          const SizedBox(height: 16),
          Row(
            children: [
              macro('Oqsil', protein, AppPalette.protein),
              macro('Uglevod', carbs, AppPalette.carbs),
              macro('Yog‘', fat, AppPalette.fat),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.icon,
    required this.accent,
    required this.title,
    required this.onTap,
  });

  final IconData icon;
  final Color accent;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final titleText = Text(
      title,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: scheme.onSurface,
        fontSize: 14,
        height: 1.25,
        fontWeight: FontWeight.w600,
        letterSpacing: -.1,
      ),
    );
    final arrow = Icon(
      LucideIcons.arrowUpRight,
      size: 16,
      color: scheme.onSurfaceVariant,
    );
    final tile = AppIconTile.tinted(icon: icon, size: 38, accent: accent);
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Grid cells have a bounded height; the standalone row does not.
          if (!constraints.hasBoundedHeight) {
            return Row(
              children: [
                tile,
                const SizedBox(width: 14),
                Expanded(child: titleText),
                arrow,
              ],
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [tile, const Spacer(), arrow],
              ),
              const Spacer(),
              titleText,
            ],
          );
        },
      ),
    );
  }
}

class _FoodAddedToast extends StatelessWidget {
  const _FoodAddedToast({
    required this.foodName,
    required this.details,
    required this.onClose,
  });

  final String foodName;
  final String details;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: scheme.outlineVariant),
        boxShadow: AppShadows.raised,
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppPalette.success.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: const Icon(
              LucideIcons.check,
              color: AppPalette.success,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr('Ovqat muvaffaqiyatli qo‘shildi'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: scheme.onSurface,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$foodName  ·  $details',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: scheme.onSurfaceVariant,
                    fontSize: 12.5,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onClose,
            tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
            icon: const Icon(LucideIcons.x, size: 18),
          ),
        ],
      ),
    );
  }
}
