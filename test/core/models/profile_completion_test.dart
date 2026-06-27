import 'package:flutter_test/flutter_test.dart';
import 'package:karatou/app/core/models/app_models.dart';

UserProfile _full({int? monthlyBudgetEur = 750}) {
  return UserProfile(
    id: 'u1',
    accountType: AccountType.student,
    fullName: 'Awa Diallo',
    email: 'awa@example.com',
    phone: '+22500000000',
    whatsApp: '+22500000000',
    countryOfResidence: 'CI',
    preferredLanguage: 'fr',
    currentLevel: 'Bachelor',
    targetLevel: 'Master',
    languageLevel: 'Advanced',
    fieldIds: const ['cs'],
    targetCountryIds: const ['fra'],
    gradeRange: '12 - 14/20',
    monthlyBudgetEur: monthlyBudgetEur,
    availableDocuments: const ['Passport'],
  );
}

void main() {
  group('UserProfile.completionScore (KPB-65)', () {
    test('reaches 100% once the monthly budget is collected', () {
      expect(_full().completionScore, 1.0);
    });

    test('without a budget it cannot reach 100% (budget was the only gap)', () {
      final score = _full(monthlyBudgetEur: null).completionScore;
      expect(score, lessThan(1.0));
      // Exactly one of 13 weighted items missing.
      expect(score, closeTo(12 / 13, 0.0001));
    });

    test('a zero budget does not count as completed', () {
      expect(_full(monthlyBudgetEur: 0).completionScore, closeTo(12 / 13, 0.0001));
    });
  });
}
