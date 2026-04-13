import 'dart:math' as math;
import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import '../../config/app_constants.dart';

class CinematicSequencePage extends StatelessWidget {
  const CinematicSequencePage({super.key});

  static const Color _white = Color(0xFFFFFFFF);

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
                  'assets/images/client_dashboard_bg.png',
                  fit: BoxFit.cover,
                ),
                Container(color: Colors.black.withValues(alpha: 0.48)),
              ],
            ),
          ),
          SafeArea(
            child: Center(
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
                          errorBuilder: (_, __, ___) => const Text(
                            'KHONOLOGY',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: _white,
                              fontFamily: 'Poppins',
                              fontSize: 38,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 14,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 0),
                      _HeroPanel(isMobile: isMobile),
                      SizedBox(height: isMobile ? 36 : 56),
                      SizedBox(
                        width: 127.85,
                        height: 127.85,
                        child: Transform.rotate(
                          angle: -180 * (math.pi / 180),
                          child: Image.asset(
                            'assets/images/f65f74_85875a9997aa4107b0ce9b656b80d19b~mv2 1.png',
                            width: 127.85,
                            height: 127.85,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 16,
            bottom: 16,
            child: IgnorePointer(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.72),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFF333333)),
                ),
                child: Text(
                  AppConstants.fullVersion,
                  style: const TextStyle(
                    color: Color(0xFF9CA3AF),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
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
  const _HeroPanel({required this.isMobile});

  static const Color _white = Color(0xFFFFFFFF);
  static const Color _accentRed = Color(0xFFC10D00);

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 2.2, sigmaY: 2.2),
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.fromLTRB(
            isMobile ? 18 : 24,
            isMobile ? 13 : 17.5,
            isMobile ? 18 : 24,
            isMobile ? 14 : 16,
          ),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.24),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              Text(
                'Proposal & SOW Builder',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _white,
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
                  color: _white.withValues(alpha: 0.95),
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
                        foregroundColor: _white,
                        side: const BorderSide(
                          color: Color(0xFFFFFFFF),
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
        ),
      ),
    );
  }
}
