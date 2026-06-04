import '../models/meal_entry.dart';
import 'nutrition_db_service.dart';
import 'body_status_service.dart';

class DeficiencyAlert {
  final String nutrientId;
  final String nutrientName;
  final int consecutiveDays;
  final List<String> recommendedFoods;
  final String message;

  const DeficiencyAlert({
    required this.nutrientId,
    required this.nutrientName,
    required this.consecutiveDays,
    required this.recommendedFoods,
    required this.message,
  });
}

class DeficiencyTrendService {
  static final DeficiencyTrendService instance = DeficiencyTrendService._();
  DeficiencyTrendService._();

  // 日付→食事記録のマップから慢性的な不足成分を検出
  List<DeficiencyAlert> getChronicDeficiencies(
    Map<String, List<MealEntry>> dailyMeals,
    int days,
  ) {
    final db = NutritionDbService.instance;
    if (!db.isReady) return [];

    final bodyService = BodyStatusService.instance;

    // 各日のスコアを計算して不足成分を把握
    final deficiencyCount = <String, int>{}; // nutrientId → 不足日数

    for (final meals in dailyMeals.values) {
      final scores = bodyService.calculateScores(meals);
      for (final score in scores) {
        for (final missing in score.missingNutrientIds) {
          deficiencyCount[missing] = (deficiencyCount[missing] ?? 0) + 1;
        }
      }
    }

    final alerts = <DeficiencyAlert>[];
    for (final entry in deficiencyCount.entries) {
      if (entry.value < 3) continue; // 3日未満は無視

      final nutrientId = entry.key;
      String name = nutrientId;
      List<String> topFoods = [];

      // 機能性成分から名前取得
      final fi = db.getFunctionalIngredientById(nutrientId);
      if (fi != null) {
        name = fi['name'] as String? ?? nutrientId;
        topFoods = List<String>.from(fi['top_foods'] as List? ?? []);
      } else {
        // 基本栄養素から名前取得
        final n = db.getNutrientById(nutrientId);
        if (n != null) {
          name = n['name'] as String? ?? nutrientId;
          topFoods = List<String>.from(n['top_foods'] as List? ?? []);
        }
      }

      final foodStr = topFoods.take(2).join('・');
      alerts.add(DeficiencyAlert(
        nutrientId: nutrientId,
        nutrientName: name,
        consecutiveDays: entry.value,
        recommendedFoods: topFoods,
        message: foodStr.isEmpty
            ? '$nameが${entry.value}日間不足しています'
            : '$nameが${entry.value}日間不足しています → $foodStrで補えます',
      ));
    }

    // 不足日数が多い順にソート
    alerts.sort((a, b) => b.consecutiveDays.compareTo(a.consecutiveDays));
    return alerts.take(3).toList();
  }

  // 今日不足している成分（BodyPartScoreから集約）
  List<MissingNutrientItem> getTodayMissingNutrients(List<MealEntry> todaysMeals) {
    final db = NutritionDbService.instance;
    if (!db.isReady) return [];

    final bodyService = BodyStatusService.instance;
    final scores = bodyService.calculateScores(todaysMeals);

    final missing = <String, MissingNutrientItem>{};
    for (final score in scores) {
      for (final nId in score.missingNutrientIds) {
        if (missing.containsKey(nId)) continue;

        String name = nId;
        List<String> topFoods = [];

        final fi = db.getFunctionalIngredientById(nId);
        if (fi != null) {
          name = fi['name'] as String? ?? nId;
          topFoods = List<String>.from(fi['top_foods'] as List? ?? []);
        } else {
          final n = db.getNutrientById(nId);
          if (n != null) {
            name = n['name'] as String? ?? nId;
            topFoods = List<String>.from(n['top_foods'] as List? ?? []);
          }
        }

        missing[nId] = MissingNutrientItem(
          id: nId,
          name: name,
          topFoods: topFoods,
        );
      }
    }

    return missing.values.take(6).toList();
  }
}

class MissingNutrientItem {
  final String id;
  final String name;
  final List<String> topFoods;

  const MissingNutrientItem({
    required this.id,
    required this.name,
    required this.topFoods,
  });
}
