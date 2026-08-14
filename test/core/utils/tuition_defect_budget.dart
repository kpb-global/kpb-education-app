// Budget des prix faux, par cause racine — même patron que color_budget.dart.
//
// MESURÉ, pas estimé : sur les 582 programmes servis par
// https://api.kpbeducation.cloud/api/catalog/programs?lang=fr le 14/08/2026,
// classés par test/core/utils/tuition_fixture.dart.
//
// Règle du cliquet : ces nombres ne peuvent que BAISSER. Le lot 6 les fera
// tomber à zéro. S'ils baissent sans être mis à jour ici, le second test de
// tuition_utils_test.dart devient rouge et vous dit exactement quoi écrire —
// c'est le seul mécanisme qui empêche un budget de pourrir en excuse permanente.
//
// Total aujourd'hui : 272 programmes sur 582 affichent un coût faux.
// L'audit du 13/08 en annonçait 227 : il avait manqué les 8 étiquettes de
// fourchette « selon le campus » (44 programmes) et les 2 coûts totaux affichés
// « /an ». Les 45 programmes d'écart sont une trouvaille de ce harnais.

import 'tuition_fixture.dart';

/// Nombre d'ÉTIQUETTES DISTINCTES par cause.
const tuitionLabelBudget = <TuitionCause, int>{
  TuitionCause.foreignTreatedAsEuro: 66,
  TuitionCause.cfaReconverted: 18,
  TuitionCause.notASingleAmount: 9,
  TuitionCause.totalShownAsAnnual: 2,
};

/// Nombre de PROGRAMMES DE PRODUCTION touchés par cause. C'est le chiffre qui
/// compte pour un étudiant : 48 programmes sénégalais affichés à 656 fois leur
/// prix réel, ce n'est pas « une étiquette ».
const tuitionProgramBudget = <TuitionCause, int>{
  TuitionCause.foreignTreatedAsEuro: 177,
  TuitionCause.cfaReconverted: 48,
  TuitionCause.notASingleAmount: 45,
  TuitionCause.totalShownAsAnnual: 2,
};

/// Ce que la fixture doit décrire. Si l'un de ces nombres change, la fixture a
/// été régénérée : c'est légitime, mais alors les budgets ci-dessus doivent être
/// recalculés dans le même commit.
const tuitionFixtureLabelCount = 146;
const tuitionFixtureProgramCount = 582;

/// Les programmes dont le prix affiché est JUSTE aujourd'hui (305 en euros
/// + 5 sans libellé). Assertion positive : un correctif de lot 6 qui casserait
/// ce cas-là serait un recul, et rien ne l'aurait dit.
const tuitionCorrectProgramCount = 310;
