import {
  BadRequestException,
  Injectable,
  NotFoundException,
  ServiceUnavailableException,
} from '@nestjs/common';

import { PrismaService } from '../prisma/prisma.service';

const VERIFICATION_MAX_AGE_DAYS = 30;
const DAY_MS = 24 * 60 * 60 * 1000;

type QualityCycle = {
  academicYear?: string | null;
  status: string;
  estimatedOpenAt?: Date | null;
  estimatedCloseAt?: Date | null;
  opensAt?: Date | null;
  closesAt?: Date | null;
  sourceUrl?: string | null;
  verifiedAt?: Date | null;
};

type QualityStep = {
  stepNumber: number;
  titleFr: string;
  titleEn: string;
  descriptionFr: string;
  descriptionEn: string;
};

export type ScholarshipQualitySnapshot = {
  id: string;
  nameFr: string;
  nameEn: string;
  countryId: string;
  countryNameFr: string;
  countryNameEn: string;
  levelEligibleFr: string;
  levelEligibleEn: string;
  typeOfFundingFr: string;
  typeOfFundingEn: string;
  fundingType: string;
  deadlineLabelFr: string;
  deadlineLabelEn: string;
  descriptionFr: string;
  descriptionEn: string;
  advantagesFr: string[];
  advantagesEn: string[];
  eligibilityFr: string[];
  eligibilityEn: string[];
  keyRequirementsFr: string[];
  keyRequirementsEn: string[];
  applicationUrl?: string | null;
  sourceUrl?: string | null;
  lastVerifiedAt?: Date | null;
  applicationSteps: QualityStep[];
  cycles: QualityCycle[];
};

export type ScholarshipQualityCheck = {
  code: string;
  labelFr: string;
  labelEn: string;
  passed: boolean;
};

export type ScholarshipReadinessReport = {
  scholarshipId: string;
  ready: boolean;
  score: number;
  verificationMaxAgeDays: number;
  checks: ScholarshipQualityCheck[];
  blockingIssues: ScholarshipQualityCheck[];
};

@Injectable()
export class ScholarshipContentQualityService {
  constructor(private readonly prismaService: PrismaService) {}

  async getReadiness(
    scholarshipId: string,
    cycleOverride?: QualityCycle,
    now = new Date(),
  ): Promise<ScholarshipReadinessReport> {
    if (!this.prismaService.isEnabled) {
      throw new ServiceUnavailableException(
        'Database is not configured. Set DATABASE_URL.',
      );
    }
    const scholarship = await this.prismaService.execute((prisma) =>
      prisma.scholarship.findUnique({
        where: { id: scholarshipId },
        include: {
          applicationSteps: { orderBy: { stepNumber: 'asc' } },
          cycles: { orderBy: { academicYear: 'desc' } },
        },
      }),
    );
    if (!scholarship) {
      throw new NotFoundException(`Scholarship ${scholarshipId} not found.`);
    }
    return this.evaluate(scholarship, cycleOverride, now);
  }

  async assertReady(
    scholarshipId: string,
    cycleOverride?: QualityCycle,
    now = new Date(),
  ): Promise<ScholarshipReadinessReport> {
    const report = await this.getReadiness(
      scholarshipId,
      cycleOverride,
      now,
    );
    if (!report.ready) {
      throw new BadRequestException({
        message: 'Scholarship content is incomplete and cannot be published.',
        code: 'SCHOLARSHIP_NOT_READY',
        readiness: report,
      });
    }
    return report;
  }

  evaluate(
    scholarship: ScholarshipQualitySnapshot,
    cycleOverride?: QualityCycle,
    now = new Date(),
  ): ScholarshipReadinessReport {
    const checks: ScholarshipQualityCheck[] = [];
    const add = (
      code: string,
      labelFr: string,
      labelEn: string,
      passed: boolean,
    ) => checks.push({ code, labelFr, labelEn, passed });

    add('name_fr', 'Nom français', 'French name', this.hasText(scholarship.nameFr));
    add('name_en', 'Nom anglais', 'English name', this.hasText(scholarship.nameEn));
    add(
      'country',
      'Pays renseigné dans les deux langues',
      'Country provided in both languages',
      this.hasText(scholarship.countryId) &&
        this.hasText(scholarship.countryNameFr) &&
        this.hasText(scholarship.countryNameEn),
    );
    add(
      'description_bilingual',
      'Description française et anglaise',
      'French and English description',
      this.hasText(scholarship.descriptionFr) &&
        this.hasText(scholarship.descriptionEn),
    );
    add(
      'level_bilingual',
      'Éligibilité de niveau bilingue',
      'Bilingual eligible study level',
      this.hasText(scholarship.levelEligibleFr) &&
        this.hasText(scholarship.levelEligibleEn),
    );
    add(
      'funding_known',
      'Type de financement confirmé',
      'Funding type confirmed',
      scholarship.fundingType !== 'unknown' &&
        this.hasText(scholarship.typeOfFundingFr) &&
        this.hasText(scholarship.typeOfFundingEn),
    );
    add(
      'deadline_label_bilingual',
      'Libellé de date bilingue',
      'Bilingual deadline label',
      this.hasText(scholarship.deadlineLabelFr) &&
        this.hasText(scholarship.deadlineLabelEn),
    );
    add(
      'advantages_bilingual',
      'Avantages complets dans les deux langues',
      'Complete benefits in both languages',
      this.hasBilingualList(
        scholarship.advantagesFr,
        scholarship.advantagesEn,
      ),
    );
    add(
      'eligibility_bilingual',
      'Critères d\'éligibilité complets dans les deux langues',
      'Complete eligibility criteria in both languages',
      this.hasBilingualList(
        scholarship.eligibilityFr,
        scholarship.eligibilityEn,
      ),
    );
    add(
      'requirements_bilingual',
      'Exigences principales dans les deux langues',
      'Key requirements in both languages',
      this.hasBilingualList(
        scholarship.keyRequirementsFr,
        scholarship.keyRequirementsEn,
      ),
    );
    add(
      'official_source_https',
      'Source officielle HTTPS',
      'HTTPS official source',
      this.isHttpsUrl(scholarship.sourceUrl),
    );
    add(
      'application_url_https',
      'Lien de candidature HTTPS',
      'HTTPS application link',
      this.isHttpsUrl(scholarship.applicationUrl),
    );

    const steps = scholarship.applicationSteps ?? [];
    add(
      'application_steps',
      'Au moins une étape de candidature bilingue et détaillée',
      'At least one detailed bilingual application step',
      steps.length > 0 &&
        steps.every(
          (step) =>
            step.stepNumber > 0 &&
            this.hasText(step.titleFr) &&
            this.hasText(step.titleEn) &&
            this.hasText(step.descriptionFr) &&
            this.hasText(step.descriptionEn),
        ),
    );

    const cycle =
      cycleOverride ?? this.selectPublicationCycle(scholarship.cycles ?? [], now);
    const dates = this.cycleDates(cycle);
    add(
      'application_cycle',
      'Cycle de candidature ouvert ou prévisionnel cohérent',
      'Consistent open or forecast application cycle',
      Boolean(
        cycle &&
          (cycle.status === 'open' || cycle.status === 'forecast') &&
          dates.open &&
          dates.close &&
          dates.close.getTime() > dates.open.getTime(),
      ),
    );
    add(
      'cycle_source_https',
      'Source HTTPS du cycle',
      'HTTPS cycle source',
      Boolean(cycle && this.isHttpsUrl(cycle.sourceUrl ?? scholarship.sourceUrl)),
    );
    const verifiedAt = cycle?.verifiedAt ?? scholarship.lastVerifiedAt;
    add(
      'recent_verification',
      `Vérification datant de ${VERIFICATION_MAX_AGE_DAYS} jours maximum`,
      `Verification no older than ${VERIFICATION_MAX_AGE_DAYS} days`,
      this.isRecent(verifiedAt, now),
    );

    const blockingIssues = checks.filter((check) => !check.passed);
    return {
      scholarshipId: scholarship.id,
      ready: blockingIssues.length === 0,
      score: Math.round(
        (checks.filter((check) => check.passed).length / checks.length) * 100,
      ),
      verificationMaxAgeDays: VERIFICATION_MAX_AGE_DAYS,
      checks,
      blockingIssues,
    };
  }

  private selectPublicationCycle(
    cycles: QualityCycle[],
    now: Date,
  ): QualityCycle | undefined {
    const open = cycles.find((cycle) => cycle.status === 'open');
    if (open) return open;
    const forecasts = cycles
      .filter((cycle) => cycle.status === 'forecast')
      .sort(
        (a, b) =>
          (this.cycleDates(b).open?.getTime() ?? 0) -
          (this.cycleDates(a).open?.getTime() ?? 0),
      );
    return (
      forecasts.find((cycle) => {
        const close = this.cycleDates(cycle).close;
        return close != null && close.getTime() >= now.getTime();
      }) ?? forecasts[0]
    );
  }

  private cycleDates(cycle?: QualityCycle): {
    open: Date | null;
    close: Date | null;
  } {
    if (!cycle) return { open: null, close: null };
    return cycle.status === 'open'
      ? { open: cycle.opensAt ?? null, close: cycle.closesAt ?? null }
      : {
          open: cycle.estimatedOpenAt ?? null,
          close: cycle.estimatedCloseAt ?? null,
        };
  }

  private hasText(value: string | null | undefined): boolean {
    return Boolean(value?.trim());
  }

  private hasBilingualList(fr: string[], en: string[]): boolean {
    return (
      fr.length > 0 &&
      fr.length === en.length &&
      fr.every((value) => this.hasText(value)) &&
      en.every((value) => this.hasText(value))
    );
  }

  private isHttpsUrl(value: string | null | undefined): boolean {
    if (!value) return false;
    try {
      return new URL(value).protocol === 'https:';
    } catch {
      return false;
    }
  }

  private isRecent(value: Date | null | undefined, now: Date): boolean {
    if (!value) return false;
    const age = now.getTime() - value.getTime();
    return age >= 0 && age <= VERIFICATION_MAX_AGE_DAYS * DAY_MS;
  }
}
