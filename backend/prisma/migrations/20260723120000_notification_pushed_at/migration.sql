-- KPB-155: track push delivery on the durable in-app feed.
-- pushedAt is set when a push is actually delivered for a UserNotification row.
-- NULL means feed-only: the entry was recorded but no push went out (suppressed
-- by quiet hours or the per-user daily frequency cap). The dispatcher counts
-- rows with a recent pushedAt to enforce that cap.
ALTER TABLE "UserNotification" ADD COLUMN "pushedAt" TIMESTAMP(3);

-- Supports the frequency-cap lookup (pushes for a user within a rolling window).
CREATE INDEX "UserNotification_userId_pushedAt_idx" ON "UserNotification"("userId", "pushedAt");
