// Living-cost model for the budget simulator.
//
// Launch scope = the locked destination countries (France, Canada, USA,
// Morocco, Turkey, United Kingdom, Germany, Spain, UAE, China).
// Each profile carries the same nine spending categories, in the same order,
// so the UI can map a category index to a fixed icon/colour palette.

class BudgetCategory {
  const BudgetCategory({
    required this.name,
    required this.typical,
    this.note,
  });

  final String name;
  final double typical;
  final String? note;
}

class LivingBudgetProfile {
  const LivingBudgetProfile({
    required this.country,
    required this.currency,
    required this.monthlyMin,
    required this.monthlyMax,
    required this.categories,
  });

  final String country;
  final String currency;
  final double monthlyMin;
  final double monthlyMax;

  /// Always nine entries, in canonical order:
  /// 0 Loyer · 1 Charges & énergie · 2 Alimentation · 3 Transport ·
  /// 4 Santé & assurance · 5 Forfait & Internet · 6 Fournitures & livres ·
  /// 7 Vêtements & hygiène · 8 Loisirs & divers
  final List<BudgetCategory> categories;

  double get totalTypical => categories.fold(0.0, (sum, c) => sum + c.typical);
}

// ── Nine MVP destination profiles · nine categories each ─────────────────────
const List<LivingBudgetProfile> mockBudgetProfiles = [
  LivingBudgetProfile(
    country: 'France',
    currency: 'EUR',
    monthlyMin: 800,
    monthlyMax: 1000,
    categories: [
      BudgetCategory(
          name: 'Loyer',
          typical: 400,
          note: 'Hors capitale, coloc ou studio modeste'),
      BudgetCategory(name: 'Charges & énergie', typical: 60),
      BudgetCategory(name: 'Alimentation', typical: 230),
      BudgetCategory(name: 'Transport', typical: 40),
      BudgetCategory(name: 'Santé & assurance', typical: 35),
      BudgetCategory(name: 'Forfait & Internet', typical: 30),
      BudgetCategory(name: 'Fournitures & livres', typical: 30),
      BudgetCategory(name: 'Vêtements & hygiène', typical: 40),
      BudgetCategory(name: 'Loisirs & divers', typical: 90),
    ],
  ),
  LivingBudgetProfile(
    country: 'Canada',
    currency: 'CAD',
    monthlyMin: 1200,
    monthlyMax: 1500,
    categories: [
      BudgetCategory(name: 'Loyer', typical: 700),
      BudgetCategory(name: 'Charges & énergie', typical: 80),
      BudgetCategory(name: 'Alimentation', typical: 300),
      BudgetCategory(name: 'Transport', typical: 100),
      BudgetCategory(name: 'Santé & assurance', typical: 60),
      BudgetCategory(name: 'Forfait & Internet', typical: 70),
      BudgetCategory(name: 'Fournitures & livres', typical: 40),
      BudgetCategory(name: 'Vêtements & hygiène', typical: 50),
      BudgetCategory(name: 'Loisirs & divers', typical: 90),
    ],
  ),
  LivingBudgetProfile(
    country: 'USA',
    currency: 'USD',
    monthlyMin: 1500,
    monthlyMax: 2000,
    categories: [
      BudgetCategory(name: 'Loyer', typical: 900),
      BudgetCategory(name: 'Charges & énergie', typical: 120),
      BudgetCategory(name: 'Alimentation', typical: 400),
      BudgetCategory(name: 'Transport', typical: 90),
      BudgetCategory(name: 'Santé & assurance', typical: 150),
      BudgetCategory(name: 'Forfait & Internet', typical: 70),
      BudgetCategory(name: 'Fournitures & livres', typical: 60),
      BudgetCategory(name: 'Vêtements & hygiène', typical: 70),
      BudgetCategory(name: 'Loisirs & divers', typical: 130),
    ],
  ),
  LivingBudgetProfile(
    country: 'Morocco',
    currency: 'MAD',
    monthlyMin: 4000,
    monthlyMax: 7000,
    categories: [
      BudgetCategory(name: 'Loyer', typical: 2500),
      BudgetCategory(name: 'Charges & énergie', typical: 350),
      BudgetCategory(name: 'Alimentation', typical: 1200),
      BudgetCategory(name: 'Transport', typical: 400),
      BudgetCategory(name: 'Santé & assurance', typical: 250),
      BudgetCategory(name: 'Forfait & Internet', typical: 200),
      BudgetCategory(name: 'Fournitures & livres', typical: 250),
      BudgetCategory(name: 'Vêtements & hygiène', typical: 300),
      BudgetCategory(name: 'Loisirs & divers', typical: 500),
    ],
  ),
  LivingBudgetProfile(
    country: 'Turkey',
    currency: 'TRY',
    monthlyMin: 12000,
    monthlyMax: 18000,
    categories: [
      BudgetCategory(name: 'Loyer', typical: 6000),
      BudgetCategory(name: 'Charges & énergie', typical: 900),
      BudgetCategory(name: 'Alimentation', typical: 4000),
      BudgetCategory(name: 'Transport', typical: 600),
      BudgetCategory(name: 'Santé & assurance', typical: 1000),
      BudgetCategory(name: 'Forfait & Internet', typical: 700),
      BudgetCategory(name: 'Fournitures & livres', typical: 600),
      BudgetCategory(name: 'Vêtements & hygiène', typical: 800),
      BudgetCategory(name: 'Loisirs & divers', typical: 1800),
    ],
  ),
  LivingBudgetProfile(
    country: 'United Kingdom',
    currency: 'GBP',
    monthlyMin: 1000,
    monthlyMax: 1300,
    categories: [
      BudgetCategory(name: 'Loyer', typical: 550),
      BudgetCategory(name: 'Charges & énergie', typical: 90),
      BudgetCategory(name: 'Alimentation', typical: 180),
      BudgetCategory(name: 'Transport', typical: 60),
      BudgetCategory(
          name: 'Santé & assurance',
          typical: 65,
          note: 'IHS surcharge lissé sur l\'année'),
      BudgetCategory(name: 'Forfait & Internet', typical: 35),
      BudgetCategory(name: 'Fournitures & livres', typical: 40),
      BudgetCategory(name: 'Vêtements & hygiène', typical: 50),
      BudgetCategory(name: 'Loisirs & divers', typical: 110),
    ],
  ),
  LivingBudgetProfile(
    country: 'Germany',
    currency: 'EUR',
    monthlyMin: 1000,
    monthlyMax: 1200,
    categories: [
      BudgetCategory(name: 'Loyer', typical: 450),
      BudgetCategory(name: 'Charges & énergie', typical: 90),
      BudgetCategory(name: 'Alimentation', typical: 200),
      BudgetCategory(name: 'Transport', typical: 40),
      BudgetCategory(
          name: 'Santé & assurance',
          typical: 120,
          note: 'Assurance santé étudiante obligatoire'),
      BudgetCategory(name: 'Forfait & Internet', typical: 35),
      BudgetCategory(name: 'Fournitures & livres', typical: 40),
      BudgetCategory(name: 'Vêtements & hygiène', typical: 50),
      BudgetCategory(name: 'Loisirs & divers', typical: 110),
    ],
  ),
  LivingBudgetProfile(
    country: 'Spain',
    currency: 'EUR',
    monthlyMin: 800,
    monthlyMax: 1000,
    categories: [
      BudgetCategory(name: 'Loyer', typical: 400),
      BudgetCategory(name: 'Charges & énergie', typical: 70),
      BudgetCategory(name: 'Alimentation', typical: 250),
      BudgetCategory(name: 'Transport', typical: 40),
      BudgetCategory(name: 'Santé & assurance', typical: 40),
      BudgetCategory(name: 'Forfait & Internet', typical: 30),
      BudgetCategory(name: 'Fournitures & livres', typical: 30),
      BudgetCategory(name: 'Vêtements & hygiène', typical: 40),
      BudgetCategory(name: 'Loisirs & divers', typical: 100),
    ],
  ),
  LivingBudgetProfile(
    country: 'United Arab Emirates',
    currency: 'AED',
    monthlyMin: 4500,
    monthlyMax: 6500,
    categories: [
      BudgetCategory(name: 'Loyer', typical: 3500),
      BudgetCategory(name: 'Charges & énergie', typical: 300),
      BudgetCategory(name: 'Alimentation', typical: 600),
      BudgetCategory(name: 'Transport', typical: 300),
      BudgetCategory(name: 'Santé & assurance', typical: 350),
      BudgetCategory(name: 'Forfait & Internet', typical: 250),
      BudgetCategory(name: 'Fournitures & livres', typical: 200),
      BudgetCategory(name: 'Vêtements & hygiène', typical: 250),
      BudgetCategory(name: 'Loisirs & divers', typical: 400),
    ],
  ),
  LivingBudgetProfile(
    country: 'China',
    currency: 'CNY',
    monthlyMin: 2000,
    monthlyMax: 4000,
    categories: [
      BudgetCategory(
          name: 'Loyer',
          typical: 1200,
          note: 'Résidence universitaire ou coloc hors centre-ville'),
      BudgetCategory(name: 'Charges & énergie', typical: 150),
      BudgetCategory(name: 'Alimentation', typical: 800),
      BudgetCategory(name: 'Transport', typical: 150),
      BudgetCategory(
          name: 'Santé & assurance',
          typical: 50,
          note: 'Assurance étudiante obligatoire ~600-800 CNY/an'),
      BudgetCategory(name: 'Forfait & Internet', typical: 100),
      BudgetCategory(name: 'Fournitures & livres', typical: 100),
      BudgetCategory(name: 'Vêtements & hygiène', typical: 150),
      BudgetCategory(name: 'Loisirs & divers', typical: 300),
    ],
  ),
];
