-- Reprise de l'auteur des avis conseillers déjà enregistrés.
--
-- `POST /counsellors/:id/reviews` prenait l'auteur DANS LE CORPS de la requête
-- (`reviewerUserId`), que l'app n'a jamais envoyé : tous les avis publiés
-- depuis l'app ont donc `reviewerUserId = NULL`. Conséquence : la suppression de
-- compte (`deleteMany WHERE reviewerUserId = …`) ne les trouvait pas, et le nom
-- civil de l'étudiant (`reviewerName`) survivait à l'effacement de son compte.
--
-- Le code lit désormais l'auteur dans le jeton vérifié. Cette reprise fait de
-- même pour l'existant : l'auteur d'un avis est le propriétaire du dossier
-- qu'il note (`caseId`), l'app ne proposant de noter qu'un dossier terminé.
--
-- Deux garde-fous :
--   * on ne touche qu'aux avis SANS auteur (`reviewerUserId IS NULL`), donc la
--     reprise est idempotente et n'écrase rien ;
--   * on ne rattache l'avis que si le dossier a bien été traité par le
--     conseiller NOTÉ. Un avis dont le `caseId` désigne le dossier d'un autre
--     conseiller ne correspond à aucun parcours légitime de l'app : le
--     rattacher au propriétaire de ce dossier attribuerait à un innocent un
--     avis qu'il n'a pas écrit, et le supprimerait avec son compte.
--
-- Les avis qui ne remplissent pas ces conditions restent à NULL : c'est
-- l'aveu honnête « auteur inconnu », que la modération voit déjà.

UPDATE "CounsellorReview" AS r
SET "reviewerUserId" = c."userId"
FROM "Case" AS c
WHERE r."reviewerUserId" IS NULL
  AND r."caseId" = c."id"
  AND c."counsellorId" = r."counsellorId";
