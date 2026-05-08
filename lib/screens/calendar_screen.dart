import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import '../models/meal_entry.dart';
import '../models/calendar_event.dart';
import '../services/database_service.dart';
import '../models/user_profile.dart';
import '../utils/date_utils.dart' as du;

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime _focused = DateTime.now();
  DateTime _selected = DateTime.now();
  Map<String, double> _dailyKcal = {};
  List<CalendarEvent> _allEvents = [];
  List<MealEntry> _selectedMeals = [];
  List<CalendarEvent> _selectedEvents = [];
  UserProfile? _profile;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    final db = DatabaseService.instance;
    final profile = await db.getUserProfile();
    final allEvents = await db.getAllEvents();
    final now = DateTime.now();
    final start = now.subtract(const Duration(days: 90));
    final meals = await db.getMealsForWeek(
        du.formatDate(start), du.formatDate(now.add(const Duration(days: 60))));
    final kcalMap = <String, double>{};
    for (final m in meals) {
      kcalMap[m.date] = (kcalMap[m.date] ?? 0) + m.kcal;
    }
    if (!mounted) return;
    setState(() {
      _profile = profile;
      _allEvents = allEvents;
      _dailyKcal = kcalMap;
    });
    _loadSelected(_selected);
  }

  Future<void> _loadSelected(DateTime day) async {
    final dateStr = du.formatDate(day);
    final db = DatabaseService.instance;
    final meals = await db.getMealsForDate(dateStr);
    final events = await db.getEventsForDate(dateStr);
    if (!mounted) return;
    setState(() {
      _selected = day;
      _selectedMeals = meals;
      _selectedEvents = events;
    });
  }

  Color? _dayColor(DateTime day) {
    final dateStr = du.formatDate(day);
    final kcal = _dailyKcal[dateStr];
    final target = _profile?.targetKcal ?? 2000;
    if (kcal == null || kcal == 0) return null;
    if (kcal > target) return Colors.red;
    if (kcal > target * 0.9) return Colors.orange;
    return Colors.green;
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Scaffold(
      appBar: AppBar(title: const Text('カレンダー')),
      body: Column(
        children: [
          TableCalendar(
            firstDay: DateTime.now().subtract(const Duration(days: 365)),
            lastDay: DateTime.now().add(const Duration(days: 365)),
            focusedDay: _focused,
            selectedDayPredicate: (d) => isSameDay(d, _selected),
            onDaySelected: (selected, focused) {
              _focused = focused;
              _loadSelected(selected);
            },
            onPageChanged: (focused) => setState(() => _focused = focused),
            eventLoader: (day) {
              final dateStr = du.formatDate(day);
              return _allEvents.where((e) => e.date == dateStr).toList();
            },
            calendarBuilders: CalendarBuilders(
              markerBuilder: (ctx, day, events) {
                final color = _dayColor(day);
                return Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (color != null)
                      Container(
                        width: 6,
                        height: 6,
                        margin: const EdgeInsets.only(top: 1),
                        decoration: BoxDecoration(
                            color: color, shape: BoxShape.circle),
                      ),
                    if (events.isNotEmpty)
                      Container(
                        width: 6,
                        height: 6,
                        margin: const EdgeInsets.only(top: 1, left: 2),
                        decoration: const BoxDecoration(
                            color: Colors.blue, shape: BoxShape.circle),
                      ),
                  ],
                );
              },
            ),
            headerStyle: const HeaderStyle(formatButtonVisible: false),
            calendarStyle: CalendarStyle(
              selectedDecoration: BoxDecoration(
                color: primary,
                shape: BoxShape.circle,
              ),
              todayDecoration: BoxDecoration(
                color: primary.withOpacity(0.3),
                shape: BoxShape.circle,
              ),
            ),
          ),
          const Divider(),
          Expanded(
            child: _SelectedDayContent(
              day: _selected,
              meals: _selectedMeals,
              events: _selectedEvents,
              onAddEvent: _addEvent,
              onDeleteEvent: _deleteEvent,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _addEvent() async {
    final titleCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
            '${du.formatDate(_selected)} にイベント追加'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
                controller: titleCtrl,
                decoration: const InputDecoration(labelText: 'タイトル *')),
            TextField(
                controller: noteCtrl,
                decoration: const InputDecoration(labelText: 'メモ')),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('キャンセル')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('追加'),
          ),
        ],
      ),
    );
    if (result == true && titleCtrl.text.isNotEmpty) {
      await DatabaseService.instance.insertEvent(CalendarEvent(
        date: du.formatDate(_selected),
        title: titleCtrl.text,
        note: noteCtrl.text.isEmpty ? null : noteCtrl.text,
      ));
      await _loadAll();
    }
  }

  Future<void> _deleteEvent(int id) async {
    await DatabaseService.instance.deleteEvent(id);
    await _loadAll();
  }
}

class _SelectedDayContent extends StatelessWidget {
  final DateTime day;
  final List<MealEntry> meals;
  final List<CalendarEvent> events;
  final VoidCallback onAddEvent;
  final Future<void> Function(int) onDeleteEvent;

  const _SelectedDayContent({
    required this.day,
    required this.meals,
    required this.events,
    required this.onAddEvent,
    required this.onDeleteEvent,
  });

  @override
  Widget build(BuildContext context) {
    final totalKcal = meals.fold(0.0, (s, m) => s + m.kcal);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
                '${day.month}/${day.day}の記録',
                style: const TextStyle(fontWeight: FontWeight.bold)),
            TextButton.icon(
              onPressed: onAddEvent,
              icon: const Icon(Icons.event, size: 16),
              label: const Text('予定追加'),
            ),
          ],
        ),
        if (events.isNotEmpty) ...[
          const Text('予定', style: TextStyle(color: Colors.grey, fontSize: 12)),
          ...events.map((e) => ListTile(
                dense: true,
                leading: const Icon(Icons.event, color: Colors.blue),
                title: Text(e.title),
                subtitle: e.note != null ? Text(e.note!) : null,
                trailing: IconButton(
                  icon: const Icon(Icons.delete, size: 16),
                  onPressed: () => onDeleteEvent(e.id!),
                ),
              )),
          const Divider(),
        ],
        if (meals.isEmpty)
          const Text('食事記録なし', style: TextStyle(color: Colors.grey))
        else ...[
          Text('合計 ${totalKcal.round()} kcal',
              style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ...meals.map((m) => ListTile(
                dense: true,
                title: Text(m.foodName),
                subtitle: Text(MealEntry.mealNames[m.mealType]),
                trailing: Text('${m.kcal.round()} kcal'),
              )),
        ],
      ],
    );
  }
}
