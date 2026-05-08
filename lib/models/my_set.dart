class MySetItem {
  final String foodId;
  final String foodName;
  final double grams;
  final double kcal;
  final double protein;
  final double fat;
  final double carb;

  const MySetItem({
    required this.foodId,
    required this.foodName,
    required this.grams,
    required this.kcal,
    required this.protein,
    required this.fat,
    required this.carb,
  });

  Map<String, dynamic> toJson() => {
        'foodId': foodId,
        'foodName': foodName,
        'grams': grams,
        'kcal': kcal,
        'protein': protein,
        'fat': fat,
        'carb': carb,
      };

  factory MySetItem.fromJson(Map<String, dynamic> j) => MySetItem(
        foodId: j['foodId'] as String,
        foodName: j['foodName'] as String,
        grams: (j['grams'] as num).toDouble(),
        kcal: (j['kcal'] as num).toDouble(),
        protein: (j['protein'] as num).toDouble(),
        fat: (j['fat'] as num).toDouble(),
        carb: (j['carb'] as num).toDouble(),
      );
}

class MySet {
  final int? id;
  final String name;
  final List<MySetItem> items;

  const MySet({this.id, required this.name, required this.items});

  double get totalKcal => items.fold(0, (s, i) => s + i.kcal);
  double get totalProtein => items.fold(0, (s, i) => s + i.protein);
  double get totalFat => items.fold(0, (s, i) => s + i.fat);
  double get totalCarb => items.fold(0, (s, i) => s + i.carb);
}
