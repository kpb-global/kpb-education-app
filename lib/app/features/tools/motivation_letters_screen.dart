import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/controllers/app_controller.dart';
import 'motivation_letter_templates.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Palette (App-engagement handoff · "Lettre de motivation" form + editor).
// Local to this file — same per-file pattern as the other restyled Student
// surfaces (#110–117). Visual only; the real template + AI-personalize flow is
// preserved.
//
// DROPPED design chrome (see PR notes): the "7 days Premium free" trial banner,
// the "humanize / anti-AI mandatory pass" button and its "universities detect
// GPT" caption, and the edit-instruction chips — none have any backend behind
// them. The design's dark "Export" pill is bound to the REAL share control, and
// copy stays a real clipboard action.
// ─────────────────────────────────────────────────────────────────────────────
class _Palette {
  static const navy = Color(0xFF0F172A);
  static const blue = Color(0xFF2563EB);
  static const slate = Color(0xFF64748B);
  static const slate400 = Color(0xFF94A3B8);
  static const body = Color(0xFF334155);
  static const border = Color(0xFFE2E8F0);
  static const line = Color(0xFFF1F5F9);
  static const page = Color(0xFFF8FAFC);
  static const card = Color(0xFFFFFFFF);
  static const chipBg = Color(0xFFEFF6FF);
  static const chipBorder = Color(0xFFBFDBFE);
  static const cardShadow = Color(0x0A0F172A);
}

const _cardShadow = <BoxShadow>[
  BoxShadow(color: _Palette.cardShadow, blurRadius: 2, offset: Offset(0, 1)),
];

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
      backgroundColor: _Palette.page,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Get.back(),
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: _Palette.card,
                        shape: BoxShape.circle,
                        border: Border.all(color: _Palette.border),
                      ),
                      child: const Icon(Icons.arrow_back_rounded,
                          size: 19, color: _Palette.navy),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'letters_title'.tr,
                          style: const TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.4,
                            color: _Palette.navy,
                          ),
                        ),
                        Text(
                          'letters_header_subtitle'.tr,
                          style: const TextStyle(
                              fontSize: 11.5, color: _Palette.slate),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ── Category chips ────────────────────────────────────────────────
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Row(
                children: [
                  _chip('all', 'letters_filter_all'.tr),
                  ...kLetterCategories.map(
                    (c) => _chip(c, categoryLabelFr(c)),
                  ),
                ],
              ),
            ),

            // ── Templates list ────────────────────────────────────────────────
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                itemCount: _filtered.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (ctx, i) => _LetterCard(template: _filtered[i]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(String value, String label) {
    final selected = _selectedCategory == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: () => setState(() => _selectedCategory = value),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: selected ? _Palette.chipBg : _Palette.card,
            borderRadius: BorderRadius.circular(100),
            border: Border.all(
              color: selected ? _Palette.chipBorder : _Palette.border,
              width: 1.5,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: selected ? _Palette.blue : _Palette.slate,
            ),
          ),
        ),
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

  bool get _hasPersonalized =>
      _personalizedFr.isNotEmpty || _personalizedEn.isNotEmpty;

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
    if (_hasPersonalized) {
      return _showEnglish
          ? (_personalizedEn.isNotEmpty ? _personalizedEn : _personalizedFr)
          : (_personalizedFr.isNotEmpty ? _personalizedFr : _personalizedEn);
    }
    return widget.template.bodyFr;
  }

  @override
  Widget build(BuildContext context) {
    final titlePrimary = _ctrl.localeCode == 'en'
        ? widget.template.titleEn
        : widget.template.titleFr;
    final titleSecondary = _ctrl.localeCode == 'en'
        ? widget.template.titleFr
        : widget.template.titleEn;

    return Container(
      decoration: BoxDecoration(
        color: _Palette.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _Palette.border),
        boxShadow: _cardShadow,
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(12),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: _Palette.chipBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(_categoryIcon, color: _Palette.blue, size: 21),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        titlePrimary,
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          color: _Palette.navy,
                        ),
                      ),
                      Text(
                        titleSecondary,
                        style: const TextStyle(
                            fontSize: 11.5, color: _Palette.slate),
                      ),
                    ],
                  ),
                ),
                Icon(
                  _expanded
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  color: _Palette.slate400,
                ),
              ],
            ),
          ),

          // Expanded body
          if (_expanded) ...[
            const SizedBox(height: 12),

            // Language toggle + personalized badge (only if personalised)
            if (_hasPersonalized) ...[
              Row(
                children: [
                  _langChip('FR', !_showEnglish,
                      () => setState(() => _showEnglish = false)),
                  const SizedBox(width: 8),
                  _langChip('EN', _showEnglish,
                      () => setState(() => _showEnglish = true)),
                  const Spacer(),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: _Palette.chipBg,
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: Text(
                      'letters_personalized_badge'.tr,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: _Palette.blue,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
            ],

            // Letter body — the "editor" card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _Palette.card,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _Palette.border),
              ),
              child: SelectableText(
                _displayText,
                style: const TextStyle(
                  fontSize: 12.5,
                  height: 1.7,
                  color: _Palette.body,
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Action row — real generate/regenerate + real copy + real share
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: _isPersonalizing ? null : _personalize,
                    child: Container(
                      height: 46,
                      decoration: BoxDecoration(
                        color: _isPersonalizing
                            ? _Palette.blue.withValues(alpha: 0.6)
                            : _Palette.blue,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.auto_awesome_rounded,
                              color: Colors.white, size: 17),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              _isPersonalizing
                                  ? 'letters_personalizing'.tr
                                  : (_hasPersonalized
                                      ? 'letters_regenerate'.tr
                                      : 'letters_adapt_to_profile'.tr),
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _iconSquare(
                  icon: Icons.copy_rounded,
                  tooltip: 'letters_copy_tooltip'.tr,
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: _displayText));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('letters_copied_snackbar'.tr)),
                    );
                  },
                ),
                const SizedBox(width: 8),
                // Design's dark "Export" pill → the REAL share sheet.
                Semantics(
                  button: true,
                  label: 'letters_share_tooltip'.tr,
                  child: GestureDetector(
                    onTap: () => SharePlus.instance.share(
                      ShareParams(text: _displayText),
                    ),
                    child: Container(
                      height: 46,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: _Palette.navy,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.ios_share_rounded,
                              color: Colors.white, size: 16),
                          const SizedBox(width: 6),
                          Text(
                            'letters_export'.tr,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _langChip(String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? _Palette.blue : _Palette.card,
          borderRadius: BorderRadius.circular(100),
          border: Border.all(
            color: selected ? _Palette.blue : _Palette.border,
            width: 1.5,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: selected ? Colors.white : _Palette.slate,
          ),
        ),
      ),
    );
  }

  Widget _iconSquare({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: _Palette.line,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: _Palette.slate, size: 19),
        ),
      ),
    );
  }
}
