# KPB Education Admin — World-Class Upgrade Audit

> Multi-perspective audit of the `admin/` app (Next.js 15 app-router) assessing what it needs to reach a Linear / Stripe / Retool-grade operations console.
> **Method:** 11 review dimensions → each finding adversarially re-checked against the actual code (rejected if not grounded) → synthesized into the roadmap below. **80 findings verified, 0 rejected.**

## Severity snapshot

| Severity | Count | |
|---|---|---|
| 🔴 Critical | 3 | destructive actions w/o confirm, no focus indicators, i18n on only 2/11 surfaces |
| 🟠 High | 30 | design tokens, brand, component kit, data layer, RSC, auth hardening, tables… |
| 🟡 Medium | 41 | dark mode, command palette, a11y ARIA, error boundaries, pagination… |
| ⚪ Low | 6 | next/font, server actions, security headers, husky, touch targets… |

The gaps are **systemic and correlated** — a handful of foundational moves (token layer, component kit, server data layer, cookie auth) unblock the large majority of the 80 findings.

## First-hand UI evidence (live preview, logged in as admin)

- **Mixed-language UI:** the sidebar renders in French (`Tableau de bord`, `Dossiers`, `Contenus`, `Vérification`…) while the body renders in English (`Overview`, `Active cases`, `Operational focus this week`). The FR/EN toggle only re-skins the chrome.
- **Raw backend errors shown to operators:** the Cases page renders the literal `{"statusCode":503,"message":"Database is not configured. Set DATABASE_URL."}` in a red box instead of a friendly empty/error state.
- **Same generic subtitle on every page:** a single hardcoded `shell.description` ("Contenus mobiles, gestion des dossiers…") sits under every page title.
- **Plain, un-branded visuals:** flat metric cards (no trend/delta/icon), no top bar, no global search, no logo, navy+orange accents (brand blue `#004AAD` is absent), and the Next dev badge overlaps the last nav item.

---

## 1. Verdict

The admin app is **functional but pre-foundational**: it works as a demo, but every layer that separates a working internal tool from a Linear/Stripe/Retool-grade console is either absent or hand-rolled. There is no design-token layer (colors are magic hex literals scattered across `lib/ui.ts` and 217+ inline `style={{}}` objects), no component primitives (`lib/ui.ts` exports raw `CSSProperties` objects, not `<Button>`/`<Table>`), no data layer (every page hand-rolls fetch-in-`useEffect` with a `cancelled` flag), no tests, no error monitoring, and the i18n switcher is cosmetic (only ~2 of 11 surfaces are translated despite a FR-first audience). Most critically, there are **silent destructive actions** (reject scholarship, reset verification, cancel case — all single un-guarded clicks), the **admin JWT lives in `localStorage`**, the login screen ships **pre-filled demo credentials**, and **route protection is client-only** (flash of protected content). The good news: the gaps are systemic and correlated, so a small number of foundational moves unblock the overwhelming majority of findings.

## 2. Critical findings (fix first)

### 🔴 Destructive actions have no confirmation or undo
`scholarships/page.tsx:166-190` rejects + drops a row on a single click; `verification/page.tsx:101-160` "Réinitialiser" wipes `lastVerifiedAt`/`sourceUrl` with no prompt; `cases/page.tsx:176-198` can set `rejected`/`cancelled` instantly; `users/page.tsx:124-149` deactivates an operator in one click. No confirm, no undo, and for scholarships the row vanishes so a misclick is hard to even notice.
**Fix:** confirmation modal naming the entity for irreversible ops + optimistic-update-with-5s-Undo toast for reversible list mutations.

### 🔴 No visible keyboard focus indicators anywhere
`globals.css` (18 lines) has no `:focus`/`:focus-visible` rule; grep for `focus`/`outline` returns zero. Every control uses inline `border:'none'` with no focus override → fails WCAG 2.4.7. Keyboard / low-vision users cannot tell what is focused.
**Fix (S):** global `:focus-visible{ outline:2px solid var(--brand); outline-offset:2px }` + a light-on-dark variant for the sidebar.

### 🔴 i18n covers only 2 of 11 surfaces
Only `login` + `dashboard-shell` use `useTranslations`. All 9 page bodies are raw literals, split between hardcoded English and hardcoded French, so the language switcher is effectively cosmetic for a FR-primary market.
**Fix (L):** route every page through next-intl with per-route namespaces + a CI guard test that fails on literal UI strings.

## 3. Top themes

### Theme A — Design system & brand (no tokens, no primitives, wrong brand)
Zero CSS custom properties exist; colors/radii/spacing are literals duplicated across files. Brand blue `#004AAD` appears **once** (`scholarships/page.tsx:261`); the UI is dominated by navy `#122033` + orange `#F97316` + indigo `#4338CA` — three competing accents, none the brand. One fixed-indigo badge is reused for every status, so status carries no color meaning. `lib/ui.ts` exports style objects, not components, so variants/states/hover/focus are impossible.
**Target:** CSS-variable token layer in `globals.css` (`--brand:#004AAD`, `--bg/--surface/--border/--text/--text-muted`, semantic `--success/--warning/--danger` with `-bg/-fg`, 4/8 spacing scale, 3–4 radius tokens, type ramp, 2 elevations) + a `components/ui/` primitive kit consuming tokens. Dark mode becomes a one-file `[data-theme=dark]` override.

### Theme B — Component & data architecture (client-only SPA, monoliths, no data layer)
13 of 14 files are `'use client'`; every page fetches in `useEffect` after hydration → blank shell → `'...'` placeholders. No caching/dedup/retry/optimistic updates; every mutation full-refetches (editing one offer reloads all 3 content collections). `content/page.tsx` is a **1060-line monolith** over 3 CRUD domains; `cases/page.tsx` is 573 LOC. 13 `as any` casts defeat `strict`; no `@/` alias (34 `../../` imports).
**Target:** Server Components fetch list/detail; `'use client'` only on leaf islands. TanStack Query data layer (caching, dedup, optimistic, scoped invalidation). Split `content` into `offers/destinations/articles` under a shared `<CrudSection<T>>`. Generated types in `lib/types.ts`, shared `lib/format.ts`/`lib/status.ts`.

### Theme C — Interaction & operator UX (no toasts, no confirms, no tables, no search)
Feedback is a top-of-page banner that never auto-dismisses (looks like nothing happened on long forms). Destructive actions fire on one click. No tables — every collection is a card list with no search/sort/filter/pagination (`verification` fetches `programs?limit=1000` and renders all). No bulk actions on batch queues; community moderation is read-only. Two incompatible master-detail mental models (edit-on-click cards vs left-rail selection).
**Target:** global toast provider (auto-dismiss + undo), confirm modals, a shared `DataTable` (debounced search, sort, facets, pagination/virtualization), bulk select + sticky action bar, one master-detail pattern, Cmd-K palette + `j/k` triage shortcuts.

### Theme D — Accessibility (fails WCAG AA broadly)
No `:focus-visible` anywhere; nav active state + FR/EN toggle are color-only (no `aria-current`/`aria-pressed`); orange `#F97316` on white = 2.80:1 and muted `#64748B` < 4.5:1 (the destructive logout is the lowest-contrast control); no skip link, no landmark labels, banners aren't `aria-live`; heading hierarchy skips h2→h3; the verification input has only a placeholder.
**Target:** focus-ring token, ARIA state, AA-compliant tokenized palette (`#C2410C` accent, `#475569` muted), skip link + landmarks + `role=status/alert`, corrected headings/labels, CI axe scans.

### Theme E — Auth & security hardening
JWT in `localStorage` (XSS-exfiltrable, `api-client.ts:22-54`); the backend's 7-day refresh token + `/auth/admin/refresh` are **thrown away** (sessions die at 1h); no 401 interceptor; no `middleware.ts` (client-only guard → flash-of-protected-content + full bundle shipped to anyone); RBAC modeled but **never enforced** (a counselor can open Users); login pre-fills `password` and advertises seeded accounts.
**Target:** httpOnly+Secure+SameSite cookies, `credentials:'include'`, silent refresh + refresh-on-401, `middleware.ts` route gate, role→route nav filtering + 403 states, cleaned login, CSP/security headers.

### Theme F — i18n & content (bilingual by accident)
Only `login` + shell use `useTranslations`; 9 page bodies are literals. Overview's catalog `overview.*` keys are **dead**; dates are hand-rolled `DD/MM/YYYY`, numbers use bare `toFixed`; status enums render via raw `replaceAll('_',' ')`; a custom `resolveDotted()` duplicates next-intl and masks missing keys.
**Target:** 100% of copy through next-intl (per-route namespaces, `titleKey` on shell), `Intl`-based formatting via `useFormatter()`, typed status label/color map, single next-intl API, CI guard test.

### Theme G — Responsive (structurally impossible today)
Inline `style={}` objects **cannot hold `@media`** (grep `@media` → zero). Shell is a hardcoded `minmax(220px,260px) 1fr` grid that never collapses; cases kanban is `repeat(4,minmax(0,1fr))`; many `1fr 1fr` grids never stack; no overflow containment; touch targets < 44px; 14px inputs trigger iOS focus-zoom.
**Target:** move layout to CSS classes/modules (prerequisite), breakpoint scale, collapsible/off-canvas sidebar, `auto-fit minmax()` grids, kanban as a horizontally-scrollable lane container, 44px targets, 16px control font, `viewport` export.

### Theme H — Quality infrastructure (no safety net)
Zero tests, no `test` script, no Vitest/Playwright; no `tsc --noEmit` step; no `error.tsx`/`not-found.tsx` (one render throw white-screens the admin); no error monitoring; no Prettier/husky; raw backend error text shown verbatim.
**Target:** Vitest + RTL units, Playwright + `@axe-core/playwright` e2e, `error.tsx`/`global-error.tsx`/`not-found.tsx` with branded retry, `@sentry/nextjs`, status-code→localized-message mapping, `typecheck` + Prettier + husky in CI.

## 4. Prioritized roadmap

### P0 — Foundations (unblock everything else)
1. **Design-token layer in `globals.css`** (M) — color/spacing/radius/type/elevation tokens + `--brand:#004AAD`. *Unblocks brand fix, dark mode, contrast, primitives, responsive.*
2. **CSS layout migration** (L) — move shell + page grids off inline styles so `@media`/container queries become possible. *Hard prerequisite for all responsive work.*
3. **Component primitive kit** `components/ui/` (L) — `Button/Input/Card/Badge/StatusPill/Table/Alert/Toast/StatCard/EmptyState/Skeleton` with focus-visible/hover/disabled/loading. *Collapses ~400 inline styles.*
4. **httpOnly cookie auth + `middleware.ts`** (M) — token off `localStorage`, server-side route gate, capture refresh token. *Top security fix; unblocks RSC.*
5. **Typed data layer — TanStack Query** (L) — `useCases()/useOverview()/useContent()` over a typed `apiFetch` + one-place error mapping. *Deletes per-page fetch/cancel boilerplate.*
6. **Quality baseline** (S each) — `typecheck` + CI, Prettier, `error.tsx`/`global-error.tsx`/`not-found.tsx`, Vitest scaffold, `@/` alias.

### P1 — Elevation ("works" → "good")
7. **Toasts + confirm modals + optimistic-with-undo** (M) — gate destructive actions. *Highest-risk gap.*
8. **Wire all pages through next-intl** (L) — namespaces, `titleKey`, `Intl` formatting, typed status map, remove `resolveDotted`, fix dead `overview.*`, guard test.
9. **DataTable + search/filter/pagination** (L) — replace `limit=1000` and card lists; saved views.
10. **Decompose `content/page.tsx` monolith** (L) — `offers/destinations/articles` + `<CrudSection<T>>`; react-hook-form + zod; kill `as any`.
11. **Accessibility pass** (M) — focus rings, ARIA, landmarks, skip-link, contrast, headings/labels, kanban a11y.
12. **RBAC in UI + login hardening** (M+S) — role→route nav + 403s; remove pre-filled creds/seeded list.
13. **Responsive shell + grids** (M) — collapsible sidebar, `auto-fit` grids, kanban scroll, overflow containment, 44px targets.
14. **RSC migration of read paths + skeletons** (L) — list/detail as Server Components with `loading.tsx` Suspense; client islands for interactivity.

### P2 — World-class polish
15. **Command palette (Cmd-K) + `j/k` shortcuts + `?` cheat-sheet** (M).
16. **Bulk operations** (M) — checkboxes + sticky bar on scholarships/verification/cases.
17. **Dark mode toggle** (M).
18. **Sentry + Playwright smoke suite + axe-in-CI** (M).
19. **Audit log / activity feed** (L).
20. **Real-time queues** (M) — polling/SSE on shared boards.
21. **Silent refresh + 401 interceptor, CSP, Server Actions, husky/lint-staged, next/font, Storybook + Chromatic** (mixed).

## 5. Concrete tech recommendations (for THIS app)

- **Styling: CSS variables + CSS Modules, NOT Tailwind** — lowest-friction path given the existing `lib/ui.ts` convention and small surface; fixes the `@media` impossibility without a build overhaul. *(Greenfield would be Tailwind+shadcn, but migrating now is net churn.)*
- **Component kit: in-house `components/ui/`** (copy individual shadcn primitives as reference) — keeps the zero-dependency ethos.
- **Data: TanStack Query** — caching/dedup/optimistic/invalidation; deletes the 9 `cancelled`-flag loaders and 21 manual refetches.
- **Server rendering: incremental RSC** after cookie auth lands; keep forms/kanban as client islands. Don't big-bang.
- **Auth: httpOnly Secure SameSite cookies + `middleware.ts`** using the backend's existing refresh endpoint.
- **i18n: standardize on next-intl, remove `resolveDotted`**; `useFormatter()` for dates/numbers; CI guard test.
- **Forms: react-hook-form + zod** for content/cases.
- **Types: generate from backend (Prisma/OpenAPI) into `lib/types.ts`** + shared `Localized = {fr;en}`; enable `no-explicit-any`.
- **Testing: Vitest + RTL (units), Playwright + @axe-core/playwright (e2e+a11y).** Storybook/Chromatic after primitives exist.
- **Observability: @sentry/nextjs** tagged by `user.id/role`.
- **DX: Prettier + husky + lint-staged + `tsc --noEmit` CI + `@/` alias** (all S, high leverage).

## 6. Quick wins (high-impact, S-effort, do now)

1. **Remove pre-filled login credentials + seeded-account paragraph** (`login/page.tsx:13-14,128-132`) — closes a default-credential backdoor.
2. **Global `:focus-visible` ring in `globals.css`** (+ light-on-dark sidebar variant) — fixes WCAG 2.4.7 everywhere.
3. **`aria-current`/`aria-pressed`/`aria-label`** on nav links + FR/EN toggle + `<nav>` (`dashboard-shell.tsx:80-132`).
4. **Bump muted `#64748B → #475569` and accent `#F97316 → #C2410C`** in `lib/ui.ts` — fixes contrast.
5. **Add `error.tsx` + `global-error.tsx` + `not-found.tsx`** with branded retry — stops white-screens.
6. **Add `"typecheck": "tsc --noEmit"` + CI step and `@/` alias** — fast feedback; kills 34 `../../` imports.
7. **Add `export const viewport` to `layout.tsx`** + skip link + landmark labels.
8. **Auto-dismiss + `role=status`/`role=alert`** on existing banners (before the full toast system).
9. **Friendly error mapping** so the Cases 503 stops dumping raw JSON to operators.

---

## Appendix — verified findings by severity

**🔴 Critical (3):** destructive actions w/o confirm·undo; no focus indicators; i18n on 2/11 surfaces.

**🟠 High (30):** token layer · brand fix · component primitives · semantic badges · toast system · first-class loading states · data tables w/ search-sort-filter-pagination · raise orange contrast · RSC + typed server data · query/mutation data layer · reusable component library · decompose 1060-line monolith · RSC routes · English/French split · dead `overview.*` keys · JWT off localStorage → cookies · use refresh token · role-aware nav/pages · wire/remove password field · error + loading boundaries · stop raw error text · establish test suite · App Router error/not-found routes · error monitoring · responsive sidebar/hamburger · inline-style can't express breakpoints · auto-collapsing grids · command palette · search/filter/saved views · bulk operations.

**🟡 Medium (41):** type & spacing scales · dark mode · shell density/polish · empty states w/ guidance · batch actions · breadcrumbs + page header · unify master-detail · fix misleading password field · ARIA on nav/toggle · skip link + landmarks + live region · heading/label fixes · SR/keyboard-robust cards & badges · close typing holes (`as any`) · shared utils + typed API · testing foundation · `loading.tsx` + Suspense streaming · replace 217 inline style objects · code-split heavy editors (`next/dynamic`) · HTTP caching/revalidation · remove custom dotted-key provider · Intl date/number formatting · localized status labels · 401 interceptor · middleware route protection · typed query-cache data layer · optimistic updates / targeted invalidation · pagination/virtualization · standardize loading/empty · handle 401/timeout/offline · type-check in CI · code formatter · Playwright e2e · a11y/visual-regression testing · horizontal-scroll containment · mobile-first breakpoint strategy · keyboard shortcuts/focus mgmt · notification + data layer · empty states/skeletons/onboarding · dark mode + tokens · audit log/activity feed · real-time updates.

**⚪ Low (6):** `next/font` · Server Actions for mutations · translate login English leaks · security response headers · husky + lint-staged · mobile/tablet touch-target sizing.

*Generated from an 11-dimension, adversarially-verified audit (92 sub-agents). No application files were modified by the audit.*
