import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/controllers/app_controller.dart';
import '../../core/ui/app_tokens.dart';
import '../cases/cases_screen.dart';
import '../explore/explore_screen.dart';
import '../home/home_screen.dart';
import '../profile/profile_screen.dart';
import '../scholarships/live_scholarships_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// AppShell — 5-tab navigation (Home · Explorer · Dossiers · Bourses · Moi)
//
// Uses a custom floating, frosted-glass bottom navigation bar for a premium
// UI/UX feel. IndexedStack keeps all pages alive so state is preserved when
// switching tabs.
// ─────────────────────────────────────────────────────────────────────────────

class AppShell extends StatelessWidget {
  const AppShell({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<AppController>();

    const pages = <Widget>[
      HomeScreen(),              // index 0
      ExploreScreen(),           // index 1
      CasesScreen(),             // index 2
      LiveScholarshipsScreen(),  // index 3  ← NEW: live scholarship index
      ProfileScreen(),           // index 4
    ];

    return GetBuilder<AppController>(
      builder: (_) {
        return Scaffold(
          extendBody: true, // Allows content to flow behind the floating nav bar
          body: IndexedStack(
            index: controller.shellIndex,
            children: pages,
          ),
          bottomNavigationBar: _KpbFloatingNavBar(
            currentIndex: controller.shellIndex,
            onTap: controller.goToTab,
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Custom Premium Floating Navigation Bar
// ─────────────────────────────────────────────────────────────────────────────
class _KpbFloatingNavBar extends StatelessWidget {
  const _KpbFloatingNavBar({
    required this.currentIndex,
    required this.onTap,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(
        left: KpbSpacing.pagePad,
        right: KpbSpacing.pagePad,
        bottom: 24,
      ),
      child: SafeArea(
        bottom: true,
        child: ClipRRect(
          borderRadius: KpbRadius.pillBr,
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Container(
              height: 68,
              decoration: BoxDecoration(
                color: isDark
                    ? KpbColors.glassBg
                    : Colors.white.withValues(alpha: 0.85),
                borderRadius: KpbRadius.pillBr,
                border: Border.all(
                  color: isDark
                      ? KpbColors.glassBorder
                      : Colors.white.withValues(alpha: 0.5),
                  width: 1.5,
                ),
                boxShadow: isDark ? null : KpbShadow.float,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _NavItem(
                    icon: Icons.home_outlined,
                    selectedIcon: Icons.home_rounded,
                    label: 'nav_home'.tr,
                    isSelected: currentIndex == 0,
                    onTap: () => onTap(0),
                  ),
                  _NavItem(
                    icon: Icons.explore_outlined,
                    selectedIcon: Icons.explore_rounded,
                    label: 'nav_explore'.tr,
                    isSelected: currentIndex == 1,
                    onTap: () => onTap(1),
                  ),
                  _NavItem(
                    icon: Icons.folder_copy_outlined,
                    selectedIcon: Icons.folder_copy_rounded,
                    label: 'nav_cases'.tr,
                    isSelected: currentIndex == 2,
                    onTap: () => onTap(2),
                  ),
                  _NavItem(
                    icon: Icons.workspace_premium_outlined,
                    selectedIcon: Icons.workspace_premium_rounded,
                    label: 'Bourses',
                    isSelected: currentIndex == 3,
                    onTap: () => onTap(3),
                  ),
                  _NavItem(
                    icon: Icons.person_outline_rounded,
                    selectedIcon: Icons.person_rounded,
                    label: 'nav_profile'.tr,
                    isSelected: currentIndex == 4,
                    onTap: () => onTap(4),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Active colors
    final activeColor = isDark ? KpbColors.stitchCyberCyan : KpbColors.blue;
    final inactiveColor = isDark ? KpbColors.textDarkSecondary : KpbColors.gray400;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutQuint,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark
                  ? KpbColors.stitchCyberCyan.withValues(alpha: 0.15)
                  : KpbColors.skyLight)
              : Colors.transparent,
          borderRadius: KpbRadius.pillBr,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              transitionBuilder: (child, animation) {
                return ScaleTransition(scale: animation, child: child);
              },
              child: Icon(
                isSelected ? selectedIcon : icon,
                key: ValueKey<bool>(isSelected),
                color: isSelected ? activeColor : inactiveColor,
                size: 24,
              ),
            ),
            if (isSelected) ...[
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: activeColor,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
