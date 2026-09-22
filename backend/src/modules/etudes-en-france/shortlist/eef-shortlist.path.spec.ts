// La table des chemins d'entrée — et surtout ce qu'elle REFUSE.
//
// Ce fichier existe pour une raison précise : la feuille de déclaration pose
// deux questions avec le même menu de six mots, et « licence » y veut dire
// « je suis au niveau licence » sans dire si l'étudiant entre en L1, continue
// en L3 ou sort diplômé. Se tromper de lecture, ce n'est pas rendre une liste
// approximative : c'est envoyer un étudiant vers une échéance qui n'est pas la
// sienne — la DAP se ferme mi-décembre, la procédure Études en France non.
import { resolveEefPath } from './eef-shortlist.path';

const fieldIds = ['d02'];

function declare(currentLevel: string | null, targetLevel: string | null) {
  return { currentLevel, targetLevel, fieldIds };
}

describe('resolveEefPath', () => {
  describe('les couples que la table accepte', () => {
    it('lit une entrée post-bac depuis le lycée comme depuis le bac', () => {
      expect(resolveEefPath(declare('terminale', 'licence')).path)
        .toBe('post_bac');
      expect(resolveEefPath(declare('bac', 'licence')).path).toBe('post_bac');
    });

    // LE cas qui justifie la table entière : même niveau visé que ci-dessus,
    // chemin entièrement différent. Seul le niveau COURANT les sépare.
    it('distingue « entrer en licence » de « continuer une licence »', () => {
      const entering = resolveEefPath(declare('bac', 'licence'));
      const continuing = resolveEefPath(declare('licence', 'licence'));

      expect(entering.path).toBe('post_bac');
      expect(continuing.path).toBe('licence_continuation');
      expect(entering.path).not.toBe(continuing.path);
    });

    it('lit le cas le plus courant de la procédure, licence → master', () => {
      expect(resolveEefPath(declare('licence', 'master')).path).toBe('master');
    });

    it('accepte un second master', () => {
      expect(resolveEefPath(declare('master', 'master')).path).toBe('master');
    });

    it('ignore la casse et les espaces du niveau déclaré', () => {
      expect(resolveEefPath(declare('  LICENCE ', 'Master')).path)
        .toBe('master');
    });
  });

  describe('les refus', () => {
    it("refuse un master demandé depuis le lycée plutôt que d'en servir 3 112",
      () => {
        for (const current of ['terminale', 'bac']) {
          const resolution = resolveEefPath(declare(current, 'master'));
          expect(resolution.path).toBeNull();
          expect(resolution.blocked).toBe('declaration_unmappable');
        }
      });

    // Reprendre une L1 ? une L3 ? Les deux listes n'ont aucune ligne en
    // commun, et deviner enverrait vers la mauvaise échéance.
    it('refuse master → licence, faute de savoir ce qui est demandé', () => {
      expect(resolveEefPath(declare('master', 'licence')).blocked)
        .toBe('declaration_unmappable');
    });

    it('refuse « autre », des deux côtés', () => {
      expect(resolveEefPath(declare('autre', 'master')).blocked)
        .toBe('declaration_unmappable');
      expect(resolveEefPath(declare('licence', 'autre')).blocked)
        .toBe('declaration_unmappable');
    });

    it('refuse un niveau hors menu sans le rapprocher du plus proche', () => {
      // « bachelor » ressemble à « licence » ; le rapprocher serait interpréter
      // une valeur que le client n'envoie pas.
      expect(resolveEefPath(declare('bachelor', 'master')).blocked)
        .toBe('current_level_missing');
    });
  });

  describe('les motifs, qui doivent se distinguer entre eux', () => {
    it("distingue « pas de déclaration » de « déclaration incomplète »", () => {
      expect(resolveEefPath(null).blocked).toBe('no_declaration');
      expect(resolveEefPath(declare(null, null)).blocked)
        .toBe('target_level_missing');
    });

    it('réclame le niveau VISÉ avant le niveau courant', () => {
      // C'est lui qui décide du chemin : sans lui, demander le niveau courant
      // ferait remplir un champ qui ne débloquerait rien.
      expect(resolveEefPath(declare('licence', null)).blocked)
        .toBe('target_level_missing');
      expect(resolveEefPath(declare(null, 'master')).blocked)
        .toBe('current_level_missing');
    });

    // Le doctorat n'est pas une déclaration illisible : c'est le catalogue qui
    // s'arrête au master. L'écran doit dire « pas encore couvert », pas
    // « complète ta déclaration » — ce dernier message ferait remplir un champ
    // qui ne changerait rien.
    it('dit « pas encore au catalogue » pour le doctorat, même sans niveau courant',
      () => {
        expect(resolveEefPath(declare('master', 'doctorat')).blocked)
          .toBe('level_not_in_catalog');
        expect(resolveEefPath(declare(null, 'doctorat')).blocked)
          .toBe('level_not_in_catalog');
      });

    it('ne rend jamais un chemin ET un motif', () => {
      const cases = [
        declare('licence', 'master'),
        declare('terminale', 'master'),
        declare(null, null),
      ];
      for (const declaration of cases) {
        const resolution = resolveEefPath(declaration);
        expect(resolution.path === null).toBe(resolution.blocked !== null);
      }
    });
  });
});
