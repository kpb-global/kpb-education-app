// ─────────────────────────────────────────────────────────────────────────────
// Les avis conseillers, par le CONTRÔLEUR — et par HTTP.
//
// POURQUOI PAR LE CONTRÔLEUR
//
// Le défaut que ce fichier garde est né précisément entre le contrôleur et le
// service : le corps de `POST /counsellors/:id/reviews` était un type en ligne,
// effacé à l'exécution, donc la `ValidationPipe` ne validait rien, et le service
// recopiait `reviewerUserId` depuis ce que le client envoyait. L'app ne
// l'envoyait pas : tous les avis avaient un auteur NULL, la suppression de
// compte n'en trouvait aucun, et le nom civil de l'étudiant survivait à
// l'effacement de son compte.
//
// Le test d'intégration existant (`profiles.postgres.spec.ts`) posait
// `reviewerUserId` À LA MAIN dans un `prisma.create` : il prouvait que la
// suppression sait effacer un avis QUI A un auteur, et rien sur le fait qu'un
// avis réel en ait un. Un test qui contourne le chemin défaillant ne peut pas le
// voir défaillir.
//
// Celui-ci monte une vraie application Nest, avec la `ValidationPipe` de
// `main.ts`, et parle HTTP : ce qui est validé, ce qui est rejeté et ce qui est
// écrit sont observés là où ils se produisent.
// ─────────────────────────────────────────────────────────────────────────────
import { readFileSync } from 'node:fs';
import { join } from 'node:path';

import {
  type ExecutionContext,
  type INestApplication,
  ValidationPipe,
} from '@nestjs/common';
import { Test } from '@nestjs/testing';
import * as ts from 'typescript';

import { GlobalExceptionFilter } from '../../common/filters/http-exception.filter';
import { StudentAuthGuard } from '../../common/guards/student-auth.guard';
import { PrismaService } from '../prisma/prisma.service';
import { CounsellorsController } from './counsellors.controller';
import { CounsellorsService } from './counsellors.service';

/** L'utilisateur que le jeton vérifié désigne. */
const CALLER = {
  id: 'user-caller',
  email: 'caller@example.org',
  fullName: 'Awa Diallo',
  role: 'student' as const,
  accountType: 'student' as const,
};

const CASE_OK = {
  id: 'case-1',
  userId: CALLER.id,
  counsellorId: 'counsellor-1',
  status: 'completed',
};

interface FakeOptions {
  cases?: Record<string, { userId: string; counsellorId: string | null; status: string }>;
  /** Les identifiants de dossier qui portent DÉJÀ un avis, de n'importe quel auteur. */
  reviewedCases?: string[];
  /** Les notes des avis déjà PUBLIÉS du conseiller (ils alimentent ses compteurs). */
  publishedRatings?: number[];
  isEnabled?: boolean;
  caller?: Partial<typeof CALLER>;
}

/** Une base simulée qui ENREGISTRE ce qui est écrit. */
function fakeDatabase(opts: FakeOptions) {
  const cases = opts.cases ?? { 'case-1': CASE_OK };
  const creates: Array<Record<string, unknown>> = [];
  const counterUpdates: Array<Record<string, unknown>> = [];
  const client = {
    case: {
      findUnique: async (args: { where: { id: string } }) =>
        cases[args.where.id] ?? null,
    },
    counsellorReview: {
      create: async (args: { data: Record<string, unknown> }) => {
        creates.push(args.data);
        return { id: 'review-1', ...args.data };
      },
      findMany: async () =>
        (opts.publishedRatings ?? []).map((rating) => ({ rating })),
      findFirst: async (args: { where: { caseId?: string } }) =>
        (opts.reviewedCases ?? []).includes(args.where.caseId ?? '')
          ? { id: 'review-existing' }
          : null,
    },
    counsellor: {
      update: async (args: Record<string, unknown>) => {
        counterUpdates.push(args);
        return {};
      },
    },
  };
  const prisma = {
    isEnabled: opts.isEnabled ?? true,
    execute: async (operation: (c: typeof client) => Promise<unknown>) =>
      (opts.isEnabled ?? true) ? operation(client) : null,
  };
  return { prisma, creates, counterUpdates };
}

async function startApp(opts: FakeOptions = {}) {
  const db = fakeDatabase(opts);
  const moduleRef = await Test.createTestingModule({
    controllers: [CounsellorsController],
    providers: [
      CounsellorsService,
      { provide: PrismaService, useValue: db.prisma },
    ],
  })
    // Le garde authentifie par jeton Supabase ; ici on lui substitue un garde
    // qui pose l'utilisateur VÉRIFIÉ, exactement comme le vrai le fait.
    .overrideGuard(StudentAuthGuard)
    .useValue({
      canActivate: (context: ExecutionContext) => {
        context.switchToHttp().getRequest().studentUser = {
          ...CALLER,
          ...opts.caller,
        };
        return true;
      },
    })
    .compile();

  const app: INestApplication = moduleRef.createNestApplication();
  // Les options de `main.ts`. Le test qui suit vérifie qu'elles n'ont pas bougé.
  app.useGlobalPipes(
    new ValidationPipe({
      whitelist: true,
      forbidNonWhitelisted: true,
      transform: true,
    }),
  );
  // Et le filtre de `main.ts` : sans lui, les corps d'erreur de ce test sont ceux
  // de Nest, déterministes — alors que ceux de la production portent un
  // `requestId` et un `timestamp`. Un test qui compare des corps sans lui prouve
  // une propriété que la production n'a pas.
  app.useGlobalFilters(new GlobalExceptionFilter());
  await app.listen(0, '127.0.0.1');
  const address = app.getHttpServer().address() as { port: number };
  const base = `http://127.0.0.1:${address.port}`;

  async function post(counsellorId: string, body: unknown) {
    const response = await fetch(`${base}/counsellors/${counsellorId}/reviews`, {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify(body),
    });
    const text = await response.text();
    return {
      status: response.status,
      body: text ? (JSON.parse(text) as Record<string, unknown>) : null,
    };
  }
  return { app, post, ...db };
}

/** Le corps EXACT que les builds 49 à 53 envoient (`submitCounsellorReview`). */
const OLD_CLIENT_BODY = {
  rating: 5,
  body: 'Très bon accompagnement.',
  reviewerName: 'Nom envoyé par le client',
  caseId: 'case-1',
};

describe('POST /counsellors/:id/reviews', () => {
  let started: Awaited<ReturnType<typeof startApp>> | null = null;
  afterEach(async () => {
    await started?.app.close();
    started = null;
  });

  async function withApp(opts: FakeOptions = {}) {
    started = await startApp(opts);
    return started;
  }

  // ── L'auteur est celui du jeton ────────────────────────────────────────────

  describe('l’auteur est celui du jeton', () => {
    it('enregistre l’utilisateur VÉRIFIÉ comme auteur', async () => {
      // LE test. Le corps envoyé par l'app ne porte aucun auteur ; c'est le
      // jeton qui doit le fournir. Sans lui, `reviewerUserId` valait NULL et la
      // suppression de compte ne trouvait pas l'avis.
      const { post, creates } = await withApp();

      const response = await post('counsellor-1', OLD_CLIENT_BODY);

      expect(response.status).toBe(201);
      expect(creates).toHaveLength(1);
      expect(creates[0].reviewerUserId).toBe(CALLER.id);
    });

    it('signe du nom du PROFIL, pas de celui que le client déclare', async () => {
      // Sinon n'importe qui signerait « Marie Curie » : ce nom est affiché
      // publiquement sur l'accueil, avec le consentement de l'auteur.
      const { post, creates } = await withApp();

      await post('counsellor-1', OLD_CLIENT_BODY);

      expect(creates[0].reviewerName).toBe('Awa Diallo');
      expect(creates[0].reviewerName).not.toBe(OLD_CLIENT_BODY.reviewerName);
    });

    it('n’accepte pas qu’un client désigne un AUTRE auteur', async () => {
      // `reviewerUserId` n'est pas déclaré dans le DTO : la pipe globale répond
      // 400 au lieu de l'ignorer en silence, et RIEN n'est écrit.
      const { post, creates } = await withApp();

      const response = await post('counsellor-1', {
        ...OLD_CLIENT_BODY,
        reviewerUserId: 'user-victim',
      });

      expect(response.status).toBe(400);
      expect(creates).toEqual([]);
    });

    it('retombe sur « KPB » quand le profil n’a pas de nom', async () => {
      // Le comportement de l'ancienne app (`fullName ?? 'KPB'`), conservé.
      const { post, creates } = await withApp({ caller: { fullName: '  ' } });

      await post('counsellor-1', OLD_CLIENT_BODY);

      expect(creates[0].reviewerName).toBe('KPB');
    });

    it('publie l’avis en attente de modération, jamais directement', async () => {
      const { post, creates } = await withApp();
      await post('counsellor-1', OLD_CLIENT_BODY);
      expect(creates[0].isPublished).toBe(false);
    });

    it('rafraîchit les compteurs du conseiller sur ses avis PUBLIÉS', async () => {
      // Le nouvel avis naît non publié : il n'entre pas dans la moyenne. Les
      // compteurs suivent les deux avis déjà publiés (4 et 5 étoiles).
      const { post, counterUpdates } = await withApp({
        publishedRatings: [4, 5],
      });
      await post('counsellor-1', OLD_CLIENT_BODY);
      expect(counterUpdates).toEqual([
        { where: { id: 'counsellor-1' }, data: { avgRating: 4.5, reviewCount: 2 } },
      ]);
    });

    it('ramène les compteurs à zéro quand aucun avis n’est publié', async () => {
      const { post, counterUpdates } = await withApp();
      await post('counsellor-1', OLD_CLIENT_BODY);
      expect(counterUpdates).toEqual([
        { where: { id: 'counsellor-1' }, data: { avgRating: 0, reviewCount: 0 } },
      ]);
    });
  });

  // ── Compatibilité avec les builds installées ───────────────────────────────

  describe('les builds 49 à 53 continuent de fonctionner', () => {
    it('accepte le corps exact que l’app envoie, `reviewerName` compris', async () => {
      // La pipe refuse les champs inconnus. Ne pas déclarer `reviewerName`
      // ferait répondre 400 à TOUS les avis des builds installées : un
      // correctif de sécurité qui casserait la fonctionnalité qu'il protège.
      const { post } = await withApp();
      const response = await post('counsellor-1', OLD_CLIENT_BODY);
      expect(response.status).toBe(201);
    });

    it('accepte un témoignage vide : seule la note est obligatoire', async () => {
      const { post, creates } = await withApp();
      const response = await post('counsellor-1', {
        ...OLD_CLIENT_BODY,
        body: '',
      });
      expect(response.status).toBe(201);
      expect(creates[0].body).toBe('');
    });
  });

  // ── Validation du corps ────────────────────────────────────────────────────

  describe('le corps est validé', () => {
    it.each([
      ['note 0', { rating: 0 }],
      ['note 6', { rating: 6 }],
      ['note décimale', { rating: 3.5 }],
      ['note en chaîne', { rating: '5' }],
      ['note absente', { rating: undefined }],
      ['témoignage absent', { body: undefined }],
      ['témoignage qui n’est pas un texte', { body: 12345 }],
      ['nom déclaré qui n’est pas un texte', { reviewerName: 42 }],
      ['dossier absent', { caseId: undefined }],
      ['dossier vide', { caseId: '' }],
    ])('répond 400 : %s', async (_label, override) => {
      const { post, creates } = await withApp();
      const response = await post('counsellor-1', {
        ...OLD_CLIENT_BODY,
        ...override,
      });
      expect(response.status).toBe(400);
      expect(creates).toEqual([]);
    });

    it('accepte les bornes : notes 1 et 5, témoignage de 1000 caractères', async () => {
      const { post } = await withApp();
      for (const override of [
        { rating: 1 },
        { rating: 5 },
        { body: 'x'.repeat(1000) },
      ]) {
        const response = await post('counsellor-1', {
          ...OLD_CLIENT_BODY,
          ...override,
        });
        expect(response.status).toBe(201);
      }
    });

    it('TRONQUE un témoignage trop long au lieu de le refuser', async () => {
      // Le champ de saisie de l'app n'a aucune limite, et l'écran répond
      // « Réessaie plus tard » à toute erreur avant de marquer le dossier comme
      // noté quoi qu'il arrive : un 400 ferait perdre à l'étudiant un texte qu'il
      // vient de rédiger, sans qu'il puisse le rejouer.
      const { post, creates } = await withApp();

      const response = await post('counsellor-1', {
        ...OLD_CLIENT_BODY,
        body: `${'a'.repeat(1000)}${'b'.repeat(500)}`,
      });

      expect(response.status).toBe(201);
      expect(creates[0].body).toBe('a'.repeat(1000));
    });

    it('ne coupe pas un emoji en deux en tronquant', async () => {
      // Un emoji vaut DEUX unités UTF-16. Coupé au milieu, il laisse un substitut
      // HAUT isolé, que Prisma rejette : la troncature qui devait préserver le
      // texte de l'étudiant le perdait en 500.
      const { post, creates } = await withApp();

      const response = await post('counsellor-1', {
        ...OLD_CLIENT_BODY,
        body: `${'a'.repeat(999)}😀${'b'.repeat(50)}`,
      });

      expect(response.status).toBe(201);
      const stored = creates[0].body as string;
      expect(stored).toBe('a'.repeat(999));
      // `encodeURIComponent` lève sur une chaîne mal formée : c'est le critère
      // même de la base.
      expect(() => encodeURIComponent(stored)).not.toThrow();
    });

    it('garde un emoji entier quand il tient dans la limite', async () => {
      const { post, creates } = await withApp();
      const body = `${'a'.repeat(998)}😀`; // 998 + 2 unités = 1000, pile
      await post('counsellor-1', { ...OLD_CLIENT_BODY, body });
      expect(creates[0].body).toBe(body);
    });

    it('retire l’octet NUL, que Postgres refuse', async () => {
      const { post, creates } = await withApp();
      const response = await post('counsellor-1', {
        ...OLD_CLIENT_BODY,
        body: 'Très bien  encadré',
      });
      expect(response.status).toBe(201);
      expect(creates[0].body).toBe('Très bien encadré');
    });

    it('remplace un substitut isolé envoyé par le client', async () => {
      // JSON permet `\ud83d` seul ; Prisma refuse la chaîne qui en résulte.
      const { post, creates } = await withApp();
      const response = await post('counsellor-1', {
        ...OLD_CLIENT_BODY,
        body: 'avant \ud83d après',
      });
      expect(response.status).toBe(201);
      expect(() => encodeURIComponent(creates[0].body as string)).not.toThrow();
    });

    it.each([
      ['un octet NUL', 'case\u0000-1'],
      ['un espace', 'case 1'],
      ['une barre oblique', 'case/1'],
      ['un guillemet', "case'1"],
    ])('refuse un identifiant de dossier qui contient %s', async (_label, caseId) => {
      const { post, creates } = await withApp();
      const response = await post('counsellor-1', { ...OLD_CLIENT_BODY, caseId });
      expect(response.status).toBe(400);
      expect(creates).toEqual([]);
    });

    it('accepte un nom déclaré de toute longueur : il est ignoré, pas jugé', async () => {
      // Le profil ne borne pas `fullName` : un étudiant au nom long enverrait un
      // `reviewerName` que la validation refuserait, pour une valeur qu'on ne lit
      // jamais.
      const { post, creates } = await withApp();

      const response = await post('counsellor-1', {
        ...OLD_CLIENT_BODY,
        reviewerName: 'N'.repeat(5000),
      });

      expect(response.status).toBe(201);
      expect(creates[0].reviewerName).toBe('Awa Diallo');
    });
  });

  // ── Le dossier prouve le droit de noter ────────────────────────────────────

  describe('le dossier prouve le droit de noter', () => {
    it('refuse le dossier d’un AUTRE utilisateur, sans écrire', async () => {
      const { post, creates } = await withApp({
        cases: {
          'case-1': { ...CASE_OK, userId: 'user-someone-else' },
        },
      });
      const response = await post('counsellor-1', OLD_CLIENT_BODY);
      expect(response.status).toBe(404);
      expect(creates).toEqual([]);
    });

    it('ne distingue pas un dossier d’autrui d’un dossier inexistant', async () => {
      // Deux réponses différentes confirmeraient l'existence du dossier
      // d'autrui à qui essaie des identifiants.
      const foreign = await withApp({
        cases: { 'case-1': { ...CASE_OK, userId: 'user-someone-else' } },
      });
      const foreignResponse = await foreign.post('counsellor-1', OLD_CLIENT_BODY);
      await foreign.app.close();

      const unknown = await withApp({ cases: {} });
      const unknownResponse = await unknown.post('counsellor-1', OLD_CLIENT_BODY);

      // Le filtre de production ajoute un identifiant de requête et une date à
      // chaque erreur : ils diffèrent d'un appel à l'autre par construction. Tout
      // le reste doit être identique.
      const stable = (body: Record<string, unknown> | null) => {
        const { requestId, timestamp, ...rest } = body ?? {};
        void requestId;
        void timestamp;
        return rest;
      };
      expect(foreignResponse.status).toBe(unknownResponse.status);
      expect(stable(foreignResponse.body)).toEqual(stable(unknownResponse.body));
    });

    it('refuse un dossier traité par un AUTRE conseiller', async () => {
      const { post, creates } = await withApp({
        cases: { 'case-1': { ...CASE_OK, counsellorId: 'counsellor-other' } },
      });
      const response = await post('counsellor-1', OLD_CLIENT_BODY);
      expect(response.status).toBe(403);
      expect(creates).toEqual([]);
    });

    it('refuse un dossier sans conseiller assigné', async () => {
      const { post, creates } = await withApp({
        cases: { 'case-1': { ...CASE_OK, counsellorId: null } },
      });
      const response = await post('counsellor-1', OLD_CLIENT_BODY);
      expect(response.status).toBe(403);
      expect(creates).toEqual([]);
    });

    it.each(['draft', 'submitted', 'in_progress', 'waiting_decision', 'rejected'])(
      'refuse un dossier non terminé : %s',
      async (status) => {
        const { post, creates } = await withApp({
          cases: { 'case-1': { ...CASE_OK, status } },
        });
        const response = await post('counsellor-1', OLD_CLIENT_BODY);
        expect(response.status).toBe(409);
        expect(creates).toEqual([]);
      },
    );

    it('refuse un second avis sur le même dossier', async () => {
      // Aucune contrainte d'unicité en base : sans cette garde, un double envoi
      // ou un utilisateur qui insiste empile des avis, et un modérateur qui
      // publie deux doublons compte deux fois.
      const { post, creates } = await withApp({ reviewedCases: ['case-1'] });

      const response = await post('counsellor-1', OLD_CLIENT_BODY);

      expect(response.status).toBe(409);
      expect(creates).toEqual([]);
    });

    it('ne laisse pas la garde du doublon masquer une erreur plus précise', async () => {
      // Un dossier d'autrui qui porte déjà un avis répond 404 comme un dossier
      // inconnu : le doublon ne doit pas devenir un oracle sur le dossier d'un
      // autre.
      const { post } = await withApp({
        cases: { 'case-1': { ...CASE_OK, userId: 'user-someone-else' } },
        reviewedCases: ['case-1'],
      });

      const response = await post('counsellor-1', OLD_CLIENT_BODY);

      expect(response.status).toBe(404);
    });
  });

  // ── Base absente ───────────────────────────────────────────────────────────

  it('répond 503 sans base, au lieu d’un 201 au corps vide', async () => {
    // `execute` rend `null` quand aucune base n'est configurée. L'ancien code
    // renvoyait ce `null` : un étudiant persuadé d'avoir noté son conseiller
    // alors que rien n'avait été écrit. (Le garde est remplacé ici : avec le
    // vrai, l'absence de base répond 401 avant le service. Ce test garde le
    // service, la défense en profondeur.)
    const { post, creates } = await withApp({ isEnabled: false });
    const response = await post('counsellor-1', OLD_CLIENT_BODY);
    expect(response.status).toBe(503);
    expect(creates).toEqual([]);
  });
});

// ─── La fiche publique ───────────────────────────────────────────────────────

describe('GET /counsellors/:id — ce que la fiche publique sert des avis', () => {
  // Sans `select`, Prisma rend TOUTES les colonnes d'un avis : `reviewerUserId`,
  // la clé de rattachement au profil, et `caseId` sortaient sur cette route
  // publique. Tant que l'auteur restait NULL, la première ne pouvait rien
  // révéler ; il est renseigné désormais. La preuve sur base réelle vit dans
  // `counsellors.reviews.postgres.spec.ts` — mais elle est sautée tant que la CI
  // unitaire est rouge : celle-ci tient toujours.
  async function capturedSelect() {
    let captured: { select: { reviews: Record<string, unknown> } } | null = null;
    const prisma = {
      isEnabled: true,
      execute: async (operation: (client: unknown) => Promise<unknown>) =>
        operation({
          counsellor: {
            findFirst: async (args: {
              select: { reviews: Record<string, unknown> };
            }) => {
              captured = args;
              return { id: 'counsellor-1', reviews: [] };
            },
          },
        }),
    };
    await new CounsellorsService(prisma as unknown as PrismaService).getPublic(
      'counsellor-1',
    );
    return captured!.select.reviews as {
      where: Record<string, unknown>;
      select: Record<string, boolean>;
    };
  }

  it('ne lit que les colonnes publiques des avis', async () => {
    const reviews = await capturedSelect();

    expect(Object.keys(reviews.select).sort()).toEqual([
      'body',
      'counsellorId',
      'createdAt',
      'id',
      'rating',
      'reviewerName',
    ]);
    expect(reviews.select).not.toHaveProperty('reviewerUserId');
    expect(reviews.select).not.toHaveProperty('caseId');
    expect(reviews.select).not.toHaveProperty('isPublished');
  });

  it('ne sert que les avis publiés', async () => {
    const reviews = await capturedSelect();
    expect(reviews.where).toEqual({ isPublished: true });
  });
});

/** Les options passées à `new ValidationPipe(...)`, lues dans le source. */
function validationPipeOptions(source: string): Record<string, string> {
  const file = ts.createSourceFile('main.ts', source, ts.ScriptTarget.Latest, true);
  const options: Record<string, string> = {};
  const visit = (node: ts.Node) => {
    if (
      ts.isNewExpression(node) &&
      ts.isIdentifier(node.expression) &&
      node.expression.text === 'ValidationPipe'
    ) {
      const argument = node.arguments?.[0];
      if (argument && ts.isObjectLiteralExpression(argument)) {
        for (const property of argument.properties) {
          if (ts.isPropertyAssignment(property)) {
            options[property.name.getText(file)] = property.initializer.getText(file);
          } else if (ts.isSpreadAssignment(property)) {
            options['<spread>'] = '<non littéral>';
          } else {
            options[property.name?.getText(file) ?? '<inconnu>'] = '<non littéral>';
          }
        }
      } else {
        options['<arguments>'] = '<non littéral>';
      }
    }
    ts.forEachChild(node, visit);
  };
  visit(file);
  return options;
}

// ─── Ce qui rend les tests ci-dessus représentatifs ──────────────────────────

describe('les avis conseillers — garde-fous du test lui-même', () => {
  it('la route reste derrière le garde étudiant', () => {
    const guards: unknown[] =
      Reflect.getMetadata(
        '__guards__',
        CounsellorsController.prototype.createReview,
      ) ?? [];
    expect(guards).toContain(StudentAuthGuard);
  });

  it('`main.ts` utilise EXACTEMENT les options de pipe que ce test', () => {
    // Le test monte sa propre `ValidationPipe`. Si la production assouplit la
    // sienne (retire `forbidNonWhitelisted`) ou la modifie autrement
    // (`transformOptions: { enableImplicitConversion: true }` ferait accepter une
    // note « 5 » en chaîne), ce test continuerait de passer — sur une pipe qui
    // n'est plus celle de la production.
    //
    // Lu par l'ARBRE SYNTAXIQUE, pas par une découpe de texte : un commentaire qui
    // cite `forbidNonWhitelisted: true` ne compte pas, l'ordre et la mise en page
    // non plus, et une option AJOUTÉE fait échouer l'égalité au lieu de passer
    // inaperçue.
    const main = readFileSync(join(__dirname, '..', '..', 'main.ts'), 'utf8');
    expect(validationPipeOptions(main)).toEqual({
      whitelist: 'true',
      forbidNonWhitelisted: 'true',
      transform: 'true',
    });
  });

  it('sait lire les options d’une pipe (le cliquet ci-dessus ne ment pas)', () => {
    const read = validationPipeOptions;
    // Un commentaire n'est pas une option.
    expect(
      read(`new ValidationPipe({ // forbidNonWhitelisted: true,
        whitelist: true })`),
    ).toEqual({ whitelist: 'true' });
    // Une option ajoutée se voit.
    expect(
      read('new ValidationPipe({ whitelist: true, skipMissingProperties: true })'),
    ).toEqual({ whitelist: 'true', skipMissingProperties: 'true' });
    // Un drapeau à `false` se voit.
    expect(read('new ValidationPipe({ forbidNonWhitelisted: false })')).toEqual({
      forbidNonWhitelisted: 'false',
    });
    // Des options déplacées dans une constante : le cliquet doit ROUGIR, pas se
    // taire.
    expect(read('new ValidationPipe(OPTIONS)')).toEqual({
      '<arguments>': '<non littéral>',
    });
    // Un `...spread` aussi.
    expect(read('new ValidationPipe({ ...BASE, transform: true })')).toEqual({
      '<spread>': '<non littéral>',
      transform: 'true',
    });
  });
});
