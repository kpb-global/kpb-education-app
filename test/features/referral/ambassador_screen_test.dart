import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:karatou/app/core/repositories/app_snapshot.dart';
import 'package:karatou/app/features/referral/ambassador_screen.dart';

import '../../widget_test_helpers.dart';

Map<String, dynamic> _sampleDashboard() => {
      'activated': false,
      'isSample': true,
      'ambassador': {
        'displayName': 'Binta Sarr',
        'campus': 'Ambassadrice campus — UCAD Dakar',
        'city': 'Dakar',
        'initials': 'BS',
        'code': 'KTOU-BS-7c21',
        'rankLabel': 'Top 3 Dakar',
        'payoutMethod': 'wave',
        'payoutAccountMasked': '+221 77 ••• 45 21',
      },
      'stats': {'activeReferrals': 12, 'placed': 3, 'earnedFCFA': 117000},
      'objective': {'target': 15, 'current': 12, 'bonusFCFA': 10000},
      'rewards': [
        {'reason': 'referral_signup', 'amountFCFA': 1000},
        {'reason': 'referral_placed', 'amountFCFA': 35000},
      ],
      'leaderboard': [
        {'rank': 1, 'name': 'Omar F.', 'initials': 'OF', 'referrals': 19, 'isMe': false},
        {'rank': 2, 'name': 'Binta Sarr', 'initials': 'BS', 'referrals': 12, 'isMe': true},
      ],
      'referrals': [
        {'name': 'Aïcha Diallo', 'initials': 'AD', 'note': 'Dossier Grenoble', 'status': 'application_created', 'gainFCFA': 1000},
        {'name': 'Moussa Dieng', 'initials': 'MD', 'note': 'Admis à Laval', 'status': 'placed', 'gainFCFA': 36000},
      ],
      'balanceFCFA': 47000,
      'withdrawableFCFA': 47000,
      'minWithdrawalFCFA': 20000,
      'history': [
        {'label': 'Moussa placé', 'date': '2026-07-02', 'kind': 'referral_placed', 'amountFCFA': 35000},
        {'label': 'Retrait Wave', 'date': '2026-06-28', 'kind': 'withdrawal', 'amountFCFA': -25000},
      ],
    };

void main() {
  setUp(resetGetxSingleton);
  tearDown(resetGetxSingleton);

  Future<void> pump(WidgetTester tester, MockApiClient mock) async {
    tester.view.physicalSize = const Size(1200, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await pumpTestApp(
      tester,
      child: const AmbassadorScreen(),
      initialSnapshot: AppSnapshot(
        localeCode: 'fr',
        hasCompletedOnboarding: true,
        profile: createTestProfile(),
      ),
      mockApiClient: mock,
    );
    await tester.pumpAndSettle();
  }

  testWidgets('renders the dashboard: code, stats and sample banner',
      (tester) async {
    final mock = MockApiClient();
    when(() => mock.getAmbassadorDashboard())
        .thenAnswer((_) async => _sampleDashboard());

    await pump(tester, mock);

    // Note: in the test env GetX translations resolve to their KEYS, so we
    // assert on keys + locale-independent computed values (formatted amounts).
    expect(find.text('KTOU-BS-7c21'), findsOneWidget);
    expect(find.text('Binta Sarr'), findsWidgets); // header + leaderboard
    expect(find.text('12'), findsWidgets); // active referrals
    expect(find.text('amb_sample_banner'), findsOneWidget);
    expect(find.text('117 k'), findsOneWidget); // compact earned
  });

  testWidgets('switches to the withdrawals tab and shows the balance',
      (tester) async {
    final mock = MockApiClient();
    when(() => mock.getAmbassadorDashboard())
        .thenAnswer((_) async => _sampleDashboard());

    await pump(tester, mock);

    // Bottom-nav "Retraits" label.
    await tester.tap(find.text('amb_nav_payout'));
    await tester.pumpAndSettle();

    expect(find.text('amb_balance_label'), findsOneWidget);
    expect(find.text('47 000 FCFA'), findsWidgets);
  });

  testWidgets('withdraw requests a payout and shows the pending state',
      (tester) async {
    final mock = MockApiClient();
    when(() => mock.getAmbassadorDashboard())
        .thenAnswer((_) async => _sampleDashboard());
    when(() => mock.requestAmbassadorWithdrawal()).thenAnswer((_) async =>
        {'id': 'wd-1', 'amountFCFA': 47000, 'status': 'requested', 'etaHours': 48});

    await pump(tester, mock);
    await tester.tap(find.text('amb_nav_payout'));
    await tester.pumpAndSettle();

    // The withdraw button label is the (unresolved) 'amb_withdraw' key here.
    await tester.tap(find.text('amb_withdraw'));
    await tester.pumpAndSettle();

    verify(() => mock.requestAmbassadorWithdrawal()).called(1);
    expect(find.text('amb_withdraw_pending'), findsOneWidget);
  });
}
