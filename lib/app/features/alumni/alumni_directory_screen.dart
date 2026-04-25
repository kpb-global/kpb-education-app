import 'package:flutter/material.dart';

import '../../core/repositories/app_api_client.dart';

/// Verified alumni mentor directory (Phase 3).
///
/// Students who got admitted show up here with a badge. Word-of-mouth is
/// KPB's best acquisition channel in francophone West Africa — seeing a
/// peer from the same country who made it into a European / Canadian
/// programme is more persuasive than any marketing copy.
///
/// Listing shows name + university + programme + graduation year + country.
/// No direct-message endpoint yet — community DM is Phase 4.
class AlumniDirectoryScreen extends StatefulWidget {
  const AlumniDirectoryScreen({super.key});

  @override
  State<AlumniDirectoryScreen> createState() => _AlumniDirectoryScreenState();
}

class _AlumniDirectoryScreenState extends State<AlumniDirectoryScreen> {
  final AppApiClient _api = AppApiClient();
  final _searchController = TextEditingController();

  bool _loading = true;
  String? _error;
  List<dynamic> _alumni = const [];
  String? _countryFilter;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await _api.listAlumni(
        country: _countryFilter,
        university: _searchController.text.trim().isEmpty
            ? null
            : _searchController.text.trim(),
      );
      if (!mounted) return;
      setState(() {
        _alumni = items;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Impossible de charger les mentors. Vérifie ta connexion.';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mentors KPB — Alumni')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _load(),
              decoration: InputDecoration(
                hintText: 'Rechercher par université…',
                prefixIcon: const Icon(Icons.search),
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _load,
                ),
              ),
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _load,
              child: _buildBody(),
            ),
          ),
        ],
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
    if (_alumni.isEmpty) {
      return ListView(
        children: const [
          Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              "Aucun mentor vérifié ne correspond à cette recherche pour l'instant.",
              textAlign: TextAlign.center,
            ),
          ),
        ],
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _alumni.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, i) =>
          _AlumnusCard(a: _alumni[i] as Map<String, dynamic>),
    );
  }
}

class _AlumnusCard extends StatelessWidget {
  const _AlumnusCard({required this.a});

  final Map<String, dynamic> a;

  @override
  Widget build(BuildContext context) {
    final name = (a['fullName'] as String?) ?? '';
    final university = (a['alumniUniversity'] as String?) ?? '';
    final programme = (a['alumniProgramme'] as String?) ?? '';
    final year = a['alumniGraduationYear'] as int?;
    final country = (a['alumniCountryCode'] as String?) ?? '';
    final bio = (a['alumniBioFr'] as String?) ?? '';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  child: Text(
                    name.isNotEmpty ? name.characters.first.toUpperCase() : '?',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              name,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                          const Chip(
                            visualDensity: VisualDensity.compact,
                            avatar: Icon(Icons.verified, size: 16),
                            label: Text('Alumni vérifié'),
                          ),
                        ],
                      ),
                      if (university.isNotEmpty)
                        Text(
                          [university, if (year != null) '$year']
                              .where((s) => s.isNotEmpty)
                              .join(' • '),
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                    ],
                  ),
                ),
              ],
            ),
            if (programme.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('Programme : $programme',
                  style: Theme.of(context).textTheme.bodySmall),
            ],
            if (country.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text('Pays : $country',
                  style: Theme.of(context).textTheme.bodySmall),
            ],
            if (bio.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(bio),
            ],
          ],
        ),
      ),
    );
  }
}
