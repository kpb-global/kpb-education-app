-- Route ouverte au tap d'une campagne push (ex. `/scholarships/<id>`).
--
-- Null veut dire « accueil », comme avant : les campagnes existantes gardent
-- leur comportement.
--
-- ADDITIF SEULEMENT.

ALTER TABLE "NotificationCampaign" ADD COLUMN "route" TEXT;
