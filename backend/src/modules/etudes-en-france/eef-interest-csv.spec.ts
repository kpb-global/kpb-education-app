import {
  buildEefInterestCsv,
  csvCell,
  EefInterestCsvRow,
} from './eef-interest-csv';

function row(overrides: Partial<EefInterestCsvRow> = {}): EefInterestCsvRow {
  return {
    createdAt: new Date('2026-08-21T10:00:00Z'),
    consentedAt: new Date('2026-08-21T10:00:00Z'),
    consentVersion: 'eef-consent-v1',
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
      minority: 'adult',
    },
    ...overrides,
  };
}

describe('is_minor — trois états, et « inconnu » n\'est pas « non »', () => {
  const cellsOf = (csv: string, line = 1) =>
    csv.replace(/^\ufeff/, '').trimEnd().split('\r\n')[line].split(',');

  it.each([
    ['minor', '"oui"'],
    ['adult', '"non"'],
    ['unknown', '"inconnu"'],
  ] as const)('rend %s comme %s', (minority, expected) => {
    const csv = buildEefInterestCsv([
      row({ user: { ...row().user!, minority } }),
    ]);
    expect(cellsOf(csv)).toContain(expected);
  });

  it('un utilisateur absent est « inconnu », jamais « non »', () => {
    // Le sens de l'échec : faire passer pour majeur un profil dont on ignore la
    // date, c'est retirer à la personne qui appelle l'information dont elle a
    // besoin. « inconnu » lui dit de vérifier.
    const csv = buildEefInterestCsv([row({ user: null })]);
    expect(cellsOf(csv)).toContain('"inconnu"');
    expect(cellsOf(csv)).not.toContain('"non"');
  });
});

describe('troncature — elle s\'écrit dans le fichier', () => {
  it('ajoute une ligne d\'avertissement quand le plafond a coupé', () => {
    const csv = buildEefInterestCsv([row()], { totalRows: 25000, limit: 20000 });
    expect(csv).toContain('EXPORT TRONQUÉ');
    expect(csv).toContain('25000');
    expect(csv).toContain('ANCIENNES');
  });

  it('n\'ajoute RIEN quand rien n\'a été coupé', () => {
    // Un avertissement qui apparaît toujours ne se lit plus.
    expect(buildEefInterestCsv([row()], { totalRows: 1 })).not.toContain(
      'TRONQUÉ',
    );
    expect(buildEefInterestCsv([row()])).not.toContain('TRONQUÉ');
  });
});

describe('fieldIds nul — la colonne est nullable en SQL', () => {
  it('ne fait pas lever l\'extraction', () => {
    // Inatteignable par le code applicatif, atteignable par un backfill. Un
    // `.join` sur `null` aurait levé en pleine génération, et l'erreur aurait
    // été livrée comme un fichier .csv que quelqu'un ouvre dans Excel.
    expect(() =>
      buildEefInterestCsv([row({ fieldIds: null })]),
    ).not.toThrow();
  });
});

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
      const payload = `${trigger}HYPERLINK("https://invalid.test","clic")`;
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
