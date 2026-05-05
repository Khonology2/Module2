import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;

import 'dart:convert';
import 'dart:html' as html;

import '../../api.dart';
import '../../config/app_constants.dart';
import '../../services/auth_service.dart';
import '../../theme/manager_theme_controller.dart';
import '../../theme/premium_theme.dart';
import '../../widgets/custom_scrollbar.dart';
import '../../widgets/finance/finance_sidebar.dart';
import '../../widgets/footer.dart';
import '../../widgets/glass_date_picker.dart';
import '../../widgets/manager_page_background.dart';
import '../creator/blank_document_editor_page.dart';
import 'finance_client_management_page.dart';

/// Simplified Finance dashboard that uses real proposal data from `/api/proposals`.
class FinanceDashboardV2Page extends StatefulWidget {
  const FinanceDashboardV2Page({Key? key}) : super(key: key);

  @override
  State<FinanceDashboardV2Page> createState() => _FinanceDashboardPageState();
}

class _FinanceDashboardPageState extends State<FinanceDashboardV2Page> {
  bool _isLoading = false;
  final Map<String, double> _amountCache = {};
  final Map<String, String> _amountCacheKey = {};
  static const List<String> _validStatusFilters = [
    'all',
    'pending_review',
    'in_pricing',
    'released',
    'signed',
  ];
  String _statusFilter = 'all';
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ScrollController _proposalsListScrollController = ScrollController();
  String _currentTab = 'dashboard'; // dashboard, proposals, clients

  static const String _managerIconDir = 'assets/images/new icons for manager';
  static const String _proposalsOverviewIcon =
      '$_managerIconDir/Draft proposal.png';
  static const String _searchIcon =
      '$_managerIconDir/Search_Seek_Red Badge_White.png';
  static const String _rowDocIcon =
      '$_managerIconDir/Project Management_Red Badge_White.png';

  int _selectedYear = DateTime.now().year;
  Future<Map<String, dynamic>>? _financeSummaryFuture;
  Future<List<Map<String, dynamic>>>? _monthlyForecastFuture;
  Future<List<Map<String, dynamic>>>? _growthFuture;
  Future<List<Map<String, dynamic>>>? _topClientsFuture;
  Future<List<Map<String, dynamic>>>? _recentSignedFuture;
  Future<List<Map<String, dynamic>>>? _agingFuture;
  Future<List<Map<String, dynamic>>>? _alertsFuture;

  bool _auditLoading = false;
  List<Map<String, dynamic>> _auditItems = [];
  DateTime? _auditFrom;
  DateTime? _auditTo;
  final TextEditingController _auditUserController = TextEditingController();
  final TextEditingController _auditEntityTypeController =
      TextEditingController();
  final TextEditingController _auditActionTypeController =
      TextEditingController();

  bool _handledInitialOpen = false;
  int _aiUsageRefreshTick = 0;
  Timer? _aiUsageRefreshTimer;
  Timer? _notificationRefreshTimer;
  Future<Map<String, dynamic>?>? _aiUsageFuture;

  static const String _financeIconDir =
      'assets/images/finance_manager_new_icons';
  static const String _kpiPipelineIcon =
      '$_financeIconDir/Total_Pipeline_Value.png';
  static const String _kpiExpectedIcon =
      '$_financeIconDir/Expected_Revenue.png';
  static const String _kpiSignedIcon = '$_financeIconDir/Signe_Revenue.png';
  static const String _kpiWinRateIcon = '$_financeIconDir/Win_Rate.png';
  static const String _kpiAvgDealIcon = '$_financeIconDir/Av_Deal_Size.png';
  static const String _pipelineChartIcon =
      '$_financeIconDir/Proposal_Pipeline.png';
  static const String _forecastChartIcon =
      '$_financeIconDir/Revenue_forecast_chart.png';
  static const String _signedGrowthIcon = '$_financeIconDir/Signe_Revenue.png';
  static const String _aiUsageIcon = '$_financeIconDir/AI_Usage.png';
  static const String _byEndpointIcon = '$_financeIconDir/By_Endpoint.png';
  static const String _includeDataIcon = '$_financeIconDir/include_data.png';
  static const String _topClientsIcon = '$_financeIconDir/Top_clients.png';
  static const String _recentSignedIcon =
      '$_financeIconDir/Recent_signed_deals.png';
  static const String _agingReportIcon =
      '$_financeIconDir/Pipeline_aging_report.png';
  static const String _financialAlertsIcon =
      '$_financeIconDir/Financial_Alerts.png';
  static const String _requiresAttentionIcon =
      '$_financeIconDir/Requires_Attention.png';
  static const String _topClientsInTabIcon =
      '$_financeIconDir/Top clients by rev_intab.png';
  static const String _recentSignedInTabIcon =
      '$_financeIconDir/Recent_signed_deals_intab.png';
  static const double _adminLikeIconDiameter = 80.0;
  static const double _adminLikeIconPadding = 14.0;

  BoxDecoration _panelDecoration() => BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: const Color(0xFF3F3F3F).withValues(alpha: 0.58),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      );

  Widget _panelIcon(String path, {double size = _adminLikeIconDiameter}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border:
            Border.all(color: Colors.white.withValues(alpha: 0.22), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.28),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: EdgeInsets.all(
          size == _adminLikeIconDiameter ? _adminLikeIconPadding : 6),
      child: Image.asset(
        path,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) =>
            const Icon(Icons.broken_image, color: Colors.red, size: 18),
      ),
    );
  }

  Widget _buildInTabIcon(String path) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: 0.12),
      ),
      padding: const EdgeInsets.all(2),
      child: Image.asset(
        path,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) =>
            const Icon(Icons.broken_image, color: Colors.red, size: 14),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _loadData();
      if (!mounted) return;
      context.read<AppState>().fetchNotifications();
    });
    _aiUsageFuture = _fetchAiUsageAnalytics();
    _aiUsageRefreshTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      if (!mounted) return;
      if (_currentTab != 'dashboard') return;
      setState(() {
        _aiUsageRefreshTick++;
        _aiUsageFuture = _fetchAiUsageAnalytics();
      });
    });
    _notificationRefreshTimer =
        Timer.periodic(const Duration(seconds: 20), (_) {
      if (!mounted) return;
      context.read<AppState>().fetchNotifications();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Ensure forecast is loaded once we have an auth token in context.
    _monthlyForecastFuture ??= _fetchMonthlyForecast(year: _selectedYear);
    _financeSummaryFuture ??= _fetchFinanceSummary(year: _selectedYear);
    _growthFuture ??= _fetchGrowth(year: _selectedYear);
    _topClientsFuture ??= _fetchTopClients(year: _selectedYear);
    _recentSignedFuture ??= _fetchRecentSigned(year: _selectedYear);
    _agingFuture ??= _fetchAging(year: _selectedYear);
    _alertsFuture ??= _fetchAlerts(year: _selectedYear);

    if (_handledInitialOpen) return;
    _handledInitialOpen = true;

    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is! Map) return;

    final String? initialTab = args['initialTab']?.toString();
    if (initialTab != null && initialTab.trim().isNotEmpty) {
      final t = initialTab.trim().toLowerCase();
      if (t == 'audit') {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          setState(() => _currentTab = 'audit');
          _loadAuditLogs();
        });
      } else if (t == 'dashboard' || t == 'proposals' || t == 'clients') {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          setState(() => _currentTab = t);
        });
      } else if (t == 'client management') {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          setState(() => _currentTab = 'clients');
        });
      }
    }

    final dynamic openIdRaw = args['openProposalId'] ?? args['proposalId'];
    final String? openProposalId =
        openIdRaw?.toString().trim().isNotEmpty == true
            ? openIdRaw.toString().trim()
            : null;

    if (openProposalId == null) return;

    final Map<String, dynamic>? aiGeneratedSections =
        (args['aiGeneratedSections'] is Map)
            ? Map<String, dynamic>.from(args['aiGeneratedSections'] as Map)
            : null;
    final String? initialTitle = args['initialTitle']?.toString();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => BlankDocumentEditorPage(
            proposalId: openProposalId,
            proposalTitle: args['proposalTitle']?.toString(),
            initialTitle: initialTitle,
            aiGeneratedSections: aiGeneratedSections,
            readOnly: false,
          ),
        ),
      );
    });
  }

  @override
  void dispose() {
    _aiUsageRefreshTimer?.cancel();
    _notificationRefreshTimer?.cancel();
    _searchController.dispose();
    _scrollController.dispose();
    _proposalsListScrollController.dispose();
    _auditUserController.dispose();
    _auditEntityTypeController.dispose();
    _auditActionTypeController.dispose();
    super.dispose();
  }

  Future<List<Map<String, dynamic>>> _fetchMonthlyForecast(
      {required int year}) async {
    final app = context.read<AppState>();
    final token = app.authToken ?? AuthService.token;
    if (token == null) return [];

    final uri = Uri.parse('${baseUrl}/api/finance/forecast/monthly')
        .replace(queryParameters: {'year': year.toString()});

    final resp = await http.get(
      uri,
      headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      },
    );

    if (resp.statusCode != 200) {
      debugPrint('Monthly forecast error: ${resp.statusCode} ${resp.body}');
      return [];
    }

    final decoded = jsonDecode(resp.body);
    final itemsAny = (decoded is Map) ? decoded['items'] : null;
    if (itemsAny is! List) return [];

    final out = <Map<String, dynamic>>[];
    for (final r in itemsAny) {
      if (r is Map<String, dynamic>) {
        out.add(r);
      } else if (r is Map) {
        out.add(r.map((k, v) => MapEntry(k.toString(), v)));
      }
    }
    return out;
  }

  Future<Map<String, dynamic>> _fetchFinanceSummary({required int year}) async {
    final app = context.read<AppState>();
    final token = app.authToken ?? AuthService.token;
    if (token == null) return {};

    final uri = Uri.parse('${baseUrl}/api/finance/summary')
        .replace(queryParameters: {'year': year.toString()});

    final resp = await http.get(
      uri,
      headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      },
    );

    if (resp.statusCode != 200) {
      debugPrint('Finance summary error: ${resp.statusCode} ${resp.body}');
      return {};
    }

    final decoded = jsonDecode(resp.body);
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is Map) {
      return decoded.map((k, v) => MapEntry(k.toString(), v));
    }
    return {};
  }

  Future<List<Map<String, dynamic>>> _fetchListEndpoint(
    String path, {
    required int year,
    Map<String, String>? query,
    String itemsKey = 'items',
  }) async {
    final app = context.read<AppState>();
    final token = app.authToken ?? AuthService.token;
    if (token == null) return [];

    final uri = Uri.parse('${baseUrl}$path').replace(
      queryParameters: {
        'year': year.toString(),
        ...?query,
      },
    );

    final resp = await http.get(
      uri,
      headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      },
    );

    if (resp.statusCode != 200) {
      debugPrint(
          'Finance endpoint error $path: ${resp.statusCode} ${resp.body}');
      return [];
    }

    final decoded = jsonDecode(resp.body);
    final itemsAny = (decoded is Map) ? decoded[itemsKey] : null;
    if (itemsAny is! List) return [];

    final out = <Map<String, dynamic>>[];
    for (final r in itemsAny) {
      if (r is Map<String, dynamic>) {
        out.add(r);
      } else if (r is Map) {
        out.add(r.map((k, v) => MapEntry(k.toString(), v)));
      }
    }
    return out;
  }

  Future<List<Map<String, dynamic>>> _fetchFunnel({required int year}) async {
    return _fetchListEndpoint('/api/finance/funnel', year: year);
  }

  Future<List<Map<String, dynamic>>> _fetchGrowth({required int year}) async {
    return _fetchListEndpoint('/api/finance/revenue-growth', year: year);
  }

  Future<List<Map<String, dynamic>>> _fetchTopClients(
      {required int year}) async {
    return _fetchListEndpoint('/api/finance/top-clients',
        year: year, query: {'limit': '10'});
  }

  Future<List<Map<String, dynamic>>> _fetchRecentSigned(
      {required int year}) async {
    return _fetchListEndpoint('/api/finance/recent-signed',
        year: year, query: {'limit': '10'});
  }

  Future<List<Map<String, dynamic>>> _fetchAging({required int year}) async {
    return _fetchListEndpoint('/api/finance/deal-aging',
        year: year, query: {'threshold_days': '30'});
  }

  Future<List<Map<String, dynamic>>> _fetchAlerts({required int year}) async {
    return _fetchListEndpoint('/api/finance/alerts', year: year);
  }

  Widget _buildYearSelector() {
    final nowYear = DateTime.now().year;
    final years = List<int>.generate(5, (i) => nowYear - 2 + i);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: _selectedYear,
          dropdownColor: const Color(0xFF0F0F0F),
          iconEnabledColor: Colors.white70,
          style: PremiumTheme.bodyMedium.copyWith(color: Colors.white),
          items: years
              .map(
                (y) => DropdownMenuItem<int>(
                  value: y,
                  child: Text(y.toString()),
                ),
              )
              .toList(),
          onChanged: (v) {
            if (v == null) return;
            setState(() {
              _selectedYear = v;
              _monthlyForecastFuture =
                  _fetchMonthlyForecast(year: _selectedYear);
              _financeSummaryFuture = _fetchFinanceSummary(year: _selectedYear);
              _growthFuture = _fetchGrowth(year: _selectedYear);
              _topClientsFuture = _fetchTopClients(year: _selectedYear);
              _recentSignedFuture = _fetchRecentSigned(year: _selectedYear);
              _agingFuture = _fetchAging(year: _selectedYear);
              _alertsFuture = _fetchAlerts(year: _selectedYear);
            });
          },
        ),
      ),
    );
  }

  Widget _buildKpiCard({
    required String label,
    required String value,
    required String iconPath,
    required String subtitle,
  }) {
    return Container(
      height: 112,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: _panelDecoration(),
      child: Row(
        children: [
          _panelIcon(iconPath),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  style:
                      PremiumTheme.labelMedium.copyWith(color: Colors.white70),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: PremiumTheme.bodySmall.copyWith(color: Colors.white54),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: PremiumTheme.titleMedium
                      .copyWith(fontWeight: FontWeight.w800),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFinanceKpis() {
    final future =
        _financeSummaryFuture ?? _fetchFinanceSummary(year: _selectedYear);
    return FutureBuilder<Map<String, dynamic>>(
      future: future,
      builder: (context, snapshot) {
        final data = snapshot.data ?? {};
        final loading = snapshot.connectionState == ConnectionState.waiting;

        final pipeline = (data['pipeline_value'] is num)
            ? (data['pipeline_value'] as num).toDouble()
            : double.tryParse(data['pipeline_value']?.toString() ?? '') ?? 0.0;
        final expected = (data['expected_revenue'] is num)
            ? (data['expected_revenue'] as num).toDouble()
            : double.tryParse(data['expected_revenue']?.toString() ?? '') ??
                0.0;
        final signed = (data['signed_revenue'] is num)
            ? (data['signed_revenue'] as num).toDouble()
            : double.tryParse(data['signed_revenue']?.toString() ?? '') ?? 0.0;
        final winRate = (data['win_rate'] is num)
            ? (data['win_rate'] as num).toDouble()
            : double.tryParse(data['win_rate']?.toString() ?? '') ?? 0.0;
        final avgDeal = (data['average_deal_size'] is num)
            ? (data['average_deal_size'] as num).toDouble()
            : double.tryParse(data['average_deal_size']?.toString() ?? '') ??
                0.0;

        final cards = [
          _buildKpiCard(
            label: 'Total Pipeline Value',
            value: loading ? '--' : _formatCurrency(pipeline),
            iconPath: _kpiPipelineIcon,
            subtitle:
                '${_getFilteredProposals(context.read<AppState>(), ignoreStatusFilter: true).length} Proposals',
          ),
          _buildKpiCard(
            label: 'Expected Revenue',
            value: loading ? '--' : _formatCurrency(expected),
            iconPath: _kpiExpectedIcon,
            subtitle: 'Awaiting Finance Action',
          ),
          _buildKpiCard(
            label: 'Signed Revenue',
            value: loading ? '--' : _formatCurrency(signed),
            iconPath: _kpiSignedIcon,
            subtitle: 'Closed-to-Lost upto 100%',
          ),
          _buildKpiCard(
            label: 'Win Rate',
            value: loading ? '--' : '${(winRate * 100).toStringAsFixed(1)}%',
            iconPath: _kpiWinRateIcon,
            subtitle: '3 of 5 Completed',
          ),
          _buildKpiCard(
            label: 'Average Deal Size',
            value: loading ? '--' : _formatCurrency(avgDeal),
            iconPath: _kpiAvgDealIcon,
            subtitle: '3 of 5 Completed',
          ),
        ];

        return LayoutBuilder(
          builder: (context, constraints) {
            final w = constraints.maxWidth;
            int columns;
            if (w >= 1300) {
              columns = 5;
            } else if (w >= 980) {
              columns = 5;
            } else if (w >= 760) {
              columns = 3;
            } else {
              columns = 2;
            }

            final spacing = 12.0;
            final cardWidth =
                ((w - (columns - 1) * spacing) / columns).clamp(160.0, 420.0);

            return Wrap(
              spacing: spacing,
              runSpacing: spacing,
              children: [
                for (final c in cards)
                  SizedBox(
                    width: cardWidth,
                    child: c,
                  ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildFinancialAlertsPanel() {
    final future = _alertsFuture ?? _fetchAlerts(year: _selectedYear);
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: future,
      builder: (context, snapshot) {
        final items = snapshot.data ?? [];
        final shown = items.take(4).toList();

        Widget alertRow(Map<String, dynamic> item, {required bool checked}) {
          final type =
              (item['type'] ?? 'Alert Title').toString().replaceAll('_', ' ');
          final details =
              (item['client'] ?? item['message'] ?? item['detail'] ?? '')
                  .toString()
                  .trim();
          final line = details.isEmpty ? type : '$type - $details';
          return Row(
            children: [
              Icon(
                checked ? Icons.check_box : Icons.check_box_outline_blank,
                color: checked ? const Color(0xFFE11D48) : Colors.white70,
                size: 14,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  line,
                  style: PremiumTheme.bodySmall.copyWith(color: Colors.white70),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 10),
              TextButton(
                onPressed: () {
                  setState(() {
                    _currentTab = 'proposals';
                    _statusFilter = 'pending_review';
                  });
                },
                style: TextButton.styleFrom(
                  backgroundColor: Colors.white.withValues(alpha: 0.35),
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  shape: const StadiumBorder(),
                ),
                child: const Text(
                  'VIEW',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          );
        }

        final count = shown.length;

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: _panelDecoration(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _panelIcon(_financialAlertsIcon),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Financial Alerts',
                            style: PremiumTheme.titleMedium),
                        const SizedBox(height: 4),
                        Text(
                          'Items requiring financial attention.',
                          style: PremiumTheme.bodyMedium
                              .copyWith(color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.95),
                      shape: BoxShape.circle,
                    ),
                    padding: const EdgeInsets.all(7),
                    child: Image.asset(
                      'assets/images/new icons for manager/notifications.png',
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      '$count',
                      style: PremiumTheme.titleMedium
                          .copyWith(fontWeight: FontWeight.w800),
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _currentTab = 'proposals';
                        _statusFilter = 'pending_review';
                      });
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: const Color(0xFFC10D00),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 6),
                      shape: const StadiumBorder(),
                    ),
                    child: const Text(
                      'VIEW ALL',
                      style:
                          TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Divider(color: Colors.white.withValues(alpha: 0.35), height: 1),
              const SizedBox(height: 10),
              if (snapshot.connectionState == ConnectionState.waiting)
                SizedBox(
                  height: 110,
                  child: Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(
                          Colors.white.withOpacity(0.7)),
                    ),
                  ),
                )
              else if (shown.isEmpty)
                SizedBox(
                  height: 70,
                  child: Center(
                    child: Text(
                      'No alerts requiring attention.',
                      style: PremiumTheme.bodyMedium
                          .copyWith(color: Colors.white60),
                    ),
                  ),
                )
              else
                Column(
                  children: [
                    for (int i = 0; i < shown.length; i++) ...[
                      alertRow(shown[i], checked: i.isOdd),
                      if (i != shown.length - 1) const SizedBox(height: 10),
                    ],
                  ],
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPanel({
    required String title,
    required String subtitle,
    required String iconPath,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _panelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _panelIcon(iconPath),
              const SizedBox(width: 10),
              Expanded(child: Text(title, style: PremiumTheme.titleMedium)),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: PremiumTheme.bodyMedium.copyWith(color: Colors.white70),
          ),
          const SizedBox(height: 14),
          SizedBox(height: 240, child: child),
        ],
      ),
    );
  }

  Widget _buildSignedRevenueGrowthChart() {
    final future = _growthFuture ?? _fetchGrowth(year: _selectedYear);
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: CircularProgressIndicator(
              valueColor:
                  AlwaysStoppedAnimation<Color>(Colors.white.withOpacity(0.7)),
            ),
          );
        }
        final items = snapshot.data ?? [];
        final months = <String>[];
        final values = <double>[];
        for (final r in items) {
          final m = (r['month'] ?? '').toString();
          if (m.length < 7) continue;
          months.add(m);
          values.add((r['signed_revenue'] is num)
              ? (r['signed_revenue'] as num).toDouble()
              : double.tryParse(r['signed_revenue']?.toString() ?? '') ?? 0.0);
        }
        if (months.isEmpty) {
          return Center(
            child: Text(
              'No data',
              style: PremiumTheme.bodyMedium.copyWith(color: Colors.white60),
            ),
          );
        }

        final now = DateTime.now();
        int endIndex = months.length - 1;
        if (_selectedYear == now.year) {
          // Prefer to end at the current month so the chart doesn't jump to
          // Jul-Dec just because the API returns Jan-Dec buckets.
          final currentKey =
              '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}';
          final idx = months.indexOf(currentKey);
          if (idx >= 0) {
            endIndex = idx;
          }
        }

        final displayCount = (endIndex + 1) >= 6 ? 6 : (endIndex + 1);
        final startIndex = (endIndex - displayCount + 1).clamp(0, endIndex);
        final months6 = months.sublist(startIndex, endIndex + 1);
        final values6 = values.sublist(startIndex, endIndex + 1);

        double maxY = 0;
        for (final v in values6) {
          if (v > maxY) maxY = v;
        }

        return Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.03),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withOpacity(0.06)),
          ),
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
          child: LineChart(
            LineChartData(
              minX: 0,
              maxX: (displayCount - 1).toDouble(),
              minY: 0,
              maxY: (maxY <= 0 ? 1 : maxY) * 1.1,
              lineTouchData: LineTouchData(
                enabled: true,
                handleBuiltInTouches: true,
                touchTooltipData: LineTouchTooltipData(
                  tooltipMargin: 12,
                  tooltipPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  getTooltipColor: (touchedSpot) =>
                      Colors.white.withOpacity(0.96),
                  getTooltipItems: (touchedSpots) {
                    if (touchedSpots.isEmpty) return [];
                    final idx =
                        touchedSpots.first.x.round().clamp(0, displayCount - 1);
                    final monthKey = months6[idx];
                    DateTime? parsed;
                    try {
                      final parts = monthKey.split('-');
                      parsed =
                          DateTime(int.parse(parts[0]), int.parse(parts[1]), 1);
                    } catch (_) {}
                    final monthLabel = parsed != null
                        ? DateFormat('MMM').format(parsed)
                        : monthKey;
                    final val = values6[idx];
                    final headerStyle = PremiumTheme.bodyMedium.copyWith(
                      color: Colors.black87,
                      fontWeight: FontWeight.w700,
                    );
                    final bodyStyle = PremiumTheme.bodyMedium.copyWith(
                      color: Colors.black87,
                      fontWeight: FontWeight.w600,
                    );
                    return [
                      LineTooltipItem(
                        '$monthLabel\n',
                        headerStyle,
                        children: [
                          TextSpan(
                            text: 'Signed : ${_formatCurrency(val)}',
                            style: bodyStyle.copyWith(color: PremiumTheme.info),
                          ),
                        ],
                      )
                    ];
                  },
                ),
              ),
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                getDrawingHorizontalLine: (value) => FlLine(
                  color: Colors.white.withOpacity(0.08),
                  strokeWidth: 1,
                ),
              ),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                topTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 42,
                    getTitlesWidget: (value, meta) {
                      if (value == 0) {
                        return Text(
                          'R0',
                          style: PremiumTheme.labelMedium
                              .copyWith(color: Colors.white60, fontSize: 10),
                        );
                      }
                      if (value == meta.max) {
                        return Text(
                          _formatCurrency(value),
                          style: PremiumTheme.labelMedium
                              .copyWith(color: Colors.white60, fontSize: 10),
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    interval: 1,
                    getTitlesWidget: (value, meta) {
                      final i = value.toInt();
                      if (i < 0 || i >= months6.length)
                        return const SizedBox.shrink();
                      DateTime? parsed;
                      try {
                        final parts = months6[i].split('-');
                        parsed = DateTime(
                            int.parse(parts[0]), int.parse(parts[1]), 1);
                      } catch (_) {}
                      final label = parsed != null
                          ? DateFormat('MMM').format(parsed)
                          : months6[i];
                      return Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          label,
                          style: PremiumTheme.labelMedium
                              .copyWith(color: Colors.white60, fontSize: 10),
                        ),
                      );
                    },
                  ),
                ),
              ),
              lineBarsData: [
                LineChartBarData(
                  spots: List.generate(
                      displayCount, (i) => FlSpot(i.toDouble(), values6[i])),
                  isCurved: true,
                  color: PremiumTheme.info,
                  barWidth: 3,
                  dotData: const FlDotData(show: false),
                  belowBarData: BarAreaData(
                    show: true,
                    color: PremiumTheme.info.withOpacity(0.10),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildChartsRow() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 1100;
        final left = _buildPanel(
          title: 'Proposal Pipeline',
          subtitle: 'Current proposals by status',
          iconPath: _pipelineChartIcon,
          child: _buildPipelineChart(),
        );
        final mid = _buildPanel(
          title: 'Revenue Forecast Chart',
          subtitle: 'Forecasted revenue by month',
          iconPath: _forecastChartIcon,
          child: _buildRevenueForecastChart(),
        );
        final right = _buildPanel(
          title: 'Signed Revenue Growth',
          subtitle: 'Projected vs Actual Revenue',
          iconPath: _signedGrowthIcon,
          child: _buildSignedRevenueGrowthChart(),
        );

        if (isNarrow) {
          return Column(
            children: [
              left,
              const SizedBox(height: 12),
              mid,
              const SizedBox(height: 12),
              right,
            ],
          );
        }

        return Column(
          children: [
            Row(
              children: [
                Expanded(child: left),
                const SizedBox(width: 12),
                Expanded(child: mid),
              ],
            ),
            const SizedBox(height: 12),
            right,
          ],
        );
      },
    );
  }

  Widget _buildSimpleListPanel({
    required String title,
    required String subtitle,
    required String iconPath,
    String? actionLabel,
    VoidCallback? onAction,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _panelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: PremiumTheme.titleMedium),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      style: PremiumTheme.bodyMedium
                          .copyWith(color: Colors.white70),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              _panelIcon(iconPath),
              if (actionLabel != null)
                TextButton(
                  onPressed: onAction,
                  style: TextButton.styleFrom(
                    backgroundColor: const Color(0xFFC10D00),
                    foregroundColor: Colors.white,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  ),
                  child: Text(
                    actionLabel,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Future<Map<String, dynamic>?> _fetchAiUsageAnalytics() async {
    final now = DateTime.now();
    final start = now.subtract(const Duration(days: 30));
    final fmt = DateFormat('yyyy-MM-dd');
    return context.read<AppState>().getAiUsageAnalytics(
          startDate: fmt.format(start),
          endDate: fmt.format(now),
        );
  }

  Widget _buildAiUsageDashboardPanel() {
    return FutureBuilder<Map<String, dynamic>?>(
      key: ValueKey('finance_dashboard_ai_usage_$_aiUsageRefreshTick'),
      future: _aiUsageFuture ?? _fetchAiUsageAnalytics(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return SizedBox(
            height: 200,
            child: Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(
                    Colors.white.withOpacity(0.7)),
              ),
            ),
          );
        }

        final data = snapshot.data;
        if (snapshot.hasError || data == null) {
          return SizedBox(
            height: 80,
            child: Center(
              child: Text(
                'Failed to load AI usage data.',
                style: PremiumTheme.bodyMedium.copyWith(color: Colors.white60),
              ),
            ),
          );
        }

        if (data['error_status'] != null) {
          return SizedBox(
            height: 80,
            child: Center(
              child: Text(
                'Unable to load AI usage (${data['error_status']}).',
                style: PremiumTheme.bodyMedium.copyWith(color: Colors.white60),
              ),
            ),
          );
        }

        int n(dynamic v) {
          if (v is int) return v;
          if (v is num) return v.toInt();
          return int.tryParse((v ?? '').toString()) ?? 0;
        }

        final totals = (data['totals'] as Map?)?.cast<String, dynamic>() ?? {};
        final endpointSplit = ((data['endpoint_split'] as List?) ?? const [])
            .whereType<Map>()
            .map((e) => e.cast<String, dynamic>())
            .toList();
        final topUsers = ((data['top_users'] as List?) ?? const [])
            .whereType<Map>()
            .map((e) => e.cast<String, dynamic>())
            .toList();
        final usageSummary =
            (data['usage_summary'] as Map?)?.cast<String, dynamic>() ?? {};
        final acceptanceRate = (totals['acceptance_rate'] is num)
            ? (totals['acceptance_rate'] as num).toDouble()
            : 0.0;
        final averageSpendZar = (usageSummary['average_spend_zar'] is num)
            ? (usageSummary['average_spend_zar'] as num).toDouble()
            : 0.0;
        final averageSpendReason =
            (usageSummary['average_spend_reason'] ?? '').toString();

        Widget statTile(String label, String value) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: PremiumTheme.labelMedium
                        .copyWith(color: Colors.white70),
                  ),
                ),
                Text(
                  value,
                  style: PremiumTheme.titleMedium.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          );
        }

        Widget includeDataCard({
          required String title,
          required String subtitle,
          required Color borderColor,
          required String actionIconPath,
        }) {
          return Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: borderColor, width: 2),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: PremiumTheme.bodyMedium.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: PremiumTheme.bodySmall.copyWith(
                          color: Colors.white60,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Include Data',
                        style: PremiumTheme.titleMedium.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 46,
                  height: 46,
                  child: Image.asset(
                    actionIconPath,
                    fit: BoxFit.contain,
                  ),
                ),
              ],
            ),
          );
        }

        final totalTokens =
            NumberFormat.compact().format(n(usageSummary['total_tokens']));
        final totalCost =
            'R ${((usageSummary['estimated_cost_zar'] as num?) ?? 0).toStringAsFixed(2)}';

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth < 960 ? 2 : 4;
                final tiles = <Widget>[
                  statTile('Requests', n(totals['total_requests']).toString()),
                  statTile('Success', n(totals['success_count']).toString()),
                  statTile('Failed', n(totals['failed_count']).toString()),
                  statTile('Blocked', n(totals['blocked_count']).toString()),
                  statTile(
                      'Acceptance', '${acceptanceRate.toStringAsFixed(1)}%'),
                  statTile('Tokens', totalTokens),
                  statTile('Cost', totalCost),
                  statTile(
                    'Average spend',
                    'R ${averageSpendZar.toStringAsFixed(2)}',
                  ),
                ];
                return GridView.count(
                  crossAxisCount: columns,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 2.6,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  children: tiles,
                );
              },
            ),
            if (averageSpendReason.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                averageSpendReason,
                style: PremiumTheme.bodySmall.copyWith(color: Colors.white54),
              ),
            ],
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                final endpointCount = endpointSplit.length.toString();
                final usersCount = topUsers.length.toString();
                final left = includeDataCard(
                  title: 'By Endpoint',
                  subtitle: 'Additional description information to include.',
                  borderColor: const Color(0xFF2D9CDB),
                  actionIconPath: _byEndpointIcon,
                );
                final right = includeDataCard(
                  title: 'Top Users',
                  subtitle: 'Additional description information to include.',
                  borderColor: const Color(0xFFC10D00),
                  actionIconPath: _includeDataIcon,
                );
                if (constraints.maxWidth < 980) {
                  return Column(
                    children: [
                      left,
                      const SizedBox(height: 10),
                      right,
                      const SizedBox(height: 6),
                      Text(
                        'Endpoints: $endpointCount | Users: $usersCount',
                        style: PremiumTheme.bodySmall
                            .copyWith(color: Colors.white54),
                      ),
                    ],
                  );
                }
                return Column(
                  children: [
                    Row(
                      children: [
                        Expanded(child: left),
                        const SizedBox(width: 12),
                        Expanded(child: right),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Endpoints: $endpointCount | Users: $usersCount',
                      style: PremiumTheme.bodySmall
                          .copyWith(color: Colors.white54),
                    ),
                  ],
                );
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildTopClientsPanel() {
    final future = _topClientsFuture ?? _fetchTopClients(year: _selectedYear);
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return SizedBox(
            height: 220,
            child: Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(
                    Colors.white.withOpacity(0.7)),
              ),
            ),
          );
        }
        final items = snapshot.data ?? [];
        if (items.isEmpty) {
          return SizedBox(
            height: 80,
            child: Center(
              child: Text('No data',
                  style:
                      PremiumTheme.bodyMedium.copyWith(color: Colors.white60)),
            ),
          );
        }

        return Column(
          children: [
            for (int i = 0; i < items.length; i++) ...[
              Row(
                children: [
                  _buildInTabIcon(_topClientsInTabIcon),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          (items[i]['client'] ?? '').toString(),
                          style: PremiumTheme.bodyMedium.copyWith(
                            color: const Color(0xFFE11D48),
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _formatCurrency((items[i]['revenue'] is num)
                              ? (items[i]['revenue'] as num).toDouble()
                              : double.tryParse(
                                      items[i]['revenue']?.toString() ?? '') ??
                                  0.0),
                          style: PremiumTheme.bodyMedium.copyWith(
                            color: const Color(0xFFE11D48),
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () {
                      setState(() => _currentTab = 'proposals');
                    },
                    style: TextButton.styleFrom(
                      backgroundColor: Colors.white.withValues(alpha: 0.35),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      shape: const StadiumBorder(),
                    ),
                    child: const Text(
                      'VIEW',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              if (i != items.length - 1)
                Divider(color: Colors.white.withOpacity(0.06), height: 14),
            ],
          ],
        );
      },
    );
  }

  Widget _buildRecentSignedPanel() {
    final future =
        _recentSignedFuture ?? _fetchRecentSigned(year: _selectedYear);
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return SizedBox(
            height: 220,
            child: Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(
                    Colors.white.withOpacity(0.7)),
              ),
            ),
          );
        }
        final items = snapshot.data ?? [];
        if (items.isEmpty) {
          return SizedBox(
            height: 80,
            child: Center(
              child: Text('No data',
                  style:
                      PremiumTheme.bodyMedium.copyWith(color: Colors.white60)),
            ),
          );
        }

        return Column(
          children: [
            for (int i = 0; i < items.length; i++) ...[
              Row(
                children: [
                  _buildInTabIcon(_recentSignedInTabIcon),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          (items[i]['proposal'] ?? '').toString(),
                          style: PremiumTheme.bodyMedium.copyWith(
                            color: const Color(0xFFE11D48),
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          (items[i]['client'] ?? '').toString(),
                          style: PremiumTheme.labelMedium
                              .copyWith(color: Colors.white70),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () {
                      setState(() => _currentTab = 'proposals');
                    },
                    style: TextButton.styleFrom(
                      backgroundColor: Colors.white.withValues(alpha: 0.35),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      shape: const StadiumBorder(),
                    ),
                    child: const Text(
                      'VIEW',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              if (i != items.length - 1)
                Divider(color: Colors.white.withOpacity(0.06), height: 14),
            ],
          ],
        );
      },
    );
  }

  Widget _buildAgingPanel() {
    final future = _agingFuture ?? _fetchAging(year: _selectedYear);
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return SizedBox(
            height: 220,
            child: Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(
                    Colors.white.withOpacity(0.7)),
              ),
            ),
          );
        }
        final items = snapshot.data ?? [];
        if (items.isEmpty) {
          return SizedBox(
            height: 80,
            child: Center(
              child: Text('No stalled deals > 30 days',
                  style:
                      PremiumTheme.bodyMedium.copyWith(color: Colors.white60)),
            ),
          );
        }

        final shown = items.take(8).toList();
        return Column(
          children: [
            for (int i = 0; i < shown.length; i++) ...[
              Row(
                children: [
                  Expanded(
                    child: Text(
                      (shown[i]['proposal'] ?? '').toString(),
                      style:
                          PremiumTheme.bodyMedium.copyWith(color: Colors.white),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '${shown[i]['days_in_stage'] ?? ''}d',
                    style: PremiumTheme.bodyMedium.copyWith(
                      color: Colors.orange,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              if (i != shown.length - 1)
                Divider(color: Colors.white.withOpacity(0.06), height: 14),
            ],
          ],
        );
      },
    );
  }

  bool _canAccessAudit(AppState app) {
    final role = (app.currentUser?['role'] ?? '').toString().toLowerCase();
    return role == 'finance_manager' || role == 'admin' || role == 'ceo';
  }

  Map<String, String> _auditQueryParams({
    required int limit,
    required int offset,
  }) {
    final params = <String, String>{
      'limit': limit.toString(),
      'offset': offset.toString(),
    };

    if (_auditFrom != null) {
      params['date_from'] = _auditFrom!.toUtc().toIso8601String();
    }
    if (_auditTo != null) {
      params['date_to'] = _auditTo!.toUtc().toIso8601String();
    }
    final u = _auditUserController.text.trim();
    if (u.isNotEmpty) params['user'] = u;
    final et = _auditEntityTypeController.text.trim();
    if (et.isNotEmpty) params['entity_type'] = et;
    final at = _auditActionTypeController.text.trim();
    if (at.isNotEmpty) params['action_type'] = at;
    return params;
  }

  Future<void> _loadAuditLogs() async {
    if (_auditLoading) return;
    final app = context.read<AppState>();
    final token = app.authToken ?? AuthService.token;
    if (token == null) return;

    setState(() => _auditLoading = true);
    try {
      final uri = Uri.parse('${baseUrl}/api/finance/audit-logs').replace(
        queryParameters: _auditQueryParams(limit: 250, offset: 0),
      );

      final resp = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (resp.statusCode == 200) {
        final decoded = jsonDecode(resp.body);
        final itemsAny = (decoded is Map) ? decoded['items'] : null;
        final items = <Map<String, dynamic>>[];
        if (itemsAny is List) {
          for (final r in itemsAny) {
            if (r is Map<String, dynamic>) {
              items.add(r);
            } else if (r is Map) {
              items.add(r.map((k, v) => MapEntry(k.toString(), v)));
            }
          }
        }
        setState(() => _auditItems = items);
      } else {
        debugPrint('Audit logs error: ${resp.statusCode} ${resp.body}');
        setState(() => _auditItems = []);
      }
    } catch (e) {
      debugPrint('Audit logs exception: $e');
      setState(() => _auditItems = []);
    } finally {
      if (mounted) setState(() => _auditLoading = false);
    }
  }

  Future<void> _exportAuditLogs(String format) async {
    final app = context.read<AppState>();
    final token = app.authToken ?? AuthService.token;
    if (token == null) return;

    final uri = Uri.parse('${baseUrl}/api/finance/audit-logs/export').replace(
      queryParameters: {
        ..._auditQueryParams(limit: 5000, offset: 0),
        'format': format,
      },
    );

    final resp = await http.get(
      uri,
      headers: {
        'Authorization': 'Bearer $token',
        'Accept': format == 'pdf' ? 'application/pdf' : 'text/csv',
      },
    );

    if (resp.statusCode != 200) {
      debugPrint('Audit export failed: ${resp.statusCode} ${resp.body}');
      return;
    }

    if (kIsWeb) {
      final bytes = resp.bodyBytes;
      final mime = format == 'pdf' ? 'application/pdf' : 'text/csv';
      final fileName =
          'finance_audit_${DateTime.now().millisecondsSinceEpoch}.${format == 'pdf' ? 'pdf' : 'csv'}';
      final blob = html.Blob([bytes], mime);
      final url = html.Url.createObjectUrlFromBlob(blob);
      final anchor = html.AnchorElement(href: url)
        ..setAttribute('download', fileName)
        ..style.display = 'none';
      html.document.body?.children.add(anchor);
      anchor.click();
      html.document.body?.children.remove(anchor);
      Future.delayed(const Duration(milliseconds: 500), () {
        html.Url.revokeObjectUrl(url);
      });
    }
  }

  Future<void> _loadData() async {
    if (_isLoading) return;
    if (!mounted) return;

    final app = context.read<AppState>();

    // Sync token from AuthService if needed
    if (app.authToken == null && AuthService.token != null) {
      app.authToken = AuthService.token;
      app.currentUser = AuthService.currentUser;
    }

    if (app.authToken == null && AuthService.token == null) {
      return;
    }

    setState(() => _isLoading = true);
    try {
      await Future.wait([
        app.fetchProposals(light: false),
        app.fetchDashboard(),
        app.fetchNotifications(),
      ]);
    } catch (e) {
      debugPrint('Error loading finance dashboard: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<Map<String, dynamic>> _getFilteredProposals(
    AppState app, {
    bool ignoreStatusFilter = false,
  }) {
    final query = _searchController.text.toLowerCase().trim();
    final List<Map<String, dynamic>> result = [];

    DateTime? parseDate(dynamic value) {
      if (value == null) return null;
      if (value is DateTime) return value;
      final s = value.toString().trim();
      if (s.isEmpty) return null;
      try {
        return DateTime.parse(s);
      } catch (_) {
        return null;
      }
    }

    final List<Map<String, dynamic>> normalized = [];
    for (final raw in app.proposals) {
      if (raw is! Map) continue;
      final p = raw is Map<String, dynamic>
          ? raw
          : raw.map((k, v) => MapEntry(k.toString(), v));
      normalized.add(p);
    }

    normalized.sort((a, b) {
      final ad = parseDate(a['created_at'] ?? a['createdAt']);
      final bd = parseDate(b['created_at'] ?? b['createdAt']);
      if (ad == null && bd == null) return 0;
      if (ad == null) return 1;
      if (bd == null) return -1;
      return bd.compareTo(ad);
    });

    // Use a large limit so finance sees all non-draft proposals (e.g. sent for pricing)
    const int maxProposals = 500;
    final recent = normalized.take(maxProposals).toList();

    for (final p in recent) {
      final statusLower = (p['status'] ?? '').toString().trim().toLowerCase();
      if (statusLower == 'draft') continue;

      final bucket = _financePipelineBucket(statusLower);
      if (bucket.isEmpty) continue;

      final title = (p['title'] ?? '').toString().toLowerCase();
      final client =
          (p['client'] ?? p['client_name'] ?? '').toString().toLowerCase();
      final status = statusLower;

      if (query.isNotEmpty &&
          !(title.contains(query) || client.contains(query))) {
        continue;
      }

      final isPendingReview = status.contains('pending review') ||
          status.contains('pending approval');
      final isReleased =
          status.contains('released') || status.contains('sent to client');
      final isSigned = status.contains('signed') || status.contains('approved');

      if (!ignoreStatusFilter) {
        switch (_statusFilter) {
          case 'pending_review':
            if (!isPendingReview) {
              continue;
            }
            break;
          case 'in_pricing':
            if (!_isPricingInProgressStatus(status)) {
              continue;
            }
            break;
          case 'released':
            if (!isReleased) {
              continue;
            }
            break;
          case 'signed':
            if (!isSigned) {
              continue;
            }
            break;
          case 'all':
          default:
            break;
        }
      }

      result.add(p);
    }

    return result;
  }

  bool _isPricingInProgressStatus(String raw) {
    final s = raw.toLowerCase();
    return s.contains('pricing in progress') ||
        s.contains('in pricing') ||
        s == 'pricing in progress';
  }

  double _extractAmount(Map<String, dynamic> p) {
    final proposalId = p['id']?.toString();
    final cacheKey =
        '${p['updated_at'] ?? p['updatedAt'] ?? ''}|${p['budget'] ?? ''}|${p['amount'] ?? ''}|${p['total'] ?? ''}|${p['value'] ?? ''}|${p['price'] ?? ''}';
    if (proposalId != null) {
      final existingKey = _amountCacheKey[proposalId];
      if (existingKey == cacheKey && _amountCache.containsKey(proposalId)) {
        return _amountCache[proposalId] ?? 0;
      }
    }

    const keys = ['budget', 'amount', 'total', 'value', 'price'];
    for (final k in keys) {
      final v = p[k];
      if (v == null) continue;
      if (v is num) return v.toDouble();
      final s = v.toString();
      final cleaned = s.replaceAll(RegExp(r'[^0-9.\-]'), '');
      final parsed = double.tryParse(cleaned);
      if (parsed != null) return parsed;
    }

    double _parseNum(dynamic v) {
      if (v == null) return 0;
      if (v is num) return v.toDouble();
      final cleaned = v.toString().replaceAll(RegExp(r'[^0-9.\-]'), '');
      return double.tryParse(cleaned) ?? 0;
    }

    int? _findHeaderIndex(List<dynamic> headers, List<String> needles) {
      for (int i = 0; i < headers.length; i++) {
        final h = headers[i].toString().toLowerCase().trim();
        for (final n in needles) {
          if (h == n || h.contains(n)) return i;
        }
      }
      return null;
    }

    double _tableSubtotalFromCells(List<dynamic> cellsRaw) {
      if (cellsRaw.isEmpty) return 0;
      final headerRow = cellsRaw.first;
      if (headerRow is! List) return 0;

      final totalCol =
          _findHeaderIndex(headerRow, ['total', 'amount', 'line total']) ?? 4;
      final qtyCol = _findHeaderIndex(headerRow, ['quantity', 'qty']) ?? 2;
      final unitCol = _findHeaderIndex(headerRow, ['unit price', 'price']) ?? 3;

      double subtotal = 0;
      for (int i = 1; i < cellsRaw.length; i++) {
        final rowAny = cellsRaw[i];
        if (rowAny is! List) continue;

        final row = rowAny;
        double rowTotal = 0;
        if (totalCol >= 0 && totalCol < row.length) {
          rowTotal = _parseNum(row[totalCol]);
        }

        if (rowTotal == 0) {
          final qty = (qtyCol >= 0 && qtyCol < row.length)
              ? _parseNum(row[qtyCol])
              : 0.0;
          final unit = (unitCol >= 0 && unitCol < row.length)
              ? _parseNum(row[unitCol])
              : 0.0;
          rowTotal = qty * unit;
        }

        subtotal += rowTotal;
      }
      return subtotal;
    }

    double _sumPriceTablesFromSections(dynamic sectionsAny) {
      final List<dynamic> sectionsList;
      if (sectionsAny is List) {
        sectionsList = sectionsAny;
      } else if (sectionsAny is Map && sectionsAny['sections'] is List) {
        sectionsList = sectionsAny['sections'] as List;
      } else {
        return 0;
      }

      double _sumPriceTablesFromSectionMap(Map sAny) {
        double total = 0;

        void sumTablesList(dynamic tablesAny) {
          if (tablesAny is! List) return;
          for (final tAny in tablesAny) {
            if (tAny is! Map) continue;
            final type = (tAny['type'] ?? '').toString().toLowerCase().trim();
            if (type != 'price') continue;
            final cellsAny = tAny['cells'];
            if (cellsAny is! List) continue;
            final subtotal = _tableSubtotalFromCells(cellsAny);
            final vatRate = _parseNum(tAny['vatRate']);
            final vat = vatRate > 0 ? subtotal * vatRate : 0;
            total += (subtotal + vat);
          }
        }

        void sumPositionedTables(dynamic positionedAny) {
          if (positionedAny is! List) return;
          for (final pAny in positionedAny) {
            if (pAny is! Map) continue;
            final tableAny = pAny['table'];
            if (tableAny is! Map) continue;
            sumTablesList([tableAny]);
          }
        }

        sumTablesList(sAny['tables']);
        sumPositionedTables(sAny['positionedPricingTables']);

        final bodyAny = sAny['body'] ?? sAny['content'];
        if (bodyAny is Map) {
          sumTablesList(bodyAny['tables']);
          sumPositionedTables(bodyAny['positionedPricingTables']);
        }

        return total;
      }

      double total = 0;
      for (final sAny in sectionsList) {
        if (sAny is! Map) continue;
        total += _sumPriceTablesFromSectionMap(sAny);
      }
      return total;
    }

    dynamic sectionsAny = p['sections'];
    if (sectionsAny == null) {
      final contentAny = p['content'];
      if (contentAny is Map) {
        sectionsAny = contentAny['sections'] ?? contentAny;
      } else if (contentAny is String) {
        final raw = contentAny;
        if (raw.length > 50000) {
          if (proposalId != null) {
            _amountCache[proposalId] = 0;
            _amountCacheKey[proposalId] = cacheKey;
          }
          return 0;
        }
        try {
          final decoded = jsonDecode(contentAny);
          if (decoded is Map || decoded is List) {
            sectionsAny = decoded;
          }
        } catch (_) {}
      }
    }

    final computed = _sumPriceTablesFromSections(sectionsAny);
    if (proposalId != null) {
      _amountCache[proposalId] = computed;
      _amountCacheKey[proposalId] = cacheKey;
    }
    return computed;
  }

  String _formatCurrency(double amount) {
    if (amount <= 0) return '--';
    final rounded = amount.round();
    final s = rounded.toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      final fromEnd = s.length - i;
      buf.write(s[i]);
      if (fromEnd > 1 && fromEnd % 3 == 1) {
        buf.write(',');
      }
    }
    return 'R${buf.toString()}';
  }

  String _formatPercent(double value) {
    final pct = (value * 100).clamp(0, 999);
    if (pct.isNaN || pct.isInfinite) return '--';
    return '${pct.toStringAsFixed(0)}%';
  }

  String _financePipelineBucket(String rawStatus) {
    final s = rawStatus.toLowerCase();
    if (_isPricingInProgressStatus(s)) return 'In Pricing';
    if (s.contains('pending review') || s.contains('pending approval')) {
      return 'Pending Review';
    }
    if (s.contains('changes requested') || s.contains('needs changes')) {
      return 'Changes Requested';
    }
    if (s.contains('released') || s.contains('sent to client')) {
      return 'Released';
    }
    if (s.contains('signed') || s.contains('approved')) {
      return 'Signed';
    }
    return 'Unknown';
  }

  Widget _buildAuditPanel() {
    final chrome = context.watch<ManagerThemeController>().chrome;
    final dateFmt = DateFormat('yyyy-MM-dd');
    final fromLabel = _auditFrom == null ? 'From' : dateFmt.format(_auditFrom!);
    final toLabel = _auditTo == null ? 'To' : dateFmt.format(_auditTo!);
    final panelFill = chrome.isDark
        ? Colors.white.withOpacity(0.04)
        : Colors.white.withValues(alpha: 0.88);
    final panelBorder = chrome.isDark
        ? Colors.white.withOpacity(0.08)
        : Colors.black.withValues(alpha: 0.10);
    final fieldFill = chrome.isDark
        ? Colors.white.withValues(alpha: 0.03)
        : Colors.white.withValues(alpha: 0.96);
    final fieldBorder =
        chrome.isDark ? Colors.white24 : Colors.black.withValues(alpha: 0.18);
    final labelColor = chrome.isDark ? Colors.white70 : chrome.textSecondary;
    final valueColor = chrome.textPrimary;
    final subtleText = chrome.isDark ? Colors.white70 : chrome.textSecondary;
    final headingColor = chrome.textPrimary;
    final tableHeadingColor = chrome.isDark
        ? Colors.white.withValues(alpha: 0.92)
        : chrome.textPrimary;
    final tableRowColor = chrome.isDark
        ? Colors.white70
        : chrome.textPrimary.withValues(alpha: 0.92);
    final buttonBorder = chrome.isDark
        ? Colors.white.withValues(alpha: 0.16)
        : Colors.black.withValues(alpha: 0.12);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: panelFill,
        border: Border.all(color: panelBorder),
        boxShadow: chrome.isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                'Audit Logs',
                style: PremiumTheme.titleMedium.copyWith(color: headingColor),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () => _exportAuditLogs('csv'),
                style: TextButton.styleFrom(
                  foregroundColor: subtleText,
                  side: BorderSide(color: buttonBorder),
                  backgroundColor: fieldFill,
                ),
                icon: Icon(Icons.download, color: subtleText, size: 18),
                label: Text('CSV', style: TextStyle(color: subtleText)),
              ),
              const SizedBox(width: 8),
              TextButton.icon(
                onPressed: () => _exportAuditLogs('pdf'),
                style: TextButton.styleFrom(
                  foregroundColor: subtleText,
                  side: BorderSide(color: buttonBorder),
                  backgroundColor: fieldFill,
                ),
                icon: Icon(Icons.picture_as_pdf, color: subtleText, size: 18),
                label: Text('PDF', style: TextStyle(color: subtleText)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: subtleText,
                  backgroundColor: fieldFill,
                  side: BorderSide(color: fieldBorder),
                ),
                onPressed: () async {
                  final picked = await showGlassDatePicker(
                    context: context,
                    initialDate: _auditFrom ?? DateTime.now(),
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2100),
                  );
                  if (picked == null) return;
                  setState(() => _auditFrom = picked);
                  _loadAuditLogs();
                },
                icon: Icon(Icons.date_range, color: subtleText),
                label: Text(fromLabel, style: TextStyle(color: subtleText)),
              ),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: subtleText,
                  backgroundColor: fieldFill,
                  side: BorderSide(color: fieldBorder),
                ),
                onPressed: () async {
                  final picked = await showGlassDatePicker(
                    context: context,
                    initialDate: _auditTo ?? DateTime.now(),
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2100),
                  );
                  if (picked == null) return;
                  setState(() => _auditTo = picked);
                  _loadAuditLogs();
                },
                icon: Icon(Icons.date_range, color: subtleText),
                label: Text(toLabel, style: TextStyle(color: subtleText)),
              ),
              SizedBox(
                width: 220,
                child: TextField(
                  controller: _auditUserController,
                  style: TextStyle(color: valueColor),
                  decoration: InputDecoration(
                    labelText: 'User',
                    labelStyle: TextStyle(color: labelColor),
                    filled: true,
                    fillColor: fieldFill,
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: fieldBorder),
                    ),
                    focusedBorder: const OutlineInputBorder(
                      borderSide: BorderSide(color: PremiumTheme.teal),
                    ),
                  ),
                  onSubmitted: (_) => _loadAuditLogs(),
                ),
              ),
              SizedBox(
                width: 220,
                child: TextField(
                  controller: _auditEntityTypeController,
                  style: TextStyle(color: valueColor),
                  decoration: InputDecoration(
                    labelText: 'Entity Type',
                    labelStyle: TextStyle(color: labelColor),
                    filled: true,
                    fillColor: fieldFill,
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: fieldBorder),
                    ),
                    focusedBorder: const OutlineInputBorder(
                      borderSide: BorderSide(color: PremiumTheme.teal),
                    ),
                  ),
                  onSubmitted: (_) => _loadAuditLogs(),
                ),
              ),
              SizedBox(
                width: 220,
                child: TextField(
                  controller: _auditActionTypeController,
                  style: TextStyle(color: valueColor),
                  decoration: InputDecoration(
                    labelText: 'Action Type',
                    labelStyle: TextStyle(color: labelColor),
                    filled: true,
                    fillColor: fieldFill,
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: fieldBorder),
                    ),
                    focusedBorder: const OutlineInputBorder(
                      borderSide: BorderSide(color: PremiumTheme.teal),
                    ),
                  ),
                  onSubmitted: (_) => _loadAuditLogs(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_auditLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(18),
                child: CircularProgressIndicator(color: PremiumTheme.teal),
              ),
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: WidgetStatePropertyAll(
                  chrome.isDark
                      ? Colors.white.withValues(alpha: 0.05)
                      : Colors.black.withValues(alpha: 0.04),
                ),
                dataRowColor: WidgetStatePropertyAll(fieldFill),
                dividerThickness: 0.6,
                columns: [
                  DataColumn(
                      label: Text('Time',
                          style: TextStyle(color: tableHeadingColor))),
                  DataColumn(
                      label: Text('User',
                          style: TextStyle(color: tableHeadingColor))),
                  DataColumn(
                      label: Text('Entity',
                          style: TextStyle(color: tableHeadingColor))),
                  DataColumn(
                      label: Text('Action',
                          style: TextStyle(color: tableHeadingColor))),
                  DataColumn(
                      label: Text('Field',
                          style: TextStyle(color: tableHeadingColor))),
                  DataColumn(
                      label: Text('Old',
                          style: TextStyle(color: tableHeadingColor))),
                  DataColumn(
                      label: Text('New',
                          style: TextStyle(color: tableHeadingColor))),
                ],
                rows: _auditItems.map((r) {
                  final createdAt = (r['created_at'] ?? '').toString();
                  final uname = (r['username'] ?? '').toString();
                  final entity =
                      '${(r['entity_type'] ?? '').toString()}#${(r['entity_id'] ?? '').toString()}';
                  final action = (r['action_type'] ?? '').toString();
                  final field = (r['field_name'] ?? '').toString();
                  final oldV = (r['old_value'] ?? '').toString();
                  final newV = (r['new_value'] ?? '').toString();

                  Text cell(String v) => Text(
                        v,
                        style: PremiumTheme.bodySmall
                            .copyWith(color: tableRowColor),
                        overflow: TextOverflow.ellipsis,
                      );

                  return DataRow(cells: [
                    DataCell(cell(createdAt)),
                    DataCell(cell(uname)),
                    DataCell(cell(entity)),
                    DataCell(cell(action)),
                    DataCell(cell(field)),
                    DataCell(cell(oldV)),
                    DataCell(cell(newV)),
                  ]);
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildNotificationButton(AppState app) {
    final unread = _unreadNotificationCount(app, messagesOnly: false);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        SizedBox(
          width: 44,
          height: 44,
          child: IconButton(
            tooltip: 'Notifications',
            icon: Icon(
              unread > 0
                  ? Icons.notifications_active
                  : Icons.notifications_none,
              color: Colors.white,
            ),
            onPressed: () async {
              await app.fetchNotifications();
              if (!mounted) return;
              _showNotificationsSheet(app, messagesOnly: false);
            },
          ),
        ),
        if (unread > 0)
          Positioned(
            right: 6,
            top: 6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: const BoxDecoration(
                color: Color(0xFFE74C3C),
                borderRadius: BorderRadius.all(Radius.circular(12)),
              ),
              child: Text(
                unread > 99 ? '99+' : unread.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
      ],
    );
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

  void _showNotificationsSheet(AppState app, {bool messagesOnly = false}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (bottomSheetContext) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFF1A1A2A),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: StatefulBuilder(
            builder: (context, setModalState) {
              final notifications =
                  _notificationsFiltered(app, messagesOnly: messagesOnly);
              final unreadCount =
                  _unreadNotificationCount(app, messagesOnly: messagesOnly);

              return Container(
                constraints: BoxConstraints(
                  maxHeight:
                      MediaQuery.of(bottomSheetContext).size.height * 0.8,
                ),
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(bottomSheetContext).viewInsets.bottom,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: const BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: Color(0xFF2C3E50),
                            width: 1,
                          ),
                        ),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                messagesOnly ? 'Messages' : 'Notifications',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                              ),
                              if (unreadCount > 0)
                                TextButton(
                                  onPressed: () async {
                                    await app.markAllNotificationsRead();
                                    setModalState(() {});
                                  },
                                  style: TextButton.styleFrom(
                                    backgroundColor: const Color(0xFF3498DB),
                                  ),
                                  child: const Text(
                                    'Mark all read',
                                    style: TextStyle(color: Colors.white),
                                  ),
                                ),
                              TextButton(
                                onPressed: notifications.isEmpty
                                    ? null
                                    : () async {
                                        await app.deleteAllNotifications();
                                        setModalState(() {});
                                      },
                                child: const Text('Delete all'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          vertical: 12,
                          horizontal: 16,
                        ),
                        child: notifications.isEmpty
                            ? Center(
                                child: Text(
                                  messagesOnly
                                      ? 'No comment messages yet.'
                                      : 'No notifications yet.',
                                  style: const TextStyle(
                                    color: Color(0xFF4A4A4A),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              )
                            : ListView.separated(
                                padding: const EdgeInsets.symmetric(
                                    vertical: 12, horizontal: 16),
                                itemCount: notifications.length,
                                separatorBuilder: (_, __) =>
                                    const Divider(height: 16),
                                itemBuilder: (context, index) {
                                  final rawItem = notifications[index];
                                  final Map<String, dynamic> notification =
                                      rawItem is Map<String, dynamic>
                                          ? rawItem
                                          : (rawItem is Map
                                              ? rawItem.cast<String, dynamic>()
                                              : <String, dynamic>{});

                                  final title =
                                      notification['title']?.toString().trim();
                                  final message = notification['message']
                                          ?.toString()
                                          .trim() ??
                                      '';
                                  final proposalTitle =
                                      notification['proposal_title']
                                          ?.toString()
                                          .trim();
                                  final isRead =
                                      notification['is_read'] == true;
                                  final timeLabel =
                                      _formatNotificationTimestamp(
                                          notification['created_at']);

                                  final dynamic notificationIdRaw =
                                      notification['id'];
                                  final int? notificationId = notificationIdRaw
                                          is int
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
                                        notificationId,
                                        isAlreadyRead: isRead,
                                      );
                                    },
                                    leading: Icon(
                                      messagesOnly
                                          ? (isRead
                                              ? Icons.chat_bubble_outline
                                              : Icons.mark_chat_unread_outlined)
                                          : (isRead
                                              ? Icons
                                                  .notifications_none_outlined
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
                                        color: Colors.white,
                                        fontWeight: isRead
                                            ? FontWeight.w600
                                            : FontWeight.w700,
                                      ),
                                    ),
                                    subtitle: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        if (message.isNotEmpty)
                                          Padding(
                                            padding:
                                                const EdgeInsets.only(top: 4),
                                            child: Text(
                                              message,
                                              style: const TextStyle(
                                                color: Color(0xFFCBD5E1),
                                                fontSize: 12,
                                              ),
                                            ),
                                          ),
                                        if (proposalTitle != null &&
                                            proposalTitle.isNotEmpty)
                                          Padding(
                                            padding:
                                                const EdgeInsets.only(top: 4),
                                            child: Text(
                                              proposalTitle,
                                              style: const TextStyle(
                                                color: Color(0xFF94A3B8),
                                                fontSize: 11,
                                              ),
                                            ),
                                          ),
                                        if (timeLabel.isNotEmpty)
                                          Padding(
                                            padding:
                                                const EdgeInsets.only(top: 4),
                                            child: Text(
                                              timeLabel,
                                              style: const TextStyle(
                                                color: Color(0xFF94A3B8),
                                                fontSize: 11,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                    isThreeLine: true,
                                    trailing: notificationId != null
                                        ? Wrap(
                                            spacing: 4,
                                            children: [
                                              if (!isRead)
                                                TextButton(
                                                  onPressed: () async {
                                                    await app
                                                        .markNotificationRead(
                                                            notificationId);
                                                    setModalState(() {});
                                                  },
                                                  child:
                                                      const Text('Mark read'),
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
                                        : null,
                                  );
                                },
                              ),
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

  Future<void> _handleNotificationTap(
      AppState app, Map<String, dynamic> notification, int? notificationId,
      {required bool isAlreadyRead}) async {
    final metadata = _parseNotificationMetadata(notification['metadata']);
    String? proposalId = _asIdString(
      metadata['proposal_id'] ?? notification['proposal_id'],
    );
    proposalId ??= _asIdString(metadata['resource_id']);
    final proposalTitle =
        notification['proposal_title']?.toString().trim().isNotEmpty == true
            ? notification['proposal_title'].toString().trim()
            : notification['title']?.toString().trim();
    final commentId = metadata['comment_id'] is int
        ? metadata['comment_id'] as int
        : int.tryParse(metadata['comment_id']?.toString() ?? '');
    final sectionIndex = metadata['section_index'] is int
        ? metadata['section_index'] as int
        : int.tryParse(metadata['section_index']?.toString() ?? '');

    if (!isAlreadyRead && notificationId != null) {
      try {
        await app.markNotificationRead(notificationId);
      } catch (e) {
        debugPrint('Error marking notification as read: $e');
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

    Navigator.of(context).pushNamed(
      '/compose',
      arguments: {
        'proposalId': proposalId,
        if (proposalTitle != null && proposalTitle.isNotEmpty)
          'proposalTitle': proposalTitle,
        'forceCommentsPanelOpen': true,
        if (commentId != null) 'initialCommentId': commentId,
        if (sectionIndex != null) 'initialSectionIndex': sectionIndex,
      },
    );
  }

  Map<String, dynamic> _parseNotificationMetadata(dynamic raw) {
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) return raw.cast<String, dynamic>();
    if (raw is String && raw.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) return decoded;
        if (decoded is Map) return decoded.cast<String, dynamic>();
      } catch (_) {}
    }
    return <String, dynamic>{};
  }

  String? _asIdString(dynamic value) {
    if (value == null) return null;
    final text = value.toString().trim();
    if (text.isEmpty || text.toLowerCase() == 'null') return null;
    return text;
  }

  DateTime _toSast(DateTime dt) {
    final utc = dt.isUtc
        ? dt
        : DateTime.utc(dt.year, dt.month, dt.day, dt.hour, dt.minute, dt.second,
            dt.millisecond, dt.microsecond);
    return utc.add(const Duration(hours: 2));
  }

  String _formatNotificationTimestamp(dynamic timestamp) {
    if (timestamp == null) return '';
    try {
      final dateTime = DateTime.parse(timestamp.toString());
      final sast = _toSast(dateTime);
      final now = _toSast(DateTime.now().toUtc());
      final difference = now.difference(sast);

      if (difference.inDays > 0) {
        return '${sast.day}/${sast.month}/${sast.year}';
      } else if (difference.inHours > 0) {
        return '${difference.inHours}h ago';
      } else if (difference.inMinutes > 0) {
        return '${difference.inMinutes}m ago';
      } else {
        return 'Just now';
      }
    } catch (e) {
      return '';
    }
  }

  double _computeAvgCycleTimeDays(List<Map<String, dynamic>> proposals) {
    double sumDays = 0;
    int n = 0;

    for (final p in proposals) {
      final createdRaw = p['created_at'] ?? p['createdAt'];
      final updatedRaw = p['updated_at'] ?? p['updatedAt'];

      if (createdRaw == null || updatedRaw == null) continue;
      final created = DateTime.tryParse(createdRaw.toString());
      final updated = DateTime.tryParse(updatedRaw.toString());
      if (created == null || updated == null) continue;

      final diff = updated.difference(created);
      final days = diff.inMinutes / (60 * 24);
      if (days.isNaN || days.isInfinite || days < 0) continue;

      sumDays += days;
      n += 1;
    }

    if (n == 0) return 0;
    return sumDays / n;
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final chrome = context.watch<ManagerThemeController>().chrome;
    final isSidebarCollapsed = app.isFinanceSidebarCollapsed;
    final dashboardProposals =
        _getFilteredProposals(app, ignoreStatusFilter: true);
    final proposalsTabProposals = _getFilteredProposals(app);
    final proposals =
        _currentTab == 'dashboard' ? dashboardProposals : proposalsTabProposals;

    final pendingBadge = app.proposals
        .where((p) =>
            (p is Map) &&
            _isPricingInProgressStatus((p['status'] ?? '').toString()))
        .length;

    final pricingCount = proposals
        .where(
            (p) => _isPricingInProgressStatus((p['status'] ?? '').toString()))
        .length;
    final approvedCount = proposals
        .where((p) => ((p['status'] ?? '')
                .toString()
                .toLowerCase()
                .contains('approved') ||
            (p['status'] ?? '').toString().toLowerCase().contains('signed')))
        .length;

    final sentToClientCount = proposals
        .where((p) => (p['status'] ?? '')
            .toString()
            .toLowerCase()
            .contains('sent to client'))
        .length;

    double totalAmount = 0;
    for (final p in proposals) {
      totalAmount += _extractAmount(p);
    }

    final requiresAttention = proposals
        .where(
            (p) => _isPricingInProgressStatus((p['status'] ?? '').toString()))
        .toList();

    final size = MediaQuery.of(context).size;
    final isMobile = size.width < 900;

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton(
        heroTag: 'finance_dashboard_theme_toggle',
        backgroundColor: ManagerChromeTheme.accentRed,
        onPressed: () => context.read<ManagerThemeController>().toggle(),
        child: Icon(
          chrome.isDark ? Icons.wb_sunny_rounded : Icons.dark_mode_rounded,
          color: Colors.white,
        ),
      ),
      body: ManagerPageBackground(
        child: Row(
          children: [
            FinanceSidebar(
              isCollapsed: isSidebarCollapsed,
              currentPage: _currentTab == 'dashboard'
                  ? 'Dashboard'
                  : _currentTab == 'proposals'
                      ? 'Proposals'
                      : _currentTab == 'clients'
                          ? 'Client Management'
                          : _currentTab == 'audit'
                              ? 'Audit'
                              : 'Dashboard',
              showAudit: _canAccessAudit(app),
              pendingBadge: pendingBadge > 0 ? pendingBadge : null,
              managerChrome: chrome,
              onToggle: app.toggleFinanceSidebar,
              onSelect: (label) {
                if (label == 'Dashboard') {
                  setState(() => _currentTab = 'dashboard');
                  return;
                }
                if (label == 'Proposals') {
                  setState(() => _currentTab = 'proposals');
                  return;
                }
                if (label == 'Client Management') {
                  setState(() => _currentTab = 'clients');
                  return;
                }
                if (label == 'Audit') {
                  setState(() => _currentTab = 'audit');
                  _loadAuditLogs();
                  return;
                }
                if (label == 'Analytics') {
                  Navigator.pushNamed(context, '/analytics');
                  return;
                }
                if (label == 'Account Profile') {
                  Navigator.pushReplacementNamed(
                      context, '/manager_account_profile');
                  return;
                }
                if (label == 'Sign Out' || label == 'Logout') {
                  app.logout();
                  AuthService.logout();
                  Navigator.pushNamed(context, '/login');
                  return;
                }
              },
            ),
            Expanded(
              child: Column(
                children: [
                  _buildHeader(app, isMobile, chrome),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: _currentTab == 'clients'
                          ? const FinanceClientManagementPage()
                          : (_currentTab == 'proposals'
                              ? SingleChildScrollView(
                                  controller: _scrollController,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      _buildProposalsOverviewPanel(
                                        chrome: chrome,
                                        proposals: proposalsTabProposals,
                                      ),
                                      const SizedBox(height: 24),
                                      const Footer(),
                                    ],
                                  ),
                                )
                              : CustomScrollbar(
                                  controller: _scrollController,
                                  child: SingleChildScrollView(
                                    controller: _scrollController,
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        if (_currentTab == 'dashboard') ...[
                                          _buildFinanceKpis(),
                                          const SizedBox(height: 16),
                                          _buildChartsRow(),
                                          const SizedBox(height: 12),
                                          LayoutBuilder(
                                            builder: (context, constraints) {
                                              final isNarrow =
                                                  constraints.maxWidth < 1100;
                                              const panelHeight = 330.0;
                                              final left =
                                                  _buildSimpleListPanel(
                                                title: 'Top Clients by Revenue',
                                                subtitle:
                                                    'Highest revenue clients',
                                                iconPath: _topClientsIcon,
                                                child: _buildTopClientsPanel(),
                                              );
                                              final mid = _buildSimpleListPanel(
                                                title: 'Recent Signed Deals',
                                                subtitle:
                                                    'Latest signed proposals',
                                                iconPath: _recentSignedIcon,
                                                child:
                                                    _buildRecentSignedPanel(),
                                              );
                                              final right =
                                                  _buildSimpleListPanel(
                                                title: 'Pipeline Aging Report',
                                                subtitle:
                                                    'Deals stuck > 30 days',
                                                iconPath: _agingReportIcon,
                                                child: _buildAgingPanel(),
                                              );

                                              if (isNarrow) {
                                                return Column(
                                                  children: [
                                                    SizedBox(
                                                      height: panelHeight,
                                                      child: left,
                                                    ),
                                                    const SizedBox(height: 12),
                                                    SizedBox(
                                                      height: panelHeight,
                                                      child: mid,
                                                    ),
                                                    const SizedBox(height: 12),
                                                    SizedBox(
                                                      height: panelHeight,
                                                      child: right,
                                                    ),
                                                  ],
                                                );
                                              }

                                              return Row(
                                                children: [
                                                  Expanded(
                                                    child: SizedBox(
                                                      height: panelHeight,
                                                      child: left,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 12),
                                                  Expanded(
                                                    child: SizedBox(
                                                      height: panelHeight,
                                                      child: mid,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 12),
                                                  Expanded(
                                                    child: SizedBox(
                                                      height: panelHeight,
                                                      child: right,
                                                    ),
                                                  ),
                                                ],
                                              );
                                            },
                                          ),
                                          const SizedBox(height: 12),
                                          _buildSimpleListPanel(
                                            title: 'AI Usage',
                                            subtitle:
                                                'Live usage for AI Assistant + Risk Gate (last 30 days, auto-refresh)',
                                            iconPath: _aiUsageIcon,
                                            child:
                                                _buildAiUsageDashboardPanel(),
                                          ),
                                          const SizedBox(height: 12),
                                          _buildFinancialAlertsPanel(),
                                          const SizedBox(height: 12),
                                          _buildRequiresAttention(
                                              requiresAttention),
                                          const SizedBox(height: 24),
                                          const Footer(),
                                        ] else ...[
                                          _buildAuditPanel(),
                                          const SizedBox(height: 24),
                                          const Footer(),
                                        ],
                                      ],
                                    ),
                                  ),
                                )),
                    ),
                  ),
                  if (_currentTab == 'proposals')
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          width: 114.93836212158203,
                          height: 18,
                          decoration: BoxDecoration(
                            color: chrome.fieldFill,
                            borderRadius: BorderRadius.circular(4.3),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            AppConstants.fullVersion,
                            style: TextStyle(
                              fontSize: 9,
                              color: chrome.textMuted,
                              height: 1,
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
    );
  }

  Widget _buildProposalsOverviewPanel({
    required ManagerChromeTheme chrome,
    required List<Map<String, dynamic>> proposals,
  }) {
    final filtered = proposals.where((p) {
      final title = (p['title'] ?? '').toString().toLowerCase();
      final client =
          (p['client_name'] ?? p['client'] ?? '').toString().toLowerCase();
      final q = _searchController.text.toLowerCase();
      final matchesSearch = title.contains(q) || client.contains(q);

      final effectiveStatusFilter =
          _validStatusFilters.contains(_statusFilter) ? _statusFilter : 'all';
      final matchesStatus = effectiveStatusFilter == 'all'
          ? true
          : _financePipelineBucket((p['status'] ?? '').toString()) ==
              _financeBucketForFilter(effectiveStatusFilter);

      return matchesSearch && matchesStatus;
    }).toList();

    final panelWidth = MediaQuery.of(context).size.width;
    final targetWidth = panelWidth > 1100 ? 946.2045288461986 : double.infinity;

    return Container(
      width: targetWidth,
      decoration: BoxDecoration(
        color: const Color(0x24FFFFFF),
        borderRadius: BorderRadius.circular(5.32),
        boxShadow: const [
          BoxShadow(
            color: Color(0x40000000),
            blurRadius: 3.55,
            offset: Offset(0, 3.55),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: _buildManagerLikeToolbar(chrome),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Divider(
              color: chrome.divider,
              height: 1,
              thickness: 1,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child: _buildManagerLikeProposalList(
              chrome: chrome,
              filtered: filtered,
              all: proposals,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildManagerLikeToolbar(ManagerChromeTheme chrome) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Image.asset(
          _proposalsOverviewIcon,
          width: 86,
          height: 86,
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
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                    letterSpacing: 0.2,
                    color: chrome.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  "Manage all your business proposals & SOW's",
                  style: TextStyle(fontSize: 12, color: chrome.textSecondary),
                ),
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
                            hintText: 'Search Proposals or Clients...',
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
                    _searchIcon,
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
              value: _validStatusFilters.contains(_statusFilter)
                  ? _statusFilter
                  : 'all',
              dropdownColor: const Color(0xFF4B5563),
              icon: const Icon(
                Icons.keyboard_arrow_down,
                color: Colors.white,
                size: 20,
              ),
              style: const TextStyle(color: Colors.white, fontSize: 14),
              items: const [
                DropdownMenuItem(value: 'all', child: Text('All Statuses')),
                DropdownMenuItem(
                    value: 'pending_review', child: Text('Pending Review')),
                DropdownMenuItem(
                    value: 'in_pricing', child: Text('In Pricing')),
                DropdownMenuItem(value: 'released', child: Text('Released')),
                DropdownMenuItem(value: 'signed', child: Text('Signed')),
              ],
              onChanged: (v) => setState(() => _statusFilter = v ?? 'all'),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildManagerLikeProposalList({
    required ManagerChromeTheme chrome,
    required List<Map<String, dynamic>> filtered,
    required List<Map<String, dynamic>> all,
  }) {
    if (_isLoading) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(PremiumTheme.teal),
          ),
        ),
      );
    }

    if (all.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 48.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.description_outlined,
                  size: 64, color: chrome.textMuted),
              const SizedBox(height: 16),
              Text(
                'No proposals yet',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: chrome.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Proposals will appear here once created.',
                style: TextStyle(color: chrome.textSecondary),
              ),
            ],
          ),
        ),
      );
    }

    if (filtered.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 48.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.search_off_outlined,
                  size: 64, color: chrome.textMuted),
              const SizedBox(height: 16),
              Text(
                'No proposals match your filters',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: chrome.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Try adjusting your search or status.',
                style: TextStyle(color: chrome.textSecondary),
              ),
            ],
          ),
        ),
      );
    }

    const rowExtent = 64.0;
    const visibleRows = 6;

    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: rowExtent * visibleRows),
      child: ListView.builder(
        controller: _proposalsListScrollController,
        itemExtent: rowExtent,
        itemCount: filtered.length,
        itemBuilder: (context, index) {
          final proposal = filtered[index];
          return _FinanceProposalRow(
            proposal: proposal,
            chrome: chrome,
            formatCurrency: _formatCurrency,
            extractAmount: _extractAmount,
            formatLastModified: _formatLastModified,
            statusLabel: _financeStatusLabel,
            statusColor: _financeStatusColor,
            onView: () {
              final proposalId = proposal['id']?.toString();
              final title =
                  (proposal['title'] ?? 'Untitled Proposal').toString();
              if (proposalId == null || proposalId.isEmpty) return;
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => BlankDocumentEditorPage(
                    proposalId: proposalId,
                    proposalTitle: title,
                    readOnly: false,
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  String _financeBucketForFilter(String filter) {
    switch (filter) {
      case 'pending_review':
        return 'Pending Review';
      case 'in_pricing':
        return 'In Pricing';
      case 'released':
        return 'Released';
      case 'signed':
        return 'Signed';
      default:
        return 'All';
    }
  }

  String _financeStatusLabel(String statusRaw) {
    final bucket = _financePipelineBucket(statusRaw);
    switch (bucket) {
      case 'In Pricing':
        return 'Pricing In Progress';
      case 'Pending Review':
        return 'Sent for Approval';
      case 'Released':
        return 'Awaiting Signature';
      case 'Signed':
        return 'Signed';
      default:
        final s = statusRaw.trim();
        return s.isEmpty ? 'Drafted' : s;
    }
  }

  Color _financeStatusColor(String statusRaw) {
    final bucket = _financePipelineBucket(statusRaw);
    switch (bucket) {
      case 'In Pricing':
        return const Color(0xFF5C389D);
      case 'Pending Review':
        return const Color(0xFFEA990C);
      case 'Released':
        return const Color(0xFF6095CC);
      case 'Signed':
        return const Color(0xFF6CA510);
      default:
        return const Color(0xFF4B5563);
    }
  }

  String _formatLastModified(dynamic date) {
    if (date == null) return 'Unknown';
    if (date is String) {
      try {
        final hasTimezone = RegExp(r'(Z|[+-]\\d{2}:\\d{2})$').hasMatch(date);
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
      } catch (_) {
        return date.toString();
      }
    }

    return date.toString();
  }

  Widget _buildBreadcrumb() {
    final label = _currentTab == 'dashboard'
        ? 'Dashboard'
        : (_currentTab == 'clients'
            ? 'Client Management'
            : (_currentTab == 'audit' ? 'Audit' : 'Proposals'));
    return Row(
      children: [
        Text(
          'Finance',
          style: PremiumTheme.bodyMedium.copyWith(color: Colors.white70),
        ),
        const SizedBox(width: 8),
        Icon(Icons.chevron_right, color: Colors.white54, size: 18),
        const SizedBox(width: 8),
        Text(
          label,
          style: PremiumTheme.bodyMedium.copyWith(color: Colors.white),
        ),
      ],
    );
  }

  Widget _buildDashboardTitle() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Finance Dashboard',
          style: PremiumTheme.titleLarge.copyWith(fontSize: 24),
        ),
        const SizedBox(height: 4),
        Text(
          'Overview of proposal pipeline and financial performance',
          style: PremiumTheme.bodyMedium.copyWith(color: Colors.white70),
        ),
      ],
    );
  }

  Widget _buildPipelineChart() {
    final app = context.read<AppState>();
    final proposals = _getFilteredProposals(app, ignoreStatusFilter: true);

    int inPricing = 0;
    int pendingReview = 0;
    int changesRequested = 0;
    int released = 0;
    int signed = 0;

    for (final p in proposals) {
      final bucket = _financePipelineBucket((p['status'] ?? '').toString());
      switch (bucket) {
        case 'In Pricing':
          inPricing += 1;
          break;
        case 'Pending Review':
          pendingReview += 1;
          break;
        case 'Changes Requested':
          changesRequested += 1;
          break;
        case 'Released':
          released += 1;
          break;
        case 'Signed':
          signed += 1;
          break;
        default:
          break;
      }
    }

    final labels = <String>[
      'In Pricing',
      'Pending Review',
      'Changes\nRequested',
      'Released',
      'Signed',
    ];
    final ys = <double>[
      inPricing.toDouble(),
      pendingReview.toDouble(),
      changesRequested.toDouble(),
      released.toDouble(),
      signed.toDouble(),
    ];
    final colors = <Color>[
      const Color(0xFF9CA3AF),
      const Color(0xFF3B82F6),
      const Color(0xFFF59E0B),
      const Color(0xFFEAB308),
      const Color(0xFF84CC16),
    ];

    final maxY = (ys.fold<double>(0, (a, b) => a > b ? a : b)).clamp(1, 999);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
      child: BarChart(
        BarChartData(
          maxY: maxY + 1,
          minY: 0,
          alignment: BarChartAlignment.spaceAround,
          groupsSpace: 18,
          barTouchData: BarTouchData(
            enabled: true,
            touchTooltipData: BarTouchTooltipData(
              tooltipPadding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 8,
              ),
              tooltipMargin: 12,
              getTooltipColor: (group) => Colors.white.withOpacity(0.92),
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                final label = groupIndex >= 0 && groupIndex < labels.length
                    ? labels[groupIndex]
                    : '';
                final count = rod.toY.round();
                return BarTooltipItem(
                  '$label\ncount : $count',
                  PremiumTheme.bodyMedium.copyWith(
                    color: Colors.black87,
                    fontWeight: FontWeight.w600,
                  ),
                );
              },
            ),
          ),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (value) => FlLine(
              color: Colors.white.withOpacity(0.08),
              strokeWidth: 1,
            ),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                interval: 10,
                getTitlesWidget: (value, meta) {
                  if (value % 10 != 0) return const SizedBox.shrink();
                  return Text(
                    value.toInt().toString(),
                    style: PremiumTheme.labelMedium.copyWith(
                      color: Colors.white60,
                      fontSize: 10,
                    ),
                  );
                },
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 36,
                getTitlesWidget: (value, meta) {
                  final i = value.toInt();
                  if (i < 0 || i >= labels.length) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      labels[i],
                      style: PremiumTheme.labelMedium.copyWith(
                        color: Colors.white60,
                        fontSize: 10,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          barGroups: List.generate(labels.length, (i) {
            return BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: ys[i],
                  color: colors[i],
                  width: 18,
                  borderRadius: BorderRadius.circular(6),
                ),
              ],
            );
          }),
        ),
      ),
    );
  }

  Widget _buildRevenueForecastChart() {
    final future =
        _monthlyForecastFuture ?? _fetchMonthlyForecast(year: _selectedYear);

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: future,
      builder: (context, snapshot) {
        final loading = snapshot.connectionState == ConnectionState.waiting;
        final items = snapshot.data ?? [];

        final months = <String>[];
        final projected = <double>[];

        for (final r in items) {
          final month = (r['month'] ?? '').toString();
          if (month.length < 7) continue;
          months.add(month);
          projected.add((r['forecast_revenue'] is num)
              ? (r['forecast_revenue'] as num).toDouble()
              : double.tryParse(r['forecast_revenue']?.toString() ?? '') ??
                  0.0);
        }

        // If no data, create a stable empty chart.
        if (months.isEmpty) {
          for (int m = 1; m <= 12; m++) {
            months.add(
                '${_selectedYear.toString().padLeft(4, '0')}-${m.toString().padLeft(2, '0')}');
            projected.add(0.0);
          }
        }

        final now = DateTime.now();
        int startIndex = 0;
        if (_selectedYear == now.year) {
          // Show from the current month forward when viewing the current year.
          startIndex =
              (now.month - 1).clamp(0, months.isEmpty ? 0 : months.length - 1);
        }
        if (startIndex >= months.length) {
          startIndex = 0;
        }
        final remaining = months.length - startIndex;
        final displayCount = remaining >= 6 ? 6 : remaining;
        final months6 = months.sublist(startIndex, startIndex + displayCount);
        final projected6 =
            projected.sublist(startIndex, startIndex + displayCount);

        double maxY = 0;
        for (final v in projected6) {
          if (v > maxY) maxY = v;
        }

        String fmt(double v) {
          if (v >= 1000000) return 'R${(v / 1000000).toStringAsFixed(1)}M';
          if (v >= 1000) return 'R${(v / 1000).toStringAsFixed(0)}K';
          return 'R${v.toStringAsFixed(0)}';
        }

        final teal = PremiumTheme.teal;

        return Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Year',
                  style:
                      PremiumTheme.labelMedium.copyWith(color: Colors.white60),
                ),
                _buildYearSelector(),
              ],
            ),
            const SizedBox(height: 10),
            if (loading)
              Expanded(
                child: Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(
                        Colors.white.withOpacity(0.7)),
                  ),
                ),
              )
            else
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.03),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: Colors.white.withOpacity(0.06)),
                  ),
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                  child: LineChart(
                    LineChartData(
                      minX: 0,
                      maxX: (displayCount - 1).toDouble(),
                      minY: 0,
                      maxY: (maxY <= 0 ? 1 : maxY) * 1.1,
                      lineTouchData: LineTouchData(
                        enabled: true,
                        handleBuiltInTouches: true,
                        touchTooltipData: LineTouchTooltipData(
                          tooltipMargin: 12,
                          tooltipPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          getTooltipColor: (touchedSpot) =>
                              Colors.white.withOpacity(0.96),
                          getTooltipItems: (touchedSpots) {
                            if (touchedSpots.isEmpty) return [];
                            final idx = touchedSpots.first.x
                                .round()
                                .clamp(0, displayCount - 1);
                            final monthKey = months6[idx];
                            DateTime? parsed;
                            try {
                              final parts = monthKey.split('-');
                              parsed = DateTime(
                                  int.parse(parts[0]), int.parse(parts[1]), 1);
                            } catch (_) {}
                            final monthLabel = parsed != null
                                ? DateFormat('MMM').format(parsed)
                                : monthKey;
                            final proj = projected6[idx];
                            final headerStyle =
                                PremiumTheme.bodyMedium.copyWith(
                              color: Colors.black87,
                              fontWeight: FontWeight.w700,
                            );
                            final bodyStyle = PremiumTheme.bodyMedium.copyWith(
                              color: Colors.black87,
                              fontWeight: FontWeight.w600,
                            );

                            return List.generate(touchedSpots.length, (i) {
                              final spot = touchedSpots[i];
                              if (spot.barIndex != 0) {
                                return const LineTooltipItem('', TextStyle());
                              }
                              return LineTooltipItem(
                                '$monthLabel\n',
                                headerStyle,
                                children: [
                                  TextSpan(
                                    text: 'Forecast : ${_formatCurrency(proj)}',
                                    style: bodyStyle.copyWith(color: teal),
                                  ),
                                ],
                              );
                            });
                          },
                        ),
                      ),
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        getDrawingHorizontalLine: (value) => FlLine(
                          color: Colors.white.withOpacity(0.08),
                          strokeWidth: 1,
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      titlesData: FlTitlesData(
                        topTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false)),
                        rightTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false)),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 42,
                            getTitlesWidget: (value, meta) {
                              if (value == 0) {
                                return Text(
                                  'R0',
                                  style: PremiumTheme.labelMedium.copyWith(
                                    color: Colors.white60,
                                    fontSize: 10,
                                  ),
                                );
                              }
                              if (value == meta.max) {
                                return Text(
                                  fmt(value),
                                  style: PremiumTheme.labelMedium.copyWith(
                                    color: Colors.white60,
                                    fontSize: 10,
                                  ),
                                );
                              }
                              return const SizedBox.shrink();
                            },
                          ),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            interval: 1,
                            getTitlesWidget: (value, meta) {
                              final i = value.toInt();
                              if (i < 0 || i >= months6.length) {
                                return const SizedBox.shrink();
                              }
                              DateTime? parsed;
                              try {
                                final parts = months6[i].split('-');
                                parsed = DateTime(int.parse(parts[0]),
                                    int.parse(parts[1]), 1);
                              } catch (_) {}
                              final label = parsed != null
                                  ? DateFormat('MMM').format(parsed)
                                  : months6[i];
                              return Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text(
                                  label,
                                  style: PremiumTheme.labelMedium.copyWith(
                                    color: Colors.white60,
                                    fontSize: 10,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      lineBarsData: [
                        LineChartBarData(
                          spots: List.generate(
                            displayCount,
                            (i) => FlSpot(i.toDouble(), projected6[i]),
                          ),
                          isCurved: true,
                          color: teal,
                          barWidth: 3,
                          dotData: const FlDotData(show: false),
                          belowBarData: BarAreaData(
                            show: true,
                            color: teal.withOpacity(0.12),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildHeader(AppState app, bool isMobile, ManagerChromeTheme chrome) {
    final userName = app.currentUser?['full_name'] ??
        app.currentUser?['first_name'] ??
        app.currentUser?['email'] ??
        'Finance User';
    final unreadMessages = _unreadNotificationCount(app, messagesOnly: true);
    final unreadNotifications =
        _unreadNotificationCount(app, messagesOnly: false);

    return Container(
      height: 70,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.black.withValues(alpha: 0.3),
            Colors.transparent,
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Row(
                children: [
                  Text(
                    _currentTab == 'proposals'
                        ? 'Finance Proposal Management'
                        : 'Finance Dashboard',
                    style: TextStyle(
                      color: chrome.textPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(width: 14),
                  if (!isMobile)
                    Flexible(
                      child: Text(
                        'Hello, ${userName.toString()}',
                        style: TextStyle(
                          color: chrome.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    SizedBox(
                      width: _adminLikeIconDiameter,
                      height: _adminLikeIconDiameter,
                      child: IconButton(
                        tooltip: 'Messages',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        splashColor: Colors.transparent,
                        highlightColor: Colors.transparent,
                        hoverColor: Colors.transparent,
                        onPressed: () async {
                          await app.fetchNotifications();
                          if (!mounted) return;
                          _showNotificationsSheet(app, messagesOnly: true);
                        },
                        icon: Image.asset(
                          'assets/images/new icons for manager/messages.png',
                          width: 52,
                          height: 52,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                    if (unreadMessages > 0)
                      Positioned(
                        right: -2,
                        top: -2,
                        child: Container(
                          width: 18,
                          height: 18,
                          decoration: const BoxDecoration(
                            color: Color(0xFFC10D00),
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            unreadMessages > 9
                                ? '9+'
                                : unreadMessages.toString(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 0),
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    SizedBox(
                      width: _adminLikeIconDiameter,
                      height: _adminLikeIconDiameter,
                      child: IconButton(
                        tooltip: 'Notifications',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        splashColor: Colors.transparent,
                        highlightColor: Colors.transparent,
                        hoverColor: Colors.transparent,
                        onPressed: () async {
                          await app.fetchNotifications();
                          if (!mounted) return;
                          _showNotificationsSheet(app, messagesOnly: false);
                        },
                        icon: Image.asset(
                          'assets/images/new icons for manager/notifications.png',
                          width: 52,
                          height: 52,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                    if (unreadNotifications > 0)
                      Positioned(
                        right: -2,
                        top: -2,
                        child: Container(
                          width: 18,
                          height: 18,
                          decoration: const BoxDecoration(
                            color: Color(0xFFC10D00),
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            unreadNotifications > 9
                                ? '9+'
                                : unreadNotifications.toString(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow({
    required List<Map<String, dynamic>> proposals,
    required int pendingCount,
    required int approvedCount,
    required int sentToClientCount,
    required double totalAmount,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final isNarrow = width < 900;
        final avgCycle = _computeAvgCycleTimeDays(proposals);
        final proposalsCount = proposals.length;

        final denom = (approvedCount + pendingCount);
        final approvalRate = denom <= 0 ? 0.0 : (approvedCount / denom);

        if (isNarrow) {
          return Column(
            children: [
              _buildSummaryCard(
                label: 'Pipeline Value',
                value: _formatCurrency(totalAmount),
                subtitle: '$proposalsCount proposals',
                icon: Icons.attach_money,
                color: PremiumTheme.info,
              ),
              const SizedBox(height: 12),
              _buildSummaryCard(
                label: 'Pending Reviews',
                value: pendingCount.toString(),
                subtitle: 'Awaiting finance action',
                icon: Icons.hourglass_empty,
                color: Colors.orange,
              ),
              const SizedBox(height: 12),
              _buildSummaryCard(
                label: 'Avg. Cycle Time',
                value: avgCycle <= 0
                    ? '--'
                    : '${avgCycle.toStringAsFixed(1)} days',
                subtitle: 'Created to last update',
                icon: Icons.timelapse,
                color: PremiumTheme.purple,
              ),
              const SizedBox(height: 12),
              _buildSummaryCard(
                label: 'Approval Rate',
                value: _formatPercent(approvalRate),
                subtitle: '$approvedCount of $denom completed',
                icon: Icons.verified,
                color: PremiumTheme.teal,
              ),
            ],
          );
        }

        return Row(
          children: [
            Expanded(
              child: _buildSummaryCard(
                label: 'Pipeline Value',
                value: _formatCurrency(totalAmount),
                subtitle: '$proposalsCount proposals',
                icon: Icons.attach_money,
                color: PremiumTheme.info,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildSummaryCard(
                label: 'Pending Reviews',
                value: pendingCount.toString(),
                subtitle: 'Awaiting finance action',
                icon: Icons.hourglass_empty,
                color: Colors.orange,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildSummaryCard(
                label: 'Avg. Cycle Time',
                value: avgCycle <= 0
                    ? '--'
                    : '${avgCycle.toStringAsFixed(1)} days',
                subtitle: 'Created to last update',
                icon: Icons.timelapse,
                color: PremiumTheme.purple,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildSummaryCard(
                label: 'Approval Rate',
                value: _formatPercent(approvalRate),
                subtitle: '$approvedCount of $denom completed',
                icon: Icons.verified,
                color: PremiumTheme.teal,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildRequiresAttention(List<Map<String, dynamic>> proposals) {
    Widget item(Map<String, dynamic> p) {
      final title = (p['title'] ?? 'Untitled Proposal').toString();
      final client = (p['client_name'] ?? p['client'] ?? '').toString();
      final status = (p['status'] ?? '').toString();
      final proposalId = p['id']?.toString();

      final content = Row(
        children: [
          Icon(
            Icons.check_box,
            color: const Color(0xFFE11D48).withValues(alpha: 0.9),
            size: 14,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$title - ${client.isEmpty ? 'Awaiting review details' : client}',
                  style: PremiumTheme.bodySmall.copyWith(
                    color: Colors.white70,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          _buildStatusChip(status.isEmpty ? 'In Pricing' : status),
          const SizedBox(width: 10),
          TextButton(
            onPressed: () {
              if (proposalId == null || proposalId.isEmpty) return;
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => BlankDocumentEditorPage(
                    proposalId: proposalId,
                    proposalTitle: title,
                    readOnly: false,
                  ),
                ),
              );
            },
            style: TextButton.styleFrom(
              backgroundColor: Colors.white.withValues(alpha: 0.35),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              shape: const StadiumBorder(),
            ),
            child: const Text(
              'VIEW',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      );

      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: content,
      );
    }

    final visible = proposals.take(5).toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _panelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _panelIcon(_requiresAttentionIcon),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Requires Attention', style: PremiumTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text(
                      'Proposals Awaiting Review or Action',
                      style: PremiumTheme.bodyMedium
                          .copyWith(color: Colors.white70),
                    ),
                  ],
                ),
              ),
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.95),
                  shape: BoxShape.circle,
                ),
                padding: const EdgeInsets.all(7),
                child: Image.asset(
                  'assets/images/new icons for manager/notifications.png',
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '${visible.length}',
                  style: PremiumTheme.titleMedium.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: () {
                  setState(() {
                    _currentTab = 'proposals';
                    _statusFilter = 'pending_review';
                  });
                },
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white,
                  backgroundColor: const Color(0xFFC10D00),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  shape: const StadiumBorder(),
                ),
                child: const Text(
                  'VIEW ALL',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Divider(color: Colors.white.withValues(alpha: 0.35), height: 1),
          const SizedBox(height: 10),
          if (proposals.isEmpty)
            Text(
              'No proposals currently in pricing.',
              style: PremiumTheme.bodyMedium.copyWith(color: Colors.white70),
            )
          else
            Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.03),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.white.withOpacity(0.06)),
              ),
              child: Column(
                children: [
                  for (int i = 0; i < visible.length; i++) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 0),
                      child: item(visible[i]),
                    ),
                    if (i != visible.length - 1)
                      Divider(
                        height: 1,
                        color: Colors.white.withOpacity(0.08),
                      ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard({
    required String label,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: PremiumTheme.darkBg2.withValues(alpha: 0.85),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  label,
                  style: PremiumTheme.bodyMedium.copyWith(
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            value,
            style: PremiumTheme.displayMedium.copyWith(
              fontSize: 30,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: PremiumTheme.labelMedium.copyWith(
              color: Colors.white.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _panelDecoration(),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 900;

          final searchField = Expanded(
            flex: 2,
            child: TextField(
              controller: _searchController,
              onChanged: (_) => setState(() {}),
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search proposals or clients…',
                hintStyle:
                    TextStyle(color: Colors.white.withValues(alpha: 0.55)),
                prefixIcon: const Icon(Icons.search, color: Colors.white70),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.04),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      BorderSide(color: Colors.white.withValues(alpha: 0.08)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: PremiumTheme.teal),
                ),
              ),
            ),
          );

          // Ensure value is one of the dropdown items to avoid assertion (e.g. never use 'pending')
          final effectiveStatusFilter =
              _validStatusFilters.contains(_statusFilter)
                  ? _statusFilter
                  : 'all';
          if (_statusFilter != effectiveStatusFilter) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted)
                setState(() => _statusFilter = effectiveStatusFilter);
            });
          }
          final statusDropdown = Expanded(
            child: DropdownButtonFormField<String>(
              initialValue: effectiveStatusFilter,
              dropdownColor: PremiumTheme.darkBg1,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Status',
                labelStyle:
                    TextStyle(color: Colors.white.withValues(alpha: 0.8)),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.04),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      BorderSide(color: Colors.white.withValues(alpha: 0.08)),
                ),
              ),
              items: const [
                DropdownMenuItem(value: 'all', child: Text('All Statuses')),
                DropdownMenuItem(
                    value: 'pending_review', child: Text('Pending Review')),
                DropdownMenuItem(
                    value: 'in_pricing', child: Text('In Pricing')),
                DropdownMenuItem(value: 'released', child: Text('Released')),
                DropdownMenuItem(value: 'signed', child: Text('Signed')),
              ],
              onChanged: (v) => setState(() => _statusFilter = v ?? 'all'),
            ),
          );

          final clearButton = TextButton.icon(
            onPressed: () {
              setState(() {
                _searchController.clear();
                _statusFilter = 'all';
              });
            },
            icon: const Icon(Icons.clear),
            label: const Text('Clear'),
          );

          if (isNarrow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(children: [searchField]),
                const SizedBox(height: 12),
                Row(children: [statusDropdown]),
                const SizedBox(height: 8),
                Align(alignment: Alignment.centerRight, child: clearButton),
              ],
            );
          }

          return Row(
            children: [
              searchField,
              const SizedBox(width: 12),
              statusDropdown,
              const SizedBox(width: 12),
              clearButton,
            ],
          );
        },
      ),
    );
  }

  Widget _buildTable(List<Map<String, dynamic>> proposals) {
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Center(
          child: CircularProgressIndicator(color: PremiumTheme.teal),
        ),
      );
    }

    if (proposals.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Icon(Icons.inbox_outlined, color: Colors.white54, size: 40),
            const SizedBox(height: 8),
            Text(
              'No proposals match your filters.',
              style: PremiumTheme.bodyMedium.copyWith(
                color: Colors.white.withValues(alpha: 0.8),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _panelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Proposals overview',
            style: PremiumTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          _buildTableHeader(),
          const Divider(height: 16, color: Colors.white24),
          ...proposals.map(_buildTableRow),
        ],
      ),
    );
  }

  Widget _buildTableHeader() {
    final headerStyle = PremiumTheme.labelMedium.copyWith(
      color: Colors.white70,
      letterSpacing: 1.0,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          Expanded(flex: 4, child: Text('PROPOSAL', style: headerStyle)),
          Expanded(flex: 3, child: Text('CLIENT', style: headerStyle)),
          Expanded(flex: 2, child: Text('STATUS', style: headerStyle)),
          Expanded(flex: 2, child: Text('AMOUNT', style: headerStyle)),
        ],
      ),
    );
  }

  Widget _buildTableRow(Map<String, dynamic> p) {
    final title = (p['title'] ?? 'Untitled Proposal').toString();
    final client = (p['client_name'] ?? p['client'] ?? 'Unknown').toString();
    final status = (p['status'] ?? 'Draft').toString();
    final amount = _extractAmount(p);

    final proposalId = p['id']?.toString();

    final row = Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Text(
              title,
              style: PremiumTheme.bodyMedium.copyWith(color: Colors.white),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              client,
              style: PremiumTheme.bodyMedium.copyWith(
                color: PremiumTheme.textSecondary,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            flex: 2,
            child: _buildStatusChip(status),
          ),
          Expanded(
            flex: 2,
            child: Align(
              alignment: Alignment.centerRight,
              child: Text(
                _formatCurrency(amount),
                style: PremiumTheme.bodyMedium.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );

    if (proposalId == null || proposalId.isEmpty) return row;

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => BlankDocumentEditorPage(
              proposalId: proposalId,
              proposalTitle: title,
              readOnly: false,
            ),
          ),
        );
      },
      child: row,
    );
  }

  Widget _buildStatusChip(String status) {
    final lower = status.toLowerCase();
    Color bg;
    Color fg;

    if (lower.contains('pending') || lower.contains('review')) {
      bg = Colors.orange.withValues(alpha: 0.15);
      fg = Colors.orange;
    } else if (lower.contains('approved') ||
        lower.contains('signed') ||
        lower.contains('released')) {
      bg = Colors.green.withValues(alpha: 0.15);
      fg = Colors.green;
    } else {
      bg = Colors.white.withValues(alpha: 0.08);
      fg = Colors.white70;
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
}

class _FinanceProposalRow extends StatelessWidget {
  const _FinanceProposalRow({
    required this.proposal,
    required this.chrome,
    required this.extractAmount,
    required this.formatCurrency,
    required this.formatLastModified,
    required this.statusLabel,
    required this.statusColor,
    required this.onView,
  });

  final Map<String, dynamic> proposal;
  final ManagerChromeTheme chrome;
  final double Function(Map<String, dynamic>) extractAmount;
  final String Function(double) formatCurrency;
  final String Function(dynamic) formatLastModified;
  final String Function(String) statusLabel;
  final Color Function(String) statusColor;
  final VoidCallback onView;

  @override
  Widget build(BuildContext context) {
    final title = (proposal['title'] ?? 'Untitled Proposal').toString();
    final client =
        (proposal['client_name'] ?? proposal['client'] ?? 'Unknown Client')
            .toString();
    final statusRaw = (proposal['status'] ?? '').toString();
    final amount = extractAmount(proposal);
    final lastModified =
        formatLastModified(proposal['updated_at'] ?? proposal['updatedAt']);

    final pillLabel = statusLabel(statusRaw);
    final pillColor = statusColor(statusRaw);

    return SizedBox(
      height: 64,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Image.asset(
              _FinanceDashboardPageState._rowDocIcon,
              width: 40,
              height: 40,
              fit: BoxFit.contain,
            ),
            const SizedBox(width: 16),
            Expanded(
              flex: 3,
              child: RichText(
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: title,
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        letterSpacing: 0.13,
                        color: chrome.textPrimary,
                      ),
                    ),
                    TextSpan(
                      text: ' - $client',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        letterSpacing: 0.13,
                        color: chrome.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 16),
            SizedBox(
              width: 190,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Last Modified: $lastModified',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w500,
                    fontSize: 10.5,
                    letterSpacing: 0.105,
                    color: chrome.textSecondary,
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
                  width: 160,
                  height: 23.0,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(15.69, 0, 15.69, 0),
                    decoration: BoxDecoration(
                      color: pillColor,
                      borderRadius: BorderRadius.circular(26.06),
                    ),
                    child: Center(
                      child: Text(
                        pillLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                          height: 1,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              flex: 1,
              child: Align(
                alignment: Alignment.centerRight,
                child: Text(
                  formatCurrency(amount),
                  style: PremiumTheme.bodyMedium.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            const SizedBox(width: 16),
            SizedBox(
              width: 92,
              child: OutlinedButton(
                onPressed: onView,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  backgroundColor: const Color(0xFF4B5563),
                  side: BorderSide.none,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
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
          ],
        ),
      ),
    );
  }
}
