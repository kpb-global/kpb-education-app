import 'package:get/get.dart';

import '../../core/models/app_models.dart';

enum CaseTimelineStepState {
  passed,
  current,
  upcoming,
  terminalSuccess,
  terminalError
}

class CaseTimelineStepViewModel {
  const CaseTimelineStepViewModel({
    required this.status,
    required this.titleFr,
    required this.state,
    this.date,
    this.subtitle,
  });

  final CaseStatus status;
  final String titleFr;
  final CaseTimelineStepState state;
  final DateTime? date;
  final String? subtitle;
}

/// Canonical M14 timeline — 10 student-facing steps (spec §5.14).
const kCaseTimelineOrder = <CaseStatus>[
  CaseStatus.submitted,
  CaseStatus.counselorAssigned,
  CaseStatus.underReview,
  CaseStatus.documentsNeeded,
  CaseStatus.awaitingStudent,
  CaseStatus.inProgress,
  CaseStatus.applicationSubmitted,
  CaseStatus.waitingDecision,
  CaseStatus.awaitingPayment,
  CaseStatus.completed,
];

// Stored as translation KEYS (const-safe); resolved with .tr at the call site
// so the labels follow the active locale.
const _timelineTitleKeys = <CaseStatus, String>{
  CaseStatus.submitted: 'case_timeline_status_submitted',
  CaseStatus.counselorAssigned: 'case_timeline_status_counselor_assigned',
  CaseStatus.underReview: 'case_timeline_status_under_review',
  CaseStatus.documentsNeeded: 'case_timeline_status_documents_needed',
  CaseStatus.awaitingStudent: 'case_timeline_status_awaiting_student',
  CaseStatus.inProgress: 'case_timeline_status_in_progress',
  CaseStatus.applicationSubmitted: 'case_timeline_status_application_submitted',
  CaseStatus.waitingDecision: 'case_timeline_status_waiting_decision',
  CaseStatus.awaitingPayment: 'case_timeline_status_awaiting_payment',
  CaseStatus.completed: 'case_timeline_status_completed',
};

/// Real, status-driven completion of the 10-step M14 pipeline — the value
/// behind the Dossier progress ring and the list-row progress bar. It mirrors
/// the checklist exactly: the fraction returned equals the number of steps
/// rendered as "done" (state == passed) over the total, so ring and checklist
/// can never disagree. Terminal states are handled explicitly (completed →
/// 100%, cancelled → 0%); a rejected case keeps the progress it reached before
/// the rejection rather than fabricating a number.
double caseTimelineProgress(CaseStatus status) {
  if (status == CaseStatus.completed) return 1;
  if (status == CaseStatus.cancelled) return 0;
  final index = caseTimelineIndexForStatus(status);
  if (index < 0) return 0;
  return (index / kCaseTimelineOrder.length).clamp(0.0, 1.0);
}

/// Whether [status] is one where the ball is in the STUDENT's court — i.e. the
/// step deserves the design's red "Your turn" badge. Kept honest: a step the
/// counsellor/KPB is working (under review, waiting decision…) never claims to
/// need the student. Matches the urgent-case heuristic on the home dashboard.
bool isCaseStudentActionStatus(CaseStatus status) {
  return status == CaseStatus.documentsNeeded ||
      status == CaseStatus.awaitingStudent ||
      status == CaseStatus.awaitingPayment;
}

int caseTimelineIndexForStatus(CaseStatus status) {
  switch (status) {
    case CaseStatus.draft:
      return -1;
    case CaseStatus.submitted:
      return 0;
    case CaseStatus.counselorAssigned:
      return 1;
    case CaseStatus.underReview:
      return 2;
    case CaseStatus.documentsNeeded:
      return 3;
    case CaseStatus.awaitingStudent:
      return 4;
    case CaseStatus.scheduled:
      return 5;
    case CaseStatus.inProgress:
      return 5;
    case CaseStatus.applicationSubmitted:
      return 6;
    case CaseStatus.waitingDecision:
      return 7;
    case CaseStatus.awaitingPayment:
      return 8;
    case CaseStatus.completed:
      return 9;
    case CaseStatus.rejected:
      return 9;
    case CaseStatus.cancelled:
      return -2;
  }
}

List<CaseTimelineStepViewModel> buildCaseTimelineSteps({
  required CaseStatus currentStatus,
  required List<CaseTimelineEvent> events,
  String? assignedAdvisorName,
}) {
  if (currentStatus == CaseStatus.cancelled) {
    return [
      CaseTimelineStepViewModel(
        status: CaseStatus.cancelled,
        titleFr: 'case_timeline_status_cancelled'.tr,
        state: CaseTimelineStepState.terminalError,
        date: _latestEventDate(events, CaseStatus.cancelled),
      ),
    ];
  }

  final currentIndex = caseTimelineIndexForStatus(currentStatus);
  final isRejected = currentStatus == CaseStatus.rejected;

  return kCaseTimelineOrder.map((stepStatus) {
    final stepIndex = kCaseTimelineOrder.indexOf(stepStatus);
    final title = _timelineTitleKeys[stepStatus]?.tr ?? stepStatus.name;

    CaseTimelineStepState state;
    if (isRejected && stepStatus == CaseStatus.completed) {
      state = CaseTimelineStepState.terminalError;
    } else if (stepIndex < currentIndex) {
      state = CaseTimelineStepState.passed;
    } else if (stepIndex == currentIndex) {
      state = isRejected && stepStatus == CaseStatus.completed
          ? CaseTimelineStepState.terminalError
          : stepStatus == CaseStatus.completed
              ? CaseTimelineStepState.terminalSuccess
              : CaseTimelineStepState.current;
    } else {
      state = CaseTimelineStepState.upcoming;
    }

    String? subtitle;
    if (stepStatus == CaseStatus.counselorAssigned &&
        (assignedAdvisorName ?? '').isNotEmpty &&
        stepIndex <= currentIndex) {
      subtitle = assignedAdvisorName;
    }

    return CaseTimelineStepViewModel(
      status: isRejected && stepStatus == CaseStatus.completed
          ? CaseStatus.rejected
          : stepStatus,
      titleFr: isRejected && stepStatus == CaseStatus.completed
          ? 'case_timeline_status_rejected'.tr
          : title,
      state: state,
      date: _latestEventDate(events, stepStatus),
      subtitle: subtitle,
    );
  }).toList();
}

DateTime? _latestEventDate(List<CaseTimelineEvent> events, CaseStatus status) {
  DateTime? latest;
  for (final event in events) {
    final matchesStatus = event.status == status;
    final matchesTitle = event.title.fr
        .toLowerCase()
        .contains(_timelineTitleKeys[status]?.tr.toLowerCase() ?? '');
    if (!matchesStatus && !matchesTitle) continue;
    if (latest == null || event.createdAt.isAfter(latest)) {
      latest = event.createdAt;
    }
  }
  return latest;
}
