import '../theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../l10n/app_localizations.dart';
import '../models/food_nutrition.dart';
import '../services/open_food_facts_service.dart';
import '../widgets/meal_type_picker.dart';
import 'meals_page.dart';
import 'custom_food_page.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class BarcodeScannerPage extends StatefulWidget {
  const BarcodeScannerPage({super.key, required this.service});

  final OpenFoodFactsService service;

  @override
  State<BarcodeScannerPage> createState() => _BarcodeScannerPageState();
}

class _BarcodeScannerPageState extends State<BarcodeScannerPage> {
  static const _green = Color(0xFF2F5BEA);
  static const _navy = Color(0xFF10223C);

  final _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    facing: CameraFacing.back,
    torchEnabled: false,
  );
  final _grams = TextEditingController(text: '100');

  /// Meal the product is added to (suggested from the time of day).
  MealType _meal = suggestedMealType();

  FoodNutrition? _food;
  String? _barcode;
  String? _error;
  bool _lookingUp = false;

  double get _weight {
    final value = double.tryParse(_grams.text.replaceAll(',', '.'));
    return value != null && value.isFinite && value >= 1 && value <= 5000
        ? value
        : 0;
  }

  @override
  void dispose() {
    _controller.dispose();
    _grams.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_lookingUp || _food != null) return;
    final languageCode = Localizations.localeOf(context).languageCode;
    final raw = capture.barcodes
        .map((barcode) => barcode.rawValue)
        .whereType<String>()
        .where((value) => value.trim().isNotEmpty)
        .firstOrNull;
    if (raw == null) return;

    setState(() {
      _lookingUp = true;
      _barcode = raw;
      _error = null;
    });
    await _controller.stop();
    final food = await widget.service.findByBarcode(
      raw,
      languageCode: languageCode,
    );
    if (!mounted) return;
    setState(() {
      _food = food;
      _lookingUp = false;
      _error = food == null
          ? context.tr('Mahsulot bazalarda topilmadi.')
          : null;
    });
  }

  Future<void> _scanAgain() async {
    setState(() {
      _food = null;
      _barcode = null;
      _error = null;
      _lookingUp = false;
      _grams.text = '100';
    });
    await _controller.start();
  }

  void _addFood() {
    if (_food?.hasMissingCoreNutrients == true) {
      setState(() => _error = context.tr('Asosiy oziq qiymatlari to‘liq emas. Boshqa yozuvni tanlang.'));
      return;
    }
    if (_food == null || _weight < 1 || _weight > 5000) {
      setState(
        () => _error = context.tr('1 dan 5000 grammgacha miqdor kiriting.'),
      );
      return;
    }
    Navigator.pop(context, _food!.forGrams(_weight).withMealType(_meal.name));
  }

  @override
  Widget build(BuildContext context) {
    return _food == null
        ? AnnotatedRegion(
            value: AppTheme.systemOverlay(AppTheme.dark),
            child: Theme(
              data: AppTheme.dark,
              child: Builder(builder: _scanner),
            ),
          )
        : _result();
  }

  Widget _scanner(BuildContext context) {
    return Scaffold(
      backgroundColor: context.appColor(Color(0xFF050706), surface: true),
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(controller: _controller, onDetect: _onDetect),
          ColoredBox(
            color: context
                .appColor(Colors.black, surface: true)
                .withValues(alpha: .25),
          ),
          SafeArea(
            child: Stack(
              children: [
                Positioned(
                  left: 14,
                  top: 8,
                  child: IconButton.filled(
                    onPressed: () => Navigator.pop(context),
                    style: IconButton.styleFrom(
                      backgroundColor: context.appColor(
                        Colors.black54,
                        surface: true,
                      ),
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(LucideIcons.chevronLeft),
                  ),
                ),
                Positioned(
                  right: 14,
                  top: 8,
                  child: Row(
                    children: [
                      IconButton.filled(
                        onPressed: _controller.toggleTorch,
                        style: IconButton.styleFrom(
                          backgroundColor: context.appColor(
                            Colors.black54,
                            surface: true,
                          ),
                          foregroundColor: Colors.white,
                        ),
                        icon: const Icon(LucideIcons.flashlight),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filled(
                        onPressed: _controller.switchCamera,
                        style: IconButton.styleFrom(
                          backgroundColor: context.appColor(
                            Colors.black54,
                            surface: true,
                          ),
                          foregroundColor: Colors.white,
                        ),
                        icon: const Icon(LucideIcons.switchCamera),
                      ),
                    ],
                  ),
                ),
                Center(
                  child: Container(
                    width: MediaQuery.sizeOf(context).width * .82,
                    height: 190,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _green, width: 3),
                      boxShadow: const [
                        BoxShadow(color: Color(0x662F5BEA), blurRadius: 20),
                      ],
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          height: 2,
                          margin: const EdgeInsets.symmetric(horizontal: 20),
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.transparent,
                                _green,
                                Colors.transparent,
                              ],
                            ),
                            boxShadow: [
                              BoxShadow(color: _green, blurRadius: 10),
                            ],
                          ),
                        ),
                        if (_lookingUp)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 15,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: context.appColor(
                                Colors.black87,
                                surface: true,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: _green,
                                  ),
                                ),
                                SizedBox(width: 10),
                                Text(
                                  context.tr('Mahsulot qidirilmoqda...'),
                                  style: TextStyle(
                                    color: context.appColor(
                                      Colors.white,
                                      surface: false,
                                    ),
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  left: 24,
                  right: 24,
                  bottom: 28,
                  child: Column(
                    children: [
                      Text(
                        context.tr('Shtrix-kodni ramka ichiga joylashtiring'),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: context.appColor(Colors.white, surface: false),
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _barcode == null
                            ? context.tr('Kod avtomatik aniqlanadi')
                            : 'Kod: $_barcode',
                        style: TextStyle(
                          color: context.appColor(
                            Colors.white60,
                            surface: false,
                          ),
                        ),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.all(13),
                          decoration: BoxDecoration(
                            color: context.appColor(
                              Color(0xFFE34848),
                              surface: true,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            _error!,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: context.appColor(
                                Colors.white,
                                surface: false,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        FilledButton.icon(
                          onPressed: _scanAgain,
                          icon: const Icon(LucideIcons.refreshCw),
                          label: Text(context.tr('Qayta skanerlash')),
                        ),
                        TextButton(onPressed: () async {
                          final food = await Navigator.push<FoodNutrition>(context, MaterialPageRoute(builder: (_) => const CustomFoodPage()));
                          if (food != null && mounted) { setState(() { _food = food; _error = null; }); }
                        }, child: Text(context.tr('Yorliqdan mahsulot qo‘shish'))),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _result() {
    final calculated = _food!.forGrams(_weight > 0 ? _weight : 100);
    return Scaffold(
      backgroundColor: context.appColor(Color(0xFFF1F3F6), surface: true),
      appBar: AppBar(
        backgroundColor: context.appColor(Color(0xFFF1F3F6), surface: true),
        title: Text(
          context.tr('Mahsulot aniqlandi'),
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        leading: IconButton(
          onPressed: _scanAgain,
          icon: const Icon(LucideIcons.chevronLeft),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.surfaceContainerLowest,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x1210223C),
                          blurRadius: 25,
                          offset: Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Icon(
                              LucideIcons.badgeCheck,
                              color: _green,
                              size: 18,
                            ),
                            SizedBox(width: 7),
                            Text(
                              _food!.dataSource ?? context.tr('Manba'),
                              style: const TextStyle(
                                color: _green,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _food!.displayNameFor(
                            Localizations.localeOf(context).languageCode,
                          ),
                          style: TextStyle(
                            color: context.appColor(_navy, surface: false),
                            fontSize: 22,
                            height: 1.15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          context.tr('Shtrix-kod: {barcode}', {
                            'barcode': _barcode ?? '',
                          }),
                          style: TextStyle(
                            color: context.appColor(
                              Color(0xFF7A8392),
                              surface: false,
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        TextField(
                          controller: _grams,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          onChanged: (_) => setState(() {}),
                          decoration: InputDecoration(
                            labelText: context.tr('Mahsulot og‘irligi'),
                            suffixText: context.tr(_food!.basisUnit),
                            filled: true,
                            fillColor: context.appColor(
                              Color(0xFFF5F7F6),
                              surface: true,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        GridView.count(
                          crossAxisCount: 2,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          mainAxisSpacing: 10,
                          crossAxisSpacing: 10,
                          childAspectRatio: 1.65,
                          children: [
                            _NutrientTile(
                              label: context.tr('Kaloriya'),
                              value:
                                  '${calculated.calories.round()} ${context.tr('kcal')}',
                            ),
                            _NutrientTile(
                              label: context.tr('Oqsil'),
                              value:
                                  '${calculated.protein.toStringAsFixed(1)} ${context.tr('g')}',
                            ),
                            _NutrientTile(
                              label: context.tr('Uglevod'),
                              value:
                                  '${calculated.carbohydrates.toStringAsFixed(1)} ${context.tr('g')}',
                            ),
                            _NutrientTile(
                              label: context.tr('Yog‘'),
                              value:
                                  '${calculated.fat.toStringAsFixed(1)} ${context.tr('g')}',
                            ),
                            _NutrientTile(
                              label: context.tr('Kletchatka'),
                              value:
                                  '${calculated.fiber.toStringAsFixed(1)} ${context.tr('g')}',
                            ),
                            _NutrientTile(
                              label: context.tr('Suv'),
                              value: calculated.hasWaterData
                                  ? '${calculated.water.toStringAsFixed(1)} ${context.tr('g')}'
                                  : context.tr('Ma’lumot yo‘q'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: context.appColor(
                          Color(0xFFD84D5B),
                          surface: false,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Text(
                    context.tr('Qaysi ovqatlanishga qo‘shilsin?'),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  MealTypePicker(
                    value: _meal,
                    onChanged: (meal) => setState(() => _meal = meal),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _addFood,
                    icon: const Icon(LucideIcons.plus),
                    label: Text(context.tr('Hisoblash va qo‘shish')),
                    style: FilledButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Theme.of(context).colorScheme.onPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NutrientTile extends StatelessWidget {
  const _NutrientTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.appColor(Color(0xFFF3F7F5), surface: true),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: TextStyle(
              color: context.appColor(Color(0xFF7A8392), surface: false),
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 3),
          FittedBox(
            child: Text(
              value,
              style: TextStyle(
                color: context.appColor(Color(0xFF10223C), surface: false),
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
