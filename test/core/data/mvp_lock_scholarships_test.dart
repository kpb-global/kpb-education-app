// Le verrou pays MVP ne touche JAMAIS aux bourses — prouvé sur les fiches
// RÉELLES du catalogue publié, pas sur une liste recopiée.
//
// ## Pourquoi ce test lit les fichiers du backend
//
// Une version antérieure du verrou appliquait aux bourses le filtre des
// destinations : 23 fiches sur 34 disparaissaient, dont TOUTES les bourses
// africaines (UWC Burkina/Kenya/Tanzanie, Ashesi, ALU, AUC, l'Afrique australe)
// et les transfrontalières codées `int` — en contradiction directe avec le
// commentaire du verrou lui-même, « Keep cross-border scholarships ». Le
// correctif est en place ; ce fichier est la garde qui l'empêche de revenir.
//
// La condition posée par le plan : puiser les identifiants pays dans une
// CONSTANTE PARTAGÉE avec le catalogue, jamais dans une liste recopiée — sinon
// le test continue de passer quand une 35e fiche arrive avec un pays inconnu.
// Le catalogue vit en TypeScript (backend/src/modules/scholarships-index/data/),
// qu'un test Dart ne peut pas importer : la seule source réellement partagée
// est le FICHIER, donc on le lit. Même doctrine que les autres gardes
// statiques du dépôt.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:karatou/app/core/config/app_config.dart';
import 'package:karatou/app/core/controllers/app_controller.dart';
import 'package:karatou/app/core/models/app_models.dart';
import 'package:karatou/app/core/utils/country_utils.dart';

import '../../widget_test_helpers.dart';

/// Les identifiants pays des fiches publiées, extraits des fichiers
/// d'enregistrements du catalogue. Deux formes coexistent dans la source :
/// `country: ['gbr', …]` (la forme compacte) et `countryId: 'bfa'` (la forme
/// développée des fiches UWC).
List<String> readCatalogCountryIds() {
  final directory = Directory('backend/src/modules/scholarships-index/data');
  final ids = <String>[];
  final compact = RegExp(r"country: \['([a-z]{2,3})'");
  final expanded = RegExp(r"countryId: '([a-z]{2,3})'");
  for (final entity in directory.listSync()) {
    if (entity is! File) continue;
    final name = entity.path.split('/').last;
    if (!name.startsWith('scholarship-catalog.records')) continue;
    final content = entity.readAsStringSync();
    ids.addAll(compact.allMatches(content).map((m) => m.group(1)!));
    ids.addAll(expanded.allMatches(content).map((m) => m.group(1)!));
  }
  return ids;
}

ScholarshipModel _scholarship(String id, String countryId) => ScholarshipModel(
      id: id,
      name: LocalizedText(fr: 'Bourse $id', en: 'Scholarship $id'),
      countryId: countryId,
      levelEligible: const LocalizedText(fr: 'Master', en: 'Master'),
      typeOfFunding: const LocalizedText(fr: 'Complète', en: 'Full'),
      deadlineLabel: const LocalizedText(fr: '2027', en: '2027'),
      keyRequirements: const [],
      relatedFieldIds: const [],
      baseMatch: 50,
    );

void main() {
  tearDown(Get.reset);

  test('l\'extraction retrouve bien le volume du catalogue publié', () {
    final ids = readCatalogCountryIds();
    // 33 fiches portaient un pays au 15/08/2026 (objectif de volume : 34).
    // Une borne BASSE, pas une égalité : une fiche ajoutée ne doit pas rougir
    // ce test — c'est précisément le scénario qu'il protège.
    expect(
      ids.length,
      greaterThanOrEqualTo(30),
      reason: 'L\'extraction ne retrouve plus les fiches du catalogue : soit '
          'les fichiers ont bougé, soit leur forme a changé. Ce test ne '
          'protège plus rien tant qu\'il lit dans le vide.',
    );
    // Et la preuve que le sujet existe encore : des fiches HORS destinations
    // MVP, celles-là mêmes que l'ancien verrou supprimait.
    expect(ids.where((id) => !isMvpCountryId(id)), isNotEmpty);
  });

  test('TOUTES les fiches réelles survivent au verrou, y compris « int »',
      () async {
    expect(AppConfig.mvpOnly, isTrue,
        reason: 'Ce test mesure le verrou : il doit être actif.');

    final ids = readCatalogCountryIds();
    final controller = AppController(
      repository: FakeRepository(),
      apiClient: MockApiClient(),
    );
    await controller.hydrate();

    controller.scholarships
      ..clear()
      ..addAll([
        for (var i = 0; i < ids.length; i++) _scholarship('sch-$i', ids[i]),
      ]);
    // Le contrepoint : un pays et un programme HORS MVP doivent, eux,
    // toujours disparaître — le verrou garde son sens pour les destinations.
    const empty = LocalizedText(fr: '', en: '');
    controller.countries.add(const CountryModel(
      id: 'bfa',
      name: LocalizedText(fr: 'Burkina Faso', en: 'Burkina Faso'),
      whyStudy: empty,
      tuitionRange: empty,
      livingCostRange: empty,
      visaOverview: empty,
      admissionDifficulty: empty,
      popularFieldIds: [],
      flagEmoji: '🇧🇫',
    ));
    controller.programs.add(const ProgramModel(
      id: 'prog-bfa',
      institutionId: 'inst-x',
      countryId: 'bfa',
      fieldId: 'd01',
      name: LocalizedText(fr: 'Programme', en: 'Program'),
      level: empty,
      duration: empty,
      tuition: empty,
      language: empty,
      requirements: [],
    ));

    controller.applyMvpCountryLockForTest();

    expect(
      controller.scholarships.length,
      ids.length,
      reason: 'Le verrou pays a de nouveau supprimé des bourses. Une bourse '
          'n\'est pas une destination : masquer un financement vérifié parce '
          'que KPB n\'a pas encore de formations dans ce pays prive '
          'l\'étudiant sans rien protéger. L\'ancienne version effaçait 23 '
          'fiches sur 34, dont toutes les africaines.',
    );
    expect(controller.countries.any((c) => c.id == 'bfa'), isFalse,
        reason: 'Le verrou doit continuer de filtrer les destinations.');
    expect(controller.programs.any((p) => p.id == 'prog-bfa'), isFalse);
  });
}
