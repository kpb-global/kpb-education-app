import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/controllers/app_controller.dart';
import '../../core/repositories/app_api_client.dart';
import '../../core/ui/app_tokens.dart';
import '../../core/ui/components/verified_advisor_sheet.dart';
import '../../core/utils/tuition_utils.dart';

/// FR/EN short labels for each backend case status (kept local so the parent
/// view doesn't depend on the student-side case models).
const _caseStatusLabels = <String, (String, String)>{
  'draft': ('Brouillon', 'Draft'),
  'submitted': ('Soumis', 'Submitted'),
  'under_review': ('En revue', 'Under review'),
  'documents_needed': ('Documents requis', 'Documents needed'),
  'counselor_assigned': ('Conseiller assigné', 'Advisor assigned'),
  'awaiting_student': ('En attente de l\'étudiant', 'Awaiting student'),
  'scheduled': ('Programmé', 'Scheduled'),
  'in_progress': ('En cours', 'In progress'),
  'application_submitted': ('Candidature envoyée', 'Application submitted'),
  'waiting_decision': ('Décision en attente', 'Awaiting decision'),
  'awaiting_payment': ('Paiement en attente', 'Awaiting payment'),
  'completed': ('Terminé', 'Completed'),
  'rejected': ('Refusé', 'Rejected'),
  'cancelled': ('Annulé', 'Cancelled'),
};

/// Read-only case view for linked parents (Track C1). The student has opted
/// in to share the case (`parentCanView = true` on the case). We show:
/// - Title, context, current status, next-step copy
/// - Timeline (read-only)
/// - Last few messages (read-only — parent can't post)
/// - A prominent "Discuter avec un conseiller" button that opens WhatsApp.
///
/// Scope is deliberately narrow — the parent's job here is to reach a KPB
/// advisor and stay informed, not to operate the case. In-app payment was
/// removed (our largely African audience settles fees directly with their
/// advisor); the backend payments module stays but is no longer called here.
class ParentCaseViewScreen extends StatefulWidget {
  const ParentCaseViewScreen({super.key, required this.caseId});

  final String caseId;

  @override
  State<ParentCaseViewScreen> createState() => _ParentCaseViewScreenState();
}

class _ParentCaseViewScreenState extends State<ParentCaseViewScreen> {
  late final AppApiClient _api = AppApiClient();
  bool _loading = true;
  String? _error;
  Map<String, dynamic> _case = const {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await _api.getParentVisibleCase(widget.caseId);
      if (!mounted) return;
      setState(() {
        _case = result;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Impossible de charger le dossier.';
        _loading = false;
      });
    }
  }

  Future<void> _discussPressed() async {
    // Anti-scam: surface the verified advisor's identity + the exact official
    // number to expect BEFORE the WhatsApp hand-off (KPB-52 pattern), so an
    // impostor number demanding Mobile Money is obvious. No in-app payment.
    final title = (_case['title'] as String?)?.trim();
    final prefill = title != null && title.isNotEmpty
        ? 'Bonjour, je suis le parent et je souhaite échanger au sujet du dossier « $title » sur KPB Education.'
        : 'Bonjour, je suis le parent et je souhaite échanger au sujet du dossier de mon enfant sur KPB Education.';
    // No `phone:` on purpose: parents always reach the official KPB line,
    // never a counsellor's personal number (anti-fraud, Item 12).
    await showVerifiedAdvisorThenWhatsApp(
      advisorName: (_case['assignedAdvisorName'] as String?)?.trim(),
      prefill: prefill,
      source: 'parent_case',
      contextType: 'parent_advisor',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KpbColors.bgPage,
      appBar: AppBar(
        title: Text('parent_case_view_title'.tr),
        backgroundColor: Colors.white,
        foregroundColor: KpbColors.textPrimary,
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : _buildBody(),
      bottomNavigationBar: _loading || _error != null
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(KpbSpacing.pagePad),
                child: SizedBox(
                  height: 52,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.chat_rounded),
                    label: const Text('Discuter avec un conseiller'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: KpbColors.success,
                      foregroundColor: Colors.white,
                      textStyle: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    onPressed: _discussPressed,
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildBody() {
    final messages = (_case['messages'] as List<dynamic>? ?? const []).toList()
      ..sort((a, b) => ((a as Map)['createdAt'] as String? ?? '')
          .compareTo((b as Map)['createdAt'] as String? ?? ''));
    final timeline = _case['timelineEvents'] as List<dynamic>? ?? const [];

    return ListView(
      padding: const EdgeInsets.all(KpbSpacing.pagePad),
      children: [
        _headerCard(),
        const SizedBox(height: KpbSpacing.lg),
        if (timeline.isNotEmpty) ...[
          const Padding(
            padding:
                EdgeInsets.only(left: KpbSpacing.xs, bottom: KpbSpacing.sm),
            child: Text('Historique', style: KpbTextStyles.label),
          ),
          ...timeline.take(6).map(_timelineTile),
          const SizedBox(height: KpbSpacing.lg),
        ],
        if (messages.isNotEmpty) ...[
          Padding(
            padding:
                EdgeInsets.only(left: KpbSpacing.xs, bottom: KpbSpacing.sm),
            child: Text('latest_messages'.tr, style: KpbTextStyles.label),
          ),
          ...messages.reversed.take(5).toList().reversed.map(_messageTile),
        ],
      ],
    );
  }

  Widget _headerCard() {
    return Container(
      padding: const EdgeInsets.all(KpbSpacing.lg),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: KpbRadius.lgBr,
        boxShadow: KpbShadow.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text((_case['title'] as String?) ?? '',
                    style: KpbTextStyles.title),
              ),
              if (_statusLabel() case final s?) ...[
                const SizedBox(width: KpbSpacing.sm),
                _StatusChip(label: s),
              ],
            ],
          ),
          const SizedBox(height: KpbSpacing.xs),
          Text(
            (_case['contextLabel'] as String?) ?? '',
            style: KpbTextStyles.bodySm,
          ),
          const SizedBox(height: KpbSpacing.md),
          Container(
            padding: const EdgeInsets.all(KpbSpacing.md),
            decoration: BoxDecoration(
              color: KpbColors.skyLight,
              borderRadius: KpbRadius.mdBr,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'next_step'.tr,
                  style: KpbTextStyles.label,
                ),
                const SizedBox(height: 4),
                Text(
                  (_case['nextStepTitle'] as String?) ?? '',
                  style: KpbTextStyles.titleMd,
                ),
                const SizedBox(height: 4),
                Text(
                  (_case['nextStepDescription'] as String?) ?? '',
                  style: KpbTextStyles.bodySm,
                ),
              ],
            ),
          ),
          _moneyAndDeadlines(),
        ],
      ),
    );
  }

  // ── Argent & échéances (KPB-58): coût FCFA + prochaine échéance ─────────────
  Widget _moneyAndDeadlines() {
    final locale = Get.find<AppController>().localeCode;
    final displayedTuition = _tuitionEstimate(locale);
    final deadline = _nextDeadline();
    if (displayedTuition == null && deadline == null) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: KpbSpacing.md),
      child: Container(
        padding: const EdgeInsets.all(KpbSpacing.md),
        decoration: BoxDecoration(
          color: KpbColors.goldLight,
          borderRadius: KpbRadius.mdBr,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (displayedTuition != null) ...[
              Row(
                children: [
                  const Icon(Icons.savings_outlined,
                      size: 18, color: KpbColors.gold),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                        '${'parent_tuition_estimate'.tr} : $displayedTuition',
                        style: KpbTextStyles.bodySm),
                  ),
                ],
              ),
            ],
            if (deadline != null) ...[
              if (displayedTuition != null) const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.event_outlined,
                      size: 18, color: KpbColors.gold),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text('${'parent_next_deadline'.tr} : $deadline',
                        style: KpbTextStyles.bodySm),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 6),
            Text('parent_cost_note'.tr, style: KpbTextStyles.caption),
          ],
        ),
      ),
    );
  }

  String? _statusLabel() {
    final raw = (_case['status'] as String?) ?? '';
    final pair = _caseStatusLabels[raw];
    if (pair == null) return raw.isEmpty ? null : raw;
    return Get.find<AppController>().localeCode.startsWith('en')
        ? pair.$2
        : pair.$1;
  }

  String? _tuitionEstimate(String locale) {
    final countryId = (_case['requestedCountryId'] as String?) ?? '';
    if (countryId.isEmpty) return null;
    final country = Get.find<AppController>().countryByIdOrNull(countryId);
    if (country == null) return null;
    final suffix = TuitionUtils.displayFromTuition(
      country.tuitionRange.resolve(locale),
      Get.find<AppController>().profile?.preferredCurrency,
    );
    return suffix.isEmpty ? null : suffix;
  }

  String? _nextDeadline() {
    final d = DateTime.tryParse((_case['scheduledAt'] as String?) ?? '');
    if (d == null) return null;
    return '${d.day.toString().padLeft(2, '0')}/'
        '${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  Widget _timelineTile(dynamic raw) {
    final item = raw as Map<String, dynamic>;
    return Container(
      margin: const EdgeInsets.only(bottom: KpbSpacing.sm),
      padding: const EdgeInsets.all(KpbSpacing.md),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: KpbRadius.mdBr,
        boxShadow: KpbShadow.soft,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            (item['title'] as String?) ?? '',
            style: KpbTextStyles.titleMd,
          ),
          const SizedBox(height: 4),
          Text(
            (item['description'] as String?) ?? '',
            style: KpbTextStyles.bodySm,
          ),
        ],
      ),
    );
  }

  Widget _messageTile(dynamic raw) {
    final item = raw as Map<String, dynamic>;
    final isAdvisor = (item['senderRole'] as String?) != 'student';
    return Align(
      alignment: isAdvisor ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(bottom: KpbSpacing.sm),
        padding: const EdgeInsets.all(KpbSpacing.md),
        constraints: const BoxConstraints(maxWidth: 320),
        decoration: BoxDecoration(
          color: isAdvisor ? Colors.white : KpbColors.skyLight,
          borderRadius: KpbRadius.mdBr,
          boxShadow: KpbShadow.soft,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              (item['senderName'] as String?) ?? '',
              style: KpbTextStyles.label,
            ),
            const SizedBox(height: 4),
            Text(
              (item['body'] as String?) ?? '',
              style: KpbTextStyles.body,
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: KpbColors.blue.withValues(alpha: 0.12),
        borderRadius: KpbRadius.pillBr,
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: KpbColors.blue,
        ),
      ),
    );
  }
}
