import { plainToInstance } from 'class-transformer';
import { validate } from 'class-validator';

import { DeclareEefInterestDto } from './declare-eef-interest.dto';

/**
 * Le DTO au VRAI point d'entrée : `plainToInstance` puis `validate`.
 *
 * Le spec de service voisin construit ses DTO à la main et court-circuite donc
 * la validation — c'est ce qui a permis au défaut testé ici de passer inaperçu.
 * Ce fichier reproduit ce que fait réellement le `ValidationPipe` monté dans
 * `main.ts` : d'abord la transformation (`transform: true`), ensuite seulement
 * les validateurs. L'ordre est ce qui compte — c'est lui qui rend `@Transform`
 * capable de corriger ce que `@IsNotEmpty()` laisse passer.
 */
const parse = async (payload: Record<string, unknown>) => {
  const dto = plainToInstance(DeclareEefInterestDto, payload);
  const errors = await validate(dto, {
    whitelist: true,
    forbidNonWhitelisted: true,
  });
  return { dto, errors };
};

const valid = (over: Record<string, unknown> = {}) => ({
  consent: true,
  consentVersion: 'eef-consent-v1',
  ...over,
});

describe('DeclareEefInterestDto — la version de consentement', () => {
  // Témoin. Sans lui, un harnais cassé rendrait tous les cas rouges et l'on
  // conclurait à tort que la garde fonctionne.
  it('accepts a real consent version', async () => {
    const { dto, errors } = await parse(valid());

    expect(errors).toHaveLength(0);
    expect(dto.consentVersion).toBe('eef-consent-v1');
  });

  // LE test de ce fichier.
  //
  // Pour class-validator, `"   "` n'est PAS une chaîne vide : `@IsNotEmpty()`
  // la laisse passer telle quelle. Le service faisait ensuite `.trim()` et
  // écrivait `""` en base — une ligne `EefInterest` d'apparence irréprochable,
  // portant un `consentedAt` et une version VIDE, c'est-à-dire une preuve de
  // consentement qui ne désigne aucun texte.
  //
  // C'est exactement la panne que cette colonne existe pour éviter : le
  // commentaire du modèle Prisma dit qu'« une date seule ne prouve que le
  // MOMENT ; elle ne dit pas ce que l'étudiant a lu ». Une version vide ramène
  // la ligne à ce qu'elle valait avant l'ajout de la colonne, sans que rien ne
  // le signale.
  //
  // Ce test ÉCHOUE sans le `@Transform` du DTO : `validate` rend zéro erreur.
  it('rejects a whitespace-only consent version instead of storing an empty one', async () => {
    const { errors } = await parse(valid({ consentVersion: '   ' }));

    expect(errors).toEqual(
      expect.arrayContaining([
        expect.objectContaining({ property: 'consentVersion' }),
      ]),
    );
  });

  // Le corollaire : le service ne doit pas être le seul rempart. Il reçoit
  // désormais la valeur déjà rognée, donc `"v1"` et `" v1 "` sont la MÊME
  // version — sans quoi un export commercial contiendrait deux entrées
  // distinctes pour un texte unique.
  it('delivers the trimmed version to the service, not the padded one', async () => {
    const { dto, errors } = await parse(
      valid({ consentVersion: '  eef-consent-v2  ' }),
    );

    expect(errors).toHaveLength(0);
    expect(dto.consentVersion).toBe('eef-consent-v2');
  });

  // Effet de bord voulu : `@MaxLength(64)` mesure maintenant la chaîne
  // STOCKÉE. Avant, elle mesurait le remplissage, et une version de 64
  // caractères entourée d'espaces était refusée alors que la valeur écrite en
  // base tenait dans la borne.
  it('measures the length bound against the stored value', async () => {
    const sixtyFour = 'v'.repeat(64);
    const { dto, errors } = await parse(
      valid({ consentVersion: `  ${sixtyFour}  ` }),
    );

    expect(errors).toHaveLength(0);
    expect(dto.consentVersion).toBe(sixtyFour);
  });
});
