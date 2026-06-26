import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/repositories/app_api_client.dart';
import '../../core/ui/app_tokens.dart';
import '../../core/utils/whatsapp_utils.dart';

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
    // No in-app payment: a parent who wants to act on the case is routed to a
    // KPB advisor on WhatsApp, pre-filled with the case title for context.
    final title = (_case['title'] as String?)?.trim();
    final prefill = title != null && title.isNotEmpty
        ? 'Bonjour, je suis le parent et je souhaite échanger au sujet du dossier « $title » sur KPB Education.'
        : 'Bonjour, je suis le parent et je souhaite échanger au sujet du dossier de mon enfant sur KPB Education.';
    await openWhatsAppOrToast(prefill: prefill);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KpbColors.bgPage,
      appBar: AppBar(
        title: const Text('Dossier (lecture)'),
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
            padding: EdgeInsets.only(left: KpbSpacing.xs, bottom: KpbSpacing.sm),
            child: Text('Historique', style: KpbTextStyles.label),
          ),
          ...timeline.take(6).map(_timelineTile),
          const SizedBox(height: KpbSpacing.lg),
        ],
        if (messages.isNotEmpty) ...[
          Padding(
            padding: EdgeInsets.only(left: KpbSpacing.xs, bottom: KpbSpacing.sm),
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
          Text((_case['title'] as String?) ?? '', style: KpbTextStyles.title),
          const SizedBox(height: KpbSpacing.xs),
          Text(
            (_case['contextLabel'] as String?) ?? '',
            style: KpbTextStyles.bodySm,
          ),
          const SizedBox(height: KpbSpacing.md),
          Container(
            padding: const EdgeInsets.all(KpbSpacing.md),
            decoration: const BoxDecoration(
              color: KpbColors.skyLight,
              borderRadius: KpbRadius.mdBr,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Prochaine étape',
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
        ],
      ),
    );
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
