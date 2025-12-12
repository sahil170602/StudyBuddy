// File: lib/main.dart
import 'package:flutter/material.dart';
import 'widgets/animated_bottom_nav.dart';
import 'screens/dashboard_screen.dart';
import 'screens/my_stuff_screen.dart';
import 'screens/chat_screen.dart';
import 'screens/notifications_screen.dart';
import 'screens/quiz_screen.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'StudyBuddy Glassy',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF071022),
        primaryColor: Colors.blueAccent,
        textTheme: ThemeData.dark().textTheme.apply(bodyColor: Colors.white),
      ),
      home: const AppShell(),
    );
  }
}

class AppShell extends StatefulWidget {
  const AppShell({Key? key}) : super(key: key);
  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  // Keep this in sync with the nav widget height constant
  static const double _navBaseHeight = 86.0;

  int _currentIndex = 0;
  int _assistantUnread = 3;

  final List<Widget> _pages = const [
    DashboardScreen(),
    MyStuffScreen(),
    ChatScreen(),
    NotificationsScreen(),
    QuizScreen(),
  ];

  void _onNavTap(int navIndex) {
    if (navIndex == 2) {
      setState(() {
        _assistantUnread = 0;
        _currentIndex = 2;
      });
      return;
    }
    setState(() => _currentIndex = navIndex);
  }

  void _onCenterAction() {
    setState(() {
      _assistantUnread = 0;
      _currentIndex = 2;
    });
  }

  @override
  Widget build(BuildContext context) {
    // No bottom padding on body — nav overlays the content (user wanted no visible gap)
    return Scaffold(
      extendBody: true,
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        // DO NOT add bottom padding here. Let nav overlay. If a page needs to avoid the nav,
        // add padding inside that specific page.
        child: IndexedStack(index: _currentIndex, children: _pages),
      ),
      bottomNavigationBar: AnimatedBottomNav(
        currentIndex: _currentIndex,
        onTap: _onNavTap,
        centerActionOnTap: _onCenterAction,
        assistantUnreadCount: _assistantUnread,
      ),
    );
  }
}
