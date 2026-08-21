import { Injectable, ServiceUnavailableException } from '@nestjs/common';

import { PrismaService } from '../prisma/prisma.service';
import { DeclareEefInterestDto } from './dto/declare-eef-interest.dto';

/** Une déclaration d'intérêt telle que la vitrine la lit. */
export interface EefInterestView {
  declared: boolean;
  currentLevel: string | null;
  targetLevel: string | null;
  fieldIds: string[];
  wantsPremium: boolean;
  consentedAt: string | null;
}

const NOT_DECLARED: EefInterestView = {
  declared: false,
  currentLevel: null,
  targetLevel: null,
  fieldIds: [],
  wantsPremium: false,
  consentedAt: null,
};

/**
 * Espace « Études en France » — Phase 0.
 *
 * Le seul travail de ce service est d'enregistrer, honnêtement, qui veut être
 * rappelé quand l'espace ouvre. Deux règles gouvernent tout le reste.
 *
 * **1. Il échoue fermé.** `PrismaService.execute` rend `null` quand aucune base
 * n'est configurée, et un service qui rendrait alors un objet d'apparence
 * normale ferait afficher « c'est noté » pour une ligne qui n'existe nulle
 * part. C'est exactement le défaut que le masquage `documentUploadEnabled`
 * documente côté mobile : « fourni ✓ » coché avant l'appel réseau, échec avalé
 * dans Crashlytics, et un étudiant persuadé d'avoir envoyé son dossier. Ici un
 * échec est un 503, et l'écran doit le montrer.
 *
 * **2. L'horodatage du consentement vient du serveur.** Le client ne l'envoie
 * pas et ne peut donc pas l'antidater : la date de consentement est l'instant
 * où cette requête — émise par un écran qui dit qu'un conseiller rappellera —
 * a été reçue. C'est la preuve RGPD, pas une métadonnée décorative.
 */
@Injectable()
export class EtudesEnFranceService {
  constructor(private readonly prismaService: PrismaService) {}

  private assertDb() {
    if (!this.prismaService.isEnabled) {
      throw new ServiceUnavailableException(
        'Database is not configured. Set DATABASE_URL.',
      );
    }
  }

  /**
   * Enregistre ou met à jour la déclaration du profil appelant.
   *
   * `upsert` plutôt que `create` : `EefInterest.userId` est unique, et une
   * redéclaration doit corriger la ligne existante. Un `create` nu aurait fait
   * remonter une violation de contrainte unique — soit un 500, soit un message
   * d'erreur pour un étudiant qui n'a rien fait de mal en tapant deux fois.
   */
  async declareInterest(
    userId: string,
    dto: DeclareEefInterestDto,
  ): Promise<EefInterestView> {
    this.assertDb();

    const consentedAt = new Date();
    const data = {
      currentLevel: dto.currentLevel?.trim() || null,
      targetLevel: dto.targetLevel?.trim() || null,
      fieldIds: this.normalizeFieldIds(dto.fieldIds),
      wantsPremium: dto.wantsPremium ?? false,
    };

    const saved = await this.prismaService.execute((prisma) =>
      prisma.eefInterest.upsert({
        where: { userId },
        create: { userId, consentedAt, ...data },
        // `consentedAt` est RAFRAÎCHI à chaque redéclaration : le consentement
        // qui compte est le dernier donné, et c'est celui qu'on doit pouvoir
        // produire. Garder la première date ferait remonter une preuve périmée.
        update: { consentedAt, ...data },
      }),
    );

    if (!saved) {
      throw new ServiceUnavailableException('Failed to persist interest.');
    }

    return this.toView(saved);
  }

  /**
   * La déclaration du profil appelant, ou l'état « pas déclaré ».
   *
   * L'absence de ligne est un fait, pas une erreur : la vitrine s'en sert pour
   * afficher « c'est noté » au lieu de reposer la question à chaque ouverture.
   */
  async getMyInterest(userId: string): Promise<EefInterestView> {
    this.assertDb();

    const found = await this.prismaService.execute((prisma) =>
      prisma.eefInterest.findUnique({ where: { userId } }),
    );

    return found ? this.toView(found) : NOT_DECLARED;
  }

  /**
   * Dédoublonne et borne les filières.
   *
   * Le DTO plafonne déjà la taille du tableau reçu ; ceci enlève les doublons
   * et les chaînes vides, pour que l'export commercial ne contienne pas
   * « info, info, info » ni des cases vides.
   */
  private normalizeFieldIds(raw: string[] | undefined): string[] {
    if (!raw?.length) return [];
    const seen = new Set<string>();
    for (const value of raw) {
      const trimmed = value.trim();
      if (trimmed) seen.add(trimmed);
    }
    return [...seen];
  }

  private toView(row: {
    currentLevel: string | null;
    targetLevel: string | null;
    fieldIds: string[];
    wantsPremium: boolean;
    consentedAt: Date;
  }): EefInterestView {
    return {
      declared: true,
      currentLevel: row.currentLevel,
      targetLevel: row.targetLevel,
      fieldIds: row.fieldIds,
      wantsPremium: row.wantsPremium,
      consentedAt: row.consentedAt.toISOString(),
    };
  }
}
