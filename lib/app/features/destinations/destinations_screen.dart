import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/controllers/app_controller.dart';
import '../explore/explore_screen.dart';

/// Onglet Destinations — grille des pays (spec §4.1, M5).
class DestinationsScreen extends StatelessWidget {
  const DestinationsScreen({super.key});

  /// Navy heading colour (App-engagement handoff palette).
  static const _navy = Color(0xFF0F172A);

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<AppController>();

    return Scaffold(
      appBar: AppBar(
        title: Text('nav_destinations'.tr),
      ),
      body: GetBuilder<AppController>(
        builder: (_) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: Text(
                'dest_countries_heading'.tr,
                style: const TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                  color: _navy,
                ),
              ),
            ),
            Expanded(
              child: CountriesCatalogGrid(controller: controller),
            ),
          ],
        ),
      ),
    );
  }
}
