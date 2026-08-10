/// Pure helpers for the "quota épuisé → conseiller WhatsApp" hand-off of the
/// KPB Intelligence chat. Kept free of Flutter/GetX so they are trivially
/// unit-testable.
library;

/// Max length of the conversation topic echoed into the WhatsApp prefill. The
/// student sees the full prefill before sending (verified-advisor sheet AND
/// WhatsApp's own compose box), but a short excerpt keeps it scannable.
const int kCoachHandoffTopicMaxChars = 160;

/// Returns the student's last message trimmed and clipped for use as the
/// "topic" line of the WhatsApp prefill, or null when there is nothing usable
/// (no user message yet → the greeting alone is sent).
String? clipCoachHandoffTopic(
  String? lastUserMessage, {
  int maxChars = kCoachHandoffTopicMaxChars,
}) {
  final topic = lastUserMessage?.trim() ?? '';
  if (topic.isEmpty) return null;
  if (topic.length <= maxChars) return topic;
  return '${topic.substring(0, maxChars).trimRight()}…';
}

/// The backend refuses an over-quota send INSIDE the SSE stream as a generic
/// `type: 'error'` event carrying only a human-readable message ("Quota
/// hebdomadaire atteint (5 messages)…") — unlike consent refusals it has no
/// machine-readable `code`. Until the backend grows one, recognize it by the
/// word "quota" so the UI can show the advisor hand-off state instead of a
/// generic error bubble.
bool looksLikeCoachQuotaError(String? message) {
  return (message ?? '').toLowerCase().contains('quota');
}
