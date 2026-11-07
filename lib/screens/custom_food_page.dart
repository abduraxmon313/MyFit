import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../models/food_nutrition.dart';
import '../services/custom_food_store.dart';

class CustomFoodPage extends StatefulWidget {
  const CustomFoodPage({super.key});
  @override
  State<CustomFoodPage> createState() => _CustomFoodPageState();
}

class _CustomFoodPageState extends State<CustomFoodPage> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _brand = TextEditingController();
  final _controllers = <String, TextEditingController>{
    for (final key in ['calories', 'protein', 'fat', 'carbohydrates', 'fiber', 'sugars', 'saturatedFat', 'salt', 'sodiumMg']) key: TextEditingController(),
  };
  String _unit = 'g';
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _brand.dispose();
    for (final controller in _controllers.values) { controller.dispose(); }
    super.dispose();
  }

  double? _number(String key) => double.tryParse(_controllers[key]!.text.trim().replaceAll(',', '.'));

  Future<void> _save() async {
    if (_saving || !_form.currentState!.validate()) return;
    setState(() => _saving = true);
    final values = <String, dynamic>{
      'fdcId': -DateTime.now().microsecondsSinceEpoch,
      'name': [_name.text.trim(), if (_brand.text.trim().isNotEmpty) _brand.text.trim()].join(' — '),
      'dataSource': 'User label',
      'basisUnit': _unit,
      'hasWaterData': false,
      'knownNutrients': [for (final key in _controllers.keys) if (_number(key) != null) key],
      for (final key in _controllers.keys) key: _number(key) ?? 0,
    };
    final food = FoodNutrition.fromMap(values);
    try {
      await CustomFoodStore().save(food);
      if (mounted) Navigator.pop(context, food);
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.tr('Mahsulotni saqlab bo‘lmadi.'))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final labels = {'calories': 'Kaloriya', 'protein': 'Oqsil', 'fat': 'Yog‘', 'carbohydrates': 'Uglevod', 'fiber': 'Kletchatka', 'sugars': 'Shakar', 'saturatedFat': 'To‘yingan yog‘', 'salt': 'Tuz', 'sodiumMg': 'Natriy'};
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('Yorliqdan mahsulot qo‘shish'))),
      body: Form(key: _form, child: ListView(padding: const EdgeInsets.all(20), children: [
        Text(context.tr('Qadoqdagi 100 g yoki 100 ml qiymatlarini kiriting. Bo‘sh maydon nol degani emas.')),
        const SizedBox(height: 16),
        TextFormField(controller: _name, maxLength: 120, decoration: InputDecoration(labelText: context.tr('Mahsulot nomi')), validator: (value) => (value ?? '').trim().isEmpty ? context.tr('Majburiy maydon') : null),
        TextFormField(controller: _brand, maxLength: 80, decoration: InputDecoration(labelText: context.tr('Brend (ixtiyoriy)'))),
        DropdownButtonFormField<String>(initialValue: _unit, decoration: InputDecoration(labelText: context.tr('O‘lchov birligi')), items: ['g', 'ml'].map((unit) => DropdownMenuItem(value: unit, child: Text('100 ${context.tr(unit)}'))).toList(), onChanged: _saving ? null : (value) => setState(() => _unit = value!)),
        for (final key in _controllers.keys) Padding(padding: const EdgeInsets.only(top: 12), child: TextFormField(
          controller: _controllers[key],
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(labelText: '${context.tr(labels[key]!)}${['calories','protein','fat','carbohydrates'].contains(key) ? ' *' : ''}', suffixText: context.tr(key == 'calories' ? 'kcal' : key == 'sodiumMg' ? 'mg' : 'g')),
          validator: (value) {
            if ((value ?? '').trim().isEmpty && !['calories','protein','fat','carbohydrates'].contains(key)) return null;
            final parsed = _number(key);
            final max = key == 'calories' ? 1000 : key == 'sodiumMg' ? 100000 : 100;
            return parsed == null || !parsed.isFinite || parsed < 0 || parsed > max ? context.tr('Yorliqdagi to‘g‘ri qiymatni kiriting.') : null;
          },
        )),
        const SizedBox(height: 24),
        FilledButton(onPressed: _saving ? null : _save, child: Text(context.tr(_saving ? 'Saqlanmoqda...' : 'Saqlash'))),
      ])),
    );
  }
}
