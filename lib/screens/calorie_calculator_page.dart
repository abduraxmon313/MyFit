import '../theme/app_theme.dart';
import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../services/calorie_needs_calculator.dart';

class CalorieCalculatorPage extends StatefulWidget {
  const CalorieCalculatorPage({super.key});

  @override
  State<CalorieCalculatorPage> createState() => _CalorieCalculatorPageState();
}

class _CalorieCalculatorPageState extends State<CalorieCalculatorPage> {
  static const _green = Color(0xFF13B957);
  final _age = TextEditingController(text: '25');
  final _height = TextEditingController(text: '175');
  final _weight = TextEditingController(text: '70');
  final _fat = TextEditingController(text: '20');
  final _calculator = const CalorieNeedsCalculator();
  BiologicalSex _sex = BiologicalSex.male;
  BmrFormula _formula = BmrFormula.mifflinStJeor;
  double _activity = 1.2;
  CalorieNeedsResult? _result;
  String? _error;
  bool _showGainInfo = false;

  bool get _isBmrOnly => (_activity - 1.0).abs() < 0.001;

  static final _activities = <double, String>{
    1.0: 'BMR — dam olish holati',
    1.2: 'Kamharakat: mashqsiz yoki juda kam',
    1.375: 'Yengil: haftasiga 1–3 marta',
    1.465: 'O‘rtacha: haftasiga 4–5 marta',
    1.55: 'Faol: har kuni yoki haftasiga 3–4 intensiv',
    1.725: 'Juda faol: haftasiga 6–7 intensiv',
    1.9: 'O‘ta faol: har kuni juda intensiv/jismoniy ish',
  };

  @override
  void dispose() {
    _age.dispose();
    _height.dispose();
    _weight.dispose();
    _fat.dispose();
    super.dispose();
  }

  void _calculate() {
    FocusScope.of(context).unfocus();
    try {
      final result = _calculator.calculate(
        age: int.tryParse(_age.text) ?? 0,
        sex: _sex,
        heightCm: double.tryParse(_height.text.replaceAll(',', '.')) ?? 0,
        weightKg: double.tryParse(_weight.text.replaceAll(',', '.')) ?? 0,
        activityFactor: _activity,
        formula: _formula,
        bodyFatPercent: double.tryParse(_fat.text.replaceAll(',', '.')),
      );
      setState(() {
        _result = result;
        _error = null;
        _showGainInfo = false;
      });
    } on CalorieNeedsException catch (error) {
      setState(() {
        _result = null;
        _error = context.tr(error.message);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.appColor(Color(0xFFFAFCFA), surface: true),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(
          context.tr('Kunlik kaloriya'),
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Text(
            context.tr(
              'Calculator.net bilan bir xil BMR formulalari va faollik koeffitsiyentlari.',
            ),
            style: TextStyle(
              color: context.appColor(Color(0xFF697386), surface: false),
            ),
          ),
          const SizedBox(height: 18),
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
            onSelectionChanged: (value) => setState(() => _sex = value.first),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _field(_age, context.tr('Yosh'), context.tr('yil')),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _field(_height, context.tr('Bo‘y'), context.tr('cm')),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _field(_weight, context.tr('Vazn'), context.tr('kg')),
              ),
            ],
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<double>(
            initialValue: _activity,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: context.tr('Faollik'),
              border: OutlineInputBorder(),
            ),
            items: _activities.entries
                .map(
                  (item) => DropdownMenuItem(
                    value: item.key,
                    child: Text(
                      context.tr(item.value),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
                .toList(),
            onChanged: (value) {
              setState(() {
                _activity = value ?? 1.2;
                _result = null;
                _error = null;
                _showGainInfo = false;
              });
            },
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<BmrFormula>(
            initialValue: _formula,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: context.tr('BMR formulasi'),
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(
                value: BmrFormula.mifflinStJeor,
                child: Text(
                  'Mifflin–St Jeor',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              DropdownMenuItem(
                value: BmrFormula.revisedHarrisBenedict,
                child: Text(
                  'Revised Harris–Benedict',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              DropdownMenuItem(
                value: BmrFormula.katchMcArdle,
                child: Text(
                  'Katch–McArdle',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
            onChanged: (value) =>
                setState(() => _formula = value ?? BmrFormula.mifflinStJeor),
          ),
          if (_formula == BmrFormula.katchMcArdle) ...[
            const SizedBox(height: 14),
            _field(_fat, context.tr('Tana yog‘i'), '%'),
          ],
          const SizedBox(height: 18),
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
            if (_isBmrOnly) _bmrOnlyResult(_result!) else _results(_result!),
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

  Widget _bmrOnlyResult(CalorieNeedsResult result) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: context.appPanelColors,
          ),
        ),
        child: Stack(
          children: [
            const Positioned(
              right: -54,
              top: -58,
              child: _BmrGlow(size: 170, opacity: .10),
            ),
            const Positioned(
              left: -48,
              bottom: -70,
              child: _BmrGlow(size: 150, opacity: .08),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 22, 22, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: context
                              .appColor(Colors.white, surface: true)
                              .withValues(alpha: .15),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: const Icon(
                          Icons.local_fire_department_rounded,
                          color: Color(0xFFC8FFD9),
                          size: 27,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.tr('BAZAL METABOLIZM'),
                            style: TextStyle(
                              color: context.appColor(
                                Color(0xFFC8FFD9),
                                surface: false,
                              ),
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            context.tr('Dam olish energiyasi'),
                            style: TextStyle(
                              color: context.appColor(
                                Colors.white,
                                surface: false,
                              ),
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0, end: result.bmr),
                          duration: const Duration(milliseconds: 850),
                          curve: Curves.easeOutCubic,
                          builder: (context, value, _) => Text(
                            '${value.round()}',
                            key: const Key('bmr-only-value'),
                            style: TextStyle(
                              color: context.appColor(
                                Colors.white,
                                surface: false,
                              ),
                              fontSize: 54,
                              height: .95,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -2,
                            ),
                          ),
                        ),
                      ),
                      Container(
                        margin: const EdgeInsets.only(bottom: 3),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 13,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: context
                              .appColor(Colors.white, surface: true)
                              .withValues(alpha: .16),
                          borderRadius: BorderRadius.circular(99),
                          border: Border.all(
                            color: context
                                .appColor(Colors.white, surface: true)
                                .withValues(alpha: .20),
                          ),
                        ),
                        child: Text(
                          context.tr('kcal'),
                          style: TextStyle(
                            color: context.appColor(
                              Colors.white,
                              surface: false,
                            ),
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: context
                          .appColor(Color(0xFF043D29), surface: true)
                          .withValues(alpha: .28),
                      borderRadius: BorderRadius.circular(17),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.bedtime_outlined,
                          color: Color(0xFFC8FFD9),
                          size: 20,
                        ),
                        SizedBox(width: 9),
                        Expanded(
                          child: Text(
                            context.tr(
                              'Tanangiz to‘liq dam olganda hayotiy funksiyalar uchun sarflaydigan energiya.',
                            ),
                            style: TextStyle(
                              color: context.appColor(
                                Colors.white,
                                surface: false,
                              ),
                              fontSize: 13,
                              height: 1.4,
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
      ),
    );
  }

  Widget _results(CalorieNeedsResult result) {
    final lossRows = [
      (context.tr('Vaznni saqlash'), result.maintenance, null),
      (
        context.tr('Yengil vazn tashlash'),
        result.mildLoss,
        '−0,25 kg / ${context.tr('hafta')}',
      ),
      (
        context.tr('Vazn tashlash'),
        result.weightLoss,
        '−0,5 kg / ${context.tr('hafta')}',
      ),
      (
        context.tr('Tez vazn tashlash'),
        result.extremeLoss,
        '−1 kg / ${context.tr('hafta')}',
      ),
    ];
    final gainRows = [
      (
        context.tr('Yengil vazn olish'),
        result.mildGain,
        '+0,25 kg / ${context.tr('hafta')}',
      ),
      (
        context.tr('Vazn olish'),
        result.weightGain,
        '+0,5 kg / ${context.tr('hafta')}',
      ),
      (
        context.tr('Tez vazn olish'),
        result.fastGain,
        '+1 kg / ${context.tr('hafta')}',
      ),
    ];
    return Column(
      key: const Key('calorie-goal-results'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'BMR  ·  ${result.bmr.round()} ${context.tr('kcal')}',
          style: TextStyle(
            color: context.appColor(Color(0xFF697386), surface: false),
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 14),
        ...lossRows.indexed.map(
          (item) => _goalCard(item.$2, highlighted: item.$1 == 0),
        ),
        const SizedBox(height: 6),
        Material(
          color: Colors.transparent,
          child: InkWell(
            key: const Key('toggle-gain-info'),
            borderRadius: BorderRadius.circular(16),
            onTap: () => setState(() => _showGainInfo = !_showGainInfo),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              width: double.infinity,
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: _showGainInfo
                    ? context.appColor(Color(0xFF08753D), surface: true)
                    : context.appColor(Color(0xFFEAF7EF), surface: true),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _showGainInfo
                      ? context.appColor(Color(0xFF08753D), surface: true)
                      : context.appColor(Color(0xFFCDEED9), surface: true),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: _showGainInfo
                          ? context
                                .appColor(Colors.white, surface: true)
                                .withValues(alpha: .15)
                          : context.appColor(Colors.white, surface: true),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Icon(
                      _showGainInfo
                          ? Icons.close_rounded
                          : Icons.trending_up_rounded,
                      color: _showGainInfo
                          ? context.appColor(Colors.white, surface: true)
                          : context.appColor(Color(0xFF13B957), surface: true),
                      size: 25,
                    ),
                  ),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _showGainInfo
                              ? context.tr('Vazn olish rejalarini yopish')
                              : context.tr('Vazn olish rejalarini ko‘rish'),
                          style: TextStyle(
                            color: _showGainInfo
                                ? context.appColor(Colors.white, surface: false)
                                : context.appColor(
                                    Color(0xFF08753D),
                                    surface: false,
                                  ),
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          _showGainInfo
                              ? context.tr('Vazn tashlash natijalariga qayting')
                              : context.tr('Kaloriya maqsadlarini oching'),
                          style: TextStyle(
                            color: _showGainInfo
                                ? context.appColor(
                                    Colors.white70,
                                    surface: false,
                                  )
                                : context.appColor(
                                    Color(0xFF5C7A69),
                                    surface: false,
                                  ),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    _showGainInfo
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.chevron_right_rounded,
                    color: _showGainInfo
                        ? context.appColor(Colors.white, surface: true)
                        : context.appColor(Color(0xFF08753D), surface: true),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (_showGainInfo) ...[
          const SizedBox(height: 10),
          ...gainRows.map((row) => _goalCard(row)),
        ],
      ],
    );
  }

  Widget _goalCard((String, double, String?) row, {bool highlighted = false}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        gradient: highlighted
            ? LinearGradient(colors: context.appPanelColors)
            : null,
        color: highlighted
            ? null
            : context.appColor(Colors.white, surface: true),
        borderRadius: BorderRadius.circular(16),
        border: highlighted
            ? null
            : Border.all(
                color: context.appColor(Color(0xFFE8ECE9), surface: true),
              ),
        boxShadow: [
          BoxShadow(
            color: highlighted
                ? context.appColor(Color(0x2413B957), surface: true)
                : context.appColor(Color(0x0D10223C), surface: true),
            blurRadius: 18,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: highlighted
                  ? context
                        .appColor(Colors.white, surface: true)
                        .withValues(alpha: .17)
                  : context.appColor(Color(0xFFEAF7EF), surface: true),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              highlighted
                  ? Icons.balance_rounded
                  : Icons.local_fire_department_rounded,
              color: highlighted
                  ? context.appColor(Colors.white, surface: true)
                  : _green,
              size: 23,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  row.$1,
                  style: TextStyle(
                    color: highlighted
                        ? context.appColor(Colors.white, surface: false)
                        : context.appColor(Color(0xFF10223C), surface: false),
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${row.$2.round()} ${context.tr('kcal')}',
                  style: TextStyle(
                    color: highlighted
                        ? context.appColor(Colors.white, surface: false)
                        : _green,
                    fontSize: 25,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (row.$3 != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 11,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: context.appColor(Color(0xFFEAF7EF), surface: true),
                      borderRadius: BorderRadius.circular(99),
                      border: Border.all(
                        color: context.appColor(
                          Color(0xFFCDEED9),
                          surface: true,
                        ),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.trending_flat_rounded,
                          size: 17,
                          color: Color(0xFF08753D),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          row.$3!,
                          style: TextStyle(
                            color: context.appColor(
                              Color(0xFF08753D),
                              surface: false,
                            ),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BmrGlow extends StatelessWidget {
  const _BmrGlow({required this.size, required this.opacity});

  final double size;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: context
            .appColor(Colors.white, surface: true)
            .withValues(alpha: opacity),
      ),
    );
  }
}
