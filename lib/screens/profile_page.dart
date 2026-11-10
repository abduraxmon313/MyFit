import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../l10n/app_localizations.dart';
import '../models/user_profile.dart';
import '../services/profile_photo_picker.dart';
import '../widgets/appearance_selector.dart';
import '../widgets/profile_avatar.dart';
import 'profile_editor_page.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({
    super.key,
    required this.profile,
    required this.phoneNumber,
    required this.onSave,
    required this.onSignOut,
    this.onLocaleChanged,
    this.onThemeChanged,
    this.onPhotoUpload,
    this.onPhotoRemove,
    this.photoPicker,
  });
  final UserProfile profile;
  final String phoneNumber;
  final Future<void> Function(UserProfile profile) onSave;
  final Future<void> Function() onSignOut;
  final ValueChanged<String>? onLocaleChanged;
  final ValueChanged<String>? onThemeChanged;
  final Future<String> Function(Uint8List bytes)? onPhotoUpload;
  final Future<void> Function()? onPhotoRemove;
  final ProfilePhotoPicker? photoPicker;
  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  late UserProfile _profile = widget.profile;
  bool _busy = false, _uploading = false;

  @override
  void didUpdateWidget(covariant ProfilePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.profile != widget.profile) _profile = widget.profile;
  }

  void _message(String text, [Map<String, Object> values = const {}]) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.tr(text, values)),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _photoOptions() async {
    if (_busy) return;
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  context.tr('Profil rasmi'),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              ListTile(
                leading: const Icon(LucideIcons.images),
                title: Text(context.tr('Galereyadan tanlash')),
                onTap: () => Navigator.pop(context, 'gallery'),
              ),
              ListTile(
                leading: const Icon(LucideIcons.camera),
                title: Text(context.tr('Kamerada suratga olish')),
                onTap: () => Navigator.pop(context, 'camera'),
              ),
              if (_profile.photoUrl != null && widget.onPhotoRemove != null)
                ListTile(
                  leading: Icon(
                    LucideIcons.trash2,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  title: Text(
                    context.tr('Rasmni olib tashlash'),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                  onTap: () => Navigator.pop(context, 'remove'),
                ),
            ],
          ),
        ),
      ),
    );
    if (!mounted || action == null) return;
    setState(() => _busy = true);
    try {
      if (action == 'remove') {
        setState(() => _uploading = true);
        await widget.onPhotoRemove!();
        if (!mounted) return;
        setState(
          () => _profile = UserProfile.fromMap({
            ..._profile.toMap(),
            'photoUrl': null,
          }),
        );
        _message('Profil rasmi olib tashlandi.');
      } else {
        final bytes = await (widget.photoPicker ?? ProfilePhotoPicker()).pick(
          action == 'camera' ? ImageSource.camera : ImageSource.gallery,
        );
        if (!mounted || bytes == null) return;
        setState(() => _uploading = true);
        final url = await widget.onPhotoUpload!(bytes);
        if (!mounted) return;
        setState(
          () => _profile = UserProfile.fromMap({
            ..._profile.toMap(),
            'photoUrl': url,
          }),
        );
        _message('Profil rasmi yangilandi.');
      }
    } catch (error) {
      final (text, values) = photoErrorMessage(error);
      _message(text, values);
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _uploading = false;
        });
      }
    }
  }

  Future<void> _edit() async {
    if (_busy) return;
    final updated = await Navigator.push<UserProfile>(
      context,
      MaterialPageRoute(builder: (_) => EditProfilePage(profile: _profile)),
    );
    if (updated == null || !mounted) return;
    setState(() => _busy = true);
    try {
      await widget.onSave(updated);
      if (!mounted) return;
      setState(() => _profile = updated);
      _message('Profil muvaffaqiyatli yangilandi');
    } catch (_) {
      _message('Profilni saqlab bo‘lmadi. Qayta urinib ko‘ring.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _language(String code) async {
    if (_busy || code == _profile.languageCode) return;
    final previous = _profile;
    final updated = UserProfile.fromMap({
      ..._profile.toMap(),
      'languageCode': code,
    });
    setState(() {
      _busy = true;
      _profile = updated;
    });
    widget.onLocaleChanged?.call(code);
    try {
      await widget.onSave(updated);
    } catch (_) {
      widget.onLocaleChanged?.call(previous.languageCode);
      if (mounted) setState(() => _profile = previous);
      _message('Profilni saqlab bo‘lmadi. Qayta urinib ko‘ring.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final profile = _profile;
    final height = profile.heightCm / 100;
    final bmi = height > 0
        ? (profile.weightKg / (height * height)).toStringAsFixed(1)
        : '—';
    final goal = switch (profile.goal) {
      'lose' => 'Vazn tashlash',
      'gain' => 'Vazn orttirish',
      _ => 'Vaznni saqlash',
    };
    final activity = switch (profile.activityLevel) {
      'low' => 'Past faollik',
      'high' => 'Yuqori faollik',
      _ => 'O‘rtacha faollik',
    };
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 32),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                context.tr('Profil'),
                style: const TextStyle(
                  fontSize: 29,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -.8,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                context.tr('Sizga mos sog‘lom hayot.'),
                style: TextStyle(color: colors.onSurfaceVariant),
              ),
              const SizedBox(height: 24),
              _panel(
                context,
                Column(
                  children: [
                    const SizedBox(height: 6),
                    Semantics(
                      button: widget.onPhotoUpload != null,
                      label: context.tr('Profil rasmini o‘zgartirish'),
                      child: InkWell(
                        key: const Key('profile-photo-button'),
                        onTap: _busy || widget.onPhotoUpload == null
                            ? null
                            : _photoOptions,
                        customBorder: const CircleBorder(),
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(5),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: colors.primary.withValues(alpha: .3),
                                  width: 1.5,
                                ),
                              ),
                              child: ProfileAvatar(
                                name: profile.fullName,
                                photoUrl: profile.photoUrl,
                                size: 94,
                              ),
                            ),
                            if (_uploading)
                              Positioned.fill(
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: colors.surface.withValues(alpha: .8),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Padding(
                                    padding: EdgeInsets.all(32),
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                ),
                              ),
                            Positioned(
                              right: 1,
                              bottom: 1,
                              child: Container(
                                padding: const EdgeInsets.all(7),
                                decoration: BoxDecoration(
                                  color: colors.primary,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: colors.surfaceContainerLowest,
                                    width: 3,
                                  ),
                                ),
                                child: Icon(
                                  LucideIcons.imagePlus,
                                  size: 16,
                                  color: colors.onPrimary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      profile.fullName,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 23,
                        height: 1.2,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      widget.phoneNumber.isEmpty
                          ? context.tr('Kiritilmagan')
                          : widget.phoneNumber,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: colors.onSurfaceVariant,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 4),
                    TextButton(
                      onPressed: _busy || widget.onPhotoUpload == null
                          ? null
                          : _photoOptions,
                      child: Text(
                        context.tr(
                          _uploading
                              ? 'Rasm yuklanmoqda…'
                              : profile.photoUrl == null
                              ? 'Rasm qo‘shish'
                              : 'Rasmni o‘zgartirish',
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Divider(height: 1, color: colors.outlineVariant),
                    const SizedBox(height: 22),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _metric(
                          context,
                          profile.weightKg.toStringAsFixed(1),
                          'kg',
                          'Vazn',
                        ),
                        _metric(
                          context,
                          '${profile.heightCm.round()}',
                          'cm',
                          'Bo‘y',
                        ),
                        _metric(context, bmi, '', 'BMI'),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              OutlinedButton.icon(
                onPressed: _busy ? null : _edit,
                icon: const Icon(LucideIcons.slidersHorizontal, size: 18),
                label: Text(context.tr('Profilni tahrirlash')),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              _section(context, 'Shaxsiy reja'),
              _panel(
                context,
                Column(
                  children: [
                    _row(
                      context,
                      LucideIcons.flag,
                      'Maqsad',
                      context.tr(goal),
                      onTap: _busy ? null : _edit,
                    ),
                    Divider(height: 24, color: colors.outlineVariant),
                    _row(
                      context,
                      LucideIcons.footprints,
                      'Faollik',
                      context.tr(activity),
                      onTap: _busy ? null : _edit,
                    ),
                  ],
                ),
              ),
              _section(context, 'Shaxsiy ma’lumotlar'),
              _panel(
                context,
                Column(
                  children: [
                    _row(context, LucideIcons.cake, 'Yosh', '${profile.age}'),
                    Divider(height: 24, color: colors.outlineVariant),
                    _row(
                      context,
                      LucideIcons.user,
                      'Jins',
                      context.tr(profile.gender == 'male' ? 'Erkak' : 'Ayol'),
                    ),
                    Divider(height: 24, color: colors.outlineVariant),
                    _row(
                      context,
                      LucideIcons.phone,
                      'Telefon',
                      widget.phoneNumber.isEmpty
                          ? context.tr('Kiritilmagan')
                          : widget.phoneNumber,
                    ),
                  ],
                ),
              ),
              _section(context, 'Sozlamalar'),
              _panel(
                context,
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _settingLabel(
                      context,
                      LucideIcons.contrast,
                      'Ilova ko‘rinishi',
                    ),
                    const SizedBox(height: 14),
                    AbsorbPointer(
                      absorbing: _busy,
                      child: AppearanceSelector(
                        selected:
                            Theme.of(context).brightness == Brightness.dark
                            ? 'dark'
                            : 'light',
                        onChanged: widget.onThemeChanged,
                        onSave: (mode) async {
                          final updated = UserProfile.fromMap({
                            ..._profile.toMap(),
                            'themeMode': mode,
                          });
                          await widget.onSave(updated);
                          if (mounted) {
                            setState(
                              () => _profile = UserProfile.fromMap({
                                ..._profile.toMap(),
                                'themeMode': mode,
                              }),
                            );
                          }
                        },
                      ),
                    ),
                    const SizedBox(height: 24),
                    _settingLabel(context, LucideIcons.languages, 'Til'),
                    const SizedBox(height: 14),
                    SegmentedButton<String>(
                      showSelectedIcon: false,
                      segments: const [
                        ButtonSegment(value: 'uz', label: Text('O‘zbekcha')),
                        ButtonSegment(value: 'ru', label: Text('Русский')),
                        ButtonSegment(value: 'en', label: Text('English')),
                      ],
                      selected: {profile.languageCode},
                      onSelectionChanged: _busy
                          ? null
                          : (values) => _language(values.single),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              TextButton.icon(
                onPressed: _busy ? null : widget.onSignOut,
                icon: const Icon(LucideIcons.logOut, size: 19),
                label: Text(context.tr('Akkauntdan chiqish')),
                style: TextButton.styleFrom(
                  foregroundColor: colors.error,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'MYFIT',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 3,
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _panel(BuildContext context, Widget child) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.outlineVariant.withValues(alpha: .7)),
      ),
      child: child,
    );
  }

  Widget _section(BuildContext context, String label) => Padding(
    padding: const EdgeInsets.fromLTRB(2, 26, 2, 12),
    child: Text(
      context.tr(label),
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        letterSpacing: -.2,
      ),
    ),
  );

  Widget _metric(
    BuildContext context,
    String value,
    String unit,
    String label,
  ) => Expanded(
    child: Column(
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            '$value${unit.isEmpty ? '' : ' ${context.tr(unit)}'}',
            style: const TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.w600,
              letterSpacing: -.5,
            ),
          ),
        ),
        const SizedBox(height: 5),
        Text(
          context.tr(label),
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    ),
  );

  Widget _settingLabel(BuildContext context, IconData icon, String label) =>
      Row(
        children: [
          Icon(
            icon,
            size: 19,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              context.tr(label),
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      );

  Widget _row(
    BuildContext context,
    IconData icon,
    String label,
    String value, {
    VoidCallback? onTap,
  }) {
    final colors = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: colors.primaryContainer.withValues(alpha: .5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 20, color: colors.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.tr(label),
                    style: TextStyle(
                      color: colors.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            if (onTap != null)
              Icon(
                LucideIcons.chevronRight,
                size: 20,
                color: colors.onSurfaceVariant,
              ),
          ],
        ),
      ),
    );
  }
}

/// Turns a photo pick/upload failure into a message that names the cause.
(String, Map<String, Object>) photoErrorMessage(Object error) {
  if (error is FirebaseException) {
    switch (error.code) {
      case 'unauthorized':
      case 'permission-denied':
        return (
          'Rasm saqlashga ruxsat yo‘q: Firebase Storage qoidalari o‘rnatilmagan.',
          const {},
        );
      case 'unauthenticated':
        return ('Rasm yuklash uchun qayta kiring.', const {});
      case 'bucket-not-found':
      case 'project-not-found':
      case 'object-not-found':
      case 'unknown':
        return ('Firebase Storage yoqilmagan (Blaze rejasi kerak).', const {});
      case 'quota-exceeded':
        return ('Firebase Storage limiti tugagan.', const {});
      case 'retry-limit-exceeded':
      case 'network-request-failed':
      case 'unavailable':
        return ('Internet aloqasi yo‘q. Qayta urinib ko‘ring.', const {});
    }
    return ('Rasmni yangilab bo‘lmadi ({code}).', {'code': error.code});
  }
  if (error is PlatformException) {
    if (error.code.contains('access_denied')) {
      return (
        'Kamera yoki galereyaga ruxsat berilmagan. Telefon sozlamalaridan ruxsat bering.',
        const {},
      );
    }
    return ('Rasmni yangilab bo‘lmadi ({code}).', {'code': error.code});
  }
  if (error is FormatException) {
    return ('Rasm juda katta yoki noto‘g‘ri formatda.', const {});
  }
  return (
    'Rasmni yangilab bo‘lmadi. Ruxsat va internetni tekshirib, qayta urinib ko‘ring.',
    const {},
  );
}
