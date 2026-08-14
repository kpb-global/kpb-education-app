// Le prix affiché sur l'onglet Universités, monté à taille de téléphone.
//
// La porte de sortie du lot 6, côté affichage. Trois assertions, dont la
// troisième est une garde ANTI-SUR-CORRECTION : il ne suffit pas de faire
// disparaître le montant faux du Maroc, il faut aussi que les 298 écoles
// partenaires françaises — la partie de l'app la plus consultée, et déjà juste —
// gardent leur équivalent en francs CFA.
//
// Plus une quatrième, que le plan n'avait pas prévue et que la revue a réclamée :
// aucun texte ne doit être TRONQUÉ. Le libellé de frais de `_SchoolRow` est
// `maxLines: 1` avec ellipsis (universities_screen.dart:920-932) : allonger la
// chaîne pouvait couper le prix sans lever aucune exception, et sans qu'aucun
// test du dépôt ne le remarque.
//
// ## Deux corrections au protocole du plan, mesurées
//
// 1. `AppSnapshot` NE sème PAS de programmes. `hydrate()` ne lit jamais
//    `snapshot.programs` — la branche catalogue lit Hive ou `MockCatalog`
//    (app_controller.dart:361-424). Un test injecte donc sa liste en mutant
//    `controller.programs`, qui est publique et mutable
//    (app_controller.dart:189-194).
//
// 2. La liste est PARESSEUSE (`ListView.builder`). Compter 20 lignes rendues sur
//    un écran de 844 pt est impossible : il s'en construit une dizaine. Le compte
//    honnête est celui que l'écran affiche lui-même (« 20 programme(s) »), ou
//    celui du modèle filtré — pas un viewport gonflé à 2 600 pt, qui serait le
//    mensonge que le lot 5 vient de retirer.

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:karatou/app/core/controllers/app_controller.dart';
import 'package:karatou/app/core/models/app_models.dart';
import 'package:karatou/app/core/services/program_filter_service.dart';
import 'package:karatou/app/features/universities/universities_screen.dart';

import '../../support/screen_harness.dart';

LocalizedText _t(String value) => LocalizedText(fr: value, en: value);

const _partnerId = 'inst-test-partner';

InstitutionModel _partner(String countryId) => InstitutionModel(
      id: _partnerId,
      name: _t('École partenaire de test'),
      countryId: countryId,
      location: _t('Casablanca'),
      overview: _t('Établissement de test.'),
      studyLevels: const ['Master'],
      tuitionLabel: _t('MAD 40 000/an'),
      languageRequirements: _t('Français B2'),
      intakePeriods: const ['Septembre'],
      programIds: const [],
      isPartner: true,
    );

ProgramModel _program({
  required String id,
  required String tuition,
  required String countryId,
  String name = 'Master en gestion',
}) =>
    ProgramModel(
      id: id,
      institutionId: _partnerId,
      countryId: countryId,
      fieldId: 'd01',
      name: _t(name),
      level: _t('Master'),
      duration: _t('2 ans'),
      tuition: _t(tuition),
      language: _t('Français'),
      requirements: <LocalizedText>[_t('Licence')],
    );

/// Remplace le catalogue du contrôleur par [programs] et une institution
/// partenaire, puis notifie l'écran.
void _seedCatalog(AppController controller, List<ProgramModel> programs) {
  controller.institutions
    ..clear()
    ..add(_partner('mar'));
  controller.programs
    ..clear()
    ..addAll(programs);
  controller.update();
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await initializeDateFormatting('fr');
  });

  tearDown(Get.reset);

  testWidgets('un programme marocain n\'affiche plus un prix multiplié par 656',
      (tester) async {
    final controller = await seedKpbController();
    _seedCatalog(controller, [
      _program(id: 'p-mar', tuition: 'MAD 40 000/an', countryId: 'mar'),
      _program(
        id: 'p-fra',
        tuition: '12 990 €/an',
        countryId: 'fra',
        name: 'Master en marketing',
      ),
    ]);

    await pumpKpbScreen(
      tester,
      screen: const UniversitiesScreen(),
      viewport: iphone14,
      inDrawerShell: true,
    );

    // 1. Le montant mensonger a disparu. 40 000 dirhams × 655,957 = 26 238 280,
    //    et c'est ce que la production affichait le 14/08/2026.
    expect(find.textContaining('26 238 280'), findsNothing,
        reason: 'Le premier nombre est de nouveau traité comme des euros.');

    // 2. L'étiquette d'origine est là : c'est elle qui informe, faute de taux.
    expect(find.textContaining('MAD 40'), findsWidgets,
        reason:
            'La conversion a de nouveau REMPLACÉ l\'étiquette au lieu de la '
            'compléter — l\'étudiant n\'a plus aucun moyen de vérifier.');

    // 3. GARDE ANTI-SUR-CORRECTION. Les euros gardent leur équivalent exact.
    expect(find.textContaining('8 520 881'), findsWidgets,
        reason: 'Les 305 programmes en euros ont perdu leur équivalent FCFA : '
            'ce n\'est pas un correctif, c\'est un recul.');
  });

  testWidgets('aucun prix n\'est coupé par un ellipsis', (tester) async {
    final controller = await seedKpbController();
    _seedCatalog(controller, [
      // L'étiquette la plus longue du catalogue de production, celle des écoles
      // multi-campus, avec son équivalent en fourchette : le pire cas réel.
      _program(
        id: 'p-long',
        tuition: '11 490 € – 11 690 €/an selon le campus',
        countryId: 'fra',
      ),
      _program(id: 'p-fra', tuition: '12 990 €/an', countryId: 'fra'),
    ]);

    await pumpKpbScreen(
      tester,
      screen: const UniversitiesScreen(),
      viewport: compactAndroid,
      inDrawerShell: true,
    );

    final truncated = truncatedTexts(tester);
    expect(
      truncated.where((text) => text.contains('FCFA')).toList(),
      isEmpty,
      reason:
          'Un prix est coupé par un ellipsis : l\'équivalent FCFA ajouté ne '
          'tient pas dans son emplacement. Un demi-prix est une information à '
          'moitié dite, et rien dans la matrice d\'écrans ne l\'aurait vu.\n'
          'Textes tronqués : $truncated',
    );
  });

  testWidgets('l\'écran compte bien les 20 programmes marocains semés',
      (tester) async {
    // Le cas qui comptait : 20 programmes en dirhams, vue par DÉFAUT (donc
    // budget à 30 000 €). Avant, 40 000 dirhams étaient comparés à 30 000 euros
    // et 18 des 20 disparaissaient sans un mot.
    final controller = await seedKpbController();
    _seedCatalog(controller, [
      for (var i = 0; i < 20; i++)
        _program(
          id: 'p-mar-$i',
          tuition: 'MAD 40 000/an',
          countryId: 'mar',
          name: 'Master marocain $i',
        ),
    ]);

    // Le modèle d'abord : c'est lui qui décide, et il est insensible à la
    // paresse de la liste.
    expect(
      ProgramFilterService.apply(
        controller.programs,
        const ProgramFilterState(),
        controller,
      ).length,
      20,
      reason: 'Le filtre budget par défaut écarte encore des programmes en '
          'dirhams.',
    );

    await pumpKpbScreen(
      tester,
      screen: const UniversitiesScreen(),
      viewport: iphone14,
      inDrawerShell: true,
    );

    // Puis le compte que l'écran affiche lui-même — toujours construit, puisqu'il
    // vit dans l'en-tête et non dans la liste paresseuse.
    expect(find.textContaining('20 programme'), findsWidgets,
        reason:
            'L\'écran annonce un autre nombre que les 20 programmes semés.');
  });
}
