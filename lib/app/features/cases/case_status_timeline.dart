import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'case_timeline_definition.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Palette (App-engagement handoff · "Dossier" step checklist).
// Local to this file — same pattern as the restyled Student surfaces (#110–116).
// ─────────────────────────────────────────────────────────────────────────────
class _Palette {
  static const navy = Color(0xFF0F172A);
  static const blue = Color(0xFF2563EB);
  static const slate400 = Color(0xFF94A3B8);
  static const body = Color(0xFF334155);
  static const border = Color(0xFFE2E8F0);
  static const lineSoft = Color(0xFFF8FAFC);
  static const card = Color(0xFFFFFFFF);
  static const outline = Color(0xFFCBD5E1);
  static const green = Color(0xFF16A34A);
  static const red = Color(0xFFDC2626);
  static const redBg = Color(0xFFFEE2E2);
  // rgba(15,23,42,0.04) — soft card shadow from the handoff.
  static const cardShadow = Color(0x0A0F172A);
}

const _cardShadow = <BoxShadow>[
  BoxShadow(color: _Palette.cardShadow, blurRadius: 2, offset: Offset(0, 1)),
];

/// M14 per-status timeline rendered as the handoff's Dossier "step checklist":
/// a done step gets a green check + struck-through label, the current step a
/// numbered blue ring (plus a red "Your turn" badge only when it is genuinely
/// the student's move), an upcoming step a muted number, and a terminal
/// rejection a red cross.
///
/// Read-only by design: the steps are DERIVED from the case status (see
/// [buildCaseTimelineSteps]) — there is no per-step "mark done" action in the
/// model, so we render status-driven progress rather than fake toggles.
class CaseStatusTimeline extends StatelessWidget {
  const CaseStatusTimeline({super.key, required this.steps});

  final List<CaseTimelineStepViewModel> steps;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _Palette.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _Palette.border),
        boxShadow: _cardShadow,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          for (var i = 0; i < steps.length; i++)
            _StepRow(
              step: steps[i],
              index: i,
              isLast: i == steps.length - 1,
            ),
        ],
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({
    required this.step,
    required this.index,
    required this.isLast,
  });

  final CaseTimelineStepViewModel step;
  final int index;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final done = step.state == CaseTimelineStepState.passed ||
        step.state == CaseTimelineStepState.terminalSuccess;
    final isError = step.state == CaseTimelineStepState.terminalError;
    final isCurrent = step.state == CaseTimelineStepState.current;
    final yourTurn = isCurrent && isCaseStudentActionStatus(step.status);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : const Border(bottom: BorderSide(color: _Palette.lineSoft)),
      ),
      child: Row(
        children: [
          _Marker(
            done: done,
            isError: isError,
            isCurrent: isCurrent,
            number: index + 1,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  step.titleFr,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: done ? FontWeight.w600 : FontWeight.w700,
                    color: done
                        ? _Palette.slate400
                        : isError
                            ? _Palette.red
                            : isCurrent
                                ? _Palette.navy
                                : _Palette.body,
                    decoration: done ? TextDecoration.lineThrough : null,
                    decorationColor: _Palette.slate400,
                  ),
                ),
                if ((step.subtitle ?? '').isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    step.subtitle!,
                    style: const TextStyle(
                      fontSize: 11,
                      color: _Palette.slate400,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (yourTurn) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: _Palette.redBg,
                borderRadius: BorderRadius.circular(100),
              ),
              child: Text(
                'case_step_your_turn'.tr,
                style: const TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w800,
                  color: _Palette.red,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Marker extends StatelessWidget {
  const _Marker({
    required this.done,
    required this.isError,
    required this.isCurrent,
    required this.number,
  });

  final bool done;
  final bool isError;
  final bool isCurrent;
  final int number;

  @override
  Widget build(BuildContext context) {
    if (done) {
      return Container(
        width: 24,
        height: 24,
        decoration: const BoxDecoration(
          color: _Palette.green,
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.check_rounded, size: 15, color: Colors.white),
      );
    }
    if (isError) {
      return Container(
        width: 24,
        height: 24,
        decoration: const BoxDecoration(
          color: _Palette.red,
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.close_rounded, size: 15, color: Colors.white),
      );
    }
    final accent = isCurrent ? _Palette.blue : _Palette.outline;
    final numColor = isCurrent ? _Palette.blue : _Palette.slate400;
    return Container(
      width: 24,
      height: 24,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: accent, width: 2),
      ),
      child: Text(
        '$number',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: numColor,
        ),
      ),
    );
  }
}
