class WaterEntry {
  final int? id;
  final String date;
  final int ml;

  const WaterEntry({this.id, required this.date, required this.ml});

  factory WaterEntry.fromMap(Map<String, dynamic> m) => WaterEntry(
        id: m['id'] as int?,
        date: m['date'] as String,
        ml: m['ml'] as int,
      );

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'date': date,
        'ml': ml,
      };
}
