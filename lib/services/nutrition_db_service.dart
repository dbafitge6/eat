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

// ─── foods_all.json モデル ────────────────────────────────────────────────────

class FoodEntry {
  final String id;
  final String name;
  final String category;
  final bool isReferenceValue;
  final double calories;
  final double proteinG;
  final double fatG;
  final double carbsG;
  final double fiberG;
  final List<String> functionalIngredientIds;
  final Map<String, double> bodyPartsEffects; // partId → score_contribution
  final List<String> combinationTips;
  final bool hasCravingSignal;
  final String? cravingMessage;
  final List<String> tags;
  final List<String> cookingTips;

  const FoodEntry({
    required this.id,
    required this.name,
    required this.category,
    required this.isReferenceValue,
    required this.calories,
    required this.proteinG,
    required this.fatG,
    required this.carbsG,
    required this.fiberG,
    required this.functionalIngredientIds,
    required this.bodyPartsEffects,
    required this.combinationTips,
    required this.hasCravingSignal,
    this.cravingMessage,
    required this.tags,
    required this.cookingTips,
  });

  factory FoodEntry.fromJson(Map<String, dynamic> j) {
    final per = j['per_100g'] as Map<String, dynamic>? ?? {};
    final funcList = (j['functional_ingredients'] as List? ?? [])
        .map((f) => (f as Map<String, dynamic>)['id']?.toString() ?? '')
        .where((s) => s.isNotEmpty)
        .toList();
    final effects = <String, double>{};
    final bpe = j['body_parts_effects'] as Map<String, dynamic>? ?? {};
    for (final e in bpe.entries) {
      final v = (e.value as Map<String, dynamic>?)?['score_contribution'];
      if (v != null) effects[e.key] = (v as num).toDouble();
    }
    final tips = (j['combination_tips'] as List? ?? [])
        .map((t) {
          final m = t as Map<String, dynamic>;
          final partner = m['partner_food_example']?.toString() ?? '';
          final effect = m['effect']?.toString() ?? '';
          return '$partner：$effect';
        })
        .toList();
    final craving = j['craving_signal'] as Map<String, dynamic>?;
    return FoodEntry(
      id: j['id']?.toString() ?? '',
      name: j['name']?.toString() ?? '',
      category: j['category']?.toString() ?? '',
      isReferenceValue: j['is_reference_value'] as bool? ?? false,
      calories: (per['calories'] as num? ?? 0).toDouble(),
      proteinG: (per['protein_g'] as num? ?? 0).toDouble(),
      fatG: (per['fat_g'] as num? ?? 0).toDouble(),
      carbsG: (per['carbs_g'] as num? ?? 0).toDouble(),
      fiberG: (per['fiber_g'] as num? ?? 0).toDouble(),
      functionalIngredientIds: funcList,
      bodyPartsEffects: effects,
      combinationTips: tips,
      hasCravingSignal: craving?['has_signal'] as bool? ?? false,
      cravingMessage: craving?['message']?.toString(),
      tags: List<String>.from(j['tags'] as List? ?? []),
      cookingTips: List<String>.from(j['cooking_tips'] as List? ?? []),
    );
  }
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
  Map<String, FoodEntry> _foodsAll = {};

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
        _loadFoodsAll(),
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

  Future<void> _loadFoodsAll() async {
    try {
      final raw = await rootBundle.loadString('assets/databases/foods_all.json');
      final data = jsonDecode(raw) as Map<String, dynamic>;
      final list = data['foods'] as List? ?? [];
      for (final item in list) {
        final entry = FoodEntry.fromJson(item as Map<String, dynamic>);
        if (entry.name.isNotEmpty) _foodsAll[entry.name] = entry;
      }
    } catch (e) {
      debugPrint('[NutritionDb] foods_all.json 読み込みエラー: $e');
    }
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

  /// foods_all.jsonから食材エントリを検索（ファジーマッチ）
  FoodEntry? lookupFoodEntry(String foodName) {
    // 完全一致
    if (_foodsAll.containsKey(foodName)) return _foodsAll[foodName];
    // 部分一致（どちらかが含む）
    for (final entry in _foodsAll.entries) {
      if (foodName.contains(entry.key) || entry.key.contains(foodName)) {
        return entry.value;
      }
    }
    // キーワードマッチ（文科省DB形式 "鶏肉 むね 皮なし 生" → "鶏むね肉" 等）
    final queryTokens = _tokenize(foodName);
    FoodEntry? bestMatch;
    int bestScore = 0;
    for (final entry in _foodsAll.entries) {
      final keyTokens = _tokenize(entry.key);
      int score = 0;
      for (final t in queryTokens) {
        if (keyTokens.any((k) => k.contains(t) || t.contains(k))) score++;
      }
      if (score >= 2 && score > bestScore) {
        bestScore = score;
        bestMatch = entry.value;
      }
    }
    return bestMatch;
  }

  /// 食材名をトークン（意味のある2文字以上の部分）に分割
  List<String> _tokenize(String name) {
    // スペース・記号で分割し2文字以上を返す
    final parts = name.split(RegExp(r'[\s　・（）\(\)/]'))
        .where((s) => s.length >= 2)
        .toList();
    if (parts.isEmpty) return [name];
    return parts;
  }

  /// Returns ingredient IDs + nutrient IDs present in a food name
  FoodNutrientsEntry? lookupFood(String foodName) {
    if (_foodNutrientsMap.containsKey(foodName)) {
      return _foodNutrientsMap[foodName];
    }
    for (final entry in _foodNutrientsMap.entries) {
      if (foodName.contains(entry.key) || entry.key.contains(foodName)) {
        return entry.value;
      }
    }
    // foods_all.jsonからもフォールバック検索
    final fe = lookupFoodEntry(foodName);
    if (fe != null) {
      return FoodNutrientsEntry(
        functionalIngredients: fe.functionalIngredientIds,
        nutrients: [],
      );
    }
    return null;
  }

  /// foods_all.jsonのbody_parts_effectsからスコアを取得
  double getBodyEffect(String foodName, String partId) {
    final entry = lookupFoodEntry(foodName);
    return entry?.bodyPartsEffects[partId] ?? 0.0;
  }

  /// 食材リストの体の部位スコアをfoods_all.jsonベースで集計
  Map<String, double> getBodyEffectScores(List<String> foodNames) {
    final scores = <String, double>{};
    for (final name in foodNames) {
      final entry = lookupFoodEntry(name);
      if (entry == null) continue;
      for (final e in entry.bodyPartsEffects.entries) {
        scores[e.key] = (scores[e.key] ?? 0.0) + e.value;
      }
    }
    // 0.0〜1.0にクランプ
    return scores.map((k, v) => MapEntry(k, v.clamp(0.0, 1.0)));
  }

  /// 今日食べた食材の調理Tipsを収集
  List<String> getCookingTips(List<String> foodNames) {
    final tips = <String>[];
    for (final name in foodNames) {
      final entry = lookupFoodEntry(name);
      if (entry != null) tips.addAll(entry.cookingTips);
    }
    return tips;
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
