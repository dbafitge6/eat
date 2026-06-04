import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/meal_entry.dart';
import '../services/food_recognition_service.dart';
import '../services/gemini_service.dart';
import '../services/database_service.dart';
import '../utils/date_utils.dart' as du;

class PhotoMealScreen extends StatefulWidget {
  final int mealType;
  final String? date;

  const PhotoMealScreen({
    super.key,
    this.mealType = 0,
    this.date,
  });

  @override
  State<PhotoMealScreen> createState() => _PhotoMealScreenState();
}

class _PhotoMealScreenState extends State<PhotoMealScreen> {
  final _picker = ImagePicker();
  File? _image;
  bool _analyzing = false;
  List<_FoodItemState> _items = [];
  bool _saving = false;
  int _step = 0; // 0=camera, 1=analyzing, 2=confirm

  late final String _date;

  @override
  void initState() {
    super.initState();
    _date = widget.date ?? du.todayString();
  }

  Future<void> _pickImage(ImageSource source) async {
    final picked = await _picker.pickImage(
      source: source,
      imageQuality: 80,
      maxWidth: 1280,
    );
    if (picked == null) return;
    setState(() {
      _image = File(picked.path);
      _step = 1;
      _analyzing = true;
      _items = [];
    });
    await _analyze(picked.path);
  }

  Future<void> _analyze(String path) async {
    try {
      final recognized =
          await FoodRecognitionService.instance.recognizeFoodFromImage(path);
      if (!mounted) return;
      if (recognized.isEmpty) {
        setState(() {
          _analyzing = false;
          _step = 0;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('食材を認識できませんでした。別の写真をお試しください。'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }
      setState(() {
        _analyzing = false;
        _step = 2;
        _items = recognized.map((r) => _FoodItemState(r)).toList();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _analyzing = false;
        _step = 0;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('解析エラー: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _fetchNutrition(_FoodItemState item) async {
    setState(() => item.fetchingNutrition = true);
    try {
      final results =
          await GeminiService.instance.searchFood(item.name);
      if (results.isNotEmpty && mounted) {
        final food = results.first;
        final g = item.grams;
        setState(() {
          item.kcal = food.kcal * g / 100;
          item.protein = food.protein * g / 100;
          item.fat = food.fat * g / 100;
          item.carb = food.carb * g / 100;
          item.nutritionFetched = true;
          item.fetchingNutrition = false;
        });
      } else {
        setState(() => item.fetchingNutrition = false);
      }
    } catch (_) {
      setState(() => item.fetchingNutrition = false);
    }
  }

  Future<void> _save() async {
    final activeItems = _items.where((i) => i.included).toList();
    if (activeItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('食材を1つ以上選択してください')),
      );
      return;
    }

    setState(() => _saving = true);

    // Fetch nutrition for items that don't have it yet
    for (final item in activeItems) {
      if (!item.nutritionFetched) {
        await _fetchNutrition(item);
      }
    }

    for (final item in activeItems) {
      final entry = MealEntry(
        date: _date,
        mealType: widget.mealType,
        foodId: 'photo_${item.name}',
        foodName: item.name,
        grams: item.grams,
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
      await DatabaseService.instance.insertMeal(entry);
    }

    if (!mounted) return;
    setState(() => _saving = false);
    Navigator.pop(context, true);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${activeItems.length}件の食材を記録しました'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final primary = cs.primary;
    final secondary = cs.secondary;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: ShaderMask(
          shaderCallback: (bounds) =>
              LinearGradient(colors: [primary, secondary]).createShader(bounds),
          child: const Text(
            '写真から記録',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ),
        actions: [
          if (_step == 2 && !_saving)
            TextButton(
              onPressed: _save,
              child: Text(
                '記録する',
                style: TextStyle(
                    color: primary, fontWeight: FontWeight.w700),
              ),
            ),
        ],
      ),
      body: _buildBody(primary, secondary),
    );
  }

  Widget _buildBody(Color primary, Color secondary) {
    if (_step == 0) {
      return _buildCameraStep(primary, secondary);
    }
    if (_step == 1 || _analyzing) {
      return _buildAnalyzingStep(primary);
    }
    return _buildConfirmStep(primary, secondary);
  }

  Widget _buildCameraStep(Color primary, Color secondary) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [primary, secondary]),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.camera_alt,
                  color: Colors.white, size: 48),
            ),
            const SizedBox(height: 24),
            const Text(
              '食事の写真を撮影すると\nAIが食材を自動認識します',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 15, color: Colors.white70, height: 1.6),
            ),
            const SizedBox(height: 8),
            const Text(
              '※AI認識には誤差があります。記録前に内容をご確認ください。',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 10, color: Colors.white38),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.camera_alt),
                label: const Text('カメラで撮影'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: () => _pickImage(ImageSource.camera),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.photo_library),
                label: const Text('カメラロールから選ぶ'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white70,
                  side: BorderSide(
                      color: Colors.white.withValues(alpha: 0.3)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: () => _pickImage(ImageSource.gallery),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnalyzingStep(Color primary) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (_image != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.file(
                _image!,
                height: 200,
                width: 200,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(height: 24),
          ],
          CircularProgressIndicator(color: primary),
          const SizedBox(height: 16),
          const Text(
            'AIが食材を解析中...',
            style: TextStyle(fontSize: 15, color: Colors.white70),
          ),
        ],
      ),
    );
  }

  Widget _buildConfirmStep(Color primary, Color secondary) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
      children: [
        // Image preview
        if (_image != null) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.file(
              _image!,
              height: 180,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(height: 16),
        ],

        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'AIが認識した食材',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const Text(
                    '追加・削除して内容を確認してください',
                    style: TextStyle(fontSize: 11, color: Colors.white38),
                  ),
                ],
              ),
            ),
            TextButton.icon(
              onPressed: () {
                setState(() {
                  _step = 0;
                  _image = null;
                  _items = [];
                });
              },
              icon: const Icon(Icons.refresh, size: 14),
              label: const Text('撮り直す'),
              style: TextButton.styleFrom(foregroundColor: Colors.white54),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Food items
        ..._items.asMap().entries.map((entry) {
          final idx = entry.key;
          final item = entry.value;
          return _FoodItemTile(
            item: item,
            primary: primary,
            secondary: secondary,
            onChanged: () => setState(() {}),
            onDelete: () => setState(() => _items.removeAt(idx)),
          );
        }),

        const SizedBox(height: 12),

        // Add item manually
        OutlinedButton.icon(
          icon: const Icon(Icons.add),
          label: const Text('食材を追加'),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.white70,
            side: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: _addItemManually,
        ),

        const SizedBox(height: 20),

        // Save button
        if (_saving)
          const Center(child: CircularProgressIndicator())
        else
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [primary, secondary]),
              borderRadius: BorderRadius.circular(14),
            ),
            child: ElevatedButton(
              onPressed: _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: Text(
                '${_items.where((i) => i.included).length}件を記録する',
                style: const TextStyle(
                    fontSize: 16,
                    color: Colors.white,
                    fontWeight: FontWeight.w700),
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _addItemManually() async {
    final ctrl = TextEditingController();
    final gramsCtrl = TextEditingController(text: '100');
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('食材を追加'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: ctrl,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: '食材名',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: gramsCtrl,
              decoration: const InputDecoration(
                labelText: 'グラム数',
                suffixText: 'g',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('キャンセル')),
          ElevatedButton(
            onPressed: () {
              if (ctrl.text.isNotEmpty) {
                final grams = double.tryParse(gramsCtrl.text) ?? 100.0;
                setState(() {
                  _items.add(_FoodItemState(RecognizedFoodItem(
                    name: ctrl.text.trim(),
                    confidence: 1.0,
                    estimatedGrams: grams,
                  )));
                });
              }
              Navigator.pop(ctx);
            },
            child: const Text('追加'),
          ),
        ],
      ),
    );
  }
}

// ─── Food Item State ──────────────────────────────────────────────────────────

class _FoodItemState {
  final RecognizedFoodItem original;
  String name;
  double grams;
  bool included;
  double kcal;
  double protein;
  double fat;
  double carb;
  bool nutritionFetched;
  bool fetchingNutrition;

  _FoodItemState(this.original)
      : name = original.name,
        grams = original.estimatedGrams,
        included = true,
        kcal = 0,
        protein = 0,
        fat = 0,
        carb = 0,
        nutritionFetched = false,
        fetchingNutrition = false;
}

// ─── Food Item Tile ───────────────────────────────────────────────────────────

class _FoodItemTile extends StatelessWidget {
  final _FoodItemState item;
  final Color primary;
  final Color secondary;
  final VoidCallback onChanged;
  final VoidCallback onDelete;

  const _FoodItemTile({
    required this.item,
    required this.primary,
    required this.secondary,
    required this.onChanged,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isLowConf = item.original.isLowConfidence;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: item.included
              ? Colors.white.withValues(alpha: 0.07)
              : Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: item.included
                ? Colors.white.withValues(alpha: 0.15)
                : Colors.white.withValues(alpha: 0.05),
          ),
        ),
        child: Row(
          children: [
            // Checkbox
            GestureDetector(
              onTap: () {
                item.included = !item.included;
                onChanged();
              },
              child: Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: item.included
                      ? primary
                      : Colors.transparent,
                  border: Border.all(
                    color: item.included ? primary : Colors.white38,
                    width: 1.5,
                  ),
                ),
                child: item.included
                    ? const Icon(Icons.check,
                        color: Colors.white, size: 13)
                    : null,
              ),
            ),
            const SizedBox(width: 10),
            // Food info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.name,
                          style: TextStyle(
                            fontSize: 14,
                            color: item.included
                                ? Colors.white
                                : Colors.white38,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (isLowConf)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: Colors.orangeAccent
                                .withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            '❓ 要確認',
                            style: TextStyle(
                                fontSize: 9,
                                color: Colors.orangeAccent),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(
                        '${item.grams.round()}g',
                        style: const TextStyle(
                            fontSize: 11, color: Colors.white38),
                      ),
                      if (item.nutritionFetched) ...[
                        const SizedBox(width: 8),
                        Text(
                          '${item.kcal.round()} kcal',
                          style: TextStyle(
                              fontSize: 11, color: Colors.white60),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            // Delete button
            GestureDetector(
              onTap: onDelete,
              child: const Icon(Icons.close,
                  size: 16, color: Colors.white24),
            ),
          ],
        ),
      ),
    );
  }
}
