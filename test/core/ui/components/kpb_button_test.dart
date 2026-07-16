// KpbButton (architecture §9.1) : façade sur les boutons Material — variantes
// sémantiques, compat héritée (`secondary:`, couleurs custom), état loading,
// tailles tactiles. Les couleurs viennent du ThemeData, jamais du composant.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:karatou/app/core/ui/app_theme.dart';
import 'package:karatou/app/core/ui/app_tokens.dart';
import 'package:karatou/app/core/ui/components/kpb_button.dart';

Widget _wrap(Widget child) => MaterialApp(
      theme: AppTheme.buildTheme(),
      home: Scaffold(body: Center(child: child)),
    );

Color? _materialColorOf(WidgetTester tester, Finder buttonFinder) {
  final material = tester.widget<Material>(
    find.descendant(of: buttonFinder, matching: find.byType(Material)).first,
  );
  return material.color;
}

void main() {
  testWidgets('primary (défaut) : FilledButton action pleine, ≥ 52 dp',
      (tester) async {
    await tester.pumpWidget(
      _wrap(KpbButton(label: 'Continuer', onTap: () {})),
    );
    final button = find.byType(FilledButton);
    expect(button, findsOneWidget);
    expect(_materialColorOf(tester, button), KpbColors.actionPrimary);
    expect(tester.getSize(button).height, greaterThanOrEqualTo(52));
  });

  testWidgets('variant secondary : OutlinedButton (surface + bordure)',
      (tester) async {
    await tester.pumpWidget(
      _wrap(KpbButton(
        label: 'Annuler',
        variant: KpbButtonVariant.secondary,
        onTap: () {},
      )),
    );
    expect(find.byType(OutlinedButton), findsOneWidget);
  });

  testWidgets('compat héritée : secondary: true → variante secondary',
      (tester) async {
    await tester.pumpWidget(
      _wrap(KpbButton(label: 'Annuler', secondary: true, onTap: () {})),
    );
    expect(find.byType(OutlinedButton), findsOneWidget);
    expect(find.byType(FilledButton), findsNothing);
  });

  testWidgets('tertiary : TextButton avec cible tactile ≥ 48 dp',
      (tester) async {
    await tester.pumpWidget(
      _wrap(KpbButton(
        label: 'Plus tard',
        variant: KpbButtonVariant.tertiary,
        onTap: () {},
      )),
    );
    final button = find.byType(TextButton);
    expect(button, findsOneWidget);
    expect(tester.getSize(button).height, greaterThanOrEqualTo(48));
  });

  testWidgets('destructive : fond error', (tester) async {
    await tester.pumpWidget(
      _wrap(KpbButton(
        label: 'Supprimer',
        variant: KpbButtonVariant.destructive,
        onTap: () {},
      )),
    );
    expect(
      _materialColorOf(tester, find.byType(FilledButton)),
      KpbColors.error,
    );
  });

  testWidgets('loading : spinner visible et action neutralisée',
      (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      _wrap(KpbButton(label: 'Envoi…', loading: true, onTap: () => taps++)),
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
    await tester.tap(find.byType(FilledButton), warnIfMissed: false);
    await tester.pump();
    expect(taps, 0);
  });

  testWidgets('compat héritée : bgColor custom respectée', (tester) async {
    await tester.pumpWidget(
      _wrap(KpbButton(
          label: 'WhatsApp', bgColor: KpbColors.whatsapp, onTap: () {})),
    );
    expect(
      _materialColorOf(tester, find.byType(FilledButton)),
      KpbColors.whatsapp,
    );
  });

  testWidgets(
      'fullWidth remplit la largeur disponible ; sinon épouse le '
      'contenu', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.buildTheme(),
        home: Scaffold(
          body: Column(
            children: [
              KpbButton(label: 'Large', fullWidth: true, onTap: () {}),
              Center(child: KpbButton(label: 'OK', onTap: () {})),
            ],
          ),
        ),
      ),
    );
    final sizes = tester
        .widgetList(find.byType(FilledButton))
        .map((w) => tester.getSize(find.byWidget(w)))
        .toList();
    expect(sizes[0].width, 800); // viewport de test
    expect(sizes[1].width, lessThan(200)); // hug content
  });

  testWidgets('l’icône de tête est rendue', (tester) async {
    await tester.pumpWidget(
      _wrap(KpbButton(label: 'Appeler', icon: Icons.call, onTap: () {})),
    );
    expect(find.byIcon(Icons.call), findsOneWidget);
  });
}
