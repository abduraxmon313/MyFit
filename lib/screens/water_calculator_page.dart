import '../theme/app_theme.dart';
import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';

class WaterCalculatorPage extends StatefulWidget {
  const WaterCalculatorPage({super.key});

  @override
  State<WaterCalculatorPage> createState() => _WaterCalculatorPageState();
}

class _WaterCalculatorPageState extends State<WaterCalculatorPage> {
  final _weight = TextEditingController(text: '70');
  final _exercise = TextEditingController(text: '30');
  bool _hotWeather = false;
  double? _liters;
  String? _error;

  @override
  void dispose() {
    _weight.dispose();
    _exercise.dispose();
    super.dispose();
  }

  void _calculate() {
    final weight = double.tryParse(_weight.text.replaceAll(',', '.')) ?? 0;
    final minutes = double.tryParse(_exercise.text.replaceAll(',', '.')) ?? 0;
    if (!weight.isFinite ||
        !minutes.isFinite ||
        weight < 25 ||
        weight > 350 ||
        minutes < 0 ||
        minutes > 600) {
      setState(() {
        _liters = null;
        _error = context.tr('Vazn yoki mashq davomiyligini to‘g‘ri kiriting.');
      });
      return;
    }
    setState(() {
      final baseLiters = weight * 0.030;
      final exerciseLiters = minutes / 60 * 0.35;
      final heatLiters = _hotWeather ? 0.30 : 0;
      _liters = baseLiters + exerciseLiters + heatLiters;
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.appColor(Color(0xFFFAFCFA), surface: true),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(
          context.tr('Kunlik suv miqdori'),
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            context.tr(
              'Vazn, mashq davomiyligi va ob-havoga qarab kunlik ehtiyojingizni hisoblang.',
            ),
            style: TextStyle(
              color: context.appColor(Color(0xFF697386), surface: false),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 18),
          TextField(
            controller: _weight,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: context.tr('Vazn'),
              suffixText: context.tr('kg'),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _exercise,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: context.tr('Kunlik mashq'),
              suffixText: context.tr('daqiqa'),
              border: OutlineInputBorder(),
            ),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(context.tr('Issiq ob-havo yoki ko‘p terlash')),
            value: _hotWeather,
            onChanged: (value) => setState(() => _hotWeather = value),
          ),
          const SizedBox(height: 10),
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
          if (_liters != null) ...[
            const SizedBox(height: 22),
            Container(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 22),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: context.appPanelColors,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x2613B957),
                    blurRadius: 24,
                    offset: Offset(0, 12),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      color: context
                          .appColor(Colors.white, surface: true)
                          .withValues(alpha: .16),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.water_drop_rounded,
                      color: Color(0xFFBFFFF0),
                      size: 32,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    context.tr('Kunlik tavsiya'),
                    style: TextStyle(
                      color: context.appColor(Colors.white70, surface: false),
                      fontSize: 15,
                    ),
                  ),
                  Text(
                    '${_liters!.toStringAsFixed(1)} ${context.tr('litr')}',
                    style: TextStyle(
                      color: context.appColor(Colors.white, surface: false),
                      fontSize: 42,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
