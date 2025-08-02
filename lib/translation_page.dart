import 'package:flutter/material.dart';
import 'mode_selection_screen.dart';

class TranslationScreen extends StatefulWidget {
  @override
  _TranslationScreenState createState() => _TranslationScreenState();
}

class _TranslationScreenState extends State<TranslationScreen> {
  String selectedLanguage = 'ARSL';

  final Color primaryColor = Color(0xFF385A64);
  final Color headerColor = Color(0xFF1B2E35);
  final Color lightBackgroundColor = Colors.white;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl, // للغة العربية
      child: Scaffold(
        backgroundColor: headerColor,
        appBar: AppBar(
          backgroundColor: headerColor,
          elevation: 0,
          title: const Text(
            'الرئيسية',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: Stack(
          children: [
            Positioned.fill(
              top: 10,
              child: Container(
                decoration: BoxDecoration(
                  color: lightBackgroundColor,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(32),
                    topRight: Radius.circular(32),
                  ),
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const SizedBox(height: 32),
                      Text(
                        'مرحبًا بك في شاشة الترجمة!',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: primaryColor,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'هنا يمكنك ترجمة أي فيديو لإشارة واحدة أو تسلسل من الإشارات إلى اللغة التي تختارها.',
                        style: TextStyle(fontSize: 16),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 32),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          'اختر لغة الإشارة:',
                          style: TextStyle(fontSize: 16),
                        ),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        value: selectedLanguage,
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        items: ['ARSL'].map((String language) {
                          return DropdownMenuItem<String>(
                            value: language,
                            child: Text(language),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            selectedLanguage = value!;
                          });
                        },
                      ),
                      const SizedBox(height: 40),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => ModeSelectionScreen()),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'اختر النموذج',
                          style: TextStyle(fontSize: 16, color: Colors.white),
                        ),
                      ),
                      const SizedBox(height: 20),

                      Opacity(
                        opacity: 0.75,
                        child: Image.asset(
                          'assets/images/robot.jpg',
                          height: 350,
                          fit: BoxFit.contain,
                        ),
                      ),


                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
