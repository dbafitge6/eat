import 'package:flutter/material.dart';
import '../models/my_set.dart';
import '../models/meal_entry.dart';
import '../services/database_service.dart';
import 'food_search_screen.dart';

class MySetScreen extends StatefulWidget {
  final String date;
  final int mealType;

  const MySetScreen({super.key, required this.date, required this.mealType});

  @override
  State<MySetScreen> createState() => _MySetScreenState();
}

class _MySetScreenState extends State<MySetScreen> {
  List<MySet> _sets = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final sets = await DatabaseService.instance.getMySets();
    if (mounted) setState(() => _sets = sets);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('マイセット'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _createSet,
          ),
        ],
      ),
      body: _sets.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('マイセットがありません'),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _createSet,
                    icon: const Icon(Icons.add),
                    label: const Text('セットを作成'),
                  ),
                ],
              ),
            )
          : ListView.builder(
              itemCount: _sets.length,
              itemBuilder: (_, i) {
                final set = _sets[i];
                return Card(
                  margin: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  child: ListTile(
                    title: Text(set.name,
                        style:
                            const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(
                        '${set.items.length}品目 / ${set.totalKcal.round()} kcal\n'
                        'P: ${set.totalProtein.toStringAsFixed(1)}g  '
                        'F: ${set.totalFat.toStringAsFixed(1)}g  '
                        'C: ${set.totalCarb.toStringAsFixed(1)}g'),
                    isThreeLine: true,
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => _deleteSet(set.id!),
                        ),
                        ElevatedButton(
                          onPressed: () => _addToMeal(set),
                          child: const Text('追加'),
                        ),
                      ],
                    ),
                    onTap: () => _showSetDetail(set),
                  ),
                );
              },
            ),
    );
  }

  Future<void> _createSet() async {
    final nameCtrl = TextEditingController();
    final items = <MySetItem>[];

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _CreateSetSheet(
        nameCtrl: nameCtrl,
        items: items,
        date: widget.date,
        mealType: widget.mealType,
        onSave: () async {
          if (nameCtrl.text.isEmpty || items.isEmpty) return;
          await DatabaseService.instance
              .insertMySet(MySet(name: nameCtrl.text, items: items));
          await _load();
          if (ctx.mounted) Navigator.pop(ctx);
        },
      ),
    );
  }

  Future<void> _deleteSet(int id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('セットを削除'),
        content: const Text('このセットを削除しますか？'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('キャンセル')),
          ElevatedButton(
            style:
                ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child:
                const Text('削除', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await DatabaseService.instance.deleteMySet(id);
      await _load();
    }
  }

  Future<void> _addToMeal(MySet set) async {
    final entries = set.items
        .map((item) => MealEntry(
              date: widget.date,
              mealType: widget.mealType,
              foodId: item.foodId,
              foodName: item.foodName,
              grams: item.grams,
              kcal: item.kcal,
              protein: item.protein,
              fat: item.fat,
              carb: item.carb,
              fiber: 0,
              sodium: 0,
              calcium: 0,
              iron: 0,
            ))
        .toList();

    for (final entry in entries) {
      await DatabaseService.instance.insertMeal(entry);
    }
    if (mounted) {
      Navigator.pop(context, entries.first);
    }
  }

  void _showSetDetail(MySet set) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(set.name,
              style: const TextStyle(
                  fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('合計: ${set.totalKcal.round()} kcal',
              style: const TextStyle(color: Colors.grey)),
          const Divider(),
          ...set.items.map((item) => ListTile(
                dense: true,
                title: Text(item.foodName),
                subtitle: Text('${item.grams.round()}g'),
                trailing: Text('${item.kcal.round()} kcal'),
              )),
        ],
      ),
    );
  }
}

class _CreateSetSheet extends StatefulWidget {
  final TextEditingController nameCtrl;
  final List<MySetItem> items;
  final String date;
  final int mealType;
  final VoidCallback onSave;

  const _CreateSetSheet({
    required this.nameCtrl,
    required this.items,
    required this.date,
    required this.mealType,
    required this.onSave,
  });

  @override
  State<_CreateSetSheet> createState() => _CreateSetSheetState();
}

class _CreateSetSheetState extends State<_CreateSetSheet> {
  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      expand: false,
      builder: (ctx, scrollCtrl) => Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('セット名',
                style: TextStyle(fontWeight: FontWeight.bold)),
            TextField(
              controller: widget.nameCtrl,
              decoration:
                  const InputDecoration(hintText: '例: いつもの朝ごはん'),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('食品リスト',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                TextButton.icon(
                  onPressed: _addFood,
                  icon: const Icon(Icons.add),
                  label: const Text('追加'),
                ),
              ],
            ),
            Expanded(
              child: widget.items.isEmpty
                  ? const Center(
                      child: Text('食品を追加してください',
                          style: TextStyle(color: Colors.grey)))
                  : ListView.builder(
                      controller: scrollCtrl,
                      itemCount: widget.items.length,
                      itemBuilder: (_, i) {
                        final item = widget.items[i];
                        return ListTile(
                          dense: true,
                          title: Text(item.foodName),
                          subtitle: Text('${item.grams.round()}g'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('${item.kcal.round()} kcal'),
                              IconButton(
                                icon: const Icon(Icons.close, size: 16),
                                onPressed: () {
                                  setState(() => widget.items.removeAt(i));
                                },
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: widget.onSave,
                child: const Text('セットを保存'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _addFood() async {
    final entry = await Navigator.push<MealEntry>(
      context,
      MaterialPageRoute(
        builder: (_) => FoodSearchScreen(
          date: widget.date,
          mealType: widget.mealType,
        ),
      ),
    );
    if (entry != null) {
      setState(() {
        widget.items.add(MySetItem(
          foodId: entry.foodId,
          foodName: entry.foodName,
          grams: entry.grams,
          kcal: entry.kcal,
          protein: entry.protein,
          fat: entry.fat,
          carb: entry.carb,
        ));
      });
    }
  }
}
