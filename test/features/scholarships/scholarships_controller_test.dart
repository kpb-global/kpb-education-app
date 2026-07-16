import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:karatou/app/features/scholarships/scholarships_controller.dart';

import '../../widget_test_helpers.dart';

Map<String, dynamic> scholarshipJson(int index) => <String, dynamic>{
      'id': 'sch-$index',
      'title': 'Scholarship $index',
      'countryName': 'International',
      'fundingType': 'fully_funded',
      'description': '',
      'advantages': <String>[],
      'eligibility': <String>[],
      'level': 'Master',
      'deadlineLabel': '',
      'applicationUrl': '',
      'tags': <String>[],
      'matchScore': 50,
    };

void main() {
  test('loads subsequent offset pages and stops after a short page', () async {
    final api = MockApiClient();
    final firstPage = List<dynamic>.generate(20, scholarshipJson);
    final secondPage = <dynamic>[scholarshipJson(20)];

    when(
      () => api.fetchLiveScholarships(
        lang: 'fr',
        level: null,
        fieldIds: null,
        fundingType: null,
        limit: 20,
        offset: 0,
      ),
    ).thenAnswer((_) async => firstPage);
    when(
      () => api.fetchLiveScholarships(
        lang: 'fr',
        level: null,
        fieldIds: null,
        fundingType: null,
        limit: 20,
        offset: 20,
      ),
    ).thenAnswer((_) async => secondPage);
    when(() => api.fetchScholarshipAlerts())
        .thenAnswer((_) async => <String>{'sch-2'});

    final controller = ScholarshipsController(apiClient: api, lang: 'fr');
    await controller.loadInitial();

    expect(controller.items, hasLength(20));
    expect(controller.hasMore, isTrue);
    expect(controller.alertedScholarshipIds, contains('sch-2'));

    await controller.loadMore();

    expect(controller.items, hasLength(21));
    expect(controller.hasMore, isFalse);
  });

  test('keeps list alert state when alert reconciliation is unavailable',
      () async {
    final api = MockApiClient();
    final item = scholarshipJson(1)..['isAlertEnabled'] = true;
    when(
      () => api.fetchLiveScholarships(
        lang: 'fr',
        level: null,
        fieldIds: null,
        fundingType: null,
        limit: 20,
        offset: 0,
      ),
    ).thenAnswer((_) async => <dynamic>[item]);
    when(() => api.fetchScholarshipAlerts())
        .thenThrow(Exception('temporarily unavailable'));

    final controller = ScholarshipsController(apiClient: api, lang: 'fr');
    await controller.loadInitial();

    expect(controller.alertedScholarshipIds, contains('sch-1'));
  });
}
