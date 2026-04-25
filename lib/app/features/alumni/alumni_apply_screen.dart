import 'package:flutter/material.dart';

import '../../core/repositories/app_api_client.dart';

/// Alumni self-application form (Phase 3).
///
/// A student who was admitted uploads proof (admission letter / diploma
/// scan URL — we don't re-host it; they paste a link to Drive / Dropbox /
/// their KPB storage bucket) and submits for admin review. Once approved,
/// they show up in the public alumni directory with a verified badge.
class AlumniApplyScreen extends StatefulWidget {
  const AlumniApplyScreen({super.key});

  @override
  State<AlumniApplyScreen> createState() => _AlumniApplyScreenState();
}

class _AlumniApplyScreenState extends State<AlumniApplyScreen> {
  final _formKey = GlobalKey<FormState>();
  final _api = AppApiClient();

  final _universityCtrl = TextEditingController();
  final _programmeCtrl = TextEditingController();
  final _yearCtrl = TextEditingController();
  final _countryCtrl = TextEditingController();
  final _proofUrlCtrl = TextEditingController();
  final _bioCtrl = TextEditingController();

  bool _loading = false;
  bool _loadingStatus = true;
  String? _currentStatus;

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  @override
  void dispose() {
    _universityCtrl.dispose();
    _programmeCtrl.dispose();
    _yearCtrl.dispose();
    _countryCtrl.dispose();
    _proofUrlCtrl.dispose();
    _bioCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadStatus() async {
    try {
      final me = await _api.getMyAlumniStatus();
      if (!mounted) return;
      setState(() {
        _currentStatus = me['alumniStatus'] as String?;
        _universityCtrl.text = (me['alumniUniversity'] as String?) ?? '';
        _programmeCtrl.text = (me['alumniProgramme'] as String?) ?? '';
        _yearCtrl.text = (me['alumniGraduationYear']?.toString()) ?? '';
        _countryCtrl.text = (me['alumniCountryCode'] as String?) ?? '';
        _bioCtrl.text = (me['alumniBioFr'] as String?) ?? '';
        _loadingStatus = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingStatus = false);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await _api.applyAsAlumni(
        university: _universityCtrl.text.trim(),
        programme: _programmeCtrl.text.trim(),
        graduationYear: int.parse(_yearCtrl.text.trim()),
        proofUrl: _proofUrlCtrl.text.trim(),
        countryCode: _countryCtrl.text.trim().isEmpty
            ? null
            : _countryCtrl.text.trim().toUpperCase(),
        bioFr: _bioCtrl.text.trim().isEmpty ? null : _bioCtrl.text.trim(),
      );
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Candidature envoyée. Un admin examinera ton dossier sous 48h.',
          ),
        ),
      );
      Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Impossible d'envoyer la candidature pour l'instant."),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Devenir mentor alumni')),
      body: _loadingStatus
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_currentStatus != null && _currentStatus != 'none')
                      _StatusBanner(status: _currentStatus!),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _universityCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Université / école',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Requis'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _programmeCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Programme / filière',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Requis'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _yearCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: "Année d'admission / diplôme",
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) {
                        final y = int.tryParse((v ?? '').trim());
                        if (y == null) return 'Année invalide';
                        if (y < 1980 || y > DateTime.now().year + 10) {
                          return 'Année hors plage';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _countryCtrl,
                      decoration: const InputDecoration(
                        labelText: "Pays de l'université (code ISO, ex. FR, CA)",
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _proofUrlCtrl,
                      decoration: const InputDecoration(
                        labelText: "Lien vers l'admission / le diplôme",
                        helperText:
                            "Google Drive, Dropbox, ou autre lien public",
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Requis pour la vérification'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _bioCtrl,
                      minLines: 3,
                      maxLines: 6,
                      decoration: const InputDecoration(
                        labelText: 'Bio courte (facultatif)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: _loading ? null : _submit,
                      child: _loading
                          ? const SizedBox(
                              height: 16,
                              width: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Envoyer ma candidature'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    late final String msg;
    late final Color color;
    switch (status) {
      case 'pending':
        msg = 'Ta candidature est en attente de vérification.';
        color = Colors.orange.shade100;
        break;
      case 'approved':
        msg = 'Tu es vérifié comme alumni. Ton badge est visible.';
        color = Colors.green.shade100;
        break;
      case 'rejected':
        msg = 'Ta dernière candidature a été refusée. Tu peux la renvoyer.';
        color = Colors.red.shade100;
        break;
      default:
        msg = '';
        color = Colors.transparent;
    }
    if (msg.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(msg),
    );
  }
}
