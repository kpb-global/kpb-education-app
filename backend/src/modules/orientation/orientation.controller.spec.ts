import { OrientationController } from './orientation.controller';
import { OrientationService } from './orientation.service';

/**
 * Bug C: students can no longer choose their own userId on
 * POST /orientation/sessions or /submit. The controller now overrides any
 * client-supplied userId / profile.id with req.studentUser.id.
 *
 * (The @UseGuards(StudentAuthGuard) is enforced by Nest at runtime; here we
 * verify the controller's body-rewriting logic in isolation.)
 */
describe('OrientationController — authenticated userId override', () => {
  function makeController() {
    let received: any = null;
    const service = {
      createSession: async (body: any) => {
        received = body;
        return { ok: true };
      },
    } as unknown as OrientationService;
    const ctrl = new OrientationController(service);
    return {
      ctrl,
      service,
      getReceived: () => received,
    };
  }

  const authedReq = { studentUser: { id: 'user-real', email: 'r@e.fr' } };

  it('forces body.userId to the authenticated id (sessions)', async () => {
    const { ctrl, getReceived } = makeController();
    await ctrl.createSession({ userId: 'attacker', payload: {} }, authedReq);
    expect(getReceived().userId).toBe('user-real');
  });

  it('forces profile.id to the authenticated id (sessions)', async () => {
    const { ctrl, getReceived } = makeController();
    await ctrl.createSession(
      { profile: { id: 'attacker', fullName: 'A' } },
      authedReq,
    );
    expect(getReceived().profile.id).toBe('user-real');
    // Other profile fields are preserved.
    expect(getReceived().profile.fullName).toBe('A');
  });

  it('forces userId on /submit too', async () => {
    const { ctrl, getReceived } = makeController();
    await ctrl.submit({ userId: 'attacker' }, authedReq);
    expect(getReceived().userId).toBe('user-real');
  });

  it('does not call the service for getQuestions (no LLM, no DB write)', () => {
    // getQuestions is intentionally public; it just returns a static catalogue.
    const service = {
      getQuestions: () => ({ q: 1 }),
    } as unknown as OrientationService;
    const ctrl = new OrientationController(service);
    expect(ctrl.getQuestions()).toEqual({ q: 1 });
  });
});
