/// One video lesson of a trainer's course.
///
/// [videoUrl] stays `null` until the video is uploaded (planned: Firebase
/// Storage + Firestore `courses/{courseId}/lessons/{lessonId}`).
class CourseLesson {
  const CourseLesson({
    required this.id,
    required this.order,
    required this.title,
    required this.description,
    this.durationMinutes,
    this.videoUrl,
    this.thumbnailUrl,
  });

  final String id;
  final int order;

  /// Translation keys (see `app_localizations.dart`).
  final String title;
  final String description;
  final int? durationMinutes;
  final String? videoUrl;
  final String? thumbnailUrl;

  bool get hasVideo => (videoUrl ?? '').trim().isNotEmpty;

  factory CourseLesson.fromMap(String id, Map<String, dynamic> map) =>
      CourseLesson(
        id: id,
        order: (map['order'] as num?)?.toInt() ?? 0,
        title: map['title'] as String? ?? '',
        description: map['description'] as String? ?? '',
        durationMinutes: (map['durationMinutes'] as num?)?.toInt(),
        videoUrl: map['videoUrl'] as String?,
        thumbnailUrl: map['thumbnailUrl'] as String?,
      );

  Map<String, Object?> toMap() => {
    'order': order,
    'title': title,
    'description': description,
    'durationMinutes': durationMinutes,
    'videoUrl': videoUrl,
    'thumbnailUrl': thumbnailUrl,
  };
}

/// A lesson category (video course) shown in the "Darslar" tab.
class TrainerCourse {
  const TrainerCourse({
    required this.id,
    required this.title,
    required this.description,
    required this.lessons,
    this.trainerName,
  });

  final String id;
  final String title;
  final String description;

  /// Real trainer name is filled in when the course is published.
  final String? trainerName;
  final List<CourseLesson> lessons;

  int get videoCount => lessons.where((lesson) => lesson.hasVideo).length;

  /// Lessons in watching order.
  List<CourseLesson> get orderedLessons =>
      [...lessons]..sort((a, b) => a.order.compareTo(b.order));
}
