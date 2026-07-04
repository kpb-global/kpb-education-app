import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:karatou/app/core/config/app_config.dart';
import 'package:karatou/app/core/translations/app_translations.dart';
import 'package:karatou/app/core/utils/whatsapp_utils.dart';

void main() {
  group('buildWhatsAppUri', () {
    test('normalizes the phone number into a wa.me link', () {
      final uri = buildWhatsAppUri(phone: '+226 70-12 34 56');
      expect(uri.toString(), 'https://wa.me/22670123456');
    });

    test('URL-encodes the prefill message', () {
      final uri = buildWhatsAppUri(
        phone: '33768674292',
        prefill: 'Bonjour KPB & co ?',
      );
      expect(uri.host, 'wa.me');
      expect(uri.queryParameters['text'], 'Bonjour KPB & co ?');
    });

    test('falls back to the KPB advisor line when no phone is given', () {
      final uri = buildWhatsAppUri();
      final advisor = AppConfig.whatsappNumber
          .trim()
          .replaceAll(RegExp(r'[^\d+]'), '')
          .replaceFirst('+', '');
      expect(uri.toString(), 'https://wa.me/$advisor');
    });

    test('group hand-offs use the shared invite link, even with a phone', () {
      final uri = buildWhatsAppUri(group: true, phone: '22670123456');
      expect(uri.toString(), AppConfig.whatsappGroupInvite);
    });
  });

  group('kpbWhatsAppPrefill', () {
    // `.tr` resolves through a running GetMaterialApp, same harness as
    // translations_parity_test.
    Future<void> pumpI18n(WidgetTester tester,
        {Locale locale = const Locale('fr')}) async {
      await tester.pumpWidget(
        GetMaterialApp(
          translations: AppTranslations(),
          locale: locale,
          fallbackLocale: const Locale('fr'),
          home: const SizedBox.shrink(),
        ),
      );
    }

    tearDown(Get.reset);

    testWidgets('an explicit custom message always wins', (tester) async {
      await pumpI18n(tester);
      expect(
        kpbWhatsAppPrefill(custom: '  Salut !  ', program: 'MSc Data'),
        'Salut !',
      );
    });

    testWidgets('a case reference beats every other context', (tester) async {
      await pumpI18n(tester);
      expect(
        kpbWhatsAppPrefill(
          reference: 'KPB-1042',
          program: 'MSc Data',
          service: 'Visa',
          country: 'France',
        ),
        'Bonjour KPB Education, je reviens vers vous au sujet du dossier '
        'KPB-1042.',
      );
    });

    testWidgets('program mentions the destination when known', (tester) async {
      await pumpI18n(tester);
      expect(
        kpbWhatsAppPrefill(program: 'MSc Data', country: 'France'),
        'Bonjour KPB Education, je suis intéressé(e) par le programme '
        '« MSc Data » (France) et j\'aimerais être accompagné(e).',
      );
      expect(
        kpbWhatsAppPrefill(program: 'MSc Data'),
        'Bonjour KPB Education, je suis intéressé(e) par le programme '
        '« MSc Data » et j\'aimerais être accompagné(e).',
      );
    });

    testWidgets('service and country contexts get their own copy',
        (tester) async {
      await pumpI18n(tester);
      expect(
        kpbWhatsAppPrefill(service: 'Visa'),
        'Bonjour KPB Education, je souhaite en savoir plus sur le service '
        '« Visa ».',
      );
      expect(
        kpbWhatsAppPrefill(country: 'Canada'),
        'Bonjour KPB Education, je souhaite être accompagné(e) pour mes '
        'études — destination : Canada.',
      );
    });

    testWidgets('blank context falls back to the generic request',
        (tester) async {
      await pumpI18n(tester);
      expect(
        kpbWhatsAppPrefill(program: '  ', country: ''),
        'Bonjour KPB Education, j\'aimerais être accompagné(e) dans mon '
        'projet d\'études.',
      );
    });

    testWidgets('EN users write to the advisor in English', (tester) async {
      await pumpI18n(tester, locale: const Locale('en'));
      expect(
        kpbWhatsAppPrefill(),
        'Hello KPB Education, I\'d like some guidance with my study plans.',
      );
      expect(
        kpbWhatsAppPrefill(program: 'MSc Data', country: 'France'),
        'Hello KPB Education, I\'m interested in the "MSc Data" programme '
        '(France) and would like some guidance.',
      );
    });
  });

  // Every WhatsApp hand-off funnels through openWhatsAppOrToast, so a call
  // site that omits `source:`/`contextType:` silently degrades the funnel to
  // 'unknown'. This ratchet keeps attribution complete: it FAILS whenever a
  // NEW call site forgets attribution — pass both parameters, do not exempt.
  group('funnel attribution ratchet', () {
    test('every openWhatsAppOrToast call site passes source and contextType',
        () {
      final offenders = <String>[];
      final callSite = RegExp(r'openWhatsAppOrToast\(');

      for (final entity in Directory('lib/app').listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        // The definition lives here; there are no calls to scan.
        if (entity.path.endsWith('whatsapp_utils.dart')) continue;

        final content = entity.readAsStringSync();
        for (final match in callSite.allMatches(content)) {
          final args = _argumentSpan(content, match.end - 1);
          if (!args.contains('source:') || !args.contains('contextType:')) {
            final line =
                '\n'.allMatches(content.substring(0, match.start)).length + 1;
            offenders.add('${entity.path}:$line');
          }
        }
      }

      expect(
        offenders,
        isEmpty,
        reason: 'openWhatsAppOrToast called without funnel attribution — '
            'pass source: and contextType: at:\n${offenders.join('\n')}',
      );
    });
  });
}

/// Returns the argument list of the call whose opening parenthesis is at
/// [openParen], respecting nested parentheses and string literals (so a
/// `trParams({...})` or a `'…(e)…'` literal inside the arguments cannot
/// unbalance the scan).
String _argumentSpan(String content, int openParen) {
  var depth = 0;
  String? quote;
  for (var i = openParen; i < content.length; i++) {
    final c = content[i];
    if (quote != null) {
      if (c == r'\') {
        i++; // Skip the escaped character.
      } else if (c == quote) {
        quote = null;
      }
      continue;
    }
    if (c == "'" || c == '"') {
      quote = c;
    } else if (c == '(') {
      depth++;
    } else if (c == ')') {
      depth--;
      if (depth == 0) return content.substring(openParen, i);
    }
  }
  return content.substring(openParen);
}
