// ─────────────────────────────────────────────────────────────────────────────
// La mention de paternité du catalogue « Études en France ».
//
// Le catalogue dérive de jeux de données du ministère de l'Enseignement
// supérieur (Parcoursup, Trouver mon master, principaux diplômes préparés),
// publiés sous Licence Ouverte 2.0. Cette licence autorise la réutilisation
// commerciale avec la mention de la source (docs/eef-catalog-pipeline.md :
// « simple mention de la source ») ; son usage courant y ajoute la date de
// dernière mise à jour de l'information. L'app affiche donc la date sous la forme
// honnête « récupérées le » : c'est la date de NOTRE copie, pas celle de chaque
// jeu (un millésime 2021 reste de 2021). `/config/app` la sert à l'app, qui la
// pose en pied de l'écran catalogue : une mention écrite dans le binaire
// vieillit avec lui, alors qu'un catalogue se réimporte.
//
// ## Pourquoi une constante, et pas une lecture de `manifest.json`
//
// Le manifeste décrit bien le catalogue importé, mais il vit dans `src/` et
// n'est pas copié dans `dist/` (aucun `resolveJsonModule`, aucun asset Nest) :
// le lire au démarrage marcherait en test et échouerait en production, en
// silence — l'app n'afficherait alors AUCUNE mention, ce qui est précisément
// le défaut que cette mention existe pour corriger.
//
// Une constante a l'inverse : elle est toujours là. Le risque devient qu'elle
// oublie une réimportation, et c'est `eef-catalog-attribution.spec.ts` qui le
// couvre — il compare cette constante au manifeste et échoue au premier
// réimport qui ne la met pas à jour.
// ─────────────────────────────────────────────────────────────────────────────

export interface EefCatalogAttribution {
  /** Le concédant, tel que la licence demande de le nommer. */
  readonly producer: string;
  /** Le portail où les jeux de données sont publiés. */
  readonly producerUrl: string;
  readonly licence: string;
  readonly licenceUrl: string;
  /** Les jeux de données réutilisés — des noms propres, jamais traduits. */
  readonly sources: readonly string[];
  /**
   * Le jour (`AAAA-MM-JJ`) de la dernière récupération des données. Un jour nu,
   * pas un instant : voir `campaignDay` dans `app-config.controller.ts`, qui
   * explique pourquoi un instant se reprojette en « la veille » pour une
   * moitié du public.
   */
  readonly updatedAt: string;
  /** `catalogVersion` du manifeste — pour relier la mention à un import. */
  readonly catalogVersion: string;
}

/**
 * Le nom lisible de chaque famille de jeux du manifeste (`sources[].dataset`).
 * Une famille absente de cette table fait échouer le spec : un nouveau jeu
 * réutilisé sans être cité est exactement ce que la licence interdit.
 */
export const EEF_ATTRIBUTION_SOURCE_NAMES: Readonly<Record<string, string>> = {
  parcoursup: 'Parcoursup',
  'trouver-mon-master': 'Trouver mon master',
  'diplomes-prepares': 'Principaux diplômes et formations préparés',
};

export const EEF_CATALOG_ATTRIBUTION: EefCatalogAttribution = {
  producer: "Ministère de l'Enseignement supérieur et de la Recherche",
  producerUrl: 'https://data.enseignementsup-recherche.gouv.fr',
  licence: 'Licence Ouverte 2.0',
  licenceUrl: 'https://www.etalab.gouv.fr/licence-ouverte-open-licence/',
  sources: [
    EEF_ATTRIBUTION_SOURCE_NAMES.parcoursup,
    EEF_ATTRIBUTION_SOURCE_NAMES['trouver-mon-master'],
    EEF_ATTRIBUTION_SOURCE_NAMES['diplomes-prepares'],
  ],
  updatedAt: '2026-09-21',
  catalogVersion: '1.3.0',
};
