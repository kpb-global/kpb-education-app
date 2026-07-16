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

    // Single "Pays"/"Countries" screen title (App-engagement handoff): the spec
    // uses one inline heading, not an app-bar "Destinations" title stacked above
    // it — so the heading IS the title (no redundant AppBar chrome).
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: GetBuilder<AppController>(
          builder: (_) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Text(
                  'dest_countries_heading'.tr,
                  style: const TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
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
      ),
    );
  }
}
