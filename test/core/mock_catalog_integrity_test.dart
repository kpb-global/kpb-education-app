import 'package:flutter_test/flutter_test.dart';
import 'package:karatou/app/core/data/mock_catalog.dart';

/// Guards the offline MockCatalog against referential drift — the exact class
/// of bug that left Canada with 20 institutions pointing at programIds that
/// existed nowhere (empty Canada catalog on the simulator / offline).
void main() {
  group('MockCatalog referential integrity', () {
    // NOTE: scoped to Canada. A repo-wide assertion would currently fail —
    // the offline MockCatalog institutions reference ~165 programIds (across
    // ~15 countries) whose program rows were never ported into programs/*.dart
    // (they live only in the backend Prisma seed). That broader gap is tracked
    // separately; here we guard that the Canada port we just added is complete.
    test('every Canadian institution.programIds resolves to a real program',
        () {
      final programIds = MockCatalog.programs.map((p) => p.id).toSet();
      final dangling = <String>[];
      for (final inst
          in MockCatalog.institutions.where((i) => i.countryId == 'canada')) {
        for (final pid in inst.programIds) {
          if (!programIds.contains(pid)) {
            dangling.add('${inst.id} → $pid');
          }
        }
      }
      expect(dangling, isEmpty,
          reason: 'Canadian institutions reference programIds with no matching '
              'program: $dangling');
    });

    test('every program.institutionId resolves to a real institution', () {
      final institutionIds = MockCatalog.institutions.map((i) => i.id).toSet();
      final orphans = MockCatalog.programs
          .where((p) => !institutionIds.contains(p.institutionId))
          .map((p) => '${p.id} → ${p.institutionId}')
          .toList();
      expect(orphans, isEmpty,
          reason: 'Programs reference an unknown institutionId: $orphans');
    });

    test('every program.countryId resolves to a real country', () {
      final countryIds = MockCatalog.countries.map((c) => c.id).toSet();
      final orphans = MockCatalog.programs
          .where((p) => !countryIds.contains(p.countryId))
          .map((p) => '${p.id} → ${p.countryId}')
          .toList();
      expect(orphans, isEmpty,
          reason: 'Programs reference an unknown countryId: $orphans');
    });

    test('Canada now has programs (regression: was empty offline)', () {
      final canadaPrograms =
          MockCatalog.programs.where((p) => p.countryId == 'canada').toList();
      expect(canadaPrograms.length, greaterThanOrEqualTo(20),
          reason: 'Canada should expose its full program set offline');
    });

    test('China is a destination with institutions and resolved programs', () {
      expect(MockCatalog.countries.any((c) => c.id == 'china'), isTrue,
          reason: 'China must exist as a destination country');
      final chinaInst =
          MockCatalog.institutions.where((i) => i.countryId == 'china');
      expect(chinaInst, isNotEmpty);
      final programIds = MockCatalog.programs.map((p) => p.id).toSet();
      final dangling = <String>[];
      for (final inst in chinaInst) {
        for (final pid in inst.programIds) {
          if (!programIds.contains(pid)) dangling.add('${inst.id} → $pid');
        }
      }
      expect(dangling, isEmpty,
          reason: 'Chinese institutions reference missing programs: $dangling');
    });
  });
}
