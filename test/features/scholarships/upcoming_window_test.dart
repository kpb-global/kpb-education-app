// Revue du build 49, point 9 : « au niveau de la date, on met "À venir,
// généralement aux mois de … - …" ».
//
// Trois défauts vivants ont été corrigés en même temps que l'ajout de cette
// formulation, et ils sont tenus ici :
//
//   1. `windowStatus` rendait « Bientôt clôturé » / « Clôturé » sur une date
//      ESTIMÉE — une affirmation au jour près sur une projection. « Clôturé »
//      aurait fait renoncer un étudiant à une bourse encore ouverte.
//   2. `toJson` perdait `dateConfidence` : toute copie passée par le cache
//      hors-ligne revenait « confirmée », et le compte à rebours réapparaissait.
//   3. La fiche détail affichait la date estimée en « Date limite » jj/mm/aaaa
//      alors que la carte de liste se taisait — deux écrans, deux vérités.

import 'package:flutter_test/flutter_test.dart';
import 'package:karatou/app/core/models/app_models.dart';
import 'package:karatou/app/features/scholarships/live_scholarships_screen.dart';

void main() {
  ScholarshipModel build({
    required DateTime? deadlineAt,
    required bool estimated,
  }) {
    return ScholarshipModel(
      id: 's1',
      name: const LocalizedText(fr: 'Bourse', en: 'Scholarship'),
      countryId: 'fra',
      levelEligible: const LocalizedText(fr: 'Licence', en: 'Bachelor'),
      typeOfFunding: const LocalizedText(fr: 'Complète', en: 'Full'),
      deadlineLabel: const LocalizedText(
        fr: 'À venir, généralement aux mois de mars – avril',
        en: 'Upcoming, usually in March – April',
      ),
      keyRequirements: const [],
      relatedFieldIds: const [],
      baseMatch: 30,
      deadlineAt: deadlineAt,
      deadlineIsEstimated: estimated,
    );
  }

  group('windowStatus ne juge jamais une date estimée', () {
    final soon = DateTime.now().add(const Duration(days: 3));
    final past = DateTime.now().subtract(const Duration(days: 10));

    test('une échéance proche mais ESTIMÉE reste « ouvert »', () {
      expect(
        build(deadlineAt: soon, estimated: true).windowStatus(),
        ScholarshipWindowStatus.open,
        reason: '« Bientôt clôturé » sur une projection est une affirmation '
            'que personne n\'a publiée',
      );
    });

    test('une date passée mais ESTIMÉE ne dit pas « clôturé »', () {
      expect(
        build(deadlineAt: past, estimated: true).windowStatus(),
        ScholarshipWindowStatus.open,
        reason: '« Clôturé » à tort fait renoncer à une bourse encore ouverte',
      );
    });

    test('contre-garde : une date CONFIRMÉE est toujours jugée', () {
      // Sans ce test, un correctif qui rendrait « ouvert » pour TOUT le monde
      // passerait pour une réussite.
      expect(
        build(deadlineAt: soon, estimated: false).windowStatus(),
        ScholarshipWindowStatus.closingSoon,
      );
      expect(
        build(deadlineAt: past, estimated: false).windowStatus(),
        ScholarshipWindowStatus.closed,
      );
    });
  });

  // ── Revue automatique de la PR #252 (P2) ────────────────────────────────
  //
  // Les bornes du catalogue sont des dates SANS heure écrites en UTC
  // (`2027-03-01T00:00:00.000Z` → `2027-04-30T23:59:59.000Z`). La première
  // version comparait après `toLocal()`, et changeait donc de jour calendaire
  // pour presque tout le monde : à l'est d'UTC — Niger, Sénégal, Côte d'Ivoire,
  // c'est-à-dire notre public — le 30 avril 23 h 59 UTC devient le 1er mai, et
  // le test « dernier jour du mois » échouait pour la convention même qu'il
  // doit reconnaître. La carte retombait alors sur des dates précises
  // trompeuses.
  group('la fenêtre de mois se lit en UTC, pas en heure locale', () {
    test('bornes de mois entières reconnues quel que soit le fuseau', () {
      final open = DateTime.utc(2027, 3, 1);
      final close = DateTime.utc(2027, 4, 30, 23, 59, 59);
      expect(isWholeMonthWindowForTest(open, close), isTrue);
      // Même instant, exprimé en local : le prédicat ne doit pas changer d'avis.
      expect(
        isWholeMonthWindowForTest(open.toLocal(), close.toLocal()),
        isTrue,
      );
    });

    test('février bissextile : le 29 est bien le dernier jour', () {
      expect(
        isWholeMonthWindowForTest(
          DateTime.utc(2028, 2, 1),
          DateTime.utc(2028, 2, 29, 23, 59, 59),
        ),
        isTrue,
      );
    });

    test('une fenêtre saisie au jour près n\'est PAS une fenêtre de mois', () {
      expect(
        isWholeMonthWindowForTest(
          DateTime.utc(2027, 3, 12),
          DateTime.utc(2027, 4, 18),
        ),
        isFalse,
        reason: 'ces dates ont été saisies précisément : les rendre en mois '
            'perdrait de l\'information que l\'opérateur a fournie',
      );
    });
  });

  group('l\'aller-retour JSON conserve la confiance de la date', () {
    test('estimée reste estimée après toJson/fromJson', () {
      final original = build(
        deadlineAt: DateTime.utc(2027, 4, 30),
        estimated: true,
      );
      final restored = ScholarshipModel.fromJson(original.toJson());
      expect(
        restored.deadlineIsEstimated,
        isTrue,
        reason: 'la clé `dateConfidence` manquait dans toJson : une fiche '
            'restaurée du cache redevenait « confirmée » et retrouvait son '
            'compte à rebours',
      );
      expect(restored.windowStatus(), ScholarshipWindowStatus.open);
    });

    test('confirmée reste confirmée', () {
      final original = build(
        deadlineAt: DateTime.utc(2027, 4, 30),
        estimated: false,
      );
      expect(
        ScholarshipModel.fromJson(original.toJson()).deadlineIsEstimated,
        isFalse,
      );
    });
  });
}
