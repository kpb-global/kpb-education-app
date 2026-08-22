// Une date de campagne est une date d'HORLOGE MURALE, pas un instant.
//
// ## Les deux défauts que ce fichier interdit
//
// **1. Le fuseau qui décale la date affichée.** La borne servie était parsée en
// instant puis reprojetée dans le fuseau de l'appareil. Deux mensonges
// symétriques en sortaient, et le second est le grave :
//
//   - `2026-10-01T00:00:00Z` lu depuis UTC−4 → « 30 septembre » ;
//   - `2026-10-01T00:00:00+02:00` — l'heure de Paris, le réflexe naturel pour
//     une procédure française — lu depuis UTC+0/+1 → « 30 septembre » pour
//     **Dakar, Bamako, Abidjan, Niamey, Douala**, c'est-à-dire l'essentiel du
//     public. Une variable mal saisie, et tout le monde a la mauvaise date.
//
// **2. La clôture excluait son propre jour.** `now.isAfter(closesAt)` avec
// `closesAt = 15 novembre 00:00` rendait la campagne close dès la première
// seconde du 15. « Jusqu'au 15 novembre » inclut le 15 : un étudiant marocain
// ouvrant l'app le matin de sa date limite lisait que c'était terminé.
//
// Les deux se corrigent au même endroit : les bornes deviennent des jours nus,
// et `phase()` compare des jours.
//
// ## Ce que ce fichier ne prouve PAS
//
// Il décode la charge JSON directement, donc il ne traverse pas le serveur — et
// c'est là que le défaut n° 1 survivait à sa correction. `/config/app` faisait
// `new Date(raw).toISOString()` : la valeur « heure de Paris » n'atteignait
// jamais ce décodage sous sa forme écrite, elle arrivait déjà réduite à
// `2026-09-30T22:00:00.000Z`. Les tests d'ici passaient en contournant
// précisément la normalisation fautive.
//
// Le format du fil est donc gardé ailleurs : `test/release/campaign_wire_day_test.dart`
// (la couture) et `backend/.../app-config.controller.spec.ts` (les quatre
// écritures d'exploitation qui doivent servir le même jour).

import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:karatou/app/core/data/eef_calendar.dart';
import 'package:karatou/app/core/services/remote_feature_flags.dart';

void main() {
  setUpAll(initializeDateFormatting);

  setUp(() => Get.locale = const Locale('fr'));

  tearDown(() {
    EefCalendar.resetForTest();
    Get.reset();
  });

  /// Construit la fenêtre depuis la CHARGE JSON, comme en production — pas
  /// depuis des `DateTime` fabriqués à la main, qui contourneraient justement le
  /// décodage qu'on veut éprouver.
  EefCampaignWindow decode({String? opensAt, String? closesAt}) =>
      EefCampaignWindow.fromJson(<String, Object?>{
        'opensAt': opensAt,
        'closesAt': closesAt,
      });

  void serveRaw({String? opensAt, String? closesAt}) {
    EefCalendar.windowSource =
        () => decode(opensAt: opensAt, closesAt: closesAt);
  }

  void freezeAt(DateTime now) => EefCalendar.clock = () => now;

  group('la date affichée est celle que l\'exploitation a écrite', () {
    // LE test de ce fichier. Ces quatre valeurs désignent des instants
    // différents et le MÊME jour administratif ; l'app doit dire « 1er octobre »
    // pour les quatre.
    for (final served in const [
      // La forme réellement servie depuis le correctif de format : un jour nu.
      '2026-10-01',
      // Et les formes d'instant, tolérées — un serveur plus ancien, ou une
      // charge en cache sur l'appareil, ne doit pas faire taire la date.
      '2026-10-01T00:00:00Z',
      '2026-10-01T00:00:00.000Z',
      '2026-10-01T00:00:00+02:00',
      '2026-10-01T23:30:00-05:00',
    ]) {
      test('« $served » s\'affiche « 1er octobre 2026 »', () {
        serveRaw(opensAt: served);
        freezeAt(DateTime(2026, 8, 22));

        expect(EefCalendar.dayLabel(EefCalendar.window.opensAt),
            '1er octobre 2026');
        expect(EefCalendar.rangeLabel(), contains('1er octobre 2026'));
      });
    }

    test('la borne décodée ne porte aucune heure', () {
      // Si une heure survivait, elle réintroduirait la possibilité d'un décalage
      // dès qu'une comparaison oublierait de réduire au jour.
      serveRaw(opensAt: '2026-10-01T23:30:00-05:00');
      final opensAt = EefCalendar.window.opensAt!;

      expect(opensAt.hour, 0);
      expect(opensAt.minute, 0);
      expect(opensAt.second, 0);
      expect(opensAt.isUtc, isFalse,
          reason: 'Un jour nu, pas un instant UTC : aucune reprojection '
              'possible ensuite.');
    });
  });

  group('valeurs illisibles — on n\'invente rien', () {
    for (final bad in const [
      'pas une date',
      '',
      '   ',
      '2026-13-01T00:00:00Z', // mois 13
      '2026-02-30T00:00:00Z', // 30 février
      'demain',
    ]) {
      test('« $bad » ne produit aucune date', () {
        serveRaw(opensAt: bad);
        expect(EefCalendar.window.opensAt, isNull);
        expect(EefCalendar.rangeLabel(), isNull);
      });
    }

    test('un 32 janvier n\'est pas silencieusement un 1er février', () {
      // `DateTime(2026, 1, 32)` vaut le 1er février : normaliser une saisie
      // fautive produirait une date inventée, exactement ce que ce module
      // refuse. On rend `null` et l'app ne dit rien.
      serveRaw(opensAt: '2026-01-32T00:00:00Z');
      expect(EefCalendar.window.opensAt, isNull);
    });
  });

  group('la clôture inclut son propre jour', () {
    test('le jour de clôture, la campagne est encore OUVERTE', () {
      serveRaw(
        opensAt: '2026-10-01T00:00:00Z',
        closesAt: '2026-11-15T00:00:00Z',
      );

      // Le matin du 15 : c'est la date limite, elle n'est pas passée.
      freezeAt(DateTime(2026, 11, 15, 8));
      expect(EefCalendar.phase(), EefCampaignPhase.open);

      // Et jusqu'au dernier instant du 15.
      freezeAt(DateTime(2026, 11, 15, 23, 59));
      expect(EefCalendar.phase(), EefCampaignPhase.open);
    });

    test('le lendemain, elle est close', () {
      serveRaw(
        opensAt: '2026-10-01T00:00:00Z',
        closesAt: '2026-11-15T00:00:00Z',
      );
      freezeAt(DateTime(2026, 11, 16));

      expect(EefCalendar.phase(), EefCampaignPhase.closed);
    });
  });

  group('l\'ouverture inclut son propre jour', () {
    test(
        'le jour d\'ouverture, la campagne est OUVERTE et sans compte à rebours',
        () {
      serveRaw(opensAt: '2026-10-01T00:00:00Z');
      freezeAt(DateTime(2026, 10, 1, 6));

      expect(EefCalendar.phase(), EefCampaignPhase.open);
      expect(EefCalendar.daysUntilOpening(), isNull);
    });

    test('la veille, elle ne l\'est pas encore', () {
      serveRaw(opensAt: '2026-10-01T00:00:00Z');
      freezeAt(DateTime(2026, 9, 30, 23, 59));

      expect(EefCalendar.phase(), EefCampaignPhase.beforeOpening);
      expect(EefCalendar.daysUntilOpening(), 1);
    });
  });
}
