import '../../core/models/app_models.dart';

enum CaseTimelineStepState { passed, current, upcoming, terminalSuccess, terminalError }

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

const _timelineTitlesFr = <CaseStatus, String>{
  CaseStatus.submitted: 'Soumise',
  CaseStatus.counselorAssigned: 'Attribuée à un conseiller',
  CaseStatus.underReview: 'En revue',
  CaseStatus.documentsNeeded: 'Documents requis',
  CaseStatus.awaitingStudent: 'En attente de ta réponse',
  CaseStatus.inProgress: 'En cours',
  CaseStatus.applicationSubmitted: 'Soumise à l\'établissement',
  CaseStatus.waitingDecision: 'Décision en attente',
  CaseStatus.awaitingPayment: 'Paiement en attente',
  CaseStatus.completed: 'Acceptée',
};

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
        titleFr: 'Demande annulée',
        state: CaseTimelineStepState.terminalError,
        date: _latestEventDate(events, CaseStatus.cancelled),
      ),
    ];
  }

  final currentIndex = caseTimelineIndexForStatus(currentStatus);
  final isRejected = currentStatus == CaseStatus.rejected;

  return kCaseTimelineOrder.map((stepStatus) {
    final stepIndex = kCaseTimelineOrder.indexOf(stepStatus);
    final title = _timelineTitlesFr[stepStatus] ?? stepStatus.name;

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
          ? 'Refusée'
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
        .contains(_timelineTitlesFr[status]?.toLowerCase() ?? '');
    if (!matchesStatus && !matchesTitle) continue;
    if (latest == null || event.createdAt.isAfter(latest)) {
      latest = event.createdAt;
    }
  }
  return latest;
}
