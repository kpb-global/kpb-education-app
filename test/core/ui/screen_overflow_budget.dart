// Budget des débordements d'écran, par cas — même patron que color_budget.dart.
//
// MESURÉ le 14/08/2026 sur Flutter 3.44.1, par
// test/core/ui/screen_matrix_test.dart : 20 surfaces × 2 téléphones × 3 échelles
// de texte = 120 cas. Les 108 cas absents de cette table valent zéro.
// (Revérifié le 15/08/2026 après les masquages M1/M2 : mêmes 20 surfaces, mêmes
// 14 cas budgétés.)
//
// La clé est `<écran>@<téléphone>@<échelle>`, la valeur est le NOMBRE d'objets de
// rendu qui débordent — pas le nombre de pixels.
//
// POURQUOI DES COMPTES ET PAS DES PIXELS. Le nombre de pixels dépend des métriques
// de police, et le dépôt sait déjà que « le rendu de police Linux diffère »
// (c'est la raison pour laquelle les goldens sont exclues de la CI,
// flutter-ci.yml:89 et architecture §11.5). Un budget en pixels rougirait en CI
// sans qu'une ligne ait bougé. Un compte, lui, est structurel : trois cartes qui
// débordent débordent sur les deux systèmes. Les pixels sont conservés en
// commentaire, pour l'humain qui corrige.
//
// Règle du cliquet, dans les deux sens :
//   · un cas qui dépasse son budget fait ÉCHOUER la CI ;
//   · un cas tombé à ZÉRO fait aussi échouer, avec le message « abaissez le
//     budget » — sinon un correctif de lot 6-8 se perdrait et le budget
//     deviendrait une excuse permanente. Seul le passage à zéro déclenche ce
//     second test : une oscillation de 3 à 2 due aux métriques de police ne doit
//     pas rougir la CI.
//
// CE QUE CE BUDGET DIT, EN FRANÇAIS. Une seule surface déborde encore :
//
//   · AuthWelcomeScreen — TROUVAILLE DE CE HARNAIS, dans aucun audit : 44 px sur
//     iPhone 14 et 38 px sur Android à l'échelle 1,3. C'est le PREMIER écran que
//     voit un testeur, et il déborde pour tout utilisateur qui a grossi la police
//     de son téléphone — une bonne part du public de cette app. Rattaché à aucun
//     lot ; à trancher avant ou après l'archive.
//
// LES TROIS AUTRES ONT ÉTÉ CORRIGÉES par le lot 8 (15/08/2026), et leurs budgets
// abaissés à zéro par le cliquet :
//
//   · FrancePrivateAdmissionScreen (FLU-07) — l'en-tête débordait de 41 à 64 px
//     À TOUTES les échelles, y compris 1,0. La hauteur du SliverAppBar est
//     désormais MESURÉE (TextPainter, style du thème fusionné) au lieu d'un
//     `expandedHeight: 220` figé ; le `padding` haut de 96 px qui doublait
//     l'encoche vient de MediaQuery.
//   · UniversitiesScreen (FLU-06) — le carrousel `SizedBox(height: 126)` fixe
//     grandit maintenant avec l'échelle de texte : base 126 mesurée-bonne à 1,0
//     plus la croissance exacte des quatre lignes de texte.
//   · HousingEstimatorScreen (FLU-08) — la fourchette de loyer est passée dans
//     un `Flexible` avec ellipse.
//
// Les 19 autres surfaces — les 5 onglets, les 4 outils que le tiroir propose
// aujourd'hui, les 4 écrans IA masqués par M1 (retirés de la navigation, gardés
// sous mesure), le tiroir lui-même, les deux écrans de lien magique, le chat —
// et les trois écrans corrigés par le lot 8 ne débordent à aucune taille ni
// aucune échelle. Et aucune des 120 combinaisons n'affiche de clé de
// traduction brute.
//
// LE COMPTE EST RESTÉ À 20 SURFACES À TRAVERS LE MASQUAGE, et ce n'est pas une
// coïncidence : le lot 7 a retiré quatre outils du tiroir et la matrice les a
// repris nommément (`ai:…` dans screen_matrix_test.dart). Sans ce rattrapage,
// la couverture serait tombée à 16 surfaces le jour du masquage — et serait
// remontée à 20 le jour où le drapeau rebascule, sur quatre écrans que plus
// rien n'aurait mesuré entre-temps.

/// Nombre d'objets de rendu qui débordent, par cas. Absent = 0.
const screenOverflowBudget = <String, int>{
  // 44 px · 38 px — le premier écran de l'app
  'AuthWelcomeScreen@iphone14@1.3': 1,
  'AuthWelcomeScreen@android360@1.3': 1,
};

/// Les cas dont on sait pourquoi ils débordent, avec le constat d'audit
/// correspondant. Sert au message d'échec : un développeur qui voit rougir un cas
/// déjà connu doit le comprendre en une ligne, et un cas SANS entrée ici est une
/// régression toute neuve.
const screenOverflowKnownCauses = <String, String>{
  'AuthWelcomeScreen':
      "TROUVÉ PAR CE HARNAIS le 14/08/2026, dans aucun audit : l'écran d'entrée "
          "déborde à l'échelle de texte 1,3 (44 px iPhone 14, 38 px Android). "
          "C'est le premier écran d'un testeur.",
};

/// Le total, pour que le message de synthèse ne puisse pas être approximatif.
const screenOverflowCaseCount = 2;
const screenMatrixCaseCount = 120;
