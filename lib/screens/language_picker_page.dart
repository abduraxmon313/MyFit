import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../theme/app_theme.dart';
import '../widgets/app_ui.dart';

/// Language options shown before the user signs in.
const kAppLanguages = [
  ('uz', '🇺🇿', 'O‘zbekcha'),
  ('ru', '🇷🇺', 'Русский'),
  ('en', '🇬🇧', 'English'),
];

/// First-launch screen: the user picks the app language before signing in.
/// Texts are shown in all three languages because none is chosen yet.
class LanguagePickerPage extends StatefulWidget {
  const LanguagePickerPage({
    super.key,
    required this.onSelected,
    this.initialCode,
  });

  final ValueChanged<String> onSelected;
  final String? initialCode;

  @override
  State<LanguagePickerPage> createState() => _LanguagePickerPageState();
}

class _LanguagePickerPageState extends State<LanguagePickerPage> {
  late String _code = widget.initialCode ?? 'uz';

  static const _continue = {
    'uz': 'Davom etish',
    'ru': 'Продолжить',
    'en': 'Continue',
  };

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Center(
                    child: AppIconTile(
                      icon: LucideIcons.activity,
                      size: 48,
                      color: Colors.white,
                      background: AppPalette.navy,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'MyFit',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: scheme.onSurface,
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -.8,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Tilni tanlang · Выберите язык · Choose language',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: scheme.onSurfaceVariant,
                      fontSize: 14,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 28),
                  AppCard(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
                        for (var i = 0; i < kAppLanguages.length; i++) ...[
                          if (i > 0)
                            Divider(height: 1, color: scheme.outlineVariant),
                          _LanguageRow(
                            code: kAppLanguages[i].$1,
                            flag: kAppLanguages[i].$2,
                            name: kAppLanguages[i].$3,
                            selected: _code == kAppLanguages[i].$1,
                            onTap: () =>
                                setState(() => _code = kAppLanguages[i].$1),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  FilledButton(
                    key: const Key('language-continue'),
                    onPressed: () => widget.onSelected(_code),
                    child: Text(_continue[_code]!),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LanguageRow extends StatelessWidget {
  const _LanguageRow({
    required this.code,
    required this.flag,
    required this.name,
    required this.selected,
    required this.onTap,
  });

  final String code;
  final String flag;
  final String name;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      key: Key('language-$code'),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        child: Row(
          children: [
            Text(flag, style: const TextStyle(fontSize: 22)),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                name,
                style: TextStyle(
                  color: scheme.onSurface,
                  fontSize: 15.5,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected ? scheme.primary : Colors.transparent,
                border: Border.all(
                  color: selected ? scheme.primary : scheme.outline,
                  width: 1.5,
                ),
              ),
              child: selected
                  ? Icon(LucideIcons.check, size: 14, color: scheme.onPrimary)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
