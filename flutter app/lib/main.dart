import 'package:flutter/material.dart';
import 'package:curved_navigation_bar/curved_navigation_bar.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'favourite_screen.dart';
import 'home_screen.dart';
import 'translation_page.dart';
import 'category_screen.dart';
import 'favorites_manager.dart';
import 'welcome_screen.dart'; // Create this file from the previous response

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FavoritesManager.init();

  final prefs = await SharedPreferences.getInstance();
  final isFirstTime = prefs.getBool('isFirstTime') ?? true;

  runApp(SignPredictorApp(isFirstTime: isFirstTime));
}

class SignPredictorApp extends StatelessWidget {
  final bool isFirstTime;

  SignPredictorApp({required this.isFirstTime});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sign Language Predictor',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        fontFamily: 'Cairo',
        scaffoldBackgroundColor: Color(0xFFF8FAFB),
      ),
      home: isFirstTime
          ? WelcomeScreen(onStart: () async {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('isFirstTime', false);
        runApp(SignPredictorApp(isFirstTime: false)); // Reload app with main navigation
      })
          : MainNavigation(),
    );
  }
}

class MainNavigation extends StatefulWidget {
  @override
  _MainNavigationState createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _page = 0;
  final GlobalKey<CurvedNavigationBarState> _navKey = GlobalKey();

  final Color primaryColor = Color(0xFF385A64);
  final Color bgColor = Color(0xFF517C91);

  final List<Widget> _screens = [
    HomeScreen(),
    TranslationScreen(),
    FavoritesScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: primaryColor,
      bottomNavigationBar: CurvedNavigationBar(
        key: _navKey,
        index: _page,
        height: 60,
        backgroundColor: primaryColor,
        color: Colors.white,
        buttonBackgroundColor: Colors.white,
        animationCurve: Curves.easeInOut,
        animationDuration: Duration(milliseconds: 500),
        items: <Widget>[
          Icon(Icons.home, size: 28, color: _page == 0 ? primaryColor : Colors.grey[400]),
          Icon(Icons.translate, size: 28, color: _page == 1 ? primaryColor : Colors.grey[400]),
          Icon(Icons.star, size: 28, color: _page == 2 ? primaryColor : Colors.grey[400]),
        ],
        onTap: (index) {
          setState(() {
            _page = index;
          });
        },
      ),
      body: _screens[_page],
    );
  }
}
