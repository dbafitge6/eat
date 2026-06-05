import 'package:flutter/material.dart';
import '../services/purchase_service.dart';

class PremiumScreen extends StatefulWidget {
  const PremiumScreen({super.key});

  @override
  State<PremiumScreen> createState() => _PremiumScreenState();
}

class _PremiumScreenState extends State<PremiumScreen> {
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final isPremium = PurchaseService.instance.isPremium;

    return Scaffold(
      appBar: AppBar(title: const Text('eat. プレミアム')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Center(
            child: Text(
              'eat.',
              style: TextStyle(
                fontSize: 48,
                fontWeight: FontWeight.bold,
                color: primary,
              ),
            ),
          ),
          const SizedBox(height: 4),
          const Center(
            child: Text('プレミアム会員',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 24),
          if (isPremium) ...[
            Card(
              color: Colors.green.withValues(alpha: 0.1),
              child: const Padding(
                padding: EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green),
                    SizedBox(width: 12),
                    Text('プレミアム会員です',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
          ] else ...[
            // Free vs Premium comparison
            _CompareSection(primary: primary),
            const SizedBox(height: 28),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: primary),
              ),
              child: Column(
                children: [
                  Text('¥500 / 月',
                      style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: primary)),
                  const Text('いつでもキャンセル可能',
                      style: TextStyle(color: Colors.grey)),
                ],
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _loading ? null : _purchase,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primary,
                  foregroundColor: Colors.white,
                ),
                child: _loading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('プレミアムに登録する',
                        style: TextStyle(fontSize: 16)),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: _loading ? null : _restore,
                child: const Text('購入を復元する'),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              '・サブスクリプションは自動更新されます\n'
              '・解約はApp Storeのサブスクリプション管理から行えます\n'
              '・購入は確認後にApple IDに請求されます',
              style: TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _purchase() async {
    setState(() => _loading = true);
    final success = await PurchaseService.instance.purchase();
    if (!mounted) return;
    setState(() => _loading = false);
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('プレミアムに登録しました！')));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('購入に失敗しました')));
    }
  }

  Future<void> _restore() async {
    setState(() => _loading = true);
    final success = await PurchaseService.instance.restore();
    if (!mounted) return;
    setState(() => _loading = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(success ? '購入を復元しました！' : '復元する購入が見つかりませんでした')));
  }
}

class _CompareSection extends StatelessWidget {
  final Color primary;
  const _CompareSection({required this.primary});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            const Expanded(
              child: Text('機能',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  textAlign: TextAlign.left),
            ),
            SizedBox(
              width: 64,
              child: Text('無料',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: Colors.grey[600]),
                  textAlign: TextAlign.center),
            ),
            SizedBox(
              width: 72,
              child: Text('プレミアム',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: primary),
                  textAlign: TextAlign.center),
            ),
          ],
        ),
        const Divider(height: 16),
        ..._rows(primary),
      ],
    );
  }

  static List<Widget> _rows(Color primary) {
    final items = [
      ('食事記録', '1日3回', '無制限'),
      ('文科省DBで食品検索', 'あり', 'あり'),
      ('外食メニュー提案', '1日3回', '無制限'),
      ('体重・水分記録', 'あり', 'あり'),
      ('基本グラフ', 'あり', 'あり'),
      ('AI栄養相談', '1日3回', '無制限'),
      ('AIチャット履歴', 'なし', 'あり'),
      ('1週間献立生成', 'なし', 'あり'),
      ('週間レポート詳細', 'なし', 'あり'),
      ('CSVエクスポート', 'なし', 'あり'),
      ('SNSシェア', 'あり', 'あり'),
      ('テーマ変更', 'なし', 'あり'),
      ('サプリ通知', '2件まで', '無制限'),
    ];
    return items
        .map((item) => _CompareRow(
            label: item.$1,
            free: item.$2,
            premium: item.$3,
            accent: primary))
        .toList();
  }
}

class _CompareRow extends StatelessWidget {
  final String label;
  final String free;
  final String premium;
  final Color accent;

  const _CompareRow(
      {required this.label,
      required this.free,
      required this.premium,
      required this.accent});

  @override
  Widget build(BuildContext context) {
    final isPremiumOnly = free == 'なし';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(label,
                style: const TextStyle(fontSize: 13)),
          ),
          SizedBox(
            width: 64,
            child: Text(free,
                style: TextStyle(
                    fontSize: 12,
                    color: isPremiumOnly ? Colors.grey[400] : Colors.grey[700]),
                textAlign: TextAlign.center),
          ),
          SizedBox(
            width: 72,
            child: Text(premium,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: accent),
                textAlign: TextAlign.center),
          ),
        ],
      ),
    );
  }
}
