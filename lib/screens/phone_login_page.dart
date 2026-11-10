import '../theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../widgets/app_ui.dart';

import '../l10n/app_localizations.dart';
import '../services/auth_service.dart';
import 'language_picker_page.dart';
import 'otp_verify_page.dart';
import '../services/phone_format.dart';

class PhoneLoginPage extends StatefulWidget {
  const PhoneLoginPage({
    super.key,
    required this.authService,
    this.onLanguageChanged,
  });

  final AuthService authService;
  final ValueChanged<String>? onLanguageChanged;

  @override
  State<PhoneLoginPage> createState() => _PhoneLoginPageState();
}

class _PhoneLoginPageState extends State<PhoneLoginPage> {
  final _phoneController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    if (!_formKey.currentState!.validate()) return;

    final phone = widget.authService.normalizePhone(_phoneController.text);

    setState(() {
      _loading = true;
      _error = null;
    });

    // OTP ekranini darhol ochamiz — Firebase javobini shu yerda kutamiz.
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => OtpVerifyPage(
          authService: widget.authService,
          phoneNumber: phone,
          autoSend: true,
        ),
      ),
    );

    if (mounted) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final languageCode = Localizations.localeOf(context).languageCode;
    final current = kAppLanguages.firstWhere(
      (l) => l.$1 == languageCode,
      orElse: () => kAppLanguages.first,
    );
    return Scaffold(
      appBar: widget.onLanguageChanged == null
          ? null
          : AppBar(
              actions: [
                PopupMenuButton<String>(
                  key: const Key('login-language'),
                  tooltip: '',
                  position: PopupMenuPosition.under,
                  onSelected: widget.onLanguageChanged,
                  itemBuilder: (_) => [
                    for (final (code, flag, name) in kAppLanguages)
                      PopupMenuItem(value: code, child: Text('$flag  $name')),
                  ],
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Text(current.$2, style: const TextStyle(fontSize: 16)),
                        const SizedBox(width: 6),
                        Text(
                          current.$3,
                          style: TextStyle(
                            color: scheme.onSurface,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 2),
                        Icon(
                          LucideIcons.chevronDown,
                          size: 16,
                          color: scheme.onSurfaceVariant,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
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
                    context.tr('Telefon raqamingiz bilan kiring'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: scheme.onSurfaceVariant,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 28),
                  AppCard(
                    padding: const EdgeInsets.all(24),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            context.tr('Telefon raqam'),
                            style: TextStyle(
                              color: scheme.onSurface,
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _phoneController,
                            keyboardType: TextInputType.phone,
                            style: TextStyle(
                              color: scheme.onSurface,
                              fontSize: 16,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                            inputFormatters: const [UzPhoneInputFormatter()],
                            decoration: InputDecoration(
                              hintText: '90 123 45 67',
                              prefixIcon: const Icon(
                                LucideIcons.phone,
                                size: 18,
                              ),
                              prefixText: '+998 ',
                              prefixStyle: TextStyle(
                                color: scheme.onSurface,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            validator: (value) {
                              final normalized = widget.authService
                                  .normalizePhone(value ?? '');
                              if (!RegExp(
                                r'^\+998\d{9}$',
                              ).hasMatch(normalized)) {
                                return context.tr(
                                  'To‘liq raqam kiriting (9 ta raqam)',
                                );
                              }
                              return null;
                            },
                          ),
                          if (_error != null) ...[
                            const SizedBox(height: 12),
                            Text(
                              _error!,
                              style: TextStyle(color: scheme.error),
                            ),
                          ],
                          const SizedBox(height: 20),
                          FilledButton(
                            onPressed: _loading ? null : _sendCode,
                            child: _loading
                                ? SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: scheme.onPrimary,
                                    ),
                                  )
                                : Text(context.tr('OTP kod olish')),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        LucideIcons.shieldCheck,
                        size: 14,
                        color: scheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          context.tr('SMS orqali 6 xonali kod yuboriladi'),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: scheme.onSurfaceVariant,
                            fontSize: 12.5,
                          ),
                        ),
                      ),
                    ],
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
