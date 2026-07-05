import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:karatou/app/core/ui/app_theme.dart';
import 'package:karatou/app/core/ui/app_tokens.dart';

/// Guards the chip label contrast fix: Chip only resolves labelStyle.color
/// (never a whole WidgetStateTextStyle), so a wrongly-typed theme value makes
/// every unselected chip label render white-on-grey across the ~13 filter
/// screens (onboarding interests, universités, orientation, search, …).
void main() {
  Color? effectiveLabelColor(WidgetTester tester, String label) {
    final element = tester.element(find.text(label));
    final text = tester.widget<Text>(find.text(label));
    return text.style?.color ?? DefaultTextStyle.of(element).style.color;
  }

  Widget host({required bool selected}) {
    return MaterialApp(
      theme: AppTheme.buildTheme(),
      home: Scaffold(
        body: FilterChip(
          label: Text(selected ? 'Sélectionné' : 'Non sélectionné'),
          selected: selected,
          onSelected: (_) {},
        ),
      ),
    );
  }

  testWidgets('unselected chip label resolves to readable grey',
      (tester) async {
    await tester.pumpWidget(host(selected: false));
    expect(
      effectiveLabelColor(tester, 'Non sélectionné'),
      KpbColors.gray700,
    );
  });

  testWidgets('selected chip label resolves to white', (tester) async {
    await tester.pumpWidget(host(selected: true));
    await tester.pumpAndSettle(); // let the select animation finish
    expect(effectiveLabelColor(tester, 'Sélectionné'), Colors.white);
  });
}
