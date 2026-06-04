import '../models/meal_entry.dart';
import 'nutrition_db_service.dart';

class BodyPartScore {
  final String id;
  final String name;
  final String emoji;
  final double score; // 0.0〜1.0
  final List<String> missingNutrientIds;
  final List<String> obtainedNutrientIds;

  const BodyPartScore({
    required this.id,
    required this.name,
    required this.emoji,
    required this.score,
    required this.missingNutrientIds,
    required this.obtainedNutrientIds,
  });
}

class BodyStatusService {
  static final BodyStatusService instance = BodyStatusService._();
  BodyStatusService._();

  // MealEntry から取れる基本栄養素ID→値のマッピング
  static Map<String, double> _extractBasicNutrients(List<MealEntry> meals) {
    final protein = meals.fold(0.0, (s, m) => s + m.protein);
    final fat = meals.fold(0.0, (s, m) => s + m.fat);
    final carb = meals.fold(0.0, (s, m) => s + m.carb);
    final fiber = meals.fold(0.0, (s, m) => s + m.fiber);
    final iron = meals.fold(0.0, (s, m) => s + m.iron);
    final calcium = meals.fold(0.0, (s, m) => s + m.calcium);
    return {
      'protein': protein,
      'fat': fat,
      'carbohydrate': carb,
      'dietary_fiber': fiber,
      'iron': iron,
      'calcium': calcium,
    };
  }

  // 各基本栄養素の1日推奨量（MealEntryの単位に合わせたもの）
  static const Map<String, double> _dailyRecommended = {
    'protein': 65.0,      // g
    'fat': 60.0,          // g
    'carbohydrate': 300.0, // g
    'dietary_fiber': 21.0, // g
    'iron': 10.5,         // mg
    'calcium': 800.0,     // mg
  };

  // 今日の食事から部位別スコアを計算
  List<BodyPartScore> calculateScores(List<MealEntry> todaysMeals) {
    final db = NutritionDbService.instance;
    if (!db.isReady) return [];

    final basicNutrients = _extractBasicNutrients(todaysMeals);
    final foodNames = todaysMeals.map((m) => m.foodName).toList();
    final obtainedFI = db.getObtainedFunctionalIngredients(foodNames);

    final scores = <BodyPartScore>[];
    for (final bp in db.bodyParts) {
      final bpId = bp['id'] as String;
      final bpName = bp['name'] as String;
      final bpEmoji = bp['emoji'] as String;
      final relatedIds = List<String>.from(bp['related_nutrients'] as List? ?? []);

      final obtained = <String>[];
      final missing = <String>[];

      for (final nId in relatedIds) {
        if (_isObtained(nId, basicNutrients, obtainedFI, db)) {
          obtained.add(nId);
        } else {
          missing.add(nId);
        }
      }

      final total = relatedIds.length;
      final score = total == 0 ? 0.5 : obtained.length / total;

      scores.add(BodyPartScore(
        id: bpId,
        name: bpName,
        emoji: bpEmoji,
        score: score,
        missingNutrientIds: missing,
        obtainedNutrientIds: obtained,
      ));
    }
    return scores;
  }

  bool _isObtained(
    String nutrientId,
    Map<String, double> basicNutrients,
    Set<String> obtainedFI,
    NutritionDbService db,
  ) {
    // 基本栄養素（MealEntryで追跡できるもの）
    if (basicNutrients.containsKey(nutrientId)) {
      final val = basicNutrients[nutrientId]!;
      final recommended = _dailyRecommended[nutrientId] ?? 1.0;
      return val >= recommended * 0.3; // 30%以上摂れていれば「得られた」とみなす
    }

    // 機能性成分
    if (db.isFunctionalIngredient(nutrientId)) {
      return obtainedFI.contains(nutrientId);
    }

    // 基本栄養素DB（top_foodsとの照合）
    final nutrient = db.getNutrientById(nutrientId);
    if (nutrient != null) {
      final topFoods = List<String>.from(nutrient['top_foods'] as List? ?? []);
      // top_foodsの食材が今日の食事に含まれているかチェック
      // obtainedFIが空でも食材名から判断
      return obtainedFI.isNotEmpty; // 何か食べた場合は部分的に得られたとみなす（簡略化）
    }

    return false;
  }

  String getStatusMessage(BodyPartScore score) {
    final db = NutritionDbService.instance;
    final bp = db.getBodyPartById(score.id);
    if (bp == null) return '';
    if (score.score >= 0.7) {
      return bp['sufficient_message'] as String? ?? '';
    } else if (score.score < 0.4) {
      return bp['deficiency_message'] as String? ?? '';
    }
    return '少し補給できると良さそうです';
  }
}
