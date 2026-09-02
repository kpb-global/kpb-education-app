import 'package:flutter/foundation.dart';

/// L'inscription d'un étudiant à la liste d'attente Karatou Premium.
///
/// `registered` est porté EXPLICITEMENT par le serveur plutôt que déduit d'une
/// date non nulle. Déduire l'existence d'un champ annexe est le raccourci qui
/// fait afficher « tu es inscrit » sur une réponse mal formée, ou l'inverse ;
/// ici l'app ne le croit que si le serveur l'affirme par un booléen.
///
/// Aucun champ de prix, de moyen de paiement ni d'état d'abonnement : Karatou
/// n'encaisse rien dans l'application, et s'inscrire ne coûte rien.
@immutable
class PremiumWaitlistEntry {
  const PremiumWaitlistEntry({
    required this.registered,
    this.registeredAt,
  });

  final bool registered;
  final DateTime? registeredAt;

  static const notRegistered = PremiumWaitlistEntry(registered: false);

  /// Décode la réponse de `/premium/waitlist`.
  ///
  /// Tolérant sur la forme, strict sur le sens. Une charge illisible vaut « pas
  /// inscrit » : au pire on repropose le bouton à quelqu'un qui avait déjà tapé,
  /// et un second tap est idempotent côté serveur. Le cas inverse — afficher
  /// « c'est noté » sans rien en base — n'a pas de rattrapage : l'étudiant
  /// attend une notification qui ne viendra jamais.
  factory PremiumWaitlistEntry.fromJson(Object? raw) {
    if (raw is! Map) return notRegistered;

    final registered = raw['registered'];
    if (registered is! bool || !registered) return notRegistered;

    return PremiumWaitlistEntry(
      registered: true,
      registeredAt: _optionalInstant(raw['registeredAt']),
    );
  }

  static DateTime? _optionalInstant(Object? value) {
    if (value is! String) return null;
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;
    return DateTime.tryParse(trimmed)?.toLocal();
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PremiumWaitlistEntry &&
          other.registered == registered &&
          other.registeredAt == registeredAt;

  @override
  int get hashCode => Object.hash(registered, registeredAt);
}
