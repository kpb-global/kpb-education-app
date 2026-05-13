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
import { CatalogController } from './modules/catalog/catalog.controller';
import { CatalogService } from './modules/catalog/catalog.service';
import { AppointmentsController } from './modules/appointments/appointments.controller';
import { AppointmentsService } from './modules/appointments/appointments.service';
import { AdminAuthGuard } from './common/guards/admin-auth.guard';
import { StudentAuthGuard } from './common/guards/student-auth.guard';
import { RolesGuard } from './common/guards/roles.guard';
import { AdminCasesController } from './modules/cases/admin-cases.controller';
import { CasesController } from './modules/cases/cases.controller';
import { CasesService } from './modules/cases/cases.service';
import { CaseMessagingGateway } from './modules/cases/case-messaging.gateway';
import { CommunityController } from './modules/community/community.controller';
import { CommunityService } from './modules/community/community.service';
import { ContentController } from './modules/content/content.controller';
import { ContentService } from './modules/content/content.service';
import { HealthController } from './modules/health/health.controller';
import { NotificationsController } from './modules/notifications/notifications.controller';
import { NotificationsService } from './modules/notifications/notifications.service';
import { FirebasePushService } from './modules/notifications/firebase-push.service';
import { CampaignExecutorService } from './modules/notifications/campaign-executor.service';
import { CampaignCronService } from './modules/notifications/campaign-cron.service';
import { DeviceTokensController } from './modules/notifications/device-tokens.controller';
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
import {
  AdminPaymentsController,
  PaymentsController,
} from './modules/payments/payments.controller';
import { PaymentsService } from './modules/payments/payments.service';
import { CinetpayAdapter } from './modules/payments/cinetpay.adapter';
import { PaydunyaAdapter } from './modules/payments/paydunya.adapter';
import { ParentLinksController } from './modules/parent-links/parent-links.controller';
import { ParentLinksService } from './modules/parent-links/parent-links.service';
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
      { name: 'global', ttl: 60000, limit: 60 },
      { name: 'auth', ttl: 60000, limit: 10 },
    ]),
    ScheduleModule.forRoot(),
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
    HealthController,
    NotificationsController,
    OrientationController,
    PartnerLeadsController,
    ProfilesController,
    ReportsController,
    SavedItemsController,
    CounsellorsController,
    AdminCounsellorsController,
    PaymentsController,
    AdminPaymentsController,
    ParentLinksController,
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
    AppointmentsService,
    CasesService,
    CaseMessagingGateway,
    CatalogService,
    CommunityService,
    ContentService,
    FirebasePushService,
    CampaignExecutorService,
    CampaignCronService,
    NotificationsService,
    OrientationService,
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
