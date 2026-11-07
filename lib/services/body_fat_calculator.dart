import 'dart:math' as math;

import 'calorie_needs_calculator.dart';

class BodyFatResult {
  const BodyFatResult({
    required this.navyPercent,
    required this.bmiPercent,
    required this.fatMassKg,
    required this.leanMassKg,
    required this.idealPercent,
    required this.fatToIdealKg,
    required this.category,
  });

  final double navyPercent;
  final double bmiPercent;
  final double fatMassKg;
  final double leanMassKg;
  final double idealPercent;
  final double fatToIdealKg;
  final String category;
}

class BodyFatCalculator {
  const BodyFatCalculator();

  BodyFatResult calculate({
    required BiologicalSex sex,
    required int age,
    required double weightKg,
    required double heightCm,
    required double neckCm,
    required double waistCm,
    double? hipCm,
  }) {
    if (age < 18 || age > 80) {
      throw const BodyFatException('Yosh 18–80 oralig‘ida bo‘lishi kerak.');
    }
    if (!weightKg.isFinite || weightKg < 30 || weightKg > 350) {
      throw const BodyFatException('Vazn 30–350 kg oralig‘ida bo‘lishi kerak.');
    }
    if (!heightCm.isFinite || heightCm < 100 || heightCm > 250) {
      throw const BodyFatException(
        'Bo‘y 100–250 cm oralig‘ida bo‘lishi kerak.',
      );
    }
    if (!neckCm.isFinite ||
        !waistCm.isFinite ||
        neckCm < 20 ||
        neckCm > 80 ||
        waistCm < 40 ||
        waistCm > 250) {
      throw const BodyFatException(
        'Bo‘yin yoki bel/qorin o‘lchovini tekshiring.',
      );
    }

    late final double navy;
    if (sex == BiologicalSex.male) {
      if (waistCm <= neckCm) {
        throw const BodyFatException(
          'Qorin o‘lchovi bo‘yin o‘lchovidan katta bo‘lishi kerak.',
        );
      }
      navy =
          495 /
              (1.0324 -
                  0.19077 * _log10(waistCm - neckCm) +
                  0.15456 * _log10(heightCm)) -
          450;
    } else {
      final hip = hipCm;
      if (hip == null || !hip.isFinite || hip < 50 || hip > 250) {
        throw const BodyFatException('Ayollar uchun son o‘lchovini kiriting.');
      }
      navy =
          495 /
              (1.29579 -
                  0.35004 * _log10(waistCm + hip - neckCm) +
                  0.22100 * _log10(heightCm)) -
          450;
    }
    if (!navy.isFinite || navy <= 0 || navy >= 75) {
      throw const BodyFatException(
        'O‘lchovlardan haqiqiy natija olinmadi. Qayta o‘lchang.',
      );
    }

    final bmi = weightKg / math.pow(heightCm / 100, 2);
    final bmiPercent =
        1.20 * bmi + 0.23 * age - (sex == BiologicalSex.male ? 16.2 : 5.4);
    final ideal = _idealForAge(sex, age);
    final fatMass = navy / 100 * weightKg;
    final idealFatMass = ideal / 100 * weightKg;
    return BodyFatResult(
      navyPercent: navy,
      bmiPercent: bmiPercent,
      fatMassKg: fatMass,
      leanMassKg: weightKg - fatMass,
      idealPercent: ideal,
      fatToIdealKg: math.max(0, fatMass - idealFatMass),
      category: _category(sex, navy),
    );
  }

  double _log10(double value) => math.log(value) / math.ln10;

  String _category(BiologicalSex sex, double value) {
    if (sex == BiologicalSex.male) {
      if (value <= 5) return 'Zaruriy yog‘';
      if (value <= 13) return 'Sportchi';
      if (value <= 17) return 'Fitness';
      if (value <= 24) return 'O‘rtacha';
      return 'Semizlik';
    }
    if (value <= 13) return 'Zaruriy yog‘';
    if (value <= 20) return 'Sportchi';
    if (value <= 24) return 'Fitness';
    if (value <= 31) return 'O‘rtacha';
    return 'Semizlik';
  }

  double _idealForAge(BiologicalSex sex, int age) {
    const male = <int, double>{
      20: 8.5,
      25: 10.5,
      30: 12.7,
      35: 13.7,
      40: 15.3,
      45: 16.4,
      50: 18.9,
      55: 20.9,
    };
    const female = <int, double>{
      20: 17.7,
      25: 18.4,
      30: 19.3,
      35: 21.5,
      40: 22.2,
      45: 22.9,
      50: 25.2,
      55: 26.3,
    };
    final table = sex == BiologicalSex.male ? male : female;
    if (age <= 20) return table[20]!;
    if (age >= 55) return table[55]!;
    final lower = (age ~/ 5) * 5;
    final upper = lower + 5;
    return table[lower]! +
        (table[upper]! - table[lower]!) * ((age - lower) / 5);
  }
}

class BodyFatException implements Exception {
  const BodyFatException(this.message);
  final String message;
}
