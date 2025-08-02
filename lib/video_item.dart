class VideoItem {
  final String videoPath;
  final String labelArabic;
  final String category;
  final String signer;

  VideoItem({
    required this.videoPath,
    required this.labelArabic,
    required this.category,
    required this.signer,
  });

  factory VideoItem.fromJson(Map<String, dynamic> json) {
    return VideoItem(
      videoPath: json['video_path'],
      labelArabic: json['label_arabic'],
      category: json['category'],
      signer: json['signer'],
    );
  }
}
