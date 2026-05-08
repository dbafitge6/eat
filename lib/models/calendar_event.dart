class CalendarEvent {
  final int? id;
  final String date;
  final String title;
  final String? note;

  const CalendarEvent({
    this.id,
    required this.date,
    required this.title,
    this.note,
  });

  factory CalendarEvent.fromMap(Map<String, dynamic> m) => CalendarEvent(
        id: m['id'] as int?,
        date: m['date'] as String,
        title: m['title'] as String,
        note: m['note'] as String?,
      );

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'date': date,
        'title': title,
        'note': note,
      };
}
