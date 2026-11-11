import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../data/trainer_course.dart';
import '../l10n/app_localizations.dart';
import '../models/trainer_course.dart';
import '../services/lesson_video_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_ui.dart';
import '../widgets/lesson_video_player.dart';
import 'video_upload_page.dart';

/// Icon and muted accent per category id.
const _categoryStyles = <String, (IconData, Color)>{
  'nutrition': (LucideIcons.salad, AppPalette.accentGreen),
  'diet-cooking': (LucideIcons.chefHat, AppPalette.accentAmber),
  'fullbody': (LucideIcons.personStanding, AppPalette.accentBlue),
  'split-3': (LucideIcons.calendar1, AppPalette.accentIndigo),
  'split-4': (LucideIcons.calendarDays, AppPalette.accentIndigo),
  'split-5': (LucideIcons.calendarRange, AppPalette.accentIndigo),
  'superset': (LucideIcons.repeat2, AppPalette.accentViolet),
  'dropset': (LucideIcons.chevronsDown, AppPalette.accentViolet),
  'sportpit': (LucideIcons.pill, AppPalette.accentTeal),
  'women-gym': (LucideIcons.dumbbell, AppPalette.accentRose),
  'women-workouts': (LucideIcons.venus, AppPalette.accentRose),
  'women-nutrition': (LucideIcons.apple, AppPalette.accentRose),
  'cardio': (LucideIcons.heartPulse, AppPalette.accentAmber),
};

(IconData, Color) _styleFor(TrainerCourse course) =>
    _categoryStyles[course.id] ??
    (LucideIcons.graduationCap, AppPalette.accentSlate);

/// "Darslar" tab: lesson categories; each opens its ordered video list.
class LessonsPage extends StatefulWidget {
  const LessonsPage({
    super.key,
    this.categories = kLessonCategories,
    this.repository,
  });

  final List<TrainerCourse> categories;

  /// Lesson source; defaults to Firestore when Firebase is initialised.
  final LessonRepository? repository;

  @override
  State<LessonsPage> createState() => _LessonsPageState();
}

class _LessonsPageState extends State<LessonsPage> {
  late final LessonRepository _repository =
      widget.repository ?? defaultLessonRepository();
  late final Stream<Map<String, int>> _counts = _repository.watchLessonCounts([
    for (final category in widget.categories) category.id,
  ]);

  @override
  Widget build(BuildContext context) => StreamBuilder<Map<String, int>>(
    stream: _counts,
    builder: (context, snapshot) =>
        _buildList(context, snapshot.data ?? const {}),
  );

  Widget _buildList(BuildContext context, Map<String, int> counts) {
    final categories = widget.categories;
    final scheme = Theme.of(context).colorScheme;
    return ColoredBox(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    context.tr('Darslar'),
                    style: TextStyle(
                      color: scheme.onSurface,
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -.6,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    context.tr('Murabbiy bilan video darslar'),
                    style: TextStyle(
                      color: scheme.onSurfaceVariant,
                      fontSize: 13.5,
                    ),
                  ),
                  const SizedBox(height: 24),
                  AppSectionHeader(
                    title: context.tr('Bo‘limlar'),
                    trailing: Text(
                      '${categories.length}',
                      style: TextStyle(
                        color: scheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  AppCard(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
                        for (var i = 0; i < categories.length; i++) ...[
                          if (i > 0)
                            Divider(
                              height: 1,
                              indent: 70,
                              color: scheme.outlineVariant,
                            ),
                          _CategoryRow(
                            course: categories[i],
                            count:
                                categories[i].lessons.length +
                                (counts[categories[i].id] ?? 0),
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute<void>(
                                builder: (_) => LessonCategoryPage(
                                  course: categories[i],
                                  repository: _repository,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({
    required this.course,
    required this.count,
    required this.onTap,
  });

  final TrainerCourse course;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (icon, accent) = _styleFor(course);
    return InkWell(
      key: Key('category-${course.id}'),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
        child: Row(
          children: [
            AppIconTile.tinted(icon: icon, size: 40, accent: accent),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.tr(course.title),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: scheme.onSurface,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    count == 0
                        ? context.tr('Videolar tez orada')
                        : context.tr('{n} ta video', {'n': count}),
                    style: TextStyle(
                      color: scheme.onSurfaceVariant,
                      fontSize: 12.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              LucideIcons.chevronRight,
              size: 18,
              color: scheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}

/// One category: its videos in order; any of them can be opened.
/// Admins (`admins/{uid}`) also get an upload button.
class LessonCategoryPage extends StatefulWidget {
  const LessonCategoryPage({
    super.key,
    required this.course,
    this.repository,
    this.uploader,
  });

  final TrainerCourse course;
  final LessonRepository? repository;
  final LessonVideoUploader? uploader;

  @override
  State<LessonCategoryPage> createState() => _LessonCategoryPageState();
}

class _LessonCategoryPageState extends State<LessonCategoryPage> {
  late final LessonRepository _repository =
      widget.repository ?? defaultLessonRepository();
  late final Stream<List<CourseLesson>> _lessons = _repository.watchLessons(
    widget.course.id,
  );
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _repository.isAdmin().then((value) {
      if (mounted && value) setState(() => _isAdmin = true);
    });
  }

  Future<void> _openUpload() async {
    final uploaded = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            VideoUploadPage(category: widget.course, uploader: widget.uploader),
      ),
    );
    if (uploaded == true && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.tr('Video yuklandi'))));
    }
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<List<CourseLesson>>(
    stream: _lessons,
    builder: (context, snapshot) {
      // Built-in lessons (none today) plus uploaded ones from Firestore.
      final course = widget.course.withLessons([
        ...widget.course.lessons,
        ...?snapshot.data,
      ]);
      return _buildPage(
        context,
        course,
        loading: !snapshot.hasData && !snapshot.hasError,
        failed: snapshot.hasError,
      );
    },
  );

  Widget _buildPage(
    BuildContext context,
    TrainerCourse course, {
    required bool loading,
    required bool failed,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final (icon, accent) = _styleFor(course);
    final lessons = course.orderedLessons;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          key: const Key('category-back'),
          tooltip: context.tr('Orqaga'),
          icon: const Icon(LucideIcons.arrowLeft),
          onPressed: () => Navigator.maybePop(context),
        ),
        title: Text(context.tr('Darslar')),
        actions: [
          if (_isAdmin)
            IconButton(
              key: const Key('category-upload'),
              tooltip: context.tr('Video yuklash'),
              icon: const Icon(LucideIcons.cloudUpload),
              onPressed: _openUpload,
            ),
          const SizedBox(width: 4),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AppCard(
                    padding: const EdgeInsets.all(18),
                    child: Row(
                      children: [
                        AppIconTile.tinted(
                          icon: icon,
                          size: 44,
                          accent: accent,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                context.tr(course.title),
                                style: TextStyle(
                                  color: scheme.onSurface,
                                  fontSize: 16.5,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: -.2,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                context.tr(course.description),
                                style: TextStyle(
                                  color: scheme.onSurfaceVariant,
                                  fontSize: 13,
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  AppSectionHeader(
                    title: context.tr('Videolar'),
                    trailing: Text(
                      '${lessons.length}',
                      style: TextStyle(
                        color: scheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (lessons.isEmpty && loading)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 32),
                      child: Center(
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2.5),
                        ),
                      ),
                    )
                  else if (lessons.isEmpty && failed)
                    const _LessonsError()
                  else if (lessons.isEmpty)
                    const _EmptyVideos()
                  else
                    AppCard(
                      padding: EdgeInsets.zero,
                      child: Column(
                        children: [
                          for (var i = 0; i < lessons.length; i++) ...[
                            if (i > 0)
                              Divider(
                                height: 1,
                                indent: 70,
                                color: scheme.outlineVariant,
                              ),
                            _LessonRow(
                              lesson: lessons[i],
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute<void>(
                                  builder: (_) =>
                                      LessonPage(course: course, index: i),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LessonsError extends StatelessWidget {
  const _LessonsError();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AppCard(
      key: const Key('category-error'),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Text(
        context.tr('Darslarni yuklab bo‘lmadi. Internetni tekshiring.'),
        textAlign: TextAlign.center,
        style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13.5),
      ),
    );
  }
}

class _EmptyVideos extends StatelessWidget {
  const _EmptyVideos();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AppCard(
      key: const Key('category-empty'),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
      child: Column(
        children: [
          const AppIconTile.tinted(
            icon: LucideIcons.clapperboard,
            size: 44,
            accent: AppPalette.accentSlate,
          ),
          const SizedBox(height: 12),
          Text(
            context.tr('Videolar tez orada yuklanadi'),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: scheme.onSurface,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            context.tr('Yuklangan videolar shu yerda tartib bilan chiqadi.'),
            textAlign: TextAlign.center,
            style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _LessonRow extends StatelessWidget {
  const _LessonRow({required this.lesson, required this.onTap});

  final CourseLesson lesson;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      key: Key('lesson-${lesson.id}'),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
        child: Row(
          children: [
            AppIconTile.tinted(
              icon: lesson.hasVideo ? LucideIcons.play : LucideIcons.lock,
              size: 40,
              accent: lesson.hasVideo
                  ? AppPalette.accentBlue
                  : AppPalette.accentSlate,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${lesson.order}. ${context.tr(lesson.title)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: scheme.onSurface,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (lesson.description.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      context.tr(lesson.description),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: scheme.onSurfaceVariant,
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (lesson.hasVideo && lesson.durationMinutes != null)
              Text(
                '${lesson.durationMinutes} ${context.tr('daq')}',
                style: TextStyle(
                  color: scheme.onSurfaceVariant,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                ),
              )
            else if (!lesson.hasVideo)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(AppRadius.xs),
                ),
                child: Text(
                  context.tr('Tez orada'),
                  style: TextStyle(
                    color: scheme.onSurfaceVariant,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Lesson detail with a video area (playback is added with the backend).
/// [index] points into [TrainerCourse.orderedLessons].
class LessonPage extends StatelessWidget {
  const LessonPage({
    super.key,
    required this.course,
    required this.index,
    this.playerBuilder,
  });

  final TrainerCourse course;
  final int index;

  /// Overrides the video player (tests).
  final Widget Function(CourseLesson lesson)? playerBuilder;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final lessons = course.orderedLessons;
    final lesson = lessons[index];
    void go(int target) => Navigator.pushReplacement(
      context,
      MaterialPageRoute<void>(
        builder: (_) => LessonPage(
          course: course,
          index: target,
          playerBuilder: playerBuilder,
        ),
      ),
    );
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('{n}-dars', {'n': lesson.order}))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
        children: [
          if (lesson.hasVideo)
            KeyedSubtree(
              key: ValueKey('player-${lesson.id}'),
              child:
                  playerBuilder?.call(lesson) ??
                  LessonVideoPlayer(url: lesson.videoUrl!),
            )
          else
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.lg),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: ColoredBox(
                  color: AppPalette.navy,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        LucideIcons.clapperboard,
                        size: 40,
                        color: Colors.white.withValues(alpha: .85),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        context.tr('Video hali yuklanmagan'),
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: .75),
                          fontSize: 13.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          const SizedBox(height: 20),
          Text(
            context.tr(lesson.title),
            style: TextStyle(
              color: scheme.onSurface,
              fontSize: 20,
              fontWeight: FontWeight.w600,
              letterSpacing: -.4,
            ),
          ),
          if (lesson.description.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              context.tr(lesson.description),
              style: TextStyle(
                color: scheme.onSurfaceVariant,
                fontSize: 14.5,
                height: 1.5,
              ),
            ),
          ],
          const SizedBox(height: 28),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: index > 0 ? () => go(index - 1) : null,
                  icon: const Icon(LucideIcons.chevronLeft, size: 16),
                  label: Text(context.tr('Oldingi')),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: index < lessons.length - 1
                      ? () => go(index + 1)
                      : null,
                  icon: const Icon(LucideIcons.chevronRight, size: 16),
                  label: Text(context.tr('Keyingi')),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
