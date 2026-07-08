part of 'app_models.dart';

/// Two render paths share one model: [ParcoursKind.video] opens the in-app
/// YouTube player; [ParcoursKind.text] opens a written Q&A interview.
enum ParcoursKind { video, text }

/// One question/answer pair of a written interview (kind == text).
class ParcoursQa {
  const ParcoursQa({required this.question, required this.answer});

  final String question;
  final String answer;

  factory ParcoursQa.fromJson(Map<String, dynamic> json) => ParcoursQa(
        question: json['question'] as String? ?? '',
        answer: json['answer'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => {'question': question, 'answer': answer};
}

/// A KPB "Parcours & Témoignages" story — a curated career/education journey.
/// Served by `/content/parcours` in the app-wide localized `{ fr, en }` shape.
class ParcoursStory {
  const ParcoursStory({
    required this.id,
    required this.slug,
    required this.kind,
    this.fieldId,
    this.tags = const [],
    this.personName = '',
    this.role = const LocalizedText(fr: '', en: ''),
    this.title = const LocalizedText(fr: '', en: ''),
    this.hook = const LocalizedText(fr: '', en: ''),
    this.summary = const LocalizedText(fr: '', en: ''),
    this.thumbnailUrl = '',
    this.photoUrl = '',
    this.youtubeId,
    this.durationMinutes,
    this.interviewFr = const [],
    this.interviewEn = const [],
    this.featured = false,
    this.displayOrder = 0,
    this.popularity = 0,
  });

  final String id;
  final String slug;
  final ParcoursKind kind;

  /// Catalog field domain (d01..d12), or null when unmapped.
  final String? fieldId;
  final List<String> tags;
  final String personName;
  final LocalizedText role;
  final LocalizedText title;
  final LocalizedText hook;
  final LocalizedText summary;
  final String thumbnailUrl;
  final String photoUrl;

  // Video-specific.
  final String? youtubeId;
  final int? durationMinutes;

  // Text-specific — FR is authoritative, EN optional.
  final List<ParcoursQa> interviewFr;
  final List<ParcoursQa> interviewEn;

  final bool featured;
  final int displayOrder;
  final int popularity;

  bool get isVideo => kind == ParcoursKind.video;

  /// Effective YouTube thumbnail (falls back to a derived URL for videos).
  String get effectiveThumbnailUrl {
    if (thumbnailUrl.isNotEmpty) return thumbnailUrl;
    if (youtubeId != null && youtubeId!.isNotEmpty) {
      return 'https://img.youtube.com/vi/$youtubeId/hqdefault.jpg';
    }
    return '';
  }

  /// The interview in the requested locale, falling back to FR when EN is
  /// missing (legacy written stories are French-first).
  List<ParcoursQa> interview(String localeCode) {
    if (localeCode.startsWith('fr')) return interviewFr;
    return interviewEn.isNotEmpty ? interviewEn : interviewFr;
  }

  static ParcoursKind _parseKind(Object? raw) =>
      raw == 'text' ? ParcoursKind.text : ParcoursKind.video;

  static LocalizedText _loc(Object? raw) {
    if (raw is Map) {
      return LocalizedText(
        fr: raw['fr'] as String? ?? '',
        en: raw['en'] as String? ?? '',
      );
    }
    return const LocalizedText(fr: '', en: '');
  }

  static List<ParcoursQa> _qaList(Object? raw) {
    if (raw is List) {
      return raw
          .whereType<Map<String, dynamic>>()
          .map(ParcoursQa.fromJson)
          .toList();
    }
    return const [];
  }

  factory ParcoursStory.fromApi(Map<String, dynamic> json) {
    final interview = json['interview'];
    final interviewMap =
        interview is Map<String, dynamic> ? interview : const {};
    return ParcoursStory(
      id: json['id'] as String? ?? json['slug'] as String? ?? '',
      slug: json['slug'] as String? ?? '',
      kind: _parseKind(json['kind']),
      fieldId: json['fieldId'] as String?,
      tags:
          (json['tags'] as List<dynamic>? ?? const []).map((e) => '$e').toList(),
      personName: json['personName'] as String? ?? '',
      role: _loc(json['role']),
      title: _loc(json['title']),
      hook: _loc(json['hook']),
      summary: _loc(json['summary']),
      thumbnailUrl: json['thumbnailUrl'] as String? ?? '',
      photoUrl: json['photoUrl'] as String? ?? '',
      youtubeId: json['youtubeId'] as String?,
      durationMinutes: (json['durationMinutes'] as num?)?.toInt(),
      interviewFr: _qaList(interviewMap['fr']),
      interviewEn: _qaList(interviewMap['en']),
      featured: json['featured'] as bool? ?? false,
      displayOrder: (json['displayOrder'] as num?)?.toInt() ?? 0,
      popularity: (json['popularity'] as num?)?.toInt() ?? 0,
    );
  }

  /// Round-trips through the offline cache (same shape as the API payload).
  Map<String, dynamic> toJson() => {
        'id': id,
        'slug': slug,
        'kind': kind == ParcoursKind.text ? 'text' : 'video',
        'fieldId': fieldId,
        'tags': tags,
        'personName': personName,
        'role': role.toJson(),
        'title': title.toJson(),
        'hook': hook.toJson(),
        'summary': summary.toJson(),
        'thumbnailUrl': thumbnailUrl,
        'photoUrl': photoUrl,
        'youtubeId': youtubeId,
        'durationMinutes': durationMinutes,
        'interview': {
          'fr': interviewFr.map((q) => q.toJson()).toList(),
          'en': interviewEn.map((q) => q.toJson()).toList(),
        },
        'featured': featured,
        'displayOrder': displayOrder,
        'popularity': popularity,
      };
}
