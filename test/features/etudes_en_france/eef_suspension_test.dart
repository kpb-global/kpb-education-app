// La suspension par pays : le cas Niger.
//
// La source officielle de l'ambassade dit que la dénonciation de la convention
// du centre qui hébergeait Campus France rend impossible le traitement des
// dossiers d'étudiants nigériens. L'ouverture nationale de la plateforme reste
// exacte — et sans effet pour eux. Annoncer « ouverture le 1er octobre » à un
// étudiant nigérien, c'est l'envoyer vers une démarche que l'État français
// déclare inopérante.
//
// Le point fragile est la COMPARAISON : `countryOfResidence` porte un nom
// français, choisi dans une liste à l'onboarding mais saisi en TEXTE LIBRE sur
// l'écran de profil. C'est donc la normalisation qui est éprouvée ici.

import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:karatou/app/core/config/app_config.dart';
import 'package:karatou/app/core/data/eef_calendar.dart';
import 'package:karatou/app/core/repositories/app_snapshot.dart';
import 'package:karatou/app/core/services/remote_feature_flags.dart';
import 'package:karatou/app/features/etudes_en_france/eef_teaser_screen.dart';

import '../../support/screen_harness.dart';
import '../../widget_test_helpers.dart';

void main() {
  setUpAll(initializeDateFormatting);

  setUp(() {
    RemoteFeatureFlags.resetForTest();
    AppConfig.eefTeaserEnabledOverride = null;
    AppConfig.eefEnabledOverride = null;
    Get.locale = const Locale('fr');
  });

  tearDown(() {
    EefCalendar.resetForTest();
    RemoteFeatureFlags.resetForTest();
    AppConfig.eefTeaserEnabledOverride = null;
    AppConfig.eefEnabledOverride = null;
    Get.reset();
  });

  group('normalizeCountry', () {
    // Les quatre écritures réelles du même pays. Une comparaison stricte les
    // aurait toutes ratées sauf une.
    test('rend la même clé pour toutes les écritures d\'un pays', () {
      final forms = [
        "Côte d'Ivoire",
        'Côte d’Ivoire', // apostrophe typographique
        "COTE D'IVOIRE",
        "  cote d'ivoire  ",
      ].map(EefCampaignWindow.normalizeCountry).toSet();

      expect(forms, hasLength(1));
    });

    test('retire les accents et réduit les espaces', () {
      expect(EefCampaignWindow.normalizeCountry(' Sénégal '), 'senegal');
      expect(EefCampaignWindow.normalizeCountry('Bénin'), 'benin');
      expect(EefCampaignWindow.normalizeCountry('Guinée   Bissau'),
          'guinee bissau');
    });

    test('rend une chaîne vide pour rien du tout', () {
      expect(EefCampaignWindow.normalizeCountry(null), '');
      expect(EefCampaignWindow.normalizeCountry('   '), '');
    });
  });

  group('isSuspendedForCountry', () {
    const window = EefCampaignWindow(suspendedCountries: ['Niger']);

    test('reconnaît le pays quelle que soit la casse ou les accents', () {
      for (final spelling in ['Niger', 'niger', 'NIGER', ' Niger ']) {
        expect(window.isSuspendedForCountry(spelling), isTrue,
            reason: 'écriture « $spelling » non reconnue');
      }
    });

    // Le piège du préfixe : « Niger » est un préfixe de « Nigeria », et une
    // comparaison par `contains` ou `startsWith` aurait suspendu le Nigeria —
    // un pays voisin, présent dans la liste d'onboarding juste après le Niger.
    test('ne confond PAS le Nigeria avec le Niger', () {
      expect(window.isSuspendedForCountry('Nigeria'), isFalse);
      expect(window.isSuspendedForCountry('NIGERIA'), isFalse);
    });

    test('un autre pays n\'est pas suspendu', () {
      expect(window.isSuspendedForCountry('Sénégal'), isFalse);
      expect(window.isSuspendedForCountry('Mali'), isFalse);
    });

    // Le SENS de l'échec est choisi : un pays inconnu ou vide voit la date
    // nationale, qui est exacte. Le cas inverse découragerait une candidature
    // parfaitement possible.
    test('un pays vide ou inconnu n\'est pas suspendu', () {
      expect(window.isSuspendedForCountry(null), isFalse);
      expect(window.isSuspendedForCountry(''), isFalse);
      expect(window.isSuspendedForCountry('Pays imaginaire'), isFalse);
    });

    test('une liste vide ne suspend personne', () {
      expect(
        const EefCampaignWindow().isSuspendedForCountry('Niger'),
        isFalse,
      );
    });

    test('l\'exploitation peut écrire un code au lieu d\'un nom', () {
      const byCode = EefCampaignWindow(suspendedCountries: ['NE']);
      expect(byCode.isSuspendedForCountry('ne'), isTrue);
      expect(byCode.isSuspendedForCountry('Niger'), isFalse,
          reason: 'un code ne vaut pas un nom — les deux doivent être listés '
              'si les deux écritures circulent');
    });
  });

  group('la vitrine', () {
    void serveWindow({List<String> suspended = const <String>[]}) {
      EefCalendar.clock = () => DateTime(2026, 8, 21);
      EefCalendar.windowSource = () => EefCampaignWindow(
            opensAt: DateTime(2026, 10, 1),
            suspendedCountries: suspended,
          );
    }

    Future<void> pumpFor(WidgetTester tester, String country,
        {List<String> suspended = const <String>[]}) async {
      serveWindow(suspended: suspended);
      await seedKpbController(
        snapshot: AppSnapshot(
          localeCode: 'fr',
          hasCompletedOnboarding: true,
          profile: createTestProfile(countryOfResidence: country),
        ),
      );
      await pumpKpbScreen(
        tester,
        screen: const EefTeaserScreen(),
        viewport: iphone14,
      );
    }

    // LE test de ce fichier : la suspension REMPLACE la date, elle ne s'y
    // ajoute pas. Les deux côte à côte laisseraient l'étudiant choisir laquelle
    // croire, et il choisirait la date.
    testWidgets('un étudiant nigérien voit la mise en garde, PAS la date',
        (tester) async {
      await pumpFor(tester, 'Niger', suspended: ['Niger']);

      expect(find.text('eef_suspended_notice'.tr), findsOneWidget);
      expect(find.textContaining('1er octobre 2026'), findsNothing);
      expect(find.textContaining('À partir du'), findsNothing);
    });

    testWidgets('un étudiant sénégalais voit la date d\'ouverture',
        (tester) async {
      await pumpFor(tester, 'Sénégal', suspended: ['Niger']);

      expect(find.textContaining('1er octobre 2026'), findsOneWidget);
      expect(find.text('eef_suspended_notice'.tr), findsNothing);
    });

    // Sans cette ligne, « à partir du 1er octobre » se lit « j'ai tout le
    // temps » — alors que le Maroc clôture le 15 novembre.
    testWidgets('la date d\'ouverture est accompagnée du caveat de clôture',
        (tester) async {
      await pumpFor(tester, 'Sénégal');

      expect(find.text('eef_deadline_varies_notice'.tr), findsOneWidget);
    });

    testWidgets('aucun caveat de clôture quand la procédure est suspendue',
        (tester) async {
      await pumpFor(tester, 'Niger', suspended: ['Niger']);

      expect(find.text('eef_deadline_varies_notice'.tr), findsNothing);
    });
  });
}
