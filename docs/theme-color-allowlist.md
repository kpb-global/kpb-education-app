# Allowlist des couleurs hors tokens

Référence : `docs/fable-global-theme-architecture.md` §10.4 et §11.1.

Toute couleur en dur hors de `lib/app/core/ui/app_tokens.dart` est une dette
mesurée par le ratchet (`test/core/ui/color_audit_test.dart` +
`color_budget.dart`). Les seules exceptions **permanentes** sont listées ici ;
dans le code, elles portent un commentaire `// kpb-allow-color: <raison>`.

| Fichier | Valeur | Raison | Depuis |
|---|---|---|---|
| `lib/app/features/profile/profile_screen.dart` | `#FDE68A` | second stop du dégradé premium du handoff (`gold → amber-200`) — décoratif, aucune valeur sémantique, aucun token équivalent | lot 6 (17/07/2026) |
| `lib/app/features/premium/premium_screen.dart` | `#FDE68A` | même dégradé premium que le profil | lot 7 (17/07/2026) |
| `lib/app/core/data/mock_catalog/fields_data.dart` | 12 accents (`accentColor`) | **données** du catalogue (accents d01..d12), miroir des seeds backend — la vraie valeur vient de l'API (`FieldModel.accentColor` parse un hex serveur, fallback `KpbColors.csBlue`) | lot 9 (17/07/2026) |

## Hors périmètre du scan (rappel)

- `eligibility_pdf.dart` : `PdfColor.fromInt(0xFF004AAD)` — marque héritée sur
  support imprimé (`brandBlueLegacy`), non scanné (pas un `Color(` Flutter).

## Candidats traités

Tous les candidats identifiés aux lots 1–8 ont été résolus : CTA WhatsApp →
token `whatsapp` ; zones vidéo → `Colors.black`/tokens dark (surfaces
immersives) ; rails hero sombres → tokens dark (lot 2).
