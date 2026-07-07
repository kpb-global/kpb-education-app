import { CanActivate, Injectable, NotFoundException } from '@nestjs/common';

/**
 * Launch-scope gate (Phase 0 / P0-C). Mobile hides several surfaces behind
 * `AppConfig.mvpOnly`, but until now their backend routes stayed fully
 * reachable. This guard 404s the student/public routes of those hidden
 * surfaces while `KPB_MVP_ONLY` is on, so the server matches what the app
 * ships. Admin routes are never gated — the back office keeps preparing
 * content for the post-MVP flip.
 *
 * Same env semantics as ScholarshipsIndexService: gated by default, opt out
 * with KPB_MVP_ONLY=false. Read per-request so deployments can flip the flag
 * without a rebuild (and tests can toggle it).
 */
@Injectable()
export class MvpGuard implements CanActivate {
  canActivate(): boolean {
    if (process.env.KPB_MVP_ONLY !== 'false') {
      // 404 rather than 403: while gated, the surface does not exist.
      throw new NotFoundException();
    }
    return true;
  }
}
