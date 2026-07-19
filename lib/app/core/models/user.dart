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
    this.annualTuitionBudgetEur,
    this.monthlyBudgetEur,
    this.preferredCurrency = 'XOF',
    this.wantsScholarshipSupport = false,
    this.wantsScholarshipNewsletter = false,
    this.availableDocuments = const [],
    this.consentedAt,
    this.aiConsentedAt,
    this.birthDate,
    this.guardianName,
    this.guardianContact,
    this.guardianConsentedAt,
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

  /// Annual tuition budget, stored in EUR for matching and filtering.
  final int? annualTuitionBudgetEur;

  /// Legacy living-budget value retained only to read older snapshots/APIs.
  final int? monthlyBudgetEur;
  final String preferredCurrency;
  final bool wantsScholarshipSupport;

  /// Opt-in to the scholarship newsletter (Mautic). Unchecked by default —
  /// GDPR requires an explicit, freely given consent. The backend stamps the
  /// consent timestamp; the app only carries the desired boolean.
  final bool wantsScholarshipNewsletter;
  final List<String> availableDocuments;
  final DateTime? consentedAt;

  /// Timestamp of explicit consent to third-party AI (Groq) processing. Null
  /// until the user opts into the AI coach. Distinct from [consentedAt].
  final DateTime? aiConsentedAt;

  /// Whether the user has granted explicit consent to AI processing.
  bool get hasAiConsent => aiConsentedAt != null;

  /// Declared birth date (onboarding age gate). Null until provided.
  final DateTime? birthDate;

  /// Self-attested guardian details + consent for users who declared an age
  /// under 18. [guardianConsentedAt] gates data sync and AI processing.
  final String? guardianName;
  final String? guardianContact;
  final DateTime? guardianConsentedAt;

  /// Age in whole years from [birthDate], or null if no birth date is set.
  int? get age {
    final b = birthDate;
    if (b == null) return null;
    final now = DateTime.now();
    var years = now.year - b.year;
    if (now.month < b.month || (now.month == b.month && now.day < b.day)) {
      years--;
    }
    return years;
  }

  /// Whether the user declared an age under 18. False when no birth date is
  /// set (we never assume someone is a minor without a declaration).
  bool get isMinor => (age ?? 99) < 18;

  /// Whether a declared minor has recorded guardian consent.
  bool get hasGuardianConsent => guardianConsentedAt != null;

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
    int? annualTuitionBudgetEur,
    int? monthlyBudgetEur,
    String? preferredCurrency,
    bool? wantsScholarshipSupport,
    bool? wantsScholarshipNewsletter,
    List<String>? availableDocuments,
    DateTime? consentedAt,
    DateTime? aiConsentedAt,
    DateTime? birthDate,
    String? guardianName,
    String? guardianContact,
    DateTime? guardianConsentedAt,
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
      annualTuitionBudgetEur:
          annualTuitionBudgetEur ?? this.annualTuitionBudgetEur,
      monthlyBudgetEur: monthlyBudgetEur ?? this.monthlyBudgetEur,
      preferredCurrency: preferredCurrency ?? this.preferredCurrency,
      wantsScholarshipSupport:
          wantsScholarshipSupport ?? this.wantsScholarshipSupport,
      wantsScholarshipNewsletter:
          wantsScholarshipNewsletter ?? this.wantsScholarshipNewsletter,
      availableDocuments: availableDocuments ?? this.availableDocuments,
      consentedAt: consentedAt ?? this.consentedAt,
      aiConsentedAt: aiConsentedAt ?? this.aiConsentedAt,
      birthDate: birthDate ?? this.birthDate,
      guardianName: guardianName ?? this.guardianName,
      guardianContact: guardianContact ?? this.guardianContact,
      guardianConsentedAt: guardianConsentedAt ?? this.guardianConsentedAt,
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
      (gradeRange ?? '').trim().isNotEmpty ||
          (bacSeries ?? '').trim().isNotEmpty,
      (annualTuitionBudgetEur ?? 0) > 0 || (monthlyBudgetEur ?? 0) > 0,
      availableDocuments.isNotEmpty,
    ];
    final completed = items.where((item) => item).length;
    return completed / items.length;
  }
}
