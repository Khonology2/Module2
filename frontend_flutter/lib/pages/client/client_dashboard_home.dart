import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:convert';
import 'dart:ui' as ui;
import 'package:http/http.dart' as http;
import 'package:fl_chart/fl_chart.dart';
import 'package:web/web.dart' as web;
import 'dart:async';
import 'package:url_launcher/url_launcher_string.dart';
import 'client_proposal_viewer.dart';
import '../../api.dart';
import '../../theme/premium_theme.dart';

class ClientDashboardHome extends StatefulWidget {
  final String? initialToken;
  final int? initialNavIndex;
  final bool showSummary;

  const ClientDashboardHome({
    super.key,
    this.initialToken,
    this.initialNavIndex,
    this.showSummary = true,
  });

  @override
  State<ClientDashboardHome> createState() => _ClientDashboardHomeState();
}

class _ClientDashboardHomeState extends State<ClientDashboardHome> {
  static bool _globalOtpDialogOpen = false;
  static Future<void>? _globalVerificationFuture;

  bool _isLoading = true;
  DateTime? _loadingStartedAt;
  bool _isLightMode = false;
  String? _error;
  String? _accessToken;
  String? _clientEmail;
  String? _deviceId;
  String? _clientSessionToken;

  /// Incremented when the persisted client session token changes (e.g. after OTP).
  /// Used to ignore in-flight proposal HTTP responses that used a superseded session.
  int _clientSessionEpoch = 0;
  bool _verificationInProgress = false;
  bool _otpDialogOpen = false;
  Future<void>? _loadProposalsFuture;
  List<Map<String, dynamic>> _proposals = [];
  Map<String, dynamic>? _selectedDocument;
  int _selectedNavIndex = 0;
  bool _overviewLoading = false;
  String? _overviewError;
  Map<String, dynamic>? _overview;
  String _dashboardDocFilter = 'all';
  Map<String, int> _statusCounts = {
    'pending': 0,
    'approved': 0,
    'rejected': 0,
    'viewed': 0,
  };
  bool _isSidebarCollapsed = false;
  int? _hoverSidebarIndex;
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _proposalsScrollController = ScrollController();

  static const List<Map<String, dynamic>> _clientNavItems = [
    {
      'index': 0,
      'label': 'Dashboard',
      'asset': 'assets/images/new icons for manager/Dashboard.png'
    },
    {
      'index': 1,
      'label': 'Proposals',
      'asset': 'assets/images/new icons for manager/proposals.png'
    },
    {
      'index': 2,
      'label': 'Documents',
      'asset': 'assets/images/client_icons/Data Approval_White Badge_Blue.png'
    },
  ];

  bool _isSow(Map<String, dynamic> p) {
    final t =
        (p['template_type'] ?? p['templateType'] ?? p['template_key'] ?? '')
            .toString()
            .toLowerCase();
    return t.contains('sow');
  }

  Future<void> _ensureMinLoadingTime(Duration minDuration) async {
    final startedAt = _loadingStartedAt;
    if (startedAt == null) return;

    final elapsed = DateTime.now().difference(startedAt);
    final remaining = minDuration - elapsed;
    if (remaining.isNegative) return;

    await Future.delayed(remaining);
  }

  Widget _filterChip(String label, String value) {
    final selected = _dashboardDocFilter == value;
    const chipHeight = 18.06;
    const chipRadius = 20.14;
    const chipBorderWidth = 1.23;
    const chipBorderColor = Color(0xFF6A6A6A);

    return InkWell(
      onTap: () {
        setState(() {
          _dashboardDocFilter = value;
        });
      },
      borderRadius: BorderRadius.circular(chipRadius),
      child: SizedBox(
        height: chipHeight,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 7),
          decoration: BoxDecoration(
            color: selected
                ? const Color(0xFFC10D00)
                : Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(chipRadius),
            border: Border.all(
                color: selected ? const Color(0xFFC10D00) : chipBorderColor,
                width: chipBorderWidth),
          ),
          child: Center(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white,
                fontSize: 7.5,
                fontWeight: FontWeight.w700,
                height: 1.0,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSidebarActionItem({
    required String label,
    required String assetPath,
    required bool isCollapsed,
    required VoidCallback onTap,
    required Color activeColor,
    required Color hoverFill,
    required Color iconCircleIdle,
  }) {
    final bool isHovering = _hoverSidebarIndex == -1;

    return MouseRegion(
      onEnter: (_) => setState(() => _hoverSidebarIndex = -1),
      onExit: (_) => setState(() => _hoverSidebarIndex = null),
      child: Padding(
        padding: isCollapsed
            ? const EdgeInsets.symmetric(vertical: 5)
            : const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        child: Tooltip(
          message: isCollapsed ? label : '',
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(10),
            child: isCollapsed
                ? Center(
                    child: Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: isHovering ? hoverFill : iconCircleIdle,
                        shape: BoxShape.circle,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Image.asset(
                          assetPath,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => const Icon(
                            Icons.image_not_supported_outlined,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                  )
                : Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: isHovering ? hoverFill : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: iconCircleIdle,
                            shape: BoxShape.circle,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Image.asset(
                              assetPath,
                              fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) => const Icon(
                                Icons.image_not_supported_outlined,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            label,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              height: 1.2,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  bool _isProposalRequiringAction(Map<String, dynamic> p) {
    if (_isSow(p)) return false;
    final s = (p['status'] ?? '').toString().toLowerCase();
    return s.contains('sent') ||
        s.contains('released') ||
        s.contains('review') ||
        s.contains('pending') ||
        s.contains('signature');
  }

  bool _isSignedDocument(Map<String, dynamic> p) {
    if (_isSow(p)) return false;
    final statusLower = (p['status'] ?? '').toString().toLowerCase().trim();
    return statusLower.contains('client signed') ||
        statusLower.contains('signed');
  }

  bool _isAwaitingSignature(Map<String, dynamic> p) {
    if (_isSow(p)) return false;
    if (_isSignedDocument(p)) return false;

    final statusLower = (p['status'] ?? '').toString().toLowerCase().trim();

    return statusLower.contains('sent for signature') ||
        statusLower.contains('sent to client') ||
        statusLower.contains('released') ||
        statusLower.contains('in review') ||
        statusLower.contains('review') ||
        statusLower.contains('sent');
  }

  int _proposalsRequiringActionCount() {
    return _proposals.where(_isProposalRequiringAction).length;
  }

  String _normalizeStatus(String rawStatus) {
    final lower = rawStatus.toLowerCase().trim();
    if (lower.isEmpty) return 'Unknown';
    if (lower.contains('signed') || lower.contains('approved')) return 'Signed';
    if (lower.contains('declined') || lower.contains('rejected')) {
      return 'Declined';
    }
    if (lower.contains('sent for signature')) return 'Sent for Signature';
    if (lower.contains('sent to client') || lower.contains('released')) {
      return 'Released';
    }
    if (lower.contains('review')) return 'In Review';
    if (lower.contains('pending')) return 'Pending';
    if (lower.contains('draft')) return 'Draft';

    return rawStatus.trim();
  }

  String _groupStatusForCounts(String rawStatus) {
    final normalized = _normalizeStatus(rawStatus).toLowerCase();
    if (normalized.contains('pending') ||
        normalized.contains('released') ||
        normalized.contains('sent for signature') ||
        normalized.contains('in review')) {
      return 'pending';
    }
    if (normalized.contains('signed')) return 'approved';
    if (normalized.contains('declined')) return 'rejected';
    if (normalized.contains('viewed')) return 'viewed';
    return 'pending';
  }

  @override
  void initState() {
    super.initState();
    _selectedNavIndex = widget.initialNavIndex ?? 0;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _extractTokenAndLoad();
    });
  }

  bool get _isOverviewDashboard => widget.showSummary && _selectedNavIndex == 0;

  void _navigateClient(String route) {
    final token = _accessToken;
    final suffix = (token != null && token.isNotEmpty)
        ? '?token=${Uri.encodeComponent(token)}'
        : '';
    Navigator.pushReplacementNamed(context, '$route$suffix');
  }

  void _logoutClient() {
    setState(() {
      _accessToken = null;
      _clientSessionToken = null;
      _selectedNavIndex = 0;
    });
    if (kIsWeb) {
      try {
        web.window.localStorage.removeItem('lukens_client_session_token');
      } catch (_) {}
    }
    Navigator.pushReplacementNamed(context, '/login');
  }

  String _sanitizeToken(String token) {
    var t = token.trim();
    try {
      t = Uri.decodeComponent(t);
    } catch (_) {}
    while (t.startsWith('"') || t.startsWith("'")) {
      t = t.substring(1);
    }
    while (t.endsWith('"') || t.endsWith("'")) {
      t = t.substring(0, t.length - 1);
    }
    return t.trim();
  }

  String _getOrCreateDeviceId() {
    if (!kIsWeb) {
      return 'flutter-device';
    }
    try {
      final existing = web.window.localStorage['lukens_client_device_id'];
      final clean = existing?.trim();
      if (clean != null && clean.isNotEmpty) return clean;
      final id =
          'dev_${DateTime.now().millisecondsSinceEpoch}_${(100000 + (DateTime.now().microsecondsSinceEpoch % 900000))}';
      web.window.localStorage['lukens_client_device_id'] = id;
      return id;
    } catch (_) {
      return 'dev_${DateTime.now().millisecondsSinceEpoch}';
    }
  }

  void _loadCachedClientSession() {
    if (!kIsWeb) return;
    try {
      final token = web.window.localStorage['lukens_client_session_token'];
      final clean = token?.trim();
      if (clean != null && clean.isNotEmpty) {
        _clientSessionToken = clean;
      }
    } catch (_) {}
  }

  void _persistClientSessionToken(String token) {
    final clean = token.trim();
    if (clean.isEmpty) return;
    if ((_clientSessionToken ?? '').trim() != clean) {
      _clientSessionEpoch++;
    }
    _clientSessionToken = clean;
    if (!kIsWeb) return;
    try {
      web.window.localStorage['lukens_client_session_token'] = clean;
    } catch (_) {}
  }

  Future<Map<String, dynamic>?> _startClientDeviceSession(
    String token, {
    bool resend = false,
  }) async {
    if (_deviceId == null || _deviceId!.isEmpty) {
      _deviceId = _getOrCreateDeviceId();
    }

    final resp = await http.post(
      Uri.parse('$baseUrl/client/device-session/start'),
      headers: {
        'Content-Type': 'application/json',
        if (_deviceId != null && _deviceId!.isNotEmpty)
          'X-Client-Device-Id': _deviceId!,
        if (_clientSessionToken != null && _clientSessionToken!.isNotEmpty)
          'X-Client-Session-Token': _clientSessionToken!,
      },
      body: jsonEncode({
        'token': token,
        'device_id': _deviceId,
        if (resend) 'resend': true,
      }),
    );

    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      return null;
    }
    final decoded = jsonDecode(resp.body);
    if (decoded is! Map) return null;
    return Map<String, dynamic>.from(decoded);
  }

  Future<Map<String, dynamic>?> _verifyClientDeviceOtp(
    String challengeId,
    String otp,
  ) async {
    final resp = await http.post(
      Uri.parse('$baseUrl/client/device-session/verify-otp'),
      headers: {
        'Content-Type': 'application/json',
        if (_deviceId != null && _deviceId!.isNotEmpty)
          'X-Client-Device-Id': _deviceId!,
        if (_clientSessionToken != null && _clientSessionToken!.isNotEmpty)
          'X-Client-Session-Token': _clientSessionToken!,
      },
      body: jsonEncode({
        'challenge_id': challengeId,
        'otp': otp,
      }),
    );

    final decoded = jsonDecode(resp.body);
    if (decoded is! Map) return null;
    final data = Map<String, dynamic>.from(decoded);
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      data['__http_status'] = resp.statusCode;
      return data;
    }
    return data;
  }

  Future<void> _ensureDeviceVerifiedAndRetry({required String token}) async {
    if (_globalVerificationFuture != null) {
      return _globalVerificationFuture!;
    }

    _globalVerificationFuture =
        _runVerificationFlow(token: token).whenComplete(() {
      _globalVerificationFuture = null;
    });

    return _globalVerificationFuture!;
  }

  Future<void> _runVerificationFlow({required String token}) async {
    if (_verificationInProgress || _otpDialogOpen) return;
    _verificationInProgress = true;

    try {
      final start = await _startClientDeviceSession(token);
      if (start == null) {
        if (!mounted) return;
        setState(() {
          _error = 'Unable to start verification. Please retry.';
          _isLoading = false;
        });
        return;
      }

      final otpRequired = start['otp_required'] == true;
      final sessionToken = start['session_token']?.toString();

      if (!otpRequired &&
          sessionToken != null &&
          sessionToken.trim().isNotEmpty) {
        _persistClientSessionToken(sessionToken);
        await _loadClientProposals();
        return;
      }

      final challengeId = start['challenge_id']?.toString() ?? '';
      if (challengeId.trim().isEmpty) {
        if (!mounted) return;
        setState(() {
          _error = 'Verification required, but no challenge was created.';
          _isLoading = false;
        });
        return;
      }

      await _showOtpDialog(token: token, challengeId: challengeId);

      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    } finally {
      _verificationInProgress = false;
    }
  }

  Future<void> _showOtpDialog({
    required String token,
    required String challengeId,
  }) async {
    if (_globalOtpDialogOpen) return;
    if (_otpDialogOpen) return;
    _otpDialogOpen = true;
    _globalOtpDialogOpen = true;
    final controller = TextEditingController();
    bool submitting = false;
    String? error;

    try {
      await showDialog<void>(
        context: context,
        useRootNavigator: true,
        barrierDismissible: !submitting,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (context, setModalState) {
              bool verificationComplete = false;

              Future<void> verify() async {
                if (submitting || verificationComplete) return;
                final otp = controller.text.trim();
                if (otp.isEmpty) {
                  setModalState(
                      () => error = 'Enter the code sent to your email.');
                  return;
                }

                setModalState(() {
                  submitting = true;
                  error = null;
                });

                try {
                  final result = await _verifyClientDeviceOtp(challengeId, otp);
                  final sessionToken = result?['session_token']?.toString();
                  if (sessionToken != null && sessionToken.trim().isNotEmpty) {
                    verificationComplete = true;
                    _persistClientSessionToken(sessionToken);
                    try {
                      Navigator.of(dialogContext, rootNavigator: true).pop();
                    } catch (_) {
                      try {
                        Navigator.of(dialogContext).pop();
                      } catch (_) {}
                    }
                    return;
                  }

                  final msg = result?['detail']?.toString() ?? 'Invalid code.';
                  setModalState(() => error = msg);
                } catch (e) {
                  setModalState(() => error = e.toString());
                } finally {
                  if (!verificationComplete) {
                    setModalState(() => submitting = false);
                  }
                }
              }

              Future<void> resend() async {
                setModalState(() {
                  submitting = true;
                  error = null;
                });
                try {
                  await _startClientDeviceSession(token, resend: true);
                  setModalState(() {
                    submitting = false;
                    error = 'A new code has been sent.';
                  });
                } catch (e) {
                  setModalState(() {
                    submitting = false;
                    error = e.toString();
                  });
                }
              }

              final w = MediaQuery.sizeOf(context).width;
              final h = MediaQuery.sizeOf(context).height;
              final logoHeight = (w * 0.10).clamp(56.0, 120.0);
              final loaderHeight = (w * 0.08).clamp(40.0, 90.0);
              final cardWidth = (w * 0.42).clamp(320.0, 520.0);
              final isLightMode = _isLightMode;
              final bgAsset = isLightMode
                  ? 'assets/images/light_mode_bg.png'
                  : 'assets/images/client_dashboard_bg.png';
              final loaderAsset = isLightMode
                  ? 'assets/images/Red_Discs.png'
                  : 'assets/images/White_khono_loading.png.png';
              final overlayGradient = isLightMode
                  ? LinearGradient(
                      colors: [
                        Colors.white.withValues(alpha: 0.50),
                        Colors.white.withValues(alpha: 0.15),
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    )
                  : LinearGradient(
                      colors: [
                        Colors.black.withValues(alpha: 0.65),
                        Colors.black.withValues(alpha: 0.35),
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    );
              final titleColor = Colors.white;
              final subtitleColor = Colors.white70;

              return Dialog(
                insetPadding: EdgeInsets.zero,
                backgroundColor: Colors.transparent,
                elevation: 0,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Positioned.fill(
                      child: Image.asset(
                        bgAsset,
                        fit: BoxFit.cover,
                      ),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        gradient: overlayGradient,
                      ),
                    ),
                    SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 14,
                        ),
                        child: Stack(
                          children: [
                            Align(
                              alignment: Alignment.topCenter,
                              child: Padding(
                                padding: const EdgeInsets.only(top: 18),
                                child: Image.asset(
                                  'assets/images/Landingscreen.png',
                                  height: logoHeight,
                                  fit: BoxFit.contain,
                                  filterQuality: FilterQuality.high,
                                ),
                              ),
                            ),
                            Center(
                              child: ConstrainedBox(
                                constraints: BoxConstraints(
                                  maxWidth: cardWidth,
                                  maxHeight: h * 0.72,
                                ),
                                child: Material(
                                  color: Colors.black.withValues(alpha: 0.55),
                                  borderRadius: BorderRadius.circular(18),
                                  child: Padding(
                                    padding: const EdgeInsets.all(18),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        Text(
                                          'Proposal & SOW Builder',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            color: titleColor,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Verify your device',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            color: titleColor,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(height: 14),
                                        Text(
                                          'Enter the code sent to your email address:',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            color: subtitleColor,
                                            fontSize: 12,
                                          ),
                                        ),
                                        const SizedBox(height: 14),
                                        TextField(
                                          controller: controller,
                                          enabled: !submitting,
                                          keyboardType: TextInputType.number,
                                          onSubmitted: (_) => verify(),
                                          style: TextStyle(
                                            color: titleColor,
                                          ),
                                          decoration: InputDecoration(
                                            hintText: 'OTP code',
                                            hintStyle: TextStyle(
                                              color: Colors.white54,
                                            ),
                                            filled: true,
                                            fillColor: Colors.white
                                                .withValues(alpha: 0.10),
                                            border: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(14),
                                              borderSide: BorderSide.none,
                                            ),
                                            contentPadding:
                                                const EdgeInsets.symmetric(
                                              horizontal: 16,
                                              vertical: 14,
                                            ),
                                          ),
                                        ),
                                        if (error != null) ...[
                                          const SizedBox(height: 12),
                                          Text(
                                            error!,
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              color: error ==
                                                      'A new code has been sent.'
                                                  ? subtitleColor
                                                  : Colors.red.shade300,
                                            ),
                                          ),
                                        ],
                                        const SizedBox(height: 18),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: ElevatedButton(
                                                onPressed: submitting
                                                    ? null
                                                    : () => Navigator.of(
                                                            dialogContext,
                                                            rootNavigator: true)
                                                        .pop(),
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: Colors.grey
                                                      .withValues(alpha: 0.65),
                                                  foregroundColor: Colors.white,
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            22),
                                                  ),
                                                ),
                                                child: const Text('CANCEL'),
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: OutlinedButton(
                                                onPressed:
                                                    submitting ? null : resend,
                                                style: OutlinedButton.styleFrom(
                                                  foregroundColor: Colors.white,
                                                  side: BorderSide(
                                                    color: Colors.white
                                                        .withValues(
                                                            alpha: 0.55),
                                                  ),
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            22),
                                                  ),
                                                ),
                                                child: const Text('RESEND'),
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: ElevatedButton(
                                                onPressed:
                                                    submitting ? null : verify,
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor:
                                                      const Color(0xFFC10D00),
                                                  foregroundColor: Colors.white,
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            22),
                                                  ),
                                                ),
                                                child: submitting
                                                    ? const SizedBox(
                                                        width: 18,
                                                        height: 18,
                                                        child:
                                                            CircularProgressIndicator(
                                                          strokeWidth: 2,
                                                          color: Colors.white,
                                                        ),
                                                      )
                                                    : const Text('VERIFY'),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Align(
                              alignment: Alignment.bottomLeft,
                              child: Padding(
                                padding:
                                    const EdgeInsets.only(left: 10, bottom: 10),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.35),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color:
                                          Colors.white.withValues(alpha: 0.18),
                                    ),
                                  ),
                                  child: const Text(
                                    'Ver 2025.03.AA1_SIT',
                                    style: TextStyle(
                                      fontSize: 9,
                                      color: Colors.white70,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Align(
                              alignment: Alignment.bottomRight,
                              child: Padding(
                                padding: const EdgeInsets.only(
                                  right: 10,
                                  bottom: 10,
                                ),
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap: () {
                                      setState(() {
                                        _isLightMode = !_isLightMode;
                                      });
                                      setModalState(() {});
                                    },
                                    borderRadius: BorderRadius.circular(18),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: (isLightMode
                                                ? Colors.white
                                                : Colors.black)
                                            .withValues(alpha: 0.35),
                                        borderRadius: BorderRadius.circular(18),
                                        border: Border.all(
                                          color: (isLightMode
                                                  ? Colors.black
                                                  : Colors.white)
                                              .withValues(alpha: 0.18),
                                        ),
                                      ),
                                      child: Icon(
                                        isLightMode
                                            ? Icons.dark_mode_outlined
                                            : Icons.light_mode_outlined,
                                        size: 16,
                                        color: isLightMode
                                            ? Colors.black
                                            : Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Align(
                              alignment: Alignment.bottomCenter,
                              child: Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: Image.asset(
                                  loaderAsset,
                                  height: loaderHeight,
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      );
    } finally {
      _otpDialogOpen = false;
      _globalOtpDialogOpen = false;
    }
  }

  List<Map<String, dynamic>> _filteredDocuments() {
    final idx = _selectedNavIndex;
    final docs = List<Map<String, dynamic>>.from(_proposals);

    // Apply search filtering if search text is present
    final searchText = _searchController.text.toLowerCase().trim();
    List<Map<String, dynamic>> filteredDocs = docs;
    if (searchText.isNotEmpty) {
      filteredDocs = docs.where((d) {
        final title = (d['title'] ?? '').toString().toLowerCase();
        final client =
            (d['client_name'] ?? d['client'] ?? '').toString().toLowerCase();
        final id = d['id']?.toString() ?? '';
        return title.contains(searchText) ||
            client.contains(searchText) ||
            id.contains(searchText);
      }).toList();
    }

    if (idx == 0) {
      if (_dashboardDocFilter == 'all') return filteredDocs;
      return filteredDocs.where((d) {
        final status = (d['status'] ?? '').toString().toLowerCase();
        switch (_dashboardDocFilter) {
          case 'draft':
            return status.contains('draft');
          case 'released':
            return status.contains('sent to client') ||
                status.contains('released');
          case 'pending':
            return status.contains('pending') ||
                status.contains('review') ||
                status.contains('sent for signature');
          case 'signed':
            return status.contains('signed');
          case 'changes_requested':
            return status.contains('change') || status.contains('request');
          default:
            return true;
        }
      }).toList();
    }
    if (idx == 1) {
      return filteredDocs.where(_isAwaitingSignature).toList();
    }
    if (idx == 2) {
      return filteredDocs.where(_isSignedDocument).toList();
    }
    return filteredDocs;
  }

  String _documentLabel(Map<String, dynamic> doc) {
    final t = (doc['template_type'] ??
            doc['templateType'] ??
            doc['template_key'] ??
            '')
        .toString()
        .toLowerCase();
    if (t.contains('sow')) return 'SOW';
    return 'Proposal';
  }

  Future<void> _downloadPdfForDocument(Map<String, dynamic> doc) async {
    final rawId = doc['id'];
    final id = rawId is int ? rawId : int.tryParse(rawId?.toString() ?? '');
    if (id == null || _accessToken == null || _accessToken!.isEmpty) return;

    final statusLower = (doc['status'] ?? '').toString().toLowerCase();
    final isSigned = statusLower.contains('client signed') ||
        (statusLower.contains('signed') && !statusLower.contains('sent'));

    final url = isSigned
        ? '$baseUrl/api/client/proposals/$id/docusign/signed-pdf?token=${Uri.encodeComponent(_accessToken!)}'
        : '$baseUrl/api/client/proposals/$id/export/pdf?token=${Uri.encodeComponent(_accessToken!)}&download=1';
    web.window.open(url, '_blank');
  }

  Future<void> _openSigningUrl(Map<String, dynamic> doc) async {
    final rawId = doc['id'];
    final proposalId =
        rawId is int ? rawId : int.tryParse(rawId?.toString() ?? '');
    if (proposalId == null || _accessToken == null || _accessToken!.isEmpty) {
      return;
    }

    try {
      final uri = Uri.parse(
          '$baseUrl/api/client/proposals/$proposalId/docusign/signing-url');
      final resp = await http
          .post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'token': _accessToken,
          'signer_name':
              (doc['client_name']?.toString().trim().isNotEmpty ?? false)
                  ? doc['client_name']?.toString().trim()
                  : (_clientEmail ?? '').trim(),
        }),
      )
          .timeout(
        const Duration(seconds: 45),
        onTimeout: () {
          throw TimeoutException('Signing URL request timed out');
        },
      );

      Map<String, dynamic>? decoded;
      try {
        final body = jsonDecode(resp.body);
        if (body is Map) {
          decoded = Map<String, dynamic>.from(body);
        }
      } catch (_) {}

      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        final fresh = decoded?['signing_url']?.toString() ?? '';
        if (fresh.trim().isNotEmpty) {
          if (kIsWeb) {
            web.window.location.href = fresh;
          } else {
            await launchUrlString(fresh, mode: LaunchMode.externalApplication);
          }
          return;
        }
      }

      final fallbackSigningUrl = doc['signing_url']?.toString() ?? '';
      if (fallbackSigningUrl.trim().isNotEmpty) {
        if (kIsWeb) {
          web.window.location.href = fallbackSigningUrl;
        } else {
          await launchUrlString(fallbackSigningUrl,
              mode: LaunchMode.externalApplication);
        }
        return;
      }

      if (mounted) {
        final msg = decoded?['detail']?.toString() ??
            'Unable to open DocuSign (HTTP ${resp.statusCode}).';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      final fallbackSigningUrl = doc['signing_url']?.toString() ?? '';
      if (fallbackSigningUrl.trim().isNotEmpty) {
        if (kIsWeb) {
          web.window.location.href = fallbackSigningUrl;
        } else {
          await launchUrlString(fallbackSigningUrl,
              mode: LaunchMode.externalApplication);
        }
        return;
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Unable to open DocuSign: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _showFallbackSignModal(Map<String, dynamic> doc) async {
    if (_accessToken == null || _accessToken!.isEmpty) return;
    final rawId = doc['id'];
    final proposalId =
        rawId is int ? rawId : int.tryParse(rawId?.toString() ?? '');
    if (proposalId == null) return;

    final nameController = TextEditingController();
    bool consent = false;
    bool submitting = false;
    String? error;

    await showDialog<void>(
      context: context,
      barrierDismissible: !submitting,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            Future<void> submit() async {
              final signerName = nameController.text.trim();
              if (signerName.isEmpty) {
                setModalState(() => error = 'Please enter your name.');
                return;
              }
              if (!consent) {
                setModalState(
                    () => error = 'Please confirm you agree to sign.');
                return;
              }

              setModalState(() {
                submitting = true;
                error = null;
              });

              try {
                final resp = await http.post(
                  Uri.parse(
                      '$baseUrl/api/client/proposals/$proposalId/sign_token'),
                  headers: {
                    'Content-Type': 'application/json',
                    if (_deviceId != null && _deviceId!.isNotEmpty)
                      'X-Client-Device-Id': _deviceId!,
                    if (_clientSessionToken != null &&
                        _clientSessionToken!.isNotEmpty)
                      'X-Client-Session-Token': _clientSessionToken!,
                  },
                  body: jsonEncode({
                    'token': _accessToken,
                    'signer_name': signerName,
                  }),
                );

                if (resp.statusCode >= 200 && resp.statusCode < 300) {
                  if (mounted) Navigator.of(context).pop();
                  await _loadClientProposals();
                  return;
                }

                String detail = 'Unable to sign (HTTP ${resp.statusCode})';
                try {
                  final decoded = jsonDecode(resp.body);
                  if (decoded is Map && decoded['detail'] != null) {
                    detail = decoded['detail'].toString();
                  }
                } catch (_) {}
                setModalState(() => error = detail);
              } catch (e) {
                setModalState(() => error = e.toString());
              } finally {
                setModalState(() => submitting = false);
              }
            }

            return AlertDialog(
              title: const Text('Confirm Signature'),
              content: SizedBox(
                width: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      doc['title']?.toString() ?? 'Document',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Your name',
                        border: OutlineInputBorder(),
                      ),
                      enabled: !submitting,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Checkbox(
                          value: consent,
                          onChanged: submitting
                              ? null
                              : (v) =>
                                  setModalState(() => consent = v ?? false),
                        ),
                        const Expanded(
                          child: Text(
                            'I confirm that I agree to sign this document electronically.',
                          ),
                        ),
                      ],
                    ),
                    if (error != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        error!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed:
                      submitting ? null : () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: submitting ? null : submit,
                  child: submitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Confirm Signature'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _handleNavTap(int index, {bool closeDrawer = false}) {
    if (index == 0) {
      if (closeDrawer) Navigator.of(context).pop();
      if (!widget.showSummary) {
        _navigateClient('/client/dashboard');
      }
      return;
    }
    if (index == 1) {
      if (closeDrawer) Navigator.of(context).pop();
      if (widget.showSummary) {
        _navigateClient('/client/proposals');
      }
      return;
    }
    setState(() {
      _selectedNavIndex = index;
    });
    if (closeDrawer) Navigator.of(context).pop();
  }

  Widget _buildSidebar() {
    const Color activeColor = Color(0xFFC10D00);
    const Color sidebarBg = Color(0xFF2A2A2A);
    const Color hoverFill = Color(0xFF3A3A3A);
    const Color iconCircleIdle = Color(0xFF4A4A4A);
    const Color leftAccent = Color(0xFF1565C0);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: _isSidebarCollapsed ? 80 : 240,
      decoration: BoxDecoration(
        color: sidebarBg,
        border: Border(
          left: const BorderSide(color: leftAccent, width: 3),
          right: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_isSidebarCollapsed)
              Padding(
                padding:
                    const EdgeInsets.symmetric(vertical: 20, horizontal: 10),
                child: InkWell(
                  onTap: () => setState(() => _isSidebarCollapsed = false),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    alignment: Alignment.center,
                    child: Container(),
                  ),
                ),
              )
            else
              Container(
                padding: const EdgeInsets.fromLTRB(16, 30, 16, 20),
                child: Stack(
                  children: [
                    Positioned(
                      top: 0,
                      right: 0,
                      child: InkWell(
                        onTap: () => setState(() => _isSidebarCollapsed = true),
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          alignment: Alignment.center,
                          child: const Icon(
                            Icons.keyboard_arrow_left,
                            color: Colors.transparent,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                    Column(
                      children: [
                        const SizedBox(height: 4),
                        Image.asset(
                          'assets/images/new icons for manager/khonology_logo.png',
                          height: 36,
                          fit: BoxFit.contain,
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'Welcome to',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 16,
                            fontWeight: FontWeight.w400,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Proposal & SOW Builder',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.3,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 22),
                        const Divider(color: Color(0x33FFFFFF), height: 1),
                      ],
                    ),
                  ],
                ),
              ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(
                  children: [
                    for (final item in _clientNavItems)
                      _buildSidebarNavItem(
                        index: item['index'] as int,
                        label: item['label'] as String,
                        assetPath: item['asset'] as String,
                        isCollapsed: _isSidebarCollapsed,
                        activeColor: activeColor,
                        hoverFill: hoverFill,
                        iconCircleIdle: iconCircleIdle,
                      ),
                  ],
                ),
              ),
            ),
            if (!_isSidebarCollapsed)
              Container(
                margin:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                height: 1,
                color: Colors.white.withValues(alpha: 0.14),
              ),
            _buildSidebarNavItem(
              index: 3,
              label: 'Account Profile',
              assetPath: 'assets/images/User_Profile.png',
              isCollapsed: _isSidebarCollapsed,
              activeColor: activeColor,
              hoverFill: hoverFill,
              iconCircleIdle: iconCircleIdle,
            ),
            _buildSidebarActionItem(
              label: 'Logout',
              assetPath: 'assets/images/Logout_KhonoBuzz.png',
              isCollapsed: _isSidebarCollapsed,
              onTap: _logoutClient,
              activeColor: activeColor,
              hoverFill: hoverFill,
              iconCircleIdle: iconCircleIdle,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSidebarNavItem({
    required int index,
    required String label,
    required String assetPath,
    required bool isCollapsed,
    required Color activeColor,
    required Color hoverFill,
    required Color iconCircleIdle,
  }) {
    final bool selected = _selectedNavIndex == index;
    final bool isHovering = _hoverSidebarIndex == index;
    final int badgeCount =
        label == 'Proposals' ? _proposalsRequiringActionCount() : 0;

    return MouseRegion(
      onEnter: (_) => setState(() => _hoverSidebarIndex = index),
      onExit: (_) => setState(() => _hoverSidebarIndex = null),
      child: Padding(
        padding: isCollapsed
            ? const EdgeInsets.symmetric(vertical: 5)
            : const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        child: Tooltip(
          message: isCollapsed ? label : '',
          child: InkWell(
            onTap: () => _handleNavTap(index),
            borderRadius: BorderRadius.circular(10),
            child: isCollapsed
                ? Center(
                    child: Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: selected
                            ? activeColor
                            : isHovering
                                ? hoverFill
                                : iconCircleIdle,
                        shape: BoxShape.circle,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Image.asset(
                          assetPath,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => const Icon(
                            Icons.image_not_supported_outlined,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                  )
                : Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: selected
                          ? activeColor
                          : isHovering
                              ? hoverFill
                              : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: selected
                                ? Colors.white.withValues(alpha: 0.22)
                                : iconCircleIdle,
                            shape: BoxShape.circle,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Image.asset(
                              assetPath,
                              fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) => const Icon(
                                Icons.image_not_supported_outlined,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            label,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight:
                                  selected ? FontWeight.w600 : FontWeight.w500,
                              height: 1.2,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (badgeCount > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              badgeCount > 99 ? '99+' : badgeCount.toString(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildSidebarDrawer() {
    return Drawer(
      backgroundColor: const Color(0xFF2A2A2A),
      child: SafeArea(
        child: Builder(
          builder: (context) {
            return Container(
              color: const Color(0xFF2A2A2A),
              child: SingleChildScrollView(
                  child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 14),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 8, 8, 10),
                    child: Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Client Portal',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.close, color: Colors.white70),
                          tooltip: 'Close',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildDrawerNavItem(
                      context,
                      0,
                      'assets/images/new icons for manager/Dashboard.png',
                      'Dashboard'),
                  _buildDrawerNavItem(
                      context,
                      1,
                      'assets/images/new icons for manager/proposals.png',
                      'Proposals'),
                  _buildDrawerNavItem(
                      context,
                      2,
                      'assets/images/client_icons/Data Approval_White Badge_Blue.png',
                      'Documents'),
                  _buildDrawerNavItem(context, 3,
                      'assets/images/User_Profile.png', 'Account Profile'),
                  const Spacer(),
                ],
              )),
            );
          },
        ),
      ),
    );
  }

  Widget _buildDrawerNavItem(
      BuildContext context, int index, String assetPath, String label,
      {VoidCallback? onTap, double itemHeight = 37.77, double? itemWidth}) {
    final selected = _selectedNavIndex == index;
    final badgeCount =
        label == 'Proposals' ? _proposalsRequiringActionCount() : 0;
    return InkWell(
      onTap: () {
        _handleNavTap(index, closeDrawer: true);
        onTap?.call();
      },
      child: Container(
        width: itemWidth,
        height: itemHeight,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: selected
              ? Colors.white.withValues(alpha: 0.12)
              : Colors.transparent,
          border: selected
              ? Border(
                  left: BorderSide(color: PremiumTheme.primaryRed, width: 3),
                )
              : null,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Container(
              width: 26,
              height: 26,
              decoration: const BoxDecoration(
                color: Color(0xFFE5E7EB),
                shape: BoxShape.circle,
              ),
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Image.asset(
                  assetPath,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Icon(
                    Icons.image_not_supported_outlined,
                    color: Color(0xFF1F2937),
                    size: 14,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: selected ? Colors.white : Colors.white70,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ),
            if (badgeCount > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: PremiumTheme.primaryRed,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  badgeCount > 99 ? '99+' : badgeCount.toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopHeader({required bool useDrawer}) {
    final isDocumentsTab = _selectedNavIndex == 2;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      child: Row(
        children: [
          if (useDrawer)
            IconButton(
              onPressed: () {
                final scaffold = Scaffold.maybeOf(context);
                scaffold?.openDrawer();
              },
              icon: const Icon(Icons.menu, color: Colors.white70),
              tooltip: 'Menu',
            ),
          if (useDrawer) const SizedBox(width: 6),
          Expanded(
            child: Row(
              children: [
                Text(
                  isDocumentsTab
                      ? 'Client Portal Signed Documents'
                      : 'Client Portal',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (!isDocumentsTab) ...[
                  const SizedBox(width: 8),
                  Text(
                    'Hello, ${_getClientDisplayName()}',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.75),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
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
                onTap: () {},
              ),
              const SizedBox(width: 8),
              _buildHeaderIconButton(
                assetPath:
                    'assets/images/new icons for manager/notifications.png',
                onTap: () {},
                badge: 2,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryTiles() {
    final allDocs = List<Map<String, dynamic>>.from(_proposals);
    final activeCount = allDocs.length;
    final pendingSignatureCount = allDocs.where((d) {
      final s = (d['status'] ?? '').toString().toLowerCase();
      if (s.contains('signed')) return false;
      return s.contains('sent') ||
          s.contains('released') ||
          s.contains('review') ||
          s.contains('signature');
    }).length;
    final signedSowCount = allDocs.where((d) {
      if (!_isSow(d)) return false;
      final s = (d['status'] ?? '').toString().toLowerCase();
      return s.contains('signed');
    }).length;
    final pendingApprovalsCount = pendingSignatureCount;

    const tileWidth = 320.0;
    const tileHeight = 102.64;

    Widget tile({
      required String label,
      required String value,
      required String subtitle,
      required String iconAssetPath,
    }) {
      return Container(
        width: tileWidth,
        height: tileHeight,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(5.32),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              offset: const Offset(0, 3.55),
              blurRadius: 3.55,
              spreadRadius: 0,
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.55),
                          fontSize: 10,
                          height: 1.25,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    value,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      height: 1.0,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    offset: const Offset(0, 1),
                    blurRadius: 2,
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Image.asset(
                  iconAssetPath,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ],
        ),
      );
    }

    final children = [
      tile(
        label: 'Active Proposals',
        value: activeCount.toString(),
        subtitle: 'All proposals',
        iconAssetPath:
            'assets/images/client_icons/Goal_Target_White Badge_Red.png',
      ),
      tile(
        label: 'Signed',
        value: signedSowCount.toString(),
        subtitle: 'Signature provided',
        iconAssetPath: 'assets/images/Admin_new_icons/Client_Approved.png',
      ),
      tile(
        label: 'Pending Approvals',
        value: pendingApprovalsCount.toString(),
        subtitle: 'Awaiting review',
        iconAssetPath: 'assets/images/Admin_new_icons/Pending_CEO_Approval.png',
      ),
    ];

    // Figma: three blocks side-by-side, 306.62 × 102.64 each; scroll horizontally if needed.
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          children[0],
          const SizedBox(width: 12),
          children[1],
          const SizedBox(width: 12),
          children[2],
        ],
      ),
    );
  }

  Widget _buildTopCornerAssetIcon(String assetPath) {
    return SizedBox(
      width: 44.87,
      height: 44.87,
      child: Image.asset(
        assetPath,
        width: 44.87,
        height: 44.87,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) {
          return Container(
            width: 44.87,
            height: 44.87,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(22.435),
              border: Border.all(color: Colors.white24),
            ),
            child: const Icon(Icons.image_not_supported_outlined,
                color: Colors.white70, size: 18),
          );
        },
      ),
    );
  }

  Widget _buildRecentDocuments({double? width, double? height}) {
    final docs = _filteredDocuments();
    final isDocumentsTab = _selectedNavIndex == 2;
    final isProposalsTab = _selectedNavIndex == 1;
    const managerBadgeAsset =
        'assets/images/Project Management_Red Badge_White.png';
    const recentDocumentsIconAsset =
        'assets/images/Admin_new_icons/Recent_Proposals.png';
    const notificationBellAsset =
        'assets/images/new icons for manager/notifications.png';
    final listTitle = isDocumentsTab
        ? 'Client Portal Signed Documents'
        : isProposalsTab
            ? 'Awaiting Signature'
            : 'Recent Documents';
    const recentDocsWidth = 520.0;
    const recentDocsHeight = 330.0;
    final panelWidth = width ?? recentDocsWidth;
    final panelHeight = height ?? recentDocsHeight;

    Widget _buildBellCountBadge(int count) {
      const size = 44.0;
      const badgeBg = Color(0xFFC10D00);
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
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.18),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: ClipOval(
                child: SizedBox(
                  width: 28,
                  height: 28,
                  child: Image.asset(
                    notificationBellAsset,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
            if (count > 0)
              Positioned(
                right: -4,
                top: -4,
                child: Container(
                  constraints:
                      const BoxConstraints(minWidth: 20, minHeight: 20),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: badgeBg,
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
                      height: 1,
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
    }

    return Align(
      alignment: Alignment.topLeft,
      child: SizedBox(
        width: panelWidth,
        height: panelHeight,
        child: Container(
          clipBehavior: Clip.antiAlias,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(5.32),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                offset: const Offset(0, 3.55),
                blurRadius: 3.55,
                spreadRadius: 0,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  SizedBox(
                    width: 44,
                    height: 44,
                    child: Image.asset(
                      recentDocumentsIconAsset,
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      listTitle,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  _buildBellCountBadge(docs.length),
                ],
              ),
              const SizedBox(height: 12),
              if (_selectedNavIndex == 0)
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _filterChip('Released', 'released'),
                      const SizedBox(width: 10),
                      _filterChip('Signed', 'signed'),
                      const SizedBox(width: 10),
                      _filterChip('Changes Requested', 'changes_requested'),
                    ],
                  ),
                ),
              if (_selectedNavIndex == 0) const SizedBox(height: 12),
              if (docs.isEmpty)
                Text(
                  isDocumentsTab
                      ? 'No signed documents available yet.'
                      : isProposalsTab
                          ? 'No proposals are currently awaiting signature.'
                          : 'No documents available for this link.',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.70)),
                )
              else
                Expanded(
                  child: ListView.separated(
                    itemCount: docs.length > 6 ? 6 : docs.length,
                    separatorBuilder: (_, __) => Divider(
                      height: 14,
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                    itemBuilder: (context, index) {
                      final doc = docs[index];
                      final status = (doc['status'] ?? '').toString();

                      Widget _statusChip(String rawStatus) {
                        final normalizedLabel = _normalizeStatus(rawStatus);
                        final lower = normalizedLabel.toLowerCase().trim();
                        Color bg = Colors.white.withValues(alpha: 0.10);
                        Color fg = Colors.white;
                        String label = normalizedLabel.isEmpty
                            ? (rawStatus.isEmpty ? 'Unknown' : rawStatus)
                            : normalizedLabel;
                        double chipWidth = 87.89;

                        if (lower.contains('signed')) {
                          bg = const Color(0xFF6CA510);
                          fg = Colors.white;
                          chipWidth = 87.89;
                        } else if (lower.contains('pending') ||
                            lower.contains('released') ||
                            lower.contains('sent for signature') ||
                            lower.contains('in review')) {
                          bg = const Color(0xFFEA990C);
                          fg = Colors.white;
                          chipWidth = 88.51;
                          if (lower.contains('pending')) {
                            label = 'Request Sent';
                          }
                        } else if (lower.contains('rejected') ||
                            lower.contains('declined')) {
                          bg = const Color(0xFFE74C3C);
                          fg = Colors.white;
                          chipWidth = 88.51;
                        }

                        return SizedBox(
                          width: chipWidth,
                          height: 23.36,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: bg,
                              borderRadius: BorderRadius.circular(26.06),
                            ),
                            child: Center(
                              child: Text(
                                label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: fg,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  height: 1.0,
                                ),
                              ),
                            ),
                          ),
                        );
                      }

                      final Widget _draftChip = _statusChip('Draft');

                      Widget _viewChip(VoidCallback onPressed) {
                        return SizedBox(
                          width: 48.56,
                          height: 23.36,
                          child: TextButton(
                            style: TextButton.styleFrom(
                              backgroundColor: const Color(0xFF7F7F7F),
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.zero,
                              minimumSize: const Size(48.56, 23.36),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(26.06),
                              ),
                            ),
                            onPressed: onPressed,
                            child: const Text(
                              'VIEW',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                height: 1.0,
                              ),
                            ),
                          ),
                        );
                      }

                      Widget _documentLeadingBadge() {
                        return SizedBox(
                          width: 33,
                          height: 33,
                          child: Image.asset(
                            isProposalsTab
                                ? recentDocumentsIconAsset
                                : managerBadgeAsset,
                            width: 33,
                            height: 33,
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => Icon(
                              Icons.check_box_outline_blank,
                              color: Colors.white70,
                              size: 18,
                            ),
                          ),
                        );
                      }

                      return InkWell(
                        onTap: () {
                          setState(() {
                            _selectedDocument = doc;
                          });
                        },
                        child: Row(
                          children: [
                            _documentLeadingBadge(),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Builder(
                                builder: (context) {
                                  final lead =
                                      '${_documentLabel(doc)} #${doc['id']}';
                                  final rawTitle =
                                      (doc['title'] ?? 'Untitled').toString();

                                  // Figma text treatment: lead is bold small-caps, project part is italic.
                                  return SizedBox(
                                    height: 22,
                                    child: RichText(
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      text: TextSpan(
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontFamily: 'Poppins',
                                          fontSize: 11.5,
                                          height: 1.05,
                                          letterSpacing: 0.11,
                                        ),
                                        children: [
                                          TextSpan(
                                            text: '$lead ',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w700,
                                              fontFeatures: [
                                                ui.FontFeature.enable('smcp')
                                              ],
                                            ),
                                          ),
                                          TextSpan(
                                            text: '- $rawTitle',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w500,
                                              fontStyle: FontStyle.italic,
                                              fontFeatures: [
                                                ui.FontFeature.enable('smcp')
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                            if (isDocumentsTab)
                              TextButton(
                                onPressed: () => _downloadPdfForDocument(doc),
                                style: TextButton.styleFrom(
                                  backgroundColor: const Color(0xFFC10D00),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 6),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                ),
                                child: const Text('Download'),
                              )
                            else if (doc['status'] == 'Draft')
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _draftChip,
                                  const SizedBox(width: 7.84),
                                  _viewChip(() {
                                    setState(() {
                                      _selectedDocument = doc;
                                    });
                                    _openProposal(doc);
                                  }),
                                ],
                              )
                            else
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _statusChip(status),
                                  const SizedBox(width: 7.84),
                                  _viewChip(() => _openProposal(doc)),
                                ],
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRightPanel() {
    final doc = _selectedDocument;

    Widget panelCard({
      required String title,
      required Widget child,
      double? fixedHeight,
    }) {
      final showTitle = title.trim().isNotEmpty;
      final card = Container(
        clipBehavior: Clip.antiAlias,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(5.32),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              offset: const Offset(0, 3.55),
              blurRadius: 3.55,
              spreadRadius: 0,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (showTitle) ...[
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
            ],
            child,
          ],
        ),
      );

      if (fixedHeight != null) {
        return SizedBox(height: fixedHeight, child: card);
      }
      return card;
    }

    return Column(
      children: [
        panelCard(
          title: '',
          fixedHeight: 128,
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(28),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Image.asset(
                    'assets/images/client_icons/HR_Team Management_White Badge_Red.png',
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'Project Chat',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              ElevatedButton(
                onPressed:
                    doc == null ? null : () => _openProposalComments(doc),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFC10D00),
                  disabledBackgroundColor: const Color(0xFFC10D00),
                  foregroundColor: Colors.white,
                  disabledForegroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: const Text('OPEN COMMENTS'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        panelCard(
          title: '',
          fixedHeight: 120,
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(28),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Image.asset(
                    'assets/images/client_icons/Download_Arrow_White Badge_Red.png',
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'Download Document',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              ElevatedButton(
                onPressed:
                    doc == null ? null : () => _downloadPdfForDocument(doc),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFC10D00),
                  disabledBackgroundColor: const Color(0xFFC10D00),
                  foregroundColor: Colors.white,
                  disabledForegroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: const Text('DOWNLOAD PDF'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildComingSoon(String title) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.hourglass_top, color: Colors.white70),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Coming soon. This section is part of the client portal experience but is not enabled in this build.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.75),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProposalsHeaderBar() {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Title
          const Text(
            'Client Portal Proposals',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(width: 12),
          // Greeting
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: RichText(
              text: TextSpan(
                text: 'Hello, ',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.70),
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                ),
                children: [
                  TextSpan(
                    text: _getClientDisplayName(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Spacer(),
          // Message icon
          _buildHeaderIconButton(
            assetPath: 'assets/images/new icons for manager/messages.png',
            onTap: () {},
          ),
          const SizedBox(width: 8),
          // Notification bell with badge
          _buildHeaderIconButton(
            assetPath: 'assets/images/new icons for manager/notifications.png',
            onTap: () {},
            badge: 2,
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderIconButton({
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
          child: SizedBox(
            width: 44.87,
            height: 44.87,
            child: Image.asset(assetPath, fit: BoxFit.contain),
          ),
        ),
        if (badge != null && badge > 0)
          Positioned(
            right: 0,
            top: 0,
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

  String _getClientDisplayName() {
    if (_clientEmail != null && _clientEmail!.isNotEmpty) {
      final namePart = _clientEmail!.split('@')[0];
      // Convert email username to title case (e.g., "john.doe" -> "John Doe")
      final parts = namePart.split('.');
      return parts
          .map((p) =>
              p.isNotEmpty ? '${p[0].toUpperCase()}${p.substring(1)}' : '')
          .join(' ');
    }
    return 'Client';
  }

  Widget _buildChatSupportButton() {
    return FloatingActionButton(
      onPressed: () {
        // Open chat support
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Chat support coming soon!'),
            duration: Duration(seconds: 2),
          ),
        );
      },
      backgroundColor: const Color(0xFFC10D00),
      mini: true,
      child: const Icon(
        Icons.support_agent,
        color: Colors.white,
        size: 24,
      ),
    );
  }

  Widget _buildProposalsContentCard() {
    final docs = _filteredDocuments();

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0x24FFFFFF),
        borderRadius: BorderRadius.circular(5.32),
        boxShadow: [
          BoxShadow(
            color: const Color(0x40000000),
            blurRadius: 3.55,
            offset: const Offset(0, 3.55),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header with handshake icon, title, subtitle, and search
          Padding(
            padding: const EdgeInsets.all(20),
            child: _buildProposalsSectionHeader(),
          ),
          // Divider
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Divider(
              color: Colors.white.withValues(alpha: 0.15),
              height: 1,
              thickness: 1,
            ),
          ),
          // List
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 400),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
              child: _buildProposalsList(docs),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProposalsContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header bar with title, greeting, and notification icons
        _buildProposalsHeaderBar(),
        const SizedBox(height: 20),
        // Main content card
        _buildProposalsContentCard(),
        const SizedBox(height: 12),
        // Version label outside the card
        Container(
          width: 115,
          height: 18,
          decoration: BoxDecoration(
            color: const Color(0xFF3D3D3D),
            borderRadius: BorderRadius.circular(4),
          ),
          alignment: Alignment.center,
          child: const Text(
            'Ver 2025.03.AA1_SIT',
            style: TextStyle(
              fontSize: 9,
              color: Colors.white70,
              height: 1,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProposalsSectionHeader() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Proposal icon (matching manager design)
        Image.asset(
          'assets/images/new icons for manager/Draft proposal.png',
          width: 56,
          height: 56,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(28),
            ),
            child: const Icon(
              Icons.handshake_outlined,
              color: Colors.white,
              size: 32,
            ),
          ),
        ),
        const SizedBox(width: 16),
        // Title and subtitle
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Proposals Awaiting Signature',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  letterSpacing: 0.2,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'The following proposal documents are waiting on your attention and action.',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withValues(alpha: 0.70),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 18),
        // Search bar with red magnifying glass
        _buildSearchBar(),
      ],
    );
  }

  Widget _buildSearchBar() {
    return SizedBox(
      width: 245,
      height: 43,
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
          // Red magnifying glass icon
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
    );
  }

  Widget _buildProposalsList(List<Map<String, dynamic>> docs) {
    if (_isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFC10D00)),
          ),
        ),
      );
    }

    if (docs.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.description_outlined,
                size: 64, color: Colors.white.withValues(alpha: 0.5)),
            const SizedBox(height: 16),
            Text(
              'No proposals are currently awaiting signature.',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white.withValues(alpha: 0.70),
              ),
            ),
          ],
        ),
      );
    }

    return Scrollbar(
      controller: _proposalsScrollController,
      thumbVisibility: true,
      trackVisibility: true,
      thickness: 6,
      radius: const Radius.circular(3),
      child: ListView.builder(
        controller: _proposalsScrollController,
        itemCount: docs.length,
        itemBuilder: (context, index) {
          final doc = docs[index];
          return _buildProposalListItem(doc);
        },
      ),
    );
  }

  Widget _buildProposalListItem(Map<String, dynamic> doc) {
    final status = (doc['status'] ?? '').toString();
    final title = (doc['title'] ?? 'Untitled Proposal').toString();
    final clientName =
        (doc['client_name'] ?? _clientEmail ?? 'Unknown Client').toString();
    final proposalId = doc['id']?.toString() ?? '';

    // Status colors and labels matching manager design
    Color statusBgColor;
    Color statusColor = Colors.white;
    String statusLabel;

    final lowerStatus = status.toLowerCase();
    if (lowerStatus.contains('sent for approval') ||
        lowerStatus.contains('approval requested')) {
      statusBgColor = const Color(0xFF6CA510); // Green
      statusLabel = 'Sent for Approval';
    } else if (lowerStatus.contains('awaiting signature') ||
        lowerStatus.contains('sent to client')) {
      statusBgColor = const Color(0xFF6095CC); // Blue
      statusLabel = 'Awaiting Signature';
    } else if (lowerStatus.contains('released') ||
        lowerStatus.contains('sent')) {
      statusBgColor = const Color(0xFFEA990C); // Orange
      statusLabel = 'Released';
    } else if (lowerStatus.contains('draft')) {
      statusBgColor = const Color(0xFF5C389D); // Purple
      statusLabel = 'Drafted';
    } else if (lowerStatus.contains('signed') ||
        lowerStatus.contains('approved')) {
      statusBgColor = const Color(0xFF6CA510); // Green
      statusLabel = 'Signed';
    } else if (lowerStatus.contains('declined') ||
        lowerStatus.contains('rejected')) {
      statusBgColor = const Color(0xFFE74C3C); // Red
      statusLabel = 'Declined';
    } else {
      statusBgColor = const Color(0xFF4B5563); // Gray
      statusLabel = status.isEmpty ? 'Unknown' : status;
    }

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
            errorBuilder: (_, __, ___) => Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFFC10D00).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child:
                  const Icon(Icons.description, color: Colors.white, size: 20),
            ),
          ),
          const SizedBox(width: 16),
          // Title and Description
          Expanded(
            flex: 3,
            child: RichText(
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              text: TextSpan(
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                  height: 9.38 / 11,
                  letterSpacing: 0.11,
                  color: Colors.white,
                ),
                children: [
                  TextSpan(
                    text: title,
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      height: 9.38 / 13,
                      letterSpacing: 0.13,
                      color: Colors.white,
                    ),
                  ),
                  TextSpan(
                    text: ' - $clientName',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w500,
                      fontSize: 13,
                      height: 9.38 / 13,
                      letterSpacing: 0.13,
                      color: Colors.white.withValues(alpha: 0.70),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 16),
          // Last Modified
          SizedBox(
            width: 160,
            child: Text(
              'Last Modified: ${_formatDate(doc['updated_at'] ?? doc['updatedAt'])}',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w500,
                fontSize: 10.5,
                height: 9.38 / 10.5,
                letterSpacing: 0.105,
                color: Colors.white.withValues(alpha: 0.70),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.left,
            ),
          ),
          const SizedBox(width: 16),
          // Status badge
          SizedBox(
            width: 130,
            height: 26,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: statusBgColor,
                borderRadius: BorderRadius.circular(26),
              ),
              child: Center(
                child: Text(
                  statusLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: statusColor,
                    height: 1,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          // VIEW button
          SizedBox(
            width: 80,
            height: 32,
            child: OutlinedButton(
              onPressed: () {
                setState(() {
                  _selectedDocument = doc;
                });
                _openSigningUrl(doc);
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: const Color(0xFF4B5563),
                side: BorderSide.none,
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: const Text(
                'VIEW',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainLeftContent() {
    if (_isOverviewDashboard) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSummaryTiles(),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              const rightPanelWidth = 420.0;
              final leftPanelWidth =
                  (constraints.maxWidth - rightPanelWidth - 16)
                      .clamp(520.0, 620.0);
              final stackLowerCards = constraints.maxWidth < 980;
              if (stackLowerCards) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildRecentDocuments(
                      width: constraints.maxWidth,
                      height: 380,
                    ),
                    const SizedBox(height: 14),
                    SizedBox(width: rightPanelWidth, child: _buildRightPanel()),
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildRecentDocuments(
                    width: leftPanelWidth,
                    height: 380,
                  ),
                  const SizedBox(width: 16),
                  SizedBox(width: rightPanelWidth, child: _buildRightPanel()),
                ],
              );
            },
          ),
        ],
      );
    }

    if (!widget.showSummary && _selectedNavIndex == 1) {
      return _buildProposalsContent();
    }

    if (_selectedNavIndex == 0 ||
        _selectedNavIndex == 1 ||
        _selectedNavIndex == 2) {
      if (_selectedNavIndex == 2) {
        return LayoutBuilder(
          builder: (context, constraints) {
            final maxWidth = constraints.maxWidth;
            final targetWidth = (maxWidth).clamp(620.0, maxWidth);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildRecentDocuments(
                  width: targetWidth,
                  height: 420,
                ),
              ],
            );
          },
        );
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.showSummary) ...[
            _buildSummaryTiles(),
            const SizedBox(height: 16),
          ],
          _buildRecentDocuments(),
        ],
      );
    }

    final titles = {
      3: 'Profile',
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSummaryTiles(),
        const SizedBox(height: 16),
        _buildComingSoon(titles[_selectedNavIndex] ?? 'Coming Soon'),
      ],
    );
  }

  void _extractTokenAndLoad() {
    String? token = widget.initialToken;

    try {
      final currentUrl = web.window.location.href;
      final uri = Uri.parse(currentUrl);

      if (token == null || token.isEmpty) {
        // Try multiple ways to extract token
        token = uri.queryParameters['token'];
      }

      if ((token == null || token.isEmpty) && uri.fragment.isNotEmpty) {
        final fragment = uri.fragment;
        if (fragment.contains('token=')) {
          final queryStart = fragment.indexOf('?');
          if (queryStart != -1) {
            final queryString = fragment.substring(queryStart + 1);
            final params = Uri.splitQueryString(queryString);
            token = params['token'];
          }
        }
      }

      if (token == null || token.isEmpty) {
        final hash = web.window.location.hash;
        if (hash.contains('token=')) {
          final tokenMatch = RegExp(r'token=([^&]+)').firstMatch(hash);
          if (tokenMatch != null) {
            token = tokenMatch.group(1);
          }
        }
      }
    } catch (e) {
      print('âŒ Error parsing URL: $e');
    }

    if (token == null || token.isEmpty) {
      setState(() {
        _error = 'No access token provided';
        _isLoading = false;
      });
      return;
    }

    token = _sanitizeToken(token);
    if (token.isEmpty) {
      setState(() {
        _error = 'No access token provided';
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _accessToken = token;
    });

    _deviceId = _getOrCreateDeviceId();
    _loadCachedClientSession();

    _loadClientProposals();
  }

  Future<void> _loadClientProposals() async {
    if (_loadProposalsFuture != null) {
      return _loadProposalsFuture!;
    }

    _loadProposalsFuture = _loadClientProposalsInternal().whenComplete(() {
      _loadProposalsFuture = null;
    });

    return _loadProposalsFuture!;
  }

  Future<void> _loadClientProposalsInternal() async {
    if (_accessToken == null) return;

    final token = _sanitizeToken(_accessToken!);
    if (token.isEmpty) {
      setState(() {
        _error = 'No access token provided';
        _isLoading = false;
      });
      return;
    }

    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _loadingStartedAt = DateTime.now();
      _error = null;
    });

    final epochAtSend = _clientSessionEpoch;
    try {
      final uri = Uri.parse('$baseUrl/api/client/proposals').replace(
        queryParameters: {
          'token': token,
          if (_deviceId != null && _deviceId!.isNotEmpty)
            'device_id': _deviceId!,
          if (_clientSessionToken != null && _clientSessionToken!.isNotEmpty)
            'session_token': _clientSessionToken!,
        },
      );
      final response = await http.get(
        uri,
        headers: {
          if (_deviceId != null) 'X-Client-Device-Id': _deviceId!,
          if (_clientSessionToken != null)
            'X-Client-Session-Token': _clientSessionToken!,
        },
      ).timeout(
        const Duration(seconds: 8),
        onTimeout: () {
          throw TimeoutException('Request timed out');
        },
      );

      print(
          '[ClientPortal] proposals status=${response.statusCode} device_id=${_deviceId ?? ""} session_token_present=${(_clientSessionToken ?? "").isNotEmpty}');

      if (!mounted) return;
      if (epochAtSend != _clientSessionEpoch) {
        // OTP (or another tab) rotated the session while this request was in flight.
        if ((_clientSessionToken ?? '').trim().isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _loadClientProposals();
          });
        }
        return;
      }

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is! Map) {
          throw Exception('Unexpected response format');
        }
        final data = Map<String, dynamic>.from(decoded);
        final proposalsRaw = data['proposals'];
        if (proposalsRaw is! List) {
          throw Exception('Invalid token response (missing proposals)');
        }
        print(
            '[ClientPortal] proposals decoded ok count=${proposalsRaw.length}');

        List<Map<String, dynamic>> parsedProposals;
        try {
          parsedProposals = proposalsRaw
              .whereType<Map>()
              .map((p) => Map<String, dynamic>.from(p))
              .toList();
        } catch (e) {
          throw Exception('Failed to parse proposals: $e');
        }

        if (parsedProposals.length != proposalsRaw.length) {
          throw Exception(
              'Invalid proposals payload (expected ${proposalsRaw.length} items, got ${parsedProposals.length} objects)');
        }

        if (!mounted) return;
        setState(() {
          _clientEmail = data['client_email'];
          _proposals = parsedProposals;

          if (_selectedDocument != null) {
            final selId = _selectedDocument?['id']?.toString();
            final updated = _proposals
                .where((p) => p['id']?.toString() == selId)
                .cast<Map<String, dynamic>>()
                .toList();
            if (updated.isNotEmpty) {
              _selectedDocument = updated.first;
            }
          }

          // Calculate status counts
          _statusCounts = {
            'pending': 0,
            'approved': 0,
            'rejected': 0,
            'viewed': 0,
          };

          for (var proposal in _proposals) {
            final status = (proposal['status'] as String? ?? '');
            final key = _groupStatusForCounts(status);
            _statusCounts[key] = (_statusCounts[key] ?? 0) + 1;
          }

          _isLoading = false;
        });

        if (_isOverviewDashboard) {
          await _loadDashboardOverview();
        }
      } else if (response.statusCode == 428) {
        Map<String, dynamic>? decoded;
        try {
          final body = jsonDecode(response.body);
          if (body is Map) {
            decoded = Map<String, dynamic>.from(body);
          }
        } catch (_) {}

        final requiresDeviceSession =
            decoded?['requires_device_session'] == true;
        if (requiresDeviceSession) {
          if (!mounted) return;
          setState(() {
            _isLoading = true;
            _loadingStartedAt = DateTime.now();
            _error = null;
          });

          await _ensureMinLoadingTime(const Duration(milliseconds: 1200));
          await _ensureDeviceVerifiedAndRetry(token: token);

          // Verification may have completed in another widget instance.
          // Refresh from localStorage so this instance picks up the session token.
          _loadCachedClientSession();

          if (!mounted) return;
          if ((_clientSessionToken ?? '').trim().isEmpty) {
            setState(() {
              _error = 'Device verification required. Please retry.';
              _isLoading = false;
            });
            return;
          }

          // Verification succeeded; retry proposals fetch now that we have a session token.
          await _loadClientProposalsInternal();
          return;
        }

        if (!mounted) return;
        setState(() {
          _error = decoded?['detail']?.toString() ??
              'Unable to open client dashboard.';
          _isLoading = false;
        });
      } else if (response.statusCode == 423) {
        Map<String, dynamic>? decoded;
        try {
          final body = jsonDecode(response.body);
          if (body is Map) {
            decoded = Map<String, dynamic>.from(body);
          }
        } catch (_) {}
        if (!mounted) return;
        setState(() {
          _error = decoded?['detail']?.toString() ??
              'Access locked due to too many failed attempts.';
          _isLoading = false;
        });
      } else {
        Map<String, dynamic>? error;
        try {
          final decoded = jsonDecode(response.body);
          if (decoded is Map) {
            error = Map<String, dynamic>.from(decoded);
          }
        } catch (_) {}
        if (!mounted) return;
        setState(() {
          _error = error?['detail'] ??
              'Failed to load proposals (HTTP ${response.statusCode})';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      // Ignore errors from superseded session fetches (e.g. OTP completed in parallel).
      if (epochAtSend != _clientSessionEpoch) {
        if ((_clientSessionToken ?? '').trim().isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _loadClientProposals();
          });
        }
        return;
      }
      setState(() {
        _error = e is TimeoutException
            ? 'This link timed out. Please retry or ask the sender to resend it.'
            : 'Error: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadDashboardOverview() async {
    final token = _accessToken;
    if (token == null || token.isEmpty) return;

    if (!mounted) return;
    setState(() {
      _overviewLoading = true;
      _overviewError = null;
    });

    try {
      final clean = _sanitizeToken(token);
      final uri = Uri.parse('$baseUrl/api/client/dashboard/overview').replace(
        queryParameters: {
          'token': clean,
          if (_deviceId != null && _deviceId!.isNotEmpty)
            'device_id': _deviceId!,
          if (_clientSessionToken != null && _clientSessionToken!.isNotEmpty)
            'session_token': _clientSessionToken!,
        },
      );

      final resp = await http.get(
        uri,
        headers: {
          if (_deviceId != null) 'X-Client-Device-Id': _deviceId!,
          if (_clientSessionToken != null)
            'X-Client-Session-Token': _clientSessionToken!,
        },
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw TimeoutException('Request timed out'),
      );

      Map<String, dynamic>? decoded;
      try {
        final body = jsonDecode(resp.body);
        if (body is Map) decoded = Map<String, dynamic>.from(body);
      } catch (_) {}

      if (resp.statusCode != 200) {
        final msg = decoded?['detail']?.toString() ??
            'Failed to load dashboard (HTTP ${resp.statusCode})';
        if (!mounted) return;
        setState(() {
          _overviewError = msg;
          _overviewLoading = false;
        });
        return;
      }

      if (!mounted) return;
      setState(() {
        _overview = decoded;
        _overviewLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _overviewError = e is TimeoutException
            ? 'Dashboard request timed out. Please retry.'
            : 'Error: $e';
        _overviewLoading = false;
      });
    }
  }

  int _kpi(String key) {
    final kpis = _overview?['kpis'];
    if (kpis is Map && kpis[key] != null) {
      return int.tryParse(kpis[key].toString()) ?? 0;
    }
    return 0;
  }

  int _pipe(String key) {
    final pipe = _overview?['pipeline'];
    if (pipe is Map && pipe[key] != null) {
      return int.tryParse(pipe[key].toString()) ?? 0;
    }
    return 0;
  }

  List<Map<String, dynamic>> _activity() {
    final a = _overview?['activity'];
    if (a is List) {
      return a.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    return [];
  }

  List<Map<String, dynamic>> _trend() {
    final analytics = _overview?['analytics'];
    if (analytics is Map) {
      final t = analytics['trend'];
      if (t is List) {
        return t.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
    }
    return [];
  }

  Map<String, int> _conversionBreakdown() {
    final analytics = _overview?['analytics'];
    if (analytics is Map) {
      final b = analytics['conversion_breakdown'];
      if (b is Map) {
        return {
          'signed': int.tryParse(b['signed']?.toString() ?? '0') ?? 0,
          'rejected': int.tryParse(b['rejected']?.toString() ?? '0') ?? 0,
          'requested_changes':
              int.tryParse(b['requested_changes']?.toString() ?? '0') ?? 0,
        };
      }
    }
    return {'signed': 0, 'rejected': 0, 'requested_changes': 0};
  }

  String _timeAgo(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inSeconds < 45) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours} hours ago';
    if (diff.inDays < 7) return '${diff.inDays} days ago';
    final weeks = (diff.inDays / 7).floor();
    if (weeks < 5) return '${weeks} weeks ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  IconData _activityIcon(String eventType) {
    final e = eventType.toLowerCase().trim();
    if (e.contains('view') || e.contains('open'))
      return Icons.visibility_outlined;
    if (e.contains('sign')) return Icons.check_circle_outline;
    if (e.contains('download')) return Icons.download_outlined;
    if (e.contains('comment') || e.contains('change')) {
      return Icons.mode_comment_outlined;
    }
    return Icons.bolt_outlined;
  }

  String _activityLabel(Map<String, dynamic> a) {
    final proposalId = a['proposal_id']?.toString();
    final event = (a['event_type'] ?? '').toString();
    final ev = event.toLowerCase().trim();
    String verb;
    if (ev.contains('view') || ev.contains('open')) {
      verb = 'viewed';
    } else if (ev.contains('sign')) {
      verb = 'signed';
    } else if (ev.contains('download')) {
      verb = 'downloaded';
    } else if (ev.contains('comment')) {
      verb = 'commented';
    } else if (ev.contains('change')) {
      verb = 'requested changes';
    } else {
      verb = event.isEmpty ? 'updated' : event;
    }
    if (proposalId == null || proposalId.isEmpty) return 'Proposal $verb';
    return 'Proposal #$proposalId $verb';
  }

  Widget _sectionCard({required String title, required Widget child}) {
    return GlassContainer(
      borderRadius: 18,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _buildKpiCards() {
    final cards = [
      (
        'Active Proposals',
        _kpi('active_proposals').toString(),
        Icons.play_circle_outline,
        PremiumTheme.blueGradient,
        '/client/proposals'
      ),
      (
        'Signed Proposals',
        _kpi('signed_proposals').toString(),
        Icons.check_circle_outline,
        PremiumTheme.tealGradient,
        '/client/proposals'
      ),
      (
        'Requested for Change',
        _kpi('requested_changes').toString(),
        Icons.edit_note,
        PremiumTheme.orangeGradient,
        '/client/proposals'
      ),
      (
        'Rejected Proposals',
        _kpi('rejected_proposals').toString(),
        Icons.cancel_outlined,
        PremiumTheme.redGradient,
        '/client/proposals'
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < 980;
        final children = cards
            .map(
              (c) => SizedBox(
                width:
                    narrow ? double.infinity : (constraints.maxWidth - 48) / 4,
                height: 109,
                child: PremiumStatCard(
                  title: c.$1,
                  value: c.$2,
                  subtitle: null,
                  icon: c.$3,
                  gradient: c.$4,
                  onTap: () => _navigateClient(c.$5),
                ),
              ),
            )
            .toList();

        if (narrow) {
          return Column(
            children: [
              for (int i = 0; i < children.length; i++) ...[
                children[i],
                if (i != children.length - 1) const SizedBox(height: 12),
              ]
            ],
          );
        }

        return Row(
          children: [
            for (int i = 0; i < children.length; i++) ...[
              Expanded(child: children[i]),
              if (i != children.length - 1) const SizedBox(width: 12),
            ]
          ],
        );
      },
    );
  }

  Widget _buildPipelineOverview() {
    final active = _pipe('active');
    final changes = _pipe('requested_changes');
    final signed = _pipe('signed');
    final rejected = _pipe('rejected');
    final total = _pipe('total');
    final denom = total <= 0 ? 1 : total;

    Widget segment({
      required int count,
      required Color color,
      required String label,
    }) {
      final flex =
          (count <= 0) ? 0 : (count * 1000 / denom).round().clamp(1, 1000);
      if (count <= 0) {
        return const SizedBox.shrink();
      }
      return Expanded(
        flex: flex,
        child: Container(
          height: 14,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(999),
          ),
        ),
      );
    }

    Widget pill(String label, int count, Color color) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '$label: $count',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.85),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    return _sectionCard(
      title: 'Pipeline Overview',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              segment(count: active, color: PremiumTheme.info, label: 'Active'),
              const SizedBox(width: 6),
              segment(
                  count: changes,
                  color: PremiumTheme.warning,
                  label: 'Changes'),
              const SizedBox(width: 6),
              segment(
                  count: signed, color: PremiumTheme.success, label: 'Signed'),
              const SizedBox(width: 6),
              segment(
                  count: rejected,
                  color: PremiumTheme.error,
                  label: 'Rejected'),
              if (active + changes + signed + rejected == 0)
                Expanded(
                  child: Container(
                    height: 14,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              pill('Active', active, PremiumTheme.info),
              pill('Requested Changes', changes, PremiumTheme.warning),
              pill('Signed', signed, PremiumTheme.success),
              pill('Rejected', rejected, PremiumTheme.error),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRecentActivity() {
    final items = _activity();
    return _sectionCard(
      title: 'Recent Activity',
      child: Column(
        children: [
          if (items.isEmpty)
            Text(
              _overviewLoading
                  ? 'Loading activity...'
                  : 'No recent activity yet.',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.70)),
            )
          else
            for (int i = 0; i < items.length; i++) ...[
              Builder(
                builder: (context) {
                  final a = items[i];
                  DateTime? created;
                  try {
                    final raw = a['created_at']?.toString();
                    if (raw != null && raw.isNotEmpty) {
                      created = DateTime.parse(raw);
                    }
                  } catch (_) {}

                  final eventType = (a['event_type'] ?? '').toString();
                  return Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Row(
                      children: [
                        Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: Colors.white.withValues(alpha: 0.10)),
                          ),
                          child: Icon(
                            _activityIcon(eventType),
                            size: 18,
                            color: Colors.white.withValues(alpha: 0.85),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _activityLabel(a),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                created == null
                                    ? ''
                                    : _timeAgo(created.toLocal()),
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.60),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
              if (i != items.length - 1)
                Divider(color: Colors.white.withValues(alpha: 0.06), height: 1),
            ],
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return _sectionCard(
      title: 'Quick Actions',
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => _navigateClient('/client/proposals'),
              icon: const Icon(Icons.description_outlined, size: 18),
              label: const Text('View Proposals'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => _navigateClient('/client/documents'),
              icon: const Icon(Icons.folder_outlined, size: 18),
              label: const Text('Download Documents'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrendChart() {
    final points = _trend();
    if (points.isEmpty) {
      return _sectionCard(
        title: 'Proposals Trend',
        child: Text(
          _overviewLoading ? 'Loading trend...' : 'No trend data yet.',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.70)),
        ),
      );
    }

    final created = <FlSpot>[];
    final signed = <FlSpot>[];
    final rejected = <FlSpot>[];
    for (int i = 0; i < points.length; i++) {
      final p = points[i];
      created.add(FlSpot(i.toDouble(), (p['created'] ?? 0).toDouble()));
      signed.add(FlSpot(i.toDouble(), (p['signed'] ?? 0).toDouble()));
      rejected.add(FlSpot(i.toDouble(), (p['rejected'] ?? 0).toDouble()));
    }

    String bottomTitle(double value) {
      final idx = value.round();
      if (idx < 0 || idx >= points.length) return '';
      final raw = points[idx]['period']?.toString();
      if (raw == null || raw.isEmpty) return '';
      try {
        final dt = DateTime.parse(raw);
        return '${dt.day}/${dt.month}';
      } catch (_) {
        return '';
      }
    }

    return _sectionCard(
      title: 'Proposals Trend',
      child: SizedBox(
        height: 240,
        child: LineChart(
          LineChartData(
            gridData: const FlGridData(show: false),
            borderData: FlBorderData(show: false),
            titlesData: FlTitlesData(
              topTitles:
                  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles:
                  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 34,
                  interval: 1,
                  getTitlesWidget: (v, meta) => Text(
                    v.toInt().toString(),
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.60),
                        fontSize: 11),
                  ),
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 28,
                  interval: (points.length / 4).ceilToDouble().clamp(1, 999),
                  getTitlesWidget: (v, meta) => Text(
                    bottomTitle(v),
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.60),
                        fontSize: 11),
                  ),
                ),
              ),
            ),
            lineBarsData: [
              LineChartBarData(
                spots: created,
                isCurved: true,
                barWidth: 3,
                color: PremiumTheme.cyan,
                dotData: const FlDotData(show: false),
              ),
              LineChartBarData(
                spots: signed,
                isCurved: true,
                barWidth: 3,
                color: PremiumTheme.success,
                dotData: const FlDotData(show: false),
              ),
              LineChartBarData(
                spots: rejected,
                isCurved: true,
                barWidth: 3,
                color: PremiumTheme.error,
                dotData: const FlDotData(show: false),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildConversionChart() {
    final b = _conversionBreakdown();
    final signed = b['signed'] ?? 0;
    final rejected = b['rejected'] ?? 0;
    final changes = b['requested_changes'] ?? 0;
    final total = signed + rejected + changes;
    if (total <= 0) {
      return _sectionCard(
        title: 'Conversion Breakdown',
        child: Text(
          _overviewLoading ? 'Loading breakdown...' : 'No conversion data yet.',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.70)),
        ),
      );
    }

    return _sectionCard(
      title: 'Conversion Breakdown',
      child: SizedBox(
        height: 220,
        child: Row(
          children: [
            Expanded(
              child: PieChart(
                PieChartData(
                  sectionsSpace: 3,
                  centerSpaceRadius: 36,
                  sections: [
                    PieChartSectionData(
                      value: signed.toDouble(),
                      color: PremiumTheme.success,
                      title: '',
                      radius: 62,
                    ),
                    PieChartSectionData(
                      value: rejected.toDouble(),
                      color: PremiumTheme.error,
                      title: '',
                      radius: 62,
                    ),
                    PieChartSectionData(
                      value: changes.toDouble(),
                      color: PremiumTheme.warning,
                      title: '',
                      radius: 62,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 170,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _legendRow('Signed', signed, PremiumTheme.success),
                  const SizedBox(height: 10),
                  _legendRow('Rejected', rejected, PremiumTheme.error),
                  const SizedBox(height: 10),
                  _legendRow(
                      'Requested Changes', changes, PremiumTheme.warning),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _legendRow(String label, int value, Color color) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
              color: color, borderRadius: BorderRadius.circular(99)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.80), fontSize: 12),
          ),
        ),
        Text(
          value.toString(),
          style:
              const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
        ),
      ],
    );
  }

  Future<void> _openProposal(Map<String, dynamic> proposal) async {
    final rawId = proposal['id'];
    final proposalId =
        rawId is int ? rawId : int.tryParse(rawId?.toString() ?? '');
    if (proposalId == null || _accessToken == null || _accessToken!.isEmpty) {
      print(
          '[ClientDashboardHome] Cannot open proposal: invalid id=$rawId tokenPresent=${_accessToken != null && _accessToken!.isNotEmpty}');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unable to open proposal (missing proposal id).'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    final statusLower = (proposal['status'] ?? '').toString().toLowerCase();
    final isSigned = statusLower.contains('client signed') ||
        (statusLower.contains('signed') && !statusLower.contains('sent'));

    if (!isSigned) {
      try {
        final uri = Uri.parse(
            '$baseUrl/api/client/proposals/$proposalId/docusign/signing-url');
        final resp = await http
            .post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'token': _accessToken,
            'signer_name':
                (proposal['client_name']?.toString().trim().isNotEmpty ?? false)
                    ? proposal['client_name']?.toString().trim()
                    : (_clientEmail ?? '').trim(),
          }),
        )
            .timeout(
          const Duration(seconds: 12),
          onTimeout: () {
            throw TimeoutException('Signing URL request timed out');
          },
        );

        Map<String, dynamic>? decoded;
        try {
          final body = jsonDecode(resp.body);
          if (body is Map) {
            decoded = Map<String, dynamic>.from(body);
          }
        } catch (_) {}

        if (resp.statusCode >= 200 && resp.statusCode < 300) {
          final fresh = decoded?['signing_url']?.toString() ?? '';
          if (fresh.trim().isNotEmpty) {
            final uri = Uri.tryParse(fresh);
            if (uri != null) {
              if (kIsWeb) {
                web.window.location.href = fresh;
              } else {
                await launchUrlString(fresh,
                    mode: LaunchMode.externalApplication);
              }
            }
            return;
          }
        }

        final fallbackSigningUrl = proposal['signing_url']?.toString() ?? '';
        if (fallbackSigningUrl.trim().isNotEmpty) {
          final uri = Uri.tryParse(fallbackSigningUrl);
          if (uri != null) {
            if (kIsWeb) {
              web.window.location.href = fallbackSigningUrl;
            } else {
              await launchUrlString(fallbackSigningUrl,
                  mode: LaunchMode.externalApplication);
            }
          }
          return;
        }

        if (mounted) {
          final msg = decoded?['detail']?.toString() ??
              'Unable to open DocuSign (HTTP ${resp.statusCode}).';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(msg), backgroundColor: Colors.red),
          );
        }
      } catch (e) {
        final fallbackSigningUrl = proposal['signing_url']?.toString() ?? '';
        if (fallbackSigningUrl.trim().isNotEmpty) {
          final uri = Uri.tryParse(fallbackSigningUrl);
          if (uri != null) {
            if (kIsWeb) {
              web.window.location.href = fallbackSigningUrl;
            } else {
              await launchUrlString(fallbackSigningUrl,
                  mode: LaunchMode.externalApplication);
            }
          }
          return;
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Unable to open DocuSign: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }

    print('[ClientDashboardHome] Opening proposal in app: id=$proposalId');

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ClientProposalViewer(
          proposalId: proposalId,
          accessToken: _accessToken!,
        ),
      ),
    ).then((_) {
      if (!mounted) return;
      _loadClientProposals();
    });
  }

  void _openProposalComments(Map<String, dynamic> proposal) {
    final rawId = proposal['id'];
    final proposalId =
        rawId is int ? rawId : int.tryParse(rawId?.toString() ?? '');
    if (proposalId == null || _accessToken == null || _accessToken!.isEmpty) {
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ClientProposalViewer(
          proposalId: proposalId,
          accessToken: _accessToken!,
          initialTab: 1,
        ),
      ),
    ).then((_) {
      if (!mounted) return;
      _loadClientProposals();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _proposalsScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      final w = MediaQuery.sizeOf(context).width;
      final logoHeight = (w * 0.10).clamp(56.0, 120.0);
      final loaderHeight = (w * 0.08).clamp(40.0, 90.0);
      final isLightMode = _isLightMode;
      final bgAsset = isLightMode
          ? 'assets/images/light_mode_bg.png'
          : 'assets/images/client_dashboard_bg.png';
      final loaderAsset = isLightMode
          ? 'assets/images/Red_Discs.png'
          : 'assets/images/White_khono_loading.png.png';
      final overlayGradient = isLightMode
          ? LinearGradient(
              colors: [
                Colors.white.withValues(alpha: 0.50),
                Colors.white.withValues(alpha: 0.15),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            )
          : LinearGradient(
              colors: [
                Colors.black.withValues(alpha: 0.65),
                Colors.black.withValues(alpha: 0.35),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            );
      return Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          fit: StackFit.expand,
          children: [
            Positioned.fill(
              child: Image.asset(
                bgAsset,
                fit: BoxFit.cover,
              ),
            ),
            Container(
              decoration: BoxDecoration(
                gradient: overlayGradient,
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 14,
                ),
                child: Stack(
                  children: [
                    Align(
                      alignment: Alignment.topCenter,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 18),
                        child: Image.asset(
                          'assets/images/Landingscreen.png',
                          height: logoHeight,
                          fit: BoxFit.contain,
                          filterQuality: FilterQuality.high,
                        ),
                      ),
                    ),
                    Center(
                      child: Text(
                        'Loading your proposals ...',
                        style: TextStyle(
                          color: isLightMode ? Colors.black : Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Align(
                      alignment: Alignment.bottomLeft,
                      child: Padding(
                        padding: const EdgeInsets.only(left: 10, bottom: 10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.35),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.18),
                            ),
                          ),
                          child: const Text(
                            'Ver 2025.03.AA1_SIT',
                            style: TextStyle(
                              fontSize: 9,
                              color: Colors.white70,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Align(
                      alignment: Alignment.bottomRight,
                      child: Padding(
                        padding: const EdgeInsets.only(
                          right: 10,
                          bottom: 10,
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () {
                              setState(() {
                                _isLightMode = !_isLightMode;
                              });
                            },
                            borderRadius: BorderRadius.circular(18),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 8),
                              decoration: BoxDecoration(
                                color:
                                    (isLightMode ? Colors.white : Colors.black)
                                        .withValues(alpha: 0.35),
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: (isLightMode
                                          ? Colors.black
                                          : Colors.white)
                                      .withValues(alpha: 0.18),
                                ),
                              ),
                              child: Icon(
                                isLightMode
                                    ? Icons.dark_mode_outlined
                                    : Icons.light_mode_outlined,
                                size: 16,
                                color:
                                    isLightMode ? Colors.black : Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Image.asset(
                          loaderAsset,
                          height: loaderHeight,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (_error != null) {
      final w = MediaQuery.sizeOf(context).width;
      final loaderHeight = (w * 0.08).clamp(40.0, 90.0);
      final isLightMode = _isLightMode;
      final bgAsset = isLightMode
          ? 'assets/images/light_mode_bg.png'
          : 'assets/images/client_dashboard_bg.png';
      final loaderAsset = isLightMode
          ? 'assets/images/Red_Discs.png'
          : 'assets/images/White_khono_loading.png.png';
      final overlayGradient = isLightMode
          ? LinearGradient(
              colors: [
                Colors.white.withValues(alpha: 0.50),
                Colors.white.withValues(alpha: 0.15),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            )
          : LinearGradient(
              colors: [
                Colors.black.withValues(alpha: 0.65),
                Colors.black.withValues(alpha: 0.35),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            );

      final errorText = _error ?? '';
      final lower = errorText.toLowerCase();
      final headline = lower.contains('timed') || lower.contains('expired')
          ? 'Link Timed Out!'
          : 'Device Verification Required';
      final subtitle = lower.contains('timed') || lower.contains('expired')
          ? 'Please retry, alternatively contact the sender for a refreshed link.'
          : 'Please retry, alternatively contact the sender for a refreshed link.';

      return Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          fit: StackFit.expand,
          children: [
            Positioned.fill(
              child: Image.asset(
                bgAsset,
                fit: BoxFit.cover,
              ),
            ),
            Container(
              decoration: BoxDecoration(
                gradient: overlayGradient,
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 14,
                ),
                child: Stack(
                  children: [
                    Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 640),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Image.asset(
                              'assets/images/client_icons/Warning Error_White Badge_Red.png',
                              width: 88,
                              height: 88,
                              fit: BoxFit.contain,
                              filterQuality: FilterQuality.high,
                              errorBuilder: (_, __, ___) => const Icon(
                                Icons.warning_amber_rounded,
                                size: 88,
                                color: Color(0xFFC10D00),
                              ),
                            ),
                            const SizedBox(height: 14),
                            Text(
                              headline,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color:
                                    isLightMode ? Colors.black : Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              subtitle,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: isLightMode
                                    ? Colors.black87
                                    : Colors.white70,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 22),
                            SizedBox(
                              width: 160,
                              height: 40,
                              child: ElevatedButton(
                                onPressed: () => _loadClientProposals(),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFC10D00),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                ),
                                child: const Text(
                                  'RETRY',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Align(
                      alignment: Alignment.bottomLeft,
                      child: Padding(
                        padding: const EdgeInsets.only(left: 10, bottom: 10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.35),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.18),
                            ),
                          ),
                          child: const Text(
                            'Ver 2025.03.AA1_SIT',
                            style: TextStyle(
                              fontSize: 9,
                              color: Colors.white70,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Align(
                      alignment: Alignment.bottomRight,
                      child: Padding(
                        padding: const EdgeInsets.only(
                          right: 10,
                          bottom: 10,
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () {
                              setState(() {
                                _isLightMode = !_isLightMode;
                              });
                            },
                            borderRadius: BorderRadius.circular(18),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 8),
                              decoration: BoxDecoration(
                                color:
                                    (isLightMode ? Colors.white : Colors.black)
                                        .withValues(alpha: 0.35),
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: (isLightMode
                                          ? Colors.black
                                          : Colors.white)
                                      .withValues(alpha: 0.18),
                                ),
                              ),
                              child: Icon(
                                isLightMode
                                    ? Icons.dark_mode_outlined
                                    : Icons.light_mode_outlined,
                                size: 16,
                                color:
                                    isLightMode ? Colors.black : Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Image.asset(
                          loaderAsset,
                          height: loaderHeight,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final useDrawer = constraints.maxWidth < 900;

        final scaffold = Scaffold(
          backgroundColor: Colors.transparent,
          drawer: useDrawer ? _buildSidebarDrawer() : null,
          // floatingActionButton: _buildChatSupportButton(), // Removed per user request
          body: Stack(
            fit: StackFit.expand,
            children: [
              Positioned.fill(
                child: Image.asset(
                  'assets/images/client_dashboard_bg.png',
                  fit: BoxFit.cover,
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.black.withValues(alpha: 0.65),
                      Colors.black.withValues(alpha: 0.35),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (!useDrawer) _buildSidebar(),
                  Expanded(
                    child: SafeArea(
                      left: false,
                      child: Column(
                        children: [
                          // Hide top header on proposals page (has its own header)
                          if (!(widget.showSummary == false &&
                              _selectedNavIndex == 1))
                            _buildTopHeader(useDrawer: useDrawer),
                          Expanded(
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.all(18),
                              child: LayoutBuilder(
                                builder: (context, constraints) {
                                  final narrow = constraints.maxWidth < 980;
                                  final leftContent = _buildMainLeftContent();

                                  if (narrow) {
                                    return Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        leftContent,
                                        const SizedBox(height: 16),
                                        if (_selectedNavIndex == 1 &&
                                            widget.showSummary)
                                          _buildRightPanel(),
                                      ],
                                    );
                                  }

                                  return Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Expanded(child: leftContent),
                                      const SizedBox(width: 16),
                                      if (_selectedNavIndex == 1 &&
                                          widget.showSummary)
                                        SizedBox(
                                          width: 380,
                                          child: _buildRightPanel(),
                                        ),
                                    ],
                                  );
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );

        return scaffold;
      },
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: const BoxDecoration(
        color: Color(0xFF2C3E50),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.dashboard, color: Colors.white, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Row(
              children: [
                const Text(
                  'Client Portal',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Hello, ${_getClientDisplayName()}',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadClientProposals,
            tooltip: 'Refresh',
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCards() {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            'Pending Review',
            _statusCounts['pending'].toString(),
            Icons.pending_actions,
            PremiumTheme.orangeGradient,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildStatCard(
            'Approved',
            _statusCounts['approved'].toString(),
            Icons.check_circle,
            PremiumTheme.tealGradient,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildStatCard(
            'Rejected',
            _statusCounts['rejected'].toString(),
            Icons.cancel,
            PremiumTheme.redGradient,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildStatCard(
            'Total Proposals',
            _proposals.length.toString(),
            Icons.description,
            PremiumTheme.blueGradient,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(
      String title, String value, IconData icon, Gradient gradient) {
    String subtitle;
    switch (title) {
      case 'Pending Review':
        subtitle = 'For your review';
        break;
      case 'Approved':
        subtitle = 'Signed / approved';
        break;
      case 'Rejected':
        subtitle = 'Declined proposals';
        break;
      case 'Total Proposals':
        subtitle = 'All proposals sent to you';
        break;
      default:
        subtitle = '';
    }

    return PremiumStatCard(
      title: title,
      value: value,
      subtitle: subtitle.isEmpty ? null : subtitle,
      icon: icon,
      gradient: gradient,
    );
  }

  Widget _buildProposalsSection() {
    return GlassContainer(
      borderRadius: 20,
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Text(
                  'Your Proposals',
                  style: PremiumTheme.titleMedium,
                ),
                const Spacer(),
                Flexible(
                  child: Text(
                    '${_proposals.length} ${_proposals.length == 1 ? 'proposal' : 'proposals'}',
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.white70,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Table
          if (_proposals.isEmpty)
            Padding(
              padding: const EdgeInsets.all(40),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.description_outlined,
                        size: 64, color: Colors.grey[300]),
                    const SizedBox(height: 16),
                    Text(
                      'No proposals yet',
                      style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columnSpacing: 24,
                headingRowColor: WidgetStateProperty.all(
                  const Color(0xFF111827),
                ),
                columns: const [
                  DataColumn(
                    label: Text(
                      'Proposal',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      'Status',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      'Last Updated',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      'Action',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
                rows: _proposals.map((proposal) {
                  return DataRow(cells: [
                    DataCell(
                      SizedBox(
                        width: 300,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              proposal['title'] ?? 'Untitled',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                                color: Colors.white,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'ID: ${proposal['id']}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    DataCell(
                        _buildStatusBadge(proposal['status'] ?? 'Unknown')),
                    DataCell(
                      Text(
                        _formatDate(proposal['updated_at']),
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.white70,
                        ),
                      ),
                    ),
                    DataCell(
                      ElevatedButton.icon(
                        onPressed: () => _openProposal(proposal),
                        icon: const Icon(Icons.visibility, size: 16),
                        label: const Text('View'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF3498DB),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                        ),
                      ),
                    ),
                  ]);
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    IconData icon;

    final statusLower = status.toLowerCase();
    if (statusLower.contains('pending') ||
        statusLower.contains('sent to client') ||
        statusLower.contains('released')) {
      color = Colors.orange;
      icon = Icons.pending;
    } else if (statusLower.contains('approved') ||
        statusLower.contains('signed')) {
      color = Colors.green;
      icon = Icons.check_circle;
    } else if (statusLower.contains('declined') ||
        statusLower.contains('rejected')) {
      color = Colors.red;
      icon = Icons.cancel;
    } else {
      color = Colors.blue;
      icon = Icons.info;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              status,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              softWrap: false,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(dynamic date) {
    if (date == null) return 'N/A';
    try {
      final dt = DateTime.parse(date.toString());
      final now = DateTime.now();
      final diff = now.difference(dt);

      if (diff.inDays == 0) return 'Today';
      if (diff.inDays == 1) return 'Yesterday';
      if (diff.inDays < 7) return '${diff.inDays} days ago';

      return '${dt.day} ${_getMonth(dt.month)} ${dt.year}';
    } catch (e) {
      return date.toString();
    }
  }

  String _getMonth(int month) {
    const months = [
      '',
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return months[month];
  }
}
