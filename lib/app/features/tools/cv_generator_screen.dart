import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../core/controllers/app_controller.dart';
import '../../core/ui/kpb_components.dart';
import '../../core/utils/study_level.dart';

/// CV Generator — pre-filled from profile, AI-enhanced summary, PDF export.
class CvGeneratorScreen extends StatefulWidget {
  const CvGeneratorScreen({super.key});

  @override
  State<CvGeneratorScreen> createState() => _CvGeneratorScreenState();
}

class _CvGeneratorScreenState extends State<CvGeneratorScreen> {
  final _ctrl = Get.find<AppController>();

  late final TextEditingController _nameCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _levelCtrl;
  late final TextEditingController _fieldCtrl;
  late final TextEditingController _countryCtrl;
  late final TextEditingController _skillsCtrl;
  late final TextEditingController _languagesCtrl;
  late final TextEditingController _experienceCtrl;
  late final TextEditingController _objectiveCtrl;

  String _aiSummaryFr = '';
  String _aiSummaryEn = '';
  bool _isGenerating = false;
  bool _useEnglish = false;

  @override
  void initState() {
    super.initState();
    final p = _ctrl.profile;
    final level = p?.currentLevel ?? '';
    final fieldId = p?.fieldIds.isNotEmpty == true ? p!.fieldIds.first : '';
    final field = _ctrl.fields
        .where((f) => f.id == fieldId)
        .map((f) => _ctrl.resolve(f.name))
        .firstOrNull ?? '';
    final targetId =
        p?.targetCountryIds.isNotEmpty == true ? p!.targetCountryIds.first : '';
    final country = _ctrl.countries
        .where((c) => c.id == targetId)
        .map((c) => _ctrl.resolve(c.name))
        .firstOrNull ?? '';

    _nameCtrl = TextEditingController(text: p?.fullName ?? '');
    _emailCtrl = TextEditingController(text: p?.email ?? '');
    _phoneCtrl = TextEditingController(text: p?.phone ?? '');
    _levelCtrl = TextEditingController(text: programLevelLabel(level));
    _fieldCtrl = TextEditingController(text: field);
    _countryCtrl = TextEditingController(text: country);
    _skillsCtrl = TextEditingController();
    _languagesCtrl = TextEditingController(text: 'Francais, Anglais');
    _experienceCtrl = TextEditingController();
    _objectiveCtrl = TextEditingController();
  }

  @override
  void dispose() {
    for (final c in [
      _nameCtrl, _emailCtrl, _phoneCtrl, _levelCtrl,
      _fieldCtrl, _countryCtrl, _skillsCtrl, _languagesCtrl,
      _experienceCtrl, _objectiveCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _generateSummary() async {
    setState(() => _isGenerating = true);
    try {
      final result = await _ctrl.apiClient.post('tools/cv-summary', {
        'name': _nameCtrl.text,
        'studyLevel': _levelCtrl.text,
        'fieldOfStudy': _fieldCtrl.text,
        'targetCountry': _countryCtrl.text,
        'skills': _skillsCtrl.text
            .split(',')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList(),
        'languages': _languagesCtrl.text
            .split(',')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList(),
        'experience': _experienceCtrl.text,
      });
      if (mounted) {
        setState(() {
          _aiSummaryFr = result['fr'] as String? ?? '';
          _aiSummaryEn = result['en'] as String? ?? '';
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erreur IA — verifiez votre connexion')),
        );
      }
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  // ── KPB brand colours for the PDF ──────────────────────────────────────────
  static const _kpbBlue = PdfColor.fromInt(0xFF004AAD);
  static const _kpbBlueBg = PdfColor.fromInt(0xFFE8F0FA);
  static const _darkText = PdfColor.fromInt(0xFF111827);
  static const _mutedText = PdfColor.fromInt(0xFF6B7280);

  Future<void> _exportPdf() async {
    final doc = pw.Document();
    final summary = _useEnglish
        ? (_aiSummaryEn.isNotEmpty ? _aiSummaryEn : _aiSummaryFr)
        : (_aiSummaryFr.isNotEmpty ? _aiSummaryFr : _aiSummaryEn);
    final en = _useEnglish;

    final skills = _skillsCtrl.text
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    final languages = _languagesCtrl.text
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    final experiences = _experienceCtrl.text
        .split('\n')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.zero,
        build: (ctx) => pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // ── LEFT SIDEBAR (blue) ──────────────────────────────────────────
            pw.Container(
              width: 190,
              height: double.infinity,
              color: _kpbBlue,
              padding: const pw.EdgeInsets.all(20),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // Initials circle
                  pw.Center(
                    child: pw.Container(
                      width: 80,
                      height: 80,
                      decoration: pw.BoxDecoration(
                        color: PdfColors.white,
                        shape: pw.BoxShape.circle,
                      ),
                      alignment: pw.Alignment.center,
                      child: pw.Text(
                        _initials(_nameCtrl.text),
                        style: pw.TextStyle(
                          fontSize: 28,
                          fontWeight: pw.FontWeight.bold,
                          color: _kpbBlue,
                        ),
                      ),
                    ),
                  ),
                  pw.SizedBox(height: 24),

                  // Contact
                  _sidebarSection(en ? 'CONTACT' : 'CONTACT'),
                  _sidebarItem(Icons.email, _emailCtrl.text),
                  _sidebarItem(Icons.phone, _phoneCtrl.text),
                  if (_countryCtrl.text.isNotEmpty)
                    _sidebarItem(Icons.location_on, _countryCtrl.text),
                  pw.SizedBox(height: 16),

                  // Languages
                  if (languages.isNotEmpty) ...[
                    _sidebarSection(en ? 'LANGUAGES' : 'LANGUES'),
                    ...languages.map((l) => pw.Padding(
                          padding: const pw.EdgeInsets.only(bottom: 4),
                          child: pw.Row(children: [
                            pw.Container(
                              width: 6,
                              height: 6,
                              decoration: const pw.BoxDecoration(
                                color: PdfColors.white,
                                shape: pw.BoxShape.circle,
                              ),
                            ),
                            pw.SizedBox(width: 8),
                            pw.Expanded(
                              child: pw.Text(
                                l,
                                style: const pw.TextStyle(
                                    fontSize: 9, color: PdfColors.white),
                              ),
                            ),
                          ]),
                        )),
                    pw.SizedBox(height: 16),
                  ],

                  // Skills as tags
                  if (skills.isNotEmpty) ...[
                    _sidebarSection(en ? 'SKILLS' : 'COMPETENCES'),
                    pw.Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: skills
                          .map((s) => pw.Container(
                                padding: const pw.EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: pw.BoxDecoration(
                                  color: PdfColors.white,
                                  borderRadius:
                                      pw.BorderRadius.circular(10),
                                ),
                                child: pw.Text(
                                  s,
                                  style: pw.TextStyle(
                                    fontSize: 8,
                                    color: _kpbBlue,
                                    fontWeight: pw.FontWeight.bold,
                                  ),
                                ),
                              ))
                          .toList(),
                    ),
                  ],
                ],
              ),
            ),

            // ── RIGHT MAIN CONTENT ───────────────────────────────────────────
            pw.Expanded(
              child: pw.Padding(
                padding: const pw.EdgeInsets.fromLTRB(28, 28, 28, 20),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    // Name & title
                    pw.Text(
                      _nameCtrl.text.toUpperCase(),
                      style: pw.TextStyle(
                        fontSize: 24,
                        fontWeight: pw.FontWeight.bold,
                        color: _darkText,
                        letterSpacing: 1.5,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      '${_levelCtrl.text} — ${_fieldCtrl.text}',
                      style: pw.TextStyle(
                        fontSize: 12,
                        color: _kpbBlue,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Container(height: 3, width: 50, color: _kpbBlue),
                    pw.SizedBox(height: 18),

                    // Summary
                    if (summary.isNotEmpty) ...[
                      _mainSection(en ? 'PROFESSIONAL SUMMARY' : 'PROFIL'),
                      pw.Text(
                        summary,
                        style: const pw.TextStyle(
                          fontSize: 9.5,
                          color: _darkText,
                          lineSpacing: 4,
                        ),
                      ),
                      pw.SizedBox(height: 16),
                    ],

                    // Education
                    _mainSection(en ? 'EDUCATION' : 'FORMATION'),
                    pw.Container(
                      padding: const pw.EdgeInsets.all(10),
                      decoration: pw.BoxDecoration(
                        color: _kpbBlueBg,
                        borderRadius: pw.BorderRadius.circular(6),
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            '${_levelCtrl.text} — ${_fieldCtrl.text}',
                            style: pw.TextStyle(
                              fontSize: 10,
                              fontWeight: pw.FontWeight.bold,
                              color: _darkText,
                            ),
                          ),
                          if (_countryCtrl.text.isNotEmpty)
                            pw.Text(
                              '${en ? "Target country" : "Pays cible"} : ${_countryCtrl.text}',
                              style: const pw.TextStyle(
                                fontSize: 9,
                                color: _mutedText,
                              ),
                            ),
                        ],
                      ),
                    ),
                    pw.SizedBox(height: 16),

                    // Experience
                    if (experiences.isNotEmpty) ...[
                      _mainSection(en ? 'EXPERIENCE' : 'EXPERIENCE'),
                      ...experiences.map((exp) => pw.Padding(
                            padding: const pw.EdgeInsets.only(bottom: 6),
                            child: pw.Row(
                              crossAxisAlignment:
                                  pw.CrossAxisAlignment.start,
                              children: [
                                pw.Container(
                                  width: 6,
                                  height: 6,
                                  margin:
                                      const pw.EdgeInsets.only(top: 3),
                                  decoration: pw.BoxDecoration(
                                    color: _kpbBlue,
                                    shape: pw.BoxShape.circle,
                                  ),
                                ),
                                pw.SizedBox(width: 8),
                                pw.Expanded(
                                  child: pw.Text(
                                    exp,
                                    style: const pw.TextStyle(
                                      fontSize: 9.5,
                                      color: _darkText,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )),
                      pw.SizedBox(height: 16),
                    ],

                    // Objective
                    if (_objectiveCtrl.text.isNotEmpty) ...[
                      _mainSection(en
                          ? 'CAREER OBJECTIVE'
                          : 'OBJECTIF PROFESSIONNEL'),
                      pw.Text(
                        _objectiveCtrl.text,
                        style: const pw.TextStyle(
                          fontSize: 9.5,
                          color: _darkText,
                          lineSpacing: 4,
                        ),
                      ),
                    ],

                    pw.Spacer(),

                    // Footer
                    pw.Align(
                      alignment: pw.Alignment.centerRight,
                      child: pw.Text(
                        'Generated with KPB Education',
                        style: const pw.TextStyle(
                          fontSize: 7,
                          color: _mutedText,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );

    await Printing.sharePdf(
      bytes: await doc.save(),
      filename: 'CV_${_nameCtrl.text.replaceAll(' ', '_')}.pdf',
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[parts.length - 1][0]}'.toUpperCase();
  }

  pw.Widget _sidebarSection(String title) => pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 6),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              title,
              style: pw.TextStyle(
                fontSize: 10,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.white,
                letterSpacing: 1.2,
              ),
            ),
            pw.SizedBox(height: 3),
            pw.Container(height: 1, width: 30, color: PdfColors.white),
          ],
        ),
      );

  pw.Widget _sidebarItem(IconData _, String text) => pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 5),
        child: pw.Text(
          text,
          style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.white),
          maxLines: 2,
        ),
      );

  pw.Widget _mainSection(String title) => pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 8),
        child: pw.Row(children: [
          pw.Container(width: 4, height: 14, color: _kpbBlue),
          pw.SizedBox(width: 8),
          pw.Text(
            title,
            style: pw.TextStyle(
              fontSize: 11,
              fontWeight: pw.FontWeight.bold,
              color: _kpbBlue,
              letterSpacing: 1,
            ),
          ),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Generateur de CV')),
      body: ListView(
        padding: const EdgeInsets.all(KpbSpacing.pagePad),
        children: [
          // ── Intro ──────────────────────────────────────────────────────────
          Text(
            'Remplissez les champs et laissez l\'IA rediger votre profil professionnel.',
            style: TextStyle(
              fontSize: 14,
              color: context.kpb.textMuted,
            ),
          ),
          const SizedBox(height: KpbSpacing.lg),

          // ── Form fields ────────────────────────────────────────────────────
          _field('Nom complet', _nameCtrl),
          _field('Email', _emailCtrl),
          _field('Telephone', _phoneCtrl),
          _field('Niveau d\'etudes', _levelCtrl),
          _field('Domaine d\'etudes', _fieldCtrl),
          _field('Pays cible', _countryCtrl),
          _field('Competences (separees par des virgules)', _skillsCtrl),
          _field('Langues', _languagesCtrl),
          _field('Experience / Stages', _experienceCtrl, maxLines: 3),
          _field('Objectif professionnel', _objectiveCtrl, maxLines: 2),

          const SizedBox(height: KpbSpacing.lg),

          // ── AI summary button ──────────────────────────────────────────────
          KpbButton(
            label: _isGenerating
                ? 'Generation en cours...'
                : 'Ameliorer avec l\'IA',
            icon: Icons.auto_awesome_rounded,
            onTap: _isGenerating ? null : _generateSummary,
          ),

          // ── AI result preview ──────────────────────────────────────────────
          if (_aiSummaryFr.isNotEmpty || _aiSummaryEn.isNotEmpty) ...[
            const SizedBox(height: KpbSpacing.lg),
            Row(
              children: [
                Text(
                  'Resume genere par l\'IA',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: context.kpb.textPrimary,
                  ),
                ),
                const Spacer(),
                ChoiceChip(
                  label: const Text('FR'),
                  selected: !_useEnglish,
                  onSelected: (_) => setState(() => _useEnglish = false),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('EN'),
                  selected: _useEnglish,
                  onSelected: (_) => setState(() => _useEnglish = true),
                ),
              ],
            ),
            const SizedBox(height: KpbSpacing.sm),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: context.kpb.cardBg,
                borderRadius: KpbRadius.lgBr,
                border: Border.all(color: KpbColors.blue.withValues(alpha: 0.3)),
              ),
              child: Text(
                _useEnglish
                    ? (_aiSummaryEn.isNotEmpty ? _aiSummaryEn : _aiSummaryFr)
                    : (_aiSummaryFr.isNotEmpty ? _aiSummaryFr : _aiSummaryEn),
                style: TextStyle(
                  fontSize: 13,
                  height: 1.5,
                  color: context.kpb.textPrimary,
                ),
              ),
            ),
          ],

          const SizedBox(height: KpbSpacing.xl),

          // ── Export PDF button ───────────────────────────────────────────────
          KpbButton(
            label: 'Exporter en PDF',
            icon: Icons.picture_as_pdf_rounded,
            secondary: true,
            onTap: _exportPdf,
          ),

          const SizedBox(height: KpbSpacing.xl),
        ],
      ),
    );
  }

  Widget _field(String label, TextEditingController ctrl, {int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: ctrl,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
      ),
    );
  }
}
