export type AiTokenUsage = {
  inputTokens: number;
  cachedInputTokens?: number;
  outputTokens: number;
};

export type AiModelRates = {
  inputMicrosUsdPerMillion: bigint;
  cachedInputMicrosUsdPerMillion?: bigint | null;
  outputMicrosUsdPerMillion: bigint;
};

const TOKENS_PER_MILLION = 1_000_000n;

function nonNegativeInteger(value: number | undefined): number {
  return Number.isSafeInteger(value) && (value ?? -1) >= 0 ? (value ?? 0) : 0;
}

function ceilDivide(numerator: bigint, denominator: bigint): bigint {
  if (numerator <= 0n) return 0n;
  return (numerator + denominator - 1n) / denominator;
}

/**
 * Estimates provider cost in the canonical ledger unit (micro USD).
 * Cached input is never charged twice: it is removed from regular input and
 * charged at its own configured rate, or the regular rate when no cache rate
 * was published for the selected price version.
 */
export function estimateAiCostMicrosUsd(
  usage: AiTokenUsage,
  rates: AiModelRates,
): bigint {
  const inputTokens = nonNegativeInteger(usage.inputTokens);
  const cachedTokens = Math.min(
    inputTokens,
    nonNegativeInteger(usage.cachedInputTokens),
  );
  const uncachedTokens = inputTokens - cachedTokens;
  const outputTokens = nonNegativeInteger(usage.outputTokens);
  const cachedRate =
    rates.cachedInputMicrosUsdPerMillion ?? rates.inputMicrosUsdPerMillion;
  const numerator =
    BigInt(uncachedTokens) * rates.inputMicrosUsdPerMillion +
    BigInt(cachedTokens) * cachedRate +
    BigInt(outputTokens) * rates.outputMicrosUsdPerMillion;

  return ceilDivide(numerator, TOKENS_PER_MILLION);
}

export function parseMicrosUsd(value: string | undefined): bigint | null {
  const normalized = value?.trim();
  if (!normalized || !/^\d+$/.test(normalized)) return null;
  const parsed = BigInt(normalized);
  return parsed > 0n ? parsed : null;
}
