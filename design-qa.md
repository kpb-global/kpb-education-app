# KPB Intelligence entry screen — design QA

- Source visual truth: `/var/folders/8h/f8vgrv412qjgft526rjky5d00000gp/T/TemporaryItems/NSIRD_screencaptureui_aSNXU9/Screenshot 2026-07-12 at 00.14.26.png`
- Rendered implementation: `/tmp/kpb-design-qa/kpb-intelligence-final.png`
- Full-view comparison: `/tmp/kpb-design-qa/reference-vs-simulator-final.png`
- Viewport and state: iPhone 17 Pro simulator, 1206 × 2622 px; French, logged-out, first-run entry state. The supplied reference is a framed 652 × 1272 px mock, so the native iOS status area is an expected device-chrome difference.
- Primary interactions checked: Google entry keeps the existing OAuth action; email entry opens the existing magic-link email flow. The route no longer shows the generic intro slideshow.

## Findings

- [P3] Native device chrome differs from the framed reference.
  - Location: top edge.
  - Evidence: the simulator shows iOS status/Dynamic Island chrome while the source is a clean device mock.
  - Impact: no impact on the usable content or entry conversion path.
  - Decision: accepted; retaining native system chrome is more appropriate for the real iOS application.

- [P3] The Google mark is supplied by the installed icon library and is monochrome blue rather than the multi-colour mark in the reference.
  - Location: Google CTA.
  - Impact: minor brand-detail drift only; label, affordance, sizing, and action match.

## Required fidelity surfaces

- **Fonts and typography:** title hierarchy, weights, three-line title wrap, two-line explanatory copy, compact benefit labels, and the single-line footer note now match the reference composition.
- **Spacing and layout rhythm:** logo, content block, benefit list, full-width rounded CTAs, and footer were tuned against the reference. The final comparison preserves the intended empty space above the promise and CTA grouping at the bottom.
- **Colors and visual tokens:** the screen uses the approved navy `#0F172A`, action blue `#2563EB`, canvas `#F8FAFC`, border `#E2E8F0`, and slate supporting copy.
- **Image quality and asset fidelity:** the supplied KPB Education logo is used directly from `assets/images/logo/kpb-education-logo-full.png`; no logo or illustration was re-created in code.
- **Copy and content:** French source copy, benefits, CTAs, and footer are present; matching English translations were added for language parity.

## Comparison history

1. **Simulator v1** (`/tmp/kpb-design-qa/kpb-intelligence-v1.png`): the logo was oversized, the supporting copy and benefits wrapped too early, and the footer note wrapped. These were P2 visual mismatches.
2. **Simulator v2** (`/tmp/kpb-design-qa/kpb-intelligence-v2.png`): logo size/alignment improved. Supporting copy, benefit wrapping, and footer still differed (P2).
3. **Simulator v3** (`/tmp/kpb-design-qa/kpb-intelligence-v3.png`): supporting copy and footer matched; benefit rows still wrapped differently (P2).
4. **Final simulator render** (`/tmp/kpb-design-qa/kpb-intelligence-final.png`): adjusted benefit typography yields the same one/two/one line pattern as the source. No actionable P0/P1/P2 findings remain.

## Implementation checklist

- [x] Direct unauthenticated first-run users to the KPB Intelligence entry screen.
- [x] Keep Google OAuth and email magic-link actions connected to their existing flows.
- [x] Add the official KPB logo asset and localized screen copy.
- [x] Verify the Flutter test suite and final iOS simulator render.

## Follow-up polish

- [P3] Add Google’s official multi-colour mark if brand-asset licensing/source is provided.

**final result: passed**
