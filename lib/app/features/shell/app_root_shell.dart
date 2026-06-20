import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/controllers/app_controller.dart';
import 'app_shell.dart';
import 'commercial_shell.dart';

/// Choisit le shell étudiant (5 onglets) ou commercial (3 onglets).
class AppRootShell extends StatelessWidget {
  const AppRootShell({super.key});

  @override
  Widget build(BuildContext context) {
    return GetBuilder<AppController>(
      builder: (controller) {
        if (controller.isCommercial) {
          return const CommercialShell();
        }
        return const AppShell();
      },
    );
  }
}
