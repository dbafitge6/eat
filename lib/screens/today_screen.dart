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
import 'my_set_screen.dart';
import 'settings_screen.dart';
import 'nutrient_screen.dart';
import 'photo_filter_screen.dart';
import '../services/ad_service.dart';
import '../models/exercise_entry.dart';
import '../services/functional_ingredient_service.dart';
import 'ai_chat_screen.dart';
import 'restaurant_screen.dart';
import 'premium_screen.dart';
import '../services/purchase_service.dart';
import 'package:fl_chart/fl_chart.dart';

class TodayScreen extends StatefulWidget {
  const TodayScreen({super.key});

  @override
  State<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends State<TodayScreen> {
  final String _today = du.todayString();
  List<MealEntry> _meals = [];
  List<ExerciseEntry> _exercises = [];
  UserProfile? _profile;
  int _waterMl = 0;
  int _streak = 0;
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
    final exercises = await db.getExercisesForDate(_today);
    final profile = await db.getUserProfile();
    final water = await db.getTotalWaterForDate(_today);
    final streak = await db.getStreak();
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
      _exercises = exercises;
      _profile = profile;
      _waterMl = water;
      _streak = streak;
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
            icon: Icons.auto_awesome,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => AiChatScreen(
                  todayMeals: _meals,
                  profile: _profile,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
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
                  const SizedBox(height: 12),

                  // PFC Balance Chart
                  _PFCChart(
                    protein: _totalProtein,
                    fat: _totalFat,
                    carb: _totalCarb,
                    primary: primary,
                    secondary: secondary,
                  ),
                  const SizedBox(height: 12),

                  // Quick Stats: water + streak
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
                        child: _StreakCard(
                          streak: _streak,
                          primary: primary,
                          secondary: secondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Exercise Card
                  _ExerciseCard(
                    exercises: _exercises,
                    primary: primary,
                    secondary: secondary,
                    weightKg: _profile?.weightKg ?? 60,
                    today: _today,
                    onChanged: _load,
                  ),
                  const SizedBox(height: 12),

                  // Advice Card
                  _AdviceCard(
                    totalKcal: _totalKcal,
                    targetKcal: target.toDouble(),
                    totalProtein: _totalProtein,
                    totalFat: _totalFat,
                    totalCarb: _totalCarb,
                    streak: _streak,
                    primary: primary,
                    secondary: secondary,
                    onChatTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AiChatScreen(
                          todayMeals: _meals,
                          profile: _profile,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Meals section header
                  const Text(
                    '今日の食事',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
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
                        onTap: () {
                          if (!PurchaseService.instance.isPremium &&
                              _visibleMealCount >= 3) {
                            _showPremiumGate('4食目以降の追加はプレミアム機能です');
                            return;
                          }
                          setState(() => _visibleMealCount++);
                        },
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
                            if (!PurchaseService.instance.isPremium &&
                                _visibleMealCount >= 3) ...[
                              const SizedBox(width: 6),
                              const Icon(Icons.lock_outline,
                                  size: 14, color: Colors.white38),
                            ],
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
            icon: Icons.favorite_outline,
            label: 'マイ食品から選ぶ',
            onTap: () { Navigator.pop(ctx); _openMyFood(mealType); },
          ),
          _BottomSheetTile(
            icon: Icons.playlist_add,
            label: 'マイセットから選ぶ',
            onTap: () { Navigator.pop(ctx); _openMySet(mealType); },
          ),
          _BottomSheetTile(
            icon: Icons.restaurant_outlined,
            label: '外食メニューを探す',
            onTap: () { Navigator.pop(ctx); _openRestaurant(mealType); },
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
      _showMealRecordedFeedback(result);
    }
  }

  void _showMealRecordedFeedback(MealEntry entry) {
    if (!mounted) return;
    final ingredients = FunctionalIngredientService.detectFromFoodName(entry.foodName);
    if (ingredients.isNotEmpty) {
      _showIngredientSheet(entry.foodName, ingredients);
    } else {
      _showTriviaSnackbar();
    }
  }

  void _showTriviaSnackbar() {
    final tips = [
      '食後30分のウォーキングで血糖値スパイクを抑えられます 🚶',
      'たんぱく質は筋肉だけでなく肌・髪の材料にもなります ✨',
      '野菜から食べると血糖値の急上昇を防げます 🥗',
      '水分補給は代謝アップにも効果的です 💧',
      '腸活には発酵食品＋食物繊維の組み合わせが効果的 🌱',
      '色の濃い野菜ほど栄養価が高い傾向があります 🥦',
    ];
    final tip = tips[DateTime.now().second % tips.length];
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(tip),
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _showIngredientSheet(String foodName, List<FunctionalIngredient> ingredients) {
    if (!mounted) return;
    final primary = Theme.of(context).colorScheme.primary;
    final secondary = Theme.of(context).colorScheme.secondary;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF1a1a2e),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36, height: 4,
                decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(Icons.science_outlined, color: primary, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('$foodName の機能性成分',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...ingredients.map((ing) => Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(ing.emoji, style: const TextStyle(fontSize: 20)),
                      const SizedBox(width: 8),
                      Text(ing.name,
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: primary)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(ing.effect,
                      style: const TextStyle(fontSize: 13, color: Colors.white70, height: 1.4)),
                  if (ing.synergyFoods.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.link, size: 13, color: secondary),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            '相乗効果: ${ing.synergyFoods.join('・')}',
                            style: TextStyle(fontSize: 11, color: secondary),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            )),
          ],
        ),
      ),
    );
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
      _showMealRecordedFeedback(result);
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

  Future<void> _openRestaurant(int mealType) async {
    final result = await Navigator.push<MealEntry>(
      context,
      MaterialPageRoute(
        builder: (_) => RestaurantScreen(date: _today, mealType: mealType),
      ),
    );
    if (result != null) {
      await DatabaseService.instance.insertMeal(result);
      await _load();
      _showMealRecordedFeedback(result);
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
    if (!PurchaseService.instance.isPremium) {
      _showPremiumGate('SNSシェアはプレミアム機能です');
      return;
    }
    await ShareService.shareDaySummary(
      meals: _meals,
      targetKcal: _profile?.targetKcal ?? 2000,
      waterMl: _waterMl,
    );
  }

  void _showPremiumGate(String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('プレミアム機能'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('キャンセル'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.push(ctx,
                  MaterialPageRoute(builder: (_) => const PremiumScreen()));
            },
            child: const Text('プレミアムを見る'),
          ),
        ],
      ),
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
    if (!PurchaseService.instance.isPremium) {
      _showPremiumGate('SNSシェアはプレミアム機能です');
      return;
    }
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

// ─── PFC Chart ─────────────────────────────────────────────────

class _PFCChart extends StatelessWidget {
  final double protein;
  final double fat;
  final double carb;
  final Color primary;
  final Color secondary;

  const _PFCChart({
    required this.protein,
    required this.fat,
    required this.carb,
    required this.primary,
    required this.secondary,
  });

  @override
  Widget build(BuildContext context) {
    final pKcal = protein * 4;
    final fKcal = fat * 9;
    final cKcal = carb * 4;
    final total = pKcal + fKcal + cKcal;
    final mid = Color.lerp(primary, secondary, 0.5)!;

    final isEmpty = total < 1;
    final sections = isEmpty
        ? [PieChartSectionData(value: 1, color: Colors.white12, radius: 18, title: '')]
        : [
            PieChartSectionData(
              value: pKcal,
              color: primary,
              radius: 18,
              title: '',
            ),
            PieChartSectionData(
              value: fKcal,
              color: mid,
              radius: 18,
              title: '',
            ),
            PieChartSectionData(
              value: cKcal,
              color: secondary,
              radius: 18,
              title: '',
            ),
          ];

    return _GlassCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            height: 80,
            child: PieChart(
              PieChartData(
                sections: sections,
                centerSpaceRadius: 26,
                sectionsSpace: 2,
              ),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('PFCバランス',
                    style: TextStyle(fontSize: 12, color: Colors.white54)),
                const SizedBox(height: 8),
                _PFCRow('P たんぱく質', protein, pKcal, total, primary),
                const SizedBox(height: 4),
                _PFCRow('F 脂質', fat, fKcal, total, mid),
                const SizedBox(height: 4),
                _PFCRow('C 炭水化物', carb, cKcal, total, secondary),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PFCRow extends StatelessWidget {
  final String label;
  final double grams;
  final double kcal;
  final double total;
  final Color color;

  const _PFCRow(this.label, this.grams, this.kcal, this.total, this.color);

  @override
  Widget build(BuildContext context) {
    final pct = total > 0 ? (kcal / total * 100).round() : 0;
    return Row(
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Expanded(child: Text(label, style: const TextStyle(fontSize: 11, color: Colors.white70))),
        Text('${grams.round()}g', style: const TextStyle(fontSize: 11, color: Colors.white60)),
        const SizedBox(width: 6),
        Text('$pct%', style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

// ─── Streak Card ───────────────────────────────────────────────

class _StreakCard extends StatelessWidget {
  final int streak;
  final Color primary;
  final Color secondary;

  const _StreakCard({
    required this.streak,
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
            child: const Icon(Icons.local_fire_department, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$streak日',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const Text('継続中', style: TextStyle(fontSize: 11, color: Colors.white54)),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Exercise Card ─────────────────────────────────────────────

class _ExerciseCard extends StatelessWidget {
  final List<ExerciseEntry> exercises;
  final Color primary;
  final Color secondary;
  final double weightKg;
  final String today;
  final VoidCallback onChanged;

  const _ExerciseCard({
    required this.exercises,
    required this.primary,
    required this.secondary,
    required this.weightKg,
    required this.today,
    required this.onChanged,
  });

  Future<void> _addExercise(BuildContext context) async {
    final nameCtrl = TextEditingController();
    int type = 0;
    int duration = 30;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, ss) {
          final kcal = ExerciseEntry.estimateKcal(type, duration, weightKg);
          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
            child: Container(
              decoration: const BoxDecoration(
                color: Color(0xFF1a1a2e),
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 36, height: 4,
                      decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('運動を記録', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
                  const SizedBox(height: 16),
                  TextField(
                    controller: nameCtrl,
                    autofocus: true,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: '例: ランニング、筋トレ',
                      hintStyle: const TextStyle(color: Colors.white38),
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.07),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SegmentedButton<int>(
                    segments: ExerciseEntry.typeNames.asMap().entries.map((e) =>
                      ButtonSegment(value: e.key, label: Text(e.value, style: const TextStyle(fontSize: 11)))
                    ).toList(),
                    selected: {type},
                    onSelectionChanged: (s) => ss(() => type = s.first),
                    style: ButtonStyle(
                      backgroundColor: WidgetStateProperty.resolveWith((states) =>
                        states.contains(WidgetState.selected) ? primary.withValues(alpha: 0.8) : Colors.white.withValues(alpha: 0.07)
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Text('時間: ', style: TextStyle(color: Colors.white70)),
                      Text('$duration分', style: TextStyle(color: primary, fontWeight: FontWeight.w700)),
                    ],
                  ),
                  Slider(
                    value: duration.toDouble(),
                    min: 5,
                    max: 120,
                    divisions: 23,
                    activeColor: primary,
                    onChanged: (v) => ss(() => duration = v.round()),
                  ),
                  Text(
                    '推定消費: ${kcal.round()} kcal',
                    style: TextStyle(color: secondary, fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () async {
                        final name = nameCtrl.text.trim().isEmpty
                            ? ExerciseEntry.typeNames[type]
                            : nameCtrl.text.trim();
                        final entry = ExerciseEntry(
                          date: today,
                          name: name,
                          type: type,
                          durationMin: duration,
                          kcalBurned: ExerciseEntry.estimateKcal(type, duration, weightKg),
                        );
                        await DatabaseService.instance.insertExercise(entry);
                        if (ctx.mounted) Navigator.pop(ctx);
                        onChanged();
                      },
                      child: const Text('記録する', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final totalKcal = exercises.fold(0.0, (s, e) => s + e.kcalBurned);

    return _GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [primary, secondary]),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.directions_run, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text('運動', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
              ),
              if (totalKcal > 0)
                Text('-${totalKcal.round()} kcal',
                    style: TextStyle(fontSize: 13, color: secondary, fontWeight: FontWeight.w600)),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => _addExercise(context),
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.add, color: Colors.white70, size: 16),
                ),
              ),
            ],
          ),
          if (exercises.isNotEmpty) ...[
            const SizedBox(height: 10),
            ...exercises.map((e) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  const SizedBox(width: 4),
                  Icon(Icons.fitness_center, size: 14, color: Colors.white38),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '${e.name}  ${e.durationMin}分',
                      style: const TextStyle(fontSize: 13, color: Colors.white70),
                    ),
                  ),
                  Text('-${e.kcalBurned.round()} kcal',
                      style: const TextStyle(fontSize: 12, color: Colors.white38)),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () async {
                      await DatabaseService.instance.deleteExercise(e.id!);
                      onChanged();
                    },
                    child: const Icon(Icons.close, size: 14, color: Colors.white24),
                  ),
                ],
              ),
            )),
          ] else ...[
            const SizedBox(height: 6),
            const Text('タップ + で運動を追加', style: TextStyle(fontSize: 12, color: Colors.white38)),
          ],
        ],
      ),
    );
  }
}

// ─── Advice Card ───────────────────────────────────────────────

class _AdviceCard extends StatelessWidget {
  final double totalKcal;
  final double targetKcal;
  final double totalProtein;
  final double totalFat;
  final double totalCarb;
  final int streak;
  final Color primary;
  final Color secondary;
  final VoidCallback onChatTap;

  const _AdviceCard({
    required this.totalKcal,
    required this.targetKcal,
    required this.totalProtein,
    required this.totalFat,
    required this.totalCarb,
    required this.streak,
    required this.primary,
    required this.secondary,
    required this.onChatTap,
  });

  ({String emoji, String message, bool isPositive}) _buildAdvice() {
    if (totalKcal < 1) {
      return (emoji: '📝', message: '今日はまだ食事が記録されていません。記録を始めましょう！', isPositive: false);
    }
    final ratio = totalKcal / targetKcal;
    final totalMacroKcal = totalProtein * 4 + totalFat * 9 + totalCarb * 4;
    final proteinRatio = totalMacroKcal > 0 ? (totalProtein * 4) / totalMacroKcal : 0;
    final fatRatio = totalMacroKcal > 0 ? (totalFat * 9) / totalMacroKcal : 0;

    if (streak >= 7) {
      return (emoji: '🔥', message: '$streak日連続記録中！継続は力なりです。', isPositive: true);
    }
    if (ratio > 1.15) {
      return (emoji: '⚠️', message: 'カロリーオーバーです。次の食事は軽めにしてみましょう。', isPositive: false);
    }
    if (ratio >= 0.85 && ratio <= 1.15) {
      if (proteinRatio < 0.15) {
        return (emoji: '💪', message: 'カロリーはいい感じ！たんぱく質をもう少し増やすとより良いです。', isPositive: true);
      }
      if (fatRatio > 0.40) {
        return (emoji: '🥗', message: 'カロリーはいい感じ！脂質が多めなので、野菜も一緒に食べましょう。', isPositive: true);
      }
      return (emoji: '✨', message: 'PFCバランスも良好です！今日は完璧な食事です。', isPositive: true);
    }
    if (ratio < 0.5) {
      return (emoji: '🍽️', message: 'カロリーが少なめです。しっかり食べてエネルギーを補給しましょう。', isPositive: false);
    }
    if (proteinRatio < 0.15) {
      return (emoji: '🥩', message: 'たんぱく質が少なめです。肉・魚・豆腐を意識してみましょう。', isPositive: false);
    }
    return (emoji: '👍', message: '順調に記録できています。この調子で続けましょう！', isPositive: true);
  }

  @override
  Widget build(BuildContext context) {
    final advice = _buildAdvice();
    return _GlassCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Row(
        children: [
          Text(advice.emoji, style: const TextStyle(fontSize: 28)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              advice.message,
              style: const TextStyle(fontSize: 13, color: Colors.white, height: 1.4),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onChatTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [primary.withValues(alpha: 0.7), secondary.withValues(alpha: 0.7)]),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                'AI相談',
                style: TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w600),
              ),
            ),
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
