const countryFlagById = <String, String>{
  'usa': '🇺🇸',
  'canada': '🇨🇦',
  'can': '🇨🇦',
  'france': '🇫🇷',
  'fra': '🇫🇷',
  'uk': '🇬🇧',
  'gbr': '🇬🇧',
  'morocco': '🇲🇦',
  'mar': '🇲🇦',
  'turkey': '🇹🇷',
  'tur': '🇹🇷',
  'germany': '🇩🇪',
  'deu': '🇩🇪',
  'spain': '🇪🇸',
  'esp': '🇪🇸',
  'are': '🇦🇪',
  'uae': '🇦🇪',
  'china': '🇨🇳',
  'chn': '🇨🇳',
  'belgium': '🇧🇪',
  'bel': '🇧🇪',
  'italy': '🇮🇹',
  'ita': '🇮🇹',
  'portugal': '🇵🇹',
  'prt': '🇵🇹',
};

const _legacyCountryIdAliases = <String, String>{
  'france': 'fra',
  'canada': 'can',
  'uk': 'gbr',
  'united kingdom': 'gbr',
  'germany': 'deu',
  'spain': 'esp',
  'morocco': 'mar',
  'turkey': 'tur',
  'uae': 'are',
  'united arab emirates': 'are',
  'united states': 'usa',
  'china': 'chn',
};

/// Destination countries available at launch (ISO-3 ids, matching the backend
/// `m5-countries` seed). Used to filter the offline mock catalog and any remote
/// payload down to the launch scope.
const kMvpCountryIds = <String>{
  'fra',
  'deu',
  'usa',
  'can',
  'mar',
  'tur',
  'are',
  'gbr',
  'esp',
  'chn',
};

String normalizeCountryId(String id) =>
    _legacyCountryIdAliases[id.trim().toLowerCase()] ?? id.trim().toLowerCase();

/// True when [id] (full-word or ISO-3) resolves to one of the nine MVP
/// destination countries.
bool isMvpCountryId(String id) =>
    kMvpCountryIds.contains(normalizeCountryId(id));

String countryFlag(String id, {String fallbackEmoji = '🌍'}) =>
    countryFlagById[id] ??
    countryFlagById[normalizeCountryId(id)] ??
    fallbackEmoji;

String displayCountryFlag({required String id, String flagEmoji = ''}) =>
    flagEmoji.isNotEmpty ? flagEmoji : countryFlag(id);
