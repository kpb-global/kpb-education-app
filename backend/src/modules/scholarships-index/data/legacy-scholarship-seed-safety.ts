type LegacyLocalized = { fr?: unknown; en?: unknown };

export interface LegacyScholarshipSeedAssessment {
  complete: boolean;
  missing: string[];
}

function nonBlank(value: unknown): boolean {
  return typeof value === 'string' && value.trim().length > 0;
}

function localized(value: unknown): value is LegacyLocalized {
  return value != null && typeof value === 'object';
}

function completeLocalized(value: unknown): boolean {
  return localized(value) && nonBlank(value.fr) && nonBlank(value.en);
}

function completeLocalizedList(value: unknown): boolean {
  return (
    Array.isArray(value) &&
    value.length > 0 &&
    value.every((item) => completeLocalized(item))
  );
}

function https(value: unknown): boolean {
  if (!nonBlank(value)) return false;
  try {
    return new URL(value as string).protocol === 'https:';
  } catch {
    return false;
  }
}

/**
 * This is intentionally a structural check, not an official verification.
 * Even a structurally complete legacy row remains inactive/pending when first
 * created by the general Prisma seed.
 */
export function assessLegacyScholarshipSeed(
  scholarship: Record<string, unknown>,
): LegacyScholarshipSeedAssessment {
  const checks: Array<[string, boolean]> = [
    ['name.fr/en', completeLocalized(scholarship.name)],
    ['countryId', nonBlank(scholarship.countryId)],
    ['countryName.fr/en', completeLocalized(scholarship.countryName)],
    ['levelEligible.fr/en', completeLocalized(scholarship.levelEligible)],
    ['typeOfFunding.fr/en', completeLocalized(scholarship.typeOfFunding)],
    ['deadlineLabel.fr/en', completeLocalized(scholarship.deadlineLabel)],
    ['description.fr/en', completeLocalized(scholarship.description)],
    ['advantages.fr/en', completeLocalizedList(scholarship.advantages)],
    ['eligibility.fr/en', completeLocalizedList(scholarship.eligibility)],
    ['keyRequirements.fr/en', completeLocalizedList(scholarship.keyRequirements)],
    ['applicationUrl.https', https(scholarship.applicationUrl)],
    ['sourceUrl.https', https(scholarship.sourceUrl)],
  ];
  const missing = checks.filter(([, ok]) => !ok).map(([field]) => field);
  return { complete: missing.length === 0, missing };
}
