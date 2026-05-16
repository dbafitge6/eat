import 'package:flutter/material.dart';
import '../models/meal_entry.dart';
import '../services/gemini_service.dart';
import '../services/limit_service.dart';
import '../services/purchase_service.dart';
import '../screens/premium_screen.dart';
import '../widgets/pfc_balance_bar.dart';

class RestaurantScreen extends StatefulWidget {
  final String date;
  final int mealType;

  const RestaurantScreen({
    super.key,
    required this.date,
    required this.mealType,
  });

  @override
  State<RestaurantScreen> createState() => _RestaurantScreenState();
}

class _RestaurantScreenState extends State<RestaurantScreen> {
  final _ctrl = TextEditingController();
  List<RestaurantMenuItem> _suggestions = [];
  bool _loading = false;
  bool _hasApiKey = false;
  String? _error;

  final List<String> _quickTaps = [
    'マクドナルド', 'すき家', 'ガスト', 'サイゼリヤ',
    'ラーメン屋', '定食屋', '回転寿司', 'コンビニ弁当',
  ];

  @override
  void initState() {
    super.initState();
    _checkApiKey();
  }

  Future<void> _checkApiKey() async {
    final key = await GeminiService.instance.getApiKey();
    if (mounted) setState(() => _hasApiKey = key != null && key.isNotEmpty);
  }

  Future<void> _search(String query) async {
    if (query.trim().isEmpty) return;
    FocusScope.of(context).unfocus();

    final canSearch = await LimitService.instance.canSearchRestaurant();
    if (!mounted) return;
    if (!canSearch) {
      _showLimitDialog();
      return;
    }

    setState(() { _loading = true; _error = null; _suggestions = []; });
    await LimitService.instance.incrementRestaurantCount();

    try {
      final items = await GeminiService.instance.searchRestaurantMenu(query.trim());
      items.sort((a, b) => a.kcal.compareTo(b.kcal));
      setState(() { _suggestions = items; _loading = false; });
    } catch (e) {
      setState(() { _loading = false; _error = '提案の取得に失敗しました\n$e'; });
    }
  }

  void _showLimitDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('外食提案の上限に達しました'),
        content: Text(
            '無料プランでは外食メニュー提案は1日${LimitService.freeRestaurantLimit}回までです。\nプレミアムにアップグレードすると無制限に使えます。'),
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

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: const Text('外食メニューを探す'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          if (!PurchaseService.instance.isPremium)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: FutureBuilder<int>(
                future: LimitService.instance.restaurantCountRemaining(),
                builder: (_, snap) {
                  final remaining =
                      snap.data ?? LimitService.freeRestaurantLimit;
                  return Chip(
                    label: Text('残り$remaining回',
                        style: TextStyle(
                            fontSize: 11,
                            color: remaining <= 0
                                ? Colors.white
                                : null)),
                    backgroundColor:
                        remaining <= 0 ? Colors.orange : null,
                    visualDensity: VisualDensity.compact,
                  );
                },
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _ctrl,
                    decoration: InputDecoration(
                      hintText: '例: マクドナルド、ラーメン屋',
                      prefixIcon: const Icon(Icons.restaurant_outlined),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    onSubmitted: _search,
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () => _search(_ctrl.text),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('探す'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          if (!_hasApiKey)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.orange, size: 16),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'この機能にはGemini APIキーが必要です。設定から登録してください。',
                        style: TextStyle(fontSize: 12, color: Colors.orange),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: _quickTaps.map((q) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ActionChip(
                    label: Text(q, style: const TextStyle(fontSize: 12)),
                    onPressed: () { _ctrl.text = q; _search(q); },
                  ),
                )).toList(),
              ),
            ),
          const SizedBox(height: 8),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(_error!, textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.grey, fontSize: 12)),
                        ),
                      )
                    : _suggestions.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.restaurant_menu_outlined,
                                    size: 48, color: primary.withValues(alpha: 0.3)),
                                const SizedBox(height: 12),
                                const Text('飲食店や料理名を入力して検索',
                                    style: TextStyle(color: Colors.grey)),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: _suggestions.length,
                            itemBuilder: (ctx, i) {
                              final item = _suggestions[i];
                              return Card(
                                margin: const EdgeInsets.only(bottom: 8),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(12),
                                  onTap: () {
                                    final entry = MealEntry(
                                      date: widget.date,
                                      mealType: widget.mealType,
                                      foodId: '',
                                      foodName: item.name,
                                      grams: 1,
                                      kcal: item.kcal,
                                      protein: item.protein,
                                      fat: item.fat,
                                      carb: item.carb,
                                      fiber: 0,
                                      sodium: 0,
                                      calcium: 0,
                                      iron: 0,
                                      isCustom: true,
                                    );
                                    Navigator.pop(context, entry);
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(item.name,
                                                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                                            ),
                                            Text('${item.kcal.round()} kcal',
                                                style: TextStyle(
                                                    fontWeight: FontWeight.w700,
                                                    color: primary,
                                                    fontSize: 15)),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            Text(
                                              'P: ${item.protein.round()}g  F: ${item.fat.round()}g  C: ${item.carb.round()}g',
                                              style: const TextStyle(fontSize: 11, color: Colors.grey),
                                            ),
                                            const Spacer(),
                                            const Text('1食分', style: TextStyle(fontSize: 10, color: Colors.grey)),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        PFCBalanceBar(
                                          protein: item.protein,
                                          fat: item.fat,
                                          carb: item.carb,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
}
