import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/controllers/app_controller.dart';
import '../cases/cases_screen.dart';
import '../explore/explore_screen.dart';
import '../home/home_screen.dart';
import '../profile/profile_screen.dart';
import '../saved/saved_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// AppShell — 5-tab navigation (Home · Explorer · Dossiers · Sauvegardés · Moi)
//
// Orientation, Bourses and Communauté are accessible via Get.to() push
// navigation from the Home quick-actions and the "Moi" screen quick-access
// section. IndexedStack keeps all pages alive so state is preserved when
// switching tabs.
// ─────────────────────────────────────────────────────────────────────────────

class AppShell extends StatelessWidget {
  const AppShell({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<AppController>();

    const pages = <Widget>[
      HomeScreen(),   // index 0
      ExploreScreen(), // index 1
      CasesScreen(),  // index 2
      SavedScreen(),  // index 3
      ProfileScreen(), // index 4
    ];

    return GetBuilder<AppController>(
      builder: (_) {
        return Scaffold(
          body: SafeArea(
            child: IndexedStack(
              index: controller.shellIndex,
              children: pages,
            ),
          ),
          bottomNavigationBar: NavigationBar(
            height: 68,
            selectedIndex: controller.shellIndex,
            onDestinationSelected: controller.goToTab,
            animationDuration: const Duration(milliseconds: 300),
            destinations: [
              NavigationDestination(
                icon: const Icon(Icons.home_outlined),
                selectedIcon: const Icon(Icons.home_rounded),
                label: 'nav_home'.tr,
              ),
              NavigationDestination(
                icon: const Icon(Icons.explore_outlined),
                selectedIcon: const Icon(Icons.explore_rounded),
                label: 'nav_explore'.tr,
              ),
              NavigationDestination(
                icon: const Icon(Icons.folder_copy_outlined),
                selectedIcon: const Icon(Icons.folder_copy_rounded),
                label: 'nav_cases'.tr,
              ),
              NavigationDestination(
                icon: const Icon(Icons.bookmark_border_rounded),
                selectedIcon: const Icon(Icons.bookmark_rounded),
                label: 'nav_saved'.tr,
              ),
              NavigationDestination(
                icon: const Icon(Icons.person_outline_rounded),
                selectedIcon: const Icon(Icons.person_rounded),
                label: 'nav_profile'.tr,
              ),
            ],
          ),
        );
      },
    );
  }
}
