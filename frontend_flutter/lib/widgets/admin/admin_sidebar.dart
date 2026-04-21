import 'package:flutter/material.dart';

import '../../config/app_constants.dart';
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
      assetPath:
          'assets/images/admin_side bar/Admin_sidebar_content_library.png',
    ),
  ];

  Color _sidebarBg(ManagerChromeTheme? c) => c?.sidebarBackground ?? _adminBase;

  Color _sidebarBorder(ManagerChromeTheme? c) =>
      c?.sidebarRightBorder ?? const Color(0x24FFFFFF);

  Color _subtleFill(ManagerChromeTheme? c) {
    if (c == null) return Colors.white.withOpacity(0.14);
    return c.isDark
        ? Colors.white.withOpacity(0.14)
        : Colors.black.withOpacity(0.06);
  }

  Color _iconFg(ManagerChromeTheme? c) =>
      c == null ? Colors.white : c.textPrimary;

  Color _dividerLine(ManagerChromeTheme? c) =>
      c?.divider ?? Colors.white.withOpacity(0.14);

  Widget _buildHeader(
    bool effectiveCollapsed,
    bool compact,
    bool veryCompact,
    ManagerChromeTheme? c,
  ) {
    if (effectiveCollapsed) {
      return Padding(
        padding: EdgeInsets.symmetric(
          vertical: veryCompact ? 10 : (compact ? 12 : 20),
          horizontal: 10,
        ),
        child: InkWell(
          onTap: onToggle,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            height: 44,
            decoration: BoxDecoration(
              color: _subtleFill(c),
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: Icon(
              Icons.keyboard_arrow_right,
              color: _iconFg(c),
              size: 24,
            ),
          ),
        ),
      );
    }

    if (veryCompact) {
      return Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
        child: Stack(
          children: [
            Positioned(
              top: 0,
              right: 0,
              child: InkWell(
                onTap: onToggle,
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: _subtleFill(c),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.keyboard_arrow_left,
                    color: _iconFg(c),
                    size: 20,
                  ),
                ),
              ),
            ),
            Column(
              children: [
                const SizedBox(height: 2),
                Image.asset(
                  'assets/images/new icons for manager/khonology_logo.png',
                  height: 26,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 8),
                Text(
                  'Welcome to',
                  style: TextStyle(
                    color: c?.textSecondary ?? Colors.white.withOpacity(0.7),
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 2),
                Text(
                  'Proposal & SOW Builder',
                  style: TextStyle(
                    color: _iconFg(c),
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                Container(
                  height: 1,
                  color: _dividerLine(c),
                ),
              ],
            ),
          ],
        ),
      );
    }

    return Container(
      padding:
          EdgeInsets.fromLTRB(16, compact ? 18 : 30, 16, compact ? 12 : 20),
      child: Stack(
        children: [
          Positioned(
            top: 0,
            right: 0,
            child: InkWell(
              onTap: onToggle,
              borderRadius: BorderRadius.circular(10),
              child: Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: _subtleFill(c),
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Icon(
                  Icons.keyboard_arrow_left,
                  color: _iconFg(c),
                  size: 20,
                ),
              ),
            ),
          ),
          Column(
            children: [
              SizedBox(height: compact ? 2 : 4),
              Image.asset(
                'assets/images/new icons for manager/khonology_logo.png',
                height: compact ? 30 : 36,
                fit: BoxFit.contain,
              ),
              SizedBox(height: compact ? 12 : 20),
              Text(
                'Welcome to',
                style: TextStyle(
                  color: c?.textSecondary ?? Colors.white.withOpacity(0.7),
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: compact ? 2 : 4),
              Text(
                'Proposal & SOW Builder',
                style: TextStyle(
                  color: _iconFg(c),
                  fontSize: compact ? 16 : 18,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: compact ? 14 : 22),
              Container(
                height: 1,
                color: _dividerLine(c),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = managerChrome;
    final height = MediaQuery.sizeOf(context).height;
    final compact = height < 820;
    final veryCompact = height < 720;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: isCollapsed ? 80.0 : 250.0,
      decoration: BoxDecoration(
        color: _sidebarBg(c),
        border: Border(
          right: BorderSide(
            color: _sidebarBorder(c),
            width: 1,
          ),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final effectiveCollapsed = constraints.maxWidth < 160;

          return Column(
            children: [
              _buildHeader(effectiveCollapsed, compact, veryCompact, c),
              Expanded(
                child: SingleChildScrollView(
                  physics: height < 640
                      ? const AlwaysScrollableScrollPhysics()
                      : const NeverScrollableScrollPhysics(),
                  child: Column(
                    children: [
                      for (final item in _items)
                        _AdminSidebarNavItem(
                          label: item.displayLabel,
                          assetPath: item.assetPath,
                          isActive: currentPage == item.pageLabel,
                          isCollapsed: effectiveCollapsed,
                          onTap: () => onSelect(item.pageLabel),
                          accent: _adminAccent,
                          managerChrome: c,
                          compact: compact,
                          veryCompact: veryCompact,
                        ),
                      SizedBox(height: veryCompact ? 10 : 20),
                    ],
                  ),
                ),
              ),
              if (!effectiveCollapsed)
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  height: 1,
                  color: _dividerLine(c),
                ),
              SizedBox(height: veryCompact ? 8 : 12),
              _AdminSidebarNavItem(
                label: 'Account Profile',
                assetPath: 'assets/images/User_Profile.png',
                isActive: currentPage == 'Account Profile',
                isCollapsed: effectiveCollapsed,
                onTap: () => onSelect('Account Profile'),
                accent: _adminAccent,
                managerChrome: c,
                compact: compact,
                veryCompact: veryCompact,
              ),
              SizedBox(height: veryCompact ? 2 : 4),
              _AdminSidebarNavItem(
                label: bottomLabel == 'Sign Out' ? 'Logout' : bottomLabel,
                assetPath: 'assets/images/Logout_KhonoBuzz.png',
                isActive: false,
                isCollapsed: effectiveCollapsed,
                onTap: () => onSelect(bottomLabel),
                accent: _adminAccent,
                managerChrome: c,
                compact: compact,
                veryCompact: veryCompact,
              ),
              if (!effectiveCollapsed) ...[
                SizedBox(height: veryCompact ? 4 : 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                    decoration: BoxDecoration(
                      color: _subtleFill(c),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      AppConstants.fullVersion,
                      style: TextStyle(
                        color: _iconFg(c),
                        fontSize: veryCompact ? 9 : 10,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ],
              SizedBox(height: veryCompact ? 12 : 20),
            ],
          );
        },
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
    this.compact = false,
    this.veryCompact = false,
  }) : assert(assetPath != null || iconData != null);

  final String label;
  final String? assetPath;
  final IconData? iconData;
  final bool isActive;
  final bool isCollapsed;
  final VoidCallback onTap;
  final Color accent;
  final ManagerChromeTheme? managerChrome;
  final bool compact;
  final bool veryCompact;
  static const Color _lightTabFill = Color(0x4D838383);
  static const double _iconWidth = 33.988162994384766;
  static const double _iconHeight = 33.998130798339844;

  Color _idleRail(ManagerChromeTheme? c) {
    return Colors.transparent;
  }

  Color _iconWell(ManagerChromeTheme? c) {
    if (c == null) return Colors.white.withOpacity(0.14);
    return c.isDark ? Colors.white.withOpacity(0.14) : c.fieldFill;
  }

  Color _labelColor(ManagerChromeTheme? c, {required bool onAccent}) {
    if (onAccent) return Colors.white;
    if (c == null) return Colors.white;
    return c.textPrimary;
  }

  Widget _buildNavIcon({required bool active}) {
    if (assetPath != null) {
      return Center(
        child: SizedBox(
          width: _iconWidth,
          height: _iconHeight,
          child: AssetService.buildImageWidget(assetPath!, fit: BoxFit.contain),
        ),
      );
    }
    return Center(
      child: SizedBox(
        width: _iconWidth,
        height: _iconHeight,
        child: Icon(
          iconData,
          size: 20,
          color: active
              ? Colors.white
              : (managerChrome?.textPrimary ?? Colors.white),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = managerChrome;
    if (isCollapsed) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: veryCompact ? 4 : 8),
        child: Tooltip(
          message: label,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(10),
              child: Container(
                width: veryCompact ? 48 : (compact ? 52 : 56),
                height: veryCompact ? 48 : (compact ? 52 : 56),
                decoration: BoxDecoration(
                  color: isActive ? accent : _idleRail(c),
                  shape: BoxShape.circle,
                ),
                padding:
                    EdgeInsets.all(veryCompact ? 6 : (compact ? 7 : 8)),
                child: _buildNavIcon(active: isActive),
              ),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: 12,
        vertical: veryCompact ? 3 : (compact ? 4 : 6),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: 14,
              vertical: veryCompact ? 7 : (compact ? 8 : 10),
            ),
            decoration: BoxDecoration(
              color: isActive ? accent : _idleRail(c),
              borderRadius:
                  isActive ? BorderRadius.circular(10) : BorderRadius.zero,
            ),
            child: Row(
              children: [
                Container(
                  width: veryCompact ? 38 : (compact ? 40 : 42),
                  height: veryCompact ? 38 : (compact ? 40 : 42),
                  decoration: BoxDecoration(
                    color: isActive
                        ? Colors.white.withOpacity(0.22)
                        : _iconWell(c),
                    shape: BoxShape.circle,
                  ),
                  padding: const EdgeInsets.all(6),
                  child: _buildNavIcon(active: isActive),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: _labelColor(c, onAccent: isActive),
                      fontSize: veryCompact ? 13 : 14,
                      fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (isActive)
                  const Icon(Icons.arrow_forward_ios,
                      size: 12, color: Colors.white),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
