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
 *
 * ## Ce que la première version de ce fichier ne voyait pas
 *
 * Elle lisait `reflector.get(ROLES_KEY, AdminEefInterestController)` — les
 * métadonnées de la CLASSE, et rien d'autre. Or `RolesGuard` résout les rôles
 * par `getAllAndOverride(ROLES_KEY, [handler, classe])` : **le handler
 * l'emporte**. Un `@Roles` posé sur une seule route redéfinissait donc
 * entièrement son périmètre sans qu'aucune assertion ne bouge.
 *
 * Mesuré : en ajoutant `@Roles(InternalRole.Moderator)` au-dessus de
 * `@Get('export.csv')` — ce qui donne à `moderator` l'accès EXCLUSIF à l'export
 * et le retire à tous les autres — les cinq tests restaient verts, y compris
 * celui intitulé « exclut moderator des données de contact ».
 *
 * Ce fichier résout donc les rôles **route par route**, exactement comme la
 * garde, et il énumère les routes depuis le prototype : une route ajoutée
 * demain sans entrée dans [expected] fait rougir.
 */
describe('AdminEefInterestController — périmètre de lecture', () => {
  const reflector = new Reflector();

  const guards: unknown[] =
    Reflect.getMetadata('__guards__', AdminEefInterestController) ?? [];

  /// Les routes du contrôleur, lues sur le prototype et non recopiées à la main.
  const handlers = Object.getOwnPropertyNames(
    AdminEefInterestController.prototype,
  ).filter((name) => name !== 'constructor');

  /// Les rôles que la garde appliquera RÉELLEMENT à [handlerName].
  const rolesFor = (handlerName: string): InternalRole[] => {
    const handler = (
      AdminEefInterestController.prototype as unknown as Record<string, unknown>
    )[handlerName];
    // Message explicite plutôt qu'une `TypeError` venue de reflect-metadata :
    // un nom de handler faux dans la table de périmètre est une faute de ce
    // fichier, et elle doit se lire comme telle.
    if (typeof handler !== 'function') {
      throw new Error(
        `Handler « ${handlerName} » absent du prototype. Routes réelles : ` +
          `${handlers.join(', ')}.`,
      );
    }
    return (
      reflector.getAllAndOverride<InternalRole[]>(ROLES_KEY, [
        handler as () => unknown,
        AdminEefInterestController,
      ]) ?? []
    );
  };

  // Le périmètre attendu, route par route. L'export est PLUS restreint que la
  // lecture : `AdminCapability.ExportPersonalData` n'est accordée qu'à Admin et
  // SuperAdmin (`admin/lib/admin-capabilities.ts`), et faire sortir la table
  // entière dans un fichier n'est pas le même acte que lire une page à l'écran.
  const READ_ROLES = [
    InternalRole.Admin,
    InternalRole.SuperAdmin,
    InternalRole.Commercial,
    InternalRole.Counselor,
  ];
  const EXPORT_ROLES = [InternalRole.Admin, InternalRole.SuperAdmin];

  const expected: Record<string, InternalRole[]> = {
    getSummary: READ_ROLES,
    list: READ_ROLES,
    exportCsv: EXPORT_ROLES,
  };

  it("exige l'authentification admin ET la garde de rôles", () => {
    // Les deux, dans cet ordre : `RolesGuard` seul n'a personne à comparer, et
    // `AdminAuthGuard` seul laisse entrer n'importe quel rôle interne.
    expect(guards).toContain(AdminAuthGuard);
    expect(guards).toContain(RolesGuard);
  });

  it('ne laisse aucune route hors de la table de périmètre', () => {
    // La garde de la garde. Une route ajoutée sans décision de périmètre
    // explicite hériterait silencieusement du `@Roles` de classe — c'est-à-dire
    // du périmètre le plus large. Elle doit rougir ici d'abord.
    expect(handlers.sort()).toEqual(Object.keys(expected).sort());
  });

  it.each(Object.keys(expected))(
    'la route %s applique exactement le périmètre attendu',
    (handler) => {
      expect(rolesFor(handler).slice().sort()).toEqual(
        expected[handler].slice().sort(),
      );
    },
  );

  // LE test de ce fichier. La modération de forum et la gestion de contenu
  // n'ont aucun usage de coordonnées d'étudiants ; les ajouter serait une
  // extension de périmètre à faire consciemment, pas par copie d'un autre
  // contrôleur. Vérifié sur CHAQUE route, pas seulement sur la classe.
  it.each(handlers)('la route %s exclut moderator et content_manager', (h) => {
    const roles = rolesFor(h);
    expect(roles).not.toContain(InternalRole.Moderator);
    expect(roles).not.toContain(InternalRole.ContentManager);
  });

  it.each(handlers)(
    "la route %s n'est pas ouverte par omission de décorateur",
    (h) => {
      // Un tableau vide vaudrait « aucun rôle exigé » selon l'implémentation de
      // RolesGuard : on vérifie que chaque route en a un renseigné.
      expect(rolesFor(h).length).toBeGreaterThan(0);
    },
  );

  it("l'export est strictement plus restreint que la lecture", () => {
    // Formulé comme une relation et non comme deux listes : si demain on élargit
    // la lecture, cette assertion continue de dire ce qui compte.
    const read = rolesFor('list');
    const exported = rolesFor('exportCsv');
    expect(exported.length).toBeLessThan(read.length);
    for (const role of exported) {
      expect(read).toContain(role);
    }
  });
});
