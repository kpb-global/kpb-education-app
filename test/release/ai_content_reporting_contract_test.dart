import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  String source(String path) => File(path).readAsStringSync();

  test('every launch-visible generative-AI surface exposes in-app reporting',
      () {
    final coach = source('lib/app/features/ai_advisor/ai_chat_screen.dart');
    final orientation =
        source('lib/app/features/orientation/orientation_screen.dart');

    expect(coach, contains('coach_report_ai_output'));
    expect(coach, contains('AiContentSurface.coach'));
    expect(coach, contains('showAiContentReportSheet'));
    expect(orientation, contains('orientation_report_ai_output_'));
    expect(orientation, contains('AiContentSurface.orientation'));
    expect(orientation, contains('showAiContentReportSheet'));
  });

  test('reports use the authenticated, staff-visible case workflow', () {
    final service =
        source('lib/app/core/services/ai_content_report_service.dart');
    final studentController =
        source('backend/src/modules/cases/cases.controller.ts');
    final adminController =
        source('backend/src/modules/cases/admin-cases.controller.ts');

    expect(service, contains("'TRUST_AND_SAFETY_REPORT'"));
    expect(service, contains("'preferredContactMethod': 'in_app'"));
    expect(service, contains('_apiClient.createCase'));
    expect(studentController, contains('@UseGuards(StudentAuthGuard)'));
    expect(studentController, contains('@Post()'));
    expect(adminController, contains("@Controller('admin/cases')"));
    expect(adminController, contains('@UseGuards(AdminAuthGuard'));
  });

  test('user blocking is not claimed when public community is launch-disabled',
      () {
    final config = source('lib/app/core/config/app_config.dart');
    final shell = source('lib/app/features/shell/app_shell.dart');
    final controller =
        source('backend/src/modules/community/community.controller.ts');

    expect(config, contains("'KPB_MVP_ONLY'"));
    expect(config, contains('defaultValue: true'));
    expect(shell, isNot(contains('CommunityScreen(')));
    expect(controller, contains('@UseGuards(MvpGuard)'));
  });
}
