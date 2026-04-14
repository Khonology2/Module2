import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';

import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import 'package:provider/provider.dart';
import '../../api.dart';
import '../../widgets/custom_scrollbar.dart';
import '../../theme/premium_theme.dart';
import '../../theme/manager_theme_controller.dart';
import '../../widgets/app_side_nav.dart';
import '../../widgets/manager_page_background.dart';
import '../../utils/manager_session_actions.dart';

class ProposalsPage extends StatefulWidget {
  const ProposalsPage({super.key});

  @override
  _ProposalsPageState createState() => _ProposalsPageState();
}

class _ProposalsPageState extends State<ProposalsPage>
    with TickerProviderStateMixin {
  String _filterStatus = 'All Statuses';
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> proposals = [];
  bool _isLoading = true;
  String? _token;
  bool _isSidebarCollapsed = false;
  String _currentNavLabel = 'Proposals';

  void _navigateToPage(BuildContext context, String label) {
    switch (label) {
      case 'Dashboard':
        Navigator.pushReplacementNamed(context, '/dashboard');
        break;
      case 'My Proposals':
      case 'Proposals':
        // Already on proposals page
        break;
      case 'Templates':
        Navigator.pushReplacementNamed(context, '/templates');
        break;
      case 'Content Library':
        Navigator.pushReplacementNamed(context, '/content_library');
        break;
      case 'Client Management':
        Navigator.pushReplacementNamed(context, '/client_management');
        break;
      case 'Approved Proposals':
        Navigator.pushReplacementNamed(context, '/approved_proposals');
        break;
      case 'Analytics (My Pipeline)':
        Navigator.pushReplacementNamed(context, '/analytics');
        break;
      case 'Account Profile':
        break;
      case 'Logout':
        _handleLogout(context);
        break;
    }
  }

  void _handleLogout(BuildContext context) {
    ManagerSessionActions.showLogoutDialog(context);
  }

  final ScrollController _scrollController = ScrollController();
  final ScrollController _listScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final appState = context.read<AppState>();
      if (appState.proposals.isNotEmpty) {
        setState(() {
          proposals = List<Map<String, dynamic>>.from(appState.proposals
              .whereType<Map>()
              .map((p) => Map<String, dynamic>.from(p)));
          _isLoading = false;
        });
      }
      _loadProposals(showLoader: appState.proposals.isEmpty);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _listScrollController.dispose();
    super.dispose();
  }

  Future<void> _loadProposals({bool showLoader = false}) async {
    if (showLoader && mounted) {
      setState(() => _isLoading = true);
    }
    try {
      // Get token from AuthService (backend JWT) - same as document editor
      final token = AuthService.token;

      // Fallback to AppState if token not in AuthService
      if (token == null || token.isEmpty) {
        if (mounted) {
          final appState = context.read<AppState>();
          _token = appState.authToken;
        }
      } else {
        _token = token;
      }

      if (_token != null && _token!.isNotEmpty) {
        print('Γ£à Loading proposals with token...');
        final data = await ApiService.getProposals(_token!);
        if (mounted) {
          setState(() {
            proposals = List<Map<String, dynamic>>.from(data);
            print('Γ£à Loaded ${proposals.length} proposals');
            _isLoading = false;
          });
        }
      } else {
        print('ΓÜá∩╕Å No authentication token found');
        if (mounted) {
          setState(() {
            proposals = [];
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      print('Γ¥î Error loading proposals: $e');
      if (mounted && showLoader) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showCreateNewDialog() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Container(
          width: 400,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.add_circle_outline,
                  color: Color(0xFF2563EB),
                  size: 32,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Create New',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2c3e50),
                ),
              ),
              const SizedBox(height: 24),
              // Start from scratch option
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () async {
                    Navigator.pop(context);
                    _navigateToBlankProposal();
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFFe2e8f0)),
                      borderRadius: BorderRadius.circular(8),
                      color: Colors.grey[50],
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color:
                                const Color(0xFF3498DB).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.edit_outlined,
                            color: Color(0xFF3498DB),
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Text(
                                'Start from scratch',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF2c3e50),
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Create a blank proposal',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF718096),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right,
                            color: Color(0xFF718096)),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // Choose from template gallery option
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, '/proposal-wizard')
                        .then((_) => _loadProposals());
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFFe2e8f0)),
                      borderRadius: BorderRadius.circular(8),
                      color: Colors.grey[50],
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color:
                                const Color(0xFF2ECC71).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.library_books_outlined,
                            color: Color(0xFF2ECC71),
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Text(
                                'Choose from Template Gallery',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF2c3e50),
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Select a template to get started',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF718096),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right,
                            color: Color(0xFF718096)),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderIconButton({
    required ManagerChromeTheme chrome,
    required String assetPath,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 80,
        height: 80,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: chrome.floatingFill,
          shape: BoxShape.circle,
        ),
        child: Image.asset(assetPath, fit: BoxFit.contain),
      ),
    );
  }

  Future<void> _navigateToBlankProposal() async {
    try {
      // Navigate directly to blank document editor
      if (mounted) {
        Navigator.pushNamed(
          context,
          '/blank-document',
          arguments: {
            'proposalId': 'temp-${DateTime.now().millisecondsSinceEpoch}',
            'proposalTitle': 'Untitled Document',
          },
        ).then((_) => _loadProposals());
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error opening blank document: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final chrome = context.watch<ManagerThemeController>().chrome;
    final userRole = app.currentUser?['role'] ?? 'Financial Manager';

    final filtered = proposals.where((p) {
      final title = (p['title'] ?? '').toString().toLowerCase();
      final client =
          (p['client_name'] ?? p['client'] ?? '').toString().toLowerCase();
      final matchesSearch =
          title.contains(_searchController.text.toLowerCase()) ||
              client.contains(_searchController.text.toLowerCase());
      final matchesStatus = _filterStatus == 'All Statuses' ||
          (p['status'] ?? '') == _filterStatus;
      return matchesSearch && matchesStatus;
    }).toList();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        bottom: false,
        child: ManagerPageBackground(
          child: Row(
            children: [
              // Consistent Sidebar using AppSideNav
              Consumer<AppState>(
                builder: (context, app, child) {
                  final role = (app.currentUser?['role'] ?? '')
                      .toString()
                      .toLowerCase()
                      .trim();
                  final isAdmin = role == 'admin' || role == 'ceo';
                  return AppSideNav(
                    isCollapsed: _isSidebarCollapsed,
                    currentLabel: _currentNavLabel,
                    onSelect: (label) {
                      setState(() => _currentNavLabel = label);
                      _navigateToPage(context, label);
                    },
                    onToggle: () => setState(
                      () => _isSidebarCollapsed = !_isSidebarCollapsed,
                    ),
                    isAdmin: isAdmin,
                  );
                },
              ),

              // Main Content Area
              Expanded(
                child: Column(
                  children: [
                    // Header bar (same style as Manager Dashboard)
                    _buildHeaderBar(app, userRole, chrome),

                    // Content Area
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 0, 24, 0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: CustomScrollbar(
                                controller: _scrollController,
                                thumbColor: chrome.scrollbarThumb,
                                trackColor: chrome.scrollbarTrack,
                                trackBorderColor: chrome.divider,
                                child: SingleChildScrollView(
                                  controller: _scrollController,
                                  padding: const EdgeInsets.only(bottom: 24),
                                  child: _buildOverviewAndListPanel(
                                    filtered: filtered,
                                    chrome: chrome,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              width: 114.93836212158203,
                              height: 18,
                              decoration: BoxDecoration(
                                color: chrome.fieldFill,
                                borderRadius: BorderRadius.circular(4.3),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                'Ver 2026.03.AA1_SIT',
                                style: TextStyle(
                                  fontSize: 9,
                                  color: chrome.textMuted,
                                  height: 1,
                                ),
                              ),
                            ),
                          ],
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
    );
  }

  Widget _buildHeaderBar(
      AppState app, String userRole, ManagerChromeTheme chrome) {
    return Container(
      height: 96,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.transparent,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            'Manager Proposal Management',
            style: TextStyle(
              color: const Color(0xFFFFFFFF),
              fontSize: 20,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(width: 12),
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: 'Hello, ',
                  style: TextStyle(
                    color: chrome.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                TextSpan(
                  text: _getUserName(app.currentUser),
                  style: TextStyle(
                    color: chrome.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          _buildHeaderIconButton(
            chrome: chrome,
            assetPath: 'assets/images/new icons for manager/messages.png',
            onTap: () {},
          ),
          const SizedBox(width: 8),
          _buildHeaderIconButton(
            chrome: chrome,
            assetPath: 'assets/images/new icons for manager/notifications.png',
            onTap: () {},
          ),
          const SizedBox(width: 12),
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: const Color(0xFFC10D00).withOpacity(0.5),
                width: 2,
              ),
            ),
            child: ClipOval(
              child: Image.asset(
                'assets/images/User_Profile.png',
                width: 80,
                height: 80,
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(width: 10),
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert, color: chrome.textSecondary, size: 28),
            onSelected: (value) {
              if (value == 'logout') {
                _handleLogout(context);
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem<String>(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout),
                    SizedBox(width: 8),
                    Text('Logout'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewAndListPanel({
    required List<Map<String, dynamic>> filtered,
    required ManagerChromeTheme chrome,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 946.2045288461986,
          decoration: BoxDecoration(
            color: const Color(0x24FFFFFF), // #FFFFFF24 with opacity
            borderRadius: BorderRadius.circular(5.32),
            boxShadow: [
              BoxShadow(
                color: const Color(0x40000000), // #00000040
                blurRadius: 3.55,
                offset: const Offset(0, 3.55),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(20),
                child: _buildToolbarContent(chrome),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Divider(
                  color: chrome.divider,
                  height: 1,
                  thickness: 1,
                ),
              ),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 330),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                  child: _buildFilterPanelBody(filtered, chrome),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildToolbarContent(ManagerChromeTheme chrome) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Image.asset(
          'assets/images/new icons for manager/Draft proposal.png',
          width: 73,
          height: 73,
          fit: BoxFit.contain,
        ),
        const SizedBox(width: 16),
        Expanded(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Proposals Overview',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                    letterSpacing: 0.2,
                    color: Color(0xFFFFFFFF),
                  ),
                ),
                const SizedBox(height: 2),
                Text("Manage all your business proposals & SOW's",
                    style:
                        TextStyle(fontSize: 12, color: chrome.textSecondary)),
              ],
            ),
          ),
        ),
        const SizedBox(width: 18),
        SizedBox(
          width: 245,
          height: 43.060546875,
          child: Stack(
            alignment: Alignment.centerLeft,
            children: [
              Positioned.fill(
                child: Padding(
                  padding: const EdgeInsets.only(left: 22),
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF3D3D3D),
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.only(left: 36, right: 12),
                      child: Center(
                        child: TextField(
                          controller: _searchController,
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(
                            hintText: 'Search Proposals...',
                            hintStyle: TextStyle(
                              color: Color(0xFF9CA3AF),
                              fontSize: 14,
                            ),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.zero,
                            isDense: true,
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Container(
                width: 43,
                height: 43,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.35),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipOval(
                  child: Image.asset(
                    'assets/images/new icons for manager/Search_Seek_Red Badge_White.png',
                    width: 43,
                    height: 43,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF4B5563),
            borderRadius: BorderRadius.circular(8),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _filterStatus,
              dropdownColor: const Color(0xFF4B5563),
              icon: const Icon(Icons.keyboard_arrow_down,
                  color: Colors.white, size: 20),
              style: const TextStyle(color: Colors.white, fontSize: 14),
              items: [
                'All Statuses',
                'Draft',
                'Sent to Client',
                'Approval Requested',
                'Approved',
                'Declined'
              ]
                  .map((String value) => DropdownMenuItem<String>(
                        value: value,
                        child: Text(value),
                      ))
                  .toList(),
              onChanged: (String? newValue) =>
                  setState(() => _filterStatus = newValue ?? 'All Statuses'),
            ),
          ),
        ),
        const SizedBox(width: 12),
        ElevatedButton.icon(
          onPressed: _showCreateNewDialog,
          icon: const Icon(Icons.add, size: 18, color: Colors.white),
          label:
              const Text('New Proposal', style: TextStyle(color: Colors.white)),
          style: ElevatedButton.styleFrom(
            backgroundColor: PremiumTheme.primaryRed,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            elevation: 0,
          ),
        ),
      ],
    );
  }

  Widget _buildFilterPanelBody(
      List<Map<String, dynamic>> filtered, ManagerChromeTheme chrome) {
    if (_isLoading) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(PremiumTheme.primaryRed),
          ),
        ),
      );
    }

    if (proposals.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 48.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.description_outlined,
                  size: 64, color: chrome.textMuted),
              const SizedBox(height: 16),
              Text('No proposals yet',
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: chrome.textPrimary)),
              const SizedBox(height: 8),
              Text('Create your first proposal to get started',
                  style: TextStyle(color: chrome.textSecondary)),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _showCreateNewDialog,
                icon: const Icon(Icons.add),
                label: const Text('Create Your First Proposal'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: PremiumTheme.primaryRed,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              )
            ],
          ),
        ),
      );
    }

    return Scrollbar(
      controller: _listScrollController,
      thumbVisibility: true,
      child: ListView.builder(
        controller: _listScrollController,
        itemCount: filtered.length,
        itemBuilder: (context, index) {
          final proposal = filtered[index];
          return ProposalItem(
            proposal: proposal,
            chrome: chrome,
            onRefresh: _loadProposals,
          );
        },
      ),
    );
  }

  String _getUserName(Map<String, dynamic>? user) {
    if (user == null) return 'User';
    String? name = user['full_name'] ??
        user['first_name'] ??
        user['name'] ??
        user['email']?.split('@')[0];
    return name ?? 'User';
  }
}

class ProposalItem extends StatelessWidget {
  final Map<String, dynamic> proposal;
  final VoidCallback? onRefresh;
  final ManagerChromeTheme chrome;

  const ProposalItem({
    Key? key,
    required this.proposal,
    this.onRefresh,
    required this.chrome,
  }) : super(key: key);

  String _formatDate(dynamic date) {
    if (date == null) return 'Unknown';
    if (date is String) {
      try {
        final hasTimezone = RegExp(r'(Z|[+-]\d{2}:\d{2})$').hasMatch(date);
        final parsedRaw = DateTime.parse(date);
        final parsed = hasTimezone
            ? parsedRaw.toLocal()
            : DateTime.utc(
                parsedRaw.year,
                parsedRaw.month,
                parsedRaw.day,
                parsedRaw.hour,
                parsedRaw.minute,
                parsedRaw.second,
                parsedRaw.millisecond,
                parsedRaw.microsecond,
              ).toLocal();
        final now = DateTime.now();

        bool isSameDay(DateTime a, DateTime b) {
          return a.year == b.year && a.month == b.month && a.day == b.day;
        }

        final today = DateTime(now.year, now.month, now.day);
        final parsedDay = DateTime(parsed.year, parsed.month, parsed.day);

        if (isSameDay(parsedDay, today)) {
          return 'Today, ${parsed.hour.toString().padLeft(2, '0')}:${parsed.minute.toString().padLeft(2, '0')}';
        }

        final yesterday = today.subtract(const Duration(days: 1));
        if (isSameDay(parsedDay, yesterday)) {
          return 'Yesterday, ${parsed.hour.toString().padLeft(2, '0')}:${parsed.minute.toString().padLeft(2, '0')}';
        }

        return '${parsed.day}/${parsed.month}/${parsed.year}';
      } catch (e) {
        return date.toString();
      }
    }
    return date.toString();
  }

  @override
  Widget build(BuildContext context) {
    final status = (proposal['status'] ?? '').toString().toLowerCase().trim();
    final editableStatuses = {
      'draft',
      'changes requested',
      'resubmitted',
    };
    final isEditable = editableStatuses.contains(status);

    // Status colors and labels matching the screenshot
    Color statusColor;
    Color statusBgColor;
    String statusLabel;

    switch (status) {
      case 'pricing':
      case 'pricing in progress':
        statusBgColor = const Color(0xFF5C389D); // Purple background
        statusColor = Colors.white;
        statusLabel = 'Pricing In Progress';
        break;
      case 'draft':
        statusBgColor = const Color(0xFF6095CC); // Blue background
        statusColor = Colors.white;
        statusLabel = 'Drafted';
        break;
      case 'pending':
      case 'pending approval':
      case 'pending ceo approval':
      case 'approval requested':
        statusBgColor = const Color(0xFFEA990C); // Orange background
        statusColor = Colors.white;
        statusLabel = 'Approval Requested';
        break;
      case 'sent':
      case 'sent to client':
        statusBgColor = const Color(0xFF6CA510); // Green background
        statusColor = Colors.white;
        statusLabel = 'Sent to Client';
        break;
      case 'approved':
        statusBgColor = const Color(0xFF6CA510); // Green background
        statusColor = Colors.white;
        statusLabel = 'Approved';
        break;
      case 'declined':
      case 'rejected':
        statusBgColor = PremiumTheme.error;
        statusColor = Colors.white;
        statusLabel = 'Declined';
        break;
      default:
        statusBgColor = chrome.fieldFill;
        statusColor = Colors.white;
        statusLabel = proposal['status'] ?? 'Unknown';
    }

    final title = proposal['title'] ?? 'Untitled Proposal';
    final clientName =
        proposal['client_name'] ?? proposal['client'] ?? 'Unknown Client';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Document Icon
          Image.asset(
            'assets/images/new icons for manager/Project Management_Red Badge_White.png',
            width: 40,
            height: 40,
            fit: BoxFit.contain,
          ),
          const SizedBox(width: 16),
          // Title and Description
          Expanded(
            flex: 3,
            child: RichText(
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              text: TextSpan(
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                  height: 9.38 / 11,
                  letterSpacing: 0.11,
                  fontFeatures: const [FontFeature.enable('smcp')],
                  color: chrome.textPrimary,
                ),
                children: [
                  TextSpan(
                    text: title,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      height: 9.38 / 13,
                      letterSpacing: 0.13,
                      fontFeatures: const [FontFeature.enable('smcp')],
                      color: chrome.textPrimary,
                    ),
                  ),
                  TextSpan(
                    text: ' - $clientName',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      height: 9.38 / 13,
                      letterSpacing: 0.13,
                      fontFeatures: const [FontFeature.enable('smcp')],
                      color: chrome.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 16),
          // Last Modified
          SizedBox(
            width: 190,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Last Modified: ${_formatDate(proposal['updated_at'] ?? proposal['updatedAt'])}',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w500,
                  fontSize: 10.5,
                  height: 9.38 / 10.5,
                  letterSpacing: 0.105,
                  color: chrome.textSecondary,
                  fontFeatures: const [FontFeature.enable('smcp')],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.left,
              ),
            ),
          ),
          const SizedBox(width: 16),
          SizedBox(
            width: 190,
            child: Align(
              alignment: Alignment.centerLeft,
              child: SizedBox(
                width: 121.00000762939453,
                height: 23.000001907348633,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(15.69, 0, 15.69, 0),
                  decoration: BoxDecoration(
                    color: statusBgColor,
                    borderRadius: BorderRadius.circular(26.06),
                  ),
                  child: Center(
                    child: Text(
                      statusLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: statusColor,
                        height: 1,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          SizedBox(
            width: 92,
            child: OutlinedButton(
              onPressed: () {
                if (isEditable) {
                  Navigator.pushNamed(context, '/compose', arguments: proposal)
                      .then((_) {
                    if (onRefresh != null) onRefresh!();
                  });
                } else {
                  try {
                    context
                        .read<AppState>()
                        .selectProposal(Map<String, dynamic>.from(proposal));
                  } catch (_) {}
                  Navigator.pushNamed(context, '/preview', arguments: proposal)
                      .then((_) {
                    if (onRefresh != null) onRefresh!();
                  });
                }
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: const Color(0xFF4B5563),
                side: BorderSide.none,
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: const Text(
                'VIEW',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 104,
            child: ElevatedButton(
              onPressed: () async {
                final confirm = await showDialog<bool>(
                    context: context,
                    builder: (_) => AlertDialog(
                            title: const Text('Delete proposal?'),
                            content: const Text(
                                'Are you sure you want to delete this proposal?'),
                            actions: [
                              TextButton(
                                  onPressed: () =>
                                      Navigator.pop(context, false),
                                  child: const Text('Cancel')),
                              TextButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  child: const Text('Delete'))
                            ]));
                if (confirm == true) {
                  final token = AuthService.token;
                  if (token != null && token.isNotEmpty) {
                    final idVal = proposal['id'];
                    final intId = idVal is int
                        ? idVal
                        : int.tryParse(idVal.toString()) ?? 0;
                    if (intId != 0) {
                      final success = await ApiService.deleteProposal(
                          token: token, id: intId);

                      if (success) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Proposal deleted successfully'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                        if (onRefresh != null) onRefresh!();
                      } else {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                  'Failed to delete proposal. Please try again.'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    } else {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Invalid proposal ID'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    }
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content:
                            Text('Authentication required. Please log in.'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: PremiumTheme.primaryRed,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                elevation: 0,
              ),
              child: const Text(
                'DELETE',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
