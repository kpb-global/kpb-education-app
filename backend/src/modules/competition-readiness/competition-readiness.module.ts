import { Module } from '@nestjs/common';

import { StudentAuthGuard } from '../../common/guards/student-auth.guard';
import { LlmService } from '../ai/llm.service';
import { SupabaseAuthService } from '../auth/supabase-auth.service';
import { PrismaService } from '../prisma/prisma.service';
import { AntivirusService } from '../storage/antivirus.service';
import { StorageService } from '../storage/storage.service';
import { ApplicationArtifactsController } from './artifacts/application-artifacts.controller';
import { ApplicationArtifactsService } from './artifacts/application-artifacts.service';
import { ArtifactPolicyService } from './artifacts/artifact-policy.service';
import { DomainEventAnalyticsProjectorService } from './analytics/domain-event-analytics-projector.service';
import { DomainEventOutboxWorkerService } from './analytics/domain-event-outbox-worker.service';
import { StoragePurgeReconciliationService } from './analytics/storage-purge-reconciliation.service';
import { AdminAiUsageService } from './admin/admin-ai-usage.service';
import { AdminAvailabilityService } from './admin/admin-availability.service';
import { AdminEvidenceService } from './admin/admin-evidence.service';
import { AdminOutcomeEvidenceService } from './admin/admin-outcome-evidence.service';
import { AdminOutcomesAccessService } from './admin/admin-outcomes-access.service';
import { AdminOutcomesService } from './admin/admin-outcomes.service';
import { AdminImpactAccessService } from './admin/admin-impact-access.service';
import { AdminPartnershipsService } from './admin/admin-partnerships.service';
import { AdminReviewAccessService } from './admin/admin-review-access.service';
import { AdminReviewOperationsService } from './admin/admin-review-operations.service';
import { DomainEventOutboxService } from './common/domain-event-outbox.service';
import { FeatureAccessService } from './common/feature-access.service';
import { IdempotencyService } from './common/idempotency.service';
import { AiBudgetService } from './diagnostics/ai-budget.service';
import { AiConsentController } from './diagnostics/ai-consent.controller';
import { AiConsentService } from './diagnostics/ai-consent.service';
import { AiDiagnosticsController } from './diagnostics/ai-diagnostics.controller';
import { AiDiagnosticsService } from './diagnostics/ai-diagnostics.service';
import { OutcomeConsentController } from './outcomes/outcome-consent.controller';
import { OutcomeConsentService } from './outcomes/outcome-consent.service';
import { OutcomeEvidenceService } from './outcomes/outcome-evidence.service';
import { OutcomesController } from './outcomes/outcomes.controller';
import { OutcomesService } from './outcomes/outcomes.service';
import { ImpactPilotsService } from './pilots/impact-pilots.service';
import { ImpactSnapshotService } from './pilots/impact-snapshot.service';
import { StudyReviewController } from './reviews/study-review.controller';
import { StudyReviewConsentController } from './reviews/study-review-consent.controller';
import { StudyReviewConsentService } from './reviews/study-review-consent.service';
import { StudyReviewSchedulingService } from './reviews/study-review-scheduling.service';
import { StudyReviewService } from './reviews/study-review.service';
import { WorkspacesController } from './workspaces/workspaces.controller';
import { WorkspaceProgressService } from './workspaces/workspace-progress.service';
import { WorkspacesService } from './workspaces/workspaces.service';

@Module({
  controllers: [
    WorkspacesController,
    ApplicationArtifactsController,
    AiConsentController,
    AiDiagnosticsController,
    StudyReviewConsentController,
    StudyReviewController,
    OutcomeConsentController,
    OutcomesController,
  ],
  providers: [
    PrismaService,
    SupabaseAuthService,
    StudentAuthGuard,
    LlmService,
    AntivirusService,
    StorageService,
    FeatureAccessService,
    IdempotencyService,
    DomainEventOutboxService,
    DomainEventAnalyticsProjectorService,
    DomainEventOutboxWorkerService,
    StoragePurgeReconciliationService,
    WorkspaceProgressService,
    WorkspacesService,
    ArtifactPolicyService,
    ApplicationArtifactsService,
    AiBudgetService,
    AiConsentService,
    AiDiagnosticsService,
    StudyReviewConsentService,
    StudyReviewService,
    StudyReviewSchedulingService,
    OutcomeConsentService,
    OutcomeEvidenceService,
    OutcomesService,
    AdminReviewAccessService,
    AdminReviewOperationsService,
    AdminEvidenceService,
    AdminAiUsageService,
    AdminAvailabilityService,
    AdminOutcomesAccessService,
    AdminOutcomesService,
    AdminOutcomeEvidenceService,
    AdminImpactAccessService,
    AdminPartnershipsService,
    ImpactPilotsService,
    ImpactSnapshotService,
  ],
  exports: [
    AdminReviewOperationsService,
    AdminEvidenceService,
    AdminAiUsageService,
    AdminAvailabilityService,
    AdminOutcomesService,
    AdminOutcomeEvidenceService,
    StudyReviewSchedulingService,
    AdminPartnershipsService,
    ImpactPilotsService,
    ImpactSnapshotService,
  ],
})
export class CompetitionReadinessModule {}
