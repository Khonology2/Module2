import 'package:flutter/material.dart';

import '../../config/app_constants.dart';
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
  });

  final bool isCollapsed;
  final String currentPage;
  final VoidCallback onToggle;
  final ValueChanged<String> onSelect;
  final String bottomLabel;
  final bool showAudit;
  final int? pendingBadge;
  final ManagerChromeTheme? managerChrome;

  static const Color _base = Color(0xFF252525);
  static const Color _accent = Color(0xFFC10D00);
  static const double _collapsedWidth = 80.0;
  static const double _expandedWidth = 250.0;

  @override
  Widget build(BuildContext context) {
    final c = managerChrome;
    final height = MediaQuery.sizeOf(context).height;
    final compact = height < 840;
    final veryCompact = height < 720;
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
          assetPath: 'assets/images/finance_manager_new_icons/Audit_sidebar.png',
        ),
      const _FinanceNavItem(
        label: 'Analytics',
        assetPath: 'assets/images/analytics.png',
      ),
    ];

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: isCollapsed ? _collapsedWidth : _expandedWidth,
      decoration: BoxDecoration(
        color: c?.sidebarBackground ?? _base,
        border: Border(
          right: BorderSide(
            color: c?.sidebarRightBorder ?? PremiumTheme.glassWhiteBorder,
            width: 1,
          ),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final effectiveCollapsed = constraints.maxWidth < 160;

          return Column(
            children: [
              _buildHeader(effectiveCollapsed, compact, c),
              Expanded(
                child: SingleChildScrollView(
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
                          compact: compact,
                          veryCompact: veryCompact,
                          managerChrome: c,
                        ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
              if (!effectiveCollapsed)
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  height: 1,
                  color: c?.divider ?? Colors.white.withValues(alpha: 0.14),
                ),
              const SizedBox(height: 12),
              _FinanceSidebarNavItem(
                label: 'Account Profile',
                assetPath: 'assets/images/User_Profile.png',
                badge: null,
                isActive: currentPage == 'Account Profile',
                isCollapsed: effectiveCollapsed,
                onTap: () => onSelect('Account Profile'),
                accent: _accent,
                compact: compact,
                veryCompact: veryCompact,
                managerChrome: c,
              ),
              const SizedBox(height: 4),
              _FinanceSidebarNavItem(
                label: bottomLabel,
                assetPath: 'assets/images/Logout_KhonoBuzz.png',
                badge: null,
                isActive: false,
                isCollapsed: effectiveCollapsed,
                onTap: () => onSelect(bottomLabel),
                accent: _accent,
                compact: compact,
                veryCompact: veryCompact,
                managerChrome: c,
              ),
              if (!effectiveCollapsed) ...[
                const SizedBox(height: 8),
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
                        color: c?.textPrimary ?? Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 20),
            ],
          );
        },
      ),
    );
  }

  Color _subtleFill(ManagerChromeTheme? c) {
    if (c == null) return Colors.white.withValues(alpha: 0.14);
    return c.isDark
        ? Colors.white.withValues(alpha: 0.14)
        : Colors.black.withValues(alpha: 0.06);
  }

  Color _iconFg(ManagerChromeTheme? c) => c == null ? Colors.white : c.textPrimary;

  Widget _buildHeader(
    bool effectiveCollapsed,
    bool compact,
    ManagerChromeTheme? c,
  ) {
    if (effectiveCollapsed) {
      return Padding(
        padding: EdgeInsets.symmetric(
          vertical: compact ? 16 : 20,
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
                  color: c?.textSecondary ?? Colors.white.withValues(alpha: 0.7),
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
    required this.compact,
    required this.veryCompact,
    this.managerChrome,
  });

  final String label;
  final String assetPath;
  final int? badge;
  final bool isActive;
  final bool isCollapsed;
  final VoidCallback onTap;
  final Color accent;
  final bool compact;
  final bool veryCompact;
  final ManagerChromeTheme? managerChrome;
  static const double _iconWidth = 33.988162994384766;
  static const double _iconHeight = 33.998130798339844;

  Color _idleRail(ManagerChromeTheme? c) => Colors.transparent;

  Color _iconWell(ManagerChromeTheme? c) {
    if (c == null) return Colors.white.withValues(alpha: 0.14);
    return c.isDark ? Colors.white.withValues(alpha: 0.14) : c.fieldFill;
  }

  Color _labelColor(ManagerChromeTheme? c, {required bool onAccent}) {
    if (onAccent) return Colors.white;
    if (c == null) return Colors.white;
    return c.textPrimary;
  }

  Widget _buildNavIcon() {
    return Center(
      child: SizedBox(
        width: _iconWidth,
        height: _iconHeight,
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
        padding: EdgeInsets.symmetric(
          vertical: veryCompact ? 2 : (compact ? 3 : 5),
        ),
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
                    width: veryCompact ? 48 : (compact ? 52 : 56),
                    height: veryCompact ? 48 : (compact ? 52 : 56),
                    decoration: BoxDecoration(
                      color: isActive ? accent : _idleRail(c),
                      shape: BoxShape.circle,
                    ),
                    padding: EdgeInsets.all(veryCompact ? 6 : (compact ? 7 : 8)),
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
        horizontal: 14,
        vertical: veryCompact ? 1 : (compact ? 2 : 4),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: 14,
              vertical: veryCompact ? 7 : (compact ? 9 : 12),
            ),
            decoration: BoxDecoration(
              color: isActive ? accent : _idleRail(c),
              borderRadius: isActive ? BorderRadius.circular(10) : BorderRadius.zero,
            ),
            child: Row(
              children: [
                Container(
                  width: veryCompact ? 40 : (compact ? 44 : 50),
                  height: veryCompact ? 40 : (compact ? 44 : 50),
                  decoration: BoxDecoration(
                    color: isActive ? Colors.white.withValues(alpha: 0.22) : _iconWell(c),
                    shape: BoxShape.circle,
                  ),
                  padding: EdgeInsets.all(veryCompact ? 7 : (compact ? 8 : 9)),
                  child: _buildNavIcon(),
                ),
                SizedBox(width: veryCompact ? 10 : (compact ? 12 : 14)),
                Expanded(
                  child: Text(
                    displayLabel,
                    style: TextStyle(
                      color: _labelColor(c, onAccent: isActive),
                      fontSize: veryCompact
                          ? 13
                          : (compact
                              ? (displayLabel == 'Client Management' ? 13 : 14)
                              : (displayLabel == 'Client Management' ? 14 : 15)),
                      fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                      letterSpacing:
                          displayLabel == 'Client Management' ? -0.2 : 0,
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
                if (isActive)
                  const Padding(
                    padding: EdgeInsets.only(left: 10),
                    child: Icon(
                      Icons.arrow_forward_ios,
                      size: 12,
                      color: Colors.white,
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
