import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/food_nutrition.dart';

class FoodLogService {
  FoodLogService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, dynamic>> _dayRef(String uid, DateTime day) {
    final id =
        '${day.year.toString().padLeft(4, '0')}-'
        '${day.month.toString().padLeft(2, '0')}-'
        '${day.day.toString().padLeft(2, '0')}';
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('food_logs')
        .doc(id);
  }

  Future<List<FoodNutrition>> loadToday(String uid) async {
    return loadDay(uid, DateTime.now());
  }

  /// A single document-ID range query; no composite index is required.
  Future<Map<DateTime, List<FoodNutrition>>> loadRange(
    String uid,
    DateTime start,
    DateTime end,
  ) async {
    String id(DateTime day) =>
        '${day.year.toString().padLeft(4, '0')}-'
        '${day.month.toString().padLeft(2, '0')}-'
        '${day.day.toString().padLeft(2, '0')}';
    final snapshot = await _firestore
        .collection('users')
        .doc(uid)
        .collection('food_logs')
        .where(FieldPath.documentId, isGreaterThanOrEqualTo: id(start))
        .where(FieldPath.documentId, isLessThan: id(end))
        .get();
    return {
      for (final doc in snapshot.docs)
        DateTime.parse(doc.id): (doc.data()['foods'] as List<dynamic>? ?? [])
            .map(
              (item) =>
                  FoodNutrition.fromMap(Map<String, dynamic>.from(item as Map)),
            )
            .toList(),
    };
  }

  Future<List<FoodNutrition>> loadDay(String uid, DateTime day) async {
    final snap = await _dayRef(uid, day).get();
    final data = snap.data();
    if (data == null) return const [];
    final foods = data['foods'] as List<dynamic>? ?? const [];
    return foods
        .map((item) => FoodNutrition.fromMap(item as Map<String, dynamic>))
        .toList();
  }

  Future<Map<DateTime, double>> loadCurrentWeekCalories(String uid) async {
    return loadWeekCalories(uid, DateTime.now());
  }

  Future<Map<DateTime, double>> loadWeekCalories(
    String uid,
    DateTime now,
  ) async {
    final today = DateTime(now.year, now.month, now.day);
    final monday = DateTime(
      today.year,
      today.month,
      today.day - today.weekday + 1,
    );
    final days = List.generate(
      7,
      (index) => DateTime(monday.year, monday.month, monday.day + index),
    );
    final snapshots = await Future.wait(
      days.map((day) => _dayRef(uid, day).get()),
    );

    return {
      for (var index = 0; index < days.length; index++)
        days[index]: _caloriesFromSnapshot(snapshots[index]),
    };
  }

  double _caloriesFromSnapshot(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final foods = snapshot.data()?['foods'] as List<dynamic>? ?? const [];
    return foods.fold<double>(0, (total, item) {
      final map = Map<String, dynamic>.from(item as Map);
      final calories = map['calories'];
      return total + (calories is num ? calories.toDouble() : 0);
    });
  }

  Future<void> saveToday(String uid, List<FoodNutrition> foods) {
    return _dayRef(uid, DateTime.now()).set({
      'foods': foods.map((food) => food.toMap()).toList(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
