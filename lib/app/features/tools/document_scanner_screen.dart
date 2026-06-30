import 'dart:io';

import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../core/services/document_upload_service.dart';
import '../../core/ui/kpb_components.dart';

/// A required document for an international application.
class _DocItem {
  _DocItem(this.title, this.hint, this.icon);
  final String title;
  final String hint;
  final IconData icon;
  final List<File> pages = [];
  bool get isDone => pages.isNotEmpty;
}

/// Document Scanner + Checklist — capture multi-page docs, assemble to PDF.
/// (True OCR auto-validation is a planned enhancement.)
class DocumentScannerScreen extends StatefulWidget {
  const DocumentScannerScreen({super.key});

  @override
  State<DocumentScannerScreen> createState() => _DocumentScannerScreenState();
}

class _DocumentScannerScreenState extends State<DocumentScannerScreen> {
  final List<_DocItem> _docs = [
    _DocItem('Passeport', 'Page d\'identité, valide 6 mois min.',
        Icons.badge_rounded),
    _DocItem('Diplôme / Attestation', 'Dernier diplôme obtenu',
        Icons.school_rounded),
    _DocItem('Relevés de notes', 'Bulletins des 2 dernières années',
        Icons.assignment_rounded),
    _DocItem('Test de langue', 'TOEFL / IELTS / TCF si disponible',
        Icons.translate_rounded),
    _DocItem('Justificatif financier', 'Relevé bancaire ou attestation',
        Icons.account_balance_rounded),
    _DocItem('Photo d\'identité', 'Fond clair, format officiel',
        Icons.photo_camera_front_rounded),
  ];

  int get _doneCount => _docs.where((d) => d.isDone).length;

  Future<void> _scan(_DocItem doc) async {
    final file = await DocumentUploadService.captureFromCamera();
    if (file != null && mounted) {
      setState(() => doc.pages.add(file));
    }
  }

  Future<void> _exportPdf(_DocItem doc) async {
    if (doc.pages.isEmpty) return;
    final pdf = pw.Document();
    for (final page in doc.pages) {
      final bytes = await page.readAsBytes();
      final image = pw.MemoryImage(bytes);
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (ctx) => pw.Center(child: pw.Image(image)),
        ),
      );
    }
    await Printing.sharePdf(
      bytes: await pdf.save(),
      filename: '${doc.title.replaceAll(' ', '_')}.pdf',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scanner mes documents')),
      body: Column(
        children: [
          // Progress header
          Container(
            margin: const EdgeInsets.all(KpbSpacing.pagePad),
            padding: const EdgeInsets.all(KpbSpacing.md),
            decoration: BoxDecoration(
              color: KpbColors.blue.withValues(alpha: 0.08),
              borderRadius: KpbRadius.lgBr,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Dossier de candidature',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: context.kpb.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$_doneCount / ${_docs.length} documents prêts',
                        style: TextStyle(
                          fontSize: 12,
                          color: context.kpb.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  width: 44,
                  height: 44,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CircularProgressIndicator(
                        value: _docs.isEmpty ? 0 : _doneCount / _docs.length,
                        strokeWidth: 5,
                        backgroundColor: context.kpb.gray200,
                        valueColor:
                            const AlwaysStoppedAnimation(KpbColors.blue),
                      ),
                      Text(
                        '${((_doneCount / _docs.length) * 100).round()}%',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Checklist
          Expanded(
            child: ListView.separated(
              padding:
                  const EdgeInsets.symmetric(horizontal: KpbSpacing.pagePad),
              itemCount: _docs.length,
              separatorBuilder: (_, __) =>
                  const SizedBox(height: KpbSpacing.sm),
              itemBuilder: (ctx, i) {
                final doc = _docs[i];
                return KpbCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: doc.isDone
                                  ? KpbColors.success.withValues(alpha: 0.12)
                                  : context.kpb.gray100,
                              borderRadius: KpbRadius.mdBr,
                            ),
                            child: Icon(
                              doc.isDone
                                  ? Icons.check_circle_rounded
                                  : doc.icon,
                              color: doc.isDone
                                  ? KpbColors.success
                                  : context.kpb.textMuted,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  doc.title,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: context.kpb.textPrimary,
                                  ),
                                ),
                                Text(
                                  doc.isDone
                                      ? '${doc.pages.length} page(s) scannée(s)'
                                      : doc.hint,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: doc.isDone
                                        ? KpbColors.success
                                        : context.kpb.textMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: KpbSpacing.sm),
                      Row(
                        children: [
                          Expanded(
                            child: KpbButton(
                              label:
                                  doc.isDone ? 'Ajouter une page' : 'Scanner',
                              icon: Icons.camera_alt_rounded,
                              secondary: doc.isDone,
                              onTap: () => _scan(doc),
                            ),
                          ),
                          if (doc.isDone) ...[
                            const SizedBox(width: 8),
                            IconButton(
                              tooltip: 'Exporter en PDF',
                              icon: const Icon(Icons.picture_as_pdf_rounded),
                              color: KpbColors.blue,
                              onPressed: () => _exportPdf(doc),
                            ),
                            IconButton(
                              tooltip: 'Réinitialiser',
                              icon: const Icon(Icons.delete_outline_rounded),
                              color: context.kpb.textMuted,
                              onPressed: () =>
                                  setState(() => doc.pages.clear()),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: KpbSpacing.md),
        ],
      ),
    );
  }
}
