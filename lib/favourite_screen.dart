import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

import 'favorites_manager.dart';
import 'video_item.dart';
import 'video_player_screen.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({Key? key}) : super(key: key);

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  List<VideoItem> favoriteVideos = [];
  bool isLoading = true;

  final Color headerColor = const Color(0xFF1B2E35);
  final Color bgColor = const Color(0xFFF8FAFB);
  final Color primaryColor = const Color(0xFF385A64);

  @override
  void initState() {
    super.initState();
    loadFavorites();
  }

  Future<void> loadFavorites() async {
    final jsonString = await rootBundle.loadString('assets/sign_videos_metadata.json');
    final List<dynamic> jsonData = json.decode(jsonString);
    final allVideos = jsonData.map((json) => VideoItem.fromJson(json)).toList();
    final favPaths = FavoritesManager.favorites;
    final favVideos = allVideos.where((video) => favPaths.contains(video.videoPath)).toList();

    setState(() {
      favoriteVideos = favVideos;
      isLoading = false;
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

      return await VideoThumbnail.thumbnailData(
        video: tempFile.path,
        imageFormat: ImageFormat.PNG,
        maxWidth: 128,
        quality: 75,
      );
    } catch (e) {
      print('Thumbnail error: $e');
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: headerColor,
        appBar: AppBar(
          backgroundColor: headerColor,
          title: const Text('الاشارات المفضلة', style: TextStyle(color: Colors.white)),
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: Container(
          decoration: const BoxDecoration(
            color: Color(0xFFF8FAFB),
            borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          ),
          padding: const EdgeInsets.all(16.0),
          child: isLoading
              ? const Center(child: CircularProgressIndicator())
              : favoriteVideos.isEmpty
              ? const Center(child: Text('لا توجد مقاطع مفضلة حاليًا.'))
              : GridView.builder(
            itemCount: favoriteVideos.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.75,
            ),
            itemBuilder: (context, index) {
              final video = favoriteVideos[index];
              return FutureBuilder<Uint8List?>(
                future: getThumbnail(video.videoPath),
                builder: (context, snapshot) {
                  return Stack(
                    children: [
                      Card(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 1,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => VideoPlayerScreen(
                                  videoPath: video.videoPath,
                                  labelArabic: video.labelArabic,
                                ),
                              ),
                            );
                          },
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              snapshot.hasData
                                  ? ClipRRect(
                                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                                child: Image.memory(
                                  snapshot.data!,
                                  fit: BoxFit.cover,
                                  height: 140,
                                ),
                              )
                                  : Container(
                                height: 140,
                                decoration: BoxDecoration(
                                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                                  color: Colors.grey[300],
                                ),
                                child: const Center(child: CircularProgressIndicator()),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(10.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'كلمة "${video.labelArabic}" بلغة الإشارة',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: primaryColor,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          video.category,
                                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                        ),
                                        Text(
                                          video.signer,
                                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: IconButton(
                          icon: Icon(
                            FavoritesManager.isFavorite(video.videoPath)
                                ? Icons.star
                                : Icons.star_border,
                            color: FavoritesManager.isFavorite(video.videoPath)
                                ? Colors.amber
                                : Colors.grey,
                          ),
                          onPressed: () {
                            setState(() {
                              FavoritesManager.toggleFavorite(video.videoPath);
                              loadFavorites(); // refresh the list
                            });
                          },
                        ),
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}
