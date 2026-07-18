import { Injectable } from '@nestjs/common';
import type {
  ScholarshipWorkspaceStatus,
  WorkspaceStepStatus,
} from '@prisma/client';

export type ProgressStep = {
  id: string;
  code: string;
  titleFr: string;
  titleEn: string;
  weight: number;
  status: WorkspaceStepStatus;
};

export type WorkspaceProgress = {
  readinessPercent: number;
  nextAction: {
    stepId: string;
    code: string;
    labelFr: string;
    labelEn: string;
  } | null;
};

@Injectable()
export class WorkspaceProgressService {
  calculate(steps: ProgressStep[]): WorkspaceProgress {
    const applicable = steps.filter(
      (step) => step.status !== 'not_applicable' && step.weight > 0,
    );
    const totalWeight = applicable.reduce((sum, step) => sum + step.weight, 0);
    const completedWeight = applicable.reduce(
      (sum, step) => sum + (step.status === 'completed' ? step.weight : 0),
      0,
    );
    const readinessPercent =
      totalWeight === 0
        ? 0
        : Math.max(
            0,
            Math.min(100, Math.round((completedWeight / totalWeight) * 100)),
          );
    const next = steps.find(
      (step) => step.status !== 'completed' && step.status !== 'not_applicable',
    );

    return {
      readinessPercent,
      nextAction: next
        ? {
            stepId: next.id,
            code: next.code,
            labelFr: next.titleFr,
            labelEn: next.titleEn,
          }
        : null,
    };
  }

  deriveStatus(
    current: ScholarshipWorkspaceStatus,
    readinessPercent: number,
    hasActivity: boolean,
  ): ScholarshipWorkspaceStatus {
    if (
      current === 'review_requested' ||
      current === 'submitted' ||
      current === 'decision_received' ||
      current === 'archived'
    ) {
      return current;
    }
    if (readinessPercent === 100) return 'ready_for_review';
    if (hasActivity) return 'preparing';
    return 'started';
  }
}
