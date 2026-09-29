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
      findMany: async () => [],
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

    it('rafraîchit les compteurs du conseiller', async () => {
      const { post, counterUpdates } = await withApp();
      await post('counsellor-1', OLD_CLIENT_BODY);
      expect(counterUpdates).toHaveLength(1);
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
      ['témoignage trop long', { body: 'x'.repeat(1001) }],
      ['témoignage absent', { body: undefined }],
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

      expect(foreignResponse.status).toBe(unknownResponse.status);
      expect(foreignResponse.body).toEqual(unknownResponse.body);
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
  });

  // ── Base absente ───────────────────────────────────────────────────────────

  it('répond 503 sans base, au lieu d’un 201 au corps vide', async () => {
    // `execute` rend `null` quand aucune base n'est configurée. L'ancien code
    // renvoyait ce `null` : un étudiant persuadé d'avoir noté son conseiller
    // alors que rien n'avait été écrit.
    const { post, creates } = await withApp({ isEnabled: false });
    const response = await post('counsellor-1', OLD_CLIENT_BODY);
    expect(response.status).toBe(503);
    expect(creates).toEqual([]);
  });
});

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

  it('`main.ts` utilise les MÊMES options de pipe que ce test', () => {
    // Le test monte sa propre `ValidationPipe`. Si la production assouplit la
    // sienne (retire `forbidNonWhitelisted`), `reviewerUserId` cesserait d'être
    // rejeté et ce test continuerait de passer — sur une pipe qui n'est plus
    // celle de la production.
    const main = readFileSync(join(__dirname, '..', '..', 'main.ts'), 'utf8');
    const pipe = main.slice(main.indexOf('new ValidationPipe('));
    const options = pipe.slice(0, pipe.indexOf('}') + 1);
    expect(options).toMatch(/whitelist:\s*true/);
    expect(options).toMatch(/forbidNonWhitelisted:\s*true/);
    expect(options).toMatch(/transform:\s*true/);
  });
});
