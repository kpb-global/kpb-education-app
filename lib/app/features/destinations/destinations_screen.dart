import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/controllers/app_controller.dart';
import '../explore/explore_screen.dart';

/// Onglet Destinations — grille des pays (spec §4.1, M5).
class DestinationsScreen extends StatelessWidget {
  const DestinationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<AppController>();

    return Scaffold(
      appBar: AppBar(
        title: Text('nav_destinations'.tr),
      ),
      body: GetBuilder<AppController>(
        builder: (_) => CountriesCatalogGrid(controller: controller),
      ),
    );
  }
}
