import type {
  ScholarshipOfficialSource,
  VerifiedScholarshipCatalogRecord,
} from './scholarship-catalog.types';

const CHECKED_AT = '2026-07-16T00:00:00.000Z';
const VERIFIED_BY = 'KPB Education official-source review';

function officialSource(
  kind: ScholarshipOfficialSource['kind'],
  url: string,
  label: string,
): ScholarshipOfficialSource {
  return {
    kind,
    url,
    isOfficial: true,
    checkedAt: CHECKED_AT,
    label,
  };
}

/**
 * Records are intentionally inactive/pending after import. Source verification
 * makes them eligible for editorial review; it never publishes them.
 */
export const VERIFIED_SCHOLARSHIP_RECORDS_V1: VerifiedScholarshipCatalogRecord[] = [
  {
    catalogId: 'uwc_burkina_faso_2027_forecast',
    levels: ['secondary'],
    scholarship: {
      id: 'uwc_burkina_faso_2027_forecast',
      nameFr: 'UWC — voie nationale Burkina Faso',
      nameEn: 'UWC — Burkina Faso national route',
      countryId: 'bfa',
      countryNameFr: 'Burkina Faso (placements UWC internationaux)',
      countryNameEn: 'Burkina Faso (international UWC placements)',
      levelEligibleFr: 'Lycée — Seconde à Terminale',
      levelEligibleEn: 'Secondary school — Seconde to Terminale equivalent',
      typeOfFundingFr: 'Aide complète ou partielle selon la place et le besoin financier',
      typeOfFundingEn: 'Full or partial aid depending on placement and financial need',
      fundingType: 'partially_funded',
      applicationRequirement: 'separate_application',
      deadlineLabelFr:
        'Prévision 2027 — environ du 1er novembre 2026 au 3 janvier 2027, à reconfirmer',
      deadlineLabelEn:
        '2027 forecast — approximately 1 November 2026 to 3 January 2027, to be reconfirmed',
      descriptionFr:
        'Sélection nationale pour une place dans un établissement UWC et le programme de deux ans du Baccalauréat International. Le financement attribué peut être complet ou partiel après évaluation du besoin financier. La fenêtre 2027 est estimée à partir du dernier cycle officiel.',
      descriptionEn:
        'National selection for a place at a UWC school and the two-year International Baccalaureate programme. Awarded funding may be full or partial after a financial-needs assessment. The 2027 window is estimated from the latest official cycle.',
      advantagesFr: [
        'Placement dans un établissement du réseau international UWC',
        'Cursus résidentiel de deux ans préparant au Baccalauréat International',
        'Aide financière complète ou partielle possible selon le placement et le besoin démontré',
      ],
      advantagesEn: [
        'Placement at a school in the international UWC network',
        'Two-year residential International Baccalaureate curriculum',
        'Possible full or partial financial aid depending on placement and demonstrated need',
      ],
      eligibilityFr: [
        'Avoir entre 16 et 18 ans au moment de l’inscription',
        'Être scolarisé en Seconde, Première ou Terminale, ou avoir récemment achevé ce niveau',
        'Être citoyen burkinabè et résident permanent au Burkina Faso selon la page officielle de la voie nationale',
        'Présenter un bon dossier scolaire et un engagement d’apprentissage au-delà de la classe',
        'Démontrer les valeurs UWC, un impact positif dans sa communauté, de la résilience et de l’adaptabilité',
        'Avoir au moins une base en anglais et la volonté de progresser ; la maîtrise courante n’est pas exigée à la candidature',
        'Ne déposer qu’une seule candidature UWC par année académique',
      ],
      eligibilityEn: [
        'Be between 16 and 18 years old at enrolment',
        'Be enrolled in Seconde, Première or Terminale equivalent, or have recently completed that stage',
        'Be a Burkinabe citizen and permanent resident in Burkina Faso according to the official national-route page',
        'Show a strong academic record and commitment to learning beyond the classroom',
        'Demonstrate UWC values, positive community impact, resilience and adaptability',
        'Have at least basic English and willingness to improve; fluency is not required when applying',
        'Submit only one UWC application per academic year',
      ],
      keyRequirementsFr: [
        'Formulaire en ligne avec informations personnelles, parcours scolaire, activités et motivations',
        'Essais ou réponses courtes',
        'Références d’enseignants, mentors ou responsables communautaires',
        'Relevés scolaires et autres justificatifs demandés',
        'Autorisation signée du parent ou tuteur légal',
        'Informations financières si la candidature est retenue pour une nomination',
      ],
      keyRequirementsEn: [
        'Online form with personal details, academic history, activities and motivations',
        'Essays or short responses',
        'References from teachers, mentors or community leaders',
        'Academic transcripts and other requested evidence',
        'Signed permission from a parent or legal guardian',
        'Financial information if shortlisted for nomination',
      ],
      relatedFieldIds: [],
      baseMatch: 80,
      applicationUrl: 'https://apply.uwc.org/',
      sourceUrl: 'https://bf.uwc.org/',
      tags: [
        'secondary',
        'uwc',
        'ib',
        'route-burkina-faso',
        'needs-based',
        'forecast',
      ],
    },
    applicationSteps: [
      {
        stepNumber: 1,
        titleFr: 'Vérifier la voie nationale',
        titleEn: 'Check the national route',
        descriptionFr:
          'Confirmer l’âge, le niveau scolaire, la citoyenneté/résidence et l’unicité de la candidature UWC.',
        descriptionEn:
          'Confirm age, school stage, citizenship/residency and that this is the only UWC application for the year.',
        estimatedDurationDays: 1,
      },
      {
        stepNumber: 2,
        titleFr: 'Préparer le dossier',
        titleEn: 'Prepare the application',
        descriptionFr:
          'Rassembler les relevés, les références, les essais, les justificatifs et l’autorisation parentale.',
        descriptionEn:
          'Gather transcripts, references, essays, supporting evidence and parental permission.',
        estimatedDurationDays: 21,
      },
      {
        stepNumber: 3,
        titleFr: 'Déposer en ligne',
        titleEn: 'Submit online',
        descriptionFr:
          'Créer son dossier sur la plateforme UWC et attendre la confirmation officielle des dates avant de le soumettre.',
        descriptionEn:
          'Create the application on the UWC platform and wait for official date confirmation before submitting.',
        estimatedDurationDays: 1,
      },
      {
        stepNumber: 4,
        titleFr: 'Participer à la sélection',
        titleEn: 'Complete selection',
        descriptionFr:
          'Si présélectionné, participer à l’entretien puis transmettre les informations financières demandées pour la nomination.',
        descriptionEn:
          'If shortlisted, attend the interview and then provide the financial information requested for nomination.',
        estimatedDurationDays: 45,
      },
    ],
    cycle: {
      academicYear: '2027-2028',
      status: 'forecast',
      dateConfidence: 'estimated',
      estimatedOpenAt: '2026-11-01T00:00:00.000Z',
      estimatedCloseAt: '2027-01-03T23:59:59.000Z',
      sourceUrl: 'https://bf.uwc.org/how-to-apply/',
    },
    officialSources: [
      officialSource('overview', 'https://bf.uwc.org/', 'UWC Burkina Faso — official home page'),
      officialSource(
        'eligibility',
        'https://bf.uwc.org/eligibility-criteria/',
        'UWC Burkina Faso — official eligibility criteria',
      ),
      officialSource(
        'benefits',
        'https://bf.uwc.org/how-to-apply/',
        'UWC Burkina Faso — official nomination and funding description',
      ),
      officialSource('application', 'https://apply.uwc.org/', 'UWC official application platform'),
      officialSource(
        'cycle',
        'https://bf.uwc.org/how-to-apply/',
        'UWC Burkina Faso — confirmed 2026 application dates',
      ),
    ],
    verifiedAt: CHECKED_AT,
    verifiedBy: VERIFIED_BY,
  },
  {
    catalogId: 'uwc_kenya_entry_2027',
    levels: ['secondary'],
    scholarship: {
      id: 'uwc_kenya_entry_2027',
      nameFr: 'UWC — voie nationale Kenya',
      nameEn: 'UWC — Kenya national route',
      countryId: 'ken',
      countryNameFr: 'Kenya (placements UWC internationaux)',
      countryNameEn: 'Kenya (international UWC placements)',
      levelEligibleFr: 'Fin du secondaire — entrée UWC 2027',
      levelEligibleEn: 'Final secondary stage — UWC entry 2027',
      typeOfFundingFr: 'Aide complète ou partielle selon la place et le besoin financier',
      typeOfFundingEn: 'Full or partial aid depending on placement and financial need',
      fundingType: 'partially_funded',
      applicationRequirement: 'separate_application',
      deadlineLabelFr: 'Ouvert — clôture le 31 décembre 2026',
      deadlineLabelEn: 'Open — closes 31 December 2026',
      descriptionFr:
        'Voie de sélection du comité national UWC Kenya pour une entrée en 2027 dans un établissement UWC. Une nomination peut être entièrement ou partiellement financée selon le besoin démontré.',
      descriptionEn:
        'UWC Kenya national committee selection route for 2027 entry at a UWC school. A nomination may be fully or partially funded according to demonstrated need.',
      advantagesFr: [
        'Placement dans un établissement du réseau international UWC',
        'Cursus UWC de deux ans centré sur le Baccalauréat International',
        'Aide financière complète ou partielle possible après évaluation du besoin',
      ],
      advantagesEn: [
        'Placement at a school in the international UWC network',
        'Two-year UWC curriculum centred on the International Baccalaureate',
        'Possible full or partial financial aid following needs assessment',
      ],
      eligibilityFr: [
        'Avoir entre 16 et 19 ans durant l’année d’entrée ; toute personne ayant 19 ans en 2027 doit les avoir après le 1er septembre 2027',
        'Être citoyen ou résident du Kenya, y compris avec une double nationalité',
        'Pour les résidents au Kenya, étudier et achever actuellement le secondaire dans le pays',
        'Atteindre avant décembre 2026 le niveau officiel correspondant à son cursus : Form 4, Grade 12, IGCSE Year 11, American Grade 10, MYP 5, German Grade 10 ou équivalent homeschool',
        'Démontrer les valeurs UWC, notamment intégrité, service, respect, responsabilité, ouverture interculturelle et action personnelle',
        'Avoir une base en anglais et la volonté de progresser ; la maîtrise courante n’est pas exigée à la candidature',
        'Ne déposer qu’une seule candidature UWC par année académique',
      ],
      eligibilityEn: [
        'Be between 16 and 19 in the entry year; applicants turning 19 in 2027 must do so after 1 September 2027',
        'Hold Kenyan citizenship or residency, including dual citizenship',
        'Kenyan residents must be studying and currently completing secondary school in Kenya',
        'Reach by December 2026 the published stage for the relevant curriculum: Form 4, Grade 12, IGCSE Year 11, American Grade 10, MYP 5, German Grade 10 or homeschool equivalent',
        'Demonstrate UWC values including integrity, service, respect, responsibility, intercultural openness and personal action',
        'Have basic English and willingness to improve; fluency is not required when applying',
        'Submit only one UWC application per academic year',
      ],
      keyRequirementsFr: [
        'Résumé officiel des notes 2025 et 2026, signé ou tamponné par l’établissement, une page maximum par année',
        'Deux lettres de recommandation : une co-curriculaire et une académique',
        'Certificats de réussite, leadership ou distinctions pertinents, si disponibles',
        'Un seul fichier PDF regroupant les pièces demandées',
        'Présence physique à Nairobi pour la journée de sélection en cas de présélection',
        'Frais de journée d’entretien de 3 000 KES, avec exonération possible au cas par cas',
        'Informations financières pour déterminer l’aide en cas de nomination',
      ],
      keyRequirementsEn: [
        'Official signed or stamped one-page transcript summary for each of 2025 and 2026',
        'Two recommendation letters: one co-curricular and one academic',
        'Relevant achievement, leadership or award certificates, if available',
        'One combined PDF containing the requested documents',
        'Physical attendance in Nairobi for selection day if shortlisted',
        'KES 3,000 interview-day fee, with case-by-case fee waivers',
        'Financial information to determine aid if nominated',
      ],
      relatedFieldIds: [],
      baseMatch: 80,
      applicationUrl: 'https://ke.uwc.org/how-to-apply/',
      sourceUrl: 'https://ke.uwc.org/',
      tags: ['secondary', 'uwc', 'ib', 'route-kenya', 'needs-based', 'open'],
    },
    applicationSteps: [
      {
        stepNumber: 1,
        titleFr: 'Vérifier le cursus et l’âge',
        titleEn: 'Check curriculum and age',
        descriptionFr:
          'Comparer son âge et son niveau prévu en décembre 2026 aux équivalences publiées par UWC Kenya.',
        descriptionEn:
          'Compare age and expected December 2026 school stage with the equivalents published by UWC Kenya.',
        estimatedDurationDays: 1,
      },
      {
        stepNumber: 2,
        titleFr: 'Constituer le PDF',
        titleEn: 'Build the PDF file',
        descriptionFr:
          'Obtenir les relevés résumés et les deux recommandations, ajouter les certificats éventuels, puis fusionner les pièces en un PDF.',
        descriptionEn:
          'Obtain transcript summaries and both recommendations, add any certificates, then merge the documents into one PDF.',
        estimatedDurationDays: 21,
      },
      {
        stepNumber: 3,
        titleFr: 'Envoyer le dossier',
        titleEn: 'Submit the application',
        descriptionFr:
          'Suivre la procédure et l’adresse de dépôt indiquées sur la page officielle avant le 31 décembre 2026.',
        descriptionEn:
          'Follow the submission procedure and address on the official page before 31 December 2026.',
        estimatedDurationDays: 1,
      },
      {
        stepNumber: 4,
        titleFr: 'Préparer la sélection à Nairobi',
        titleEn: 'Prepare for Nairobi selection',
        descriptionFr:
          'En cas de présélection, préparer les activités de groupe, l’entretien, une présentation éventuelle et l’évaluation financière.',
        descriptionEn:
          'If shortlisted, prepare for group activities, interview, a possible project presentation and financial assessment.',
        estimatedDurationDays: 31,
      },
    ],
    cycle: {
      academicYear: '2027-2028',
      status: 'open',
      dateConfidence: 'confirmed',
      opensAt: '2026-07-01T00:00:00.000Z',
      closesAt: '2026-12-31T23:59:59.000Z',
      sourceUrl: 'https://ke.uwc.org/how-to-apply/',
    },
    officialSources: [
      officialSource('overview', 'https://ke.uwc.org/', 'UWC Kenya — official home page'),
      officialSource(
        'eligibility',
        'https://ke.uwc.org/eligibility-criteria/',
        'UWC Kenya — official entry 2027 eligibility criteria',
      ),
      officialSource(
        'benefits',
        'https://ke.uwc.org/how-to-apply/',
        'UWC Kenya — official nomination and needs-based funding description',
      ),
      officialSource(
        'application',
        'https://ke.uwc.org/how-to-apply/',
        'UWC Kenya — official application instructions',
      ),
      officialSource(
        'cycle',
        'https://ke.uwc.org/how-to-apply/',
        'UWC Kenya — confirmed entry 2027 application dates',
      ),
    ],
    verifiedAt: CHECKED_AT,
    verifiedBy: VERIFIED_BY,
  },
  {
    catalogId: 'uwc_tanzania_2027_forecast',
    levels: ['secondary'],
    scholarship: {
      id: 'uwc_tanzania_2027_forecast',
      nameFr: 'UWC — voie nationale Tanzanie',
      nameEn: 'UWC — Tanzania national route',
      countryId: 'tza',
      countryNameFr: 'Tanzanie (placements UWC internationaux)',
      countryNameEn: 'Tanzania (international UWC placements)',
      levelEligibleFr: 'Fin du secondaire — Form Four ou équivalent',
      levelEligibleEn: 'Final secondary stage — Form Four or equivalent',
      typeOfFundingFr: 'Aide complète ou partielle selon la place et le besoin financier',
      typeOfFundingEn: 'Full or partial aid depending on placement and financial need',
      fundingType: 'partially_funded',
      applicationRequirement: 'separate_application',
      deadlineLabelFr:
        'Prévision 2027 — environ du 8 décembre 2026 au 16 janvier 2027, à reconfirmer',
      deadlineLabelEn:
        '2027 forecast — approximately 8 December 2026 to 16 January 2027, to be reconfirmed',
      descriptionFr:
        'Sélection du comité national UWC Tanzanie pour un placement dans le réseau UWC. La nomination peut être entièrement ou partiellement financée après évaluation du besoin. La fenêtre 2027 est estimée à partir du dernier cycle officiel.',
      descriptionEn:
        'Tanzania UWC national committee selection for a placement in the UWC network. A nomination may be fully or partially funded following a needs assessment. The 2027 window is estimated from the latest official cycle.',
      advantagesFr: [
        'Placement dans un établissement du réseau international UWC',
        'Cursus résidentiel de deux ans préparant au Baccalauréat International',
        'Aide complète ou partielle possible selon la place et le besoin démontré',
      ],
      advantagesEn: [
        'Placement at a school in the international UWC network',
        'Two-year residential International Baccalaureate curriculum',
        'Possible full or partial aid depending on placement and demonstrated need',
      ],
      eligibilityFr: [
        'Avoir entre 16 et 18 ans au moment de l’inscription',
        'Avoir terminé le Form Four CSEE ou prévoir de terminer IGCSE/GCSE ou MYP',
        'Être citoyen tanzanien ou résident permanent en Tanzanie',
        'Pouvoir participer physiquement à tous les entretiens et évaluations financières à Dar es Salaam en cas de sélection',
        'Présenter un bon dossier scolaire et un engagement d’apprentissage au-delà de la classe',
        'Démontrer les valeurs UWC, un impact communautaire positif, de la résilience et de l’adaptabilité',
        'Avoir une base en anglais et la volonté de progresser ; la maîtrise courante n’est pas exigée à la candidature',
        'Ne déposer qu’une seule candidature UWC par année académique',
      ],
      eligibilityEn: [
        'Be between 16 and 18 years old at enrolment',
        'Have completed Form Four CSEE or expect to complete IGCSE/GCSE or MYP',
        'Be a Tanzanian citizen or permanent resident in Tanzania',
        'Be able to attend all interviews and financial assessments physically in Dar es Salaam if selected',
        'Show a strong academic record and commitment to learning beyond the classroom',
        'Demonstrate UWC values, positive community impact, resilience and adaptability',
        'Have basic English and willingness to improve; fluency is not required when applying',
        'Submit only one UWC application per academic year',
      ],
      keyRequirementsFr: [
        'Formulaire en ligne avec informations personnelles, parcours, activités et motivations',
        'Essais ou réponses courtes',
        'Références d’enseignants, mentors ou responsables communautaires',
        'Relevés scolaires et autres justificatifs demandés',
        'Autorisation signée du parent ou tuteur légal',
        'Présence à Dar es Salaam pour la sélection en cas de présélection',
        'Informations financières pour l’évaluation du besoin',
      ],
      keyRequirementsEn: [
        'Online form with personal details, academic history, activities and motivations',
        'Essays or short responses',
        'References from teachers, mentors or community leaders',
        'Academic transcripts and other requested evidence',
        'Signed permission from a parent or legal guardian',
        'Attendance in Dar es Salaam for selection if shortlisted',
        'Financial information for needs assessment',
      ],
      relatedFieldIds: [],
      baseMatch: 80,
      applicationUrl: 'https://tz.uwc.org/how-to-apply/',
      sourceUrl: 'https://tz.uwc.org/',
      tags: [
        'secondary',
        'uwc',
        'ib',
        'route-tanzania',
        'needs-based',
        'forecast',
      ],
    },
    applicationSteps: [
      {
        stepNumber: 1,
        titleFr: 'Vérifier son admissibilité',
        titleEn: 'Check eligibility',
        descriptionFr:
          'Confirmer l’âge, le niveau scolaire, la citoyenneté ou résidence et la disponibilité pour la sélection à Dar es Salaam.',
        descriptionEn:
          'Confirm age, school stage, citizenship or residency and availability for selection in Dar es Salaam.',
        estimatedDurationDays: 1,
      },
      {
        stepNumber: 2,
        titleFr: 'Préparer les pièces',
        titleEn: 'Prepare documents',
        descriptionFr:
          'Rassembler les relevés, références, essais, justificatifs et l’autorisation parentale.',
        descriptionEn:
          'Gather transcripts, references, essays, supporting evidence and parental permission.',
        estimatedDurationDays: 21,
      },
      {
        stepNumber: 3,
        titleFr: 'Soumettre la candidature',
        titleEn: 'Submit the application',
        descriptionFr:
          'Utiliser le lien de formulaire publié sur la page officielle du comité national avant la date limite.',
        descriptionEn:
          'Use the form link published on the national committee’s official page before the deadline.',
        estimatedDurationDays: 1,
      },
      {
        stepNumber: 4,
        titleFr: 'Passer la sélection',
        titleEn: 'Complete selection',
        descriptionFr:
          'En cas de présélection, participer aux évaluations, activités de groupe, entretien et évaluation financière à Dar es Salaam.',
        descriptionEn:
          'If shortlisted, attend assessments, group activities, interview and financial assessment in Dar es Salaam.',
        estimatedDurationDays: 42,
      },
    ],
    cycle: {
      academicYear: '2027-2028',
      status: 'forecast',
      dateConfidence: 'estimated',
      estimatedOpenAt: '2026-12-08T00:00:00.000Z',
      estimatedCloseAt: '2027-01-16T23:59:59.000Z',
      sourceUrl: 'https://tz.uwc.org/how-to-apply/',
    },
    officialSources: [
      officialSource('overview', 'https://tz.uwc.org/', 'Tanzania UWC National Committee — official home page'),
      officialSource(
        'eligibility',
        'https://tz.uwc.org/eligibility-criteria/',
        'Tanzania UWC National Committee — official eligibility criteria',
      ),
      officialSource(
        'benefits',
        'https://tz.uwc.org/how-to-apply/',
        'Tanzania UWC National Committee — nomination and funding description',
      ),
      officialSource(
        'application',
        'https://tz.uwc.org/how-to-apply/',
        'Tanzania UWC National Committee — official application instructions',
      ),
      officialSource(
        'cycle',
        'https://tz.uwc.org/how-to-apply/',
        'Tanzania UWC National Committee — confirmed 2026 application dates',
      ),
    ],
    verifiedAt: CHECKED_AT,
    verifiedBy: VERIFIED_BY,
  },
];
