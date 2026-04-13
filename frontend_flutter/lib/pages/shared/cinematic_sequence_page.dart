import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../config/app_constants.dart';

class CinematicSequencePage extends StatefulWidget {
  const CinematicSequencePage({super.key});

  @override
  State<CinematicSequencePage> createState() => _CinematicSequencePageState();
}

class _CinematicSequencePageState extends State<CinematicSequencePage> {
  bool _isLightMode = false;

  static const Color _white = Color(0xFFFFFFFF);
  static const Color _lightText = Color(0xFF090812);

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final bool isMobile = size.width < 900;
    final double heroFrameWidth = isMobile ? math.min(size.width - 40, 609.02) : 609.02;

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
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
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
                        color: _isLightMode ? const Color(0xFF3D3F40) : const Color(0xFF9CA3AF),
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
                icon: Icon(_isLightMode ? Icons.dark_mode : Icons.light_mode, size: 12),
                label: Text(_isLightMode ? 'Dark' : 'Light'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _isLightMode ? _lightText : const Color(0xFFFFFFFF),
                  side: BorderSide(
                    color: _isLightMode ? _lightText : const Color(0xFFFFFFFF),
                    width: 1,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
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
        ],
      ),
    );
  }
}

class _HeroPanel extends StatelessWidget {
  final bool isMobile;
  final bool isLightMode;
  const _HeroPanel({required this.isMobile, required this.isLightMode});

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
                  onPressed: () => Navigator.pushNamed(context, '/login'),
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
                  onPressed: () {},
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
