import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/asset_service.dart';
import '../theme/manager_theme_controller.dart';

class AppSideNav extends StatefulWidget {
  const AppSideNav({
    super.key,
    required this.isCollapsed,
    required this.currentLabel,
    required this.onSelect,
    required this.onToggle,
    required this.isAdmin,
  });

  final bool isCollapsed;
  final String currentLabel;
  final ValueChanged<String> onSelect;
  final VoidCallback onToggle;
  final bool isAdmin;

  static const Color activeColor = Color(0xFFC10D00);
  static const Color leftAccentColor = Color(0xFF1565C0);

  static const double collapsedWidth = 80.0;
  static const double expandedWidth = 300.0;

  static const List<Map<String, String>> _items = [
    {
      'label': 'Dashboard',
      'icon':
          'assets/images/Creator_Dashboard/Project Launch_Start_White Badge_Blue.png',
    },
    {
      'label': 'Proposals',
      'icon':
          'assets/images/Creator_Dashboard/Networking_Collaboration_White Badge__Blue.png',
    },
    {
      'label': 'Templates',
      'icon':
          'assets/images/Creator_Dashboard/Task Management_White Badge_Blue.png',
    },
    {
      'label': 'Content Library',
      'icon':
          'assets/images/Creator_Dashboard/Process Flows_Automation_White Badge_Blue.png',
    },
    {
      'label': 'Client Management',
      'icon':
          'assets/images/Creator_Dashboard/HR_Team Management_White Badge_Blue.png',
    },
    {
      'label': 'Approved Proposals',
      'icon': 'assets/images/Creator_Dashboard/Approved_White Badge_Blue.png',
    },
    {
      'label': 'Analytics (My Pipeline)',
      'icon':
          'assets/images/Creator_Dashboard/Business Growth_Development_White Badge_Blue.png',
    },
  ];

  static const List<Map<String, String>> _adminItems = [
    {
      'label': 'Dashboard',
      'icon': 'assets/images/new icons for manager/Dashboard.png',
    },
    {
      'label': 'Approvals',
      'icon': 'assets/images/new icons for manager/Approved proposals.png',
    },
    {
      'label': 'Analytics',
      'icon': 'assets/images/analytics.png',
    },
    {
      'label': 'History',
      'icon': 'assets/images/new icons for manager/Approved proposals.png',
    },
    {
      'label': 'Content Library',
      'icon': 'assets/images/new icons for manager/content library.png',
    },
  ];

  @override
  State<AppSideNav> createState() => _AppSideNavState();
}

class _AppSideNavState extends State<AppSideNav> {
  String? _hoveringItem;

  @override
  Widget build(BuildContext context) {
    final chrome = context.watch<ManagerThemeController>().chrome;
    final items = widget.isAdmin ? AppSideNav._adminItems : AppSideNav._items;

    // Keep the creator/manager sidebar visually stable while the window resizes.
    const isCompact = true;
    const isVeryCompact = false;
    const isUltraCompact = false;
    const navToBottomGap = 42.0;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: widget.isCollapsed
          ? AppSideNav.collapsedWidth
          : AppSideNav.expandedWidth,
      decoration: BoxDecoration(
        color: chrome.sidebarBackground,
        border: Border(
          left: const BorderSide(color: AppSideNav.leftAccentColor, width: 3),
          right: BorderSide(color: chrome.sidebarRightBorder, width: 1),
        ),
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(
              widget.isCollapsed,
              chrome,
              isCompact: isCompact,
              isVeryCompact: isVeryCompact,
              isUltraCompact: isUltraCompact,
            ),
            Expanded(
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  children: [
                    for (final item in items)
                      _buildNavItem(
                        label: item['label']!,
                        assetPath: item['icon']!,
                        isCollapsed: widget.isCollapsed,
                        chrome: chrome,
                        isCompact: isCompact,
                        isVeryCompact: isVeryCompact,
                        isUltraCompact: isUltraCompact,
                      ),
                    SizedBox(height: navToBottomGap),
                  ],
                ),
              ),
            ),
            _buildBottom(
              widget.isCollapsed,
              chrome,
              isCompact: isCompact,
              isUltraCompact: isUltraCompact,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(
    bool isCollapsed,
    ManagerChromeTheme chrome, {
    bool isCompact = false,
    bool isVeryCompact = false,
    bool isUltraCompact = false,
  }) {
    if (isCollapsed) {
      return Padding(
        padding: EdgeInsets.symmetric(
          vertical: isUltraCompact ? 10 : (isCompact ? 14 : 20),
          horizontal: 10,
        ),
        child: InkWell(
          onTap: widget.onToggle,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            height: isUltraCompact ? 34 : (isCompact ? 38 : 44),
            decoration: BoxDecoration(
              color: chrome.sidebarHoverFill,
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: Icon(
              Icons.keyboard_arrow_right,
              color: chrome.textPrimary,
              size: isUltraCompact ? 20 : 24,
            ),
          ),
        ),
      );
    }

    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        isUltraCompact ? 12 : (isCompact ? 18 : 30),
        16,
        isUltraCompact ? 8 : (isCompact ? 12 : 20),
      ),
      child: Stack(
        children: [
          Positioned(
            top: 0,
            right: 0,
            child: InkWell(
              onTap: widget.onToggle,
              borderRadius: BorderRadius.circular(10),
              child: Container(
                width: isUltraCompact ? 26 : 30,
                height: isUltraCompact ? 26 : 30,
                decoration: BoxDecoration(
                  color: chrome.sidebarHoverFill,
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Icon(
                  Icons.keyboard_arrow_left,
                  color: chrome.textPrimary,
                  size: isUltraCompact ? 18 : 20,
                ),
              ),
            ),
          ),
          Column(
            children: [
              SizedBox(height: isUltraCompact ? 0 : 2),
              Image.asset(
                'assets/images/new icons for manager/khonology_logo.png',
                height: isUltraCompact ? 22 : (isVeryCompact ? 26 : 30),
                fit: BoxFit.contain,
              ),
              SizedBox(height: isUltraCompact ? 6 : (isCompact ? 8 : 12)),
              Text(
                'Welcome to',
                style: TextStyle(
                  color: chrome.textSecondary,
                  fontSize: isUltraCompact ? 10.5 : (isCompact ? 11.5 : 12.5),
                  fontWeight: FontWeight.w400,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 2),
              Text(
                'Proposal & SOW Builder',
                style: TextStyle(
                  color: chrome.textPrimary,
                  fontSize: isUltraCompact ? 12 : (isCompact ? 13.5 : 15),
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: isUltraCompact ? 8 : (isCompact ? 10 : 14)),
              Container(
                height: 1,
                color: chrome.divider,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem({
    required String label,
    required String assetPath,
    required bool isCollapsed,
    required ManagerChromeTheme chrome,
    bool isCompact = false,
    bool isVeryCompact = false,
    bool isUltraCompact = false,
    bool isBottomItem = false,
  }) {
    final bool isActive = label == widget.currentLabel;
    final bool isHovering = _hoveringItem == label;

    return MouseRegion(
      onEnter: (_) => setState(() => _hoveringItem = label),
      onExit: (_) => setState(() => _hoveringItem = null),
      child: Padding(
        padding: isCollapsed
            ? EdgeInsets.symmetric(vertical: isUltraCompact ? 2 : 5)
            : EdgeInsets.symmetric(
                horizontal: isUltraCompact ? 10 : 14,
                vertical: isBottomItem
                    ? (isUltraCompact ? 0.6 : 1.0)
                    : (isUltraCompact ? 1 : (isCompact ? 1.2 : 2)),
              ),
        child: Tooltip(
          message: isCollapsed ? label : '',
          child: InkWell(
            onTap: () => widget.onSelect(label),
            borderRadius: BorderRadius.circular(10),
            child: isCollapsed
                ? _buildCollapsedIcon(
                    assetPath,
                    isActive,
                    isHovering,
                    chrome,
                    isCompact: isCompact,
                    isUltraCompact: isUltraCompact,
                  )
                : _buildExpandedRow(
                    label,
                    assetPath,
                    isActive,
                    isHovering,
                    chrome,
                    isCompact: isCompact,
                    isVeryCompact: isVeryCompact,
                    isUltraCompact: isUltraCompact,
                    isBottomItem: isBottomItem,
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildExpandedRow(
    String label,
    String assetPath,
    bool isActive,
    bool isHovering,
    ManagerChromeTheme chrome,
    {
    bool isCompact = false,
    bool isVeryCompact = false,
    bool isUltraCompact = false,
    bool isBottomItem = false,
  }) {
    final Color rowHover =
        isHovering ? chrome.sidebarHoverFill : Colors.transparent;
    final rowVerticalPadding = isBottomItem
        ? (isUltraCompact ? 3.8 : 4.4)
        : (isUltraCompact ? 4.5 : (isVeryCompact ? 5.5 : 6.5));
    final iconSize = isBottomItem
        ? (isUltraCompact ? 31.0 : 33.0)
        : (isUltraCompact ? 33.0 : (isCompact ? 35.0 : 37.0));
    final fontSize = isBottomItem
        ? (isUltraCompact ? 11.0 : 11.4)
        : (isUltraCompact ? 11.2 : (isVeryCompact ? 11.6 : 12.0));

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: rowVerticalPadding),
      decoration: BoxDecoration(
        color: isActive ? AppSideNav.activeColor : rowHover,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          SizedBox(
            width: iconSize,
            height: iconSize,
            child: AssetService.buildImageWidget(assetPath, fit: BoxFit.contain),
          ),
          SizedBox(width: isUltraCompact ? 10 : 12),
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: SizedBox(
                width: 111.87,
                height: 20.7,
                child: Text(
                  label,
                  style: TextStyle(
                    color: isActive ? Colors.white : chrome.textPrimary,
                    fontSize: fontSize,
                    fontWeight: FontWeight.w500,
                    height: 1.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCollapsedIcon(
    String assetPath,
    bool isActive,
    bool isHovering,
    ManagerChromeTheme chrome,
    {
    bool isCompact = false,
    bool isUltraCompact = false,
  }) {
    final collapsedIconSize = isUltraCompact ? 44.0 : (isCompact ? 50.0 : 56.0);
    return Center(
      child: Container(
        width: collapsedIconSize,
        height: collapsedIconSize,
        decoration: BoxDecoration(
          color: isActive
              ? AppSideNav.activeColor
              : isHovering
                  ? chrome.sidebarHoverFill
                  : chrome.sidebarCollapsedIconIdle,
          shape: BoxShape.circle,
        ),
        padding: EdgeInsets.all(isUltraCompact ? 9 : 12),
        child: AssetService.buildImageWidget(assetPath, fit: BoxFit.contain),
      ),
    );
  }

  Widget _buildBottom(
    bool isCollapsed,
    ManagerChromeTheme chrome, {
    bool isCompact = false,
    bool isUltraCompact = false,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: isUltraCompact ? 6 : 10),
      child: Column(
        children: [
          _buildNavItem(
            label: 'Account Profile',
            assetPath: 'assets/images/User_Profile.png',
            isCollapsed: isCollapsed,
            chrome: chrome,
            isCompact: isCompact,
            isUltraCompact: isUltraCompact,
            isBottomItem: true,
          ),
          if (!isCollapsed)
            Container(
              margin: EdgeInsets.symmetric(
                horizontal: 18,
                vertical: isUltraCompact ? 4 : 6,
              ),
              height: 1,
              color: const Color(0xFFFFFFFF),
            ),
          _buildNavItem(
            label: 'Logout',
            assetPath: 'assets/images/Logout_KhonoBuzz.png',
            isCollapsed: isCollapsed,
            chrome: chrome,
            isCompact: isCompact,
            isUltraCompact: isUltraCompact,
            isBottomItem: true,
          ),
        ],
      ),
    );
  }
}
