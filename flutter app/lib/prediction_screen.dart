import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:video_player/video_player.dart';
import 'package:http/http.dart' as http;

const Color primaryColor = Color(0xFF385A64);
const Color headerColor = Color(0xFF1B2E35);
const Color accentColor = Color(0xFFFFC801);
const Color lightBgColor = Color(0xFFF8FAFB);
const Color lightPrimary = Color(0xFFE8EFF1);

class PredictionScreen extends StatefulWidget {
  final String mode;
  final String seqType;

  const PredictionScreen({
    Key? key,
    required this.mode,
    required this.seqType,
  }) : super(key: key);

  @override
  _PredictionScreenState createState() => _PredictionScreenState();
}

class _PredictionScreenState extends State<PredictionScreen> {
  String _result = '';
  bool _loading = false;
  File? _videoFile;
  VideoPlayerController? _controller;
  bool _showControls = false;
  String? _selectedLanguage;
  int? _selectedModelType;

  String get _title {
    final modelType = widget.mode == 'complex' ? 'معقد' : 'بسيط';
    final taskType = widget.seqType == 'single' ? 'إشارة واحدة' : 'تسلسل إشارات';
    return 'ترجمة $taskType ($modelType)';
  }

  Future<void> _pickAndUploadVideo() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.video);
    if (result != null && result.files.single.path != null) {
      File videoFile = File(result.files.single.path!);
      setState(() {
        _videoFile = videoFile;
        _result = '';
        _controller?.dispose();
        _controller = VideoPlayerController.file(videoFile)
          ..initialize().then((_) {
            setState(() {});
            _controller!.play();
            _controller!.addListener(() {
              if (_controller!.value.position >= _controller!.value.duration) {
                setState(() => _showControls = true);
              }
            });
          });
      });
    }
  }

  Future<void> _startPrediction() async {
    if (_videoFile == null || _selectedLanguage == null || _selectedModelType == null) return;

    await Future.delayed(const Duration(milliseconds: 300));
    setState(() => _loading = true);

    var uri = Uri.parse("http://192.168.110.152:5000/predict_video").replace(queryParameters: {
      'mode': widget.mode,
      'seq_type': widget.seqType,
      'model_type': _selectedModelType.toString()
    });

    var request = http.MultipartRequest('POST', uri);
    request.files.add(await http.MultipartFile.fromPath('video', _videoFile!.path));

    try {
      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        final label = decoded['label'];
        setState(() {
          _result = widget.seqType == 'single' ? "$label" : "$label";
        });
      } else {
        setState(() {
          _result = "خطأ: ${response.body}";
        });
      }
    } catch (e) {
      setState(() {
        _result = "حدث خطأ أثناء الإرسال: $e";
      });
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Widget _buildPredictingDots() {
    return TweenAnimationBuilder<int>(
      tween: IntTween(begin: 0, end: 3),
      duration: const Duration(milliseconds: 900),
      builder: (context, value, child) {
        final dots = '.' * (value + 1);
        return Text(
          '$dotsجارٍ التنبؤ',
          style: const TextStyle(fontSize: 18, fontStyle: FontStyle.italic, color: headerColor),
          textAlign: TextAlign.right,
        );
      },
      onEnd: () {
        if (_loading) setState(() {});
      },
    );
  }

  Widget _buildLanguageDropdown() {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'اللغة:',
            style: TextStyle(fontSize: 20, color: headerColor, fontWeight: FontWeight.w600),
          ),
          DropdownButton<String>(
            value: _selectedLanguage,
            hint: const Text("اختر"),
            items: const [
              DropdownMenuItem(value: 'Arabic', child: Text('العربية')),
            ],
            onChanged: (value) {
              setState(() {
                _selectedLanguage = value;
                _startPrediction();
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildModelTypeDropdown() {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'الفئة:',
            style: TextStyle(fontSize: 20, color: headerColor, fontWeight: FontWeight.w600),
          ),
          DropdownButton<int>(
            value: _selectedModelType,
            hint: const Text("اختر"),
            items: const [
              DropdownMenuItem(value: 1, child: Text('أحرف')),
              DropdownMenuItem(value: 2, child: Text('أرقام')),
              DropdownMenuItem(value: 3, child: Text('كلمات')),
            ],
            onChanged: (value) {
              setState(() {
                _selectedModelType = value;
                _startPrediction();
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildVideoDisplay() {
    return GestureDetector(
      onTap: () {
        setState(() {
          _showControls = !_showControls;
        });
      },
      child: Container(
        width: 320,
        height: 320,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: Colors.black,
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          alignment: Alignment.center,
          children: [
            _controller != null && _controller!.value.isInitialized
                ? VideoPlayer(_controller!)
                : const Center(child: CircularProgressIndicator()),
            if (_controller != null && _controller!.value.isInitialized && _showControls)
              Center(
                child: IconButton(
                  iconSize: 64,
                  color: Colors.white.withOpacity(0.85),
                  icon: Icon(
                    _controller!.value.position >= _controller!.value.duration
                        ? Icons.replay
                        : _controller!.value.isPlaying
                        ? Icons.pause
                        : Icons.play_arrow,
                  ),
                  onPressed: () {
                    setState(() {
                      if (_controller!.value.position >= _controller!.value.duration) {
                        _controller!.seekTo(Duration.zero);
                        _controller!.play();
                      } else if (_controller!.value.isPlaying) {
                        _controller!.pause();
                      } else {
                        _controller!.play();
                      }
                      _showControls = false;
                    });
                  },
                ),
              ),
            if (_controller != null && _controller!.value.isInitialized)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: VideoProgressIndicator(
                  _controller!,
                  allowScrubbing: true,
                  padding: const EdgeInsets.only(bottom: 0),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildUploadButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _loading ? null : _pickAndUploadVideo,
        style: ElevatedButton.styleFrom(
          backgroundColor: lightPrimary,
          foregroundColor: primaryColor,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: primaryColor, width: 2),
          ),
          textStyle: const TextStyle(fontSize: 16),
        ),
        child: const Text('اختر الفيديو', textAlign: TextAlign.right),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: headerColor,
      appBar: AppBar(
        title: Text(
          _title,
          style: const TextStyle(color: Colors.white),
          textAlign: TextAlign.right,
        ),
        backgroundColor: headerColor,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SizedBox.expand(
        child: SingleChildScrollView(
          child: Container(
            constraints: BoxConstraints(
              minHeight: MediaQuery.of(context).size.height - kToolbarHeight,
            ),
            padding: const EdgeInsets.fromLTRB(30, 30, 30, 30),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(32),
                topRight: Radius.circular(32),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _buildUploadButton(),
                const SizedBox(height: 20),
                if (_videoFile != null) ...[
                  _buildVideoDisplay(),
                  const SizedBox(height: 16),
                  _buildLanguageDropdown(),
                  const SizedBox(height: 16),
                  _buildModelTypeDropdown(),
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    height: 200,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: lightPrimary,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Align(
                      alignment: Alignment.topRight,
                      child: _loading
                          ? _buildPredictingDots()
                          : Text(
                        _result.isNotEmpty ? _result : '...اختر الغة والفئة',
                        style: const TextStyle(
                          fontSize: 18,
                          color: headerColor,
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.right,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
