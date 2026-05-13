import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui_web' as ui_web;
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:web/web.dart' as web;
import 'package:pointer_interceptor/pointer_interceptor.dart';
import 'package:signature/signature.dart';
import '../../api.dart';
import '../../theme/premium_theme.dart';
import '../../theme/manager_theme_controller.dart';
import '../../widgets/app_side_nav.dart';
import '../../widgets/client_proposal_document_preview.dart';

class ClientProposalViewer extends StatefulWidget {
  final int proposalId;
  final String accessToken;
  final int initialTab;

  const ClientProposalViewer({
    super.key,
    required this.proposalId,
    required this.accessToken,
    this.initialTab = 0,
  });

  @override
  State<ClientProposalViewer> createState() => _ClientProposalViewerState();
}

class _ClientProposalViewerState extends State<ClientProposalViewer> {
  static const List<Map<String, String>> _clientAppSideNavItems = [
    {
      'label': 'Dashboard',
      'icon':
          'assets/images/Creator_Dashboard/Project Launch_Start_White Badge_Blue.png',
    },
    {
      'label': 'Proposals',
      'icon':
          'assets/images/Creator_Dashboard/Networking_Collaboration_White Badge__Blue.png',
    },
    {
      'label': 'Documents',
      'icon': 'assets/images/client_icons/Data Approval_White Badge_Blue.png',
    },
  ];

  bool _isLoading = true;
  String? _error;
  Map<String, dynamic>? _proposalData;
  Map<String, dynamic>? _signatureData;
  String? _signingUrl;
  String? _signatureStatus;
  List<Map<String, dynamic>> _comments = [];
  final TextEditingController _commentController = TextEditingController();
  bool _isSubmittingComment = false;
  String? _currentSessionId;
  // Section-by-section viewing state for analytics
  List<Map<String, dynamic>> _sections = [];
  int _currentSectionIndex = 0;
  DateTime? _sectionViewStart;

  int _selectedTab = 0; // 0: Content, 1: Comments

  late final SignatureController _signatureController;
  final TextEditingController _signerNameController = TextEditingController();

  String? _pdfObjectUrl;
  bool _isPdfLoading = false;
  String? _pdfError;
  late final String _pdfViewType;
  bool _pdfViewRegistered = false;
  html.IFrameElement? _pdfIframe;
  bool _pdfIframeListenersAttached = false;
  bool _isSidebarCollapsed = false;
  final GlobalKey<ScaffoldState> _portalScaffoldKey =
      GlobalKey<ScaffoldState>();
  final ScrollController _proposalScrollController = ScrollController();
  final ScrollController _commentsScrollController = ScrollController();

  static const Duration _networkTimeout = Duration(seconds: 20);

  bool _canSignInApp() {
    final p = _proposalData;
    if (p == null) return false;
    final st = (_signatureStatus ?? '').toLowerCase();
    if (st.contains('completed')) return false;
    final hash = p['signing_payload_hash']?.toString() ?? '';
    return hash.isNotEmpty;
  }

  Map<String, String> _clientDeviceHeaders() {
    final headers = <String, String>{};
    try {
      // Align with ClientDashboardHome keys
      final deviceId =
          web.window.localStorage['lukens_client_device_id']?.trim();
      if (deviceId != null && deviceId.isNotEmpty) {
        headers['X-Client-Device-Id'] = deviceId;
      }
      final sessionToken =
          web.window.localStorage['lukens_client_session_token']?.trim();
      if (sessionToken != null && sessionToken.isNotEmpty) {
        headers['X-Client-Session-Token'] = sessionToken;
      }
    } catch (_) {
      // ignore
    }
    return headers;
  }

  @override
  void initState() {
    super.initState();
    _signatureController = SignatureController(
      penStrokeWidth: 2.5,
      penColor: Colors.black87,
      exportBackgroundColor: Colors.white,
    );
    _selectedTab = widget.initialTab;
    _pdfViewType = 'pdf-preview-${DateTime.now().microsecondsSinceEpoch}';
    _initPdfView();
    _loadProposal();
    _startSession();
    _logEvent('open');
  }

  void _initPdfView() {
    if (!kIsWeb || _pdfViewRegistered) return;
    _pdfViewRegistered = true;

    // ignore: undefined_prefixed_name
    ui_web.platformViewRegistry.registerViewFactory(_pdfViewType, (int viewId) {
      _pdfIframe ??= html.IFrameElement()
        ..style.border = 'none'
        ..style.width = '100%'
        ..style.height = '100%'
        ..allow = 'fullscreen';

      // If we already computed the PDF URL before the iframe existed,
      // ensure we apply it as soon as the iframe is created.
      final pendingUrl = _pdfObjectUrl;
      if (pendingUrl != null && pendingUrl.isNotEmpty) {
        _pdfIframe!.src = pendingUrl;
      }

      if (!_pdfIframeListenersAttached) {
        _pdfIframeListenersAttached = true;
        _pdfIframe!.onLoad.listen((_) {
          if (!mounted) return;
          if (_isPdfLoading) {
            setState(() {
              _isPdfLoading = false;
            });
          }
        });

        _pdfIframe!.onError.listen((_) {
          if (!mounted) return;
          if (_isPdfLoading || _pdfError == null) {
            setState(() {
              _isPdfLoading = false;
              _pdfError =
                  'Failed to load PDF preview. Use Export PDF to open it in a new tab.';
            });
          }
        });
      }
      return _pdfIframe!;
    });
  }

  List<Map<String, dynamic>> _parseSectionsFromContent(dynamic content) {
    try {
      if (content == null) return [];

      dynamic decoded = content;
      if (decoded is String) {
        if (decoded.trim().isEmpty) return [];
        decoded = jsonDecode(decoded);
      }

      if (decoded is Map<String, dynamic>) {
        if (decoded['sections'] is List) {
          final list = decoded['sections'] as List;
          return list
              .where((item) => item is Map)
              .map((item) => Map<String, dynamic>.from(item as Map))
              .toList();
        }

        return decoded.entries
            .map((entry) => <String, dynamic>{
                  'title': entry.key,
                  'content': entry.value?.toString() ?? '',
                })
            .toList();
      }

      if (decoded is Map) {
        final map = Map<String, dynamic>.from(decoded);
        return _parseSectionsFromContent(map);
      }

      if (decoded is List) {
        return decoded
            .where((item) => item is Map)
            .map((item) => Map<String, dynamic>.from(item as Map))
            .toList();
      }

      return [
        {
          'title': 'Content',
          'content': decoded.toString(),
        },
      ];
    } catch (e) {
      print('Error parsing sections from content: $e');
      return [];
    }
  }

  void _logCurrentSectionView() {
    if (_sections.isEmpty || _sectionViewStart == null) return;

    final now = DateTime.now();
    final index = _currentSectionIndex.clamp(0, _sections.length - 1);
    final section = _sections[index];
    final sectionTitle =
        (section['title']?.toString().trim().isNotEmpty ?? false)
            ? section['title'].toString().trim()
            : 'Section ${index + 1}';

    final durationSeconds = now.difference(_sectionViewStart!).inSeconds;
    final safeDuration = durationSeconds <= 0 ? 1 : durationSeconds;

    _logEvent('view_section', metadata: {
      'section': sectionTitle,
      'duration': safeDuration,
    });
  }

  @override
  void dispose() {
    _signatureController.dispose();
    _signerNameController.dispose();
    _commentController.dispose();
    _proposalScrollController.dispose();
    _commentsScrollController.dispose();
    _logCurrentSectionView();
    _endSession();
    _logEvent('close');
    super.dispose();
  }

  Future<void> _loadPdfPreview() async {
    if (!kIsWeb) return;
    _initPdfView();
    setState(() {
      _isPdfLoading = true;
      _pdfError = null;
    });

    try {
      // Load directly via URL so the browser can stream + cache.
      final url =
          '$baseUrl/api/client/proposals/${widget.proposalId}/export/pdf?token=${Uri.encodeComponent(widget.accessToken)}';

// Probe the endpoint first. Iframe load events are unreliable for PDFs
      // and can lead to an endless spinner. A small Range request gives us a
      // fast, deterministic signal.
      http.Response probe;
      try {
        probe = await http.get(
          Uri.parse(url),
          headers: const {
            'Range': 'bytes=0-0',
          },
        ).timeout(const Duration(seconds: 25));
      } catch (_) {
        if (!mounted) return;
        setState(() {
          _isPdfLoading = false;
          _pdfError =
              'Unable to load PDF preview (network). Please retry, or use Export PDF.';
        });
        return;
      }

      final status = probe.statusCode;
      final contentType = (probe.headers['content-type'] ?? '').toLowerCase();
      final isPdf = contentType.contains('application/pdf');
      final ok = status == 200 || status == 206;

      if (!ok || !isPdf) {
        String details = '';
        try {
          final decoded = jsonDecode(probe.body);
          if (decoded is Map && decoded['detail'] != null) {
            details = decoded['detail'].toString();
          }
        } catch (_) {
          // ignore
        }

        if (!mounted) return;
        setState(() {
          _isPdfLoading = false;
          _pdfError = details.isNotEmpty
              ? details
              : 'PDF not available. Use Export PDF to open it in a new tab.';
        });
        return;
      }

      // Probe succeeded - load the full PDF in the iframe.
      _pdfObjectUrl = url;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final iframe = _pdfIframe;
        if (iframe != null && mounted) {
          iframe.src = url;
        }
      });

      // _isPdfLoading will flip to false in the iframe onLoad listener.
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isPdfLoading = false;
        _pdfError = e.toString();
      });
    }
  }

  Future<void> _exportPdf() async {
    final url =
        '$baseUrl/api/client/proposals/${widget.proposalId}/export/pdf?token=${Uri.encodeComponent(widget.accessToken)}&download=1';
    if (kIsWeb) {
      web.window.open(url, '_blank');
      return;
    }
    await launchUrlString(url);
  }

  Future<void> _exportWord() async {
    final url =
        '$baseUrl/api/client/proposals/${widget.proposalId}/export/word?token=${Uri.encodeComponent(widget.accessToken)}';
    if (kIsWeb) {
      web.window.open(url, '_blank');
      return;
    }
    await launchUrlString(url);
  }

  Future<void> _uploadSignedBytes({
    required Uint8List bytes,
    required String filename,
  }) async {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Uploading signed document...'),
        duration: Duration(seconds: 2),
      ),
    );

    final uri = Uri.parse(
      '$baseUrl/api/client/proposals/${widget.proposalId}/upload-signed',
    );
    final req = http.MultipartRequest('POST', uri)
      ..fields['token'] = widget.accessToken
      ..files.add(
        http.MultipartFile.fromBytes(
          'file',
          bytes,
          filename: filename,
        ),
      );

    try {
      final streamedResponse = await req.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Signed document uploaded successfully'),
            backgroundColor: Colors.green,
          ),
        );
        // Refresh proposal to show the updated signature
        await _loadProposal();
      } else {
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Upload failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _uploadSignedDocument() async {
    try {
      final res = await FilePicker.platform.pickFiles(withData: true);
      if (res == null || res.files.isEmpty) return;

      final file = res.files.first;
      final bytes = file.bytes;
      if (bytes == null) {
        throw Exception('Unable to read file bytes');
      }

      await _uploadSignedBytes(bytes: bytes, filename: file.name);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Upload failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _scanSignedDocument() async {
    try {
      if (kIsWeb) {
        final input = html.FileUploadInputElement();
        input.accept = 'image/*,application/pdf';
        input.setAttribute('capture', 'environment');
        input.click();

        await input.onChange.first;
        final files = input.files;
        if (files == null || files.isEmpty) return;

        final f = files.first;
        final reader = html.FileReader();
        reader.readAsArrayBuffer(f);
        await reader.onLoadEnd.first;

        final result = reader.result;
        if (result is! ByteBuffer) {
          throw Exception('Unable to read captured file');
        }

        await _uploadSignedBytes(
          bytes: Uint8List.view(result),
          filename: f.name,
        );
        return;
      }

      final picker = ImagePicker();
      final image = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
      );
      if (image == null) return;

      final bytes = await image.readAsBytes();
      await _uploadSignedBytes(bytes: bytes, filename: image.name);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Scan failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _startSession() async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/client/session/start'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'token': widget.accessToken,
          'proposal_id': widget.proposalId,
        }),
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        setState(() {
          _currentSessionId = data['session_id'];
        });
      }
    } catch (e) {
      print('Error starting session: $e');
    }
  }

  Future<void> _endSession() async {
    if (_currentSessionId != null) {
      try {
        await http
            .post(
              Uri.parse('$baseUrl/api/client/session/end'),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({
                'session_id': _currentSessionId,
              }),
            )
            .timeout(_networkTimeout);
      } catch (e) {
        print('Error ending session: $e');
      }
    }
  }

  Future<void> _logEvent(String eventType,
      {Map<String, dynamic>? metadata}) async {
    try {
      await http
          .post(
            Uri.parse('$baseUrl/api/client/activity'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'token': widget.accessToken,
              'proposal_id': widget.proposalId,
              'event_type': eventType,
              'metadata': metadata ?? {},
            }),
          )
          .timeout(_networkTimeout);
    } catch (e) {
      print('Error logging event: $e');
    }
  }

  Future<void> _loadProposal() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final extraHeaders =
          kIsWeb ? _clientDeviceHeaders() : const <String, String>{};
      final response = await http
          .get(
            Uri.parse(
                '$baseUrl/api/client/proposals/${widget.proposalId}?token=${Uri.encodeComponent(widget.accessToken)}'),
            headers: extraHeaders.isEmpty ? null : extraHeaders,
          )
          .timeout(_networkTimeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final content = data['proposal']?['content'];
        if (content != null) {
          content.toString();
        } else {}
        final parsedSections = _parseSectionsFromContent(content);

        setState(() {
          _proposalData = data['proposal'];
          _signatureData = data['signature'] != null
              ? Map<String, dynamic>.from(data['signature'])
              : null;
          _signingUrl = _signatureData?['signing_url']?.toString();
          _signatureStatus = _signatureData?['status']?.toString();

          // Debug logging for signature data

          _comments = (data['comments'] as List?)
                  ?.map((c) => Map<String, dynamic>.from(c))
                  .toList() ??
              [];
          _sections = parsedSections;
          _currentSectionIndex = 0;
          _sectionViewStart = _sections.isNotEmpty ? DateTime.now() : null;
          _isLoading = false;
        });

        await _loadPdfPreview();
      } else {
        final errorBody = response.body;
        try {
          final error = jsonDecode(errorBody);
          setState(() {
            _error = error['detail'] ?? 'Failed to load proposal';
            _isLoading = false;
          });
        } catch (e) {
          setState(() {
            _error =
                'Failed to load proposal (${response.statusCode}): $errorBody';
            _isLoading = false;
          });
        }
      }
    } on TimeoutException {
      setState(() {
        _error =
            'Request timed out. Confirm the backend is running on ${baseUrl.replaceAll("/api", "")} and retry.';
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Error: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _submitComment() async {
    if (_commentController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a comment'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isSubmittingComment = true;
    });

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/client/proposals/${widget.proposalId}/comment'),
        headers: {
          'Content-Type': 'application/json',
          ..._clientDeviceHeaders(),
        },
        body: jsonEncode({
          'token': widget.accessToken,
          'comment_text': _commentController.text.trim(),
        }),
      );

      if (response.statusCode == 201) {
        _logEvent('comment', metadata: {
          'comment_length': _commentController.text.trim().length
        });
        _commentController.clear();
        await _loadProposal();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Comment added successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['detail'] ?? 'Failed to add comment');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isSubmittingComment = false;
      });
    }
  }

  void _showSignedSubmissionPreview({
    required String signedPdfUrl,
    String? signatureImageUrl,
    required String signerName,
  }) {
    final chrome = context.read<ManagerThemeController>().chrome;
    final h = MediaQuery.sizeOf(context).height;

    showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dialogCtx) {
        final maxW = math.min(
          920.0,
          MediaQuery.sizeOf(dialogCtx).width - 32,
        );
        return Dialog(
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          backgroundColor: Colors.transparent,
          child: GlassContainer(
            borderRadius: 14,
            padding: const EdgeInsets.all(18),
            child: SizedBox(
              width: maxW,
              height: h * 0.86,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Icon(Icons.fact_check_outlined,
                          color: chrome.textPrimary, size: 22),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Submission preview',
                          style: TextStyle(
                            color: chrome.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Close',
                        onPressed: () => Navigator.pop(dialogCtx),
                        icon: Icon(Icons.close, color: chrome.textPrimary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'This is the merged PDF and signature record returned to your provider.',
                    style: TextStyle(
                      color: chrome.textSecondary,
                      fontSize: 13,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Signer: $signerName',
                    style: TextStyle(
                      color: chrome.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (signatureImageUrl != null &&
                      signatureImageUrl.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          signatureImageUrl,
                          height: 72,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) =>
                              const SizedBox.shrink(),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: kIsWeb
                          ? _SignedPdfHtmlEmbed(url: signedPdfUrl)
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'Open the signed PDF on this device to review.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: chrome.textSecondary),
                                ),
                                const SizedBox(height: 12),
                                FilledButton(
                                  onPressed: () =>
                                      launchUrlString(signedPdfUrl),
                                  child: const Text('Open signed PDF'),
                                ),
                              ],
                            ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () {
                        if (kIsWeb) {
                          web.window.open(signedPdfUrl, '_blank');
                        } else {
                          launchUrlString(signedPdfUrl);
                        }
                      },
                      icon: const Icon(Icons.open_in_new, size: 18),
                      label: const Text('Open in new tab'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showRejectDialog() {
    showDialog(
      context: context,
      builder: (context) => RejectDialog(
        proposalId: widget.proposalId,
        accessToken: widget.accessToken,
        onSuccess: () {
          Navigator.pop(context); // Close dialog
          Navigator.pop(context); // Go back to dashboard
        },
      ),
    );
  }

  void _showApproveDialog() {
    showDialog(
      context: context,
      builder: (context) => ApproveDialog(
        proposalId: widget.proposalId,
        accessToken: widget.accessToken,
        onSuccess: () {
          Navigator.pop(context); // Close dialog
          _loadProposal(); // Reload to show updated status
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pageBg = const Color(0xFFF3F5F8);
    if (_isLoading) {
      return _buildPortalShell(
        pageBg: pageBg,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Loading proposal...'),
            ],
          ),
        ),
      );
    }

    if (_error != null) {
      return _buildPortalShell(
        pageBg: pageBg,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
              const SizedBox(height: 16),
              Text(
                _error!,
                style: const TextStyle(fontSize: 18, color: Colors.red),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () => _loadProposal(),
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final proposal = _proposalData!;
    final status = proposal['status'] as String? ?? 'Unknown';
    final signatureStatus = (_signatureStatus ?? '').toLowerCase();
    final isSigned = signatureStatus.contains('completed');
    final isDeclined = signatureStatus.contains('declined');
    // Show action bar if not signed and not declined, or if signature status is unknown
    final canTakeAction = !isSigned && !isDeclined;

    return _buildPortalShell(
      pageBg: pageBg,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1380),
          child: Column(
            children: [
              // Header
              _buildHeader(proposal, status),

              _buildSignaturePanel(),

              // Sign / reject — available on web and mobile (first-party flow).
              if (canTakeAction) _buildActionBar(),

              // Content
              Expanded(
                child: _selectedTab == 0
                    ? _buildProposalContent(proposal)
                    : _buildCommentsSection(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPortalShell({
    required Color pageBg,
    required Widget child,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final useDrawer = constraints.maxWidth < 950;
        final chrome = context.watch<ManagerThemeController>().chrome;

        return Scaffold(
          key: _portalScaffoldKey,
          backgroundColor: Colors.transparent,
          drawer: useDrawer
              ? Drawer(
                  backgroundColor: chrome.sidebarBackground,
                  child: SafeArea(
                    child: PointerInterceptor(
                      child: AppSideNav(
                        isCollapsed: false,
                        currentLabel: 'Proposals',
                        onSelect: (label) => _handleClientSideNavSelect(
                          label,
                          closeDrawer: true,
                        ),
                        onToggle: () {},
                        isAdmin: false,
                        showCollapseToggle: true,
                        items: _clientAppSideNavItems,
                        collapsedWidthOverride: 76,
                        expandedWidthOverride: 220,
                      ),
                    ),
                  ),
                )
              : null,
          body: Stack(
            fit: StackFit.expand,
            children: [
              Positioned.fill(
                child: Image.asset(
                  chrome.backgroundAsset,
                  fit: BoxFit.cover,
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  gradient: chrome.isDark
                      ? LinearGradient(
                          colors: [
                            Colors.black.withValues(alpha: 0.65),
                            Colors.black.withValues(alpha: 0.35),
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        )
                      : LinearGradient(
                          colors: [
                            Colors.white.withValues(alpha: 0.50),
                            Colors.white.withValues(alpha: 0.15),
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                ),
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (!useDrawer)
                    PointerInterceptor(
                      child: AppSideNav(
                        isCollapsed: _isSidebarCollapsed,
                        currentLabel: 'Proposals',
                        onSelect: (label) => _handleClientSideNavSelect(
                          label,
                          closeDrawer: false,
                        ),
                        onToggle: () => setState(
                          () => _isSidebarCollapsed = !_isSidebarCollapsed,
                        ),
                        isAdmin: false,
                        showCollapseToggle: true,
                        items: _clientAppSideNavItems,
                        collapsedWidthOverride: 76,
                        expandedWidthOverride: 220,
                      ),
                    ),
                  Expanded(
                    child: SafeArea(
                      left: false,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (useDrawer)
                            PointerInterceptor(
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(8, 6, 16, 4),
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: IconButton(
                                    tooltip: 'Navigation menu',
                                    icon: Icon(
                                      Icons.menu,
                                      color: chrome.textPrimary,
                                    ),
                                    onPressed: () => _portalScaffoldKey
                                        .currentState
                                        ?.openDrawer(),
                                  ),
                                ),
                              ),
                            ),
                          Expanded(child: child),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  void _navigateClient(String route) {
    final suffix = widget.accessToken.trim().isNotEmpty
        ? '?token=${Uri.encodeComponent(widget.accessToken)}'
        : '';
    Navigator.pushReplacementNamed(context, '$route$suffix');
  }

  void _handleClientSideNavSelect(String label, {required bool closeDrawer}) {
    if (closeDrawer && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
    if (label == 'Dashboard') {
      _navigateClient('/client/dashboard');
      return;
    }
    if (label == 'Proposals' || label == 'Documents') {
      _navigateClient('/client/proposals');
      return;
    }
  }

  /// Matches client dashboard "Project Chat" / right-panel card sizing and finish.
  Widget _buildHeader(Map<String, dynamic> proposal, String status) {
    final chrome = context.watch<ManagerThemeController>().chrome;
    final title = (proposal['title'] ?? 'Untitled Proposal').toString();

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      height: 184,
      child: Container(
        width: double.infinity,
        clipBehavior: Clip.antiAlias,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: chrome.floatingFill,
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
            IconButton(
              padding: const EdgeInsets.all(8),
              constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
              icon: Icon(Icons.arrow_back, color: chrome.textPrimary, size: 22),
              onPressed: () => Navigator.pop(context),
            ),
            const SizedBox(width: 4),
            SizedBox(
              width: 64,
              height: 64,
              child: Image.asset(
                'assets/images/finance_manager_new_icons/Audit_sidebar.png',
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) => Icon(
                  Icons.fact_check_outlined,
                  size: 40,
                  color: chrome.textPrimary,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: chrome.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Proposal #${proposal['id']} • v${proposal['version_number'] ?? 1} • ${_formatDate(proposal['version_created_at'] ?? proposal['updated_at'])}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: chrome.textSecondary,
                      fontSize: 12,
                      height: 1.15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Opp ${proposal['opportunity_id'] ?? '—'} • Stage: ${proposal['engagement_stage'] ?? 'N/A'} • Owner: ${proposal['owner_name'] ?? 'Unknown'}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: chrome.textSecondary,
                      fontSize: 11,
                      height: 1.15,
                    ),
                  ),
                ],
              ),
            ),
            _buildProposalStatusChip(status, chrome),
            const SizedBox(width: 4),
            if (_selectedTab == 0)
              IconButton(
                tooltip: 'Refresh preview',
                onPressed: _loadPdfPreview,
                icon: Icon(Icons.refresh, color: chrome.textPrimary),
              ),
          ],
        ),
      ),
    );
  }

  String _normalizeClientProposalStatus(String rawStatus) {
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

  Widget _buildProposalStatusChip(String rawStatus, ManagerChromeTheme chrome) {
    final label = _normalizeClientProposalStatus(rawStatus);
    final lower = label.toLowerCase();
    Color bg = chrome.isDark
        ? Colors.white.withValues(alpha: 0.12)
        : Colors.black.withValues(alpha: 0.08);
    Color fg = chrome.textPrimary;

    if (lower.contains('signed')) {
      bg = const Color(0xFF6CA510);
      fg = Colors.white;
    } else if (lower.contains('declined') || lower.contains('rejected')) {
      bg = const Color(0xFFE74C3C);
      fg = Colors.white;
    } else if (lower.contains('pending') ||
        lower.contains('released') ||
        lower.contains('signature') ||
        lower.contains('sent') ||
        lower.contains('review')) {
      bg = const Color(0xFFEA990C);
      fg = Colors.white;
    }

    return Padding(
      padding: const EdgeInsets.only(left: 6),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 148),
        child: SizedBox(
          height: 26,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(26),
            ),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
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
          ),
        ),
      ),
    );
  }

  Widget _buildSignaturePanel() {
    final sig = _signatureData;
    final status = (sig?['status'] ?? _signatureStatus ?? 'unknown').toString();
    final signedAt = (sig?['signed_at'] ?? '').toString();
    final signedUrl = (sig?['signed_document_url'] ?? '').toString();
    final signingUrl = (sig?['signing_url'] ?? _signingUrl ?? '').toString();

    if (signingUrl.trim().isNotEmpty &&
        (_signingUrl == null || _signingUrl!.isEmpty)) {
      _signingUrl = signingUrl;
    }

    String subtitle = status;
    if (signedAt.trim().isNotEmpty) {
      subtitle = '$status • $signedAt';
    }
    final isUnknown = status.trim().toLowerCase() == 'unknown';
    final hasUsefulState = !isUnknown || signedUrl.trim().isNotEmpty;
    if (!hasUsefulState) {
      return const SizedBox.shrink();
    }

    final chrome = context.watch<ManagerThemeController>().chrome;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: GlassContainer(
        borderRadius: 12,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(Icons.verified_outlined, size: 18, color: chrome.textPrimary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                subtitle,
                style: TextStyle(
                    color: chrome.textPrimary, fontWeight: FontWeight.w600),
              ),
            ),
            if (signedUrl.trim().isNotEmpty)
              TextButton.icon(
                onPressed: () async {
                  if (kIsWeb) {
                    web.window.open(signedUrl, '_blank');
                    return;
                  }
                  await launchUrlString(signedUrl);
                },
                icon: const Icon(Icons.open_in_new, size: 18),
                label: const Text('View'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFloatingActionToolbar() {
    final chrome = context.watch<ManagerThemeController>().chrome;
    final sig = _signatureData;
    final signedUrl = (sig?['signed_document_url'] ?? '').toString();
    final canSign = _canSignInApp();

    Widget _toolButton({
      required IconData icon,
      required String tooltip,
      required VoidCallback onPressed,
      bool primary = false,
    }) {
      final bg = primary
          ? const Color(0xFF2D9CDB)
          : (chrome.isDark
              ? Colors.white.withValues(alpha: 0.10)
              : Colors.white.withValues(alpha: 0.45));
      final fg = primary ? Colors.white : chrome.textPrimary;
      return Tooltip(
        message: tooltip,
        child: Material(
          color: bg,
          elevation: 2,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: onPressed,
            child: SizedBox(
              width: 44,
              height: 44,
              child: Icon(icon, color: fg, size: 22),
            ),
          ),
        ),
      );
    }

    return GlassContainer(
      borderRadius: 14,
      padding: const EdgeInsets.all(10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _toolButton(
            icon: Icons.picture_as_pdf,
            tooltip: 'Export PDF',
            onPressed: _exportPdf,
          ),
          const SizedBox(height: 10),
          _toolButton(
            icon: Icons.description,
            tooltip: 'Export Word',
            onPressed: _exportWord,
          ),
          const SizedBox(height: 10),
          _toolButton(
            icon: Icons.document_scanner,
            tooltip: 'Scan (Phone Camera)',
            onPressed: _scanSignedDocument,
          ),
          const SizedBox(height: 10),
          _toolButton(
            icon: Icons.upload_file,
            tooltip: 'Upload Signed',
            onPressed: _uploadSignedDocument,
          ),
          if (signedUrl.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            _toolButton(
              icon: Icons.open_in_new,
              tooltip: 'View Signed',
              onPressed: () {
                if (kIsWeb) {
                  web.window.open(signedUrl, '_blank');
                  return;
                }
                launchUrlString(signedUrl);
              },
            ),
          ],
          if (canSign) ...[
            const SizedBox(height: 10),
            _toolButton(
              icon: Icons.draw,
              tooltip: 'Sign in app',
              onPressed: _openSigningModal,
              primary: true,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActionBar() {
    final signatureStatus = (_signatureStatus ?? '').toLowerCase();
    final isSigned = signatureStatus.contains('completed');
    final canInApp = _canSignInApp();
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Row(
        children: [
          if (!isSigned)
            Expanded(
              child: Align(
                alignment: Alignment.centerLeft,
                child: ElevatedButton.icon(
                  onPressed: _showRejectDialog,
                  icon: const Icon(Icons.cancel, size: 18),
                  label: const Text('Reject'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFC10D00),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 22, vertical: 12),
                    shape: const StadiumBorder(),
                  ),
                ),
              ),
            ),
          Expanded(
            child: Align(
              alignment: Alignment.centerRight,
              child: (!isSigned && canInApp)
                  ? ElevatedButton.icon(
                      onPressed: () {
                        _logEvent('sign',
                            metadata: {'action': 'sign_button_clicked'});
                        _openSigningModal();
                      },
                      icon: const Icon(Icons.draw, size: 18),
                      label: const Text('Sign Proposal'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF7F7F7F),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 22, vertical: 12),
                        shape: const StadiumBorder(),
                      ),
                    )
                  : (!isSigned && !canInApp)
                      ? ElevatedButton.icon(
                          onPressed: _showApproveDialog,
                          icon: const Icon(Icons.check_circle, size: 18),
                          label: const Text('Approve'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF7F7F7F),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 22, vertical: 12),
                            shape: const StadiumBorder(),
                          ),
                        )
                      : const SizedBox.shrink(),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openSigningModal() async {
    _logEvent('sign', metadata: {'action': 'in_app_sign_modal'});
    final hash = _proposalData?['signing_payload_hash']?.toString() ?? '';
    if (hash.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Loading signing data… Refresh and try again if this persists.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      await _loadProposal();
      return;
    }

    _signatureController.clear();
    _signerNameController.text =
        (_proposalData?['client_name'] ?? '').toString().trim();

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        var step = 0;
        var consent = false;
        var busy = false;
        return StatefulBuilder(
          builder: (ctx, setModal) {
            Future<void> submit() async {
              final name = _signerNameController.text.trim();
              if (!consent) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Please acknowledge before signing.')),
                );
                return;
              }
              if (name.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Enter your full name.')),
                );
                return;
              }
              if (_signatureController.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please draw your signature.')),
                );
                return;
              }

              setModal(() => busy = true);
              try {
                final png = await _signatureController.toPngBytes();
                if (png == null || png.isEmpty) {
                  throw Exception('Could not export signature');
                }
                final b64 = base64Encode(png);
                final headers = <String, String>{
                  'Content-Type': 'application/json',
                  ..._clientDeviceHeaders(),
                };
                final resp = await http
                    .post(
                      Uri.parse(
                        '$baseUrl/api/client/proposals/${widget.proposalId}/sign',
                      ),
                      headers: headers,
                      body: jsonEncode({
                        'token': widget.accessToken,
                        'signing_payload_hash': hash,
                        'signer_name': name,
                        'consent_acknowledged': true,
                        'consent_version': 'v1',
                        'signature_png_base64': b64,
                      }),
                    )
                    .timeout(const Duration(seconds: 90));

                if (!dialogCtx.mounted) return;

                if (resp.statusCode >= 200 && resp.statusCode < 300) {
                  Map<String, dynamic>? okBody;
                  try {
                    final d = jsonDecode(resp.body);
                    if (d is Map<String, dynamic>) okBody = d;
                  } catch (_) {}
                  final signedPdfUrl =
                      (okBody?['signed_document_url'] ?? '').toString().trim();
                  final sigImgUrl =
                      (okBody?['signature_image_url'] ?? '').toString().trim();

                  Navigator.pop(dialogCtx);
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Signed successfully.'),
                      backgroundColor: Colors.green,
                    ),
                  );
                  await _loadProposal();
                  if (!mounted) return;
                  if (signedPdfUrl.isNotEmpty) {
                    _showSignedSubmissionPreview(
                      signedPdfUrl: signedPdfUrl,
                      signatureImageUrl:
                          sigImgUrl.isNotEmpty ? sigImgUrl : null,
                      signerName: name,
                    );
                  }
                  return;
                }

                Map<String, dynamic>? err;
                try {
                  final d = jsonDecode(resp.body);
                  if (d is Map<String, dynamic>) err = d;
                } catch (_) {}
                final detail = err?['detail']?.toString() ?? resp.body;
                if (resp.statusCode == 409) {
                  await _loadProposal();
                }
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(detail),
                    backgroundColor: Colors.red,
                  ),
                );
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Sign failed: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              } finally {
                if (dialogCtx.mounted) {
                  setModal(() => busy = false);
                }
              }
            }

            void goNext() {
              if (step == 0) {
                if (!consent) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                          'Confirm that you have reviewed and agree to sign.'),
                    ),
                  );
                  return;
                }
                setModal(() => step = 1);
                return;
              }
              if (step == 1) {
                final name = _signerNameController.text.trim();
                if (name.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Enter your full name.')),
                  );
                  return;
                }
                if (_signatureController.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Please draw your signature.')),
                  );
                  return;
                }
                setModal(() => step = 2);
              }
            }

            void goBack() {
              if (step <= 0) return;
              setModal(() => step = step - 1);
            }

            Widget stepBody() {
              switch (step) {
                case 0:
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Review the proposal on the Proposal tab, then confirm you are ready to sign.',
                        style: TextStyle(fontSize: 14, height: 1.45),
                      ),
                      const SizedBox(height: 16),
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text(
                          'I have read this proposal and agree to sign electronically.',
                          style: TextStyle(fontSize: 13),
                        ),
                        value: consent,
                        onChanged: busy
                            ? null
                            : (v) => setModal(() => consent = v ?? false),
                      ),
                    ],
                  );
                case 1:
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        controller: _signerNameController,
                        decoration: const InputDecoration(
                          labelText: 'Full name (as signature)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Draw your signature',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 200,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Signature(
                            controller: _signatureController,
                            backgroundColor: Colors.grey.shade200,
                          ),
                        ),
                      ),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton(
                          onPressed: busy
                              ? null
                              : () =>
                                  setModal(() => _signatureController.clear()),
                          child: const Text('Clear signature'),
                        ),
                      ),
                    ],
                  );
                default:
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Submitting creates a legally binding electronic signature record stored with your proposal.',
                        style: TextStyle(fontSize: 14, height: 1.45),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Signer: ${_signerNameController.text.trim()}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ],
                  );
              }
            }

            final titles = ['Acknowledge', 'Sign', 'Confirm'];
            return AlertDialog(
              title: Text('Sign proposal — ${titles[step.clamp(0, 2)]}'),
              content: SizedBox(
                width: 440,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: List.generate(3, (i) {
                          final active = step == i;
                          return Expanded(
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 2),
                              child: Container(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 6),
                                decoration: BoxDecoration(
                                  color: active
                                      ? const Color(0xFF2D9CDB)
                                          .withValues(alpha: 0.15)
                                      : Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '${i + 1}. ${titles[i]}',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: active
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
                      const SizedBox(height: 20),
                      stepBody(),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: busy
                      ? null
                      : () {
                          if (step == 0) {
                            Navigator.pop(dialogCtx);
                          } else {
                            goBack();
                          }
                        },
                  child: Text(step == 0 ? 'Cancel' : 'Back'),
                ),
                if (step < 2)
                  ElevatedButton(
                    onPressed: busy ? null : goNext,
                    child: const Text('Next'),
                  )
                else
                  ElevatedButton(
                    onPressed: busy ? null : submit,
                    child: busy
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Sign & submit'),
                  ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildProposalContent(Map<String, dynamic> proposal) {
    final parsed = ClientProposalDocumentPreview.parseDocumentData(proposal);
    final hasStructuredSections = parsed != null &&
        parsed['sections'] is List &&
        (parsed['sections'] as List).isNotEmpty;

    Widget shell(Widget child) {
      return RawScrollbar(
        controller: _proposalScrollController,
        thumbVisibility: true,
        trackVisibility: true,
        interactive: true,
        thickness: 12,
        radius: const Radius.circular(10),
        thumbColor: const Color(0xFFC10D00),
        trackColor: Colors.black.withValues(alpha: 0.25),
        trackBorderColor: Colors.white.withValues(alpha: 0.25),
        child: SingleChildScrollView(
          controller: _proposalScrollController,
          padding: const EdgeInsets.all(24),
          child: child,
        ),
      );
    }

    if (hasStructuredSections) {
      return shell(
        ClientProposalDocumentPreview(proposal: proposal),
      );
    }

    if (!kIsWeb) {
      final content = proposal['content']?.toString() ?? '';
      return shell(
        SelectableText(
          content.isNotEmpty ? content : 'No proposal content available.',
          style: const TextStyle(
            fontSize: 15,
            height: 1.8,
            color: Color(0xFF34495E),
          ),
        ),
      );
    }

    return shell(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            proposal['title'] ?? 'Untitled',
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2C3E50),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Shared by ${proposal['owner_name'] ?? 'Unknown'}',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          const Divider(height: 40),
          _buildContentSections(proposal['content']),
        ],
      ),
    );
  }

  void _onSectionChanged(int newIndex) {
    if (_sections.isEmpty) return;
    final bounded = newIndex.clamp(0, _sections.length - 1);
    if (bounded == _currentSectionIndex) return;

    _logCurrentSectionView();

    setState(() {
      _currentSectionIndex = bounded;
      _sectionViewStart = DateTime.now();
    });
  }

  Widget _buildContentSections(dynamic content) {
    if (_sections.isNotEmpty) {
      final total = _sections.length;
      final index = _currentSectionIndex.clamp(0, total - 1);
      final currentSection = _sections[index];
      final sectionTitle =
          (currentSection['title']?.toString().trim().isNotEmpty ?? false)
              ? currentSection['title'].toString().trim()
              : 'Section ${index + 1}';
      final sectionContent = currentSection['content']?.toString() ??
          currentSection['text']?.toString() ??
          '';

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 380;
              final left = const Text(
                'Sections',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF2C3E50),
                ),
              );
              final right = Text(
                'Section ${index + 1} of $total',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
                overflow: TextOverflow.ellipsis,
              );

              if (!isNarrow) {
                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    left,
                    right,
                  ],
                );
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  left,
                  const SizedBox(height: 6),
                  right,
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: List.generate(total, (i) {
                final section = _sections[i];
                final title =
                    (section['title']?.toString().trim().isNotEmpty ?? false)
                        ? section['title'].toString().trim()
                        : 'Section ${i + 1}';
                final isSelected = i == index;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(
                      title,
                      overflow: TextOverflow.ellipsis,
                    ),
                    selected: isSelected,
                    onSelected: (selected) {
                      if (selected) {
                        _onSectionChanged(i);
                      }
                    },
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            sectionTitle,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Color(0xFF2C3E50),
            ),
          ),
          const SizedBox(height: 12),
          SelectableText(
            sectionContent,
            style: const TextStyle(
              fontSize: 15,
              height: 1.8,
              color: Color(0xFF34495E),
            ),
          ),
          const SizedBox(height: 24),
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 520;
              final prev = TextButton.icon(
                onPressed:
                    index > 0 ? () => _onSectionChanged(index - 1) : null,
                icon: const Icon(Icons.chevron_left),
                label: const Text('Previous section'),
              );
              final next = TextButton.icon(
                onPressed: index < total - 1
                    ? () => _onSectionChanged(index + 1)
                    : null,
                label: const Text('Next section'),
                icon: const Icon(Icons.chevron_right),
              );

              if (!isNarrow) {
                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    prev,
                    next,
                  ],
                );
              }

              return Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  prev,
                  next,
                ],
              );
            },
          ),
        ],
      );
    }

    if (content == null || content.toString().isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.description_outlined,
                  size: 64, color: Colors.grey[400]),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _exportPdf,
                icon: const Icon(Icons.picture_as_pdf),
                label: const Text('Export PDF'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _exportWord,
                icon: const Icon(Icons.description),
                label: const Text('Export Word'),
              ),
            ],
          ),
        ),
      );
    }

    if (_isPdfLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_pdfError != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Failed to load preview: $_pdfError'),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _loadPdfPreview,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_pdfObjectUrl == null) {
      return Center(
        child: ElevatedButton.icon(
          onPressed: _loadPdfPreview,
          icon: const Icon(Icons.picture_as_pdf),
          label: const Text('Load PDF Preview'),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.78,
        child: Stack(
          children: [
            GlassContainer(
              borderRadius: 12,
              padding: const EdgeInsets.all(0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox.expand(
                  child: HtmlElementView(viewType: _pdfViewType),
                ),
              ),
            ),
            Positioned(
              right: 14,
              bottom: 20,
              child: PointerInterceptor(
                child: _buildFloatingActionToolbar(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCommentsSection() {
    return RawScrollbar(
      controller: _commentsScrollController,
      thumbVisibility: true,
      trackVisibility: true,
      interactive: true,
      thickness: 12,
      radius: const Radius.circular(10),
      thumbColor: const Color(0xFFC10D00),
      trackColor: Colors.black.withValues(alpha: 0.25),
      trackBorderColor: Colors.white.withValues(alpha: 0.25),
      child: SingleChildScrollView(
        controller: _commentsScrollController,
        padding: const EdgeInsets.all(24),
        child: GlassContainer(
          borderRadius: 12,
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Discussion & Comments',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2C3E50),
                ),
              ),
              const SizedBox(height: 24),

              // Add comment
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _commentController,
                      decoration: InputDecoration(
                        hintText: 'Add a comment or question...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding: const EdgeInsets.all(16),
                      ),
                      maxLines: 3,
                      enabled: !_isSubmittingComment,
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: _isSubmittingComment ? null : _submitComment,
                    icon: _isSubmittingComment
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send, size: 18),
                    label: const Text('Send'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF3498DB),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 20),
                    ),
                  ),
                ],
              ),

              const Divider(height: 40),

              // Comments list
              if (_comments.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(40),
                    child: Column(
                      children: [
                        Icon(Icons.chat_bubble_outline,
                            size: 64, color: Colors.grey[300]),
                        const SizedBox(height: 16),
                        Text(
                          'No comments yet',
                          style:
                              TextStyle(fontSize: 16, color: Colors.grey[600]),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Be the first to add a comment',
                          style:
                              TextStyle(fontSize: 14, color: Colors.grey[500]),
                        ),
                      ],
                    ),
                  ),
                )
              else
                ..._comments
                    .map((comment) => _buildCommentItem(comment))
                    .toList(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCommentItem(Map<String, dynamic> comment) {
    final commenterName = comment['created_by_name']?.toString() ??
        comment['created_by_email']?.toString() ??
        'User';
    final commentText = comment['comment_text']?.toString() ?? '';
    final timestamp = comment['created_at']?.toString() ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: const Color(0xFF3498DB),
                child: Text(
                  commenterName.isNotEmpty
                      ? commenterName[0].toUpperCase()
                      : 'U',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      commenterName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      _formatDate(timestamp),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            commentText,
            style: const TextStyle(fontSize: 14, height: 1.5),
          ),
        ],
      ),
    );
  }

  String _formatDate(dynamic date) {
    if (date == null) return 'N/A';
    try {
      final raw = date.toString();
      final hasTimezone = RegExp(r'(Z|[+-]\d{2}:\d{2})$').hasMatch(raw);
      final parsedRaw = DateTime.parse(raw);
      final dt = hasTimezone
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

// Reject Dialog
/// One-off iframe factory per dialog instance (Flutter web PDF preview).
class _SignedPdfHtmlEmbed extends StatefulWidget {
  const _SignedPdfHtmlEmbed({required this.url});

  final String url;

  @override
  State<_SignedPdfHtmlEmbed> createState() => _SignedPdfHtmlEmbedState();
}

class _SignedPdfHtmlEmbedState extends State<_SignedPdfHtmlEmbed> {
  late final String _viewType;

  @override
  void initState() {
    super.initState();
    _viewType = 'signed-pdf-preview-${DateTime.now().microsecondsSinceEpoch}';
    // ignore: undefined_prefixed_name
    ui_web.platformViewRegistry.registerViewFactory(_viewType, (int viewId) {
      return html.IFrameElement()
        ..style.border = 'none'
        ..style.width = '100%'
        ..style.height = '100%'
        ..src = widget.url
        ..allow = 'fullscreen';
    });
  }

  @override
  Widget build(BuildContext context) => HtmlElementView(viewType: _viewType);
}

class RejectDialog extends StatefulWidget {
  final int proposalId;
  final String accessToken;
  final VoidCallback onSuccess;

  const RejectDialog({
    super.key,
    required this.proposalId,
    required this.accessToken,
    required this.onSuccess,
  });

  @override
  State<RejectDialog> createState() => _RejectDialogState();
}

class _RejectDialogState extends State<RejectDialog> {
  final TextEditingController _reasonController = TextEditingController();
  bool _isSubmitting = false;

  Future<void> _submit() async {
    if (_reasonController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please provide a reason for rejection'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/client/proposals/${widget.proposalId}/reject'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'token': widget.accessToken,
          'reason': _reasonController.text.trim(),
        }),
      );

      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Proposal rejected'),
              backgroundColor: Colors.orange,
            ),
          );
          widget.onSuccess();
        }
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['detail'] ?? 'Failed to reject');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 500,
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.cancel, color: Colors.red, size: 28),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Text(
                    'Reject Proposal',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2C3E50),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Text(
              'Please provide a reason for rejecting this proposal. This will help the team understand your concerns.',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _reasonController,
              decoration: InputDecoration(
                labelText: 'Reason for Rejection *',
                hintText: 'Explain why you are rejecting this proposal...',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
              maxLines: 5,
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed:
                      _isSubmitting ? null : () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: _isSubmitting ? null : _submit,
                  icon: _isSubmitting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.cancel),
                  label: const Text('Reject Proposal'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }
}

// Approve Dialog
class ApproveDialog extends StatefulWidget {
  final int proposalId;
  final String accessToken;
  final VoidCallback onSuccess;

  const ApproveDialog({
    super.key,
    required this.proposalId,
    required this.accessToken,
    required this.onSuccess,
  });

  @override
  State<ApproveDialog> createState() => _ApproveDialogState();
}

class _ApproveDialogState extends State<ApproveDialog> {
  final TextEditingController _signerNameController = TextEditingController();
  final TextEditingController _signerTitleController = TextEditingController();
  final TextEditingController _commentsController = TextEditingController();
  bool _isSubmitting = false;

  static const Duration _networkTimeout = Duration(seconds: 20);

  Future<void> _submit() async {
    if (_signerNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please provide your name'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final response = await http
          .post(
            Uri.parse(
                '$baseUrl/api/client/proposals/${widget.proposalId}/approve'),
            headers: {
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'token': widget.accessToken,
              'signer_name': _signerNameController.text.trim(),
              'signer_title': _signerTitleController.text.trim(),
              'comments': _commentsController.text.trim(),
            }),
          )
          .timeout(_networkTimeout);

      print('✅ Client approve response: ${response.statusCode}');
      final bodyText = response.body;
      if (bodyText.isNotEmpty) {
        final preview =
            bodyText.length > 500 ? bodyText.substring(0, 500) : bodyText;
        print('✅ Client approve body (preview): $preview');
      }

      if (response.statusCode == 200) {
        if (mounted) {
          Navigator.pop(context); // Close approve dialog
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'Use Sign on the toolbar to complete first-party electronic signing.'),
              backgroundColor: Colors.green,
            ),
          );
          widget.onSuccess();
        }
      } else {
        String detail = 'Failed to approve';
        try {
          final decoded = jsonDecode(response.body);
          if (decoded is Map && decoded['detail'] != null) {
            detail = decoded['detail'].toString();
          } else {
            detail = response.body;
          }
        } catch (_) {
          detail = response.body.isNotEmpty ? response.body : detail;
        }

        if (response.statusCode == 501) {
          throw Exception(
              'DocuSign disabled on server. Set ENABLE_DOCUSIGN=true. ($detail)');
        }

        throw Exception(detail);
      }
    } on TimeoutException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Approve timed out. Confirm backend is running on http://127.0.0.1:5000 and retry.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 500,
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.check_circle,
                      color: Colors.green, size: 28),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Text(
                    'Approve Proposal',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2C3E50),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Text(
              'Please provide your information to approve this proposal.',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _signerNameController,
              decoration: InputDecoration(
                labelText: 'Your Name *',
                hintText: 'Enter your full name',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _signerTitleController,
              decoration: InputDecoration(
                labelText: 'Your Title (Optional)',
                hintText: 'e.g., CEO, Director, Manager',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _commentsController,
              decoration: InputDecoration(
                labelText: 'Comments (Optional)',
                hintText: 'Any additional comments...',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed:
                      _isSubmitting ? null : () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: _isSubmitting ? null : _submit,
                  icon: _isSubmitting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.check_circle),
                  label: const Text('Approve Proposal'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF27AE60),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _signerNameController.dispose();
    _signerTitleController.dispose();
    _commentsController.dispose();
    super.dispose();
  }
}
