class MealEntry {
  final int? id;
  final String date;
  final int mealType; // 0=朝 1=昼 2=夕 3-5=間食
  final String foodId;
  final String foodName;
  final double grams;
  final double kcal;
  final double protein;
  final double fat;
  final double carb;
  final double fiber;
  final double sodium;
  final double calcium;
  final double iron;
  final bool isCustom;

  const MealEntry({
    this.id,
    required this.date,
    required this.mealType,
    required this.foodId,
    required this.foodName,
    required this.grams,
    required this.kcal,
    required this.protein,
    required this.fat,
    required this.carb,
    required this.fiber,
    required this.sodium,
    required this.calcium,
    required this.iron,
    this.isCustom = false,
  });

  factory MealEntry.fromMap(Map<String, dynamic> m) => MealEntry(
        id: m['id'] as int?,
        date: m['date'] as String,
        mealType: m['meal_type'] as int,
        foodId: m['food_id'] as String,
        foodName: m['food_name'] as String,
        grams: (m['grams'] as num).toDouble(),
        kcal: (m['kcal'] as num).toDouble(),
        protein: (m['protein'] as num).toDouble(),
        fat: (m['fat'] as num).toDouble(),
        carb: (m['carb'] as num).toDouble(),
        fiber: (m['fiber'] as num).toDouble(),
        sodium: (m['sodium'] as num).toDouble(),
        calcium: (m['calcium'] as num).toDouble(),
        iron: (m['iron'] as num).toDouble(),
        isCustom: (m['is_custom'] as int) == 1,
      );

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'date': date,
        'meal_type': mealType,
        'food_id': foodId,
        'food_name': foodName,
        'grams': grams,
        'kcal': kcal,
        'protein': protein,
        'fat': fat,
        'carb': carb,
        'fiber': fiber,
        'sodium': sodium,
        'calcium': calcium,
        'iron': iron,
        'is_custom': isCustom ? 1 : 0,
      };

  static const mealNames = ['朝食', '昼食', '夕食', '間食①', '間食②', '夜食'];
}
