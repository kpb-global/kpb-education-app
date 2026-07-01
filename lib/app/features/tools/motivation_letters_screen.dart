import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/controllers/app_controller.dart';
import '../../core/ui/kpb_components.dart';
import 'motivation_letter_templates.dart';

/// Motivation Letters — browse templates, personalise with AI (FR + EN).
class MotivationLettersScreen extends StatefulWidget {
  const MotivationLettersScreen({super.key});

  @override
  State<MotivationLettersScreen> createState() =>
      _MotivationLettersScreenState();
}

class _MotivationLettersScreenState extends State<MotivationLettersScreen> {
  String _selectedCategory = 'all';

  List<LetterTemplate> get _filtered => _selectedCategory == 'all'
      ? kLetterTemplates
      : kLetterTemplates.where((t) => t.category == _selectedCategory).toList();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('letters_title'.tr)),
      body: Column(
        children: [
          // ── Category chips ─────────────────────────────────────────────────
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(
                horizontal: KpbSpacing.pagePad, vertical: KpbSpacing.sm),
            child: Row(
              children: [
                _chip('all', 'letters_filter_all'.tr),
                ...kLetterCategories.map(
                  (c) => _chip(c, categoryLabelFr(c)),
                ),
              ],
            ),
          ),

          // ── Templates list ─────────────────────────────────────────────────
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(KpbSpacing.pagePad),
              itemCount: _filtered.length,
              separatorBuilder: (_, __) =>
                  const SizedBox(height: KpbSpacing.sm),
              itemBuilder: (ctx, i) {
                final t = _filtered[i];
                return _LetterCard(template: t);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String value, String label) {
    final selected = _selectedCategory == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => setState(() => _selectedCategory = value),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Single letter card — expand to preview, personalise with AI
// ─────────────────────────────────────────────────────────────────────────────

class _LetterCard extends StatefulWidget {
  const _LetterCard({required this.template});
  final LetterTemplate template;

  @override
  State<_LetterCard> createState() => _LetterCardState();
}

class _LetterCardState extends State<_LetterCard> {
  final _ctrl = Get.find<AppController>();
  bool _expanded = false;
  bool _isPersonalizing = false;
  String _personalizedFr = '';
  String _personalizedEn = '';
  bool _showEnglish = false;

  IconData get _categoryIcon {
    switch (widget.template.category) {
      case 'admission':
        return Icons.school_rounded;
      case 'scholarship':
        return Icons.emoji_events_rounded;
      case 'visa':
        return Icons.flight_takeoff_rounded;
      case 'internship':
        return Icons.work_outline_rounded;
      default:
        return Icons.description_rounded;
    }
  }

  Future<void> _personalize() async {
    setState(() => _isPersonalizing = true);
    try {
      final p = _ctrl.profile;
      final fieldId = p?.fieldIds.isNotEmpty == true ? p!.fieldIds.first : '';
      final field = _ctrl.fields
              .where((f) => f.id == fieldId)
              .map((f) => _ctrl.resolve(f.name))
              .firstOrNull ??
          '';
      final targetId = p?.targetCountryIds.isNotEmpty == true
          ? p!.targetCountryIds.first
          : '';
      final country = _ctrl.countries
              .where((c) => c.id == targetId)
              .map((c) => _ctrl.resolve(c.name))
              .firstOrNull ??
          '';

      final result = await _ctrl.apiClient.post('tools/personalize-letter', {
        'templateKey': widget.template.key,
        'templateBody': widget.template.bodyFr,
        'name': p?.fullName ?? '',
        'fieldOfStudy': field,
        'targetCountry': country,
      });

      if (mounted) {
        setState(() {
          _personalizedFr = result['fr'] as String? ?? '';
          _personalizedEn = result['en'] as String? ?? '';
        });
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('tools_ai_error_check_connection'.tr)),
        );
      }
    } finally {
      if (mounted) setState(() => _isPersonalizing = false);
    }
  }

  String get _displayText {
    if (_personalizedFr.isNotEmpty || _personalizedEn.isNotEmpty) {
      return _showEnglish
          ? (_personalizedEn.isNotEmpty ? _personalizedEn : _personalizedFr)
          : (_personalizedFr.isNotEmpty ? _personalizedFr : _personalizedEn);
    }
    return widget.template.bodyFr;
  }

  @override
  Widget build(BuildContext context) {
    return KpbCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: KpbRadius.lgBr,
            child: Row(
              children: [
                Icon(_categoryIcon, color: KpbColors.blue, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.template.titleFr,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: context.kpb.textPrimary,
                        ),
                      ),
                      Text(
                        widget.template.titleEn,
                        style: TextStyle(
                          fontSize: 12,
                          color: context.kpb.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  _expanded
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                  color: context.kpb.textMuted,
                ),
              ],
            ),
          ),

          // Expanded body
          if (_expanded) ...[
            const SizedBox(height: KpbSpacing.md),

            // Language toggle (only if personalised)
            if (_personalizedFr.isNotEmpty || _personalizedEn.isNotEmpty)
              Row(
                children: [
                  ChoiceChip(
                    label: const Text('FR'),
                    selected: !_showEnglish,
                    onSelected: (_) => setState(() => _showEnglish = false),
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('EN'),
                    selected: _showEnglish,
                    onSelected: (_) => setState(() => _showEnglish = true),
                  ),
                  const Spacer(),
                  if (_personalizedFr.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: KpbColors.blue.withValues(alpha: 0.1),
                        borderRadius: KpbRadius.smBr,
                      ),
                      child: Text(
                        'letters_personalized_badge'.tr,
                        style: TextStyle(fontSize: 11, color: KpbColors.blue),
                      ),
                    ),
                ],
              ),

            if (_personalizedFr.isNotEmpty || _personalizedEn.isNotEmpty)
              const SizedBox(height: KpbSpacing.sm),

            // Letter body
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: context.kpb.cardBg,
                borderRadius: KpbRadius.mdBr,
              ),
              child: SelectableText(
                _displayText,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.6,
                  color: context.kpb.textPrimary,
                ),
              ),
            ),

            const SizedBox(height: KpbSpacing.md),

            // Action buttons
            Row(
              children: [
                Expanded(
                  child: KpbButton(
                    label: _isPersonalizing
                        ? 'letters_personalizing'.tr
                        : 'letters_adapt_to_profile'.tr,
                    icon: Icons.auto_awesome_rounded,
                    onTap: _isPersonalizing ? null : _personalize,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'letters_copy_tooltip'.tr,
                  icon: const Icon(Icons.copy_rounded, size: 20),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: _displayText));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('letters_copied_snackbar'.tr)),
                    );
                  },
                ),
                IconButton(
                  tooltip: 'letters_share_tooltip'.tr,
                  icon: const Icon(Icons.share_rounded, size: 20),
                  onPressed: () => SharePlus.instance.share(
                    ShareParams(text: _displayText),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
