import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AdService {
  static final AdService _instance = AdService._();
  static AdService get instance => _instance;
  AdService._();

  // 本番IDはAdMobコンソールで取得したものに差し替える
  static const String _bannerAdUnitId =
      'ca-app-pub-3940256099942544/2934735716'; // テスト用
  static const String _interstitialAdUnitId =
      'ca-app-pub-3940256099942544/4411468910'; // テスト用
  static const String _rewardedAdUnitId =
      'ca-app-pub-3940256099942544/1712485313'; // テスト用

  bool _isPremium = false;
  DateTime? _adFreeUntil;
  InterstitialAd? _interstitialAd;
  RewardedAd? _rewardedAd;

  bool get showAds {
    if (_isPremium) return false;
    if (_adFreeUntil != null && DateTime.now().isBefore(_adFreeUntil!)) {
      return false;
    }
    return true;
  }

  Future<void> init() async {
    await MobileAds.instance.initialize();
    final prefs = await SharedPreferences.getInstance();
    _isPremium = prefs.getBool('is_premium') ?? false;
    final adFreeUntilMs = prefs.getInt('ad_free_until');
    if (adFreeUntilMs != null) {
      _adFreeUntil = DateTime.fromMillisecondsSinceEpoch(adFreeUntilMs);
    }
    _loadInterstitial();
    _loadRewarded();
  }

  Future<void> setPremium(bool value) async {
    _isPremium = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_premium', value);
  }

  Future<void> grantAdFree(Duration duration) async {
    _adFreeUntil = DateTime.now().add(duration);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
        'ad_free_until', _adFreeUntil!.millisecondsSinceEpoch);
  }

  BannerAd createBannerAd() => BannerAd(
        adUnitId: _bannerAdUnitId,
        size: AdSize.banner,
        request: const AdRequest(),
        listener: BannerAdListener(
          onAdFailedToLoad: (ad, error) => ad.dispose(),
        ),
      );

  void _loadInterstitial() {
    InterstitialAd.load(
      adUnitId: _interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) => _interstitialAd = ad,
        onAdFailedToLoad: (_) => _interstitialAd = null,
      ),
    );
  }

  void _loadRewarded() {
    RewardedAd.load(
      adUnitId: _rewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) => _rewardedAd = ad,
        onAdFailedToLoad: (_) => _rewardedAd = null,
      ),
    );
  }

  Future<void> showInterstitial() async {
    if (_interstitialAd == null || !showAds) return;
    _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _interstitialAd = null;
        _loadInterstitial();
      },
    );
    await _interstitialAd!.show();
  }

  Future<bool> showRewarded(BuildContext context) async {
    if (_rewardedAd == null) return false;
    bool rewarded = false;
    _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _rewardedAd = null;
        _loadRewarded();
      },
    );
    await _rewardedAd!.show(
      onUserEarnedReward: (_, reward) => rewarded = true,
    );
    return rewarded;
  }
}

class BannerAdWidget extends StatefulWidget {
  const BannerAdWidget({super.key});

  @override
  State<BannerAdWidget> createState() => _BannerAdWidgetState();
}

class _BannerAdWidgetState extends State<BannerAdWidget> {
  BannerAd? _ad;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    if (AdService.instance.showAds) {
      _ad = AdService.instance.createBannerAd()
        ..load().then((_) {
          if (mounted) setState(() => _loaded = true);
        });
    }
  }

  @override
  void dispose() {
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!AdService.instance.showAds || !_loaded || _ad == null) {
      return const SizedBox.shrink();
    }
    return SizedBox(
      width: _ad!.size.width.toDouble(),
      height: _ad!.size.height.toDouble(),
      child: AdWidget(ad: _ad!),
    );
  }
}
