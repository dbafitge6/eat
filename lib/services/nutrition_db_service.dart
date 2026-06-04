import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

// ─── Data Models ──────────────────────────────────────────────────────────────

class NutrientInfo {
  final String id;
  final String name;
  final String unit;
  final double dailyTarget;
  final String emoji;
  final List<String> bodyParts;

  const NutrientInfo({
    required this.id,
    required this.name,
    required this.unit,
    required this.dailyTarget,
    required this.emoji,
    required this.bodyParts,
  });

  factory NutrientInfo.fromJson(Map<String, dynamic> j) => NutrientInfo(
        id: j['id'] as String,
        name: j['name'] as String,
        unit: j['unit'] as String,
        dailyTarget: (j['daily_target'] as num).toDouble(),
        emoji: j['emoji'] as String,
        bodyParts: List<String>.from(j['body_parts'] as List),
      );
}

class FunctionalIngredientInfo {
  final String id;
  final String name;
  final String emoji;
  final String effect;
  final List<String> foods;
  final String synergy;
  final List<String> bodyParts;

  const FunctionalIngredientInfo({
    required this.id,
    required this.name,
    required this.emoji,
    required this.effect,
    required this.foods,
    required this.synergy,
    required this.bodyParts,
  });

  factory FunctionalIngredientInfo.fromJson(Map<String, dynamic> j) =>
      FunctionalIngredientInfo(
        id: j['id'] as String,
        name: j['name'] as String,
        emoji: j['emoji'] as String,
        effect: j['effect'] as String,
        foods: List<String>.from(j['foods'] as List),
        synergy: j['synergy'] as String,
        bodyParts: List<String>.from(j['body_parts'] as List),
      );
}

class FoodNutrientsEntry {
  final List<String> functionalIngredients;
  final List<String> nutrients;

  const FoodNutrientsEntry({
    required this.functionalIngredients,
    required this.nutrients,
  });

  factory FoodNutrientsEntry.fromJson(Map<String, dynamic> j) =>
      FoodNutrientsEntry(
        functionalIngredients:
            List<String>.from(j['functional_ingredients'] as List),
        nutrients: List<String>.from(j['nutrients'] as List),
      );
}

class BodyPartInfo {
  final String id;
  final String name;
  final String emoji;
  final List<String> relatedNutrients;
  final List<String> relatedIngredients;
  final String deficiencyMessage;
  final String sufficientMessage;
  final String tip;

  const BodyPartInfo({
    required this.id,
    required this.name,
    required this.emoji,
    required this.relatedNutrients,
    required this.relatedIngredients,
    required this.deficiencyMessage,
    required this.sufficientMessage,
    required this.tip,
  });

  factory BodyPartInfo.fromJson(Map<String, dynamic> j) => BodyPartInfo(
        id: j['id'] as String,
        name: j['name'] as String,
        emoji: j['emoji'] as String,
        relatedNutrients: List<String>.from(j['related_nutrients'] as List),
        relatedIngredients: List<String>.from(j['related_ingredients'] as List),
        deficiencyMessage: j['deficiency_message'] as String,
        sufficientMessage: j['sufficient_message'] as String,
        tip: j['tip'] as String,
      );
}

class SymptomInfo {
  final String id;
  final String name;
  final String emoji;
  final List<String> relatedIngredients;
  final String message;
  final List<String> foods;

  const SymptomInfo({
    required this.id,
    required this.name,
    required this.emoji,
    required this.relatedIngredients,
    required this.message,
    required this.foods,
  });

  factory SymptomInfo.fromJson(Map<String, dynamic> j) => SymptomInfo(
        id: j['id'] as String,
        name: j['name'] as String,
        emoji: j['emoji'] as String,
        relatedIngredients:
            List<String>.from(j['related_ingredients'] as List),
        message: j['message'] as String,
        foods: List<String>.from(j['foods'] as List),
      );
}

class CravingInfo {
  final List<String> foods;
  final String nutrient;
  final String emoji;
  final String message;

  const CravingInfo({
    required this.foods,
    required this.nutrient,
    required this.emoji,
    required this.message,
  });

  factory CravingInfo.fromJson(Map<String, dynamic> j) => CravingInfo(
        foods: List<String>.from(j['foods'] as List),
        nutrient: j['nutrient'] as String,
        emoji: j['emoji'] as String,
        message: j['message'] as String,
      );
}

// ─── Service ──────────────────────────────────────────────────────────────────

class NutritionDbService {
  static final NutritionDbService instance = NutritionDbService._();
  NutritionDbService._();

  Map<String, NutrientInfo> _nutrients = {};
  Map<String, FunctionalIngredientInfo> _functionalIngredients = {};
  Map<String, FoodNutrientsEntry> _foodNutrientsMap = {};
  Map<String, BodyPartInfo> _bodyParts = {};
  Map<String, SymptomInfo> _symptoms = {};
  Map<String, CravingInfo> _cravings = {};

  bool _loaded = false;

  Future<void> load() async {
    if (_loaded) return;
    try {
      await Future.wait([
        _loadNutrients(),
        _loadFunctionalIngredients(),
        _loadFoodNutrientsMap(),
        _loadBodyParts(),
        _loadSymptoms(),
        _loadCravings(),
      ]);
    } catch (e) {
      debugPrint('[NutritionDb] 初期化エラー（スキップ）: $e');
    }
    _loaded = true;
  }

  Future<void> _loadNutrients() async {
    final raw = await rootBundle.loadString('assets/databases/nutrients.json');
    final map = jsonDecode(raw) as Map<String, dynamic>;
    _nutrients = map.map(
      (k, v) => MapEntry(k, NutrientInfo.fromJson(v as Map<String, dynamic>)),
    );
  }

  Future<void> _loadFunctionalIngredients() async {
    final raw = await rootBundle
        .loadString('assets/databases/functional_ingredients.json');
    final map = jsonDecode(raw) as Map<String, dynamic>;
    _functionalIngredients = map.map(
      (k, v) => MapEntry(
          k, FunctionalIngredientInfo.fromJson(v as Map<String, dynamic>)),
    );
  }

  Future<void> _loadFoodNutrientsMap() async {
    final raw =
        await rootBundle.loadString('assets/databases/food_nutrients_map.json');
    final map = jsonDecode(raw) as Map<String, dynamic>;
    _foodNutrientsMap = map.map(
      (k, v) =>
          MapEntry(k, FoodNutrientsEntry.fromJson(v as Map<String, dynamic>)),
    );
  }

  Future<void> _loadBodyParts() async {
    final raw =
        await rootBundle.loadString('assets/databases/body_parts.json');
    final map = jsonDecode(raw) as Map<String, dynamic>;
    _bodyParts = map.map(
      (k, v) => MapEntry(k, BodyPartInfo.fromJson(v as Map<String, dynamic>)),
    );
  }

  Future<void> _loadSymptoms() async {
    final raw =
        await rootBundle.loadString('assets/databases/symptoms_map.json');
    final map = jsonDecode(raw) as Map<String, dynamic>;
    _symptoms = map.map(
      (k, v) => MapEntry(k, SymptomInfo.fromJson(v as Map<String, dynamic>)),
    );
  }

  Future<void> _loadCravings() async {
    final raw =
        await rootBundle.loadString('assets/databases/craving_map.json');
    final map = jsonDecode(raw) as Map<String, dynamic>;
    _cravings = map.map(
      (k, v) => MapEntry(k, CravingInfo.fromJson(v as Map<String, dynamic>)),
    );
  }

  // ─── Getters ──────────────────────────────────────────────────────────────

  Map<String, NutrientInfo> get nutrients => _nutrients;
  Map<String, FunctionalIngredientInfo> get functionalIngredients =>
      _functionalIngredients;
  Map<String, BodyPartInfo> get bodyParts => _bodyParts;
  Map<String, SymptomInfo> get symptoms => _symptoms;
  Map<String, CravingInfo> get cravings => _cravings;

  NutrientInfo? getNutrient(String id) => _nutrients[id];
  FunctionalIngredientInfo? getIngredient(String id) =>
      _functionalIngredients[id];
  BodyPartInfo? getBodyPart(String id) => _bodyParts[id];
  SymptomInfo? getSymptom(String id) => _symptoms[id];

  // ─── Lookup Methods ───────────────────────────────────────────────────────

  /// Returns ingredient IDs + nutrient IDs present in a food name
  FoodNutrientsEntry? lookupFood(String foodName) {
    // Exact match first
    if (_foodNutrientsMap.containsKey(foodName)) {
      return _foodNutrientsMap[foodName];
    }
    // Partial match
    for (final entry in _foodNutrientsMap.entries) {
      if (foodName.contains(entry.key) || entry.key.contains(foodName)) {
        return entry.value;
      }
    }
    return null;
  }

  /// Given a list of food names, compute which ingredient IDs and nutrient IDs
  /// are covered
  ({Set<String> ingredientIds, Set<String> nutrientIds}) analyzefoods(
      List<String> foodNames) {
    final ingredientIds = <String>{};
    final nutrientIds = <String>{};
    for (final name in foodNames) {
      final entry = lookupFood(name);
      if (entry != null) {
        ingredientIds.addAll(entry.functionalIngredients);
        nutrientIds.addAll(entry.nutrients);
      }
    }
    return (ingredientIds: ingredientIds, nutrientIds: nutrientIds);
  }

  /// Check if a food search query matches any craving pattern
  CravingInfo? matchCraving(String query) {
    final lower = query.toLowerCase();
    for (final craving in _cravings.values) {
      for (final food in craving.foods) {
        if (lower.contains(food) || food.contains(query)) {
          return craving;
        }
      }
    }
    return null;
  }

  List<SymptomInfo> get allSymptoms => _symptoms.values.toList();
  List<BodyPartInfo> get allBodyParts => _bodyParts.values.toList();
}
