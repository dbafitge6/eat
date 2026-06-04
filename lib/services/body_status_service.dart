import '../services/nutrition_db_service.dart';

class BodyPartScore {
  final String partId;
  final double score; // 0.0 ~ 1.0
  final List<String> coveredIngredientIds;
  final List<String> missingIngredientIds;
  final List<String> coveredNutrientIds;
  final List<String> missingNutrientIds;

  const BodyPartScore({
    required this.partId,
    required this.score,
    required this.coveredIngredientIds,
    required this.missingIngredientIds,
    required this.coveredNutrientIds,
    required this.missingNutrientIds,
  });
}

class BodyStatusService {
  static final BodyStatusService instance = BodyStatusService._();
  BodyStatusService._();

  /// Calculate body part scores based on today's food names.
  List<BodyPartScore> calculate(List<String> foodNames) {
    final db = NutritionDbService.instance;
    final analysis = db.analyzefoods(foodNames);
    final coveredIngredients = analysis.ingredientIds;
    final coveredNutrients = analysis.nutrientIds;

    final scores = <BodyPartScore>[];

    for (final part in db.allBodyParts) {
      final totalItems =
          part.relatedIngredients.length + part.relatedNutrients.length;

      if (totalItems == 0) {
        scores.add(BodyPartScore(
          partId: part.id,
          score: 0.5,
          coveredIngredientIds: [],
          missingIngredientIds: [],
          coveredNutrientIds: [],
          missingNutrientIds: [],
        ));
        continue;
      }

      final coveredIng = part.relatedIngredients
          .where((id) => coveredIngredients.contains(id))
          .toList();
      final missingIng = part.relatedIngredients
          .where((id) => !coveredIngredients.contains(id))
          .toList();
      final coveredNut = part.relatedNutrients
          .where((id) => coveredNutrients.contains(id))
          .toList();
      final missingNut = part.relatedNutrients
          .where((id) => !coveredNutrients.contains(id))
          .toList();

      final coveredCount = coveredIng.length + coveredNut.length;
      final score = coveredCount / totalItems;

      scores.add(BodyPartScore(
        partId: part.id,
        score: score.clamp(0.0, 1.0),
        coveredIngredientIds: coveredIng,
        missingIngredientIds: missingIng,
        coveredNutrientIds: coveredNut,
        missingNutrientIds: missingNut,
      ));
    }

    return scores;
  }
}
