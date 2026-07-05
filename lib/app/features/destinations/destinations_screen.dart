import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/controllers/app_controller.dart';
import '../explore/explore_screen.dart';
import '../shell/kpb_tools_drawer.dart';

/// Onglet Destinations — grille des pays (spec §4.1, M5).
class DestinationsScreen extends StatelessWidget {
  const DestinationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<AppController>();

    return Scaffold(
      appBar: AppBar(
        // Inner Scaffold has no drawer, so surface the shell drawer entry
        // explicitly (the other tabs get it auto-implied by the shell).
        leading: IconButton(
          icon: const Icon(Icons.menu_rounded),
          tooltip: 'tools_drawer_title'.tr,
          onPressed: () => KpbToolsDrawer.open(context),
        ),
        title: Text('nav_destinations'.tr),
      ),
      body: GetBuilder<AppController>(
        builder: (_) => CountriesCatalogGrid(controller: controller),
      ),
    );
  }
}
