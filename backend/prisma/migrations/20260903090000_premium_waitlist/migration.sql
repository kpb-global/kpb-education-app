-- Liste d'attente Karatou Premium.
--
-- Table DÉDIÉE, et non une colonne de plus sur "EefInterest".
--
-- "EefInterest" est un registre de consentement : sa raison d'être est de
-- pouvoir produire la phrase exacte qu'un étudiant a acceptée pour l'espace
-- « Études en France ». Y cocher "wantsPremium" pour quelqu'un qui n'a jamais
-- rien lu sur cet espace aurait écrit un consentement qu'il n'a pas donné, dans
-- le registre même qui sert à le prouver — et le back-office l'aurait ensuite
-- listé comme prospect Études en France, avec un conseiller qui rappelle au
-- mauvais sujet.
--
-- Une ligne par profil : la contrainte unique sur "userId" fait qu'une seconde
-- inscription met à jour la ligne au lieu d'en créer une autre. Sans elle, un
-- double tap sur un réseau lent gonflerait le compteur que cette table existe
-- précisément pour rendre fiable.
--
-- "consentedAt" est NOT NULL SANS valeur par défaut, volontairement : la preuve
-- doit venir de l'écran qui l'a demandée, jamais d'un now() implicite qui
-- daterait une inscription que personne n'a demandée. "consentVersion" pousse
-- la même idée d'un cran — une date dit QUAND, la version dit CE QUI a été lu.
--
-- Aucune colonne de montant, d'état de facturation ni de référence de paiement.
-- Karatou n'encaisse rien dans l'application (App Store 3.1.1) : l'inscription
-- est une déclaration d'intérêt gratuite et sans engagement.
CREATE TABLE "PremiumWaitlistEntry" (
    "id" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "consentVersion" TEXT NOT NULL,
    "consentedAt" TIMESTAMP(3) NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "PremiumWaitlistEntry_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX "PremiumWaitlistEntry_userId_key" ON "PremiumWaitlistEntry"("userId");

CREATE INDEX "PremiumWaitlistEntry_createdAt_idx" ON "PremiumWaitlistEntry"("createdAt");

ALTER TABLE "PremiumWaitlistEntry" ADD CONSTRAINT "PremiumWaitlistEntry_userId_fkey" FOREIGN KEY ("userId") REFERENCES "UserProfile"("id") ON DELETE CASCADE ON UPDATE CASCADE;
