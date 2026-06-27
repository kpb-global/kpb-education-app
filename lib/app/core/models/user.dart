part of 'app_models.dart';


enum AccountType { student, parent, partner, commercial }
enum InternalRole {
  admin,
  counselor,
  commercial,
  contentManager,
  moderator,
  superAdmin,
}
enum PublicationStatus { draft, published, archived }
class LocalizedText {
  const LocalizedText({
    required this.fr,
    required this.en,
  });

  final String fr;
  final String en;

  String resolve(String localeCode) => localeCode.startsWith('fr') ? fr : en;

  factory LocalizedText.fromJson(Map<String, dynamic> json) {
    return LocalizedText(
      fr: json['fr'] as String? ?? '',
      en: json['en'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'fr': fr,
        'en': en,
      };
}
class UserProfile {
  const UserProfile({
    required this.id,
    required this.accountType,
    required this.fullName,
    required this.email,
    required this.phone,
    required this.whatsApp,
    required this.countryOfResidence,
    required this.preferredLanguage,
    this.currentLevel,
    this.targetLevel,
    this.languageLevel,
    this.fieldIds = const [],
    this.targetCountryIds = const [],
    this.gradeRange,
    this.bacSeries,
    this.monthlyBudgetEur,
    this.wantsScholarshipSupport = false,
    this.availableDocuments = const [],
    this.consentedAt,
    this.aiConsentedAt,
  });

  final String id;
  final AccountType accountType;
  final String fullName;
  final String email;
  final String phone;
  final String whatsApp;
  final String countryOfResidence;
  final String preferredLanguage;
  final String? currentLevel;
  final String? targetLevel;
  final String? languageLevel;
  final List<String> fieldIds;
  final List<String> targetCountryIds;
  final String? gradeRange;
  final String? bacSeries;
  final int? monthlyBudgetEur;
  final bool wantsScholarshipSupport;
  final List<String> availableDocuments;
  final DateTime? consentedAt;

  /// Timestamp of explicit consent to third-party AI (Groq) processing. Null
  /// until the user opts into the AI coach. Distinct from [consentedAt].
  final DateTime? aiConsentedAt;

  /// Whether the user has granted explicit consent to AI processing.
  bool get hasAiConsent => aiConsentedAt != null;

  UserProfile copyWith({
    String? fullName,
    String? email,
    String? phone,
    String? whatsApp,
    String? countryOfResidence,
    String? preferredLanguage,
    String? currentLevel,
    String? targetLevel,
    String? languageLevel,
    List<String>? fieldIds,
    List<String>? targetCountryIds,
    String? gradeRange,
    String? bacSeries,
    int? monthlyBudgetEur,
    bool? wantsScholarshipSupport,
    List<String>? availableDocuments,
    DateTime? consentedAt,
    DateTime? aiConsentedAt,
  }) {
    return UserProfile(
      id: id,
      accountType: accountType,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      whatsApp: whatsApp ?? this.whatsApp,
      countryOfResidence: countryOfResidence ?? this.countryOfResidence,
      preferredLanguage: preferredLanguage ?? this.preferredLanguage,
      currentLevel: currentLevel ?? this.currentLevel,
      targetLevel: targetLevel ?? this.targetLevel,
      languageLevel: languageLevel ?? this.languageLevel,
      fieldIds: fieldIds ?? this.fieldIds,
      targetCountryIds: targetCountryIds ?? this.targetCountryIds,
      gradeRange: gradeRange ?? this.gradeRange,
      bacSeries: bacSeries ?? this.bacSeries,
      monthlyBudgetEur: monthlyBudgetEur ?? this.monthlyBudgetEur,
      wantsScholarshipSupport:
          wantsScholarshipSupport ?? this.wantsScholarshipSupport,
      availableDocuments: availableDocuments ?? this.availableDocuments,
      consentedAt: consentedAt ?? this.consentedAt,
      aiConsentedAt: aiConsentedAt ?? this.aiConsentedAt,
    );
  }

  double get completionScore {
    final items = <bool>[
      fullName.trim().isNotEmpty,
      email.trim().isNotEmpty,
      phone.trim().isNotEmpty,
      countryOfResidence.trim().isNotEmpty,
      preferredLanguage.trim().isNotEmpty,
      (currentLevel ?? '').trim().isNotEmpty,
      (targetLevel ?? '').trim().isNotEmpty,
      (languageLevel ?? '').trim().isNotEmpty,
      fieldIds.isNotEmpty,
      targetCountryIds.isNotEmpty,
      (gradeRange ?? '').trim().isNotEmpty || (bacSeries ?? '').trim().isNotEmpty,
      monthlyBudgetEur != null && monthlyBudgetEur! > 0,
      availableDocuments.isNotEmpty,
    ];
    final completed = items.where((item) => item).length;
    return completed / items.length;
  }
}
