import 'package:flutter_test/flutter_test.dart';
import 'package:karatou/app/core/models/app_models.dart';

void main() {
  group('ParcoursStory.fromApi', () {
    test('parses a complete video payload', () {
      final s = ParcoursStory.fromApi(const {
        'id': 'row-1',
        'slug': 'v-google',
        'kind': 'video',
        'fieldId': 'd01',
        'tags': ['Google', 'Tech'],
        'personName': 'Hamza',
        'role': {'fr': 'Ingénieur', 'en': 'Engineer'},
        'title': {'fr': 'Chez Google', 'en': 'At Google'},
        'hook': {'fr': 'Son parcours', 'en': 'His journey'},
        'summary': {'fr': 'Résumé', 'en': 'Summary'},
        'thumbnailUrl': 'https://img/v.jpg',
        'youtubeId': 'abc123',
        'durationMinutes': 42,
        'interview': {'fr': [], 'en': []},
        'featured': true,
        'displayOrder': 2,
        'popularity': 10,
      });
      expect(s.slug, 'v-google');
      expect(s.kind, ParcoursKind.video);
      expect(s.isVideo, true);
      expect(s.fieldId, 'd01');
      expect(s.tags, ['Google', 'Tech']);
      expect(s.title.resolve('fr'), 'Chez Google');
      expect(s.title.resolve('en'), 'At Google');
      expect(s.youtubeId, 'abc123');
      expect(s.durationMinutes, 42);
      expect(s.featured, true);
    });

    test('parses a written story and resolves interview locale with fallback',
        () {
      final s = ParcoursStory.fromApi(const {
        'slug': 't-fadji',
        'kind': 'text',
        'title': {'fr': 'Parcours', 'en': 'Journey'},
        'interview': {
          'fr': [
            {'question': 'Qui es-tu ?', 'answer': 'Ingénieure.'}
          ],
          'en': [],
        },
      });
      expect(s.kind, ParcoursKind.text);
      expect(s.isVideo, false);
      // FR present, EN empty → EN request falls back to FR.
      expect(s.interview('fr').length, 1);
      expect(s.interview('en').length, 1);
      expect(s.interview('fr').first.question, 'Qui es-tu ?');
    });

    test('derives a YouTube thumbnail when none is provided', () {
      final s = ParcoursStory.fromApi(const {
        'slug': 'v-x',
        'kind': 'video',
        'title': {'fr': 'X', 'en': 'X'},
        'youtubeId': 'zzz999zzz01',
      });
      expect(s.effectiveThumbnailUrl, contains('zzz999zzz01'));
    });

    test('tolerates missing fields with safe defaults', () {
      final s = ParcoursStory.fromApi(const {'slug': 'x'});
      expect(s.slug, 'x');
      expect(s.kind, ParcoursKind.video);
      expect(s.tags, isEmpty);
      expect(s.title.resolve('fr'), '');
      expect(s.youtubeId, isNull);
      expect(s.interviewFr, isEmpty);
    });

    test('round-trips through toJson (offline cache)', () {
      const original = ParcoursStory(
        id: 't1',
        slug: 't-1',
        kind: ParcoursKind.text,
        fieldId: 'd07',
        tags: ['Droit'],
        personName: 'Awa',
        role: LocalizedText(fr: 'Avocate', en: 'Lawyer'),
        title: LocalizedText(fr: 'Titre', en: 'Title'),
        summary: LocalizedText(fr: 'Résumé', en: 'Summary'),
        interviewFr: [ParcoursQa(question: 'Q', answer: 'A')],
      );
      final restored = ParcoursStory.fromApi(original.toJson());
      expect(restored.slug, original.slug);
      expect(restored.kind, ParcoursKind.text);
      expect(restored.fieldId, 'd07');
      expect(restored.role.resolve('fr'), 'Avocate');
      expect(restored.interviewFr.length, 1);
      expect(restored.interviewFr.first.answer, 'A');
    });
  });
}
