import { Injectable, ServiceUnavailableException } from '@nestjs/common';

import { PrismaService } from '../prisma/prisma.service';
import { JoinPremiumWaitlistDto } from './dto/join-premium-waitlist.dto';

/** L'inscription du profil appelant, telle que l'écran la lit. */
export interface PremiumWaitlistView {
  registered: boolean;
  registeredAt: string | null;
}

const NOT_REGISTERED: PremiumWaitlistView = {
  registered: false,
  registeredAt: null,
};

/**
 * Liste d'attente Karatou Premium.
 *
 * Son seul travail est d'enregistrer honnêtement qui veut être prévenu quand le
 * Pass ouvrira. Trois règles gouvernent le reste.
 *
 * **1. Il échoue fermé.** `PrismaService.execute` rend `null` quand aucune base
 * n'est configurée. Un service qui rendrait alors un objet d'apparence normale
 * ferait afficher « tu es inscrit » pour une ligne qui n'existe nulle part —
 * c'est le défaut que le masquage `documentUploadEnabled` documente côté
 * mobile, où « fourni ✓ » était coché avant l'appel réseau. Ici un échec est un
 * 503, et l'écran doit le montrer.
 *
 * **2. L'horodatage vient du serveur.** Le client ne l'envoie pas et ne peut
 * donc pas l'antidater. Mais ce n'est une preuve que parce que le DTO exige un
 * `consent: true` explicite et une version de texte : sans eux, ce `new Date()`
 * ne serait qu'un `now()` déplacé de Postgres vers Node.
 *
 * **3. Il n'encaisse rien.** Aucun montant, aucun état de facturation, aucune
 * référence de paiement ne transite ni n'est stocké. S'inscrire est gratuit et
 * n'engage à rien ; le jour où le Pass s'achètera, ce sera par un autre chemin.
 */
@Injectable()
export class PremiumWaitlistService {
  constructor(private readonly prismaService: PrismaService) {}

  private assertDb() {
    if (!this.prismaService.isEnabled) {
      throw new ServiceUnavailableException(
        'Database is not configured. Set DATABASE_URL.',
      );
    }
  }

  /**
   * Inscrit le profil appelant, ou rafraîchit son inscription.
   *
   * `upsert` plutôt que `create` : `userId` est unique, et un second tap doit
   * corriger la ligne existante. Un `create` nu aurait fait remonter une
   * violation de contrainte — donc une erreur affichée à un étudiant qui n'a
   * rien fait de mal en tapant deux fois sur un réseau lent.
   */
  async join(
    userId: string,
    dto: JoinPremiumWaitlistDto,
  ): Promise<PremiumWaitlistView> {
    this.assertDb();

    const consentedAt = new Date();
    const consentVersion = dto.consentVersion.trim();
    // La langue est déjà normalisée et bornée par le DTO (`@IsIn`) ; on la
    // recopie telle quelle plutôt que de la redériver ici, pour qu'il n'existe
    // qu'un seul endroit où la liste des langues acceptées est écrite.
    const consentLocale = dto.consentLocale;

    const saved = await this.prismaService.execute((prisma) =>
      prisma.premiumWaitlistEntry.upsert({
        where: { userId },
        create: { userId, consentedAt, consentVersion, consentLocale },
        // Rafraîchi à chaque inscription : le consentement qui compte est le
        // dernier donné, et c'est celui qu'on doit pouvoir produire. Garder la
        // première date ferait remonter une preuve périmée, désignant un texte
        // que l'étudiant n'a peut-être jamais vu.
        update: { consentedAt, consentVersion, consentLocale },
      }),
    );

    if (!saved) {
      throw new ServiceUnavailableException(
        'Failed to persist the waitlist entry.',
      );
    }

    return this.toView(saved);
  }

  /**
   * L'inscription du profil appelant, ou l'état « pas inscrit ».
   *
   * L'absence de ligne est un fait, pas une erreur : l'écran s'en sert pour
   * afficher « tu es sur la liste » au lieu de reproposer le bouton à quelqu'un
   * qui a déjà tapé.
   */
  async getMine(userId: string): Promise<PremiumWaitlistView> {
    this.assertDb();

    const found = await this.prismaService.execute((prisma) =>
      prisma.premiumWaitlistEntry.findUnique({ where: { userId } }),
    );

    return found ? this.toView(found) : NOT_REGISTERED;
  }

  /**
   * Retire le profil appelant de la liste.
   *
   * Existe parce que le texte affiché dit qu'on peut se retirer à tout moment.
   * Une collecte fondée sur le consentement a besoin d'un mécanisme de retrait,
   * sinon le consentement n'est pas révocable et n'en est pas un.
   *
   * **Idempotente.** Retirer une inscription absente rend le même état que
   * retirer celle qui existait. Un 404 obligerait l'écran à distinguer « rien à
   * retirer » de « échec du retrait » pour aboutir au même affichage, et un
   * double tap produirait une erreur pour une action qui a réussi.
   *
   * `deleteMany` et non `delete` : `delete` lève P2025 quand la ligne est
   * absente, ce qui remonterait en erreur pour ce cas exact.
   */
  async leave(userId: string): Promise<PremiumWaitlistView> {
    this.assertDb();

    const result = await this.prismaService.execute((prisma) =>
      prisma.premiumWaitlistEntry.deleteMany({ where: { userId } }),
    );

    // Échec fermé : après `assertDb()`, un `null` ne peut plus vouloir dire
    // « pas de base », donc il signale une panne réelle. Sans ce contrôle,
    // l'écran afficherait « tu es retiré » sur une ligne toujours en base.
    if (!result) {
      throw new ServiceUnavailableException('Failed to leave the waitlist.');
    }

    return NOT_REGISTERED;
  }

  private toView(row: { consentedAt: Date }): PremiumWaitlistView {
    return {
      registered: true,
      registeredAt: row.consentedAt.toISOString(),
    };
  }
}
