import {
  ValidatorConstraint,
  type ValidatorConstraintInterface,
} from 'class-validator';

export const MINIMUM_ACCOUNT_AGE = 16;

/** Calendar-age check used by both HTTP validation and the service boundary. */
export function isAtLeastAge(
  value: string | Date,
  minimumAge = MINIMUM_ACCOUNT_AGE,
  now = new Date(),
): boolean {
  const birthDate = value instanceof Date ? new Date(value) : new Date(value);
  if (Number.isNaN(birthDate.getTime()) || birthDate.getTime() > now.getTime()) {
    return false;
  }

  const threshold = new Date(now);
  threshold.setUTCFullYear(threshold.getUTCFullYear() - minimumAge);
  return birthDate.getTime() <= threshold.getTime();
}

@ValidatorConstraint({ name: 'minimumAccountAge', async: false })
export class MinimumAccountAgeConstraint
  implements ValidatorConstraintInterface
{
  validate(value: unknown): boolean {
    return (
      (typeof value === 'string' || value instanceof Date) &&
      isAtLeastAge(value)
    );
  }

  defaultMessage(): string {
    return `birthDate must show an age of at least ${MINIMUM_ACCOUNT_AGE}.`;
  }
}
