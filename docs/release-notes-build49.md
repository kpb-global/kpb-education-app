# Notes de version — build 49 (2.1.0+49)

> Build précédent chez les testeurs : **48** (TestFlight, 12/08/2026). Ce fichier
> fournit le texte à coller (1) dans TestFlight → « What to Test » (interne) et
> (2) dans la fiche store → « Nouveautés » (public). Établi le 2026-08-25 sur le
> périmètre **vérifié** de la 49 ; ne pas y ajouter une fonctionnalité non livrée.

---

## A. TestFlight — « What to Test » (testeurs internes, FR)

**2.1.0 (49) — corrections + durcissement confidentialité**

À tester en priorité :

1. **Verrou d'application (Face ID / code).** Activez « Verrouiller l'app » dans
   le profil, mettez l'app en arrière-plan, revenez : le déverrouillage doit être
   **unique**. L'ancien défaut rejouait l'invite Face ID en boucle (~toutes les
   1,6 s) — il ne doit plus jamais réapparaître après un déverrouillage réussi.
2. **Catalogue de bourses.** Ouvrez le catalogue sans filtre : **toutes** les
   fiches publiées doivent s'afficher. L'ancien défaut n'en montrait qu'une
   fraction quand le profil n'avait pas de domaine renseigné.
3. **Dictée du message d'accompagnement.** Dans le tunnel de dossier, dictez un
   message : reconnaissance **sur l'appareil** par défaut ; si l'appareil ne la
   propose pas, un **dialogue d'accord explicite** doit précéder tout repli réseau.
4. **Analyse d'usage (Profil → Analyse d'usage).** La couper doit désactiver
   Firebase Analytics, PostHog et Crashlytics ; la réactiver les rétablit.
5. **Notifications push.** Réception nominale (l'identité poussée est un UUID,
   sans e-mail).

Confidentialité (invisible mais à ne pas casser) : aucun identifiant publicitaire,
aucun envoi d'e-mail à OneSignal, collecteurs éteints tant que le consentement
n'est pas restauré.

---

## B. Fiche store — « Nouveautés » (public, FR)

> Court, sans jargon. À traduire en EN pour la fiche App Store si besoin (la 49
> localise `fr` uniquement côté binaire, mais la fiche store peut être bilingue).

```
• Correction du verrou par Face ID / code qui pouvait se rouvrir en boucle.
• Le catalogue de bourses affiche désormais toutes les offres disponibles.
• Dictée vocale traitée sur l'appareil, avec votre accord avant tout repli.
• Confidentialité renforcée : aucun identifiant publicitaire, réglage d'analyse
  d'usage respecté partout.
• Catalogue de bourses revérifié aux sources officielles et dates mises à jour.
```

---

## C. Pré-vol d'archive — état vérifié le 2026-08-25 (aucune distribution)

| Contrôle | État | Preuve |
|---|---|---|
| Version / build | ✅ `2.1.0+49` | `pubspec.yaml:22` = ledger « courant » = `EXPECTED_BUILD` des 2 préflights |
| Arbre = `origin/main` | ✅ identique | HEAD `db268e5` ancêtre de `bd3d50e` (#237), `git diff` vide |
| `dart format` (gate CI) | ✅ propre | 466 fichiers, 0 modifié |
| Gardes de release | ✅ vertes | `flutter test test/release/` — 46 tests, dont manifeste Android (AD_ID, QUERY_ALL_PACKAGES), iOS, signature, analytics-off-par-défaut |
| Manifeste Android | ✅ conforme | AD_ID `tools:node="remove"`, collecteurs `=false`, pas de `QUERY_ALL_PACKAGES` |
| Info.plist iOS | ✅ conforme | 6 chaînes d'usage, `ITSAppUsesNonExemptEncryption=false`, `NSPrivacyTracking=false` |
| Icônes iOS sans alpha | ✅ | `pubspec.yaml:164` `remove_alpha_ios: true` |

⚠️ **Le `ios/Flutter/Generated.xcconfig` actuellement sur disque ne porte AUCUN
dart-define KPB** (fichier de dev). Il **échouerait** le préflight iOS. Avant
d'archiver dans Xcode, le régénérer avec l'ensemble complet — étape 4 de
`docs/cutover-build49.md` :

```bash
# POSTHOG_API_KEY : phc_… réel, ou VIDE = PostHog désactivé. Jamais « phc_… »
# littéral (il passe le préflight mais livre une clé morte). Décision : point 1
# de CONSOLE_ANSWERS_build49.md.
export POSTHOG_API_KEY="${POSTHOG_API_KEY-}"
flutter build ios --release --no-codesign \
  --dart-define=KPB_APP_ENV=prod \
  --dart-define=KPB_WHATSAPP_NUMBER=+33768674292 \
  --dart-define=POSTHOG_API_KEY="$POSTHOG_API_KEY"
```

Puis, **sur l'archive** (ne construit rien) :

```bash
scripts/preflight-ios-archive.sh \
  --xcconfig ios/Flutter/Generated.xcconfig \
  --archive-plist <Archive>.xcarchive/Products/Applications/Runner.app/Info.plist
```

Côté Android, sur l'AAB signé (point 2) :

```bash
scripts/preflight-android-aab.sh \
  --aab build/app/outputs/bundle/release/app-release.aab \
  --expected-cert-sha256 <SHA-256 d'importation Play>
```

**Ce qui reste ton geste explicite** (règle : pas de distribution ni d'archive
spontanée sans feu vert) : Xcode → Product → Archive → Organizer, téléversement
des dSYM, puis Organizer → Distribute → TestFlight / Play Console. La séquence
complète, avec les feux verts propriétaire, est dans `docs/cutover-build49.md` §4.
