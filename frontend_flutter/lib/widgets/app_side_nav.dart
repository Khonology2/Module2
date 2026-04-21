import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/app_constants.dart';
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
  static const double expandedWidth = 250.0;

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
    final height = MediaQuery.sizeOf(context).height;
    final compact = height < 820;
    final veryCompact = height < 720;

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
            _buildHeader(widget.isCollapsed, compact, veryCompact, chrome),
            Expanded(
              child: SingleChildScrollView(
                physics: height < 640
                    ? const AlwaysScrollableScrollPhysics()
                    : const NeverScrollableScrollPhysics(),
                padding: EdgeInsets.symmetric(
                  vertical: veryCompact ? 2 : (compact ? 4 : 6),
                ),
                child: Column(
                  children: [
                    for (final item in items)
                      _buildNavItem(
                        label: item['label']!,
                        assetPath: item['icon']!,
                        isCollapsed: widget.isCollapsed,
                        compact: compact,
                        veryCompact: veryCompact,
                        chrome: chrome,
                      ),
                  ],
                ),
              ),
            ),
            _buildBottom(widget.isCollapsed, compact, veryCompact, chrome),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(
    bool isCollapsed,
    bool compact,
    bool veryCompact,
    ManagerChromeTheme chrome,
  ) {
    if (isCollapsed) {
      return Padding(
        padding: EdgeInsets.symmetric(
          vertical: veryCompact ? 10 : (compact ? 12 : 20),
          horizontal: 10,
        ),
        child: InkWell(
          onTap: widget.onToggle,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            height: 44,
            decoration: BoxDecoration(
              color: chrome.sidebarHoverFill,
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: Icon(
              Icons.keyboard_arrow_right,
              color: chrome.textPrimary,
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
                onTap: widget.onToggle,
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: chrome.sidebarHoverFill,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.keyboard_arrow_left,
                    color: chrome.textPrimary,
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
                    color: chrome.textSecondary,
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 2),
                Text(
                  'Proposal & SOW Builder',
                  style: TextStyle(
                    color: chrome.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
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

    return Container(
      padding:
          EdgeInsets.fromLTRB(16, compact ? 18 : 30, 16, compact ? 12 : 20),
      child: Stack(
        children: [
          Positioned(
            top: 0,
            right: 0,
            child: InkWell(
              onTap: widget.onToggle,
              borderRadius: BorderRadius.circular(10),
              child: Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: chrome.sidebarHoverFill,
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Icon(
                  Icons.keyboard_arrow_left,
                  color: chrome.textPrimary,
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
                  color: chrome.textSecondary,
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: compact ? 2 : 4),
              Text(
                'Proposal & SOW Builder',
                style: TextStyle(
                  color: chrome.textPrimary,
                  fontSize: compact ? 16 : 18,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: compact ? 14 : 22),
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
    required bool compact,
    required bool veryCompact,
    required ManagerChromeTheme chrome,
  }) {
    final bool isActive = label == widget.currentLabel;
    final bool isHovering = _hoveringItem == label;

    return MouseRegion(
      onEnter: (_) => setState(() => _hoveringItem = label),
      onExit: (_) => setState(() => _hoveringItem = null),
      child: Padding(
        padding: isCollapsed
            ? EdgeInsets.symmetric(
                vertical: veryCompact ? 2 : (compact ? 3 : 5))
            : EdgeInsets.symmetric(
                horizontal: 14,
                vertical: veryCompact ? 1 : (compact ? 2 : 4),
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
                    compact,
                    veryCompact,
                    chrome,
                  )
                : _buildExpandedRow(
                    label,
                    assetPath,
                    isActive,
                    isHovering,
                    compact,
                    veryCompact,
                    chrome,
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
    bool compact,
    bool veryCompact,
    ManagerChromeTheme chrome,
  ) {
    final Color rowHover =
        isHovering ? chrome.sidebarHoverFill : Colors.transparent;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: 14,
        vertical: veryCompact ? 7 : (compact ? 9 : 12),
      ),
      decoration: BoxDecoration(
        color: isActive ? AppSideNav.activeColor : rowHover,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Container(
            width: veryCompact ? 40 : (compact ? 44 : 50),
            height: veryCompact ? 40 : (compact ? 44 : 50),
            decoration: BoxDecoration(
              color: isActive
                  ? Colors.white.withOpacity(0.22)
                  : chrome.sidebarIconCircleFill,
              shape: BoxShape.circle,
            ),
            padding: EdgeInsets.all(veryCompact ? 7 : (compact ? 8 : 9)),
            child:
                AssetService.buildImageWidget(assetPath, fit: BoxFit.contain),
          ),
          SizedBox(width: veryCompact ? 10 : (compact ? 12 : 14)),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: isActive ? Colors.white : chrome.textPrimary,
                fontSize: veryCompact ? 13 : (compact ? 14 : 15),
                fontWeight: FontWeight.w500,
                height: 1.2,
              ),
              overflow: TextOverflow.ellipsis,
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
    bool compact,
    bool veryCompact,
    ManagerChromeTheme chrome,
  ) {
    return Center(
      child: Container(
        width: veryCompact ? 48 : (compact ? 52 : 56),
        height: veryCompact ? 48 : (compact ? 52 : 56),
        decoration: BoxDecoration(
          color: isActive
              ? AppSideNav.activeColor
              : isHovering
                  ? chrome.sidebarHoverFill
                  : chrome.sidebarCollapsedIconIdle,
          shape: BoxShape.circle,
        ),
        padding: EdgeInsets.all(veryCompact ? 9 : (compact ? 10 : 12)),
        child: AssetService.buildImageWidget(assetPath, fit: BoxFit.contain),
      ),
    );
  }

  Widget _buildBottom(
    bool isCollapsed,
    bool compact,
    bool veryCompact,
    ManagerChromeTheme chrome,
  ) {
    return Padding(
      padding: EdgeInsets.only(bottom: veryCompact ? 8 : (compact ? 10 : 16)),
      child: Column(
        children: [
          if (!isCollapsed)
            Container(
              margin: EdgeInsets.symmetric(
                horizontal: 18,
                vertical: veryCompact ? 4 : (compact ? 6 : 10),
              ),
              height: 1,
              color: chrome.divider,
            ),
          _buildNavItem(
            label: 'Account Profile',
            assetPath: 'assets/images/User_Profile.png',
            isCollapsed: isCollapsed,
            compact: compact,
            veryCompact: veryCompact,
            chrome: chrome,
          ),
          _buildNavItem(
            label: 'Logout',
            assetPath: 'assets/images/Logout_KhonoBuzz.png',
            isCollapsed: isCollapsed,
            compact: compact,
            veryCompact: veryCompact,
            chrome: chrome,
          ),
          if (!isCollapsed) ...[
            SizedBox(height: veryCompact ? 4 : (compact ? 6 : 10)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                decoration: BoxDecoration(
                  color: chrome.sidebarHoverFill,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  AppConstants.fullVersion,
                  style: TextStyle(
                    color: chrome.textSecondary,
                    fontSize: veryCompact ? 10 : 11,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
