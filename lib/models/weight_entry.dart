class WeightEntry {
  final int? id;
  final String date;
  final double weight;
  final double? bmi;

  const WeightEntry({
    this.id,
    required this.date,
    required this.weight,
    this.bmi,
  });

  factory WeightEntry.fromMap(Map<String, dynamic> m) => WeightEntry(
        id: m['id'] as int?,
        date: m['date'] as String,
        weight: (m['weight'] as num).toDouble(),
        bmi: m['bmi'] != null ? (m['bmi'] as num).toDouble() : null,
      );

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'date': date,
        'weight': weight,
        'bmi': bmi,
      };
}
