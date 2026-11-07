import '../theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/app_localizations.dart';
import '../services/auth_service.dart';
import 'otp_verify_page.dart';

class PhoneLoginPage extends StatefulWidget {
  const PhoneLoginPage({super.key, required this.authService});

  final AuthService authService;

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
    final theme = Theme.of(context);

    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: context.appPanelColors,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 24),
                    Text(
                      'MyFit',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.displaySmall?.copyWith(
                        color: context.appColor(Colors.white, surface: false),
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      context.tr('Telefon raqamingiz bilan kiring'),
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: context.appColor(Colors.white70, surface: false),
                      ),
                    ),
                    const SizedBox(height: 40),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: context
                            .appColor(Colors.white, surface: true)
                            .withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: context.appColor(
                            Colors.white24,
                            surface: true,
                          ),
                        ),
                      ),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              context.tr('Telefon raqam'),
                              style: theme.textTheme.labelLarge?.copyWith(
                                color: context.appColor(
                                  Colors.white70,
                                  surface: false,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _phoneController,
                              keyboardType: TextInputType.phone,
                              style: TextStyle(
                                color: context.appColor(
                                  Colors.white,
                                  surface: false,
                                ),
                              ),
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                  RegExp(r'[0-9+\s]'),
                                ),
                              ],
                              decoration: InputDecoration(
                                hintText: '90 123 45 67',
                                hintStyle: TextStyle(
                                  color: context
                                      .appColor(Colors.white, surface: false)
                                      .withValues(alpha: 0.35),
                                ),
                                prefixText: '+998 ',
                                prefixStyle: TextStyle(
                                  color: context.appColor(
                                    Colors.white,
                                    surface: false,
                                  ),
                                  fontWeight: FontWeight.w600,
                                ),
                                filled: true,
                                fillColor: context
                                    .appColor(Colors.black, surface: true)
                                    .withValues(alpha: 0.25),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: BorderSide.none,
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
                                style: TextStyle(
                                  color: context.appColor(
                                    Color(0xFFFFB4A8),
                                    surface: false,
                                  ),
                                ),
                              ),
                            ],
                            const SizedBox(height: 20),
                            FilledButton(
                              onPressed: _loading ? null : _sendCode,
                              style: FilledButton.styleFrom(
                                backgroundColor: Theme.of(
                                  context,
                                ).colorScheme.primary,
                                foregroundColor: Theme.of(
                                  context,
                                ).colorScheme.onPrimary,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: _loading
                                  ? const SizedBox(
                                      height: 22,
                                      width: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.4,
                                        color: Color(0xFF0B3D2E),
                                      ),
                                    )
                                  : Text(
                                      context.tr('OTP kod olish'),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 16,
                                      ),
                                    ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      context.tr('SMS orqali 6 xonali kod yuboriladi'),
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: context.appColor(Colors.white54, surface: false),
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
