import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/repositories/app_api_client.dart';
import '../../core/ui/app_tokens.dart';

/// Read-only case view for linked parents (Track C1). The student has opted
/// in to share the case (`parentCanView = true` on the case). We show:
/// - Title, context, current status, next-step copy
/// - Timeline (read-only)
/// - Last few messages (read-only — parent can't post)
/// - A prominent "Payer" button that routes to the hosted checkout page.
///
/// Scope is deliberately narrow — the parent's job here is to pay and stay
/// informed, not to operate the case. Advisor chat stays with the student.
class ParentCaseViewScreen extends StatefulWidget {
  const ParentCaseViewScreen({super.key, required this.caseId});

  final String caseId;

  @override
  State<ParentCaseViewScreen> createState() => _ParentCaseViewScreenState();
}

class _ParentCaseViewScreenState extends State<ParentCaseViewScreen> {
  late final AppApiClient _api = AppApiClient();
  bool _loading = true;
  bool _paying = false;
  String? _error;
  Map<String, dynamic> _case = const {};
  List<String> _providers = const [];

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
      final results = await Future.wait([
        _api.getParentVisibleCase(widget.caseId),
        _api.listPaymentProviders().catchError((_) => <String>[]),
      ]);
      if (!mounted) return;
      setState(() {
        _case = results[0] as Map<String, dynamic>;
        _providers = results[1] as List<String>;
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

  Future<void> _payPressed() async {
    if (_providers.isEmpty) {
      _toast('Aucun moyen de paiement disponible.');
      return;
    }
    // Pick the first configured provider automatically — adding a picker here
    // would be a UX step too many for a parent who just wants to pay.
    final provider = _providers.first;
    setState(() => _paying = true);
    try {
      final intent = await _api.createPaymentIntent(
        provider: provider,
        // Default to a 25,000 XOF advisor consultation deposit. Real amount
        // should come from the case's pending invoice — stubbed for Phase 1.
        amountMinor: 25000,
        currency: 'XOF',
        caseId: widget.caseId,
        description: 'KPB Education — consultation',
        returnUrl: 'https://kpb-education.com/pay/success',
        cancelUrl: 'https://kpb-education.com/pay/cancel',
      );
      final url = intent['checkoutUrl'] as String?;
      if (url != null && url.isNotEmpty) {
        await launchUrl(
          Uri.parse(url),
          mode: LaunchMode.externalApplication,
        );
      } else {
        _toast('Lien de paiement indisponible.');
      }
    } catch (_) {
      _toast('Paiement impossible pour le moment.');
    } finally {
      if (mounted) setState(() => _paying = false);
    }
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
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
                    icon: _paying
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.payments_rounded),
                    label: Text(_paying ? 'Ouverture…' : 'Payer'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: KpbColors.success,
                      foregroundColor: Colors.white,
                      textStyle: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    onPressed: _paying ? null : _payPressed,
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
          const Padding(
            padding:
                EdgeInsets.only(left: KpbSpacing.xs, bottom: KpbSpacing.sm),
            child: Text('Derniers échanges', style: KpbTextStyles.label),
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
