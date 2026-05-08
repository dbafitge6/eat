import 'package:flutter/material.dart';
import '../services/purchase_service.dart';
import '../services/ad_service.dart';

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
          const SizedBox(height: 8),
          const Center(
            child: Text('プレミアム会員',
                style:
                    TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 32),
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
            _FeatureRow(Icons.block, '広告なし', '完全広告なし'),
            _FeatureRow(Icons.star, '全機能利用', 'すべての機能が使い放題'),
            _FeatureRow(Icons.support, '優先サポート', '問い合わせを優先対応'),
            const SizedBox(height: 32),
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
            const SizedBox(height: 24),
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
            const SizedBox(height: 24),
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
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('購入を復元しました！')));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('復元する購入が見つかりませんでした')));
    }
  }
}

class _FeatureRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _FeatureRow(this.icon, this.title, this.subtitle);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              Text(subtitle,
                  style: const TextStyle(color: Colors.grey, fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }
}

// 食事記録後のシェア/広告ダイアログ
Future<void> showMealAddedDialog(BuildContext context,
    {required String mealName, required double kcal}) async {
  if (!AdService.instance.showAds) return;

  await showDialog(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      title: const Text('記録しました！'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(mealName,
              style: const TextStyle(fontWeight: FontWeight.bold)),
          Text('${kcal.round()} kcal',
              style: const TextStyle(fontSize: 24, color: Colors.grey)),
          const SizedBox(height: 16),
          const Text('広告を非表示にするには:',
              style: TextStyle(fontSize: 12, color: Colors.grey)),
        ],
      ),
      actions: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ElevatedButton.icon(
              onPressed: () async {
                Navigator.pop(ctx);
                await _shareMeal(context, mealName, kcal);
                await AdService.instance
                    .grantAdFree(const Duration(hours: 24));
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('シェアありがとう！24時間広告なしです')),
                  );
                }
              },
              icon: const Icon(Icons.share),
              label: const Text('SNSでシェア → 24時間広告なし'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () async {
                Navigator.pop(ctx);
                final rewarded =
                    await AdService.instance.showRewarded(context);
                if (rewarded && context.mounted) {
                  await AdService.instance
                      .grantAdFree(const Duration(hours: 1));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('1時間広告なしです')),
                  );
                }
              },
              icon: const Icon(Icons.play_circle_outline),
              label: const Text('動画広告を見る → 1時間広告なし'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('閉じる'),
            ),
          ],
        ),
      ],
    ),
  );
}

Future<void> _shareMeal(
    BuildContext context, String mealName, double kcal) async {
  // Share機能はshare_plusで実装
  // この関数は今_shareTextとして別途実装
}
