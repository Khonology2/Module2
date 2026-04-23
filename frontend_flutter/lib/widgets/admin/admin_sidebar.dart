import 'package:flutter/material.dart';

import '../../services/asset_service.dart';
import '../../theme/manager_theme_controller.dart';

class AdminSidebar extends StatelessWidget {
  const AdminSidebar({
    super.key,
    required this.isCollapsed,
    required this.currentPage,
    required this.onToggle,
    required this.onSelect,
    this.bottomLabel = 'Logout',
    /// When set (e.g. admin dashboard + manager theme), sidebar and nav
    /// chrome follow light/dark manager spec instead of legacy fixed dark UI.
    this.managerChrome,
  });

  final bool isCollapsed;
  final String currentPage;
  final VoidCallback onToggle;
  final ValueChanged<String> onSelect;
  final String bottomLabel;
  final ManagerChromeTheme? managerChrome;

  static const double collapsedWidth = 76.0;
  static const double expandedWidth = 220.0;

  // Legacy default when [managerChrome] is null (other admin surfaces).
  static const Color _adminBase = Color(0xFF2A2A2A);
  static const Color _adminAccent = Color(0xFFC10D00);

  static const List<_AdminNavItem> _items = [
    _AdminNavItem(
      pageLabel: 'Dashboard',
      displayLabel: 'Dashboard',
      assetPath: 'assets/images/Dahboard.png',
    ),
    _AdminNavItem(
      pageLabel: 'Approvals',
      displayLabel: 'Approvals',
      assetPath: 'assets/images/admin_side bar/Admin_sidebar_approvals.png',
    ),
    _AdminNavItem(
      pageLabel: 'Analytics',
      displayLabel: 'Analytics',
      assetPath: 'assets/images/analytics.png',
    ),
    _AdminNavItem(
      pageLabel: 'History',
      displayLabel: 'History',
      assetPath: 'assets/images/admin_side bar/Admin_sidebar_History.png',
    ),
    _AdminNavItem(
      pageLabel: 'Content Library',
      displayLabel: 'Content History',
      assetPath: 'assets/images/admin_side bar/Admin_sidebar_content_library.png',
    ),
  ];

  Color _sidebarBg(ManagerChromeTheme? c) =>
      c?.sidebarBackground ?? _adminBase;

  Color _sidebarBorder(ManagerChromeTheme? c) =>
      c?.sidebarRightBorder ?? const Color(0x24FFFFFF);

  Color _iconFg(ManagerChromeTheme? c) =>
      c == null ? Colors.white : c.textPrimary;

  Color _dividerLine(ManagerChromeTheme? c) => const Color(0xFFFFFFFF);

  Widget _buildHeader(bool effectiveCollapsed, ManagerChromeTheme? c) {
    if (effectiveCollapsed) {
      return const SizedBox(height: 12);
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
      child: Column(
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
              color: c?.textSecondary ?? Colors.white.withValues(alpha: 0.7),
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
            color: _dividerLine(c),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = managerChrome;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: isCollapsed ? collapsedWidth : expandedWidth,
      decoration: BoxDecoration(
        color: _sidebarBg(c),
        border: Border(
          right: BorderSide(
            color: _sidebarBorder(c),
            width: 1,
          ),
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            _buildHeader(isCollapsed, c),
            Expanded(
              child: Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.only(
                        top: isCollapsed ? 8 : 6,
                        left: isCollapsed ? 0 : 4,
                        right: isCollapsed ? 0 : 4,
                      ),
                      child: Column(
                        children: [
                          for (final item in _items)
                            _AdminSidebarNavItem(
                              label: item.displayLabel,
                              assetPath: item.assetPath,
                              isActive: currentPage == item.pageLabel,
                              isCollapsed: isCollapsed,
                              onTap: () => onSelect(item.pageLabel),
                              accent: _adminAccent,
                              managerChrome: c,
                            ),
                          SizedBox(height: isCollapsed ? 18 : 40),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: isCollapsed ? 8 : 10),
                  _AdminSidebarNavItem(
                    label: 'Account Profile',
                    assetPath: 'assets/images/User_Profile.png',
                    isActive: currentPage == 'Account Profile',
                    isCollapsed: isCollapsed,
                    onTap: () => onSelect('Account Profile'),
                    accent: _adminAccent,
                    managerChrome: c,
                    isBottomItem: true,
                  ),
                  if (!isCollapsed)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 4),
                      child: Divider(
                        height: 1,
                        thickness: 1,
                        color: _dividerLine(c),
                      ),
                    ),
                  _AdminSidebarNavItem(
                    label: bottomLabel == 'Sign Out' ? 'Logout' : bottomLabel,
                    assetPath: 'assets/images/Logout_KhonoBuzz.png',
                    isActive: false,
                    isCollapsed: isCollapsed,
                    onTap: () => onSelect(bottomLabel),
                    accent: _adminAccent,
                    managerChrome: c,
                    isBottomItem: true,
                  ),
                  SizedBox(height: isCollapsed ? 8 : 10),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AdminNavItem {
  final String pageLabel;
  final String displayLabel;
  final String assetPath;

  const _AdminNavItem({
    required this.pageLabel,
    required this.displayLabel,
    required this.assetPath,
  });
}

class _AdminSidebarNavItem extends StatelessWidget {
  const _AdminSidebarNavItem({
    required this.label,
    required this.isActive,
    required this.isCollapsed,
    required this.onTap,
    required this.accent,
    this.assetPath,
    this.iconData,
    this.managerChrome,
    this.isBottomItem = false,
  }) : assert(assetPath != null || iconData != null);

  final String label;
  final String? assetPath;
  final IconData? iconData;
  final bool isActive;
  final bool isCollapsed;
  final VoidCallback onTap;
  final Color accent;
  final ManagerChromeTheme? managerChrome;
  final bool isBottomItem;

  Color _idleRail(ManagerChromeTheme? c) {
    return Colors.transparent;
  }

  Color _labelColor(ManagerChromeTheme? c, {required bool onAccent}) {
    if (onAccent) return Colors.white;
    if (c == null) return Colors.white;
    return c.textPrimary;
  }

  Widget _buildNavIcon({required bool active}) {
    final iconSize = isBottomItem ? 31.0 : 34.0;
    if (assetPath != null) {
      return Center(
        child: SizedBox(
          width: iconSize,
          height: iconSize,
          child: AssetService.buildImageWidget(assetPath!, fit: BoxFit.contain),
        ),
      );
    }
    return Center(
      child: SizedBox(
        width: iconSize,
        height: iconSize,
        child: Icon(
          iconData,
          size: 20,
          color:
              active ? Colors.white : (managerChrome?.textPrimary ?? Colors.white),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = managerChrome;
    if (isCollapsed) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: isBottomItem ? 4 : 6),
        child: Tooltip(
          message: label,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(10),
              child: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: _buildNavIcon(active: isActive),
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
                _buildNavIcon(active: isActive),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: _labelColor(c, onAccent: isActive),
                      fontSize: isBottomItem ? 11.2 : 11.8,
                      fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
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
