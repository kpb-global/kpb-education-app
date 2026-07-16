import 'package:collection/collection.dart';

import '../models/app_models.dart';
import 'json_parse_utils.dart';

/// Maps `/profiles/me` JSON to [UserProfile].
abstract final class ProfileApiCodec {
  static UserProfile userProfileFromApi(
    Map<String, dynamic> json, {
    required String fallbackLocale,
  }) {
    final id = json['id'] as String?;
    // A profile without an id would silently impersonate a placeholder user
    // and poison the local store; the sync call-site catches and reports.
    if (id == null || id.isEmpty) {
      throw const FormatException('Profile payload is missing "id".');
    }
    return UserProfile(
      id: id,
      accountType: AccountType.values
              .firstWhereOrNull((item) => item.name == json['accountType']) ??
          AccountType.student,
      fullName: json['fullName'] as String? ?? '',
      email: json['email'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      whatsApp: json['whatsApp'] as String? ?? '',
      countryOfResidence: json['countryOfResidence'] as String? ?? '',
      preferredLanguage: json['preferredLanguage'] as String? ?? fallbackLocale,
      currentLevel: json['currentLevel'] as String?,
      targetLevel: json['targetLevel'] as String?,
      languageLevel: json['languageLevel'] as String?,
      fieldIds: stringListFromJson(json['fieldIds']),
      targetCountryIds: stringListFromJson(json['targetCountryIds']),
      gradeRange: json['gradeRange'] as String?,
      bacSeries: json['bacSeries'] as String?,
      annualTuitionBudgetEur: json['annualTuitionBudgetEur'] as int? ??
          ((json['monthlyBudgetEur'] as int?) != null
              ? (json['monthlyBudgetEur'] as int) * 12
              : null),
      monthlyBudgetEur: json['monthlyBudgetEur'] as int?,
      preferredCurrency: json['preferredCurrency'] as String? ?? 'XOF',
      wantsScholarshipSupport: json['wantsScholarshipSupport'] as bool? ??
          json['wantsScholarship'] as bool? ??
          false,
      availableDocuments: stringListFromJson(json['availableDocuments']),
      consentedAt: DateTime.tryParse(json['consentedAt'] as String? ?? ''),
      aiConsentedAt: DateTime.tryParse(json['aiConsentedAt'] as String? ?? ''),
      birthDate: DateTime.tryParse(json['birthDate'] as String? ?? ''),
      guardianName: json['guardianName'] as String?,
      guardianContact: json['guardianContact'] as String?,
      guardianConsentedAt:
          DateTime.tryParse(json['guardianConsentedAt'] as String? ?? ''),
    );
  }
}
