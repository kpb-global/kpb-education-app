// Les couplages de test de la visite guidée « Études en France » : un magasin
// de drapeau « vue » en mémoire, qui peut tomber en panne à la lecture ou à
// l'écriture, et un enregistreur de mesure.
//
// Comme `EefHelpCard.analytics`, les deux sont des COUTURES que le code de
// production expose (`EefTour.store`, `EefTour.analytics`) : rien n'a été
// modifié pour être testable.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:karatou/app/features/etudes_en_france/eef_tour.dart';
import 'package:karatou/app/features/etudes_en_france/eef_tour_store.dart';

/// Le drapeau « vue » en mémoire.
class FakeEefTourStore implements EefTourStore {
  FakeEefTourStore({
    this.seen = false,
    this.failRead = false,
    this.failWrite = false,
  });

  /// La visite a déjà été montrée.
  bool seen;

  /// La lecture lève une exception.
  bool failRead;

  /// L'écriture lève une exception.
  bool failWrite;

  int reads = 0;
  int writes = 0;

  /// Quand il est posé, la lecture ATTEND ce `Completer` : permet à un test
  /// d'ouvrir un dialogue entre la lecture et l'affichage.
  Completer<void>? readGate;

  @override
  Future<bool> hasBeenShown() async {
    reads++;
    final gate = readGate;
    if (gate != null) await gate.future;
    if (failRead) throw StateError('lecture impossible');
    return seen;
  }

  @override
  Future<void> markShown() async {
    writes++;
    if (failWrite) throw StateError('écriture impossible');
    seen = true;
  }
}

/// Ce que la visite mesure : `eef_tour_shown` et `eef_tour_completed`.
class RecordingTourAnalytics implements EefTourAnalytics {
  final List<String> shownTriggers = <String>[];
  final List<({String exit, int cardsSeen})> completedCalls =
      <({String exit, int cardsSeen})>[];

  @override
  void shown({required String trigger}) => shownTriggers.add(trigger);

  @override
  void completed({required String exit, required int cardsSeen}) =>
      completedCalls.add((exit: exit, cardsSeen: cardsSeen));
}

/// Pose la visite « déjà vue » pour un fichier de test qui ne la concerne pas :
/// le hub s'ouvre alors comme avant la build 56, sans feuille par-dessus.
/// À appeler dans `setUp` ; la remise à zéro est enregistrée d'elle-même.
void useSeenTour() {
  EefTour.store = FakeEefTourStore(seen: true);
  EefTour.analytics = RecordingTourAnalytics();
  addTearDown(EefTour.resetForTest);
}
