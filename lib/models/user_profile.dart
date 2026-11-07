class UserProfile {
  const UserProfile({
    required this.firstName,
    required this.lastName,
    required this.gender,
    required this.age,
    required this.heightCm,
    required this.weightKg,
    required this.activityLevel,
    required this.goal,
    this.photoUrl,
    this.languageCode = 'uz',
    this.themeMode = 'dark',
  });

  final String firstName;
  final String lastName;
  final String gender;
  final int age;
  final double heightCm;
  final double weightKg;
  final String activityLevel;
  final String goal;
  final String? photoUrl;
  final String languageCode;
  final String themeMode;

  String get fullName => '$firstName $lastName'.trim();

  Map<String, Object> toMap() => {
    'firstName': firstName,
    'lastName': lastName,
    'gender': gender,
    'age': age,
    'heightCm': heightCm,
    'weightKg': weightKg,
    'activityLevel': activityLevel,
    'goal': goal,
    'photoUrl': ?photoUrl,
    'languageCode': languageCode,
    'themeMode': themeMode,
    'appearanceVersion': 2,
  };

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    return UserProfile(
      firstName: map['firstName'] as String? ?? '',
      lastName: map['lastName'] as String? ?? '',
      gender: map['gender'] as String? ?? '',
      age: (map['age'] as num?)?.toInt() ?? 0,
      heightCm: (map['heightCm'] as num?)?.toDouble() ?? 0,
      weightKg: (map['weightKg'] as num?)?.toDouble() ?? 0,
      activityLevel: map['activityLevel'] as String? ?? '',
      goal: map['goal'] as String? ?? '',
      photoUrl: map['photoUrl'] as String?,
      themeMode: map['themeMode'] == 'light' ? 'light' : 'dark',
      languageCode: switch (map['languageCode']) {
        'ru' => 'ru',
        'en' => 'en',
        _ => 'uz',
      },
    );
  }
}
