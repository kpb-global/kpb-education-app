import {
  buildEefInterestCsv,
  csvCell,
  EefInterestCsvRow,
} from './eef-interest-csv';

function row(overrides: Partial<EefInterestCsvRow> = {}): EefInterestCsvRow {
  return {
    createdAt: new Date('2026-08-21T10:00:00Z'),
    consentedAt: new Date('2026-08-21T10:00:00Z'),
    userId: 'user-1',
    currentLevel: 'terminale',
    targetLevel: 'licence',
    fieldIds: ['info', 'sante'],
    wantsPremium: true,
    user: {
      fullName: 'Aïcha Diallo',
      email: 'aicha@example.test',
      phone: '+22790000000',
      whatsApp: null,
      countryOfResidence: "Côte d'Ivoire",
    },
    ...overrides,
  };
}

describe('csvCell', () => {
  it('quotes every cell and doubles inner quotes (RFC 4180)', () => {
    expect(csvCell('Droit, économie')).toBe('"Droit, économie"');
    expect(csvCell('dit "bonjour"')).toBe('"dit ""bonjour"""');
    expect(csvCell('deux\nlignes')).toBe('"deux\nlignes"');
  });

  it('renders null and undefined as an empty cell, not as "null"', () => {
    expect(csvCell(null)).toBe('""');
    expect(csvCell(undefined)).toBe('""');
  });

  // LE test de sécurité de ce fichier. Excel, LibreOffice et Sheets évaluent
  // toute cellule commençant par = + - @ tab ou CR. Les guillemets de la
  // RFC 4180 n'y changent rien : le tableur déguillemette AVANT d'évaluer.
  // Un niveau déclaré `=HYPERLINK(...)` exfiltrerait la ligne voisine dès
  // qu'un commercial ouvre le fichier.
  it.each(['=', '+', '-', '@', '\t', '\r'])(
    'neutralizes a cell starting with %j so a spreadsheet cannot evaluate it',
    (trigger) => {
      const payload = `${trigger}HYPERLINK("https://x.test","clic")`;
      const cell = csvCell(payload);

      // Le contenu reste lisible — on ne supprime rien, on désamorce.
      expect(cell).toContain('HYPERLINK');
      // Mais le premier caractère de la valeur n'est plus le déclencheur.
      expect(cell.startsWith(`"'${trigger}`)).toBe(true);
    },
  );

  it('leaves an ordinary value untouched apart from quoting', () => {
    expect(csvCell('terminale')).toBe('"terminale"');
    expect(csvCell('2+2')).toBe('"2+2"');
  });
});

describe('buildEefInterestCsv', () => {
  it('starts with a UTF-8 BOM so Excel on Windows keeps the accents', () => {
    const csv = buildEefInterestCsv([row()]);
    expect(csv.charCodeAt(0)).toBe(0xfeff);
    expect(csv).toContain("Côte d'Ivoire");
  });

  it('writes the header even when there is nothing to export', () => {
    const csv = buildEefInterestCsv([]);
    expect(csv).toContain('"declared_at"');
    expect(csv).toContain('"wants_premium"');
    expect(csv.trimEnd().split('\r\n')).toHaveLength(1);
  });

  it('renders the premium flag in the language the team reads', () => {
    expect(buildEefInterestCsv([row({ wantsPremium: true })])).toContain('"oui"');
    expect(buildEefInterestCsv([row({ wantsPremium: false })])).toContain('"non"');
  });

  it('joins field ids into one cell instead of shifting the columns', () => {
    const csv = buildEefInterestCsv([row({ fieldIds: ['info', 'sante'] })]);
    expect(csv).toContain('"info | sante"');
  });

  // Un profil supprimé laisse la déclaration orpheline le temps d'une cascade,
  // ou un `include` peut rendre null. L'export doit produire une ligne
  // incomplète et lisible, pas planter en pleine extraction.
  it('exports a row whose user could not be joined', () => {
    const csv = buildEefInterestCsv([row({ user: null })]);
    expect(csv).toContain('"user-1"');
    expect(csv.trimEnd().split('\r\n')).toHaveLength(2);
  });
});
