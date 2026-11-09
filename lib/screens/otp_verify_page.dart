import '../theme/app_theme.dart';
import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/app_localizations.dart';
import '../services/auth_service.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class OtpVerifyPage extends StatefulWidget {
  const OtpVerifyPage({
    super.key,
    required this.authService,
    required this.phoneNumber,
    this.verificationId,
    this.resendToken,
    this.autoSend = false,
  });

  final AuthService authService;
  final String phoneNumber;
  final String? verificationId;
  final int? resendToken;
  final bool autoSend;

  @override
  State<OtpVerifyPage> createState() => _OtpVerifyPageState();
}

class _OtpVerifyPageState extends State<OtpVerifyPage> {
  final _codeController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  String? _verificationId;
  int? _resendToken;
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
    _verificationId = widget.verificationId;
    _resendToken = widget.resendToken;
    if (_verificationId != null) {
      _startTimer();
      _info = 'Kod yuborildi';
    } else if (widget.autoSend) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _requestCode());
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _codeController.dispose();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    setState(() => _secondsLeft = 60);
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
      _info = 'Kod yuborilmoqda...';
    });

    try {
      await widget.authService.sendOtp(
        phoneNumber: widget.phoneNumber,
        forceResendingToken: isResend ? _resendToken : null,
        onCodeSent: (verificationId, resendToken) {
          if (!mounted) return;
          setState(() {
            _verificationId = verificationId;
            _resendToken = resendToken;
            _sending = false;
            _resending = false;
            _info = 'Kod yuborildi. SMS ni tekshiring.';
          });
          _startTimer();
        },
        onError: (error) {
          if (!mounted) return;
          setState(() {
            _sending = false;
            _resending = false;
            _info = null;
            _error = _mapError(error);
          });
        },
        onAutoVerified: (credential) async {
          if (!mounted) return;
          try {
            await widget.authService.signInWithCredential(credential);
            if (!mounted) return;
            Navigator.of(context).popUntil((route) => route.isFirst);
          } on FirebaseAuthException catch (e) {
            if (!mounted) return;
            setState(() {
              _sending = false;
              _resending = false;
              _error = _mapError(e);
            });
          }
        },
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _resending = false;
        _info = null;
        _error = _mapError(e);
      });
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
    if (_verificationId == null) {
      setState(() => _error = context.tr('Avval kod yuborilsin.'));
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await widget.authService.verifyOtp(
        verificationId: _verificationId!,
        smsCode: _codeController.text,
      );
      if (!mounted) return;
      // AuthGate HomePage ga o‘tadi; OTP stackni tozalaymiz.
      Navigator.of(context).popUntil((route) => route.isFirst);
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = _mapError(e);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = context.tr('Xatolik: {error}', {'error': e});
      });
    }
  }

  String _mapError(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-verification-code':
        return context.tr('Kod noto‘g‘ri.');
      case 'session-expired':
        return context.tr('Sessiya tugadi. Kodni qayta yuboring.');
      case 'invalid-phone-number':
        return context.tr('Telefon raqam noto‘g‘ri.');
      case 'too-many-requests':
        return context.tr('Juda ko‘p urinish. Keyinroq qayta urinib ko‘ring.');
      case 'network-request-failed':
        return context.tr('Internet aloqasi yo‘q.');
      default:
        return context.tr('Xatolik ({code}).', {'code': e.code});
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final canResend = !_sending && !_resending && _secondsLeft == 0;

    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0B1324), Color(0xFF111B30), Color(0xFF16213A)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  icon: Icon(
                    LucideIcons.chevronLeft,
                    color: context.appColor(Colors.white, surface: false),
                  ),
                ),
              ),
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 16,
                    ),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 420),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            context.tr('OTP kod'),
                            textAlign: TextAlign.center,
                            style: theme.textTheme.headlineMedium?.copyWith(
                              color: context.appColor(
                                Colors.white,
                                surface: false,
                              ),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            context.tr(
                              '{phone} raqamiga yuborilgan\n6 xonali kodni kiriting',
                              {'phone': widget.phoneNumber},
                            ),
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: context.appColor(
                                Colors.white70,
                                surface: false,
                              ),
                            ),
                          ),
                          const SizedBox(height: 32),
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: context
                                  .appColor(Colors.white, surface: true)
                                  .withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(12),
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
                                  if (_sending) ...[
                                    const Center(
                                      child: CircularProgressIndicator(
                                        color: Color(0xFFA9C1FF),
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                  ],
                                  TextFormField(
                                    controller: _codeController,
                                    enabled:
                                        !_sending && _verificationId != null,
                                    keyboardType: TextInputType.number,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: context.appColor(
                                        Colors.white,
                                        surface: false,
                                      ),
                                      fontSize: 28,
                                      letterSpacing: 10,
                                      fontWeight: FontWeight.w700,
                                    ),
                                    maxLength: 6,
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly,
                                    ],
                                    decoration: InputDecoration(
                                      counterText: '',
                                      hintText: '------',
                                      hintStyle: TextStyle(
                                        color: context
                                            .appColor(
                                              Colors.white,
                                              surface: false,
                                            )
                                            .withValues(alpha: 0.25),
                                        letterSpacing: 10,
                                      ),
                                      filled: true,
                                      fillColor: context
                                          .appColor(Colors.black, surface: true)
                                          .withValues(alpha: 0.25),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide.none,
                                      ),
                                    ),
                                    validator: (value) {
                                      if ((value ?? '').trim().length != 6) {
                                        return context.tr(
                                          '6 xonali kod kiriting',
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
                                        color: context.appColor(
                                          Color(0xFFA9C1FF),
                                          surface: false,
                                        ),
                                      ),
                                    ),
                                  ],
                                  if (_error != null) ...[
                                    const SizedBox(height: 12),
                                    Text(
                                      _error!,
                                      textAlign: TextAlign.center,
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
                                    onPressed:
                                        (_loading ||
                                            _sending ||
                                            _verificationId == null)
                                        ? null
                                        : _verify,
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
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    child: _loading
                                        ? const SizedBox(
                                            height: 22,
                                            width: 22,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2.4,
                                              color: Color(0xFFA9C1FF),
                                            ),
                                          )
                                        : Text(
                                            context.tr('Tasdiqlash'),
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 16,
                                            ),
                                          ),
                                  ),
                                  const SizedBox(height: 12),
                                  TextButton(
                                    onPressed: canResend
                                        ? () => _requestCode(isResend: true)
                                        : null,
                                    child: Text(
                                      _resending
                                          ? context.tr('Yuborilmoqda...')
                                          : _secondsLeft > 0
                                          ? context.tr(
                                              'Qayta yuborish ({seconds} s)',
                                              {'seconds': _secondsLeft},
                                            )
                                          : context.tr('Kodni qayta yuborish'),
                                      style: TextStyle(
                                        color: canResend
                                            ? context.appColor(
                                                Color(0xFFA9C1FF),
                                                surface: false,
                                              )
                                            : context.appColor(
                                                Colors.white54,
                                                surface: false,
                                              ),
                                      ),
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
            ],
          ),
        ),
      ),
    );
  }
}
