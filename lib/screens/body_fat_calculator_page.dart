import '../theme/app_theme.dart';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../services/body_fat_calculator.dart';
import '../services/calorie_needs_calculator.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class BodyFatCalculatorPage extends StatefulWidget {
  const BodyFatCalculatorPage({super.key});

  @override
  State<BodyFatCalculatorPage> createState() => _BodyFatCalculatorPageState();
}

class _BodyFatCalculatorPageState extends State<BodyFatCalculatorPage> {
  final _age = TextEditingController(text: '25');
  final _weight = TextEditingController(text: '70');
  final _height = TextEditingController(text: '175');
  final _neck = TextEditingController(text: '38');
  final _waist = TextEditingController(text: '82');
  final _hip = TextEditingController(text: '95');
  BiologicalSex _sex = BiologicalSex.male;
  BodyFatResult? _result;
  String? _error;

  @override
  void dispose() {
    for (final controller in [_age, _weight, _height, _neck, _waist, _hip]) {
      controller.dispose();
    }
    super.dispose();
  }

  double _value(TextEditingController controller) =>
      double.tryParse(controller.text.replaceAll(',', '.')) ?? 0;

  void _calculate() {
    FocusScope.of(context).unfocus();
    try {
      final result = const BodyFatCalculator().calculate(
        sex: _sex,
        age: int.tryParse(_age.text) ?? 0,
        weightKg: _value(_weight),
        heightCm: _value(_height),
        neckCm: _value(_neck),
        waistCm: _value(_waist),
        hipCm: _sex == BiologicalSex.female ? _value(_hip) : null,
      );
      setState(() {
        _result = result;
        _error = null;
      });
    } on BodyFatException catch (error) {
      setState(() {
        _result = null;
        _error = context.tr(error.message);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(
          context.tr('Tana yog‘i kalkulyatori'),
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Text(
            context.tr('U.S. Navy va BMI usullarida tana yog‘ini hisoblash.'),
            style: TextStyle(
              color: context.appColor(Color(0xFF697386), surface: false),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              color: context.appColor(Color(0xFFF1F3F6), surface: true),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(LucideIcons.ruler, color: Color(0xFF2F5BEA)),
                SizedBox(width: 9),
                Expanded(
                  child: Text(
                    context.tr('O‘lchov birligi: kilogramm va santimetr'),
                    style: TextStyle(
                      color: context.appColor(
                        Color(0xFF2F5BEA),
                        surface: false,
                      ),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          SegmentedButton<BiologicalSex>(
            segments: [
              ButtonSegment(
                value: BiologicalSex.male,
                label: Text(context.tr('Erkak')),
              ),
              ButtonSegment(
                value: BiologicalSex.female,
                label: Text(context.tr('Ayol')),
              ),
            ],
            selected: {_sex},
            onSelectionChanged: (selection) => setState(() {
              _sex = selection.first;
              _result = null;
            }),
          ),
          const SizedBox(height: 14),
          _field(_age, context.tr('Yosh'), context.tr('yil')),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _field(_weight, context.tr('Vazn'), context.tr('kg')),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _field(_height, context.tr('Bo‘y'), context.tr('cm')),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _field(_neck, context.tr('Bo‘yin'), context.tr('cm')),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _field(
                  _waist,
                  context.tr(_sex == BiologicalSex.male ? 'Qorin' : 'Bel'),
                  context.tr('cm'),
                ),
              ),
            ],
          ),
          if (_sex == BiologicalSex.female) ...[
            const SizedBox(height: 14),
            _field(_hip, context.tr('Son aylanasi'), context.tr('cm')),
          ],
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Text(
              context.tr(
                'Erkak: qorinni kindik atrofidan o‘lchang. Ayol: belning eng ingichka va sonning eng keng joyini o‘lchang.',
              ),
              style: TextStyle(
                color: context.appColor(Color(0xFF697386), surface: false),
                fontSize: 12,
              ),
            ),
          ),
          FilledButton(
            onPressed: _calculate,
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              minimumSize: const Size.fromHeight(54),
            ),
            child: Text(
              context.tr('Hisoblash'),
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                _error!,
                style: TextStyle(
                  color: context.appColor(Colors.red, surface: false),
                ),
              ),
            ),
          if (_result != null) ...[
            const SizedBox(height: 22),
            _resultView(_result!),
          ],
        ],
      ),
    );
  }

  Widget _field(TextEditingController controller, String label, String suffix) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: label,
        suffixText: suffix,
        border: const OutlineInputBorder(),
      ),
    );
  }

  Widget _resultView(BodyFatResult result) {
    String formatted(double number, String unit) =>
        '${number.toStringAsFixed(1)}$unit';
    final progress = (result.navyPercent / 50).clamp(0.0, 1.0);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 28),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: context.appPanelColors,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
            color: Color(0x302F5BEA),
            blurRadius: 24,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            context.tr('Tana yog‘i foizi'),
            style: TextStyle(
              color: context.appColor(Colors.white, surface: false),
              fontSize: 19,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 18),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: progress),
            duration: const Duration(milliseconds: 900),
            curve: Curves.easeOutCubic,
            builder: (context, value, _) => CustomPaint(
              painter: _BodyFatRingPainter(value),
              child: SizedBox(
                width: 180,
                height: 180,
                child: Center(
                  child: Text(
                    formatted(result.navyPercent, '%'),
                    key: const Key('body-fat-result'),
                    style: TextStyle(
                      color: context.appColor(Colors.white, surface: false),
                      fontSize: 43,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BodyFatRingPainter extends CustomPainter {
  const _BodyFatRingPainter(this.progress);

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2 - 8;
    final background = Paint()
      ..color = Colors.white.withValues(alpha: .18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 11;
    final foreground = Paint()
      ..color = const Color(0xFFF1F3F6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 11
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, background);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      math.pi * 2 * progress,
      false,
      foreground,
    );
  }

  @override
  bool shouldRepaint(_BodyFatRingPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
