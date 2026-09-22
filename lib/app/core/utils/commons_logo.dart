/// Affichage des logos Wikimedia : raster + crédit de licence.
///
/// `Image.network` / le codec Flutter ne décodent pas le SVG. Commons sert un
/// PNG miniature pour chaque SVG ; on l'utilise à l'écran, la page fichier
/// reste la source de licence. CC BY / CC BY-SA exigent un crédit ; CC0 et le
/// domaine public, non.
String? commonsRasterDisplayUrl(String? fileUrl, {int width = 320}) {
  final url = fileUrl?.trim() ?? '';
  if (url.isEmpty) return null;
  final cleaned = url.split('?').first;
  if (!cleaned.toLowerCase().endsWith('.svg')) return url;
  final match = RegExp(
    r'^https://upload\.wikimedia\.org/wikipedia/([^/]+)/([0-9a-f])/([0-9a-f]{2})/([^/?#]+)$',
    caseSensitive: false,
  ).firstMatch(cleaned);
  if (match == null) return url;
  final project = match.group(1)!;
  final hash1 = match.group(2)!;
  final hash2 = match.group(3)!;
  final filename = match.group(4)!;
  return 'https://upload.wikimedia.org/wikipedia/$project/thumb/'
      '$hash1/$hash2/$filename/${width}px-$filename.png';
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
