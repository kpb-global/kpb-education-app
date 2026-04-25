import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/repositories/app_api_client.dart';

/// "Dossier prêt" + scholarship / visa prep kits catalog (Phase 3).
///
/// This is the SKU that anchors KPB's monetization: fixed-price bundles
/// (10k–25k FCFA) where we review CV, motivation and recommendation
/// letters in FR + EN before submission. Parents have a concrete, tangible
/// thing to pay for.
///
/// The screen splits the catalog by category and opens a purchase flow
/// via [AppApiClient.purchaseServicePackage], which creates a PaymentIntent
/// and returns the provider-hosted checkout URL (CinetPay / Paydunya).
class ServicePackagesScreen extends StatefulWidget {
  const ServicePackagesScreen({super.key});

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

  Future<void> _purchase(Map<String, dynamic> pkg) async {
    final code = pkg['code'] as String?;
    if (code == null) return;
    // Deep-link the CinetPay/Paydunya return journey back into the app.
    const returnUrl = 'kpb://payment/success';
    const cancelUrl = 'kpb://payment/cancel';

    try {
      final result = await _api.purchaseServicePackage(
        packageCode: code,
        returnUrl: returnUrl,
        cancelUrl: cancelUrl,
      );
      final intent = result['paymentIntent'] as Map<String, dynamic>?;
      final checkoutUrl = intent?['checkoutUrl'] as String?;
      if (checkoutUrl == null || checkoutUrl.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Paiement préparé. Un conseiller te contactera.'),
          ),
        );
        return;
      }
      final uri = Uri.parse(checkoutUrl);
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Impossible de démarrer le paiement.'),
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
      itemBuilder: (context, i) =>
          _PackageCard(pkg: _packages[i] as Map<String, dynamic>, onBuy: _purchase),
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
              '${_formatFcfa(price)} FCFA',
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
                label: const Text('Payer maintenant'),
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

  static String _formatFcfa(int value) {
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
