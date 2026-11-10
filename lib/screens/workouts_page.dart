import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../data/trainer_course.dart';
import '../l10n/app_localizations.dart';
import '../models/trainer_course.dart';
import '../theme/app_theme.dart';
import '../widgets/app_ui.dart';

/// "Mashqlar" tab: the selected trainer's video course.
class WorkoutsPage extends StatelessWidget {
  const WorkoutsPage({super.key, this.course = kTrainerCourse});

  final TrainerCourse course;

  void _open(BuildContext context, int index) {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => LessonPage(course: course, index: index),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final lessons = [...course.lessons]
      ..sort((a, b) => a.order.compareTo(b.order));
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
                    context.tr('Mashqlar'),
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
                  const SizedBox(height: 20),
                  _CourseHeader(course: course),
                  if (course.videoCount < lessons.length) ...[
                    const SizedBox(height: 12),
                    _Notice(
                      text: context.tr(
                        'Videolar tez orada yuklanadi. Darslar tartibi quyida.',
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  AppSectionHeader(
                    title: context.tr('Darslar'),
                    trailing: Text(
                      '${lessons.length}',
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
                        for (var i = 0; i < lessons.length; i++) ...[
                          if (i > 0)
                            Divider(
                              height: 1,
                              indent: 70,
                              color: scheme.outlineVariant,
                            ),
                          _LessonRow(
                            lesson: lessons[i],
                            onTap: () => _open(
                              context,
                              course.lessons.indexOf(lessons[i]),
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

class _CourseHeader extends StatelessWidget {
  const _CourseHeader({required this.course});

  final TrainerCourse course;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final minutes = course.lessons.fold<int>(
      0,
      (sum, lesson) => sum + (lesson.durationMinutes ?? 0),
    );
    Widget stat(IconData icon, String value, String label) => Expanded(
      child: Row(
        children: [
          Icon(icon, size: 16, color: scheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    color: scheme.onSurface,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: scheme.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
    return AppCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const AppIconTile.tinted(
                icon: LucideIcons.graduationCap,
                size: 44,
                accent: AppPalette.accentViolet,
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
                    const SizedBox(height: 2),
                    Text(
                      course.trainerName ?? context.tr('Murabbiy'),
                      style: TextStyle(
                        color: scheme.onSurfaceVariant,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            context.tr(course.description),
            style: TextStyle(
              color: scheme.onSurfaceVariant,
              fontSize: 13.5,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 16),
          Divider(height: 1, color: scheme.outlineVariant),
          const SizedBox(height: 14),
          Row(
            children: [
              stat(
                LucideIcons.listVideo,
                '${course.lessons.length}',
                context.tr('dars'),
              ),
              stat(
                LucideIcons.circlePlay,
                '${course.videoCount}',
                context.tr('video yuklangan'),
              ),
              stat(
                LucideIcons.timer,
                minutes > 0 ? '$minutes' : '—',
                context.tr('daqiqa'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        children: [
          Icon(LucideIcons.info, size: 16, color: scheme.onSurfaceVariant),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
            ),
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
class LessonPage extends StatelessWidget {
  const LessonPage({super.key, required this.course, required this.index});

  final TrainerCourse course;
  final int index;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final lesson = course.lessons[index];
    void go(int target) => Navigator.pushReplacement(
      context,
      MaterialPageRoute<void>(
        builder: (_) => LessonPage(course: course, index: target),
      ),
    );
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('{n}-dars', {'n': lesson.order}))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
        children: [
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
                      lesson.hasVideo
                          ? LucideIcons.circlePlay
                          : LucideIcons.clapperboard,
                      size: 40,
                      color: Colors.white.withValues(alpha: .85),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      context.tr(
                        lesson.hasVideo
                            ? 'Video tez orada ijro etiladi'
                            : 'Video hali yuklanmagan',
                      ),
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
          const SizedBox(height: 6),
          Text(
            context.tr(lesson.description),
            style: TextStyle(
              color: scheme.onSurfaceVariant,
              fontSize: 14.5,
              height: 1.5,
            ),
          ),
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
                  onPressed: index < course.lessons.length - 1
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
