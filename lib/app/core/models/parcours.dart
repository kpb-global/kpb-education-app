part of 'app_models.dart';


class YoutubeVideo {
  const YoutubeVideo({
    required this.videoId,
    required this.title,
    this.description = '',
    this.thumbnailUrl = '',
    this.publishedAt,
    this.position = 0,
  });

  final String videoId;
  final String title;
  final String description;
  final String thumbnailUrl;
  final DateTime? publishedAt;
  final int position;

  factory YoutubeVideo.fromApi(Map<String, dynamic> json) {
    return YoutubeVideo(
      videoId: json['videoId'] as String? ?? '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      thumbnailUrl: json['thumbnailUrl'] as String? ?? '',
      publishedAt: DateTime.tryParse(json['publishedAt'] as String? ?? ''),
      position: json['position'] as int? ?? 0,
    );
  }

  /// Round-trips through the offline cache (same shape as the API payload).
  Map<String, dynamic> toJson() => {
        'videoId': videoId,
        'title': title,
        'description': description,
        'thumbnailUrl': thumbnailUrl,
        'publishedAt': publishedAt?.toIso8601String(),
        'position': position,
      };
}
