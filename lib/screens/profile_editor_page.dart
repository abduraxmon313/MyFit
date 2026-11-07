import 'package:flutter/material.dart';
import '../models/user_profile.dart';
import '../l10n/app_localizations.dart';

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key, required this.profile});
  final UserProfile profile;

  @override
  State<EditProfilePage> createState() => EditProfilePageState();
}

class EditProfilePageState extends State<EditProfilePage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _firstName;
  late final TextEditingController _lastName;
  late final TextEditingController _age;
  late final TextEditingController _height;
  late final TextEditingController _weight;
  late String _gender;
  late String _activity;
  late String _goal;

  @override
  void initState() {
    super.initState();
    final profile = widget.profile;
    _firstName = TextEditingController(text: profile.firstName);
    _lastName = TextEditingController(text: profile.lastName);
    _age = TextEditingController(text: profile.age.toString());
    _height = TextEditingController(text: profile.heightCm.toStringAsFixed(0));
    _weight = TextEditingController(text: profile.weightKg.toStringAsFixed(1));
    _gender = profile.gender;
    _activity = profile.activityLevel;
    _goal = profile.goal;
  }

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _age.dispose();
    _height.dispose();
    _weight.dispose();
    super.dispose();
  }

  String? _required(String? value) {
    if (value == null || value.trim().isEmpty) {
      return context.tr('Maydonni to‘ldiring');
    }
    return null;
  }

  String? _number(String? value, double min, double max) {
    final number = double.tryParse((value ?? '').replaceAll(',', '.'));
    if (number == null || !number.isFinite || number < min || number > max) {
      return context.tr('{min}–{max} oralig‘ida kiriting', {
        'min': min,
        'max': max,
      });
    }
    return null;
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(
      context,
      UserProfile(
        firstName: _firstName.text.trim(),
        lastName: _lastName.text.trim(),
        gender: _gender,
        age: double.parse(_age.text.replaceAll(',', '.')).round(),
        heightCm: double.parse(_height.text.replaceAll(',', '.')),
        weightKg: double.parse(_weight.text.replaceAll(',', '.')),
        activityLevel: _activity,
        goal: _goal,
        photoUrl: widget.profile.photoUrl,
        languageCode: widget.profile.languageCode,
        themeMode: widget.profile.themeMode,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        title: Text(
          context.tr('Profilni tahrirlash'),
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 30),
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _firstName,
                      validator: _required,
                      decoration: InputDecoration(labelText: context.tr('Ism')),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextFormField(
                      controller: _lastName,
                      validator: _required,
                      decoration: InputDecoration(
                        labelText: context.tr('Familiya'),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              SegmentedButton<String>(
                segments: [
                  ButtonSegment(
                    value: 'male',
                    label: Text(context.tr('Erkak')),
                  ),
                  ButtonSegment(
                    value: 'female',
                    label: Text(context.tr('Ayol')),
                  ),
                ],
                selected: {_gender},
                onSelectionChanged: (value) {
                  setState(() => _gender = value.first);
                },
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _age,
                      keyboardType: TextInputType.number,
                      validator: (value) => _number(value, 13, 100),
                      decoration: InputDecoration(
                        labelText: context.tr('Yosh'),
                        suffixText: context.tr('yil'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextFormField(
                      controller: _height,
                      keyboardType: TextInputType.number,
                      validator: (value) => _number(value, 120, 230),
                      decoration: InputDecoration(
                        labelText: context.tr('Bo‘y'),
                        suffixText: 'cm',
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextFormField(
                      controller: _weight,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      validator: (value) => _number(value, 30, 300),
                      decoration: InputDecoration(
                        labelText: context.tr('Vazn'),
                        suffixText: 'kg',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                initialValue: _activity,
                decoration: InputDecoration(labelText: context.tr('Faollik')),
                items: [
                  DropdownMenuItem(
                    value: 'low',
                    child: Text(context.tr('Past faollik')),
                  ),
                  DropdownMenuItem(
                    value: 'medium',
                    child: Text(context.tr('O‘rtacha faollik')),
                  ),
                  DropdownMenuItem(
                    value: 'high',
                    child: Text(context.tr('Yuqori faollik')),
                  ),
                ],
                onChanged: (value) => setState(() => _activity = value!),
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                initialValue: _goal,
                decoration: InputDecoration(labelText: context.tr('Maqsad')),
                items: [
                  DropdownMenuItem(
                    value: 'lose',
                    child: Text(context.tr('Vazn tashlash')),
                  ),
                  DropdownMenuItem(
                    value: 'maintain',
                    child: Text(context.tr('Vaznni saqlash')),
                  ),
                  DropdownMenuItem(
                    value: 'gain',
                    child: Text(context.tr('Vazn orttirish')),
                  ),
                ],
                onChanged: (value) => setState(() => _goal = value!),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: Text(
                  context.tr('Saqlash'),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
