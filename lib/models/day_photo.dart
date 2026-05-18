class DayPhoto {
  final int? id;
  final String date;
  final String path;

  const DayPhoto({this.id, required this.date, required this.path});

  Map<String, dynamic> toMap() => {'date': date, 'path': path};

  static DayPhoto fromMap(Map<String, dynamic> m) => DayPhoto(
        id: m['id'] as int?,
        date: m['date'] as String,
        path: m['path'] as String,
      );
}
