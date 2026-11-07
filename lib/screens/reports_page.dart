import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/nutrition_report.dart';
import '../services/food_log_service.dart';
import 'food_history_page.dart';
import 'meals_page.dart';

class ReportsPage extends StatefulWidget {
  const ReportsPage({
    super.key,
    required this.uid,
    required this.service,
    required this.dailyTarget,
    this.initialDate,
  });
  final String uid;
  final FoodLogService service;
  final double dailyTarget;
  final DateTime? initialDate;

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  ReportPeriod _period = ReportPeriod.week;
  late DateTime _anchor = DateUtils.dateOnly(
    widget.initialDate ?? DateTime.now(),
  );
  NutritionReport? _report;
  bool _loading = true, _failed = false;
  int _request = 0;
  DateTime get _today => DateUtils.dateOnly(DateTime.now());
  ReportRange get _range => ReportRange(_anchor, _period);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final request = ++_request;
    final range = _range;
    setState(() {
      _loading = true;
      _failed = false;
      _report = null;
    });
    try {
      final tomorrow = DateTime(_today.year, _today.month, _today.day + 1);
      final logs = await widget.service.loadRange(
        widget.uid,
        range.start,
        range.end.isAfter(tomorrow) ? tomorrow : range.end,
      );
      if (!mounted || request != _request) return;
      setState(() {
        _report = NutritionReport(range: range, logs: logs, today: _today);
        _loading = false;
      });
    } catch (_) {
      if (!mounted || request != _request) return;
      setState(() {
        _failed = true;
        _loading = false;
      });
    }
  }

  void _move(int direction) {
    final next = _range.adjacent(direction);
    if (next.isAfter(_today) || next.isBefore(DateTime(2000))) return;
    _anchor = next;
    _load();
  }

  Future<void> _calendar() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _anchor,
      firstDate: DateTime(2000),
      lastDate: _today,
    );
    if (!mounted || date == null) return;
    _anchor = date;
    _load();
  }

  void _openDay(DateTime day) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => FoodHistoryPage(
          uid: widget.uid,
          initialDate: day,
          service: widget.service,
        ),
      ),
    );
  }

  String _number(double value) => value.toStringAsFixed(0);
  String _value(NutritionTotals totals, String key, double value) =>
      '${totals.missing.contains(key) ? '≥ ' : ''}${_number(value)}';

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final dates = MaterialLocalizations.of(context);
    final range = _range;
    final last = DateTime(range.end.year, range.end.month, range.end.day - 1);
    final title = _period == ReportPeriod.day
        ? dates.formatMediumDate(range.start)
        : _period == ReportPeriod.month
        ? dates.formatMonthYear(range.start)
        : '${dates.formatShortDate(range.start)} – ${dates.formatShortDate(last)}';
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        key: const PageStorageKey('reports-scroll'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 700),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              context.tr('Hisobotlar'),
                              style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -.8,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              context.tr('Ovqatlanishingiz raqamlarda'),
                              style: TextStyle(color: colors.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                      IconButton.filledTonal(
                        onPressed: _calendar,
                        tooltip: context.tr('Kalendar'),
                        icon: const Icon(Icons.calendar_month_outlined),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  SegmentedButton<ReportPeriod>(
                    segments: [
                      ButtonSegment(
                        value: ReportPeriod.day,
                        label: Text(context.tr('Kunlik')),
                      ),
                      ButtonSegment(
                        value: ReportPeriod.week,
                        label: Text(context.tr('Haftalik')),
                      ),
                      ButtonSegment(
                        value: ReportPeriod.month,
                        label: Text(context.tr('Oylik')),
                      ),
                    ],
                    selected: {_period},
                    showSelectedIcon: false,
                    onSelectionChanged: (values) {
                      _period = values.first;
                      _load();
                    },
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      IconButton(
                        onPressed: range.adjacent(-1).isBefore(DateTime(2000))
                            ? null
                            : () => _move(-1),
                        tooltip: context.tr('Oldingi davr'),
                        icon: const Icon(Icons.chevron_left),
                      ),
                      Expanded(
                        child: TextButton(
                          onPressed: _calendar,
                          child: Text(title, textAlign: TextAlign.center),
                        ),
                      ),
                      IconButton(
                        onPressed: range.adjacent(1).isAfter(_today)
                            ? null
                            : () => _move(1),
                        tooltip: context.tr('Keyingi davr'),
                        icon: const Icon(Icons.chevron_right),
                      ),
                      TextButton(
                        onPressed: () {
                          _anchor = _today;
                          _load();
                        },
                        child: Text(context.tr('Bugun')),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (_loading)
                    const Padding(
                      padding: EdgeInsets.all(64),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (_failed)
                    _panel(
                      context,
                      Column(
                        children: [
                          Icon(
                            Icons.cloud_off_outlined,
                            color: colors.onSurfaceVariant,
                            size: 36,
                          ),
                          const SizedBox(height: 12),
                          Text(context.tr('Hisobotni yuklab bo‘lmadi.')),
                          TextButton.icon(
                            onPressed: _load,
                            icon: const Icon(Icons.refresh),
                            label: Text(context.tr('Qayta urinish')),
                          ),
                        ],
                      ),
                    )
                  else if (_report case final report?)
                    ..._content(context, report),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _panel(BuildContext context, Widget child, {bool accent = false}) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: accent ? colors.primaryContainer : colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: accent
              ? colors.primary.withValues(alpha: .2)
              : colors.outlineVariant.withValues(alpha: .5),
        ),
      ),
      child: child,
    );
  }

  Widget _heading(BuildContext context, String title, IconData icon) => Row(
    children: [
      Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
      const SizedBox(width: 10),
      Expanded(
        child: Text(
          context.tr(title),
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
        ),
      ),
    ],
  );

  List<Widget> _content(BuildContext context, NutritionReport report) {
    final colors = Theme.of(context).colorScheme;
    final total = report.totals;
    final foods = report.products.values.toList()
      ..sort((a, b) => b.totals.calories.compareTo(a.totals.calories));
    final target = widget.dailyTarget.isFinite && widget.dailyTarget > 0
        ? widget.dailyTarget
        : 0.0;
    final days = report.elapsedDays;
    final average = report.dailyAverage;
    final incomplete = total.missing.contains('calories');
    return [
      _panel(
        context,
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    context.tr('Jami kaloriya'),
                    style: TextStyle(color: colors.onPrimaryContainer),
                  ),
                ),
                Icon(Icons.insights_rounded, color: colors.primary),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.end,
              spacing: 8,
              children: [
                Text(
                  _value(total, 'calories', total.calories),
                  key: const Key('report-total'),
                  style: TextStyle(
                    fontSize: 44,
                    height: 1.1,
                    letterSpacing: -1.5,
                    fontWeight: FontWeight.w700,
                    color: colors.onPrimaryContainer,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 5),
                  child: Text(
                    context.tr('kcal'),
                    style: TextStyle(color: colors.onPrimaryContainer),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _stat(
                    context,
                    'Kunlik o‘rtacha',
                    '${incomplete ? '≥ ' : ''}${_number(average)} ${context.tr('kcal')}',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _stat(
                    context,
                    'Yozuvli kunlar',
                    '${report.loggedDays} / $days',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              context.tr('O‘rtacha bugungacha bo‘lgan barcha kunlar bo‘yicha.'),
              style: TextStyle(fontSize: 12, color: colors.onPrimaryContainer),
            ),
          ],
        ),
        accent: true,
      ),
      const SizedBox(height: 16),
      if (total.entries == 0) ...[
        _panel(
          context,
          Column(
            children: [
              Icon(
                Icons.restaurant_menu_rounded,
                size: 36,
                color: colors.primary,
              ),
              const SizedBox(height: 12),
              Text(
                context.tr('Bu davrda ovqat yozuvlari yo‘q.'),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                context.tr(
                  'Kundalikka ovqat qo‘shing — hisoblar shu yerda ko‘rinadi.',
                ),
                textAlign: TextAlign.center,
                style: TextStyle(color: colors.onSurfaceVariant),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
      ],
      _panel(
        context,
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _heading(context, 'Kaloriya dinamikasi', Icons.bar_chart_rounded),
            const SizedBox(height: 8),
            Text(
              '${context.tr('Kunlik maqsad')}: ${_number(target)} ${context.tr('kcal')}',
              style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12),
            ),
            const SizedBox(height: 20),
            _chart(context, report, target),
            const SizedBox(height: 12),
            Text(
              context.tr(
                'Kunni bosib, ovqatlarni ko‘ring. Chiziq — joriy kunlik maqsad.',
              ),
              style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12),
            ),
          ],
        ),
      ),
      const SizedBox(height: 16),
      _panel(
        context,
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _heading(context, 'Makronutrientlar', Icons.donut_large_rounded),
            const SizedBox(height: 20),
            _macro(
              context,
              'Oqsil',
              total,
              'protein',
              total.protein,
              colors.primary,
              total.protein * 4,
              total,
            ),
            _macro(
              context,
              'Uglevodlar',
              total,
              'carbohydrates',
              total.carbs,
              const Color(0xFF7CA9D2),
              total.carbs * 4,
              total,
            ),
            _macro(
              context,
              'Yog‘lar',
              total,
              'fat',
              total.fat,
              const Color(0xFFD4AF72),
              total.fat * 9,
              total,
            ),
            Text(
              context.tr(
                'Ulushlar oqsil va uglevod uchun 4, yog‘ uchun 9 kcal/g asosida.',
              ),
              style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12),
            ),
          ],
        ),
      ),
      const SizedBox(height: 16),
      _panel(
        context,
        Column(
          children: [
            _heading(
              context,
              'Ovqatlanish taqsimoti',
              Icons.restaurant_outlined,
            ),
            const SizedBox(height: 12),
            for (final meal in MealType.values) ...[
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(
                        color: meal.color.withValues(alpha: .12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        meal.icon,
                        size: 20,
                        color: meal.accent(context),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: Text(meal.localizedTitle(context))),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${_value(report.meals[meal.name]!, 'calories', report.meals[meal.name]!.calories)} ${context.tr('kcal')}',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        Text(
                          incomplete
                              ? '—'
                              : '${total.calories == 0 ? 0 : (report.meals[meal.name]!.calories / total.calories * 100).round()}%',
                          style: TextStyle(
                            color: colors.onSurfaceVariant,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      const SizedBox(height: 16),
      _panel(
        context,
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _heading(
              context,
              'Iste’mol qilingan mahsulotlar',
              Icons.receipt_long_outlined,
            ),
            const SizedBox(height: 10),
            for (final item in foods)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  item.food.displayNameFor(
                    Localizations.localeOf(context).languageCode,
                  ),
                ),
                subtitle: Text(
                  '${item.amount.toStringAsFixed(1)} ${context.tr(item.food.basisUnit)} · ${item.totals.entries} ${context.tr('ta yozuv')}',
                ),
                trailing: Text(
                  '${_value(item.totals, 'calories', item.totals.calories)}\n${context.tr('kcal')}',
                  textAlign: TextAlign.end,
                ),
              ),
            if (foods.isEmpty)
              Text('—', style: TextStyle(color: colors.onSurfaceVariant)),
          ],
        ),
      ),
      const SizedBox(height: 16),
      Text(
        context.tr(
          'Hisoblar saqlangan porsiyalarga asoslangan. Yozuvsiz kun iste’mol qilinmaganini anglatmaydi. Maqsad joriy profilingizdan olinadi.',
        ),
        style: TextStyle(
          color: colors.onSurfaceVariant,
          fontSize: 12,
          height: 1.5,
        ),
      ),
      if (total.missing.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            context.tr(
              'Ayrim oziq qiymatlari yetishmaydi. ≥ — ma’lum qiymatlar yig‘indisi; ulushlar to‘liq emas.',
            ),
            style: TextStyle(color: colors.error, fontSize: 12),
          ),
        ),
    ];
  }

  Widget _stat(BuildContext context, String label, String value) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        context.tr(label),
        style: TextStyle(
          fontSize: 12,
          color: Theme.of(context).colorScheme.onPrimaryContainer,
        ),
      ),
      const SizedBox(height: 5),
      Text(
        value,
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).colorScheme.onPrimaryContainer,
        ),
      ),
    ],
  );

  Widget _macro(
    BuildContext context,
    String label,
    NutritionTotals totals,
    String key,
    double grams,
    Color color,
    double energy,
    NutritionTotals all,
  ) {
    final sum = all.protein * 4 + all.carbs * 4 + all.fat * 9;
    final incomplete = [
      'protein',
      'fat',
      'carbohydrates',
    ].any(all.missing.contains);
    final share = sum > 0 ? energy / sum : 0.0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: Text(context.tr(label))),
              Text(
                '${_value(totals, key, grams)} ${context.tr('g')}  ·  ${incomplete ? '—' : '${(share * 100).round()}%'}',
              ),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: incomplete ? 0 : share.clamp(0, 1),
            minHeight: 7,
            borderRadius: BorderRadius.circular(10),
            color: color,
            backgroundColor: color.withValues(alpha: .12),
          ),
        ],
      ),
    );
  }

  Widget _chart(BuildContext context, NutritionReport report, double target) {
    final colors = Theme.of(context).colorScheme;
    final dates = MaterialLocalizations.of(context);
    final days = report.range.days;
    final maximum = math.max(
      target,
      report.dailyTotals.values.fold(0.0, (a, b) => math.max(a, b.calories)),
    );
    final ceiling = maximum > 0 ? maximum * 1.15 : 100.0;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = math.max(constraints.maxWidth, days.length * 32.0);
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: width,
            height: 206,
            child: Stack(
              children: [
                Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  height: 166,
                  child: CustomPaint(
                    painter: _GridPainter(
                      colors.outlineVariant,
                      target / ceiling,
                      colors.primary,
                    ),
                  ),
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (final day in days)
                      Expanded(
                        child: Builder(
                          builder: (context) {
                            final total = report.dailyTotals[day];
                            final future = day.isAfter(_today);
                            final value = total?.calories ?? 0;
                            final label =
                                '${dates.formatFullDate(day)}: ${future
                                    ? context.tr('Kelajak kun')
                                    : total == null || total.entries == 0
                                    ? context.tr('Yozuv yo‘q')
                                    : '${_value(total, 'calories', value)} ${context.tr('kcal')}'}';
                            return Semantics(
                              label: label,
                              button: !future,
                              child: Tooltip(
                                message: label,
                                child: InkWell(
                                  key: ValueKey(
                                    'report-day-${day.toIso8601String()}',
                                  ),
                                  onTap: future ? null : () => _openDay(day),
                                  borderRadius: BorderRadius.circular(8),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 5,
                                    ),
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        SizedBox(
                                          height: 166,
                                          child: Align(
                                            alignment: Alignment.bottomCenter,
                                            child: Container(
                                              width: days.length == 1 ? 64 : 24,
                                              height: value > 0
                                                  ? (value / ceiling * 166)
                                                        .clamp(3, 166)
                                                  : 3,
                                              decoration: BoxDecoration(
                                                color: future
                                                    ? colors.outlineVariant
                                                          .withValues(
                                                            alpha: .25,
                                                          )
                                                    : total == null ||
                                                          total.entries == 0
                                                    ? colors.outlineVariant
                                                    : colors.primary,
                                                borderRadius:
                                                    const BorderRadius.vertical(
                                                      top: Radius.circular(6),
                                                    ),
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 10),
                                        Text(
                                          '${day.day}',
                                          maxLines: 1,
                                          softWrap: false,
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: future
                                                ? colors.outline
                                                : colors.onSurfaceVariant,
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _GridPainter extends CustomPainter {
  _GridPainter(this.grid, this.goal, this.accent);
  final Color grid, accent;
  final double goal;
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = grid.withValues(alpha: .5)
      ..strokeWidth = 1;
    for (var i = 0; i <= 3; i++) {
      final y = size.height * i / 3;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
    if (goal <= 0) return;
    paint.color = accent.withValues(alpha: .7);
    final y = size.height * (1 - goal);
    for (double x = 0; x < size.width; x += 9) {
      canvas.drawLine(
        Offset(x, y),
        Offset(math.min(x + 5, size.width), y),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_GridPainter oldDelegate) =>
      oldDelegate.grid != grid ||
      oldDelegate.goal != goal ||
      oldDelegate.accent != accent;
}
