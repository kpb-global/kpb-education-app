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

    // Horodaté ICI, jamais reçu du client. Mais ce n'est une PREUVE que parce que
    // le DTO exige `consent: true` et une version : sans eux, ce `new Date()`
    // n'était qu'un `now()` déplacé de Postgres vers Node, et un corps vide
    // fabriquait un consentement que personne n'avait donné.
    const consentedAt = new Date();
    const data = {
      currentLevel: dto.currentLevel?.trim() || null,
      targetLevel: dto.targetLevel?.trim() || null,
      fieldIds: this.normalizeFieldIds(dto.fieldIds),
      wantsPremium: dto.wantsPremium ?? false,
      consentVersion: dto.consentVersion.trim(),
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
   * Retire la déclaration du profil appelant.
   *
   * ## Pourquoi cette route existe
   *
   * Parce que le texte de consentement dit « tu peux te retirer à tout moment ».
   * Il le disait déjà avant que cette méthode existe, et c'était une promesse
   * sans mécanisme : les seules issues réelles étaient d'écrire à une adresse
   * générique ou de supprimer le compte ENTIER pour retirer une ligne de
   * prospection. Une collecte fondée sur le consentement a besoin d'un outil
   * d'exécution du retrait, sinon le consentement n'est pas révocable et n'en
   * est pas un.
   *
   * **Idempotente.** Retirer une déclaration qui n'existe pas rend le même état
   * que retirer celle qui existait : `NOT_DECLARED`. Un 404 sur un retrait
   * obligerait l'écran à distinguer « rien à retirer » de « échec du retrait »
   * pour aboutir au même affichage, et un double tap sur un réseau lent
   * produirait une erreur pour une action qui a réussi.
   *
   * `deleteMany` et non `delete` : `delete` lève P2025 quand la ligne est
   * absente, ce qui remonterait en erreur pour le cas ci-dessus.
   */
  async withdraw(userId: string): Promise<EefInterestView> {
    this.assertDb();

    const result = await this.prismaService.execute((prisma) =>
      prisma.eefInterest.deleteMany({ where: { userId } }),
    );

    // Échec fermé, comme partout ici : un `null` après `assertDb()` ne peut
    // plus vouloir dire « pas de base », donc il signale une panne réelle. Sans
    // ce contrôle, l'écran afficherait « tu es retiré » sur une ligne toujours
    // en base — c'est-à-dire le mensonge exact que ce module refuse.
    if (!result) {
      throw new ServiceUnavailableException('Failed to withdraw interest.');
    }

    return NOT_DECLARED;
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
