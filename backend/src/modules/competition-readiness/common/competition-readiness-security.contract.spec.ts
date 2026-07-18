import { readFileSync } from 'node:fs';
import { join } from 'node:path';

import {
  GUARDS_METADATA,
  METHOD_METADATA,
  PATH_METADATA,
} from '@nestjs/common/constants';

import { ROLES_KEY } from '../../../common/decorators/roles.decorator';
import { AdminAuthGuard } from '../../../common/guards/admin-auth.guard';
import { RolesGuard } from '../../../common/guards/roles.guard';
import { StudentAuthGuard } from '../../../common/guards/student-auth.guard';
import { AdminCompetitionReadinessController } from '../admin/admin-competition-readiness.controller';
import { ApplicationArtifactsController } from '../artifacts/application-artifacts.controller';
import { AiConsentController } from '../diagnostics/ai-consent.controller';
import { AiDiagnosticsController } from '../diagnostics/ai-diagnostics.controller';
import { OutcomeConsentController } from '../outcomes/outcome-consent.controller';
import { OutcomesController } from '../outcomes/outcomes.controller';
import { StudyReviewConsentController } from '../reviews/study-review-consent.controller';
import { StudyReviewController } from '../reviews/study-review.controller';
import { WorkspacesController } from '../workspaces/workspaces.controller';

type ControllerClass = abstract new (...args: never[]) => unknown;

const studentControllers: ControllerClass[] = [
  WorkspacesController,
  ApplicationArtifactsController,
  AiConsentController,
  AiDiagnosticsController,
  StudyReviewConsentController,
  StudyReviewController,
  OutcomeConsentController,
  OutcomesController,
];

function controllerGuards(controller: ControllerClass): unknown[] {
  return Reflect.getMetadata(GUARDS_METADATA, controller) ?? [];
}

function routeMethods(controller: ControllerClass): Array<{
  name: string;
  handler: (...args: unknown[]) => unknown;
}> {
  return Object.getOwnPropertyNames(controller.prototype)
    .filter((name) => name !== 'constructor')
    .map((name) => ({
      name,
      handler: controller.prototype[name] as (...args: unknown[]) => unknown,
    }))
    .filter(({ handler }) => Reflect.hasMetadata(METHOD_METADATA, handler));
}

describe('Competition Readiness route security contract', () => {
  it.each(studentControllers.map((controller) => [controller.name, controller]))(
    '%s authenticates every route through the student guard',
    (_name, controller) => {
      const guards = controllerGuards(controller as ControllerClass);
      expect(guards).toContain(StudentAuthGuard);
      expect(routeMethods(controller as ControllerClass)).not.toHaveLength(0);
    },
  );

  it('authenticates admin routes and evaluates role metadata', () => {
    const guards = controllerGuards(AdminCompetitionReadinessController);
    expect(guards).toEqual(expect.arrayContaining([AdminAuthGuard, RolesGuard]));
  });

  it('declares an explicit non-empty RBAC allowlist on every admin route', () => {
    const unsecured = routeMethods(AdminCompetitionReadinessController)
      .filter(({ handler }) => {
        const roles = Reflect.getMetadata(ROLES_KEY, handler) as
          | unknown[]
          | undefined;
        return !roles?.length;
      })
      .map(({ name }) => name);

    expect(unsecured).toEqual([]);
  });

  it('does not accidentally mount student controllers under an admin path', () => {
    for (const controller of studentControllers) {
      const path = Reflect.getMetadata(PATH_METADATA, controller) as
        | string
        | undefined;
      expect(path).toMatch(/^competition-readiness(?:\/|$)/);
      expect(path).not.toMatch(/^admin(?:\/|$)/);
    }
  });

  it('keeps optimistic concurrency and correlation headers in the CORS allowlist', () => {
    const bootstrap = readFileSync(join(process.cwd(), 'src/main.ts'), 'utf8');
    for (const header of [
      'Authorization',
      'Idempotency-Key',
      'If-Match',
      'X-Request-Id',
    ]) {
      expect(bootstrap).toContain(`'${header}'`);
    }
  });
});
