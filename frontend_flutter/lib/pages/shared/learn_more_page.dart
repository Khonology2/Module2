import 'package:flutter/material.dart';

class LearnMorePage extends StatelessWidget {
  const LearnMorePage({super.key});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isMobile = size.width < 900;

    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/images/client_dashboard_bg.png',
              fit: BoxFit.cover,
            ),
          ),
          Positioned.fill(
            child: Container(
              color: Colors.black.withValues(alpha: 0.55),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.of(context).maybePop(),
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Learn More',
                        style: TextStyle(
                          color: Colors.white,
                          fontFamily: 'Poppins',
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: isMobile ? double.infinity : 1040,
                        ),
                        child: Container(
                          padding: const EdgeInsets.all(22),
                          decoration: BoxDecoration(
                            color: const Color(0x24FFFFFF),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.10),
                              width: 1,
                            ),
                          ),
                          child: SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: const [
                                Text(
                                  'Proposal & SOW Builder',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontFamily: 'Poppins',
                                    fontSize: 20,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                SizedBox(height: 10),
                                Text(
                                  'Create high-quality proposals and Statements of Work (SOWs) faster with a guided, all-in-one platform designed for consistency, collaboration, and control.',
                                  style: TextStyle(
                                    color: Color(0xFFE5E7EB),
                                    fontFamily: 'Poppins',
                                    fontSize: 14,
                                    fontWeight: FontWeight.w400,
                                    height: 1.45,
                                  ),
                                ),
                                SizedBox(height: 12),
                                Text(
                                  'Stop juggling documents, emails, and templates. Everything you need to draft, review, and finalize proposals lives in one place—from the first outline to client sign-off.',
                                  style: TextStyle(
                                    color: Color(0xFFE5E7EB),
                                    fontFamily: 'Poppins',
                                    fontSize: 14,
                                    fontWeight: FontWeight.w400,
                                    height: 1.45,
                                  ),
                                ),
                                SizedBox(height: 18),
                                Text(
                                  'What You Can Do',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontFamily: 'Poppins',
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                SizedBox(height: 10),
                                Text(
                                  '• Build proposals and SOWs using structured templates and reusable content blocks',
                                  style: TextStyle(
                                    color: Color(0xFFE5E7EB),
                                    fontFamily: 'Poppins',
                                    fontSize: 14,
                                    fontWeight: FontWeight.w400,
                                    height: 1.45,
                                  ),
                                ),
                                SizedBox(height: 6),
                                Text(
                                  '• Automatically manage and track proposal status across your pipeline',
                                  style: TextStyle(
                                    color: Color(0xFFE5E7EB),
                                    fontFamily: 'Poppins',
                                    fontSize: 14,
                                    fontWeight: FontWeight.w400,
                                    height: 1.45,
                                  ),
                                ),
                                SizedBox(height: 6),
                                Text(
                                  '• Collaborate seamlessly with comments, edits, and version history',
                                  style: TextStyle(
                                    color: Color(0xFFE5E7EB),
                                    fontFamily: 'Poppins',
                                    fontSize: 14,
                                    fontWeight: FontWeight.w400,
                                    height: 1.45,
                                  ),
                                ),
                                SizedBox(height: 6),
                                Text(
                                  '• Ensure consistency with centralized templates and client data',
                                  style: TextStyle(
                                    color: Color(0xFFE5E7EB),
                                    fontFamily: 'Poppins',
                                    fontSize: 14,
                                    fontWeight: FontWeight.w400,
                                    height: 1.45,
                                  ),
                                ),
                                SizedBox(height: 18),
                                Text(
                                  'How It Works',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontFamily: 'Poppins',
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                SizedBox(height: 10),
                                Text(
                                  'Compose',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontFamily: 'Poppins',
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                SizedBox(height: 6),
                                Text(
                                  'Create proposals using guided templates and pre-approved sections. Quickly assemble documents with consistent structure and auto-filled client details.',
                                  style: TextStyle(
                                    color: Color(0xFFE5E7EB),
                                    fontFamily: 'Poppins',
                                    fontSize: 14,
                                    fontWeight: FontWeight.w400,
                                    height: 1.45,
                                  ),
                                ),
                                SizedBox(height: 12),
                                Text(
                                  'Govern',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontFamily: 'Poppins',
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                SizedBox(height: 6),
                                Text(
                                  'Maintain quality with built-in checks. Identify missing sections, ensure completeness, and reduce risk before sharing with clients.',
                                  style: TextStyle(
                                    color: Color(0xFFE5E7EB),
                                    fontFamily: 'Poppins',
                                    fontSize: 14,
                                    fontWeight: FontWeight.w400,
                                    height: 1.45,
                                  ),
                                ),
                                SizedBox(height: 12),
                                Text(
                                  'Sign-Off',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontFamily: 'Poppins',
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                SizedBox(height: 6),
                                Text(
                                  'Streamline approvals and capture secure client signatures. Track progress and finalize proposals without leaving the platform.',
                                  style: TextStyle(
                                    color: Color(0xFFE5E7EB),
                                    fontFamily: 'Poppins',
                                    fontSize: 14,
                                    fontWeight: FontWeight.w400,
                                    height: 1.45,
                                  ),
                                ),
                                SizedBox(height: 18),
                                Text(
                                  'Why It Matters',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontFamily: 'Poppins',
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                SizedBox(height: 10),
                                Text(
                                  '• Save time by eliminating manual formatting and scattered content',
                                  style: TextStyle(
                                    color: Color(0xFFE5E7EB),
                                    fontFamily: 'Poppins',
                                    fontSize: 14,
                                    fontWeight: FontWeight.w400,
                                    height: 1.45,
                                  ),
                                ),
                                SizedBox(height: 6),
                                Text(
                                  '• Reduce errors with built-in governance and structure',
                                  style: TextStyle(
                                    color: Color(0xFFE5E7EB),
                                    fontFamily: 'Poppins',
                                    fontSize: 14,
                                    fontWeight: FontWeight.w400,
                                    height: 1.45,
                                  ),
                                ),
                                SizedBox(height: 6),
                                Text(
                                  '• Maintain professional, consistent proposals every time',
                                  style: TextStyle(
                                    color: Color(0xFFE5E7EB),
                                    fontFamily: 'Poppins',
                                    fontSize: 14,
                                    fontWeight: FontWeight.w400,
                                    height: 1.45,
                                  ),
                                ),
                                SizedBox(height: 6),
                                Text(
                                  '• Accelerate deal closure with faster approvals and sign-off',
                                  style: TextStyle(
                                    color: Color(0xFFE5E7EB),
                                    fontFamily: 'Poppins',
                                    fontSize: 14,
                                    fontWeight: FontWeight.w400,
                                    height: 1.45,
                                  ),
                                ),
                                SizedBox(height: 18),
                                Text(
                                  'Ready to get started?',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontFamily: 'Poppins',
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                SizedBox(height: 10),
                                Text(
                                  'Create a new proposal or head to your dashboard to manage and track your work.',
                                  style: TextStyle(
                                    color: Color(0xFFE5E7EB),
                                    fontFamily: 'Poppins',
                                    fontSize: 14,
                                    fontWeight: FontWeight.w400,
                                    height: 1.45,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.center,
                    child: SizedBox(
                      width: isMobile ? double.infinity : 260,
                      height: 44,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pushNamed(context, '/login'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFD72638),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(50),
                          ),
                          elevation: 0,
                        ),
                        child: const Text(
                          'GET STARTED',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.3,
                          ),
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
    );
  }
}
