import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../models/meal_entry.dart';
import '../services/food_search_service.dart';
import 'food_search_screen.dart';

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

class _BarcodeScannerScreenState extends State<BarcodeScannerScreen> {
  final MobileScannerController _controller = MobileScannerController();
  bool _scanned = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_scanned) return;
    final barcode = capture.barcodes.firstOrNull;
    if (barcode?.rawValue == null) return;
    _scanned = true;
    await _controller.stop();

    final code = barcode!.rawValue!;

    // まず内蔵DBで検索（JANコードを商品名として扱う簡易実装）
    // 実際の運用ではOpen Food Facts APIなどを使う
    // ここではWebViewで商品検索にフォールバック
    if (!mounted) return;
    final result = await Navigator.pushReplacement<MealEntry, void>(
      context,
      MaterialPageRoute(
        builder: (_) => _BarcodeResultScreen(
          barcode: code,
          date: widget.date,
          mealType: widget.mealType,
        ),
      ),
    );
    if (result != null && mounted) {
      Navigator.pop(context, result);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('バーコードスキャン'),
        actions: [
          IconButton(
            icon: const Icon(Icons.flash_on),
            onPressed: () => _controller.toggleTorch(),
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
          ),
          Center(
            child: Container(
              width: 280,
              height: 140,
              decoration: BoxDecoration(
                border: Border.all(
                    color: Theme.of(context).colorScheme.primary, width: 2),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'バーコードをスキャンしてください',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BarcodeResultScreen extends StatefulWidget {
  final String barcode;
  final String date;
  final int mealType;

  const _BarcodeResultScreen({
    required this.barcode,
    required this.date,
    required this.mealType,
  });

  @override
  State<_BarcodeResultScreen> createState() => _BarcodeResultScreenState();
}

class _BarcodeResultScreenState extends State<_BarcodeResultScreen> {
  bool _searching = true;

  @override
  void initState() {
    super.initState();
    _search();
  }

  Future<void> _search() async {
    // バーコード番号でDB検索（ヒットしない場合はWeb検索へ）
    final results =
        await FoodSearchService.instance.search(widget.barcode);
    if (!mounted) return;
    setState(() => _searching = false);
    if (results.isEmpty) {
      // Web検索にフォールバック
      _openWebSearch();
    }
  }

  Future<void> _openWebSearch() async {
    final entry = await Navigator.pushReplacement<MealEntry, void>(
      context,
      MaterialPageRoute(
        builder: (_) => _WebSearchProxy(
          query: 'JAN ${widget.barcode} カロリー 栄養素',
          date: widget.date,
          mealType: widget.mealType,
        ),
      ),
    );
    if (entry != null && mounted) {
      Navigator.pop(context, entry);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: _searching
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text('バーコード: ${widget.barcode}'),
                  const Text('検索中...'),
                ],
              )
            : const SizedBox.shrink(),
      ),
    );
  }
}

// Web検索画面のプロキシ（food_search_screen.dartの_WebSearchScreenをここから呼ぶため）
class _WebSearchProxy extends StatelessWidget {
  final String query;
  final String date;
  final int mealType;

  const _WebSearchProxy({
    required this.query,
    required this.date,
    required this.mealType,
  });

  @override
  Widget build(BuildContext context) {
    // FoodSearchScreen経由でWeb検索画面を開く
    return FoodSearchScreen(date: date, mealType: mealType);
  }
}
