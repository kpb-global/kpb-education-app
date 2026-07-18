# KPB Competition Readiness — apports CR-021 à CR-032

Date : 18 juillet 2026

## Impact, mesure et intégrité

- Les admissions, financements et soumissions publiques proviennent de sources
  vérifiées, jamais de `Case.completed`.
- Les statistiques publiques utilisent uniquement le dernier snapshot
  `isPublicSafe`, avec métriques uniques, versionnées, sans caveat et `n ≥ 20`.
- Les témoignages exigent un consentement `public_testimonial` actif ; une
  révocation, une notice retirée ou une autorisation parentale invalide retire
  immédiatement le témoignage.
- Les snapshots, rapports et exports sont append-only PostgreSQL ; leur
  modification ou suppression est bloquée par triggers.

## Partenaires et pilotes

- Les accords ont un cycle de révision immuable, des preuves contrôlées et des
  scopes pays/partenaire/ressource.
- Les pilotes ne sont activables que lorsqu’un accord actif couvre leur fenêtre
  et chacun de leurs pays ciblés.
- Les enrolments exigent consentement de recherche, date de naissance, pays
  profil canonique et autorisation parentale active pour les mineurs.
- Cohortes, assignments et assessments minimisent les données, rejettent les
  champs PII et restent associés au pilote autorisé.

## Fiabilité et privacy

- Outbox durable avec lease, récupération des leases expirés, retry
  exponentiel, dead-letter et projection analytique allowlistée.
- Réconciliation idempotente des objets stockage orphelins et rétention des
  uploads abandonnés.
- Export et suppression de compte couvrent les données Success Lab, résultats,
  pilotes, cohortes, assessments, assignments et snapshots d’idempotence ; les
  données analytiques nécessaires sont pseudonymisées.
- Les logs et téléchargements privés ont été assainis : pas de payload
  fournisseur, secret, token, email, identifiant utilisateur ou storage key
  dans les messages techniques.

## Interfaces étudiant et admin

- Flutter : Success Lab fail-closed, i18n FR/EN, écrans accessibles à 200 %,
  états réseau compréhensibles et opérationnels hors ligne lorsque sûr.
- Flutter : les statistiques Impact indisponibles affichent une erreur et un
  retry, jamais des zéros créés par l’application.
- Admin : hub partenaires/pilotes/impact/data room, confirmations, erreurs,
  limitation JSON de la data room et protection contre les réponses contenant
  `storageKey` ou manifest privé.
- Toutes les mutations partenaires/pilotes utilisent une clé d’idempotence,
  y compris les mises à jour PATCH.

## Release engineering

- Variables de production validées au démarrage, SHA de build exigé lorsque la
  fonctionnalité est active, Docker sans migration automatique et procédure de
  migration/rollback documentée.
- CI : migrations neuves, upgrade additif sur données peuplées, privacy
  PostgreSQL, lint, build, tests backend/admin et validation Compose.
- Validations locales de release : 46 migrations neuves, upgrade peuplé,
  privacy PostgreSQL, 572 tests backend, 50 tests admin, analyse Flutter et
  APK debug.

## Hors code avant activation

- provisionner les secrets et l’infrastructure production ;
- tester stockage, antivirus, push et suppression Supabase en staging ;
- valider les accords/notices et former les conseillers ;
- ouvrir le pilote progressivement et mesurer J0/J30/J90.
