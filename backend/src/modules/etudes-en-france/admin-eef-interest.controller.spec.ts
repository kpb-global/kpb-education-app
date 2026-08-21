import { Reflector } from '@nestjs/core';

import { ROLES_KEY } from '../../common/decorators/roles.decorator';
import { InternalRole } from '../../common/enums/internal-role.enum';
import { AdminAuthGuard } from '../../common/guards/admin-auth.guard';
import { RolesGuard } from '../../common/guards/roles.guard';
import { AdminEefInterestController } from './admin-eef-interest.controller';

/**
 * Les rôles de la liste d'intérêt, éprouvés plutôt que relus.
 *
 * Ce que cette table contient : des noms complets, des e-mails, des numéros de
 * téléphone et un pays de résidence — pour des étudiants dont une partie sont
 * mineurs. Le périmètre de lecture est donc une décision de confidentialité, pas
 * une commodité, et un décorateur est trop facile à élargir d'une ligne sans que
 * personne ne le remarque en revue.
 */
describe('AdminEefInterestController — périmètre de lecture', () => {
  const reflector = new Reflector();

  const roles: InternalRole[] =
    reflector.get(ROLES_KEY, AdminEefInterestController) ?? [];

  const guards: unknown[] =
    Reflect.getMetadata('__guards__', AdminEefInterestController) ?? [];

  it('exige l\'authentification admin ET la garde de rôles', () => {
    // Les deux, dans cet ordre : `RolesGuard` seul n'a personne à comparer, et
    // `AdminAuthGuard` seul laisse entrer n'importe quel rôle interne.
    expect(guards).toContain(AdminAuthGuard);
    expect(guards).toContain(RolesGuard);
  });

  it('ouvre la liste aux rôles qui ont une raison de rappeler un prospect', () => {
    expect(roles).toEqual(
      expect.arrayContaining([
        InternalRole.Admin,
        InternalRole.SuperAdmin,
        InternalRole.Commercial,
        InternalRole.Counselor,
      ]),
    );
  });

  // LE test de ce fichier. La modération de forum et la gestion de contenu
  // n'ont aucun usage de coordonnées d'étudiants ; les ajouter serait une
  // extension de périmètre à faire consciemment, pas par copie d'un autre
  // contrôleur.
  it.each([InternalRole.Moderator, InternalRole.ContentManager])(
    'exclut %s des données de contact',
    (role) => {
      expect(roles).not.toContain(role);
    },
  );

  it('n\'ouvre pas la liste à un rôle inconnu par omission', () => {
    // Un décorateur vide vaudrait « aucun rôle exigé » selon l'implémentation
    // de RolesGuard : on vérifie qu'il est bien renseigné.
    expect(roles.length).toBeGreaterThan(0);
  });
});
