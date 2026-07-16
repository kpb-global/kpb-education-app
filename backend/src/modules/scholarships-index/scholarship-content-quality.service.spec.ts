import { PrismaService } from '../prisma/prisma.service';
import {
  ScholarshipContentQualityService,
  ScholarshipQualitySnapshot,
} from './scholarship-content-quality.service';

describe('ScholarshipContentQualityService', () => {
  const now = new Date('2026-07-16T12:00:00.000Z');

  const complete: ScholarshipQualitySnapshot = {
    id: 'sch-1',
    nameFr: 'Bourse Test',
    nameEn: 'Test Scholarship',
    countryId: 'gb',
    countryNameFr: 'Royaume-Uni',
    countryNameEn: 'United Kingdom',
    levelEligibleFr: 'Master',
    levelEligibleEn: 'Master',
    typeOfFundingFr: 'Financement complet',
    typeOfFundingEn: 'Fully funded',
    fundingType: 'fully_funded',
    deadlineLabelFr: 'Clôture en novembre',
    deadlineLabelEn: 'Closes in November',
    descriptionFr: 'Une description complète.',
    descriptionEn: 'A complete description.',
    advantagesFr: ['Frais de scolarité'],
    advantagesEn: ['Tuition fees'],
    eligibilityFr: ['Licence obtenue'],
    eligibilityEn: ["Bachelor's degree"],
    keyRequirementsFr: ['Deux recommandations'],
    keyRequirementsEn: ['Two references'],
    applicationUrl: 'https://apply.example.org',
    sourceUrl: 'https://official.example.org',
    lastVerifiedAt: now,
    applicationSteps: [
      {
        stepNumber: 1,
        titleFr: 'Créer un compte',
        titleEn: 'Create an account',
        descriptionFr: 'Ouvrir le portail officiel.',
        descriptionEn: 'Open the official portal.',
      },
    ],
    cycles: [
      {
        academicYear: '2026-2027',
        status: 'forecast',
        estimatedOpenAt: new Date('2026-08-01T00:00:00.000Z'),
        estimatedCloseAt: new Date('2026-11-01T00:00:00.000Z'),
        sourceUrl: 'https://official.example.org/dates',
        verifiedAt: now,
      },
    ],
  };

  function service() {
    return new ScholarshipContentQualityService({} as PrismaService);
  }

  it('accepts a complete bilingual scholarship with a verified cycle', () => {
    const report = service().evaluate(complete, undefined, now);

    expect(report.ready).toBe(true);
    expect(report.score).toBe(100);
    expect(report.blockingIssues).toEqual([]);
  });

  it('reports every publication blocker instead of only the first one', () => {
    const report = service().evaluate(
      {
        ...complete,
        advantagesEn: [],
        applicationUrl: 'http://apply.example.org',
        applicationSteps: [],
        cycles: [],
      },
      undefined,
      now,
    );

    expect(report.ready).toBe(false);
    expect(report.blockingIssues.map((issue) => issue.code)).toEqual(
      expect.arrayContaining([
        'advantages_bilingual',
        'application_url_https',
        'application_steps',
        'application_cycle',
        'cycle_source_https',
      ]),
    );
  });

  it('rejects content whose verification is older than 30 days', () => {
    const report = service().evaluate(
      {
        ...complete,
        cycles: [
          {
            ...complete.cycles[0],
            verifiedAt: new Date('2026-06-01T00:00:00.000Z'),
          },
        ],
      },
      undefined,
      now,
    );

    expect(report.blockingIssues.map((issue) => issue.code)).toContain(
      'recent_verification',
    );
  });

  it('can validate the confirmed dates supplied during activation', () => {
    const report = service().evaluate(
      { ...complete, cycles: [] },
      {
        academicYear: '2026-2027',
        status: 'open',
        opensAt: new Date('2026-08-01T00:00:00.000Z'),
        closesAt: new Date('2026-11-01T00:00:00.000Z'),
        sourceUrl: 'https://official.example.org/current-cycle',
        verifiedAt: now,
      },
      now,
    );

    expect(report.ready).toBe(true);
  });
});
