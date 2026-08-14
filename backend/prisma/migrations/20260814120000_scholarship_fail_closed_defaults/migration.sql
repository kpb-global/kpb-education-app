-- Défauts fail-closed sur Scholarship.
--
-- ADDITIF ET SANS RISQUE : cette migration ne change QUE les valeurs par défaut
-- appliquées aux futures insertions. Aucune ligne existante n'est touchée — pas
-- d'UPDATE, pas de backfill, pas de réécriture de table. Un backend antérieur
-- remis en place continue de fonctionner : il pose ces deux champs
-- explicitement, comme le font tous les chemins d'écriture actuels.
--
-- POURQUOI : les défauts précédents (true / approved) sont le mécanisme exact
-- par lequel 11 fiches de démonstration sont devenues publiques en production.
-- Créées par une version du seed qui ne posait pas ces colonnes, elles ont été
-- publiées par le schéma lui-même. Une bourse créée sans qu'on précise rien ne
-- doit plus jamais être visible d'un étudiant.
ALTER TABLE "Scholarship" ALTER COLUMN "isActive" SET DEFAULT false;
ALTER TABLE "Scholarship" ALTER COLUMN "moderationStatus" SET DEFAULT 'pending';
