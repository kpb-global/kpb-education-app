import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:karatou/app/core/models/app_models.dart';
import 'package:karatou/app/core/services/app_search_service.dart';

FieldModel _field({
  required String id,
  required String nameFr,
  required String nameEn,
}) {
  return FieldModel(
    id: id,
    name: LocalizedText(fr: nameFr, en: nameEn),
    description: const LocalizedText(fr: 'Desc', en: 'Desc'),
    subjects: const [],
    careers: const [],
    dailyLife: const [],
    skills: const [],
    personalityTraits: const [],
    relatedCountryIds: const [],
    relatedScholarshipIds: const [],
    accentColor: Colors.blue,
  );
}

void main() {
  group('AppSearchService', () {
    late AppSearchContext ctx;
    late AppSearchService service;

    setUp(() {
      ctx = AppSearchContext(
        localeCode: 'fr',
        fields: [
          _field(id: 'f1', nameFr: 'Médecine', nameEn: 'Medicine'),
        ],
        countries: const [],
        institutions: const [],
        programs: const [],
        scholarships: const [],
        profile: null,
        latestOrientationSession: null,
      );
      service = AppSearchService(ctx);
    });

    test('run returns empty for empty or whitespace query', () {
      expect(service.run(''), isEmpty);
      expect(service.run('   '), isEmpty);
      expect(service.run('\t'), isEmpty);
    });

    test('run matches field by localized name (EN substring)', () {
      final results = service.run('med');
      expect(results, hasLength(1));
      expect(results.single.type, SearchResultType.field);
      expect(results.single.id, 'f1');
      expect(results.single.title, 'Médecine');
    });

    test('fieldMatch uses baseline score when profile is null', () {
      expect(service.fieldMatch(ctx.fields.single), 40);
    });
  });

  group('AppSearchContext', () {
    test('stores locale and empty catalog lists', () {
      const ctx = AppSearchContext(
        localeCode: 'en',
        fields: [],
        countries: [],
        institutions: [],
        programs: [],
        scholarships: [],
        profile: null,
        latestOrientationSession: null,
      );
      expect(ctx.localeCode, 'en');
      expect(ctx.fields, isEmpty);
      expect(ctx.profile, isNull);
    });
  });
}
