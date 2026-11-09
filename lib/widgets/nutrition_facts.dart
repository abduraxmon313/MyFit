import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../models/food_nutrition.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

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
        ? '${number(value, 0)} ${context.tr('kcal')}'
        : grams(value);
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
    Widget summary(String label, String value) => Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 8),
        margin: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: dark ? colors.surfaceContainerLow : const Color(0xFFF1F5F8),
          borderRadius: BorderRadius.circular(12),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
          decoration: BoxDecoration(
            color: dark ? colors.surfaceContainerLow : const Color(0xFFEDF2F6),
            borderRadius: BorderRadius.circular(12),
          ),
          child: row('Porsiya', portion, bold: true, icon: LucideIcons.scale),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            summary('Kaloriya', core('calories', food.calories)),
            summary('Oqsil', core('protein', food.protein)),
          ],
        ),
        Row(
          children: [
            summary('Uglevod', core('carbohydrates', food.carbohydrates)),
            summary('Yog‘', core('fat', food.fat)),
          ],
        ),
      ],
    );
  }
}
