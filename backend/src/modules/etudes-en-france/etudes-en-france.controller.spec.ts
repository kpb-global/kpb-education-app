import { ForbiddenException } from '@nestjs/common';
import { Request } from 'express';

import { EtudesEnFranceController } from './etudes-en-france.controller';

/**
 * Qui peut ÉCRIRE dans la liste d'intérêt.
 *
 * ## Le défaut que ce fichier interdit
 *
 * `StudentAuthGuard` s'appelle « student » mais authentifie aussi les comptes
 * `parent` et `partner` — son propre commentaire le dit, et c'est voulu :
 * beaucoup de routes servent légitimement les deux. Cette route-ci non.
 *
 * La déclaration d'intérêt écrit les coordonnées du profil APPELANT dans une
 * liste que l'équipe rappelle, et que le back-office présente comme une liste
 * d'étudiants. Un parent qui tape « ça m'intéresse » y ferait entrer ses nom,
 * e-mail et téléphone : le conseiller rappellerait la mauvaise personne, au
 * sujet des études de quelqu'un d'autre.
 *
 * Le masquage côté mobile (`EefEntry.isVisible`) est l'autre moitié, mais il ne
 * protège pas la donnée : une requête forgée ne passe pas par un écran.
 */
describe('EtudesEnFranceController — qui peut écrire', () => {
  const service = {
    declareInterest: jest.fn(async () => ({ declared: true })),
    withdraw: jest.fn(async () => ({ declared: false })),
    getMyInterest: jest.fn(async () => ({ declared: false })),
  };

  const controller = new EtudesEnFranceController(service as never);

  const req = (accountType?: string) =>
    ({ studentUser: { id: 'user-1', accountType } }) as unknown as Request;

  const dto = { consent: true, consentVersion: 'eef-consent-v1' } as never;

  beforeEach(() => jest.clearAllMocks());

  // `toThrow` et non `.rejects` : `assertStudent` lève AVANT que la méthode
  // rende sa promesse, donc l'appel lève synchroniquement. La nuance compte —
  // un test écrit avec `.rejects` échouerait alors que le refus fonctionne, et
  // on irait chercher le défaut dans le code plutôt que dans le test.
  it.each(['parent', 'partner'])(
    'refuse la déclaration à un compte %s',
    (accountType) => {
      expect(() => controller.declareInterest(req(accountType), dto)).toThrow(
        ForbiddenException,
      );
      expect(service.declareInterest).not.toHaveBeenCalled();
    },
  );

  it.each(['parent', 'partner'])(
    'refuse le retrait à un compte %s',
    (accountType) => {
      // Le retrait est aussi une écriture. Un parent n'a rien à retirer, mais
      // laisser la porte ouverte inviterait à croire que la règle ne vaut que
      // pour la création.
      expect(() => controller.withdraw(req(accountType))).toThrow(
        ForbiddenException,
      );
      expect(service.withdraw).not.toHaveBeenCalled();
    },
  );

  it('accepte la déclaration d\'un compte étudiant', async () => {
    await controller.declareInterest(req('student'), dto);
    expect(service.declareInterest).toHaveBeenCalledWith('user-1', dto);
  });

  it('laisse la LECTURE ouverte à un parent', async () => {
    // Elle rend « pas déclaré », ce qui est vrai et sans effet. La fermer
    // produirait un 403 que le client avale en silence — donc une erreur
    // invisible pour un non-problème.
    await expect(controller.getMyInterest(req('parent'))).resolves.toEqual({
      declared: false,
    });
  });

  it('un accountType absent ne bloque pas — le garde reste la source', async () => {
    // Défensif : si un jour le garde cesse de résoudre ce champ, cette route ne
    // doit pas se fermer à tout le monde en silence. Le refus porte sur une
    // valeur CONNUE et différente de « student », jamais sur une absence.
    await controller.declareInterest(req(undefined), dto);
    expect(service.declareInterest).toHaveBeenCalled();
  });
});
