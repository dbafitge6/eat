import 'dart:convert';
import 'package:flutter/services.dart';

class NutritionDbService {
  static final NutritionDbService instance = NutritionDbService._();
  NutritionDbService._();

  List<Map<String, dynamic>> _nutrients = [];
  List<Map<String, dynamic>> _functionalIngredients = [];
  List<Map<String, dynamic>> _foodMap = [];
  List<Map<String, dynamic>> _bodyParts = [];
  List<Map<String, dynamic>> _symptoms = [];
  List<Map<String, dynamic>> _cravings = [];
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    try {
      final nJson = await rootBundle.loadString('assets/food_db/nutrients.json');
      _nutrients = List<Map<String, dynamic>>.from(
          (jsonDecode(nJson) as Map)['nutrients'] as List);

      final fiJson = await rootBundle.loadString('assets/food_db/functional_ingredients.json');
      _functionalIngredients = List<Map<String, dynamic>>.from(
          (jsonDecode(fiJson) as Map)['functional_ingredients'] as List);

      final fmJson = await rootBundle.loadString('assets/food_db/food_nutrients_map.json');
      _foodMap = List<Map<String, dynamic>>.from(
          (jsonDecode(fmJson) as Map)['food_map'] as List);

      final bpJson = await rootBundle.loadString('assets/food_db/body_parts.json');
      _bodyParts = List<Map<String, dynamic>>.from(
          (jsonDecode(bpJson) as Map)['body_parts'] as List);

      final sJson = await rootBundle.loadString('assets/food_db/symptoms_map.json');
      _symptoms = List<Map<String, dynamic>>.from(
          (jsonDecode(sJson) as Map)['symptoms'] as List);

      final cJson = await rootBundle.loadString('assets/food_db/craving_map.json');
      _cravings = List<Map<String, dynamic>>.from(
          (jsonDecode(cJson) as Map)['cravings'] as List);

      _initialized = true;
    } catch (e) {
      // DBロード失敗時も動作継続
    }
  }

  bool get isReady => _initialized;
  List<Map<String, dynamic>> get nutrients => _nutrients;
  List<Map<String, dynamic>> get functionalIngredients => _functionalIngredients;
  List<Map<String, dynamic>> get bodyParts => _bodyParts;
  List<Map<String, dynamic>> get symptoms => _symptoms;
  List<Map<String, dynamic>> get cravings => _cravings;

  // 食材名から機能性成分IDリストを取得
  List<String> getFunctionalIngredientsByFood(String foodName) {
    for (final item in _foodMap) {
      final name = (item['food_name'] as String? ?? '');
      if (foodName.contains(name) || name.contains(foodName)) {
        return List<String>.from(item['functional_ingredients'] as List? ?? []);
      }
    }
    return [];
  }

  // 食材名のリストから摂取した機能性成分IDのセットを返す
  Set<String> getObtainedFunctionalIngredients(List<String> foodNames) {
    final result = <String>{};
    for (final food in foodNames) {
      result.addAll(getFunctionalIngredientsByFood(food));
    }
    return result;
  }

  Map<String, dynamic>? getNutrientById(String id) {
    try {
      return _nutrients.firstWhere((n) => n['id'] == id);
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic>? getFunctionalIngredientById(String id) {
    try {
      return _functionalIngredients.firstWhere((f) => f['id'] == id);
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic>? getBodyPartById(String id) {
    try {
      return _bodyParts.firstWhere((b) => b['id'] == id);
    } catch (_) {
      return null;
    }
  }

  List<Map<String, dynamic>> getSymptomsByTags(List<String> tags) {
    if (tags.isEmpty) return _symptoms;
    return _symptoms.where((s) {
      final sTags = List<String>.from(s['tags'] as List? ?? []);
      return tags.any((t) => sTags.contains(t));
    }).toList();
  }

  // 食欲から体の声を返す
  Map<String, dynamic>? getCravingByFoodName(String foodName) {
    final lower = foodName;
    for (final c in _cravings) {
      final food = c['food'] as String? ?? '';
      if (lower.contains(food) || food.contains(lower)) {
        return c;
      }
    }
    return null;
  }

  // 栄養素IDが機能性成分かどうか判定
  bool isFunctionalIngredient(String id) {
    return _functionalIngredients.any((f) => f['id'] == id);
  }

  // 今日の食事から取得できていない機能性成分を返す
  List<Map<String, dynamic>> getMissingFunctionalIngredients(Set<String> obtained) {
    return _functionalIngredients
        .where((f) => !obtained.contains(f['id'] as String))
        .toList();
  }
}
