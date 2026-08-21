-- Espace « Études en France » — déclaration d'intérêt (Phase 0).
--
-- Une ligne par profil : la contrainte unique sur "userId" fait qu'une
-- redéclaration met à jour la ligne existante au lieu d'en créer une seconde.
-- Sans elle, un double tap sur un réseau lent remplit la liste d'appel de
-- doublons que personne ne dédoublonne ensuite.
--
-- "consentedAt" est NOT NULL sans valeur par défaut, volontairement : la preuve
-- de consentement doit venir de l'écran qui l'a demandé, jamais d'un
-- now() implicite qui daterait un consentement que personne n'a donné.
CREATE TABLE "EefInterest" (
    "id" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "currentLevel" TEXT,
    "targetLevel" TEXT,
    "fieldIds" TEXT[] DEFAULT ARRAY[]::TEXT[],
    "wantsPremium" BOOLEAN NOT NULL DEFAULT false,
    "consentedAt" TIMESTAMP(3) NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "EefInterest_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX "EefInterest_userId_key" ON "EefInterest"("userId");

CREATE INDEX "EefInterest_createdAt_idx" ON "EefInterest"("createdAt");

CREATE INDEX "EefInterest_wantsPremium_idx" ON "EefInterest"("wantsPremium");

ALTER TABLE "EefInterest" ADD CONSTRAINT "EefInterest_userId_fkey" FOREIGN KEY ("userId") REFERENCES "UserProfile"("id") ON DELETE CASCADE ON UPDATE CASCADE;
