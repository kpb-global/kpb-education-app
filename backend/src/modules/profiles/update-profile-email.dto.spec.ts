import { plainToInstance } from 'class-transformer';
import { validate } from 'class-validator';

import { UpdateProfileDto } from './dto/update-profile.dto';

// `email` est ignoré par `updateMe` (l'email est l'identité d'auth). Les apps
// publiées l'envoient pourtant — vide après « Passer » l'onboarding, ou tel que
// tapé à la main. Il ne doit JAMAIS faire échouer le PATCH : un 400 ici bloque
// toute la synchronisation du profil côté mobile.
describe('UpdateProfileDto — email', () => {
  it.each(['', 'suzane@gmail', 'pas un email', 'a@b.co'])(
    'accepte email=%j sans faire échouer le reste du PATCH',
    async (email) => {
      const dto = plainToInstance(UpdateProfileDto, {
        email,
        fullName: 'Suzane Salifou',
      });
      await expect(
        validate(dto, { whitelist: true, forbidNonWhitelisted: true }),
      ).resolves.toHaveLength(0);
    },
  );

  it('refuse toujours un email qui n’est pas une chaîne', async () => {
    const dto = plainToInstance(UpdateProfileDto, { email: 42 });
    const errors = await validate(dto);
    expect(errors.map((e) => e.property)).toContain('email');
  });
});
