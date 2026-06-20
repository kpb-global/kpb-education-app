import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/controllers/app_controller.dart';
import '../../core/navigation/shell_tabs.dart';
import '../../core/ui/app_tokens.dart';
import '../commercial/commercial_conversations_screen.dart';
import '../commercial/commercial_leads_screen.dart';
import '../commercial/commercial_profile_screen.dart';

/// Navigation commerciale — Mes Leads · Conversations · Moi (spec §4.2).
class CommercialShell extends StatelessWidget {
  const CommercialShell({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<AppController>();

    const pages = <Widget>[
      CommercialLeadsScreen(),
      CommercialConversationsScreen(),
      CommercialProfileScreen(),
    ];

    return GetBuilder<AppController>(
      builder: (_) {
        final index = controller.commercialShellIndex
            .clamp(0, CommercialShellTab.count - 1);

        return Scaffold(
          body: Stack(
            children: [
              IndexedStack(index: index, children: pages),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: _CommercialNavBar(
                  currentIndex: index,
                  onTap: controller.goToCommercialTab,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _CommercialNavBar extends StatelessWidget {
  const _CommercialNavBar({
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
                children: [
                  _NavItem(
                    icon: Icons.inbox_outlined,
                    selectedIcon: Icons.inbox_rounded,
                    label: 'nav_commercial_leads'.tr,
                    isSelected: currentIndex == CommercialShellTab.leads,
                    onTap: () => onTap(CommercialShellTab.leads),
                  ),
                  _NavItem(
                    icon: Icons.chat_bubble_outline_rounded,
                    selectedIcon: Icons.chat_bubble_rounded,
                    label: 'nav_commercial_chat'.tr,
                    isSelected: currentIndex == CommercialShellTab.conversations,
                    onTap: () => onTap(CommercialShellTab.conversations),
                  ),
                  _NavItem(
                    icon: Icons.person_outline_rounded,
                    selectedIcon: Icons.person_rounded,
                    label: 'nav_profile'.tr,
                    isSelected: currentIndex == CommercialShellTab.profile,
                    onTap: () => onTap(CommercialShellTab.profile),
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
    final activeColor = isDark ? KpbColors.blue : KpbColors.blue;
    final inactiveColor =
        isDark ? KpbColors.textDarkSecondary : KpbColors.gray400;

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected
                  ? (isDark
                      ? KpbColors.blue.withValues(alpha: 0.15)
                      : KpbColors.skyLight)
                  : Colors.transparent,
              borderRadius: KpbRadius.pillBr,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  isSelected ? selectedIcon : icon,
                  color: isSelected ? activeColor : inactiveColor,
                  size: 22,
                ),
                if (isSelected) ...[
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      label,
                      style: TextStyle(
                        color: activeColor,
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
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
