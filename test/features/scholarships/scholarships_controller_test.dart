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

  // A profile with a field of interest used to filter the whole published
  // catalog out server-side (`relatedFieldIds` is empty on every write path
  // until an admin curates it), and the screen reported "no scholarships found".
  // The profile criteria must degrade to a ranking preference, not an outage.
  test('retries without the profile criteria when they match nothing',
      () async {
    final api = MockApiClient();
    when(
      () => api.fetchLiveScholarships(
        lang: 'fr',
        level: 'Master',
        fieldIds: <String>['d01'],
        fundingType: null,
        limit: 20,
        offset: 0,
      ),
    ).thenAnswer((_) async => <dynamic>[]);
    when(
      () => api.fetchLiveScholarships(
        lang: 'fr',
        level: null,
        fieldIds: null,
        fundingType: null,
        limit: 20,
        offset: 0,
      ),
    ).thenAnswer((_) async => <dynamic>[scholarshipJson(1)]);
    when(() => api.fetchScholarshipAlerts())
        .thenAnswer((_) async => <String>{});

    final controller = ScholarshipsController(
      apiClient: api,
      lang: 'fr',
      level: 'Master',
      fieldIds: const <String>['d01'],
    );
    await controller.loadInitial();

    expect(controller.items, hasLength(1));
    expect(controller.profileFiltersRelaxed, isTrue);
    expect(controller.error, isNull);
  });

  test('keeps the profile criteria when they do match', () async {
    final api = MockApiClient();
    when(
      () => api.fetchLiveScholarships(
        lang: 'fr',
        level: 'Master',
        fieldIds: <String>['d01'],
        fundingType: null,
        limit: 20,
        offset: 0,
      ),
    ).thenAnswer((_) async => <dynamic>[scholarshipJson(1)]);
    when(() => api.fetchScholarshipAlerts())
        .thenAnswer((_) async => <String>{});

    final controller = ScholarshipsController(
      apiClient: api,
      lang: 'fr',
      level: 'Master',
      fieldIds: const <String>['d01'],
    );
    await controller.loadInitial();

    expect(controller.items, hasLength(1));
    expect(controller.profileFiltersRelaxed, isFalse);
    verifyNever(
      () => api.fetchLiveScholarships(
        lang: 'fr',
        level: null,
        fieldIds: null,
        fundingType: null,
        limit: 20,
        offset: 0,
      ),
    );
  });

  test('re-attempts the profile criteria on a later reload', () async {
    final api = MockApiClient();
    var filteredCalls = 0;
    when(
      () => api.fetchLiveScholarships(
        lang: 'fr',
        level: null,
        fieldIds: <String>['d01'],
        fundingType: null,
        limit: 20,
        offset: 0,
      ),
    ).thenAnswer((_) async {
      filteredCalls += 1;
      // Curated only by the time of the second load.
      return filteredCalls == 1 ? <dynamic>[] : <dynamic>[scholarshipJson(2)];
    });
    when(
      () => api.fetchLiveScholarships(
        lang: 'fr',
        level: null,
        fieldIds: null,
        fundingType: null,
        limit: 20,
        offset: 0,
      ),
    ).thenAnswer((_) async => <dynamic>[scholarshipJson(1)]);
    when(() => api.fetchScholarshipAlerts())
        .thenAnswer((_) async => <String>{});

    final controller = ScholarshipsController(
      apiClient: api,
      lang: 'fr',
      fieldIds: const <String>['d01'],
    );
    await controller.loadInitial();
    expect(controller.profileFiltersRelaxed, isTrue);

    await controller.loadInitial();

    expect(filteredCalls, 2);
    expect(controller.profileFiltersRelaxed, isFalse);
  });

  test('clearAllFilters drops funding and profile criteria for good', () async {
    final api = MockApiClient();
    when(
      () => api.fetchLiveScholarships(
        lang: 'fr',
        level: null,
        fieldIds: null,
        fundingType: null,
        limit: 20,
        offset: 0,
      ),
    ).thenAnswer((_) async => <dynamic>[scholarshipJson(1)]);
    when(() => api.fetchScholarshipAlerts())
        .thenAnswer((_) async => <String>{});

    final controller = ScholarshipsController(
      apiClient: api,
      lang: 'fr',
      level: 'Master',
      fieldIds: const <String>['d01'],
    )..fundingFilter = 'fully_funded';

    await controller.clearAllFilters();

    expect(controller.fundingFilter, 'all');
    expect(controller.profileFiltersRelaxed, isTrue);
    expect(controller.items, hasLength(1));

    // Sticky: a pull-to-refresh must not silently re-apply what the student
    // explicitly cleared.
    await controller.loadInitial();
    expect(controller.profileFiltersRelaxed, isTrue);
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
