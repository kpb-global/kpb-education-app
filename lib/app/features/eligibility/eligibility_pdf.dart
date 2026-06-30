// M11 — PDF export for the eligibility simulator.
//
// Builds a one-page summary (student inputs + per-country verdicts) and hands
// it to the OS share sheet via the `printing` package. Avoids emoji/flags in
// the document because the standard PDF fonts don't render them; uses coloured
// text labels instead.

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../core/models/app_models.dart';
import 'eligibility_simulator_data.dart';

PdfColor _verdictColor(EligibilityVerdict v) {
  switch (v) {
    case EligibilityVerdict.eligible:
      return PdfColors.green700;
    case EligibilityVerdict.eligibleWithConditions:
      return PdfColors.orange700;
    case EligibilityVerdict.notEligible:
      return PdfColors.red700;
  }
}

Future<void> shareEligibilityPdf({
  required EligibilityInput input,
  required List<EligibilityResult> results,
  String? studentName,
}) async {
  final doc = pw.Document();
  final now = DateTime.now();
  final dateStr =
      '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}';

  pw.Widget inputLine(String label, String value) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 1),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.SizedBox(
              width: 130,
              child: pw.Text(label,
                  style: pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
            ),
            pw.Expanded(
              child: pw.Text(value, style: const pw.TextStyle(fontSize: 9)),
            ),
          ],
        ),
      );

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      build: (context) => [
        pw.Header(
          level: 0,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('KPB Education',
                  style: pw.TextStyle(
                      fontSize: 18,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColor.fromInt(0xFF004AAD))),
              pw.Text('Simulateur d\'éligibilité',
                  style: const pw.TextStyle(fontSize: 13)),
              pw.SizedBox(height: 2),
              pw.Text('Généré le $dateStr', // date
                  style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
            ],
          ),
        ),
        pw.SizedBox(height: 8),
        pw.Text('Ton profil',
            style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 4),
        if (studentName != null && studentName.trim().isNotEmpty)
          inputLine('Nom', studentName),
        inputLine('Niveau d\'études', input.studyLevel ?? 'Non renseigné'),
        if ((input.bacSeries ?? '').isNotEmpty)
          inputLine('Série du bac', input.bacSeries!),
        inputLine(
            'Budget mensuel',
            input.monthlyBudgetEur != null
                ? '${input.monthlyBudgetEur} € / mois'
                : 'À confirmer'),
        inputLine('Niveau de français', input.frenchLevel.labelFr),
        inputLine('Niveau d\'anglais', input.englishLevel.labelFr),
        pw.SizedBox(height: 14),
        pw.Text('Verdicts par destination',
            style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 6),
        ...results.map(
          (r) => pw.Container(
            margin: const pw.EdgeInsets.only(bottom: 8),
            padding: const pw.EdgeInsets.all(8),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey300),
              borderRadius: pw.BorderRadius.circular(6),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(r.rule.nameFr,
                        style: pw.TextStyle(
                            fontSize: 11, fontWeight: pw.FontWeight.bold)),
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: pw.BoxDecoration(
                        color: _verdictColor(r.verdict),
                        borderRadius: pw.BorderRadius.circular(4),
                      ),
                      child: pw.Text(
                        '${r.verdictLabel.toUpperCase()} · ${r.score}%',
                        style: const pw.TextStyle(
                            fontSize: 8, color: PdfColors.white),
                      ),
                    ),
                  ],
                ),
                pw.SizedBox(height: 3),
                ...r.reasons.map(
                  (reason) => pw.Bullet(
                    text: reason,
                    style: const pw.TextStyle(fontSize: 8),
                    bulletColor: PdfColors.grey500,
                  ),
                ),
              ],
            ),
          ),
        ),
        pw.SizedBox(height: 8),
        pw.Text(
          'Estimation indicative générée par KPB Education. Les conditions définitives dépendent de chaque école et du consulat. Contacte ton conseiller KPB pour valider ton dossier.',
          style: pw.TextStyle(
              fontSize: 7,
              color: PdfColors.grey600,
              fontStyle: pw.FontStyle.italic),
        ),
      ],
    ),
  );

  await Printing.sharePdf(
    bytes: await doc.save(),
    filename: 'eligibilite_kpb.pdf',
  );
}
