import 'package:flutter/material.dart';

import '../services/asset_service.dart';
import '../theme/app_colors.dart';

class CreatorDashboardSidebar extends StatelessWidget {
  const CreatorDashboardSidebar({
    super.key,
    required this.isCollapsed,
    required this.currentLabel,
    required this.onSelect,
    required this.onToggle,
    this.showCollapseToggle = false,
  });

  final bool isCollapsed;
  final String currentLabel;
  final ValueChanged<String> onSelect;
  final VoidCallback onToggle;
  final bool showCollapseToggle;

  static const double collapsedWidth = 76.0;
  static const double expandedWidth = 220.0;

  static const List<_SidebarNavItem> _items = [
    _SidebarNavItem(
      label: 'Dashboard',
      assetPath:
          'assets/images/Creator_Dashboard/Project Launch_Start_White Badge_Blue.png',
    ),
    _SidebarNavItem(
      label: 'My Proposals',
      assetPath:
          'assets/images/Creator_Dashboard/Networking_Collaboration_White Badge__Blue.png',
    ),
    _SidebarNavItem(
      label: 'Templates',
      assetPath:
          'assets/images/Creator_Dashboard/Task Management_White Badge_Blue.png',
    ),
    _SidebarNavItem(
      label: 'Content Library',
      assetPath:
          'assets/images/Creator_Dashboard/Process Flows_Automation_White Badge_Blue.png',
    ),
    _SidebarNavItem(
      label: 'Client Management',
      assetPath:
          'assets/images/Creator_Dashboard/HR_Team Management_White Badge_Blue.png',
    ),
    _SidebarNavItem(
      label: 'Approved Proposals',
      assetPath:
          'assets/images/Creator_Dashboard/Approved_White Badge_Blue.png',
    ),
    _SidebarNavItem(
      label: 'Analytics (My Pipeline)',
      assetPath:
          'assets/images/Creator_Dashboard/Business Growth_Development_White Badge_Blue.png',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final effectiveCollapsed = showCollapseToggle ? isCollapsed : false;
    return AnimatedContainer(
      duration: AppColors.animationDuration,
      width: effectiveCollapsed ? collapsedWidth : expandedWidth,
      decoration: const BoxDecoration(
        color: AppColors.backgroundColor,
        border: Border(
          right: BorderSide(color: AppColors.borderColor, width: 1),
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            _SidebarHeader(
              isCollapsed: effectiveCollapsed,
              onToggle: onToggle,
              showCollapseToggle: showCollapseToggle,
            ),
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
                          for (final item in _items)
                            _SidebarRow(
                              label: item.label,
                              assetPath: item.assetPath,
                              isCollapsed: effectiveCollapsed,
                              isSelected: currentLabel == item.label,
                              onTap: () => onSelect(item.label),
                            ),
                          SizedBox(height: effectiveCollapsed ? 18 : 40),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: effectiveCollapsed ? 8 : 10),
                  _SidebarRow(
                    label: 'Account Profile',
                    assetPath:
                        'assets/images/Creator_Dashboard/User Profile_White Badge_Blue.png',
                    isCollapsed: effectiveCollapsed,
                    isSelected: currentLabel == 'Account Profile',
                    isBottomItem: true,
                    onTap: () => onSelect('Account Profile'),
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
                  _SidebarRow(
                    label: 'Logout',
                    assetPath: 'assets/images/Logout_KhonoBuzz.png',
                    isCollapsed: effectiveCollapsed,
                    isSelected: false,
                    isBottomItem: true,
                    onTap: () => onSelect('Logout'),
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
}

class _SidebarHeader extends StatelessWidget {
  const _SidebarHeader({
    required this.isCollapsed,
    required this.onToggle,
    required this.showCollapseToggle,
  });

  final bool isCollapsed;
  final VoidCallback onToggle;
  final bool showCollapseToggle;

  @override
  Widget build(BuildContext context) {
    if (isCollapsed) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        child: InkWell(
          onTap: showCollapseToggle ? onToggle : null,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.hoverColor,
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: showCollapseToggle
                ? const Icon(
                    Icons.keyboard_arrow_right,
                    color: AppColors.textPrimary,
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
                    color: AppColors.hoverColor,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.keyboard_arrow_left,
                    color: AppColors.textPrimary,
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
              const Text(
                'Welcome to',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              const Text(
                'Proposal & SOW Builder',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 12.8,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                height: 1,
                color: AppColors.borderColor,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SidebarRow extends StatelessWidget {
  const _SidebarRow({
    required this.label,
    required this.assetPath,
    required this.isCollapsed,
    required this.isSelected,
    required this.onTap,
    this.isBottomItem = false,
  });

  final String label;
  final String assetPath;
  final bool isCollapsed;
  final bool isSelected;
  final bool isBottomItem;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final iconSize = isBottomItem ? 31.0 : 34.0;
    final fontSize = isBottomItem ? 11.2 : 11.8;

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: isCollapsed ? 0 : 10,
        vertical: isBottomItem ? 1 : 2,
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          height: isBottomItem ? 38 : 40,
          padding: EdgeInsets.symmetric(horizontal: isCollapsed ? 0 : 10),
          decoration: BoxDecoration(
            color: isCollapsed
                ? Colors.transparent
                : (isSelected ? AppColors.activeColor : Colors.transparent),
            borderRadius: BorderRadius.circular(10),
          ),
          child: isCollapsed
              ? Center(
                  child: SizedBox(
                    width: 42,
                    height: 42,
                    child: AssetService.buildImageWidget(
                      assetPath,
                      fit: BoxFit.contain,
                    ),
                  ),
                )
              : Row(
                  children: [
                    SizedBox(
                      width: iconSize,
                      height: iconSize,
                      child: AssetService.buildImageWidget(
                        assetPath,
                        fit: BoxFit.contain,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: isSelected
                              ? AppColors.textPrimary
                              : AppColors.textSecondary,
                          fontSize: fontSize,
                          fontWeight:
                              isSelected ? FontWeight.w600 : FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _SidebarNavItem {
  const _SidebarNavItem({
    required this.label,
    required this.assetPath,
  });

  final String label;
  final String assetPath;
}
