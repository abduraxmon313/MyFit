import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../models/food_nutrition.dart';

/// Displays the already-scaled portion. Never rounds before scaling.
class NutritionFacts extends StatelessWidget {
  const NutritionFacts({super.key, required this.food, required this.portion});
  final FoodNutrition food;
  final String portion;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final comma = Localizations.localeOf(context).languageCode != 'en';
    String number(double value, int digits) {
      var text = value.toStringAsFixed(digits);
      if (digits > 0) text = text.replaceFirst(RegExp(r'\.?0+$'), '');
      return comma ? text.replaceAll('.', ',') : text;
    }

    String grams(double value, [int digits = 2]) =>
        '${number(value, digits)} ${context.tr('g')}';
    String core(String key, double value) => food.missingNutrients.contains(key)
        ? '—'
        : key == 'calories'
        ? number(value, 0)
        : grams(value);
    String optional(
      String key,
      double value, {
      bool mg = false,
      int digits = 2,
    }) => value > 0 || food.knownNutrients.contains(key)
        ? '${number(value, mg ? 0 : digits)} ${context.tr(mg ? 'mg' : 'g')}'
        : '—';
    final dark = Theme.of(context).brightness == Brightness.dark;
    final accent = dark ? const Color(0xFFB3C7D9) : const Color(0xFF263D52);
    Widget row(
      String label,
      String value, {
      bool bold = false,
      bool indent = false,
      IconData? icon,
    }) => Padding(
      padding: EdgeInsets.fromLTRB(indent ? 15 : 0, 12, 0, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: .08),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(icon, color: accent, size: 17),
            ),
            const SizedBox(width: 10),
          ] else if (indent) ...[
            Container(
              width: 3,
              height: 16,
              margin: const EdgeInsets.only(top: 3),
              decoration: BoxDecoration(
                color: colors.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 10),
          ],
          Expanded(
            flex: 5,
            child: Text(
              context.tr(label),
              style: TextStyle(
                color: bold ? colors.onSurface : colors.onSurfaceVariant,
                fontSize: bold ? 14 : 12.5,
                height: 1.5,
                fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Flexible(
            flex: 4,
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(
                fontSize: bold ? 16 : 13,
                color: colors.onSurface,
                fontFeatures: const [FontFeature.tabularFigures()],
                height: 1.4,
                fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
    Widget panel(List<Widget> children) => Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: dark ? colors.outlineVariant : const Color(0xFFE1E7ED),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
    Widget summary(String label, String value) => Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 8),
        margin: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: dark ? colors.surfaceContainerLow : const Color(0xFFF1F5F8),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          children: [
            Text(
              context.tr(label),
              style: TextStyle(color: colors.onSurface, fontSize: 14),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colors.onSurface,
                fontSize: 23,
                fontWeight: FontWeight.w600,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
    final divider = Divider(
      height: 1,
      thickness: 1,
      color: colors.outlineVariant.withValues(alpha: .55),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            summary('Kaloriya', core('calories', food.calories)),
            summary('Yog‘', core('fat', food.fat)),
          ],
        ),
        Row(
          children: [
            summary('Uglevod', core('carbohydrates', food.carbohydrates)),
            summary('Oqsil', core('protein', food.protein)),
          ],
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: .09),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.analytics_outlined, color: accent, size: 21),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                context.tr('Oziq qiymati'),
                style: TextStyle(
                  color: colors.onSurface,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -.5,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
          decoration: BoxDecoration(
            color: dark ? colors.surfaceContainerLow : const Color(0xFFEDF2F6),
            borderRadius: BorderRadius.circular(16),
          ),
          child: row(
            'Porsiya',
            portion,
            bold: true,
            icon: Icons.scale_outlined,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF263D52), Color(0xFF17293B)],
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.local_fire_department_outlined,
                    color: Color(0xFFCCDCE9),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      context.tr('Energiya qiymati'),
                      style: const TextStyle(
                        color: Color(0xFFDAE4ED),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                food.missingNutrients.contains('calories')
                    ? '—'
                    : '${number(food.calories * 4.184, 0)} ${context.tr('kJ')}\n${number(food.calories, 0)} ${context.tr('kcal')}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 25,
                  height: 1.35,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -.4,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        panel([
          row(
            'Yog‘',
            core('fat', food.fat),
            bold: true,
            icon: Icons.water_drop_outlined,
          ),
          divider,
          row(
            'To‘yingan yog‘lar',
            optional('saturatedFat', food.saturatedFat, digits: 3),
            indent: true,
          ),
          row(
            'Bir to‘yinmagan yog‘lar',
            food.monounsaturatedFat == null
                ? '—'
                : grams(food.monounsaturatedFat!, 3),
            indent: true,
          ),
          row(
            'Ko‘p to‘yinmagan yog‘lar',
            food.polyunsaturatedFat == null
                ? '—'
                : grams(food.polyunsaturatedFat!, 3),
            indent: true,
          ),
        ]),
        panel([
          row(
            'Uglevod',
            core('carbohydrates', food.carbohydrates),
            bold: true,
            icon: Icons.grain_rounded,
          ),
          divider,
          row('Shakar', optional('sugars', food.sugars), indent: true),
          row('Kletchatka', optional('fiber', food.fiber), indent: true),
        ]),
        panel([
          row(
            'Oqsil',
            core('protein', food.protein),
            bold: true,
            icon: Icons.fitness_center_outlined,
          ),
        ]),
        panel([
          row(
            'Natriy',
            optional('sodiumMg', food.sodiumMg, mg: true),
            icon: Icons.scatter_plot_outlined,
          ),
          divider,
          row(
            'Xolesterin',
            optional('cholesterolMg', food.cholesterolMg, mg: true),
            icon: Icons.monitor_heart_outlined,
          ),
          divider,
          row(
            'Kaliy',
            optional('potassiumMg', food.potassiumMg, mg: true),
            icon: Icons.bolt_outlined,
          ),
        ]),
      ],
    );
  }
}
