import { createHash } from 'node:crypto';

export type DiagnosticLanguage = 'fr' | 'en';

export type SuccessLabDiagnosticOutput = {
  strength: string;
  priorityImprovement: string;
  rationale: string;
  nextAction: string;
  criterionReferences: string[];
};

export type DiagnosticCriterion = {
  code: string;
  label: string;
};

export type DiagnosticStep = {
  code: string;
  title: string;
  status: 'not_started' | 'in_progress' | 'completed' | 'not_applicable';
  isRequired: boolean;
};

const OUTPUT_LIMITS = {
  strength: 280,
  priorityImprovement: 360,
  rationale: 480,
  nextAction: 280,
} as const;

const UNSAFE_CLAIMS = [
  /(?:chance|chances|probabilit[eé]|pourcentage)\s+(?:d['’ ]?|of\s+)?(?:admission|acceptation)/i,
  /\b\d{1,3}\s*%\s+(?:de\s+)?chances?\b/i,
  /\badmission\s+(?:est\s+)?(?:garantie|assur[eé]e|certaine)/i,
  /\b(?:ton|votre)\s+admission\s+est\s+(?:garantie|assur[eé]e|certaine)/i,
  /\btu\s+seras\s+admis(?:e)?\b/i,
  /\badmis(?:e)?\s+à\s+coup\s+sûr\b/i,
  /\b(?:admission|acceptance)\s+(?:is\s+)?(?:guaranteed|assured|certain)/i,
  /\b(?:guaranteed|assured|certain)\s+(?:admission|acceptance)/i,
  /\b(?:chance|probability|likelihood)\s+(?:of\s+)?(?:admission|acceptance)/i,
  /\b(?:admission|acceptance)\s+(?:chance|probability|likelihood)/i,
  /\byou\s+will\s+be\s+(?:admitted|accepted)\b/i,
] as const;

function hasUnsafeClaim(value: string): boolean {
  return UNSAFE_CLAIMS.some((pattern) => pattern.test(value));
}

function escapeRegExp(value: string): string {
  return value.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}

export function redactDiagnosticInput(
  input: string,
  forbiddenValues: readonly string[] = [],
  maxChars = 8000,
): string {
  let redacted = input
    .replace(/[\u0000-\u0008\u000b\u000c\u000e-\u001f\u007f]/g, ' ')
    .replace(/\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}\b/gi, '[email]')
    .replace(/https?:\/\/\S+|www\.\S+/gi, '[url]')
    .replace(/(?:\+?\d[\s().-]*){8,}/g, '[telephone]');

  for (const raw of forbiddenValues) {
    const value = raw.trim();
    if (value.length < 3) continue;
    redacted = redacted.replace(
      new RegExp(escapeRegExp(value), 'gi'),
      '[identite]',
    );
  }

  return redacted
    .replace(/[ \t]+/g, ' ')
    .trim()
    .slice(0, maxChars);
}

export function buildDeterministicDiagnostic(input: {
  language: DiagnosticLanguage;
  steps: readonly DiagnosticStep[];
  criteria: readonly DiagnosticCriterion[];
}): SuccessLabDiagnosticOutput {
  const completed = input.steps.filter((step) => step.status === 'completed');
  const priority = input.steps.find(
    (step) =>
      step.isRequired &&
      step.status !== 'completed' &&
      step.status !== 'not_applicable',
  );
  const criterion = input.criteria[0];
  const en = input.language === 'en';

  if (!priority) {
    return {
      strength: en
        ? 'Your required preparation steps are complete.'
        : 'Tes étapes de préparation obligatoires sont complètes.',
      priorityImprovement: en
        ? 'Review the full application once before submission.'
        : 'Relis une dernière fois l’ensemble de ta candidature avant l’envoi.',
      rationale: criterion
        ? en
          ? `A final review should confirm that your evidence addresses “${criterion.label}”.`
          : `La relecture finale doit confirmer que tes preuves répondent à « ${criterion.label} ».`
        : en
          ? 'A final consistency check reduces avoidable omissions.'
          : 'Une vérification finale de cohérence réduit les oublis évitables.',
      nextAction: en
        ? 'Open your application checklist and perform one final review.'
        : 'Ouvre ta checklist et effectue une dernière relecture.',
      criterionReferences: criterion ? [criterion.code] : [],
    };
  }

  return {
    strength:
      completed.length > 0
        ? en
          ? `You have already completed ${completed.length} preparation step${completed.length === 1 ? '' : 's'}.`
          : `Tu as déjà complété ${completed.length} étape${completed.length === 1 ? '' : 's'} de préparation.`
        : en
          ? 'Your application workspace is created and ready to be completed.'
          : 'Ton atelier de candidature est créé et prêt à être complété.',
    priorityImprovement: en
      ? `Complete “${priority.title}” before working on secondary details.`
      : `Termine « ${priority.title} » avant de travailler les détails secondaires.`,
    rationale: criterion
      ? en
        ? `This is the clearest next step for demonstrating “${criterion.label}”.`
        : `C’est la prochaine étape la plus claire pour démontrer « ${criterion.label} ».`
      : en
        ? 'This required step currently blocks a complete application review.'
        : 'Cette étape obligatoire empêche actuellement une relecture complète du dossier.',
    nextAction: en
      ? `Open “${priority.title}” and add one verifiable piece of evidence.`
      : `Ouvre « ${priority.title} » et ajoute une preuve vérifiable.`,
    criterionReferences: criterion ? [criterion.code] : [],
  };
}

export function isSuccessLabDiagnosticOutput(
  value: unknown,
  allowedCriterionCodes: ReadonlySet<string>,
): value is SuccessLabDiagnosticOutput {
  if (!value || typeof value !== 'object' || Array.isArray(value)) return false;
  const record = value as Record<string, unknown>;
  const expectedKeys = [
    'strength',
    'priorityImprovement',
    'rationale',
    'nextAction',
    'criterionReferences',
  ];
  if (
    Object.keys(record).length !== expectedKeys.length ||
    expectedKeys.some((key) => !(key in record))
  ) {
    return false;
  }

  for (const key of [
    'strength',
    'priorityImprovement',
    'rationale',
    'nextAction',
  ] as const) {
    const text = record[key];
    if (
      typeof text !== 'string' ||
      text.trim().length < 8 ||
      text.length > OUTPUT_LIMITS[key] ||
      hasUnsafeClaim(text)
    ) {
      return false;
    }
  }

  return (
    Array.isArray(record.criterionReferences) &&
    record.criterionReferences.length <= 3 &&
    record.criterionReferences.every(
      (code) => typeof code === 'string' && allowedCriterionCodes.has(code),
    )
  );
}

export function diagnosticInputFingerprint(input: {
  promptVersion: string;
  language: DiagnosticLanguage;
  workspaceVersion: number;
  criteriaVersion: string;
  artifactSha256?: string | null;
}): string {
  return createHash('sha256')
    .update(
      JSON.stringify({
        promptVersion: input.promptVersion,
        language: input.language,
        workspaceVersion: input.workspaceVersion,
        criteriaVersion: input.criteriaVersion,
        artifactSha256: input.artifactSha256 ?? null,
      }),
    )
    .digest('hex');
}

export const SUCCESS_LAB_DIAGNOSTIC_SCHEMA = {
  type: 'object',
  properties: {
    strength: { type: 'string', maxLength: OUTPUT_LIMITS.strength },
    priorityImprovement: {
      type: 'string',
      maxLength: OUTPUT_LIMITS.priorityImprovement,
    },
    rationale: { type: 'string', maxLength: OUTPUT_LIMITS.rationale },
    nextAction: { type: 'string', maxLength: OUTPUT_LIMITS.nextAction },
    criterionReferences: {
      type: 'array',
      maxItems: 3,
      items: { type: 'string' },
    },
  },
  required: [
    'strength',
    'priorityImprovement',
    'rationale',
    'nextAction',
    'criterionReferences',
  ],
  additionalProperties: false,
} as const;
