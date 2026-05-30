import 'package:flutter_test/flutter_test.dart';
import 'package:karatou/app/core/models/app_models.dart';

void main() {
  group('YoutubeVideo.fromApi', () {
    test('parses a complete payload', () {
      final v = YoutubeVideo.fromApi(const {
        'videoId': 'abc123',
        'title': 'Mon parcours vers le Canada',
        'description': 'Témoignage de Awa',
        'thumbnailUrl': 'https://i.ytimg.com/vi/abc123/hqdefault.jpg',
        'publishedAt': '2026-04-01T10:00:00.000Z',
        'position': 3,
      });
      expect(v.videoId, 'abc123');
      expect(v.title, 'Mon parcours vers le Canada');
      expect(v.description, 'Témoignage de Awa');
      expect(v.thumbnailUrl, contains('abc123'));
      expect(v.publishedAt, isNotNull);
      expect(v.position, 3);
    });

    test('tolerates missing fields with safe defaults', () {
      final v = YoutubeVideo.fromApi(const {'videoId': 'x'});
      expect(v.videoId, 'x');
      expect(v.title, '');
      expect(v.description, '');
      expect(v.thumbnailUrl, '');
      expect(v.publishedAt, isNull);
      expect(v.position, 0);
    });

    test('round-trips through toJson (offline cache)', () {
      const original = YoutubeVideo(
        videoId: 'yt9',
        title: 'Visa étudiant France',
        description: 'Étapes clés',
        thumbnailUrl: 'https://img/yt9.jpg',
        position: 1,
      );
      final restored = YoutubeVideo.fromApi(original.toJson());
      expect(restored.videoId, original.videoId);
      expect(restored.title, original.title);
      expect(restored.description, original.description);
      expect(restored.thumbnailUrl, original.thumbnailUrl);
      expect(restored.position, original.position);
    });
  });
}
