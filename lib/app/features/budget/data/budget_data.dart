
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
    required this.rent,
    required this.food,
    required this.transport,
    required this.healthInsurance,
    required this.internetMobile,
    required this.leisureMisc,
  });

  final String country;
  final String currency;
  final double monthlyMin;
  final double monthlyMax;
  
  final BudgetCategory rent;
  final BudgetCategory food;
  final BudgetCategory transport;
  final BudgetCategory healthInsurance;
  final BudgetCategory internetMobile;
  final BudgetCategory leisureMisc;

  double get totalTypical =>
      rent.typical +
      food.typical +
      transport.typical +
      healthInsurance.typical +
      internetMobile.typical +
      leisureMisc.typical;
}

// ── Static Mock Data matching the supplied JSON exactly ──────────────────────
const List<LivingBudgetProfile> mockBudgetProfiles = [
  LivingBudgetProfile(
    country: 'France',
    currency: 'EUR',
    monthlyMin: 800,
    monthlyMax: 1000,
    rent: BudgetCategory(name: 'Loyer', typical: 400, note: 'Loyer hors capitale, coloc ou studio modeste'),
    food: BudgetCategory(name: 'Alimentation', typical: 230),
    transport: BudgetCategory(name: 'Transport', typical: 40),
    healthInsurance: BudgetCategory(name: 'Santé/Assurance', typical: 35),
    internetMobile: BudgetCategory(name: 'Forfaits & Internet', typical: 50),
    leisureMisc: BudgetCategory(name: 'Loisirs & Divers', typical: 120),
  ),
  LivingBudgetProfile(
    country: 'Canada',
    currency: 'CAD',
    monthlyMin: 1200,
    monthlyMax: 1500,
    rent: BudgetCategory(name: 'Loyer', typical: 700),
    food: BudgetCategory(name: 'Alimentation', typical: 300),
    transport: BudgetCategory(name: 'Transport', typical: 100),
    healthInsurance: BudgetCategory(name: 'Santé/Assurance', typical: 60),
    internetMobile: BudgetCategory(name: 'Forfaits & Internet', typical: 90),
    leisureMisc: BudgetCategory(name: 'Loisirs & Divers', typical: 200),
  ),
  LivingBudgetProfile(
    country: 'USA',
    currency: 'USD',
    monthlyMin: 1500,
    monthlyMax: 2000,
    rent: BudgetCategory(name: 'Loyer', typical: 900),
    food: BudgetCategory(name: 'Alimentation', typical: 400),
    transport: BudgetCategory(name: 'Transport', typical: 90),
    healthInsurance: BudgetCategory(name: 'Santé/Assurance', typical: 150),
    internetMobile: BudgetCategory(name: 'Forfaits & Internet', typical: 70),
    leisureMisc: BudgetCategory(name: 'Loisirs & Divers', typical: 200),
  ),
  LivingBudgetProfile(
    country: 'Belgium',
    currency: 'EUR',
    monthlyMin: 900,
    monthlyMax: 1100,
    rent: BudgetCategory(name: 'Loyer', typical: 450),
    food: BudgetCategory(name: 'Alimentation', typical: 280),
    transport: BudgetCategory(name: 'Transport', typical: 20),
    healthInsurance: BudgetCategory(name: 'Santé/Assurance', typical: 10),
    internetMobile: BudgetCategory(name: 'Forfaits & Internet', typical: 30),
    leisureMisc: BudgetCategory(name: 'Loisirs & Divers', typical: 200),
  ),
  LivingBudgetProfile(
    country: 'Morocco',
    currency: 'MAD',
    monthlyMin: 4000,
    monthlyMax: 7000,
    rent: BudgetCategory(name: 'Loyer', typical: 2500),
    food: BudgetCategory(name: 'Alimentation', typical: 1200),
    transport: BudgetCategory(name: 'Transport', typical: 400),
    healthInsurance: BudgetCategory(name: 'Santé/Assurance', typical: 250),
    internetMobile: BudgetCategory(name: 'Forfaits & Internet', typical: 250),
    leisureMisc: BudgetCategory(name: 'Loisirs & Divers', typical: 600),
  ),
  LivingBudgetProfile(
    country: 'Turkey',
    currency: 'TRY',
    monthlyMin: 12000,
    monthlyMax: 18000,
    rent: BudgetCategory(name: 'Loyer', typical: 6000),
    food: BudgetCategory(name: 'Alimentation', typical: 4000),
    transport: BudgetCategory(name: 'Transport', typical: 600),
    healthInsurance: BudgetCategory(name: 'Santé/Assurance', typical: 1000),
    internetMobile: BudgetCategory(name: 'Forfaits & Internet', typical: 800),
    leisureMisc: BudgetCategory(name: 'Loisirs & Divers', typical: 2000),
  ),
  LivingBudgetProfile(
    country: 'United Kingdom',
    currency: 'GBP',
    monthlyMin: 1000,
    monthlyMax: 1300,
    rent: BudgetCategory(name: 'Loyer', typical: 550),
    food: BudgetCategory(name: 'Alimentation', typical: 180),
    transport: BudgetCategory(name: 'Transport', typical: 60),
    healthInsurance: BudgetCategory(name: 'Santé/Assurance', typical: 65),
    internetMobile: BudgetCategory(name: 'Forfaits & Internet', typical: 40),
    leisureMisc: BudgetCategory(name: 'Loisirs & Divers', typical: 120),
  ),
  LivingBudgetProfile(
    country: 'Germany',
    currency: 'EUR',
    monthlyMin: 1000,
    monthlyMax: 1200,
    rent: BudgetCategory(name: 'Loyer', typical: 450),
    food: BudgetCategory(name: 'Alimentation', typical: 200),
    transport: BudgetCategory(name: 'Transport', typical: 40),
    healthInsurance: BudgetCategory(name: 'Santé/Assurance', typical: 120),
    internetMobile: BudgetCategory(name: 'Forfaits & Internet', typical: 35),
    leisureMisc: BudgetCategory(name: 'Loisirs & Divers', typical: 150),
  ),
  LivingBudgetProfile(
    country: 'Spain',
    currency: 'EUR',
    monthlyMin: 800,
    monthlyMax: 1000,
    rent: BudgetCategory(name: 'Loyer', typical: 400),
    food: BudgetCategory(name: 'Alimentation', typical: 250),
    transport: BudgetCategory(name: 'Transport', typical: 40),
    healthInsurance: BudgetCategory(name: 'Santé/Assurance', typical: 40),
    internetMobile: BudgetCategory(name: 'Forfaits & Internet', typical: 30),
    leisureMisc: BudgetCategory(name: 'Loisirs & Divers', typical: 150),
  ),
  LivingBudgetProfile(
    country: 'China',
    currency: 'CNY',
    monthlyMin: 4000,
    monthlyMax: 5500,
    rent: BudgetCategory(name: 'Loyer', typical: 2000),
    food: BudgetCategory(name: 'Alimentation', typical: 1500),
    transport: BudgetCategory(name: 'Transport', typical: 200),
    healthInsurance: BudgetCategory(name: 'Santé/Assurance', typical: 150),
    internetMobile: BudgetCategory(name: 'Forfaits & Internet', typical: 120),
    leisureMisc: BudgetCategory(name: 'Loisirs & Divers', typical: 500),
  ),
  LivingBudgetProfile(
    country: 'United Arab Emirates',
    currency: 'AED',
    monthlyMin: 4500,
    monthlyMax: 6000,
    rent: BudgetCategory(name: 'Loyer', typical: 3500),
    food: BudgetCategory(name: 'Alimentation', typical: 600),
    transport: BudgetCategory(name: 'Transport', typical: 350),
    healthInsurance: BudgetCategory(name: 'Santé/Assurance', typical: 400),
    internetMobile: BudgetCategory(name: 'Forfaits & Internet', typical: 400),
    leisureMisc: BudgetCategory(name: 'Loisirs & Divers', typical: 500),
  )
];
