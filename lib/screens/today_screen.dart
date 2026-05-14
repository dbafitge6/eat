import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/meal_entry.dart';
import '../models/user_profile.dart';
import '../models/water_entry.dart';
import '../services/database_service.dart';
import '../services/share_service.dart';
import '../services/meal_photo_service.dart';
import '../widgets/meal_share_card.dart';
import '../utils/date_utils.dart' as du;
import 'food_search_screen.dart';
import 'barcode_screen.dart';
import 'my_set_screen.dart';
import 'settings_screen.dart';
import 'nutrient_screen.dart';
import 'photo_filter_screen.dart';
import '../services/ad_service.dart';

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
  Map<int, File?> _mealPhotos = {};
  int _visibleMealCount = 1;
  final Set<int> _confirmedMealTypes = {};

  static const _pendingKey = 'pending_sns_dialog';

  @override
  void initState() {
    super.initState();
    _loadThenCheckPending();
  }

  Future<void> _loadThenCheckPending() async {
    await _load();
    if (!mounted) return;
    await _checkPendingDialogs();
  }

  Future<void> _checkPendingDialogs() async {
    final prefs = await SharedPreferences.getInstance();
    final pending = prefs.getStringList(_pendingKey) ?? [];
    final todayPending = pending
        .where((s) => s.startsWith(_today))
        .map((s) => int.tryParse(s.split('_').last))
        .whereType<int>()
        .toList();
    for (final mealType in todayPending) {
      if (!mounted) return;
      await _showSnsAdDialog(mealType);
    }
  }

  Future<void> _savePending(int mealType) async {
    final prefs = await SharedPreferences.getInstance();
    final pending = prefs.getStringList(_pendingKey) ?? [];
    final key = '${_today}_$mealType';
    if (!pending.contains(key)) {
      pending.add(key);
      await prefs.setStringList(_pendingKey, pending);
    }
  }

  Future<void> _removePending(int mealType) async {
    final prefs = await SharedPreferences.getInstance();
    final pending = prefs.getStringList(_pendingKey) ?? [];
    pending.remove('${_today}_$mealType');
    await prefs.setStringList(_pendingKey, pending);
  }

  Future<void> _load() async {
    final db = DatabaseService.instance;
    final meals = await db.getMealsForDate(_today);
    final profile = await db.getUserProfile();
    final water = await db.getTotalWaterForDate(_today);
    final photos = <int, File?>{};
    for (int i = 0; i < 6; i++) {
      photos[i] = await MealPhotoService.getPhoto(_today, i);
    }
    int visibleCount = _visibleMealCount;
    if (meals.isNotEmpty) {
      final maxType = meals.map((m) => m.mealType).reduce((a, b) => a > b ? a : b);
      visibleCount = (maxType + 2).clamp(visibleCount, 6);
    }
    if (!mounted) return;
    setState(() {
      _meals = meals;
      _profile = profile;
      _waterMl = water;
      _mealPhotos = photos;
      _visibleMealCount = visibleCount;
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
    final targetWater = _profile?.targetWaterMl ?? 2000;
    final cs = Theme.of(context).colorScheme;
    final primary = cs.primary;
    final secondary = cs.secondary;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: ShaderMask(
          shaderCallback: (bounds) => LinearGradient(
            colors: [primary, secondary],
          ).createShader(bounds),
          child: const Text(
            'eat.',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: -1.5,
            ),
          ),
        ),
        actions: [
          _GlassIconButton(
            icon: Icons.share_outlined,
            onTap: _shareDaySummary,
          ),
          const SizedBox(width: 8),
          _GlassIconButton(
            icon: Icons.settings_outlined,
            onTap: () async {
              await Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const SettingsScreen()));
              _load();
            },
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                children: [
                  // Hero: Calorie Ring
                  _HeroSection(
                    totalKcal: _totalKcal,
                    targetKcal: target,
                    primary: primary,
                    secondary: secondary,
                    onTapNutrient: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => NutrientScreen(meals: _meals),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Macro Grid
                  _MacroGrid(
                    protein: _totalProtein,
                    fat: _totalFat,
                    carb: _totalCarb,
                    targetKcal: target,
                    primary: primary,
                    secondary: secondary,
                  ),
                  const SizedBox(height: 16),

                  // Quick Stats: water + meal count
                  Row(
                    children: [
                      Expanded(
                        child: _WaterStatCard(
                          waterMl: _waterMl,
                          targetMl: targetWater,
                          primary: primary,
                          secondary: secondary,
                          onAdd: _addWater,
                          onReset: _resetWater,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _MealCountCard(
                          count: _visibleMealCount,
                          primary: primary,
                          secondary: secondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),

                  // Meals section header
                  Row(
                    children: [
                      const Text(
                        '今日の食事',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Meal sections
                  ...List.generate(_visibleMealCount, (mealType) {
                    final entries = _meals
                        .where((m) => m.mealType == mealType)
                        .toList();
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _MealSection(
                        mealType: mealType,
                        entries: entries,
                        photoFile: _mealPhotos[mealType],
                        primary: primary,
                        secondary: secondary,
                        onAdd: () => _showAddOptions(mealType),
                        onCopy: entries.isNotEmpty
                            ? () => _copyMeal(mealType)
                            : null,
                        onDelete: _deleteMeal,
                        onEdit: _editMeal,
                        onCameraAdd: () => _handleCameraAdd(mealType),
                        onSharePhoto: _mealPhotos[mealType] != null
                            ? () => _shareWithPhoto(mealType)
                            : null,
                        onConfirm: entries.isNotEmpty
                            ? () => _confirmMeal(mealType)
                            : null,
                        confirmed: _confirmedMealTypes.contains(mealType),
                        onRemove: entries.isEmpty &&
                                mealType == _visibleMealCount - 1
                            ? _removeMealSection
                            : null,
                      ),
                    );
                  }),

                  // Add meal button
                  if (_visibleMealCount < 6)
                    _GlassCard(
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      child: GestureDetector(
                        onTap: () =>
                            setState(() => _visibleMealCount++),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add, color: Colors.white54, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              '食事${_visibleMealCount + 1}を追加',
                              style: const TextStyle(
                                  color: Colors.white54,
                                  fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  void _removeMealSection() {
    if (_visibleMealCount > 1) {
      setState(() => _visibleMealCount--);
    }
  }

  Future<void> _showAddOptions(int mealType) async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _BottomSheet(
        children: [
          _BottomSheetTile(
            icon: Icons.search,
            label: '食品を検索',
            onTap: () { Navigator.pop(ctx); _openFoodSearch(mealType); },
          ),
          _BottomSheetTile(
            icon: Icons.qr_code_scanner,
            label: 'バーコードスキャン',
            onTap: () { Navigator.pop(ctx); _openBarcode(mealType); },
          ),
          _BottomSheetTile(
            icon: Icons.favorite_outline,
            label: 'マイ食品から選ぶ',
            onTap: () { Navigator.pop(ctx); _openMyFood(mealType); },
          ),
          _BottomSheetTile(
            icon: Icons.playlist_add,
            label: 'マイセットから選ぶ',
            onTap: () { Navigator.pop(ctx); _openMySet(mealType); },
          ),
        ],
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
    }
  }

  Future<void> _openMyFood(int mealType) async {
    final result = await Navigator.push<MealEntry>(
      context,
      MaterialPageRoute(
        builder: (_) => FoodSearchScreen(
          date: _today,
          mealType: mealType,
          initialTab: 1,
        ),
      ),
    );
    if (result != null) {
      await DatabaseService.instance.insertMeal(result);
      await _load();
    }
  }

  Future<void> _openBarcode(int mealType) async {
    final result = await Navigator.push<MealEntry>(
      context,
      MaterialPageRoute(
        builder: (_) => BarcodeScannerScreen(date: _today, mealType: mealType),
      ),
    );
    if (result != null) {
      await DatabaseService.instance.insertMeal(result);
      await _load();
    }
  }

  Future<void> _confirmMeal(int mealType) async {
    final entries = _meals.where((m) => m.mealType == mealType).toList();
    if (entries.isEmpty) return;

    final totalKcal = entries.fold(0.0, (s, e) => s + e.kcal);
    final mealName = MealEntry.mealNames[mealType];

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('$mealName の内容'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ...entries.map((e) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                      child: Text(e.foodName,
                          style: const TextStyle(fontSize: 13))),
                  Text('${e.kcal.round()} kcal',
                      style:
                          const TextStyle(fontSize: 13, color: Colors.grey)),
                ],
              ),
            )),
            const Divider(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('合計',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                Text('${totalKcal.round()} kcal',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('修正する')),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('この内容でOK')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _confirmedMealTypes.add(mealType));
    await _savePending(mealType);
    await _showSnsAdDialog(mealType);
  }

  Future<void> _showSnsAdDialog(int mealType) async {
    final entries = _meals.where((m) => m.mealType == mealType).toList();
    final totalKcal = entries.fold(0.0, (s, e) => s + e.kcal);
    final totalProtein = entries.fold(0.0, (s, e) => s + e.protein);
    final totalFat = entries.fold(0.0, (s, e) => s + e.fat);
    final totalCarb = entries.fold(0.0, (s, e) => s + e.carb);
    final mealName = MealEntry.mealNames[mealType];

    final willPost = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text('$mealName を記録しました！'),
        content: Text(
          '${totalKcal.round()} kcal\nSNSに投稿しますか？',
          style: const TextStyle(fontSize: 16),
          textAlign: TextAlign.center,
        ),
        actions: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('いいえ')),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.share, size: 16),
                  label: const Text('はい'),
                  onPressed: () => Navigator.pop(ctx, true),
                ),
              ),
            ],
          ),
        ],
      ),
    );
    if (!mounted) return;
    await _removePending(mealType);
    if (!mounted) return;
    if (willPost == true) {
      await showShareCardSheet(
        context: context,
        photo: _mealPhotos[mealType],
        mealName: mealName,
        kcal: totalKcal,
        protein: totalProtein,
        fat: totalFat,
        carb: totalCarb,
        targetKcal: _profile?.targetKcal ?? 2000,
      );
    } else {
      AdService.instance.showInterstitial();
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
    final entries = _meals.where((m) => m.mealType == mealType).toList();
    if (entries.isEmpty) return;
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
  }

  Future<void> _deleteMeal(int id) async {
    await DatabaseService.instance.deleteMeal(id);
    await _load();
  }

  Future<void> _editMeal(MealEntry entry) async {
    final nameCtrl = TextEditingController(text: entry.foodName);
    final gramsCtrl =
        TextEditingController(text: entry.grams.round().toString());
    final kcalCtrl =
        TextEditingController(text: entry.kcal.round().toString());
    final proteinCtrl = TextEditingController(
        text: entry.protein > 0 ? entry.protein.toStringAsFixed(1) : '');
    final fatCtrl = TextEditingController(
        text: entry.fat > 0 ? entry.fat.toStringAsFixed(1) : '');
    final carbCtrl = TextEditingController(
        text: entry.carb > 0 ? entry.carb.toStringAsFixed(1) : '');

    final baseG = entry.grams > 0 ? entry.grams : 100.0;
    final kcalP = entry.kcal / baseG * 100;
    final protP = entry.protein / baseG * 100;
    final fatP  = entry.fat  / baseG * 100;
    final carbP = entry.carb / baseG * 100;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, ss) => AlertDialog(
          title: const Text('食事を編集'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                      labelText: '食品名',
                      isDense: true,
                      border: OutlineInputBorder()),
                ),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(
                    child: TextField(
                      controller: gramsCtrl,
                      decoration: const InputDecoration(
                          labelText: 'グラム数',
                          suffixText: 'g',
                          isDense: true,
                          border: OutlineInputBorder()),
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      onChanged: (v) {
                        final g = double.tryParse(v);
                        if (g != null && g > 0) {
                          ss(() {
                            kcalCtrl.text = (kcalP * g / 100).round().toString();
                            if (protP > 0) proteinCtrl.text = (protP * g / 100).toStringAsFixed(1);
                            if (fatP  > 0) fatCtrl.text  = (fatP  * g / 100).toStringAsFixed(1);
                            if (carbP > 0) carbCtrl.text = (carbP * g / 100).toStringAsFixed(1);
                          });
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: kcalCtrl,
                      decoration: const InputDecoration(
                          labelText: 'kcal',
                          isDense: true,
                          border: OutlineInputBorder()),
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                    ),
                  ),
                ]),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(
                    child: TextField(
                      controller: proteinCtrl,
                      decoration: const InputDecoration(
                          labelText: 'P(g)',
                          isDense: true,
                          border: OutlineInputBorder()),
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: fatCtrl,
                      decoration: const InputDecoration(
                          labelText: 'F(g)',
                          isDense: true,
                          border: OutlineInputBorder()),
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: carbCtrl,
                      decoration: const InputDecoration(
                          labelText: 'C(g)',
                          isDense: true,
                          border: OutlineInputBorder()),
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                    ),
                  ),
                ]),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('キャンセル')),
            ElevatedButton(
              onPressed: () async {
                final updated = MealEntry(
                  id: entry.id,
                  date: entry.date,
                  mealType: entry.mealType,
                  foodId: entry.foodId,
                  foodName: nameCtrl.text.isEmpty ? entry.foodName : nameCtrl.text,
                  grams: double.tryParse(gramsCtrl.text) ?? entry.grams,
                  kcal: double.tryParse(kcalCtrl.text) ?? entry.kcal,
                  protein: double.tryParse(proteinCtrl.text) ?? entry.protein,
                  fat: double.tryParse(fatCtrl.text) ?? entry.fat,
                  carb: double.tryParse(carbCtrl.text) ?? entry.carb,
                  fiber: entry.fiber,
                  sodium: entry.sodium,
                  calcium: entry.calcium,
                  iron: entry.iron,
                  isCustom: entry.isCustom,
                );
                await DatabaseService.instance.updateMeal(updated);
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );
    await _load();
  }

  Future<void> _handleCameraAdd(int mealType) async {
    final hasPhoto = _mealPhotos[mealType] != null;
    final source = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _BottomSheet(
        children: [
          _BottomSheetTile(
            icon: Icons.camera_alt,
            label: 'カメラで撮影',
            onTap: () => Navigator.pop(ctx, 'camera'),
          ),
          _BottomSheetTile(
            icon: Icons.photo_library,
            label: 'カメラロールから選ぶ',
            onTap: () => Navigator.pop(ctx, 'gallery'),
          ),
          if (hasPhoto)
            _BottomSheetTile(
              icon: Icons.delete_outline,
              label: '写真を削除',
              onTap: () => Navigator.pop(ctx, 'delete'),
              destructive: true,
            ),
        ],
      ),
    );
    if (source == null || !mounted) return;
    if (source == 'delete') {
      await MealPhotoService.delete(_today, mealType);
    } else {
      final raw = await MealPhotoService.pick(
          _today, mealType,
          fromCamera: source == 'camera');
      if (raw != null && mounted) {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PhotoFilterScreen(
              photo: raw,
              date: _today,
              mealType: mealType,
            ),
          ),
        );
      }
    }
    await _load();
  }

  Future<void> _shareWithPhoto(int mealType) async {
    final photo = _mealPhotos[mealType];
    if (photo == null || !mounted) return;
    final entries = _meals.where((m) => m.mealType == mealType).toList();
    await showShareCardSheet(
      context: context,
      photo: photo,
      mealName: MealEntry.mealNames[mealType],
      kcal: entries.fold(0.0, (s, e) => s + e.kcal),
      protein: entries.fold(0.0, (s, e) => s + e.protein),
      fat: entries.fold(0.0, (s, e) => s + e.fat),
      carb: entries.fold(0.0, (s, e) => s + e.carb),
    );
  }

  Future<void> _addWater() async {
    final ml = await _showWaterDialog();
    if (ml == null) return;
    await DatabaseService.instance
        .addWater(WaterEntry(date: _today, ml: ml));
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

// ─── Hero Section ──────────────────────────────────────────────

class _HeroSection extends StatelessWidget {
  final double totalKcal;
  final double targetKcal;
  final Color primary;
  final Color secondary;
  final VoidCallback onTapNutrient;

  const _HeroSection({
    required this.totalKcal,
    required this.targetKcal,
    required this.primary,
    required this.secondary,
    required this.onTapNutrient,
  });

  @override
  Widget build(BuildContext context) {
    final progress = (totalKcal / targetKcal).clamp(0.0, 1.0);
    final remaining = targetKcal - totalKcal;
    final isOver = remaining < 0;

    return Column(
      children: [
        const SizedBox(height: 16),
        GestureDetector(
          onTap: onTapNutrient,
          child: _ProgressRing(
            progress: progress,
            size: 200,
            strokeWidth: 14,
            colorStart: primary,
            colorEnd: secondary,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  totalKcal.round().toString(),
                  style: const TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    height: 1,
                    letterSpacing: -2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '/ ${targetKcal.round()} kcal',
                  style: const TextStyle(
                    fontSize: 13,
                    color: Colors.white54,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          '今日の摂取カロリー',
          style: TextStyle(fontSize: 14, color: Colors.white60),
        ),
        const SizedBox(height: 4),
        ShaderMask(
          shaderCallback: (bounds) => LinearGradient(
            colors: isOver ? [Colors.redAccent, Colors.orange] : [primary, secondary],
          ).createShader(bounds),
          child: Text(
            isOver
                ? '${(-remaining).round()} kcal オーバー'
                : '残り ${remaining.round()} kcal',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 4),
      ],
    );
  }
}

// ─── Macro Grid ────────────────────────────────────────────────

class _MacroGrid extends StatelessWidget {
  final double protein;
  final double fat;
  final double carb;
  final double targetKcal;
  final Color primary;
  final Color secondary;

  const _MacroGrid({
    required this.protein,
    required this.fat,
    required this.carb,
    required this.targetKcal,
    required this.primary,
    required this.secondary,
  });

  @override
  Widget build(BuildContext context) {
    final targetProtein = targetKcal * 0.25 / 4;
    final targetFat = targetKcal * 0.25 / 9;
    final targetCarb = targetKcal * 0.50 / 4;

    return Row(
      children: [
        Expanded(child: _MacroCard(
          label: 'たんぱく質',
          value: protein,
          target: targetProtein,
          accentColor: primary,
        )),
        const SizedBox(width: 10),
        Expanded(child: _MacroCard(
          label: '脂質',
          value: fat,
          target: targetFat,
          accentColor: Color.lerp(primary, secondary, 0.5)!,
        )),
        const SizedBox(width: 10),
        Expanded(child: _MacroCard(
          label: '炭水化物',
          value: carb,
          target: targetCarb,
          accentColor: secondary,
        )),
      ],
    );
  }
}

class _MacroCard extends StatelessWidget {
  final String label;
  final double value;
  final double target;
  final Color accentColor;

  const _MacroCard({
    required this.label,
    required this.value,
    required this.target,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final ratio = (value / target).clamp(0.0, 1.0);
    return _GlassCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: Colors.white54),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          Text(
            '${value.round()}g',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 4,
              backgroundColor: Colors.white12,
              valueColor: AlwaysStoppedAnimation(accentColor),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Water Stat Card ───────────────────────────────────────────

class _WaterStatCard extends StatelessWidget {
  final int waterMl;
  final double targetMl;
  final Color primary;
  final Color secondary;
  final VoidCallback onAdd;
  final VoidCallback onReset;

  const _WaterStatCard({
    required this.waterMl,
    required this.targetMl,
    required this.primary,
    required this.secondary,
    required this.onAdd,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    return _GlassCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [primary, secondary]),
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Icon(Icons.water_drop_outlined, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: GestureDetector(
              onLongPress: onReset,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    waterMl >= 1000
                        ? '${(waterMl / 1000).toStringAsFixed(1)}L'
                        : '${waterMl}ml',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    '水分',
                    style: const TextStyle(fontSize: 11, color: Colors.white54),
                  ),
                ],
              ),
            ),
          ),
          GestureDetector(
            onTap: onAdd,
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.add, color: Colors.white70, size: 18),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Meal Count Card ───────────────────────────────────────────

class _MealCountCard extends StatelessWidget {
  final int count;
  final Color primary;
  final Color secondary;

  const _MealCountCard({
    required this.count,
    required this.primary,
    required this.secondary,
  });

  @override
  Widget build(BuildContext context) {
    return _GlassCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [primary, secondary]),
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Icon(Icons.local_fire_department_outlined,
                color: Colors.white, size: 22),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$count',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const Text(
                '食事',
                style: TextStyle(fontSize: 11, color: Colors.white54),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Meal Section ──────────────────────────────────────────────

class _MealSection extends StatelessWidget {
  final int mealType;
  final List<MealEntry> entries;
  final File? photoFile;
  final Color primary;
  final Color secondary;
  final VoidCallback onAdd;
  final VoidCallback? onCopy;
  final VoidCallback onCameraAdd;
  final VoidCallback? onSharePhoto;
  final VoidCallback? onConfirm;
  final bool confirmed;
  final VoidCallback? onRemove;
  final Future<void> Function(int) onDelete;
  final Future<void> Function(MealEntry) onEdit;

  const _MealSection({
    required this.mealType,
    required this.entries,
    required this.primary,
    required this.secondary,
    required this.onAdd,
    required this.onDelete,
    required this.onCameraAdd,
    required this.onEdit,
    this.photoFile,
    this.onCopy,
    this.onSharePhoto,
    this.onConfirm,
    this.confirmed = false,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final mealName = MealEntry.mealNames[mealType];
    final totalKcal = entries.fold(0.0, (s, e) => s + e.kcal);

    return _GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            children: [
              if (onRemove != null)
                GestureDetector(
                  onTap: onRemove,
                  child: const Padding(
                    padding: EdgeInsets.only(right: 8),
                    child: Icon(Icons.remove_circle_outline,
                        size: 16, color: Colors.white38),
                  ),
                ),
              Text(
                mealName,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 8),
              if (entries.isNotEmpty)
                Text(
                  '${totalKcal.round()} kcal',
                  style: const TextStyle(color: Colors.white38, fontSize: 12),
                ),
              const Spacer(),
              // Action icons
              GestureDetector(
                onTap: onCameraAdd,
                child: Icon(
                  photoFile != null
                      ? Icons.photo_camera
                      : Icons.add_a_photo_outlined,
                  size: 17,
                  color: photoFile != null ? primary : Colors.white38,
                ),
              ),
              if (onSharePhoto != null) ...[
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: onSharePhoto,
                  child: Icon(Icons.ios_share, size: 17, color: primary),
                ),
              ],
              if (onCopy != null) ...[
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: onCopy,
                  child: const Icon(Icons.copy, size: 16, color: Colors.white38),
                ),
              ],
              const SizedBox(width: 12),
              GestureDetector(
                onTap: onAdd,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [primary, secondary]),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add, size: 13, color: Colors.white),
                      SizedBox(width: 2),
                      Text('追加',
                          style: TextStyle(
                              fontSize: 12,
                              color: Colors.white,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // Photo thumbnail
          if (photoFile != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: GestureDetector(
                onTap: onCameraAdd,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Stack(
                    children: [
                      Image.file(
                        photoFile!,
                        height: 140,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                      Positioned(
                        top: 6,
                        right: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text('変更',
                              style: TextStyle(
                                  color: Colors.white, fontSize: 11)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // Food entries
          if (entries.isNotEmpty) ...[
            const SizedBox(height: 10),
            const Divider(color: Colors.white10, height: 1),
            ...entries.map((e) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onLongPress: () => onEdit(e),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            e.foodName,
                            style: const TextStyle(
                                fontSize: 14, color: Colors.white),
                          ),
                          Text(
                            '${e.grams.round()}g',
                            style: const TextStyle(
                                fontSize: 11, color: Colors.white38),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Text(
                    '${e.kcal.round()} kcal',
                    style:
                        const TextStyle(fontSize: 13, color: Colors.white60),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => onDelete(e.id!),
                    child: const Icon(Icons.cancel,
                        size: 18, color: Colors.white24),
                  ),
                ],
              ),
            )),
          ],

          // Confirm button
          if (onConfirm != null) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: confirmed
                  ? OutlinedButton.icon(
                      onPressed: onConfirm,
                      icon: const Icon(Icons.check_circle,
                          size: 15, color: Colors.greenAccent),
                      label: const Text('確定済み　再確認する',
                          style: TextStyle(color: Colors.greenAccent)),
                      style: OutlinedButton.styleFrom(
                          side:
                              const BorderSide(color: Colors.greenAccent, width: 0.8),
                          padding: const EdgeInsets.symmetric(vertical: 10)),
                    )
                  : DecoratedBox(
                      decoration: BoxDecoration(
                        gradient:
                            LinearGradient(colors: [primary, secondary]),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ElevatedButton(
                        onPressed: onConfirm,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Text('OK　この食事を確定する',
                            style: TextStyle(color: Colors.white)),
                      ),
                    ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Shared UI Components ──────────────────────────────────────

class _GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;

  const _GlassCard({required this.child, this.padding = const EdgeInsets.all(20)});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          ),
          child: child,
        ),
      ),
    );
  }
}

class _GlassIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _GlassIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
            ),
            child: Icon(icon, color: Colors.white70, size: 18),
          ),
        ),
      ),
    );
  }
}

// ─── Progress Ring ─────────────────────────────────────────────

class _ProgressRing extends StatelessWidget {
  final double progress;
  final double size;
  final double strokeWidth;
  final Color colorStart;
  final Color colorEnd;
  final Widget child;

  const _ProgressRing({
    required this.progress,
    required this.size,
    required this.strokeWidth,
    required this.colorStart,
    required this.colorEnd,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size(size, size),
            painter: _RingPainter(
              progress: progress.clamp(0.0, 1.0),
              strokeWidth: strokeWidth,
              colorStart: colorStart,
              colorEnd: colorEnd,
            ),
          ),
          child,
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  final double strokeWidth;
  final Color colorStart;
  final Color colorEnd;

  const _RingPainter({
    required this.progress,
    required this.strokeWidth,
    required this.colorStart,
    required this.colorEnd,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.08)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth,
    );

    if (progress <= 0) return;

    final sweepAngle = 2 * math.pi * progress;
    final rect = Rect.fromCircle(center: center, radius: radius);

    canvas.drawArc(
      rect,
      -math.pi / 2,
      sweepAngle,
      false,
      Paint()
        ..shader = SweepGradient(
          startAngle: -math.pi / 2,
          endAngle: -math.pi / 2 + sweepAngle,
          colors: [colorStart, colorEnd],
        ).createShader(rect)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress ||
      old.colorStart != colorStart ||
      old.colorEnd != colorEnd;
}

// ─── Bottom Sheet ──────────────────────────────────────────────

class _BottomSheet extends StatelessWidget {
  final List<Widget> children;

  const _BottomSheet({required this.children});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 8),
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 8),
                ...children,
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BottomSheetTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool destructive;

  const _BottomSheetTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.destructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = destructive ? Colors.redAccent : Colors.white;
    return ListTile(
      leading: Icon(icon, color: color.withValues(alpha: 0.8)),
      title: Text(label, style: TextStyle(color: color)),
      onTap: onTap,
    );
  }
}
