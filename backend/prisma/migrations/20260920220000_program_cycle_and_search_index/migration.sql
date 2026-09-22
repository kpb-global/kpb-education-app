-- `Program.cycle` et l'index qui rend la recherche paginée tenable.
--
-- POURQUOI UNE COLONNE ET PAS UN PRÉFIXE DE `levelFr`
--
-- Le catalogue « Études en France » connaît le cycle exact de chaque ligne —
-- licence1, licence2, licence3, but1, deust, sante, ingenieur, master — mais
-- ne l'écrivait nulle part : il le fondait dans `levelFr`
-- (« Bac+3 — Licence, 2e année »). Facetter là-dessus obligerait à découper
-- une chaîne rédigée pour être LUE, donc à faire dépendre un filtre de la
-- ponctuation d'un libellé. Le premier qui corrige un tiret casse la facette.
--
-- La colonne est nullable : les 133 formations France déjà en base (écoles
-- privées partenaires) n'ont pas de cycle universitaire, et NULL dit
-- exactement cela — « cycle non qualifié » — au lieu d'un `''` qui se
-- rangerait dans les facettes comme une valeur.
--
-- POURQUOI L'INDEX COMPOSITE
--
-- La pagination par curseur ordonne sur (nameFr, id) et filtre toujours sur
-- `isActive`. Sans index, chaque page trie 10 247 lignes pour en rendre 20, et
-- le coût est le MÊME à la page 1 et à la page 500 — c'est-à-dire que la
-- lenteur n'apparaît qu'en charge, le jour de la campagne. L'index couvre le
-- filtre et l'ordre d'un coup.
--
-- ADDITIF SEULEMENT : une colonne nullable, un index, aucun DROP, aucune
-- reprise de données.

ALTER TABLE "Program" ADD COLUMN "cycle" TEXT;

CREATE INDEX "Program_cycle_idx" ON "Program"("cycle");
CREATE INDEX "Program_isActive_nameFr_id_idx" ON "Program"("isActive", "nameFr", "id");
