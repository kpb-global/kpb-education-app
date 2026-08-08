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

COMMIT;
