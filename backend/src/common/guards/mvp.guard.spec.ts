import { NotFoundException } from '@nestjs/common';

import { MvpGuard } from './mvp.guard';

describe('MvpGuard', () => {
  const guard = new MvpGuard();
  const original = process.env.KPB_MVP_ONLY;

  afterEach(() => {
    if (original === undefined) {
      delete process.env.KPB_MVP_ONLY;
    } else {
      process.env.KPB_MVP_ONLY = original;
    }
  });

  it('404s by default (flag unset → gated)', () => {
    delete process.env.KPB_MVP_ONLY;
    expect(() => guard.canActivate()).toThrow(NotFoundException);
  });

  it('404s when the flag is explicitly on', () => {
    process.env.KPB_MVP_ONLY = 'true';
    expect(() => guard.canActivate()).toThrow(NotFoundException);
  });

  it('allows the request only when KPB_MVP_ONLY=false', () => {
    process.env.KPB_MVP_ONLY = 'false';
    expect(guard.canActivate()).toBe(true);
  });
});
