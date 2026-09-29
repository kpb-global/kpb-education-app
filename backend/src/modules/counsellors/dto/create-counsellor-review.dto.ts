import {
  IsInt,
  IsNotEmpty,
  IsOptional,
  IsString,
  Max,
  MaxLength,
  Min,
} from 'class-validator';

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
   * Borné parce qu'il est relu par la modération, puis publié.
   */
  @IsString()
  @MaxLength(1000)
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
  caseId!: string;

  /**
   * ACCEPTÉ ET IGNORÉ — compatibilité avec les builds déjà installées.
   *
   * L'app envoie encore `reviewerName` (le nom du profil). La pipe globale
   * refusant les champs inconnus (`forbidNonWhitelisted`), ne pas le déclarer
   * ferait répondre 400 à TOUS les avis des builds 49 à 53 — c'est-à-dire qu'un
   * correctif de sécurité casserait la fonctionnalité qu'il protège.
   *
   * La valeur n'est jamais lue : le nom affiché est celui du jeton.
   */
  @IsOptional()
  @IsString()
  @MaxLength(200)
  reviewerName?: string;
}
