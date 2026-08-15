# Release ledger

Un numéro listé sous **Consommés** ne peut plus figurer dans `pubspec.yaml`.
Le numéro sous **Courant** est le seul autorisé. Le test
`test/release/build_number_test.dart` lit ce fichier.

## Consommés

- `46` — AAB CI du 31/07/2026, jamais téléversé sur Play
- `48` — consommé sur TestFlight le 12/08/2026

## Courant

- `49` — SHA de la branche release, à remplir le jour J
