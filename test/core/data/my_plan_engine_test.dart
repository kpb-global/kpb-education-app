import 'package:flutter_test/flutter_test.dart';

import 'package:karatou/app/core/data/my_plan_engine.dart';
import 'package:karatou/app/core/models/app_models.dart';

/// Guards KPB-164: the unified score moves with real progress, exposes exactly
/// ONE next action, and never invents an outstanding task (documents are only
/// counted once an advisor has actually requested something).
void main() {
  UserProfile emptyProfile() => UserProfile(
        id: 'u-1',
        accountType: AccountType.student,
        fullName: '',
        email: '',
        phone: '',
        whatsApp: '',
        countryOfResidence: '',
        preferredLanguage: 'fr',
      );

  UserProfile fullProfile() => UserProfile(
        id: 'u-1',
        accountType: AccountType.student,
        fullName: 'Awa Diallo',
        email: 'awa@example.com',
        phone: '+221770000000',
        whatsApp: '+221770000000',
        countryOfResidence: 'SN',
        preferredLanguage: 'fr',
        currentLevel: 'Licence',
        targetLevel: 'Master',
        languageLevel: 'B2',
        fieldIds: const ['d01'],
        targetCountryIds: const ['fra'],
        gradeRange: '15-16',
        annualTuitionBudgetEur: 6000,
        availableDocuments: const ['Passport'],
      );

  StudentCase caseWith({
    List<DocumentRequest> requests = const [],
    CaseStatus status = CaseStatus.submitted,
    String id = 'case-1',
  }) {
    const t = LocalizedText(fr: 'x', en: 'x');
    return StudentCase(
      id: id,
      referenceCode: 'KPB-2026-001',
      type: CaseType.consultation,
      title: t,
      description: t,
      contextLabel: t,
      status: status,
      preferredContactMethod: ContactMethod.whatsapp,
      createdAt: DateTime(2026, 7, 1),
      updatedAt: DateTime(2026, 7, 2),
      nextStepTitle: t,
      nextStepDescription: t,
      timeline: const [],
      messages: const [],
      documentRequests: requests,
    );
  }

  test('a guest (no profile) has no plan', () {
    final plan = MyPlanEngine.compute(
      profile: null,
      hasOrientationResult: false,
      cases: const [],
    );
    expect(plan.percentRounded, 0);
    expect(plan.nextBlock, isNull);
    expect(plan.blocks, isEmpty);
  });

  test('AC: the score moves as the profile fills in', () {
    final low = MyPlanEngine.compute(
      profile: emptyProfile(),
      hasOrientationResult: false,
      cases: const [],
    );
    final high = MyPlanEngine.compute(
      profile: fullProfile(),
      hasOrientationResult: false,
      cases: const [],
    );
    expect(high.percentRounded, greaterThan(low.percentRounded));
  });

  test('AC: the score moves when a document is provided', () {
    const pending = DocumentRequest(
      id: 'd1',
      title: LocalizedText(fr: 'Passeport', en: 'Passport'),
      isProvided: false,
    );
    final before = MyPlanEngine.compute(
      profile: fullProfile(),
      hasOrientationResult: true,
      cases: [
        caseWith(requests: const [pending])
      ],
    );
    final after = MyPlanEngine.compute(
      profile: fullProfile(),
      hasOrientationResult: true,
      cases: [
        caseWith(requests: [pending.copyWith(isProvided: true)])
      ],
    );
    expect(after.percentRounded, greaterThan(before.percentRounded));
    // Everything applicable is now done ⇒ no next action, card self-hides.
    expect(after.nextBlock, isNull);
    expect(after.percentRounded, 100);
  });

  test('AC: exactly one next action, in priority order', () {
    // Nothing done ⇒ the profile comes first.
    final fresh = MyPlanEngine.compute(
      profile: emptyProfile(),
      hasOrientationResult: false,
      cases: const [],
    );
    expect(fresh.nextBlock?.block, MyPlanBlock.profile);

    // Profile done ⇒ orientation is next.
    final profiled = MyPlanEngine.compute(
      profile: fullProfile(),
      hasOrientationResult: false,
      cases: const [],
    );
    expect(profiled.nextBlock?.block, MyPlanBlock.orientation);

    // Profile + orientation done ⇒ open a dossier.
    final oriented = MyPlanEngine.compute(
      profile: fullProfile(),
      hasOrientationResult: true,
      cases: const [],
    );
    expect(oriented.nextBlock?.block, MyPlanBlock.dossier);
    expect(oriented.nextBlock?.route, '/new-case');
  });

  test('documents are excluded until an advisor requests one', () {
    final noRequests = MyPlanEngine.compute(
      profile: fullProfile(),
      hasOrientationResult: true,
      cases: [caseWith()],
    );
    // Profile + orientation + dossier all complete and documents not applicable
    // ⇒ 100 %, no fabricated outstanding task.
    expect(noRequests.percentRounded, 100);
    expect(noRequests.nextBlock, isNull);
    expect(
      noRequests.blocks
          .firstWhere((b) => b.block == MyPlanBlock.documents)
          .applicable,
      isFalse,
    );

    final withRequest = MyPlanEngine.compute(
      profile: fullProfile(),
      hasOrientationResult: true,
      cases: [
        caseWith(requests: const [
          DocumentRequest(
            id: 'd1',
            title: LocalizedText(fr: 'CV', en: 'CV'),
            isProvided: false,
          ),
        ]),
      ],
    );
    expect(withRequest.nextBlock?.block, MyPlanBlock.documents);
    expect(withRequest.percentRounded, lessThan(100));
  });

  test('closed dossiers do not count as active progress', () {
    final closed = MyPlanEngine.compute(
      profile: fullProfile(),
      hasOrientationResult: true,
      cases: [caseWith(status: CaseStatus.completed)],
    );
    // The completed dossier is ignored ⇒ opening one is still the next action.
    expect(closed.nextBlock?.block, MyPlanBlock.dossier);
  });
}
