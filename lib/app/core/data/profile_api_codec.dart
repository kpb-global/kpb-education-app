import 'package:collection/collection.dart';

import '../models/app_models.dart';
import 'json_parse_utils.dart';

/// Maps `/profiles/me` JSON to [UserProfile].
abstract final class ProfileApiCodec {
  static UserProfile userProfileFromApi(
    Map<String, dynamic> json, {
    required String fallbackLocale,
  }) {
    return UserProfile(
      id: json['id'] as String? ?? 'demo-user',
      accountType: AccountType.values
              .firstWhereOrNull((item) => item.name == json['accountType']) ??
          AccountType.student,
      fullName: json['fullName'] as String? ?? '',
      email: json['email'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      whatsApp: json['whatsApp'] as String? ?? '',
      countryOfResidence: json['countryOfResidence'] as String? ?? '',
      preferredLanguage:
          json['preferredLanguage'] as String? ?? fallbackLocale,
      currentLevel: json['currentLevel'] as String?,
      targetLevel: json['targetLevel'] as String?,
      languageLevel: json['languageLevel'] as String?,
      fieldIds: stringListFromJson(json['fieldIds']),
      targetCountryIds: stringListFromJson(json['targetCountryIds']),
      gradeRange: json['gradeRange'] as String?,
      bacSeries: json['bacSeries'] as String?,
      monthlyBudgetEur: json['monthlyBudgetEur'] as int?,
      wantsScholarshipSupport: json['wantsScholarshipSupport'] as bool? ??
          json['wantsScholarship'] as bool? ??
          false,
      availableDocuments: stringListFromJson(json['availableDocuments']),
      consentedAt: DateTime.tryParse(json['consentedAt'] as String? ?? ''),
      aiConsentedAt: DateTime.tryParse(json['aiConsentedAt'] as String? ?? ''),
    );
  }
}
