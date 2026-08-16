/// Locale livrée (build 49) : le français seulement.
///
/// L'anglais existe encore dans [AppTranslations] — le test de parité fr↔en
/// doit rester vert — mais l'UI livrée est panachée (verdicts EN, justifications
/// FR, « /an » en dur). On masque le sélecteur et on ramène toute préférence
/// persistée à `fr`, pour ne pas laisser un utilisateur déjà en `en` sans
/// interrupteur.
const kShippedLocale = 'fr';

/// Le sélecteur FR | EN reste dans le code (Profil, onboarding) mais n'est
/// plus monté. Masquer, ne pas détruire : le jour où l'anglais sera homogène,
/// on remonte le drapeau.
const kLanguageSwitchVisible = false;

/// Toute valeur persistée (`en`, `ar`, vide, préfixe `en_US`) devient `fr`.
String canonicalAppLocale(String? raw) => kShippedLocale;
