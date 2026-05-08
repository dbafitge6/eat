import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../models/meal_entry.dart';
import '../models/user_profile.dart';
import '../models/water_entry.dart';
import '../services/database_service.dart';
import '../services/ad_service.dart';
import '../services/share_service.dart';
import '../utils/date_utils.dart' as du;
import 'food_search_screen.dart';
import 'barcode_screen.dart';
import 'my_set_screen.dart';
import 'settings_screen.dart';
import 'nutrient_screen.dart';
import 'premium_screen.dart';

class TodayScreen extends StatefulWidget {
  const TodayScreen({super.key});

  @override
  State<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends State<TodayScreen> {
  final String _today = du.todayString();
  List<MealEntry> _meals = [];
  UserProfile? _profile;
  int _waterMl = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final db = DatabaseService.instance;
    final meals = await db.getMealsForDate(_today);
    final profile = await db.getUserProfile();
    final water = await db.getTotalWaterForDate(_today);
    if (!mounted) return;
    setState(() {
      _meals = meals;
      _profile = profile;
      _waterMl = water;
      _loading = false;
    });
  }

  double get _totalKcal => _meals.fold(0, (s, m) => s + m.kcal);
  double get _totalProtein => _meals.fold(0, (s, m) => s + m.protein);
  double get _totalFat => _meals.fold(0, (s, m) => s + m.fat);
  double get _totalCarb => _meals.fold(0, (s, m) => s + m.carb);

  @override
  Widget build(BuildContext context) {
    final target = _profile?.targetKcal ?? 2000;
    final primary = Theme.of(context).colorScheme.primary;
    return Scaffold(
      appBar: AppBar(
        title: const Text('eat.'),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined),
            onPressed: _shareDaySummary,
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () async {
              await Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const SettingsScreen()));
              _load();
            },
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _CalorieCard(
                    total: _totalKcal,
                    target: target,
                    protein: _totalProtein,
                    fat: _totalFat,
                    carb: _totalCarb,
                    primary: primary,
                    onTapNutrient: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => NutrientScreen(meals: _meals),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _WaterCard(
                    waterMl: _waterMl,
                    targetMl: _profile?.targetWaterMl ?? 2000,
                    primary: primary,
                    onAdd: _addWater,
                    onReset: _resetWater,
                  ),
                  const SizedBox(height: 12),
                  ...List.generate(6, (mealType) {
                    final entries = _meals
                        .where((m) => m.mealType == mealType)
                        .toList();
                    return _MealSection(
                      mealType: mealType,
                      entries: entries,
                      onAdd: () => _showAddOptions(mealType),
                      onCopy: entries.isNotEmpty
                          ? () => _copyMeal(mealType)
                          : null,
                      onDelete: _deleteMeal,
                    );
                  }),
                  const SizedBox(height: 16),
                  const BannerAdWidget(),
                  const SizedBox(height: 8),
                ],
              ),
            ),
    );
  }

  Future<void> _showAddOptions(int mealType) async {
    await showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.search),
              title: const Text('食品を検索'),
              onTap: () {
                Navigator.pop(ctx);
                _openFoodSearch(mealType);
              },
            ),
            ListTile(
              leading: const Icon(Icons.qr_code_scanner),
              title: const Text('バーコードスキャン'),
              onTap: () {
                Navigator.pop(ctx);
                _openBarcode(mealType);
              },
            ),
            ListTile(
              leading: const Icon(Icons.playlist_add),
              title: const Text('マイセットから選ぶ'),
              onTap: () {
                Navigator.pop(ctx);
                _openMySet(mealType);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openFoodSearch(int mealType) async {
    final result = await Navigator.push<MealEntry>(
      context,
      MaterialPageRoute(
        builder: (_) => FoodSearchScreen(date: _today, mealType: mealType),
      ),
    );
    if (result != null) {
      await DatabaseService.instance.insertMeal(result);
      await _load();
      if (mounted) {
        await showMealAddedDialog(
          context,
          mealName: result.foodName,
          kcal: result.kcal,
        );
      }
    }
  }

  Future<void> _openBarcode(int mealType) async {
    final result = await Navigator.push<MealEntry>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            BarcodeScannerScreen(date: _today, mealType: mealType),
      ),
    );
    if (result != null) {
      await DatabaseService.instance.insertMeal(result);
      await _load();
    }
  }

  Future<void> _openMySet(int mealType) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MySetScreen(date: _today, mealType: mealType),
      ),
    );
    await _load();
  }

  Future<void> _copyMeal(int mealType) async {
    final entries =
        _meals.where((m) => m.mealType == mealType).toList();
    if (entries.isEmpty) return;
    // 別の食事タイプに同じ内容をコピー
    final targetType = await _showMealTypePicker(exclude: mealType);
    if (targetType == null) return;
    for (final e in entries) {
      await DatabaseService.instance.insertMeal(MealEntry(
        date: _today,
        mealType: targetType,
        foodId: e.foodId,
        foodName: e.foodName,
        grams: e.grams,
        kcal: e.kcal,
        protein: e.protein,
        fat: e.fat,
        carb: e.carb,
        fiber: e.fiber,
        sodium: e.sodium,
        calcium: e.calcium,
        iron: e.iron,
        isCustom: e.isCustom,
      ));
    }
    await _load();
  }

  Future<int?> _showMealTypePicker({required int exclude}) {
    return showModalBottomSheet<int>(
      context: context,
      builder: (ctx) => ListView(
        shrinkWrap: true,
        children: List.generate(6, (i) {
          if (i == exclude) return const SizedBox.shrink();
          return ListTile(
            title: Text(MealEntry.mealNames[i]),
            onTap: () => Navigator.pop(ctx, i),
          );
        }),
      ),
    );
  }

  Future<void> _shareDaySummary() async {
    await ShareService.shareDaySummary(
      meals: _meals,
      targetKcal: _profile?.targetKcal ?? 2000,
      waterMl: _waterMl,
    );
    if (AdService.instance.showAds) {
      await AdService.instance.grantAdFree(const Duration(hours: 24));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('シェアありがとう！24時間広告なし')),
        );
      }
    }
  }

  Future<void> _deleteMeal(int id) async {
    await DatabaseService.instance.deleteMeal(id);
    await _load();
  }

  Future<void> _addWater() async {
    final ml = await _showWaterDialog();
    if (ml == null) return;
    await DatabaseService.instance.addWater(
        WaterEntry(date: _today, ml: ml));
    await _load();
  }

  Future<void> _resetWater() async {
    await DatabaseService.instance.deleteWaterForDate(_today);
    await _load();
  }

  Future<int?> _showWaterDialog() async {
    int selected = 200;
    return showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('水分を追加'),
        content: StatefulBuilder(
          builder: (ctx, ss) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('$selected ml',
                  style: const TextStyle(
                      fontSize: 28, fontWeight: FontWeight.bold)),
              Slider(
                value: selected.toDouble(),
                min: 50,
                max: 1000,
                divisions: 19,
                onChanged: (v) => ss(() => selected = v.round()),
              ),
              Wrap(
                spacing: 8,
                children: [100, 150, 200, 250, 350, 500].map((ml) {
                  return ActionChip(
                    label: Text('$ml ml'),
                    onPressed: () => ss(() => selected = ml),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('キャンセル')),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, selected),
              child: const Text('追加')),
        ],
      ),
    );
  }
}

class _CalorieCard extends StatelessWidget {
  final double total;
  final double target;
  final double protein;
  final double fat;
  final double carb;
  final Color primary;
  final VoidCallback onTapNutrient;

  const _CalorieCard({
    required this.total,
    required this.target,
    required this.protein,
    required this.fat,
    required this.carb,
    required this.primary,
    required this.onTapNutrient,
  });

  @override
  Widget build(BuildContext context) {
    final ratio = (total / target).clamp(0.0, 1.0);
    final remaining = target - total;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('今日のカロリー',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                TextButton(
                    onPressed: onTapNutrient,
                    child: const Text('栄養素詳細 >')),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: ratio,
              minHeight: 12,
              borderRadius: BorderRadius.circular(6),
              valueColor: AlwaysStoppedAnimation(
                  total > target ? Colors.red : primary),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('${total.round()} kcal',
                    style: const TextStyle(
                        fontSize: 22, fontWeight: FontWeight.bold)),
                Text(
                    remaining >= 0
                        ? '残り ${remaining.round()} kcal'
                        : '${(-remaining).round()} kcal オーバー',
                    style: TextStyle(
                        color: remaining < 0 ? Colors.red : Colors.grey)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _MacroChip('P', protein, Colors.blue),
                _MacroChip('F', fat, Colors.orange),
                _MacroChip('C', carb, Colors.green),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MacroChip extends StatelessWidget {
  final String label;
  final double value;
  final Color color;
  const _MacroChip(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration:
              BoxDecoration(color: color.withOpacity(0.2), shape: BoxShape.circle),
          child: Center(
              child: Text(label,
                  style: TextStyle(color: color, fontWeight: FontWeight.bold))),
        ),
        const SizedBox(height: 4),
        Text('${value.round()}g', style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}

class _WaterCard extends StatelessWidget {
  final int waterMl;
  final double targetMl;
  final Color primary;
  final VoidCallback onAdd;
  final VoidCallback onReset;

  const _WaterCard({
    required this.waterMl,
    required this.targetMl,
    required this.primary,
    required this.onAdd,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    final ratio = (waterMl / targetMl).clamp(0.0, 1.0);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.water_drop, color: Colors.blue, size: 32),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('水分 $waterMl ml / ${targetMl.round()} ml'),
                      GestureDetector(
                        onLongPress: onReset,
                        child: const Icon(Icons.refresh,
                            size: 16, color: Colors.grey),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  LinearProgressIndicator(
                    value: ratio,
                    minHeight: 8,
                    borderRadius: BorderRadius.circular(4),
                    valueColor:
                        const AlwaysStoppedAnimation(Colors.blue),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: onAdd,
              icon: const Icon(Icons.add_circle_outline),
            ),
          ],
        ),
      ),
    );
  }
}

class _MealSection extends StatelessWidget {
  final int mealType;
  final List<MealEntry> entries;
  final VoidCallback onAdd;
  final VoidCallback? onCopy;
  final Future<void> Function(int) onDelete;

  const _MealSection({
    required this.mealType,
    required this.entries,
    required this.onAdd,
    required this.onDelete,
    this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    final mealName = MealEntry.mealNames[mealType];
    final totalKcal = entries.fold(0.0, (s, e) => s + e.kcal);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(mealName,
                style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(width: 8),
            if (entries.isNotEmpty)
              Text('${totalKcal.round()} kcal',
                  style: const TextStyle(color: Colors.grey, fontSize: 12)),
            const Spacer(),
            if (onCopy != null)
              IconButton(
                icon: const Icon(Icons.copy, size: 16),
                onPressed: onCopy,
                tooltip: '他の食事にコピー',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            TextButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add, size: 16),
              label: const Text('追加'),
            ),
          ],
        ),
        ...entries.map((e) => Dismissible(
              key: Key('meal_${e.id}'),
              direction: DismissDirection.endToStart,
              background: Container(
                color: Colors.red,
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 16),
                child: const Icon(Icons.delete, color: Colors.white),
              ),
              onDismissed: (_) => onDelete(e.id!),
              child: ListTile(
                dense: true,
                title: Text(e.foodName),
                subtitle: Text('${e.grams.round()}g'),
                trailing: Text('${e.kcal.round()} kcal'),
              ),
            )),
        const Divider(),
      ],
    );
  }
}
