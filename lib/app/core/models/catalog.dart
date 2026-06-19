part of 'app_models.dart';


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
    this.eligibility = const [],
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

  /// Who can apply (distinct from [keyRequirements], which are application
  /// steps). Drives the scholarship eligibility self-check. May be empty for
  /// scraped/live entries.
  final List<LocalizedText> eligibility;

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
      eligibility: parseLocList('eligibility'),
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
        'eligibility': eligibility.map((e) => e.toJson()).toList(),
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
