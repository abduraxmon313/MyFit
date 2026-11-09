import '../theme/app_theme.dart';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../l10n/app_localizations.dart';
import '../models/food_nutrition.dart';
import '../services/food_vision_service.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class FoodScanPage extends StatefulWidget {
  const FoodScanPage({super.key, required this.service});

  final FoodVisionService service;

  @override
  State<FoodScanPage> createState() => _FoodScanPageState();
}

class _FoodScanPageState extends State<FoodScanPage> {
  static const _green = Color(0xFF2F5BEA);
  static const _navy = Color(0xFF10223C);
  final _picker = ImagePicker();
  final _grams = TextEditingController(text: '100');

  XFile? _image;
  FoodNutrition? _nutrition;
  bool _analyzing = false;
  String? _error;

  double get _weight {
    final value = double.tryParse(_grams.text.replaceAll(',', '.'));
    return value != null && value.isFinite && value >= 1 && value <= 5000
        ? value
        : 0;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _capture());
  }

  @override
  void dispose() {
    _grams.dispose();
    super.dispose();
  }

  Future<void> _capture({ImageSource source = ImageSource.camera}) async {
    if (!mounted || _analyzing) return;
    setState(() {
      _error = null;
      _nutrition = null;
    });
    try {
      final image = await _picker.pickImage(
        source: source,
        imageQuality: 88,
        maxWidth: 1600,
        preferredCameraDevice: CameraDevice.rear,
      );
      if (image == null || !mounted) return;
      setState(() {
        _image = image;
        _analyzing = true;
      });
      final result = await widget.service.analyzeFile(image.path);
      if (!mounted) return;
      setState(() {
        _nutrition = result;
        _grams.text = '100';
        _analyzing = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _analyzing = false;
        _error = context.tr(error.toString());
      });
    }
  }

  void _add() {
    if (_nutrition?.hasMissingCoreNutrients == true) {
      setState(() => _error = context.tr('Asosiy oziq qiymatlari to‘liq emas. Boshqa yozuvni tanlang.'));
      return;
    }
    if (_nutrition == null || _weight < 1 || _weight > 5000) {
      setState(
        () => _error = context.tr('1 dan 5000 grammgacha miqdor kiriting.'),
      );
      return;
    }
    Navigator.pop(context, _nutrition!.forGrams(_weight));
  }

  @override
  Widget build(BuildContext context) {
    return _nutrition == null
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
      backgroundColor: context.appColor(Color(0xFF0B1324), surface: true),
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (_image != null)
            Image.file(File(_image!.path), fit: BoxFit.cover)
          else
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF0B1324), Color(0xFF0B1324)],
                ),
              ),
            ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xA6000000),
                  Color(0x14000000),
                  Color(0x26000000),
                  Color(0xD9000000),
                ],
                stops: [0, .24, .58, 1],
              ),
            ),
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final frameSize = (constraints.maxWidth * .76)
                    .clamp(270.0, 350.0)
                    .toDouble();
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    Positioned(
                      left: 18,
                      right: 18,
                      top: 10,
                      child: _ScannerHeader(
                        title: context.tr('AI ovqat skaneri'),
                        subtitle: context.tr(
                          'Mahsulot tarkibini bir zumda biling',
                        ),
                        onBack: () => Navigator.pop(context),
                      ),
                    ),
                    Align(
                      alignment: const Alignment(0, -.05),
                      child: _ScanFrame(
                        size: frameSize,
                        analyzing: _analyzing,
                        title: context.tr('Ovqatni ramka ichiga joylashtiring'),
                        analyzingLabel: context.tr('AI ovqatni aniqlamoqda...'),
                        readyLabel: context.tr('Tahlilga tayyor'),
                      ),
                    ),
                    Positioned(
                      left: 18,
                      right: 18,
                      bottom: 16,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_error != null) ...[
                            _ScannerError(
                              message: _error!,
                              onRetry: _analyzing ? null : _capture,
                            ),
                            const SizedBox(height: 12),
                          ],
                          _ScannerControls(
                            analyzing: _analyzing,
                            galleryLabel: context.tr('Galereya'),
                            captureLabel: context.tr('Suratga olish'),
                            retryLabel: context.tr('Qayta olish'),
                            onGallery: () =>
                                _capture(source: ImageSource.gallery),
                            onCapture: _capture,
                            onRetry: _capture,
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _result() {
    final calculated = _nutrition!.forGrams(_weight > 0 ? _weight : 100);
    final confidence = _nutrition!.confidence;
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
        ),
        child: SafeArea(
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: IconButton.filled(
                    onPressed: () => setState(() => _nutrition = null),
                    style: IconButton.styleFrom(
                      foregroundColor: context.appColor(_navy, surface: false),
                      backgroundColor: context.appColor(
                        Colors.white,
                        surface: true,
                      ),
                    ),
                    icon: const Icon(LucideIcons.chevronLeft),
                  ),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(22, 5, 22, 20),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 430),
                      child: Container(
                        padding: const EdgeInsets.all(21),
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).colorScheme.surfaceContainerLowest,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x10000000),
                              blurRadius: 30,
                              offset: Offset(0, 14),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: AspectRatio(
                                aspectRatio: 16 / 9,
                                child: Image.file(
                                  File(_image!.path),
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                            const SizedBox(height: 17),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: context.appColor(
                                    Color(0xFFF1F3F6),
                                    surface: true,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 11,
                                    vertical: 6,
                                  ),
                                  child: Text(
                                    confidence == null
                                        ? context.tr('AI aniqlandi')
                                        : '${context.tr('AI aniqlandi')} · '
                                              '${(confidence * 100).round()}%',
                                    style: TextStyle(
                                      color: context.appColor(
                                        Color(0xFF2F5BEA),
                                        surface: false,
                                      ),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              _nutrition!.displayNameFor(
                                Localizations.localeOf(context).languageCode,
                              ),
                              style: TextStyle(
                                color: context.appColor(_navy, surface: false),
                                fontSize: 24,
                                height: 1.1,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 18),
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    '${context.tr('Miqdori')} (${context.tr(_nutrition!.basisUnit)})',
                                    style: TextStyle(
                                      color: context.appColor(
                                        Color(0xFF778195),
                                        surface: false,
                                      ),
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                SizedBox(
                                  width: 120,
                                  child: TextField(
                                    controller: _grams,
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                          decimal: true,
                                        ),
                                    textAlign: TextAlign.center,
                                    onChanged: (_) => setState(() {}),
                                    decoration: InputDecoration(
                                      filled: true,
                                      fillColor: context.appColor(
                                        Color(0xFFF7F8FA),
                                        surface: true,
                                      ),
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 10,
                                          ),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    style: TextStyle(
                                      color: context.appColor(
                                        _navy,
                                        surface: false,
                                      ),
                                      fontSize: 17,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            GridView.count(
                              crossAxisCount: 2,
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              mainAxisSpacing: 10,
                              crossAxisSpacing: 10,
                              childAspectRatio: 1.45,
                              children: [
                                _Nutrient(
                                  label: context.tr('Kaloriya'),
                                  value:
                                      '${calculated.calories.round()} ${context.tr('kcal')}',
                                ),
                                _Nutrient(
                                  label: context.tr('Oqsil'),
                                  value:
                                      '${calculated.protein.toStringAsFixed(1)} ${context.tr('g')}',
                                  color: context.appColor(
                                    Color(0xFF2F5BEA),
                                    surface: true,
                                  ),
                                ),
                                _Nutrient(
                                  label: context.tr('Uglevod'),
                                  value:
                                      '${calculated.carbohydrates.toStringAsFixed(1)} ${context.tr('g')}',
                                ),
                                _Nutrient(
                                  label: context.tr('Yog‘'),
                                  value:
                                      '${calculated.fat.toStringAsFixed(1)} ${context.tr('g')}',
                                  color: context.appColor(
                                    Color(0xFFB7791F),
                                    surface: true,
                                  ),
                                ),
                                _Nutrient(
                                  label: context.tr('Suv'),
                                  value: calculated.hasWaterData
                                      ? '${calculated.water.toStringAsFixed(1)} ${context.tr('ml')}'
                                      : context.tr('Ma’lumot yo‘q'),
                                  color: context.appColor(
                                    Color(0xFF3B6FE0),
                                    surface: true,
                                  ),
                                ),
                              ],
                            ),
                            if (_error != null) ...[
                              const SizedBox(height: 12),
                              Text(
                                _error!,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: context.appColor(
                                    Colors.red,
                                    surface: false,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 6, 22, 22),
                child: SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: FilledButton(
                    onPressed: _add,
                    style: FilledButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      context.tr('Hisoblash va qo‘shish'),
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScannerHeader extends StatelessWidget {
  const _ScannerHeader({
    required this.title,
    required this.subtitle,
    required this.onBack,
  });

  final String title;
  final String subtitle;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _GlassIconButton(icon: LucideIcons.chevronLeft, onTap: onBack),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            height: 56,
            padding: const EdgeInsets.symmetric(horizontal: 15),
            decoration: BoxDecoration(
              color: context
                  .appColor(Color(0xFF0B1324), surface: true)
                  .withValues(alpha: .72),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: context
                    .appColor(Colors.white, surface: true)
                    .withValues(alpha: .13),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: _FoodScanPageState._green.withValues(alpha: .17),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: const Icon(
                    LucideIcons.sparkles,
                    color: Color(0xFFA9C1FF),
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: context.appColor(Colors.white, surface: false),
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: context
                              .appColor(Colors.white, surface: false)
                              .withValues(alpha: .62),
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _GlassIconButton extends StatelessWidget {
  const _GlassIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context
          .appColor(Color(0xFF0B1324), surface: true)
          .withValues(alpha: .76),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: context
              .appColor(Colors.white, surface: true)
              .withValues(alpha: .14),
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: 56,
          height: 56,
          child: Icon(
            icon,
            color: context.appColor(Colors.white, surface: false),
            size: 21,
          ),
        ),
      ),
    );
  }
}

class _ScanFrame extends StatelessWidget {
  const _ScanFrame({
    required this.size,
    required this.analyzing,
    required this.title,
    required this.analyzingLabel,
    required this.readyLabel,
  });

  final double size;
  final bool analyzing;
  final String title;
  final String analyzingLabel;
  final String readyLabel;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: context.appColor(Colors.white, surface: false),
              fontSize: 16,
              fontWeight: FontWeight.w600,
              shadows: [
                Shadow(
                  color: context.appColor(Colors.black87, surface: false),
                  blurRadius: 12,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: size,
            height: size,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: context
                        .appColor(Colors.white, surface: true)
                        .withValues(alpha: .025),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: context
                          .appColor(Colors.white, surface: true)
                          .withValues(alpha: .17),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: CustomPaint(
                    painter: _ScanCornersPainter(
                      color: analyzing
                          ? context.appColor(Color(0xFFA9C1FF), surface: true)
                          : _FoodScanPageState._green,
                    ),
                  ),
                ),
                if (analyzing) const _ScanningBeam(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    color: context.appColor(Color(0xE60B1324), surface: true),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: context
                          .appColor(Colors.white, surface: true)
                          .withValues(alpha: .12),
                    ),
                    boxShadow: const [
                      BoxShadow(color: Color(0x55000000), blurRadius: 18),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (analyzing)
                        const SizedBox(
                          width: 17,
                          height: 17,
                          child: CircularProgressIndicator(
                            color: Color(0xFFA9C1FF),
                            strokeWidth: 2.2,
                          ),
                        )
                      else
                        const Icon(
                          LucideIcons.focus,
                          color: Color(0xFFA9C1FF),
                          size: 18,
                        ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          analyzing ? analyzingLabel : readyLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: context.appColor(
                              Colors.white,
                              surface: false,
                            ),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
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
}

class _ScanningBeam extends StatefulWidget {
  const _ScanningBeam();

  @override
  State<_ScanningBeam> createState() => _ScanningBeamState();
}

class _ScanningBeamState extends State<_ScanningBeam>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1700),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (_, _) => Align(
          alignment: Alignment(0, -0.75 + _controller.value * 1.5),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 22),
            height: 2,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.transparent,
                  Color(0xFFA9C1FF),
                  Colors.transparent,
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: Color(0xAAA9C1FF),
                  blurRadius: 12,
                  spreadRadius: 2,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ScanCornersPainter extends CustomPainter {
  const _ScanCornersPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const inset = 3.0;
    const radius = 31.0;
    const segment = 54.0;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    final path = Path()
      ..moveTo(inset, segment)
      ..lineTo(inset, radius)
      ..quadraticBezierTo(inset, inset, radius, inset)
      ..lineTo(segment, inset)
      ..moveTo(size.width - segment, inset)
      ..lineTo(size.width - radius, inset)
      ..quadraticBezierTo(size.width - inset, inset, size.width - inset, radius)
      ..lineTo(size.width - inset, segment)
      ..moveTo(size.width - inset, size.height - segment)
      ..lineTo(size.width - inset, size.height - radius)
      ..quadraticBezierTo(
        size.width - inset,
        size.height - inset,
        size.width - radius,
        size.height - inset,
      )
      ..lineTo(size.width - segment, size.height - inset)
      ..moveTo(segment, size.height - inset)
      ..lineTo(radius, size.height - inset)
      ..quadraticBezierTo(
        inset,
        size.height - inset,
        inset,
        size.height - radius,
      )
      ..lineTo(inset, size.height - segment);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _ScanCornersPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

class _ScannerError extends StatelessWidget {
  const _ScannerError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 11, 8, 11),
      decoration: BoxDecoration(
        color: context
            .appColor(Color(0xFFFDF8F2), surface: true)
            .withValues(alpha: .96),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: context.appColor(Color(0xFFFFD8C5), surface: true),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x4D000000),
            blurRadius: 24,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: context.appColor(Color(0xFFF1F3F6), surface: true),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              LucideIcons.info,
              color: Color(0xFFB7791F),
              size: 21,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: context.appColor(Color(0xFF422D27), surface: false),
                fontSize: 12,
                height: 1.3,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          IconButton(
            onPressed: onRetry,
            style: IconButton.styleFrom(
              backgroundColor: context.appColor(
                Color(0xFFF1F3F6),
                surface: true,
              ),
              foregroundColor: context.appColor(
                Color(0xFFB7791F),
                surface: false,
              ),
            ),
            icon: const Icon(LucideIcons.refreshCw, size: 21),
          ),
        ],
      ),
    );
  }
}

class _ScannerControls extends StatelessWidget {
  const _ScannerControls({
    required this.analyzing,
    required this.galleryLabel,
    required this.captureLabel,
    required this.retryLabel,
    required this.onGallery,
    required this.onCapture,
    required this.onRetry,
  });

  final bool analyzing;
  final String galleryLabel;
  final String captureLabel;
  final String retryLabel;
  final VoidCallback onGallery;
  final VoidCallback onCapture;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 104,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: context.appColor(Color(0xE60B1324), surface: true),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: context
              .appColor(Colors.white, surface: true)
              .withValues(alpha: .13),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x66000000),
            blurRadius: 28,
            offset: Offset(0, 14),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _ScanAction(
            icon: LucideIcons.images,
            label: galleryLabel,
            onTap: analyzing ? null : onGallery,
          ),
          Semantics(
            button: true,
            label: captureLabel,
            child: GestureDetector(
              onTap: analyzing ? null : onCapture,
              child: AnimatedOpacity(
                opacity: analyzing ? .5 : 1,
                duration: const Duration(milliseconds: 180),
                child: Container(
                  width: 78,
                  height: 78,
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Theme.of(context).colorScheme.surfaceContainerLowest,
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x662F5BEA),
                        blurRadius: 18,
                        spreadRadius: 2,
                      ),
                    ],
                    border: Border.all(
                      color: context
                          .appColor(Colors.white, surface: true)
                          .withValues(alpha: .75),
                      width: 2,
                    ),
                  ),
                  child: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFFA9C1FF), Color(0xFF2F5BEA)],
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      analyzing
                          ? LucideIcons.hourglass
                          : LucideIcons.camera,
                      color: context.appColor(Colors.white, surface: false),
                      size: 27,
                    ),
                  ),
                ),
              ),
            ),
          ),
          _ScanAction(
            icon: LucideIcons.refreshCw,
            label: retryLabel,
            onTap: analyzing ? null : onRetry,
          ),
        ],
      ),
    );
  }
}

class _ScanAction extends StatelessWidget {
  const _ScanAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: 82,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: context
                    .appColor(Colors.white, surface: true)
                    .withValues(alpha: .09),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: context
                      .appColor(Colors.white, surface: true)
                      .withValues(alpha: .1),
                ),
              ),
              child: Icon(
                icon,
                color: onTap == null
                    ? context.appColor(Colors.white38, surface: true)
                    : context.appColor(Colors.white, surface: true),
                size: 22,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: onTap == null
                    ? context.appColor(Colors.white38, surface: false)
                    : context.appColor(Colors.white70, surface: false),
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Nutrient extends StatelessWidget {
  const _Nutrient({
    required this.label,
    required this.value,
    this.color = const Color(0xFF10223C),
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.appColor(Color(0xFFF7F8FA), surface: true),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: TextStyle(
              color: context.appColor(Color(0xFF7B8495), surface: false),
              fontSize: 12,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
