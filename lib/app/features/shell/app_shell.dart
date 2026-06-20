import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../core/controllers/app_controller.dart';
import '../../core/navigation/shell_tabs.dart';
import '../../core/ui/app_tokens.dart';
import '../cases/cases_screen.dart';
import '../destinations/destinations_screen.dart';
import '../home/home_screen.dart';
import '../profile/profile_screen.dart';
import '../universities/universities_screen.dart';
import '../ai_advisor/coach_fab.dart';

// ─────────────────────────────────────────────────────────────────────────────
// AppShell — 5-tab navigation (Accueil · Destinations · Universités · Demandes · Moi)
// ─────────────────────────────────────────────────────────────────────────────

class AppShell extends StatelessWidget {
  const AppShell({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<AppController>();

    return GetBuilder<AppController>(
      builder: (_) {
        final index =
            controller.shellIndex.clamp(0, StudentShellTab.count - 1);
        final fieldFilter = controller.universitiesInitialFieldId;

        final pages = <Widget>[
          const HomeScreen(),
          const DestinationsScreen(),
          UniversitiesScreen(
            key: ValueKey(fieldFilter ?? 'all'),
            initialFieldId: fieldFilter,
          ),
          const CasesScreen(),
          const ProfileScreen(),
        ];

        return Scaffold(
          body: Stack(
            children: [
              IndexedStack(index: index, children: pages),
              if (index != StudentShellTab.home) const CoachFab(),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: _KpbFloatingNavBar(
                  currentIndex: index,
                  onTap: controller.goToTab,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

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
              key: const ValueKey('kpb_shell_nav_bar'),
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
                children: [
                  _NavItem(
                    icon: Icons.home_outlined,
                    selectedIcon: Icons.home_rounded,
                    label: 'nav_home'.tr,
                    isSelected: currentIndex == StudentShellTab.home,
                    onTap: () => onTap(StudentShellTab.home),
                  ),
                  _NavItem(
                    icon: Icons.public_outlined,
                    selectedIcon: Icons.public_rounded,
                    label: 'nav_destinations'.tr,
                    isSelected: currentIndex == StudentShellTab.destinations,
                    onTap: () => onTap(StudentShellTab.destinations),
                  ),
                  _NavItem(
                    icon: Icons.school_outlined,
                    selectedIcon: Icons.school_rounded,
                    label: 'nav_universities'.tr,
                    isSelected: currentIndex == StudentShellTab.universities,
                    onTap: () => onTap(StudentShellTab.universities),
                  ),
                  _NavItem(
                    icon: Icons.folder_copy_outlined,
                    selectedIcon: Icons.folder_copy_rounded,
                    label: 'nav_cases'.tr,
                    isSelected: currentIndex == StudentShellTab.cases,
                    onTap: () => onTap(StudentShellTab.cases),
                    badgeCount: Get.find<AppController>().totalUnreadCaseMessages,
                  ),
                  _NavItem(
                    icon: Icons.person_outline_rounded,
                    selectedIcon: Icons.person_rounded,
                    label: 'nav_profile'.tr,
                    isSelected: currentIndex == StudentShellTab.profile,
                    onTap: () => onTap(StudentShellTab.profile),
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
    this.badgeCount = 0,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final int badgeCount;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeColor = KpbColors.blue;
    final inactiveColor =
        isDark ? KpbColors.textDarkSecondary : KpbColors.gray400;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (!isSelected) HapticFeedback.selectionClick();
          onTap();
        },
        behavior: HitTestBehavior.opaque,
        child: Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutQuint,
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected
                  ? (isDark
                      ? KpbColors.blue.withValues(alpha: 0.15)
                      : KpbColors.skyLight)
                  : Colors.transparent,
              borderRadius: KpbRadius.pillBr,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  clipBehavior: Clip.none,
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
                        size: 22,
                      ),
                    ),
                    if (badgeCount > 0)
                      Positioned(
                        right: -8,
                        top: -4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: KpbColors.error,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            badgeCount > 9 ? '9+' : '$badgeCount',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                if (isSelected) ...[
                  const SizedBox(height: 2),
                  Text(
                    label,
                    style: TextStyle(
                      color: activeColor,
                      fontWeight: FontWeight.w700,
                      fontSize: 9,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
