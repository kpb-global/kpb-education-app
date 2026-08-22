// La feuille de déclaration : l'échec est À L'ÉCRAN, et il y RESTE.
//
// C'est la moitié visible de la règle éprouvée dans
// `eef_interest_controller_test.dart`. Le contrôleur garantit qu'un échec ne
// devient pas un état de succès ; ce fichier garantit que l'étudiant le VOIT.
//
// Le défaut évité, mot pour mot : un `Navigator.pop()` optimiste suivi d'un
// toast laisse l'étudiant devant un écran inchangé, avec un message qui
// disparaît en trois secondes et la conviction d'avoir répondu. Le masquage
// `documentUploadEnabled` existe pour cette raison exacte, une surface plus tôt.

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';

import 'package:karatou/app/core/repositories/app_api_client.dart';
import 'package:karatou/app/core/translations/app_translations.dart';
import 'package:karatou/app/features/etudes_en_france/eef_interest_controller.dart';
import 'package:karatou/app/features/etudes_en_france/eef_interest_sheet.dart';

class _MockApiClient extends Mock implements AppApiClient {}

DioException _dio(DioExceptionType type) => DioException(
      requestOptions: RequestOptions(path: '/etudes-en-france/interest'),
      type: type,
    );

/// Monte un bouton qui ouvre la feuille, avec les traductions de production.
Future<EefInterestController> _pumpSheet(
  WidgetTester tester,
  AppApiClient api, {
  required void Function(bool?) onClosed,
}) async {
  final controller = EefInterestController(apiClient: api);
  addTearDown(controller.dispose);

  Get.addTranslations(AppTranslations().keys);
  Get.locale = const Locale('fr');
  Get.fallbackLocale = const Locale('fr');

  await tester.pumpWidget(
    GetMaterialApp(
      translations: AppTranslations(),
      locale: const Locale('fr'),
      fallbackLocale: const Locale('fr'),
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () async {
                final result =
                    await showEefInterestSheet(context, controller: controller);
                onClosed(result);
              },
              child: const Text('ouvrir'),
            ),
          ),
        ),
      ),
    ),
  );

  await tester.tap(find.text('ouvrir'));
  await tester.pumpAndSettle();
  return controller;
}

void main() {
  late _MockApiClient api;

  setUp(() => api = _MockApiClient());
  tearDown(Get.reset);

  void stubDeclare(dynamic Function() answer) {
    when(() => api.declareEefInterest(
          consentVersion: any(named: 'consentVersion'),
          currentLevel: any(named: 'currentLevel'),
          targetLevel: any(named: 'targetLevel'),
          fieldIds: any(named: 'fieldIds'),
          wantsPremium: any(named: 'wantsPremium'),
        )).thenAnswer((_) async => answer() as Map<String, dynamic>);
  }

  testWidgets('sur ÉCHEC : la feuille reste ouverte et affiche la raison',
      (tester) async {
    when(() => api.declareEefInterest(
          consentVersion: any(named: 'consentVersion'),
          currentLevel: any(named: 'currentLevel'),
          targetLevel: any(named: 'targetLevel'),
          fieldIds: any(named: 'fieldIds'),
          wantsPremium: any(named: 'wantsPremium'),
        )).thenThrow(_dio(DioExceptionType.connectionError));

    bool? closedWith;
    final controller =
        await _pumpSheet(tester, api, onClosed: (r) => closedWith = r);

    await tester.tap(find.text('eef_sheet_confirm'.tr));
    await tester.pumpAndSettle();

    // La feuille est TOUJOURS là.
    expect(find.text('eef_sheet_title'.tr), findsOneWidget);
    expect(closedWith, isNull, reason: 'la feuille ne doit pas s\'être fermée');

    // L'erreur est à l'écran, en clair, et ne s'efface pas.
    expect(find.text('eef_error_network'.tr), findsOneWidget);

    // Le bouton propose de RÉESSAYER — donc l'action reste possible.
    expect(find.text('eef_sheet_retry'.tr), findsOneWidget);

    // Et surtout : aucun état de succès nulle part.
    expect(controller.declared, isFalse);
    expect(find.text('eef_interest_recorded_title'.tr), findsNothing);

    // L'erreur SURVIT à plusieurs cadres — ce n'est pas un toast.
    await tester.pump(const Duration(seconds: 5));
    expect(find.text('eef_error_network'.tr), findsOneWidget);
  });

  testWidgets('sur SUCCÈS : la feuille se ferme en confirmant', (tester) async {
    stubDeclare(() => <String, dynamic>{
          'declared': true,
          'wantsPremium': true,
          'fieldIds': <String>[],
          'consentedAt': '2026-08-21T10:00:00.000Z',
        });

    bool? closedWith;
    final controller =
        await _pumpSheet(tester, api, onClosed: (r) => closedWith = r);

    await tester.tap(find.text('eef_sheet_confirm'.tr));
    await tester.pumpAndSettle();

    expect(closedWith, isTrue);
    expect(find.text('eef_sheet_title'.tr), findsNothing);
    expect(controller.declared, isTrue);
  });

  // Une réponse 2xx dont le corps ne confirme rien doit se voir comme un échec,
  // pas se fermer sur un succès. C'est le cas limite du défaut d'origine.
  testWidgets('un 2xx sans confirmation garde la feuille ouverte',
      (tester) async {
    stubDeclare(() => <String, dynamic>{'declared': false});

    bool? closedWith;
    await _pumpSheet(tester, api, onClosed: (r) => closedWith = r);

    await tester.tap(find.text('eef_sheet_confirm'.tr));
    await tester.pumpAndSettle();

    expect(closedWith, isNull);
    expect(find.text('eef_error_server'.tr), findsOneWidget);
  });

  testWidgets('le consentement est ANNONCÉ avant le bouton qui le donne',
      (tester) async {
    await _pumpSheet(tester, api, onClosed: (_) {});

    expect(find.text('eef_consent_notice'.tr), findsOneWidget);

    final noticeY =
        tester.getRect(find.text('eef_consent_notice'.tr)).center.dy;
    final buttonY = tester.getRect(find.text('eef_sheet_confirm'.tr)).center.dy;

    expect(noticeY, lessThan(buttonY),
        reason: 'Une preuve de consentement horodatée par le serveur n\'a de '
            'valeur que si l\'écran a dit AVANT à quoi l\'étudiant consent.');
  });

  testWidgets('annuler ne déclare rien', (tester) async {
    bool? closedWith;
    final controller =
        await _pumpSheet(tester, api, onClosed: (r) => closedWith = r);

    await tester.tap(find.text('eef_sheet_cancel'.tr));
    await tester.pumpAndSettle();

    expect(closedWith, isFalse);
    expect(controller.declared, isFalse);
    verifyNever(() => api.declareEefInterest(
          consentVersion: any(named: 'consentVersion'),
          currentLevel: any(named: 'currentLevel'),
          targetLevel: any(named: 'targetLevel'),
          fieldIds: any(named: 'fieldIds'),
          wantsPremium: any(named: 'wantsPremium'),
        ));
  });
}
