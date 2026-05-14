import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/meal_share_card.dart';

class PhotoFilterScreen extends StatefulWidget {
  final File photo;
  final String date;
  final int mealType;

  const PhotoFilterScreen({
    super.key,
    required this.photo,
    required this.date,
    required this.mealType,
  });

  @override
  State<PhotoFilterScreen> createState() => _PhotoFilterScreenState();
}

class _PhotoFilterScreenState extends State<PhotoFilterScreen> {
  FoodFilter _filter = FoodFilter.natural;
  bool _saving = false;
  final _previewKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('フィルター'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: Text(
              _saving ? '保存中...' : '保存',
              style: TextStyle(
                color: _saving ? Colors.white38 : Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // 写真プレビュー
          Expanded(
            child: Center(
              child: RepaintBoundary(
                key: _previewKey,
                child: ColorFiltered(
                  colorFilter: _filter.colorFilter,
                  child: Image.file(
                    widget.photo,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
          ),
          // フィルター選択
          Container(
            color: const Color(0xFF111111),
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: SizedBox(
              height: 76,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: FoodFilter.values.length,
                separatorBuilder: (_, __) => const SizedBox(width: 16),
                itemBuilder: (_, i) {
                  final f = FoodFilter.values[i];
                  final selected = _filter == f;
                  return GestureDetector(
                    onTap: () => setState(() => _filter = f),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: selected
                                ? Border.all(color: Colors.white, width: 3)
                                : Border.all(color: Colors.white24, width: 1.5),
                          ),
                          child: ClipOval(
                            child: ColorFiltered(
                              colorFilter: f.colorFilter,
                              child: Image.file(widget.photo, fit: BoxFit.cover),
                            ),
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          f.label,
                          style: TextStyle(
                            fontSize: 10,
                            color: selected ? Colors.white : Colors.white38,
                            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom),
        ],
      ),
    );
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await Future.delayed(const Duration(milliseconds: 80));
      final boundary = _previewKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 2.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final bytes = byteData!.buffer.asUint8List();

      final dir = await getApplicationDocumentsDirectory();
      final dest = File(p.join(
        dir.path,
        'meal_${widget.date}_${widget.mealType}_${DateTime.now().millisecondsSinceEpoch}.jpg',
      ));
      await dest.writeAsBytes(bytes);

      // 旧ファイル削除
      final key = 'photo_${widget.date}_${widget.mealType}';
      final prefs = await SharedPreferences.getInstance();
      final oldPath = prefs.getString(key);
      if (oldPath != null && oldPath != dest.path) {
        final oldFile = File(oldPath);
        if (await oldFile.exists()) await oldFile.delete();
      }
      await prefs.setString(key, dest.path);

      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() => _saving = false);
    }
  }
}
