// LIV-T3 / T4 / T5 / TST-T20 : le manifeste iOS dit ce que le binaire fait.
//
// Égalités de LISTES exactes — un « ne contient pas » laisserait passer un
// `fetch` oublié à côté de `remote-notification`.

import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:karatou/app/core/ui/portrait_lock.dart';

List<String> _plistArray(String xml, String key) {
  final match = RegExp(
    '<key>${RegExp.escape(key)}</key>\\s*<array>(.*?)</array>',
    dotAll: true,
  ).firstMatch(xml);
  expect(match, isNotNull, reason: 'Clé absente : $key');
  return RegExp(r'<string>(.*?)</string>')
      .allMatches(match!.group(1)!)
      .map((m) => m.group(1)!)
      .toList();
}

String _plistString(String xml, String key) {
  final match = RegExp(
    '<key>${RegExp.escape(key)}</key>\\s*<string>(.*?)</string>',
    dotAll: true,
  ).firstMatch(xml);
  expect(match, isNotNull, reason: 'Clé absente : $key');
  return match!.group(1)!;
}

void main() {
  final plist = File('ios/Runner/Info.plist').readAsStringSync();
  final pbx = File('ios/Runner.xcodeproj/project.pbxproj').readAsStringSync();

  test('TST-T20 : le binaire se déclare français', () {
    expect(pbx.contains('developmentRegion = fr;'), isTrue);
    expect(
      RegExp(r'knownRegions = \(\s*fr,', dotAll: true).hasMatch(pbx),
      isTrue,
    );
    expect(_plistArray(plist, 'CFBundleLocalizations'), ['fr']);
  });

  test('LIV-T3 : caméra et photothèque couvrent dossier ET photo de profil',
      () {
    final camera = _plistString(plist, 'NSCameraUsageDescription');
    expect(camera.toLowerCase(), contains('dossier'));
    expect(camera.toLowerCase(), contains('photo de profil'));
    final photos = _plistString(plist, 'NSPhotoLibraryUsageDescription');
    expect(photos.toLowerCase(), contains('dossier'));
    expect(photos.toLowerCase(), contains('photo de profil'));
  });

  test('LIV-T4 : UIBackgroundModes == [remote-notification]', () {
    expect(_plistArray(plist, 'UIBackgroundModes'), ['remote-notification']);
  });

  // Les deux rejets App Store de la build 49, encodés. Ils se contredisent en
  // apparence et ne laissent qu'UNE configuration valide :
  //   · 90101 — retirer une famille d'appareils d'une app DÉJÀ publiée est
  //     interdit. La fiche (id 1128659292) est universelle : l'iPad reste.
  //   · 90474 — un bundle qui embarque l'iPad doit déclarer les QUATRE
  //     orientations iPad (multitâche).
  // D'où : famille « 1,2 » + 4 orientations iPad, comme la build 48 acceptée.
  // L'iPhone reste portrait-only, et `lockPortraitOrientation` (testé juste en
  // dessous) garde l'UI en portrait sur les deux familles — les 4 orientations
  // déclarées n'autorisent aucune rotation réelle.
  test(
      'LIV-T5 : iPhone portrait, iPad universel + 4 orientations (90101/90474)',
      () {
    expect(
      _plistArray(plist, 'UISupportedInterfaceOrientations'),
      ['UIInterfaceOrientationPortrait'],
    );
    expect(
      _plistArray(plist, 'UISupportedInterfaceOrientations~ipad'),
      [
        'UIInterfaceOrientationPortrait',
        'UIInterfaceOrientationPortraitUpsideDown',
        'UIInterfaceOrientationLandscapeLeft',
        'UIInterfaceOrientationLandscapeRight',
      ],
      reason: 'Moins de 4 orientations iPad = rejet 90474 à l\'upload.',
    );
    expect(pbx.contains('TARGETED_DEVICE_FAMILY = "1,2";'), isTrue,
        reason: 'Ne pas retirer l\'iPad d\'une app déjà publiée : rejet 90101. '
            'Tenté le 28/08 en iPhone-only, refusé par App Store Connect.');
    expect(pbx.contains('TARGETED_DEVICE_FAMILY = "1";'), isFalse,
        reason: 'iPhone-only = rejet 90101 sur cette app publiée.');
  });

  test('LIV-T5 : SystemChrome portrait avant runApp', () async {
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      calls.add(call);
      return null;
    });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });

    await lockPortraitOrientation();

    final orientation = calls.where(
      (c) => c.method == 'SystemChrome.setPreferredOrientations',
    );
    expect(orientation, isNotEmpty);
    expect(
      orientation.first.arguments,
      ['DeviceOrientation.portraitUp'],
    );
  });
}
