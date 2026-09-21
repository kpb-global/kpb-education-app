-- Logo d'établissement, uniquement quand un fichier réutilisable existe.
--
-- Les trois colonnes voyagent ensemble : l'URL seule ne dit ni d'où vient
-- l'image ni sous quelle licence on a le droit de l'afficher. Null des trois
-- côtés veut dire « pas de logo libre », pas « oubli ».
--
-- ADDITIF SEULEMENT.

ALTER TABLE "Institution" ADD COLUMN "logoUrl" TEXT;
ALTER TABLE "Institution" ADD COLUMN "logoSourceUrl" TEXT;
ALTER TABLE "Institution" ADD COLUMN "logoLicence" TEXT;
