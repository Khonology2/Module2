import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import '../../config/app_constants.dart';
import '../../services/auth_service.dart';
import '../../services/role_service.dart';
import '../../api.dart';

class CinematicSequencePage extends StatefulWidget {
  const CinematicSequencePage({super.key});

  @override
  State<CinematicSequencePage> createState() => _CinematicSequencePageState();
}

class _CinematicSequencePageState extends State<CinematicSequencePage> {
  bool _isLightMode = false;
  bool _isProcessingToken = false;
  String? _urlSsoToken;
  final TextEditingController _tokenController = TextEditingController();
  static const bool _showTokenField =
      bool.fromEnvironment('SHOW_SSO_TOKEN_FIELD', defaultValue: true);

  static const Color _white = Color(0xFFFFFFFF);
  static const Color _lightText = Color(0xFF090812);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _urlSsoToken = _extractTokenFromUrl();
      // Deployment flow: user clicks GET STARTED to exchange token.
      // If a token exists in URL, preload it for explicit submit.
      if (_urlSsoToken != null &&
          _urlSsoToken!.isNotEmpty &&
          _tokenController.text.trim().isEmpty) {
        _tokenController.text = _urlSsoToken!;
      }
    });
  }

  @override
  void dispose() {
    _tokenController.dispose();
    super.dispose();
  }

  String? _extractTokenFromUrl() {
    final uri = Uri.base;
    String? token = uri.queryParameters['token'] ??
        uri.queryParameters['jwt'] ??
        uri.queryParameters['access_token'] ??
        uri.queryParameters['id_token'];

    if ((token == null || token.isEmpty) && uri.fragment.isNotEmpty) {
      final match = RegExp(r'(?:token|jwt|access_token|id_token)=([^&#]+)')
          .firstMatch(uri.fragment);
      if (match != null) {
        token = Uri.decodeComponent(match.group(1)!);
      }
    }

    // Extra fallback for Flutter web hash/deep-link formats.
    if ((token == null || token.isEmpty)) {
      final href = Uri.base.toString();
      final match =
          RegExp(r'(?:token|jwt|access_token|id_token)=([^&#]+)').firstMatch(href);
      if (match != null) {
        token = Uri.decodeComponent(match.group(1)!);
      }
    }

    if (token == null || token.trim().isEmpty) return null;
    return token.trim();
  }

  Future<void> _exchangeSsoToken(String token) async {
    if (!mounted || _isProcessingToken) return;
    setState(() {
      _isProcessingToken = true;
    });
    try {
      final loginResult = await AuthService.loginWithSsoToken(token);
      final userProfile = loginResult?['user'] as Map<String, dynamic>?;
      final accessToken = loginResult?['access_token'] as String?;
      final backendDashboard = loginResult?['dashboard']?.toString();
      final backendRole = loginResult?['role']?.toString();

      if (!mounted || userProfile == null || accessToken == null) {
        return;
      }

      final appState = context.read<AppState>();
      appState.authToken = accessToken;
      appState.currentUser = userProfile;

      final roleService = context.read<RoleService>();
      await roleService.initializeRoleFromUser(userProfile);
      await appState.init();

      final roleKey = (backendRole ?? userProfile['role']?.toString() ?? '')
          .toLowerCase()
          .trim()
          .replaceAll('-', '_')
          .replaceAll(' ', '_');

      final dashboardRoute = backendDashboard ??
          (roleKey == 'admin' ||
                  roleKey == 'ceo' ||
                  roleKey == 'clientreviewer' ||
                  roleKey == 'client_reviewer' ||
                  roleKey == 'reviewer'
              ? '/approver_dashboard'
              : roleKey == 'finance' ||
                      roleKey == 'finance_manager' ||
                      roleKey == 'financial_manager' ||
                      roleKey.contains('finance')
                  ? '/finance_dashboard'
                  : roleKey.contains('admin') ||
                          roleKey.contains('approver')
                      ? '/approver_dashboard'
                      : roleKey.contains('manager') ||
                              roleKey.contains('creator')
                          ? '/creator_dashboard'
                  : '/creator_dashboard');

      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, dashboardRoute, (route) => false);
    } catch (e) {
      debugPrint('SSO token exchange failed: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isProcessingToken = false;
        });
      }
    }
  }

  Future<void> _onGetStartedPressed() async {
    final manualToken = _tokenController.text.trim();
    if (manualToken.isNotEmpty) {
      await _exchangeSsoToken(manualToken);
      return;
    }

    if (_urlSsoToken != null && _urlSsoToken!.isNotEmpty) {
      await _exchangeSsoToken(_urlSsoToken!);
      return;
    }

    if (!mounted) return;
    Navigator.pushNamed(context, '/login');
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final bool isMobile = size.width < 900;
    final double heroFrameWidth =
        isMobile ? math.min(size.width - 40, 609.02) : 609.02;

    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      body: Stack(
        children: [
          Positioned.fill(
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.asset(
                  _isLightMode
                      ? 'assets/images/light_mode_bg.png'
                      : 'assets/images/client_dashboard_bg.png',
                  fit: BoxFit.cover,
                ),
                Container(
                  color: _isLightMode
                      ? Colors.white.withValues(alpha: 0.08)
                      : Colors.black.withValues(alpha: 0.48),
                ),
              ],
            ),
          ),
          SafeArea(
            child: Center(
              child: Transform.translate(
                offset: Offset(0, isMobile ? -14 : -30),
                child: SingleChildScrollView(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                  child: SizedBox(
                    width: heroFrameWidth,
                    child: Column(
                      children: [
                        SizedBox(
                          width: heroFrameWidth,
                          height: isMobile ? 80 : 102,
                          child: Image.asset(
                            'assets/images/2026.png',
                            fit: BoxFit.contain,
                            filterQuality: FilterQuality.high,
                            errorBuilder: (_, __, ___) => Text(
                              'KHONOLOGY',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: _isLightMode ? _lightText : _white,
                                fontFamily: 'Poppins',
                                fontSize: 38,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 14,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 0),
                        _HeroPanel(
                          isMobile: isMobile,
                          isLightMode: _isLightMode,
                          showTokenField: _showTokenField,
                          tokenController: _tokenController,
                          onGetStartedPressed: _onGetStartedPressed,
                          isProcessingToken: _isProcessingToken,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 46,
            child: Center(
              child: Transform.translate(
                // Red and white disc assets have slightly different internal padding.
                // Nudge light-mode discs so both modes align visually.
                offset: Offset(0, _isLightMode ? 6 : 0),
                child: Opacity(
                  opacity: _isLightMode ? 0.8 : 1.0,
                  child: SizedBox(
                    width: 127.85,
                    height: 127.85,
                    child: Transform.rotate(
                      angle: -180 * (math.pi / 180),
                      child: Image.asset(
                        _isLightMode
                            ? 'assets/images/Red_Discs.png'
                            : 'assets/images/white_khono_loading.png',
                        width: 127.85,
                        height: 127.85,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 16,
            bottom: 16,
            child: IgnorePointer(
              child: SizedBox(
                width: 113,
                height: 23,
                child: Container(
                  decoration: BoxDecoration(
                    color: _isLightMode
                        ? Colors.transparent
                        : Colors.black.withValues(alpha: 0.72),
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(
                      color: _isLightMode
                          ? const Color(0xFF3D3F40)
                          : const Color(0xFF3D3F40),
                      width: 1,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      AppConstants.fullVersion,
                      style: TextStyle(
                        color: _isLightMode
                            ? const Color(0xFF3D3F40)
                            : const Color(0xFF9CA3AF),
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            right: 16,
            bottom: 16,
            child: SizedBox(
              width: 84,
              height: 25.2,
              child: OutlinedButton.icon(
                onPressed: () {
                  setState(() {
                    _isLightMode = !_isLightMode;
                  });
                },
                icon: Icon(_isLightMode ? Icons.dark_mode : Icons.light_mode,
                    size: 12),
                label: Text(_isLightMode ? 'Dark' : 'Light'),
                style: OutlinedButton.styleFrom(
                  foregroundColor:
                      _isLightMode ? _lightText : const Color(0xFFFFFFFF),
                  side: BorderSide(
                    color: _isLightMode ? _lightText : const Color(0xFFFFFFFF),
                    width: 1,
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  textStyle: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
          if (_isProcessingToken)
            Positioned.fill(
              child: Container(
                color: Colors.black.withValues(alpha: 0.78),
                child: const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFE9293A)),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _HeroPanel extends StatelessWidget {
  final bool isMobile;
  final bool isLightMode;
  final bool showTokenField;
  final bool isProcessingToken;
  final TextEditingController tokenController;
  final Future<void> Function() onGetStartedPressed;
  const _HeroPanel({
    required this.isMobile,
    required this.isLightMode,
    required this.showTokenField,
    required this.tokenController,
    required this.onGetStartedPressed,
    required this.isProcessingToken,
  });

  static const Color _white = Color(0xFFFFFFFF);
  static const Color _lightText = Color(0xFF090812);
  static const Color _accentRed = Color(0xFFC10D00);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 18 : 24),
      child: Column(
        children: [
          Text(
            'Proposal & SOW Builder',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isLightMode ? _lightText : _white,
              fontFamily: 'Poppins',
              fontSize: isMobile ? 19 : 24.59,
              fontWeight: FontWeight.w600,
              height: 1.0,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Craft refined requirement into polished execution proposal.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isLightMode ? _lightText : _white.withValues(alpha: 0.95),
              fontFamily: 'Poppins',
              fontSize: isMobile ? 13 : 17.5,
              fontWeight: FontWeight.w500,
              height: 1.05,
            ),
          ),
          SizedBox(height: isMobile ? 24 : 32.58),
          if (showTokenField)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: SizedBox(
                width: 412.6,
                child: TextField(
                  controller: tokenController,
                  style: TextStyle(color: isLightMode ? _lightText : _white),
                  decoration: InputDecoration(
                    hintText: 'Paste token here',
                    hintStyle: TextStyle(
                      color: isLightMode
                          ? _lightText.withValues(alpha: 0.55)
                          : _white.withValues(alpha: 0.55),
                    ),
                    filled: true,
                    fillColor: isLightMode
                        ? Colors.white.withValues(alpha: 0.9)
                        : Colors.black.withValues(alpha: 0.55),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                        color: isLightMode ? _lightText : _white,
                        width: 1,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                        color: isLightMode
                            ? _lightText.withValues(alpha: 0.55)
                            : _white.withValues(alpha: 0.55),
                        width: 1,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 10,
            runSpacing: 10,
            children: [
              SizedBox(
                width: 201.3,
                height: 32.58,
                child: ElevatedButton(
                  onPressed: isProcessingToken ? null : onGetStartedPressed,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _accentRed,
                    foregroundColor: _white,
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(34.11),
                    ),
                    textStyle: const TextStyle(
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                      letterSpacing: 0.3,
                    ),
                    elevation: 0,
                  ),
                  child: const Text('GET STARTED'),
                ),
              ),
              SizedBox(
                width: 201.3,
                height: 32.58,
                child: OutlinedButton(
                  onPressed: () => Navigator.pushNamed(context, '/learn-more'),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: const Color(0x00C10D00),
                    foregroundColor: isLightMode ? _lightText : _white,
                    side: BorderSide(
                      color: isLightMode ? _lightText : const Color(0xFFFFFFFF),
                      width: 1.23,
                    ),
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(34.11),
                    ),
                    textStyle: const TextStyle(
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w600,
                      fontSize: 18,
                      letterSpacing: 0.4,
                    ),
                  ),
                  child: const Text('LEARN MORE'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
