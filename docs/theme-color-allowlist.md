# Allowlist des couleurs hors tokens

Référence : `docs/fable-global-theme-architecture.md` §10.4 et §11.1.

Toute couleur en dur hors de `lib/app/core/ui/app_tokens.dart` est une dette
mesurée par le ratchet (`test/core/ui/color_audit_test.dart` +
`color_budget.dart`). Les seules exceptions **permanentes** sont listées ici ;
dans le code, elles portent un commentaire `// kpb-allow-color: <raison>`.

| Fichier | Valeur | Raison | Depuis |
|---|---|---|---|
| — | — | *(aucune exception permanente enregistrée pour l'instant : les budgets du ratchet couvrent la dette héritée, à éteindre lot par lot)* | — |

## Candidats identifiés (à confirmer lors des lots concernés)

- `lib/app/features/*/…` CTA WhatsApp → utiliser le token `KpbColors.whatsapp` (lot 2/7).
- `backend`/PDF : `eligibility_pdf.dart` utilise `PdfColor.fromInt(0xFF004AAD)` — marque héritée sur support imprimé, hors du scan (pas un `Color(0x…)` Flutter scanné ? si, même motif : à allowlister au lot 7 si conservé).
- Zone vidéo `academy_player_screen.dart` : noirs volontaires (surface immersive, lot 7).
- Rails hero sombres (`institution_mini_card`, `scholarship_mini_card`) : via tokens dark (lot 2).
