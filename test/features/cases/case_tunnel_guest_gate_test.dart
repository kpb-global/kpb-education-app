// Le mur invité du tunnel de dossier — posé au POINT D'ÉTRANGLEMENT, pas sur
// une entrée.
//
// ## Le défaut, et pourquoi il a survécu
//
// Le mur existait dans deux fichiers (`case_create_screen` et `cases_screen`)
// alors que le tunnel a DIX-NEUF entrées mesurées : dix-sept
// `CaseComposerSheet(`, plus `case_create_screen` et `program_detail_screen`.
// Le CTA de héros de l'accueil est de celles-là — il est AFFICHÉ à l'invité —
// et il ouvrait le tunnel sans rencontrer la moindre garde.
//
// Ce que vivait l'invité : cinq étapes remplies, « Envoyer », puis un bandeau
// « Profil incomplet » qui lui parle d'un onboarding jamais commencé, sans
// bouton pour s'y rendre, et sa saisie perdue. L'étape de conversion la plus
// précieuse de l'app se terminait en cul-de-sac.
//
// ## Ce que ce fichier vérifie, et dans quel ordre
//
//   (1) Les TROIS constructions de `CaseTunnelFlow` — écran plein, feuille
//       modale, feuille du détail de programme — sont gardées. La feuille
//       modale est le cas qui échouait AVANT correctif : c'est la preuve que ce
//       test attrape le bug, et pas seulement qu'il décrit le correctif.
//   (2) L'assertion de non-régression qui aurait attrapé le défaut d'origine :
//       parcourir les cinq étapes en invité et taper « Envoyer » ne doit JAMAIS
//       faire apparaître `case_tunnel_incomplete_profile_title` en bandeau —
//       le chemin est devenu INATTEIGNABLE, pas seulement moins probable.
//   (3) Une garde statique contre une quatrième construction du tunnel.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';

import 'package:karatou/app/core/config/app_config.dart';
import 'package:karatou/app/core/controllers/app_controller.dart';
import 'package:karatou/app/core/models/app_models.dart';
import 'package:karatou/app/core/repositories/app_snapshot.dart';
import 'package:karatou/app/core/services/auth_service.dart';
import 'package:karatou/app/core/translations/app_translations.dart';
import 'package:karatou/app/features/cases/case_composer_sheet.dart';
import 'package:karatou/app/features/cases/case_create_screen.dart';
import 'package:karatou/app/features/cases/case_tunnel_flow.dart';

import '../../widget_test_helpers.dart';
import 'tunnel_entry_points.dart';

class _MockAuthService extends Mock implements AuthService {}

Future<AppController> _seed({
  required bool guest,
  UserProfile? profile,
}) async {
  AppConfig.enableRemoteSyncOverride = false;
  final controller = AppController(
    repository: FakeRepository(
      snapshot: AppSnapshot(
        localeCode: 'fr',
        hasCompletedOnboarding: !guest && profile != null,
        isGuestMode: guest,
        profile: profile,
      ),
    ),
    apiClient: MockApiClient(),
  );
  await controller.hydrate();
  Get.put<AppController>(controller, permanent: true);

  final auth = _MockAuthService();
  when(() => auth.onAuthStateChange).thenAnswer((_) => const Stream.empty());
  when(() => auth.isLoggedIn).thenReturn(false);
  Get.put<AuthService>(auth, permanent: true);
  return controller;
}

void _tallPhone(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

Widget _wrap(Widget home) => GetMaterialApp(
      translations: AppTranslations(),
      locale: const Locale('fr'),
      fallbackLocale: const Locale('fr'),
      home: home,
    );

const _prefill = CaseTunnelPrefill(
  title: 'Master en France',
  contextLabel: 'France • master',
);

/// L'en-tête d'étape du tunnel : « Étape 1/5 · Type ». Sa présence signifie que
/// l'utilisateur est ENTRÉ dans le tunnel.
///
/// On vise cette ligne-là et non le libellé « Type » seul : ce mot apparaît
/// ailleurs dans l'arbre, et un finder qui matche par coïncidence n'est pas une
/// assertion.
Finder get _firstStep =>
    find.textContaining('${'step_label'.tr} 1/5', findRichText: true);

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    resetGetxSingleton();
  });
  tearDown(() {
    AppConfig.enableRemoteSyncOverride = null;
    resetGetxSingleton();
  });

  group('(1) les trois entrées du tunnel sont gardées en mode invité', () {
    testWidgets('écran plein — CaseCreateScreen', (tester) async {
      await _seed(guest: true);
      _tallPhone(tester);

      await tester.pumpWidget(_wrap(const CaseCreateScreen()));
      await tester.pumpAndSettle();

      expect(find.text('guest_case_gate_cta'.tr), findsOneWidget);
      expect(_firstStep, findsNothing);
    });

    testWidgets(
        'feuille modale — CaseComposerSheet, le cas qui échouait avant correctif',
        (tester) async {
      await _seed(guest: true);
      _tallPhone(tester);

      // Montée comme en production : `showModalBottomSheet`. C'est par ce
      // chemin que passent dix-sept des dix-neuf entrées, dont le CTA de héros
      // de l'accueil, et c'est celui qu'aucune garde ne couvrait.
      await tester.pumpWidget(_wrap(
        Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) => CaseComposerSheet(
                    caseType: CaseType.consultation,
                    title: 'new_case'.tr,
                    contextLabel: 'KPB Education',
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.text('guest_case_gate_cta'.tr), findsOneWidget);
      expect(_firstStep, findsNothing);
    });

    testWidgets('feuille du détail de programme — CaseTunnelFlow direct',
        (tester) async {
      await _seed(guest: true);
      _tallPhone(tester);

      // `program_detail_screen` construit `CaseTunnelFlow` lui-même, dans une
      // `DraggableScrollableSheet`. On monte le widget tel qu'il le reçoit.
      await tester.pumpWidget(_wrap(
        const Scaffold(body: CaseTunnelFlow(prefill: _prefill)),
      ));
      await tester.pumpAndSettle();

      expect(find.text('guest_case_gate_cta'.tr), findsOneWidget);
      expect(_firstStep, findsNothing);
    });

    testWidgets('contre-épreuve — un compte complet entre bien dans le tunnel',
        (tester) async {
      await _seed(guest: false, profile: createTestProfile());
      _tallPhone(tester);

      await tester.pumpWidget(_wrap(
        const Scaffold(body: CaseTunnelFlow(prefill: _prefill)),
      ));
      await tester.pumpAndSettle();

      expect(
        _firstStep,
        findsWidgets,
        reason: 'Sans cette contre-épreuve, un tunnel cassé pour TOUT LE MONDE '
            'donnerait les mêmes verts que le masquage de l\'invité.',
      );
      expect(find.text('guest_case_gate_cta'.tr), findsNothing);
    });
  });

  group('(2) le bandeau « Profil incomplet » est devenu inatteignable', () {
    testWidgets(
        'un invité ne peut plus parcourir cinq étapes pour buter à l\'envoi',
        (tester) async {
      await _seed(guest: true);
      _tallPhone(tester);

      await tester.pumpWidget(_wrap(
        const Scaffold(body: CaseTunnelFlow(prefill: _prefill)),
      ));
      await tester.pumpAndSettle();

      // On TENTE le parcours complet, comme le faisait l'utilisateur. Chaque
      // « Suivant » est facultatif : s'il n'existe pas, le mur a fait son
      // travail et la boucle ne fait rien.
      for (var step = 0; step < 4; step++) {
        final next = find.text('common_next'.tr);
        if (next.evaluate().isEmpty) break;
        await tester.tap(next);
        await tester.pumpAndSettle();
      }
      final submit = find.text('submit'.tr);
      if (submit.evaluate().isNotEmpty) {
        await tester.tap(submit);
        await tester.pump(const Duration(seconds: 5));
        await tester.pumpAndSettle();
      }

      expect(
        find.text('case_tunnel_incomplete_profile_title'.tr),
        findsNothing,
        reason: 'C\'est l\'assertion qui aurait attrapé le défaut d\'origine. '
            'Le bandeau parlait d\'un onboarding jamais commencé, sans bouton '
            'pour s\'y rendre, après cinq étapes de saisie perdues.',
      );
      // Et il n'a jamais quitté le mur.
      expect(find.text('guest_case_gate_cta'.tr), findsOneWidget);
    });

    testWidgets(
        'un compte réel sans profil reçoit un CHEMIN, pas un constat d\'échec',
        (tester) async {
      await _seed(guest: false);
      _tallPhone(tester);

      await tester.pumpWidget(_wrap(
        const Scaffold(body: CaseTunnelFlow(prefill: _prefill)),
      ));
      await tester.pumpAndSettle();

      expect(
          find.text('case_tunnel_incomplete_profile_title'.tr), findsOneWidget);
      expect(
        find.text('case_tunnel_incomplete_profile_cta'.tr),
        findsOneWidget,
        reason: 'Le bandeau d\'origine énonçait le problème sans donner le '
            'moindre moyen de le résoudre — la définition d\'une impasse.',
      );
      expect(_firstStep, findsNothing);
    });
  });

  group('(3) garde statique — le tunnel garde UN seul point d\'entrée gardé',
      () {
    test('aucune quatrième construction de CaseTunnelFlow', () {
      final measured = measuredTunnelConstructionSites();

      expect(
        measured.keys.toSet(),
        kDeclaredTunnelHosts.keys.toSet(),
        reason: 'Un fichier construit `CaseTunnelFlow(` sans figurer dans la '
            'liste déclarée. Ce n\'est pas forcément un bug — la garde vit '
            'DANS le tunnel, donc une entrée de plus est protégée d\'office — '
            'mais chaque construction est une occasion de contourner le point '
            'd\'étranglement, et personne ne doit en ajouter une sans le voir.\n'
            'Mesuré : ${measured.keys.join(', ')}',
      );
      expect(measured, kDeclaredTunnelHosts);
    });

    test(
        'les feuilles CaseComposerSheet, elles, peuvent se multiplier sans '
        'risque', () {
      // Et c'est tout l'objet du déplacement de la garde. Avant, chaque nouvelle
      // feuille était une entrée non gardée de plus ; aujourd'hui elles passent
      // toutes par le `build` du tunnel. Ce test ne compte donc PAS les
      // feuilles : il affirme seulement qu'elles existent en nombre, pour que la
      // prochaine personne comprenne pourquoi il n'y a pas de liste à tenir.
      expect(
        measuredComposerSheetSiteCount(),
        greaterThan(10),
        reason: 'Si ce nombre tombait à zéro, le tunnel aurait changé de forme '
            'et cette architecture mériterait d\'être relue.',
      );
    });
  });
}
