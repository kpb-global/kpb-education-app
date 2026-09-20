-- `Institution.isActive` — la moitié manquante du garde-fou d'import.
--
-- CE QUE LA MIGRATION PRÉCÉDENTE A RATÉ
--
-- `20260920120000_eef_catalog_procedure_fields` a ajouté `Program.isActive`
-- et l'import EEF écrit `false` : 10 247 formations créées « en attente de
-- modération ». Sauf que RIEN ne lisait ce drapeau. `CatalogService` et
-- `MatchesService` construisaient leur filtre à partir des seuls paramètres de
-- requête, donc les 10 247 lignes non relues étaient publiques à la seconde
-- où l'import se terminait. Le drapeau existait, la garantie non.
--
-- Et même une fois les formations filtrées, l'établissement restait public
-- avec son `programIds` complet — un tableau que l'app utilise pour compter,
-- prévisualiser, naviguer et comparer. Publier l'université, c'était publier
-- des références vers 294 formations que personne n'a relues.
--
-- D'où cette colonne : un établissement importé est mis en attente comme ses
-- formations, et la fiche d'université — son texte de présentation, son
-- effectif daté — est elle aussi une affirmation qui se vérifie avant de
-- s'afficher.
--
-- ADDITIF SEULEMENT. Le défaut est `true` : les établissements DÉJÀ en
-- production sont publiés et doivent le rester. C'est l'import EEF qui écrit
-- `false` explicitement, jamais le schéma qui le devine.

ALTER TABLE "Institution" ADD COLUMN "isActive" BOOLEAN NOT NULL DEFAULT true;

CREATE INDEX "Institution_isActive_idx" ON "Institution"("isActive");
