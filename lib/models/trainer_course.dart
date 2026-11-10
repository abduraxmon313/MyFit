/// One video lesson of a trainer's course.
///
/// Stored in Firestore at `courses/{categoryId}/lessons/{lessonId}`. New
/// uploads live on Cloudflare R2 ([storageProvider] `r2`); [videoUrl] is the
/// public playback URL, so older documents with any other URL keep working.
class CourseLesson {
  const CourseLesson({
    required this.id,
    required this.order,
    required this.title,
    required this.description,
    this.durationMinutes,
    this.durationSeconds,
    this.videoUrl,
    this.thumbnailUrl,
    this.storageProvider,
    this.objectKey,
    this.sizeBytes,
    this.contentType,
  });

  final String id;
  final int order;

  /// Translation keys for built-in lessons; plain text for uploaded ones.
  final String title;
  final String description;
  final int? durationMinutes;
  final int? durationSeconds;
  final String? videoUrl;
  final String? thumbnailUrl;

  /// `r2` for Cloudflare R2 uploads; `null` for older documents.
  final String? storageProvider;
  final String? objectKey;
  final int? sizeBytes;
  final String? contentType;

  bool get hasVideo => (videoUrl ?? '').trim().isNotEmpty;

  factory CourseLesson.fromMap(String id, Map<String, dynamic> map) =>
      CourseLesson(
        id: id,
        order: (map['order'] as num?)?.toInt() ?? 0,
        title: map['title'] as String? ?? '',
        description: map['description'] as String? ?? '',
        durationMinutes: (map['durationMinutes'] as num?)?.toInt(),
        durationSeconds: (map['durationSeconds'] as num?)?.toInt(),
        videoUrl: map['videoUrl'] as String?,
        thumbnailUrl: map['thumbnailUrl'] as String?,
        storageProvider: map['storageProvider'] as String?,
        objectKey: map['objectKey'] as String?,
        sizeBytes: (map['sizeBytes'] as num?)?.toInt(),
        contentType: map['contentType'] as String?,
      );

  Map<String, Object?> toMap() => {
    'order': order,
    'title': title,
    'description': description,
    'durationMinutes': durationMinutes,
    'videoUrl': videoUrl,
    'thumbnailUrl': thumbnailUrl,
    'durationSeconds': ?durationSeconds,
    'storageProvider': ?storageProvider,
    'objectKey': ?objectKey,
    'sizeBytes': ?sizeBytes,
    'contentType': ?contentType,
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

  /// Same category with a different lesson list.
  TrainerCourse withLessons(List<CourseLesson> lessons) => TrainerCourse(
    id: id,
    title: title,
    description: description,
    trainerName: trainerName,
    lessons: lessons,
  );
}
