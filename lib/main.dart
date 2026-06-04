import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/onboarding_screen.dart';
import 'screens/home_screen.dart';
import 'themes/app_theme.dart';
import 'services/database_service.dart';
import 'services/ad_service.dart';
import 'services/notification_service.dart';
import 'services/diet_type_service.dart';
import 'services/purchase_service.dart';
import 'services/nutrition_db_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await DatabaseService.instance.db;
  await AdService.instance.init();
  await NotificationService.instance.init();
  await DietTypeService.instance.load();
  await PurchaseService.instance.init();
  await NutritionDbService.instance.initialize();
  runApp(const EatApp());
}

class EatApp extends StatefulWidget {
  const EatApp({super.key});

  static _EatAppState? of(BuildContext context) =>
      context.findAncestorStateOfType<_EatAppState>();

  @override
  State<EatApp> createState() => _EatAppState();
}

class _EatAppState extends State<EatApp> {
  AppThemeType _themeType = AppThemeType.darkMode;
  AppThemeType get currentTheme => _themeType;
  bool _onboardingDone = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final themeIndex = prefs.getInt('theme') ?? AppThemeType.darkMode.index;
    final onboarding = prefs.getBool('onboarding_done') ?? false;
    setState(() {
      _themeType = AppThemeType.values[themeIndex.clamp(0, AppThemeType.values.length - 1)];
      _onboardingDone = onboarding;
      _loading = false;
    });
  }

  Future<void> setTheme(AppThemeType t) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('theme', t.index);
    setState(() => _themeType = t);
  }

  Future<void> completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_done', true);
    setState(() => _onboardingDone = true);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const MaterialApp(
        home: Scaffold(body: Center(child: CircularProgressIndicator())),
      );
    }
    return MaterialApp(
      title: 'eat.',
      debugShowCheckedModeBanner: false,
      theme: AppThemes.get(_themeType),
      home: _onboardingDone
          ? const HomeScreen()
          : OnboardingScreen(onComplete: completeOnboarding),
    );
  }
}
