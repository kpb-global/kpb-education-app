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
// CE QUE CE BUDGET DIT, EN FRANÇAIS. Quatre surfaces débordent aujourd'hui, dont
// deux qu'aucun audit n'avait vues :
//
//   · FrancePrivateAdmissionScreen — déborde À TOUTES LES ÉCHELLES, y compris
//     1,0 : 41 px sur iPhone 14, 64 px sur Android compact. L'en-tête
//     (`SliverAppBar(expandedHeight: 220)` + `FlexibleSpaceBar` avec un drapeau à
//     44 pt) ne tient pas. À 1,3 sur Android un SECOND débordement apparaît, de
//     1,3 px sur la droite. Écran atteignable en trois taps :
//     Explorer → France → « Admission écoles privées ».
//     (L'audit du 13/08 annonçait 88 px ; il mesurait sans encoche. Avec une
//     barre de statut de 24 pt, le SliverAppBar gagne ces 24 pt et il reste
//     64 px. 88 − 24 = 64 : les deux mesures sont cohérentes, celle-ci est celle
//     d'un vrai téléphone.)
//
//   · UniversitiesScreen — le carrousel de destinations : rien à 1,0, puis
//     3 cartes × 3 px à 1,1, et 3 cartes × 19 px à 1,3. Identique sur les deux
//     largeurs, le débordement étant vertical (`SizedBox(height: 126)` fixe).
//
//   · AuthWelcomeScreen — TROUVAILLE DE CE HARNAIS, dans aucun audit : 44 px sur
//     iPhone 14 et 38 px sur Android à l'échelle 1,3. C'est le PREMIER écran que
//     voit un testeur, et il déborde pour tout utilisateur qui a grossi la police
//     de son téléphone — une bonne part du public de cette app.
//
//   · HousingEstimatorScreen — 4,8 px sur la droite, uniquement à 1,3 et
//     uniquement sur Android compact (la ligne de fourchette de loyer, un `Row`
//     sans `Flexible`). Compté deux fois ci-dessous parce que l'écran est
//     atteignable par deux chemins et monté par les deux dans la matrice.
//
// Les 16 autres surfaces — les 5 onglets, les 4 outils que le tiroir propose
// aujourd'hui, les 4 écrans IA masqués par M1 (retirés de la navigation, gardés
// sous mesure), le tiroir lui-même, les deux écrans de lien magique, le chat —
// ne débordent à aucune taille ni aucune échelle. Et aucune des 120
// combinaisons n'affiche de clé de traduction brute.
//
// LE COMPTE EST RESTÉ À 20 SURFACES À TRAVERS LE MASQUAGE, et ce n'est pas une
// coïncidence : le lot 7 a retiré quatre outils du tiroir et la matrice les a
// repris nommément (`ai:…` dans screen_matrix_test.dart). Sans ce rattrapage,
// la couverture serait tombée à 16 surfaces le jour du masquage — et serait
// remontée à 20 le jour où le drapeau rebascule, sur quatre écrans que plus
// rien n'aurait mesuré entre-temps.

/// Nombre d'objets de rendu qui débordent, par cas. Absent = 0.
const screenOverflowBudget = <String, int>{
  // 41 px · 58 px · 93 px
  'FrancePrivateAdmissionScreen@iphone14@1.0': 1,
  'FrancePrivateAdmissionScreen@iphone14@1.1': 1,
  'FrancePrivateAdmissionScreen@iphone14@1.3': 1,
  // 64 px · 81 px · 116 px + 1,3 px à droite
  'FrancePrivateAdmissionScreen@android360@1.0': 1,
  'FrancePrivateAdmissionScreen@android360@1.1': 1,
  'FrancePrivateAdmissionScreen@android360@1.3': 2,

  // 3 cartes × 3 px, puis 3 cartes × 19 px
  'UniversitiesScreen@iphone14@1.1': 3,
  'UniversitiesScreen@iphone14@1.3': 3,
  'UniversitiesScreen@android360@1.1': 3,
  'UniversitiesScreen@android360@1.3': 3,

  // 44 px · 38 px — le premier écran de l'app
  'AuthWelcomeScreen@iphone14@1.3': 1,
  'AuthWelcomeScreen@android360@1.3': 1,

  // 4,8 px à droite, Android compact uniquement
  'HousingEstimatorScreen@android360@1.3': 1,
  'tool:tools_housing@android360@1.3': 1,
};

/// Les cas dont on sait pourquoi ils débordent, avec le constat d'audit
/// correspondant. Sert au message d'échec : un développeur qui voit rougir un cas
/// déjà connu doit le comprendre en une ligne, et un cas SANS entrée ici est une
/// régression toute neuve.
const screenOverflowKnownCauses = <String, String>{
  'FrancePrivateAdmissionScreen':
      "FLU-07 — en-tête SliverAppBar(expandedHeight: 220) trop court pour son "
          'Column (drapeau 44 pt, titre 24, sous-titre 13) : '
          'france_private_admission_screen.dart:41-51',
  'UniversitiesScreen':
      'FLU-06 — carrousel de destinations à hauteur fixe SizedBox(height: 126) '
          'avec des polices fixes qui grandissent : universities_screen.dart:472, '
          '515-522',
  'HousingEstimatorScreen':
      'FLU-08 — ligne de fourchette de loyer, Row sans Flexible : '
          'housing_estimator_screen.dart:151',
  'tool:tools_housing': 'FLU-08 — même écran, atteint depuis le tiroir',
  'AuthWelcomeScreen':
      "TROUVÉ PAR CE HARNAIS le 14/08/2026, dans aucun audit : l'écran d'entrée "
          "déborde à l'échelle de texte 1,3 (44 px iPhone 14, 38 px Android). "
          "C'est le premier écran d'un testeur.",
};

/// Le total, pour que le message de synthèse ne puisse pas être approximatif.
const screenOverflowCaseCount = 14;
const screenMatrixCaseCount = 120;
