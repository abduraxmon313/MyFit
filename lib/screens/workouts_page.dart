import '../theme/app_theme.dart';
import 'package:flutter/material.dart';

import '../data/workout_catalog.dart';
import '../models/workout.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../widgets/app_ui.dart';

class WorkoutsPage extends StatefulWidget {
  const WorkoutsPage({
    super.key,
    required this.weightKg,
    required this.logs,
    required this.onAdded,
    required this.onRemoved,
  });

  final double weightKg;
  final List<WorkoutLog> logs;
  final ValueChanged<WorkoutLog> onAdded;
  final ValueChanged<int> onRemoved;

  @override
  State<WorkoutsPage> createState() => _WorkoutsPageState();
}

class _WorkoutsPageState extends State<WorkoutsPage> {
  WorkoutCategory? _category;
  String _query = '';

  String _categoryName(WorkoutCategory category) => switch (category) {
    WorkoutCategory.cardio => 'Kardio',
    WorkoutCategory.strength => 'Kuch',
    WorkoutCategory.bodyweight => 'Tana vazni',
    WorkoutCategory.flexibility => 'Egiluvchanlik',
    WorkoutCategory.sport => 'Sport',
  };

  Future<void> _add(Workout workout) async {
    var minutes = 30.0;
    final result = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) {
          final calories = workout.calories(
            weightKg: widget.weightKg,
            minutes: minutes.round(),
          );
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 4, 22, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    workout.name,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${minutes.round()} daqiqa · ≈ ${calories.round()} kcal',
                    style: TextStyle(
                      color: context.appColor(
                        Color(0xFF61716A),
                        surface: false,
                      ),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Slider(
                    value: minutes,
                    min: 5,
                    max: 180,
                    divisions: 35,
                    label: '${minutes.round()} daqiqa',
                    onChanged: (v) => setSheetState(() => minutes = v),
                  ),
                  FilledButton.icon(
                    onPressed: () => Navigator.pop(context, minutes.round()),
                    icon: const Icon(LucideIcons.plus),
                    label: const Text('Mashqni qo‘shish'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
    if (result == null || !mounted) return;
    widget.onAdded(
      WorkoutLog(
        workout: workout,
        minutes: result,
        calories: workout.calories(weightKg: widget.weightKg, minutes: result),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = kWorkoutCatalog
        .where(
          (w) =>
              (_category == null || w.category == _category) &&
              w.name.toLowerCase().contains(_query.toLowerCase()),
        )
        .toList();
    final totalMinutes = widget.logs.fold<int>(
      0,
      (sum, log) => sum + log.minutes,
    );
    final totalCalories = widget.logs.fold<double>(
      0,
      (sum, log) => sum + log.calories,
    );
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
            sliver: SliverList.list(
              children: [
                Text(
                  'Mashqlar',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -.6,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Harakatni kuzating, maqsadingizga yaqinlashing',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 13.5,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _Summary(
                        value: '$totalMinutes',
                        label: 'daqiqa',
                        icon: LucideIcons.timer,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _Summary(
                        value: '${totalCalories.round()}',
                        label: 'kcal',
                        icon: LucideIcons.flame,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  onChanged: (v) => setState(() => _query = v),
                  decoration: const InputDecoration(
                    hintText: 'Mashqni qidiring',
                    prefixIcon: Icon(LucideIcons.search, size: 18),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 42,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      ChoiceChip(
                        label: const Text('Hammasi'),
                        selected: _category == null,
                        onSelected: (_) => setState(() => _category = null),
                      ),
                      ...WorkoutCategory.values.map(
                        (c) => Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: ChoiceChip(
                            label: Text(_categoryName(c)),
                            selected: _category == c,
                            onSelected: (_) => setState(() => _category = c),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (widget.logs.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  const AppSectionHeader(title: 'Bugungi mashqlar'),
                  const SizedBox(height: 8),
                  ...widget.logs.asMap().entries.map(
                    (e) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: AppIconTile(icon: e.value.workout.icon),
                      title: Text(e.value.workout.name),
                      subtitle: Text(
                        '${e.value.minutes} daqiqa · ${e.value.calories.round()} kcal',
                      ),
                      trailing: IconButton(
                        tooltip: MaterialLocalizations.of(
                          context,
                        ).deleteButtonTooltip,
                        icon: Icon(
                          LucideIcons.trash2,
                          size: 19,
                          color: Theme.of(context).colorScheme.error,
                        ),
                        onPressed: () => widget.onRemoved(e.key),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                AppSectionHeader(title: '${filtered.length} ta mashq'),
                const SizedBox(height: 4),
              ],
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
            sliver: SliverGrid.builder(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: MediaQuery.sizeOf(context).width >= 1100
                    ? 4
                    : MediaQuery.sizeOf(context).width >= 700
                    ? 3
                    : MediaQuery.sizeOf(context).width < 360 &&
                          MediaQuery.textScalerOf(context).scale(14) > 18
                    ? 1
                    : 2,
                mainAxisExtent:
                    124 + (MediaQuery.textScalerOf(context).scale(14) - 14) * 6,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
              ),
              itemCount: filtered.length,
              itemBuilder: (_, i) {
                final w = filtered[i];
                return AppCard(
                  onTap: () => _add(w),
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          AppIconTile(icon: w.icon, size: 36),
                          const Spacer(),
                          Icon(
                            LucideIcons.plus,
                            size: 16,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                        ],
                      ),
                      const Spacer(),
                      Text(
                        w.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _categoryName(w.category),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({
    required this.value,
    required this.label,
    required this.icon,
  });
  final String value;
  final String label;
  final IconData icon;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          AppIconTile(icon: icon, size: 36),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    color: scheme.onSurface,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -.4,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                Text(
                  label,
                  style: TextStyle(
                    color: scheme.onSurfaceVariant,
                    fontSize: 12.5,
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
