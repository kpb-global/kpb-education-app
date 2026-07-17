// Galerie de référence du système visuel KPB Intelligence (architecture
// §11.5) : tokens, typographie et primitives sur canvas, capturée en golden.
//
// Génération/comparaison EN LOCAL (macOS) uniquement :
//   flutter test --update-goldens --tags=golden test/goldens
//   flutter test --tags=golden test/goldens
// La CI Linux exclut le tag (rendu de police différent).
@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:karatou/app/core/ui/app_theme.dart';
import 'package:karatou/app/core/ui/app_tokens.dart';
import 'package:karatou/app/core/ui/components/kpb_button.dart';
import 'package:karatou/app/core/ui/components/kpb_card.dart';
import 'package:karatou/app/core/ui/components/kpb_sample_data_banner.dart';
import 'package:karatou/app/core/ui/components/kpb_status_chip.dart';
import 'package:karatou/app/core/ui/components/match_badge.dart';
import 'package:karatou/app/core/ui/components/section_header.dart';

Widget _gallery() {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: AppTheme.buildTheme(),
    home: Scaffold(
      body: ListView(
        padding: const EdgeInsets.all(KpbSpacing.md),
        children: [
          Text('KPB Intelligence', style: KpbTextStyles.display),
          Text('Système visuel — galerie de référence',
              style: KpbTextStyles.bodySm),
          const SizedBox(height: KpbSpacing.md),
          const KpbSampleDataBanner(),
          const SizedBox(height: KpbSpacing.md),
          SectionHeader(
            title: 'Boutons',
            actionLabel: 'Action',
            onAction: () {},
            padding: EdgeInsets.zero,
          ),
          const SizedBox(height: KpbSpacing.sm),
          KpbButton(label: 'Action principale', fullWidth: true, onTap: () {}),
          const SizedBox(height: KpbSpacing.sm),
          KpbButton(
            label: 'Secondaire',
            variant: KpbButtonVariant.secondary,
            fullWidth: true,
            onTap: () {},
          ),
          const SizedBox(height: KpbSpacing.sm),
          Wrap(
            spacing: KpbSpacing.sm,
            runSpacing: KpbSpacing.sm,
            children: [
              KpbButton(
                label: 'Tertiaire',
                variant: KpbButtonVariant.tertiary,
                onTap: () {},
              ),
              KpbButton(
                label: 'Supprimer',
                variant: KpbButtonVariant.destructive,
                onTap: () {},
              ),
              KpbButton(label: 'Envoi…', loading: true, onTap: () {}),
            ],
          ),
          const SizedBox(height: KpbSpacing.lg),
          SectionHeader(title: 'Cartes', padding: EdgeInsets.zero),
          const SizedBox(height: KpbSpacing.sm),
          const KpbCard(child: Text('Carte standard')),
          const SizedBox(height: KpbSpacing.sm),
          const KpbCard(
            variant: KpbCardVariant.highlighted,
            child: Text('Carte mise en avant'),
          ),
          const SizedBox(height: KpbSpacing.lg),
          SectionHeader(title: 'Statuts', padding: EdgeInsets.zero),
          const SizedBox(height: KpbSpacing.sm),
          const Wrap(
            spacing: KpbSpacing.sm,
            runSpacing: KpbSpacing.sm,
            children: [
              KpbStatusChip(status: KpbStatus.success, label: 'Ouverte'),
              KpbStatusChip(status: KpbStatus.warning, label: 'Bientôt close'),
              KpbStatusChip(status: KpbStatus.error, label: 'Fermée'),
              KpbStatusChip(status: KpbStatus.info, label: 'Info'),
              KpbStatusChip(status: KpbStatus.neutral, label: 'Neutre'),
              MatchBadge(score: 86),
              MatchBadge(score: 65),
              MatchBadge(score: 42),
            ],
          ),
          const SizedBox(height: KpbSpacing.lg),
          SectionHeader(title: 'Formulaire', padding: EdgeInsets.zero),
          const SizedBox(height: KpbSpacing.sm),
          const TextField(
            decoration: InputDecoration(labelText: 'Adresse e-mail'),
          ),
          const SizedBox(height: KpbSpacing.md),
          const Wrap(
            spacing: KpbSpacing.sm,
            children: [
              Chip(label: Text('France')),
              Chip(label: Text('Canada')),
            ],
          ),
        ],
      ),
    ),
  );
}

void main() {
  testWidgets('galerie du système visuel — 390×844 @1x', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.binding.setSurfaceSize(null));
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_gallery());
    await tester.pump(const Duration(milliseconds: 400));

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('theme_gallery.png'),
    );
  });
}
