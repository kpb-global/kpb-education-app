import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/config/app_routes.dart';
import '../../core/controllers/app_controller.dart';
import '../../core/data/match_api_codec.dart';
import '../../core/models/app_models.dart';
import '../../core/ui/kpb_components.dart';

/// Post-onboarding AHA moment (Phase 0 / P0-D — kit US-003): the first thing
/// a student sees after completing their profile is where their chances are
/// best, with an explainable admission probability per school.
///
/// Primary source is the backend `GET /matches/aha-moment` (deterministic
/// algorithm v1). If the call fails (offline, guest token edge, server down),
/// the screen degrades to the local AppSearchService affinity score so the
/// reveal never dead-ends — those fallback results are flagged as estimates.
class AhaMomentScreen extends StatefulWidget {
  const AhaMomentScreen({super.key});

  @override
  State<AhaMomentScreen> createState() => _AhaMomentScreenState();
}

class _AhaMomentScreenState extends State<AhaMomentScreen> {
  final AppController _ctrl = Get.find<AppController>();

  bool _loading = true;
  List<SchoolMatch> _matches = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    List<SchoolMatch> matches;
    try {
      final json = await _ctrl.apiClient.getAhaMatches();
      matches = MatchApiCodec.ahaMatchesFromApi(json);
    } catch (_) {
      matches = const [];
    }
    if (matches.isEmpty) {
      matches = _localFallback();
    }
    if (!mounted) return;
    setState(() {
      _matches = matches;
      _loading = false;
    });
  }

  /// Offline/degraded path: reuse the local affinity score (0–98) and map it
  /// onto match zones through the MatchBadge thresholds (80/60).
  List<SchoolMatch> _localFallback() {
    final institutions = _ctrl.recommendedInstitutions.take(3);
    return institutions.map((institution) {
      final score = _ctrl.institutionMatch(institution);
      return SchoolMatch(
        institutionId: institution.id,
        institutionName: institution.name,
        programId: '',
        programName: const LocalizedText(fr: '', en: ''),
        probability: score / 100,
        zone: score >= 80
            ? SchoolMatchZone.green
            : score >= 60
                ? SchoolMatchZone.yellow
                : SchoolMatchZone.blue,
        isEstimate: true,
        algorithmVersion: 'local',
        factors: const [],
        narrative: const LocalizedText(fr: '', en: ''),
      );
    }).toList();
  }

  void _goHome() => Get.offAllNamed(AppRoutes.home);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.kpb.pageBg,
      body: SafeArea(
        child: _loading
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: KpbSpacing.md),
                    Text('aha_loading'.tr, style: KpbTextStyles.bodySm),
                  ],
                ),
              )
            : Padding(
                padding: const EdgeInsets.all(KpbSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: KpbSpacing.lg),
                    const Icon(
                      Icons.auto_awesome_rounded,
                      size: 48,
                      color: KpbColors.gold,
                    ),
                    const SizedBox(height: KpbSpacing.md),
                    Text(
                      'aha_title'.tr,
                      style: KpbTextStyles.headline,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: KpbSpacing.sm),
                    Text(
                      _matches.isEmpty
                          ? 'aha_empty_body'.tr
                          : 'aha_subtitle'.tr,
                      style: KpbTextStyles.bodySm,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: KpbSpacing.lg),
                    Expanded(
                      child: ListView.separated(
                        itemCount: _matches.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: KpbSpacing.md),
                        itemBuilder: (context, index) =>
                            _MatchCard(match: _matches[index]),
                      ),
                    ),
                    if (_matches.any((m) => m.isEstimate)) ...[
                      const SizedBox(height: KpbSpacing.sm),
                      Text(
                        'aha_estimate_note'.tr,
                        style: KpbTextStyles.caption,
                        textAlign: TextAlign.center,
                      ),
                    ],
                    const SizedBox(height: KpbSpacing.md),
                    FilledButton(
                      onPressed: _goHome,
                      child: Text('aha_cta'.tr),
                    ),
                    const SizedBox(height: KpbSpacing.sm),
                  ],
                ),
              ),
      ),
    );
  }
}

class _MatchCard extends StatelessWidget {
  const _MatchCard({required this.match});

  final SchoolMatch match;

  String get _zoneKey => switch (match.zone) {
        SchoolMatchZone.green => 'aha_zone_green',
        SchoolMatchZone.yellow => 'aha_zone_yellow',
        SchoolMatchZone.blue => 'aha_zone_blue',
      };

  @override
  Widget build(BuildContext context) {
    final locale = Get.find<AppController>().localeCode;
    final institutionName = match.institutionName.resolve(locale);
    final programName = match.programName.resolve(locale);
    final narrative = match.narrative.resolve(locale);

    return Container(
      padding: const EdgeInsets.all(KpbSpacing.md),
      decoration: BoxDecoration(
        color: context.kpb.cardBg,
        borderRadius: KpbRadius.lgBr,
        border: Border.all(color: context.kpb.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  institutionName,
                  style: KpbTextStyles.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: KpbSpacing.sm),
              MatchBadge(score: match.probabilityPercent),
            ],
          ),
          if (programName.isNotEmpty) ...[
            const SizedBox(height: KpbSpacing.xs),
            Text(
              programName,
              style: KpbTextStyles.bodySm,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: KpbSpacing.xs),
          Text(_zoneKey.tr, style: KpbTextStyles.caption),
          if (narrative.isNotEmpty) ...[
            const SizedBox(height: KpbSpacing.sm),
            Text(narrative, style: KpbTextStyles.bodySm),
          ],
        ],
      ),
    );
  }
}
