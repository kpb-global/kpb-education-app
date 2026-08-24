// Garde PRIV-T4 : les destinataires et permissions que le code utilise
// doivent être NOMMÉS dans la politique in-app et sur la page web.
//
// Dérivé du dépôt suivi par git (patron no_hardcoded_french_test.dart),
// pas d'un souvenir. Deux familles :
//
//   (A) hôtes https:// dans lib/ + backend/src (hors *.spec.*)
//   (B) permissions AndroidManifest + clés NS*UsageDescription d'Info.plist
//
// Chaque processeur de (A) et chaque jeton de (B) doit apparaître dans
// legal_pages.dart ET confidentialite.html. Un hôte tiers qui n'est ni
// first-party, ni processeur mappé, ni contenu/catalogue connu, fait
// échouer avec « hôte tiers non mappé » — c'est la mutation n°2.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

final _hostPattern = RegExp(r'https?://([A-Za-z0-9.-]+)');

const _firstPartySuffixes = <String>[
  'kpbeducation.cloud',
  'kpbeducation.com',
  'vps-planethoster.com',
  'localhost',
  'localhost.',
  '127.0.0.1',
  'example.org',
  'example.test',
  'student.example',
  'invalid.test',
];

/// Hôte → jeton qui doit figurer dans les deux politiques.
const _processorSuffixToToken = <String, String>{
  'groq.com': 'Groq',
  'onesignal.com': 'OneSignal',
  'posthog.com': 'PostHog',
  'supabase.co': 'Supabase',
  'resend.com': 'Resend',
  'firebaseio.com': 'Firebase',
  'paydunya.com': 'PayDunya',
  'cinetpay.com': 'CinetPay',
  // YouTube a longtemps vécu dans la liste des NON-processeurs, et c'est
  // précisément ce classement qui a autorisé l'omission du lecteur embarqué
  // dans les deux politiques : le lecteur (youtube-nocookie.com) et les
  // vignettes (img.youtube.com, rendues dès l'accueil, connexion ou pas)
  // envoient l'adresse IP et le user-agent de l'étudiant à Google à chaque
  // affichage. Un destinataire de données techniques est un destinataire :
  // il se nomme.
  'youtube.com': 'YouTube',
  'youtu.be': 'YouTube',
};

/// Sites que le code cite sans leur envoyer les données personnelles de
/// l'étudiant (catalogue, scrapers, WebView, stores, médias).
const _nonProcessorSuffixes = <String>[
  'googleapis.com',
  'unsplash.com',
  'wa.me',
  'whatsapp.com',
  'kayak.fr',
  'kayak.com',
  'studapart.com',
  'apple.com',
  'play.google.com',
  'google.com',
  'ashesi.edu.gh',
  'stanford.edu',
  'mccallmacbainscholars.org',
  'stipendiumhungaricum.hu',
  'uwc.org',
  'univ-poitiers.fr',
  'education-in-russia.com',
  'state.gov',
  'sjtu.edu.cn',
  'europa.eu',
  'ethz.ch',
  'fulbrightonline.org',
  'utoronto.ca',
  'yorku.ca',
  'greatyop.com',
  'alueducation.com',
  'blogspot.com',
  'mastercardfdn.org',
  'yok.gov.tr',
  'dfat.gov.au',
  'globaluni.ru',
  'gov.kz',
  'campusfrance.org',
  'studyinromania.gov.ro',
  'si.se',
  'daad.de',
  'studyin.kz',
  'studyinazerbaijan.edu.az',
  'turkiyeburslari.gov.tr',
  'worldbank.org',
  'u.ae',
  'uct.ac.za',
  'amci.ma',
  'aucegypt.edu',
  'auf.org',
  'campuschina.org',
  'chevening.org',
  'funding-guide.de',
  'educanada.ca',
  'gov.uk',
  'icdf.org.tw',
  'mastere.tn',
  'mes.tn',
  'mesrs.dz',
  'mfa.gov.bn',
  'ote.nat.tn',
  'qu.edu.qa',
  'rhodeshouse.ox.ac.uk',
  'schwarzmanscholars.org',
  'studyinjapan.go.jp',
  'studyinspain.info',
  'up.ac.za',
];

const _permissionToToken = <String, String>{
  'android.permission.INTERNET': 'HTTPS',
  'android.permission.ACCESS_NETWORK_STATE': 'HTTPS',
  'android.permission.POST_NOTIFICATIONS': 'notifications',
  'android.permission.USE_BIOMETRIC': 'biométrie',
  'android.permission.RECORD_AUDIO': 'micro',
  'NSFaceIDUsageDescription': 'biométrie',
  'NSCameraUsageDescription': 'caméra',
  'NSPhotoLibraryUsageDescription': 'photo',
  'NSMicrophoneUsageDescription': 'micro',
  // « micro » ne suffit pas pour celle-ci : la permission couvre la
  // reconnaissance VOCALE, et une politique qui parle du micro sans dire que
  // la voix peut être reconnue (et par qui) ne dit pas ce que l'OS demande.
  'NSSpeechRecognitionUsageDescription': 'reconnaissance',
  'NSLocationWhenInUseUsageDescription': 'localisation',
};

String _legalPages() =>
    File('lib/app/features/legal/legal_pages.dart').readAsStringSync();

String _confidentialite() =>
    File('web/public/confidentialite.html').readAsStringSync();

String _translations() =>
    File('lib/app/core/translations/app_translations.dart').readAsStringSync();

bool _matchesSuffix(String host, String suffix) {
  return host == suffix || host.endsWith('.$suffix');
}

String? _processorToken(String host) {
  for (final entry in _processorSuffixToToken.entries) {
    if (_matchesSuffix(host, entry.key)) return entry.value;
  }
  return null;
}

bool _isFirstParty(String host) =>
    _firstPartySuffixes.any((s) => _matchesSuffix(host, s));

bool _isNonProcessor(String host) =>
    _nonProcessorSuffixes.any((s) => _matchesSuffix(host, s));

Iterable<File> _codeFiles() sync* {
  for (final root in ['lib', 'backend/src']) {
    yield* Directory(root)
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) {
      final path = f.path;
      if (path.endsWith('.spec.ts') ||
          path.endsWith('.spec.dart') ||
          path.endsWith('_test.dart')) {
        return false;
      }
      return path.endsWith('.dart') ||
          path.endsWith('.ts') ||
          path.endsWith('.js');
    });
  }
}

Map<String, String> _hostsByFile() {
  final found = <String, String>{};
  for (final file in _codeFiles()) {
    final text = file.readAsStringSync();
    for (final match in _hostPattern.allMatches(text)) {
      final host = match.group(1)!.toLowerCase();
      found.putIfAbsent(host, () => file.path);
    }
  }
  return found;
}

void main() {
  test('chaque hôte processeur est nommé dans legal_pages ET confidentialite',
      () {
    final hosts = _hostsByFile();
    expect(hosts.length, greaterThan(20),
        reason: 'L\'extraction ne lit plus les sources : garde morte.');

    final unmapped = <String>[];
    final missing = <String>[];
    final inApp = '${_legalPages()}\n${_translations()}';
    final web = _confidentialite();

    hosts.forEach((host, file) {
      if (_isFirstParty(host) || _isNonProcessor(host)) return;
      final token = _processorToken(host);
      if (token == null) {
        unmapped.add('$host  (dans $file)');
        return;
      }
      final inLegal = inApp.contains(token);
      final inWeb = web.toLowerCase().contains(token.toLowerCase());
      if (!inLegal) {
        missing
            .add('$token — absent de legal_pages.dart / app_translations.dart '
                '(hôte $host)');
      }
      if (!inWeb) {
        missing.add('$token — absent de confidentialite.html (hôte $host)');
      }
    });

    expect(
      unmapped,
      isEmpty,
      reason: 'Hôte tiers non mappé — ajoute-le comme processeur (et nomme-le '
          'dans les deux politiques) ou comme contenu/catalogue :\n'
          '${unmapped.join('\n')}',
    );
    expect(
      missing,
      isEmpty,
      reason: 'Divulgation manquante :\n${missing.join('\n')}',
    );
  });

  test('chaque permission OS est nommée dans legal_pages ET confidentialite',
      () {
    // Le manifeste est lu SANS SES COMMENTAIRES. Un commentaire n'est pas une
    // permission déclarée, et depuis que le manifeste documente pourquoi il
    // LAISSE `android.permission.ACCESS_ADSERVICES_ATTRIBUTION` au fusionneur,
    // le scan brut prenait cette explication pour une demande de permission et
    // exigeait qu'elle soit divulguée dans les politiques. C'est le symétrique
    // exact du défaut corrigé dans test/release/android_manifest_test.dart, où
    // la garde se déclenchait sur `QUERY_ALL_PACKAGES` écrit dans son propre
    // commentaire d'interdiction. Une garde qui lit les commentaires mesure la
    // prose, pas la configuration.
    final manifest = File('android/app/src/main/AndroidManifest.xml')
        .readAsStringSync()
        .replaceAll(RegExp(r'<!--.*?-->', dotAll: true), '');
    final plist = File('ios/Runner/Info.plist').readAsStringSync();
    final inApp = '${_legalPages()}\n${_translations()}';
    final web = _confidentialite();

    final permissions = <String>[
      ...RegExp(r'android.permission.[A-Z_]+')
          .allMatches(manifest)
          .map((m) => m.group(0)!),
      ...RegExp(r'<key>(NS\w+UsageDescription)</key>')
          .allMatches(plist)
          .map((m) => m.group(1)!),
    ];
    expect(permissions, isNotEmpty,
        reason: 'Aucune permission extraite — garde morte.');

    final missing = <String>[];
    for (final perm in permissions.toSet()) {
      final token = _permissionToToken[perm];
      if (token == null) {
        missing.add('$perm — permission non mappée');
        continue;
      }
      if (!inApp.contains(token)) {
        missing.add('$token — absent de legal_pages.dart (permission $perm)');
      }
      if (!web.contains(token)) {
        missing
            .add('$token — absent de confidentialite.html (permission $perm)');
      }
    }
    expect(missing, isEmpty, reason: missing.join('\n'));
  });

  test('plus de www.kpbeducation.com ni de conservation « 3 ans »', () {
    final corpus =
        '${_legalPages()}\n${_confidentialite()}\n${_translations()}';
    expect(corpus.contains('www.kpbeducation.com'), isFalse);
    expect(corpus.contains('3 ans après la clôture'), isFalse);
  });
}
