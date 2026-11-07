import 'package:flutter/material.dart';

enum WorkoutCategory { cardio, strength, bodyweight, flexibility, sport }

class Workout {
  const Workout({
    required this.name,
    required this.category,
    required this.met,
    required this.icon,
  });

  final String name;
  final WorkoutCategory category;
  final double met;
  final IconData icon;

  double calories({required double weightKg, required int minutes}) =>
      met * 3.5 * weightKg / 200 * minutes;
}

class WorkoutLog {
  const WorkoutLog({
    required this.workout,
    required this.minutes,
    required this.calories,
  });

  final Workout workout;
  final int minutes;
  final double calories;
}
