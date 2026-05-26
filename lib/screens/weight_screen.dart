import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/weight_entry.dart';
import '../models/user_profile.dart';
import '../services/database_service.dart';
import '../utils/date_utils.dart' as du;

class WeightScreen extends StatefulWidget {
  const WeightScreen({super.key});

  @override
  State<WeightScreen> createState() => _WeightScreenState();
}

class _WeightScreenState extends State<WeightScreen> {
  List<WeightEntry> _entries = [];
  UserProfile? _profile;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final entries = await DatabaseService.instance.getWeights();
    final profile = await DatabaseService.instance.getUserProfile();
    if (!mounted) return;
    setState(() {
      _entries = entries.reversed.toList();
      _profile = profile;
      _loading = false;
    });
  }

  double get _latestWeight =>
      _entries.isNotEmpty ? _entries.last.weight : (_profile?.weightKg ?? 60);

  double get _bmi {
    final h = _profile?.heightCm ?? 170;
    return _latestWeight / ((h / 100) * (h / 100));
  }

  String get _bmiLabel {
    if (_bmi < 18.5) return '低体重';
    if (_bmi < 25) return '普通体重';
    if (_bmi < 30) return '肥満(1度)';
    return '肥満(2度以上)';
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Scaffold(
      appBar: AppBar(title: const Text('体重記録')),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddWeightDialog,
        child: const Icon(Icons.add),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('体重',
                                  style: TextStyle(color: Colors.grey)),
                              Text('${_latestWeight.toStringAsFixed(1)} kg',
                                  style: const TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('BMI',
                                  style: TextStyle(color: Colors.grey)),
                              Text(_bmi.toStringAsFixed(1),
                                  style: const TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold)),
                              Text(_bmiLabel,
                                  style: const TextStyle(
                                      fontSize: 12, color: Colors.grey)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                if (_profile != null)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('基礎代謝',
                              style: TextStyle(color: Colors.grey)),
                          Text('${_profile!.bmr.round()} kcal/日',
                              style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text('目標カロリー: ${_profile!.targetKcal.round()} kcal/日',
                              style: const TextStyle(color: Colors.grey)),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
                _CitationCard(),
                if (_entries.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
                      child: SizedBox(
                        height: 220,
                        child: _WeightChart(
                          entries: _entries,
                          targetWeight: _profile?.weightKg,
                          primary: primary,
                        ),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                ..._entries.reversed.take(30).map((e) => ListTile(
                      title: Text(e.date),
                      trailing: Text('${e.weight.toStringAsFixed(1)} kg',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold)),
                    )),
              ],
            ),
    );
  }

  Future<void> _showAddWeightDialog() async {
    final result = await showDialog<double>(
      context: context,
      builder: (ctx) => _WeightInputDialog(initialWeight: _latestWeight),
    );
    if (result != null) {
      final h = _profile?.heightCm ?? 170;
      final bmi = result / ((h / 100) * (h / 100));
      await DatabaseService.instance.upsertWeight(WeightEntry(
        date: du.todayString(),
        weight: result,
        bmi: bmi,
      ));
      await _load();
    }
  }
}

class _CitationCard extends StatelessWidget {
  Future<void> _open(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('参考文献',
                style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () => _open('https://www.who.int/news-room/fact-sheets/detail/obesity-and-overweight'),
              child: const Text(
                '• BMI基準: WHO「Obesity and overweight」',
                style: TextStyle(fontSize: 12, color: Colors.blue, decoration: TextDecoration.underline),
              ),
            ),
            const SizedBox(height: 4),
            GestureDetector(
              onTap: () => _open('https://pubmed.ncbi.nlm.nih.gov/2305711/'),
              child: const Text(
                '• 基礎代謝: Mifflin-St Jeor式 (1990)',
                style: TextStyle(fontSize: 12, color: Colors.blue, decoration: TextDecoration.underline),
              ),
            ),
            const SizedBox(height: 4),
            GestureDetector(
              onTap: () => _open('https://www.mhlw.go.jp/content/001213449.pdf'),
              child: const Text(
                '• 目標カロリー: 厚生労働省「日本人の食事摂取基準(2025年版)」',
                style: TextStyle(fontSize: 12, color: Colors.blue, decoration: TextDecoration.underline),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WeightChart extends StatelessWidget {
  final List<WeightEntry> entries;
  final double? targetWeight;
  final Color primary;

  const _WeightChart({
    required this.entries,
    required this.primary,
    this.targetWeight,
  });

  @override
  Widget build(BuildContext context) {
    final spots = List.generate(entries.length, (i) =>
        FlSpot(i.toDouble(), entries[i].weight));

    final weights = entries.map((e) => e.weight).toList();
    final minW = weights.reduce((a, b) => a < b ? a : b);
    final maxW = weights.reduce((a, b) => a > b ? a : b);
    final minY = (minW - 2).floorToDouble();
    final maxY = (maxW + 2).ceilToDouble();

    final extraLines = <HorizontalLine>[];
    if (targetWeight != null &&
        targetWeight! >= minY &&
        targetWeight! <= maxY) {
      extraLines.add(HorizontalLine(
        y: targetWeight!,
        color: Colors.orange.withValues(alpha: 0.6),
        strokeWidth: 1,
        dashArray: [6, 4],
        label: HorizontalLineLabel(
          show: true,
          alignment: Alignment.topRight,
          labelResolver: (_) => '目標 ${targetWeight!.toStringAsFixed(1)}kg',
          style: const TextStyle(fontSize: 10, color: Colors.orange),
        ),
      ));
    }

    final step = entries.length <= 10 ? 1 : (entries.length / 5).ceil();

    return LineChart(
      LineChartData(
        minY: minY,
        maxY: maxY,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) => FlLine(
            color: Colors.grey.withValues(alpha: 0.15),
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(show: false),
        extraLinesData: ExtraLinesData(horizontalLines: extraLines),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (value, meta) {
                if (value == meta.min || value == meta.max) return const SizedBox();
                return Text(
                  '${value.toStringAsFixed(1)}',
                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 24,
              interval: step.toDouble(),
              getTitlesWidget: (value, meta) {
                final i = value.toInt();
                if (i < 0 || i >= entries.length) return const SizedBox();
                if (i % step != 0) return const SizedBox();
                final parts = entries[i].date.split('-');
                final label = parts.length >= 3 ? '${parts[1]}/${parts[2]}' : entries[i].date;
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(label, style: const TextStyle(fontSize: 9, color: Colors.grey)),
                );
              },
            ),
          ),
        ),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (spots) => spots.map((s) {
              final i = s.spotIndex;
              final entry = entries[i];
              return LineTooltipItem(
                '${entry.date.substring(5)}\n${entry.weight.toStringAsFixed(1)} kg',
                TextStyle(color: primary, fontSize: 12, fontWeight: FontWeight.bold),
              );
            }).toList(),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: primary,
            barWidth: 2.5,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, bar, index) => FlDotCirclePainter(
                radius: 3,
                color: primary,
                strokeWidth: 0,
              ),
            ),
            belowBarData: BarAreaData(
              show: true,
              color: primary.withValues(alpha: 0.08),
            ),
          ),
        ],
      ),
    );
  }
}

class _WeightInputDialog extends StatefulWidget {
  final double initialWeight;
  const _WeightInputDialog({required this.initialWeight});

  @override
  State<_WeightInputDialog> createState() => _WeightInputDialogState();
}

class _WeightInputDialogState extends State<_WeightInputDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.initialWeight.toStringAsFixed(1),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('体重を記録'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        textInputAction: TextInputAction.done,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
        decoration: const InputDecoration(
          suffixText: 'kg',
          suffixStyle: TextStyle(fontSize: 18),
        ),
        onSubmitted: (v) {
          final parsed = double.tryParse(v);
          if (parsed != null && parsed >= 20 && parsed <= 300) {
            Navigator.pop(context, parsed);
          }
        },
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('キャンセル'),
        ),
        ElevatedButton(
          onPressed: () {
            final parsed = double.tryParse(_controller.text);
            if (parsed != null && parsed >= 20 && parsed <= 300) {
              Navigator.pop(context, parsed);
            }
          },
          child: const Text('記録'),
        ),
      ],
    );
  }
}
