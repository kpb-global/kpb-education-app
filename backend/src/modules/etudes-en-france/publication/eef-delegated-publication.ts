import type { AdminSessionUser } from '../../auth/auth.service';
import type { InstitutionRefusal, ProgramRefusal } from './eef-publication.plan';
import type { EefPublicationService, PublishResult } from './eef-publication.service';

/**
 * La publication de l'import « Études en France » MENÉE PAR UN OUTIL, pour le compte
 * d'un administrateur qui l'a demandée.
 *
 * ## Pourquoi un second chemin, alors que l'écran admin publie déjà
 *
 * L'écran admin publie un établissement à la fois, sous la session de la personne
 * qui clique. Pour 84 établissements et 10 502 formations, le propriétaire a demandé
 * de ne pas cliquer 84 fois — et aucun outil n'a de session.
 *
 * ## Ce qui est identique, et ce qui ne l'est PAS
 *
 * Identique : l'outil appelle le MÊME service (`EefPublicationService`), donc le même
 * plan (`planEefPublication`), la même transaction `RepeatableRead` par établissement,
 * le même « tout ou rien », le même `expectedPrograms`.
 *
 * Différent, et c'est un affaiblissement réel de la garantie « le relecteur est la
 * personne qui a appuyé » (`eef-publication.controller.ts`) : ici le relecteur inscrit
 * est un compte administrateur CHOISI par une valeur de workflow, et non prouvé par une
 * session. Qui peut lancer ce workflow peut déjà déployer le backend ; la trace de qui
 * l'a lancé (`github.triggering_actor`) va dans l'audit, et le tampon dit « publication
 * déléguée » plutôt que de laisser croire à une relecture une à une.
 *
 * Ce que l'outil ajoute au-dessus du service :
 *
 *   • une **simulation par défaut** (l'application est un choix explicite), puis
 *     l'application des listes EXACTES que la simulation a produites ;
 *   • une **liste d'attente** : les formations dont la page-source a disparu
 *     (`eef-source-check.ts`) ne sont jamais envoyées au service — elles restent
 *     inactives, comme avant.
 *
 * Il ne remplace ni ne contourne la relecture métier des procédures
 * (`docs/eef-dossier-relecture-procedures.md`) : il ne la remplit pas.
 */

/** Ce que l'orchestrateur demande au service ; `EefPublicationService` y satisfait. */
export type PublishingService = Pick<EefPublicationService, 'publish'>;

export type InstitutionOutcome =
  | 'published' // écrit (ou, en simulation, publiable)
  | 'nothing' // rien à publier (déjà publié, ou tout en attente)
  | 'refused' // l'établissement lui-même est refusé par le plan
  | 'failed'; // l'écriture a échoué ; rien n'a été écrit pour cet établissement

export interface InstitutionReport {
  readonly institutionId: string;
  readonly institutionName: string;
  readonly outcome: InstitutionOutcome;
  readonly programsPublished: number;
  readonly programsHeldBack: number;
  readonly programsRefused: number;
  readonly institutionActivated: boolean;
  readonly refusals: readonly InstitutionRefusal[];
  /**
   * Les formations que cette passe publie (ou, en simulation, publierait) : c'est
   * CETTE liste que l'application réutilise, pas un nouveau calcul.
   */
  readonly programIds: readonly string[];
  readonly error?: string;
}

export interface DelegatedPublicationReport {
  readonly mode: 'dry-run' | 'applied';
  readonly institutions: readonly InstitutionReport[];
  readonly totals: {
    readonly institutions: number;
    readonly institutionsPublished: number;
    readonly institutionsRefused: number;
    readonly institutionsFailed: number;
    readonly institutionsNothingToDo: number;
    readonly programsPublished: number;
    readonly programsHeldBack: number;
    readonly programsRefused: number;
    readonly refusedByReason: Readonly<Record<string, number>>;
  };
  /** Vrai si au moins un établissement a échoué : le code de sortie doit le dire. */
  readonly hasFailures: boolean;
}

/**
 * Le tampon posé sur chaque ligne publiée. `verifierName()` du service retient
 * `fullName`, d'où la mention portée ici plutôt que dans un champ de plus.
 *
 * Ce tampon est PUBLIC : `mapEefProgram` recopie `verifiedByName` et `verifiedById`
 * dans la réponse non authentifiée de `/etudes-en-france/search` (c'est aussi le cas
 * d'une publication par l'écran admin). On n'y met donc NI l'e-mail (le service retombe
 * dessus quand le nom est vide), NI le compte GitHub de l'opérateur : celui-ci va dans
 * la ligne d'audit. Un compte sans nom signe « Administrateur KPB ».
 */
export function delegatedVerifier(admin: AdminSessionUser): AdminSessionUser {
  const base = admin.fullName.trim() || 'Administrateur KPB';
  return { ...admin, fullName: `${base} (publication déléguée)` };
}

export interface AdminCandidate {
  readonly id: string;
  readonly fullName: string;
  readonly email: string;
  readonly role: string;
  readonly isActive: boolean;
  readonly languageScope: readonly string[];
}

const PUBLISHING_ROLES: ReadonlySet<string> = new Set(['admin', 'super_admin']);

/** « a***@domaine » : de quoi reconnaître son compte, pas de quoi le recopier. */
function maskEmail(email: string): string {
  const at = email.lastIndexOf('@');
  if (at <= 0) return '***';
  return `${email.slice(0, 1)}***${email.slice(at)}`;
}

/**
 * Le compte administrateur au nom duquel l'outil publie — celui de l'écran admin :
 * actif, `admin` ou `super_admin` (jamais `content_manager`, qui édite le catalogue
 * sans signer sa publication).
 *
 * - Avec un e-mail : exactement ce compte, sinon refus.
 * - Sans e-mail : le SEUL `super_admin` actif ; à défaut, le SEUL compte éligible.
 *   Deviner entre deux reviendrait à signer au nom de la mauvaise personne : l'outil
 *   refuse alors, et liste les comptes éligibles MASQUÉS (« a***@domaine », avec leur
 *   rôle) pour que l'on sache lequel désigner. Aucun message ne recopie une adresse.
 */
export function pickVerifier(
  candidates: readonly AdminCandidate[],
  email: string | null,
): AdminSessionUser {
  const eligible = candidates.filter(
    (candidate) => candidate.isActive && PUBLISHING_ROLES.has(candidate.role),
  );
  const wanted = email?.trim().toLowerCase() ?? '';
  let matches: AdminCandidate[];
  if (wanted) {
    matches = eligible.filter((candidate) => candidate.email.trim().toLowerCase() === wanted);
  } else {
    const supers = eligible.filter((candidate) => candidate.role === 'super_admin');
    matches = supers.length > 0 ? supers : eligible;
  }
  if (matches.length !== 1) {
    const known = eligible.map((c) => `${maskEmail(c.email)} (${c.role})`).join(', ') || 'aucun';
    throw new Error(
      wanted
        ? `Aucun compte administrateur actif (admin ou super_admin) ne porte cet e-mail. Comptes éligibles : ${known}.`
        : `${matches.length} compte(s) éligible(s) : précisez le relecteur avec --verifier-email. Comptes éligibles : ${known}.`,
    );
  }
  const [admin] = matches;
  return {
    id: admin.id,
    fullName: admin.fullName,
    email: admin.email,
    role: admin.role,
    languageScope: [...admin.languageScope],
  };
}

export interface DelegatedPublicationInput {
  readonly service: PublishingService;
  readonly institutionIds: readonly string[];
  /** Formations à ne PAS publier : jamais transmises au service. */
  readonly holdback: ReadonlySet<string>;
  readonly apply: boolean;
  readonly verifier: AdminSessionUser;
  /**
   * Pour écrire : le rapport de la SIMULATION, dont on applique les listes exactes.
   * Sans lui, une écriture recalculerait ses listes, et le total saisi (comparé une
   * fois, avant la boucle) ne protégerait plus rien si la base bouge pendant la boucle.
   * Avec lui, une formation qui n'est plus publiable ou qui est publiée entre-temps
   * fait échouer son établissement (409 du service, rien d'écrit pour lui).
   */
  readonly simulation?: DelegatedPublicationReport;
  readonly log?: (line: string) => void;
}

function tally(
  into: Record<string, number>,
  reasons: readonly ProgramRefusal[],
): void {
  for (const reason of reasons) into[reason] = (into[reason] ?? 0) + 1;
}

export async function runDelegatedPublication(
  input: DelegatedPublicationInput,
): Promise<DelegatedPublicationReport> {
  const log = input.log ?? (() => undefined);
  const refusedByReason: Record<string, number> = {};
  const reports: InstitutionReport[] = [];

  for (const institutionId of input.institutionIds) {
    let report: InstitutionReport;
    try {
      report = input.apply && input.simulation
        ? await applySimulated(input, institutionId)
        : await publishOne(input, institutionId, refusedByReason);
    } catch (error) {
      // Une erreur sur UN établissement (conflit d'écriture, base) n'arrête pas les
      // autres : la transaction de celui-ci est annulée en entier, les suivants sont
      // indépendants. Le code de sortie, lui, le dit.
      report = {
        institutionId,
        institutionName: institutionId,
        outcome: 'failed',
        programsPublished: 0,
        programsHeldBack: 0,
        programsRefused: 0,
        institutionActivated: false,
        refusals: [],
        programIds: [],
        error: error instanceof Error ? error.message : String(error),
      };
    }
    reports.push(report);
    log(describe(report, input.apply));
  }

  const sum = (pick: (r: InstitutionReport) => number) =>
    reports.reduce((n, r) => n + pick(r), 0);
  const count = (outcome: InstitutionOutcome) =>
    reports.filter((r) => r.outcome === outcome).length;
  return {
    mode: input.apply ? 'applied' : 'dry-run',
    institutions: reports,
    totals: {
      institutions: reports.length,
      institutionsPublished: count('published'),
      institutionsRefused: count('refused'),
      institutionsFailed: count('failed'),
      institutionsNothingToDo: count('nothing'),
      programsPublished: sum((r) => r.programsPublished),
      programsHeldBack: sum((r) => r.programsHeldBack),
      programsRefused: sum((r) => r.programsRefused),
      refusedByReason,
    },
    hasFailures: reports.some((r) => r.outcome === 'failed'),
  };
}

async function publishOne(
  input: DelegatedPublicationInput,
  institutionId: string,
  refusedByReason: Record<string, number>,
): Promise<InstitutionReport> {
  const { service, holdback, verifier } = input;

  // 1. Le plan complet : ce que le service publierait de lui-même.
  const preview = await service.publish(institutionId, { apply: false, verifier });
  const plan = preview.plan;
  const base = {
    institutionId,
    institutionName: plan.institutionName,
    refusals: plan.institution.refusals,
    programsRefused: plan.programs.refused.length,
  };
  for (const program of plan.programs.refused) {
    tally(refusedByReason, program.reasons);
  }

  if (plan.institution.refusals.length > 0) {
    return {
      ...base,
      outcome: 'refused',
      programsPublished: 0,
      programsHeldBack: 0,
      institutionActivated: false,
      programIds: [],
    };
  }

  // 2. La liste d'attente se retire ICI, avant le service : une formation dont la
  //    page a disparu n'est pas « refusée par le plan », elle est mise de côté.
  const ids = plan.programs.toPublish.filter((id) => !holdback.has(id));
  const heldBack = plan.programs.toPublish.length - ids.length;
  if (ids.length === 0) {
    return {
      ...base,
      outcome: 'nothing',
      programsPublished: 0,
      programsHeldBack: heldBack,
      institutionActivated: false,
      programIds: [],
    };
  }

  // 3. Simulation : le plan RESTREINT à ces formations (il revalide aussi celles
  //    déjà actives du parent). Écriture : le service recalcule dans sa transaction.
  const result: PublishResult = await service.publish(institutionId, {
    apply: input.apply,
    programIds: ids,
    expectedPrograms: ids.length,
    verifier,
  });
  if (result.mode === 'applied') {
    return {
      ...base,
      outcome: 'published',
      programsPublished: result.programsPublished,
      programsHeldBack: heldBack,
      institutionActivated: result.institutionActivated,
      programIds: ids,
    };
  }
  return {
    ...base,
    outcome: result.plan.publishable ? 'published' : 'nothing',
    programsPublished: result.plan.programs.toPublish.length,
    programsHeldBack: heldBack,
    institutionActivated: result.plan.institution.willActivate,
    programIds: result.plan.publishable ? [...result.plan.programs.toPublish] : [],
  };
}

/**
 * L'écriture : pour chaque établissement, les formations EXACTES de la simulation et
 * leur nombre comme `expectedPrograms`. Un établissement que la simulation ne publiait
 * pas n'est pas même transmis au service. Le service recalcule dans sa transaction : si
 * la base a bougé (formation devenue invalide, publiée par un autre), il lève un 409 et
 * rien n'est écrit pour cet établissement.
 */
async function applySimulated(
  input: DelegatedPublicationInput,
  institutionId: string,
): Promise<InstitutionReport> {
  const planned = input.simulation?.institutions.find(
    (report) => report.institutionId === institutionId,
  );
  if (!planned || planned.outcome !== 'published' || planned.programIds.length === 0) {
    return planned
      ? { ...planned, programsPublished: 0, institutionActivated: false, programIds: [] }
      : {
          institutionId,
          institutionName: institutionId,
          outcome: 'nothing',
          programsPublished: 0,
          programsHeldBack: 0,
          programsRefused: 0,
          institutionActivated: false,
          refusals: [],
          programIds: [],
        };
  }
  const result = await input.service.publish(institutionId, {
    apply: true,
    programIds: planned.programIds,
    expectedPrograms: planned.programIds.length,
    verifier: input.verifier,
  });
  if (result.mode !== 'applied') {
    throw new Error('Le service a répondu par une simulation à une demande d’écriture.');
  }
  return {
    ...planned,
    outcome: 'published',
    programsPublished: result.programsPublished,
    institutionActivated: result.institutionActivated,
  };
}

function describe(report: InstitutionReport, apply: boolean): string {
  const verb = apply ? 'publiée(s)' : 'publiable(s)';
  switch (report.outcome) {
    case 'published':
      return (
        `✓ ${report.institutionName} : ${report.programsPublished} formation(s) ${verb}`
        + (report.programsHeldBack > 0 ? `, ${report.programsHeldBack} en attente (page morte)` : '')
        + (report.programsRefused > 0 ? `, ${report.programsRefused} refusée(s) par le plan` : '')
        + (report.institutionActivated ? ' — établissement activé' : '')
      );
    case 'nothing':
      return (
        `· ${report.institutionName} : rien à publier`
        + (report.programsHeldBack > 0 ? ` (${report.programsHeldBack} en attente : page morte)` : '')
      );
    case 'refused':
      return `✗ ${report.institutionName} : établissement refusé (${report.refusals.join(', ')})`;
    case 'failed':
      return `✗ ${report.institutionId} : ÉCHEC, rien n'a été écrit pour lui — ${report.error ?? 'raison inconnue'}`;
  }
}
