import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/gemini_service.dart';
import '../services/food_search_service.dart';
import '../services/database_service.dart';
import '../models/meal_entry.dart';
import '../models/food.dart';

class FoodPhotoScreen extends StatefulWidget {
  final String date;
  final int mealType;
  final VoidCallback onMealAdded;

  const FoodPhotoScreen({
    super.key,
    required this.date,
    required this.mealType,
    required this.onMealAdded,
  });

  @override
  State<FoodPhotoScreen> createState() => _FoodPhotoScreenState();
}

class _FoodPhotoScreenState extends State<FoodPhotoScreen> {
  File? _image;
  bool _analyzing = false;
  List<RecognizedFood> _recognized = [];
  String? _errorMsg;

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: source,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 85,
    );
    if (picked == null) return;
    final file = File(picked.path);
    setState(() {
      _image = file;
      _recognized = [];
      _errorMsg = null;
    });
    await _analyze(file);
  }

  Future<void> _analyze(File file) async {
    setState(() => _analyzing = true);
    try {
      final foods = await GeminiService.instance.recognizeFoodsFromImage(file);
      setState(() {
        _recognized = foods;
        _analyzing = false;
      });
    } catch (e) {
      setState(() {
        _errorMsg = 'AIによる解析に失敗しました。手動で食材を追加してください。';
        _analyzing = false;
      });
    }
  }

  Future<void> _confirm() async {
    final confirmed = _recognized.where((f) => f.isConfirmed).toList();
    if (confirmed.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('食材を1つ以上チェックしてください')),
      );
      return;
    }

    for (final rf in confirmed) {
      // 食品DBで検索
      final foods = await FoodSearchService.instance.search(rf.name);
      Food? food;
      if (foods.isNotEmpty) {
        food = foods.first;
      } else {
        // DBになければAI推定値を使う
        food = Food(
          id: 'photo_${rf.name}',
          name: rf.name,
          kcal: rf.estimatedKcal,
          protein: rf.estimatedProtein,
          fat: rf.estimatedFat,
          carb: rf.estimatedCarb,
          fiber: 0,
          sodium: 0,
          calcium: 0,
          iron: 0,
        );
      }

      final grams = rf.estimatedAmountG;
      final ratio = grams / 100.0;
      final entry = MealEntry(
        date: widget.date,
        mealType: widget.mealType,
        foodId: food.id,
        foodName: food.name,
        grams: grams,
        kcal: food.kcal * ratio,
        protein: food.protein * ratio,
        fat: food.fat * ratio,
        carb: food.carb * ratio,
        fiber: food.fiber * ratio,
        sodium: food.sodium * ratio,
        calcium: food.calcium * ratio,
        iron: food.iron * ratio,
      );
      await DatabaseService.instance.insertMeal(entry);
    }

    if (!mounted) return;
    widget.onMealAdded();
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${confirmed.length}件の食材を記録しました')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;
    final textColor = isDark ? Colors.white : const Color(0xFF1a1a1a);

    return Scaffold(
      appBar: AppBar(
        title: const Text('写真から食事を記録'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // 撮影エリア
          if (_image == null) ...[
            Text(
              '食事の写真を撮影またはアルバムから選択',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: textColor,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _PhotoButton(
                    icon: Icons.camera_alt,
                    label: 'カメラで撮影',
                    primary: cs.primary,
                    onTap: () => _pickImage(ImageSource.camera),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _PhotoButton(
                    icon: Icons.photo_library,
                    label: 'アルバムから選択',
                    primary: cs.secondary,
                    onTap: () => _pickImage(ImageSource.gallery),
                  ),
                ),
              ],
            ),
          ] else ...[
            // プレビュー
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.file(
                _image!,
                height: 220,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () => setState(() {
                _image = null;
                _recognized = [];
              }),
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('撮り直す'),
            ),
          ],

          const SizedBox(height: 20),

          // 解析中
          if (_analyzing)
            const Center(
              child: Column(
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 12),
                  Text('AIが食材を解析しています...'),
                ],
              ),
            ),

          // エラー
          if (_errorMsg != null)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(_errorMsg!,
                  style: const TextStyle(color: Colors.red, fontSize: 13)),
            ),

          // 認識結果
          if (_recognized.isNotEmpty) ...[
            Text(
              'AIが検出した食材',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: textColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'チェックした食材を記録します。量を調整できます。',
              style: TextStyle(
                  fontSize: 12, color: textColor.withValues(alpha: 0.6)),
            ),
            const SizedBox(height: 12),
            ..._recognized.asMap().entries.map((e) {
              final idx = e.key;
              final food = e.value;
              return _RecognizedFoodRow(
                food: food,
                onToggle: (v) => setState(() => _recognized[idx].isConfirmed = v),
                onAmountChanged: (g) =>
                    setState(() => _recognized[idx].estimatedAmountG = g),
              );
            }),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _confirm,
              style: ElevatedButton.styleFrom(
                backgroundColor: cs.primary,
                minimumSize: const Size.fromHeight(50),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: const Text(
                'これで記録する',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.white),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PhotoButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color primary;
  final VoidCallback onTap;

  const _PhotoButton({
    required this.icon,
    required this.label,
    required this.primary,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 100,
        decoration: BoxDecoration(
          color: primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: primary.withValues(alpha: 0.3)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: primary, size: 32),
            const SizedBox(height: 8),
            Text(label,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: primary)),
          ],
        ),
      ),
    );
  }
}

class _RecognizedFoodRow extends StatefulWidget {
  final RecognizedFood food;
  final ValueChanged<bool> onToggle;
  final ValueChanged<double> onAmountChanged;

  const _RecognizedFoodRow({
    required this.food,
    required this.onToggle,
    required this.onAmountChanged,
  });

  @override
  State<_RecognizedFoodRow> createState() => _RecognizedFoodRowState();
}

class _RecognizedFoodRowState extends State<_RecognizedFoodRow> {
  late TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(
        text: widget.food.estimatedAmountG.round().toString());
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF1a1a1a);
    final isLow = widget.food.confidence < 0.6;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.06)
            : Colors.black.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: widget.food.isConfirmed
              ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.4)
              : Colors.transparent,
        ),
      ),
      child: Row(
        children: [
          Checkbox(
            value: widget.food.isConfirmed,
            onChanged: (v) => widget.onToggle(v ?? false),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      widget.food.name,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: textColor,
                      ),
                    ),
                    if (isLow) ...[
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          '確信度低',
                          style: TextStyle(fontSize: 10, color: Colors.orange),
                        ),
                      ),
                    ],
                  ],
                ),
                Text(
                  '信頼度 ${(widget.food.confidence * 100).round()}%',
                  style: TextStyle(
                    fontSize: 11,
                    color: textColor.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 64,
            child: TextField(
              controller: _ctrl,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: textColor),
              decoration: InputDecoration(
                suffixText: 'g',
                suffixStyle: TextStyle(
                    fontSize: 11, color: textColor.withValues(alpha: 0.5)),
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onChanged: (v) {
                final g = double.tryParse(v);
                if (g != null && g > 0) widget.onAmountChanged(g);
              },
            ),
          ),
        ],
      ),
    );
  }
}
