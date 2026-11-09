import '../theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter/services.dart';

import '../l10n/app_localizations.dart';
import '../models/user_profile.dart';
import '../services/profile_service.dart';

class ProfileSetupPage extends StatefulWidget {
  const ProfileSetupPage({
    super.key,
    required this.uid,
    required this.profileService,
  });

  final String uid;
  final ProfileService profileService;

  @override
  State<ProfileSetupPage> createState() => _ProfileSetupPageState();
}

class _ProfileSetupPageState extends State<ProfileSetupPage> {
  static const _green = Color(0xFF2F5BEA);
  static const _navy = Color(0xFF10223C);

  final _formKey = GlobalKey<FormState>();
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _age = TextEditingController();
  final _height = TextEditingController();
  final _weight = TextEditingController();

  String _gender = 'male';
  String _activity = 'medium';
  String _goal = 'lose';
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _age.dispose();
    _height.dispose();
    _weight.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _saving = true;
      _error = null;
    });
    final profile = UserProfile(
      firstName: _firstName.text.trim(),
      lastName: _lastName.text.trim(),
      gender: _gender,
      age: int.parse(_age.text),
      heightCm: double.parse(_height.text.replaceAll(',', '.')),
      weightKg: double.parse(_weight.text.replaceAll(',', '.')),
      activityLevel: _activity,
      goal: _goal,
      languageCode: Localizations.localeOf(context).languageCode,
    );

    try {
      await widget.profileService.saveProfile(widget.uid, profile);
      // AuthGate stream HomePage ga o‘tkazadi.
      if (mounted) setState(() => _saving = false);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = context.tr('Saqlashda xatolik: {error}', {'error': error});
      });
    }
  }

  String? _requiredText(String? value) {
    if ((value ?? '').trim().isEmpty) return context.tr('Majburiy');
    if (value!.trim().length < 2) return context.tr('Kamida 2 harf');
    return null;
  }

  String? _numberValidator(String? value, double min, double max) {
    final number = double.tryParse((value ?? '').replaceAll(',', '.'));
    if (number == null) return context.tr('Kiriting');
    if (!number.isFinite || number < min || number > max) return '$min–$max';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.appColor(Colors.white, surface: true),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 430),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      context.tr('O‘zingiz haqingizda ayting.'),
                      style: TextStyle(
                        color: context.appColor(_navy, surface: false),
                        fontSize: 25,
                        height: 1.15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      context.tr(
                        'Shunda MyFit sizga mos shaxsiy reja tuza oladi.',
                      ),
                      style: TextStyle(
                        color: context.appColor(
                          Color(0xFF7D8797),
                          surface: false,
                        ),
                        fontSize: 15,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: _Input(
                            controller: _firstName,
                            hint: context.tr('Ism'),
                            validator: _requiredText,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _Input(
                            controller: _lastName,
                            hint: context.tr('Familiya'),
                            validator: _requiredText,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _ChoiceButton(
                            label: context.tr('Erkak'),
                            selected: _gender == 'male',
                            onTap: () => setState(() => _gender = 'male'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _ChoiceButton(
                            label: context.tr('Ayol'),
                            selected: _gender == 'female',
                            onTap: () => setState(() => _gender = 'female'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _Input(
                            controller: _age,
                            hint: context.tr('Yosh'),
                            keyboardType: TextInputType.number,
                            formatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            validator: (v) => _numberValidator(v, 14, 100),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _Input(
                            controller: _height,
                            hint: context.tr('Bo‘y, sm'),
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            validator: (v) => _numberValidator(v, 100, 250),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _Input(
                            controller: _weight,
                            hint: context.tr('Vazn, kg'),
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            validator: (v) => _numberValidator(v, 30, 300),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _SectionTitle(context.tr('FAOLLIK DARAJASI')),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _SmallChoice(
                          label: context.tr('O‘rtacha'),
                          selected: _activity == 'medium',
                          onTap: () => setState(() => _activity = 'medium'),
                        ),
                        _SmallChoice(
                          label: context.tr('Past'),
                          selected: _activity == 'low',
                          onTap: () => setState(() => _activity = 'low'),
                        ),
                        _SmallChoice(
                          label: context.tr('Yuqori'),
                          selected: _activity == 'high',
                          onTap: () => setState(() => _activity = 'high'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _SectionTitle(context.tr('SIZNING MAQSADINGIZ')),
                    const SizedBox(height: 8),
                    _GoalButton(
                      label: context.tr('Vazn kamaytirish'),
                      icon: LucideIcons.trendingDown,
                      selected: _goal == 'lose',
                      onTap: () => setState(() => _goal = 'lose'),
                    ),
                    const SizedBox(height: 10),
                    _GoalButton(
                      label: context.tr('Vazn oshirish'),
                      icon: LucideIcons.trendingUp,
                      selected: _goal == 'gain',
                      onTap: () => setState(() => _goal = 'gain'),
                    ),
                    const SizedBox(height: 10),
                    _GoalButton(
                      label: context.tr('Vazn saqlash'),
                      icon: LucideIcons.scale,
                      selected: _goal == 'maintain',
                      onTap: () => setState(() => _goal = 'maintain'),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: context.appColor(Colors.red, surface: false),
                        ),
                      ),
                    ],
                    const SizedBox(height: 22),
                    SizedBox(
                      height: 54,
                      child: FilledButton(
                        onPressed: _saving ? null : _continue,
                        style: FilledButton.styleFrom(
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.primary,
                          disabledBackgroundColor: _green.withValues(alpha: .6),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _saving
                            ? SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: context.appColor(
                                    Colors.white,
                                    surface: true,
                                  ),
                                ),
                              )
                            : Text(
                                context.tr('Davom etish'),
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Input extends StatelessWidget {
  const _Input({
    required this.controller,
    required this.hint,
    required this.validator,
    this.keyboardType,
    this.formatters,
  });

  final TextEditingController controller;
  final String hint;
  final FormFieldValidator<String> validator;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? formatters;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: formatters,
      validator: validator,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
          color: context.appColor(Color(0xFF737E90), surface: false),
          fontWeight: FontWeight.w600,
        ),
        filled: true,
        fillColor: context.appColor(Color(0xFFF7F8FA), surface: true),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 18,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE8EBEF)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE8EBEF)),
        ),
      ),
    );
  }
}

class _ChoiceButton extends StatelessWidget {
  const _ChoiceButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(48),
        foregroundColor: selected
            ? _ProfileColors.green
            : context.appColor(Color(0xFF737E90), surface: false),
        backgroundColor: selected
            ? context.appColor(Color(0xFFF1F3F6), surface: true)
            : context.appColor(Colors.white, surface: true),
        side: BorderSide(
          color: selected
              ? _ProfileColors.green
              : context.appColor(Color(0xFFE8EBEF), surface: true),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
    );
  }
}

class _SmallChoice extends StatelessWidget {
  const _SmallChoice({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      showCheckmark: false,
      side: BorderSide.none,
      selectedColor: context.appColor(Color(0xFFF1F3F6), surface: true),
      backgroundColor: context.appColor(Color(0xFFF6F7F9), surface: true),
      labelStyle: TextStyle(
        color: selected
            ? context.appColor(Color(0xFF2F5BEA), surface: false)
            : context.appColor(Color(0xFF687386), surface: false),
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _GoalButton extends StatelessWidget {
  const _GoalButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: BoxDecoration(
          color: selected
              ? context.appColor(Color(0xFFF1F3F6), surface: true)
              : context.appColor(Colors.white, surface: true),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected
                ? _ProfileColors.green
                : context.appColor(Color(0xFFE8EBEF), surface: true),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: selected
                      ? context.appColor(Color(0xFF2F5BEA), surface: false)
                      : context.appColor(Color(0xFF15243B), surface: false),
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
            ),
            Icon(
              icon,
              size: 20,
              color: selected
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        color: context.appColor(Color(0xFF203047), surface: false),
        fontSize: 13,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

abstract final class _ProfileColors {
  static const green = Color(0xFF2F5BEA);
}
