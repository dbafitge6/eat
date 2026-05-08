import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/food.dart';
import '../models/my_food.dart';
import 'database_service.dart';

class FoodSearchService {
  static final FoodSearchService _instance = FoodSearchService._();
  static FoodSearchService get instance => _instance;
  FoodSearchService._();

  List<Food> _builtinFoods = [];
  bool _loaded = false;

  Future<void> init() async {
    if (_loaded) return;
    final raw = await rootBundle.loadString('assets/food_db/foods.json');
    final list = jsonDecode(raw) as List;
    _builtinFoods = list.map((j) => Food.fromJson(j as Map<String, dynamic>)).toList();
    _loaded = true;
  }

  Future<List<Food>> search(String query) async {
    await init();
    if (query.trim().isEmpty) return [];
    final q = query.trim().toLowerCase();
    final results = _builtinFoods.where((f) {
      return f.name.toLowerCase().contains(q);
    }).toList();
    results.sort((a, b) {
      final aStarts = a.name.toLowerCase().startsWith(q);
      final bStarts = b.name.toLowerCase().startsWith(q);
      if (aStarts && !bStarts) return -1;
      if (!aStarts && bStarts) return 1;
      return a.name.compareTo(b.name);
    });
    return results.take(30).toList();
  }

  Future<List<MyFood>> searchMyFoods(String query) async {
    final all = await DatabaseService.instance.getMyFoods();
    if (query.trim().isEmpty) return all;
    final q = query.trim().toLowerCase();
    return all.where((f) => f.name.toLowerCase().contains(q)).toList();
  }

  Food? findById(String id) {
    try {
      return _builtinFoods.firstWhere((f) => f.id == id);
    } catch (_) {
      return null;
    }
  }
}
