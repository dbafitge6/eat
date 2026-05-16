class ExerciseEntry {
  final int? id;
  final String date;
  final String name;
  final int type; // 0=有酸素, 1=筋トレ軽, 2=筋トレ中, 3=筋トレ強
  final int durationMin;
  final double kcalBurned;

  const ExerciseEntry({
    this.id,
    required this.date,
    required this.name,
    required this.type,
    required this.durationMin,
    required this.kcalBurned,
  });

  static const typeNames = ['有酸素', '筋トレ(軽)', '筋トレ(中)', '筋トレ(強)'];
  // MET × 体重 × 時間 の近似: met/min per kg (体重60kgで割って使う)
  static const typeMets = [7.0, 3.5, 5.0, 6.5];

  static double estimateKcal(int type, int durationMin, double weightKg) {
    final met = typeMets[type.clamp(0, 3)];
    return met * weightKg * (durationMin / 60);
  }

  factory ExerciseEntry.fromMap(Map<String, dynamic> m) => ExerciseEntry(
        id: m['id'] as int?,
        date: m['date'] as String,
        name: m['name'] as String,
        type: m['type'] as int,
        durationMin: m['duration_min'] as int,
        kcalBurned: (m['kcal_burned'] as num).toDouble(),
      );

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'date': date,
        'name': name,
        'type': type,
        'duration_min': durationMin,
        'kcal_burned': kcalBurned,
      };
}
