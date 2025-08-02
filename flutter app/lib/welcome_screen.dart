import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'main.dart'; // Update this import path if needed

class WelcomeScreen extends StatefulWidget {
  final VoidCallback onStart;

  WelcomeScreen({required this.onStart});

  @override
  _WelcomeScreenState createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<Map<String, String>> _pages = [
    {
      'image': 'assets/images/welcome_1.jpg',
      'description': '.هذا التطبيق يساعدك على تعلم وفهم لغة الإشارة بسهولة من خلال فيديوهات تفاعلية'
    },
    {
      'image': 'assets/images/welcome_2.jpg',
      'description': '.ابدأ الآن في استكشاف الإشارات وتصنيفها، وترجم فيديوهاتك بلغة الإشارة إلى نص مكتوب'
    },
  ];

  void _onNext() {
    if (_currentPage == _pages.length - 1) {
      _finishWelcome();
    } else {
      _pageController.nextPage(
        duration: Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _finishWelcome() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isFirstTime', false);
    widget.onStart();
  }

  Widget _buildDot(int index) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        color: _currentPage == index ? Color(0xFF385A64) : Colors.grey[400],
        shape: BoxShape.circle,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final headerColor = Color(0xFF1B2E35);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: PageView.builder(
          controller: _pageController,
          itemCount: _pages.length,
          onPageChanged: (index) {
            setState(() {
              _currentPage = index;
            });
          },
          itemBuilder: (context, index) {
            final page = _pages[index];
            return SingleChildScrollView(
              child: Column(
                children: [
                  const SizedBox(height: 100),
                  Image.asset(
                    page['image']!,
                    height: 325,
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(_pages.length, _buildDot),
                  ),
                  const SizedBox(height: 30),
                  Text(
                    '!مرحبا بك',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: headerColor,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: Text(
                      page['description']!,
                      style: TextStyle(fontSize: 18, color: headerColor),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 30),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _onNext,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xFF385A64),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          _currentPage == _pages.length - 1 ? 'ابدأ' : 'التالي',
                          style: const TextStyle(fontSize: 20, color: Colors.white),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
