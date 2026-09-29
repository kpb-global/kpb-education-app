/// Les largeurs de miniature que Wikimedia accepte de fabriquer. Toute autre est
/// REFUSÉE (HTTP 400) : mesuré le 29/09/2026 sur un même fichier, 20, 40, 60,
/// 120, 250, 330 et 500 px répondent 200, alors que 200, 300, 320, 400 et 640 px
/// répondent 400. Le 320 px demandé jusque-là n'affichait AUCUN logo.
const List<int> kCommonsStandardThumbWidths = <int>[
  20,
  40,
  60,
  120,
  250,
  330,
  500,
  960,
  1280,
  1920,
  3840,
];

/// La plus petite largeur standard qui contient [width] (la plus grande sinon).
int commonsStandardThumbWidth(int width) {
  for (final standard in kCommonsStandardThumbWidths) {
    if (standard >= width) return standard;
  }
  return kCommonsStandardThumbWidths.last;
}

/// Une miniature Commons, lue sur son seul chemin (l'hôte est vérifié avant).
final RegExp _commonsThumbPath = RegExp(
  r'/wikipedia/([^/]+)/thumb/([0-9a-f])/([0-9a-f]{2})/([^/?#]+)/(\d+)px-([^/?#]+)$',
  caseSensitive: false,
);

/// Affichage des logos Wikimedia : raster + crédit de licence.
///
/// `Image.network` / le codec Flutter ne décodent pas le SVG. Commons sert un
/// PNG miniature pour chaque SVG ; on l'utilise à l'écran, la page fichier
/// reste la source de licence. CC BY / CC BY-SA exigent un crédit ; CC0 et le
/// domaine public, non.
///
/// [width] est ramenée à la largeur standard qui la contient : Wikimedia
/// refuse les autres (voir [kCommonsStandardThumbWidths]).
String? commonsRasterDisplayUrl(String? fileUrl, {int width = 330}) {
  final url = fileUrl?.trim() ?? '';
  if (url.isEmpty) return null;
  final cleaned = url.split('?').first;
  // La garde PRIV-T4 lit un hostname après `https://`. Un motif regex
  // `upload\.wikimedia` collé à ce préfixe ferait de `upload` un hôte.
  if (!cleaned.toLowerCase().startsWith('https://upload.wikimedia.org/')) {
    return url;
  }
  // Une miniature DÉJÀ stockée à une largeur que Wikimedia refuse (les lignes
  // importées avec l'ancien 320 px) est ramenée à la largeur standard voisine.
  final thumb = _commonsThumbPath.firstMatch(cleaned);
  if (thumb != null) {
    final stored = int.tryParse(thumb.group(5)!);
    if (stored == null || kCommonsStandardThumbWidths.contains(stored)) {
      return url;
    }
    return 'https://upload.wikimedia.org/wikipedia/${thumb.group(1)}/thumb/'
        '${thumb.group(2)}/${thumb.group(3)}/${thumb.group(4)}/'
        '${commonsStandardThumbWidth(stored)}px-${thumb.group(6)}';
  }
  if (!cleaned.toLowerCase().endsWith('.svg')) return url;
  final match = RegExp(
    r'/wikipedia/([^/]+)/([0-9a-f])/([0-9a-f]{2})/([^/?#]+)$',
    caseSensitive: false,
  ).firstMatch(cleaned);
  if (match == null) return url;
  final project = match.group(1)!;
  final hash1 = match.group(2)!;
  final hash2 = match.group(3)!;
  final filename = match.group(4)!;
  final standardWidth = commonsStandardThumbWidth(width);
  return 'https://upload.wikimedia.org/wikipedia/$project/thumb/'
      '$hash1/$hash2/$filename/${standardWidth}px-$filename.png';
}

bool logoRequiresAttribution(String? licence) {
  final normalized = (licence ?? '').trim().toLowerCase();
  if (normalized.isEmpty) return false;
  if (normalized.contains('public domain') ||
      RegExp(r'\bcc0\b').hasMatch(normalized)) {
    return false;
  }
  if (RegExp(r'\bnc\b').hasMatch(normalized) ||
      normalized.contains('noncommercial') ||
      normalized.contains('non-commercial')) {
    return false;
  }
  return RegExp(r'cc[ -]?by(?:[ -]?sa)?\b').hasMatch(normalized);
}
