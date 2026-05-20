import 'dart:convert';

class MealPlanDish {
  final String name;
  final double grams;
  final double kcal;
  final double protein;
  final double fat;
  final double carb;

  const MealPlanDish({
    required this.name,
    required this.grams,
    required this.kcal,
    required this.protein,
    required this.fat,
    required this.carb,
  });

  factory MealPlanDish.fromJson(Map<String, dynamic> j) => MealPlanDish(
        name: j['name']?.toString() ?? '',
        grams: _d(j['grams']),
        kcal: _d(j['kcal']),
        protein: _d(j['protein']),
        fat: _d(j['fat']),
        carb: _d(j['carb']),
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'grams': grams,
        'kcal': kcal,
        'protein': protein,
        'fat': fat,
        'carb': carb,
      };

  static double _d(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0;
  }
}

class MealPlan {
  final int? id;
  final String weekStart;
  final String date;
  final int mealType; // 0=朝 1=昼 2=夕
  final String title;
  final List<MealPlanDish> dishes;

  static const mealNames = ['朝食', '昼食', '夕食'];
  static const mealIcons = ['🌅', '☀', '🌙'];

  const MealPlan({
    this.id,
    required this.weekStart,
    required this.date,
    required this.mealType,
    required this.title,
    required this.dishes,
  });

  double get totalKcal => dishes.fold(0.0, (s, d) => s + d.kcal);

  Map<String, dynamic> toMap() => {
        'week_start': weekStart,
        'date': date,
        'meal_type': mealType,
        'title': title,
        'dishes_json': jsonEncode(dishes.map((d) => d.toJson()).toList()),
      };

  static MealPlan fromMap(Map<String, dynamic> m) => MealPlan(
        id: m['id'] as int?,
        weekStart: m['week_start'] as String,
        date: m['date'] as String,
        mealType: m['meal_type'] as int,
        title: m['title'] as String,
        dishes: (jsonDecode(m['dishes_json'] as String) as List)
            .map((d) => MealPlanDish.fromJson(d as Map<String, dynamic>))
            .toList(),
      );
}
