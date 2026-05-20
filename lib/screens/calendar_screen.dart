import 'dart:io';
import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../models/meal_entry.dart';
import '../models/calendar_event.dart';
import '../models/day_photo.dart';
import '../services/database_service.dart';
import '../services/meal_photo_service.dart';
import '../models/user_profile.dart';
import '../models/meal_plan.dart';
import '../utils/date_utils.dart' as du;
import 'meal_plan_screen.dart';

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
  List<DayPhoto> _selectedPhotos = [];
  Map<int, File> _mealPhotos = {};
  List<MealPlan> _selectedMealPlans = [];
  UserProfile? _profile;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    final db = DatabaseService.instance;
    final now = DateTime.now();
    await db.deletePhotosBeforeMonth(now.year, now.month);
    final profile = await db.getUserProfile();
    final allEvents = await db.getAllEvents();
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
    final photos = await db.getPhotosForDate(dateStr);
    final mealPlans = await db.getMealPlansForDate(dateStr);
    final mealPhotos = <int, File>{};
    for (var i = 0; i < 6; i++) {
      final f = await MealPhotoService.getPhoto(dateStr, i);
      if (f != null) mealPhotos[i] = f;
    }
    if (!mounted) return;
    setState(() {
      _selected = day;
      _selectedMeals = meals;
      _selectedEvents = events;
      _selectedPhotos = photos;
      _selectedMealPlans = mealPlans;
      _mealPhotos = mealPhotos;
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
      appBar: AppBar(
        title: const Text('カレンダー'),
        actions: [
          IconButton(
            icon: const Icon(Icons.restaurant_menu),
            tooltip: '1週間献立',
            onPressed: () async {
              await Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const MealPlanScreen()));
              _loadSelected(_selected);
            },
          ),
        ],
      ),
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
              photos: _selectedPhotos,
              mealPhotos: _mealPhotos,
              mealPlans: _selectedMealPlans,
              onAddEvent: _addEvent,
              onDeleteEvent: _deleteEvent,
              onAddPhoto: _addPhoto,
              onDeletePhoto: _deletePhoto,
              onViewPhoto: _viewPhoto,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _addPhoto() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('カメラで撮影'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('ライブラリから選択'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;

    final picker = ImagePicker();
    final picked = await picker.pickImage(source: source, imageQuality: 80);
    if (picked == null || !mounted) return;

    final dir = await getApplicationDocumentsDirectory();
    final photoDir = Directory(p.join(dir.path, 'day_photos'));
    if (!await photoDir.exists()) await photoDir.create();
    final filename =
        '${du.formatDate(_selected)}_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final dest = p.join(photoDir.path, filename);
    await File(picked.path).copy(dest);

    await DatabaseService.instance.insertPhoto(
      DayPhoto(date: du.formatDate(_selected), path: dest),
    );
    await _loadSelected(_selected);
  }

  Future<void> _deletePhoto(int id) async {
    await DatabaseService.instance.deletePhoto(id);
    await _loadSelected(_selected);
  }

  void _viewPhoto(String path) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => _PhotoViewScreen(path: path),
    ));
  }

  Future<void> _addEvent() async {
    final result = await showDialog<_EventInput>(
      context: context,
      builder: (ctx) => const _AddEventDialog(),
    );
    if (result != null && result.title.isNotEmpty) {
      await DatabaseService.instance.insertEvent(CalendarEvent(
        date: du.formatDate(_selected),
        title: result.title,
        note: result.note.isEmpty ? null : result.note,
      ));
      await _loadAll();
    }
  }

  Future<void> _deleteEvent(int id) async {
    await DatabaseService.instance.deleteEvent(id);
    await _loadAll();
  }
}

class _EventInput {
  final String title;
  final String note;
  const _EventInput(this.title, this.note);
}

class _AddEventDialog extends StatefulWidget {
  const _AddEventDialog();

  @override
  State<_AddEventDialog> createState() => _AddEventDialogState();
}

class _AddEventDialogState extends State<_AddEventDialog> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _noteCtrl;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController();
    _noteCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('イベント追加'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
              controller: _titleCtrl,
              decoration: const InputDecoration(labelText: 'タイトル *')),
          TextField(
              controller: _noteCtrl,
              decoration: const InputDecoration(labelText: 'メモ')),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('キャンセル')),
        ElevatedButton(
          onPressed: () =>
              Navigator.pop(context, _EventInput(_titleCtrl.text, _noteCtrl.text)),
          child: const Text('追加'),
        ),
      ],
    );
  }
}

class _SelectedDayContent extends StatelessWidget {
  final DateTime day;
  final List<MealEntry> meals;
  final List<CalendarEvent> events;
  final List<DayPhoto> photos;
  final Map<int, File> mealPhotos;
  final List<MealPlan> mealPlans;
  final VoidCallback onAddEvent;
  final Future<void> Function(int) onDeleteEvent;
  final VoidCallback onAddPhoto;
  final Future<void> Function(int) onDeletePhoto;
  final void Function(String) onViewPhoto;

  const _SelectedDayContent({
    required this.day,
    required this.meals,
    required this.events,
    required this.photos,
    required this.mealPhotos,
    required this.mealPlans,
    required this.onAddEvent,
    required this.onDeleteEvent,
    required this.onAddPhoto,
    required this.onDeletePhoto,
    required this.onViewPhoto,
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
        // 写真セクション
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('写真', style: TextStyle(color: Colors.grey, fontSize: 12)),
            IconButton(
              icon: const Icon(Icons.add_a_photo, size: 20),
              onPressed: onAddPhoto,
              tooltip: '写真を追加',
            ),
          ],
        ),
        if (photos.isNotEmpty)
          SizedBox(
            height: 100,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: photos.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (ctx, i) {
                final photo = photos[i];
                return GestureDetector(
                  onTap: () => onViewPhoto(photo.path),
                  onLongPress: () => showDialog(
                    context: ctx,
                    builder: (_) => AlertDialog(
                      content: const Text('この写真を削除しますか？'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('キャンセル'),
                        ),
                        ElevatedButton(
                          onPressed: () {
                            Navigator.pop(ctx);
                            onDeletePhoto(photo.id!);
                          },
                          child: const Text('削除'),
                        ),
                      ],
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(
                      File(photo.path),
                      width: 100,
                      height: 100,
                      fit: BoxFit.cover,
                    ),
                  ),
                );
              },
            ),
          ),
        const Divider(),
        if (mealPlans.isNotEmpty) ...[
          const Text('AI献立', style: TextStyle(color: Colors.grey, fontSize: 12)),
          ...mealPlans.map((p) => Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.blueAccent.withValues(alpha: 0.4)),
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.blueAccent.withValues(alpha: 0.05),
                ),
                child: Row(
                  children: [
                    Text(MealPlan.mealIcons[p.mealType], style: const TextStyle(fontSize: 14)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${MealPlan.mealNames[p.mealType]}・${p.title}',
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                          Text(p.dishes.map((d) => d.name).join('・'),
                              style: const TextStyle(fontSize: 11, color: Colors.grey),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),
                    Text('${p.totalKcal.round()}kcal',
                        style: const TextStyle(fontSize: 11, color: Colors.blueAccent)),
                  ],
                ),
              )),
          const Divider(),
        ],
        if (meals.isEmpty && mealPhotos.isEmpty)
          const Text('食事記録なし', style: TextStyle(color: Colors.grey))
        else ...[
          Text('合計 ${totalKcal.round()} kcal',
              style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ...() {
            final grouped = <int, List<MealEntry>>{};
            for (final m in meals) {
              grouped.putIfAbsent(m.mealType, () => []).add(m);
            }
            // 写真だけあるmealTypeも含める
            for (final t in mealPhotos.keys) {
              grouped.putIfAbsent(t, () => []);
            }
            final sortedTypes = grouped.keys.toList()..sort();
            return sortedTypes.map((mealType) {
              final items = grouped[mealType]!;
              final photo = mealPhotos[mealType];
              final mealKcal = items.fold(0.0, (s, m) => s + m.kcal);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (photo != null)
                        GestureDetector(
                          onTap: () => onViewPhoto(photo.path),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.file(photo,
                                width: 72, height: 72, fit: BoxFit.cover),
                          ),
                        ),
                      if (photo != null) const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              MealEntry.mealNames[mealType],
                              style: const TextStyle(
                                  fontSize: 12, color: Colors.grey),
                            ),
                            Text('${mealKcal.round()} kcal',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold)),
                            ...items.map((m) => Text(
                                  '${m.foodName}  ${m.kcal.round()}kcal',
                                  style: const TextStyle(fontSize: 13),
                                )),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],
              );
            }).toList();
          }(),
        ],
      ],
    );
  }
}

class _PhotoViewScreen extends StatelessWidget {
  final String path;
  const _PhotoViewScreen({required this.path});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.black),
      body: Center(
        child: InteractiveViewer(
          child: Image.file(File(path)),
        ),
      ),
    );
  }
}
