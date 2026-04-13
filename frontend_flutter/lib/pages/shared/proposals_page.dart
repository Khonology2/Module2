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
        border: Border(
          bottom: BorderSide(
            color: chrome.divider,
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
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
                const SizedBox(height: 2),
                RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: 'Hello, ',
                        style: TextStyle(
                          color: chrome.textSecondary,
                          fontSize: 13,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      TextSpan(
                        text: _getUserName(app.currentUser),
                        style: TextStyle(
                          color: chrome.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
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
    return Container(
      decoration: chrome.floatingPanelDecoration(radius: 12, borderWidth: 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: _buildToolbarContent(chrome),
          ),
          Divider(height: 1, color: chrome.divider),
          Padding(
            padding: const EdgeInsets.all(24),
            child: _buildFilterPanelBody(filtered, chrome),
          ),
        ],
      ),
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
          flex: 2,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Proposals Overview',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: chrome.textPrimary)),
              const SizedBox(height: 2),
              Text("Manage all your business proposals & SOW's",
                  style: TextStyle(fontSize: 12, color: chrome.textSecondary)),
            ],
          ),
        ),
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

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: filtered.length,
      separatorBuilder: (context, index) =>
          Divider(height: 1, color: chrome.divider),
      itemBuilder: (context, index) {
        final proposal = filtered[index];
        return ProposalItem(
            proposal: proposal, onRefresh: _loadProposals, chrome: chrome);
      },
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
        statusColor = const Color(0xFF6CA510); // Green for Sent to Client
        statusBgColor = const Color(0xFF6CA510).withValues(alpha: 0.2);
        statusLabel = 'Sent to Client';
        break;
      case 'approved':
        statusColor = const Color(0xFF6CA510); // Green for Approved
        statusBgColor = const Color(0xFF6CA510).withValues(alpha: 0.2);
        statusLabel = 'Approved';
        break;
      case 'declined':
      case 'rejected':
        statusColor = PremiumTheme.error;
        statusBgColor = PremiumTheme.error.withValues(alpha: 0.2);
        statusLabel = 'Declined';
        break;
      default:
        statusColor = chrome.textMuted;
        statusBgColor = chrome.fieldFill;
        statusLabel = proposal['status'] ?? 'Unknown';
    }

    final title = proposal['title'] ?? 'Untitled Proposal';
    final clientName =
        proposal['client_name'] ?? proposal['client'] ?? 'Unknown Client';
    final description =
        proposal['description'] ?? 'Short description for detail';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                  fontSize: 14,
                  color: chrome.textPrimary,
                ),
                children: [
                  TextSpan(
                    text: title,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  TextSpan(
                    text: ' - $clientName - ',
                    style: TextStyle(color: chrome.textSecondary),
                  ),
                  TextSpan(
                    text: description,
                    style: TextStyle(color: chrome.textSecondary),
                  ),
                ],
              ),
            ),
          ),
          // Last Modified
          Expanded(
            flex: 1,
            child: Text(
              'Last Modified: ${_formatDate(proposal['updated_at'] ?? proposal['updatedAt'])}',
              style: TextStyle(
                fontSize: 13,
                color: chrome.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          // Status Badge and Actions
          Row(mainAxisSize: MainAxisSize.min, children: [
            // Status Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: statusBgColor,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                statusLabel,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: statusColor,
                ),
              ),
            ),
            const SizedBox(width: 12),
            // View Button (Gray outline)
            OutlinedButton(
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
                foregroundColor: chrome.textSecondary,
                side: BorderSide(color: chrome.divider),
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
            const SizedBox(width: 8),
            // Delete Button (Red pill)
            ElevatedButton(
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
                  // Use AuthService token (same as document editor)
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
            )
          ])
        ],
      ),
    );
  }
}
