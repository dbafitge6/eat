class MyFood {
  final int? id;
  final String name;
  final double kcalPer100g;
  final double proteinPer100g;
  final double fatPer100g;
  final double carbPer100g;
  final double fiberPer100g;
  final double sodiumPer100g;
  final double calciumPer100g;
  final double ironPer100g;
  final String? note;

  const MyFood({
    this.id,
    required this.name,
    required this.kcalPer100g,
    required this.proteinPer100g,
    required this.fatPer100g,
    required this.carbPer100g,
    required this.fiberPer100g,
    required this.sodiumPer100g,
    required this.calciumPer100g,
    required this.ironPer100g,
    this.note,
  });

  factory MyFood.fromMap(Map<String, dynamic> m) => MyFood(
        id: m['id'] as int?,
        name: m['name'] as String,
        kcalPer100g: (m['kcal_per100g'] as num).toDouble(),
        proteinPer100g: (m['protein_per100g'] as num).toDouble(),
        fatPer100g: (m['fat_per100g'] as num).toDouble(),
        carbPer100g: (m['carb_per100g'] as num).toDouble(),
        fiberPer100g: (m['fiber_per100g'] as num).toDouble(),
        sodiumPer100g: (m['sodium_per100g'] as num).toDouble(),
        calciumPer100g: (m['calcium_per100g'] as num).toDouble(),
        ironPer100g: (m['iron_per100g'] as num).toDouble(),
        note: m['note'] as String?,
      );

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'name': name,
        'kcal_per100g': kcalPer100g,
        'protein_per100g': proteinPer100g,
        'fat_per100g': fatPer100g,
        'carb_per100g': carbPer100g,
        'fiber_per100g': fiberPer100g,
        'sodium_per100g': sodiumPer100g,
        'calcium_per100g': calciumPer100g,
        'iron_per100g': ironPer100g,
        'note': note,
      };
}
