import 'package:flutter_test/flutter_test.dart';
import 'package:karatou/app/core/models/app_models.dart';

void main() {
  group('CommercialLead.fromApi', () {
    test('parses a complete payload', () {
      final lead = CommercialLead.fromApi(<String, dynamic>{
        'id': 'case-1',
        'referenceCode': 'KPB-2026-001',
        'title': 'Inscription ECE Lyon',
        'status': 'submitted',
        'studentName': 'Awa Diallo',
        'studentLevel': 'M1',
        'leadTag': 'qualified',
        'discussionMotive': 'Budget à confirmer',
        'createdAt': '2026-05-20T10:00:00.000Z',
        'updatedAt': '2026-05-21T09:30:00.000Z',
        'unreadMessages': 3,
      });

      expect(lead.id, 'case-1');
      expect(lead.referenceCode, 'KPB-2026-001');
      expect(lead.studentName, 'Awa Diallo');
      expect(lead.studentLevel, 'M1');
      expect(lead.leadTag, 'qualified');
      expect(lead.discussionMotive, 'Budget à confirmer');
      expect(lead.unreadMessages, 3);
    });

    test('tolerates missing optional fields with safe defaults', () {
      final lead = CommercialLead.fromApi(<String, dynamic>{
        'id': 'case-2',
        'title': 'Demande',
        'studentName': 'Sékou',
      });

      expect(lead.id, 'case-2');
      expect(lead.studentLevel, isNull);
      expect(lead.leadTag, isNull);
      expect(lead.discussionMotive, isNull);
      expect(lead.unreadMessages, 0);
      // Falls back to "now" rather than throwing on bad/absent dates.
      expect(lead.createdAt, isA<DateTime>());
    });
  });

  group('CommercialStats.fromApi', () {
    test('parses totals and nullable response time', () {
      final stats = CommercialStats.fromApi(<String, dynamic>{
        'totalLeads': 42,
        'convertedLast30Days': 7,
        'avgFirstResponseMinutes': 18,
      });

      expect(stats.totalLeads, 42);
      expect(stats.convertedLast30Days, 7);
      expect(stats.avgFirstResponseMinutes, 18);
    });

    test('handles a null avgFirstResponseMinutes (no responses yet)', () {
      final stats = CommercialStats.fromApi(<String, dynamic>{
        'totalLeads': 5,
        'convertedLast30Days': 0,
        'avgFirstResponseMinutes': null,
      });

      expect(stats.totalLeads, 5);
      expect(stats.convertedLast30Days, 0);
      expect(stats.avgFirstResponseMinutes, isNull);
    });

    test('empty payload yields zeroed defaults', () {
      final stats = CommercialStats.fromApi(<String, dynamic>{});
      expect(stats.totalLeads, 0);
      expect(stats.convertedLast30Days, 0);
      expect(stats.avgFirstResponseMinutes, isNull);
    });

    test('const empty is the zero state', () {
      expect(CommercialStats.empty.totalLeads, 0);
      expect(CommercialStats.empty.convertedLast30Days, 0);
      expect(CommercialStats.empty.avgFirstResponseMinutes, isNull);
    });
  });
}
