// Le hub de l'espace « Études en France » (build 54), monté tel qu'en production.
//
// Ce que ce fichier garantit, pour l'étudiant : que chaque tuile mène quelque
// part (aucun « en préparation »), que la suspension d'un pays REMPLACE la date,
// que la déclaration se voit, se modifie et se retire DEPUIS ce hub (le texte de
// consentement le promet), et que rien ne déborde sur un petit téléphone.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';

import 'package:karatou/app/core/config/app_config.dart';
import 'package:karatou/app/core/data/eef_calendar.dart';
import 'package:karatou/app/core/repositories/app_snapshot.dart';
import 'package:karatou/app/core/services/remote_feature_flags.dart';
import 'package:karatou/app/features/etudes_en_france/eef_home_screen.dart';

import '../../support/raw_key_guard.dart';
import '../../support/screen_harness.dart';
import '../../widget_test_helpers.dart';

/// Un écran assez haut pour construire TOUTE la liste paresseuse d'un coup : les
/// tests de contenu cherchent des tuiles, pas la position du pli.
const _tall = KpbViewport(
  id: 'tall',
  name: 'Écran haut 393×2600',
  size: Size(393, 2600),
  padding: EdgeInsets.zero,
);

const _declaredBody = <String, dynamic>{
  'declared': true,
  'currentLevel': 'licence',
  'targetLevel': 'master',
  'fieldIds': ['d01', 'd07'],
  'wantsPremium': false,
  'consentedAt': '2026-09-30T10:00:00.000Z',
};

void main() {
  setUpAll(initializeDateFormatting);

  late MockApiClient api;

  setUp(() {
    api = MockApiClient();
    RemoteFeatureFlags.resetForTest();
    AppConfig.eefSpaceEnabledOverride = true;
    AppConfig.aiToolsEnabledOverride = null;
    Get.locale = const Locale('fr');
    EefCalendar.clock = () => DateTime(2026, 9, 28);
    EefCalendar.windowSource = () => EefCampaignWindow(
          opensAt: DateTime(2026, 10, 1),
          platformUrl: 'https://www.campusfrance.org/fr',
          suspendedCountries: const ['Niger'],
          suspendedSources: const {
            'niger': 'https://ne.diplomatie.gouv.fr/informations-visas',
          },
        );
  });

  tearDown(() {
    EefCalendar.resetForTest();
    RemoteFeatureFlags.resetForTest();
    AppConfig.eefSpaceEnabledOverride = null;
    AppConfig.aiToolsEnabledOverride = null;
    Get.reset();
  });

  void stubInterest(Map<String, dynamic>? body) {
    when(() => api.getEefInterest())
        .thenAnswer((_) async => body ?? <String, dynamic>{'declared': false});
  }

  Future<KpbScreenReport> pump(
    WidgetTester tester, {
    String country = 'Sénégal',
    String? currentLevel,
    List<String>? fieldIds,
    bool guest = false,
    KpbViewport viewport = iphone14,
    double textScale = 1.0,
  }) async {
    await seedKpbController(
      apiClient: api,
      snapshot: AppSnapshot(
        localeCode: 'fr',
        hasCompletedOnboarding: true,
        isGuestMode: guest,
        profile: guest
            ? null
            : createTestProfile(countryOfResidence: country).copyWith(
                currentLevel: currentLevel,
                fieldIds: fieldIds,
              ),
      ),
    );
    return pumpKpbScreen(
      tester,
      screen: const EefHomeScreen(),
      viewport: viewport,
      textScale: textScale,
    );
  }

  Future<void> scrollDown(WidgetTester tester) async {
    await tester.drag(find.byType(ListView).first, const Offset(0, -4000));
    await tester.pumpAndSettle();
  }

  group('les tuiles', () {
    testWidgets(
        'chaque tuile promise existe, et aucune n\'est « en préparation »',
        (tester) async {
      stubInterest(null);
      await pump(tester, viewport: _tall);

      expect(find.text('Trouver ma formation'), findsOneWidget);
      expect(find.text('Préparer mon dossier'), findsOneWidget);
      // Les trois outils : mêmes libellés que la boîte à outils.
      expect(find.text('cv_generator_title'.tr), findsOneWidget);
      expect(find.text('letters_title'.tr), findsOneWidget);
      expect(find.text('interview_title'.tr), findsOneWidget);
      // Aucun module annoncé qui n'existe pas.
      expect(find.text('En préparation'), findsNothing);
      expect(find.textContaining('arrivent'), findsNothing);
    });

    testWidgets('le masque des outils IA vaut aussi dans le hub',
        (tester) async {
      AppConfig.aiToolsEnabledOverride = false;
      stubInterest(null);
      await pump(tester, viewport: _tall);

      expect(find.text('Trouver ma formation'), findsOneWidget);
      expect(find.text('cv_generator_title'.tr), findsNothing);
      expect(find.text('letters_title'.tr), findsNothing);
      expect(find.text('interview_title'.tr), findsNothing);
      // Le hub reste utile : catalogue et conseiller ne dépendent pas de l'IA.
      expect(find.text('Parler à un conseiller'), findsOneWidget);
    });

    testWidgets('le héros dit où se dépose la candidature — dans son corps',
        (tester) async {
      stubInterest(null);
      await pump(tester);

      expect(
        find.textContaining('plateforme officielle Études en France'),
        findsOneWidget,
      );
      // L'enseigne du titre ne nomme pas l'agence (eef_naming_test).
      expect(find.text('Prépare ta candidature aux universités françaises'),
          findsOneWidget);
    });

    testWidgets('la promesse du catalogue ne cite plus ce qui n\'existe pas',
        (tester) async {
      stubInterest(null);
      await pump(tester);

      expect(find.textContaining('BTS'), findsNothing);
      expect(find.textContaining('commerce'), findsNothing);
      expect(find.textContaining('budget'), findsNothing);
    });
  });

  group('suspension et dates', () {
    testWidgets('un étudiant sénégalais lit la date, le caveat et le lien',
        (tester) async {
      stubInterest(null);
      await pump(tester, country: 'Sénégal');

      expect(find.textContaining('1er octobre 2026'), findsOneWidget);
      expect(find.text('eef_deadline_varies_notice'.tr), findsOneWidget);
      expect(find.text('Voir la plateforme officielle'), findsWidgets);
      expect(find.text('eef_suspended_notice'.tr), findsNothing);
    });

    testWidgets('un étudiant nigérien lit la mise en garde, PAS la date',
        (tester) async {
      stubInterest(null);
      await pump(tester, country: 'Niger');

      expect(find.text('eef_suspended_notice'.tr), findsOneWidget);
      expect(find.text('Voir la source officielle'), findsOneWidget);
      expect(find.textContaining('1er octobre 2026'), findsNothing);
      expect(find.text('eef_deadline_varies_notice'.tr), findsNothing);
    });
  });

  group('mon profil Études en France', () {
    testWidgets('pas encore déclaré → invitation à compléter', (tester) async {
      stubInterest(null);
      await pump(tester);
      await scrollDown(tester);

      expect(find.text('Mon profil Études en France'), findsOneWidget);
      expect(find.text('Compléter mon profil'), findsOneWidget);
      expect(find.text('Me retirer de la liste'), findsNothing);
    });

    testWidgets('déclaré → résumé lisible, Modifier et Me retirer',
        (tester) async {
      stubInterest(_declaredBody);
      await pump(tester);
      await scrollDown(tester);

      expect(find.text('Niveau actuel : Licence'), findsOneWidget);
      expect(find.text('Niveau visé : Master'), findsOneWidget);
      expect(
        find.textContaining('Informatique'),
        findsOneWidget,
        reason: 'les domaines se lisent en clair, pas en « d01 »',
      );
      expect(find.textContaining('d01'), findsNothing);
      expect(find.text('Modifier mon profil'), findsOneWidget);
      // La promesse du texte de consentement : « depuis cet écran ».
      expect(find.text('Me retirer de la liste'), findsOneWidget);
      expect(rawTranslationKeysOnScreen(tester), isEmpty);
    });

    testWidgets('« Me retirer » confirme, retire, et le dit', (tester) async {
      stubInterest(_declaredBody);
      when(() => api.withdrawEefInterest())
          .thenAnswer((_) async => <String, dynamic>{'declared': false});
      await pump(tester);
      await scrollDown(tester);

      await tester.tap(find.text('Me retirer de la liste'));
      await tester.pumpAndSettle();
      expect(find.text('Te retirer de la liste ?'), findsOneWidget);

      await tester.tap(find.text('Me retirer'));
      await tester.pumpAndSettle();

      verify(() => api.withdrawEefInterest()).called(1);
      expect(find.text('Tu es retiré de la liste.'), findsOneWidget);
      // Le bloc revient à « pas déclaré ».
      expect(find.text('Compléter mon profil'), findsOneWidget);
    });

    testWidgets('un retrait qui échoue le DIT et garde la déclaration',
        (tester) async {
      stubInterest(_declaredBody);
      when(() => api.withdrawEefInterest())
          .thenAnswer((_) async => <String, dynamic>{'declared': true});
      await pump(tester);
      await scrollDown(tester);

      await tester.tap(find.text('Me retirer de la liste'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Me retirer'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Retrait impossible'), findsOneWidget);
      expect(find.text('Modifier mon profil'), findsOneWidget);
    });

    testWidgets('annuler la confirmation ne retire rien', (tester) async {
      stubInterest(_declaredBody);
      await pump(tester);
      await scrollDown(tester);

      await tester.tap(find.text('Me retirer de la liste'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Annuler'));
      await tester.pumpAndSettle();

      verifyNever(() => api.withdrawEefInterest());
      expect(find.text('Modifier mon profil'), findsOneWidget);
    });

    testWidgets(
        '« Modifier » passe par PATCH et ne redemande pas le consentement',
        (tester) async {
      stubInterest(_declaredBody);
      when(() => api.updateEefProfile(
            currentLevel: any(named: 'currentLevel'),
            targetLevel: any(named: 'targetLevel'),
            fieldIds: any(named: 'fieldIds'),
          )).thenAnswer((_) async => <String, dynamic>{
            ..._declaredBody,
            'fieldIds': ['d01', 'd07', 'd02'],
          });
      await pump(tester);
      await scrollDown(tester);

      await tester.tap(find.text('Modifier mon profil'));
      await tester.pumpAndSettle();

      // La feuille d'édition : ni consentement, ni intérêt Premium.
      expect(find.text('eef_consent_notice'.tr), findsNothing);
      expect(find.text('eef_field_wants_premium'.tr), findsNothing);
      expect(find.text('Tes domaines (plusieurs choix possibles)'),
          findsOneWidget);

      // Un domaine de plus : d02.
      final d02 = find.byType(FilterChip).at(1);
      await tester.ensureVisible(d02);
      await tester.tap(d02);
      await tester.pump();
      await tester.ensureVisible(find.text('Valider'));
      await tester.tap(find.text('Valider'));
      await tester.pumpAndSettle();

      verify(() => api.updateEefProfile(
            currentLevel: 'licence',
            targetLevel: 'master',
            fieldIds: ['d01', 'd02', 'd07'],
          )).called(1);
      verifyNever(() => api.declareEefInterest(
            consentVersion: any(named: 'consentVersion'),
            currentLevel: any(named: 'currentLevel'),
            targetLevel: any(named: 'targetLevel'),
            fieldIds: any(named: 'fieldIds'),
            wantsPremium: any(named: 'wantsPremium'),
          ));
    });

    // EEF-UX-13 (2) : la première déclaration part de ce que le profil sait déjà,
    // par une table FERMÉE — jamais une copie de la chaîne du profil.
    testWidgets('la première déclaration est préremplie depuis le profil',
        (tester) async {
      stubInterest(null);
      when(() => api.declareEefInterest(
            consentVersion: any(named: 'consentVersion'),
            currentLevel: any(named: 'currentLevel'),
            targetLevel: any(named: 'targetLevel'),
            fieldIds: any(named: 'fieldIds'),
            wantsPremium: any(named: 'wantsPremium'),
          )).thenAnswer((_) async => _declaredBody);
      await pump(
        tester,
        // « bachelor_2 » est une ANNÉE du profil ; la déclaration attend un
        // NIVEAU. « zz » n'est pas un domaine connu : il doit être écarté.
        currentLevel: 'bachelor_2',
        fieldIds: ['d03', 'zz', 'd05'],
      );
      await scrollDown(tester);

      await tester.tap(find.text('Compléter mon profil'));
      await tester.pumpAndSettle();

      // Le consentement est annoncé, avant le bouton qui le donne.
      expect(find.text('eef_consent_notice'.tr), findsOneWidget);

      await tester.ensureVisible(find.text('Valider'));
      await tester.tap(find.text('Valider'));
      await tester.pumpAndSettle();

      verify(() => api.declareEefInterest(
            consentVersion: 'eef-consent-v1',
            currentLevel: 'licence',
            // Le profil de test vise un master : la même table fermée s'applique
            // au niveau visé.
            targetLevel: 'master',
            fieldIds: ['d03', 'd05'],
            wantsPremium: false,
          )).called(1);
    });

    testWidgets(
        'un invité n\'a pas de déclaration : il est invité à créer un compte',
        (tester) async {
      await pump(tester, guest: true);
      await scrollDown(tester);

      expect(find.text('Créer mon compte'), findsOneWidget);
      expect(find.text('Compléter mon profil'), findsNothing);
      // Et aucun appel : un invité n'a pas de session, l'appel reviendrait en 401.
      verifyNever(() => api.getEefInterest());
    });
  });

  group('géométrie', () {
    for (final viewport in kpbPhoneViewports) {
      for (final scale in kpbTextScales) {
        testWidgets('${viewport.id} ×$scale — profil déclaré', (tester) async {
          stubInterest(_declaredBody);
          final report = await pump(
            tester,
            viewport: viewport,
            textScale: scale,
          );
          expect(report.overflows, isEmpty, reason: report.toString());
          expect(report.otherErrors, isEmpty, reason: report.toString());
          expect(rawTranslationKeysOnScreen(tester), isEmpty);

          await scrollDown(tester);
          expect(truncatedTexts(tester), isEmpty);
        });

        testWidgets('${viewport.id} ×$scale — pays suspendu', (tester) async {
          stubInterest(null);
          final report = await pump(
            tester,
            country: 'Niger',
            viewport: viewport,
            textScale: scale,
          );
          expect(report.overflows, isEmpty, reason: report.toString());
          expect(truncatedTexts(tester), isEmpty);
        });
      }
    }
  });
}
