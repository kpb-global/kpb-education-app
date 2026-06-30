import 'package:flutter/material.dart';

import '../../core/repositories/app_api_client.dart';
import '../../core/utils/whatsapp_utils.dart';

/// "Dossier prêt" + scholarship / visa prep kits catalog (Phase 3).
///
/// This is the SKU that anchors KPB's monetization: fixed-price bundles
/// (10k–25k FCFA) where we review CV, motivation and recommendation
/// letters in FR + EN before submission. Parents have a concrete, tangible
/// thing to pay for.
///
/// The screen splits the catalog by category and opens a WhatsApp-assisted
/// sales flow. The CTA first creates a pending [ServicePurchase] row, then
/// opens WhatsApp so ops can collect payment and advance delivery manually.
class ServicePackagesScreen extends StatefulWidget {
  const ServicePackagesScreen({
    super.key,
    this.caseId,
    this.caseReference,
    this.source = 'service_package_whatsapp',
  });

  final String? caseId;
  final String? caseReference;
  final String source;

  @override
  State<ServicePackagesScreen> createState() => _ServicePackagesScreenState();
}

class _ServicePackagesScreenState extends State<ServicePackagesScreen> {
  final AppApiClient _api = AppApiClient();
  bool _loading = true;
  String? _error;
  List<dynamic> _packages = const [];

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
      final items = await _api.listServicePackages();
      if (!mounted) return;
      setState(() {
        _packages = items;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Impossible de charger la liste. Vérifie ta connexion.';
        _loading = false;
      });
    }
  }

  Future<void> _requestOnWhatsApp(Map<String, dynamic> pkg) async {
    final code = pkg['code'] as String?;
    if (code == null) return;

    try {
      final result = await _api.requestServicePackageViaWhatsApp(
        packageCode: code,
        caseId: widget.caseId,
        source: widget.source,
      );
      final purchaseId = result['id'] as String? ?? '';
      final name = (pkg['nameFr'] as String?) ?? code;
      final price = (pkg['priceXOF'] as num?)?.toInt() ?? 0;
      final dossier = widget.caseReference?.trim().isNotEmpty == true
          ? widget.caseReference!.trim()
          : 'non rattaché';

      await openWhatsAppOrToast(
        prefill: [
          'Bonjour KPB, je souhaite réserver le service $name.',
          'SKU : $code.',
          'Prix : ${_PackageCard.formatFcfa(price)} FCFA.',
          if (purchaseId.isNotEmpty) 'Référence demande : $purchaseId.',
          'Dossier : $dossier.',
        ].join('\n'),
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Demande créée. Un conseiller suivra le paiement.'),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Impossible de créer la demande WhatsApp.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Services KPB')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return ListView(
        children: [
          Padding(
            padding: const EdgeInsets.all(24),
            child: Text(_error!, textAlign: TextAlign.center),
          ),
        ],
      );
    }
    if (_packages.isEmpty) {
      return ListView(
        children: const [
          Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Aucun service disponible pour le moment.',
              textAlign: TextAlign.center,
            ),
          ),
        ],
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _packages.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, i) => _PackageCard(
        pkg: _packages[i] as Map<String, dynamic>,
        onBuy: _requestOnWhatsApp,
      ),
    );
  }
}

class _PackageCard extends StatelessWidget {
  const _PackageCard({required this.pkg, required this.onBuy});

  final Map<String, dynamic> pkg;
  final Future<void> Function(Map<String, dynamic>) onBuy;

  @override
  Widget build(BuildContext context) {
    final name = (pkg['nameFr'] as String?) ?? '';
    final summary = (pkg['summaryFr'] as String?) ?? '';
    final price = (pkg['priceXOF'] as num?)?.toInt() ?? 0;
    final turnaround = (pkg['turnaroundFr'] as String?) ?? '';
    final deliverables =
        (pkg['deliverablesFr'] as List<dynamic>? ?? const []).cast<String>();
    final category = (pkg['category'] as String?) ?? '';

    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    name,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                Chip(label: Text(_categoryLabel(category))),
              ],
            ),
            const SizedBox(height: 8),
            Text(summary, style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 12),
            Text(
              '${formatFcfa(price)} FCFA',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            if (turnaround.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text('Délai : $turnaround',
                  style: Theme.of(context).textTheme.bodySmall),
            ],
            if (deliverables.isNotEmpty) ...[
              const SizedBox(height: 12),
              ...deliverables.map(
                (d) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('•  '),
                      Expanded(child: Text(d)),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                icon: const Icon(Icons.payments),
                label: const Text('Réserver sur WhatsApp'),
                onPressed: () => onBuy(pkg),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _categoryLabel(String raw) {
    switch (raw) {
      case 'dossier_pret':
        return 'Dossier prêt';
      case 'scholarship_kit':
        return 'Kit bourse';
      case 'visa_kit':
        return 'Kit visa';
      case 'consultation':
        return 'Consultation';
      default:
        return 'Service';
    }
  }

  static String formatFcfa(int value) {
    // Group thousands with a non-breaking space — matches local convention.
    final s = value.toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write('\u00A0');
      buf.write(s[i]);
    }
    return buf.toString();
  }
}
