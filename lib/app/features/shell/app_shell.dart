import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../core/controllers/app_controller.dart';
import '../../core/navigation/shell_tabs.dart';
import '../../core/services/connectivity_service.dart';
import '../../core/ui/app_tokens.dart';
import '../../core/ui/components/kpb_offline_banner.dart';
import '../../core/ui/components/kpb_sample_data_banner.dart';
import '../../core/ui/kpb_theme_ext.dart';
import '../cases/cases_screen.dart';
import '../home/home_screen.dart';
import '../profile/profile_screen.dart';
import '../scholarships/live_scholarships_screen.dart';
import '../universities/universities_screen.dart';
import '../ai_advisor/coach_fab.dart';
import 'kpb_tools_drawer.dart';

// ─────────────────────────────────────────────────────────────────────────────
// AppShell — 5-tab navigation. The order mirrors the approved engagement
// design, with Scholarships occupying the high-intent centre slot.
// ─────────────────────────────────────────────────────────────────────────────

class AppShell extends StatelessWidget {
  const AppShell({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<AppController>();

    return GetBuilder<AppController>(
      builder: (_) {
        final index = controller.shellIndex.clamp(0, StudentShellTab.count - 1);
        final fieldFilter = controller.universitiesInitialFieldId;

        final pages = <Widget>[
          const HomeScreen(),
          LiveScholarshipsScreen(apiClient: controller.apiClient),
          UniversitiesScreen(
            key: ValueKey(fieldFilter ?? 'all'),
            initialFieldId: fieldFilter,
          ),
          const CasesScreen(),
          const ProfileScreen(),
        ];

        return Scaffold(
          // Attach the global tools-drawer key so any descendant (including
          // tab screens with their own inner Scaffolds) can call
          // `KpbToolsDrawer.open(context)`.
          key: KpbToolsDrawer.shellKey,
          drawer: const KpbToolsDrawer(),
          // The banners live ABOVE the overlay Stack so they push everything
          // (tab content AND the floating hamburger) down instead of colliding
          // with the top-left drawer button. Both banners collapse to zero
          // height when inactive, so this has no effect in the normal case.
          body: StreamBuilder<bool>(
            stream: ConnectivityService.instance.onConnectivityChanged,
            initialData: ConnectivityService.instance.isOnline,
            builder: (context, snapshot) {
              final online = snapshot.data ?? true;
              // When a banner is visible it already absorbs the status-bar
              // inset (each banner wraps its content in SafeArea), so the
              // subtree below must not re-apply the top padding — otherwise
              // the hamburger would float a full status-bar height too low.
              final bannerVisible = !online || controller.catalogIsSampleData;

              return Column(
                children: [
                  const KpbOfflineBanner(),
                  // Honest signal when we're still on the bundled sample
                  // catalog (backend unreachable/empty, no cache) rather than
                  // real data.
                  if (controller.catalogIsSampleData)
                    const KpbSampleDataBanner(),
                  Expanded(
                    child: MediaQuery.removePadding(
                      context: context,
                      removeTop: bannerVisible,
                      child: Stack(
                        children: [
                          IndexedStack(index: index, children: pages),
                          // Top-left hamburger overlay. Tab screens have their
                          // own Scaffolds without leading icons, so we surface
                          // the drawer entry point from the AppShell level.
                          // Sits clear of the dynamic-island / notch via
                          // SafeArea (a no-op below a visible banner).
                          Positioned(
                            top: 0,
                            left: 0,
                            child: SafeArea(
                              child: Padding(
                                padding: const EdgeInsets.only(
                                    left: KpbSpacing.xs, top: KpbSpacing.xs),
                                child: _KpbDrawerButton(),
                              ),
                            ),
                          ),
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
                    ),
                  ),
                ],
              );
            },
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

    return SafeArea(
      top: false,
      child: Container(
        key: const ValueKey('kpb_shell_nav_bar'),
        height: 62,
        decoration: BoxDecoration(
          color: isDark ? KpbColors.bgDarkCard : Colors.white,
          border: Border(
            top: BorderSide(
              color: isDark ? KpbColors.glassBorder : KpbColors.border,
            ),
          ),
        ),
        child: Row(
          children: [
            _NavItem(
              key: const ValueKey('kpb_nav_home'),
              icon: Icons.home_outlined,
              selectedIcon: Icons.home_rounded,
              label: 'nav_home'.tr,
              isSelected: currentIndex == StudentShellTab.home,
              onTap: () => onTap(StudentShellTab.home),
            ),
            // The source design gives the university search the second slot.
            _NavItem(
              key: const ValueKey('kpb_nav_universities'),
              icon: Icons.school_outlined,
              selectedIcon: Icons.school_rounded,
              label: 'nav_universities'.tr,
              isSelected: currentIndex == StudentShellTab.universities,
              onTap: () => onTap(StudentShellTab.universities),
            ),
            _NavItem(
              key: const ValueKey('kpb_nav_scholarships'),
              icon: Icons.notifications_none_rounded,
              selectedIcon: Icons.notifications_active_rounded,
              label: 'nav_scholarships'.tr,
              isSelected: currentIndex == StudentShellTab.scholarships,
              onTap: () => onTap(StudentShellTab.scholarships),
            ),
            _NavItem(
              key: const ValueKey('kpb_nav_cases'),
              icon: Icons.folder_copy_outlined,
              selectedIcon: Icons.folder_copy_rounded,
              label: 'nav_cases'.tr,
              isSelected: currentIndex == StudentShellTab.cases,
              onTap: () => onTap(StudentShellTab.cases),
              badgeCount: Get.find<AppController>().totalUnreadCaseMessages,
            ),
            _NavItem(
              key: const ValueKey('kpb_nav_profile'),
              icon: Icons.person_outline_rounded,
              selectedIcon: Icons.person_rounded,
              label: 'nav_profile'.tr,
              isSelected: currentIndex == StudentShellTab.profile,
              onTap: () => onTap(StudentShellTab.profile),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    super.key,
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
    const activeColor = KpbColors.actionPrimary;
    const inactiveColor = KpbColors.textMuted;

    return Expanded(
      child: Semantics(
        button: true,
        selected: isSelected,
        label: label,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              if (!isSelected) HapticFeedback.selectionClick();
              onTap();
            },
            child: Padding(
              padding: const EdgeInsets.only(top: 6, bottom: 2),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 52,
                    height: 28,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      curve: Curves.easeOut,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? (isDark
                                ? KpbColors.actionPrimary.withValues(alpha: 0.2)
                                : KpbColors.actionPrimarySoft)
                            : Colors.transparent,
                        borderRadius: KpbRadius.pillBr,
                      ),
                      alignment: Alignment.center,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 180),
                            child: Icon(
                              isSelected ? selectedIcon : icon,
                              key: ValueKey<bool>(isSelected),
                              color: isSelected ? activeColor : inactiveColor,
                              size: 20,
                            ),
                          ),
                          if (badgeCount > 0)
                            Positioned(
                              right: -12,
                              top: -7,
                              child: _NavBadge(count: badgeCount),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 3),
                  // Scale the label down instead of truncating ("Destinatio…")
                  // or wrapping: every tab's label always fits on one line.
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      label,
                      style: TextStyle(
                        color: isSelected ? activeColor : inactiveColor,
                        fontWeight:
                            isSelected ? FontWeight.w800 : FontWeight.w600,
                        fontSize: 9.5,
                        height: 1,
                      ),
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.visible,
                      textAlign: TextAlign.center,
                    ),
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

class _NavBadge extends StatelessWidget {
  const _NavBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: KpbColors.error,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        count > 9 ? '9+' : '$count',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 8,
          height: 1.1,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

/// Small floating menu (hamburger) button that opens the KPB tools drawer.
/// Lives in the AppShell stack so it surfaces regardless of which tab is
/// currently rendered (each tab has its own Scaffold without a leading icon).
class _KpbDrawerButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          color: context.kpb.cardBg.withValues(alpha: 0.85),
          shape: BoxShape.circle,
          boxShadow: KpbShadow.soft,
        ),
        child: IconButton(
          icon: Icon(Icons.menu_rounded, color: context.kpb.textPrimary),
          tooltip: 'tools_drawer_title'.tr,
          onPressed: () => KpbToolsDrawer.open(context),
        ),
      ),
    );
  }
}
