import '../theme/app_theme.dart';
import '../widgets/profile_avatar.dart';
import 'package:flutter/material.dart';

import '../models/food_nutrition.dart';
import '../models/user_profile.dart';
import '../models/workout.dart';
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
import 'food_search_page.dart';
import 'meals_page.dart';
import 'food_history_page.dart';
import 'reports_page.dart';
import 'national_food_picker_page.dart';
import 'profile_page.dart';
import 'workouts_page.dart';

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
  static const _navy = Color(0xFF10223C);

  final _visionService = FoodVisionService();
  final _foodDataService = FoodDataService();
  late final _foodLogService = widget.foodLogService ?? FoodLogService();
  final _openFoodFactsService = OpenFoodFactsService();
  final _profileService = ProfileService();
  final List<FoodNutrition> _foods = [];
  final List<WorkoutLog> _workouts = [];
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

  void _showFoodAddedMessage(FoodNutrition food) {
    final messenger = ScaffoldMessenger.of(context);
    final languageCode = Localizations.localeOf(context).languageCode;
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
          foodName: food.displayNameFor(languageCode),
          details:
              '${food.grams.round()} ${context.tr(food.basisUnit)}  •  '
              '${food.calories.round()} ${context.tr('kcal')}',
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

  Future<void> _searchFood() async {
    final food = await Navigator.push<FoodNutrition>(
      context,
      MaterialPageRoute(
        builder: (_) => FoodSearchPage(service: _foodDataService),
      ),
    );
    if (food != null && mounted) {
      setState(() => _foods.add(food));
      final saved = await _persistFoods();
      if (!mounted || !saved) return;
      _showFoodAddedMessage(food);
    }
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
    final food = await Navigator.push<FoodNutrition>(
      context,
      MaterialPageRoute(builder: (_) => NationalFoodPickerPage(meal: meal)),
    );
    if (food == null || !mounted) return;
    final mealFood = food.withMealType(meal.name);
    setState(() => _foods.add(mealFood));
    final saved = await _persistFoods();
    if (!mounted || !saved) return;
    _showFoodAddedMessage(mealFood);
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
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: _navIndex == 4
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
                            const Icon(Icons.cloud_off_outlined, size: 40),
                            const SizedBox(height: 16),
                            Text(
                              context.tr('Kundalikni yuklab bo‘lmadi.'),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            FilledButton.icon(
                              onPressed: _loadFoods,
                              icon: const Icon(Icons.refresh_rounded),
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
                  ? WorkoutsPage(
                      weightKg: widget.profile.weightKg,
                      logs: _workouts,
                      onAdded: (workout) =>
                          setState(() => _workouts.add(workout)),
                      onRemoved: (index) =>
                          setState(() => _workouts.removeAt(index)),
                    )
                  : _navIndex == 3
                  ? ProfilePage(
                      profile: widget.profile,
                      phoneNumber:
                          widget.authService.currentUser?.phoneNumber ?? '',
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
                  : SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(22, 14, 22, 28),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 440),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _HomeHeader(
                                greeting: _greeting(context),
                                profile: widget.profile,
                                onProfileTap: () {
                                  setState(() => _navIndex = 3);
                                },
                                onSignOut: widget.authService.signOut,
                              ),
                              const SizedBox(height: 14),
                              _BodyStatusCard(profile: widget.profile),
                              const SizedBox(height: 24),
                              Text(
                                context.tr('Tezkor amallar'),
                                style: TextStyle(
                                  color: context.appColor(
                                    _navy,
                                    surface: false,
                                  ),
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -.2,
                                ),
                              ),
                              const SizedBox(height: 12),
                              GridView.count(
                                crossAxisCount: 2,
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                mainAxisSpacing: 12,
                                crossAxisSpacing: 12,
                                mainAxisExtent:
                                    164 +
                                    (MediaQuery.textScalerOf(
                                              context,
                                            ).scale(15) -
                                            15) *
                                        4,
                                children: [
                                  _ActionCard(
                                    asset: 'assets/quick_actions/food_scan.png',
                                    title: context.tr('Ovqatni skanerlash'),
                                    tint: context.appColor(
                                      Color(0xFFE8F8EF),
                                      surface: true,
                                    ),
                                    accent: context.appColor(
                                      Color(0xFF0AA758),
                                      surface: true,
                                    ),
                                    onTap: _addFood,
                                  ),
                                  _ActionCard(
                                    asset:
                                        'assets/quick_actions/barcode_scan.png',
                                    title: context.tr('Shtrix-kod skaneri'),
                                    tint: context.appColor(
                                      Color(0xFFEAF7F1),
                                      surface: true,
                                    ),
                                    accent: context.appColor(
                                      Color(0xFF168D62),
                                      surface: true,
                                    ),
                                    onTap: _scanBarcode,
                                  ),
                                  _ActionCard(
                                    asset:
                                        'assets/quick_actions/food_search.png',
                                    title: context.tr('Ovqat qidirish'),
                                    tint: context.appColor(
                                      Color(0xFFEEF5E9),
                                      surface: true,
                                    ),
                                    accent: context.appColor(
                                      Color(0xFF668D3B),
                                      surface: true,
                                    ),
                                    onTap: _searchFood,
                                  ),
                                  _ActionCard(
                                    asset:
                                        'assets/quick_actions/calculator.png',
                                    title: context.tr('Kalkulyator'),
                                    tint: context.appColor(
                                      Color(0xFFF3F5E6),
                                      surface: true,
                                    ),
                                    accent: context.appColor(
                                      Color(0xFF809039),
                                      surface: true,
                                    ),
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute<void>(
                                          builder: (_) =>
                                              const CalculatorPage(),
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                height: 104,
                                child: _ActionCard(
                                  asset: 'assets/quick_actions/workout.png',
                                  title: context.tr('Mashq qo‘shish'),
                                  tint: context.appColor(
                                    Color(0xFFE9F7ED),
                                    surface: true,
                                  ),
                                  accent: context.appColor(
                                    Color(0xFF178C4F),
                                    surface: true,
                                  ),
                                  horizontal: true,
                                  onTap: () => setState(() => _navIndex = 2),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
            ),
            NavigationBar(
              selectedIndex: _navIndex,
              onDestinationSelected: (index) {
                setState(() => _navIndex = index);
              },
              indicatorColor: Theme.of(context).colorScheme.primaryContainer,
              destinations: [
                NavigationDestination(
                  icon: Icon(Icons.home_outlined),
                  selectedIcon: Icon(
                    Icons.home_outlined,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  label: context.tr('Bosh sahifa'),
                ),
                NavigationDestination(
                  icon: Icon(Icons.restaurant_outlined),
                  selectedIcon: Icon(
                    Icons.restaurant_outlined,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  label: context.tr('Ovqatlar'),
                ),
                NavigationDestination(
                  icon: Icon(Icons.fitness_center_outlined),
                  selectedIcon: Icon(
                    Icons.fitness_center_outlined,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  label: context.tr('Mashqlar'),
                ),
                NavigationDestination(
                  icon: Icon(Icons.person_outline),
                  selectedIcon: Icon(
                    Icons.person_outline,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  label: context.tr('Profil'),
                ),
                NavigationDestination(
                  icon: Icon(Icons.bar_chart_outlined),
                  selectedIcon: Icon(Icons.bar_chart_rounded),
                  label: context.tr('Hisobotlar'),
                ),
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
    required this.onSignOut,
  });

  final String greeting;
  final UserProfile profile;
  final VoidCallback onProfileTap;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 10, 8, 10),
      decoration: BoxDecoration(
        color: context.appColor(Colors.white, surface: true),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: context.appColor(Color(0xFFE4E9EE), surface: true),
        ),
        boxShadow: Theme.of(context).brightness == Brightness.dark
            ? const []
            : const [
                BoxShadow(
                  color: Color(0x0A0F1B2D),
                  blurRadius: 18,
                  offset: Offset(0, 6),
                ),
              ],
      ),
      child: Row(
        children: [
          Semantics(
            button: true,
            label: context.tr('Profil'),
            child: InkWell(
              onTap: onProfileTap,
              customBorder: const CircleBorder(),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 58,
                    height: 58,
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: context.appPanelColors,
                      ),
                      boxShadow: Theme.of(context).brightness == Brightness.dark
                          ? const []
                          : const [
                              BoxShadow(
                                color: Color(0x3312B75A),
                                blurRadius: 14,
                                offset: Offset(0, 5),
                              ),
                            ],
                    ),
                    child: ProfileAvatar(
                      name: profile.fullName,
                      photoUrl: profile.photoUrl,
                      size: 52,
                    ),
                  ),
                  Positioned(
                    right: 1,
                    bottom: 1,
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: context.appColor(
                          Color(0xFF19C968),
                          surface: true,
                        ),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: context.appColor(Colors.white, surface: false),
                          width: 2.5,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: InkWell(
              onTap: onProfileTap,
              borderRadius: BorderRadius.circular(14),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      greeting.replaceAll(',', ''),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: context.appColor(
                          Color(0xFF6F7D78),
                          surface: false,
                        ),
                        fontSize: 13,
                        height: 1.1,
                        fontWeight: FontWeight.w600,
                        letterSpacing: .1,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      profile.firstName.trim().isEmpty
                          ? context.tr('Profil')
                          : profile.firstName.trim(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: context.appColor(
                          Color(0xFF10283A),
                          surface: false,
                        ),
                        fontSize: 23,
                        height: 1,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -.35,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Theme(
            data: Theme.of(context).copyWith(
              splashColor: context.appColor(Color(0x1A0FA85A), surface: false),
              highlightColor: context.appColor(
                Color(0x0F0FA85A),
                surface: false,
              ),
            ),
            child: PopupMenuButton<String>(
              tooltip: MaterialLocalizations.of(context).showMenuTooltip,
              color: Theme.of(context).colorScheme.surfaceContainerLow,
              elevation: 10,
              position: PopupMenuPosition.under,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              offset: const Offset(0, 7),
              icon: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: context
                      .appColor(Colors.white, surface: true)
                      .withValues(alpha: .82),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: context.appColor(Color(0xFFE4E9EE), surface: true),
                  ),
                ),
                child: Icon(
                  Icons.more_horiz_rounded,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  size: 25,
                ),
              ),
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 'profile',
                  child: Row(
                    children: [
                      const Icon(
                        Icons.person_outline_rounded,
                        color: Color(0xFF118A50),
                      ),
                      const SizedBox(width: 11),
                      Text(context.tr('Profil')),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'logout',
                  child: Row(
                    children: [
                      const Icon(
                        Icons.logout_rounded,
                        color: Color(0xFFD95252),
                      ),
                      const SizedBox(width: 11),
                      Text(context.tr('Chiqish')),
                    ],
                  ),
                ),
              ],
              onSelected: (value) {
                if (value == 'profile') onProfileTap();
                if (value == 'logout') onSignOut();
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _BodyStatusCard extends StatefulWidget {
  const _BodyStatusCard({required this.profile});

  final UserProfile profile;

  @override
  State<_BodyStatusCard> createState() => _BodyStatusCardState();
}

class _BodyStatusCardState extends State<_BodyStatusCard> {
  double _rotation = 0;

  double get _bmi {
    final heightMeters = widget.profile.heightCm / 100;
    if (heightMeters <= 0) return 0;
    return widget.profile.weightKg / (heightMeters * heightMeters);
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
    if (Theme.of(context).brightness == Brightness.dark) {
      return _buildCard(context, onLightPage: false);
    }
    // Yorug' sahifada gologramma to'q brend kartada ko'rsatiladi.
    return Theme(
      data: AppTheme.dark,
      child: Builder(
        builder: (context) => _buildCard(context, onLightPage: true),
      ),
    );
  }

  Widget _buildCard(BuildContext context, {required bool onLightPage}) {
    final profile = widget.profile;
    final bmi = _bmi;
    final bodyFactor = ((bmi - 16) / 20).clamp(0.0, 1.0);
    final heightFactor = ((profile.heightCm - 145) / 60).clamp(0.0, 1.0);
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final statusColor = bmi < 18.5 || bmi >= 25
        ? (dark ? const Color(0xFFF0C078) : const Color(0xFF946015))
        : scheme.primary;

    return Container(
      height: 310,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: onLightPage
              ? const [Color(0xFF123A3C), Color(0xFF0C2A30), Color(0xFF081C24)]
              : context.appPanelColors,
          stops: const [0, .55, 1],
        ),
        borderRadius: BorderRadius.circular(onLightPage ? 24 : 16),
        border: Border.all(
          color: onLightPage ? const Color(0xFF1E4A4A) : scheme.outlineVariant,
        ),
        boxShadow: onLightPage
            ? const [
                BoxShadow(
                  color: Color(0x2E0B2A2E),
                  blurRadius: 32,
                  offset: Offset(0, 14),
                ),
              ]
            : const [],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -70,
            top: -90,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    context
                        .appColor(Color(0xFF8CFFC1), surface: true)
                        .withValues(alpha: .18),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: -80,
            bottom: -105,
            child: Container(
              width: 230,
              height: 230,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    context
                        .appColor(Color(0xFF62E9D1), surface: true)
                        .withValues(alpha: .12),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 18, 15),
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: context
                            .appColor(Colors.white, surface: true)
                            .withValues(alpha: .10),
                        borderRadius: BorderRadius.circular(13),
                        border: Border.all(
                          color: context
                              .appColor(Colors.white, surface: true)
                              .withValues(alpha: .10),
                        ),
                      ),
                      child: Icon(
                        Icons.accessibility_new_rounded,
                        color: scheme.primary,
                        size: 21,
                      ),
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.tr('TANA DINAMIKASI'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: context.appColor(
                                Color(0xFF9ACCB5),
                                surface: false,
                              ),
                              fontSize: 9.5,
                              letterSpacing: 1.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            context.tr('Bugungi holatingiz'),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: context.appColor(
                                Colors.white,
                                surface: false,
                              ),
                              fontSize: 19,
                              height: 1,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -.25,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      constraints: const BoxConstraints(maxWidth: 96),
                      padding: const EdgeInsets.fromLTRB(9, 7, 11, 7),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: dark ? .14 : .09),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: statusColor.withValues(alpha: .16),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 7,
                            height: 7,
                            decoration: BoxDecoration(
                              color: statusColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              _bodyStatus(context),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: statusColor,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 7),
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onHorizontalDragUpdate: (details) {
                      setState(() {
                        _rotation = (_rotation + details.delta.dx / 150).clamp(
                          -1.0,
                          1.0,
                        );
                      });
                    },
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Positioned(
                          left: 0,
                          top: 20,
                          width: 128,
                          child: Column(
                            children: [
                              _ProfileMetric(
                                icon: Icons.monitor_weight_outlined,
                                label: context.tr('Vazn'),
                                value: profile.weightKg.toStringAsFixed(1),
                                unit: context.tr('kg'),
                              ),
                              const SizedBox(height: 9),
                              _ProfileMetric(
                                icon: Icons.height_rounded,
                                label: context.tr('Bo‘y'),
                                value: profile.heightCm.round().toString(),
                                unit: context.tr('cm'),
                              ),
                              const SizedBox(height: 9),
                              _ProfileMetric(
                                icon: Icons.insights_rounded,
                                label: context.tr('BMI'),
                                value: bmi.toStringAsFixed(1),
                                unit: '',
                              ),
                            ],
                          ),
                        ),
                        Align(
                          alignment: const Alignment(.53, .08),
                          child: Semantics(
                            label:
                                'Aylantiriladigan tana modeli. '
                                'Bo‘y ${profile.heightCm.round()} santimetr, '
                                'vazn ${profile.weightKg.toStringAsFixed(1)} kilogramm, '
                                'BMI ${bmi.toStringAsFixed(1)}',
                            child: TweenAnimationBuilder<double>(
                              tween: Tween(begin: .45, end: bodyFactor),
                              duration: const Duration(milliseconds: 700),
                              curve: Curves.easeOutCubic,
                              builder: (context, animatedBody, _) {
                                final bodyWidth = .94 + animatedBody * .30;
                                final bodyHeight = .92 + heightFactor * .12;
                                return Transform.translate(
                                  offset: Offset(_rotation * 5, 0),
                                  child: Transform(
                                    alignment: Alignment.center,
                                    transform: Matrix4.identity()
                                      ..setEntry(3, 2, .0007)
                                      ..rotateY(_rotation * .28)
                                      ..scaleByDouble(
                                        bodyWidth,
                                        bodyHeight,
                                        1,
                                        1,
                                      ),
                                    child: ColorFiltered(
                                      colorFilter: const ColorFilter.mode(
                                        Color(0xFF9AFFC9),
                                        BlendMode.modulate,
                                      ),
                                      child: Image.asset(
                                        'assets/images/body_hologram_trimmed.png',
                                        width: 190,
                                        height: 226,
                                        fit: BoxFit.contain,
                                        filterQuality: FilterQuality.high,
                                        gaplessPlayback: true,
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileMetric extends StatelessWidget {
  const _ProfileMetric({
    required this.icon,
    required this.label,
    required this.value,
    required this.unit,
  });

  final IconData icon;
  final String label;
  final String value;
  final String unit;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 7, 9, 7),
      decoration: BoxDecoration(
        color: context
            .appColor(Colors.white, surface: true)
            .withValues(alpha: .105),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: context
              .appColor(Colors.white, surface: true)
              .withValues(alpha: .11),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 29,
            height: 29,
            decoration: BoxDecoration(
              color: context
                  .appColor(Color(0xFF8AF5B8), surface: true)
                  .withValues(alpha: .13),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              size: 16,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  style: TextStyle(
                    color: context.appColor(Color(0xFF9ACCB5), surface: false),
                    fontSize: 8.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 1),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: value,
                          style: TextStyle(
                            color: context.appColor(
                              Colors.white,
                              surface: false,
                            ),
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (unit.isNotEmpty)
                          TextSpan(
                            text: ' $unit',
                            style: TextStyle(
                              color: context.appColor(
                                Color(0xFFC1E5D2),
                                surface: false,
                              ),
                              fontSize: 9.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Eski vektor renderer fallback sifatida saqlanadi.
// ignore: unused_element
class _BodySilhouettePainter extends CustomPainter {
  const _BodySilhouettePainter({
    required this.bodyFactor,
    required this.heightFactor,
    required this.isMale,
    required this.rotation,
  });

  final double bodyFactor;
  final double heightFactor;
  final bool isMale;
  final double rotation;

  @override
  void paint(Canvas canvas, Size size) {
    final centerX = size.width / 2;
    final verticalScale = .9 + heightFactor * .1;
    final topOffset = (size.height * (1 - verticalScale)) / 2;
    final sideAmount = rotation.abs().clamp(0.0, 1.0);
    final perspective = 1 - sideAmount * .58;
    final direction = rotation >= 0 ? 1.0 : -1.0;
    canvas.save();
    canvas.translate(centerX + direction * sideAmount * 4, topOffset);
    canvas.scale(perspective, verticalScale);
    canvas.translate(-centerX, 0);

    final glow = Paint()
      ..color = const Color(0xFF00DDF5).withValues(alpha: .16)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(centerX, size.height * .52),
        width: 82 + bodyFactor * 18,
        height: 145,
      ),
      glow,
    );

    final platformGlow = Paint()
      ..color = const Color(0xFF00DDF5).withValues(alpha: .24)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    final platformLine = Paint()
      ..color = const Color(0xFF57F1FF).withValues(alpha: .75)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final platformCenter = Offset(centerX, size.height - 10);
    canvas.drawOval(
      Rect.fromCenter(center: platformCenter, width: 112, height: 19),
      platformGlow,
    );
    for (final ring in [1.0, .72, .43]) {
      canvas.drawOval(
        Rect.fromCenter(
          center: platformCenter,
          width: 112 * ring,
          height: 19 * ring,
        ),
        platformLine,
      );
    }

    final bodyPaint = Paint()
      ..shader = LinearGradient(
        begin: rotation >= 0 ? Alignment.topLeft : Alignment.topRight,
        end: rotation >= 0 ? Alignment.bottomRight : Alignment.bottomLeft,
        colors: const [Color(0xFFE9FDFF), Color(0xFF43E9FA), Color(0xFF0089B6)],
        stops: const [0, .55, 1],
      ).createShader(Rect.fromLTWH(0, 10, size.width, size.height - 10))
      ..style = PaintingStyle.fill;
    final outlinePaint = Paint()
      ..color = const Color(0xFF77F5FF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.35
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5);

    final headRadius = 10.5 + bodyFactor * 1.7;
    canvas.drawCircle(Offset(centerX, 20), headRadius, bodyPaint);
    canvas.drawCircle(Offset(centerX, 20), headRadius, outlinePaint);
    if (sideAmount < .72) {
      final facePaint = Paint()
        ..color = const Color(
          0xFF006B88,
        ).withValues(alpha: (1 - sideAmount / .72) * .6)
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 1.7;
      final faceShift = rotation * 4;
      canvas.drawCircle(Offset(centerX - 3 + faceShift, 19), 1.1, facePaint);
      canvas.drawCircle(Offset(centerX + 3 + faceShift, 19), 1.1, facePaint);
      canvas.drawLine(
        Offset(centerX - 2 + faceShift, 24),
        Offset(centerX + 2 + faceShift, 24),
        facePaint,
      );
    }

    final shoulderHalf = (isMale ? 18.5 : 16.5) + bodyFactor * 9;
    final waistHalf = 10.5 + bodyFactor * 11;
    final hipHalf = (isMale ? 13.5 : 16) + bodyFactor * 10;
    final torso = Path()
      ..moveTo(centerX - shoulderHalf, 42)
      ..quadraticBezierTo(centerX - waistHalf, 69, centerX - hipHalf, 96)
      ..quadraticBezierTo(centerX, 108, centerX + hipHalf, 96)
      ..quadraticBezierTo(centerX + waistHalf, 69, centerX + shoulderHalf, 42)
      ..quadraticBezierTo(centerX, 34, centerX - shoulderHalf, 42)
      ..close();
    canvas.drawPath(torso, bodyPaint);
    canvas.drawPath(torso, outlinePaint);

    final anatomyPaint = Paint()
      ..color = const Color(0xFFCBFCFF).withValues(alpha: .5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = .8;
    canvas.drawLine(Offset(centerX, 42), Offset(centerX, 97), anatomyPaint);
    canvas.drawLine(
      Offset(centerX - shoulderHalf * .72, 49),
      Offset(centerX + shoulderHalf * .72, 49),
      anatomyPaint,
    );
    for (final y in [58.0, 67.0, 77.0]) {
      final ribWidth = waistHalf + (77 - y) * .25;
      final rib = Path()
        ..moveTo(centerX - ribWidth, y)
        ..quadraticBezierTo(centerX, y + 5, centerX + ribWidth, y);
      canvas.drawPath(rib, anatomyPaint);
    }
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(centerX, 88),
        width: waistHalf * 1.15,
        height: 10,
      ),
      anatomyPaint,
    );

    canvas.save();
    canvas.clipPath(torso);
    final scanPaint = Paint()
      ..color = const Color(0xFFD4FDFF).withValues(alpha: .15)
      ..strokeWidth = .7;
    for (double y = 43; y < 98; y += 5) {
      canvas.drawLine(
        Offset(centerX - shoulderHalf, y),
        Offset(centerX + shoulderHalf, y),
        scanPaint,
      );
    }
    canvas.restore();

    final limbPaint = Paint()
      ..shader = bodyPaint.shader
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 7.5 + bodyFactor * 5;
    canvas.drawLine(
      Offset(centerX - shoulderHalf + 3, 47),
      Offset(centerX - shoulderHalf - 7, 101),
      limbPaint,
    );
    canvas.drawLine(
      Offset(centerX + shoulderHalf - 3, 47),
      Offset(centerX + shoulderHalf + 7, 101),
      limbPaint,
    );
    final limbOutline = Paint()
      ..color = const Color(0xFF77F5FF).withValues(alpha: .88)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 1.2;
    canvas.drawLine(
      Offset(centerX - shoulderHalf + 3, 47),
      Offset(centerX - shoulderHalf - 7, 101),
      limbOutline,
    );
    canvas.drawLine(
      Offset(centerX + shoulderHalf - 3, 47),
      Offset(centerX + shoulderHalf + 7, 101),
      limbOutline,
    );

    limbPaint.strokeWidth = 9 + bodyFactor * 5;
    canvas.drawLine(
      Offset(centerX - hipHalf * .48, 99),
      Offset(centerX - 13 - bodyFactor * 3, 146),
      limbPaint,
    );
    canvas.drawLine(
      Offset(centerX + hipHalf * .48, 99),
      Offset(centerX + 13 + bodyFactor * 3, 146),
      limbPaint,
    );
    canvas.drawLine(
      Offset(centerX - hipHalf * .48, 99),
      Offset(centerX - 13 - bodyFactor * 3, 146),
      limbOutline,
    );
    canvas.drawLine(
      Offset(centerX + hipHalf * .48, 99),
      Offset(centerX + 13 + bodyFactor * 3, 146),
      limbOutline,
    );

    final basePaint = Paint()
      ..color = const Color(0xFF00DDF5).withValues(alpha: .35)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(centerX, 154),
        width: 55 + bodyFactor * 15,
        height: 7,
      ),
      basePaint,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _BodySilhouettePainter oldDelegate) {
    return bodyFactor != oldDelegate.bodyFactor ||
        heightFactor != oldDelegate.heightFactor ||
        isMale != oldDelegate.isMale ||
        rotation != oldDelegate.rotation;
  }
}

class _ActionCard extends StatelessWidget {
  // Yorug' rejim uchun bir xil to'yinganlikdagi uyg'un palitra.
  Color get _accent => switch (asset.split('/').last) {
    'food_scan.png' => const Color(0xFF0F9D72),
    'barcode_scan.png' => const Color(0xFF0E8AA6),
    'food_search.png' => const Color(0xFF4F5FD8),
    'calculator.png' => const Color(0xFFE08A1E),
    _ => const Color(0xFFE5536B),
  };

  static const _cardBorder = Color(0xFFE4E9EE);
  static const _title = Color(0xFF0F1B2D);
  static const _arrowBg = Color(0xFFF1F4F8);
  static const _arrowFg = Color(0xFF64748B);

  const _ActionCard({
    required this.asset,
    required this.title,
    required this.tint,
    required this.accent,
    required this.onTap,
    this.horizontal = false,
  });

  final String asset;
  final String title;
  final Color tint;
  final Color accent;
  final VoidCallback onTap;
  final bool horizontal;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final scheme = theme.colorScheme;
    final radius = BorderRadius.circular(20);
    return Material(
      color: scheme.surfaceContainerLowest,
      borderRadius: radius,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        splashColor: scheme.primary.withValues(alpha: .09),
        highlightColor: scheme.primary.withValues(alpha: .04),
        child: Ink(
          padding: EdgeInsets.all(horizontal ? 14 : 16),
          decoration: BoxDecoration(
            color: dark ? scheme.surfaceContainerLowest : Colors.white,
            borderRadius: radius,
            border: Border.all(
              color: dark
                  ? scheme.outlineVariant.withValues(alpha: .65)
                  : _cardBorder,
            ),
            boxShadow: dark
                ? const []
                : const [
                    BoxShadow(
                      color: Color(0x0A0F1B2D),
                      blurRadius: 18,
                      offset: Offset(0, 6),
                    ),
                    BoxShadow(
                      color: Color(0x050F1B2D),
                      blurRadius: 2,
                      offset: Offset(0, 1),
                    ),
                  ],
          ),
          child: horizontal
              ? _horizontalContent(context)
              : _verticalContent(context),
        ),
      ),
    );
  }

  Widget _image(BuildContext context, {required double size}) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: dark
            ? Theme.of(context).colorScheme.primary.withValues(alpha: .10)
            : null,
        gradient: dark
            ? null
            : LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color.alphaBlend(
                    Colors.white.withValues(alpha: .18),
                    _accent,
                  ),
                  _accent,
                ],
              ),
        borderRadius: BorderRadius.circular(size * .28),
        boxShadow: dark
            ? null
            : [
                BoxShadow(
                  color: _accent.withValues(alpha: .28),
                  blurRadius: 12,
                  offset: const Offset(0, 5),
                ),
              ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(size * .24),
        child: Icon(
          switch (asset.split('/').last) {
            'food_scan.png' => Icons.document_scanner_outlined,
            'barcode_scan.png' => Icons.qr_code_scanner_outlined,
            'food_search.png' => Icons.search_outlined,
            'calculator.png' => Icons.calculate_outlined,
            _ => Icons.fitness_center_outlined,
          },
          size: size * .44,
          color: dark ? Theme.of(context).colorScheme.primary : Colors.white,
        ),
      ),
    );
  }

  Widget _arrow(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final color = dark ? Theme.of(context).colorScheme.primary : _arrowFg;
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        color: dark ? color.withValues(alpha: .08) : _arrowBg,
        shape: BoxShape.circle,
      ),
      child: Icon(Icons.arrow_outward_rounded, color: color, size: 16),
    );
  }

  Widget _verticalContent(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _image(context, size: 56),
            const Spacer(),
            _arrow(context),
          ],
        ),
        const Spacer(),
        Text(
          title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: context.appColor(_title, surface: false),
            fontSize: 15,
            height: 1.15,
            fontWeight: FontWeight.w700,
            letterSpacing: -.15,
          ),
        ),
      ],
    );
  }

  Widget _horizontalContent(BuildContext context) {
    return Row(
      children: [
        _image(context, size: 62),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: context.appColor(_title, surface: false),
              fontSize: 17,
              height: 1.15,
              fontWeight: FontWeight.w700,
              letterSpacing: -.2,
            ),
          ),
        ),
        const SizedBox(width: 10),
        _arrow(context),
        const SizedBox(width: 5),
      ],
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
    return Container(
      constraints: const BoxConstraints(minHeight: 76),
      padding: const EdgeInsets.fromLTRB(12, 11, 8, 11),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: context.appPanelColors,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: context.appColor(Color(0x3D8CFFC0), surface: true),
        ),
        boxShadow: Theme.of(context).brightness == Brightness.dark
            ? const []
            : const [
                BoxShadow(
                  color: Color(0x40104732),
                  blurRadius: 24,
                  offset: Offset(0, 11),
                ),
              ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: context.appColor(Color(0xFFECFFF4), surface: true),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.check_rounded,
              color: Color(0xFF0AA758),
              size: 29,
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
                    color: context.appColor(Colors.white, surface: false),
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -.1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$foodName  •  $details',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: context.appColor(Color(0xFFD2F5E2), surface: false),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            onPressed: onClose,
            tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
            style: IconButton.styleFrom(
              foregroundColor: context.appColor(
                Color(0xFFD2F5E2),
                surface: false,
              ),
              backgroundColor: context.appColor(
                Color(0x1FFFFFFF),
                surface: true,
              ),
              minimumSize: const Size(38, 38),
            ),
            icon: const Icon(Icons.close_rounded, size: 19),
          ),
        ],
      ),
    );
  }
}
