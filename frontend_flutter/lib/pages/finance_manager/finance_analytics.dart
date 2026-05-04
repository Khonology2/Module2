import 'dart:async';
import 'dart:math' as math;

import 'dart:convert';
import 'dart:html' as html;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;

import '../../api.dart';
import '../../services/auth_service.dart';
import '../../theme/manager_theme_controller.dart';
import '../../theme/premium_theme.dart';
import '../../widgets/custom_scrollbar.dart';
import '../../widgets/finance/finance_sidebar.dart';
import '../../widgets/footer.dart';
import '../../widgets/manager_page_background.dart';

class FinanceAnalyticsPage extends StatefulWidget {
  const FinanceAnalyticsPage({super.key});

  @override
  State<FinanceAnalyticsPage> createState() => _FinanceAnalyticsPageState();
}

class _FinanceAnalyticsPageState extends State<FinanceAnalyticsPage> {
  final ScrollController _scrollController = ScrollController();
  final NumberFormat _currencyFormatter =
      NumberFormat.currency(symbol: 'R', decimalDigits: 0);
  Timer? _aiUsageRefreshTimer;
  Timer? _notificationRefreshTimer;
  int _aiUsageRefreshTick = 0;

  static const String _financeIconDir =
      'assets/images/finance_manager_new_icons';
  static const String _kpiPipelineIcon =
      '$_financeIconDir/Total_Pipeline_Value.png';
  static const String _kpiExpectedIcon =
      '$_financeIconDir/conversion_rate_finace analytics.png';
  static const String _kpiAvgDealIcon =
      '$_financeIconDir/Revenue_forecast_chart.png';
  static const String _topClientsIcon =
      '$_financeIconDir/Top_client_finance_analytics (1).png';
  static const String _forecastChartIcon =
      '$_financeIconDir/Revenue_forecast_chart.png';
  static const String _pipelineChartIcon =
      '$_financeIconDir/Proposal_Pipeline.png';
  static const String _revenuePanelIcon = '$_financeIconDir/Top_clients.png';
  static const String _approvalFunnelIcon = '$_financeIconDir/Win_Rate.png';
  static const String _aiUsageIcon = '$_financeIconDir/AI_Usage.png';
  static const String _financialAlertsIcon =
      '$_financeIconDir/Financial_Alerts.png';
  static const String _byEndpointIcon = '$_financeIconDir/By_Endpoint.png';
  static const String _includeDataIcon = '$_financeIconDir/include_data.png';
  static const double _topPanelIconSize = 102.0;
  static const double _bottomPanelIconSize = 102.0;
  static const double _kpiIconSize = 102.0;
  static const double _mainPanelIconSize = _kpiIconSize;
  static const double _financialAlertsBellIconSize = 51.0;
  static const double _headerActionIconDiameter = 80.0;
  static const double _headerActionIconAssetSize = 52.0;

  Future<List<Map<String, dynamic>>>? _pipelineFunnelFuture;
  Future<List<Map<String, dynamic>>>? _alertsFuture;

  BoxDecoration _panelDecoration() {
    final isDark = context.watch<ManagerThemeController>().chrome.isDark;
    return BoxDecoration(
      borderRadius: BorderRadius.circular(6),
      color: isDark ? const Color(0x24FFFFFF) : const Color(0x66838383),
      border: Border.all(
        color: isDark
            ? Colors.white.withValues(alpha: 0.10)
            : const Color(0x66838383),
      ),
      boxShadow: [
        BoxShadow(
          color: isDark ? const Color(0x40000000) : const Color(0x24000000),
          blurRadius: 3.55,
          offset: const Offset(0, 3.55),
        ),
      ],
    );
  }

  Widget _panelIcon(String path, {double size = _topPanelIconSize}) {
    return SizedBox(
      width: size,
      height: size,
      child: Image.asset(
        path,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
        cacheWidth: (size * 4).round(),
        cacheHeight: (size * 4).round(),
        errorBuilder: (_, __, ___) =>
            const Icon(Icons.broken_image, color: Colors.red, size: 18),
      ),
    );
  }

  Widget _buildDashboardStylePanel({
    required String title,
    required String subtitle,
    required String iconPath,
    required Widget child,
    double iconSize = _mainPanelIconSize,
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
              _panelIcon(iconPath, size: iconSize),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: PremiumTheme.titleMedium),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      style: PremiumTheme.bodyMedium.copyWith(color: Colors.white70),
                    ),
                  ],
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

  Future<List<Map<String, dynamic>>> _fetchPipelineFunnel() async {
    final app = context.read<AppState>();
    final token = app.authToken ?? AuthService.token;

    if (token == null) return [];

    try {
      final uri = Uri.parse('$baseUrl/api/finance/funnel');
      final r = await http.get(uri, headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      });
      if (r.statusCode != 200) return [];
      final decoded = jsonDecode(r.body);
      if (decoded is List) {
        return decoded
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
    } catch (_) {}
    return [];
  }

  String _formatCurrency(double value) {
    return _currencyFormatter.format(value);
  }

  Widget _buildPipelineFunnelChart() {
    final future = _pipelineFunnelFuture ?? _fetchPipelineFunnel();
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
        final stages = <String>[];
        final values = <double>[];
        for (final r in items) {
          final s = (r['stage'] ?? '').toString();
          if (s.isEmpty) continue;
          stages.add(s);
          values.add((r['value'] is num)
              ? (r['value'] as num).toDouble()
              : double.tryParse(r['value']?.toString() ?? '') ?? 0.0);
        }

        if (stages.isEmpty) {
          return Center(
            child: Text(
              'No data',
              style: PremiumTheme.bodyMedium.copyWith(color: Colors.white60),
            ),
          );
        }

        final maxY = (values.fold<double>(0, (a, b) => a > b ? a : b))
            .clamp(1, double.infinity);

        return Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.03),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withOpacity(0.06)),
          ),
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
          child: BarChart(
            BarChartData(
              maxY: maxY * 1.1,
              minY: 0,
              alignment: BarChartAlignment.spaceAround,
              groupsSpace: 18,
              barTouchData: BarTouchData(
                enabled: true,
                touchTooltipData: BarTouchTooltipData(
                  tooltipPadding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  tooltipMargin: 12,
                  getTooltipColor: (group) => Colors.white.withOpacity(0.92),
                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                    final label = groupIndex >= 0 && groupIndex < stages.length
                        ? stages[groupIndex]
                        : '';
                    return BarTooltipItem(
                      '$label\nvalue : ${_formatCurrency(rod.toY)}',
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
                    reservedSize: 34,
                    getTitlesWidget: (value, meta) {
                      final i = value.toInt();
                      if (i < 0 || i >= stages.length) {
                        return const SizedBox.shrink();
                      }
                      return Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          stages[i],
                          style: PremiumTheme.labelMedium
                              .copyWith(color: Colors.white60, fontSize: 10),
                        ),
                      );
                    },
                  ),
                ),
              ),
              barGroups: List.generate(stages.length, (i) {
                return BarChartGroupData(
                  x: i,
                  barRods: [
                    BarChartRodData(
                      toY: values[i],
                      color: PremiumTheme.teal,
                      width: 18,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ],
                );
              }),
            ),
          ),
        );
      },
    );
  }

  bool _canAccessAudit(AppState app) {
    final role = (app.currentUser?['role'] ?? '').toString().toLowerCase();
    return role == 'finance_manager' || role == 'admin' || role == 'ceo';
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final app = context.read<AppState>();
      app.fetchProposals();
      app.fetchNotifications();
    });
    _aiUsageRefreshTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      if (!mounted) return;
      setState(() => _aiUsageRefreshTick++);
    });
    _notificationRefreshTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      if (!mounted) return;
      context.read<AppState>().fetchNotifications();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _pipelineFunnelFuture ??= _fetchPipelineFunnel();
    _alertsFuture ??= _fetchAlerts(year: DateTime.now().year);
  }

  Future<List<Map<String, dynamic>>> _fetchAlerts({required int year}) async {
    final app = context.read<AppState>();
    final token = app.authToken ?? AuthService.token;
    if (token == null) return [];

    try {
      final uri = Uri.parse('$baseUrl/api/finance/alerts')
          .replace(queryParameters: {'year': year.toString()});
      final r = await http.get(uri, headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      });
      if (r.statusCode != 200) return [];
      final decoded = jsonDecode(r.body);
      if (decoded is List) {
        return decoded
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
    } catch (_) {}
    return [];
  }

  Widget _buildFinancialAlertsPanel() {
    final year = DateTime.now().year;
    final future = _alertsFuture ?? _fetchAlerts(year: year);
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: future,
      builder: (context, snapshot) {
        final items = snapshot.data ?? [];
        final shown = items.take(4).toList();

        Widget alertRow(Map<String, dynamic> item, {required bool checked}) {
          final type =
              (item['type'] ?? 'Alert Title').toString().replaceAll('_', ' ');
          final details = (item['client'] ?? item['message'] ?? item['detail'] ?? '')
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
                onPressed: () {},
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
                  _panelIcon(_financialAlertsIcon, size: _mainPanelIconSize),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Financial Alerts', style: PremiumTheme.titleMedium),
                        const SizedBox(height: 4),
                        Text(
                          'Items requiring financial attention.',
                          style: PremiumTheme.bodyMedium.copyWith(color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: _financialAlertsBellIconSize,
                    height: _financialAlertsBellIconSize,
                    child: Image.asset(
                      'assets/images/new icons for manager/notifications.png',
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.high,
                      cacheWidth: (_financialAlertsBellIconSize * 4).round(),
                      cacheHeight: (_financialAlertsBellIconSize * 4).round(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      '$count',
                      style: PremiumTheme.titleMedium.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () {},
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: const Color(0xFFC10D00),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
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
                      style: PremiumTheme.bodyMedium.copyWith(color: Colors.white60),
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

  @override
  void dispose() {
    _aiUsageRefreshTimer?.cancel();
    _notificationRefreshTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
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

  Widget _buildAiUsagePanel() {
    return FutureBuilder<Map<String, dynamic>?>(
      key: ValueKey('finance_analytics_ai_usage_$_aiUsageRefreshTick'),
      future: _fetchAiUsageAnalytics(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return SizedBox(
            height: 200,
            child: Center(
              child: CircularProgressIndicator(
                valueColor:
                    AlwaysStoppedAnimation<Color>(Colors.white.withOpacity(0.7)),
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
                    style:
                        PremiumTheme.labelMedium.copyWith(color: Colors.white70),
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
                  width: _bottomPanelIconSize,
                  height: _bottomPanelIconSize,
                  child: Image.asset(
                    actionIconPath,
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.high,
                    cacheWidth: (_bottomPanelIconSize * 4).round(),
                    cacheHeight: (_bottomPanelIconSize * 4).round(),
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
                  statTile('Acceptance', '${acceptanceRate.toStringAsFixed(1)}%'),
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
                      style: PremiumTheme.bodySmall.copyWith(color: Colors.white54),
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

  Widget _statPill(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
      ),
      child: Text('$label: $value', style: PremiumTheme.bodySmall),
    );
  }

  void _showExportDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        String selectedReport = 'proposal_summary';
        String selectedFormat = 'csv';
        bool isExporting = false;

        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text(
                'Export Financial Data',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Select report type and format:',
                    style: TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 16),

                  // Report Type Selection
                  const Text(
                    'Report Type:',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  RadioListTile<String>(
                    title: const Text('Proposal Financial Summary'),
                    subtitle:
                        const Text('Individual proposal details with amounts'),
                    value: 'proposal_summary',
                    groupValue: selectedReport,
                    onChanged: (value) {
                      setState(() {
                        selectedReport = value!;
                      });
                    },
                    contentPadding: EdgeInsets.zero,
                  ),
                  RadioListTile<String>(
                    title: const Text('Client Financial Report'),
                    subtitle: const Text('Aggregated data by client'),
                    value: 'client_report',
                    groupValue: selectedReport,
                    onChanged: (value) {
                      setState(() {
                        selectedReport = value!;
                      });
                    },
                    contentPadding: EdgeInsets.zero,
                  ),
                  const SizedBox(height: 16),

                  // Format Selection
                  const Text(
                    'Export Format:',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  RadioListTile<String>(
                    title: const Text('Excel (.xlsx)'),
                    subtitle: const Text(
                        'Native Excel format, structured columns and sheets'),
                    value: 'xlsx',
                    groupValue: selectedFormat,
                    onChanged: (value) {
                      setState(() {
                        selectedFormat = value!;
                      });
                    },
                    contentPadding: EdgeInsets.zero,
                  ),
                  RadioListTile<String>(
                    title: const Text('CSV'),
                    subtitle: const Text(
                        'Comma-separated values, opens in Excel with columns'),
                    value: 'csv',
                    groupValue: selectedFormat,
                    onChanged: (value) {
                      setState(() {
                        selectedFormat = value!;
                      });
                    },
                    contentPadding: EdgeInsets.zero,
                  ),
                  RadioListTile<String>(
                    title: const Text('PDF'),
                    subtitle: const Text('Printable report'),
                    value: 'pdf',
                    groupValue: selectedFormat,
                    onChanged: (value) {
                      setState(() {
                        selectedFormat = value!;
                      });
                    },
                    contentPadding: EdgeInsets.zero,
                  ),
                  RadioListTile<String>(
                    title: const Text('PDF'),
                    subtitle: const Text('Printable report'),
                    value: 'pdf',
                    groupValue: selectedFormat,
                    onChanged: (value) {
                      setState(() {
                        selectedFormat = value!;
                      });
                    },
                    contentPadding: EdgeInsets.zero,
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isExporting
                      ? null
                      : () {
                          Navigator.of(context).pop();
                        },
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: isExporting
                      ? null
                      : () async {
                          setState(() {
                            isExporting = true;
                          });

                          try {
                            await _performExport(
                                selectedReport, selectedFormat);
                            if (mounted) {
                              Navigator.of(context).pop();
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content:
                                      Text('Export completed successfully!'),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            }
                          } catch (e) {
                            if (mounted) {
                              Navigator.of(context).pop();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Export failed: $e'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          } finally {
                            setState(() {
                              isExporting = false;
                            });
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: PremiumTheme.teal,
                    foregroundColor: Colors.white,
                  ),
                  child: isExporting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text('Export'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _performExport(String reportType, String format) async {
    final app = context.read<AppState>();
    final token = app.authToken ?? AuthService.token;

    if (token == null) {
      throw Exception('Authentication required');
    }

    String endpoint;
    if (reportType == 'proposal_summary') {
      endpoint = '/api/finance/export/proposal-summary';
    } else if (reportType == 'client_report') {
      endpoint = '/api/finance/export/client-report';
    } else {
      throw Exception('Invalid report type');
    }

    final uri = Uri.parse('${baseUrl}$endpoint').replace(queryParameters: {
      'format': format,
    });

    final response = await http.get(
      uri,
      headers: {
        'Authorization': 'Bearer $token',
        'Accept': format == 'pdf' ? 'application/pdf' : 'text/csv',
      },
    ).timeout(
      const Duration(seconds: 60),
      onTimeout: () => throw Exception('Export request timed out'),
    );

    if (response.statusCode == 200) {
      // Create download link
      final bytes = response.bodyBytes;
      if (bytes.isEmpty) {
        throw Exception('Export returned empty data');
      }
      final ext = format == 'pdf' ? 'pdf' : 'csv';
      final fileName =
          '${reportType}_${DateTime.now().millisecondsSinceEpoch}.$ext';

      // For web, create download link
      if (kIsWeb) {
        final contentType =
            response.headers['content-type'] ?? 'application/octet-stream';
        final blob = html.Blob([bytes], contentType);
        final url = html.Url.createObjectUrlFromBlob(blob);
        final anchor = html.AnchorElement(href: url)
          ..download = fileName
          ..style.display = 'none';
        html.document.body?.children.add(anchor);
        anchor.click();
        html.document.body?.children.remove(anchor);
        // Delay revoke so the browser has time to start the download
        Future.delayed(const Duration(milliseconds: 1200), () {
          html.Url.revokeObjectUrl(url);
        });
      } else {
        // For mobile/desktop, save to file
        // You might want to use path_provider package here
        print('Export saved: $fileName (${bytes.length} bytes)');
      }
    } else {
      final body = response.body;
      throw Exception(
          'Export failed: ${response.statusCode}${body.isNotEmpty ? ' - $body' : ''}');
    }
  }

  bool _isDraft(String status) => status.trim().toLowerCase() == 'draft';

  DateTime? _parseDate(dynamic value) {
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

  double _extractAmount(Map<String, dynamic> p) {
    final keys = ['budget', 'amount', 'value', 'total', 'total_amount'];
    for (final k in keys) {
      final v = p[k];
      if (v is num) return v.toDouble();
      if (v is String) {
        final cleaned = v.replaceAll(RegExp(r'[^0-9.\-]'), '');
        final d = double.tryParse(cleaned);
        if (d != null) return d;
      }
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
        try {
          final decoded = jsonDecode(contentAny);
          if (decoded is Map || decoded is List) {
            sectionsAny = decoded;
          }
        } catch (_) {}
      }
    }

    return _sumPriceTablesFromSections(sectionsAny);
  }

  List<Map<String, dynamic>> _financeProposals(AppState app) {
    final List<Map<String, dynamic>> normalized = [];
    for (final raw in app.proposals) {
      if (raw is! Map) continue;
      final p = raw is Map<String, dynamic>
          ? raw
          : raw.map((k, v) => MapEntry(k.toString(), v));
      final status = (p['status'] ?? '').toString();
      if (_isDraft(status)) continue;
      normalized.add(p);
    }

    normalized.sort((a, b) {
      final ad = _parseDate(a['created_at'] ?? a['createdAt']);
      final bd = _parseDate(b['created_at'] ?? b['createdAt']);
      if (ad == null && bd == null) return 0;
      if (ad == null) return 1;
      if (bd == null) return -1;
      return bd.compareTo(ad);
    });

    return normalized;
  }

  DateTime _quarterStart(DateTime now) {
    final quarter = ((now.month - 1) ~/ 3) + 1;
    final startMonth = (quarter - 1) * 3 + 1;
    return DateTime(now.year, startMonth, 1);
  }

  Widget _kpiCard({
    required String label,
    required String value,
    required String iconPath,
    String? subtitle,
  }) {
    return Container(
      height: 154,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: _panelDecoration(),
      child: Stack(
        children: [
          Positioned(
            right: 0,
            top: 0,
            child: _panelIcon(iconPath, size: _kpiIconSize),
          ),
          Padding(
            padding: EdgeInsets.only(right: _kpiIconSize + 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: PremiumTheme.bodySmall.copyWith(color: Colors.white70),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: PremiumTheme.labelMedium
                        .copyWith(color: Colors.white54, fontSize: 9),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const Spacer(),
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
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

  Widget _buildRevenueProjectionsChart() {
    final months = ["Oct '25", "Nov '25", "Dec '25", "Jan '26", "Feb '26", "Mar '26"];
    final projected = [2.20, 2.35, 2.55, 2.85, 2.45, 3.05];
    final actual = [2.05, 2.30, 2.50, 2.80, 3.00, 3.20];
    const yTick = 0.6;
    final gridColor = Colors.white.withValues(alpha: 0.10);

    return SizedBox(
      height: 220,
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Container(
                height: 24,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.20),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.24),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Text(
                      '2026',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(width: 6),
                    Icon(Icons.keyboard_arrow_down_rounded,
                        color: Colors.white, size: 14),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: LineChart(
              LineChartData(
                minX: 0,
                maxX: (months.length - 1).toDouble(),
                minY: 0,
                maxY: 4.2,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: yTick,
                  getDrawingHorizontalLine: (_) =>
                      FlLine(color: gridColor, strokeWidth: 1),
                ),
                borderData: FlBorderData(
                  show: true,
                  border: Border(
                    left: BorderSide(
                      color: Colors.white.withValues(alpha: 0.18),
                      width: 1,
                    ),
                    bottom: BorderSide(
                      color: Colors.white.withValues(alpha: 0.18),
                      width: 1,
                    ),
                  ),
                ),
                titlesData: FlTitlesData(
                  topTitles:
                      const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles:
                      const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      interval: yTick,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          'R ${value.toStringAsFixed(1)}M',
                          style: PremiumTheme.labelMedium.copyWith(
                            color: Colors.white70,
                            fontSize: 9,
                          ),
                        );
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 1,
                      getTitlesWidget: (value, meta) {
                        final i = value.toInt();
                        if (i < 0 || i >= months.length) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            months[i],
                            style: PremiumTheme.labelMedium.copyWith(
                              color: Colors.white70,
                              fontSize: 9,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                lineTouchData: LineTouchData(
                  enabled: true,
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (touchedSpot) =>
                        Colors.black.withValues(alpha: 0.90),
                    getTooltipItems: (touchedSpots) {
                      if (touchedSpots.isEmpty) return [];
                      final x = touchedSpots.first.x.round();
                      final month = (x >= 0 && x < months.length) ? months[x] : '';
                      final proj = projected[x];
                      final act = actual[x];
                      return [
                        LineTooltipItem(
                          '$month\n',
                          PremiumTheme.bodyMedium.copyWith(color: Colors.white),
                        ),
                        LineTooltipItem(
                          'Projected: R ${proj.toStringAsFixed(2)}M\n',
                          PremiumTheme.bodyMedium
                              .copyWith(color: const Color(0xFFE9A100)),
                        ),
                        LineTooltipItem(
                          'Actual: R ${act.toStringAsFixed(2)}M',
                          PremiumTheme.bodyMedium
                              .copyWith(color: const Color(0xFF8FBF26)),
                        ),
                      ];
                    },
                  ),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: List.generate(
                      months.length,
                      (i) => FlSpot(i.toDouble(), projected[i]),
                    ),
                    isCurved: false,
                    barWidth: 2.2,
                    color: const Color(0xFFE9A100),
                    dotData: const FlDotData(show: false),
                  ),
                  LineChartBarData(
                    spots: List.generate(
                      months.length,
                      (i) => FlSpot(i.toDouble(), actual[i]),
                    ),
                    isCurved: false,
                    barWidth: 2.2,
                    color: const Color(0xFF8FBF26),
                    dotData: const FlDotData(show: false),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCycleTimeByStageChart(Map<String, double> stageDays) {
    final entries = stageDays.entries.toList();
    final maxY =
        entries.isEmpty ? 1.0 : entries.map((e) => e.value).reduce(math.max);
    final barColor = PremiumTheme.teal;

    return SizedBox(
      height: 220,
      child: BarChart(
        BarChartData(
          maxY: maxY + 0.6,
          alignment: BarChartAlignment.spaceBetween,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: true,
            horizontalInterval: 0.75,
            verticalInterval: 1,
            getDrawingHorizontalLine: (_) =>
                FlLine(color: Colors.white.withOpacity(0.08), strokeWidth: 1),
            getDrawingVerticalLine: (_) =>
                FlLine(color: Colors.white.withOpacity(0.08), strokeWidth: 1),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 44,
                interval: 0.75,
                getTitlesWidget: (value, meta) {
                  return Text(
                    '${value.toStringAsFixed(2)} days',
                    style: PremiumTheme.labelMedium
                        .copyWith(color: Colors.white54),
                  );
                },
              ),
            ),
          ),
          barGroups: List.generate(entries.length, (i) {
            return BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: entries[i].value,
                  color: barColor,
                  width: 14,
                  borderRadius: BorderRadius.circular(6),
                ),
              ],
            );
          }),
          barTouchData: BarTouchData(
            enabled: true,
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (group) => Colors.black.withOpacity(0.86),
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                final label = entries[group.x.toInt()].key;
                return BarTooltipItem(
                  '$label\n${rod.toY.toStringAsFixed(2)} days',
                  PremiumTheme.bodyMedium.copyWith(color: Colors.white),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildApprovalFunnel({
    required int submitted,
    required int inReview,
    required int approved,
    required int released,
  }) {
    final maxVal = [submitted, inReview, approved, released]
        .fold<int>(0, math.max)
        .clamp(1, 1 << 30);
    final items = [
      ('Submitted', submitted, const Color(0xFFF2C230)),
      ('In Review', inReview, const Color(0xFFF4A022)),
      ('Approved', approved, const Color(0xFF6CA510)),
      ('Released', released, const Color(0xFF6F42C1)),
    ];

    Widget row(String label, int value, Color color) {
      final pct = maxVal <= 0 ? 0.0 : (value / maxVal);
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(
          children: [
            Container(
              width: 96,
              height: 24,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(18),
              ),
              alignment: Alignment.center,
              child: Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Added detail is useful or required.',
                style:
                    PremiumTheme.bodySmall.copyWith(color: Colors.white54),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: Container(
                  height: 14,
                  color: const Color(0xFF4A4A54),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: FractionallySizedBox(
                      widthFactor: pct.clamp(0.0, 1.0),
                      child: Container(color: const Color(0xFF5B9BD5)),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(
                '$value',
                style: const TextStyle(
                  color: Colors.black87,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 44,
              child: Text(
                '${(pct * 100).round()}%',
                textAlign: TextAlign.right,
                style: PremiumTheme.labelMedium.copyWith(color: Colors.white70),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        for (final it in items) row(it.$1, it.$2, it.$3),
      ],
    );
  }

  Widget _buildHeader(AppState app, bool isMobile) {
    final userName = app.currentUser?['full_name'] ??
        app.currentUser?['first_name'] ??
        app.currentUser?['email'] ??
        'Finance User';

    return Container(
      height: 66,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.25),
        border: Border(
          bottom: BorderSide(
            color: Colors.white.withOpacity(0.06),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                Text(
                  'Finance Analytics',
                  style: PremiumTheme.titleMedium.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (!isMobile) ...[
                  const SizedBox(width: 8),
                  Text(
                    'Hello, ${userName.toString()}',
                    style: PremiumTheme.bodySmall.copyWith(color: Colors.white70),
                  ),
                ],
              ],
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHeaderIconButton(
                assetPath: 'assets/images/new icons for manager/messages.png',
                tooltip: 'Messages',
                badge: _unreadNotificationCount(app, messagesOnly: true),
                onTap: () async {
                  await app.fetchNotifications();
                  if (!mounted) return;
                  _showNotificationsSheet(app, messagesOnly: true);
                },
              ),
              const SizedBox(width: 8),
              _buildHeaderIconButton(
                assetPath:
                    'assets/images/new icons for manager/notifications.png',
                tooltip: 'Notifications',
                badge: _unreadNotificationCount(app, messagesOnly: false),
                onTap: () async {
                  await app.fetchNotifications();
                  if (!mounted) return;
                  _showNotificationsSheet(app, messagesOnly: false);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderIconButton({
    required String assetPath,
    required String tooltip,
    required VoidCallback onTap,
    int? badge,
  }) {
    final showBadge = (badge ?? 0) > 0;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        SizedBox(
          width: _headerActionIconDiameter,
          height: _headerActionIconDiameter,
          child: IconButton(
            tooltip: tooltip,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            splashColor: Colors.transparent,
            highlightColor: Colors.transparent,
            hoverColor: Colors.transparent,
            onPressed: onTap,
            icon: Image.asset(
              assetPath,
              width: _headerActionIconAssetSize,
              height: _headerActionIconAssetSize,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.high,
              cacheWidth: (_headerActionIconAssetSize * 4).round(),
              cacheHeight: (_headerActionIconAssetSize * 4).round(),
            ),
          ),
        ),
        if (showBadge)
          Positioned(
            right: -2,
            top: -2,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: const BoxDecoration(
                color: Color(0xFFC10D00),
                borderRadius: BorderRadius.all(Radius.circular(10)),
              ),
              child: Text(
                (badge ?? 0) > 99 ? '99+' : '${badge ?? 0}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
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
                  maxHeight: MediaQuery.of(bottomSheetContext).size.height * 0.8,
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
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            messagesOnly ? 'Messages' : 'Notifications',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                          Row(
                            children: [
                              if (unreadCount > 0)
                                TextButton(
                                  onPressed: () async {
                                    for (final item in notifications) {
                                      if (item['is_read'] == true) continue;
                                      final dynamic idRaw = item['id'];
                                      final int? id = idRaw is int
                                          ? idRaw
                                          : int.tryParse(
                                              idRaw?.toString() ?? '',
                                            );
                                      if (id != null) {
                                        await app.markNotificationRead(id);
                                      }
                                    }
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
                              IconButton(
                                onPressed: () => Navigator.of(context).pop(),
                                icon: const Icon(Icons.close, color: Colors.white),
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
                                  final isRead = notification['is_read'] == true;
                                  final timeLabel = _formatNotificationTimestamp(
                                      notification['created_at']);

                                  final dynamic notificationIdRaw =
                                      notification['id'];
                                  final int? notificationId =
                                      notificationIdRaw is int
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
                                        color: Colors.white,
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
                                                color: Color(0xFFCBD5E1),
                                                fontSize: 12,
                                              ),
                                            ),
                                          ),
                                        if (timeLabel.isNotEmpty)
                                          Padding(
                                            padding: const EdgeInsets.only(top: 4),
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
                                    trailing: notificationId != null && !isRead
                                        ? TextButton(
                                            onPressed: () async {
                                              await app.markNotificationRead(
                                                  notificationId);
                                              setModalState(() {});
                                            },
                                            child: const Text('Mark read'),
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

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final chrome = context.watch<ManagerThemeController>().chrome;
    final isSidebarCollapsed = app.isFinanceSidebarCollapsed;
    final proposals = _financeProposals(app);
    final showAudit = _canAccessAudit(app);
    final pendingBadge = proposals
        .where((p) =>
            (p['status'] ?? '').toString().toLowerCase().contains('pricing'))
        .length;

    final now = DateTime.now();
    final quarterStart = _quarterStart(now);
    final proposalsThisQuarter = proposals.where((p) {
      final created = _parseDate(p['created_at'] ?? p['createdAt']);
      if (created == null) return false;
      return !created.isBefore(quarterStart);
    }).toList();

    final approvedOrReleased = proposals.where((p) {
      final s = (p['status'] ?? '').toString().toLowerCase();
      return s.contains('approved') ||
          s.contains('signed') ||
          s.contains('released') ||
          s.contains('sent to client');
    }).length;

    final conversionRate =
        proposals.isEmpty ? 0.0 : approvedOrReleased / proposals.length;

    double totalValue = 0;
    int valueCount = 0;
    final Map<String, double> clientTotals = {};
    for (final p in proposals) {
      final amt = _extractAmount(p);
      if (amt > 0) {
        totalValue += amt;
        valueCount += 1;
      }
      final client = (p['client'] ?? p['client_name'] ?? '').toString().trim();
      if (client.isNotEmpty && amt > 0) {
        clientTotals[client] = (clientTotals[client] ?? 0) + amt;
      }
    }
    final avgDeal = valueCount == 0 ? 0.0 : (totalValue / valueCount);

    String topClient = '--';
    double topClientValue = 0;
    for (final e in clientTotals.entries) {
      if (e.value > topClientValue) {
        topClientValue = e.value;
        topClient = e.key;
      }
    }

    final stageDays = <String, List<double>>{};
    for (final p in proposals) {
      final created = _parseDate(p['created_at'] ?? p['createdAt']);
      final updated = _parseDate(p['updated_at'] ?? p['updatedAt']);
      if (created == null || updated == null) continue;
      final days = updated.difference(created).inMinutes / (60 * 24);
      if (days < 0) continue;
      final s = (p['status'] ?? '').toString().toLowerCase();
      final stage = s.contains('pricing')
          ? 'Pricing'
          : (s.contains('pending review') || s.contains('pending approval'))
              ? 'Finance Review'
              : s.contains('changes requested')
                  ? 'Pricing Adjustment'
                  : (s.contains('released') || s.contains('sent to client'))
                      ? 'Client Release'
                      : (s.contains('approved') || s.contains('signed'))
                          ? 'Final Approval'
                          : 'Submission';
      stageDays.putIfAbsent(stage, () => []).add(days);
    }
    final stageAvg = <String, double>{};
    for (final e in stageDays.entries) {
      final v = e.value;
      if (v.isEmpty) continue;
      stageAvg[e.key] = v.reduce((a, b) => a + b) / v.length;
    }
    if (stageAvg.isEmpty) {
      stageAvg.addAll({
        'Submission': 0.9,
        'Finance Review': 3.0,
        'Pricing Adjustment': 1.9,
        'Final Approval': 1.5,
        'Client Release': 0.6,
      });
    }

    final submitted = proposals.length;
    final inReview = proposals.where((p) {
      final s = (p['status'] ?? '').toString().toLowerCase();
      return s.contains('pending') ||
          s.contains('review') ||
          s.contains('pricing');
    }).length;
    final approved = proposals.where((p) {
      final s = (p['status'] ?? '').toString().toLowerCase();
      return s.contains('approved') || s.contains('signed');
    }).length;
    final released = proposals.where((p) {
      final s = (p['status'] ?? '').toString().toLowerCase();
      return s.contains('released') || s.contains('sent to client');
    }).length;

    final size = MediaQuery.of(context).size;
    final isMobile = size.width < 900;

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton(
        heroTag: 'finance_analytics_theme_toggle',
        backgroundColor: ManagerChromeTheme.accentRed,
        onPressed: () => context.read<ManagerThemeController>().toggle(),
        child: Icon(
          chrome.isDark ? Icons.wb_sunny_rounded : Icons.dark_mode_rounded,
          color: Colors.white,
        ),
      ),
      body: ManagerPageBackground(
        child: Column(
          children: [
            _buildHeader(app, isMobile),
            Expanded(
              child: Row(
                children: [
                  FinanceSidebar(
                    isCollapsed: isSidebarCollapsed,
                    currentPage: 'Analytics',
                    showAudit: showAudit,
                    pendingBadge: pendingBadge > 0 ? pendingBadge : null,
                    managerChrome: chrome,
                    onToggle: app.toggleFinanceSidebar,
                    onSelect: (label) {
                      if (label == 'Dashboard' || label == 'Proposals') {
                        Navigator.pushNamed(context, '/finance_dashboard');
                        return;
                      }
                      if (label == 'Client Management') {
                        Navigator.pushNamed(
                          context,
                          '/finance_dashboard',
                          arguments: const {'initialTab': 'clients'},
                        );
                        return;
                      }
                      if (label == 'Audit') {
                        Navigator.pushNamed(
                          context,
                          '/finance_dashboard',
                          arguments: const {'initialTab': 'audit'},
                        );
                        return;
                      }
                      if (label == 'Analytics') {
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
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: CustomScrollbar(
                        controller: _scrollController,
                        child: SingleChildScrollView(
                          controller: _scrollController,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              LayoutBuilder(
                                builder: (context, c) {
                                  final narrow = c.maxWidth < 980;
                                  final cards = [
                                    _kpiCard(
                                      label: 'Proposals This Quarter',
                                      value: proposalsThisQuarter.length
                                          .toString(),
                                      subtitle:
                                          'Q${((now.month - 1) ~/ 3) + 1} ${now.year}',
                                      iconPath: _kpiPipelineIcon,
                                    ),
                                    _kpiCard(
                                      label: 'Conversion Rate',
                                      value:
                                          '${(conversionRate * 100).round()}%',
                                      subtitle: 'Approved or released',
                                      iconPath: _kpiExpectedIcon,
                                    ),
                                    _kpiCard(
                                      label: 'Avg. Deal Size',
                                      value: avgDeal <= 0
                                          ? '--'
                                          : _currencyFormatter.format(avgDeal),
                                      subtitle: 'Across all proposals',
                                      iconPath: _kpiAvgDealIcon,
                                    ),
                                    _kpiCard(
                                      label: 'Top Client by Value',
                                      value: topClient,
                                      subtitle: topClientValue <= 0
                                          ? null
                                          : _currencyFormatter
                                              .format(topClientValue),
                                      iconPath: _topClientsIcon,
                                    ),
                                  ];

                                  if (narrow) {
                                    return Column(
                                      children: [
                                        for (int i = 0;
                                            i < cards.length;
                                            i++) ...[
                                          cards[i],
                                          if (i != cards.length - 1)
                                            const SizedBox(height: 12),
                                        ],
                                      ],
                                    );
                                  }
                                  return Row(
                                    children: [
                                      for (int i = 0;
                                          i < cards.length;
                                          i++) ...[
                                        Expanded(child: cards[i]),
                                        if (i != cards.length - 1)
                                          const SizedBox(width: 12),
                                      ],
                                    ],
                                  );
                                },
                              ),
                              const SizedBox(height: 18),
                              LayoutBuilder(
                                builder: (context, c) {
                                  final narrow = c.maxWidth < 980;
                                  final revenue = _buildDashboardStylePanel(
                                    title: 'Revenue Projections',
                                    subtitle: 'Projected vs Actual Monthly Revenue.',
                                    iconPath: _revenuePanelIcon,
                                    child: _buildRevenueProjectionsChart(),
                                  );
                                  final cycle = _buildDashboardStylePanel(
                                    title: 'Cycle Time by Stage',
                                    subtitle:
                                        'Average days spent in each approval stage',
                                    iconPath: _pipelineChartIcon,
                                    child:
                                        _buildCycleTimeByStageChart(stageAvg),
                                  );

                                  if (narrow) {
                                    return Column(
                                      children: [
                                        revenue,
                                        const SizedBox(height: 12),
                                        cycle,
                                      ],
                                    );
                                  }
                                  return Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Expanded(child: revenue),
                                      const SizedBox(width: 12),
                                      Expanded(child: cycle),
                                    ],
                                  );
                                },
                              ),
                              const SizedBox(height: 18),
                              _buildDashboardStylePanel(
                                title: 'Approval Funnel',
                                subtitle:
                                    'Proposal Progression through Approval Pipeline.',
                                iconPath: _approvalFunnelIcon,
                                child: _buildApprovalFunnel(
                                  submitted: submitted,
                                  inReview: inReview,
                                  approved: approved,
                                  released: released,
                                ),
                              ),
                              const SizedBox(height: 18),
                              _buildDashboardStylePanel(
                                title: 'AI Usage',
                                subtitle:
                                    'Live usage for AI Assistant + Risk Gate (last 30 days, auto-refresh).',
                                iconPath: _aiUsageIcon,
                                child: _buildAiUsagePanel(),
                              ),
                              const SizedBox(height: 18),
                              _buildDashboardStylePanel(
                                title: 'Pipeline Funnel Chart',
                                subtitle:
                                    'Additional description can be included.',
                                iconPath: _pipelineChartIcon,
                                child: _buildPipelineFunnelChart(),
                              ),
                              const SizedBox(height: 18),
                              _buildFinancialAlertsPanel(),
                              const SizedBox(height: 24),
                              const Footer(),
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
    );
  }
}
