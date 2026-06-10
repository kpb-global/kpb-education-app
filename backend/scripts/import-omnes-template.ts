import * as path from 'node:path';
import * as fs from 'node:fs';

// Template importer for OMNES catalog source file:
// OMNES_FALL_26_TOUT_PROGRAMME_030426.xlsx
//
// This script is intentionally safe:
// - validates expected columns
// - emits normalized JSON payload
// - does not write to DB directly
//
// Convert the generated JSON in a dedicated seed job after QA validation.

type OmnesRow = {
  school: string;
  campus: string;
  programName: string;
  programFamily: string;
  degreeLevel: string;
  admissionLevel: string;
  language: string;
  paymentUpfront: number | null;
  paymentInstallments: number | null;
  intakeDate: string | null;
};

const REQUIRED_COLUMNS = [
  'Ecole / School',
  'Campus',
  'NOM / NAME',
  'Type_Programme / Type of program',
  'Niveau_Etude_ / Level of studies',
  'Niveau Admission / Admission Level',
  'Langue / Language',
  'Payment Comptant / Payment Upfront',
  'Paiement Echelonné / With installments (2)',
  'Date_de_Rentrée / Intake Date',
] as const;

function normalizeLanguage(raw: unknown): string {
  const value = String(raw ?? '').trim().toUpperCase();
  switch (value) {
    case 'FR':
      return 'Français';
    case 'EN':
      return 'Anglais';
    case 'MX':
      return 'Mixte FR/EN';
    default:
      return String(raw ?? '').trim();
  }
}

function toNumberOrNull(raw: unknown): number | null {
  if (raw == null) return null;
  const text = String(raw).replace(/[^\d.,-]/g, '').replace(',', '.').trim();
  if (!text) return null;
  const parsed = Number(text);
  return Number.isFinite(parsed) ? parsed : null;
}

function ensureOutputDir(dir: string) {
  if (!fs.existsSync(dir)) fs.mkdirSync(dir, { recursive: true });
}

async function main() {
  const xlsxPath = process.argv[2];
  if (!xlsxPath) {
    throw new Error(
      'Usage: ts-node backend/scripts/import-omnes-template.ts <path-to-xlsx>',
    );
  }

  // Lazy import to avoid forcing xlsx at runtime unless importer is used.
  // eslint-disable-next-line @typescript-eslint/no-var-requires
  const XLSX = require('xlsx');

  const workbook = XLSX.readFile(xlsxPath);
  const sheetName = workbook.SheetNames[0];
  const sheet = workbook.Sheets[sheetName];
  const rows: Record<string, unknown>[] = XLSX.utils.sheet_to_json(sheet, {
    defval: '',
  });

  if (!rows.length) throw new Error('No rows found in OMNES source file.');

  const availableColumns = Object.keys(rows[0]);
  const missing = REQUIRED_COLUMNS.filter((name) => !availableColumns.includes(name));
  if (missing.length > 0) {
    throw new Error(`Missing required columns: ${missing.join(', ')}`);
  }

  const payload: OmnesRow[] = rows
    .filter((r) => String(r['Ecole / School'] ?? '').trim().length > 0)
    .map((r) => ({
      school: String(r['Ecole / School'] ?? '').trim(),
      campus: String(r['Campus'] ?? '').trim(),
      programName: String(r['NOM / NAME'] ?? '').trim(),
      programFamily: String(r['Type_Programme / Type of program'] ?? '').trim(),
      degreeLevel: String(r['Niveau_Etude_ / Level of studies'] ?? '').trim(),
      admissionLevel: String(r['Niveau Admission / Admission Level'] ?? '').trim(),
      language: normalizeLanguage(r['Langue / Language']),
      paymentUpfront: toNumberOrNull(r['Payment Comptant / Payment Upfront']),
      paymentInstallments: toNumberOrNull(
        r['Paiement Echelonné / With installments (2)'],
      ),
      intakeDate: String(r['Date_de_Rentrée / Intake Date'] ?? '').trim() || null,
    }))
    .filter((r) => r.programName.length > 0);

  const outputDir = path.resolve(__dirname, 'output');
  ensureOutputDir(outputDir);
  const outputPath = path.join(outputDir, 'omnes-programs-normalized.json');
  fs.writeFileSync(outputPath, JSON.stringify(payload, null, 2), 'utf-8');

  const schoolCount = new Set(payload.map((r) => r.school)).size;
  // eslint-disable-next-line no-console
  console.log(
    `Generated ${payload.length} normalized rows across ${schoolCount} schools -> ${outputPath}`,
  );
}

main().catch((error) => {
  // eslint-disable-next-line no-console
  console.error(error);
  process.exit(1);
});
