enum BiologicalSex { male, female }

enum BmrFormula { mifflinStJeor, revisedHarrisBenedict, katchMcArdle }

class CalorieNeedsResult {
  const CalorieNeedsResult({required this.bmr, required this.maintenance});

  final double bmr;
  final double maintenance;

  double get mildLoss => maintenance - 250;
  double get weightLoss => maintenance - 500;
  double get extremeLoss => maintenance - 1000;
  double get mildGain => maintenance + 250;
  double get weightGain => maintenance + 500;
  double get fastGain => maintenance + 1000;

  MacroTargets macrosFor(double calories) => MacroTargets(
    proteinGrams: calories * .30 / 4,
    carbohydrateGrams: calories * .40 / 4,
    fatGrams: calories * .30 / 9,
  );
}

class MacroTargets {
  const MacroTargets({
    required this.proteinGrams,
    required this.carbohydrateGrams,
    required this.fatGrams,
  });

  final double proteinGrams;
  final double carbohydrateGrams;
  final double fatGrams;
}

class CalorieNeedsCalculator {
  const CalorieNeedsCalculator();

  CalorieNeedsResult calculate({
    required int age,
    required BiologicalSex sex,
    required double heightCm,
    required double weightKg,
    required double activityFactor,
    BmrFormula formula = BmrFormula.mifflinStJeor,
    double? bodyFatPercent,
  }) {
    if (age < 15 || age > 80) {
      throw const CalorieNeedsException(
        'Yosh 15–80 oralig‘ida bo‘lishi kerak.',
      );
    }
    if (!heightCm.isFinite || heightCm < 100 || heightCm > 250) {
      throw const CalorieNeedsException(
        'Bo‘y 100–250 cm oralig‘ida bo‘lishi kerak.',
      );
    }
    if (!weightKg.isFinite || weightKg < 30 || weightKg > 350) {
      throw const CalorieNeedsException(
        'Vazn 30–350 kg oralig‘ida bo‘lishi kerak.',
      );
    }
    if (!activityFactor.isFinite ||
        activityFactor < 1 ||
        activityFactor > 1.95) {
      throw const CalorieNeedsException('Faollik darajasi noto‘g‘ri.');
    }

    late final double bmr;
    switch (formula) {
      case BmrFormula.mifflinStJeor:
        bmr =
            10 * weightKg +
            6.25 * heightCm -
            5 * age +
            (sex == BiologicalSex.male ? 5 : -161);
      case BmrFormula.revisedHarrisBenedict:
        bmr = sex == BiologicalSex.male
            ? 13.397 * weightKg + 4.799 * heightCm - 5.677 * age + 88.362
            : 9.247 * weightKg + 3.098 * heightCm - 4.330 * age + 447.593;
      case BmrFormula.katchMcArdle:
        final fat = bodyFatPercent;
        if (fat == null || !fat.isFinite || fat < 2 || fat > 70) {
          throw const CalorieNeedsException(
            'Katch–McArdle uchun tana yog‘ini 2–70% kiriting.',
          );
        }
        bmr = 370 + 21.6 * (1 - fat / 100) * weightKg;
    }
    return CalorieNeedsResult(bmr: bmr, maintenance: bmr * activityFactor);
  }
}

class CalorieNeedsException implements Exception {
  const CalorieNeedsException(this.message);
  final String message;
}
