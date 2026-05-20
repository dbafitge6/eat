import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/meal_plan.dart';
import '../models/user_profile.dart';
import '../services/database_service.dart';
import '../services/diet_type_service.dart';
import '../services/gemini_service.dart';
import '../services/purchase_service.dart';
import '../utils/date_utils.dart' as du;
import 'premium_screen.dart';

class MealPlanScreen extends StatefulWidget {
  const MealPlanScreen({super.key});

  @override
  State<MealPlanScreen> createState() => _MealPlanScreenState();
}

class _MealPlanScreenState extends State<MealPlanScreen> {
  Map<int, List<bool>> _schedule = {};
  List<MealPlan> _plans = [];
  bool _generating = false;
  String _errorMsg = '';
  UserProfile? _profile;
  List<String> _allergies = [];
  String _dislikedFoods = '';
  bool _loading = true;
  final Set<String> _checkedItems = {};

  static const _scheduleKey = 'meal_plan_schedule';
  static const _dayNames = ['月', '火', '水', '木', '金', '土', '日'];

  String get _weekStart {
    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    return du.formatDate(monday);
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();

    final scheduleJson = prefs.getString(_scheduleKey);
    Map<int, List<bool>> schedule;
    if (scheduleJson != null) {
      final decoded = jsonDecode(scheduleJson) as Map<String, dynamic>;
      schedule = {
        for (final e in decoded.entries)
          int.parse(e.key): List<bool>.from(e.value as List)
      };
    } else {
      schedule = {
        for (int i = 0; i < 5; i++) i: [false, false, true],
        5: [true, true, true],
        6: [true, true, true],
      };
    }

    final allergyList = prefs.getStringList('user_allergies') ?? [];
    final allergyCustom = prefs.getString('user_allergies_custom') ?? '';
    final allergies = [
      ...allergyList,
      if (allergyCustom.isNotEmpty) ...allergyCustom.split('、').where((s) => s.isNotEmpty),
    ];
    final disliked = prefs.getString('user_disliked_foods') ?? '';
    await DietTypeService.instance.load();
    final profile = await DatabaseService.instance.getUserProfile();
    final plans = await DatabaseService.instance.getMealPlansForWeek(_weekStart);

    if (!mounted) return;
    setState(() {
      _schedule = schedule;
      _allergies = allergies;
      _dislikedFoods = disliked;
      _profile = profile;
      _plans = plans;
      _loading = false;
    });
  }

  Future<void> _saveSchedule() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(
        {for (final e in _schedule.entries) e.key.toString(): e.value});
    await prefs.setString(_scheduleKey, encoded);
  }

  Future<void> _generate() async {
    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));

    final scheduleEntries = <Map<String, dynamic>>[];
    for (int day = 0; day < 7; day++) {
      final date = monday.add(Duration(days: day));
      final meals = _schedule[day] ?? [false, false, false];
      for (int meal = 0; meal < 3; meal++) {
        if (meals[meal]) {
          scheduleEntries.add({'date': du.formatDate(date), 'meal_type': meal});
        }
      }
    }

    if (scheduleEntries.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('少なくとも1つの食事を選択してください')));
      return;
    }

    setState(() {
      _generating = true;
      _errorMsg = '';
    });

    try {
      final plans = await GeminiService.instance.generateMealPlan(
        schedule: scheduleEntries,
        allergies: _allergies,
        dislikedFoods: _dislikedFoods,
        targetKcal: _profile?.targetKcal ?? 2000,
        weekStart: _weekStart,
        dietType: DietTypeService.instance.current,
      );

      if (plans == null) {
        setState(() => _errorMsg = 'APIキーが設定されていません（設定→AI食品検索から設定）');
        return;
      }

      await DatabaseService.instance.saveMealPlansForWeek(_weekStart, plans);
      setState(() => _plans = plans);
    } catch (e) {
      setState(() => _errorMsg = '生成に失敗しました: $e');
    } finally {
      setState(() => _generating = false);
    }
  }

  Map<String, double> get _shoppingList {
    final list = <String, double>{};
    for (final plan in _plans) {
      for (final dish in plan.dishes) {
        list[dish.name] = (list[dish.name] ?? 0) + dish.grams;
      }
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    if (!PurchaseService.instance.isPremium) {
      return Scaffold(
        appBar: AppBar(title: const Text('1週間献立')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock_outline, size: 64, color: Colors.grey),
                const SizedBox(height: 16),
                const Text('プレミアム機能',
                    style:
                        TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                const Text('1週間の献立生成はプレミアム会員専用です',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey)),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const PremiumScreen())),
                  child: const Text('プレミアムに登録する'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('1週間献立'),
          bottom: const TabBar(
              tabs: [Tab(text: '献立'), Tab(text: '買い物リスト')]),
        ),
        body: TabBarView(
          physics: const NeverScrollableScrollPhysics(),
          children: [
            _buildMealTab(),
            _buildShoppingTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildMealTab() {
    final primary = Theme.of(context).colorScheme.primary;
    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('スケジュール',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const SizedBox(width: 28),
                    ...List.generate(
                        7,
                        (i) => Expanded(
                              child: Center(
                                child: Text(_dayNames[i],
                                    style: const TextStyle(
                                        fontSize: 11, color: Colors.grey)),
                              ),
                            )),
                  ],
                ),
                ...List.generate(3, (meal) {
                  return Row(
                    children: [
                      SizedBox(
                        width: 28,
                        child: Text(MealPlan.mealIcons[meal],
                            style: const TextStyle(fontSize: 13)),
                      ),
                      ...List.generate(7, (day) {
                        final checked = _schedule[day]?[meal] ?? false;
                        return Expanded(
                          child: Checkbox(
                            value: checked,
                            visualDensity: VisualDensity.compact,
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                            onChanged: (v) {
                              setState(() {
                                _schedule.putIfAbsent(
                                    day, () => [false, false, false]);
                                _schedule[day]![meal] = v ?? false;
                              });
                              _saveSchedule();
                            },
                          ),
                        );
                      }),
                    ],
                  );
                }),
              ],
            ),
          ),
        ),
        if (_allergies.isNotEmpty || _dislikedFoods.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Wrap(
              spacing: 6,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const Text('除外:',
                    style: TextStyle(fontSize: 12, color: Colors.grey)),
                ..._allergies.map((a) => Chip(
                      label: Text(a, style: const TextStyle(fontSize: 11)),
                      visualDensity: VisualDensity.compact,
                      backgroundColor:
                          Colors.red.withValues(alpha: 0.1),
                      side: const BorderSide(color: Colors.red, width: 0.5),
                    )),
                if (_dislikedFoods.isNotEmpty)
                  Chip(
                    label: Text(_dislikedFoods,
                        style: const TextStyle(fontSize: 11)),
                    visualDensity: VisualDensity.compact,
                    backgroundColor:
                        Colors.orange.withValues(alpha: 0.1),
                    side:
                        const BorderSide(color: Colors.orange, width: 0.5),
                  ),
              ],
            ),
          ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _generating ? null : _generate,
            icon: _generating
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.auto_awesome, size: 16),
            label: Text(_generating ? '生成中...' : '献立を生成する'),
            style: ElevatedButton.styleFrom(
              backgroundColor: primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
        if (_errorMsg.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(_errorMsg,
                style: const TextStyle(color: Colors.red, fontSize: 12)),
          ),
        const SizedBox(height: 16),
        if (_plans.isEmpty && !_generating)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Text('スケジュールを設定して生成してください',
                  style: TextStyle(color: Colors.grey)),
            ),
          )
        else
          ..._buildPlanList(monday, primary),
      ],
    );
  }

  List<Widget> _buildPlanList(DateTime monday, Color primary) {
    final byDate = <String, List<MealPlan>>{};
    for (final p in _plans) {
      byDate.putIfAbsent(p.date, () => []).add(p);
    }
    final sortedDates = byDate.keys.toList()..sort();

    return sortedDates.map((date) {
      final plans = byDate[date]!
        ..sort((a, b) => a.mealType.compareTo(b.mealType));
      final dt = DateTime.parse(date);
      final dayName = _dayNames[dt.weekday - 1];
      final dateStr = '${dt.month}/${dt.day}（$dayName）';

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 4),
            child: Text(dateStr,
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 14)),
          ),
          ...plans.map((p) => Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(MealPlan.mealIcons[p.mealType],
                              style: const TextStyle(fontSize: 14)),
                          const SizedBox(width: 6),
                          Text(MealPlan.mealNames[p.mealType],
                              style: const TextStyle(
                                  fontSize: 12, color: Colors.grey)),
                          const Spacer(),
                          Text('${p.totalKcal.round()} kcal',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: primary,
                                  fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(p.title,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 14)),
                      if (p.dishes.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          p.dishes.map((d) => d.name).join('・'),
                          style: const TextStyle(
                              fontSize: 11, color: Colors.grey),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
              )),
        ],
      );
    }).toList();
  }

  Widget _buildShoppingTab() {
    if (_plans.isEmpty) {
      return const Center(
        child: Text('まず献立を生成してください',
            style: TextStyle(color: Colors.grey)),
      );
    }

    final list = _shoppingList;
    final sortedItems = list.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: sortedItems.length + 1,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (ctx, i) {
        if (i == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('${list.length}品目',
                    style:
                        const TextStyle(color: Colors.grey, fontSize: 13)),
                TextButton(
                  onPressed: () => setState(() => _checkedItems.clear()),
                  child: const Text('チェックをクリア'),
                ),
              ],
            ),
          );
        }
        final item = sortedItems[i - 1];
        final checked = _checkedItems.contains(item.key);
        return CheckboxListTile(
          dense: true,
          value: checked,
          onChanged: (v) => setState(() {
            if (v == true) {
              _checkedItems.add(item.key);
            } else {
              _checkedItems.remove(item.key);
            }
          }),
          title: Text(
            item.key,
            style: TextStyle(
              fontSize: 14,
              decoration:
                  checked ? TextDecoration.lineThrough : null,
              color: checked ? Colors.grey : null,
            ),
          ),
          subtitle: Text('約 ${item.value.round()}g',
              style: const TextStyle(fontSize: 12)),
          controlAffinity: ListTileControlAffinity.leading,
        );
      },
    );
  }
}
