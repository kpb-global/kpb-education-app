import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/controllers/app_controller.dart';
import '../../core/models/app_models.dart';
import '../../core/repositories/app_api_client.dart';
import '../../core/services/analytics_service.dart';
import '../../core/ui/kpb_components.dart';
import '../cases/case_composer_sheet.dart';
import 'scholarship_video_player_screen.dart';
import 'widgets/how_to_apply_sheet.dart';
import 'widgets/scholarship_alert_button.dart';

class ScholarshipDetailScreen extends StatefulWidget {
  const ScholarshipDetailScreen({
    super.key,
    required this.scholarshipId,
    this.initialScholarship,
    this.initialAlertEnabled = false,
    this.apiClient,
    this.onAlertChanged,
  });

  final String scholarshipId;
  final LiveScholarshipModel? initialScholarship;
  final bool initialAlertEnabled;
  final AppApiClient? apiClient;
  final ValueChanged<bool>? onAlertChanged;

  @override
  State<ScholarshipDetailScreen> createState() =>
      _ScholarshipDetailScreenState();
}

class _ScholarshipDetailScreenState extends State<ScholarshipDetailScreen> {
  late final AppApiClient _apiClient;
  LiveScholarshipModel? _scholarship;
  late bool _alertEnabled;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _apiClient = widget.apiClient ?? Get.find<AppController>().apiClient;
    _scholarship = widget.initialScholarship;
    _alertEnabled =
        widget.initialScholarship?.isAlertEnabled ?? widget.initialAlertEnabled;
    unawaited(
      AnalyticsService.instance.logViewScholarship(widget.scholarshipId),
    );
    unawaited(_load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = _scholarship == null;
      _error = null;
    });
    try {
      final language =
          Get.find<AppController>().profile?.preferredLanguage == 'en'
              ? 'en'
              : 'fr';
      final detail = await _apiClient.fetchLiveScholarshipDetailWithFallback(
        scholarshipId: widget.scholarshipId,
        lang: language,
        initial: _scholarship,
      );
      if (mounted) {
        setState(() {
          _scholarship = detail;
          if (detail?.isAlertEnabled != null) {
            _alertEnabled = detail!.isAlertEnabled!;
          }
        });
      }
      try {
        final alerts = await _apiClient.fetchScholarshipAlerts();
        if (mounted) {
          setState(() => _alertEnabled = alerts.contains(widget.scholarshipId));
        }
      } catch (_) {
        // Keep the initial state if alert reconciliation is temporarily offline.
      }
    } catch (exception) {
      if (mounted && _scholarship == null) {
        setState(() => _error = exception.toString());
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openUrl(String value) async {
    final uri = Uri.tryParse(value);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _setAlert(bool enabled) {
    setState(() => _alertEnabled = enabled);
    widget.onAlertChanged?.call(enabled);
  }

  void _openVideo(int index) {
    final scholarship = _scholarship;
    if (scholarship == null || scholarship.videos.isEmpty) return;
    Get.to(
      () => ScholarshipVideoPlayerScreen(
        scholarshipTitle: scholarship.title,
        videos: scholarship.videos,
        initialIndex: index,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scholarship = _scholarship;
    return Scaffold(
      backgroundColor: KpbColors.canvas,
      appBar: AppBar(
        title: Text('scholarship_detail_title'.tr),
        actions: [
          IconButton(
            tooltip: 'a11y_refresh'.tr,
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: scholarship == null
          ? _buildUnavailable()
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 36),
                children: [
                  _HeaderCard(scholarship: scholarship),
                  const SizedBox(height: 12),
                  ScholarshipAlertButton(
                    scholarshipId: scholarship.id,
                    scholarshipTitle: scholarship.title,
                    initialEnabled: _alertEnabled,
                    apiClient: _apiClient,
                    onChanged: _setAlert,
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: () => showHowToApplySheet(
                      context,
                      scholarshipTitle: scholarship.title,
                      steps: scholarship.applicationSteps,
                      onOpenOfficialForm: scholarship.applicationUrl.isEmpty
                          ? null
                          : () => _openUrl(scholarship.applicationUrl),
                    ),
                    icon: const Icon(Icons.format_list_numbered_rounded),
                    label: Text(
                      'live_scholarships_section_application_steps'.tr,
                    ),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                    ),
                  ),
                  if (scholarship.description.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _TextSection(
                      title: 'live_scholarships_section_description'.tr,
                      body: scholarship.description,
                    ),
                  ],
                  if (scholarship.advantages.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _BulletSection(
                      title: 'live_scholarships_section_advantages'.tr,
                      items: scholarship.advantages,
                      color: KpbColors.success,
                    ),
                  ],
                  if (scholarship.eligibility.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _BulletSection(
                      title: 'live_scholarships_section_eligibility'.tr,
                      items: scholarship.eligibility,
                      color: KpbColors.actionPrimary,
                    ),
                  ],
                  if (scholarship.keyRequirements.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _BulletSection(
                      title: 'live_scholarships_section_key_requirements'.tr,
                      items: scholarship.keyRequirements,
                      color: KpbColors.lawPurple,
                    ),
                  ],
                  if (scholarship.videos.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _VideosSection(
                      videos: scholarship.videos,
                      onOpen: _openVideo,
                    ),
                  ],
                  const SizedBox(height: 18),
                  if (scholarship.applicationUrl.isNotEmpty) ...[
                    FilledButton.icon(
                      onPressed: () => _openUrl(scholarship.applicationUrl),
                      icon: const Icon(Icons.open_in_new_rounded),
                      label: Text('live_scholarships_official_form'.tr),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(50),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                  OutlinedButton(
                    onPressed: () => showModalBottomSheet<void>(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (_) => CaseComposerSheet(
                        caseType: CaseType.scholarshipSupport,
                        title: scholarship.title,
                        contextLabel: scholarship.countryName,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(50),
                    ),
                    child: Text('live_scholarships_apply_with_kpb'.tr),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildUnavailable() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    return Center(
      child: KpbEmptyState(
        icon:
            _error == null ? Icons.search_off_rounded : Icons.wifi_off_rounded,
        title: _error == null
            ? 'scholarship_detail_not_found'.tr
            : 'live_scholarships_connection_error_title'.tr,
        subtitle: _error == null
            ? 'scholarship_detail_not_found_body'.tr
            : 'live_scholarships_connection_error_subtitle'.tr,
        action: KpbButton(text: 'retry'.tr, onPressed: _load),
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.scholarship});

  final LiveScholarshipModel scholarship;

  @override
  Widget build(BuildContext context) {
    final cycle = scholarship.currentCycle;
    final deadline = cycle?.closesAt ?? scholarship.deadlineAt;
    final funding = scholarship.isFullyFunded
        ? 'live_scholarships_fully_funded'.tr
        : scholarship.isPartiallyFunded
            ? 'live_scholarships_partially_funded'.tr
            : 'live_scholarships_funding_unknown'.tr;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: KpbColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(
                    scholarship.title,
                    style: const TextStyle(
                      color: KpbColors.brandNavy,
                      fontSize: 21,
                      height: 1.2,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GetBuilder<AppController>(
                builder: (controller) {
                  final saved = controller.isSaved(
                    SavedItemType.scholarship,
                    scholarship.id,
                  );
                  return IconButton.filledTonal(
                    tooltip: 'a11y_save'.tr,
                    onPressed: () => controller.toggleSaved(
                      SavedItemType.scholarship,
                      scholarship.id,
                    ),
                    icon: Icon(
                      saved
                          ? Icons.bookmark_rounded
                          : Icons.bookmark_outline_rounded,
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            [
              scholarship.countryName,
              scholarship.level,
            ].where((value) => value.isNotEmpty).join(' · '),
            style: const TextStyle(color: KpbColors.textMuted),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _MetaTile(
                  label: 'live_scholarships_funding_tile'.tr,
                  value: funding,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MetaTile(
                  label: 'live_scholarships_deadline_label'.tr,
                  value: deadline == null
                      ? (scholarship.deadlineLabel.isEmpty
                          ? 'live_scholarships_no_deadline'.tr
                          : scholarship.deadlineLabel)
                      : _formatDate(deadline),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final local = date.toLocal();
    return '${local.day.toString().padLeft(2, '0')}/'
        '${local.month.toString().padLeft(2, '0')}/${local.year}';
  }
}

class _MetaTile extends StatelessWidget {
  const _MetaTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: KpbColors.canvas,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label.toUpperCase(),
              style: const TextStyle(
                fontSize: 9.5,
                color: KpbColors.textFaint,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                color: KpbColors.brandNavy,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      );
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: KpbColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              header: true,
              child: Text(
                title,
                style: const TextStyle(
                  color: KpbColors.brandNavy,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      );
}

class _TextSection extends StatelessWidget {
  const _TextSection({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) => _SectionCard(
        title: title,
        child: Text(
          body,
          style: const TextStyle(
            color: KpbColors.gray700,
            fontSize: 13,
            height: 1.55,
          ),
        ),
      );
}

class _BulletSection extends StatelessWidget {
  const _BulletSection({
    required this.title,
    required this.items,
    required this.color,
  });

  final String title;
  final List<String> items;
  final Color color;

  @override
  Widget build(BuildContext context) => _SectionCard(
        title: title,
        child: Column(
          children: [
            for (final item in items)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 1, right: 10),
                      child: Icon(
                        Icons.check_circle_rounded,
                        size: 17,
                        color: color,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        item,
                        style: const TextStyle(
                          color: KpbColors.gray700,
                          fontSize: 12.5,
                          height: 1.45,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      );
}

class _VideosSection extends StatelessWidget {
  const _VideosSection({required this.videos, required this.onOpen});

  final List<ScholarshipVideoModel> videos;
  final ValueChanged<int> onOpen;

  @override
  Widget build(BuildContext context) => _SectionCard(
        title: 'scholarship_videos_title'.tr,
        child: SizedBox(
          height: 168,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: videos.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final video = videos[index];
              final title = video.title.isEmpty
                  ? 'scholarship_video_explanation'.tr
                  : video.title;
              return Semantics(
                button: true,
                label: '${'scholarship_video_play'.tr}: $title',
                child: SizedBox(
                  width: 220,
                  child: Card(
                    clipBehavior: Clip.antiAlias,
                    margin: EdgeInsets.zero,
                    child: InkWell(
                      onTap: () => onOpen(index),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Stack(
                            alignment: Alignment.center,
                            children: [
                              SizedBox(
                                height: 112,
                                child: KpbNetworkImage(
                                  imageUrl: video.effectiveThumbnailUrl,
                                  targetWidth: 440,
                                  placeholderIcon:
                                      Icons.play_circle_outline_rounded,
                                ),
                              ),
                              Container(
                                width: 44,
                                height: 44,
                                decoration: const BoxDecoration(
                                  color: Colors.black87,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.play_arrow_rounded,
                                  color: Colors.white,
                                  size: 28,
                                ),
                              ),
                            ],
                          ),
                          Padding(
                            padding: const EdgeInsets.all(10),
                            child: Text(
                              title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11.5,
                                height: 1.25,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      );
}
