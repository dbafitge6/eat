import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/meal_entry.dart';
import '../models/weight_entry.dart';
import '../models/water_entry.dart';
import '../models/my_food.dart';
import '../models/my_set.dart';
import '../models/user_profile.dart';
import '../models/calendar_event.dart';
import '../models/exercise_entry.dart';
import '../models/day_photo.dart';
import 'dart:convert';
import 'dart:io';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._();
  static DatabaseService get instance => _instance;
  DatabaseService._();

  Database? _db;

  Future<Database> get db async {
    _db ??= await _open();
    return _db!;
  }

  Future<Database> _open() async {
    final path = join(await getDatabasesPath(), 'eat.db');
    return openDatabase(
      path,
      version: 5,
      onUpgrade: (db, oldV, newV) async {
        if (oldV < 2) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS exercise_entries (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              date TEXT NOT NULL,
              name TEXT NOT NULL,
              type INTEGER NOT NULL,
              duration_min INTEGER NOT NULL,
              kcal_burned REAL NOT NULL
            )
          ''');
        }
        if (oldV < 4) {
          // user_profile に diet_intensity が無いケース（v3 onCreate のバグで欠落していた）を補修
          final cols = await db.rawQuery('PRAGMA table_info(user_profile)');
          final hasDietIntensity = cols.any((c) => c['name'] == 'diet_intensity');
          if (!hasDietIntensity) {
            await db.execute(
              'ALTER TABLE user_profile ADD COLUMN diet_intensity INTEGER NOT NULL DEFAULT 1',
            );
          }
        }
        if (oldV < 5) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS day_photos (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              date TEXT NOT NULL,
              path TEXT NOT NULL
            )
          ''');
        }
      },
      onCreate: (db, v) async {
        await db.execute('''
          CREATE TABLE meal_entries (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            date TEXT NOT NULL,
            meal_type INTEGER NOT NULL,
            food_id TEXT NOT NULL,
            food_name TEXT NOT NULL,
            grams REAL NOT NULL,
            kcal REAL NOT NULL,
            protein REAL NOT NULL,
            fat REAL NOT NULL,
            carb REAL NOT NULL,
            fiber REAL NOT NULL,
            sodium REAL NOT NULL,
            calcium REAL NOT NULL,
            iron REAL NOT NULL,
            is_custom INTEGER NOT NULL DEFAULT 0
          )
        ''');
        await db.execute('''
          CREATE TABLE weight_entries (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            date TEXT NOT NULL UNIQUE,
            weight REAL NOT NULL,
            bmi REAL
          )
        ''');
        await db.execute('''
          CREATE TABLE water_entries (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            date TEXT NOT NULL,
            ml INTEGER NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE my_foods (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            kcal_per100g REAL NOT NULL,
            protein_per100g REAL NOT NULL,
            fat_per100g REAL NOT NULL,
            carb_per100g REAL NOT NULL,
            fiber_per100g REAL NOT NULL,
            sodium_per100g REAL NOT NULL,
            calcium_per100g REAL NOT NULL,
            iron_per100g REAL NOT NULL,
            note TEXT
          )
        ''');
        await db.execute('''
          CREATE TABLE my_sets (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            items_json TEXT NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE user_profile (
            id INTEGER PRIMARY KEY DEFAULT 1,
            height_cm REAL NOT NULL,
            weight_kg REAL NOT NULL,
            age INTEGER NOT NULL,
            sex INTEGER NOT NULL,
            activity_level INTEGER NOT NULL,
            goal INTEGER NOT NULL,
            diet_intensity INTEGER NOT NULL DEFAULT 1,
            target_kcal REAL NOT NULL,
            target_water_ml REAL NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE calendar_events (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            date TEXT NOT NULL,
            title TEXT NOT NULL,
            note TEXT
          )
        ''');
        await db.execute('''
          CREATE TABLE exercise_entries (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            date TEXT NOT NULL,
            name TEXT NOT NULL,
            type INTEGER NOT NULL,
            duration_min INTEGER NOT NULL,
            kcal_burned REAL NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE day_photos (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            date TEXT NOT NULL,
            path TEXT NOT NULL
          )
        ''');
      },
    );
  }

  // ─── Meal ───────────────────────────────────────────────────────────────────

  Future<List<MealEntry>> getMealsForDate(String date) async {
    final d = await db;
    final rows = await d.query('meal_entries',
        where: 'date = ?', whereArgs: [date], orderBy: 'meal_type, id');
    return rows.map(MealEntry.fromMap).toList();
  }

  Future<List<MealEntry>> getMealsForWeek(String startDate, String endDate) async {
    final d = await db;
    final rows = await d.query('meal_entries',
        where: 'date >= ? AND date <= ?',
        whereArgs: [startDate, endDate],
        orderBy: 'date, meal_type');
    return rows.map(MealEntry.fromMap).toList();
  }

  Future<int> insertMeal(MealEntry entry) async {
    final d = await db;
    return d.insert('meal_entries', entry.toMap());
  }

  Future<void> updateMeal(MealEntry entry) async {
    final d = await db;
    await d.update('meal_entries', entry.toMap(),
        where: 'id = ?', whereArgs: [entry.id]);
  }

  Future<void> deleteMeal(int id) async {
    final d = await db;
    await d.delete('meal_entries', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteOldMeals() async {
    final d = await db;
    final cutoff = DateTime.now().subtract(const Duration(days: 90));
    final cutoffStr =
        '${cutoff.year}-${cutoff.month.toString().padLeft(2, '0')}-${cutoff.day.toString().padLeft(2, '0')}';
    await d.delete('meal_entries', where: 'date < ?', whereArgs: [cutoffStr]);
  }

  // ─── Weight ─────────────────────────────────────────────────────────────────

  Future<List<WeightEntry>> getWeights({int limit = 90}) async {
    final d = await db;
    final rows = await d.query('weight_entries',
        orderBy: 'date DESC', limit: limit);
    return rows.map(WeightEntry.fromMap).toList();
  }

  Future<WeightEntry?> getWeightForDate(String date) async {
    final d = await db;
    final rows = await d.query('weight_entries',
        where: 'date = ?', whereArgs: [date]);
    if (rows.isEmpty) return null;
    return WeightEntry.fromMap(rows.first);
  }

  Future<void> upsertWeight(WeightEntry entry) async {
    final d = await db;
    await d.insert('weight_entries', entry.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  // ─── Water ──────────────────────────────────────────────────────────────────

  Future<int> getTotalWaterForDate(String date) async {
    final d = await db;
    final rows = await d.rawQuery(
        'SELECT SUM(ml) as total FROM water_entries WHERE date = ?', [date]);
    return (rows.first['total'] as int?) ?? 0;
  }

  Future<void> addWater(WaterEntry entry) async {
    final d = await db;
    await d.insert('water_entries', entry.toMap());
  }

  Future<void> deleteWaterForDate(String date) async {
    final d = await db;
    await d.delete('water_entries', where: 'date = ?', whereArgs: [date]);
  }

  // ─── MyFood ─────────────────────────────────────────────────────────────────

  Future<List<MyFood>> getMyFoods() async {
    final d = await db;
    final rows = await d.query('my_foods', orderBy: 'name');
    return rows.map(MyFood.fromMap).toList();
  }

  Future<int> insertMyFood(MyFood food) async {
    final d = await db;
    return d.insert('my_foods', food.toMap());
  }

  Future<void> deleteMyFood(int id) async {
    final d = await db;
    await d.delete('my_foods', where: 'id = ?', whereArgs: [id]);
  }

  // ─── MySet ──────────────────────────────────────────────────────────────────

  Future<List<MySet>> getMySets() async {
    final d = await db;
    final rows = await d.query('my_sets', orderBy: 'name');
    return rows.map((r) {
      final items = (jsonDecode(r['items_json'] as String) as List)
          .map((i) => MySetItem.fromJson(i as Map<String, dynamic>))
          .toList();
      return MySet(id: r['id'] as int, name: r['name'] as String, items: items);
    }).toList();
  }

  Future<int> insertMySet(MySet set) async {
    final d = await db;
    return d.insert('my_sets', {
      'name': set.name,
      'items_json': jsonEncode(set.items.map((i) => i.toJson()).toList()),
    });
  }

  Future<void> deleteMySet(int id) async {
    final d = await db;
    await d.delete('my_sets', where: 'id = ?', whereArgs: [id]);
  }

  // ─── UserProfile ────────────────────────────────────────────────────────────

  Future<UserProfile?> getUserProfile() async {
    final d = await db;
    final rows = await d.query('user_profile');
    if (rows.isEmpty) return null;
    return UserProfile.fromMap(rows.first);
  }

  Future<void> saveUserProfile(UserProfile profile) async {
    final d = await db;
    final map = profile.toMap();
    map['id'] = 1;
    await d.insert('user_profile', map,
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  // ─── CalendarEvents ─────────────────────────────────────────────────────────

  Future<List<CalendarEvent>> getEventsForDate(String date) async {
    final d = await db;
    final rows = await d.query('calendar_events',
        where: 'date = ?', whereArgs: [date]);
    return rows.map(CalendarEvent.fromMap).toList();
  }

  Future<List<CalendarEvent>> getAllEvents() async {
    final d = await db;
    final rows = await d.query('calendar_events', orderBy: 'date');
    return rows.map(CalendarEvent.fromMap).toList();
  }

  Future<int> insertEvent(CalendarEvent event) async {
    final d = await db;
    return d.insert('calendar_events', event.toMap());
  }

  Future<void> deleteEvent(int id) async {
    final d = await db;
    await d.delete('calendar_events', where: 'id = ?', whereArgs: [id]);
  }

  // ─── Exercise ────────────────────────────────────────────────────────────────

  Future<List<ExerciseEntry>> getExercisesForDate(String date) async {
    final d = await db;
    final rows = await d.query('exercise_entries',
        where: 'date = ?', whereArgs: [date], orderBy: 'id');
    return rows.map(ExerciseEntry.fromMap).toList();
  }

  Future<int> insertExercise(ExerciseEntry entry) async {
    final d = await db;
    return d.insert('exercise_entries', entry.toMap());
  }

  Future<void> deleteExercise(int id) async {
    final d = await db;
    await d.delete('exercise_entries', where: 'id = ?', whereArgs: [id]);
  }

  Future<double> getTotalExerciseKcalForDate(String date) async {
    final d = await db;
    final rows = await d.query('exercise_entries',
        columns: ['SUM(kcal_burned) as total'],
        where: 'date = ?', whereArgs: [date]);
    return (rows.first['total'] as num?)?.toDouble() ?? 0.0;
  }

  // ─── Streak ──────────────────────────────────────────────────────────────────

  Future<int> getStreak() async {
    final d = await db;
    final rows = await d.rawQuery(
        'SELECT DISTINCT date FROM meal_entries ORDER BY date DESC');
    if (rows.isEmpty) return 0;

    final dates = rows.map((r) => r['date'] as String).toSet();
    final today = DateTime.now();
    String _fmt(DateTime dt) =>
        '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';

    DateTime start = today;
    if (!dates.contains(_fmt(today))) {
      final yesterday = today.subtract(const Duration(days: 1));
      if (!dates.contains(_fmt(yesterday))) return 0;
      start = yesterday;
    }

    int streak = 0;
    for (int i = 0; i < 365; i++) {
      final check = start.subtract(Duration(days: i));
      if (dates.contains(_fmt(check))) {
        streak++;
      } else {
        break;
      }
    }
    return streak;
  }

  // ─── DayPhotos ───────────────────────────────────────────────────────────────

  Future<List<DayPhoto>> getPhotosForDate(String date) async {
    final d = await db;
    final rows = await d.query('day_photos',
        where: 'date = ?', whereArgs: [date], orderBy: 'id');
    return rows.map(DayPhoto.fromMap).toList();
  }

  Future<int> insertPhoto(DayPhoto photo) async {
    final d = await db;
    return d.insert('day_photos', photo.toMap());
  }

  Future<void> deletePhoto(int id) async {
    final d = await db;
    final rows =
        await d.query('day_photos', where: 'id = ?', whereArgs: [id]);
    if (rows.isNotEmpty) {
      final file = File(rows.first['path'] as String);
      if (await file.exists()) await file.delete();
    }
    await d.delete('day_photos', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deletePhotosBeforeMonth(int year, int month) async {
    final cutoff =
        '$year-${month.toString().padLeft(2, '0')}-01';
    final d = await db;
    final rows = await d.query('day_photos',
        where: 'date < ?', whereArgs: [cutoff]);
    for (final row in rows) {
      final file = File(row['path'] as String);
      if (await file.exists()) await file.delete();
    }
    await d.delete('day_photos', where: 'date < ?', whereArgs: [cutoff]);
  }

  // ─── CSV Export ─────────────────────────────────────────────────────────────

  Future<String> exportMealsCsv() async {
    final d = await db;
    final rows = await d.query('meal_entries', orderBy: 'date, meal_type');
    final buf = StringBuffer();
    buf.writeln('日付,食事,食品名,量(g),エネルギー(kcal),たんぱく質(g),脂質(g),炭水化物(g),食物繊維(g)');
    for (final r in rows) {
      final mealName = MealEntry.mealNames[r['meal_type'] as int];
      buf.writeln(
          '${r['date']},$mealName,${r['food_name']},${r['grams']},${(r['kcal'] as num).toStringAsFixed(1)},${(r['protein'] as num).toStringAsFixed(1)},${(r['fat'] as num).toStringAsFixed(1)},${(r['carb'] as num).toStringAsFixed(1)},${(r['fiber'] as num).toStringAsFixed(1)}');
    }
    return buf.toString();
  }
}
