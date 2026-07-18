import type { ProgressStep } from './workspace-progress.service';
import { WorkspaceProgressService } from './workspace-progress.service';

describe('WorkspaceProgressService', () => {
  const service = new WorkspaceProgressService();

  function step(
    code: string,
    weight: number,
    status: ProgressStep['status'],
  ): ProgressStep {
    return {
      id: code,
      code,
      titleFr: code,
      titleEn: code,
      weight,
      status,
    };
  }

  it('calculates deterministic weighted readiness and next action', () => {
    const result = service.calculate([
      step('profile', 20, 'completed'),
      step('documents', 40, 'in_progress'),
      step('form', 25, 'not_started'),
      step('review', 15, 'not_started'),
    ]);

    expect(result.readinessPercent).toBe(20);
    expect(result.nextAction?.code).toBe('documents');
  });

  it('removes a justified non-applicable step from the denominator', () => {
    const result = service.calculate([
      step('profile', 20, 'completed'),
      step('documents', 40, 'not_applicable'),
      step('form', 25, 'completed'),
      step('review', 15, 'completed'),
    ]);

    expect(result.readinessPercent).toBe(100);
    expect(result.nextAction).toBeNull();
  });

  it('never advances submitted or decision states from checklist changes', () => {
    expect(service.deriveStatus('submitted', 20, true)).toBe('submitted');
    expect(service.deriveStatus('decision_received', 100, true)).toBe(
      'decision_received',
    );
  });
});
