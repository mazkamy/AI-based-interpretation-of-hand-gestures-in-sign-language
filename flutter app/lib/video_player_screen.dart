import 'dart:convert';
import 'dart:typed_data';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'favorites_manager.dart';

class VideoPlayerScreen extends StatefulWidget {
  final String videoPath;
  final String labelArabic;

  const VideoPlayerScreen({
    required this.videoPath,
    required this.labelArabic,
  });

  @override
  _VideoPlayerScreenState createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  late VideoPlayerController _controller;
  final ScrollController _scrollController = ScrollController();

  bool _isInitialized = false;
  bool _showControls = false;
  List<dynamic> _relatedVideos = [];
  final Map<String, Uint8List?> _thumbnails = {};
  bool isFavorite = false;

  final Color primaryColor = Color(0xFF385A64);
  final Color headerColor = Color(0xFF1B2E35);
  final Color accentColor = Color(0xFFFFC801);
  final Color lightBackgroundColor = Color(0xFFF8FAFB);

  @override
  void initState() {
    super.initState();
    _loadRelatedVideos();
    _initializeVideo(widget.videoPath);
    isFavorite = FavoritesManager.isFavorite(widget.videoPath);
  }

  void _initializeVideo(String path) {
    _controller = VideoPlayerController.asset(path)
      ..initialize().then((_) {
        setState(() {
          _isInitialized = true;
        });
        _controller.play();

        _controller.addListener(() {
          final isEnded = _controller.value.position >= _controller.value.duration &&
              !_controller.value.isPlaying;

          if (isEnded) {
            setState(() {
              _showControls = true;
            });
          }
        });
      });
  }

  Future<void> _loadRelatedVideos() async {
    final String jsonData = await rootBundle.loadString('assets/sign_videos_metadata.json');
    final List<dynamic> videoList = json.decode(jsonData);

    final filtered = videoList
        .where((video) =>
    video['label_arabic'] == widget.labelArabic &&
        video['video_path'] != widget.videoPath)
        .toList();

    for (var video in filtered) {
      final thumb = await getThumbnail(video['video_path']);
      _thumbnails[video['video_path']] = thumb;
    }

    setState(() {
      _relatedVideos = filtered;
    });
  }

  Future<Uint8List?> getThumbnail(String videoPath) async {
    try {
      final byteData = await rootBundle.load(videoPath);
      final buffer = byteData.buffer;
      final tempDir = await getTemporaryDirectory();
      final tempFilePath = '${tempDir.path}/${videoPath.split('/').last}';
      final tempFile = File(tempFilePath);
      await tempFile.writeAsBytes(
        buffer.asUint8List(byteData.offsetInBytes, byteData.lengthInBytes),
      );

      final thumb = await VideoThumbnail.thumbnailData(
        video: tempFile.path,
        imageFormat: ImageFormat.PNG,
        maxWidth: 128,
        quality: 75,
      );
      return thumb;
    } catch (e) {
      print('Thumbnail error: $e');
      return null;
    }
  }

  void _changeVideo(String newPath) {
    _controller.pause();
    _controller.dispose();
    setState(() {
      _isInitialized = false;
      _showControls = false;
    });

    _scrollController.animateTo(
      0.0,
      duration: Duration(milliseconds: 400),
      curve: Curves.easeInOut,
    );

    _initializeVideo(newPath);
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Widget buildVideoPlayer() {
    return GestureDetector(
      onTap: () {
        setState(() {
          _showControls = !_showControls;
        });
      },
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: double.infinity,
            height: 250,
            color: Colors.black,
            alignment: Alignment.center,
            child: _isInitialized
                ? FittedBox(
              fit: BoxFit.contain,
              child: SizedBox(
                width: _controller.value.size.width,
                height: _controller.value.size.height,
                child: VideoPlayer(_controller),
              ),
            )
                : const Center(child: CircularProgressIndicator()),
          ),
          if (_isInitialized && _showControls)
            Center(
              child: IconButton(
                iconSize: 64,
                color: Colors.white.withOpacity(0.85),
                icon: Icon(
                  _controller.value.position >= _controller.value.duration
                      ? Icons.replay
                      : _controller.value.isPlaying
                      ? Icons.pause
                      : Icons.play_arrow,
                ),
                onPressed: () {
                  setState(() {
                    if (_controller.value.position >= _controller.value.duration) {
                      _controller.seekTo(Duration.zero);
                      _controller.play();
                    } else if (_controller.value.isPlaying) {
                      _controller.pause();
                    } else {
                      _controller.play();
                    }
                    _showControls = false;
                  });
                },
              ),
            ),
          if (_isInitialized)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: VideoProgressIndicator(
                _controller,
                allowScrubbing: true,
                padding: EdgeInsets.only(bottom: 0),
              ),
            ),
        ],
      ),
    );
  }

  Widget buildVideoList() {
    return ListView.builder(
      itemCount: _relatedVideos.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemBuilder: (context, index) {
        final video = _relatedVideos[index];
        final thumbnail = _thumbnails[video['video_path']];
        return GestureDetector(
          onTap: () {
            if (video['video_path'] != _controller.dataSource) {
              _changeVideo(video['video_path']);
            }
          },
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  blurRadius: 6,
                  offset: Offset(2, 4),
                ),
              ],
            ),
            child: Row(
              textDirection: TextDirection.ltr,
              children: [
                thumbnail != null
                    ? ClipRRect(
                  borderRadius: BorderRadius.horizontal(left: Radius.circular(16)),
                  child: Image.memory(thumbnail,
                      width: 120, height: 80, fit: BoxFit.cover),
                )
                    : Container(
                  width: 120,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.horizontal(left: Radius.circular(16)),
                  ),
                  child: Icon(Icons.play_circle_fill,
                      size: 40, color: Colors.black45),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'كلمة "${video['label_arabic']}" بلغة الإشارة',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: headerColor),
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.right,
                        ),
                        SizedBox(height: 4),
                        Text("الفئة: ${video['category']}",
                            style: TextStyle(fontSize: 13),
                            textAlign: TextAlign.right),
                        Text("المؤدي: ${video['signer']}",
                            style: TextStyle(fontSize: 13),
                            textAlign: TextAlign.right),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: lightBackgroundColor,
      appBar: AppBar(
        backgroundColor: headerColor,
        elevation: 0,
        iconTheme: IconThemeData(color: lightBackgroundColor),
        title: Text(
          'عارض الفيديو',
          style: TextStyle(color: lightBackgroundColor, fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        controller: _scrollController,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Column(
              children: [
                buildVideoPlayer(),
                ClipRRect(
                  borderRadius: BorderRadius.vertical(
                    bottom: Radius.circular(20),
                  ),
                  child: Container(
                    width: double.infinity,
                    color: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          icon: Icon(
                            isFavorite ? Icons.star : Icons.star_border,
                            color: isFavorite ? Colors.amber : Colors.grey,
                          ),
                          onPressed: () async {
                            await FavoritesManager.toggleFavorite(widget.videoPath);
                            setState(() {
                              isFavorite = !isFavorite;
                            });
                          },
                        ),
                        Expanded(
                          child: Text(
                            'كلمة "${widget.labelArabic}" بلغة الإشارة',
                            style: TextStyle(
                              fontSize: 25,
                              fontWeight: FontWeight.bold,
                              color: headerColor,
                            ),
                            textAlign: TextAlign.right,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 15, 8, 15),
              child: Text(
                'فيديوهات مشابهة',
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: headerColor),
              ),
            ),
            buildVideoList(),
            SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
