-- Diagnostic EN LECTURE SEULE du catalogue de production.
-- Exécuté par .github/workflows/db-info.yml — voir ce fichier pour le contexte.
--
-- Postgres refuse toute écriture dans cette transaction : la lecture seule est
-- garantie par le serveur, pas seulement par notre bonne volonté.
BEGIN READ ONLY;

\echo '=== 1. Répartition publication/activation des bourses ==='
SELECT "moderationStatus", "isActive", COUNT(*) AS lignes
FROM "Scholarship" GROUP BY 1, 2 ORDER BY 3 DESC;

\echo ''
\echo '=== 2. Le filtre exact des endpoints publics ==='
SELECT COUNT(*) AS bourses_visibles_par_lapp
FROM "Scholarship"
WHERE "isActive" = true AND "moderationStatus" = 'approved';

\echo ''
\echo '=== 3. Parmi les visibles : domaines renseignés ? dates vivantes ? ==='
SELECT COUNT(*)                                                    AS visibles,
       COUNT(*) FILTER (WHERE cardinality("relatedFieldIds") > 0)   AS avec_domaines,
       COUNT(*) FILTER (WHERE "deadlineAt" IS NULL)                 AS sans_date_limite,
       COUNT(*) FILTER (WHERE "deadlineAt" > now())                 AS date_limite_future
FROM "Scholarship"
WHERE "isActive" = true AND "moderationStatus" = 'approved';

\echo ''
\echo '=== 4. Les deux cartes vues sur l app existent-elles en base ? ==='
\echo '    0 ligne = ce sont des donnees fictives servies par le repli mock'
SELECT id, "nameFr", "isActive", "moderationStatus"
FROM "Scholarship"
WHERE "nameFr" ILIKE '%MacBain%' OR "nameFr" ILIKE '%Mastercard%';

\echo ''
\echo '=== 5. Controle : les programmes, eux, sont bien la ==='
\echo '    L app en affiche 344. Si le compte concorde, la base est vivante et'
\echo '    le probleme est propre aux bourses. Program n a pas de colonne de'
\echo '    publication : sa visibilite ne depend que de la presence des lignes.'
SELECT COUNT(*) AS programmes FROM "Program";

\echo ''
\echo '=== 6. Agregat des domaines declares dans les profils ==='
\echo '    Aucune donnee nominative : uniquement des compteurs.'
SELECT COUNT(*)                                              AS profils,
       COUNT(*) FILTER (WHERE cardinality("fieldIds") > 0)    AS avec_domaines_choisis
FROM "UserProfile";

\echo ''
\echo '=== 7. Preuves de consentement Etudes en France : la version est-elle reelle ? ==='
\echo '    Pour class-validator, une chaine d espaces n est PAS vide : le DTO la'
\echo '    laissait passer et le service ecrivait une version VIDE. La ligne'
\echo '    portait alors un consentedAt sans designer aucun texte, c est-a-dire'
\echo '    ce qu elle valait AVANT l ajout de la colonne. La garde est posee ;'
\echo '    ceci compte les lignes ecrites AVANT elle.'
\echo '    Aucune donnee nominative : consentVersion identifie un texte, pas'
\echo '    un etudiant.'
\echo '    Place en dernier a dessein : ON_ERROR_STOP arreterait le script si'
\echo '    cette table manquait, et les sections catalogue ont deja imprime.'
SELECT COUNT(*)                                                          AS declarations,
       COUNT(*) FILTER (WHERE btrim("consentVersion") = '')              AS version_vide_ou_blanche,
       COUNT(*) FILTER (WHERE "consentVersion" <> btrim("consentVersion")) AS version_rembourree
FROM "EefInterest";

\echo ''
\echo '=== 8. Les versions reellement enregistrees ==='
\echo '    quote_literal + length rendent les espaces VISIBLES : sans eux, une'
\echo '    version blanche s afficherait comme une cellule vide indiscernable.'
SELECT quote_literal("consentVersion") AS version,
       length("consentVersion")        AS longueur,
       COUNT(*)                        AS lignes
FROM "EefInterest" GROUP BY 1, 2 ORDER BY 3 DESC;

COMMIT;
