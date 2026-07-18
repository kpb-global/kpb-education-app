-- CreateEnum
CREATE TYPE "ConsentPurpose" AS ENUM (
  'product_analytics',
  'ai_third_party',
  'advisor_document_share',
  'outcome_evidence',
  'pilot_research',
  'aggregate_impact',
  'public_testimonial',
  'guardian_authorization',
  'marketing'
);

-- CreateTable
CREATE TABLE "ConsentNotice" (
  "id" TEXT NOT NULL,
  "purpose" "ConsentPurpose" NOT NULL,
  "version" TEXT NOT NULL,
  "languageCode" TEXT NOT NULL,
  "contentHash" TEXT NOT NULL,
  "contentStorageKey" TEXT,
  "effectiveAt" TIMESTAMP(3) NOT NULL,
  "retiredAt" TIMESTAMP(3),
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "ConsentNotice_pkey" PRIMARY KEY ("id")
);

CREATE TABLE "GuardianAuthorization" (
  "id" TEXT NOT NULL,
  "minorUserId" TEXT NOT NULL,
  "guardianUserId" TEXT,
  "relationshipCode" TEXT NOT NULL,
  "verificationMethod" TEXT NOT NULL,
  "evidenceStorageKey" TEXT,
  "status" TEXT NOT NULL DEFAULT 'pending',
  "verifiedAt" TIMESTAMP(3),
  "expiresAt" TIMESTAMP(3),
  "revokedAt" TIMESTAMP(3),
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updatedAt" TIMESTAMP(3) NOT NULL,
  CONSTRAINT "GuardianAuthorization_pkey" PRIMARY KEY ("id")
);

CREATE TABLE "ConsentReceipt" (
  "id" TEXT NOT NULL,
  "userId" TEXT NOT NULL,
  "purpose" "ConsentPurpose" NOT NULL,
  "noticeId" TEXT NOT NULL,
  "languageCode" TEXT NOT NULL,
  "channel" TEXT NOT NULL,
  "grantedAt" TIMESTAMP(3) NOT NULL,
  "revokedAt" TIMESTAMP(3),
  "guardianAuthorizationId" TEXT,
  "ipHash" TEXT,
  "userAgentClass" TEXT,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "ConsentReceipt_pkey" PRIMARY KEY ("id")
);

CREATE TABLE "IdempotencyRecord" (
  "id" TEXT NOT NULL,
  "actorType" TEXT NOT NULL,
  "actorId" TEXT NOT NULL,
  "operation" TEXT NOT NULL,
  "idempotencyKey" TEXT NOT NULL,
  "payloadHash" TEXT NOT NULL,
  "status" TEXT NOT NULL DEFAULT 'in_progress',
  "resourceType" TEXT,
  "resourceId" TEXT,
  "resultingVersion" INTEGER,
  "responseCode" INTEGER,
  "responseSnapshot" JSONB,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "completedAt" TIMESTAMP(3),
  "expiresAt" TIMESTAMP(3) NOT NULL,
  CONSTRAINT "IdempotencyRecord_pkey" PRIMARY KEY ("id")
);

CREATE TABLE "DomainEventOutbox" (
  "id" TEXT NOT NULL,
  "eventId" TEXT NOT NULL,
  "eventName" TEXT NOT NULL,
  "schemaVersion" INTEGER NOT NULL,
  "aggregateType" TEXT NOT NULL,
  "aggregateId" TEXT NOT NULL,
  "payload" JSONB NOT NULL,
  "occurredAt" TIMESTAMP(3) NOT NULL,
  "status" TEXT NOT NULL DEFAULT 'pending',
  "attemptCount" INTEGER NOT NULL DEFAULT 0,
  "nextAttemptAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "lockedAt" TIMESTAMP(3),
  "lockedBy" TEXT,
  "leaseExpiresAt" TIMESTAMP(3),
  "lastErrorCode" TEXT,
  "processedAt" TIMESTAMP(3),
  "deadLetteredAt" TIMESTAMP(3),
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "DomainEventOutbox_pkey" PRIMARY KEY ("id")
);

CREATE TABLE "AnalyticsEvent" (
  "id" TEXT NOT NULL,
  "eventId" TEXT NOT NULL,
  "idempotencyKey" TEXT NOT NULL,
  "eventName" TEXT NOT NULL,
  "schemaVersion" INTEGER NOT NULL,
  "occurredAt" TIMESTAMP(3) NOT NULL,
  "receivedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "source" TEXT NOT NULL,
  "actorKey" TEXT,
  "actorKeyVersion" TEXT,
  "pilotId" TEXT,
  "cohortId" TEXT,
  "countryCodeLocked" TEXT,
  "scholarshipId" TEXT,
  "cycleId" TEXT,
  "workspaceId" TEXT,
  "properties" JSONB NOT NULL,
  "traceId" TEXT,
  "isTest" BOOLEAN NOT NULL DEFAULT false,
  CONSTRAINT "AnalyticsEvent_pkey" PRIMARY KEY ("id")
);

CREATE TABLE "MetricDefinition" (
  "id" TEXT NOT NULL,
  "metricKey" TEXT NOT NULL,
  "version" INTEGER NOT NULL,
  "nameFr" TEXT NOT NULL,
  "definition" TEXT NOT NULL,
  "grain" TEXT NOT NULL,
  "numeratorDefinition" TEXT NOT NULL,
  "denominatorDefinition" TEXT NOT NULL,
  "numeratorQueryPath" TEXT,
  "denominatorQueryPath" TEXT,
  "numeratorSqlHash" TEXT,
  "denominatorSqlHash" TEXT,
  "definitionCommitSha" TEXT NOT NULL,
  "exclusions" JSONB NOT NULL,
  "dimensions" TEXT[] NOT NULL DEFAULT ARRAY[]::TEXT[],
  "sourceWatermarkField" TEXT NOT NULL,
  "lateArrivalHours" INTEGER NOT NULL DEFAULT 72,
  "correctionPolicy" TEXT NOT NULL,
  "ownerAdminId" TEXT NOT NULL,
  "effectiveAt" TIMESTAMP(3) NOT NULL,
  "retiredAt" TIMESTAMP(3),
  CONSTRAINT "MetricDefinition_pkey" PRIMARY KEY ("id")
);

CREATE TABLE "AdminScopeGrant" (
  "id" TEXT NOT NULL,
  "adminUserId" TEXT NOT NULL,
  "capability" TEXT NOT NULL,
  "countryCodes" TEXT[] NOT NULL DEFAULT ARRAY[]::TEXT[],
  "cohortIds" TEXT[] NOT NULL DEFAULT ARRAY[]::TEXT[],
  "resourceScope" JSONB,
  "grantedByAdminId" TEXT NOT NULL,
  "startsAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "expiresAt" TIMESTAMP(3),
  "revokedAt" TIMESTAMP(3),
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "AdminScopeGrant_pkey" PRIMARY KEY ("id")
);

CREATE TABLE "AdminAuditEvent" (
  "id" TEXT NOT NULL,
  "actorAdminId" TEXT,
  "action" TEXT NOT NULL,
  "purposeCode" TEXT,
  "entityType" TEXT NOT NULL,
  "entityId" TEXT NOT NULL,
  "requestId" TEXT NOT NULL,
  "correlationId" TEXT,
  "reasonCode" TEXT,
  "result" TEXT NOT NULL,
  "changes" JSONB,
  "occurredAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "AdminAuditEvent_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "ConsentNotice_purpose_version_languageCode_key" ON "ConsentNotice"("purpose", "version", "languageCode");
CREATE INDEX "ConsentNotice_purpose_effectiveAt_retiredAt_idx" ON "ConsentNotice"("purpose", "effectiveAt", "retiredAt");
CREATE INDEX "GuardianAuthorization_minorUserId_status_idx" ON "GuardianAuthorization"("minorUserId", "status");
CREATE INDEX "GuardianAuthorization_guardianUserId_status_idx" ON "GuardianAuthorization"("guardianUserId", "status");
CREATE INDEX "ConsentReceipt_userId_purpose_grantedAt_idx" ON "ConsentReceipt"("userId", "purpose", "grantedAt");
CREATE INDEX "ConsentReceipt_purpose_revokedAt_idx" ON "ConsentReceipt"("purpose", "revokedAt");
CREATE UNIQUE INDEX "one_active_consent_per_user_purpose" ON "ConsentReceipt"("userId", "purpose") WHERE "revokedAt" IS NULL;
CREATE UNIQUE INDEX "IdempotencyRecord_actorType_actorId_operation_idempotencyKe_key" ON "IdempotencyRecord"("actorType", "actorId", "operation", "idempotencyKey");
CREATE INDEX "IdempotencyRecord_resourceType_resourceId_createdAt_idx" ON "IdempotencyRecord"("resourceType", "resourceId", "createdAt");
CREATE INDEX "IdempotencyRecord_status_expiresAt_idx" ON "IdempotencyRecord"("status", "expiresAt");
CREATE UNIQUE INDEX "DomainEventOutbox_eventId_key" ON "DomainEventOutbox"("eventId");
CREATE INDEX "DomainEventOutbox_status_nextAttemptAt_idx" ON "DomainEventOutbox"("status", "nextAttemptAt");
CREATE INDEX "DomainEventOutbox_aggregateType_aggregateId_occurredAt_idx" ON "DomainEventOutbox"("aggregateType", "aggregateId", "occurredAt");
CREATE UNIQUE INDEX "AnalyticsEvent_eventId_key" ON "AnalyticsEvent"("eventId");
CREATE UNIQUE INDEX "AnalyticsEvent_idempotencyKey_key" ON "AnalyticsEvent"("idempotencyKey");
CREATE INDEX "AnalyticsEvent_eventName_occurredAt_idx" ON "AnalyticsEvent"("eventName", "occurredAt");
CREATE INDEX "AnalyticsEvent_pilotId_cohortId_occurredAt_idx" ON "AnalyticsEvent"("pilotId", "cohortId", "occurredAt");
CREATE INDEX "AnalyticsEvent_workspaceId_occurredAt_idx" ON "AnalyticsEvent"("workspaceId", "occurredAt");
CREATE UNIQUE INDEX "MetricDefinition_metricKey_version_key" ON "MetricDefinition"("metricKey", "version");
CREATE INDEX "MetricDefinition_effectiveAt_retiredAt_idx" ON "MetricDefinition"("effectiveAt", "retiredAt");
CREATE INDEX "AdminScopeGrant_adminUserId_capability_revokedAt_idx" ON "AdminScopeGrant"("adminUserId", "capability", "revokedAt");
CREATE INDEX "AdminScopeGrant_expiresAt_idx" ON "AdminScopeGrant"("expiresAt");
CREATE INDEX "AdminAuditEvent_entityType_entityId_occurredAt_idx" ON "AdminAuditEvent"("entityType", "entityId", "occurredAt");
CREATE INDEX "AdminAuditEvent_actorAdminId_occurredAt_idx" ON "AdminAuditEvent"("actorAdminId", "occurredAt");
CREATE INDEX "AdminAuditEvent_action_occurredAt_idx" ON "AdminAuditEvent"("action", "occurredAt");

-- AddForeignKey
ALTER TABLE "ConsentReceipt" ADD CONSTRAINT "ConsentReceipt_userId_fkey" FOREIGN KEY ("userId") REFERENCES "UserProfile"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "ConsentReceipt" ADD CONSTRAINT "ConsentReceipt_noticeId_fkey" FOREIGN KEY ("noticeId") REFERENCES "ConsentNotice"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "ConsentReceipt" ADD CONSTRAINT "ConsentReceipt_guardianAuthorizationId_fkey" FOREIGN KEY ("guardianAuthorizationId") REFERENCES "GuardianAuthorization"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "AdminScopeGrant" ADD CONSTRAINT "AdminScopeGrant_adminUserId_fkey" FOREIGN KEY ("adminUserId") REFERENCES "AdminUser"("id") ON DELETE CASCADE ON UPDATE CASCADE;
