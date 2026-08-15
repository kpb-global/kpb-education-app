import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

/// La campagne de rentrée affichée par l'app — CALCULÉE, jamais figée.
///
/// ## Le défaut que ce fichier supprime
///
/// « Rentrée septembre 2026 » était écrit EN DUR dans quatre clés de traduction
/// (huit chaînes avec les jumelles anglaises), rendues sur l'en-tête France et
/// la fiche pays. Or la build 49 doit vivre environ quatre-vingt-dix jours : le
/// 1er octobre 2026, chacune de ces chaînes devenait un mensonge — l'app aurait
/// proposé un accompagnement vers une rentrée déjà passée, sans qu'aucune
/// mise à jour de contenu puisse la corriger, puisque le texte vit dans le
/// binaire.
///
/// ## La règle
///
/// Les écoles privées partenaires ont UNE rentrée principale : septembre. La
/// campagne « septembre N » reste la campagne courante jusqu'au 30 septembre N
/// inclus — pendant le mois de septembre, la rentrée est en cours et c'est
/// toujours d'elle qu'on parle. À partir du 1er octobre, la campagne suivante
/// prend le relais.
class IntakeCalendar {
  IntakeCalendar._();

  /// L'horloge, INJECTABLE — c'est toute la différence avec le défaut
  /// d'origine. Un `DateTime.now()` en dur aurait rendu l'expiration
  /// invérifiable : aucun test ne peut attendre le 1er octobre. Le spec du
  /// projet a déjà fait exactement cette erreur une fois.
  @visibleForTesting
  static DateTime Function() clock = DateTime.now;

  /// L'année de la campagne de septembre courante.
  static int intakeYear() {
    final now = clock();
    return now.month <= DateTime.september ? now.year : now.year + 1;
  }

  /// « septembre 2026 » / « September 2026 », dans la langue active.
  ///
  /// [capitalized] pour les positions de titre (« France · Septembre 2026 ») ;
  /// l'anglais capitalise toujours son nom de mois.
  static String label({bool capitalized = false}) {
    final year = intakeYear();
    final isEnglish = Get.locale?.languageCode == 'en';
    if (isEnglish) return 'September $year';
    return capitalized ? 'Septembre $year' : 'septembre $year';
  }
}
