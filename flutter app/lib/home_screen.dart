import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:app_pfe/search_result_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

import 'video_item.dart';
import 'video_player_screen.dart';
import 'category_screen.dart';
import 'signer_screen.dart';

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final List<String> categories = [
    'العائلة',
    'الافعال',
    'محادثة',
    'الصفات',
    'المهن',
    'جماد',
    'الاتجاهات',
  ];

  List<VideoItem> randomVideos = [];
  List<String> signers = [];
  List<String> allLabels = [];
  List<String> searchSuggestions = [];

  final TextEditingController _searchController = TextEditingController();

  final Map<String, String> signerImages = {
    'الأستاذ حمزة لقمان': 'assets/images/alostadh_hamza_luqman.jpg',
    'الأستاذ صابري محمود': 'assets/images/alostadh_sabri_mahmoud.jpg',
    'الأستاذ محمد مهندس': 'assets/images/alostadh_mohamed_mohandes.jpg',
  };

  final Color primaryColor = Color(0xFF385A64);
  final Color headerColor = Color(0xFF1B2E35);
  final Color accentColor = Color(0xFFFFC801);
  final Color lightButtonColor = Color(0xFFE8EFF1);
  final Color lightBackgroundColor = Color(0xFFF8FAFB);

  @override
  void initState() {
    super.initState();
    loadVideos();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> loadVideos() async {
    final String jsonString = await rootBundle.loadString('assets/sign_videos_metadata.json');
    final List<dynamic> jsonData = json.decode(jsonString);
    final List<VideoItem> allVideos = jsonData.map((item) => VideoItem.fromJson(item)).toList();

    allVideos.shuffle();
    final uniqueSigners = {for (var v in allVideos) v.signer}.toList();

    setState(() {
      randomVideos = allVideos.take(10).toList();
      signers = uniqueSigners;
      allLabels = allVideos.map((v) => v.labelArabic).toSet().toList();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: headerColor,
      appBar: AppBar(
        backgroundColor: headerColor,
        elevation: 0,
        title: const Text('                                           ! اهلا و سهلا بك',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SafeArea(
        child: Container(
          decoration: BoxDecoration(
            color: lightBackgroundColor,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(32),
              topRight: Radius.circular(32),
            ),
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const SizedBox(height: 12),
                TextField(
                  controller: _searchController,
                  textAlign: TextAlign.right,
                  decoration: InputDecoration(
                    hintText: 'ابحث عن إشارة...',
                    prefixIcon: Icon(Icons.search, color: primaryColor),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                  ),
                  onChanged: (query) {
                    setState(() {
                      searchSuggestions = query.isEmpty
                          ? []
                          : allLabels
                          .where((label) => label.startsWith(query.trim()))
                          .take(5)
                          .toList();
                    });
                  },
                  onSubmitted: (query) {
                    if (query.trim().isNotEmpty) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => SearchResultsScreen(label: query.trim()),
                        ),
                      );
                    }
                  },
                ),
                if (searchSuggestions.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: searchSuggestions.length,
                      itemBuilder: (context, index) {
                        final suggestion = searchSuggestions[index];
                        return ListTile(
                          title: Text(
                            suggestion,
                            textAlign: TextAlign.right,
                            style: TextStyle(color: primaryColor),
                          ),
                          onTap: () {
                            _searchController.text = suggestion;
                            setState(() => searchSuggestions.clear());
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => SearchResultsScreen(label: suggestion),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                const SizedBox(height: 24),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: categories.map((category) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6.0),
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => CategoryScreen(category: category)),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: lightButtonColor,
                            foregroundColor: primaryColor,
                            elevation: 0,
                            side: BorderSide(color: primaryColor),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                          ),
                          child: Text(category,
                              style: const TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 24),
                Text('إشارات عشوائية',
                    style: TextStyle(
                        fontSize: 20, fontWeight: FontWeight.bold, color: headerColor),
                    textAlign: TextAlign.right),
                const SizedBox(height: 12),
                SizedBox(
                  height: 220,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: randomVideos.length,
                    itemBuilder: (context, index) {
                      final video = randomVideos[index];
                      return FutureBuilder<Uint8List?>(
                        future: getThumbnail(video.videoPath),
                        builder: (context, snapshot) {
                          return Padding(
                            padding: const EdgeInsets.only(right: 5),
                            child: GestureDetector(
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
                              child: Card(
                                elevation: 1,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    ClipRRect(
                                      borderRadius:
                                      const BorderRadius.vertical(top: Radius.circular(16)),
                                      child: snapshot.hasData
                                          ? Image.memory(
                                        snapshot.data!,
                                        height: 140,
                                        width: 200,
                                        fit: BoxFit.cover,
                                      )
                                          : Container(
                                        height: 140,
                                        width: 200,
                                        color: Colors.grey[300],
                                        child: const Center(
                                            child: CircularProgressIndicator()),
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.all(8.0),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          Text(
                                            'كلمة "${video.labelArabic}" بلغة الإشارة',
                                            style: const TextStyle(
                                                fontSize: 13, fontWeight: FontWeight.bold),
                                            overflow: TextOverflow.ellipsis,
                                            textAlign: TextAlign.right,
                                          ),
                                          const SizedBox(height: 4),
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            textDirection: TextDirection.rtl,
                                            children: [
                                              Text(video.category,
                                                  style: const TextStyle(fontSize: 11)),
                                              Text(video.signer,
                                                  style: const TextStyle(fontSize: 11)),
                                            ],
                                          )
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
                const SizedBox(height: 24),
                Text('المؤدون',
                    style: TextStyle(
                        fontSize: 20, fontWeight: FontWeight.bold, color: headerColor),
                    textAlign: TextAlign.right),
                const SizedBox(height: 12),
                Column(
                  children: signers.map((signer) {
                    final imagePath = signerImages[signer];
                    return GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => SignerScreen(signer: signer)),
                        );
                      },
                      child: Card(
                        color: lightButtonColor,
                        elevation: 1,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(color: primaryColor),
                        ),
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            textDirection: TextDirection.rtl,
                            children: [
                              imagePath != null
                                  ? ClipRRect(
                                borderRadius: BorderRadius.circular(50),
                                child: Image.asset(
                                  imagePath,
                                  width: 60,
                                  height: 60,
                                  fit: BoxFit.cover,
                                ),
                              )
                                  : CircleAvatar(
                                radius: 30,
                                backgroundColor: Colors.grey[300],
                                child: const Icon(Icons.person,
                                    color: Colors.white, size: 30),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Text(
                                  signer,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                    color: primaryColor,
                                  ),
                                  textAlign: TextAlign.right,
                                ),
                              ),
                              Icon(Icons.arrow_back_ios, size: 16, color: primaryColor),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
