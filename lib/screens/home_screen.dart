import 'package:flutter/material.dart';
import 'today_screen.dart';
import 'week_screen.dart';
import 'calendar_screen.dart';
import 'weight_screen.dart';
import '../services/ad_service.dart';

class HomeScreen extends StatefulWidget {
  final int initialTab;
  const HomeScreen({super.key, this.initialTab = 0});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _index = widget.initialTab;
  }

  final _screens = const [
    TodayScreen(),
    WeekScreen(),
    CalendarScreen(),
    WeightScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_index],
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const BannerAdWidget(),
          BottomNavigationBar(
        currentIndex: _index,
        onTap: (i) => setState(() => _index = i),
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.restaurant), label: '今日'),
          BottomNavigationBarItem(icon: Icon(Icons.bar_chart), label: '週間'),
          BottomNavigationBarItem(icon: Icon(Icons.calendar_month), label: 'カレンダー'),
          BottomNavigationBarItem(icon: Icon(Icons.monitor_weight), label: '体重'),
        ],
      ),
        ],
      ),
    );
  }
}
