-- Les signaux d'admission publiés par l'établissement, en colonnes.
--
-- CE QUE LA SHORTLIST NE POUVAIT PAS FAIRE SANS ELLES
--
-- La liste à trois étages (ambition / cible / sécurité) suppose qu'on sache
-- classer deux formations par risque d'admission. Or `selectivity` ne le
-- permet PAS : sur les 10 247 lignes du catalogue, elle est constante à
-- l'intérieur d'un cycle — tous les masters, toutes les L2, toutes les L3,
-- tous les BUT et tous les DEUST sont `selective`, et seule la L1 varie
-- (1 723 non sélectives contre 663). Trier les masters là-dessus aurait
-- reproduit le cycle que l'étudiant venait de choisir, sous trois noms
-- différents. C'est exactement le « pourcentage opaque dans un produit
-- payant » que le plan (§ 6) dit de ne pas livrer.
--
-- Ce qui varie réellement et qui est ATTESTÉ, le catalogue le portait déjà,
-- mais seulement en prose, noyé dans `requirementsFr` :
--
--   `recommendedBachelors` — les licences conseillées à l'entrée, telles que
--   publiées par l'établissement. 2 955 masters sur 3 112 en déclarent. C'est
--   la seule exigence d'admission NOMINATIVE que les données ouvertes
--   fournissent, et 302 d'entre eux publient « Toutes licences », ce qui est
--   une information en soi.
--
--   `admissionModes` — « Dossier », « Entretien », « Examen », « Concours ».
--   2 914 masters en déclarent. Un dossier seul et un concours ne demandent
--   pas le même travail : c'est une échelle d'effort publiée, pas une
--   estimation maison.
--
-- Une phrase se lit ; elle ne se filtre pas. Redécouper `requirementsFr` pour
-- retrouver ces listes ferait dépendre l'appariement de la ponctuation d'un
-- texte rédigé pour être LU — la faute que `Program.cycle` avait déjà refusé
-- de commettre sur `levelFr`.
--
-- POURQUOI UNE TROISIÈME COLONNE DÉRIVÉE
--
-- `recommendedFieldIds` est l'index matérialisé de `recommendedBachelors` :
-- chaque mention passée par `resolveFieldId`, la MÊME fonction qui classe déjà
-- les intitulés du catalogue (99,4 % des 353 mentions distinctes tombent sur
-- un mot-clé, sans repli). Elle existe pour que la requête puisse demander
-- « les masters dont la porte d'entrée est ouverte à mon domaine » sans lire
-- 3 112 lignes à chaque appel.
--
-- Les libellés restent la source de vérité : c'est eux qu'on montre à
-- l'étudiant, eux que l'établissement a publiés. La colonne dérivée est
-- rejouable — si la table de mots-clés change, on la recalcule.
--
-- ADDITIF SEULEMENT : trois colonnes à défaut vide, un index, aucun DROP.
-- Les lignes déjà en base reçoivent `{}`, ce qui les rend simplement
-- invisibles à l'appariement par licence conseillée — vrai, et sans effet de
-- bord : les 133 formations d'écoles privées n'en publient pas.

ALTER TABLE "Program" ADD COLUMN "recommendedBachelors" TEXT[] NOT NULL DEFAULT '{}';
ALTER TABLE "Program" ADD COLUMN "recommendedFieldIds" TEXT[] NOT NULL DEFAULT '{}';
ALTER TABLE "Program" ADD COLUMN "admissionModes" TEXT[] NOT NULL DEFAULT '{}';

-- GIN : l'appariement demande un CHEVAUCHEMENT de tableaux
-- (`recommendedFieldIds && ARRAY['d02','d07']`). Un B-tree ne sait pas
-- répondre à cette question ; sans index, chaque shortlist relit la table.
CREATE INDEX "Program_recommendedFieldIds_idx" ON "Program" USING GIN ("recommendedFieldIds");
