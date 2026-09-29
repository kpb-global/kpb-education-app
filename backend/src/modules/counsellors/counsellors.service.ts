import {
  ConflictException,
  ForbiddenException,
  Injectable,
  NotFoundException,
  ServiceUnavailableException,
} from '@nestjs/common';

import { PrismaService } from '../prisma/prisma.service';

/// Aucune base configurée : on ne prétend pas avoir enregistré l'avis.
function reviewsUnavailable(): ServiceUnavailableException {
  return new ServiceUnavailableException('Reviews are temporarily unavailable.');
}

type CounsellorInput = {
  fullName?: string;
  email?: string;
  phone?: string;
  whatsApp?: string;
  countryOfResidence?: string;
  specialties?: string[];
  languagesSpoken?: string[];
  bioFr?: string;
  bioEn?: string;
  yearsExperience?: number;
  hourlyRateXOF?: number;
  commissionBps?: number;
  kycStatus?:
    | 'pending'
    | 'under_review'
    | 'approved'
    | 'rejected'
    | 'suspended';
  kycNotes?: string | null;
  isActive?: boolean;
};

/**
 * Counsellor marketplace (Track B). Independent counsellors across francophone
 * West Africa can be onboarded, KYC-verified by admins, and assigned to cases.
 * KPB takes a commission (default 15%) on each paid consultation via
 * PaymentIntent.
 */
@Injectable()
export class CounsellorsService {
  constructor(private readonly prismaService: PrismaService) {}

  /** Public list — only active, KYC-approved counsellors. Used by mobile. */
  async listPublic(params: {
    countryOfResidence?: string;
    specialty?: string;
  }) {
    const items = await this.prismaService.execute((prisma) =>
      prisma.counsellor.findMany({
        where: {
          isActive: true,
          kycStatus: 'approved',
          ...(params.countryOfResidence
            ? { countryOfResidence: params.countryOfResidence }
            : {}),
          ...(params.specialty
            ? { specialties: { has: params.specialty } }
            : {}),
        },
        orderBy: [{ avgRating: 'desc' }, { reviewCount: 'desc' }],
        select: {
          id: true,
          fullName: true,
          countryOfResidence: true,
          specialties: true,
          languagesSpoken: true,
          bioFr: true,
          bioEn: true,
          yearsExperience: true,
          hourlyRateXOF: true,
          avgRating: true,
          reviewCount: true,
        },
      }),
    );
    return { items: items ?? [] };
  }

  async getPublic(id: string) {
    const counsellor = await this.prismaService.execute((prisma) =>
      prisma.counsellor.findFirst({
        where: { id, isActive: true, kycStatus: 'approved' },
        // Explicit select: the public detail view must never leak the
        // counsellor's personal contact details (email/phone/whatsApp) or
        // internal KYC/commission fields.
        select: {
          id: true,
          fullName: true,
          countryOfResidence: true,
          specialties: true,
          languagesSpoken: true,
          bioFr: true,
          bioEn: true,
          yearsExperience: true,
          hourlyRateXOF: true,
          avgRating: true,
          reviewCount: true,
          reviews: {
            where: { isPublished: true },
            orderBy: { createdAt: 'desc' },
            take: 20,
            // Ce que `/impact/reviews` sert déjà, et rien de plus. Sans `select`,
            // Prisma rend TOUTES les colonnes — `reviewerUserId`, la clé de
            // rattachement au profil, et `caseId` sortaient donc sur cette route
            // publique. Tant que l'auteur restait nul (l'app ne l'envoyait pas),
            // la première ne pouvait rien révéler ; il est renseigné désormais.
            select: {
              id: true,
              counsellorId: true,
              reviewerName: true,
              rating: true,
              body: true,
              createdAt: true,
            },
          },
        },
      }),
    );
    if (!counsellor) {
      throw new NotFoundException(`Counsellor ${id} not available.`);
    }
    return counsellor;
  }

  /** Admin list — includes pending/rejected for the KYC queue. */
  async listAdmin(params: { kycStatus?: string }) {
    const items = await this.prismaService.execute((prisma) =>
      prisma.counsellor.findMany({
        where: {
          ...(params.kycStatus
            ? { kycStatus: params.kycStatus as never }
            : {}),
        },
        orderBy: { createdAt: 'desc' },
      }),
    );
    return { items: items ?? [] };
  }

  async create(input: CounsellorInput) {
    const required = [
      'fullName',
      'email',
      'phone',
      'countryOfResidence',
      'bioFr',
      'bioEn',
    ] as const;
    for (const key of required) {
      if (!input[key]) {
        throw new NotFoundException(`Missing required field: ${key}`);
      }
    }

    const created = await this.prismaService.execute((prisma) =>
      prisma.counsellor.create({
        data: {
          fullName: input.fullName!,
          email: input.email!.toLowerCase(),
          phone: input.phone!,
          whatsApp: input.whatsApp,
          countryOfResidence: input.countryOfResidence!,
          specialties: input.specialties ?? [],
          languagesSpoken: input.languagesSpoken ?? ['fr'],
          bioFr: input.bioFr!,
          bioEn: input.bioEn!,
          yearsExperience: input.yearsExperience ?? 0,
          hourlyRateXOF: input.hourlyRateXOF ?? 0,
          commissionBps: input.commissionBps ?? 1500,
        },
      }),
    );
    return created;
  }

  async update(id: string, input: CounsellorInput) {
    const updated = await this.prismaService.execute((prisma) =>
      prisma.counsellor.update({
        where: { id },
        data: {
          ...(input.fullName !== undefined
            ? { fullName: input.fullName }
            : {}),
          ...(input.phone !== undefined ? { phone: input.phone } : {}),
          ...(input.whatsApp !== undefined
            ? { whatsApp: input.whatsApp }
            : {}),
          ...(input.countryOfResidence !== undefined
            ? { countryOfResidence: input.countryOfResidence }
            : {}),
          ...(input.specialties !== undefined
            ? { specialties: input.specialties }
            : {}),
          ...(input.languagesSpoken !== undefined
            ? { languagesSpoken: input.languagesSpoken }
            : {}),
          ...(input.bioFr !== undefined ? { bioFr: input.bioFr } : {}),
          ...(input.bioEn !== undefined ? { bioEn: input.bioEn } : {}),
          ...(input.yearsExperience !== undefined
            ? { yearsExperience: input.yearsExperience }
            : {}),
          ...(input.hourlyRateXOF !== undefined
            ? { hourlyRateXOF: input.hourlyRateXOF }
            : {}),
          ...(input.commissionBps !== undefined
            ? { commissionBps: input.commissionBps }
            : {}),
          ...(input.isActive !== undefined
            ? { isActive: input.isActive }
            : {}),
        },
      }),
    );
    return updated;
  }

  /** Admin-only: approve/reject KYC. Flipping to `approved` auto-activates. */
  async updateKyc(
    id: string,
    input: { kycStatus: CounsellorInput['kycStatus']; kycNotes?: string | null },
  ) {
    if (!input.kycStatus) {
      throw new NotFoundException('kycStatus is required.');
    }
    const now = input.kycStatus === 'approved' ? new Date() : null;
    const updated = await this.prismaService.execute((prisma) =>
      prisma.counsellor.update({
        where: { id },
        data: {
          kycStatus: input.kycStatus,
          kycNotes: input.kycNotes ?? null,
          kycVerifiedAt: now ?? undefined,
          // Approving auto-activates; any non-approved status deactivates.
          isActive: input.kycStatus === 'approved',
        },
      }),
    );
    return updated;
  }

  /**
   * Un étudiant note le conseiller qui a traité SON dossier terminé.
   *
   * ## L'auteur est celui du jeton
   *
   * `reviewer` vient du jeton vérifié par `StudentAuthGuard` — jamais du corps.
   * Le service recopiait auparavant `reviewerUserId` depuis ce que le client
   * envoyait. L'app ne l'envoyait pas : les avis n'avaient aucun auteur en base,
   * la suppression de compte (`deleteMany WHERE reviewerUserId = …`) n'en
   * trouvait aucun, et le nom civil de l'étudiant survivait à l'effacement de
   * son compte. Et un client pouvait poster au nom de n'importe qui.
   *
   * Le nom est celui du PROFIL, que l'utilisateur maîtrise (`PATCH /profiles/me`) :
   * ce que ce code garantit, c'est que la requête ne le déclare pas — pas qu'il
   * soit civil ou exact.
   *
   * ## Le dossier lie l'avis à un parcours réel — il ne le PROUVE pas
   *
   * L'avis n'est accepté que si le dossier existe, appartient à l'appelant, a été
   * traité par CE conseiller et est terminé — exactement ce que l'app ne propose
   * qu'à ce moment-là. Un dossier introuvable ET un dossier d'un autre répondent
   * la même chose (404) : on ne confirme pas l'existence du dossier d'autrui.
   *
   * Honnêtement : « terminé » n'est pas une preuve. `PATCH /cases/:id` laisse le
   * propriétaire fixer lui-même le `status` de son dossier (aucun client de l'app
   * ne le fait). Ce contrôle écarte les avis incohérents, pas un utilisateur qui
   * le veut ; les défenses réelles sont la propriété du dossier et la modération
   * (un avis naît non publié).
   *
   * ## Un avis par dossier
   *
   * Un second avis sur le même dossier est refusé (409). Sans contrainte d'unicité
   * en base, la garde est au mieux-effort : deux requêtes simultanées peuvent
   * toutes deux passer. Elle borne le cas ordinaire — un double envoi, un
   * utilisateur qui insiste — sans migration de schéma.
   *
   * ## Base absente : 503, jamais une réponse d'apparence normale
   *
   * `execute` rend `null` quand aucune base n'est configurée. L'ancien code
   * renvoyait alors ce `null` : un 201 au corps vide, donc un étudiant persuadé
   * d'avoir noté son conseiller alors que rien n'avait été écrit. En pratique le
   * garde d'authentification répond 401 avant d'arriver ici quand la base manque ;
   * ce 503 est la défense en profondeur d'un service qui ne doit jamais
   * confondre « rien n'a été écrit » et « c'est fait ».
   */
  async createReview(
    counsellorId: string,
    input: { rating: number; body: string; caseId: string },
    reviewer: { id: string; fullName: string },
  ) {
    // Le résultat est EMBALLÉ : `findUnique` rend légitimement `null` pour un
    // dossier inconnu, et `execute` rend aussi `null` quand la base est absente.
    // Sans emballage, les deux se confondraient — un 404 métier prendrait le
    // masque d'une panne, ou l'inverse.
    const lookup = await this.prismaService.execute(async (prisma) => ({
      found: await prisma.case.findUnique({
        where: { id: input.caseId },
        select: { userId: true, counsellorId: true, status: true },
      }),
      // Tout avis qui porte ce dossier, quel que soit son auteur : ceux d'avant
      // l'auteur-par-jeton n'en ont pas, et ils comptent autant.
      alreadyReviewed: await prisma.counsellorReview.findFirst({
        where: { caseId: input.caseId },
        select: { id: true },
      }),
    }));
    if (lookup === null) throw reviewsUnavailable();

    const { found, alreadyReviewed } = lookup;
    if (!found || found.userId !== reviewer.id) {
      throw new NotFoundException('Case not found.');
    }
    if (found.counsellorId !== counsellorId) {
      throw new ForbiddenException(
        'This case was not handled by this counsellor.',
      );
    }
    if (found.status !== 'completed') {
      throw new ConflictException(
        'A counsellor can be reviewed once the case is completed.',
      );
    }
    if (alreadyReviewed) {
      throw new ConflictException('This case has already been reviewed.');
    }

    const review = await this.prismaService.execute(async (prisma) => {
      const created = await prisma.counsellorReview.create({
        data: {
          counsellorId,
          // Le nom affiché est celui du profil vérifié, pas celui que la requête
          // déclare : elle ne peut plus signer « Marie Curie » d'un seul appel.
          reviewerName: reviewer.fullName?.trim() || 'KPB',
          reviewerUserId: reviewer.id,
          caseId: input.caseId,
          rating: input.rating,
          body: input.body.trim(),
          // Reviews are unpublished by default — moderators approve them. Cuts
          // down on fake/abusive reviews during beta.
          isPublished: false,
        },
      });
      // Refresh denormalized counters using only published reviews.
      const published = await prisma.counsellorReview.findMany({
        where: { counsellorId, isPublished: true },
        select: { rating: true },
      });
      const count = published.length;
      const avg =
        count === 0
          ? 0
          : published.reduce((sum, r) => sum + r.rating, 0) / count;
      await prisma.counsellor.update({
        where: { id: counsellorId },
        data: { avgRating: avg, reviewCount: count },
      });
      return created;
    });
    if (review === null) throw reviewsUnavailable();
    return review;
  }

  /** Admin-only: publish or unpublish a review. */
  async setReviewPublished(reviewId: string, isPublished: boolean) {
    return this.prismaService.execute(async (prisma) => {
      const updated = await prisma.counsellorReview.update({
        where: { id: reviewId },
        data: { isPublished },
      });
      const published = await prisma.counsellorReview.findMany({
        where: { counsellorId: updated.counsellorId, isPublished: true },
        select: { rating: true },
      });
      const count = published.length;
      const avg =
        count === 0
          ? 0
          : published.reduce((sum, r) => sum + r.rating, 0) / count;
      await prisma.counsellor.update({
        where: { id: updated.counsellorId },
        data: { avgRating: avg, reviewCount: count },
      });
      return updated;
    });
  }
}
