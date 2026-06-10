part of 'app_models.dart';


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
