-- Catalogue « Études en France » — l'écart procédure (plan § 5.3).
--
-- CE QUE `Institution` / `Program` NE SAVAIENT PAS DIRE
--
-- Le tronc commun du catalogue décrit une formation : son nom, son niveau, son
-- prix, sa langue. Il ne dit rien de la SEULE chose qui décide du calendrier et
-- du dossier d'un étudiant ouest-africain : par quelle procédure on y entre.
-- Une licence 1re année se demande par DAP blanche, avant le 17 décembre, avec
-- un test de français. Un master se demande par la procédure Études en France,
-- sur un autre calendrier, sans DAP. Servir les deux sous la même fiche, c'est
-- laisser l'étudiant rater la seule échéance qui compte.
--
-- D'où ces colonnes. Elles sont toutes NULLABLES et sans défaut : les 133
-- formations France déjà en base (écoles privées partenaires, procédure
-- directe) restent valides avec NULL = « procédure non qualifiée », et un
-- backend plus ancien remis sur ce schéma les ignore.
--
-- POURQUOI `uaiCode` SUR L'ÉTABLISSEMENT
--
-- L'UAI est l'identifiant officiel d'un établissement français. C'est la clé
-- qui relie une ligne du catalogue aux jeux de données du ministère — donc la
-- seule façon de RE-vérifier une fiche automatiquement dans six mois, quand
-- l'université aura fusionné, changé de nom, ou fermé une mention. Sans elle,
-- la re-vérification redevient du travail manuel, c'est-à-dire du travail qui
-- n'est pas fait.
--
-- ADDITIF SEULEMENT : aucun DROP, aucun NOT NULL, aucune reprise de données.

ALTER TABLE "Institution" ADD COLUMN "institutionType" TEXT;
ALTER TABLE "Institution" ADD COLUMN "uaiCode" TEXT;
ALTER TABLE "Institution" ADD COLUMN "websiteUrl" TEXT;

ALTER TABLE "Program" ADD COLUMN "procedureType" TEXT;
ALTER TABLE "Program" ADD COLUMN "selectivity" TEXT;
ALTER TABLE "Program" ADD COLUMN "formationCode" TEXT;
ALTER TABLE "Program" ADD COLUMN "campusCity" TEXT;
ALTER TABLE "Program" ADD COLUMN "frenchLevelRequired" TEXT;
ALTER TABLE "Program" ADD COLUMN "applicationFeeEur" INTEGER;
ALTER TABLE "Program" ADD COLUMN "isActive" BOOLEAN NOT NULL DEFAULT true;

-- `isActive` existe DÉJÀ sur Country ; il manquait sur Program, et son absence
-- est bloquante ici : le pipeline des bourses importe ses lignes INACTIVES, en
-- attente de modération, et c'est précisément ce qui a empêché une fiche non
-- vérifiée d'atteindre un appareil. Un import de 7 000 formations sans ce
-- garde-fou publierait 7 000 fiches non relues le jour même.
--
-- Le défaut est `true`, et il est volontaire : les lignes DÉJÀ en production
-- sont publiées et doivent le rester. C'est l'import EEF qui écrit `false`
-- explicitement, jamais le schéma qui le devine.

CREATE INDEX "Institution_uaiCode_idx" ON "Institution"("uaiCode");
CREATE INDEX "Program_procedureType_idx" ON "Program"("procedureType");
CREATE INDEX "Program_isActive_idx" ON "Program"("isActive");
