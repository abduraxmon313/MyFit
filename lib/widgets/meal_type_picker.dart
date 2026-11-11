import 'package:flutter/material.dart';

import '../screens/meals_page.dart';

/// Meal the user is most likely logging now (local time).
MealType suggestedMealType([DateTime? now]) {
  final hour = (now ?? DateTime.now()).hour;
  if (hour >= 4 && hour < 11) return MealType.breakfast;
  if (hour >= 11 && hour < 16) return MealType.lunch;
  if (hour >= 16 && hour < 21) return MealType.dinner;
  return MealType.fifthSnack;
}

/// Chips for choosing which meal a scanned food goes to.
class MealTypePicker extends StatelessWidget {
  const MealTypePicker({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final MealType value;
  final ValueChanged<MealType> onChanged;

  static const order = [
    MealType.breakfast,
    MealType.lunch,
    MealType.dinner,
    MealType.snack,
    MealType.fifthSnack,
  ];

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      for (final meal in order)
        ChoiceChip(
          key: Key('meal-${meal.name}'),
          selected: meal == value,
          showCheckmark: false,
          avatar: Icon(meal.icon, size: 16, color: meal.accent(context)),
          label: Text(meal.localizedTitle(context)),
          onSelected: (_) => onChanged(meal),
        ),
    ],
  );
}
