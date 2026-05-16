import 'package:flutter/material.dart';

enum DietType { calorie, keto }

class PFCScore {
  static double calculate(double protein, double fat, double carb, DietType diet) {
    final pKcal = protein * 4;
    final fKcal = fat * 9;
    final cKcal = carb * 4;
    final total = pKcal + fKcal + cKcal;
    if (total <= 0) return 0;

    final pRatio = pKcal / total;
    final fRatio = fKcal / total;
    final cRatio = cKcal / total;

    if (diet == DietType.keto) {
      // Keto: F=65%+ ideal, C=8% or less ideal
      // 50pts fat: starts scoring at 30%, full at 65%+
      final fatScore = ((fRatio - 0.30) / 0.35).clamp(0.0, 1.0) * 50;
      // 50pts low carb: full at <=8%, zero at 20%+
      final lowCarbScore = (1.0 - ((cRatio - 0.08) / 0.12).clamp(0.0, 1.0)) * 50;
      return (fatScore + lowCarbScore).clamp(0.0, 100.0);
    }

    // Calorie restriction: protein-first scoring for fat loss
    // 50pts protein: full at 25%+  (ダイエット中は筋肉維持のため高タンパクが重要)
    final proteinScore = (pRatio / 0.25).clamp(0.0, 1.0) * 50;
    // 30pts fat: full at <=35%, zero at 65%+
    final fatScore = (1.0 - ((fRatio - 0.35) / 0.30).clamp(0.0, 1.0)) * 30;
    // 20pts carb: full at <=55%, zero at 80%+  (カロリー制限中の糖質過多にペナルティ)
    final carbScore = (1.0 - ((cRatio - 0.55) / 0.25).clamp(0.0, 1.0)) * 20;
    return (proteinScore + fatScore + carbScore).clamp(0.0, 100.0);
  }

  static Color color(double score) {
    if (score >= 75) return const Color(0xFF4CAF50); // green
    if (score >= 55) return const Color(0xFF8BC34A); // light green
    if (score >= 35) return const Color(0xFFFFC107); // amber
    if (score >= 15) return const Color(0xFFFF9800); // orange
    return const Color(0xFFF44336);                  // red
  }

  static String label(double score) {
    if (score >= 75) return 'バランス良';
    if (score >= 55) return 'まずまず';
    if (score >= 35) return 'やや偏り';
    if (score >= 15) return '偏りあり';
    return '要注意';
  }
}
