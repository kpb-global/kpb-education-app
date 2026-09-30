import { BadRequestException, ValidationPipe } from '@nestjs/common';

import { UpdateEefProfileDto } from './update-eef-profile.dto';

/// Les MÊMES options que `main.ts` : c'est le pipe global qui refuse un champ
/// inconnu, et la garantie « la mise à jour du profil ne touche pas au
/// consentement » en dépend.
const pipe = new ValidationPipe({
  whitelist: true,
  forbidNonWhitelisted: true,
  transform: true,
});

const run = (body: unknown) =>
  pipe.transform(body, { type: 'body', metatype: UpdateEefProfileDto });

describe('UpdateEefProfileDto', () => {
  it('accepte les niveaux et les domaines', async () => {
    await expect(
      run({ currentLevel: 'licence', targetLevel: 'master', fieldIds: ['d01'] }),
    ).resolves.toMatchObject({ targetLevel: 'master', fieldIds: ['d01'] });
  });

  it('accepte un seul champ', async () => {
    await expect(run({ fieldIds: [] })).resolves.toMatchObject({ fieldIds: [] });
    await expect(run({ currentLevel: '' })).resolves.toMatchObject({ currentLevel: '' });
  });

  // Le cœur de XC-07 : ces trois champs relèvent du consentement et ne passent
  // pas par ici. REFUSÉS, pas ignorés : un client qui les enverrait croirait les
  // avoir mis à jour.
  it.each(['consent', 'consentVersion', 'wantsPremium', 'consentedAt', 'userId'])(
    'refuse le champ « %s »',
    async (field) => {
      await expect(run({ fieldIds: ['d01'], [field]: true })).rejects.toBeInstanceOf(
        BadRequestException,
      );
    },
  );

  it('refuse null, qui se lirait aussi bien « inchangé » que « effacé »', async () => {
    await expect(run({ currentLevel: null })).rejects.toBeInstanceOf(BadRequestException);
    await expect(run({ fieldIds: null })).rejects.toBeInstanceOf(BadRequestException);
  });

  it('refuse un mauvais type et les dépassements', async () => {
    await expect(run({ fieldIds: 'd01' })).rejects.toBeInstanceOf(BadRequestException);
    await expect(run({ fieldIds: [1] })).rejects.toBeInstanceOf(BadRequestException);
    await expect(run({ currentLevel: 'x'.repeat(65) })).rejects.toBeInstanceOf(
      BadRequestException,
    );
    await expect(
      run({ fieldIds: Array.from({ length: 33 }, (_, i) => `d${i}`) }),
    ).rejects.toBeInstanceOf(BadRequestException);
  });
});
