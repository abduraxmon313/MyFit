import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/app_localizations.dart';
import '../services/auth_service.dart';
import '../services/phone_format.dart';
import '../theme/app_theme.dart';
import '../widgets/app_ui.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class OtpVerifyPage extends StatefulWidget {
  const OtpVerifyPage({
    super.key,
    required this.authService,
    required this.phoneNumber,
    this.autoSend = false,
  });

  final AuthService authService;
  final String phoneNumber;

  /// Request the SMS code as soon as the page opens.
  final bool autoSend;

  @override
  State<OtpVerifyPage> createState() => _OtpVerifyPageState();
}

class _OtpVerifyPageState extends State<OtpVerifyPage> {
  final _codeController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _codeSent = false;
  bool _sending = false;
  bool _loading = false;
  bool _resending = false;
  String? _error;
  String? _info;
  int _secondsLeft = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    if (widget.autoSend) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _requestCode());
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _codeController.dispose();
    super.dispose();
  }

  void _startTimer([int seconds = 60]) {
    _timer?.cancel();
    setState(() => _secondsLeft = seconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsLeft <= 1) {
        timer.cancel();
        if (mounted) setState(() => _secondsLeft = 0);
      } else if (mounted) {
        setState(() => _secondsLeft -= 1);
      }
    });
  }

  Future<void> _requestCode({bool isResend = false}) async {
    if (!mounted || _sending || _resending) return;
    setState(() {
      if (isResend) {
        _resending = true;
      } else {
        _sending = true;
      }
      _error = null;
      _info = 'SMS kod yuborilmoqda...';
    });

    try {
      await widget.authService.requestSmsCode(widget.phoneNumber);
      if (!mounted) return;
      setState(() {
        _codeSent = true;
        _sending = false;
        _resending = false;
        _info = 'SMS kod yuborildi. Xabarlarni tekshiring.';
      });
      _startTimer();
    } on SmsAuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _resending = false;
        _info = null;
        // A code sent a moment ago is still valid: allow typing it.
        if (e.reason == 'resend-too-soon') _codeSent = true;
        _error = _mapError(e);
      });
      if (e.retryAfterSeconds != null && e.retryAfterSeconds! <= 3600) {
        _startTimer(e.retryAfterSeconds!);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _resending = false;
        _info = null;
        _error = context.tr('Xatolik: {error}', {'error': e});
      });
    }
  }

  Future<void> _verify() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_codeSent) {
      setState(() => _error = context.tr('Avval SMS kodni oling.'));
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await widget.authService.verifySmsCode(
        phoneNumber: widget.phoneNumber,
        code: _codeController.text,
      );
      if (!mounted) return;
      // AuthGate HomePage ga o‘tadi; OTP stackni tozalaymiz.
      Navigator.of(context).popUntil((route) => route.isFirst);
    } on SmsAuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = _mapError(e);
      });
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.code == 'network-request-failed'
            ? context.tr('Internet aloqasi yo‘q.')
            : context.tr('Xatolik ({code}).', {'code': e.code});
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = context.tr('Xatolik: {error}', {'error': e});
      });
    }
  }

  String _mapError(SmsAuthException e) {
    switch (e.reason) {
      case 'invalid-code':
        return context.tr('SMS kod noto‘g‘ri.');
      case 'code-expired':
        return context.tr('SMS kod muddati tugadi. Qayta yuboring.');
      case 'too-many-attempts':
        return context.tr('Ko‘p marta noto‘g‘ri kiritildi. Yangi kod so‘rang.');
      case 'invalid-phone':
        return context.tr('Telefon raqam noto‘g‘ri.');
      case 'resend-too-soon':
        return context.tr('Yangi kodni biroz kutib so‘rang.');
      case 'too-many-requests':
        return context.tr('Juda ko‘p urinish. Keyinroq qayta urinib ko‘ring.');
      case 'network':
        return context.tr('Internet aloqasi yo‘q.');
      case 'user-disabled':
        return context.tr('Bu akkaunt bloklangan.');
      case 'sms-unavailable':
      case 'sms-misconfigured':
      case 'auth-unavailable':
      case 'auth-misconfigured':
      case 'database-unavailable':
        return context.tr(
          'SMS xizmati vaqtincha ishlamayapti. Keyinroq urinib ko‘ring.',
        );
      default:
        return context.tr('Xatolik ({code}).', {'code': e.reason});
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final canResend = !_sending && !_resending && _secondsLeft == 0;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: MaterialLocalizations.of(context).backButtonTooltip,
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(LucideIcons.chevronLeft),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Center(
                    child: AppIconTile.tinted(
                      icon: LucideIcons.messageSquareText,
                      size: 48,
                      accent: AppPalette.accentBlue,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    context.tr('SMS kod'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: scheme.onSurface,
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    context.tr(
                      '{phone} raqamiga yuborilgan\n6 xonali SMS kodni kiriting',
                      {'phone': formatUzPhone(widget.phoneNumber)},
                    ),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: scheme.onSurfaceVariant,
                      fontSize: 14.5,
                      height: 1.45,
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
                          if (_sending) ...[
                            const Center(child: CircularProgressIndicator()),
                            const SizedBox(height: 16),
                          ],
                          TextFormField(
                            controller: _codeController,
                            enabled: !_sending && _codeSent,
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: scheme.onSurface,
                              fontSize: 26,
                              letterSpacing: 10,
                              fontWeight: FontWeight.w600,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                            maxLength: 6,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            decoration: const InputDecoration(
                              counterText: '',
                              hintText: '––––––',
                              hintStyle: TextStyle(letterSpacing: 10),
                            ),
                            validator: (value) {
                              if ((value ?? '').trim().length != 6) {
                                return context.tr(
                                  '6 xonali SMS kodni kiriting',
                                );
                              }
                              return null;
                            },
                          ),
                          if (_info != null) ...[
                            const SizedBox(height: 12),
                            Text(
                              context.tr(_info!),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: scheme.onSurfaceVariant,
                                fontSize: 13,
                              ),
                            ),
                          ],
                          if (_error != null) ...[
                            const SizedBox(height: 12),
                            Text(
                              _error!,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: scheme.error,
                                fontSize: 13,
                              ),
                            ),
                          ],
                          const SizedBox(height: 20),
                          FilledButton(
                            onPressed: (_loading || _sending || !_codeSent)
                                ? null
                                : _verify,
                            child: _loading
                                ? SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: scheme.onPrimary,
                                    ),
                                  )
                                : Text(context.tr('Tasdiqlash')),
                          ),
                          const SizedBox(height: 8),
                          TextButton(
                            onPressed: canResend
                                ? () => _requestCode(isResend: true)
                                : null,
                            child: Text(
                              _resending
                                  ? context.tr('Yuborilmoqda...')
                                  : _secondsLeft > 0
                                  ? context.tr('Qayta yuborish ({seconds} s)', {
                                      'seconds': _secondsLeft,
                                    })
                                  : context.tr('SMS kodni qayta yuborish'),
                            ),
                          ),
                        ],
                      ),
                    ),
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
