import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../models/food.dart';
import '../models/meal_entry.dart';
import '../models/my_food.dart';
import '../services/food_search_service.dart';
import '../services/database_service.dart';

class FoodSearchScreen extends StatefulWidget {
  final String date;
  final int mealType;

  const FoodSearchScreen({
    super.key,
    required this.date,
    required this.mealType,
  });

  @override
  State<FoodSearchScreen> createState() => _FoodSearchScreenState();
}

class _FoodSearchScreenState extends State<FoodSearchScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _searchCtrl = TextEditingController();
  List<Food> _builtinResults = [];
  List<MyFood> _myFoodResults = [];
  bool _searching = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    FoodSearchService.instance.init();
  }

  @override
  void dispose() {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('食品を選択'),
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
              onChanged: (q) {
                if (q.length >= 1) {
                  _search(q);
                } else {
                  setState(() {
                    _builtinResults = [];
                    _myFoodResults = [];
                  });
                }
              },
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _BuiltinList(
                  results: _builtinResults,
                  searching: _searching,
                  query: _searchCtrl.text,
                  onSelect: _showPortionDialog,
                  onWebSearch: _openWebSearch,
                ),
                _MyFoodList(
                  results: _myFoodResults,
                  onSelect: _showMyFoodPortionDialog,
                  onAdd: _showAddMyFoodDialog,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showPortionDialog(Food food) async {
    double grams = 100;
    final result = await showDialog<MealEntry>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, ss) => AlertDialog(
          title: Text(food.name),
          content: Column(
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
              const SizedBox(height: 16),
              Row(
                children: [
                  Text('${grams.round()} g',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
              Slider(
                value: grams,
                min: 5,
                max: 500,
                divisions: 99,
                onChanged: (v) => ss(() => grams = v),
              ),
              Wrap(
                spacing: 6,
                children: [50, 100, 150, 200, 300].map((g) {
                  return ActionChip(
                    label: Text('$g g'),
                    onPressed: () => ss(() => grams = g.toDouble()),
                  );
                }).toList(),
              ),
            ],
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
    final result = await showDialog<MealEntry>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, ss) => AlertDialog(
          title: Text(food.name),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                  '${(food.kcalPer100g * grams / 100).round()} kcal',
                  style: const TextStyle(
                      fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Slider(
                value: grams,
                min: 5,
                max: 500,
                divisions: 99,
                label: '${grams.round()} g',
                onChanged: (v) => ss(() => grams = v),
              ),
            ],
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

  Future<void> _openWebSearch(String query) async {
    final entry = await Navigator.push<MealEntry>(
      context,
      MaterialPageRoute(
        builder: (_) => _WebSearchScreen(
          query: '$query カロリー 栄養素',
          date: widget.date,
          mealType: widget.mealType,
        ),
      ),
    );
    if (entry != null && mounted) {
      Navigator.pop(context, entry);
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
              await _search(_searchCtrl.text);
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
  final bool searching;
  final String query;
  final void Function(Food) onSelect;
  final void Function(String) onWebSearch;

  const _BuiltinList({
    required this.results,
    required this.searching,
    required this.query,
    required this.onSelect,
    required this.onWebSearch,
  });

  @override
  Widget build(BuildContext context) {
    if (searching) {
      return const Center(child: CircularProgressIndicator());
    }
    if (results.isEmpty && query.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('データベースに見つかりませんでした'),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => onWebSearch(query),
              icon: const Icon(Icons.search),
              label: const Text('Webで検索する'),
            ),
            const SizedBox(height: 8),
            const Text(
              '⚠️ Web検索の結果は参考値です',
              style: TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
        ),
      );
    }
    return ListView.builder(
      itemCount: results.length,
      itemBuilder: (_, i) {
        final f = results[i];
        return ListTile(
          title: Text(f.name),
          subtitle: Text(
              '${f.kcal.round()} kcal / 100g  P:${f.protein.toStringAsFixed(1)}g'),
          onTap: () => onSelect(f),
        );
      },
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

class _WebSearchScreen extends StatefulWidget {
  final String query;
  final String date;
  final int mealType;

  const _WebSearchScreen({
    required this.query,
    required this.date,
    required this.mealType,
  });

  @override
  State<_WebSearchScreen> createState() => _WebSearchScreenState();
}

class _WebSearchScreenState extends State<_WebSearchScreen> {
  late final WebViewController _controller;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onPageFinished: (_) => setState(() => _loading = false),
      ))
      ..loadRequest(Uri.parse(
          'https://www.google.com/search?q=${Uri.encodeComponent(widget.query)}'));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Web検索'),
        actions: [
          TextButton(
            onPressed: _showManualEntry,
            child: const Text('数値を入力'),
          ),
        ],
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_loading) const Center(child: CircularProgressIndicator()),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '⚠️ Web検索の結果は参考値です。正確な数値は公式サイトでご確認ください。',
                style: TextStyle(fontSize: 11, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _showManualEntry,
                  child: const Text('カロリーを入力して記録する'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showManualEntry() async {
    final nameCtrl = TextEditingController(
        text: widget.query.replaceAll(' カロリー 栄養素', ''));
    final kcalCtrl = TextEditingController();
    final proteinCtrl = TextEditingController();
    final fatCtrl = TextEditingController();
    final carbCtrl = TextEditingController();
    double grams = 100;

    final result = await showDialog<MealEntry>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, ss) => AlertDialog(
          title: const Text('数値を入力'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(labelText: '食品名')),
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
                const SizedBox(height: 12),
                Text('量: ${grams.round()} g',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                Slider(
                  value: grams,
                  min: 5,
                  max: 1000,
                  divisions: 199,
                  onChanged: (v) => ss(() => grams = v),
                ),
                const Text(
                  '⚠️ Webから取得した数値は参考値です。',
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
              onPressed: () {
                final kcalPer100 = double.tryParse(kcalCtrl.text) ?? 0;
                final proteinPer100 =
                    double.tryParse(proteinCtrl.text) ?? 0;
                final fatPer100 = double.tryParse(fatCtrl.text) ?? 0;
                final carbPer100 = double.tryParse(carbCtrl.text) ?? 0;
                final r = grams / 100;
                Navigator.pop(
                  ctx,
                  MealEntry(
                    date: widget.date,
                    mealType: widget.mealType,
                    foodId: 'web_${DateTime.now().millisecondsSinceEpoch}',
                    foodName:
                        nameCtrl.text.isEmpty ? widget.query : nameCtrl.text,
                    grams: grams,
                    kcal: kcalPer100 * r,
                    protein: proteinPer100 * r,
                    fat: fatPer100 * r,
                    carb: carbPer100 * r,
                    fiber: 0,
                    sodium: 0,
                    calcium: 0,
                    iron: 0,
                    isCustom: true,
                  ),
                );
              },
              child: const Text('記録'),
            ),
          ],
        ),
      ),
    );
    if (result != null && mounted) {
      Navigator.pop(context, result);
    }
  }
}
