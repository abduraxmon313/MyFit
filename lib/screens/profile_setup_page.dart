import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../l10n/app_localizations.dart';
import '../models/user_profile.dart';
import '../services/onboarding_store.dart';
import '../services/profile_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_ui.dart';

/// First-run profile form shown after the SMS code is confirmed.
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
  static const _steps = 4;

  final _formKeys = List.generate(_steps, (_) => GlobalKey<FormState>());
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _age = TextEditingController();
  final _height = TextEditingController();
  final _weight = TextEditingController();

  int _step = 0;
  String _gender = 'male';
  String _activity = 'medium';
  String _goal = 'lose';
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Sozlash tugamaguncha ilova yopilsa, keyingi safar boshidan boshlanadi.
    OnboardingStore().setInProgress(true);
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

  void _next() {
    FocusScope.of(context).unfocus();
    final form = _formKeys[_step].currentState;
    if (form != null && !form.validate()) return;
    if (_step < _steps - 1) {
      setState(() => _step++);
    } else {
      _finish();
    }
  }

  void _back() {
    if (_step == 0) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _step--;
      _error = null;
    });
  }

  Future<void> _finish() async {
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
      // Hozirgi ko'rinish saqlanadi (birinchi ochilishda yorug').
      themeMode: Theme.of(context).brightness == Brightness.dark
          ? 'dark'
          : 'light',
    );

    try {
      await widget.profileService.saveProfile(widget.uid, profile);
      await OnboardingStore().setInProgress(false);
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
    if (!number.isFinite || number < min || number > max) {
      String f(double v) => v == v.roundToDouble() ? '${v.round()}' : '$v';
      return '${f(min)}–${f(max)}';
    }
    return null;
  }

  Widget _personal() => _Section(
    icon: LucideIcons.userRound,
    accent: AppPalette.accentBlue,
    title: context.tr('Shaxsiy ma’lumotlar'),
    children: [
      TextFormField(
        key: const Key('setup-first-name'),
        controller: _firstName,
        textCapitalization: TextCapitalization.words,
        textInputAction: TextInputAction.next,
        decoration: InputDecoration(labelText: context.tr('Ism')),
        validator: _requiredText,
      ),
      const SizedBox(height: 12),
      TextFormField(
        key: const Key('setup-last-name'),
        controller: _lastName,
        textCapitalization: TextCapitalization.words,
        textInputAction: TextInputAction.next,
        decoration: InputDecoration(labelText: context.tr('Familiya')),
        validator: _requiredText,
      ),
      const SizedBox(height: 16),
      _FieldLabel(context.tr('Jins')),
      const SizedBox(height: 8),
      SegmentedButton<String>(
        showSelectedIcon: false,
        segments: [
          ButtonSegment(
            value: 'male',
            icon: const Icon(LucideIcons.mars, size: 16),
            label: Text(context.tr('Erkak')),
          ),
          ButtonSegment(
            value: 'female',
            icon: const Icon(LucideIcons.venus, size: 16),
            label: Text(context.tr('Ayol')),
          ),
        ],
        selected: {_gender},
        onSelectionChanged: (value) => setState(() => _gender = value.first),
      ),
      const SizedBox(height: 16),
      _NumberField(
        fieldKey: const Key('setup-age'),
        controller: _age,
        label: context.tr('Yosh'),
        suffix: context.tr('yil'),
        decimal: false,
        validator: (v) => _numberValidator(v, 14, 100),
      ),
    ],
  );

  Widget _body() => _Section(
    icon: LucideIcons.ruler,
    accent: AppPalette.accentTeal,
    title: context.tr('Tana o‘lchamlari'),
    children: [
      _NumberField(
        fieldKey: const Key('setup-height'),
        controller: _height,
        label: context.tr('Bo‘y'),
        suffix: context.tr('cm'),
        validator: (v) => _numberValidator(v, 100, 250),
      ),
      const SizedBox(height: 12),
      _NumberField(
        fieldKey: const Key('setup-weight'),
        controller: _weight,
        label: context.tr('Vazn'),
        suffix: context.tr('kg'),
        validator: (v) => _numberValidator(v, 30, 300),
      ),
    ],
  );

  Widget _activityStep() => _Section(
    icon: LucideIcons.activity,
    accent: AppPalette.accentAmber,
    title: context.tr('Faollik darajasi'),
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
    children: [
      for (final (value, title, hint) in [
        ('low', 'Past', 'Asosan o‘tirib ishlayman, mashq kam'),
        ('medium', 'O‘rtacha', 'Haftasiga 2–4 marta mashq qilaman'),
        ('high', 'Yuqori', 'Deyarli har kuni faol harakatdaman'),
      ])
        _OptionRow(
          key: Key('setup-activity-$value'),
          title: context.tr(title),
          subtitle: context.tr(hint),
          selected: _activity == value,
          onTap: () => setState(() => _activity = value),
        ),
    ],
  );

  Widget _goalStep() => _Section(
    icon: LucideIcons.flag,
    accent: AppPalette.accentRose,
    title: context.tr('Maqsadingiz'),
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
    children: [
      for (final (value, title, icon) in [
        ('lose', 'Vazn kamaytirish', LucideIcons.trendingDown),
        ('maintain', 'Vazn saqlash', LucideIcons.scale),
        ('gain', 'Vazn oshirish', LucideIcons.trendingUp),
      ])
        _OptionRow(
          key: Key('setup-goal-$value'),
          icon: icon,
          title: context.tr(title),
          selected: _goal == value,
          onTap: () => setState(() => _goal = value),
        ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final last = _step == _steps - 1;
    final content = switch (_step) {
      0 => _personal(),
      1 => _body(),
      2 => _activityStep(),
      _ => _goalStep(),
    };
    return PopScope(
      canPop: _step == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          leading: _step == 0
              ? null
              : IconButton(
                  key: const Key('setup-back'),
                  tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                  onPressed: _saving ? null : _back,
                  icon: const Icon(LucideIcons.chevronLeft),
                ),
          title: Text(
            context.tr('{n} / {total} qadam', {
              'n': _step + 1,
              'total': _steps,
            }),
            style: TextStyle(
              color: scheme.onSurfaceVariant,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(4),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  for (var i = 0; i < _steps; i++)
                    Expanded(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        height: 4,
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        decoration: BoxDecoration(
                          color: i <= _step
                              ? scheme.primary
                              : scheme.surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        bottomNavigationBar: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_error != null) ...[
                  Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: scheme.error, fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                ],
                FilledButton(
                  key: const Key('setup-continue'),
                  onPressed: _saving ? null : _next,
                  child: _saving
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: scheme.onPrimary,
                          ),
                        )
                      : Text(context.tr(last ? 'Yakunlash' : 'Davom etish')),
                ),
              ],
            ),
          ),
        ),
        body: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      context.tr('O‘zingiz haqingizda ayting.'),
                      style: TextStyle(
                        color: scheme.onSurface,
                        fontSize: 24,
                        height: 1.2,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -.6,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      context.tr(
                        'Shunda MyFit sizga mos shaxsiy reja tuza oladi.',
                      ),
                      style: TextStyle(
                        color: scheme.onSurfaceVariant,
                        fontSize: 14.5,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 24),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: Form(
                        key: _formKeys[_step],
                        child: KeyedSubtree(
                          key: ValueKey(_step),
                          child: content,
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

class _Section extends StatelessWidget {
  const _Section({
    required this.icon,
    required this.accent,
    required this.title,
    required this.children,
    this.padding = const EdgeInsets.all(16),
  });

  final IconData icon;
  final Color accent;
  final String title;
  final List<Widget> children;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AppCard(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              AppIconTile.tinted(icon: icon, size: 32, accent: accent),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: scheme.onSurface,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -.2,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: TextStyle(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
      fontSize: 13,
      fontWeight: FontWeight.w500,
    ),
  );
}

class _NumberField extends StatelessWidget {
  const _NumberField({
    required this.fieldKey,
    required this.controller,
    required this.label,
    required this.suffix,
    required this.validator,
    this.decimal = true,
  });

  final Key fieldKey;
  final TextEditingController controller;
  final String label;
  final String suffix;
  final FormFieldValidator<String> validator;
  final bool decimal;

  @override
  Widget build(BuildContext context) => TextFormField(
    key: fieldKey,
    controller: controller,
    textInputAction: TextInputAction.next,
    keyboardType: TextInputType.numberWithOptions(decimal: decimal),
    inputFormatters: [
      FilteringTextInputFormatter.allow(
        RegExp(decimal ? r'[0-9,.]' : r'[0-9]'),
      ),
    ],
    decoration: InputDecoration(
      labelText: label,
      suffixText: suffix,
      errorMaxLines: 2,
    ),
    validator: validator,
  );
}

class _OptionRow extends StatelessWidget {
  const _OptionRow({
    super.key,
    required this.title,
    required this.selected,
    required this.onTap,
    this.subtitle,
    this.icon,
  });

  final String title;
  final String? subtitle;
  final IconData? icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: selected
            ? scheme.primaryContainer.withValues(alpha: .6)
            : scheme.surfaceContainerLowest,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          side: BorderSide(
            color: selected ? scheme.primary : scheme.outlineVariant,
            width: selected ? 1.5 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                if (icon != null) ...[
                  Icon(
                    icon,
                    size: 18,
                    color: selected ? scheme.primary : scheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: scheme.onSurface,
                          fontSize: 14.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle!,
                          style: TextStyle(
                            color: scheme.onSurfaceVariant,
                            fontSize: 12.5,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: selected ? scheme.primary : Colors.transparent,
                    border: Border.all(
                      color: selected ? scheme.primary : scheme.outline,
                      width: 1.5,
                    ),
                  ),
                  child: selected
                      ? Icon(
                          LucideIcons.check,
                          size: 12,
                          color: scheme.onPrimary,
                        )
                      : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
