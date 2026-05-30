import 'package:flutter/material.dart';

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

enum SavedItemType { field, country, institution, program, scholarship }

enum SearchResultType { field, country, institution, program, scholarship }

class SearchResult {
  const SearchResult({
    required this.type,
    required this.id,
    required this.title,
    required this.subtitle,
  });
  final SearchResultType type;
  final String id;
  final String title;
  final String subtitle;
}

enum CaseType {
  consultation,
  applicationSupport,
  scholarshipSupport,
  housingSupport,
  mentorship,
}

enum CaseStatus {
  draft,
  submitted,
  underReview,
  documentsNeeded,
  counselorAssigned,
  awaitingStudent,
  scheduled,
  inProgress,
  applicationSubmitted,
  waitingDecision,
  awaitingPayment,
  completed,
  rejected,
  cancelled,
}

enum ContactMethod { inApp, whatsapp, phone }

enum EligibilityVerdict { eligible, eligibleWithConditions, notEligible }

EligibilityVerdict eligibilityVerdictFromKey(String key) {
  switch (key) {
    case 'eligible':
      return EligibilityVerdict.eligible;
    case 'not_eligible':
      return EligibilityVerdict.notEligible;
    default:
      return EligibilityVerdict.eligibleWithConditions;
  }
}

class QuizOptionModel {
  const QuizOptionModel({
    required this.value,
    required this.labelFr,
    required this.labelEn,
  });

  final String value;
  final String labelFr;
  final String labelEn;

  String labelFor(String localeCode) =>
      localeCode.startsWith('en') && labelEn.isNotEmpty ? labelEn : labelFr;

  factory QuizOptionModel.fromJson(Map<String, dynamic> json) {
    return QuizOptionModel(
      value: json['value'] as String? ?? '',
      labelFr: json['labelFr'] as String? ?? '',
      labelEn: json['labelEn'] as String? ?? '',
    );
  }
}

class QuizQuestionModel {
  const QuizQuestionModel({
    required this.id,
    required this.textFr,
    required this.textEn,
    required this.options,
  });

  final String id;
  final String textFr;
  final String textEn;
  final List<QuizOptionModel> options;

  String textFor(String localeCode) =>
      localeCode.startsWith('en') && textEn.isNotEmpty ? textEn : textFr;

  factory QuizQuestionModel.fromJson(Map<String, dynamic> json) {
    return QuizQuestionModel(
      id: json['id'] as String? ?? '',
      textFr: json['textFr'] as String? ?? '',
      textEn: json['textEn'] as String? ?? '',
      options: (json['options'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(QuizOptionModel.fromJson)
          .toList(),
    );
  }
}

class QuizVerdictModel {
  const QuizVerdictModel({
    required this.titleFr,
    required this.titleEn,
    required this.messageFr,
    required this.messageEn,
    required this.ctaFr,
    required this.ctaEn,
    this.alternativeCountryIds = const [],
  });

  final String titleFr;
  final String titleEn;
  final String messageFr;
  final String messageEn;
  final String ctaFr;
  final String ctaEn;
  final List<String> alternativeCountryIds;

  String titleFor(String localeCode) =>
      localeCode.startsWith('en') && titleEn.isNotEmpty ? titleEn : titleFr;

  String messageFor(String localeCode) =>
      localeCode.startsWith('en') && messageEn.isNotEmpty ? messageEn : messageFr;

  String ctaFor(String localeCode) =>
      localeCode.startsWith('en') && ctaEn.isNotEmpty ? ctaEn : ctaFr;

  factory QuizVerdictModel.fromJson(Map<String, dynamic> json) {
    return QuizVerdictModel(
      titleFr: json['titleFr'] as String? ?? '',
      titleEn: json['titleEn'] as String? ?? '',
      messageFr: json['messageFr'] as String? ?? '',
      messageEn: json['messageEn'] as String? ?? '',
      ctaFr: json['ctaFr'] as String? ?? '',
      ctaEn: json['ctaEn'] as String? ?? '',
      alternativeCountryIds:
          (json['alternativeCountryIds'] as List<dynamic>?)?.cast<String>() ??
              const [],
    );
  }
}

class CountryEligibilityQuizModel {
  const CountryEligibilityQuizModel({
    required this.questions,
    required this.verdicts,
  });

  final List<QuizQuestionModel> questions;
  final Map<String, QuizVerdictModel> verdicts;

  factory CountryEligibilityQuizModel.fromJson(Map<String, dynamic> json) {
    final rawVerdicts =
        json['verdicts'] as Map<String, dynamic>? ?? <String, dynamic>{};
    return CountryEligibilityQuizModel(
      questions: (json['questions'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(QuizQuestionModel.fromJson)
          .toList(),
      verdicts: rawVerdicts.map(
        (key, value) => MapEntry(
          key,
          QuizVerdictModel.fromJson(value as Map<String, dynamic>),
        ),
      ),
    );
  }
}

class CountryQuizResultModel {
  const CountryQuizResultModel({
    required this.verdict,
    required this.verdictTitle,
    required this.verdictMessage,
    required this.ctaLabel,
    required this.countryId,
    this.alternativeCountryIds = const [],
  });

  final EligibilityVerdict verdict;
  final String verdictTitle;
  final String verdictMessage;
  final String ctaLabel;
  final String countryId;
  final List<String> alternativeCountryIds;

  factory CountryQuizResultModel.fromJson(
    Map<String, dynamic> json, {
    required String localeCode,
  }) {
    final en = localeCode.startsWith('en');
    return CountryQuizResultModel(
      verdict: eligibilityVerdictFromKey(json['verdict'] as String? ?? ''),
      verdictTitle: en
          ? (json['verdictTitleEn'] as String? ??
              json['verdictTitle'] as String? ??
              '')
          : json['verdictTitle'] as String? ?? '',
      verdictMessage: en
          ? (json['verdictMessageEn'] as String? ??
              json['verdictMessage'] as String? ??
              '')
          : json['verdictMessage'] as String? ?? '',
      ctaLabel: en
          ? (json['ctaLabelEn'] as String? ?? json['ctaLabel'] as String? ?? '')
          : json['ctaLabel'] as String? ?? '',
      countryId: json['countryId'] as String? ?? '',
      alternativeCountryIds:
          (json['alternativeCountryIds'] as List<dynamic>?)?.cast<String>() ??
              const [],
    );
  }
}

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

class FieldModel {
  const FieldModel({
    required this.id,
    required this.name,
    required this.description,
    required this.subjects,
    required this.careers,
    required this.dailyLife,
    required this.skills,
    required this.personalityTraits,
    required this.relatedCountryIds,
    required this.relatedScholarshipIds,
    required this.accentColor,
  });

  final String id;
  final LocalizedText name;
  final LocalizedText description;
  final List<LocalizedText> subjects;
  final List<LocalizedText> careers;
  final List<LocalizedText> dailyLife;
  final List<LocalizedText> skills;
  final List<LocalizedText> personalityTraits;
  final List<String> relatedCountryIds;
  final List<String> relatedScholarshipIds;
  final Color accentColor;

  factory FieldModel.fromJson(Map<String, dynamic> json) {
    LocalizedText parseLoc(String key) {
      if (json[key] is Map) {
        return LocalizedText.fromJson(json[key] as Map<String, dynamic>);
      }
      return LocalizedText(
          fr: json['${key}Fr'] as String? ?? '',
          en: json['${key}En'] as String? ?? '');
    }

    List<LocalizedText> parseLocList(String prefix) {
      if (json[prefix] is List) {
        return (json[prefix] as List)
            .map((e) => LocalizedText.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      final frList =
          (json['${prefix}Fr'] as List<dynamic>?)?.cast<String>() ?? [];
      final enList =
          (json['${prefix}En'] as List<dynamic>?)?.cast<String>() ?? [];
      final len = frList.length > enList.length ? frList.length : enList.length;
      return List.generate(
        len,
        (i) => LocalizedText(
            fr: i < frList.length ? frList[i] : '',
            en: i < enList.length ? enList[i] : ''),
      );
    }

    Color parseColor(String? hex) {
      if (hex == null || hex.isEmpty) return const Color(0xFF233F84);
      try {
        return Color(int.parse(hex.replaceFirst('#', '0xff')));
      } catch (e) {
        return const Color(0xFF233F84);
      }
    }

    return FieldModel(
      id: json['id'] as String? ?? '',
      name: parseLoc('name'),
      description: parseLoc('description'),
      subjects: parseLocList('subjects'),
      careers: parseLocList('careers'),
      dailyLife: parseLocList('dailyLife'),
      skills: parseLocList('skills'),
      personalityTraits: parseLocList('personalityTraits'),
      relatedCountryIds:
          (json['relatedCountryIds'] as List<dynamic>?)?.cast<String>() ?? [],
      relatedScholarshipIds:
          (json['relatedScholarshipIds'] as List<dynamic>?)?.cast<String>() ??
              [],
      accentColor: parseColor(json['accentColorHex'] as String?),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name.toJson(),
        'description': description.toJson(),
        'subjects': subjects.map((e) => e.toJson()).toList(),
        'careers': careers.map((e) => e.toJson()).toList(),
        'dailyLife': dailyLife.map((e) => e.toJson()).toList(),
        'skills': skills.map((e) => e.toJson()).toList(),
        'personalityTraits': personalityTraits.map((e) => e.toJson()).toList(),
        'relatedCountryIds': relatedCountryIds,
        'relatedScholarshipIds': relatedScholarshipIds,
        'accentColorHex':
            '#${accentColor.toARGB32().toRadixString(16).substring(2)}',
      };
}

class CountryModel {
  const CountryModel({
    required this.id,
    required this.name,
    required this.whyStudy,
    required this.tuitionRange,
    required this.livingCostRange,
    required this.visaOverview,
    required this.admissionDifficulty,
    required this.popularFieldIds,
    this.code = '',
    this.flagEmoji = '',
    this.tagline = const LocalizedText(fr: '', en: ''),
    this.nextIntakeLabel = const LocalizedText(fr: '', en: ''),
    this.mainLanguage = const LocalizedText(fr: '', en: ''),
    this.marketingDescription = const LocalizedText(fr: '', en: ''),
    this.whyStudyBulletsFr = const [],
    this.whyStudyBulletsEn = const [],
    this.howItWorks = const LocalizedText(fr: '', en: ''),
    this.costsOverview = const LocalizedText(fr: '', en: ''),
    this.languageSection = const LocalizedText(fr: '', en: ''),
    this.partnerSchools = const LocalizedText(fr: '', en: ''),
    this.scholarshipsSection = const LocalizedText(fr: '', en: ''),
    this.whatsAppPrefill = const LocalizedText(fr: '', en: ''),
    this.mvpNote = const LocalizedText(fr: '', en: ''),
    this.displayOrder = 0,
    this.isActive = true,
    this.eligibilityQuiz,
  });

  final String id;
  final String code;
  final String flagEmoji;
  final LocalizedText name;
  final LocalizedText tagline;
  final LocalizedText nextIntakeLabel;
  final LocalizedText mainLanguage;
  final LocalizedText whyStudy;
  final LocalizedText marketingDescription;
  final List<String> whyStudyBulletsFr;
  final List<String> whyStudyBulletsEn;
  final LocalizedText howItWorks;
  final LocalizedText costsOverview;
  final LocalizedText languageSection;
  final LocalizedText partnerSchools;
  final LocalizedText scholarshipsSection;
  final LocalizedText whatsAppPrefill;
  final LocalizedText mvpNote;
  final LocalizedText tuitionRange;
  final LocalizedText livingCostRange;
  final LocalizedText visaOverview;
  final LocalizedText admissionDifficulty;
  final List<String> popularFieldIds;
  final int displayOrder;
  final bool isActive;
  final CountryEligibilityQuizModel? eligibilityQuiz;

  List<String> whyStudyBulletsFor(String localeCode) =>
      localeCode.startsWith('en') && whyStudyBulletsEn.isNotEmpty
          ? whyStudyBulletsEn
          : whyStudyBulletsFr;

  List<String> howItWorksStepsFor(String localeCode) {
    final raw = howItWorks.resolve(localeCode);
    if (raw.isEmpty) return const [];
    return raw
        .split('·')
        .map((step) => step.trim())
        .where((step) => step.isNotEmpty)
        .toList();
  }

  CountryModel copyWith({CountryEligibilityQuizModel? eligibilityQuiz}) {
    return CountryModel(
      id: id,
      code: code,
      flagEmoji: flagEmoji,
      name: name,
      tagline: tagline,
      nextIntakeLabel: nextIntakeLabel,
      mainLanguage: mainLanguage,
      whyStudy: whyStudy,
      marketingDescription: marketingDescription,
      whyStudyBulletsFr: whyStudyBulletsFr,
      whyStudyBulletsEn: whyStudyBulletsEn,
      howItWorks: howItWorks,
      costsOverview: costsOverview,
      languageSection: languageSection,
      partnerSchools: partnerSchools,
      scholarshipsSection: scholarshipsSection,
      whatsAppPrefill: whatsAppPrefill,
      mvpNote: mvpNote,
      tuitionRange: tuitionRange,
      livingCostRange: livingCostRange,
      visaOverview: visaOverview,
      admissionDifficulty: admissionDifficulty,
      popularFieldIds: popularFieldIds,
      displayOrder: displayOrder,
      isActive: isActive,
      eligibilityQuiz: eligibilityQuiz ?? this.eligibilityQuiz,
    );
  }

  factory CountryModel.fromJson(Map<String, dynamic> json) {
    LocalizedText parseLoc(String key) {
      if (json[key] is Map) {
        return LocalizedText.fromJson(json[key] as Map<String, dynamic>);
      }
      return LocalizedText(
          fr: json['${key}Fr'] as String? ?? '',
          en: json['${key}En'] as String? ?? '');
    }

    List<String> parseBulletList(String key) {
      final nested = json[key];
      if (nested is Map) {
        final fr = nested['fr'];
        if (fr is List) return fr.cast<String>();
      }
      final direct = json['${key}Fr'];
      if (direct is List) return direct.cast<String>();
      return const [];
    }

    List<String> parseBulletListEn(String key) {
      final nested = json[key];
      if (nested is Map) {
        final en = nested['en'];
        if (en is List) return en.cast<String>();
      }
      final direct = json['${key}En'];
      if (direct is List) return direct.cast<String>();
      return const [];
    }

    CountryEligibilityQuizModel? quiz;
    final rawQuiz = json['eligibilityQuiz'];
    if (rawQuiz is Map<String, dynamic>) {
      quiz = CountryEligibilityQuizModel.fromJson(rawQuiz);
    }

    return CountryModel(
      id: json['id'] as String? ?? '',
      code: json['code'] as String? ?? '',
      flagEmoji: json['flagEmoji'] as String? ?? '',
      name: parseLoc('name'),
      tagline: parseLoc('tagline'),
      nextIntakeLabel: parseLoc('nextIntakeLabel'),
      mainLanguage: parseLoc('mainLanguage'),
      whyStudy: parseLoc('whyStudy'),
      marketingDescription: parseLoc('marketingDescription'),
      whyStudyBulletsFr: parseBulletList('whyStudyBullets'),
      whyStudyBulletsEn: parseBulletListEn('whyStudyBullets'),
      howItWorks: parseLoc('howItWorks'),
      costsOverview: parseLoc('costsOverview'),
      languageSection: parseLoc('languageSection'),
      partnerSchools: parseLoc('partnerSchools'),
      scholarshipsSection: parseLoc('scholarshipsSection'),
      whatsAppPrefill: parseLoc('whatsAppPrefill'),
      mvpNote: parseLoc('mvpNote'),
      tuitionRange: parseLoc('tuitionRange'),
      livingCostRange: parseLoc('livingCostRange'),
      visaOverview: parseLoc('visaOverview'),
      admissionDifficulty: parseLoc('admissionDifficulty'),
      popularFieldIds:
          (json['popularFieldIds'] as List<dynamic>?)?.cast<String>() ?? [],
      displayOrder: json['displayOrder'] as int? ?? 0,
      isActive: json['isActive'] as bool? ?? true,
      eligibilityQuiz: quiz,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'code': code,
        'flagEmoji': flagEmoji,
        'name': name.toJson(),
        'tagline': tagline.toJson(),
        'nextIntakeLabel': nextIntakeLabel.toJson(),
        'mainLanguage': mainLanguage.toJson(),
        'whyStudy': whyStudy.toJson(),
        'marketingDescription': marketingDescription.toJson(),
        'whyStudyBullets': {
          'fr': whyStudyBulletsFr,
          'en': whyStudyBulletsEn,
        },
        'howItWorks': howItWorks.toJson(),
        'costsOverview': costsOverview.toJson(),
        'languageSection': languageSection.toJson(),
        'partnerSchools': partnerSchools.toJson(),
        'scholarshipsSection': scholarshipsSection.toJson(),
        'whatsAppPrefill': whatsAppPrefill.toJson(),
        'mvpNote': mvpNote.toJson(),
        'tuitionRange': tuitionRange.toJson(),
        'livingCostRange': livingCostRange.toJson(),
        'visaOverview': visaOverview.toJson(),
        'admissionDifficulty': admissionDifficulty.toJson(),
        'popularFieldIds': popularFieldIds,
        'displayOrder': displayOrder,
        'isActive': isActive,
        if (eligibilityQuiz != null)
          'eligibilityQuiz': {
            'questions': eligibilityQuiz!.questions
                .map(
                  (q) => {
                    'id': q.id,
                    'textFr': q.textFr,
                    'textEn': q.textEn,
                    'options': q.options
                        .map(
                          (o) => {
                            'value': o.value,
                            'labelFr': o.labelFr,
                            'labelEn': o.labelEn,
                          },
                        )
                        .toList(),
                  },
                )
                .toList(),
            'verdicts': eligibilityQuiz!.verdicts.map(
              (key, value) => MapEntry(
                key,
                {
                  'titleFr': value.titleFr,
                  'titleEn': value.titleEn,
                  'messageFr': value.messageFr,
                  'messageEn': value.messageEn,
                  'ctaFr': value.ctaFr,
                  'ctaEn': value.ctaEn,
                  'alternativeCountryIds': value.alternativeCountryIds,
                },
              ),
            ),
          },
      };
}

class InstitutionModel {
  const InstitutionModel({
    required this.id,
    required this.name,
    required this.countryId,
    required this.location,
    required this.overview,
    required this.studyLevels,
    required this.tuitionLabel,
    required this.languageRequirements,
    required this.intakePeriods,
    required this.programIds,
    this.isPartner = false,
  });

  final String id;
  final LocalizedText name;
  final String countryId;
  final LocalizedText location;
  final LocalizedText overview;
  final List<String> studyLevels;
  final LocalizedText tuitionLabel;
  final LocalizedText languageRequirements;
  final List<String> intakePeriods;
  final List<String> programIds;
  final bool isPartner;

  factory InstitutionModel.fromJson(Map<String, dynamic> json) {
    LocalizedText parseLoc(String key) {
      if (json[key] is Map) {
        return LocalizedText.fromJson(json[key] as Map<String, dynamic>);
      }
      return LocalizedText(
          fr: json['${key}Fr'] as String? ?? '',
          en: json['${key}En'] as String? ?? '');
    }

    return InstitutionModel(
      id: json['id'] as String? ?? '',
      name: parseLoc('name'),
      countryId: json['countryId'] as String? ?? '',
      location: parseLoc('location'),
      overview: parseLoc('overview'),
      studyLevels:
          (json['studyLevels'] as List<dynamic>?)?.cast<String>() ?? [],
      tuitionLabel: parseLoc('tuitionLabel'),
      languageRequirements: parseLoc('languageRequirements'),
      intakePeriods:
          (json['intakePeriods'] as List<dynamic>?)?.cast<String>() ?? [],
      programIds: (json['programIds'] as List<dynamic>?)?.cast<String>() ?? [],
      isPartner: json['isPartner'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name.toJson(),
        'countryId': countryId,
        'location': location.toJson(),
        'overview': overview.toJson(),
        'studyLevels': studyLevels,
        'tuitionLabel': tuitionLabel.toJson(),
        'languageRequirements': languageRequirements.toJson(),
        'intakePeriods': intakePeriods,
        'programIds': programIds,
        'isPartner': isPartner,
      };
}

class ProgramModel {
  const ProgramModel({
    required this.id,
    required this.institutionId,
    required this.countryId,
    required this.fieldId,
    required this.name,
    required this.level,
    required this.duration,
    required this.tuition,
    required this.language,
    required this.requirements,
  });

  final String id;
  final String institutionId;
  final String countryId;
  final String fieldId;
  final LocalizedText name;
  final LocalizedText level;
  final LocalizedText duration;
  final LocalizedText tuition;
  final LocalizedText language;
  final List<LocalizedText> requirements;

  factory ProgramModel.fromJson(Map<String, dynamic> json) {
    LocalizedText parseLoc(String key) {
      if (json[key] is Map) {
        return LocalizedText.fromJson(json[key] as Map<String, dynamic>);
      }
      return LocalizedText(
          fr: json['${key}Fr'] as String? ?? '',
          en: json['${key}En'] as String? ?? '');
    }

    List<LocalizedText> parseLocList(String prefix) {
      if (json[prefix] is List) {
        return (json[prefix] as List)
            .map((e) => LocalizedText.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      final frList =
          (json['${prefix}Fr'] as List<dynamic>?)?.cast<String>() ?? [];
      final enList =
          (json['${prefix}En'] as List<dynamic>?)?.cast<String>() ?? [];
      final len = frList.length > enList.length ? frList.length : enList.length;
      return List.generate(
        len,
        (i) => LocalizedText(
            fr: i < frList.length ? frList[i] : '',
            en: i < enList.length ? enList[i] : ''),
      );
    }

    return ProgramModel(
      id: json['id'] as String? ?? '',
      institutionId: json['institutionId'] as String? ?? '',
      countryId: json['countryId'] as String? ?? '',
      fieldId: json['fieldId'] as String? ?? '',
      name: parseLoc('name'),
      level: parseLoc('level'),
      duration: parseLoc('duration'),
      tuition: parseLoc('tuition'),
      language: parseLoc('language'),
      requirements: parseLocList('requirements'),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'institutionId': institutionId,
        'countryId': countryId,
        'fieldId': fieldId,
        'name': name.toJson(),
        'level': level.toJson(),
        'duration': duration.toJson(),
        'tuition': tuition.toJson(),
        'language': language.toJson(),
        'requirements': requirements.map((e) => e.toJson()).toList(),
      };
}

class ScholarshipModel {
  const ScholarshipModel({
    required this.id,
    required this.name,
    required this.countryId,
    required this.levelEligible,
    required this.typeOfFunding,
    required this.deadlineLabel,
    required this.keyRequirements,
    required this.relatedFieldIds,
    required this.baseMatch,
    this.academyCourseId,
  });

  final String id;
  final LocalizedText name;
  final String countryId;
  final LocalizedText levelEligible;
  final LocalizedText typeOfFunding;
  final LocalizedText deadlineLabel;
  final List<LocalizedText> keyRequirements;
  final List<String> relatedFieldIds;
  final int baseMatch;
  final String? academyCourseId;

  factory ScholarshipModel.fromJson(Map<String, dynamic> json) {
    LocalizedText parseLoc(String key) {
      if (json[key] is Map) {
        return LocalizedText.fromJson(json[key] as Map<String, dynamic>);
      }
      return LocalizedText(
          fr: json['${key}Fr'] as String? ?? '',
          en: json['${key}En'] as String? ?? '');
    }

    List<LocalizedText> parseLocList(String prefix) {
      if (json[prefix] is List) {
        return (json[prefix] as List)
            .map((e) => LocalizedText.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      final frList =
          (json['${prefix}Fr'] as List<dynamic>?)?.cast<String>() ?? [];
      final enList =
          (json['${prefix}En'] as List<dynamic>?)?.cast<String>() ?? [];
      final len = frList.length > enList.length ? frList.length : enList.length;
      return List.generate(
        len,
        (i) => LocalizedText(
            fr: i < frList.length ? frList[i] : '',
            en: i < enList.length ? enList[i] : ''),
      );
    }

    return ScholarshipModel(
      id: json['id'] as String? ?? '',
      name: parseLoc('name'),
      countryId: json['countryId'] as String? ?? '',
      levelEligible: parseLoc('levelEligible'),
      typeOfFunding: parseLoc('typeOfFunding'),
      deadlineLabel: parseLoc('deadlineLabel'),
      keyRequirements: parseLocList('keyRequirements'),
      relatedFieldIds:
          (json['relatedFieldIds'] as List<dynamic>?)?.cast<String>() ?? [],
      baseMatch: json['baseMatch'] as int? ?? 0,
      academyCourseId: json['academyCourseId'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name.toJson(),
        'countryId': countryId,
        'levelEligible': levelEligible.toJson(),
        'typeOfFunding': typeOfFunding.toJson(),
        'deadlineLabel': deadlineLabel.toJson(),
        'keyRequirements': keyRequirements.map((e) => e.toJson()).toList(),
        'relatedFieldIds': relatedFieldIds,
        'baseMatch': baseMatch,
        'academyCourseId': academyCourseId,
      };
}

/// Scraped scholarship from the live index (GreatYop + Mastere.tn).
/// This is a separate model from [ScholarshipModel] which is the curated,
/// seed-based catalog. Live scholarships come from the /scholarships endpoint.
class LiveScholarshipModel {
  const LiveScholarshipModel({
    required this.id,
    required this.title,
    required this.countryName,
    required this.fundingType,
    required this.description,
    required this.advantages,
    required this.eligibility,
    required this.level,
    required this.deadlineLabel,
    this.deadlineAt,
    required this.applicationUrl,
    this.sourceUrl,
    required this.tags,
    required this.matchScore,
  });

  final String id;
  final String title;
  final String countryName;
  final String fundingType; // 'fully_funded' | 'partially_funded' | 'unknown'
  final String description;
  final List<String> advantages;
  final List<String> eligibility;
  final String level;
  final String deadlineLabel;
  final DateTime? deadlineAt;
  final String applicationUrl;
  final String? sourceUrl;
  final List<String> tags;
  final int matchScore;

  bool get isFullyFunded => fundingType == 'fully_funded';
  bool get isPartiallyFunded => fundingType == 'partially_funded';

  factory LiveScholarshipModel.fromJson(Map<String, dynamic> json) {
    return LiveScholarshipModel(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      countryName: json['countryName'] as String? ?? '',
      fundingType: json['fundingType'] as String? ?? 'unknown',
      description: json['description'] as String? ?? '',
      advantages: (json['advantages'] as List<dynamic>?)?.cast<String>() ?? [],
      eligibility: (json['eligibility'] as List<dynamic>?)?.cast<String>() ?? [],
      level: json['level'] as String? ?? '',
      deadlineLabel: json['deadlineLabel'] as String? ?? '',
      deadlineAt: json['deadlineAt'] != null
          ? DateTime.tryParse(json['deadlineAt'] as String)
          : null,
      applicationUrl: json['applicationUrl'] as String? ?? '',
      sourceUrl: json['sourceUrl'] as String?,
      tags: (json['tags'] as List<dynamic>?)?.cast<String>() ?? [],
      matchScore: json['matchScore'] as int? ?? 0,
    );
  }
}

class AcademyCourseModel {
  const AcademyCourseModel({
    required this.id,
    required this.title,
    required this.description,
    required this.coverImageUrl,
    required this.priceXOF,
    required this.priceEUR,
    required this.lessonCount,
  });

  final String id;
  final LocalizedText title;
  final LocalizedText description;
  final String? coverImageUrl;
  final int priceXOF;
  final double priceEUR;
  final int lessonCount;

  factory AcademyCourseModel.fromJson(Map<String, dynamic> json) {
    LocalizedText parseLoc(String key) {
      if (json[key] is Map) {
        return LocalizedText.fromJson(json[key] as Map<String, dynamic>);
      }
      return LocalizedText(
          fr: json['${key}Fr'] as String? ?? '',
          en: json['${key}En'] as String? ?? '');
    }

    return AcademyCourseModel(
      id: json['id'] as String? ?? '',
      title: parseLoc('title'),
      description: parseLoc('description'),
      coverImageUrl: json['coverImageUrl'] as String?,
      priceXOF: json['priceXOF'] as int? ?? 0,
      priceEUR: (json['priceEUR'] as num?)?.toDouble() ?? 0.0,
      lessonCount: json['lessonCount'] as int? ?? 0,
    );
  }
}

class AcademyLessonModel {
  const AcademyLessonModel({
    required this.id,
    required this.title,
    required this.videoUrl,
    required this.durationSeconds,
    required this.order,
  });

  final String id;
  final LocalizedText title;
  final String videoUrl;
  final int durationSeconds;
  final int order;

  factory AcademyLessonModel.fromJson(Map<String, dynamic> json) {
    LocalizedText parseLoc(String key) {
      if (json[key] is Map) {
        return LocalizedText.fromJson(json[key] as Map<String, dynamic>);
      }
      return LocalizedText(
          fr: json['${key}Fr'] as String? ?? '',
          en: json['${key}En'] as String? ?? '');
    }

    return AcademyLessonModel(
      id: json['id'] as String? ?? '',
      title: parseLoc('title'),
      videoUrl: json['videoUrl'] as String? ?? '',
      durationSeconds: json['durationSeconds'] as int? ?? 0,
      order: json['order'] as int? ?? 0,
    );
  }
}

class ServiceOffer {
  const ServiceOffer({
    required this.id,
    required this.name,
    required this.offerType,
    required this.destinationIds,
    required this.studyLevels,
    required this.priceLabel,
    required this.benefits,
    required this.ctaLabel,
    required this.status,
  });

  final String id;
  final LocalizedText name;
  final String offerType;
  final List<String> destinationIds;
  final List<String> studyLevels;
  final LocalizedText priceLabel;
  final List<LocalizedText> benefits;
  final LocalizedText ctaLabel;
  final PublicationStatus status;
}

class SupportDestination {
  const SupportDestination({
    required this.id,
    required this.countryId,
    required this.supportLanguages,
    required this.availableServiceTypes,
    required this.conditions,
    required this.counselorNames,
    required this.isVisible,
    required this.status,
  });

  final String id;
  final String countryId;
  final List<String> supportLanguages;
  final List<String> availableServiceTypes;
  final List<LocalizedText> conditions;
  final List<String> counselorNames;
  final bool isVisible;
  final PublicationStatus status;
}

class ArticleModel {
  const ArticleModel({
    required this.id,
    required this.slug,
    required this.category,
    required this.title,
    required this.summary,
    required this.content,
    required this.tags,
    required this.authorName,
    required this.status,
    required this.publishedAt,
  });

  final String id;
  final String slug;
  final String category;
  final LocalizedText title;
  final LocalizedText summary;
  final LocalizedText content;
  final List<String> tags;
  final String authorName;
  final PublicationStatus status;
  final DateTime? publishedAt;
}

enum RoadmapStepType { audit, language, writing, review, submission }

class RoadmapStepModel {
  const RoadmapStepModel({
    required this.type,
    required this.title,
    required this.description,
    required this.daysBeforeDeadline,
    this.actionRoute,
  });

  final RoadmapStepType type;
  final LocalizedText title;
  final LocalizedText description;
  final int daysBeforeDeadline;
  final String? actionRoute;
}

class ForumCategoryModel {
  const ForumCategoryModel({
    required this.id,
    required this.label,
    required this.description,
    required this.displayOrder,
    required this.status,
  });

  final String id;
  final LocalizedText label;
  final LocalizedText description;
  final int displayOrder;
  final PublicationStatus status;
}

class ForumTopicTagModel {
  const ForumTopicTagModel({
    required this.id,
    required this.label,
    required this.description,
    required this.displayOrder,
    required this.status,
  });

  final String id;
  final LocalizedText label;
  final LocalizedText description;
  final int displayOrder;
  final PublicationStatus status;
}

class SavedItem {
  const SavedItem({
    required this.type,
    required this.itemId,
  });

  final SavedItemType type;
  final String itemId;
}

class CaseTimelineEvent {
  const CaseTimelineEvent({
    required this.id,
    required this.title,
    required this.description,
    required this.createdAt,
    required this.status,
  });

  final String id;
  final LocalizedText title;
  final LocalizedText description;
  final DateTime createdAt;
  final CaseStatus status;
}

class CaseMessage {
  const CaseMessage({
    required this.id,
    required this.senderName,
    required this.senderRole,
    required this.body,
    required this.createdAt,
  });

  final String id;
  final String senderName;
  final String senderRole;
  final LocalizedText body;
  final DateTime createdAt;
}

class DocumentRequest {
  const DocumentRequest({
    required this.id,
    required this.title,
    required this.isProvided,
  });

  final String id;
  final LocalizedText title;
  final bool isProvided;

  DocumentRequest copyWith({
    bool? isProvided,
  }) {
    return DocumentRequest(
      id: id,
      title: title,
      isProvided: isProvided ?? this.isProvided,
    );
  }
}

class StudentCase {
  const StudentCase({
    required this.id,
    required this.referenceCode,
    required this.type,
    required this.title,
    required this.description,
    required this.contextLabel,
    required this.status,
    required this.preferredContactMethod,
    required this.createdAt,
    required this.updatedAt,
    required this.nextStepTitle,
    required this.nextStepDescription,
    required this.timeline,
    required this.messages,
    required this.documentRequests,
    this.assignedAdvisorName,
    this.advisorPhone,
    this.advisorWhatsapp,
    this.scheduledAt,
  });

  final String id;
  final String referenceCode;
  final CaseType type;
  final LocalizedText title;
  final LocalizedText description;
  final LocalizedText contextLabel;
  final CaseStatus status;
  final ContactMethod preferredContactMethod;
  final DateTime createdAt;
  final DateTime updatedAt;
  final LocalizedText nextStepTitle;
  final LocalizedText nextStepDescription;
  final List<CaseTimelineEvent> timeline;
  final List<CaseMessage> messages;
  final List<DocumentRequest> documentRequests;
  final String? assignedAdvisorName;
  final String? advisorPhone;
  final String? advisorWhatsapp;
  final DateTime? scheduledAt;

  StudentCase copyWith({
    CaseStatus? status,
    DateTime? updatedAt,
    LocalizedText? nextStepTitle,
    LocalizedText? nextStepDescription,
    List<CaseTimelineEvent>? timeline,
    List<CaseMessage>? messages,
    List<DocumentRequest>? documentRequests,
    String? assignedAdvisorName,
    String? advisorPhone,
    String? advisorWhatsapp,
    DateTime? scheduledAt,
  }) {
    return StudentCase(
      id: id,
      referenceCode: referenceCode,
      type: type,
      title: title,
      description: description,
      contextLabel: contextLabel,
      status: status ?? this.status,
      preferredContactMethod: preferredContactMethod,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      nextStepTitle: nextStepTitle ?? this.nextStepTitle,
      nextStepDescription: nextStepDescription ?? this.nextStepDescription,
      timeline: timeline ?? this.timeline,
      messages: messages ?? this.messages,
      documentRequests: documentRequests ?? this.documentRequests,
      assignedAdvisorName: assignedAdvisorName ?? this.assignedAdvisorName,
      advisorPhone: advisorPhone ?? this.advisorPhone,
      advisorWhatsapp: advisorWhatsapp ?? this.advisorWhatsapp,
      scheduledAt: scheduledAt ?? this.scheduledAt,
    );
  }
}

class OrientationOption {
  const OrientationOption({
    required this.id,
    required this.label,
    required this.weights,
  });

  final String id;
  final LocalizedText label;
  final Map<String, int> weights;
}

class OrientationQuestion {
  const OrientationQuestion({
    required this.id,
    required this.prompt,
    required this.options,
    this.multiSelect = false,
  });

  final String id;
  final LocalizedText prompt;
  final List<OrientationOption> options;
  final bool multiSelect;
}

class OrientationRecommendation {
  const OrientationRecommendation({
    required this.fieldId,
    required this.score,
    required this.explanation,
    required this.relatedCountryIds,
    required this.relatedScholarshipIds,
    this.jobs = const [],
    this.iaResilience = 'medium',
  });

  final String fieldId;
  final int score;
  final LocalizedText explanation;
  final List<String> relatedCountryIds;
  final List<String> relatedScholarshipIds;
  final List<String> jobs;
  final String iaResilience;
}

class OrientationSession {
  const OrientationSession({
    required this.id,
    required this.completedAt,
    required this.answers,
    required this.recommendations,
  });

  final String id;
  final DateTime completedAt;
  final Map<String, List<String>> answers;
  final List<OrientationRecommendation> recommendations;
}

class CommercialLead {
  const CommercialLead({
    required this.id,
    required this.referenceCode,
    required this.title,
    required this.status,
    required this.studentName,
    this.studentLevel,
    this.leadTag,
    this.discussionMotive,
    required this.createdAt,
    required this.updatedAt,
    this.unreadMessages = 0,
  });

  final String id;
  final String referenceCode;
  final String title;
  final String status;
  final String studentName;
  final String? studentLevel;
  final String? leadTag;
  final String? discussionMotive;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int unreadMessages;

  factory CommercialLead.fromApi(Map<String, dynamic> json) {
    return CommercialLead(
      id: json['id'] as String? ?? '',
      referenceCode: json['referenceCode'] as String? ?? '',
      title: json['title'] as String? ?? '',
      status: json['status'] as String? ?? '',
      studentName: json['studentName'] as String? ?? '',
      studentLevel: json['studentLevel'] as String?,
      leadTag: json['leadTag'] as String?,
      discussionMotive: json['discussionMotive'] as String?,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
          DateTime.now(),
      unreadMessages: json['unreadMessages'] as int? ?? 0,
    );
  }
}

class CommercialStats {
  const CommercialStats({
    required this.totalLeads,
    required this.convertedLast30Days,
    this.avgFirstResponseMinutes,
  });

  final int totalLeads;
  final int convertedLast30Days;
  final int? avgFirstResponseMinutes;

  factory CommercialStats.fromApi(Map<String, dynamic> json) {
    return CommercialStats(
      totalLeads: json['totalLeads'] as int? ?? 0,
      convertedLast30Days: json['convertedLast30Days'] as int? ?? 0,
      avgFirstResponseMinutes: json['avgFirstResponseMinutes'] as int?,
    );
  }

  static const empty = CommercialStats(
    totalLeads: 0,
    convertedLast30Days: 0,
  );
}

/// A single video from the KPB YouTube playlist (Chantier C — section Parcours).
class YoutubeVideo {
  const YoutubeVideo({
    required this.videoId,
    required this.title,
    this.description = '',
    this.thumbnailUrl = '',
    this.publishedAt,
    this.position = 0,
  });

  final String videoId;
  final String title;
  final String description;
  final String thumbnailUrl;
  final DateTime? publishedAt;
  final int position;

  factory YoutubeVideo.fromApi(Map<String, dynamic> json) {
    return YoutubeVideo(
      videoId: json['videoId'] as String? ?? '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      thumbnailUrl: json['thumbnailUrl'] as String? ?? '',
      publishedAt: DateTime.tryParse(json['publishedAt'] as String? ?? ''),
      position: json['position'] as int? ?? 0,
    );
  }

  /// Round-trips through the offline cache (same shape as the API payload).
  Map<String, dynamic> toJson() => {
        'videoId': videoId,
        'title': title,
        'description': description,
        'thumbnailUrl': thumbnailUrl,
        'publishedAt': publishedAt?.toIso8601String(),
        'position': position,
      };
}
