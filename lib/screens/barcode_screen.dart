import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../models/food.dart';
import '../models/meal_entry.dart';
import '../services/gemini_service.dart';
import '../services/barcode_service.dart';
import 'food_search_screen.dart' show WebSearchScreen;

class BarcodeScannerScreen extends StatefulWidget {
  final String date;
  final int mealType;

  const BarcodeScannerScreen({
    super.key,
    required this.date,
    required this.mealType,
  });

  @override
  State<BarcodeScannerScreen> createState() => _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends State<BarcodeScannerScreen>
    with WidgetsBindingObserver {
  final MobileScannerController _controller = MobileScannerController(
    formats: [
      BarcodeFormat.ean13,
      BarcodeFormat.ean8,
      BarcodeFormat.code128,
      BarcodeFormat.qrCode,
    ],
  );

  bool _scanned = false;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        if (!_scanned) _safeStart();
      case AppLifecycleState.paused:
        _safeStop();
      default:
        break;
    }
  }

  Future<void> _safeStart() async {
    try {
      await _controller.start();
    } catch (_) {}
  }

  Future<void> _safeStop() async {
    try {
      await _controller.stop();
    } catch (_) {}
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_scanned || _loading) return;
    final barcode = capture.barcodes.firstOrNull;
    if (barcode?.rawValue == null) return;

    setState(() {
      _scanned = true;
      _loading = true;
    });
    await _safeStop();

    final code = barcode!.rawValue!;
    if (!mounted) return;

    await _handleCode(code);
  }

  Future<void> _handleCode(String code) async {
    // 1. Open Food Facts でバーコード検索（APIキー不要）
    final barcodeResult = await BarcodeService.instance.lookup(code);
    if (!mounted) return;

    if (barcodeResult != null) {
      final (food, packageGrams) = barcodeResult;
      final result = await _showFoodPicker([food], code, defaultGrams: packageGrams);
      if (result != null && mounted) {
        Navigator.pop(context, result);
        return;
      }
      _resetScan();
      return;
    }

    // 2. 商品名入力 → Gemini AI検索
    final productName = await _askProductName(code);
    if (!mounted) return;

    if (productName != null && productName.isNotEmpty) {
      final apiKey = await GeminiService.instance.getApiKey();
      if (!mounted) return;

      if (apiKey != null) {
        setState(() => _loading = true);
        final foods = await GeminiService.instance.searchFood(productName);
        if (!mounted) return;

        if (foods.isNotEmpty) {
          final result = await _showFoodPicker(foods, code);
          if (result != null && mounted) {
            Navigator.pop(context, result);
            return;
          }
          _resetScan();
          return;
        }
        setState(() => _loading = false);
      }

      // Geminiなし or 結果なし → Web検索（商品名で、AI自動入力付き）
      final result = await Navigator.push<MealEntry>(
        context,
        MaterialPageRoute(
          builder: (_) => WebSearchScreen(
            query: '$productName カロリー 栄養素',
            date: widget.date,
            mealType: widget.mealType,
            foodName: productName,
          ),
        ),
      );
      if (result != null && mounted) {
        Navigator.pop(context, result);
      } else {
        _resetScan();
      }
      return;
    }

    // 3. スキップ → Web検索（JAN番号で）
    final result = await Navigator.push<MealEntry>(
      context,
      MaterialPageRoute(
        builder: (_) => WebSearchScreen(
          query: 'JAN $code カロリー 栄養素',
          date: widget.date,
          mealType: widget.mealType,
        ),
      ),
    );

    if (result != null && mounted) {
      Navigator.pop(context, result);
    } else {
      _resetScan();
    }
  }

  Future<String?> _askProductName(String code) async {
    final ctrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('商品が見つかりませんでした'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('JAN: $code',
                style: const TextStyle(fontSize: 11, color: Colors.grey)),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: '例: カナダドライ ジンジャーエール',
                labelText: '商品名を入力',
                border: OutlineInputBorder(),
              ),
              onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
            ),
            const SizedBox(height: 8),
            const Text(
              '入力するとAI検索します（Gemini APIキー設定時）',
              style: TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, null),
            child: const Text('スキップ'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('検索'),
          ),
        ],
      ),
    );
    return name;
  }

  Future<MealEntry?> _showFoodPicker(List<Food> foods, String code, {double? defaultGrams}) async {
    return showModalBottomSheet<MealEntry>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _FoodPickerSheet(
        foods: foods,
        code: code,
        date: widget.date,
        mealType: widget.mealType,
        defaultGrams: defaultGrams,
        onWebSearch: () {
          Navigator.pop(ctx);
          Navigator.push<MealEntry>(
            context,
            MaterialPageRoute(
              builder: (_) => WebSearchScreen(
                query: 'JAN $code カロリー 栄養素',
                date: widget.date,
                mealType: widget.mealType,
              ),
            ),
          ).then((result) {
            if (result != null && mounted) Navigator.pop(context, result);
            else _resetScan();
          });
        },
      ),
    );
  }

  void _resetScan() {
    if (!mounted) return;
    setState(() {
      _scanned = false;
      _loading = false;
    });
    _safeStart();
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('バーコードスキャン', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.flash_on, color: Colors.white),
            onPressed: () => _controller.toggleTorch(),
          ),
        ],
      ),
      body: Stack(
        children: [
          // カメラプレビュー
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
            errorBuilder: (ctx, error) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.camera_alt_outlined,
                        color: Colors.white54, size: 64),
                    const SizedBox(height: 16),
                    const Text(
                      'カメラを起動できませんでした\n設定 > プライバシー > カメラ\nでアクセスを許可してください',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // スキャン枠
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 280,
                  height: 140,
                  decoration: BoxDecoration(
                    border: Border.all(color: primary, width: 2.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  // 四隅を強調
                  child: Stack(
                    children: [
                      Positioned(top: -1, left: -1, child: _Corner(color: primary)),
                      Positioned(top: -1, right: -1, child: _Corner(color: primary, flipH: true)),
                      Positioned(bottom: -1, left: -1, child: _Corner(color: primary, flipV: true)),
                      Positioned(bottom: -1, right: -1, child: _Corner(color: primary, flipH: true, flipV: true)),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'バーコードを枠内に合わせてください',
                    style: TextStyle(color: Colors.white, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),

          // ローディングオーバーレイ
          if (_loading)
            Container(
              color: Colors.black54,
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Colors.white),
                    SizedBox(height: 16),
                    Text('食品を検索中...',
                        style: TextStyle(color: Colors.white, fontSize: 16)),
                  ],
                ),
              ),
            ),

          // 再スキャンボタン（スキャン済みで非ローディング時）
          if (_scanned && !_loading)
            Positioned(
              bottom: 40,
              left: 0,
              right: 0,
              child: Center(
                child: ElevatedButton.icon(
                  onPressed: _resetScan,
                  icon: const Icon(Icons.refresh),
                  label: const Text('再スキャン'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// 四隅の装飾
class _Corner extends StatelessWidget {
  final Color color;
  final bool flipH;
  final bool flipV;
  const _Corner({required this.color, this.flipH = false, this.flipV = false});

  @override
  Widget build(BuildContext context) {
    return Transform.scale(
      scaleX: flipH ? -1 : 1,
      scaleY: flipV ? -1 : 1,
      child: CustomPaint(
        size: const Size(20, 20),
        painter: _CornerPainter(color: color),
      ),
    );
  }
}

class _CornerPainter extends CustomPainter {
  final Color color;
  const _CornerPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    canvas.drawLine(Offset.zero, Offset(size.width, 0), paint);
    canvas.drawLine(Offset.zero, Offset(0, size.height), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// Gemini結果ピッカー
class _FoodPickerSheet extends StatefulWidget {
  final List<Food> foods;
  final String code;
  final String date;
  final int mealType;
  final VoidCallback onWebSearch;
  final double? defaultGrams;

  const _FoodPickerSheet({
    required this.foods,
    required this.code,
    required this.date,
    required this.mealType,
    required this.onWebSearch,
    this.defaultGrams,
  });

  @override
  State<_FoodPickerSheet> createState() => _FoodPickerSheetState();
}

class _FoodPickerSheetState extends State<_FoodPickerSheet> {
  late double _grams;

  @override
  void initState() {
    super.initState();
    _grams = (widget.defaultGrams ?? 100).clamp(10, 500);
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1a1a2e),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36, height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Icon(Icons.auto_awesome, color: primary, size: 18),
              const SizedBox(width: 8),
              const Text('AI検索結果', style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white,
              )),
              const SizedBox(width: 8),
              Text('JAN: ${widget.code}',
                  style: const TextStyle(fontSize: 11, color: Colors.white38)),
            ],
          ),
          const SizedBox(height: 4),
          const Text('※推定値です。正確な情報は商品パッケージをご確認ください',
              style: TextStyle(fontSize: 11, color: Colors.white38)),
          const SizedBox(height: 12),
          ...widget.foods.map((f) => _FoodTile(
            food: f,
            grams: _grams,
            primary: primary,
            onGramsChanged: (v) => setState(() => _grams = v),
            onSelect: () {
              final r = _grams / 100;
              Navigator.pop(
                context,
                MealEntry(
                  date: widget.date,
                  mealType: widget.mealType,
                  foodId: f.id,
                  foodName: f.name,
                  grams: _grams,
                  kcal: f.kcal * r,
                  protein: f.protein * r,
                  fat: f.fat * r,
                  carb: f.carb * r,
                  fiber: f.fiber * r,
                  sodium: f.sodium * r,
                  calcium: f.calcium * r,
                  iron: f.iron * r,
                  isCustom: true,
                ),
              );
            },
          )),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: widget.onWebSearch,
              icon: const Icon(Icons.search, size: 16),
              label: const Text('Webで詳細を確認する'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white54,
                side: const BorderSide(color: Colors.white24),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FoodTile extends StatelessWidget {
  final Food food;
  final double grams;
  final Color primary;
  final void Function(double) onGramsChanged;
  final VoidCallback onSelect;

  const _FoodTile({
    required this.food,
    required this.grams,
    required this.primary,
    required this.onGramsChanged,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final r = grams / 100;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(food.name, style: const TextStyle(
                  fontWeight: FontWeight.w600, color: Colors.white, fontSize: 15,
                )),
              ),
              GestureDetector(
                onTap: onSelect,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [primary, Theme.of(context).colorScheme.secondary],
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text('追加', style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13,
                  )),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${(food.kcal * r).round()} kcal  '
            'P:${(food.protein * r).toStringAsFixed(1)}g  '
            'F:${(food.fat * r).toStringAsFixed(1)}g  '
            'C:${(food.carb * r).toStringAsFixed(1)}g',
            style: const TextStyle(fontSize: 12, color: Colors.white60),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Text('グラム数:', style: TextStyle(fontSize: 12, color: Colors.white54)),
              const SizedBox(width: 8),
              Expanded(
                child: Slider(
                  value: grams.clamp(10, 500),
                  min: 10,
                  max: 500,
                  divisions: 49,
                  activeColor: primary,
                  onChanged: onGramsChanged,
                ),
              ),
              Text('${grams.round()}g',
                  style: const TextStyle(fontSize: 12, color: Colors.white70)),
            ],
          ),
        ],
      ),
    );
  }
}
