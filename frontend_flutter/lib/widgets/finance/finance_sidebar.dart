import 'package:flutter/material.dart';

import '../../services/asset_service.dart';
import '../../theme/manager_theme_controller.dart';
import '../../theme/premium_theme.dart';

class FinanceSidebar extends StatelessWidget {
  const FinanceSidebar({
    super.key,
    required this.isCollapsed,
    required this.currentPage,
    required this.onToggle,
    required this.onSelect,
    this.bottomLabel = 'Sign Out',
    this.showAudit = false,
    this.pendingBadge,
    this.managerChrome,
    this.showCollapseToggle = false,
  });

  final bool isCollapsed;
  final String currentPage;
  final VoidCallback onToggle;
  final ValueChanged<String> onSelect;
  final String bottomLabel;
  final bool showAudit;
  final int? pendingBadge;
  final ManagerChromeTheme? managerChrome;
  final bool showCollapseToggle;

  static const double collapsedWidth = 76.0;
  static const double expandedWidth = 220.0;
  static const Color _base = Color(0xFF252525);
  static const Color _accent = Color(0xFFC10D00);

  @override
  Widget build(BuildContext context) {
    final c = managerChrome;
    final effectiveCollapsed = showCollapseToggle ? isCollapsed : false;
    final items = <_FinanceNavItem>[
      const _FinanceNavItem(
        label: 'Dashboard',
        assetPath: 'assets/images/Dahboard.png',
      ),
      _FinanceNavItem(
        label: 'Proposals',
        assetPath: 'assets/images/new icons for manager/proposals.png',
        badge: pendingBadge,
      ),
      const _FinanceNavItem(
        label: 'Client Management',
        assetPath:
            'assets/images/finance_manager_new_icons/client_management_Sidebar.png',
      ),
      if (showAudit)
        const _FinanceNavItem(
          label: 'Audit',
          assetPath:
              'assets/images/finance_manager_new_icons/Audit_sidebar.png',
        ),
      const _FinanceNavItem(
        label: 'Analytics',
        assetPath: 'assets/images/analytics.png',
      ),
    ];

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: effectiveCollapsed ? collapsedWidth : expandedWidth,
      decoration: BoxDecoration(
        color: c?.sidebarBackground ?? _base,
        border: Border(
          right: BorderSide(
            color: c?.sidebarRightBorder ?? PremiumTheme.glassWhiteBorder,
            width: 1,
          ),
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            _buildHeader(effectiveCollapsed, c),
            Expanded(
              child: Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.only(
                        top: effectiveCollapsed ? 8 : 6,
                        left: effectiveCollapsed ? 0 : 4,
                        right: effectiveCollapsed ? 0 : 4,
                      ),
                      child: Column(
                        children: [
                          for (final item in items)
                            _FinanceSidebarNavItem(
                              label: item.label,
                              assetPath: item.assetPath,
                              badge: item.badge,
                              isActive: currentPage == item.label,
                              isCollapsed: effectiveCollapsed,
                              onTap: () => onSelect(item.label),
                              accent: _accent,
                              managerChrome: c,
                            ),
                          SizedBox(height: effectiveCollapsed ? 18 : 40),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: effectiveCollapsed ? 8 : 10),
                  _FinanceSidebarNavItem(
                    label: 'Account Profile',
                    assetPath: 'assets/images/User_Profile.png',
                    badge: null,
                    isActive: currentPage == 'Account Profile',
                    isCollapsed: effectiveCollapsed,
                    onTap: () => onSelect('Account Profile'),
                    accent: _accent,
                    managerChrome: c,
                    isBottomItem: true,
                  ),
                  if (!effectiveCollapsed)
                    const Padding(
                      padding:
                          EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                      child: Divider(
                        height: 1,
                        thickness: 1,
                        color: Color(0xFFFFFFFF),
                      ),
                    ),
                  _FinanceSidebarNavItem(
                    label: bottomLabel,
                    assetPath: 'assets/images/Logout_KhonoBuzz.png',
                    badge: null,
                    isActive: false,
                    isCollapsed: effectiveCollapsed,
                    onTap: () => onSelect(bottomLabel),
                    accent: _accent,
                    managerChrome: c,
                    isBottomItem: true,
                  ),
                  SizedBox(height: effectiveCollapsed ? 8 : 10),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _subtleFill(ManagerChromeTheme? c) {
    if (c == null) return Colors.white.withValues(alpha: 0.14);
    return c.isDark
        ? Colors.white.withValues(alpha: 0.14)
        : Colors.black.withValues(alpha: 0.06);
  }

  Color _iconFg(ManagerChromeTheme? c) =>
      c == null ? Colors.white : c.textPrimary;

  Widget _buildHeader(bool effectiveCollapsed, ManagerChromeTheme? c) {
    if (effectiveCollapsed) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        child: InkWell(
          onTap: showCollapseToggle ? onToggle : null,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            height: 36,
            decoration: BoxDecoration(
              color: _subtleFill(c),
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: showCollapseToggle
                ? Icon(
                    Icons.keyboard_arrow_right,
                    color: _iconFg(c),
                    size: 20,
                  )
                : const SizedBox.shrink(),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
      child: Stack(
        children: [
          if (showCollapseToggle)
            Positioned(
              top: 0,
              right: 0,
              child: InkWell(
                onTap: onToggle,
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: _subtleFill(c),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.keyboard_arrow_left,
                    color: _iconFg(c),
                    size: 18,
                  ),
                ),
              ),
            ),
          Column(
            children: [
              const SizedBox(height: 2),
              Image.asset(
                'assets/images/new icons for manager/khonology_logo.png',
                height: 22,
                fit: BoxFit.contain,
              ),
              const SizedBox(height: 8),
              Text(
                'Welcome to',
                style: TextStyle(
                  color:
                      c?.textSecondary ?? Colors.white.withValues(alpha: 0.7),
                  fontSize: 10.5,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 2),
              Text(
                'Proposal & SOW Builder',
                style: TextStyle(
                  color: _iconFg(c),
                  fontSize: 12.8,
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Container(
                height: 1,
                color: c?.divider ?? Colors.white.withValues(alpha: 0.14),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FinanceNavItem {
  final String label;
  final String assetPath;
  final int? badge;

  const _FinanceNavItem({
    required this.label,
    required this.assetPath,
    this.badge,
  });
}

class _FinanceSidebarNavItem extends StatelessWidget {
  const _FinanceSidebarNavItem({
    required this.label,
    required this.assetPath,
    required this.badge,
    required this.isActive,
    required this.isCollapsed,
    required this.onTap,
    required this.accent,
    this.managerChrome,
    this.isBottomItem = false,
  });

  final String label;
  final String assetPath;
  final int? badge;
  final bool isActive;
  final bool isCollapsed;
  final VoidCallback onTap;
  final Color accent;
  final ManagerChromeTheme? managerChrome;
  final bool isBottomItem;

  Color _idleRail(ManagerChromeTheme? c) => Colors.transparent;

  Color _labelColor(ManagerChromeTheme? c, {required bool onAccent}) {
    if (onAccent) return Colors.white;
    if (c == null) return Colors.white;
    return c.textPrimary;
  }

  Widget _buildNavIcon() {
    final iconSize = isBottomItem ? 31.0 : 34.0;
    return Center(
      child: SizedBox(
        width: iconSize,
        height: iconSize,
        child: AssetService.buildImageWidget(assetPath, fit: BoxFit.contain),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = managerChrome;
    final displayLabel = label == 'Sign Out' ? 'Logout' : label;

    if (isCollapsed) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: isBottomItem ? 4 : 6),
        child: Tooltip(
          message: label,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(30),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: _buildNavIcon(),
                  ),
                  if (badge != null)
                    Positioned(
                      right: -4,
                      top: -4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: isActive
                              ? Colors.white.withValues(alpha: 0.9)
                              : Colors.white.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: isActive
                                ? Colors.white.withValues(alpha: 0.9)
                                : Colors.white.withValues(alpha: 0.14),
                          ),
                        ),
                        child: Text(
                          badge! > 99 ? '99+' : badge.toString(),
                          style: TextStyle(
                            color: isActive ? accent : Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: 10,
        vertical: isBottomItem ? 1 : 2,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Container(
            height: isBottomItem ? 38 : 40,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: isActive ? accent : _idleRail(c),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                _buildNavIcon(),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    displayLabel,
                    style: TextStyle(
                      color: _labelColor(c, onAccent: isActive),
                      fontSize: isBottomItem
                          ? 11.2
                          : (displayLabel == 'Client Management' ? 11.4 : 11.8),
                      fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (badge != null)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: isActive
                          ? Colors.white.withValues(alpha: 0.9)
                          : Colors.white.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: isActive
                            ? Colors.white.withValues(alpha: 0.9)
                            : Colors.white.withValues(alpha: 0.12),
                      ),
                    ),
                    child: Text(
                      badge! > 99 ? '99+' : badge.toString(),
                      style: TextStyle(
                        color: isActive ? accent : Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
