// ignore_for_file: unused_field, unused_element, unused_local_variable, deprecated_member_use

import 'package:flutter/material.dart';
import 'dart:ui' show FontFeature;
import 'package:provider/provider.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../api.dart';
import '../../services/auth_service.dart';
import '../../services/api_service.dart';
import '../../services/asset_service.dart';
import '../../theme/premium_theme.dart';
import '../../theme/manager_theme_controller.dart';
import '../../widgets/custom_scrollbar.dart';
import '../../widgets/admin/admin_sidebar.dart';
import '../../widgets/manager_page_background.dart';
import 'package:intl/intl.dart';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

class ApproverDashboardPage extends StatefulWidget {
  const ApproverDashboardPage({super.key});

  @override
  State<ApproverDashboardPage> createState() => _ApproverDashboardPageState();
}

class _ApproverDashboardPageState extends State<ApproverDashboardPage>
    with TickerProviderStateMixin {
  List<Map<String, dynamic>> _pendingApprovals = [];
  bool _isLoading = true;
  final ScrollController _scrollController = ScrollController();
  final NumberFormat _currencyFormatter =
      NumberFormat.currency(symbol: 'R', decimalDigits: 0);
  late AnimationController _animationController;
  int _highRiskCount = 0;
  int _approvedThisMonthCount = 0;
  int _sentToClientCount = 0;
  int _clientApprovedCount = 0;

  List<Map<String, dynamic>> _combinedProposals = [];
  List<Map<String, dynamic>> _attentionBlocked = [];
  List<Map<String, dynamic>> _attentionDelayed = [];
  List<Map<String, dynamic>> _attentionNeedsApproval = [];
  List<Map<String, dynamic>> _attentionAwaitingSignature = [];
  List<Map<String, dynamic>> _attentionRecentlySigned = [];
  int _attentionBlockedTotal = 0;
  int _attentionDelayedTotal = 0;
  int _attentionNeedsApprovalTotal = 0;
  int _attentionAwaitingSignatureTotal = 0;
  int _attentionRecentlySignedTotal = 0;
  Map<String, int> _riskReasons = {};
  int _draftCount = 0;
  int _reviewCount = 0;
  int _releasedCount = 0;
  int _signedCount = 0;

  bool _isSidebarCollapsed = false;
  String _currentPage = 'Dashboard';

  /// Matches manager dashboard metric cards (visual + tap feedback).
  int _selectedMetricIndex = 0;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _animationController.value = 1.0;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _enforceAccessAndLoad();
      if (!mounted) return;
      context.read<AppState>().setAdminNavLabel('Dashboard');
      context.read<AppState>().fetchNotifications();
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _enforceAccessAndLoad() async {
    final userRole =
        AuthService.currentUser?['role']?.toString().toLowerCase() ?? 'manager';

    // Only allow admin/CEO users to access this dashboard
    if (userRole != 'admin' && userRole != 'ceo') {
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed('/creator_dashboard');
      return;
    }

    await _loadData();
  }

  Future<void> _loadData() async {
    print('🔄 Approver Dashboard: Loading data...');
    if (!mounted) return;

    setState(() => _isLoading = true);

    try {
      print('🔄 Restoring session from storage...');
      AuthService.restoreSessionFromStorage();

      var token = AuthService.token;
      print('🔑 After restore - Token available: ${token != null}');
      print('🔑 After restore - User: ${AuthService.currentUser?['email']}');
      print('🔑 After restore - isLoggedIn: ${AuthService.isLoggedIn}');

      if (token == null) {
        print(
            '⚠️ Token still null after restore, checking localStorage directly...');
        try {
          final data = html.window.localStorage['lukens_auth_session'];
          print('📦 localStorage data exists: ${data != null}');
          if (data != null) {
            print('📦 localStorage content: ${data.substring(0, 50)}...');
          }
        } catch (e) {
          print('❌ Error accessing localStorage: $e');
        }

        await Future.delayed(const Duration(milliseconds: 500));
        token = AuthService.token;
      }

      if (token == null) {
        print('❌ No token available after restoration attempts');
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                  '⚠️ Session expired. Please switch back to Creator mode.'),
              backgroundColor: Colors.orange,
              action: SnackBarAction(
                label: 'Retry',
                textColor: Colors.white,
                onPressed: () => _loadData(),
              ),
            ),
          );
        }
        return;
      }

      print('📡 Fetching proposals from API...');

      // Fetch pending approvals
      print(
          '🌐 Fetching pending approvals from: ${ApiService.baseUrl}/api/proposals/pending_approval');
      final pendingResponse = await http.get(
        Uri.parse('${ApiService.baseUrl}/api/proposals/pending_approval'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(
        const Duration(seconds: 45),
        onTimeout: () {
          print('⏱️ Timeout! Pending approvals API call took too long');
          throw Exception('Request timed out');
        },
      );

      List<Map<String, dynamic>> pending = [];
      if (pendingResponse.statusCode == 200) {
        final pendingData = json.decode(pendingResponse.body);
        pending = (pendingData['proposals'] as List? ?? [])
            .map((p) => Map<String, dynamic>.from(p))
            .toList();
        print('✅ Pending approvals received: ${pending.length}');
      } else {
        print(
            '⚠️ Failed to fetch pending approvals: ${pendingResponse.statusCode}');
      }

      int highRiskCount = 0;
      int approvedThisMonthCount = 0;
      int sentToClientCount = 0;
      int clientApprovedCount = 0;
      List<Map<String, dynamic>> combinedForDashboard = [];

      try {
        List<Map<String, dynamic>> allProposals = [];

        try {
          final allResponse = await http.get(
            Uri.parse('${ApiService.baseUrl}/api/proposals/all'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
          );

          if (allResponse.statusCode == 200) {
            final decoded = json.decode(allResponse.body);
            final items =
                (decoded is Map ? decoded['proposals'] : null) as List?;
            allProposals = (items ?? [])
                .whereType<Map>()
                .map((p) => Map<String, dynamic>.from(p))
                .toList();
          }
        } catch (_) {
          // Fall through to AppState fallback
        }

        if (allProposals.isEmpty) {
          final appState = context.read<AppState>();
          await appState.fetchProposals();
          allProposals = List<Map<String, dynamic>>.from(
            (appState.proposals)
                .whereType<Map>()
                .map((p) => Map<String, dynamic>.from(p)),
          );
        }
        final now = DateTime.now();
        final startOfMonth = DateTime(now.year, now.month, 1);
        final startOfNextMonth = now.month == 12
            ? DateTime(now.year + 1, 1, 1)
            : DateTime(now.year, now.month + 1, 1);

        // Combine pending approvals and general proposals into a single list
        // so that admins who don't author proposals still see recent items.
        final List<Map<String, dynamic>> combined = [];
        final Set<String> seenIds = {};

        void addCombined(Map<String, dynamic> proposal) {
          final id = proposal['id']?.toString();
          if (id != null) {
            if (seenIds.contains(id)) return;
            seenIds.add(id);
          }
          combined.add(proposal);
        }

        // Seed with pending approvals from the dedicated endpoint
        for (final proposal in pending) {
          addCombined(Map<String, dynamic>.from(proposal));
        }

        // Add any additional proposals returned by /api/proposals
        for (final raw in allProposals) {
          addCombined(Map<String, dynamic>.from(raw));
        }

        // Compute dashboard metrics from the combined set
        for (final proposal in combined) {
          final riskScore = _extractRiskScore(proposal);
          final riskLevel = _extractRiskLevel(proposal);
          if (_isHighRisk(riskScore: riskScore, riskLevel: riskLevel)) {
            highRiskCount++;
          }

          dynamic rawStatus(dynamic p) {
            if (p is! Map) return null;
            return p['status'] ??
                p['proposal_status'] ??
                p['approval_status'] ??
                p['state'] ??
                p['stage'];
          }

          String normalizeStatus(dynamic value) {
            return (value ?? '')
                .toString()
                .trim()
                .toLowerCase()
                .replaceAll('_', ' ');
          }

          final status = normalizeStatus(rawStatus(proposal));

          final isSentToClient = status.contains('released') ||
              status.contains('release') ||
              status == 'sent' ||
              status.contains('sent to client') ||
              status.contains('client sent') ||
              status.contains('shared');
          if (isSentToClient) {
            sentToClientCount++;
          }

          final isClientApproved = status == 'signed' ||
              status == 'client signed' ||
              status == 'client approved' ||
              status == 'approved' ||
              status == 'completed';
          if (isClientApproved) {
            clientApprovedCount++;
          }

          final isApproved = isClientApproved ||
              isSentToClient ||
              status.contains('sent for signature') ||
              status.contains('out for signature');
          if (isApproved) {
            final updatedRaw = proposal['updated_at'] ?? proposal['updatedAt'];
            final updatedAt = _parseDate(updatedRaw);
            if (updatedAt != null &&
                !updatedAt.isBefore(startOfMonth) &&
                updatedAt.isBefore(startOfNextMonth)) {
              approvedThisMonthCount++;
            }
          }
        }

        combinedForDashboard = List<Map<String, dynamic>>.from(combined);
      } catch (e) {
        print('⚠️ Error computing approver metrics: $e');
      }

      if (mounted) {
        setState(() {
          _pendingApprovals = pending;
          _highRiskCount = highRiskCount;
          _approvedThisMonthCount = approvedThisMonthCount;
          _sentToClientCount = sentToClientCount;
          _clientApprovedCount = clientApprovedCount;
          _combinedProposals = combinedForDashboard;
          _isLoading = false;
        });

        _computeOperationsModel();
      }
    } catch (e, stackTrace) {
      print('❌ Error loading approver data: $e');
      print('Stack trace: $stackTrace');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading data: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final chrome = context.watch<ManagerThemeController>().chrome;
    final size = MediaQuery.sizeOf(context);
    // Two-column structure (left: CEO + pending | right: Recent) — do not tie to "compact".
    final useTwoColumnLayout = size.width >= 1000;
    final compact = size.height < 860 || size.width < 720;

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton(
        heroTag: 'admin_dashboard_theme_toggle',
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
      body: ManagerPageBackground(
        child: SafeArea(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AdminSidebar(
                isCollapsed: app.isAdminSidebarCollapsed,
                currentPage: _currentPage,
                managerChrome: chrome,
                onToggle: () => context.read<AppState>().toggleAdminSidebar(),
                onSelect: (label) {
                  setState(() => _currentPage = label);
                  _navigateToPage(label);
                },
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildManagerStyleHeader(app, chrome),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                        child: CustomScrollbar(
                          controller: _scrollController,
                          child: SingleChildScrollView(
                            controller: _scrollController,
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.only(bottom: 16),
                            child: _buildDashboardBody(
                              app,
                              chrome,
                              compact,
                              useTwoColumnLayout: useTwoColumnLayout,
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
    );
  }

  Widget _buildDashboardBody(
    AppState app,
    ManagerChromeTheme chrome,
    bool compact, {
    required bool useTwoColumnLayout,
  }) {
    final leftColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildHeroSection(chrome, useFigmaSizes: useTwoColumnLayout),
        SizedBox(height: compact ? 16 : 24),
        _buildSection(
          chrome,
          'Proposals Pending Your Approval',
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _buildPendingApprovalsList(chrome),
          titleIconAsset:
              'assets/images/Admin_new_icons/Proposal_Pending_Your_Approvals.png',
          titleBadge: _pendingApprovals.length,
          useFigmaSizes: useTwoColumnLayout,
          showHeaderListDivider: true,
        ),
      ],
    );

    final rightColumn = _buildRecentProposalsPanel(
      chrome,
      stretchTable: useTwoColumnLayout,
      useFigmaSizes: useTwoColumnLayout,
    );

    final belowTwoCol = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(height: compact ? 16 : 24),
        _buildSection(
            chrome, 'Pipeline Health', _buildPipelineHealthInline(chrome)),
        SizedBox(height: compact ? 16 : 24),
        _buildSection(
          chrome,
          'What Needs Attention',
          _buildWhatNeedsAttentionInline(chrome),
        ),
      ],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildFourStatCardsRow(chrome),
        SizedBox(height: compact ? 16 : 24),
        if (useTwoColumnLayout)
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  flex: 11,
                  child: leftColumn,
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 9,
                  child: rightColumn,
                ),
              ],
            ),
          )
        else ...[
          leftColumn,
          SizedBox(height: compact ? 16 : 24),
          rightColumn,
        ],
        belowTwoCol,
      ],
    );
  }

  Widget _buildStatusPill(ManagerChromeTheme chrome, String status) {
    final lower = status.toLowerCase();
    Color bg;
    Color fg;

    if (lower.contains('pending')) {
      bg = PremiumTheme.orange.withOpacity(0.15);
      fg = PremiumTheme.orange;
    } else if (lower.contains('approved') || lower.contains('signed')) {
      bg = PremiumTheme.success.withOpacity(0.15);
      fg = PremiumTheme.success;
    } else if (lower.contains('rejected') ||
        lower.contains('declined') ||
        lower.contains('lost')) {
      bg = PremiumTheme.error.withOpacity(0.15);
      fg = PremiumTheme.error;
    } else {
      bg = chrome.isDark
          ? Colors.white.withOpacity(0.08)
          : Colors.black.withOpacity(0.06);
      fg = chrome.textMuted;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: fg,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  String _getUserName(Map<String, dynamic>? user) {
    if (user == null) return 'User';
    final name = user['full_name'] ??
        user['first_name'] ??
        user['name'] ??
        user['email']?.toString().split('@').first;
    return (name ?? 'User').toString();
  }

  static bool _notificationIsCommentMessage(Map<String, dynamic> n) {
    final t =
        (n['notification_type'] ?? n['type'] ?? '').toString().toLowerCase();
    return t.contains('comment') || t == 'mentioned' || t.contains('mention');
  }

  static Map<String, dynamic> _asNotificationMap(dynamic raw) {
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) {
      try {
        return raw.cast<String, dynamic>();
      } catch (_) {
        return <String, dynamic>{};
      }
    }
    return <String, dynamic>{};
  }

  int _unreadNotificationCount(AppState app, {required bool messagesOnly}) {
    var n = 0;
    for (final raw in app.notifications) {
      final item = _asNotificationMap(raw);
      if (item.isEmpty) continue;
      final isComment = _notificationIsCommentMessage(item);
      if (messagesOnly != isComment) continue;
      if (item['is_read'] != true) n++;
    }
    return n;
  }

  List<Map<String, dynamic>> _notificationsFiltered(
    AppState app, {
    required bool messagesOnly,
  }) {
    final out = <Map<String, dynamic>>[];
    for (final raw in app.notifications) {
      final item = _asNotificationMap(raw);
      if (item.isEmpty) continue;
      if (messagesOnly != _notificationIsCommentMessage(item)) continue;
      out.add(item);
    }
    return out;
  }

  Widget _buildManagerHeaderIconButton({
    required ManagerChromeTheme chrome,
    required String assetPath,
    required VoidCallback onTap,
    int? badge,
  }) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            width: 64,
            height: 64,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: chrome.floatingFill,
              shape: BoxShape.circle,
              border: Border.all(
                color: chrome.isDark
                    ? Colors.white.withValues(alpha: 0.90)
                    : ManagerChromeTheme.textDark.withValues(alpha: 0.20),
                width: 2,
              ),
            ),
            child: Image.asset(assetPath, fit: BoxFit.contain),
          ),
        ),
        if (badge != null && badge > 0)
          Positioned(
            right: 2,
            top: 2,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: const BoxDecoration(
                color: Color(0xFFC10D00),
                borderRadius: BorderRadius.all(Radius.circular(10)),
              ),
              child: Text(
                badge > 99 ? '99+' : badge.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildNotificationButton(AppState app, ManagerChromeTheme chrome) {
    final unread = _unreadNotificationCount(app, messagesOnly: false);
    return _buildManagerHeaderIconButton(
      chrome: chrome,
      assetPath: 'assets/images/new icons for manager/notifications.png',
      badge: unread > 0 ? unread : null,
      onTap: () async {
        await app.fetchNotifications();
        if (!mounted) return;
        _showNotificationsSheet(app, messagesOnly: false);
      },
    );
  }

  void _showNotificationsSheet(AppState app, {bool messagesOnly = false}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (bottomSheetContext) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(bottomSheetContext).viewInsets.bottom,
          ),
          child: StatefulBuilder(
            builder: (context, setModalState) {
              final notifications =
                  _notificationsFiltered(app, messagesOnly: messagesOnly);
              final unreadCount =
                  _unreadNotificationCount(app, messagesOnly: messagesOnly);

              Future<void> markAllInSheet() async {
                for (final n
                    in List<Map<String, dynamic>>.from(notifications)) {
                  if (n['is_read'] == true) continue;
                  final idRaw = n['id'];
                  final id = idRaw is int
                      ? idRaw
                      : int.tryParse(idRaw?.toString() ?? '');
                  if (id != null) await app.markNotificationRead(id);
                }
                await app.fetchNotifications();
                if (context.mounted) setModalState(() {});
              }

              Future<void> deleteAllInSheet() async {
                for (final n
                    in List<Map<String, dynamic>>.from(notifications)) {
                  final idRaw = n['id'];
                  final id = idRaw is int
                      ? idRaw
                      : int.tryParse(idRaw?.toString() ?? '');
                  if (id != null) await app.deleteNotification(id);
                }
                await app.fetchNotifications();
                if (context.mounted) setModalState(() {});
              }

              return Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.7,
                ),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 16,
                      ),
                      decoration: const BoxDecoration(
                        color: Color(0xFF2C3E50),
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(10),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            messagesOnly ? 'Messages' : 'Notifications',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          Row(
                            children: [
                              if (unreadCount > 0)
                                TextButton(
                                  onPressed: () async {
                                    await markAllInSheet();
                                  },
                                  style: TextButton.styleFrom(
                                    foregroundColor: Colors.white,
                                  ),
                                  child: const Text(
                                    'Mark all read',
                                    style: TextStyle(fontSize: 12),
                                  ),
                                ),
                              TextButton(
                                onPressed: notifications.isEmpty
                                    ? null
                                    : () async {
                                        await deleteAllInSheet();
                                      },
                                style: TextButton.styleFrom(
                                  foregroundColor: Colors.red.shade200,
                                ),
                                child: const Text(
                                  'Delete all',
                                  style: TextStyle(fontSize: 12),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.close,
                                    color: Colors.white),
                                onPressed: () => Navigator.of(context).pop(),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (notifications.isEmpty)
                      Expanded(
                        child: Center(
                          child: Text(
                            messagesOnly
                                ? 'No comment messages yet.'
                                : 'No notifications yet.',
                            style: const TextStyle(
                              color: Color(0xFF4A4A4A),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      )
                    else
                      Expanded(
                        child: ListView.separated(
                          padding: const EdgeInsets.symmetric(
                            vertical: 12,
                            horizontal: 16,
                          ),
                          itemCount: notifications.length,
                          separatorBuilder: (_, __) =>
                              const Divider(height: 16),
                          itemBuilder: (context, index) {
                            final notification = notifications[index];
                            final title =
                                notification['title']?.toString().trim();
                            final message =
                                notification['message']?.toString().trim() ??
                                    '';
                            final proposalTitle = notification['proposal_title']
                                ?.toString()
                                .trim();
                            final isRead = notification['is_read'] == true;
                            final timeLabel = _formatNotificationTimestamp(
                              notification['created_at'],
                            );
                            final dynamic notificationIdRaw =
                                notification['id'];
                            final int? notificationId = notificationIdRaw is int
                                ? notificationIdRaw
                                : int.tryParse(
                                    notificationIdRaw?.toString() ?? '',
                                  );

                            return ListTile(
                              onTap: () async {
                                Navigator.of(bottomSheetContext).pop();
                                await _handleNotificationTap(
                                  app,
                                  notification,
                                  notificationId: notificationId,
                                  isAlreadyRead: isRead,
                                );
                              },
                              leading: Icon(
                                messagesOnly
                                    ? (isRead
                                        ? Icons.chat_bubble_outline
                                        : Icons.mark_chat_unread_outlined)
                                    : (isRead
                                        ? Icons.notifications_none_outlined
                                        : Icons.notifications_active),
                                color: isRead
                                    ? const Color(0xFF95A5A6)
                                    : const Color(0xFF3498DB),
                              ),
                              title: Text(
                                title?.isNotEmpty == true
                                    ? title!
                                    : 'Notification',
                                style: TextStyle(
                                  color: const Color(0xFF2C3E50),
                                  fontWeight: isRead
                                      ? FontWeight.w600
                                      : FontWeight.w700,
                                ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (message.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Text(
                                        message,
                                        style: const TextStyle(
                                          color: Color(0xFF4A4A4A),
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  if (proposalTitle != null &&
                                      proposalTitle.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Text(
                                        proposalTitle,
                                        style: const TextStyle(
                                          color: Color(0xFF7F8C8D),
                                          fontSize: 11,
                                        ),
                                      ),
                                    ),
                                  if (timeLabel.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Text(
                                        timeLabel,
                                        style: const TextStyle(
                                          color: Color(0xFF95A5A6),
                                          fontSize: 11,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              isThreeLine: true,
                              trailing: !isRead && notificationId != null
                                  ? Wrap(
                                      spacing: 4,
                                      children: [
                                        TextButton(
                                          onPressed: () async {
                                            await app.markNotificationRead(
                                                notificationId);
                                            setModalState(() {});
                                          },
                                          child: const Text('Mark read'),
                                        ),
                                        IconButton(
                                          tooltip: 'Delete',
                                          onPressed: () async {
                                            await app.deleteNotification(
                                                notificationId);
                                            setModalState(() {});
                                          },
                                          icon: const Icon(
                                            Icons.delete_outline,
                                            size: 18,
                                            color: Colors.redAccent,
                                          ),
                                        ),
                                      ],
                                    )
                                  : (notificationId != null
                                      ? IconButton(
                                          tooltip: 'Delete',
                                          onPressed: () async {
                                            await app.deleteNotification(
                                                notificationId);
                                            setModalState(() {});
                                          },
                                          icon: const Icon(
                                            Icons.delete_outline,
                                            size: 18,
                                            color: Colors.redAccent,
                                          ),
                                        )
                                      : null),
                            );
                          },
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Map<String, dynamic> _parseNotificationMetadata(dynamic raw) {
    if (raw == null) return <String, dynamic>{};
    if (raw is Map<String, dynamic>) {
      return Map<String, dynamic>.from(raw);
    }
    if (raw is Map) {
      try {
        return raw.cast<String, dynamic>();
      } catch (_) {
        return <String, dynamic>{};
      }
    }
    if (raw is String && raw.isNotEmpty) {
      try {
        final decoded = json.decode(raw);
        if (decoded is Map) {
          return decoded.cast<String, dynamic>();
        }
      } catch (e) {
        debugPrint('⚠️ Failed to decode notification metadata: $e');
      }
    }
    return <String, dynamic>{};
  }

  int? _asInt(dynamic value) {
    if (value is int) return value;
    if (value is String && value.trim().isNotEmpty) {
      return int.tryParse(value.trim());
    }
    return null;
  }

  String? _asIdString(dynamic value) {
    if (value == null) return null;
    if (value is String) {
      final trimmed = value.trim();
      if (trimmed.isEmpty || trimmed.toLowerCase() == 'null') {
        return null;
      }
      return trimmed;
    }
    return value.toString();
  }

  Future<void> _handleNotificationTap(
    AppState app,
    Map<String, dynamic> notification, {
    int? notificationId,
    bool isAlreadyRead = false,
  }) async {
    final metadata = _parseNotificationMetadata(notification['metadata']);
    String? proposalId = _asIdString(
      metadata['proposal_id'] ?? notification['proposal_id'],
    );
    proposalId ??= _asIdString(metadata['resource_id']);
    final proposalTitle =
        notification['proposal_title']?.toString().trim().isNotEmpty == true
            ? notification['proposal_title'].toString().trim()
            : notification['title']?.toString().trim();

    if (notificationId != null && !isAlreadyRead) {
      try {
        await app.markNotificationRead(notificationId);
      } catch (e) {
        debugPrint('⚠️ Failed to mark notification as read: $e');
      }
    }

    if (!mounted) return;

    if (proposalId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This notification is missing proposal details.'),
        ),
      );
      return;
    }

    final args = <String, dynamic>{
      'proposalId': proposalId,
      if (proposalTitle != null && proposalTitle.isNotEmpty)
        'proposalTitle': proposalTitle,
    };
    final sectionIndex = _asInt(metadata['section_index']);
    final commentId = _asInt(metadata['comment_id']);
    if (sectionIndex != null) {
      args['initialSectionIndex'] = sectionIndex;
    }
    if (commentId != null) {
      args['initialCommentId'] = commentId;
    }

    Navigator.of(context).pushNamed('/blank-document', arguments: args);
  }

  Widget _buildManagerStyleHeader(AppState app, ManagerChromeTheme chrome) {
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
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _buildAdminDashboardTitle(chrome),
                const SizedBox(width: 16),
                Expanded(
                  child: RichText(
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    text: TextSpan(
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 13,
                      ),
                      children: [
                        TextSpan(
                          text: 'Hello, ',
                          style: TextStyle(
                            color: chrome.textSecondary,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                        TextSpan(
                          text: _getUserName(app.currentUser),
                          style: TextStyle(
                            color: chrome.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          _buildManagerHeaderIconButton(
            chrome: chrome,
            assetPath: 'assets/images/new icons for manager/messages.png',
            badge: _unreadNotificationCount(app, messagesOnly: true) > 0
                ? _unreadNotificationCount(app, messagesOnly: true)
                : null,
            onTap: () async {
              await app.fetchNotifications();
              if (!mounted) return;
              _showNotificationsSheet(app, messagesOnly: true);
            },
          ),
          const SizedBox(width: 8),
          _buildNotificationButton(app, chrome),
        ],
      ),
    );
  }

  String _formatNotificationTimestamp(dynamic raw) {
    if (raw == null) return '';
    final value = raw.toString().trim();
    if (value.isEmpty) return '';
    final dt = DateTime.tryParse(value);
    if (dt == null) return value;
    final local = dt.toLocal();
    final diff = DateTime.now().difference(local);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat('MMM d, y • HH:mm').format(local);
  }

  static const Color _cardAccent = Color(0xFFC10D00);
  static const Color _adminBase = Color(0xFF252525);

  /// Proposals-pending row: design spec (Figma).
  static const double _pendingPillRadius = 26.06;
  static const EdgeInsets _pendingPillPadding =
      EdgeInsets.fromLTRB(15.69, 11.77, 15.69, 11.77);
  static const double _pendingPillGap = 7.84;

  /// Figma: REVIEW / APPROVE / REJECT in each pending-approval row (fixed pill box).
  static const double _figmaPendingRowActionH = 23;
  static const double _figmaPendingRowReviewW = 58;
  static const double _figmaPendingRowApproveW = 68;
  static const double _figmaPendingRowRejectW = 68;

  /// Figma "Line 23": divider between pending-approval rows.
  static const double _figmaPendingListDividerThickness = 0.61;
  static const double _figmaPendingListRowIconSize = 22;
  static const String _assetPendingApprovalRowIcon =
      'assets/images/Admin_new_icons/Group522.png';
  /// Section header bell (Proposals Pending Your Approval) — from Figma asset.
  static const String _assetSectionNotificationBell =
      'assets/images/Admin_new_icons/Group3988.png';
  static const double _headerActionPillWidth = 68;
  static const Color _pendingReviewBg = Color(0xFF7F7F7F);
  static const Color _pendingApproveBg = Color(0xFF6CA510);
  static const Color _pendingRejectBg = Color(0xFFC10D00);

  /// Figma: primary line in each pending-approval row ("Name - Short description").
  static const double _figmaPendingRowTitleSize = 9.22;
  static const double _figmaPendingRowTitleLineHeight = 9.38;

  /// Figma admin left/right panel boxes (wide layout).
  static const double _figmaAdminPanelRadius = 5.32;
  static const double _figmaCeoPanelW = 468.9003296495665;
  static const double _figmaCeoPanelH = 80.59740449431575;
  static const double _figmaPendingSectionW = 468.1190185732919;
  static const double _figmaPendingSectionH = 312.6899721020658;
  static const double _figmaRecentPanelW = 468.9003296495665;
  static const double _figmaRecentPanelH = 404.86380012083833;

  TextStyle _pendingApprovalRowTitleStyle(ManagerChromeTheme chrome) {
    return TextStyle(
      color: chrome.textPrimary,
      fontFamily: 'Poppins',
      fontSize: _figmaPendingRowTitleSize,
      fontWeight: FontWeight.w700,
      height: _figmaPendingRowTitleLineHeight / _figmaPendingRowTitleSize,
      letterSpacing: _figmaPendingRowTitleSize * 0.01,
      fontFeatures: const [FontFeature.enable('smcp')],
    );
  }

  Widget _buildDarkGlass({
    required ManagerChromeTheme chrome,
    required Widget child,
    double borderRadius = 24,
    EdgeInsets padding = const EdgeInsets.all(20),
  }) {
    return Container(
      padding: padding,
      decoration: chrome.floatingPanelDecoration(radius: borderRadius),
      child: child,
    );
  }

  /// Mock: coloured asset on a **white** disc (CEO / section / Recent Proposals).
  /// Inset kept small so the glyph fills the ring like Figma (not dominated by white).
  Widget _buildAdminPanelWhiteIconRing({
    required ManagerChromeTheme chrome,
    required Widget child,
    double diameter = 80,
  }) {
    final pad = diameter * 0.07;
    return Container(
      width: diameter,
      height: diameter,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(
          color: chrome.isDark
              ? Colors.white.withOpacity(0.22)
              : Colors.black.withOpacity(0.08),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(chrome.isDark ? 0.32 : 0.10),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: EdgeInsets.all(pad),
      child: child,
    );
  }

  Widget _buildAdminDashboardTitle(ManagerChromeTheme chrome) {
    final base = TextStyle(
      color: chrome.textPrimary,
      fontSize: 20,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.2,
      fontFamily: 'Poppins',
    );
    return Text(
      'Admin Dashboard',
      style: base,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  /// Mock: bell in white circle + red count badge.
  Widget _buildSectionBellCountBadge(
    int count,
    ManagerChromeTheme chrome, {
    double size = 48,
  }) {
    // Large fraction of the white disc so the raster reads clearly (inscribed square ~70% of ⌀).
    final iconSize = (size * 0.72).clamp(24.0, 40.0);
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: chrome.divider),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(chrome.isDark ? 0.28 : 0.08),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: ClipOval(
              child: SizedBox(
                width: iconSize,
                height: iconSize,
                child: Image.asset(
                  _assetSectionNotificationBell,
                  fit: BoxFit.contain,
                  alignment: Alignment.center,
                ),
              ),
            ),
          ),
          Positioned(
            right: -4,
            top: -4,
            child: Container(
              constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: _pendingRejectBg,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              alignment: Alignment.center,
              child: Text(
                count > 99 ? '99+' : '$count',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Same layout / icon sizing as [CreatorDashboardPage._buildStatCard].
  Widget _buildManagerStyleMetricCard(
    ManagerChromeTheme chrome, {
    required String title,
    required String value,
    required String subtitle,
    required String iconAsset,
    required int metricIndex,
    VoidCallback? onTap,
  }) {
    final showBlue = _selectedMetricIndex == metricIndex;
    return InkWell(
      onTap: () {
        setState(() => _selectedMetricIndex = metricIndex);
        onTap?.call();
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: chrome.floatingFill,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color:
                showBlue ? ManagerChromeTheme.leftAccentBlue : chrome.divider,
            width: showBlue ? 2 : 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: chrome.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Poppins',
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: chrome.textSecondary,
                      fontSize: 10,
                      height: 1.3,
                      fontFamily: 'Poppins',
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    value,
                    style: TextStyle(
                      color: chrome.textPrimary,
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      height: 1,
                      fontFamily: 'Poppins',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                color: const Color(0xFFC10D00).withValues(alpha: 0.15),
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFFC10D00).withValues(alpha: 0.30),
                  width: 1,
                ),
              ),
              padding: const EdgeInsets.all(14),
              child: Image.asset(iconAsset, fit: BoxFit.contain),
            ),
          ],
        ),
      ),
    );
  }

  void _navigateMetricFilter(int index) {
    switch (index) {
      case 0:
        Navigator.pushNamed(
          context,
          '/admin_approvals',
          arguments: const {'initialFilter': 'ready'},
        );
        break;
      case 1:
        Navigator.pushNamed(
          context,
          '/admin_approvals',
          arguments: const {
            'initialFilter': 'all',
            'minRiskScore': 70,
          },
        );
        break;
      case 2:
        Navigator.pushNamed(
          context,
          '/admin_approvals',
          arguments: const {
            'initialFilter': 'approved',
            'pipelineStage': 'released_awaiting_signature',
          },
        );
        break;
      case 3:
        Navigator.pushNamed(
          context,
          '/admin_approvals',
          arguments: const {
            'initialFilter': 'approved',
            'pipelineStage': 'recently_signed',
            'recentDays': 365,
          },
        );
        break;
    }
  }

  Widget _buildFourStatCardsRow(ManagerChromeTheme chrome) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;

        Widget card(
          int metricIndex,
          String title,
          String val,
          String sub,
          String asset,
        ) {
          return _buildManagerStyleMetricCard(
            chrome,
            title: title,
            value: val,
            subtitle: sub,
            iconAsset: asset,
            metricIndex: metricIndex,
            onTap: () => _navigateMetricFilter(metricIndex),
          );
        }

        final c1 = card(
          0,
          'Pending Approvals',
          _pendingApprovals.length.toString(),
          'Awaiting review',
          'assets/images/Admin_new_icons/Pending_Approvals.png',
        );
        final c2 = card(
          1,
          'High-Risk Items',
          _highRiskCount.toString(),
          'Flagged by risk analysis',
          'assets/images/Admin_new_icons/High_Risk_Items.png',
        );
        final c3 = card(
          2,
          'Sent to Client',
          _sentToClientCount.toString(),
          'Released to client',
          'assets/images/Admin_new_icons/Sent_to_client.png',
        );
        final c4 = card(
          3,
          'Client Approved',
          _clientApprovedCount.toString(),
          'Signature provided',
          'assets/images/Admin_new_icons/Client_Approved.png',
        );

        if (w >= 1000) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: c1),
              const SizedBox(width: 12),
              Expanded(child: c2),
              const SizedBox(width: 12),
              Expanded(child: c3),
              const SizedBox(width: 12),
              Expanded(child: c4),
            ],
          );
        }
        if (w >= 520) {
          return Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: c1),
                  const SizedBox(width: 12),
                  Expanded(child: c2),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: c3),
                  const SizedBox(width: 12),
                  Expanded(child: c4),
                ],
              ),
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            c1,
            const SizedBox(height: 12),
            c2,
            const SizedBox(height: 12),
            c3,
            const SizedBox(height: 12),
            c4,
          ],
        );
      },
    );
  }

  Widget _buildHeroSection(
    ManagerChromeTheme chrome, {
    bool useFigmaSizes = false,
  }) {
    final compact = MediaQuery.sizeOf(context).height < 860;
    final iconDiameter = useFigmaSizes ? 48.0 : 72.0;
    final pad = useFigmaSizes
        ? const EdgeInsets.symmetric(horizontal: 10, vertical: 6)
        : EdgeInsets.all(compact ? 18 : 24);
    final titleSize = useFigmaSizes ? 16.0 : (compact ? 18.0 : 20.0);
    final subtitleSize = useFigmaSizes ? 11.5 : 13.0;

    final inner = _buildDarkGlass(
      chrome: chrome,
      borderRadius: useFigmaSizes ? _figmaAdminPanelRadius : 24,
      padding: pad,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _buildAdminPanelWhiteIconRing(
            chrome: chrome,
            diameter: iconDiameter,
            child: Image.asset(
              'assets/images/Admin_new_icons/Pending_CEO_Approval.png',
              fit: BoxFit.contain,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Pending CEO Approval',
                  style: TextStyle(
                    color: chrome.textPrimary,
                    fontSize: titleSize,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'Poppins',
                  ),
                ),
                SizedBox(height: useFigmaSizes ? 4 : 6),
                Text(
                  'Proposals Awaiting your Review & Approval:',
                  style: TextStyle(
                    color: chrome.textSecondary,
                    fontSize: subtitleSize,
                    fontFamily: 'Poppins',
                  ),
                ),
                if (_pendingApprovals.isEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    'No proposals pending your approval.',
                    style: TextStyle(
                      color: chrome.textMuted,
                      fontSize: 12,
                      fontFamily: 'Poppins',
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (_pendingApprovals.isNotEmpty) ...[
            SizedBox(width: useFigmaSizes ? 6 : 8),
            Container(
              width: useFigmaSizes ? 36 : 44,
              height: useFigmaSizes ? 36 : 44,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: chrome.divider),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black
                        .withValues(alpha: chrome.isDark ? 0.25 : 0.08),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: Text(
                '${_pendingApprovals.length}',
                style: TextStyle(
                  color: ManagerChromeTheme.textDark,
                  fontSize: useFigmaSizes ? 14 : 16,
                  fontWeight: FontWeight.w800,
                  fontFamily: 'Poppins',
                ),
              ),
            ),
          ],
          SizedBox(width: useFigmaSizes ? 6 : 8),
          _buildRedRejectStylePill(
            label: 'ACTION',
            width: _headerActionPillWidth,
            onTap: () {
              setState(() => _currentPage = 'Approvals');
              _navigateToPage('Approvals');
            },
          ),
        ],
      ),
    );

    if (useFigmaSizes) {
      return SizedBox(
        width: _figmaCeoPanelW,
        height: _figmaCeoPanelH,
        child: inner,
      );
    }
    return inner;
  }

  Widget _buildRecentProposalsPanel(
    ManagerChromeTheme chrome, {
    bool stretchTable = false,
    bool useFigmaSizes = false,
  }) {
    final compact = MediaQuery.sizeOf(context).height < 860;
    final sorted = List<Map<String, dynamic>>.from(_combinedProposals);
    sorted.sort((a, b) {
      final da = _parseDate(a['updated_at'] ?? a['updatedAt']);
      final db = _parseDate(b['updated_at'] ?? b['updatedAt']);
      return (db ?? DateTime(1970)).compareTo(da ?? DateTime(1970));
    });
    final rows = sorted.take(10).toList();

    final radius = useFigmaSizes ? _figmaAdminPanelRadius : 24.0;
    final pad = useFigmaSizes
        ? const EdgeInsets.all(12)
        : EdgeInsets.all(compact ? 16 : 20);
    final headerIconDiameter = useFigmaSizes ? 52.0 : 72.0;

    Widget inner = _buildDarkGlass(
      chrome: chrome,
      borderRadius: radius,
      padding: pad,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildAdminPanelWhiteIconRing(
                chrome: chrome,
                diameter: headerIconDiameter,
                child: Image.asset(
                  'assets/images/Admin_new_icons/Recent_Proposals.png',
                  fit: BoxFit.contain,
                ),
              ),
              SizedBox(width: useFigmaSizes ? 10 : 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Recent Proposals',
                      style: TextStyle(
                        color: chrome.textPrimary,
                        fontSize: useFigmaSizes ? 14 : 15,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'Poppins',
                      ),
                    ),
                    SizedBox(height: useFigmaSizes ? 3 : 4),
                    Text(
                      'Additional description information can be added.',
                      style: TextStyle(
                        color: chrome.textMuted,
                        fontSize: useFigmaSizes ? 10 : 11,
                        height: 1.35,
                        fontFamily: 'Poppins',
                      ),
                    ),
                  ],
                ),
              ),
              _buildRedRejectStylePill(
                label: 'VIEW ALL',
                width: _headerActionPillWidth,
                onTap: () {
                  Navigator.pushReplacementNamed(
                    context,
                    '/admin_approvals',
                  );
                },
              ),
            ],
          ),
          Divider(color: chrome.divider, height: useFigmaSizes ? 16 : 24),
          if (rows.isEmpty)
            stretchTable
                ? Expanded(
                    child: Center(
                      child: Text(
                        'No proposals loaded yet.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: chrome.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  )
                : Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Text(
                      'No proposals loaded yet.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: chrome.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  )
          else if (stretchTable)
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          flex: 11,
                          child: Text(
                            'Proposal Name',
                            style: TextStyle(
                              color: chrome.textPrimary,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              fontFamily: 'Poppins',
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 8,
                          child: Text(
                            'Client',
                            style: TextStyle(
                              color: chrome.textPrimary,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              fontFamily: 'Poppins',
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 6,
                          child: Text(
                            'Date',
                            style: TextStyle(
                              color: chrome.textPrimary,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              fontFamily: 'Poppins',
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 7,
                          child: Text(
                            'Status',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: chrome.textPrimary,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              fontFamily: 'Poppins',
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        const SizedBox(width: 58),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ...rows.map((p) => _buildRecentProposalRow(chrome, p)),
                  ],
                ),
              ),
            )
          else ...[
            Row(
              children: [
                Expanded(
                  flex: 11,
                  child: Text(
                    'Proposal Name',
                    style: TextStyle(
                      color: chrome.textPrimary,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'Poppins',
                    ),
                  ),
                ),
                Expanded(
                  flex: 8,
                  child: Text(
                    'Client',
                    style: TextStyle(
                      color: chrome.textPrimary,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'Poppins',
                    ),
                  ),
                ),
                Expanded(
                  flex: 6,
                  child: Text(
                    'Date',
                    style: TextStyle(
                      color: chrome.textPrimary,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'Poppins',
                    ),
                  ),
                ),
                Expanded(
                  flex: 7,
                  child: Text(
                    'Status',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: chrome.textPrimary,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'Poppins',
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                const SizedBox(width: 58),
              ],
            ),
            const SizedBox(height: 8),
            ...rows.map((p) => _buildRecentProposalRow(chrome, p)),
          ],
        ],
      ),
    );

    if (useFigmaSizes) {
      inner = SizedBox(
        width: _figmaRecentPanelW,
        height: _figmaRecentPanelH,
        child: inner,
      );
    }
    return inner;
  }

  /// Table status column: blue pill for draft-like rows (matches design spec).
  (String label, Color bg) _recentRowStatusPresentation(String raw) {
    final s = raw.toLowerCase().trim().replaceAll('_', ' ');
    if (s.isEmpty ||
        s == 'draft' ||
        s.contains('draft') ||
        s.contains('in progress')) {
      return ('Draft', ManagerChromeTheme.leftAccentBlue);
    }
    if (s.contains('submitted') ||
        s.contains('pending') ||
        s.contains('review')) {
      return ('Review', ManagerChromeTheme.leftAccentBlue.withOpacity(0.85));
    }
    if (s.contains('signed') || s.contains('approved')) {
      return ('Signed', const Color(0xFF2E7D32));
    }
    if (s.contains('sent') || s.contains('released')) {
      return ('Released', const Color(0xFF1565C0));
    }
    final short = raw.length > 14 ? '${raw.substring(0, 12)}…' : raw;
    return (short, ManagerChromeTheme.leftAccentBlue);
  }

  Widget _buildRecentTableStatusPill(String label, Color backgroundColor) {
    return Align(
      alignment: Alignment.center,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(_pendingPillRadius),
        ),
        child: Text(
          label.toUpperCase(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
            fontFamily: 'Poppins',
          ),
        ),
      ),
    );
  }

  Widget _buildRecentProposalRow(
    ManagerChromeTheme chrome,
    Map<String, dynamic> p,
  ) {
    final title = (p['title'] ?? 'Untitled').toString();
    final statusRaw = (p['status'] ?? p['stage'] ?? 'Draft').toString();
    final client =
        (p['client_name'] ?? p['client'] ?? 'Client Name').toString();
    final updated = _parseDate(p['updated_at'] ?? p['updatedAt']);
    final updatedLabel = updated != null
        ? DateFormat("dd MMM ''yy").format(updated.toLocal())
        : '—';
    final statusVis = _recentRowStatusPresentation(statusRaw);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            flex: 11,
            child: Text(
              title,
              style: TextStyle(
                color: chrome.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w500,
                fontFamily: 'Poppins',
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            flex: 8,
            child: Text(
              client,
              style: TextStyle(
                color: chrome.textPrimary,
                fontSize: 12,
                fontFamily: 'Poppins',
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            flex: 6,
            child: Text(
              updatedLabel,
              style: TextStyle(
                color: chrome.textPrimary,
                fontSize: 12,
                fontFamily: 'Poppins',
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            flex: 7,
            child: _buildRecentTableStatusPill(
              statusVis.$1,
              statusVis.$2,
            ),
          ),
          const SizedBox(width: 4),
          _buildPendingApprovalActionPill(
            width: _figmaPendingRowReviewW,
            height: _figmaPendingRowActionH,
            backgroundColor: _pendingReviewBg,
            label: 'REVIEW',
            onTap: () => _openProposal(p),
          ),
        ],
      ),
    );
  }

  void _computeOperationsModel() {
    if (!mounted) return;

    final now = DateTime.now();
    final blocked = <Map<String, dynamic>>[];
    final delayed = <Map<String, dynamic>>[];
    final needsApproval = <Map<String, dynamic>>[];
    final awaitingSignature = <Map<String, dynamic>>[];
    final recentlySigned = <Map<String, dynamic>>[];
    final reasons = <String, int>{};
    int highRiskTotal = 0;

    int draft = 0, review = 0, released = 0, signed = 0;

    String statusOf(Map<String, dynamic> p) {
      final raw = p['status'] ?? p['stage'] ?? p['state'] ?? '';
      return raw.toString().trim().toLowerCase().replaceAll('_', ' ');
    }

    bool isSigned(String s) =>
        s == 'signed' || s == 'client signed' || s == 'completed';
    bool isReleased(String s) =>
        s.contains('released') ||
        s.contains('sent to client') ||
        s.contains('sent for signature') ||
        s.contains('out for signature');
    bool isReview(String s) =>
        s.contains('review') ||
        s.contains('submitted') ||
        s.contains('pending');
    bool isDraft(String s) =>
        s.isEmpty ||
        s == 'draft' ||
        s.contains('pricing') ||
        s.contains('in progress');

    void bump(String k) => reasons[k] = (reasons[k] ?? 0) + 1;

    for (final p in _combinedProposals) {
      final status = statusOf(p);
      final updatedAt = _parseDate(p['updated_at'] ?? p['updatedAt']);
      final riskScore = _extractRiskScore(p);
      final riskLevel = _extractRiskLevel(p);
      final highRisk = _isHighRisk(riskScore: riskScore, riskLevel: riskLevel);
      if (highRisk) highRiskTotal++;

      if (isSigned(status)) {
        signed++;
      } else if (isReleased(status)) {
        released++;
      } else if (isReview(status)) {
        review++;
      } else if (isDraft(status)) {
        draft++;
      } else {
        review++;
      }

      if (status.contains('pending')) needsApproval.add(p);
      if (isReleased(status) && !isSigned(status)) awaitingSignature.add(p);
      if (isSigned(status) &&
          updatedAt != null &&
          now.difference(updatedAt).inDays <= 14) {
        recentlySigned.add(p);
      }
      if (!isSigned(status) &&
          updatedAt != null &&
          now.difference(updatedAt).inDays >= 14) {
        delayed.add(p);
      }

      final title = (p['title'] ?? '').toString().trim();
      final clientEmail =
          (p['client_email'] ?? p['clientEmail'] ?? '').toString().trim();
      final budget = _parseBudget(p['budget']);
      final missingTitle = title.isEmpty;
      final missingBudget = budget <= 0;
      final missingEmailForRelease = isReleased(status) && clientEmail.isEmpty;

      if (highRisk || missingTitle || missingBudget || missingEmailForRelease)
        blocked.add(p);

      if (highRisk) bump('High risk score');
      if (missingEmailForRelease) bump('Missing client email');
      if (missingBudget) bump('Missing budget');
      if (missingTitle) bump('Missing title');
    }

    blocked.sort((a, b) => (_parseDate(b['updated_at'] ?? b['updatedAt']) ??
            DateTime(1970))
        .compareTo(
            _parseDate(a['updated_at'] ?? a['updatedAt']) ?? DateTime(1970)));

    final topReasons = reasons.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final trimmedReasons = <String, int>{};
    for (final e in topReasons.take(3)) {
      trimmedReasons[e.key] = e.value;
    }

    setState(() {
      _highRiskCount = highRiskTotal;
      _attentionBlockedTotal = blocked.length;
      _attentionDelayedTotal = delayed.length;
      _attentionNeedsApprovalTotal = needsApproval.length;
      _attentionAwaitingSignatureTotal = awaitingSignature.length;
      _attentionRecentlySignedTotal = recentlySigned.length;
      _attentionBlocked = blocked.take(5).toList();
      _attentionDelayed = delayed.take(5).toList();
      _attentionNeedsApproval = needsApproval.take(5).toList();
      _attentionAwaitingSignature = awaitingSignature.take(5).toList();
      _attentionRecentlySigned = recentlySigned.take(5).toList();
      _riskReasons = trimmedReasons;
      _draftCount = draft;
      _reviewCount = review;
      _releasedCount = released;
      _signedCount = signed;
    });
  }

  Widget _buildPipelineHealthInline(ManagerChromeTheme chrome) {
    return Row(
      children: [
        Expanded(child: _buildStatusPill(chrome, 'Draft: $_draftCount')),
        const SizedBox(width: 10),
        Expanded(child: _buildStatusPill(chrome, 'Review: $_reviewCount')),
        const SizedBox(width: 10),
        Expanded(child: _buildStatusPill(chrome, 'Released: $_releasedCount')),
        const SizedBox(width: 10),
        Expanded(child: _buildStatusPill(chrome, 'Signed: $_signedCount')),
      ],
    );
  }

  Widget _buildWhatNeedsAttentionInline(ManagerChromeTheme chrome) {
    Widget row({
      required String label,
      required int count,
      required VoidCallback onView,
    }) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          children: [
            Expanded(
              child: Text(
                '$label: $count',
                style: TextStyle(
                  color: chrome.textSecondary,
                  fontSize: 13,
                  fontFamily: 'Poppins',
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            TextButton(
              onPressed: onView,
              style: TextButton.styleFrom(
                foregroundColor: ManagerChromeTheme.accentRed,
              ),
              child: const Text('View'),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        row(
          label: 'Blocked proposals',
          count: _attentionBlockedTotal,
          onView: () {
            Navigator.pushReplacementNamed(
              context,
              '/admin_approvals',
              arguments: const {
                'initialFilter': 'blocked',
              },
            );
          },
        ),
        row(
          label: 'Delayed (14+ days inactive)',
          count: _attentionDelayedTotal,
          onView: () {
            Navigator.pushReplacementNamed(
              context,
              '/admin_approvals',
              arguments: const {
                'initialFilter': 'all',
                'staleDays': 14,
              },
            );
          },
        ),
        row(
          label: 'Needs approval',
          count: _attentionNeedsApprovalTotal,
          onView: () {
            Navigator.pushReplacementNamed(
              context,
              '/admin_approvals',
              arguments: const {'initialFilter': 'ready'},
            );
          },
        ),
        row(
          label: 'Released awaiting signature',
          count: _attentionAwaitingSignatureTotal,
          onView: () {
            Navigator.pushReplacementNamed(
              context,
              '/admin_approvals',
              arguments: const {
                'initialFilter': 'approved',
                'pipelineStage': 'released_awaiting_signature',
              },
            );
          },
        ),
        row(
          label: 'Recently signed',
          count: _attentionRecentlySignedTotal,
          onView: () {
            Navigator.pushReplacementNamed(
              context,
              '/admin_approvals',
              arguments: const {
                'initialFilter': 'approved',
                'pipelineStage': 'recently_signed',
                'recentDays': 14,
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildRiskGateInline(ManagerChromeTheme chrome) {
    if (_riskReasons.isEmpty) {
      return Text(
        'No risk signals available.',
        style: TextStyle(color: chrome.textSecondary, fontSize: 13),
      );
    }
    final items = _riskReasons.entries
        .map((e) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                '${e.key}: ${e.value}',
                style: TextStyle(color: chrome.textSecondary, fontSize: 13),
              ),
            ))
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...items,
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: () {
              Navigator.pushReplacementNamed(
                context,
                '/admin_approvals',
                arguments: const {
                  'initialFilter': 'all',
                  'minRiskScore': 70,
                },
              );
            },
            style: TextButton.styleFrom(
              foregroundColor: ManagerChromeTheme.accentRed,
            ),
            icon: const Icon(Icons.arrow_forward, size: 16),
            label: const Text('Review high-risk'),
          ),
        ),
      ],
    );
  }

  Widget _buildSection(
    ManagerChromeTheme chrome,
    String title,
    Widget content, {
    String? titleIconAsset,
    int? titleBadge,
    bool useFigmaSizes = false,
    bool showHeaderListDivider = false,
  }) {
    final compact = MediaQuery.sizeOf(context).height < 860;
    final radius = useFigmaSizes ? _figmaAdminPanelRadius : 24.0;
    final pad = useFigmaSizes
        ? const EdgeInsets.all(12)
        : EdgeInsets.all(compact ? 18 : 24);
    final sectionIconDiameter = useFigmaSizes ? 52.0 : 72.0;
    final gapAfterHeader = useFigmaSizes ? 10.0 : (compact ? 12.0 : 20.0);
    final gapBeforeHeaderDivider =
        useFigmaSizes ? 10.0 : (compact ? 12.0 : 16.0);
    final gapAfterHeaderDivider =
        useFigmaSizes ? 10.0 : (compact ? 12.0 : 16.0);

    final header = Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (titleIconAsset != null) ...[
          _buildAdminPanelWhiteIconRing(
            chrome: chrome,
            diameter: sectionIconDiameter,
            child: Image.asset(
              titleIconAsset,
              fit: BoxFit.contain,
            ),
          ),
          SizedBox(width: useFigmaSizes ? 10 : 14),
        ],
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              color: chrome.textPrimary,
              fontSize: useFigmaSizes ? 14 : 15,
              fontWeight: FontWeight.w700,
              fontFamily: 'Poppins',
            ),
          ),
        ),
        if (titleBadge != null && titleBadge > 0) ...[
          SizedBox(width: useFigmaSizes ? 8 : 10),
          useFigmaSizes
              ? _buildSectionBellCountBadge(titleBadge, chrome, size: 40)
              : _buildSectionBellCountBadge(titleBadge, chrome),
        ],
      ],
    );

    final body = useFigmaSizes
        ? Expanded(
            child: SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              child: content,
            ),
          )
        : content;

    final List<Widget> belowHeader = showHeaderListDivider
        ? [
            SizedBox(height: gapBeforeHeaderDivider),
            _buildPendingListDivider(),
            SizedBox(height: gapAfterHeaderDivider),
          ]
        : [
            SizedBox(height: gapAfterHeader),
          ];

    Widget inner = _buildDarkGlass(
      chrome: chrome,
      borderRadius: radius,
      padding: pad,
      child: useFigmaSizes
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                header,
                ...belowHeader,
                body,
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                header,
                ...belowHeader,
                content,
              ],
            ),
    );

    if (useFigmaSizes) {
      inner = SizedBox(
        width: _figmaPendingSectionW,
        height: _figmaPendingSectionH,
        child: inner,
      );
    }
    return inner;
  }

  Widget _buildSidebar(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: _isSidebarCollapsed ? 90.0 : 250.0,
      decoration: BoxDecoration(
        color: const Color(0xFF252525),
        border: Border(
          right: BorderSide(
            color: PremiumTheme.glassWhiteBorder,
            width: 1,
          ),
        ),
      ),
      child: Column(
        children: [
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: InkWell(
              onTap: _toggleSidebar,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                height: 44,
                decoration: BoxDecoration(
                  color: _adminBase.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.10),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: _isSidebarCollapsed
                      ? MainAxisAlignment.center
                      : MainAxisAlignment.spaceBetween,
                  children: [
                    if (!_isSidebarCollapsed)
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          'Navigation',
                          style: TextStyle(color: Colors.white, fontSize: 12),
                        ),
                      ),
                    Padding(
                      padding: EdgeInsets.symmetric(
                          horizontal: _isSidebarCollapsed ? 0 : 8),
                      child: Icon(
                        _isSidebarCollapsed
                            ? Icons.keyboard_arrow_right
                            : Icons.keyboard_arrow_left,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  _buildNavItem('Dashboard', 'assets/images/Dahboard.png',
                      _currentPage == 'Dashboard', context),
                  _buildNavItem(
                      'Approvals',
                      'assets/images/Time Allocation_Approval_Blue.png',
                      _currentPage == 'Approvals',
                      context),
                  _buildNavItem('Analytics', 'assets/images/analytics.png',
                      _currentPage == 'Analytics', context),
                  _buildNavItem('History', 'assets/images/analytics.png',
                      _currentPage == 'History', context),
                  _buildNavItem(
                      'Content Library',
                      'assets/images/content_library.png',
                      _currentPage == 'Content Library',
                      context),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
          if (!_isSidebarCollapsed)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              height: 1,
              color: const Color(0xFF2C3E50),
            ),
          const SizedBox(height: 12),
          _buildNavItem(
              'Sign Out', 'assets/images/Logout_KhonoBuzz.png', false, context),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildNavItem(
      String label, String assetPath, bool isActive, BuildContext context) {
    if (_isSidebarCollapsed) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Tooltip(
          message: label,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                setState(() => _currentPage = label);
                _navigateToPage(label);
              },
              borderRadius: BorderRadius.circular(30),
              child: Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: _adminBase.withValues(alpha: 0.25),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isActive
                        ? _cardAccent
                        : Colors.white.withValues(alpha: 0.18),
                    width: isActive ? 2 : 1,
                  ),
                ),
                padding: const EdgeInsets.all(6),
                child: ClipOval(
                  child: AssetService.buildImageWidget(assetPath,
                      fit: BoxFit.contain),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            setState(() => _currentPage = label);
            _navigateToPage(label);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isActive
                  ? _adminBase.withValues(alpha: 0.30)
                  : _adminBase.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isActive
                    ? _cardAccent.withValues(alpha: 0.65)
                    : Colors.white.withValues(alpha: 0.10),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: _adminBase.withValues(alpha: 0.25),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isActive
                          ? _cardAccent
                          : Colors.white.withValues(alpha: 0.18),
                      width: isActive ? 2 : 1,
                    ),
                  ),
                  padding: const EdgeInsets.all(6),
                  child: ClipOval(
                    child: AssetService.buildImageWidget(assetPath,
                        fit: BoxFit.contain),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: isActive ? Colors.white : const Color(0xFFECF0F1),
                      fontSize: 14,
                      fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                    ),
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

  void _toggleSidebar() {
    final app = context.read<AppState>();
    app.setAdminSidebarCollapsed(!app.isAdminSidebarCollapsed);
  }

  Widget _buildPendingApprovalsList(ManagerChromeTheme chrome) {
    if (_pendingApprovals.isEmpty) {
      final compact = MediaQuery.sizeOf(context).height < 860;
      return Padding(
        padding: EdgeInsets.symmetric(vertical: compact ? 18 : 36),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.pending_actions,
              size: 54,
              color: ManagerChromeTheme.accentRed.withOpacity(0.85),
            ),
            const SizedBox(height: 12),
            Text(
              'No proposals pending approval',
              style: TextStyle(
                fontSize: 16,
                color: chrome.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    final compact = MediaQuery.sizeOf(context).height < 860;
    final maxItems = compact ? 3 : 6;
    final shown = _pendingApprovals.take(maxItems).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < shown.length; i++) ...[
          if (i > 0) _buildPendingListDivider(),
          _buildPendingApprovalCard(chrome, shown[i]),
        ],
        if (_pendingApprovals.length > shown.length)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () {
                setState(() => _currentPage = 'Approvals');
                _navigateToPage('Approvals');
              },
              style: TextButton.styleFrom(
                foregroundColor: ManagerChromeTheme.accentRed,
              ),
              child: Text('View all (${_pendingApprovals.length})'),
            ),
          ),
      ],
    );
  }

  void _handleLogout() {
    AuthService.logout();
    Navigator.pushNamedAndRemoveUntil(
      context,
      '/login',
      (Route<dynamic> route) => false,
    );
  }

  /// Same colors / radius / padding / typography as REJECT; [width] null = intrinsic (min 68).
  Widget _buildRedRejectStylePill({
    required String label,
    required VoidCallback onTap,
    double? width,
  }) {
    return _buildPendingApprovalActionPill(
      width: width,
      backgroundColor: _pendingRejectBg,
      label: label,
      onTap: onTap,
    );
  }

  /// Padding inside decoration. If [width] is set, outer width is fixed (border-box).
  /// If [width] is null, width is intrinsic (at least min touch width for short labels).
  /// When [height] is set with [width], uses compact Figma row buttons (23px tall).
  Widget _buildPendingApprovalActionPill({
    double? width,
    double? height,
    required Color backgroundColor,
    required String label,
    required VoidCallback onTap,
  }) {
    final compactRow = width != null && height != null;
    final double radius;
    if (width != null && height != null) {
      radius = height / 2;
    } else {
      radius = _pendingPillRadius;
    }

    // Do not use unbounded [Center] in header pills (no fixed height): see compactRow branch.
    final Widget pillBody = compactRow
        ? Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.center,
              child: Text(
                label,
                maxLines: 1,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.08,
                  height: 1.0,
                  fontFamily: 'Poppins',
                ),
              ),
            ),
          )
        : Padding(
            padding: _pendingPillPadding,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.center,
              child: Text(
                label,
                maxLines: 1,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.15,
                  fontFamily: 'Poppins',
                ),
              ),
            ),
          );

    final inkDecoration = BoxDecoration(
      color: backgroundColor,
      borderRadius: BorderRadius.circular(radius),
    );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(radius),
        child: width != null
            ? Ink(
                width: width,
                height: height,
                decoration: inkDecoration,
                child: pillBody,
              )
            : Ink(
                decoration: inkDecoration,
                child: IntrinsicWidth(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minWidth: 68),
                    child: pillBody,
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildPendingListDivider() {
    return Container(
      height: _figmaPendingListDividerThickness,
      width: double.infinity,
      color: Colors.white,
    );
  }

  /// Single-line row on the section panel (no nested glass card — avoids the bulky light panel).
  Widget _buildPendingApprovalCard(
    ManagerChromeTheme chrome,
    Map<String, dynamic> proposal,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: SizedBox(
              width: _figmaPendingListRowIconSize,
              height: _figmaPendingListRowIconSize,
              child: Image.asset(
                _assetPendingApprovalRowIcon,
                fit: BoxFit.contain,
              ),
            ),
          ),
          Expanded(
            child: Text(
              proposal['title'] ?? 'Untitled Proposal',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: _pendingApprovalRowTitleStyle(chrome),
            ),
          ),
          const SizedBox(width: 8),
          _buildPendingApprovalActionPill(
            width: _figmaPendingRowReviewW,
            height: _figmaPendingRowActionH,
            backgroundColor: _pendingReviewBg,
            label: 'REVIEW',
            onTap: () => _openProposal(proposal),
          ),
          const SizedBox(width: _pendingPillGap),
          _buildPendingApprovalActionPill(
            width: _figmaPendingRowApproveW,
            height: _figmaPendingRowActionH,
            backgroundColor: _pendingApproveBg,
            label: 'APPROVE',
            onTap: () => _approveProposal(proposal),
          ),
          const SizedBox(width: _pendingPillGap),
          _buildPendingApprovalActionPill(
            width: _figmaPendingRowRejectW,
            height: _figmaPendingRowActionH,
            backgroundColor: _pendingRejectBg,
            label: 'REJECT',
            onTap: () => _rejectProposal(proposal),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip(
    ManagerChromeTheme chrome,
    IconData icon,
    String label,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: chrome.fieldFill,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: chrome.divider),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: chrome.textMuted),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(color: chrome.textSecondary, fontSize: 12),
          ),
        ],
      ),
    );
  }

  void _openProposal(Map<String, dynamic> proposal) {
    final id = proposal['id']?.toString();
    if (id == null) return;
    Navigator.pushNamed(
      context,
      '/proposal_review',
      arguments: {
        'id': id,
        'title': proposal['title'],
      },
    );
  }

  Future<void> _approveProposal(Map<String, dynamic> proposal) async {
    final id = proposal['id']?.toString();
    if (id == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Approve Proposal'),
        content: Text(
          'Are you sure you want to approve "${proposal['title'] ?? 'this proposal'}"? '
          'This will send it to the client.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: PremiumTheme.teal,
            ),
            child: const Text('Approve'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final token = AuthService.token;
      if (token == null) {
        throw Exception('Not authenticated');
      }

      String? clientEmail;
      final rawEmail = proposal['client_email'] ?? proposal['clientEmail'];
      if (rawEmail is String && rawEmail.trim().isNotEmpty) {
        clientEmail = rawEmail.trim();
      }

      Future<http.Response> sendApproval({String? overrideEmail}) {
        final body = <String, dynamic>{};
        final emailToUse = overrideEmail ?? clientEmail;
        if (emailToUse != null && emailToUse.isNotEmpty) {
          body['client_email'] = emailToUse;
        }
        return http.post(
          Uri.parse('${ApiService.baseUrl}/api/proposals/$id/approve'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: json.encode(body),
        );
      }

      http.Response response = await sendApproval();

      if (response.statusCode == 400) {
        try {
          final contentType = response.headers['content-type'] ?? '';
          if (contentType.contains('application/json')) {
            final error = json.decode(response.body);
            if (error is Map &&
                error['error'] == 'missing_client_email' &&
                error['has_override_option'] == true) {
              final controller = TextEditingController(text: clientEmail ?? '');
              final override = await showDialog<String>(
                context: context,
                builder: (context) {
                  return AlertDialog(
                    title: const Text('Client Email Required'),
                    content: TextField(
                      controller: controller,
                      decoration: const InputDecoration(
                        labelText: 'Client Email',
                      ),
                      keyboardType: TextInputType.emailAddress,
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                      ElevatedButton(
                        onPressed: () =>
                            Navigator.pop(context, controller.text.trim()),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: PremiumTheme.teal,
                        ),
                        child: const Text('Continue'),
                      ),
                    ],
                  );
                },
              );

              if (override != null && override.isNotEmpty) {
                clientEmail = override;
                response = await sendApproval(overrideEmail: override);
              }
            }
          }
        } catch (_) {}
      }

      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Proposal approved and sent to client!'),
              backgroundColor: Color(0xFF2ECC71),
            ),
          );
          _loadData();
        }
      } else {
        String errorMessage = 'Failed to approve proposal';
        try {
          final contentType = response.headers['content-type'] ?? '';
          if (contentType.contains('application/json')) {
            final error = json.decode(response.body);
            errorMessage = error['detail'] ?? errorMessage;
          } else {
            if (response.statusCode == 404) {
              errorMessage =
                  'Proposal approval endpoint not found (404). Please check server configuration.';
            } else {
              errorMessage =
                  'Server error (${response.statusCode}): ${response.body.substring(0, response.body.length > 100 ? 100 : response.body.length)}';
            }
          }
        } catch (_) {
          if (response.statusCode == 404) {
            errorMessage =
                'Endpoint not found (404). The approval route may not be registered correctly.';
          } else {
            errorMessage = 'Server returned error ${response.statusCode}';
          }
        }
        throw Exception(errorMessage);
      }
    } catch (e) {
      print('❌ Error approving proposal: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to approve proposal: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _rejectProposal(Map<String, dynamic> proposal) async {
    final id = proposal['id']?.toString();
    if (id == null) return;

    final commentsController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject Proposal'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Are you sure you want to reject "${proposal['title'] ?? 'this proposal'}"? '
              'This will return it to draft status.',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: commentsController,
              decoration: const InputDecoration(
                labelText: 'Rejection Comments (optional)',
                hintText: 'Explain why this proposal is being rejected...',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Reject'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final token = AuthService.token;
      if (token == null) {
        throw Exception('Not authenticated');
      }

      final response = await http.post(
        Uri.parse('${ApiService.baseUrl}/api/proposals/$id/reject'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({
          'comments': commentsController.text.trim(),
        }),
      );

      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Proposal rejected and returned to draft'),
              backgroundColor: Colors.orange,
            ),
          );
          // Reload data
          _loadData();
        }
      } else {
        final error = json.decode(response.body);
        throw Exception(error['detail'] ?? 'Failed to reject proposal');
      }
    } catch (e) {
      print('❌ Error rejecting proposal: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to reject proposal: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  double _parseBudget(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    if (value is String) {
      final cleaned = value.replaceAll(RegExp(r'[^\d.]'), '');
      return double.tryParse(cleaned) ?? 0;
    }
    return 0;
  }

  DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String && value.isNotEmpty) {
      return DateTime.tryParse(value);
    }
    return null;
  }

  double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    if (value is String && value.trim().isNotEmpty) {
      final cleaned = value.trim().replaceAll('%', '');
      return double.tryParse(cleaned);
    }
    return null;
  }

  Map<String, dynamic>? _extractRiskGateObject(Map<String, dynamic> proposal) {
    final raw = proposal['risk_gate'] ??
        proposal['riskGate'] ??
        proposal['risk_analysis'] ??
        proposal['riskAnalysis'] ??
        proposal['riskResult'] ??
        proposal['risk_result'];
    if (raw is Map) return Map<String, dynamic>.from(raw);
    if (raw is String && raw.trim().isNotEmpty) {
      try {
        final decoded = json.decode(raw);
        if (decoded is Map) {
          return Map<String, dynamic>.from(decoded);
        }
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  double? _extractRiskScore(Map<String, dynamic> proposal) {
    final gate = _extractRiskGateObject(proposal);
    final raw = proposal['risk_score'] ??
        proposal['riskScore'] ??
        proposal['risk'] ??
        proposal['risk_percent'] ??
        proposal['riskPercent'] ??
        proposal['risk_rating'] ??
        proposal['riskRating'] ??
        gate?['risk_score'] ??
        gate?['riskScore'] ??
        gate?['score'] ??
        gate?['risk'] ??
        gate?['risk_percent'] ??
        gate?['riskPercent'];
    final parsed = _parseDouble(raw);
    if (parsed == null) return null;

    // Some backends store risk as 0..1; normalize to 0..100.
    if (parsed > 0 && parsed <= 1) return parsed * 100;
    return parsed;
  }

  String _extractRiskLevel(Map<String, dynamic> proposal) {
    final gate = _extractRiskGateObject(proposal);
    return (proposal['risk_level'] ??
            proposal['riskLevel'] ??
            proposal['riskLevelLabel'] ??
            gate?['risk_level'] ??
            gate?['riskLevel'] ??
            gate?['level'] ??
            gate?['risk_level_label'] ??
            gate?['riskLevelLabel'] ??
            '')
        .toString()
        .toLowerCase()
        .trim();
  }

  bool _isHighRisk({required double? riskScore, required String riskLevel}) {
    if (riskScore != null && riskScore >= 70) return true;
    if (riskLevel.isEmpty) return false;
    return riskLevel == 'high' ||
        riskLevel == 'critical' ||
        riskLevel.contains('high') ||
        riskLevel.contains('critical');
  }

  String _formatCurrency(double value) {
    if (value == 0) return 'R0';
    return _currencyFormatter.format(value);
  }

  void _navigateToPage(String page) {
    setState(() => _currentPage = page);

    switch (page) {
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
        _handleLogout();
        break;
    }
  }
}
