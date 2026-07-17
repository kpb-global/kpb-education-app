// Audit d'accessibilité du kit (architecture §11.6) : les primitives et les
// composants Material thémés doivent rester sans overflow sur un viewport
// Android compact (360×800) avec le text scale maximal supporté par l'app
// (1.3 — clamp global de main.dart). Un RenderFlex overflow fait échouer le
// test via FlutterError.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:karatou/app/core/ui/app_theme.dart';
import 'package:karatou/app/core/ui/app_tokens.dart';
import 'package:karatou/app/core/ui/components/kpb_button.dart';
import 'package:karatou/app/core/ui/components/kpb_card.dart';
import 'package:karatou/app/core/ui/components/kpb_empty_state.dart';
import 'package:karatou/app/core/ui/components/kpb_error_state.dart';
import 'package:karatou/app/core/ui/components/kpb_sample_data_banner.dart';
import 'package:karatou/app/core/ui/components/kpb_status_chip.dart';
import 'package:karatou/app/core/ui/components/match_badge.dart';
import 'package:karatou/app/core/ui/components/section_header.dart';

Widget _kit() {
  return ListView(
    padding: const EdgeInsets.all(KpbSpacing.md),
    children: [
      const KpbSampleDataBanner(),
      const SizedBox(height: KpbSpacing.sm),
      SectionHeader(
        title: 'Une section au titre volontairement long pour le test',
        actionLabel: 'Tout voir',
        onAction: () {},
        padding: EdgeInsets.zero,
      ),
      const SizedBox(height: KpbSpacing.sm),
      KpbButton(
        label: 'Recevoir le lien de connexion par e-mail',
        fullWidth: true,
        onTap: () {},
      ),
      const SizedBox(height: KpbSpacing.sm),
      KpbButton(
        label: 'Continuer avec Google',
        variant: KpbButtonVariant.secondary,
        fullWidth: true,
        icon: Icons.mail_outline_rounded,
        onTap: () {},
      ),
      const SizedBox(height: KpbSpacing.sm),
      const KpbCard(
        variant: KpbCardVariant.highlighted,
        child: Text(
          'Une carte mise en avant avec un contenu de plusieurs lignes pour '
          'vérifier le comportement du texte agrandi.',
        ),
      ),
      const SizedBox(height: KpbSpacing.sm),
      const Wrap(
        spacing: KpbSpacing.sm,
        runSpacing: KpbSpacing.sm,
        children: [
          KpbStatusChip(status: KpbStatus.warning, label: 'Date limite proche'),
          KpbStatusChip(
              status: KpbStatus.success, label: 'Candidature ouverte'),
          MatchBadge(score: 86),
        ],
      ),
      const SizedBox(height: KpbSpacing.sm),
      const KpbEmptyState(
        icon: Icons.search_off_rounded,
        title: 'Aucun résultat pour cette recherche',
        subtitle: 'Essaie d’élargir tes filtres ou de changer de mots-clés.',
      ),
      const SizedBox(height: KpbSpacing.sm),
      KpbErrorState(onRetry: () {}),
    ],
  );
}

Future<void> _pumpAtScale(WidgetTester tester, double scale) async {
  await tester.binding.setSurfaceSize(const Size(360, 800));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.buildTheme(),
      home: MediaQuery(
        data: MediaQueryData(
          size: const Size(360, 800),
          textScaler: TextScaler.linear(scale),
        ),
        child: Scaffold(body: _kit()),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('kit sans overflow à 360×800, text scale 1.0', (tester) async {
    await _pumpAtScale(tester, 1.0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('kit sans overflow à 360×800, text scale 1.3 (clamp app)',
      (tester) async {
    await _pumpAtScale(tester, 1.3);
    expect(tester.takeException(), isNull);
  });
}
