import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../api.dart';
import '../../services/auth_service.dart';
import '../../theme/manager_theme_controller.dart';
import '../../widgets/admin/admin_sidebar.dart';
import '../../widgets/ai_persona_router_local_panel.dart';
import '../../widgets/manager_page_background.dart';

/// Proposal assistant HF Space routing (provider / model / optional BYOK) — device-only prefs.
/// Opened from the Admin sidebar, not from global Settings.
class AIConfigurationPage extends StatefulWidget {
  const AIConfigurationPage({super.key});

  @override
  State<AIConfigurationPage> createState() => _AIConfigurationPageState();
}

class _AIConfigurationPageState extends State<AIConfigurationPage> {
  final ScrollController _scrollController = ScrollController();
  final GlobalKey<AiPersonaRouterLocalPanelState> _panelKey =
      GlobalKey<AiPersonaRouterLocalPanelState>();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _navigateToPage(String label) {
    switch (label) {
      case 'AI Configuration':
        return;
      case 'Dashboard':
        Navigator.pushReplacementNamed(context, '/approver_dashboard');
        break;
      case 'Approvals':
        Navigator.pushReplacementNamed(context, '/admin_approvals');
        break;
      case 'Analytics':
      case 'All analytics':
      case 'My analytics':
        Navigator.pushReplacementNamed(context, '/admin_analytics');
        break;
      case 'History':
        Navigator.pushReplacementNamed(context, '/admin_history');
        break;
      case 'Content Library':
        Navigator.pushNamed(context, '/content_library');
        break;
      case 'Account Profile':
        Navigator.pushReplacementNamed(context, '/manager_account_profile');
        break;
      case 'Sign Out':
      case 'Logout':
        AuthService.logout();
        Navigator.pushNamedAndRemoveUntil(
            context, '/login', (Route<dynamic> route) => false);
        break;
    }
  }

  Future<void> _saveRouting() async {
    final ok = await _panelKey.currentState?.saveToDevice() ?? false;
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'AI assistant routing saved on this device.'
              : 'Fix the highlighted issues and try again.',
        ),
      ),
    );
  }

  Widget _buildManagerStyleHeaderStrip(ManagerChromeTheme chrome) {
    return Container(
      height: 96,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: chrome.headerBarFill,
        border: Border(
          bottom: BorderSide(color: chrome.divider, width: 1),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Back',
            onPressed: () => Navigator.of(context).maybePop(),
            icon: Icon(
              Icons.arrow_back_rounded,
              color: chrome.textPrimary,
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              'AI Configuration',
              style: TextStyle(
                color: chrome.textPrimary,
                fontFamily: 'Poppins',
                fontSize: 20,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final chrome = context.watch<ManagerThemeController>().chrome;

    final scrollTheme = ScrollbarThemeData(
      thumbVisibility: WidgetStateProperty.all(true),
      trackVisibility: WidgetStateProperty.all(true),
      thickness: WidgetStateProperty.all(10),
      radius: const Radius.circular(6),
      thumbColor: WidgetStateProperty.all(chrome.scrollbarThumb),
      trackColor: WidgetStateProperty.all(chrome.scrollbarTrack),
      trackBorderColor: WidgetStateProperty.all(chrome.divider),
      crossAxisMargin: 4,
      mainAxisMargin: 2,
    );

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton(
        heroTag: 'ai_configuration_theme_toggle',
        backgroundColor: ManagerChromeTheme.accentRed,
        onPressed: () {
          final ctrl = context.read<ManagerThemeController>();
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ctrl.toggle();
          });
        },
        child: Icon(
          chrome.isDark ? Icons.wb_sunny_rounded : Icons.dark_mode_rounded,
          color: Colors.white,
        ),
      ),
      body: DefaultTextStyle.merge(
        style: GoogleFonts.poppins(),
        child: ManagerPageBackground(
          child: SafeArea(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AdminSidebar(
                  isCollapsed: app.isAdminSidebarCollapsed,
                  currentPage: 'AI Configuration',
                  managerChrome: chrome,
                  onToggle: app.toggleAdminSidebar,
                  onSelect: _navigateToPage,
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildManagerStyleHeaderStrip(chrome),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: DecoratedBox(
                              decoration:
                                  chrome.floatingPanelDecoration(radius: 16),
                              child: Stack(
                                clipBehavior: Clip.hardEdge,
                                children: [
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.fromLTRB(
                                          22,
                                          18,
                                          22,
                                          8,
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Proposal assistant routing',
                                              style: GoogleFonts.poppins(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w600,
                                                color: chrome.textPrimary,
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                              'Set default Hugging Face Space provider routing '
                                              'and optional API keys (stored on this device only). '
                                              'If you leave overrides empty, workspace defaults '
                                              'from the backend apply.',
                                              style: GoogleFonts.poppins(
                                                fontSize: 13,
                                                height: 1.45,
                                                color: chrome.textSecondary,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Expanded(
                                        child: Theme(
                                          data: Theme.of(context).copyWith(
                                            scrollbarTheme: scrollTheme,
                                          ),
                                          child: Scrollbar(
                                            controller: _scrollController,
                                            thumbVisibility: true,
                                            trackVisibility: true,
                                            thickness: 10,
                                            radius: const Radius.circular(6),
                                            interactive: true,
                                            child: SingleChildScrollView(
                                              controller:
                                                  _scrollController,
                                              physics:
                                                  const AlwaysScrollableScrollPhysics(),
                                              padding: const EdgeInsets.only(
                                                left: 22,
                                                right: 22,
                                                bottom: 112,
                                              ),
                                              child:
                                                  AiPersonaRouterLocalPanel(
                                                key: _panelKey,
                                                embedInGlass: true,
                                                managerChrome: chrome,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  Positioned(
                                    right: 16,
                                    bottom: 76,
                                    child: Material(
                                      elevation: 8,
                                      color: ManagerChromeTheme.accentRed,
                                      borderRadius:
                                          BorderRadius.circular(999),
                                      shadowColor: Colors.black54,
                                      child: InkWell(
                                        borderRadius:
                                            BorderRadius.circular(999),
                                        onTap: _saveRouting,
                                        child: Padding(
                                          padding:
                                              const EdgeInsets.symmetric(
                                            horizontal: 22,
                                            vertical: 12,
                                          ),
                                          child: Text(
                                            'Save',
                                            style: GoogleFonts.poppins(
                                              color: Colors.white,
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
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
