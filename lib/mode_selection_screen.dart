import 'package:flutter/material.dart';
import 'prediction_screen.dart';

class ModeSelectionScreen extends StatelessWidget {
  final Color primaryColor = const Color(0xFF385A64);
  final Color headerColor = const Color(0xFF1B2E35);
  final Color lightBackgroundColor = const Color(0xFFF8FAFB);
  final Color lightPrimary = const Color(0xFFE8EFF1);

  void _navigate(BuildContext context, String mode, String seqType) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PredictionScreen(mode: mode, seqType: seqType),
      ),
    );
  }

  Widget _buildModeButton({
    required BuildContext context,
    required String label,
    required String mode,
    required String seqType,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: () => _navigate(context, mode, seqType),
        style: ElevatedButton.styleFrom(
          backgroundColor: lightPrimary,
          foregroundColor: primaryColor,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: primaryColor, width: 2),
          ),
          textStyle: const TextStyle(fontSize: 16),
        ),
        child: Text(label, textDirection: TextDirection.rtl),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: headerColor,
        appBar: AppBar(
          backgroundColor: headerColor,
          elevation: 0,
          title: const Text(
            'اختر نموذج الترجمة',
            style: TextStyle(color: Colors.white),
          ),
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: Stack(
          children: [
            // الحاوية البيضاء للمحتوى
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
                      const SizedBox(height: 24),
                      Text(
                        "النموذج المعقد",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: primaryColor,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildModeButton(
                        context: context,
                        label: "ترجمة إشارة واحدة",
                        mode: "complex",
                        seqType: "single",
                      ),
                      const SizedBox(height: 12),
                      _buildModeButton(
                        context: context,
                        label: "ترجمة تسلسل إشارات",
                        mode: "complex",
                        seqType: "sequence",
                      ),
                      const SizedBox(height: 48),
                      Text(
                        "النموذج البسيط",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: primaryColor,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildModeButton(
                        context: context,
                        label: "ترجمة إشارة واحدة",
                        mode: "simple",
                        seqType: "single",
                      ),
                      const SizedBox(height: 12),
                      _buildModeButton(
                        context: context,
                        label: "ترجمة تسلسل إشارات",
                        mode: "simple",
                        seqType: "sequence",
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Icon(Icons.warning, color: Colors.red, size: 20),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              "على الرغم من أن هذا النموذج أسرع، إلا أنه أكثر عرضة للأخطاء.",
                              style: TextStyle(
                                color: Colors.red[800],
                                fontSize: 12,
                              ),
                              textAlign: TextAlign.right,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),
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
