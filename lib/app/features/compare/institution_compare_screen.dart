import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/controllers/app_controller.dart';
import '../../core/models/app_models.dart';
import '../../core/utils/country_utils.dart';
import '../cases/case_composer_sheet.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Palette (App-engagement handoff · Student App.dc.html · "Comparateur").
// Local to this file — same pattern as Home / Onboarding / Country guide.
// ─────────────────────────────────────────────────────────────────────────────
class _Palette {
  static const navy = Color(0xFF0F172A);
  static const blue = Color(0xFF2563EB);
  static const slate = Color(0xFF64748B);
  static const slate400 = Color(0xFF94A3B8);
  static const border = Color(0xFFE2E8F0);
  static const line = Color(0xFFF1F5F9);
  static const lineSoft = Color(0xFFF8FAFC);
  static const page = Color(0xFFF8FAFC);
  static const card = Color(0xFFFFFFFF);
  static const chipBg = Color(0xFFEFF6FF);
  static const chipBorder = Color(0xFFBFDBFE);
  static const green = Color(0xFF16A34A);
  static const greenBg = Color(0xFFDCFCE7);
  static const amber = Color(0xFFB45309);
  static const amberBg = Color(0xFFFEF3C7);
  static const body = Color(0xFF334155);
  // rgba(15,23,42,0.25) — bottom-sheet drop shadow.
  static const sheetShadow = Color(0x400F172A);
}

String _flag(String id) => countryFlag(id);

/// Match-percentage zone colours (bg, fg) — shared by the table match chip and
/// the picker badges.
(Color, Color) _zoneColors(int score) {
  if (score >= 85) return (_Palette.greenBg, _Palette.green);
  if (score >= 70) return (_Palette.chipBg, _Palette.blue);
  if (score >= 50) return (_Palette.amberBg, _Palette.amber);
  return (_Palette.line, _Palette.slate);
}

// ─────────────────────────────────────────────────────────────────────────────
// Comparator screen
// ─────────────────────────────────────────────────────────────────────────────
class InstitutionCompareScreen extends StatefulWidget {
  const InstitutionCompareScreen({
    super.key,
    required this.institutionId1,
    required this.institutionId2,
  });

  final String institutionId1;
  final String institutionId2;

  @override
  State<InstitutionCompareScreen> createState() =>
      _InstitutionCompareScreenState();
}

class _InstitutionCompareScreenState extends State<InstitutionCompareScreen> {
  final AppController _controller = Get.find<AppController>();

  // Local state: the two currently-compared institution ids, seeded from the
  // constructor. The picker swaps one of these via setState.
  late String _id1 = widget.institutionId1;
  late String _id2 = widget.institutionId2;

  @override
  Widget build(BuildContext context) {
    final inst1 = _controller.institutionByIdOrNull(_id1);
    final inst2 = _controller.institutionByIdOrNull(_id2);

    if (inst1 == null || inst2 == null) {
      return Scaffold(
        backgroundColor: _Palette.page,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Align(
              alignment: Alignment.topLeft,
              child: _circleButton(
                icon: Icons.arrow_back_rounded,
                onTap: () => Get.back<void>(),
                tooltip: 'a11y_back'.tr,
              ),
            ),
          ),
        ),
      );
    }

    final score1 = _controller.institutionMatch(inst1);
    final score2 = _controller.institutionMatch(inst2);
    final verdict = _verdict(inst1, inst2, score1, score2);

    return Scaffold(
      backgroundColor: _Palette.page,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _header(inst1, inst2),
              const SizedBox(height: 13),
              _table(inst1, inst2, score1, score2, verdict),
              const SizedBox(height: 13),
              Row(
                children: [
                  Expanded(child: _caseCta(inst1)),
                  const SizedBox(width: 10),
                  Expanded(child: _caseCta(inst2)),
                ],
              ),
              const SizedBox(height: 10),
              _helpButton(inst1, inst2),
            ],
          ),
        ),
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────
  Widget _header(InstitutionModel inst1, InstitutionModel inst2) {
    return Row(
      children: [
        _circleButton(
          icon: Icons.arrow_back_rounded,
          onTap: () => Get.back<void>(),
          tooltip: 'a11y_back'.tr,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'compare_title'.tr,
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                  color: _Palette.navy,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                'compare_subtitle'.tr,
                style: const TextStyle(fontSize: 11.5, color: _Palette.slate),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        _circleButton(
          icon: Icons.ios_share_rounded,
          onTap: () => _shareComparison(inst1, inst2),
          tooltip: 'a11y_share'.tr,
        ),
      ],
    );
  }

  Widget _circleButton({
    required IconData icon,
    required VoidCallback onTap,
    required String tooltip,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: _Palette.card,
        shape: const CircleBorder(side: BorderSide(color: _Palette.border)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            width: 38,
            height: 38,
            child: Icon(icon, size: 19, color: _Palette.navy),
          ),
        ),
      ),
    );
  }

  // ── Comparison table card ───────────────────────────────────────────────────
  Widget _table(
    InstitutionModel inst1,
    InstitutionModel inst2,
    int score1,
    int score2,
    String? verdict,
  ) {
    final (bg1, fg1) = _zoneColors(score1);
    final (bg2, fg2) = _zoneColors(score2);

    return Container(
      decoration: BoxDecoration(
        color: _Palette.card,
        border: Border.all(color: _Palette.border),
        borderRadius: BorderRadius.circular(16),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          _pickHeaderRow(inst1, inst2),
          _attrRow(
            'compare_row_match'.tr,
            _chip('$score1%', bg1, fg1),
            _chip('$score2%', bg2, fg2),
          ),
          _attrRow(
            'saved_group_countries'.tr,
            _cellText(
                '${_flag(inst1.countryId)} ${_countryName(inst1.countryId)}'),
            _cellText(
                '${_flag(inst2.countryId)} ${_countryName(inst2.countryId)}'),
          ),
          _attrRow(
            'compare_row_location'.tr,
            _cellText(_controller.resolve(inst1.location)),
            _cellText(_controller.resolve(inst2.location)),
          ),
          _attrRow(
            'compare_row_tuition'.tr,
            _cellText(_controller.resolve(inst1.tuitionLabel)),
            _cellText(_controller.resolve(inst2.tuitionLabel)),
          ),
          _attrRow(
            'compare_row_language'.tr,
            _cellText(_controller.resolve(inst1.languageRequirements)),
            _cellText(_controller.resolve(inst2.languageRequirements)),
          ),
          _attrRow(
            'compare_row_levels'.tr,
            _cellText(_join(inst1.studyLevels)),
            _cellText(_join(inst2.studyLevels)),
          ),
          _attrRow(
            'compare_row_intakes'.tr,
            _cellText(_join(inst1.intakePeriods)),
            _cellText(_join(inst2.intakePeriods)),
          ),
          _attrRow(
            'saved_group_programs'.tr,
            _cellText('compare_program_count'
                .trParams({'n': '${inst1.programIds.length}'})),
            _cellText('compare_program_count'
                .trParams({'n': '${inst2.programIds.length}'})),
          ),
          _attrRow(
            'compare_row_kpb_partner'.tr,
            _partnerChip(inst1.isPartner),
            _partnerChip(inst2.isPartner),
          ),
          if (verdict != null) _verdictRow(verdict),
        ],
      ),
    );
  }

  Widget _pickHeaderRow(InstitutionModel inst1, InstitutionModel inst2) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: _Palette.line)),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Expanded(flex: 9, child: SizedBox()),
            _pickCell(inst1, () => _openPicker(column: 1)),
            _pickCell(inst2, () => _openPicker(column: 2)),
          ],
        ),
      ),
    );
  }

  Widget _pickCell(InstitutionModel inst, VoidCallback onTap) {
    return Expanded(
      flex: 10,
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: const BoxDecoration(
            border: Border(left: BorderSide(color: _Palette.line)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 14),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(_flag(inst.countryId),
                  style: const TextStyle(fontSize: 22, height: 1)),
              const SizedBox(height: 4),
              Text(
                _controller.resolve(inst.name),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  color: _Palette.navy,
                  height: 1.25,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.search_rounded,
                      size: 11, color: _Palette.blue),
                  const SizedBox(width: 3),
                  Text(
                    'compare_pick'.tr,
                    style: const TextStyle(
                      fontSize: 8.5,
                      fontWeight: FontWeight.w800,
                      color: _Palette.blue,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _attrRow(String label, Widget cell1, Widget cell2) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: _Palette.lineSoft)),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              flex: 9,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    label.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.4,
                      color: _Palette.slate400,
                    ),
                  ),
                ),
              ),
            ),
            _valueCell(cell1),
            _valueCell(cell2),
          ],
        ),
      ),
    );
  }

  Widget _valueCell(Widget child) {
    return Expanded(
      flex: 10,
      child: Container(
        decoration: const BoxDecoration(
          border: Border(left: BorderSide(color: _Palette.lineSoft)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
        alignment: Alignment.center,
        child: child,
      ),
    );
  }

  Widget _cellText(String text) {
    return Text(
      text,
      textAlign: TextAlign.center,
      style: const TextStyle(
        fontSize: 11.5,
        fontWeight: FontWeight.w700,
        color: _Palette.body,
        height: 1.4,
      ),
    );
  }

  Widget _chip(String text, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: fg),
      ),
    );
  }

  Widget _partnerChip(bool value) => value
      ? _chip('compare_yes'.tr, _Palette.greenBg, _Palette.green)
      : _chip('compare_no'.tr, _Palette.line, _Palette.slate);

  Widget _verdictRow(String verdict) {
    return Container(
      color: _Palette.chipBg,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.lightbulb_rounded, size: 15, color: _Palette.blue),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              verdict,
              style: const TextStyle(
                fontSize: 11.5,
                height: 1.5,
                fontWeight: FontWeight.w600,
                color: _Palette.body,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── CTAs ────────────────────────────────────────────────────────────────────
  Widget _caseCta(InstitutionModel inst) {
    return Material(
      color: _Palette.blue,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _openCase(inst),
        child: Container(
          height: 50,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.folder_open_rounded,
                  size: 17, color: Colors.white),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  'compare_open_case_for'
                      .trParams({'name': _controller.resolve(inst.name)}),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _helpButton(InstitutionModel inst1, InstitutionModel inst2) {
    return Material(
      color: _Palette.card,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _openHelp(inst1, inst2),
        child: Container(
          height: 48,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _Palette.border),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.support_agent_rounded,
                  size: 17, color: _Palette.blue),
              const SizedBox(width: 8),
              Text(
                'compare_need_help_choosing'.tr,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: _Palette.blue,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Actions ──────────────────────────────────────────────────────────────────
  Future<void> _openPicker({required int column}) async {
    final currentId = column == 1 ? _id1 : _id2;
    final excludeId = column == 1 ? _id2 : _id1;
    final chosen = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _UniversityPickerSheet(
        controller: _controller,
        currentId: currentId,
        excludeId: excludeId,
      ),
    );
    if (chosen == null || !mounted) return;
    setState(() {
      if (column == 1) {
        _id1 = chosen;
      } else {
        _id2 = chosen;
      }
    });
  }

  void _openCase(InstitutionModel inst) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CaseComposerSheet(
        caseType: CaseType.applicationSupport,
        title: _controller.resolve(inst.name),
        contextLabel: _controller.resolve(inst.location),
        institutionId: inst.id,
      ),
    );
  }

  void _openHelp(InstitutionModel inst1, InstitutionModel inst2) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CaseComposerSheet(
        caseType: CaseType.consultation,
        title: 'compare_help_choosing_university'.tr,
        contextLabel:
            '${_controller.resolve(inst1.name)} vs ${_controller.resolve(inst2.name)}',
      ),
    );
  }

  /// Verdict tip — only ever mechanically derived from the two real records.
  /// Returns null (row omitted) when nothing truthful can be said.
  String? _verdict(
    InstitutionModel a,
    InstitutionModel b,
    int scoreA,
    int scoreB,
  ) {
    if (scoreA != scoreB) {
      final higher = scoreA > scoreB ? a : b;
      return 'compare_verdict_higher_match'.trParams({
        'name': _controller.resolve(higher.name),
        'hi': '${scoreA > scoreB ? scoreA : scoreB}',
        'lo': '${scoreA > scoreB ? scoreB : scoreA}',
      });
    }
    if (a.isPartner != b.isPartner) {
      final partner = a.isPartner ? a : b;
      return 'compare_verdict_partner'
          .trParams({'name': _controller.resolve(partner.name)});
    }
    final na = a.programIds.length;
    final nb = b.programIds.length;
    if (na != nb) {
      final more = na > nb ? a : b;
      return 'compare_verdict_more_programs'.trParams({
        'name': _controller.resolve(more.name),
        'hi': '${na > nb ? na : nb}',
        'lo': '${na > nb ? nb : na}',
      });
    }
    return null;
  }

  void _shareComparison(InstitutionModel inst1, InstitutionModel inst2) {
    final name1 = _controller.resolve(inst1.name);
    final name2 = _controller.resolve(inst2.name);
    final score1 = _controller.institutionMatch(inst1);
    final score2 = _controller.institutionMatch(inst2);
    SharePlus.instance.share(ShareParams(
      text: 'compare_share_header'.tr +
          'compare_share_line'.trParams({'name': name1, 'score': '$score1'}) +
          'compare_share_tuition'
              .trParams({'tuition': _controller.resolve(inst1.tuitionLabel)}) +
          'compare_share_language'.trParams(
              {'lang': _controller.resolve(inst1.languageRequirements)}) +
          'compare_share_line'.trParams({'name': name2, 'score': '$score2'}) +
          'compare_share_tuition'
              .trParams({'tuition': _controller.resolve(inst2.tuitionLabel)}) +
          'compare_share_language'.trParams(
              {'lang': _controller.resolve(inst2.languageRequirements)}) +
          'compare_share_footer'.tr,
    ));
  }

  String _join(List<String> values) =>
      values.isEmpty ? '—' : values.join(' · ');

  String _countryName(String countryId) {
    try {
      return _controller.resolve(_controller.countryById(countryId).name);
    } catch (_) {
      return countryId;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sélecteur d'université — bottom-sheet picker for switching a compared column.
// ─────────────────────────────────────────────────────────────────────────────
class _UniversityPickerSheet extends StatefulWidget {
  const _UniversityPickerSheet({
    required this.controller,
    required this.currentId,
    required this.excludeId,
  });

  final AppController controller;

  /// The column's current institution — highlighted in the list.
  final String currentId;

  /// The opposite column's institution — hidden so the two columns stay
  /// distinct (you can't compare a university with itself).
  final String excludeId;

  @override
  State<_UniversityPickerSheet> createState() => _UniversityPickerSheetState();
}

class _UniversityPickerSheetState extends State<_UniversityPickerSheet> {
  final TextEditingController _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<InstitutionModel> get _results {
    final q = _query.trim().toLowerCase();
    return widget.controller.institutions.where((inst) {
      if (inst.id == widget.excludeId) return false;
      if (q.isEmpty) return true;
      final name = widget.controller.resolve(inst.name).toLowerCase();
      final city = widget.controller.resolve(inst.location).toLowerCase();
      return name.contains(q) || city.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final results = _results;
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.74,
        child: Container(
          decoration: const BoxDecoration(
            color: _Palette.card,
            borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
            boxShadow: [
              BoxShadow(
                color: _Palette.sheetShadow,
                blurRadius: 40,
                offset: Offset(0, -12),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 10),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'compare_picker_title'.tr,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: _Palette.navy,
                            ),
                          ),
                        ),
                        _closeButton(),
                      ],
                    ),
                    const SizedBox(height: 11),
                    _searchField(),
                  ],
                ),
              ),
              Expanded(
                child: results.isEmpty
                    ? _emptyState()
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                        itemCount: results.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 6),
                        itemBuilder: (_, i) => _pickRow(results[i]),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _closeButton() {
    return Material(
      color: _Palette.line,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).maybePop(),
        child: const SizedBox(
          width: 30,
          height: 30,
          child: Icon(Icons.close_rounded, size: 15, color: _Palette.navy),
        ),
      ),
    );
  }

  Widget _searchField() {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 15),
      decoration: BoxDecoration(
        color: _Palette.page,
        border: Border.all(color: _Palette.border, width: 1.5),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Row(
        children: [
          const Icon(Icons.search_rounded, size: 18, color: _Palette.slate400),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _search,
              onChanged: (value) => setState(() => _query = value),
              textInputAction: TextInputAction.search,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: _Palette.navy,
              ),
              decoration: InputDecoration(
                isCollapsed: true,
                border: InputBorder.none,
                hintText: 'compare_search_hint'.tr,
                hintStyle: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: _Palette.slate400,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _pickRow(InstitutionModel inst) {
    final score = widget.controller.institutionMatch(inst);
    final (bg, fg) = _zoneColors(score);
    final selected = inst.id == widget.currentId;
    return Material(
      color: selected ? _Palette.chipBg : Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).pop(inst.id),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: selected ? Border.all(color: _Palette.chipBorder) : null,
          ),
          child: Row(
            children: [
              Text(_flag(inst.countryId),
                  style: const TextStyle(fontSize: 22, height: 1)),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.controller.resolve(inst.name),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: _Palette.navy,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.controller.resolve(inst.location),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 10.5,
                        color: _Palette.slate,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text(
                  '$score%',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    color: fg,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _emptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
      child: Align(
        alignment: Alignment.topCenter,
        child: Text(
          'compare_picker_empty'.tr,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 12, color: _Palette.slate400),
        ),
      ),
    );
  }
}
