import { estimateAiCostMicrosUsd, parseMicrosUsd } from './ai-cost.policy';

describe('AI diagnostic cost policy', () => {
  it('prices uncached input, cached input and output without double counting', () => {
    expect(
      estimateAiCostMicrosUsd(
        { inputTokens: 1000, cachedInputTokens: 400, outputTokens: 200 },
        {
          inputMicrosUsdPerMillion: 1_000_000n,
          cachedInputMicrosUsdPerMillion: 100_000n,
          outputMicrosUsdPerMillion: 2_000_000n,
        },
      ),
    ).toBe(1040n);
  });

  it('rounds fractional micro USD upward for a conservative ledger', () => {
    expect(
      estimateAiCostMicrosUsd(
        { inputTokens: 1, outputTokens: 0 },
        {
          inputMicrosUsdPerMillion: 1n,
          outputMicrosUsdPerMillion: 1n,
        },
      ),
    ).toBe(1n);
  });

  it('bounds invalid and oversized cached usage', () => {
    expect(
      estimateAiCostMicrosUsd(
        { inputTokens: 10, cachedInputTokens: 50, outputTokens: -2 },
        {
          inputMicrosUsdPerMillion: 1_000_000n,
          cachedInputMicrosUsdPerMillion: 0n,
          outputMicrosUsdPerMillion: 1_000_000n,
        },
      ),
    ).toBe(0n);
  });

  it('parses only strictly positive integer micro USD values', () => {
    expect(parseMicrosUsd('25000')).toBe(25000n);
    expect(parseMicrosUsd('0')).toBeNull();
    expect(parseMicrosUsd('-1')).toBeNull();
    expect(parseMicrosUsd('1.5')).toBeNull();
    expect(parseMicrosUsd(undefined)).toBeNull();
  });
});
