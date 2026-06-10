-- CreateTable
CREATE TABLE "OrientationSession" (
    "id" TEXT NOT NULL,
    "userId" TEXT,
    "answers" JSONB NOT NULL,
    "recommendations" JSONB NOT NULL,
    "iaModelUsed" TEXT,
    "nextActions" JSONB,
    "completedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "OrientationSession_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "OrientationSession_userId_idx" ON "OrientationSession"("userId");
