import { Module } from '@nestjs/common';
import { JwtModule } from '@nestjs/jwt';
import { APP_GUARD, Reflector } from '@nestjs/core';
import { ScheduleModule } from '@nestjs/schedule';
import { ThrottlerModule, ThrottlerGuard } from '@nestjs/throttler';

import { AdminUsersController } from './modules/admin-users/admin-users.controller';
import { AdminUsersService } from './modules/admin-users/admin-users.service';
import { AuthController } from './modules/auth/auth.controller';
import { AuthService } from './modules/auth/auth.service';
import { StudentAuthController } from './modules/auth/student-auth.controller';
import { StudentAuthService } from './modules/auth/student-auth.service';
import { SupabaseAuthService } from './modules/auth/supabase-auth.service';
import { MagicLinkMailService } from './modules/auth/magic-link-mail.service';
import { CatalogController } from './modules/catalog/catalog.controller';
import { CatalogService } from './modules/catalog/catalog.service';
import { CountriesModule } from './modules/countries/countries.module';
import { AppointmentsController } from './modules/appointments/appointments.controller';
import { AppointmentsService } from './modules/appointments/appointments.service';
import { AdminAuthGuard } from './common/guards/admin-auth.guard';
import { StudentAuthGuard } from './common/guards/student-auth.guard';
import { RolesGuard } from './common/guards/roles.guard';
import { AdminCasesController } from './modules/cases/admin-cases.controller';
import { CasesController } from './modules/cases/cases.controller';
import { CasesService } from './modules/cases/cases.service';
import { CaseMessagingGateway } from './modules/cases/case-messaging.gateway';
import { CaseReassignmentCronService } from './modules/cases/case-reassignment-cron.service';
import { CommunityController } from './modules/community/community.controller';
import { CommunityService } from './modules/community/community.service';
import { ContentController } from './modules/content/content.controller';
import { ContentService } from './modules/content/content.service';
import { HealthController } from './modules/health/health.controller';
import { NotificationsController } from './modules/notifications/notifications.controller';
import { NotificationsService } from './modules/notifications/notifications.service';
import { OneSignalSenderService } from './modules/notifications/onesignal-sender.service';
import { CampaignExecutorService } from './modules/notifications/campaign-executor.service';
import { CampaignCronService } from './modules/notifications/campaign-cron.service';
import { DeadlineReminderCronService } from './modules/notifications/deadline-reminder-cron.service';
import { ProfileNudgeCronService } from './modules/notifications/profile-nudge-cron.service';
import { DeviceTokensController } from './modules/notifications/device-tokens.controller';
import { AdminPushController } from './modules/notifications/admin-push.controller';
import { CoachController } from './modules/coach/coach.controller';
import { CoachQuotaService } from './modules/coach/coach-quota.service';
import { CoachService } from './modules/coach/coach.service';
import { DocumentReviewController } from './modules/document-review/document-review.controller';
import { DocumentReviewService } from './modules/document-review/document-review.service';
import { CommercialController } from './modules/commercial/commercial.controller';
import { CommercialService } from './modules/commercial/commercial.service';
import { AdminDashboardController } from './modules/admin-dashboard/admin-dashboard.controller';
import { AdminDashboardService } from './modules/admin-dashboard/admin-dashboard.service';
import { AdminCatalogController } from './modules/admin-catalog/admin-catalog.controller';
import { AdminCatalogService } from './modules/admin-catalog/admin-catalog.service';
import { ImpactController } from './modules/impact/impact.controller';
import { ImpactService } from './modules/impact/impact.service';
import { ToolsController } from './modules/tools/tools.controller';
import { ToolsService } from './modules/tools/tools.service';
import { YoutubeController } from './modules/content-youtube/youtube.controller';
import { YoutubeService } from './modules/content-youtube/youtube.service';
import { LlmService } from './modules/ai/llm.service';
import { OrientationController } from './modules/orientation/orientation.controller';
import { OrientationService } from './modules/orientation/orientation.service';
import { PartnerLeadsController } from './modules/partner-leads/partner-leads.controller';
import { PartnerLeadsService } from './modules/partner-leads/partner-leads.service';
import { ProfilesController } from './modules/profiles/profiles.controller';
import { ProfilesService } from './modules/profiles/profiles.service';
import { PrismaService } from './modules/prisma/prisma.service';
import { ReportsController } from './modules/reports/reports.controller';
import { ReportsService } from './modules/reports/reports.service';
import { SavedItemsController } from './modules/saved-items/saved-items.controller';
import { SavedItemsService } from './modules/saved-items/saved-items.service';
import { StorageService } from './modules/storage/storage.service';
import {
  AdminCounsellorsController,
  CounsellorsController,
} from './modules/counsellors/counsellors.controller';
import { CounsellorsService } from './modules/counsellors/counsellors.service';
// NOTE: PaymentsController/AdminPaymentsController are intentionally NOT
// registered — the launch is WhatsApp-advisor only (no in-app checkout), and an
// unauthenticated payment webhook is a needless attack surface. PaymentsService
// stays a provider because ServicePackagesService injects it.
import { PaymentsService } from './modules/payments/payments.service';
import { CinetpayAdapter } from './modules/payments/cinetpay.adapter';
import { PaydunyaAdapter } from './modules/payments/paydunya.adapter';
import { ParentLinksController } from './modules/parent-links/parent-links.controller';
import { ParentLinksService } from './modules/parent-links/parent-links.service';
import { ReferralsController } from './modules/referrals/referrals.controller';
import { ReferralsService } from './modules/referrals/referrals.service';
import { AdminScholarshipsController, ScholarshipsController } from './modules/scholarships-index/admin-scholarships.controller';
import { ScholarshipsIndexService } from './modules/scholarships-index/scholarships-index.service';
import { GreatYopScraper } from './modules/scholarships-index/scrapers/greatyop.scraper';
import { MastereTnScraper } from './modules/scholarships-index/scrapers/mastereTn.scraper';
import { VisaAvailabilityController } from './modules/visa-availability/visa-availability.controller';
import { VisaAvailabilityService } from './modules/visa-availability/visa-availability.service';
import {
  AdminServicePackagesController,
  MyPurchasesController,
  ServicePackagesController,
} from './modules/service-packages/service-packages.controller';
import { ServicePackagesService } from './modules/service-packages/service-packages.service';
import {
  AdminAlumniController,
  AlumniController,
  MyAlumniController,
} from './modules/alumni/alumni.controller';
import { AlumniService } from './modules/alumni/alumni.service';
import {
  AdminPartnersController,
  PartnersController,
} from './modules/partners/partners.controller';
import { PartnersService } from './modules/partners/partners.service';
import {
  AdminSalonController,
  MySalonController,
  SalonController,
} from './modules/salon/salon.controller';
import { SalonService } from './modules/salon/salon.service';


@Module({
  imports: [
    JwtModule.register({
      global: true,
      secret: process.env.KPB_JWT_SECRET ?? (() => {
        if (process.env.NODE_ENV === 'production') {
          throw new Error('KPB_JWT_SECRET must be set in production');
        }
        return 'kpb-student-jwt-secret-local-dev';
      })(),
      signOptions: { expiresIn: '1h' },
    }),
    ThrottlerModule.forRoot([
      {
        name: 'global',
        ttl: 60000,
        limit: process.env.NODE_ENV === 'production' ? 60 : 600,
      },
      { name: 'auth', ttl: 60000, limit: 10 },
    ]),
    ScheduleModule.forRoot(),
    CountriesModule,
  ],
  controllers: [
    AuthController,
    StudentAuthController,
    AdminCasesController,
    AdminUsersController,
    CatalogController,
    AppointmentsController,
    CasesController,
    CommunityController,
    ContentController,
    DeviceTokensController,
    AdminPushController,
    DocumentReviewController,
    HealthController,
    NotificationsController,
    OrientationController,
    CoachController,
    CommercialController,
    AdminDashboardController,
    AdminCatalogController,
    ImpactController,
    ToolsController,
    YoutubeController,
    PartnerLeadsController,
    ProfilesController,
    ReportsController,
    SavedItemsController,
    CounsellorsController,
    AdminCounsellorsController,
    ParentLinksController,
    ReferralsController,
    AdminScholarshipsController,
    ScholarshipsController,
    VisaAvailabilityController,
    ServicePackagesController,
    MyPurchasesController,
    AdminServicePackagesController,
    AlumniController,
    MyAlumniController,
    AdminAlumniController,
    PartnersController,
    AdminPartnersController,
    SalonController,
    MySalonController,
    AdminSalonController,
  ],
  providers: [
    Reflector,
    { provide: APP_GUARD, useClass: ThrottlerGuard },
    AdminAuthGuard,
    StudentAuthGuard,
    RolesGuard,
    AdminUsersService,
    AuthService,
    StudentAuthService,
    SupabaseAuthService,
    MagicLinkMailService,
    AppointmentsService,
    CasesService,
    CaseMessagingGateway,
    CaseReassignmentCronService,
    CatalogService,
    CommunityService,
    ContentService,
    OneSignalSenderService,
    CampaignExecutorService,
    CampaignCronService,
    DeadlineReminderCronService,
    ProfileNudgeCronService,
    NotificationsService,
    OrientationService,
    LlmService,
    DocumentReviewService,
    CoachService,
    CoachQuotaService,
    CommercialService,
    AdminDashboardService,
    AdminCatalogService,
    ImpactService,
    ToolsService,
    YoutubeService,
    PartnerLeadsService,
    ProfilesService,
    PrismaService,
    ReportsService,
    SavedItemsService,
    StorageService,
    CounsellorsService,
    PaymentsService,
    CinetpayAdapter,
    PaydunyaAdapter,
    ParentLinksService,
    ReferralsService,
    ScholarshipsIndexService,
    GreatYopScraper,
    MastereTnScraper,
    VisaAvailabilityService,
    ServicePackagesService,
    AlumniService,
    PartnersService,
    SalonService,
  ],
})
export class AppModule {}
