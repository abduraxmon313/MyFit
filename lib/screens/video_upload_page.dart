import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../l10n/app_localizations.dart';
import '../models/trainer_course.dart';
import '../services/lesson_video_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_ui.dart';

/// Localized text for a [LessonVideoException].
String lessonVideoErrorText(
  BuildContext context,
  LessonVideoException error,
) => context.tr(switch (error.reason) {
  'too-large' => 'Video hajmi 2 GB dan oshmasligi kerak.',
  'empty-file' => 'Video fayli bo‘sh.',
  'unsupported-format' => 'Faqat MP4 formatidagi videolar qabul qilinadi.',
  'not-h264' =>
    'Video H.264 kodekida bo‘lishi kerak. Videoni H.264 MP4 qilib eksport qiling.',
  'cancelled' => 'Yuklash bekor qilindi.',
  'network' => 'Internet aloqasi uzildi. Qayta urinib ko‘ring.',
  'not-admin' => 'Video yuklash faqat adminlar uchun.',
  'sign-in-required' => 'Video yuklash uchun qayta kiring.',
  'upload-expired' => 'Yuklash muddati tugadi. Qaytadan boshlang.',
  'object-missing' ||
  'size-mismatch' => 'Video to‘liq yuklanmadi. Qayta urinib ko‘ring.',
  'storage-unavailable' => 'Video ombori vaqtincha ishlamayapti.',
  'database-unavailable' || 'auth-unavailable' =>
    'Server vaqtincha ishlamayapti. Keyinroq urinib ko‘ring.',
  'not-configured' => 'Video xizmati hali sozlanmagan.',
  'invalid-title' => 'Dars nomini kiriting (2–120 belgi).',
  'lesson-not-found' => 'Dars topilmadi (o‘chirilgan bo‘lishi mumkin).',
  _ => 'Videoni yuklab bo‘lmadi. Qayta urinib ko‘ring.',
});

String _megabytes(int bytes) => (bytes / (1024 * 1024)).toStringAsFixed(1);

/// Admin-only screen: pick an H.264 MP4 and upload it to a lesson category.
class VideoUploadPage extends StatefulWidget {
  const VideoUploadPage({
    super.key,
    required this.category,
    this.uploader,
    this.pickVideo,
    this.lesson,
  });

  final TrainerCourse category;

  /// Edit mode: change this lesson's title/description and, optionally,
  /// replace its video. `null` creates a new lesson.
  final CourseLesson? lesson;
  final LessonVideoUploader? uploader;

  /// Overrides the gallery picker (tests).
  final Future<XFile?> Function()? pickVideo;

  @override
  State<VideoUploadPage> createState() => _VideoUploadPageState();
}

class _VideoUploadPageState extends State<VideoUploadPage> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _description = TextEditingController();
  late final LessonVideoUploader _uploader =
      widget.uploader ?? LessonVideoUploader();

  bool get _editing => widget.lesson != null;

  @override
  void initState() {
    super.initState();
    final lesson = widget.lesson;
    if (lesson != null) {
      _title.text = lesson.title;
      _description.text = lesson.description;
    }
  }

  XFile? _file;
  int _fileSize = 0;
  bool _checking = false;
  LessonUploadPhase? _phase;
  int _sent = 0;
  int _total = 0;
  String? _error;
  UploadCancelToken? _cancel;

  bool get _busy => _phase != null;

  @override
  void dispose() {
    _cancel?.cancel();
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    setState(() => _error = null);
    XFile? picked;
    try {
      picked =
          await (widget.pickVideo ??
              () => ImagePicker().pickVideo(source: ImageSource.gallery))();
    } catch (_) {
      if (mounted) {
        setState(() => _error = context.tr('Videoni tanlab bo‘lmadi.'));
      }
      return;
    }
    if (picked == null || !mounted) return;
    final file = picked;
    setState(() {
      _checking = true;
      _file = null;
    });
    try {
      final size = await file.length();
      await validateLessonVideo(
        fileName: file.name,
        mimeType: file.mimeType,
        sizeBytes: size,
        readAt: (offset, length) => readXFileRange(file, offset, length),
      );
      if (!mounted) return;
      setState(() {
        _file = file;
        _fileSize = size;
      });
    } on LessonVideoException catch (error) {
      if (mounted) {
        setState(() => _error = lessonVideoErrorText(context, error));
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = context.tr('Videoni tanlab bo‘lmadi.'));
      }
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  /// Edit mode without a new video: only title/description change.
  Future<void> _saveDetails() async {
    final lesson = widget.lesson!;
    setState(() {
      _phase = LessonUploadPhase.finalizing;
      _error = null;
    });
    try {
      await _uploader.updateLesson(
        categoryId: widget.category.id,
        lessonId: lesson.id,
        title: _title.text,
        description: _description.text,
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } on LessonVideoException catch (error) {
      if (mounted) {
        setState(() {
          _phase = null;
          // Saving text only: never mention a video upload here.
          _error =
              const {
                'not-admin',
                'sign-in-required',
                'invalid-title',
                'lesson-not-found',
                'network',
                'not-configured',
              }.contains(error.reason)
              ? lessonVideoErrorText(context, error)
              : context.tr('Saqlab bo‘lmadi. Qayta urinib ko‘ring.');
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _phase = null;
          _error = context.tr('Saqlab bo‘lmadi. Qayta urinib ko‘ring.');
        });
      }
    }
  }

  Future<void> _upload() async {
    final file = _file;
    if (_busy) return;
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (file == null) {
      if (_editing) await _saveDetails();
      return;
    }
    final cancel = UploadCancelToken();
    setState(() {
      _cancel = cancel;
      _phase = LessonUploadPhase.validating;
      _sent = 0;
      _total = _fileSize;
      _error = null;
    });
    try {
      await _uploader.upload(
        categoryId: widget.category.id,
        title: _title.text,
        description: _description.text,
        file: file,
        cancelToken: cancel,
        replaceLessonId: widget.lesson?.id,
        onPhase: (phase) {
          if (mounted) setState(() => _phase = phase);
        },
        onProgress: (sent, total) {
          if (mounted) {
            setState(() {
              _sent = sent;
              _total = total;
            });
          }
        },
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } on LessonVideoException catch (error) {
      if (mounted) {
        setState(() {
          _phase = null;
          _error = lessonVideoErrorText(context, error);
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _phase = null;
          _error = context.tr('Videoni yuklab bo‘lmadi. Qayta urinib ko‘ring.');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final file = _file;
    final progress = _total > 0 ? _sent / _total : 0.0;
    return PopScope(
      canPop: !_busy,
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            key: const Key('upload-back'),
            tooltip: context.tr('Orqaga'),
            icon: const Icon(LucideIcons.arrowLeft),
            onPressed: _busy ? null : () => Navigator.maybePop(context),
          ),
          title: Text(
            context.tr(_editing ? 'Darsni tahrirlash' : 'Video yuklash'),
          ),
        ),
        bottomNavigationBar: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            child: _busy
                ? OutlinedButton.icon(
                    key: const Key('upload-cancel'),
                    onPressed: _phase == LessonUploadPhase.uploading
                        ? () => _cancel?.cancel()
                        : null,
                    icon: const Icon(LucideIcons.x, size: 16),
                    label: Text(context.tr('Bekor qilish')),
                  )
                : FilledButton.icon(
                    key: const Key('upload-start'),
                    onPressed: (file == null && !_editing) || _checking
                        ? null
                        : _upload,
                    icon: const Icon(LucideIcons.cloudUpload, size: 18),
                    label: Text(context.tr(_editing ? 'Saqlash' : 'Yuklash')),
                  ),
          ),
        ),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
            children: [
              Text(
                context.tr(widget.category.title),
                style: TextStyle(
                  color: scheme.onSurface,
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                context.tr('Faqat MP4 (H.264), 2 GB gacha.'),
                style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
              ),
              const SizedBox(height: 16),
              AppCard(
                key: const Key('upload-pick'),
                onTap: _busy || _checking ? null : _pick,
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    AppIconTile.tinted(
                      icon: file == null
                          ? LucideIcons.fileVideo
                          : LucideIcons.circleCheck,
                      size: 44,
                      accent: file == null
                          ? AppPalette.accentSlate
                          : AppPalette.accentGreen,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            file == null
                                ? context.tr(
                                    _editing
                                        ? 'Videoni almashtirish (ixtiyoriy)'
                                        : 'Videoni tanlash',
                                  )
                                : file.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: scheme.onSurface,
                              fontSize: 14.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _checking
                                ? context.tr('Video tekshirilmoqda...')
                                : file == null
                                ? context.tr(
                                    _editing
                                        ? 'Joriy video qoladi'
                                        : 'Galereyadan MP4 video',
                                  )
                                : '${_megabytes(_fileSize)} MB · H.264',
                            style: TextStyle(
                              color: scheme.onSurfaceVariant,
                              fontSize: 12.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_checking)
                      const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                key: const Key('upload-title'),
                controller: _title,
                enabled: !_busy,
                maxLength: 120,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(labelText: context.tr('Dars nomi')),
                validator: (value) {
                  final text = (value ?? '').trim();
                  return text.length < 2
                      ? context.tr('Dars nomini kiriting (2–120 belgi).')
                      : null;
                },
              ),
              const SizedBox(height: 8),
              TextFormField(
                key: const Key('upload-description'),
                controller: _description,
                enabled: !_busy,
                maxLength: 1000,
                minLines: 2,
                maxLines: 5,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: context.tr('Tavsif (ixtiyoriy)'),
                ),
              ),
              if (_busy) ...[
                const SizedBox(height: 12),
                Text(
                  context.tr(switch (_phase!) {
                    LessonUploadPhase.validating => 'Video tekshirilmoqda...',
                    LessonUploadPhase.uploading => 'Yuklanmoqda...',
                    LessonUploadPhase.finalizing =>
                      'Serverda tekshirilmoqda...',
                  }),
                  style: TextStyle(
                    color: scheme.onSurface,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    key: const Key('upload-progress'),
                    minHeight: 6,
                    value: _phase == LessonUploadPhase.uploading
                        ? progress
                        : null,
                  ),
                ),
                if (_phase == LessonUploadPhase.uploading) ...[
                  const SizedBox(height: 6),
                  Text(
                    '${(progress * 100).floor()}% · '
                    '${_megabytes(_sent)} / ${_megabytes(_total)} MB',
                    style: TextStyle(
                      color: scheme.onSurfaceVariant,
                      fontSize: 12.5,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ],
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  key: const Key('upload-error'),
                  style: TextStyle(color: scheme.error, fontSize: 13),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
