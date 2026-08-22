import 'package:flutter/foundation.dart';

/// La déclaration d'intérêt d'un étudiant pour l'espace « Études en France ».
///
/// `declared` est porté explicitement plutôt que déduit d'un champ non nul :
/// une déclaration où l'étudiant n'a rempli aucun niveau ni aucune filière est
/// parfaitement valide — c'est même le cas majoritaire attendu, la vitrine
/// devant se satisfaire d'un seul tap. Déduire l'existence de la présence de
/// données aurait effacé ces déclarations minimales, c'est-à-dire précisément
/// celles qu'on cherche à compter.
@immutable
class EefInterest {
  const EefInterest({
    required this.declared,
    this.currentLevel,
    this.targetLevel,
    this.fieldIds = const <String>[],
    this.wantsPremium = false,
    this.consentedAt,
  });

  final bool declared;
  final String? currentLevel;
  final String? targetLevel;
  final List<String> fieldIds;
  final bool wantsPremium;
  final DateTime? consentedAt;

  static const notDeclared = EefInterest(declared: false);

  /// Décode la réponse de `/etudes-en-france/interest`.
  ///
  /// Tolérant sur la forme, strict sur le sens : `declared` n'est vrai que si le
  /// serveur l'affirme par un booléen. Une charge illisible vaut « pas
  /// déclaré », ce qui fait au pire reposer la question à un étudiant qui avait
  /// déjà répondu — coût acceptable, à comparer avec le cas inverse, où l'app
  /// affirmerait « c'est noté » sans rien avoir en base.
  factory EefInterest.fromJson(Object? raw) {
    if (raw is! Map) return notDeclared;

    final declared = raw['declared'];
    if (declared is! bool || !declared) return notDeclared;

    return EefInterest(
      declared: true,
      currentLevel: _optionalString(raw['currentLevel']),
      targetLevel: _optionalString(raw['targetLevel']),
      fieldIds: _stringList(raw['fieldIds']),
      wantsPremium: raw['wantsPremium'] == true,
      consentedAt: _optionalInstant(raw['consentedAt']),
    );
  }

  static String? _optionalString(Object? value) {
    if (value is! String) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  static DateTime? _optionalInstant(Object? value) {
    final text = _optionalString(value);
    if (text == null) return null;
    return DateTime.tryParse(text)?.toLocal();
  }

  static List<String> _stringList(Object? value) {
    if (value is! List) return const <String>[];
    return value
        .whereType<String>()
        .map((entry) => entry.trim())
        .where((entry) => entry.isNotEmpty)
        .toList(growable: false);
  }
}
