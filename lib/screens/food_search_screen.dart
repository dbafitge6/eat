import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../models/food.dart';
import '../models/meal_entry.dart';
import '../models/my_food.dart';
import '../services/food_search_service.dart';
import '../services/gemini_service.dart';
import '../services/database_service.dart';
import '../services/limit_service.dart';
import '../services/purchase_service.dart';
import '../screens/premium_screen.dart';
import '../widgets/pfc_balance_bar.dart';

class FoodSearchScreen extends StatefulWidget {
  final String date;
  final int mealType;
  final int initialTab;

  const FoodSearchScreen({
    super.key,
    required this.date,
    required this.mealType,
    this.initialTab = 0,
  });

  @override
  State<FoodSearchScreen> createState() => _FoodSearchScreenState();
}

class _FoodSearchScreenState extends State<FoodSearchScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _searchCtrl = TextEditingController();
  List<Food> _builtinResults = [];
  List<Food> _aiResults = [];
  List<MyFood> _myFoodResults = [];
  bool _searching = false;
  bool _aiSearching = false;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this, initialIndex: widget.initialTab);
    FoodSearchService.instance.init();
    _loadAllMyFoods();
  }

  Future<void> _loadAllMyFoods() async {
    final all = await DatabaseService.instance.getMyFoods();
    if (!mounted) return;
    setState(() => _myFoodResults = all);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _tabController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _search(String q) async {
    setState(() => _searching = true);
    final builtin = await FoodSearchService.instance.search(q);
    final myFoods = await FoodSearchService.instance.searchMyFoods(q);
    if (!mounted) return;
    setState(() {
      _builtinResults = builtin;
      _myFoodResults = myFoods;
      _searching = false;
    });
  }

  void _onSearchChanged(String q) {
    if (q.isEmpty) {
      _debounceTimer?.cancel();
      setState(() {
        _builtinResults = [];
        _aiResults = [];
        _aiSearching = false;
      });
      _loadAllMyFoods();
      return;
    }

    _search(q);

    // AI検索: 入力時点でスピナーを出し、1秒後に実行
    _debounceTimer?.cancel();
    setState(() {
      _aiResults = [];
      _aiSearching = true;
    });
    _debounceTimer = Timer(const Duration(milliseconds: 1000), () async {
      if (!mounted) return;
      final canSearch = await LimitService.instance.canSearchAI();
      if (!mounted) return;
      if (!canSearch) {
        setState(() => _aiSearching = false);
        _showAILimitDialog();
        return;
      }
      await LimitService.instance.incrementAICount();
      final results = await GeminiService.instance.searchFood(q);
      if (!mounted) return;
      setState(() {
        _aiResults = results;
        _aiSearching = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('食品を選択'),
        actions: [
          if (!PurchaseService.instance.isPremium)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: FutureBuilder<int>(
                future: LimitService.instance.aiCountRemaining(),
                builder: (_, snap) {
                  final remaining = snap.data ?? LimitService.freeAISearchLimit;
                  return Chip(
                    label: Text('AI $remaining回',
                        style: TextStyle(
                            fontSize: 11,
                            color: remaining <= 1
                                ? Colors.white
                                : null)),
                    backgroundColor:
                        remaining <= 1 ? Colors.orange : null,
                    visualDensity: VisualDensity.compact,
                  );
                },
              ),
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'データベース'),
            Tab(text: 'マイ食品'),
          ],
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchCtrl,
              autofocus: true,
              decoration: InputDecoration(
                hintText: '食品名を入力',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() {
                            _builtinResults = [];
                            _myFoodResults = [];
                          });
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
                filled: true,
              ),
              onChanged: _onSearchChanged,
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _BuiltinList(
                  results: _builtinResults,
                  aiResults: _aiResults,
                  searching: _searching,
                  aiSearching: _aiSearching,
                  query: _searchCtrl.text,
                  onSelect: _showPortionDialog,
                  onWebSearch: _openWebSearch,
                  onFavorite: _saveToMyFood,
                ),
                _MyFoodList(
                  results: _myFoodResults,
                  onSelect: _showMyFoodPortionDialog,
                  onAdd: _showAddMyFoodOptions,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showAILimitDialog() {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('AI検索の上限に達しました'),
        content: Text(
            '無料プランではAI食品検索は1日${LimitService.freeAISearchLimit}回までです。\nプレミアムにアップグレードすると無制限に使えます。'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('閉じる')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const PremiumScreen()));
            },
            child: const Text('プレミアムを見る'),
          ),
        ],
      ),
    );
  }

  Future<void> _showPortionDialog(Food food) async {
    double grams = 100;
    final gramsCtrl = TextEditingController(text: '100');
    final result = await showDialog<MealEntry>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, ss) => AlertDialog(
          title: Text(food.name),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('${(food.kcal * grams / 100).round()} kcal',
                    style: const TextStyle(
                        fontSize: 24, fontWeight: FontWeight.bold)),
                Text(
                    'P: ${(food.protein * grams / 100).toStringAsFixed(1)}g  '
                    'F: ${(food.fat * grams / 100).toStringAsFixed(1)}g  '
                    'C: ${(food.carb * grams / 100).toStringAsFixed(1)}g',
                    style: const TextStyle(color: Colors.grey)),
                const SizedBox(height: 12),
                TextField(
                  controller: gramsCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    suffixText: 'g',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (v) {
                    final parsed = double.tryParse(v);
                    if (parsed != null && parsed > 0) ss(() => grams = parsed);
                  },
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  children: [50, 100, 150, 200, 300].map((g) {
                    return ActionChip(
                      label: Text('$g g'),
                      onPressed: () {
                        ss(() => grams = g.toDouble());
                        gramsCtrl.text = g.toString();
                      },
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
              onPressed: () {
                final scaled = food.scaled(grams);
                Navigator.pop(
                  ctx,
                  MealEntry(
                    date: widget.date,
                    mealType: widget.mealType,
                    foodId: food.id,
                    foodName: food.name,
                    grams: grams,
                    kcal: scaled.kcal,
                    protein: scaled.protein,
                    fat: scaled.fat,
                    carb: scaled.carb,
                    fiber: scaled.fiber,
                    sodium: scaled.sodium,
                    calcium: scaled.calcium,
                    iron: scaled.iron,
                  ),
                );
              },
              child: const Text('追加'),
            ),
          ],
        ),
      ),
    );
    if (result != null && mounted) {
      Navigator.pop(context, result);
    }
  }

  Future<void> _showMyFoodPortionDialog(MyFood food) async {
    double grams = 100;
    final gramsCtrl = TextEditingController(text: '100');
    final result = await showDialog<MealEntry>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, ss) => AlertDialog(
          title: Text(food.name),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                    '${(food.kcalPer100g * grams / 100).round()} kcal',
                    style: const TextStyle(
                        fontSize: 24, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                TextField(
                  controller: gramsCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    suffixText: 'g',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (v) {
                    final parsed = double.tryParse(v);
                    if (parsed != null && parsed > 0) ss(() => grams = parsed);
                  },
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  children: [50, 100, 150, 200, 300].map((g) {
                    return ActionChip(
                      label: Text('$g g'),
                      onPressed: () {
                        ss(() => grams = g.toDouble());
                        gramsCtrl.text = g.toString();
                      },
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
              onPressed: () {
                final r = grams / 100;
                Navigator.pop(
                  ctx,
                  MealEntry(
                    date: widget.date,
                    mealType: widget.mealType,
                    foodId: 'my_${food.id}',
                    foodName: food.name,
                    grams: grams,
                    kcal: food.kcalPer100g * r,
                    protein: food.proteinPer100g * r,
                    fat: food.fatPer100g * r,
                    carb: food.carbPer100g * r,
                    fiber: food.fiberPer100g * r,
                    sodium: food.sodiumPer100g * r,
                    calcium: food.calciumPer100g * r,
                    iron: food.ironPer100g * r,
                    isCustom: true,
                  ),
                );
              },
              child: const Text('追加'),
            ),
          ],
        ),
      ),
    );
    if (result != null && mounted) {
      Navigator.pop(context, result);
    }
  }

  Future<void> _saveToMyFood(Food food) async {
    await DatabaseService.instance.insertMyFood(MyFood(
      name: food.name,
      kcalPer100g: food.kcal,
      proteinPer100g: food.protein,
      fatPer100g: food.fat,
      carbPer100g: food.carb,
      fiberPer100g: food.fiber,
      sodiumPer100g: food.sodium,
      calciumPer100g: food.calcium,
      ironPer100g: food.iron,
    ));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('「${food.name}」をマイ食品に登録しました'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _openWebSearch(String query) async {
    final entry = await Navigator.push<MealEntry>(
      context,
      MaterialPageRoute(
        builder: (_) => WebSearchScreen(
          query: '$query カロリー 栄養素',
          date: widget.date,
          mealType: widget.mealType,
          foodName: query,
        ),
      ),
    );
    if (entry != null && mounted) {
      Navigator.pop(context, entry);
    }
  }

  Future<void> _showAddMyFoodOptions() async {
    await showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_note),
              title: const Text('手動で入力'),
              onTap: () {
                Navigator.pop(ctx);
                _showAddMyFoodDialog();
              },
            ),
            ListTile(
              leading: const Icon(Icons.search),
              title: const Text('Webで検索して登録'),
              onTap: () {
                Navigator.pop(ctx);
                _openMyFoodWebSearch();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openMyFoodWebSearch() async {
    final queryCtrl = TextEditingController();
    final query = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('何を検索しますか？'),
        content: TextField(
          controller: queryCtrl,
          autofocus: true,
          decoration: const InputDecoration(hintText: '食品名を入力', border: OutlineInputBorder()),
          onSubmitted: (v) => Navigator.pop(ctx, v),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('キャンセル')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, queryCtrl.text),
            child: const Text('検索'),
          ),
        ],
      ),
    );
    if (query == null || query.isEmpty || !mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MyFoodWebSearchScreen(query: '$query カロリー 栄養素'),
      ),
    );
    if (_searchCtrl.text.isEmpty) {
      await _loadAllMyFoods();
    } else {
      await _search(_searchCtrl.text);
    }
  }

  Future<void> _showAddMyFoodDialog() async {
    final nameCtrl = TextEditingController();
    final kcalCtrl = TextEditingController();
    final proteinCtrl = TextEditingController();
    final fatCtrl = TextEditingController();
    final carbCtrl = TextEditingController();
    final noteCtrl = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('マイ食品を登録'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                  controller: nameCtrl,
                  decoration:
                      const InputDecoration(labelText: '食品名 *')),
              TextField(
                  controller: kcalCtrl,
                  decoration:
                      const InputDecoration(labelText: 'カロリー (kcal/100g) *'),
                  keyboardType: TextInputType.number),
              TextField(
                  controller: proteinCtrl,
                  decoration: const InputDecoration(
                      labelText: 'たんぱく質 (g/100g)'),
                  keyboardType: TextInputType.number),
              TextField(
                  controller: fatCtrl,
                  decoration:
                      const InputDecoration(labelText: '脂質 (g/100g)'),
                  keyboardType: TextInputType.number),
              TextField(
                  controller: carbCtrl,
                  decoration:
                      const InputDecoration(labelText: '炭水化物 (g/100g)'),
                  keyboardType: TextInputType.number),
              TextField(
                  controller: noteCtrl,
                  decoration: const InputDecoration(
                      labelText: 'メモ (参考値の場合はその旨記載)')),
              const SizedBox(height: 8),
              const Text(
                '⚠️ Web検索で取得した数値を入力する場合、参考値となります。正確な数値は公式サイトをご確認ください。',
                style: TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('キャンセル')),
          ElevatedButton(
            onPressed: () async {
              if (nameCtrl.text.isEmpty || kcalCtrl.text.isEmpty) return;
              final food = MyFood(
                name: nameCtrl.text,
                kcalPer100g: double.tryParse(kcalCtrl.text) ?? 0,
                proteinPer100g: double.tryParse(proteinCtrl.text) ?? 0,
                fatPer100g: double.tryParse(fatCtrl.text) ?? 0,
                carbPer100g: double.tryParse(carbCtrl.text) ?? 0,
                fiberPer100g: 0,
                sodiumPer100g: 0,
                calciumPer100g: 0,
                ironPer100g: 0,
                note: noteCtrl.text.isEmpty ? null : noteCtrl.text,
              );
              await DatabaseService.instance.insertMyFood(food);
              if (ctx.mounted) Navigator.pop(ctx);
              if (_searchCtrl.text.isEmpty) {
                await _loadAllMyFoods();
              } else {
                await _search(_searchCtrl.text);
              }
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }
}

class _BuiltinList extends StatelessWidget {
  final List<Food> results;
  final List<Food> aiResults;
  final bool searching;
  final bool aiSearching;
  final String query;
  final void Function(Food) onSelect;
  final void Function(String) onWebSearch;
  final void Function(Food) onFavorite;

  const _BuiltinList({
    required this.results,
    required this.aiResults,
    required this.searching,
    required this.aiSearching,
    required this.query,
    required this.onSelect,
    required this.onWebSearch,
    required this.onFavorite,
  });

  @override
  Widget build(BuildContext context) {
    if (searching) {
      return const Center(child: CircularProgressIndicator());
    }

    final hasQuery = query.isNotEmpty;
    final hasBuiltin = results.isNotEmpty;
    final hasAi = aiResults.isNotEmpty;

    return ListView(
      children: [
        // DB not found メッセージ
        if (!hasBuiltin && hasQuery)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Text(
              'データベースに見つかりませんでした',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
            ),
          ),

        // DB results
        if (hasBuiltin) ...[
          ...results.map((f) => ListTile(
            title: Text(f.name),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${f.kcal.round()} kcal / 100g  P:${f.protein.toStringAsFixed(1)}g'),
                const SizedBox(height: 4),
                PFCBalanceBar(protein: f.protein, fat: f.fat, carb: f.carb),
              ],
            ),
            isThreeLine: true,
            trailing: IconButton(
              icon: const Icon(Icons.favorite_border, size: 20, color: Colors.pinkAccent),
              onPressed: () => onFavorite(f),
              tooltip: 'マイ食品に登録',
            ),
            onTap: () => onSelect(f),
          )),
        ],

        // Web search button when DB empty
        if (!hasBuiltin && hasQuery) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: ElevatedButton.icon(
              onPressed: () => onWebSearch(query),
              icon: const Icon(Icons.search),
              label: const Text('Webで検索する'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey.shade600,
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ],

        // AI results section
        if (hasQuery) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              children: [
                const Text(
                  'AI提案',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(width: 8),
                if (aiSearching)
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
          ),
          if (hasAi)
            ...aiResults.map((f) => ListTile(
              leading: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Theme.of(context).colorScheme.primary,
                      Theme.of(context).colorScheme.secondary,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.auto_awesome, color: Colors.white, size: 18),
              ),
              title: Text(f.name),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${f.kcal.round()} kcal / 100g  P:${f.protein.toStringAsFixed(1)}g  ※AI推定値'),
                  const SizedBox(height: 4),
                  PFCBalanceBar(protein: f.protein, fat: f.fat, carb: f.carb),
                ],
              ),
              isThreeLine: true,
              trailing: IconButton(
                icon: const Icon(Icons.favorite_border, size: 20, color: Colors.pinkAccent),
                onPressed: () => onFavorite(f),
                tooltip: 'マイ食品に登録',
              ),
              onTap: () => onSelect(f),
            )),
          if (!hasAi && !aiSearching)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Text(
                '設定画面でGemini APIキーを登録するとAI提案が表示されます',
                style: TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Text(
              '※ AI提案の数値は推定値です。正確な情報は公式サイトをご確認ください。',
              style: TextStyle(fontSize: 10, color: Colors.grey),
            ),
          ),
        ],
      ],
    );
  }
}

class _MyFoodList extends StatelessWidget {
  final List<MyFood> results;
  final void Function(MyFood) onSelect;
  final VoidCallback onAdd;

  const _MyFoodList({
    required this.results,
    required this.onSelect,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              label: const Text('マイ食品を追加'),
            ),
          ),
        ),
        Expanded(
          child: results.isEmpty
              ? const Center(child: Text('マイ食品がありません'))
              : ListView.builder(
                  itemCount: results.length,
                  itemBuilder: (_, i) {
                    final f = results[i];
                    return ListTile(
                      title: Text(f.name),
                      subtitle: Text(
                          '${f.kcalPer100g.round()} kcal / 100g${f.note != null ? '  ⚠️参考値' : ''}'),
                      onTap: () => onSelect(f),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class WebSearchScreen extends StatefulWidget {
  final String query;
  final String date;
  final int mealType;
  final String? foodName;

  const WebSearchScreen({
    super.key,
    required this.query,
    required this.date,
    required this.mealType,
    this.foodName,
  });

  @override
  State<WebSearchScreen> createState() => _WebSearchScreenState();
}

class _WebSearchScreenState extends State<WebSearchScreen> {
  late final WebViewController _controller;
  bool _loading = true;
  bool _aiLoading = false;
  bool _aiPrefilled = false;

  late final TextEditingController _nameCtrl;
  final _kcalCtrl = TextEditingController();
  final _proteinCtrl = TextEditingController();
  final _fatCtrl = TextEditingController();
  final _carbCtrl = TextEditingController();
  final _gramsCtrl = TextEditingController(text: '100');
  bool _saveToMyFood = false;
  bool _extracting = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(
        text: widget.foodName ?? widget.query.replaceAll(' カロリー 栄養素', ''));
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onPageFinished: (_) => setState(() => _loading = false),
      ))
      ..loadRequest(Uri.parse(
          'https://www.google.com/search?q=${Uri.encodeComponent(widget.query)}'));

    if (widget.foodName != null) _prefillWithAi(widget.foodName!);
  }

  Future<void> _prefillWithAi(String name) async {
    final apiKey = await GeminiService.instance.getApiKey();
    if (apiKey == null || !mounted) return;
    setState(() => _aiLoading = true);
    final foods = await GeminiService.instance.searchFood(name);
    if (!mounted) return;
    if (foods.isNotEmpty) {
      final f = foods.first;
      setState(() {
        _kcalCtrl.text = f.kcal.round().toString();
        if (f.protein > 0) _proteinCtrl.text = f.protein.toStringAsFixed(1);
        if (f.fat > 0) _fatCtrl.text = f.fat.toStringAsFixed(1);
        if (f.carb > 0) _carbCtrl.text = f.carb.toStringAsFixed(1);
        _aiPrefilled = true;
        _aiLoading = false;
      });
    } else {
      setState(() => _aiLoading = false);
    }
  }

  Future<void> _pasteAndExtract() async {
    final apiKey = await GeminiService.instance.getApiKey();
    if (!mounted) return;
    if (apiKey == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('設定でGemini APIキーを登録してください')),
      );
      return;
    }

    final pasteCtrl = TextEditingController();
    final submitted = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('栄養素テキストを貼り付け'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'ページ上の栄養素が書かれた部分をコピーして貼り付けてください。\nGeminiが自動で解析します。',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: pasteCtrl,
              maxLines: 5,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: '例: エネルギー 250kcal タンパク質 5g 脂質 3g 炭水化物 48g',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('キャンセル'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('解析'),
          ),
        ],
      ),
    );

    if (submitted != true || pasteCtrl.text.trim().isEmpty || !mounted) return;

    setState(() => _extracting = true);
    try {
      final nutrition = await GeminiService.instance
          .extractNutritionFromText(pasteCtrl.text.trim());
      if (!mounted) return;
      if (nutrition != null && (nutrition['kcal'] ?? 0) > 0) {
        setState(() {
          _kcalCtrl.text = (nutrition['kcal'] ?? 0).round().toString();
          final p = nutrition['protein'] ?? 0;
          final f = nutrition['fat'] ?? 0;
          final c = nutrition['carb'] ?? 0;
          if (p > 0) _proteinCtrl.text = p.toStringAsFixed(1);
          if (f > 0) _fatCtrl.text = f.toStringAsFixed(1);
          if (c > 0) _carbCtrl.text = c.toStringAsFixed(1);
          _aiPrefilled = true;
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('栄養素を解析できませんでした')),
        );
      }
    } finally {
      if (mounted) setState(() => _extracting = false);
    }
  }

  Future<void> _aiEstimate() async {
    final apiKey = await GeminiService.instance.getApiKey();
    if (!mounted) return;
    if (apiKey == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('設定でGemini APIキーを登録してください')),
      );
      return;
    }
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('先に食品名を入力してください')),
      );
      return;
    }
    setState(() => _extracting = true);
    try {
      final foods = await GeminiService.instance.searchFood(name);
      if (!mounted) return;
      if (foods.isNotEmpty) {
        final f = foods.first;
        setState(() {
          _kcalCtrl.text = f.kcal.round().toString();
          if (f.protein > 0) _proteinCtrl.text = f.protein.toStringAsFixed(1);
          if (f.fat > 0) _fatCtrl.text = f.fat.toStringAsFixed(1);
          if (f.carb > 0) _carbCtrl.text = f.carb.toStringAsFixed(1);
          _aiPrefilled = true;
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('AIで推定できませんでした。📋で貼り付けてください')),
        );
      }
    } finally {
      if (mounted) setState(() => _extracting = false);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _kcalCtrl.dispose();
    _proteinCtrl.dispose();
    _fatCtrl.dispose();
    _carbCtrl.dispose();
    _gramsCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      appBar: AppBar(
        title: const Text('Web検索'),
        actions: [
          if (_extracting)
            const Padding(
              padding: EdgeInsets.all(12),
              child: SizedBox(
                  width: 20, height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
            )
          else ...[
            IconButton(
              icon: const Icon(Icons.auto_awesome),
              tooltip: '食品名でAI推定',
              onPressed: _aiEstimate,
            ),
            IconButton(
              icon: const Icon(Icons.content_paste),
              tooltip: '栄養素テキストを貼り付けて解析',
              onPressed: _pasteAndExtract,
            ),
          ],
        ],
      ),
      body: Column(
        children: [
          // 上: WebView
          Expanded(
            flex: 11,
            child: Stack(
              children: [
                WebViewWidget(controller: _controller),
                if (_loading)
                  const Center(child: CircularProgressIndicator()),
              ],
            ),
          ),
          // 仕切り
          Container(
            width: double.infinity,
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade400,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
          // 下: 入力フォーム
          Expanded(
            flex: 9,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_aiLoading)
                    const Row(children: [
                      SizedBox(width: 12, height: 12,
                          child: CircularProgressIndicator(strokeWidth: 2)),
                      SizedBox(width: 8),
                      Text('AIで栄養素を推定中...',
                          style: TextStyle(fontSize: 11, color: Colors.grey)),
                    ])
                  else if (_aiPrefilled)
                    const Text('✨ AI推定値を入力しました。上のサイトで確認・修正してください。',
                        style: TextStyle(fontSize: 11, color: Colors.amber))
                  else
                    const Text('⚠️ 参考値です。上のサイトで確認した数値を入力してください。',
                        style: TextStyle(fontSize: 11, color: Colors.grey)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _nameCtrl,
                    decoration: const InputDecoration(
                      labelText: '食品名',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // kcal + たんぱく質
                  Row(children: [
                    Expanded(
                      child: TextField(
                        controller: _kcalCtrl,
                        decoration: const InputDecoration(
                          labelText: 'kcal *',
                          isDense: true,
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _proteinCtrl,
                        decoration: const InputDecoration(
                          labelText: 'たんぱく質g (任意)',
                          isDense: true,
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ]),
                  const SizedBox(height: 8),
                  // 脂質 + 炭水化物
                  Row(children: [
                    Expanded(
                      child: TextField(
                        controller: _fatCtrl,
                        decoration: const InputDecoration(
                          labelText: '脂質g (任意)',
                          isDense: true,
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _carbCtrl,
                        decoration: const InputDecoration(
                          labelText: '炭水化物g (任意)',
                          isDense: true,
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ]),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _gramsCtrl,
                    decoration: const InputDecoration(
                      labelText: 'グラム数',
                      suffixText: 'g',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    children: [50, 100, 150, 200, 300, 500].map((g) {
                      return ActionChip(
                        label: Text('$g g'),
                        onPressed: () => setState(() => _gramsCtrl.text = g.toString()),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 4),
                  CheckboxListTile(
                    title: const Text('マイ食品に保存', style: TextStyle(fontSize: 13)),
                    value: _saveToMyFood,
                    onChanged: (v) => setState(() => _saveToMyFood = v ?? false),
                    controlAffinity: ListTileControlAffinity.leading,
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                  const SizedBox(height: 4),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _kcalCtrl.text.isEmpty ? null : _record,
                      child: const Text('記録する'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _record() async {
    final name = _nameCtrl.text.isEmpty
        ? widget.query.replaceAll(' カロリー 栄養素', '')
        : _nameCtrl.text;
    final grams = double.tryParse(_gramsCtrl.text) ?? 100;
    final kcal = double.tryParse(_kcalCtrl.text) ?? 0;
    final protein = double.tryParse(_proteinCtrl.text) ?? 0;
    final fat = double.tryParse(_fatCtrl.text) ?? 0;
    final carb = double.tryParse(_carbCtrl.text) ?? 0;

    if (_saveToMyFood) {
      final ratio = grams > 0 ? 100 / grams : 1.0;
      await DatabaseService.instance.insertMyFood(MyFood(
        name: name,
        kcalPer100g: kcal * ratio,
        proteinPer100g: protein * ratio,
        fatPer100g: fat * ratio,
        carbPer100g: carb * ratio,
        fiberPer100g: 0,
        sodiumPer100g: 0,
        calciumPer100g: 0,
        ironPer100g: 0,
        note: '⚠️参考値',
      ));
    }

    if (!mounted) return;
    Navigator.pop(
      context,
      MealEntry(
        date: widget.date,
        mealType: widget.mealType,
        foodId: 'web_${DateTime.now().millisecondsSinceEpoch}',
        foodName: name,
        grams: grams,
        kcal: kcal,
        protein: protein,
        fat: fat,
        carb: carb,
        fiber: 0,
        sodium: 0,
        calcium: 0,
        iron: 0,
        isCustom: true,
      ),
    );
  }
}

class MyFoodWebSearchScreen extends StatefulWidget {
  final String query;
  const MyFoodWebSearchScreen({super.key, required this.query});

  @override
  State<MyFoodWebSearchScreen> createState() => _MyFoodWebSearchScreenState();
}

class _MyFoodWebSearchScreenState extends State<MyFoodWebSearchScreen> {
  late final WebViewController _controller;
  bool _loading = true;

  late final TextEditingController _nameCtrl;
  final _kcalCtrl = TextEditingController();
  final _proteinCtrl = TextEditingController();
  final _fatCtrl = TextEditingController();
  final _carbCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(
        text: widget.query.replaceAll(' カロリー 栄養素', ''));
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onPageFinished: (_) => setState(() => _loading = false),
      ))
      ..loadRequest(Uri.parse(
          'https://www.google.com/search?q=${Uri.encodeComponent(widget.query)}'));
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _kcalCtrl.dispose();
    _proteinCtrl.dispose();
    _fatCtrl.dispose();
    _carbCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('マイ食品をWeb検索で追加')),
      body: Column(
        children: [
          Expanded(
            flex: 11,
            child: Stack(
              children: [
                WebViewWidget(controller: _controller),
                if (_loading) const Center(child: CircularProgressIndicator()),
              ],
            ),
          ),
          Container(
            width: double.infinity,
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Center(
              child: Container(
                width: 36, height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade400,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
          Expanded(
            flex: 9,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '⚠️ 参考値です。100gあたりの数値を入力してください。',
                    style: TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _nameCtrl,
                    decoration: const InputDecoration(
                      labelText: '食品名',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(
                      child: TextField(
                        controller: _kcalCtrl,
                        decoration: const InputDecoration(
                          labelText: 'kcal/100g *',
                          isDense: true,
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _proteinCtrl,
                        decoration: const InputDecoration(
                          labelText: 'たんぱく質g/100g',
                          isDense: true,
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(
                      child: TextField(
                        controller: _fatCtrl,
                        decoration: const InputDecoration(
                          labelText: '脂質g/100g',
                          isDense: true,
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _carbCtrl,
                        decoration: const InputDecoration(
                          labelText: '炭水化物g/100g',
                          isDense: true,
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _kcalCtrl.text.isEmpty ? null : _save,
                      child: const Text('マイ食品に保存'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    await DatabaseService.instance.insertMyFood(MyFood(
      name: _nameCtrl.text.isEmpty
          ? widget.query.replaceAll(' カロリー 栄養素', '')
          : _nameCtrl.text,
      kcalPer100g: double.tryParse(_kcalCtrl.text) ?? 0,
      proteinPer100g: double.tryParse(_proteinCtrl.text) ?? 0,
      fatPer100g: double.tryParse(_fatCtrl.text) ?? 0,
      carbPer100g: double.tryParse(_carbCtrl.text) ?? 0,
      fiberPer100g: 0,
      sodiumPer100g: 0,
      calciumPer100g: 0,
      ironPer100g: 0,
      note: '⚠️参考値',
    ));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('「${_nameCtrl.text}」をマイ食品に保存しました'),
        duration: const Duration(seconds: 2),
      ),
    );
    Navigator.pop(context);
  }
}
