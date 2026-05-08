class Food {
  final String id;
  final String name;
  final double kcal;
  final double protein;
  final double fat;
  final double carb;
  final double fiber;
  final double sodium;
  final double calcium;
  final double iron;

  const Food({
    required this.id,
    required this.name,
    required this.kcal,
    required this.protein,
    required this.fat,
    required this.carb,
    required this.fiber,
    required this.sodium,
    required this.calcium,
    required this.iron,
  });

  factory Food.fromJson(Map<String, dynamic> json) => Food(
        id: json['id'] as String,
        name: json['name'] as String,
        kcal: (json['kcal'] as num).toDouble(),
        protein: (json['protein'] as num).toDouble(),
        fat: (json['fat'] as num).toDouble(),
        carb: (json['carb'] as num).toDouble(),
        fiber: (json['fiber'] as num).toDouble(),
        sodium: (json['sodium'] as num).toDouble(),
        calcium: (json['calcium'] as num).toDouble(),
        iron: (json['iron'] as num).toDouble(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'kcal': kcal,
        'protein': protein,
        'fat': fat,
        'carb': carb,
        'fiber': fiber,
        'sodium': sodium,
        'calcium': calcium,
        'iron': iron,
      };

  Food scaled(double grams) {
    final r = grams / 100.0;
    return Food(
      id: id,
      name: name,
      kcal: kcal * r,
      protein: protein * r,
      fat: fat * r,
      carb: carb * r,
      fiber: fiber * r,
      sodium: sodium * r,
      calcium: calcium * r,
      iron: iron * r,
    );
  }
}
