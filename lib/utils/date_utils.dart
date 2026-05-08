String formatDate(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

DateTime parseDate(String s) => DateTime.parse(s);

String todayString() => formatDate(DateTime.now());

List<String> weekDates(DateTime anchor) {
  final monday = anchor.subtract(Duration(days: anchor.weekday - 1));
  return List.generate(7, (i) => formatDate(monday.add(Duration(days: i))));
}

String weekRangeLabel(DateTime anchor) {
  final dates = weekDates(anchor);
  return '${dates.first} 〜 ${dates.last}';
}
