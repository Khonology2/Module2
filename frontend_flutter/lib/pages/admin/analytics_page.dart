import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:math' as math;
import 'dart:ui';
import 'package:web/web.dart' as web;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../api.dart';
import '../../services/auth_service.dart';
import '../../theme/manager_theme_controller.dart';
import '../../theme/premium_theme.dart';
import '../../widgets/custom_scrollbar.dart';
import '../../widgets/app_side_nav.dart';
import '../../widgets/admin/admin_sidebar.dart';
import '../../widgets/manager_page_background.dart';
enum AnalyticsPageMode {
  auto,
  creator,
  admin,
}

class AnalyticsPage extends StatefulWidget {
  const AnalyticsPage({
    super.key,
    this.mode = AnalyticsPageMode.auto,
  });

  final AnalyticsPageMode mode;

  @override
  State<AnalyticsPage> createState() => _AnalyticsPageState();
}

class _AnalyticsPageState extends State<AnalyticsPage>
    with TickerProviderStateMixin {
  // Figma redesign: this page is locked to a dark Figma palette and uses the
  // named PNGs in assets/images/admin_analytics_page/ which already contain
  // the red disc + glyph baked in. Other panel icons reuse existing assets.
  static const String _adminAnalyticsIconDir =
      'assets/images/admin_analytics_page';

  // ── KPI tiles (top row) ──
  static const String _icRevenue =
      '$_adminAnalyticsIconDir/Total_Revenue.png';
  static const String _icActive =
      '$_adminAnalyticsIconDir/Active_Proposals.png';
  static const String _icConversion =
      '$_adminAnalyticsIconDir/conversion_Rate.png';
  static const String _icAvgDeal =
      '$_adminAnalyticsIconDir/average_deal-size.png';

  // ── Panel headers ──
  static const String _icRevenuePanel =
      '$_adminAnalyticsIconDir/Revenue_Analytics.png';
  static const String _icPipeline =
      '$_adminAnalyticsIconDir/Proposal_Pipeline_view.png';
  static const String _ic30DayTrend =
      '$_adminAnalyticsIconDir/30days trend.png';
  static const String _icOverview =
      '$_adminAnalyticsIconDir/proposals over view.png';

  // ── Secondary KPI strip ──
  static const String _icProposals =
      '$_adminAnalyticsIconDir/Proposals.png';
  static const String _icPassing =
      '$_adminAnalyticsIconDir/Passing.png';
  static const String _icCompletion =
      '$_adminAnalyticsIconDir/Completion_rate.png';
  static const String _icSignOff =
      '$_adminAnalyticsIconDir/sign_off_rate.png';
  static const String _icAvgScore =
      '$_adminAnalyticsIconDir/ave_score.png';

  // ── Reused icons (no dedicated asset yet) ──
  static const String _icWinRate =
      '$_adminAnalyticsIconDir/Total_Revenue.png';
  static const String _icRiskGate = '$_adminAnalyticsIconDir/30days trend.png';
  static const String _icAiUsage =
      'assets/images/finance_manager_new_icons/AI_Usage.png';
  static const String _icCollab = '$_adminAnalyticsIconDir/30days trend.png';
  static const String _icEngagement =
      '$_adminAnalyticsIconDir/30days trend.png';
  static const String _icCycleTime =
      '$_adminAnalyticsIconDir/Proposal_Pipeline_view.png';
  // Center decorator inside donut charts (Win Rate, Readiness Breakdown).
  // Filename actually contains an apostrophe.
  static const String _icInnerPie =
      "$_adminAnalyticsIconDir/inner_piechart'.png";
  static const String _icReadiness =
      '$_adminAnalyticsIconDir/Total_Revenue.png';
  static const String _icProposalStatus =
      '$_adminAnalyticsIconDir/30days trend.png';

  // ── Header notification icons (reused from manager dashboard pattern) ──
  static const String _icHeaderMessages =
      'assets/images/new icons for manager/messages.png';
  static const String _icHeaderNotifications =
      'assets/images/new icons for manager/notifications.png';

  // ── Sizing (matches finance_manager analytics) ──
  static const double _kpiIconSize = 102.0;
  static const double _panelIconSize = 102.0;
  static const double _smallKpiIconSize = 72.0;
  static const double _headerActionIconDiameter = 80.0;
  static const double _headerActionIconAssetSize = 52.0;

  String _selectedPeriod = 'Last 30 Days';
  String _cycleTimeScope = 'team';
  // Disabled by default — every tick rebuilds every panel keyed off
  // `_cycleTimeRefreshTick` (Risk Gate, Cycle Time, Collaboration Load,
  // Client Engagement, AI Usage), which makes their values blank out and
  // re-populate. Users can flip the "Auto" switch to opt in.
  bool _cycleTimeAutoRefresh = false;
  int _cycleTimeRefreshTick = 0;
  Timer? _cycleTimeRefreshTimer;
  bool _isRefreshing = false;
  String? _pipelineStageFilter;
  final TextEditingController _cycleTimeOwnerCtrl = TextEditingController();
  final TextEditingController _cycleTimeProposalTypeCtrl =
      TextEditingController();
  final TextEditingController _globalClientCtrl = TextEditingController();
  final TextEditingController _globalRegionCtrl = TextEditingController();
  final TextEditingController _globalOwnerCtrl = TextEditingController();
  final TextEditingController _globalProposalTypeCtrl = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final _compactCurrencyFormatter = NumberFormat.compactCurrency(
    decimalDigits: 0,
    symbol: 'R',
    locale: 'en_ZA',
  );
  final _currencyFormatter = NumberFormat.currency(
    symbol: 'R',
    decimalDigits: 0,
    locale: 'en_ZA',
  );
  static const _currencySymbol = 'R';

  bool get _effectiveIsAdmin {
    switch (widget.mode) {
      case AnalyticsPageMode.admin:
        return true;
      case AnalyticsPageMode.creator:
        return false;
      case AnalyticsPageMode.auto:
        return _isAdminUser();
    }
  }

  String _resolvedScopeForCurrentUser() {
    // Prevent empty analytics caused by invalid scope/role combinations.
    final selected = _cycleTimeScope.trim().toLowerCase();
    if (_effectiveIsAdmin) {
      return selected.isEmpty ? 'all' : selected;
    }
    if (selected == 'all') return 'self';
    return selected.isEmpty ? 'self' : selected;
  }

  @override
  void initState() {
    super.initState();
    if (_effectiveIsAdmin) {
      _cycleTimeScope = 'all';
    } else {
      _cycleTimeScope = 'self';
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _ensureProposalsLoaded();
    });

    _cycleTimeRefreshTimer =
        Timer.periodic(const Duration(seconds: 60), (timer) {
      if (!mounted) return;
      if (!_cycleTimeAutoRefresh) return;
      setState(() => _cycleTimeRefreshTick++);
    });
  }

  /// Ensures `app.proposals` is populated before the dashboard renders KPIs.
  /// The first `fetchProposals()` call may silently time out (transient
  /// backend slowness) and leave every panel reading zero. We retry a few
  /// times with backoff so the page self-heals without a manual reload.
  Future<void> _ensureProposalsLoaded() async {
    final app = context.read<AppState>();
    const maxAttempts = 3;
    const initialDelay = Duration(seconds: 2);
    for (int attempt = 1; attempt <= maxAttempts; attempt++) {
      if (!mounted) return;
      try {
        await app.fetchProposals();
      } catch (_) {/* swallowed inside fetchProposals */}
      if (!mounted) return;
      if (app.proposals.isNotEmpty) return;
      if (attempt < maxAttempts) {
        await Future<void>.delayed(initialDelay * attempt);
      }
    }
  }

  /// Handler for the header "REFRESH" button. Refetches proposals (with
  /// retry), refreshes the notification bell, and force-rebuilds every
  /// FutureBuilder keyed off `_cycleTimeRefreshTick` (risk gate, cycle time,
  /// collaboration load, client engagement, AI usage). Provides explicit
  /// loading state + SnackBar feedback so the user can see it actually ran.
  Future<void> _runManualRefresh() async {
    if (_isRefreshing) return;
    setState(() => _isRefreshing = true);
    final app = context.read<AppState>();
    final messenger = ScaffoldMessenger.of(context);
    try {
      await Future.wait<void>([
        _ensureProposalsLoaded(),
        app.fetchNotifications().catchError((_) {}),
      ]);
      if (!mounted) return;
      setState(() {
        _cycleTimeRefreshTick++;
      });
      messenger.showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 2),
          backgroundColor: const Color(0xFF111827),
          content: Text(
            app.proposals.isEmpty
                ? 'Refreshed — backend returned 0 proposals.'
                : 'Refreshed ${app.proposals.length} proposals.',
            style: const TextStyle(color: Colors.white),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 3),
          backgroundColor: const Color(0xFFB91C1C),
          content: Text('Refresh failed: $e',
              style: const TextStyle(color: Colors.white)),
        ),
      );
    } finally {
      if (mounted) setState(() => _isRefreshing = false);
    }
  }

  Future<Map<String, dynamic>?> _fetchClientEngagement() async {
    try {
      final now = DateTime.now();
      final start = _periodStart(now);
      final fmt = DateFormat('yyyy-MM-dd');
      final startDate = start != null ? fmt.format(start) : null;
      final endDate = fmt.format(now);

      final owner = _globalOwnerCtrl.text.trim();
      final proposalType = _globalProposalTypeCtrl.text.trim();
      final client = _globalClientCtrl.text.trim();
      final region = _globalRegionCtrl.text.trim();
      final currentUser = context.read<AppState>().currentUser;
      final department = (currentUser?['department'] ?? '').toString().trim();
      final effectiveScope = _resolvedScopeForCurrentUser();

      final data = await context.read<AppState>().getClientEngagementAnalytics(
            startDate: startDate,
            endDate: endDate,
            owner: owner.isEmpty ? null : owner,
            proposalType: proposalType.isEmpty ? null : proposalType,
            client: client.isEmpty ? null : client,
            region: region.isEmpty ? null : region,
            scope: effectiveScope,
            department: department.isEmpty ? null : department,
          );
      return data;
    } catch (e) {
      print('Client engagement exception: $e');
      return null;
    }
  }

  // ignore: unused_element
  Future<Map<String, dynamic>?> _fetchPipelineBundle() async {
    try {
      final now = DateTime.now();
      final start = _periodStart(now);
      final fmt = DateFormat('yyyy-MM-dd');
      final startDate = start != null ? fmt.format(start) : null;
      final endDate = fmt.format(now);

      final owner = _globalOwnerCtrl.text.trim();
      final proposalType = _globalProposalTypeCtrl.text.trim();
      final client = _globalClientCtrl.text.trim();
      final currentUser = context.read<AppState>().currentUser;
      final department = (currentUser?['department'] ?? '').toString().trim();
      final app = context.read<AppState>();
      final effectiveScope = _resolvedScopeForCurrentUser();

      final results = await Future.wait([
        app.getProposalPipelineAnalytics(
          startDate: startDate,
          endDate: endDate,
          owner: owner.isEmpty ? null : owner,
          proposalType: proposalType.isEmpty ? null : proposalType,
          client: client.isEmpty ? null : client,
          scope: effectiveScope,
          department: department.isEmpty ? null : department,
          stage: _pipelineStageFilter,
        ),
        app.getCompletionRatesAnalytics(
          startDate: startDate,
          endDate: endDate,
          owner: owner.isEmpty ? null : owner,
          proposalType: proposalType.isEmpty ? null : proposalType,
          client: client.isEmpty ? null : client,
          scope: effectiveScope,
          department: department.isEmpty ? null : department,
        ),
      ]);

      return {
        'pipeline': results[0],
        'completion_rates': results[1],
      };
    } catch (e) {
      print('Pipeline bundle exception: $e');
      return null;
    }
  }

  // ignore: unused_element
  Widget _buildProposalPipelineView(Map<String, dynamic>? data) {
    final chrome = context.watch<ManagerThemeController>().chrome;
    final stagesRaw = (data?['stages'] as List?) ?? [];
    if (stagesRaw.isEmpty) {
      return Center(
        child: Text(
          'No pipeline proposals match these filters yet',
          style: PremiumTheme.bodyMedium.copyWith(color: chrome.textSecondary),
        ),
      );
    }

    final stages = <Map<String, dynamic>>[];
    for (final item in stagesRaw) {
      if (item is Map) {
        stages.add(item.cast<String, dynamic>());
      }
    }

    String formatDate(String? iso) {
      if (iso == null || iso.isEmpty) return '--';
      try {
        final dt = DateTime.parse(iso);
        return DateFormat('MMM d').format(dt);
      } catch (_) {
        return iso.length >= 10 ? iso.substring(0, 10) : iso;
      }
    }

    Color stageColor(String stage) {
      switch (stage) {
        case 'Signed':
          return PremiumTheme.success;
        case 'Released':
          return PremiumTheme.info;
        case 'In Review':
          return PremiumTheme.warning;
        case 'Archived':
          return Colors.white70;
        default:
          return PremiumTheme.orange;
      }
    }

    Widget stageHeader(String stage, int count) {
      final active =
          (_pipelineStageFilter ?? '').toLowerCase() == stage.toLowerCase();
      return InkWell(
        onTap: () {
          setState(() {
            if (active) {
              _pipelineStageFilter = null;
            } else {
              _pipelineStageFilter = stage;
            }
            _cycleTimeRefreshTick++;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: stageColor(stage).withValues(alpha: active ? 0.22 : 0.10),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: stageColor(stage).withValues(alpha: active ? 0.55 : 0.25),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  stage,
                  overflow: TextOverflow.ellipsis,
                  style: PremiumTheme.bodyMedium.copyWith(
                    color: chrome.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: chrome.isDark
                      ? Colors.black.withValues(alpha: 0.25)
                      : Colors.black.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  count.toString(),
                  style: PremiumTheme.labelMedium.copyWith(
                    color: chrome.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    Widget proposalCard(Map<String, dynamic> p) {
      final id = (p['proposal_id'] ?? '').toString();
      final title = (p['title'] ?? 'Untitled').toString();
      final client = (p['client'] ?? '').toString();
      final owner = (p['owner'] ?? '').toString();
      final updated = (p['updated_at'] ?? p['created_at'])?.toString();
      final status = (p['status'] ?? '').toString();
      return InkWell(
        onTap: () {
          Navigator.pushNamed(
            context,
            '/proposal_review',
            arguments: {
              'id': id,
              'title': title,
            },
          );
        },
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: chrome.isDark
              ? BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border:
                      Border.all(color: Colors.white.withValues(alpha: 0.10)),
                )
              : chrome.floatingPanelDecoration(radius: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: PremiumTheme.bodyMedium.copyWith(
                  color: chrome.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      client.isEmpty ? '-' : client,
                      overflow: TextOverflow.ellipsis,
                      style: PremiumTheme.bodyMedium.copyWith(
                        color: chrome.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  Text(
                    formatDate(updated),
                    style: PremiumTheme.bodyMedium.copyWith(
                      color: chrome.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      owner.isEmpty ? '-' : owner,
                      overflow: TextOverflow.ellipsis,
                      style: PremiumTheme.bodyMedium.copyWith(
                        color: chrome.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  Text(
                    status.isEmpty ? '-' : status,
                    overflow: TextOverflow.ellipsis,
                    style: PremiumTheme.bodyMedium.copyWith(
                      color: chrome.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    Widget stageColumn(Map<String, dynamic> stage) {
      final stageName = (stage['stage'] ?? '').toString();
      final count =
          (stage['count'] is num) ? (stage['count'] as num).toInt() : 0;
      final proposals = (stage['proposals'] as List?) ?? [];
      final cards = <Map<String, dynamic>>[];
      for (final p in proposals) {
        if (p is Map) {
          cards.add(p.cast<String, dynamic>());
        }
      }
      return SizedBox(
        width: 260,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            stageHeader(stageName, count),
            const SizedBox(height: 10),
            Expanded(
              child: cards.isEmpty
                  ? Center(
                      child: Text(
                        'No proposals',
                        style: PremiumTheme.bodyMedium.copyWith(
                          color: chrome.textMuted,
                          fontSize: 12,
                        ),
                      ),
                    )
                  : ListView.separated(
                      itemCount: cards.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, i) => proposalCard(cards[i]),
                    ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if ((_pipelineStageFilter ?? '').isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: chrome.isDark
                      ? BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                              color: Colors.white.withValues(alpha: 0.18)),
                        )
                      : chrome.floatingPanelDecoration(radius: 999),
                  child: Text(
                    'Filtered: ${_pipelineStageFilter!}',
                    style: PremiumTheme.bodyMedium.copyWith(
                      color: chrome.textPrimary,
                      fontSize: 12,
                    ),
                  ),
                ),
                _buildGlassButton(
                  'Clear',
                  Icons.close,
                  () {
                    setState(() {
                      _pipelineStageFilter = null;
                      _cycleTimeRefreshTick++;
                    });
                  },
                ),
              ],
            ),
          ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: math.max(constraints.maxWidth,
                      260.0 * stages.length + 20.0 * (stages.length - 1)),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (int i = 0; i < stages.length; i++) ...[
                        Expanded(
                          child: stageColumn(stages[i]),
                        ),
                        if (i != stages.length - 1) const SizedBox(width: 20),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  String _formatDurationSeconds(int seconds) {
    if (seconds <= 0) return '0m';
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    if (h > 0) {
      return '${h}h ${m}m';
    }
    if (m > 0) {
      return '${m}m';
    }
    return '${seconds}s';
  }

  Widget _buildClientEngagementChart(List<Map<String, dynamic>> points) {
    if (points.isEmpty) {
      return const Center(
        child: Text(
          'No client engagement data yet',
          style: TextStyle(color: Colors.white70),
        ),
      );
    }

    final maxValue = points.fold<double>(
      0,
      (p, e) => math.max(
          p, (e['views'] is num) ? (e['views'] as num).toDouble() : 0.0),
    );
    final yMax = maxValue == 0 ? 1.0 : maxValue * 1.2;
    final spots = <FlSpot>[
      for (int i = 0; i < points.length; i++)
        FlSpot(
          i.toDouble(),
          (points[i]['views'] is num)
              ? (points[i]['views'] as num).toDouble()
              : 0.0,
        )
    ];

    String _labelForIndex(int index) {
      if (index < 0 || index >= points.length) return '';
      final raw = (points[index]['date'] ?? '').toString();
      if (raw.length >= 10) {
        final mmdd = raw.substring(5, 10);
        return mmdd.replaceAll('-', '/');
      }
      return raw;
    }

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: yMax / 4,
          getDrawingHorizontalLine: (value) => FlLine(
            color: const Color(0xFF2D3748),
            strokeWidth: 1,
          ),
        ),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (value, meta) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: Text(
                    value.toInt().toString(),
                    style: const TextStyle(
                      color: Color(0xFF6B7280),
                      fontSize: 12,
                    ),
                  ),
                );
              },
            ),
          ),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              interval: (points.length / 6).clamp(1, 999).toDouble(),
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                return Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    _labelForIndex(index),
                    style: const TextStyle(
                      color: Color(0xFF6B7280),
                      fontSize: 12,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        minX: 0,
        maxX: (points.length - 1).toDouble(),
        minY: 0,
        maxY: yMax,
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: const Color(0xFF06B6D4),
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, index) {
                return FlDotCirclePainter(
                  radius: 4,
                  color: const Color(0xFF06B6D4),
                  strokeWidth: 2,
                  strokeColor: Colors.black.withValues(alpha: 0.3),
                );
              },
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  const Color(0xFF06B6D4).withValues(alpha: 0.3),
                  const Color(0xFF06B6D4).withValues(alpha: 0.0),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClientEngagementCard(Map<String, dynamic>? data) {
    final viewsByDayRaw = (data?['views_by_day'] as List?) ?? [];
    final points = <Map<String, dynamic>>[
      for (final item in viewsByDayRaw)
        if (item is Map)
          {
            'date': item['date'],
            'views': item['views'],
          }
    ];

    int n(dynamic v) {
      if (v is int) return v;
      if (v is num) return v.toInt();
      return 0;
    }

    final viewsTotal = n(data?['views_total']);
    final uniqueClients = n(data?['unique_clients']);
    final timeSpentSeconds = n(data?['time_spent_seconds']);
    final sessionsCount = n(data?['sessions_count']);

    final timeToSign = (data?['time_to_sign'] as Map?) ?? {};
    final ttsSamples = n(timeToSign['samples']);
    final avgDaysRaw = timeToSign['avg_days'];
    final avgDays = (avgDaysRaw is num) ? avgDaysRaw.toDouble() : null;
    final avgDaysLabel =
        avgDays == null ? '--' : '${avgDays.toStringAsFixed(1)} days';

    final conversion = (data?['conversion'] as Map?) ?? {};
    final released = n(conversion['released']);
    final signed = n(conversion['signed']);
    final rateRaw = conversion['rate_percent'];
    final rate = (rateRaw is num) ? rateRaw.toDouble() : null;
    final conversionLabel =
        rate == null ? '--' : '${rate.toStringAsFixed(1)}% ($signed/$released)';

    Widget statChip(String label, String value, Color color) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Text(
          '$label: $value',
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            statChip('Views', viewsTotal.toString(),
                Colors.white.withValues(alpha: 0.9)),
            statChip(
                'Unique Clients', uniqueClients.toString(), PremiumTheme.cyan),
            statChip('Time Spent', _formatDurationSeconds(timeSpentSeconds),
                PremiumTheme.teal),
            statChip('Sessions', sessionsCount.toString(), PremiumTheme.info),
            statChip('Conversion', conversionLabel, PremiumTheme.success),
            statChip('Avg Time To Sign', avgDaysLabel, PremiumTheme.purple),
            statChip('Samples', ttsSamples.toString(), Colors.white70),
          ],
        ),
        const SizedBox(height: 14),
        Expanded(child: _buildClientEngagementChart(points)),
      ],
    );
  }

  Future<Map<String, dynamic>?> _fetchCollaborationLoad() async {
    try {
      final now = DateTime.now();
      final start = _periodStart(now);
      final fmt = DateFormat('yyyy-MM-dd');
      final startDate = start != null ? fmt.format(start) : null;
      final endDate = fmt.format(now);

      final owner = _globalOwnerCtrl.text.trim();
      final proposalType = _globalProposalTypeCtrl.text.trim();
      final client = _globalClientCtrl.text.trim();
      final currentUser = context.read<AppState>().currentUser;
      final department = (currentUser?['department'] ?? '').toString().trim();

      final data = await context.read<AppState>().getCollaborationLoadAnalytics(
            startDate: startDate,
            endDate: endDate,
            owner: owner.isEmpty ? null : owner,
            proposalType: proposalType.isEmpty ? null : proposalType,
            client: client.isEmpty ? null : client,
            scope: _cycleTimeScope,
            department: department.isEmpty ? null : department,
          );
      return data;
    } catch (e) {
      print('Collaboration load exception: $e');
      return null;
    }
  }

  bool _canViewAiUsage() {
    final role = (context.read<AppState>().currentUser?['role'] ?? '')
        .toString()
        .trim()
        .toLowerCase();
    return role == 'admin' ||
        role == 'ceo' ||
        role == 'approver' ||
        role == 'manager' ||
        role == 'finance' ||
        role == 'finance_manager' ||
        role == 'financial_manager' ||
        role == 'finance manager' ||
        role == 'financial manager';
  }

  Future<Map<String, dynamic>?> _fetchAiUsageAnalytics() async {
    try {
      final now = DateTime.now();
      final start = _periodStart(now);
      final fmt = DateFormat('yyyy-MM-dd');
      final startDate = start != null ? fmt.format(start) : null;
      final endDate = fmt.format(now);

      return await context.read<AppState>().getAiUsageAnalytics(
            startDate: startDate,
            endDate: endDate,
          );
    } catch (e) {
      print('AI usage analytics exception: $e');
      return null;
    }
  }

  Widget _buildAiUsageCard(Map<String, dynamic>? data) {
    if (data == null) {
      return Center(
        child: Text(
          'AI usage data unavailable.',
          style: PremiumTheme.bodyMedium.copyWith(color: Colors.white70),
        ),
      );
    }
    if (data['error_status'] != null) {
      final status = data['error_status'];
      if (status == 403) {
        return Center(
          child: Text(
            'AI usage dashboard is only available to admin and finance roles.',
            style: PremiumTheme.bodyMedium.copyWith(color: Colors.white70),
            textAlign: TextAlign.center,
          ),
        );
      }
      return Center(
        child: Text(
          'Failed to load AI usage data${data['error'] != null ? ': ${data['error']}' : '.'}',
          style: PremiumTheme.bodyMedium.copyWith(color: Colors.white70),
          textAlign: TextAlign.center,
        ),
      );
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
    final dailyTrend = ((data['daily_trend'] as List?) ?? const [])
        .whereType<Map>()
        .map((e) => e.cast<String, dynamic>())
        .toList();

    int n(dynamic v) {
      if (v is int) return v;
      if (v is num) return v.toInt();
      return int.tryParse((v ?? '').toString()) ?? 0;
    }

    final totalRequests = n(totals['total_requests']);
    final successCount = n(totals['success_count']);
    final failedCount = n(totals['failed_count']);
    final blockedCount = n(totals['blocked_count']);
    final acceptedCount = n(totals['accepted_count']);
    final acceptanceRate = (totals['acceptance_rate'] is num)
        ? totals['acceptance_rate'] as num
        : 0;
    final totalTokens = n(usageSummary['total_tokens']);
    final estimatedCostZar = (usageSummary['estimated_cost_zar'] is num)
        ? usageSummary['estimated_cost_zar'] as num
        : 0;
    final averageSpendZar = (usageSummary['average_spend_zar'] is num)
        ? usageSummary['average_spend_zar'] as num
        : 0;
    final averageSpendReason =
        (usageSummary['average_spend_reason'] ?? '').toString();

    Widget chip(String label, String value, Color color) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Text(
          '$label: $value',
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
        ),
      );
    }

    final trendSummary = dailyTrend.isNotEmpty
        ? '${dailyTrend.length} day${dailyTrend.length == 1 ? '' : 's'} tracked'
        : 'No trend data yet';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            chip('Requests', totalRequests.toString(), Colors.white),
            chip('Success', successCount.toString(), PremiumTheme.success),
            chip('Failed', failedCount.toString(), PremiumTheme.error),
            chip('Blocked', blockedCount.toString(), PremiumTheme.warning),
            chip('Accepted', acceptedCount.toString(), PremiumTheme.teal),
            chip('Acceptance', '${acceptanceRate.toStringAsFixed(1)}%',
                PremiumTheme.cyan),
            chip('Tokens', NumberFormat.compact().format(totalTokens),
                PremiumTheme.purple),
            chip('Approx Cost', 'R ${estimatedCostZar.toStringAsFixed(2)}',
                PremiumTheme.info),
            chip('Average Spent', 'R ${averageSpendZar.toStringAsFixed(2)}',
                PremiumTheme.teal),
          ],
        ),
        const SizedBox(height: 14),
        if (averageSpendReason.isNotEmpty)
          Text(
            'Reason: $averageSpendReason',
            style: PremiumTheme.bodyMedium.copyWith(color: Colors.white70),
          ),
        if (averageSpendReason.isNotEmpty) const SizedBox(height: 8),
        Text(
          trendSummary,
          style: PremiumTheme.bodyMedium.copyWith(color: Colors.white70),
        ),
        const SizedBox(height: 14),
        Expanded(
          child: Row(
            children: [
              Expanded(
                child: _buildAiUsageList(
                  title: 'By Endpoint',
                  rows: endpointSplit,
                  leftKey: 'endpoint',
                  rightKey: 'requests',
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildAiUsageList(
                  title: 'Top Users',
                  rows: topUsers,
                  leftKey: 'username',
                  rightKey: 'requests',
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAiUsageList({
    required String title,
    required List<Map<String, dynamic>> rows,
    required String leftKey,
    required String rightKey,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
            child: Text(
              title,
              style: PremiumTheme.bodyMedium.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const Divider(height: 1, color: Color(0x22FFFFFF)),
          Expanded(
            child: rows.isEmpty
                ? Center(
                    child: Text(
                      'No data',
                      style: PremiumTheme.bodyMedium
                          .copyWith(color: Colors.white70),
                    ),
                  )
                : ListView.separated(
                    itemCount: rows.length,
                    separatorBuilder: (_, __) =>
                        const Divider(height: 1, color: Color(0x11FFFFFF)),
                    itemBuilder: (context, i) {
                      final row = rows[i];
                      final left = (row[leftKey] ?? '-').toString();
                      final right = (row[rightKey] ?? '0').toString();
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                left,
                                style: PremiumTheme.bodyMedium
                                    .copyWith(color: Colors.white),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(
                              right,
                              style: PremiumTheme.bodyMedium
                                  .copyWith(color: Colors.white70),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildCollaborationLoadCard(Map<String, dynamic>? data) {
    final totals = (data?['totals'] as Map?) ?? {};
    final totalProposals = (data?['total_proposals'] is num)
        ? (data?['total_proposals'] as num).toInt()
        : 0;

    int n(dynamic v) {
      if (v is int) return v;
      if (v is num) return v.toInt();
      return 0;
    }

    final comments = n(totals['comments']);
    final versions = n(totals['versions']);
    final events = n(totals['activity_events']);
    final interactions = n(totals['interactions']);

    final top = (data?['top_proposals'] as List?) ?? [];

    Widget statChip(String label, int value, Color color) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Text(
          '$label: $value',
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            statChip('Interactions', interactions,
                Colors.white.withValues(alpha: 0.9)),
            statChip('Comments', comments, PremiumTheme.teal),
            statChip('Versions', versions, PremiumTheme.purple),
            statChip('Activity', events, PremiumTheme.info),
            statChip('Proposals', totalProposals, Colors.white70),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          'Top active proposals',
          style: PremiumTheme.titleMedium.copyWith(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 10),
        if (top.isEmpty)
          Text(
            'No collaboration activity found in this period.',
            style: PremiumTheme.bodyMedium.copyWith(color: Colors.white70),
          )
        else
          SizedBox(
            height: 220,
            child: ListView.separated(
              itemCount: top.length,
              separatorBuilder: (_, __) => Divider(
                height: 1,
                color: Colors.white.withValues(alpha: 0.08),
              ),
              itemBuilder: (context, i) {
                final row = top[i];
                final id = (row['proposal_id'] ?? '').toString();
                final title = (row['title'] ?? 'Untitled').toString();
                final client = (row['client'] ?? '').toString();
                final status = (row['status'] ?? '').toString();
                final rowInteractions = n(row['interactions']);

                return InkWell(
                  onTap: () {
                    Navigator.pushNamed(
                      context,
                      '/proposal_review',
                      arguments: {
                        'id': id,
                        'title': title,
                      },
                    );
                  },
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 5,
                          child: Text(
                            title,
                            style: PremiumTheme.bodyMedium.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Expanded(
                          flex: 3,
                          child: Text(
                            client.isEmpty ? '-' : client,
                            style: PremiumTheme.bodyMedium
                                .copyWith(color: Colors.white70),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            status.isEmpty ? '-' : status,
                            style: PremiumTheme.bodyMedium
                                .copyWith(color: Colors.white70),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        SizedBox(
                          width: 110,
                          child: Text(
                            rowInteractions.toString(),
                            style: PremiumTheme.bodyMedium
                                .copyWith(color: Colors.white70),
                            textAlign: TextAlign.right,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _cycleTimeRefreshTimer?.cancel();
    _cycleTimeOwnerCtrl.dispose();
    _cycleTimeProposalTypeCtrl.dispose();
    _globalClientCtrl.dispose();
    _globalRegionCtrl.dispose();
    _globalOwnerCtrl.dispose();
    _globalProposalTypeCtrl.dispose();
    super.dispose();
  }

  void _exportAsCSV() {
    try {
      final app = context.read<AppState>();
      final filtered = _filterProposals(app.proposals);
      final analytics = _calculateAnalytics(filtered);
      final metrics = _buildMetricCards(analytics);
      final csvContent = StringBuffer();
      csvContent.writeln('Analytics Report - $_selectedPeriod');
      csvContent.writeln(
          'Generated: ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}');
      csvContent.writeln('');
      csvContent.writeln('KEY METRICS');
      csvContent.writeln('Metric,Value,Change');
      for (final metric in metrics) {
        csvContent.writeln(
            '${metric.title},"${metric.value}",${metric.change.isEmpty ? "--" : metric.change}');
      }
      csvContent.writeln('');
      csvContent.writeln('RECENT PROPOSALS');
      csvContent.writeln('Proposal,Value,Status,Days,Win Probability');
      for (final proposal in analytics.recentProposals) {
        csvContent.writeln('"${proposal.title}",'
            '"${proposal.valueLabel}",'
            '"${proposal.status}",'
            '${proposal.daysOpen},'
            '${proposal.probabilityLabel}');
      }

      final blob = web.Blob([csvContent.toString().toJS].toJS);
      final url = web.URL.createObjectURL(blob);
      final anchor = web.document.createElement('a') as web.HTMLAnchorElement;
      anchor.href = url;
      anchor.download =
          'analytics_${DateTime.now().millisecondsSinceEpoch}.csv';
      anchor.click();
      web.URL.revokeObjectURL(url);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          _buildSuccessSnackBar('CSV exported successfully!'),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          _buildErrorSnackBar('Export failed: $e'),
        );
      }
    }
  }

  void _exportAsJSON() {
    try {
      final app = context.read<AppState>();
      final filtered = _filterProposals(app.proposals);
      final analytics = _calculateAnalytics(filtered);
      final data = {
        'export_date': DateTime.now().toIso8601String(),
        'period': _selectedPeriod,
        'metrics': {
          'total_pipeline_value': analytics.totalPipelineValue,
          'active_proposals': analytics.activeProposals,
          'conversion_rate_percent': analytics.winRate,
          'average_deal_size': analytics.averageDealSize,
          'revenue_change_percent': analytics.revenueChangePercent,
          'active_change_percent': analytics.activeChangePercent,
          'conversion_change_percent': analytics.conversionChangePercent,
          'average_deal_change_percent': analytics.averageDealChangePercent,
        },
        'recent_proposals': analytics.recentProposals
            .map((proposal) => {
                  'title': proposal.title,
                  'value': proposal.value,
                  'status': proposal.status,
                  'days_open': proposal.daysOpen,
                  'win_probability_percent':
                      (proposal.probability * 100).round(),
                })
            .toList(),
      };

      final jsonContent = const JsonEncoder.withIndent('  ').convert(data);
      final blob = web.Blob([jsonContent.toJS].toJS);
      final url = web.URL.createObjectURL(blob);
      final anchor = web.document.createElement('a') as web.HTMLAnchorElement;
      anchor.href = url;
      anchor.download =
          'analytics_${DateTime.now().millisecondsSinceEpoch}.json';
      anchor.click();
      web.URL.revokeObjectURL(url);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          _buildSuccessSnackBar('JSON exported successfully!'),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          _buildErrorSnackBar('Export failed: $e'),
        );
      }
    }
  }

  SnackBar _buildSuccessSnackBar(String message) {
    return SnackBar(
      content: Row(
        children: [
          const Icon(Icons.check_circle, color: Color(0xFF10B981)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
      backgroundColor: const Color(0xFF1A1F26),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0x33FFFFFF)),
      ),
      duration: const Duration(seconds: 3),
    );
  }

  Future<Map<String, dynamic>?> _fetchRiskGateSummary() async {
    try {
      final now = DateTime.now();
      final start = _periodStart(now);
      final fmt = DateFormat('yyyy-MM-dd');
      final startDate = start != null ? fmt.format(start) : null;
      final endDate = fmt.format(now);

      final owner = _globalOwnerCtrl.text.trim();
      final proposalType = _globalProposalTypeCtrl.text.trim();
      final client = _globalClientCtrl.text.trim();
      final currentUser = context.read<AppState>().currentUser;
      final department = (currentUser?['department'] ?? '').toString().trim();
      final role = (currentUser?['role'] ?? '').toString().trim().toLowerCase();
      final riskScope = (role == 'admin' ||
              role == 'ceo' ||
              role == 'approver' ||
              role == 'manager' ||
              role == 'finance' ||
              role == 'finance_manager' ||
              role == 'financial_manager' ||
              role == 'financial manager')
          ? 'all'
          : _cycleTimeScope;

      final data = await context.read<AppState>().getRiskGateSummary(
            startDate: startDate,
            endDate: endDate,
            owner: owner.isEmpty ? null : owner,
            proposalType: proposalType.isEmpty ? null : proposalType,
            client: client.isEmpty ? null : client,
            scope: riskScope,
            department: department.isEmpty ? null : department,
          );
      return data;
    } catch (e) {
      print('Risk gate summary exception: $e');
      return null;
    }
  }

  Future<void> _showRiskGateProposalsDialog(String riskStatus) async {
    try {
      final now = DateTime.now();
      final start = _periodStart(now);
      final fmt = DateFormat('yyyy-MM-dd');
      final startDate = start != null ? fmt.format(start) : null;
      final endDate = fmt.format(now);

      final owner = _globalOwnerCtrl.text.trim();
      final proposalType = _globalProposalTypeCtrl.text.trim();
      final client = _globalClientCtrl.text.trim();
      final currentUser = context.read<AppState>().currentUser;
      final department = (currentUser?['department'] ?? '').toString().trim();
      final role = (currentUser?['role'] ?? '').toString().trim().toLowerCase();
      final riskScope = (role == 'admin' ||
              role == 'ceo' ||
              role == 'approver' ||
              role == 'manager' ||
              role == 'finance' ||
              role == 'finance_manager' ||
              role == 'financial_manager' ||
              role == 'financial manager')
          ? 'all'
          : _cycleTimeScope;

      await showDialog(
        context: context,
        builder: (context) {
          return Dialog(
            backgroundColor: Colors.transparent,
            insetPadding:
                const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                child: Container(
                  constraints:
                      const BoxConstraints(maxWidth: 980, maxHeight: 720),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.white.withValues(alpha: 0.12),
                        Colors.white.withValues(alpha: 0.06),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: PremiumTheme.glassWhiteBorder,
                      width: 1.5,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Risk Gate: $riskStatus',
                              style: PremiumTheme.titleLarge
                                  .copyWith(color: Colors.white),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.close, color: Colors.white),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: FutureBuilder<Map<String, dynamic>?>(
                          future: context.read<AppState>().getRiskGateProposals(
                                riskStatus: riskStatus,
                                startDate: startDate,
                                endDate: endDate,
                                owner: owner.isEmpty ? null : owner,
                                proposalType:
                                    proposalType.isEmpty ? null : proposalType,
                                client: client.isEmpty ? null : client,
                                scope: riskScope,
                                department:
                                    department.isEmpty ? null : department,
                                limit: 250,
                              ),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              return const Center(
                                  child: CircularProgressIndicator());
                            }
                            final data = snapshot.data;
                            final proposals =
                                (data?['proposals'] as List?) ?? [];

                            if (proposals.isEmpty) {
                              return Center(
                                child: Text(
                                  'No proposals match this bucket under the current filters.',
                                  style: PremiumTheme.bodyMedium,
                                ),
                              );
                            }

                            return ListView.separated(
                              itemCount: proposals.length,
                              separatorBuilder: (_, __) => Divider(
                                height: 1,
                                color: Colors.white.withValues(alpha: 0.08),
                              ),
                              itemBuilder: (context, i) {
                                final p = proposals[i];
                                final id = (p['proposal_id'] ?? '').toString();
                                final title =
                                    (p['proposal_title'] ?? 'Untitled')
                                        .toString();
                                final clientName =
                                    (p['client'] ?? '').toString();
                                final status =
                                    (p['proposal_status'] ?? '').toString();
                                final risk =
                                    (p['risk_status'] ?? 'NONE').toString();
                                final score = p['risk_score'];

                                return InkWell(
                                  onTap: () {
                                    Navigator.pop(context);
                                    Navigator.pushNamed(
                                      this.context,
                                      '/proposal_review',
                                      arguments: {
                                        'id': id,
                                        'title': title,
                                      },
                                    );
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 12),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          flex: 4,
                                          child: Text(
                                            title,
                                            style: PremiumTheme.bodyMedium
                                                .copyWith(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w600,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        Expanded(
                                          flex: 3,
                                          child: Text(
                                            clientName.isEmpty
                                                ? '-'
                                                : clientName,
                                            style: PremiumTheme.bodyMedium
                                                .copyWith(
                                              color: Colors.white70,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                            textAlign: TextAlign.left,
                                          ),
                                        ),
                                        Expanded(
                                          flex: 2,
                                          child: Text(
                                            status.isEmpty ? '-' : status,
                                            style: PremiumTheme.bodyMedium
                                                .copyWith(
                                              color: Colors.white70,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        Expanded(
                                          flex: 2,
                                          child: Text(
                                            risk,
                                            style: PremiumTheme.bodyMedium
                                                .copyWith(
                                              color: Colors.white70,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        SizedBox(
                                          width: 90,
                                          child: Text(
                                            score == null
                                                ? '-'
                                                : score.toString(),
                                            style: PremiumTheme.bodyMedium
                                                .copyWith(
                                              color: Colors.white70,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                            textAlign: TextAlign.right,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      );
    } catch (e) {
      print('Risk gate drill-down dialog error: $e');
    }
  }

  Widget _buildRiskGateIndicator(Map<String, dynamic>? data) {
    final overall = (data?['overall_level'] ?? 'NONE').toString().toUpperCase();
    final countsMap = data?['counts'];
    final counts = <String, int>{'PASS': 0, 'REVIEW': 0, 'BLOCK': 0, 'NONE': 0};
    final totalProposals = (data?['total_proposals'] is num)
        ? (data?['total_proposals'] as num).toInt()
        : 0;
    final analyzedProposals = (data?['analyzed_proposals'] is num)
        ? (data?['analyzed_proposals'] as num).toInt()
        : 0;
    if (countsMap is Map) {
      for (final k in counts.keys) {
        final v = countsMap[k];
        if (v is int) {
          counts[k] = v;
        } else if (v is num) {
          counts[k] = v.toInt();
        }
      }
    }

    Color levelColor() {
      switch (overall) {
        case 'BLOCK':
          return PremiumTheme.error;
        case 'REVIEW':
          return PremiumTheme.warning;
        case 'PASS':
          return PremiumTheme.success;
        default:
          return Colors.white.withValues(alpha: 0.6);
      }
    }

    String levelLabel() {
      switch (overall) {
        case 'BLOCK':
          return 'High Risk';
        case 'REVIEW':
          return 'Needs Review';
        case 'PASS':
          return 'Low Risk';
        default:
          return 'Not Analyzed';
      }
    }

    Widget chip({
      required String riskKey,
      required String label,
      required int value,
      required Color color,
    }) {
      return InkWell(
        onTap: () => _showRiskGateProposalsDialog(riskKey),
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: color.withValues(alpha: 0.35)),
          ),
          child: Text(
            '$label: $value',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: levelColor(),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              levelLabel(),
              style: PremiumTheme.titleMedium.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            chip(
              riskKey: 'PASS',
              label: 'Pass',
              value: counts['PASS'] ?? 0,
              color: PremiumTheme.success,
            ),
            chip(
              riskKey: 'REVIEW',
              label: 'Review',
              value: counts['REVIEW'] ?? 0,
              color: PremiumTheme.warning,
            ),
            chip(
              riskKey: 'BLOCK',
              label: 'Block',
              value: counts['BLOCK'] ?? 0,
              color: PremiumTheme.error,
            ),
            chip(
              riskKey: 'NONE',
              label: 'Not Run Yet',
              value: counts['NONE'] ?? 0,
              color: Colors.white.withValues(alpha: 0.7),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Coverage: $analyzedProposals of $totalProposals proposals analyzed (latest run per proposal)',
          style: PremiumTheme.bodyMedium.copyWith(
            color: PremiumTheme.textSecondary,
          ),
        ),
      ],
    );
  }

  SnackBar _buildErrorSnackBar(String message) {
    return SnackBar(
      content: Text(message, style: const TextStyle(color: Colors.white)),
      backgroundColor: const Color(0xFFEF4444),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      duration: const Duration(seconds: 3),
    );
  }

  void _showExportDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
              child: Container(
                padding: const EdgeInsets.all(40),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.black.withValues(alpha: 0.85),
                      Colors.black.withValues(alpha: 0.75),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border:
                      Border.all(color: const Color(0x33FFFFFF), width: 1.5),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: const Color(0xFF06B6D4).withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.download_rounded,
                        size: 48,
                        color: Color(0xFF06B6D4),
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Export Analytics Report',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Choose your preferred export format',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                    ),
                    const SizedBox(height: 32),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildExportButton(
                          'CSV',
                          Icons.table_chart,
                          const Color(0xFF10B981),
                          _exportAsCSV,
                        ),
                        const SizedBox(width: 16),
                        _buildExportButton(
                          'JSON',
                          Icons.code,
                          const Color(0xFF06B6D4),
                          _exportAsJSON,
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(color: Color(0xFF9CA3AF)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildExportButton(
    String label,
    IconData icon,
    Color color,
    VoidCallback onPressed,
  ) {
    return ElevatedButton(
      onPressed: () {
        Navigator.of(context).pop();
        onPressed();
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 0,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 32),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  _AnalyticsSnapshot _calculateAnalytics(List<dynamic> rawProposals) {
    final now = DateTime.now();
    final normalized = <Map<String, dynamic>>[];
    for (final proposal in rawProposals) {
      if (proposal is Map<String, dynamic>) {
        normalized.add(proposal);
      } else if (proposal is Map) {
        try {
          normalized.add(proposal.cast<String, dynamic>());
        } catch (_) {
          continue;
        }
      }
    }

    final startMonth = DateTime(now.year, 1, 1);
    final monthlyPoints = <_MonthlyPoint>[];
    var cursorMonth = startMonth;
    while (!cursorMonth.isAfter(DateTime(now.year, 12, 1))) {
      monthlyPoints.add(_MonthlyPoint(cursorMonth));
      cursorMonth = DateTime(cursorMonth.year, cursorMonth.month + 1, 1);
    }

    double totalRevenue = 0;
    int proposalsWithBudget = 0;
    int winCount = 0;
    int lossCount = 0;
    int activeCount = 0;
    final Map<String, int> statusCounts = {};
    final List<_ProposalPerformanceRow> performanceRows = [];

    for (final proposal in normalized) {
      final statusRaw = (proposal['status'] ?? 'Draft').toString();
      final statusLabel = _formatStatusLabel(statusRaw);
      final statusLower = statusRaw.toLowerCase();
      statusCounts[statusLabel] = (statusCounts[statusLabel] ?? 0) + 1;

      final budget = _parseBudget(proposal['budget'] ??
          proposal['estimated_value'] ??
          proposal['estimatedValue']);
      if (budget > 0) {
        totalRevenue += budget;
        proposalsWithBudget++;
      }

      final isWin = _isWinStatus(statusLower);
      final isLoss = _isLossStatus(statusLower);
      if (isWin) {
        winCount++;
      } else if (isLoss) {
        lossCount++;
      }
      if (!_isClosedStatus(statusLower)) {
        activeCount++;
      }

      final created =
          _parseDate(proposal['created_at'] ?? proposal['createdAt']);
      if (created != null) {
        final diffFromStart = (created.year - startMonth.year) * 12 +
            (created.month - startMonth.month);
        if (diffFromStart >= 0 && diffFromStart < monthlyPoints.length) {
          monthlyPoints[diffFromStart].revenue += budget;
          monthlyPoints[diffFromStart].proposals += 1;
          if (isWin) {
            monthlyPoints[diffFromStart].wins += 1;
          } else if (isLoss) {
            monthlyPoints[diffFromStart].losses += 1;
          }
        }
      }

      final updated =
          _parseDate(proposal['updated_at'] ?? proposal['updatedAt']) ??
              created;
      performanceRows.add(
        _ProposalPerformanceRow(
          title: proposal['title']?.toString().isNotEmpty == true
              ? proposal['title'].toString()
              : 'Untitled',
          value: budget > 0 ? budget : null,
          valueLabel: budget > 0 ? _formatCurrency(budget) : 'R0',
          status: statusLabel,
          daysOpen:
              updated != null ? DateTime.now().difference(updated).inDays : 0,
          probability: _probabilityForStatus(statusLower),
          statusColor: _statusColor(statusLower),
          updatedAt: updated,
        ),
      );
    }

    performanceRows.sort((a, b) {
      final aDate = a.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bDate = b.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bDate.compareTo(aDate);
    });
    final recentProposals = performanceRows.take(5).toList();

    final double winRate = winCount + lossCount > 0
        ? (winCount / (winCount + lossCount)) * 100
        : 0.0;
    final double lossRate = winCount + lossCount > 0
        ? (lossCount / (winCount + lossCount)) * 100
        : 0.0;
    final double averageDealSize =
        proposalsWithBudget > 0 ? totalRevenue / proposalsWithBudget : 0.0;

    double? revenueChangePercent;
    double? activeChangePercent;
    double? conversionChangePercent;
    double? averageDealChangePercent;

    if (monthlyPoints.length >= 2) {
      final currentMonth = monthlyPoints.last;
      final previousMonth = monthlyPoints[monthlyPoints.length - 2];
      revenueChangePercent =
          _percentChange(previousMonth.revenue, currentMonth.revenue);
      activeChangePercent = _percentChange(
        previousMonth.proposals.toDouble(),
        currentMonth.proposals.toDouble(),
      );

      final currentDecisions = currentMonth.wins + currentMonth.losses;
      final previousDecisions = previousMonth.wins + previousMonth.losses;
      final currentConversion = currentDecisions > 0
          ? (currentMonth.wins / currentDecisions) * 100
          : null;
      final previousConversion = previousDecisions > 0
          ? (previousMonth.wins / previousDecisions) * 100
          : null;
      if (currentConversion != null && previousConversion != null) {
        conversionChangePercent =
            _percentChange(previousConversion, currentConversion);
      }

      final currentAvg = currentMonth.proposals > 0
          ? currentMonth.revenue / currentMonth.proposals
          : null;
      final previousAvg = previousMonth.proposals > 0
          ? previousMonth.revenue / previousMonth.proposals
          : null;
      if (currentAvg != null && previousAvg != null) {
        averageDealChangePercent = _percentChange(previousAvg, currentAvg);
      }
    }

    return _AnalyticsSnapshot(
      totalPipelineValue: totalRevenue,
      totalProposals: normalized.length,
      activeProposals: activeCount,
      averageDealSize: averageDealSize,
      winRate: winRate,
      lossRate: lossRate,
      statusCounts: statusCounts,
      monthlyPoints: monthlyPoints,
      recentProposals: recentProposals,
      revenueChangePercent: revenueChangePercent,
      activeChangePercent: activeChangePercent,
      conversionChangePercent: conversionChangePercent,
      averageDealChangePercent: averageDealChangePercent,
    );
  }

  List<_MetricCardData> _buildMetricCards(_AnalyticsSnapshot analytics) {
    final metrics = <_MetricCardData>[];
    metrics.add(
      _MetricCardData(
        title: 'Total Revenue',
        value: _formatCurrency(analytics.totalPipelineValue, compact: true),
        change: _formatChange(analytics.revenueChangePercent),
        isPositive: _isPositiveChange(analytics.revenueChangePercent),
        subtitle: 'vs last month',
      ),
    );
    metrics.add(
      _MetricCardData(
        title: 'Active Proposals',
        value: analytics.activeProposals.toString(),
        change: _formatChange(analytics.activeChangePercent),
        isPositive: _isPositiveChange(analytics.activeChangePercent),
        subtitle: 'vs last month',
      ),
    );
    metrics.add(
      _MetricCardData(
        title: 'Conversion Rate',
        value: '${analytics.winRate.toStringAsFixed(1)}%',
        change: _formatChange(analytics.conversionChangePercent),
        isPositive: _isPositiveChange(analytics.conversionChangePercent),
        subtitle: 'vs last month',
      ),
    );
    metrics.add(
      _MetricCardData(
        title: 'Avg Deal Size',
        value: _formatCurrency(analytics.averageDealSize, compact: true),
        change: _formatChange(analytics.averageDealChangePercent),
        isPositive: _isPositiveChange(analytics.averageDealChangePercent),
        subtitle: 'vs last month',
      ),
    );
    return metrics;
  }

  double _parseBudget(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    final cleaned = value.toString().replaceAll(RegExp(r'[^\d\.-]'), '');
    return double.tryParse(cleaned) ?? 0;
  }

  DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String && value.isNotEmpty) {
      return DateTime.tryParse(value);
    }
    return null;
  }

  DateTime? _periodStart(DateTime now) {
    if (_selectedPeriod == 'Last 7 Days') {
      return now.subtract(const Duration(days: 7));
    }
    if (_selectedPeriod == 'Last 30 Days') {
      return now.subtract(const Duration(days: 30));
    }
    if (_selectedPeriod == 'Last 90 Days') {
      return now.subtract(const Duration(days: 90));
    }
    if (_selectedPeriod == 'This Year') {
      return DateTime(now.year, 1, 1);
    }
    return null;
  }

  List<Map<String, dynamic>> _filterProposals(List<dynamic> rawProposals) {
    final normalized = <Map<String, dynamic>>[];
    for (final proposal in rawProposals) {
      if (proposal is Map<String, dynamic>) {
        normalized.add(proposal);
      } else if (proposal is Map) {
        try {
          normalized.add(proposal.cast<String, dynamic>());
        } catch (_) {
          continue;
        }
      }
    }

    final now = DateTime.now();
    final start = _periodStart(now);
    final clientQ = _globalClientCtrl.text.trim().toLowerCase();
    final ownerQ = _globalOwnerCtrl.text.trim().toLowerCase();
    final typeQ = _globalProposalTypeCtrl.text.trim().toLowerCase();

    bool matchesAny(dynamic value, String query) {
      if (query.isEmpty) return true;
      if (value == null) return false;
      return value.toString().toLowerCase().contains(query);
    }

    return normalized.where((p) {
      if (clientQ.isNotEmpty) {
        final ok = matchesAny(p['client'], clientQ) ||
            matchesAny(p['client_name'], clientQ) ||
            matchesAny(p['clientName'], clientQ) ||
            matchesAny(p['client_email'], clientQ) ||
            matchesAny(p['clientEmail'], clientQ);
        if (!ok) return false;
      }

      if (ownerQ.isNotEmpty) {
        final ok = matchesAny(p['owner_id'], ownerQ) ||
            matchesAny(p['ownerId'], ownerQ) ||
            matchesAny(p['user_id'], ownerQ) ||
            matchesAny(p['userId'], ownerQ) ||
            matchesAny(p['owner'], ownerQ) ||
            matchesAny(p['owner_name'], ownerQ) ||
            matchesAny(p['ownerName'], ownerQ) ||
            matchesAny(p['owner_email'], ownerQ) ||
            matchesAny(p['ownerEmail'], ownerQ);
        if (!ok) return false;
      }

      if (typeQ.isNotEmpty) {
        final ok = matchesAny(p['template_type'], typeQ) ||
            matchesAny(p['templateType'], typeQ) ||
            matchesAny(p['template_key'], typeQ) ||
            matchesAny(p['templateKey'], typeQ);
        if (!ok) return false;
      }

      if (start != null) {
        final created = _parseDate(p['created_at'] ?? p['createdAt']);
        final updated = _parseDate(p['updated_at'] ?? p['updatedAt']);
        final probe = created ?? updated;
        if (probe == null) return false;
        if (probe.isBefore(start) || probe.isAfter(now)) return false;
      }

      return true;
    }).toList();
  }

  Widget _analyticsFilterShell(ManagerChromeTheme chrome, Widget child) {
    const pad = EdgeInsets.symmetric(horizontal: 10, vertical: 6);
    if (chrome.isDark) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: pad,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
            ),
            child: child,
          ),
        ),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: pad,
        decoration: chrome.floatingPanelDecoration(radius: 10),
        child: child,
      ),
    );
  }

  Widget _buildGlobalFilterBar() {
    final chrome = context.watch<ManagerThemeController>().chrome;
    Widget glassField({required Widget child}) =>
        _analyticsFilterShell(chrome, child);

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(
          width: 240,
          child: glassField(
            child: TextField(
              controller: _globalClientCtrl,
              style: TextStyle(color: chrome.textPrimary, fontSize: 12),
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                hintText: 'Client (optional)',
                hintStyle: TextStyle(color: chrome.textMuted),
              ),
              onSubmitted: (_) => setState(() {}),
            ),
          ),
        ),
        SizedBox(
          width: 240,
          child: glassField(
            child: TextField(
              controller: _globalOwnerCtrl,
              style: TextStyle(color: chrome.textPrimary, fontSize: 12),
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                hintText: 'Owner (optional)',
                hintStyle: TextStyle(color: chrome.textMuted),
              ),
              onSubmitted: (_) => setState(() {}),
            ),
          ),
        ),
        SizedBox(
          width: 260,
          child: glassField(
            child: TextField(
              controller: _globalProposalTypeCtrl,
              style: TextStyle(color: chrome.textPrimary, fontSize: 12),
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                hintText: 'Proposal type (optional)',
                hintStyle: TextStyle(color: chrome.textMuted),
              ),
              onSubmitted: (_) => setState(() {}),
            ),
          ),
        ),
        SizedBox(
          width: 220,
          child: glassField(
            child: TextField(
              controller: _globalRegionCtrl,
              style: TextStyle(color: chrome.textPrimary, fontSize: 12),
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                hintText: 'Region (optional)',
                hintStyle: TextStyle(color: chrome.textMuted),
              ),
              onSubmitted: (_) => setState(() {}),
            ),
          ),
        ),
        glassField(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: Icon(Icons.clear, color: chrome.textPrimary, size: 18),
                tooltip: 'Clear filters',
                onPressed: () {
                  setState(() {
                    _globalClientCtrl.clear();
                    _globalRegionCtrl.clear();
                    _globalOwnerCtrl.clear();
                    _globalProposalTypeCtrl.clear();
                    _cycleTimeRefreshTick++;
                  });
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  double? _percentChange(double previous, double current) {
    if (previous == 0) {
      if (current == 0) return 0;
      return null;
    }
    return ((current - previous) / previous) * 100;
  }

  String _formatCurrency(double value, {bool compact = false}) {
    if (value == 0) return '${_currencySymbol}0';
    return compact
        ? _compactCurrencyFormatter.format(value)
        : _currencyFormatter.format(value);
  }

  String _formatChange(double? percent) {
    if (percent == null) return '--';
    final formatted = percent.abs() >= 1000
        ? percent.toStringAsFixed(0)
        : percent.toStringAsFixed(1);
    return percent >= 0 ? '+$formatted%' : '$formatted%';
  }

  bool _isPositiveChange(double? percent) {
    if (percent == null) return true;
    return percent >= 0;
  }

  bool _isWinStatus(String status) {
    return status.contains('signed') || status.contains('won');
  }

  bool _isLossStatus(String status) {
    return status.contains('lost') || status.contains('declined');
  }

  bool _isClosedStatus(String status) {
    return _isWinStatus(status) || _isLossStatus(status);
  }

  double _probabilityForStatus(String status) {
    if (_isWinStatus(status)) return 1;
    if (_isLossStatus(status)) return 0;
    if (status.contains('sent to client')) return 0.8;
    if (status.contains('pending ceo') || status.contains('in review')) {
      return 0.6;
    }
    if (status.contains('draft')) return 0.3;
    return 0.5;
  }

  Color _statusColor(String status) {
    if (_isWinStatus(status)) return PremiumTheme.success;
    if (_isLossStatus(status)) return PremiumTheme.error;
    if (status.contains('sent to client')) return PremiumTheme.info;
    if (status.contains('pending') || status.contains('review')) {
      return PremiumTheme.warning;
    }
    return PremiumTheme.orange;
  }

  String _formatStatusLabel(String status) {
    if (status.isEmpty) return 'Draft';
    final parts = status
        .replaceAll('_', ' ')
        .split(' ')
        .where((part) => part.isNotEmpty)
        .map((part) => part[0].toUpperCase() + part.substring(1).toLowerCase())
        .toList();
    return parts.isEmpty ? 'Draft' : parts.join(' ');
  }

  bool _isAdminUser() {
    final user =
        AuthService.currentUser ?? context.read<AppState>().currentUser;
    final backendRole = (user?['role'] ?? '').toString().toLowerCase().trim();
    // Treat only true admin roles as admin for routing/sidebar behavior.
    return backendRole == 'admin' ||
        backendRole == 'ceo' ||
        backendRole == 'approver';
  }

  String? _pipelineStageForStatus(String statusLower) {
    final s = statusLower.trim();
    if (s.isEmpty || s.contains('draft')) return 'Draft';
    if (s.contains('signed') || s.contains('won')) return 'Signed';
    if (s.contains('sent to client') || s.contains('released'))
      return 'Released';
    if (s.contains('review') ||
        (s.contains('pending') && s.contains('ceo')) ||
        s.contains('approved')) {
      return 'In Review';
    }
    return null;
  }

  Map<String, int> _calculatePipelineCounts(List<dynamic> rawProposals) {
    final counts = <String, int>{
      'Draft': 0,
      'In Review': 0,
      'Released': 0,
      'Signed': 0,
    };

    for (final proposal in rawProposals) {
      Map<String, dynamic>? p;
      if (proposal is Map<String, dynamic>) {
        p = proposal;
      } else if (proposal is Map) {
        try {
          p = proposal.cast<String, dynamic>();
        } catch (_) {
          p = null;
        }
      }
      if (p == null) continue;

      final statusLower = (p['status'] ?? '').toString().toLowerCase();
      final stage = _pipelineStageForStatus(statusLower);
      if (stage == null) continue;
      counts[stage] = (counts[stage] ?? 0) + 1;
    }
    return counts;
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final chrome = context.watch<ManagerThemeController>().chrome;
    final sidebarCollapsed = app.isAdminSidebarCollapsed;
    final filtered = _filterProposals(app.proposals);
    final analytics = _calculateAnalytics(filtered);
    final metrics = _buildMetricCards(analytics);
    final isAdminUser = _effectiveIsAdmin;

    _calculatePipelineCounts(filtered);

    // Resolve a friendly greeting from the current user (Figma: "Hello, Name Surname").
    final user = app.currentUser ?? const <String, dynamic>{};
    final greetingName = (() {
      final full = (user['full_name'] ??
              user['fullName'] ??
              user['name'] ??
              user['displayName'] ??
              '')
          .toString()
          .trim();
      if (full.isNotEmpty) return full;
      final email = (user['email'] ?? '').toString();
      if (email.contains('@')) return email.split('@').first;
      return 'there';
    })();

    final pipelineCounts = _calculatePipelineCounts(filtered);
    final notificationCount = _unreadNotificationCount(app, messagesOnly: false);

    final assetByMetric = <String, String>{
      'Total Revenue': _icRevenue,
      'Active Proposals': _icActive,
      'Conversion Rate': _icConversion,
      'Avg Deal Size': _icAvgDeal,
    };

    final analyticsContent = CustomScrollbar(
      controller: _scrollController,
      child: SingleChildScrollView(
        controller: _scrollController,
        padding: const EdgeInsets.only(right: 24),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ──────────────── Figma header ────────────────
              LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxWidth < 1100;
                  final headerActions = Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      _buildGlassDropdown(),
                      _figmaPrimaryButton(
                        _isRefreshing ? 'Refreshing' : 'Refresh',
                        Icons.refresh,
                        _runManualRefresh,
                        loading: _isRefreshing,
                      ),
                      _figmaSecondaryButton(
                        'Export Data',
                        Icons.download_rounded,
                        _showExportDialog,
                      ),
                      _buildHeaderIconButton(
                        assetPath: _icHeaderMessages,
                        tooltip: 'Messages',
                        badge:
                            _unreadNotificationCount(app, messagesOnly: true),
                        onTap: () async {
                          await app.fetchNotifications();
                          if (!mounted) return;
                          _showNotificationsSheet(app, messagesOnly: true);
                        },
                      ),
                      _buildHeaderIconButton(
                        assetPath: _icHeaderNotifications,
                        tooltip: 'Notifications',
                        badge:
                            _unreadNotificationCount(app, messagesOnly: false),
                        onTap: () async {
                          await app.fetchNotifications();
                          if (!mounted) return;
                          _showNotificationsSheet(app, messagesOnly: false);
                        },
                      ),
                    ],
                  );

                  final titleBlock = RichText(
                    text: TextSpan(
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                      ),
                      children: [
                        const TextSpan(text: 'Admin Analytics  '),
                        TextSpan(
                          text: 'Hello, ',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.55),
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        TextSpan(
                          text: greetingName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  );

                  if (compact) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        titleBlock,
                        const SizedBox(height: 16),
                        headerActions,
                      ],
                    );
                  }

                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Flexible(child: titleBlock),
                      headerActions,
                    ],
                  );
                },
              ),
              const SizedBox(height: 28),
              _buildGlobalFilterBar(),
              const SizedBox(height: 24),

              // ──────────────── Top KPI row ────────────────
              LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxWidth < 900;
                  if (compact) {
                    return Column(
                      children: [
                        for (int i = 0; i < metrics.length; i++) ...[
                          _buildGlassMetricCard(
                            metrics[i].title,
                            metrics[i].value,
                            metrics[i].change,
                            metrics[i].isPositive,
                            metrics[i].subtitle,
                            iconAsset: assetByMetric[metrics[i].title],
                          ),
                          if (i != metrics.length - 1)
                            const SizedBox(height: 20),
                        ],
                      ],
                    );
                  }

                  return Row(
                    children: [
                      for (int i = 0; i < metrics.length; i++) ...[
                        Expanded(
                          child: _buildGlassMetricCard(
                            metrics[i].title,
                            metrics[i].value,
                            metrics[i].change,
                            metrics[i].isPositive,
                            metrics[i].subtitle,
                            iconAsset: assetByMetric[metrics[i].title],
                          ),
                        ),
                        if (i != metrics.length - 1)
                          const SizedBox(width: 20),
                      ],
                    ],
                  );
                },
              ),
              const SizedBox(height: 28),

              // ──────────────── Revenue Analytics ────────────────
              _buildGlassChartCard(
                'Revenue Analytics',
                _buildRevenueChart(analytics.monthlyPoints),
                height: 320,
                iconAsset: _icRevenuePanel,
                subtitle: 'Additional description if required.',
              ),
              const SizedBox(height: 28),

              // ──────────────── Proposal Pipeline View ────────────────
              _buildGlassChartCard(
                'Proposal Pipeline View',
                _buildPipelinePillStrip(pipelineCounts),
                height: 80,
                iconAsset: _icPipeline,
                subtitle:
                    'Live usage for AI Assistant + Risk Gate (last 30 days, auto-refresh).',
              ),
              const SizedBox(height: 28),

              // ──────────────── Secondary KPI strip (5) ────────────────
              _buildSecondaryKpiRow(analytics),
              const SizedBox(height: 28),

              // ──────────────── Readiness / 30-Day Trend ────────────────
              LayoutBuilder(
                builder: (context, constraints) {
                  final wide = constraints.maxWidth >= 1100;
                  // Same height for both cards (Figma parity).
                  const _trendCardHeight = 320.0;
                  final pipelineCard = _buildGlassChartCard(
                    'Readiness Breakdown',
                    _buildReadinessBreakdownDonut(analytics),
                    height: _trendCardHeight,
                    iconAsset: _icReadiness,
                    subtitle: 'Proposals passing vs below threshold.',
                  );

                  final completionCard = _buildGlassChartCard(
                    '30-Day Trend',
                    _buildThirtyDayTrendChart(app.proposals),
                    height: _trendCardHeight,
                    iconAsset: _ic30DayTrend,
                    subtitle: 'Daily creation vs sign-off volume.',
                  );

                  if (wide) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: pipelineCard),
                        const SizedBox(width: 20),
                        Expanded(child: completionCard),
                      ],
                    );
                  }
                  return Column(
                    children: [
                      pipelineCard,
                      const SizedBox(height: 20),
                      completionCard,
                    ],
                  );
                },
              ),
              const SizedBox(height: 28),

              // ──────────────── Proposal Readiness / Status ────────────────
              LayoutBuilder(
                builder: (context, constraints) {
                  final wide = constraints.maxWidth >= 1100;
                  final readinessCard = _buildGlassChartCard(
                    'Proposal Readiness',
                    Center(
                      child: Text(
                        analytics.recentProposals.isEmpty
                            ? 'No data to display.'
                            : '${analytics.recentProposals.length} low-scoring proposals',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.55),
                        ),
                      ),
                    ),
                    height: 220,
                    iconAsset: _icReadiness,
                    subtitle: 'Low-scoring proposals - tap to fix missing sections.',
                  );
                  final statusCard = _buildGlassChartCard(
                    'Proposal Status',
                    _buildProposalStatusChart(analytics.statusCounts),
                    height: 220,
                    iconAsset: _icProposalStatus,
                    subtitle: 'Additional description if required.',
                  );
                  if (wide) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: readinessCard),
                        const SizedBox(width: 20),
                        Expanded(child: statusCard),
                      ],
                    );
                  }
                  return Column(
                    children: [
                      readinessCard,
                      const SizedBox(height: 20),
                      statusCard,
                    ],
                  );
                },
              ),
              const SizedBox(height: 28),

              // ──────────────── Win Rate / Risk Gate ────────────────
              LayoutBuilder(
                builder: (context, constraints) {
                  final wide = constraints.maxWidth >= 1100;
                  final winRate = _buildGlassChartCard(
                    'Win Rate',
                    _buildWinRatePieChart(
                      analytics.winRate,
                      analytics.lossRate,
                    ),
                    height: 280,
                    iconAsset: _icWinRate,
                    subtitle: 'Additional description if required.',
                  );
                  final riskGate = _buildGlassChartCard(
                    'Risk Gate',
                    FutureBuilder<Map<String, dynamic>?>(
                      key: ValueKey(
                        'risk_gate_${_cycleTimeRefreshTick}_${_selectedPeriod}_${_globalClientCtrl.text}_${_globalOwnerCtrl.text}_${_globalProposalTypeCtrl.text}',
                      ),
                      future: _fetchRiskGateSummary(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }
                        if (snapshot.hasError) {
                          return Center(
                            child: Text(
                              'Failed to load risk gate summary.',
                              style: PremiumTheme.bodyMedium
                                  .copyWith(color: Colors.white70),
                            ),
                          );
                        }
                        return _buildRiskGateIndicator(snapshot.data);
                      },
                    ),
                    height: 280,
                    iconAsset: _icRiskGate,
                    subtitle:
                        'Coverage of proposals analysed (latest run per proposal).',
                  );
                  if (wide) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: winRate),
                        const SizedBox(width: 20),
                        Expanded(child: riskGate),
                      ],
                    );
                  }
                  return Column(
                    children: [
                      winRate,
                      const SizedBox(height: 20),
                      riskGate,
                    ],
                  );
                },
              ),
              if (_canViewAiUsage()) ...[
                const SizedBox(height: 28),
                _buildGlassChartCard(
                  'AI Usage',
                  FutureBuilder<Map<String, dynamic>?>(
                    key: ValueKey(
                      'ai_usage_${_cycleTimeRefreshTick}_${_selectedPeriod}',
                    ),
                    future: _fetchAiUsageAnalytics(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (snapshot.hasError) {
                        return Center(
                          child: Text(
                            'Failed to load AI usage analytics.',
                            style: PremiumTheme.bodyMedium
                                .copyWith(color: Colors.white70),
                          ),
                        );
                      }
                      return _buildAiUsageCard(snapshot.data);
                    },
                  ),
                  height: 360,
                  iconAsset: _icAiUsage,
                  subtitle:
                      'Live usage for AI Assistant + Risk Gate (last 30 days, auto-refresh).',
                ),
              ],
              const SizedBox(height: 28),

              // ──────────────── Collaboration / Engagement ────────────────
              LayoutBuilder(
                builder: (context, constraints) {
                  final wide = constraints.maxWidth >= 1100;
                  final collab = _buildGlassChartCard(
                    'Collaboration Load',
                    FutureBuilder<Map<String, dynamic>?>(
                      key: ValueKey(
                        'collab_${_cycleTimeRefreshTick}_${_selectedPeriod}_${_globalClientCtrl.text}_${_globalOwnerCtrl.text}_${_globalProposalTypeCtrl.text}',
                      ),
                      future: _fetchCollaborationLoad(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }
                        if (snapshot.hasError) {
                          return Center(
                            child: Text(
                              'Failed to load collaboration metrics.',
                              style: PremiumTheme.bodyMedium
                                  .copyWith(color: Colors.white70),
                            ),
                          );
                        }
                        return _buildCollaborationLoadCard(snapshot.data);
                      },
                    ),
                    height: 360,
                    iconAsset: _icCollab,
                    subtitle: 'Top active proposals',
                  );
                  final engagement = _buildGlassChartCard(
                    'Client Engagement',
                    FutureBuilder<Map<String, dynamic>?>(
                      key: ValueKey(
                        'engagement_${_cycleTimeRefreshTick}_${_selectedPeriod}_${_globalClientCtrl.text}_${_globalOwnerCtrl.text}_${_globalProposalTypeCtrl.text}_${_globalRegionCtrl.text}',
                      ),
                      future: _fetchClientEngagement(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }
                        if (snapshot.hasError) {
                          return Center(
                            child: Text(
                              'Failed to load client engagement.',
                              style: PremiumTheme.bodyMedium
                                  .copyWith(color: Colors.white70),
                            ),
                          );
                        }
                        return _buildClientEngagementCard(snapshot.data);
                      },
                    ),
                    height: 360,
                    iconAsset: _icEngagement,
                    subtitle: 'Top active proposals',
                  );
                  if (wide) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: collab),
                        const SizedBox(width: 20),
                        Expanded(child: engagement),
                      ],
                    );
                  }
                  return Column(
                    children: [
                      collab,
                      const SizedBox(height: 20),
                      engagement,
                    ],
                  );
                },
              ),
              const SizedBox(height: 28),

              // ──────────────── Cycle Time Metrics ────────────────
              _buildGlassChartCard(
                'Cycle Time Metrics',
                _buildCycleTimeContent(null),
                height: 360,
                iconAsset: _icCycleTime,
                subtitle: 'Additional description if required.',
              ),
              const SizedBox(height: 28),

              // ──────────────── Proposals Overview (table) ────────────────
              _buildProposalsOverviewTable(
                analytics.recentProposals,
                notificationCount,
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );

    final body = Row(
      children: [
        if (isAdminUser)
          AdminSidebar(
            isCollapsed: sidebarCollapsed,
            currentPage: 'Analytics',
            managerChrome: chrome,
            onToggle: app.toggleAdminSidebar,
            onSelect: (label) {
              if (label == 'AI Configuration') {
                Navigator.pushNamed(context, '/ai-configuration');
                return;
              }
              app.setAdminNavLabel(label);
              _navigatePage(label);
            },
          )
        else
          AppSideNav(
            isCollapsed: app.isSidebarCollapsed,
            currentLabel: 'Analytics (My Pipeline)',
            isAdmin: false,
            onToggle: app.toggleSidebar,
            onSelect: _navigatePage,
          ),
        Expanded(child: analyticsContent),
      ],
    );

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: ManagerPageBackground(child: body),
    );
  }

  Widget _buildGlassDropdown() {
    final inner = Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 4),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: _selectedPeriod,
            dropdownColor: const Color(0xFF1E1E22),
            style: const TextStyle(color: Colors.white),
            icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white),
            items: const [
              'Last 7 Days',
              'Last 30 Days',
              'Last 90 Days',
              'This Year'
            ].map((String value) {
              return DropdownMenuItem<String>(
                value: value,
                child: Text(value,
                    style: const TextStyle(color: Colors.white)),
              );
            }).toList(),
            onChanged: (String? newValue) {
              setState(() {
                _selectedPeriod = newValue!;
                _cycleTimeRefreshTick++;
              });
            },
          ),
        ),
      ),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: inner,
      ),
    );
  }

  /// Solid red action button used in the Figma header (Refresh).
  /// When `loading` is true the icon is replaced by a spinner and taps
  /// are ignored to prevent overlapping refresh calls.
  Widget _figmaPrimaryButton(
    String label,
    IconData icon,
    VoidCallback onPressed, {
    bool loading = false,
  }) {
    return InkWell(
      onTap: loading ? null : onPressed,
      borderRadius: BorderRadius.circular(999),
      child: Opacity(
        opacity: loading ? 0.85 : 1.0,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFEF4444), Color(0xFFB91C1C)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(999),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFEF4444).withValues(alpha: 0.35),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              loading
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Icon(icon, color: Colors.white, size: 16),
              const SizedBox(width: 8),
              Text(
                label.toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Compact pill button used in each Proposals Overview row (the Figma "VIEW"
  /// affordance). Sized so it fits in the table's trailing column without the
  /// horizontal-overflow stripe pattern.
  Widget _figmaTableViewButton(VoidCallback onPressed) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.visibility_outlined, color: Colors.white, size: 14),
            SizedBox(width: 6),
            Text(
              'VIEW',
              style: TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.0,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Outlined gray action button used in the Figma header (Export Data).
  Widget _figmaSecondaryButton(
      String label, IconData icon, VoidCallback onPressed) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 16),
            const SizedBox(width: 8),
            Text(
              label.toUpperCase(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Five horizontal pill chips for the Proposal Pipeline View
  /// (Draft / In Review / Released / Signed / Archived) with live counts.
  Widget _buildPipelinePillStrip(Map<String, int> counts) {
    final items = <_PipelinePill>[
      _PipelinePill('Draft', counts['Draft'] ?? 0),
      _PipelinePill('In Review', counts['In Review'] ?? 0),
      _PipelinePill('Released', counts['Released'] ?? 0),
      _PipelinePill('Signed', counts['Signed'] ?? 0),
      _PipelinePill('Archived', counts['Archived'] ?? 0),
    ];

    Widget pill(_PipelinePill p) {
      final active =
          (_pipelineStageFilter ?? '').toLowerCase() == p.label.toLowerCase();
      return InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: () {
          setState(() {
            _pipelineStageFilter = active ? null : p.label;
            _cycleTimeRefreshTick++;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: active
                ? const Color(0xFFEF4444).withValues(alpha: 0.16)
                : Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: active
                  ? const Color(0xFFEF4444).withValues(alpha: 0.55)
                  : Colors.white.withValues(alpha: 0.18),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                p.label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  p.count.toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (int i = 0; i < items.length; i++) ...[
            pill(items[i]),
            if (i != items.length - 1) const SizedBox(width: 14),
          ],
        ],
      ),
    );
  }

  /// Secondary KPI strip from the Figma frame:
  /// Proposals (%) / Passing / Completion Rate / Sign-Off Rate / Average Score.
  Widget _buildSecondaryKpiRow(_AnalyticsSnapshot analytics) {
    int signedCount = 0;
    int completedCount = 0;
    int reviewCount = 0;
    for (final e in analytics.statusCounts.entries) {
      final s = e.key.toLowerCase();
      if (s.contains('signed')) signedCount += e.value;
      if (s.contains('signed') ||
          s.contains('approved') ||
          s.contains('sent')) {
        completedCount += e.value;
      }
      if (s.contains('review') || s.contains('approval')) {
        reviewCount += e.value;
      }
    }
    final passing = analytics.totalProposals > 0
        ? analytics.totalProposals - reviewCount
        : 0;
    final completionRate = completedCount;
    final signOffRate = signedCount;
    final avgScore = analytics.totalProposals == 0
        ? 0
        : ((analytics.winRate / 10).clamp(0, 10)).toInt();

    final tiles = <_SmallKpi>[
      _SmallKpi(
        title: 'Proposals',
        subtitle: 'Total Proposals.',
        value: '${analytics.winRate.toStringAsFixed(0)}%',
        iconAsset: _icProposals,
      ),
      _SmallKpi(
        title: 'Passing',
        subtitle: 'Readiness Checks.',
        value: passing.toString(),
        iconAsset: _icPassing,
      ),
      _SmallKpi(
        title: 'Completion Rate',
        subtitle: 'Pass Threshold.',
        value: completionRate.toString(),
        iconAsset: _icCompletion,
      ),
      _SmallKpi(
        title: 'Sign-Off Rate',
        subtitle: 'Signed / Approved.',
        value: signOffRate.toString(),
        iconAsset: _icSignOff,
      ),
      _SmallKpi(
        title: 'Average Score',
        subtitle: 'Readiness Score.',
        value: avgScore.toString(),
        iconAsset: _icAvgScore,
      ),
    ];

    Widget tileCard(_SmallKpi t) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0x24FFFFFF),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    t.subtitle,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    t.value,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            _panelIcon(t.iconAsset, size: _smallKpiIconSize),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 1100;
        if (compact) {
          return Column(
            children: [
              for (int i = 0; i < tiles.length; i++) ...[
                tileCard(tiles[i]),
                if (i != tiles.length - 1) const SizedBox(height: 12),
              ],
            ],
          );
        }
        return Row(
          children: [
            for (int i = 0; i < tiles.length; i++) ...[
              Expanded(child: tileCard(tiles[i])),
              if (i != tiles.length - 1) const SizedBox(width: 14),
            ],
          ],
        );
      },
    );
  }

  /// Bottom Figma "Proposals Overview" table card with status pills + view action.
  Widget _buildProposalsOverviewTable(
    List<_ProposalPerformanceRow> rows,
    int notifications,
  ) {
    Color pillColor(String status) {
      final s = status.toLowerCase();
      if (s.contains('sent for approval') || s.contains('sent')) {
        return const Color(0xFF22C55E);
      }
      if (s.contains('await') || s.contains('signature')) {
        return const Color(0xFF3B82F6);
      }
      if (s.contains('release')) return const Color(0xFFF59E0B);
      if (s.contains('signed')) return const Color(0xFF22C55E);
      if (s.contains('draft')) return const Color(0xFF8B5CF6);
      if (s.contains('lost') ||
          s.contains('reject') ||
          s.contains('declined')) {
        return const Color(0xFFEF4444);
      }
      return const Color(0xFF6B7280);
    }

    Widget statusPill(String status) {
      final color = pillColor(status);
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          status,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    }

    String fmtUpdated(DateTime? dt) {
      if (dt == null) return 'Last Modified: --';
      final today = DateTime.now();
      final isToday = dt.year == today.year &&
          dt.month == today.month &&
          dt.day == today.day;
      final t = DateFormat('HH:mm').format(dt);
      if (isToday) return 'Last Modified: Today, $t';
      return 'Last Modified: ${DateFormat('d MMM, HH:mm').format(dt)}';
    }

    Widget header() {
      return Row(
        children: [
          _panelIcon(_icOverview, size: _panelIconSize),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Proposals Overview',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  "Manage all your business proposals & SOW's.",
                  style: TextStyle(color: Color(0xCCFFFFFF), fontSize: 12),
                ),
              ],
            ),
          ),
          _buildGlassDropdown(),
          const SizedBox(width: 12),
          _buildHeaderIconButton(
            assetPath: _icHeaderNotifications,
            tooltip: 'Notifications',
            badge: notifications,
            onTap: () async {
              final app = context.read<AppState>();
              await app.fetchNotifications();
              if (!mounted) return;
              _showNotificationsSheet(app, messagesOnly: false);
            },
          ),
        ],
      );
    }

    Widget tableHeader() {
      return Padding(
        padding:
            const EdgeInsets.symmetric(horizontal: 4).copyWith(bottom: 12),
        child: Row(
          children: [
            const Expanded(
              flex: 4,
              child: Text(
                'Proposal Title',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                'Value',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                'Status',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Expanded(
              flex: 3,
              child: Text(
                'Days',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 110),
          ],
        ),
      );
    }

    Widget rowTile(_ProposalPerformanceRow r) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              flex: 4,
              child: Row(
                children: [
                  _panelIcon(_icOverview, size: 36),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      r.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                r.valueLabel,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Expanded(flex: 2, child: statusPill(r.status)),
            Expanded(
              flex: 3,
              child: Text(
                fmtUpdated(r.updatedAt),
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 12,
                ),
              ),
            ),
            SizedBox(
              width: 110,
              child: Align(
                alignment: Alignment.centerRight,
                child: _figmaTableViewButton(() {
                  Navigator.pushNamed(
                    context,
                    '/proposal_review',
                    arguments: {'title': r.title},
                  );
                }),
              ),
            ),
          ],
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: const Color(0x24FFFFFF),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              header(),
              const SizedBox(height: 18),
              Container(
                height: 1,
                color: Colors.white.withValues(alpha: 0.06),
              ),
              const SizedBox(height: 14),
              tableHeader(),
              if (rows.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  child: Center(
                    child: Text(
                      'No proposals to display.',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.55),
                      ),
                    ),
                  ),
                )
              else
                for (final r in rows) rowTile(r),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────── Header bell / messages ───────────────────────
  // Mirrors the manager dashboard pattern (`approver_dashboard_page.dart`)
  // so admin gets a single, real-time notification flow with admin-aware tap
  // routing — no cross/duplicate functionality.

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
            right: 4,
            top: 4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: const BoxDecoration(
                color: Color(0xFFC10D00),
                borderRadius: BorderRadius.all(Radius.circular(10)),
              ),
              child: Text(
                (badge ?? 0) > 99 ? '99+' : '${badge ?? 0}',
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
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          return decoded.cast<String, dynamic>();
        }
      } catch (_) {/* swallow malformed metadata */}
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
      if (trimmed.isEmpty || trimmed.toLowerCase() == 'null') return null;
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
      } catch (_) {/* swallow; UI will reconcile on next fetch */}
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
    if (sectionIndex != null) args['initialSectionIndex'] = sectionIndex;
    if (commentId != null) args['initialCommentId'] = commentId;

    Navigator.of(context).pushNamed('/blank-document', arguments: args);
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
                  borderRadius:
                      BorderRadius.vertical(top: Radius.circular(10)),
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 16),
                      decoration: const BoxDecoration(
                        color: Color(0xFF2C3E50),
                        borderRadius:
                            BorderRadius.vertical(top: Radius.circular(10)),
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
                                  onPressed: markAllInSheet,
                                  style: TextButton.styleFrom(
                                    foregroundColor: Colors.white,
                                  ),
                                  child: const Text('Mark all read',
                                      style: TextStyle(fontSize: 12)),
                                ),
                              TextButton(
                                onPressed: notifications.isEmpty
                                    ? null
                                    : deleteAllInSheet,
                                style: TextButton.styleFrom(
                                  foregroundColor: Colors.red.shade200,
                                ),
                                child: const Text('Delete all',
                                    style: TextStyle(fontSize: 12)),
                              ),
                              IconButton(
                                icon: const Icon(Icons.close,
                                    color: Colors.white),
                                onPressed: () =>
                                    Navigator.of(context).pop(),
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
                              vertical: 12, horizontal: 16),
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
                                      padding:
                                          const EdgeInsets.only(top: 4),
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
                                      padding:
                                          const EdgeInsets.only(top: 4),
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
                                      padding:
                                          const EdgeInsets.only(top: 4),
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
                              trailing:
                                  !isRead && notificationId != null
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

  Widget _buildGlassMetricCard(
    String title,
    String value,
    String change,
    bool isPositive,
    String subtitle, {
    String? iconAsset,
    String? subtitleOverride,
  }) {
    const radius = 16.0;
    final decoration = BoxDecoration(
      color: const Color(0x24FFFFFF),
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.35),
          blurRadius: 18,
          offset: const Offset(0, 6),
        ),
      ],
    );

    final body = Container(
      padding: const EdgeInsets.all(20),
      decoration: decoration,
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
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitleOverride ?? 'Current vs last month.',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.55),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              if (iconAsset != null) _panelIcon(iconAsset, size: _kpiIconSize),
            ],
          ),
          const SizedBox(height: 22),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 30,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(
                isPositive ? Icons.trending_up : Icons.trending_down,
                size: 14,
                color:
                    isPositive ? PremiumTheme.success : PremiumTheme.error,
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  change,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: isPositive
                        ? PremiumTheme.success
                        : PremiumTheme.error,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.white.withValues(alpha: 0.45),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: body,
      ),
    );
  }

  /// Renders a Figma analytics PNG at full quality with no tinting. Used for
  /// every panel header / KPI accent icon. The new icons in
  /// `assets/images/admin_analytics_page/` already contain the red disc and
  /// white glyph baked in.
  Widget _panelIcon(String asset, {double size = _panelIconSize}) {
    return SizedBox(
      width: size,
      height: size,
      child: Image.asset(
        asset,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
        cacheWidth: (size * 4).round(),
        cacheHeight: (size * 4).round(),
        errorBuilder: (_, __, ___) =>
            const Icon(Icons.broken_image, color: Colors.redAccent, size: 24),
      ),
    );
  }

  Widget _buildGlassChartCard(
    String title,
    Widget chart, {
    double height = 300,
    String? iconAsset,
    String? subtitle,
    Widget? trailing,
  }) {
    const radius = 16.0;
    final decoration = BoxDecoration(
      color: const Color(0x24FFFFFF),
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.35),
          blurRadius: 18,
          offset: const Offset(0, 6),
        ),
      ],
    );

    final headerRow = Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (iconAsset != null) ...[
          _panelIcon(iconAsset, size: _panelIconSize),
          const SizedBox(width: 14),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if ((subtitle ?? '').isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.55),
                    fontSize: 12,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (trailing != null) trailing,
      ],
    );

    final body = Container(
      padding: const EdgeInsets.all(22),
      decoration: decoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          headerRow,
          const SizedBox(height: 14),
          Container(
            height: 1,
            color: Colors.white.withValues(alpha: 0.06),
          ),
          const SizedBox(height: 18),
          SizedBox(height: height, child: chart),
        ],
      ),
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: body,
      ),
    );
  }

  Widget _buildRevenueChart(List<_MonthlyPoint> points) {
    if (points.isEmpty) {
      return const Center(
        child: Text(
          'No revenue data yet',
          style: TextStyle(color: Colors.white70),
        ),
      );
    }
    final maxValue = points.fold<double>(0,
        (previousValue, element) => math.max(previousValue, element.revenue));
    final yMax = maxValue == 0 ? 1.0 : maxValue * 1.2;
    final spots = <FlSpot>[
      for (int i = 0; i < points.length; i++)
        FlSpot(i.toDouble(), points[i].revenue)
    ];
    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: yMax / 4,
          getDrawingHorizontalLine: (value) => FlLine(
            color: const Color(0xFF2D3748),
            strokeWidth: 1,
          ),
        ),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 50,
              getTitlesWidget: (value, meta) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: Text(
                    _compactCurrencyFormatter.format(value),
                    style: const TextStyle(
                      color: Color(0xFF6B7280),
                      fontSize: 12,
                    ),
                  ),
                );
              },
            ),
          ),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              getTitlesWidget: (value, meta) {
                if (value % 1 != 0) {
                  return const SizedBox.shrink();
                }
                final index = value.toInt();
                if (index >= 0 && index < points.length) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      points[index].label,
                      style: const TextStyle(
                        color: Color(0xFF6B7280),
                        fontSize: 12,
                      ),
                    ),
                  );
                }
                return const Text('');
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        minX: 0,
        maxX: (points.length - 1).toDouble(),
        minY: 0,
        maxY: yMax,
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: const Color(0xFF06B6D4),
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, index) {
                return FlDotCirclePainter(
                  radius: 5,
                  color: const Color(0xFF06B6D4),
                  strokeWidth: 2,
                  strokeColor: Colors.black.withValues(alpha: 0.3),
                );
              },
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  const Color(0xFF06B6D4).withValues(alpha: 0.3),
                  const Color(0xFF06B6D4).withValues(alpha: 0.0),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 30-day daily trend line chart — Created (green) vs Signed (orange).
  /// Buckets the supplied proposal list into 30 daily buckets ending today
  /// and renders two real-data line series with proper X/Y axes.
  Widget _buildThirtyDayTrendChart(List<dynamic> proposals) {
    const int days = 30;
    final today = DateTime.now();
    final startDay = DateTime(today.year, today.month, today.day)
        .subtract(const Duration(days: days - 1));

    final created = List<int>.filled(days, 0);
    final signed = List<int>.filled(days, 0);

    for (final raw in proposals) {
      if (raw is! Map) continue;
      final p = raw;
      final createdAt =
          _parseDate(p['created_at'] ?? p['createdAt']);
      if (createdAt != null) {
        final d = DateTime(createdAt.year, createdAt.month, createdAt.day);
        final idx = d.difference(startDay).inDays;
        if (idx >= 0 && idx < days) {
          created[idx] = created[idx] + 1;
        }
      }

      final status = (p['status'] ?? '').toString().toLowerCase();
      if (_isWinStatus(status)) {
        final updatedAt =
            _parseDate(p['updated_at'] ?? p['updatedAt']) ?? createdAt;
        if (updatedAt != null) {
          final d = DateTime(updatedAt.year, updatedAt.month, updatedAt.day);
          final idx = d.difference(startDay).inDays;
          if (idx >= 0 && idx < days) {
            signed[idx] = signed[idx] + 1;
          }
        }
      }
    }

    final createdSpots = <FlSpot>[
      for (int i = 0; i < days; i++) FlSpot(i.toDouble(), created[i].toDouble())
    ];
    final signedSpots = <FlSpot>[
      for (int i = 0; i < days; i++) FlSpot(i.toDouble(), signed[i].toDouble())
    ];

    final rawMax = math.max<int>(
      created.fold<int>(0, math.max),
      signed.fold<int>(0, math.max),
    );
    final yMax = rawMax <= 0 ? 4.0 : (rawMax * 1.25).ceilToDouble();
    final yInterval = (yMax / 4).ceilToDouble().clamp(1.0, double.infinity);

    String monthAbbr(int m) {
      const names = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ];
      return names[(m - 1).clamp(0, 11)];
    }

    Widget legendDot(Color c, String label) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: c,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            legendDot(const Color(0xFF22C55E), 'Created'),
            const SizedBox(width: 16),
            legendDot(const Color(0xFFF59E0B), 'Signed'),
          ],
        ),
        const SizedBox(height: 12),
        Expanded(
          child: LineChart(
            LineChartData(
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: yInterval,
                getDrawingHorizontalLine: (value) => FlLine(
                  color: Colors.white.withValues(alpha: 0.08),
                  strokeWidth: 1,
                ),
              ),
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 36,
                    interval: yInterval,
                    getTitlesWidget: (value, meta) {
                      if (value < 0) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(right: 6.0),
                        child: Text(
                          value.toInt().toString(),
                          style: const TextStyle(
                            color: Color(0xFF9CA3AF),
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false)),
                topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false)),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 26,
                    interval: 6,
                    getTitlesWidget: (value, meta) {
                      final i = value.toInt();
                      if (i < 0 || i >= days) return const SizedBox.shrink();
                      // Show labels at days 0, 6, 12, 18, 24, 29 (last).
                      final isLast = i == days - 1;
                      final showHere = i % 6 == 0 || isLast;
                      if (!showHere) return const SizedBox.shrink();
                      final d = startDay.add(Duration(days: i));
                      return Padding(
                        padding: const EdgeInsets.only(top: 6.0),
                        child: Text(
                          '${monthAbbr(d.month)} ${d.day}',
                          style: const TextStyle(
                            color: Color(0xFF9CA3AF),
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              borderData: FlBorderData(show: false),
              minX: 0,
              maxX: (days - 1).toDouble(),
              minY: 0,
              maxY: yMax,
              lineTouchData: LineTouchData(
                touchTooltipData: LineTouchTooltipData(
                  getTooltipColor: (_) =>
                      const Color(0xFF111827).withValues(alpha: 0.95),
                  getTooltipItems: (spots) {
                    return spots.map((s) {
                      final i = s.x.toInt().clamp(0, days - 1);
                      final d = startDay.add(Duration(days: i));
                      final label = s.bar.color == const Color(0xFF22C55E)
                          ? 'Created'
                          : 'Signed';
                      return LineTooltipItem(
                        '$label · ${monthAbbr(d.month)} ${d.day}\n${s.y.toInt()}',
                        const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      );
                    }).toList();
                  },
                ),
              ),
              lineBarsData: [
                LineChartBarData(
                  spots: createdSpots,
                  isCurved: false,
                  color: const Color(0xFF22C55E),
                  barWidth: 2.4,
                  isStrokeCapRound: true,
                  dotData: const FlDotData(show: false),
                  belowBarData: BarAreaData(show: false),
                ),
                LineChartBarData(
                  spots: signedSpots,
                  isCurved: false,
                  color: const Color(0xFFF59E0B),
                  barWidth: 2.4,
                  isStrokeCapRound: true,
                  dotData: const FlDotData(show: false),
                  belowBarData: BarAreaData(show: false),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProposalStatusChart(Map<String, int> statusCounts) {
    final statuses = [
      'Draft',
      'In Review',
      'Pending Ceo Approval',
      'Sent To Client',
      'Signed',
      'Lost',
    ];

    // Map declined statuses to "Lost"
    final normalizedCounts = <String, int>{};
    int lostCount = 0;
    for (final entry in statusCounts.entries) {
      final status = entry.key.toLowerCase();
      if (status.contains('declined') ||
          status.contains('lost') ||
          status.contains('rejected')) {
        lostCount += entry.value;
      } else {
        normalizedCounts[entry.key] = entry.value;
      }
    }
    if (lostCount > 0) {
      normalizedCounts['Lost'] = lostCount;
    }

    final bars = <BarChartGroupData>[];
    int maxCount = 0;
    for (int i = 0; i < statuses.length; i++) {
      final label = statuses[i];
      final count = normalizedCounts[label] ?? 0;
      maxCount = math.max(maxCount, count);
      bars.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: count.toDouble(),
              color: _statusColor(label.toLowerCase()),
              width: 28,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(6),
                topRight: Radius.circular(6),
              ),
            ),
          ],
        ),
      );
    }
    final maxY = math.max(maxCount.toDouble(), 5.0);
    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxY,
        barTouchData: BarTouchData(
          enabled: true,
          touchTooltipData: BarTouchTooltipData(
            tooltipPadding: const EdgeInsets.all(8),
            tooltipMargin: 8,
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              return BarTooltipItem(
                '${rod.toY.toInt()} proposals',
                const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (value, meta) {
                return Text(
                  value.toInt().toString(),
                  style: const TextStyle(
                    color: Color(0xFF6B7280),
                    fontSize: 12,
                  ),
                );
              },
            ),
          ),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 38,
              getTitlesWidget: (value, meta) {
                if (value.toInt() >= 0 && value.toInt() < statuses.length) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      statuses[value.toInt()],
                      style: const TextStyle(
                        color: Color(0xFF6B7280),
                        fontSize: 12,
                      ),
                    ),
                  );
                }
                return const Text('');
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: math.max(maxY / 4, 1.0),
          getDrawingHorizontalLine: (value) => FlLine(
            color: const Color(0xFF2D3748),
            strokeWidth: 1,
          ),
        ),
        barGroups: bars,
      ),
    );
  }

  Widget _buildWinRatePieChart(double winRate, double lossRate) {
    // All values are live (winRate/lossRate come straight from analytics).
    final pendingRate = math.max(0.0, 100 - winRate - lossRate);
    return _buildDonutWithLegend(
      slices: [
        _DonutSlice('Wins', winRate, PremiumTheme.success),
        _DonutSlice('Losses', lossRate, PremiumTheme.error),
        _DonutSlice('In Progress', pendingRate, const Color(0xFF8B5CF6)),
      ],
      centerAsset: _icInnerPie,
    );
  }

  /// Real-time Readiness Breakdown donut. Buckets the live status counts from
  /// `_calculateAnalytics(...)` into Figma-aligned legend rows.
  Widget _buildReadinessBreakdownDonut(_AnalyticsSnapshot analytics) {
    int passing = 0;
    int below = 0;
    int inReview = 0;
    int sent = 0;
    int lost = 0;
    for (final entry in analytics.statusCounts.entries) {
      final s = entry.key.toLowerCase();
      final v = entry.value;
      if (s.contains('signed') ||
          s.contains('approved') ||
          s.contains('won')) {
        passing += v;
      } else if (s.contains('draft')) {
        below += v;
      } else if (s.contains('review') || s.contains('pending')) {
        inReview += v;
      } else if (s.contains('sent') || s.contains('released')) {
        sent += v;
      } else if (s.contains('lost') ||
          s.contains('reject') ||
          s.contains('declined')) {
        lost += v;
      }
    }
    return _buildDonutWithLegend(
      slices: [
        _DonutSlice(
            'Passing', passing.toDouble(), const Color(0xFF22C55E)),
        _DonutSlice(
            'Below threshold', below.toDouble(), const Color(0xFFF59E0B)),
        _DonutSlice(
            'In Review', inReview.toDouble(), const Color(0xFF8B5CF6)),
        _DonutSlice(
            'Sent to Client', sent.toDouble(), const Color(0xFF3B82F6)),
        _DonutSlice('Lost', lost.toDouble(), const Color(0xFFEF4444)),
      ],
      centerAsset: _icInnerPie,
    );
  }

  /// Shared donut+legend renderer. Empty (all-zero) data shows a soft ring.
  Widget _buildDonutWithLegend({
    required List<_DonutSlice> slices,
    String? centerAsset,
    String legendTitle = 'Key Guide:',
  }) {
    final total = slices.fold<double>(0, (sum, s) => sum + s.value);

    final sections = <PieChartSectionData>[];
    if (total <= 0) {
      sections.add(
        PieChartSectionData(
          color: Colors.white.withValues(alpha: 0.10),
          value: 1,
          title: '',
          showTitle: false,
          radius: 32,
        ),
      );
    } else {
      for (final s in slices) {
        if (s.value <= 0) continue;
        final pct = (s.value / total) * 100;
        sections.add(
          PieChartSectionData(
            color: s.color,
            value: s.value,
            title: '${pct.toStringAsFixed(0)}%',
            radius: 36,
            titleStyle: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
            titlePositionPercentageOffset: 0.6,
          ),
        );
      }
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          flex: 5,
          child: AspectRatio(
            aspectRatio: 1,
            child: Stack(
              alignment: Alignment.center,
              children: [
                PieChart(
                  PieChartData(
                    sectionsSpace: 2,
                    centerSpaceRadius: 50,
                    sections: sections,
                    pieTouchData: PieTouchData(enabled: total > 0),
                  ),
                ),
                if (centerAsset != null)
                  IgnorePointer(
                    child: SizedBox(
                      width: 70,
                      height: 70,
                      child: Image.asset(
                        centerAsset,
                        fit: BoxFit.contain,
                        filterQuality: FilterQuality.high,
                        cacheWidth: 280,
                        cacheHeight: 280,
                        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 18),
        Expanded(
          flex: 6,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                legendTitle,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              for (final s in slices)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 44,
                        child: Text(
                          total > 0
                              ? '${((s.value / total) * 100).toStringAsFixed(0)}%'
                              : '0%',
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            color: s.color,
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Flexible(
                        child: Text(
                          s.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  // ignore: unused_element
  Widget _buildGlassPerformanceTable(List<_ProposalPerformanceRow> rows) {
    final chrome = context.watch<ManagerThemeController>().chrome;
    if (rows.isEmpty) {
      return SizedBox(
        height: 160,
        child: Center(
          child: Text(
            'No recent proposals yet',
            style: PremiumTheme.bodyMedium.copyWith(color: chrome.textSecondary),
          ),
        ),
      );
    }
    final radius = chrome.isDark ? 16.0 : 10.0;
    final outerDecoration = chrome.isDark
        ? BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.white.withValues(alpha: 0.1),
                Colors.white.withValues(alpha: 0.05),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(
              color: PremiumTheme.glassWhiteBorder,
              width: 1.5,
            ),
          )
        : chrome.floatingPanelDecoration(radius: radius, borderWidth: 1.5);

    final tableBorder = chrome.isDark
        ? const Color(0xFF2D3748)
        : chrome.divider;

    final inner = Container(
      padding: const EdgeInsets.all(24),
      decoration: outerDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Recent Proposals',
            style: PremiumTheme.titleMedium.copyWith(color: chrome.textPrimary),
          ),
          const SizedBox(height: 24),
          Table(
            columnWidths: const {
              0: FlexColumnWidth(3),
              1: FlexColumnWidth(1.5),
              2: FlexColumnWidth(1.5),
              3: FlexColumnWidth(1),
              4: FlexColumnWidth(1.5),
            },
            children: [
              TableRow(
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: tableBorder,
                      width: 2,
                    ),
                  ),
                ),
                children: [
                  _buildTableHeader('PROPOSAL', chrome),
                  _buildTableHeader('VALUE', chrome),
                  _buildTableHeader('STATUS', chrome),
                  _buildTableHeader('DAYS', chrome),
                  _buildTableHeader('WIN PROBABILITY', chrome),
                ],
              ),
              for (final proposal in rows) _buildTableRow(proposal, chrome),
            ],
          ),
        ],
      ),
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: chrome.isDark
          ? BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
              child: inner,
            )
          : inner,
    );
  }

  Widget _buildTableHeader(String text, ManagerChromeTheme chrome) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      child: Text(
        text,
        style: PremiumTheme.labelMedium.copyWith(color: chrome.textSecondary),
      ),
    );
  }

  TableRow _buildTableRow(
      _ProposalPerformanceRow data, ManagerChromeTheme chrome) {
    final rowBorder = chrome.isDark
        ? const Color(0xFF2D3748)
        : chrome.divider;
    final progressTrack = chrome.isDark
        ? const Color(0xFF2D3748)
        : Colors.black.withValues(alpha: 0.08);

    return TableRow(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: rowBorder, width: 1)),
      ),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          child: Text(
            data.title,
            style: PremiumTheme.bodyMedium.copyWith(
              color: chrome.textPrimary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          child: Text(
            data.valueLabel,
            style: PremiumTheme.bodyMedium.copyWith(color: chrome.textSecondary),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: data.statusColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
              border:
                  Border.all(color: data.statusColor.withValues(alpha: 0.4)),
            ),
            child: Text(
              data.status,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: data.statusColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          child: Text(
            data.daysOpen.toString(),
            style: PremiumTheme.bodyMedium.copyWith(color: chrome.textSecondary),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          child: Row(
            children: [
              Expanded(
                child: LinearProgressIndicator(
                  value: data.probability.clamp(0, 1),
                  backgroundColor: progressTrack,
                  valueColor: AlwaysStoppedAnimation<Color>(data.statusColor),
                  minHeight: 6,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                data.probabilityLabel,
                style: TextStyle(
                  fontSize: 13,
                  color: data.statusColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<Map<String, dynamic>?> _fetchCycleTimeAnalytics() async {
    try {
      final now = DateTime.now();
      DateTime? start;
      if (_selectedPeriod == 'Last 7 Days') {
        start = now.subtract(const Duration(days: 7));
      } else if (_selectedPeriod == 'Last 30 Days') {
        start = now.subtract(const Duration(days: 30));
      } else if (_selectedPeriod == 'Last 90 Days') {
        start = now.subtract(const Duration(days: 90));
      } else if (_selectedPeriod == 'This Year') {
        start = DateTime(now.year, 1, 1);
      }

      final fmt = DateFormat('yyyy-MM-dd');
      final startDate = start != null ? fmt.format(start) : null;
      final endDate = fmt.format(now);

      final owner = _cycleTimeOwnerCtrl.text.trim().isNotEmpty
          ? _cycleTimeOwnerCtrl.text.trim()
          : _globalOwnerCtrl.text.trim();
      final proposalType = _cycleTimeProposalTypeCtrl.text.trim().isNotEmpty
          ? _cycleTimeProposalTypeCtrl.text.trim()
          : _globalProposalTypeCtrl.text.trim();
      final currentUser = context.read<AppState>().currentUser;
      final department = (currentUser?['department'] ?? '').toString().trim();

      final data = await context.read<AppState>().getCycleTimeAnalytics(
            startDate: startDate,
            endDate: endDate,
            owner: owner.isEmpty ? null : owner,
            proposalType: proposalType.isEmpty ? null : proposalType,
            scope: _cycleTimeScope,
            department: department.isEmpty ? null : department,
          );
      return data;
    } catch (e) {
      print('Cycle time analytics exception: $e');
      return null;
    }
  }

  Widget _buildCycleTimeContent(Map<String, dynamic>? cycleTimeAnalytics) {
    _cycleTimeRefreshTick;
    final chrome = context.watch<ManagerThemeController>().chrome;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildCycleTimeFilterBar(),
        const SizedBox(height: 12),
        Expanded(
          child: FutureBuilder<Map<String, dynamic>?>(
            key: ValueKey(_cycleTimeRefreshTick),
            future: _fetchCycleTimeAnalytics(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final data = snapshot.data ?? cycleTimeAnalytics;
              final byStage = (data?['by_stage'] as List?) ?? [];

              final totalSamples = byStage.fold<int>(0, (sum, item) {
                if (item is Map) {
                  final s = item['samples'];
                  if (s is int) return sum + s;
                  if (s is num) return sum + s.toInt();
                }
                return sum;
              });

              if (byStage.isEmpty || totalSamples == 0) {
                return Center(
                  child: Text(
                    'No proposals found for these filters.',
                    style: PremiumTheme.bodyMedium.copyWith(
                      color: chrome.textSecondary,
                    ),
                  ),
                );
              }

              return _buildCycleTimeCards(byStage, data?['bottleneck'], chrome);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCycleTimeFilterBar() {
    final chrome = context.watch<ManagerThemeController>().chrome;
    Widget glassField({required Widget child}) =>
        _analyticsFilterShell(chrome, child);

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        glassField(
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _cycleTimeScope,
              dropdownColor: chrome.dropdownSurface,
              style: TextStyle(color: chrome.textPrimary),
              icon: Icon(Icons.keyboard_arrow_down, color: chrome.textPrimary),
              items: [
                if (_isAdminUser())
                  DropdownMenuItem(
                      value: 'all',
                      child: Text('All',
                          style: TextStyle(color: chrome.textPrimary))),
                DropdownMenuItem(
                    value: 'team',
                    child: Text('Team',
                        style: TextStyle(color: chrome.textPrimary))),
                DropdownMenuItem(
                    value: 'self',
                    child: Text('My',
                        style: TextStyle(color: chrome.textPrimary))),
              ],
              onChanged: (v) {
                if (v == null) return;
                setState(() {
                  _cycleTimeScope = v;
                  _cycleTimeRefreshTick++;
                });
              },
            ),
          ),
        ),
        SizedBox(
          width: 220,
          child: glassField(
            child: TextField(
              controller: _cycleTimeOwnerCtrl,
              style: TextStyle(color: chrome.textPrimary, fontSize: 12),
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                hintText: 'Owner (optional)',
                hintStyle: TextStyle(color: chrome.textMuted),
              ),
              onSubmitted: (_) => setState(() => _cycleTimeRefreshTick++),
            ),
          ),
        ),
        SizedBox(
          width: 220,
          child: glassField(
            child: TextField(
              controller: _cycleTimeProposalTypeCtrl,
              style: TextStyle(color: chrome.textPrimary, fontSize: 12),
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                hintText: 'Proposal type (optional)',
                hintStyle: TextStyle(color: chrome.textMuted),
              ),
              onSubmitted: (_) => setState(() => _cycleTimeRefreshTick++),
            ),
          ),
        ),
        glassField(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Auto',
                  style: TextStyle(color: chrome.textPrimary, fontSize: 12)),
              const SizedBox(width: 6),
              Switch(
                value: _cycleTimeAutoRefresh,
                onChanged: (v) {
                  setState(() {
                    _cycleTimeAutoRefresh = v;
                    _cycleTimeRefreshTick++;
                  });
                },
              ),
            ],
          ),
        ),
        glassField(
          child: IconButton(
            icon: Icon(Icons.refresh, color: chrome.textPrimary, size: 18),
            onPressed: () => setState(() => _cycleTimeRefreshTick++),
            tooltip: 'Refresh',
          ),
        ),
      ],
    );
  }

  Widget _buildCycleTimeCards(
    List<dynamic> byStage,
    Map<String, dynamic>? bottleneck,
    ManagerChromeTheme chrome,
  ) {
    String formatDays(num? days) {
      if (days == null) return '-';
      if (days < 1) {
        final hours = days * 24;
        if (hours < 1) {
          final minutes = hours * 60;
          return '${minutes.toStringAsFixed(0)} min';
        }
        return '${hours.toStringAsFixed(1)} h';
      }
      return '${days.toStringAsFixed(1)} d';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (bottleneck != null) ...[
          Text(
            'Current Bottleneck: ${bottleneck['stage']}',
            style: PremiumTheme.bodyLarge.copyWith(
              fontWeight: FontWeight.bold,
              color: chrome.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
        ],
        SizedBox(
          height: 140,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: byStage.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final item = byStage[index] as Map<String, dynamic>;
              final stage = item['stage']?.toString() ?? 'Unknown';
              final avgDays = item['avg_days'] as num?;
              final samples = item['samples'] as int? ?? 0;
              final bottleneckStage = bottleneck?['stage']?.toString();
              final isBottleneck =
                  bottleneckStage != null && bottleneckStage == stage;
              final borderColor = isBottleneck
                  ? const Color(0xFFE74C3C)
                  : (chrome.isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : chrome.divider);
              return Container(
                width: 220,
                padding: const EdgeInsets.all(16),
                decoration: chrome.isDark
                    ? BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.03),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: borderColor,
                          width: isBottleneck ? 2 : 1,
                        ),
                      )
                    : BoxDecoration(
                        color: chrome.floatingFill,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: borderColor,
                          width: isBottleneck ? 2 : 1,
                        ),
                      ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      stage,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: chrome.textPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      formatDays(avgDays),
                      style: PremiumTheme.displayMedium.copyWith(
                        fontSize: 22,
                        color: chrome.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$samples samples',
                      style: PremiumTheme.bodyMedium.copyWith(
                        color: chrome.textSecondary,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // ignore: unused_element
  String _formatDate(DateTime? date) {
    if (date == null) return 'No date';
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  void _navigatePage(String label) {
    final isAdminUser = _isAdminUser();
    switch (label) {
      case 'Dashboard':
        Navigator.pushReplacementNamed(
          context,
          isAdminUser ? '/approver_dashboard' : '/creator_dashboard',
        );
        break;
      case 'Approvals':
        Navigator.pushReplacementNamed(
          context,
          isAdminUser ? '/admin_approvals' : '/approved_proposals',
        );
        break;
      case 'Approved Proposals':
        Navigator.pushReplacementNamed(context, '/approved_proposals');
        break;
      case 'Proposals':
        Navigator.pushReplacementNamed(context, '/proposals');
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
      case 'Analytics':
      case 'Analytics (My Pipeline)':
        break; // already on this page
      case 'History':
        Navigator.pushReplacementNamed(context, '/admin_history');
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

  Widget _buildGlassButton(
    String label,
    IconData icon,
    VoidCallback onPressed,
  ) {
    final chrome = context.watch<ManagerThemeController>().chrome;
    final decoration = chrome.isDark
        ? BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
          )
        : chrome.floatingPanelDecoration(radius: 10);

    final ink = InkWell(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: decoration,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: chrome.textPrimary, size: 16),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: chrome.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: chrome.isDark
          ? BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: ink,
            )
          : ink,
    );
  }

  // ignore: unused_element
  Widget _buildNavItem(
    String label,
    String iconAsset,
    bool isActive,
    BuildContext context,
  ) {
    final collapsed = context.watch<AppState>().isAdminSidebarCollapsed;
    return Tooltip(
      message: collapsed ? label : '',
      child: InkWell(
        onTap: () {
          final isAdminUser = _isAdminUser();
          switch (label) {
            case 'Logout':
              Navigator.pushReplacementNamed(context, '/login');
              break;
            case 'Dashboard':
              Navigator.pushReplacementNamed(
                context,
                isAdminUser ? '/approver_dashboard' : '/creator_dashboard',
              );
              break;
            case 'My Proposals':
            case 'Proposals':
              Navigator.pushReplacementNamed(context, '/proposals');
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
              Navigator.pushReplacementNamed(
                context,
                isAdminUser ? '/admin_approvals' : '/approved_proposals',
              );
              break;
            case 'Approvals':
              Navigator.pushReplacementNamed(
                context,
                isAdminUser ? '/admin_approvals' : '/approved_proposals',
              );
              break;
            case 'Analytics':
            case 'Analytics (My Pipeline)':
              Navigator.pushReplacementNamed(
                context,
                isAdminUser ? '/admin_analytics' : '/analytics',
              );
              break;
            default:
              Navigator.pushReplacementNamed(
                context,
                isAdminUser ? '/approver_dashboard' : '/creator_dashboard',
              );
          }
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          padding: EdgeInsets.symmetric(
            horizontal: collapsed ? 10 : 14,
            vertical: 10,
          ),
          decoration: BoxDecoration(
            color: isActive
                ? Colors.white.withValues(alpha: 0.12)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Image.asset(
                iconAsset,
                width: 22,
                height: 22,
                color: isActive ? Colors.white : Colors.white70,
                errorBuilder: (_, __, ___) => Icon(
                  Icons.circle,
                  size: 20,
                  color: isActive ? Colors.white : Colors.white70,
                ),
              ),
              if (!collapsed) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isActive ? Colors.white : Colors.white70,
                      fontSize: 13,
                      fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
} // end _AnalyticsPageState

// ---------------------------------------------------------------------------
// Data classes used by analytics charts / tables
// ---------------------------------------------------------------------------

class _MonthlyPoint {
  final DateTime month;
  double revenue;
  int proposals;
  int wins;
  int losses;

  _MonthlyPoint(this.month)
      : revenue = 0,
        proposals = 0,
        wins = 0,
        losses = 0;

  String get label => DateFormat.MMM().format(month);
}

class _ProposalPerformanceRow {
  final String title;
  final double? value;
  final String valueLabel;
  final String status;
  final int daysOpen;
  final double probability;
  final Color statusColor;
  final DateTime? updatedAt;

  const _ProposalPerformanceRow({
    required this.title,
    this.value,
    required this.valueLabel,
    required this.status,
    required this.daysOpen,
    required this.probability,
    required this.statusColor,
    this.updatedAt,
  });

  String get probabilityLabel => '${(probability * 100).toStringAsFixed(0)}%';
}

class _AnalyticsSnapshot {
  final double totalPipelineValue;
  final int totalProposals;
  final int activeProposals;
  final double averageDealSize;
  final double winRate;
  final double lossRate;
  final Map<String, int> statusCounts;
  final List<_MonthlyPoint> monthlyPoints;
  final List<_ProposalPerformanceRow> recentProposals;
  final double? revenueChangePercent;
  final double? activeChangePercent;
  final double? conversionChangePercent;
  final double? averageDealChangePercent;

  const _AnalyticsSnapshot({
    required this.totalPipelineValue,
    required this.totalProposals,
    required this.activeProposals,
    required this.averageDealSize,
    required this.winRate,
    required this.lossRate,
    required this.statusCounts,
    required this.monthlyPoints,
    required this.recentProposals,
    this.revenueChangePercent,
    this.activeChangePercent,
    this.conversionChangePercent,
    this.averageDealChangePercent,
  });
}

class _MetricCardData {
  final String title;
  final String value;
  final String change;
  final bool isPositive;
  final String subtitle;

  const _MetricCardData({
    required this.title,
    required this.value,
    required this.change,
    required this.isPositive,
    required this.subtitle,
  });
}

/// Pipeline pill chip model used by the redesigned Pipeline View strip.
class _PipelinePill {
  final String label;
  final int count;
  const _PipelinePill(this.label, this.count);
}

/// Slice descriptor for `_buildDonutWithLegend` (Win Rate, Readiness Breakdown).
class _DonutSlice {
  final String label;
  final double value;
  final Color color;
  const _DonutSlice(this.label, this.value, this.color);
}

/// Small KPI tile model used by the secondary KPI strip in the Figma design.
class _SmallKpi {
  final String title;
  final String subtitle;
  final String value;
  final String iconAsset;
  const _SmallKpi({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.iconAsset,
  });
}
