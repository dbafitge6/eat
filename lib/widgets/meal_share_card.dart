import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';

enum ShareCardStyle { photoFull, whiteFooter, sticker, wide }
enum FoodFilter { natural, warm, vivid, restaurant, fresh, studio }

extension FilterExt on FoodFilter {
  String get label {
    const labels = {
      FoodFilter.natural: 'ナチュラル',
      FoodFilter.warm: 'あたたか',
      FoodFilter.vivid: '鮮やか',
      FoodFilter.restaurant: 'レストラン',
      FoodFilter.fresh: 'さわやか',
      FoodFilter.studio: 'スタジオ',
    };
    return labels[this]!;
  }

  Color get previewColor {
    const colors = {
      FoodFilter.natural: Color(0xFFAAAAAA),
      FoodFilter.warm: Color(0xFFFF9F47),
      FoodFilter.vivid: Color(0xFFFFD700),
      FoodFilter.restaurant: Color(0xFF8B5E3C),
      FoodFilter.fresh: Color(0xFF4FC3F7),
      FoodFilter.studio: Color(0xFFB39DDB),
    };
    return colors[this]!;
  }

  ColorFilter get colorFilter {
    switch (this) {
      case FoodFilter.natural:
        return const ColorFilter.matrix([
          1, 0, 0, 0, 0,
          0, 1, 0, 0, 0,
          0, 0, 1, 0, 0,
          0, 0, 0, 1, 0,
        ]);
      case FoodFilter.warm:
        return const ColorFilter.matrix([
          1.1, 0, 0, 0, 10,
          0, 1.0, 0, 0, 0,
          0, 0, 0.88, 0, -10,
          0, 0, 0, 1, 0,
        ]);
      case FoodFilter.vivid:
        return const ColorFilter.matrix([
          1.38, -0.34, -0.04, 0, 0,
          -0.11, 1.36, -0.06, 0, 0,
          -0.11, -0.34, 1.45, 0, 0,
          0, 0, 0, 1, 0,
        ]);
      case FoodFilter.restaurant:
        return const ColorFilter.matrix([
          1.15, 0.05, 0, 0, -10,
          0, 1.0, 0, 0, -8,
          0, 0, 0.82, 0, -8,
          0, 0, 0, 1, 0,
        ]);
      case FoodFilter.fresh:
        return const ColorFilter.matrix([
          0.95, 0, 0, 0, 0,
          0, 1.02, 0, 0, 5,
          0, 0, 1.12, 0, 15,
          0, 0, 0, 1, 0,
        ]);
      case FoodFilter.studio:
        return const ColorFilter.matrix([
          1.1, -0.05, 0, 0, 5,
          0, 1.12, 0, 0, -3,
          0, 0, 0.92, 0, -5,
          0, 0, 0, 1, 0,
        ]);
    }
  }
}

class MealShareCard extends StatelessWidget {
  final GlobalKey repaintKey;
  final File? photo;
  final String mealName;
  final String mealTimeLabel;
  final double kcal;
  final double protein;
  final double fat;
  final double carb;
  final double targetKcal;
  final ShareCardStyle style;
  final FoodFilter filter;

  const MealShareCard({
    super.key,
    required this.repaintKey,
    this.photo,
    required this.mealName,
    required this.mealTimeLabel,
    required this.kcal,
    required this.protein,
    required this.fat,
    required this.carb,
    this.targetKcal = 2000,
    required this.style,
    required this.filter,
  });

  Widget _photoWidget({BoxFit fit = BoxFit.cover}) {
    final f = photo;
    if (f != null) {
      return ColorFiltered(
        colorFilter: filter.colorFilter,
        child: Image.file(f, fit: fit, width: double.infinity),
      );
    }
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2A2018), Color(0xFF1A1A2E)],
        ),
      ),
      child: const Center(
        child: Text('🍽️', style: TextStyle(fontSize: 64)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ratio = style == ShareCardStyle.wide ? 3 / 2 : 1.0;
    return RepaintBoundary(
      key: repaintKey,
      child: AspectRatio(aspectRatio: ratio, child: _build()),
    );
  }

  Widget _build() {
    switch (style) {
      case ShareCardStyle.photoFull:   return _buildPhotoFull();
      case ShareCardStyle.whiteFooter: return _buildWhiteFooter();
      case ShareCardStyle.sticker:     return _buildSticker();
      case ShareCardStyle.wide:        return _buildWide();
    }
  }

  // ── 01 写真全面・最小テキスト ──────────────────────────────
  Widget _buildPhotoFull() {
    return Stack(
      fit: StackFit.expand,
      children: [
        _photoWidget(),
        Positioned(
          top: 16, left: 16, right: 16,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0x26FFFFFF),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0x33FFFFFF), width: 0.5),
                ),
                child: const Text('eat.', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0x4D000000),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(mealTimeLabel, style: const TextStyle(color: Color(0xCCFFFFFF), fontSize: 10)),
              ),
            ],
          ),
        ),
        Positioned(
          bottom: 0, left: 0, right: 0,
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Color(0xB5000000)],
              ),
            ),
            padding: const EdgeInsets.fromLTRB(20, 40, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(mealName, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w500)),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    RichText(text: TextSpan(children: [
                      TextSpan(text: '${kcal.round()}', style: const TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.w500, height: 1)),
                      const TextSpan(text: ' kcal', style: TextStyle(color: Color(0x99FFFFFF), fontSize: 14)),
                    ])),
                    Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      _dot('P', protein, const Color(0xFFE8FF47)),
                      const SizedBox(height: 3),
                      _dot('F', fat, const Color(0xFFFF9F47)),
                      const SizedBox(height: 3),
                      _dot('C', carb, const Color(0xFF47FFEA)),
                    ]),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _dot(String label, double val, Color color) => Row(mainAxisSize: MainAxisSize.min, children: [
    Container(width: 5, height: 5, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
    const SizedBox(width: 5),
    Text('$label ${val.round()}g', style: const TextStyle(color: Color(0xCCFFFFFF), fontSize: 12)),
  ]);

  // ── 02 白フッター・シンプル ──────────────────────────────────
  Widget _buildWhiteFooter() {
    final ratio = (kcal / targetKcal).clamp(0.0, 1.0);
    final pct = (ratio * 100).round();
    return Column(
      children: [
        Expanded(
          flex: 13,
          child: Stack(fit: StackFit.expand, children: [
            _photoWidget(),
            Positioned(
              top: 14, right: 14,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(color: const Color(0xEBFFFFFF), borderRadius: BorderRadius.circular(10)),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text('${kcal.round()}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Color(0xFF1A1A1A), height: 1)),
                  const Text('kcal', style: TextStyle(fontSize: 9, color: Color(0xFFAAAAAA))),
                ]),
              ),
            ),
          ]),
        ),
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(18, 13, 18, 13),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(mealName, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w500, color: Color(0xFF1A1A1A))),
                  const SizedBox(height: 2),
                  Text(mealTimeLabel, style: const TextStyle(fontSize: 11, color: Color(0xFFBBBBBB))),
                ])),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text('目標 $pct%', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFF4CAF7D))),
                  const Text('今日の合計', style: TextStyle(fontSize: 10, color: Color(0xFFCCCCCC))),
                ]),
              ],
            ),
            const SizedBox(height: 9),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: ratio, minHeight: 3,
                backgroundColor: const Color(0xFFF0EDE8),
                valueColor: const AlwaysStoppedAnimation(Color(0xFF1A1A1A)),
              ),
            ),
            const SizedBox(height: 9),
            IntrinsicHeight(
              child: Row(children: [
                _footerMacro('${carb.round()}g', '炭水化物'),
                const VerticalDivider(color: Color(0xFFF0EDE8), width: 1),
                _footerMacro('${protein.round()}g', 'たんぱく質'),
                const VerticalDivider(color: Color(0xFFF0EDE8), width: 1),
                _footerMacro('${fat.round()}g', '脂質'),
              ]),
            ),
          ]),
        ),
      ],
    );
  }

  Widget _footerMacro(String val, String name) => Expanded(child: Column(children: [
    Text(val, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: Color(0xFF1A1A1A))),
    const SizedBox(height: 2),
    Text(name, style: const TextStyle(fontSize: 10, color: Color(0xFFCCCCCC))),
  ]));

  // ── 03 ステッカー風バッジ ────────────────────────────────────
  Widget _buildSticker() {
    return Stack(fit: StackFit.expand, children: [
      Container(color: const Color(0xFF0D0D0D)),
      _photoWidget(),
      Positioned(top: 16, left: 16, child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(color: const Color(0xFFE8FF47), borderRadius: BorderRadius.circular(14)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Text('${kcal.round()}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w500, color: Color(0xFF1A1A00), height: 1)),
          const Text('kcal', style: TextStyle(fontSize: 9, color: Color(0xFF6A6A00))),
        ]),
      )),
      Positioned(top: 16, right: 16, child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: const Color(0x1AFFFFFF),
          border: Border.all(color: const Color(0x26FFFFFF), width: 0.5),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(mealTimeLabel, style: const TextStyle(fontSize: 11, color: Color(0xCCFFFFFF))),
      )),
      Positioned(
        bottom: 0, left: 0, right: 0,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(crossAxisAlignment: CrossAxisAlignment.end, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text(mealName, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w500, color: Colors.white)),
              const SizedBox(height: 6),
              Wrap(spacing: 6, children: [
                _pill('P ${protein.round()}g'),
                _pill('F ${fat.round()}g'),
                _pill('C ${carb.round()}g'),
              ]),
            ])),
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0x14FFFFFF),
                border: Border.all(color: const Color(0x1FFFFFFF), width: 0.5),
              ),
              child: const Center(child: Text('e', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Color(0x80FFFFFF)))),
            ),
          ]),
        ),
      ),
    ]);
  }

  Widget _pill(String text) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
    decoration: BoxDecoration(
      color: const Color(0x1FE8FF47),
      border: Border.all(color: const Color(0x33E8FF47), width: 0.5),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(text, style: const TextStyle(fontSize: 10, color: Color(0xFFE8FF47))),
  );

  // ── 04 横2分割（Twitter/X向け）──────────────────────────────
  Widget _buildWide() {
    return Container(
      color: Colors.white,
      child: Row(children: [
        Expanded(child: Stack(fit: StackFit.expand, children: [
          _photoWidget(),
          Positioned(bottom: 10, left: 10, child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(color: const Color(0x66000000), borderRadius: BorderRadius.circular(6)),
            child: Text(mealTimeLabel, style: const TextStyle(color: Colors.white, fontSize: 9)),
          )),
        ])),
        SizedBox(
          width: 150,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('eat.', style: TextStyle(fontSize: 9, color: Color(0xFFCCCCCC), letterSpacing: 1)),
                  const SizedBox(height: 8),
                  Text(mealName, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: Color(0xFF1A1A1A), height: 1.3)),
                ]),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  RichText(text: TextSpan(children: [
                    TextSpan(text: '${kcal.round()}', style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w500, color: Color(0xFF1A1A1A))),
                    const TextSpan(text: ' kcal', style: TextStyle(fontSize: 11, color: Color(0xFFBBBBBB))),
                  ])),
                  const Divider(color: Color(0xFFF0EDE8), height: 18, thickness: 0.5),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    _wideM('${carb.round()}g', '炭水化物'),
                    _wideM('${protein.round()}g', 'たんぱく質'),
                    _wideM('${fat.round()}g', '脂質'),
                  ]),
                ]),
              ],
            ),
          ),
        ),
      ]),
    );
  }

  Widget _wideM(String val, String name) => Column(children: [
    Text(val, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFF1A1A1A))),
    const SizedBox(height: 2),
    Text(name, style: const TextStyle(fontSize: 8, color: Color(0xFFCCCCCC))),
  ]);
}

// ── シェアシート ─────────────────────────────────────────────

Future<void> showShareCardSheet({
  required BuildContext context,
  File? photo,
  required String mealName,
  required double kcal,
  required double protein,
  required double fat,
  required double carb,
  double targetKcal = 2000,
}) async {
  final now = TimeOfDay.now();
  final time = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _ShareCardSheet(
      photo: photo,
      mealName: mealName,
      mealTimeLabel: '$mealName · $time',
      kcal: kcal,
      protein: protein,
      fat: fat,
      carb: carb,
      targetKcal: targetKcal,
    ),
  );
}

class _ShareCardSheet extends StatefulWidget {
  final File? photo;
  final String mealName;
  final String mealTimeLabel;
  final double kcal;
  final double protein;
  final double fat;
  final double carb;
  final double targetKcal;

  const _ShareCardSheet({
    this.photo,
    required this.mealName,
    required this.mealTimeLabel,
    required this.kcal,
    required this.protein,
    required this.fat,
    required this.carb,
    required this.targetKcal,
  });

  @override
  State<_ShareCardSheet> createState() => _ShareCardSheetState();
}

class _ShareCardSheetState extends State<_ShareCardSheet> {
  final _cardKey = GlobalKey();
  ShareCardStyle _style = ShareCardStyle.photoFull;
  FoodFilter _filter = FoodFilter.natural;
  bool _sharing = false;

  static const _styleLabels = ['01 全面', '02 白フッター', '03 バッジ', '04 横長'];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF111111),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(16, 12, 16, MediaQuery.of(context).padding.bottom + 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 14),
          // カードプレビュー
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: MealShareCard(
              repaintKey: _cardKey,
              photo: widget.photo,
              mealName: widget.mealName,
              mealTimeLabel: widget.mealTimeLabel,
              kcal: widget.kcal,
              protein: widget.protein,
              fat: widget.fat,
              carb: widget.carb,
              targetKcal: widget.targetKcal,
              style: _style,
              filter: _filter,
            ),
          ),
          const SizedBox(height: 16),
          // スタイル選択
          SizedBox(
            height: 34,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: ShareCardStyle.values.length,
              separatorBuilder: (context, index) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final s = ShareCardStyle.values[i];
                final selected = _style == s;
                return GestureDetector(
                  onTap: () => setState(() => _style = s),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                    decoration: BoxDecoration(
                      color: selected ? Colors.white : Colors.white12,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _styleLabels[i],
                      style: TextStyle(
                        fontSize: 12,
                        color: selected ? Colors.black : Colors.white60,
                        fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          // フィルター選択
          SizedBox(
            height: 60,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: FoodFilter.values.length,
              separatorBuilder: (context, index) => const SizedBox(width: 12),
              itemBuilder: (_, i) {
                final f = FoodFilter.values[i];
                final selected = _filter == f;
                return GestureDetector(
                  onTap: () => setState(() => _filter = f),
                  child: Column(children: [
                    Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: f.previewColor,
                        border: selected
                            ? Border.all(color: Colors.white, width: 2.5)
                            : Border.all(color: Colors.transparent, width: 2.5),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      f.label,
                      style: TextStyle(fontSize: 9, color: selected ? Colors.white : Colors.white38),
                    ),
                  ]),
                );
              },
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _sharing ? null : _share,
              icon: _sharing
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.ios_share),
              label: Text(_sharing ? '生成中...' : 'シェアする'),
              style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _share() async {
    setState(() => _sharing = true);
    try {
      await Future.delayed(const Duration(milliseconds: 100));
      final boundary = _cardKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final bytes = byteData!.buffer.asUint8List();
      final dir = await getTemporaryDirectory();
      final file = File(p.join(dir.path, 'eat_share_${DateTime.now().millisecondsSinceEpoch}.png'));
      await file.writeAsBytes(bytes);
      if (mounted) Navigator.pop(context);
      await Share.shareXFiles(
        [XFile(file.path)],
        text: '#eat. ${widget.mealName} ${widget.kcal.round()}kcal',
      );
    } catch (_) {
      setState(() => _sharing = false);
    }
  }
}
