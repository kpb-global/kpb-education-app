import { Transform } from 'class-transformer';
import {
  IsInt,
  IsNotEmpty,
  IsOptional,
  IsString,
  Matches,
  Max,
  MaxLength,
  Min,
} from 'class-validator';

/** Longueur maximale d'un témoignage conservé, en unités UTF-16. */
export const REVIEW_BODY_MAX_LENGTH = 1000;

/**
 * Un témoignage que la base accepte, borné à [REVIEW_BODY_MAX_LENGTH].
 *
 * Trois choses que `slice` seul ne fait pas, et qui toutes finissent en 500 :
 *
 *  • l'octet NUL n'est pas du texte valide pour Postgres ;
 *  • une paire de substituts UTF-16 (un emoji) coupée en deux laisse un substitut
 *    HAUT isolé à la fin — Prisma rejette la chaîne, et l'étudiant perd le texte
 *    que la troncature devait justement préserver ;
 *  • un substitut isolé déjà présent dans la requête (un client peut en envoyer
 *    en JSON) a le même effet : remplacé par U+FFFD.
 *
 * On ne tronque pas en points de code : `@MaxLength` compte en unités UTF-16, et
 * rejetterait ensuite un texte que la coupe aurait laissé passer.
 */
export function sanitizeReviewBody(value: string): string {
  const wellFormed = value
    .replace(/\u0000/g, '')
    .replace(
      /[\ud800-\udbff](?![\udc00-\udfff])|(?<![\ud800-\udbff])[\udc00-\udfff]/g,
      '�',
    );
  if (wellFormed.length <= REVIEW_BODY_MAX_LENGTH) return wellFormed;
  const cut = wellFormed.slice(0, REVIEW_BODY_MAX_LENGTH);
  return /[\ud800-\udbff]$/.test(cut) ? cut.slice(0, -1) : cut;
}

/**
 * Un avis sur un conseiller, laissé par l'étudiant à la fin d'un dossier.
 *
 * ## Ce que ce DTO ne contient PAS, et c'est le point
 *
 * Ni `reviewerUserId` ni `reviewerName` ne sont des données que le client
 * DÉCLARE : l'auteur est celui du jeton vérifié, et son nom est celui de son
 * profil. Le corps était auparavant un type en ligne, effacé à l'exécution — la
 * `ValidationPipe` globale ne validait donc rien —, et le service recopiait ce
 * que le client envoyait. Deux conséquences, toutes deux vues :
 *
 *   1. l'app n'envoyait jamais `reviewerUserId`, donc les avis n'avaient AUCUN
 *      auteur en base et la suppression de compte ne les trouvait pas : le nom
 *      civil de l'étudiant survivait à l'effacement de son compte ;
 *   2. n'importe quel client pouvait poster un avis au nom d'un autre
 *      utilisateur, ou sous un nom inventé.
 *
 * `reviewerUserId` n'est délibérément PAS déclaré ici : la pipe globale
 * (`forbidNonWhitelisted`) répond 400 à qui l'envoie, au lieu de l'ignorer en
 * silence.
 */
export class CreateCounsellorReviewDto {
  @IsInt()
  @Min(1)
  @Max(5)
  rating!: number;

  /**
   * Le témoignage. Peut être VIDE : l'app le traite comme facultatif (la note
   * de 1 à 5 est la seule obligation, le témoignage est optionnel) et envoie
   * `''` quand l'étudiant ne l'écrit pas. L'exiger ferait échouer en 400 la
   * note seule.
   *
   * Borné parce qu'il est relu par la modération, puis publié — mais TRONQUÉ,
   * pas refusé. Le champ de saisie de l'app n'a aucune limite, et l'écran
   * répond « Réessaie plus tard » à toute erreur avant de marquer le dossier
   * comme noté quoi qu'il arrive : un 400 ferait perdre définitivement à
   * l'étudiant un texte qu'il vient de rédiger. La coupe se fait avant la
   * validation ; `@MaxLength` reste, comme garde-fou de la borne elle-même.
   */
  @Transform(({ value }: { value: unknown }) =>
    typeof value === 'string' ? sanitizeReviewBody(value) : value,
  )
  @IsString()
  @MaxLength(REVIEW_BODY_MAX_LENGTH)
  body!: string;

  /**
   * Le dossier noté. Obligatoire : c'est lui qui prouve que l'auteur a été
   * suivi par CE conseiller (voir `CounsellorsService.createReview`). L'app
   * l'envoie toujours ; le rendre facultatif laissait poster un avis sans
   * aucun rapport avec un dossier réel.
   */
  @IsString()
  @IsNotEmpty()
  @MaxLength(64)
  // Un identifiant de dossier est un `cuid` : lettres, chiffres, `-` et `_`. Le
  // restreindre écarte à la porte les valeurs que Postgres refuserait (un octet
  // NUL donnait un 500) sans rien changer pour un dossier réel.
  @Matches(/^[A-Za-z0-9_-]+$/)
  caseId!: string;

  /**
   * ACCEPTÉ ET IGNORÉ — compatibilité avec les builds déjà installées.
   *
   * L'app envoie encore `reviewerName` (le nom du profil). La pipe globale
   * refusant les champs inconnus (`forbidNonWhitelisted`), ne pas le déclarer
   * ferait répondre 400 à TOUS les avis des builds 49 à 53 — c'est-à-dire qu'un
   * correctif de sécurité casserait la fonctionnalité qu'il protège.
   *
   * La valeur n'est jamais lue : le nom affiché est celui du profil vérifié.
   * Sans borne de longueur, donc : refuser pour sa taille un champ qu'on ignore
   * ferait perdre son avis à un étudiant dont le profil porte un nom long (le
   * profil n'en borne pas la longueur), sans rien protéger.
   */
  @IsOptional()
  @IsString()
  reviewerName?: string;
}
