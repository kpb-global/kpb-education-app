import type { Institution } from '@prisma/client';

import { mapInstitution } from './catalog.mapper';

// Le logo qu'un écran reçoit : Wikimedia ne fabrique que des miniatures de largeur
// standard (20, 40, 60, 120, 250, 330, 500…). Toute autre répond HTTP 400 — le
// 320 px que l'import a longtemps écrit en base n'affichait aucun logo.

const THUMB = (width: number) =>
  `https://upload.wikimedia.org/wikipedia/commons/thumb/c/c6/Universit%C3%A4t_Artois_Logo.svg/${width}px-Universit%C3%A4t_Artois_Logo.svg.png`;

const institution = (logoUrl: string | null) =>
  ({ id: 'eef-univ-1', logoUrl }) as unknown as Institution;

describe('mapInstitution — logo', () => {
  it('sert une ligne importée avec l’ancien 320 px à une largeur que Wikimedia accepte', () => {
    expect(mapInstitution(institution(THUMB(320))).logoUrl).toBe(THUMB(330));
  });

  it('convertit un SVG en miniature standard', () => {
    expect(
      mapInstitution(
        institution(
          'https://upload.wikimedia.org/wikipedia/commons/c/c6/Universit%C3%A4t_Artois_Logo.svg',
        ),
      ).logoUrl,
    ).toBe(THUMB(330));
  });

  it('laisse une miniature déjà standard, un PNG d’origine et l’absence de logo', () => {
    expect(mapInstitution(institution(THUMB(330))).logoUrl).toBe(THUMB(330));
    const png = 'https://upload.wikimedia.org/wikipedia/commons/6/6d/Logo_Reims_University.png';
    expect(mapInstitution(institution(png)).logoUrl).toBe(png);
    expect(mapInstitution(institution(null)).logoUrl).toBeNull();
  });
});
