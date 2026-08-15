// M2 — l'envoi de documents en app est masqué, et il ne laisse AUCUNE promesse
// derrière lui.
//
// ## Ce qui se passait vraiment
//
// Deux chemins, deux mensonges différents.
//
//   · Le TUNNEL de création de dossier ne gardait qu'un chemin local de fichier
//     et écrivait son nom dans la description du dossier
//     (« Documents joints: • CV: IMG_1234.jpg »). Pas un octet ne partait :
//     `submitCase` n'a aucun paramètre de pièce jointe. L'étudiant croyait avoir
//     joint son passeport, le conseiller lisait un nom de fichier.
//   · L'ÉCRAN DE DOSSIER, seul chemin d'envoi réel, cochait `isProvided: true`
//     AVANT l'appel réseau, avalait l'échec dans Crashlytics et faisait
//     disparaître le bouton « Envoyer ». Côté serveur, le conteneur d'analyse
//     antivirale est mort et la route échoue fermé : la coche verte survivait à
//     un 503 que personne n'a jamais vu.
//
// ## Pourquoi masquer crée une impasse si on s'arrête là
//
// C'est l'objection qui a façonné ce fichier : retirer le bouton d'envoi laisse
// DEUX surfaces qui comptent les documents non fournis. Le calendrier
// d'échéances fabrique un jalon « document manquant » par demande non satisfaite,
// avec une route vers l'écran de dossier ; « Mon plan » calcule un pourcentage
// sur ces mêmes demandes. Un lot dont l'objectif est « plus aucune impasse » en
// aurait introduit une, sur deux surfaces, pour tout dossier créé.
//
// La réponse tient en deux mouvements, et il faut les deux :
//
//   (1) l'app cesse de FABRIQUER une demande que personne n'a formulée — la
//       demande `doc-profile` naissait à la création du dossier, sans conseiller
//       derrière ;
//   (2) les demandes VENUES DU SERVEUR restent affichées et deviennent
//       envoyables par WhatsApp — les masquer serait le mensonge inverse, car
//       celles-là un conseiller les a réellement écrites.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

import 'package:karatou/app/core/config/app_config.dart';
import 'package:karatou/app/core/controllers/app_controller.dart';
import 'package:karatou/app/core/data/my_plan_engine.dart';
import 'package:karatou/app/core/models/app_models.dart';
import 'package:karatou/app/core/repositories/app_snapshot.dart';
import 'package:karatou/app/core/translations/app_translations.dart';
import 'package:karatou/app/features/cases/case_detail_screen.dart';
import 'package:karatou/app/features/cases/case_tunnel_flow.dart';
import 'package:karatou/app/features/deadlines/deadline_calendar_screen.dart';

import '../widget_test_helpers.dart';

/// Enregistre les URL qu'on lui demande d'ouvrir — même couture officielle que
/// test/core/navigation/force_update_screen_test.dart.
class _RecordingLauncher extends Fake
    with MockPlatformInterfaceMixin
    implements UrlLauncherPlatform {
  final List<String> launched = <String>[];

  @override
  Future<bool> canLaunch(String url) async => true;

  @override
  Future<bool> launchUrl(String url, LaunchOptions options) async {
    launched.add(url);
    return true;
  }
}

AppSnapshot _emptySnapshot() => AppSnapshot(
      localeCode: 'fr',
      hasCompletedOnboarding: true,
      profile: createTestProfile(fullName: 'Awa Traoré'),
    );

/// Un dossier tel que le CODEC le construit depuis la réponse du serveur : la
/// demande de document vient d'un conseiller, pas de l'app.
StudentCase _caseWithServerDocument() {
  final now = DateTime.now();
  return StudentCase(
    id: 'case-m2',
    referenceCode: 'KPB-M2',
    type: CaseType.applicationSupport,
    title: const LocalizedText(fr: 'Dossier master', en: 'Master case'),
    description: const LocalizedText(fr: 'Desc', en: 'Desc'),
    contextLabel: const LocalizedText(fr: 'France', en: 'France'),
    status: CaseStatus.documentsNeeded,
    preferredContactMethod: ContactMethod.inApp,
    createdAt: now.subtract(const Duration(days: 2)),
    updatedAt: now,
    nextStepTitle: const LocalizedText(fr: 'Suite', en: 'Next'),
    nextStepDescription: const LocalizedText(fr: '', en: ''),
    timeline: const <CaseTimelineEvent>[],
    messages: const [],
    documentRequests: const [
      DocumentRequest(
        id: 'doc-transcripts',
        title: LocalizedText(fr: 'Relevés de notes', en: 'Transcripts'),
        isProvided: false,
      ),
    ],
  );
}

/// Un contrôleur hydraté, prêt pour `submitCase`.
Future<AppController> _controller([AppSnapshot? snapshot]) async {
  final controller = AppController(
    repository: FakeRepository(snapshot: snapshot ?? _emptySnapshot()),
    apiClient: MockApiClient(),
  );
  await controller.hydrate();
  Get.put<AppController>(controller, permanent: true);
  return controller;
}

/// `submitCase` termine par un `Get.snackbar`, qui exige un navigateur monté :
/// appelée depuis un `test()` nu, elle lève dans la file d'attente des snackbars
/// de GetX. D'où les `testWidgets` ci-dessous, même pour ce qui ressemble à de
/// la logique pure — c'est la production qui impose le contexte, pas le test.
Future<StudentCase> _submit(
  WidgetTester tester,
  AppController controller,
) async {
  final created = controller.submitCase(
    type: CaseType.applicationSupport,
    title: 'Master en France',
    description: 'Je souhaite candidater.',
    contextLabel: 'France • master',
    contactMethod: ContactMethod.inApp,
  );
  // Le snackbar de confirmation pose une minuterie de 4 s. La laisser courir
  // fait échouer le test sur « A Timer is still pending », c'est-à-dire pour une
  // raison qui n'a rien à voir avec les documents.
  await tester.pump(const Duration(seconds: 5));
  await tester.pumpAndSettle();
  return created;
}

Future<void> _pump(WidgetTester tester, Widget child) async {
  // Surface haute : l'écran de dossier et le calendrier sont des listes
  // paresseuses, et sur 800 px la section « Documents » n'est pas construite du
  // tout. Un test qui la cherche là trouve « rien » et déclare le masquage
  // réussi sans avoir rien mesuré.
  tester.view.physicalSize = const Size(1080, 2600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  await tester.pumpWidget(
    GetMaterialApp(
      home: Scaffold(body: child),
      debugShowCheckedModeBanner: false,
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  late _RecordingLauncher launcher;
  late UrlLauncherPlatform previousLauncher;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await initializeDateFormatting('fr');
  });

  setUp(() {
    resetGetxSingleton();
    setupPlatformChannelMocks();
    // Les traductions sont câblées ICI, contrairement à la plupart des tests du
    // dépôt : ce fichier vérifie le CONTENU du message pré-rempli — le nom du
    // document et la référence du dossier — et une clé brute ne prouverait rien
    // de ce que le conseiller recevra.
    Get.addTranslations(AppTranslations().keys);
    Get.locale = const Locale('fr');
    Get.fallbackLocale = const Locale('fr');
    previousLauncher = UrlLauncherPlatform.instance;
    launcher = _RecordingLauncher();
    UrlLauncherPlatform.instance = launcher;
  });

  tearDown(() {
    UrlLauncherPlatform.instance = previousLauncher;
    AppConfig.documentUploadEnabledOverride = null;
    AppConfig.enableRemoteSyncOverride = null;
    resetGetxSingleton();
  });

  group('l\'app ne fabrique plus de demande que personne n\'a formulée', () {
    testWidgets(
        'drapeau à FAUX : un dossier neuf naît sans demande de document',
        (tester) async {
      AppConfig.documentUploadEnabledOverride = false;
      final controller = await _controller();
      await _pump(tester, const SizedBox.shrink());

      final created = await _submit(tester, controller);

      expect(
        created.documentRequests,
        isEmpty,
        reason: 'La demande `doc-profile` est fabriquée par le client à la '
            'création du dossier — aucun conseiller ne l\'a écrite. Tant que '
            'l\'app ne sait pas recevoir le fichier, la produire crée un jalon '
            '« document manquant » et un bloc de progression bloqués à jamais.',
      );
    });

    testWidgets('contre-épreuve, drapeau à VRAI : la demande revient',
        (tester) async {
      AppConfig.documentUploadEnabledOverride = true;
      final controller = await _controller();
      await _pump(tester, const SizedBox.shrink());

      final created = await _submit(tester, controller);

      expect(created.documentRequests, hasLength(1));
      expect(created.documentRequests.single.id, 'doc-profile');
      expect(created.documentRequests.single.isProvided, isFalse);
    });
  });

  group('le calendrier d\'échéances ne montre aucun jalon fantôme', () {
    testWidgets('drapeau à FAUX : aucun jalon « document manquant »',
        (tester) async {
      AppConfig.documentUploadEnabledOverride = false;
      final controller = await _controller();

      await _pump(tester, const DeadlineCalendarScreen());
      await _submit(tester, controller);

      expect(
        find.textContaining('Document manquant'),
        findsNothing,
        reason: 'Un jalon renvoie vers l\'écran de dossier pour une action que '
            'l\'app n\'offre plus : c\'est l\'impasse que ce lot supprime, '
            'recréée par le lot lui-même.',
      );
    });

    testWidgets('contre-épreuve, drapeau à VRAI : le jalon réapparaît',
        (tester) async {
      AppConfig.documentUploadEnabledOverride = true;
      final controller = await _controller();

      await _pump(tester, const DeadlineCalendarScreen());
      await _submit(tester, controller);

      expect(
        find.textContaining('Document manquant'),
        findsOneWidget,
        reason: 'Sans ce retour, le test « aucun jalon » passerait au vert sur '
            'un calendrier vide pour toute autre raison.',
      );
    });
  });

  group('« Mon plan » ne compte plus de documents', () {
    testWidgets('drapeau à FAUX : le bloc Documents sort du dénominateur',
        (tester) async {
      AppConfig.documentUploadEnabledOverride = false;
      final controller = await _controller();
      await _pump(tester, const SizedBox.shrink());
      await _submit(tester, controller);

      final plan = MyPlanEngine.compute(
        profile: controller.profile,
        hasOrientationResult: false,
        cases: controller.cases,
      );
      final documents = plan.blocks
          .firstWhere((block) => block.block == MyPlanBlock.documents);

      expect(
        documents.applicable,
        isFalse,
        reason: 'Le bloc Documents resterait à 0 % pour toujours : l\'app ne '
            'peut plus rien envoyer, donc rien ne peut le faire monter.',
      );
    });

    testWidgets('contre-épreuve, drapeau à VRAI : le bloc redevient applicable',
        (tester) async {
      AppConfig.documentUploadEnabledOverride = true;
      final controller = await _controller();
      await _pump(tester, const SizedBox.shrink());
      await _submit(tester, controller);

      final plan = MyPlanEngine.compute(
        profile: controller.profile,
        hasOrientationResult: false,
        cases: controller.cases,
      );
      final documents = plan.blocks
          .firstWhere((block) => block.block == MyPlanBlock.documents);

      expect(documents.applicable, isTrue);
      expect(documents.progress, 0);
    });
  });

  group('le tunnel dit par où passent les documents', () {
    testWidgets('l\'étape 3 offre le conseiller, pas trois sélecteurs morts',
        (tester) async {
      AppConfig.documentUploadEnabledOverride = false;
      await _controller();

      await _pump(
        tester,
        const CaseTunnelFlow(
          prefill: CaseTunnelPrefill(
            title: 'Master en France',
            contextLabel: 'France • master',
          ),
        ),
      );

      // Deux « Suivant » pour atteindre l'étape des documents.
      await tester.tap(find.text('common_next'.tr));
      await tester.pumpAndSettle();
      await tester.tap(find.text('common_next'.tr));
      await tester.pumpAndSettle();

      expect(find.text('case_documents_handoff_cta'.tr), findsOneWidget);
      expect(
        find.text('common_add'.tr),
        findsNothing,
        reason: 'Les sélecteurs de fichier sont toujours là : ils gardent un '
            'chemin local et n\'envoient rien.',
      );
    });

    testWidgets('et la demande envoyée ne prétend plus porter de pièce jointe',
        (tester) async {
      AppConfig.documentUploadEnabledOverride = false;
      final controller = await _controller();

      await _pump(
        tester,
        const CaseTunnelFlow(
          prefill: CaseTunnelPrefill(
            title: 'Master en France',
            contextLabel: 'France • master',
          ),
        ),
      );

      // Les cinq étapes, jusqu'à l'envoi.
      for (var step = 0; step < 4; step++) {
        await tester.tap(find.text('common_next'.tr));
        await tester.pumpAndSettle();
      }
      await tester.tap(find.text('submit'.tr));
      // Le snackbar de confirmation pose une minuterie de 4 s. Sans ce drainage,
      // le test échoue sur « A Timer is still pending » — et, pire, la minuterie
      // fuit dans la zone du test SUIVANT, qu'elle fait échouer à son tour pour
      // une raison qui n'a plus aucun rapport avec ce qu'il mesure. C'est ainsi
      // que ce fichier a d'abord accusé le lanceur WhatsApp d'être muet alors
      // qu'il fonctionnait.
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();

      expect(controller.cases, hasLength(1));
      expect(
        controller.resolve(controller.cases.single.description),
        isNot(contains('case_tunnel_attached_documents_prefix'.tr)),
        reason: 'La description annonce des documents joints alors qu\'aucun '
            'octet n\'a été transmis — c\'est le mensonge exact que M2 retire.',
      );
    });
  });

  group('une demande VENUE DU SERVEUR reste visible et envoyable', () {
    testWidgets('le bouton change de destination, pas d\'existence',
        (tester) async {
      AppConfig.documentUploadEnabledOverride = false;
      await _controller(
        AppSnapshot(
          localeCode: 'fr',
          hasCompletedOnboarding: true,
          profile: createTestProfile(fullName: 'Awa Traoré'),
          cases: [_caseWithServerDocument()],
        ),
      );

      await _pump(tester, const CaseDetailScreen(caseId: 'case-m2'));

      expect(find.text('Relevés de notes'), findsOneWidget);
      expect(find.text('case_document_send_whatsapp'.tr), findsOneWidget);
      expect(
        find.text('case_document_send'.tr),
        findsNothing,
        reason: 'Le bouton d\'envoi en app est encore là : il cocherait '
            '« fourni ✓ » avant un appel réseau qui échoue fermé.',
      );
    });

    testWidgets('et il mène au conseiller, message déjà écrit', (tester) async {
      AppConfig.documentUploadEnabledOverride = false;
      await _controller(
        AppSnapshot(
          localeCode: 'fr',
          hasCompletedOnboarding: true,
          profile: createTestProfile(fullName: 'Awa Traoré'),
          cases: [_caseWithServerDocument()],
        ),
      );

      await _pump(tester, const CaseDetailScreen(caseId: 'case-m2'));
      await tester.tap(find.text('case_document_send_whatsapp'.tr));
      await tester.pumpAndSettle();

      // La feuille « conseiller vérifié » montre le message AVANT l'envoi.
      //
      // On cherche la phrase ENTIÈRE, et pas « Relevés de notes » : ce
      // fragment-là existe déjà deux fois sur l'écran de dossier, donc un
      // `textContaining` passerait au vert même si la feuille ne s'était jamais
      // ouverte. La leçon est la même que partout dans ce dépôt : un finder trop
      // large n'est pas une assertion, c'est une coïncidence.
      final expectedMessage = 'case_document_whatsapp_prefill'.trParams({
        'document': 'Relevés de notes',
        'reference': 'KPB-M2',
      });
      expect(
        find.text(expectedMessage),
        findsOneWidget,
        reason: 'Le message pré-rempli doit être visible avant l\'envoi, avec '
            'le nom du document ET la référence du dossier — sans elle, le '
            'conseiller reçoit un fichier qu\'il ne sait pas rattacher.',
      );

      await tester.tap(find.text('continue_to_whatsapp'.tr));
      // Le lancement traverse `Get.back` (animation de fermeture), puis un
      // `await canLaunchUrl`. `pumpAndSettle` rend la main dès qu'aucune frame
      // n'est planifiée, ce qui peut précéder cette micro-tâche : d'où le pump
      // temporisé, sans lequel le test échouerait sur un `launched` vide alors
      // que la production fonctionne.
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      expect(launcher.launched, isNotEmpty);
      final uri = Uri.parse(launcher.launched.single);
      expect(uri.host, 'wa.me');
      expect(uri.queryParameters['text'], expectedMessage);
    });
  });

  group('le point d\'étranglement, et pas seulement l\'interface', () {
    testWidgets(
        'uploadDocument refuse de cocher « fourni » pendant le masquage',
        (tester) async {
      AppConfig.documentUploadEnabledOverride = false;
      await _controller(
        AppSnapshot(
          localeCode: 'fr',
          hasCompletedOnboarding: true,
          profile: createTestProfile(),
          cases: [_caseWithServerDocument()],
        ),
      );
      final controller = Get.find<AppController>();

      controller.uploadDocument('case-m2', 'doc-transcripts', '/tmp/faux.pdf');

      expect(
        controller.cases.single.documentRequests.single.isProvided,
        isFalse,
        reason:
            'La garde n\'est posée que sur l\'écran. La leçon PARC-05 de ce '
            'dépôt est qu\'une garde d\'interface ne tient pas : le prochain '
            'appelant remettra la coche mensongère sans le savoir.',
      );
    });

    testWidgets(
        'contre-épreuve, drapeau à VRAI : la méthode fait de nouveau son '
        'travail', (tester) async {
      AppConfig.documentUploadEnabledOverride = true;
      await _controller(
        AppSnapshot(
          localeCode: 'fr',
          hasCompletedOnboarding: true,
          profile: createTestProfile(),
          cases: [_caseWithServerDocument()],
        ),
      );
      final controller = Get.find<AppController>();

      controller.uploadDocument('case-m2', 'doc-transcripts', '/tmp/faux.pdf');

      expect(
          controller.cases.single.documentRequests.single.isProvided, isTrue);
    });
  });
}
