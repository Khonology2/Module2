import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../document_editor/models/document_table.dart';
import '../document_editor/models/positioned_pricing_table.dart';
import '../document_editor/widgets/table_widget.dart';
import '../theme/manager_theme_controller.dart';
import 'header.dart';

/// Read-only structured proposal body aligned with [ProposalReviewPage]
/// (admin/finance): metadata-driven header/footer and section pages including tables.
class ClientProposalDocumentPreview extends StatefulWidget {
  final Map<String, dynamic> proposal;
  final ScrollController? scrollController;
  final ValueChanged<int>? onSectionChanged;

  const ClientProposalDocumentPreview({
    super.key,
    required this.proposal,
    this.scrollController,
    this.onSectionChanged,
  });

  @override
  State<ClientProposalDocumentPreview> createState() =>
      _ClientProposalDocumentPreviewState();

  static const String _stdHeaderLogo =
      'assets/images/new icons for manager/khonology_logo.png';
  static const String _stdFooterAsset = 'assets/images/footer.png';
  static const String _stdRiskGateAsset =
      'assets/images/new icons for manager/risk_gate_tab.png';

  static Map<String, dynamic>? parseDocumentData(
      Map<String, dynamic> proposal) {
    dynamic raw = proposal['content'];
    Map<String, dynamic>? decoded;
    if (raw is String && raw.trim().isNotEmpty) {
      try {
        final d = json.decode(raw);
        if (d is Map<String, dynamic>) {
          decoded = d;
        }
      } catch (_) {}
    } else if (raw is Map<String, dynamic>) {
      decoded = raw;
    }

    if (decoded != null && proposal['sections'] != null) {
      decoded = Map<String, dynamic>.from(decoded);
      decoded['sections'] = proposal['sections'];
    }

    if (decoded == null && proposal['sections'] is List) {
      return {
        'title': proposal['title'],
        'sections': proposal['sections'],
        'metadata': <String, dynamic>{},
      };
    }

    return decoded;
  }

  static bool _isTruthy(dynamic value) {
    if (value is bool) return value;
    if (value is int) return value == 1;
    if (value is String) {
      final v = value.trim().toLowerCase();
      return v == 'true' || v == '1' || v == 't' || v == 'yes';
    }
    return false;
  }

  static DateTime _parseStandardizedDateFromMetadata(
      Map<String, dynamic> metadata) {
    final raw = metadata['standardizedProposalDate']?.toString().trim() ?? '';
    if (raw.isEmpty) {
      return DateTime.now();
    }
    final iso = DateTime.tryParse(raw);
    if (iso != null) return iso;
    try {
      return DateFormat('yyyy-MM-dd').parse(raw);
    } catch (_) {}
    try {
      return DateFormat('dd/MM/yyyy').parse(raw);
    } catch (_) {}
    return DateTime.now();
  }

  static Alignment _alignmentForFooterPosition(String? position) {
    switch (position) {
      case 'left':
        return Alignment.centerLeft;
      case 'right':
        return Alignment.centerRight;
      case 'center':
      default:
        return Alignment.center;
    }
  }

  static String _formatContent(dynamic content) {
    if (content == null) return 'No content available';
    if (content is String) {
      try {
        final parsed = json.decode(content);
        if (parsed is Map && parsed.containsKey('sections')) {
          final sections = parsed['sections'] as List;
          return sections.map((s) {
            final title = s['title'] ?? 'Untitled Section';
            final sectionContent = s['content'] ?? '';
            return '$title\n\n$sectionContent';
          }).join('\n\n---\n\n');
        }
        return content;
      } catch (_) {
        return content;
      }
    }
    return content.toString();
  }

  Widget _readOnlyStandardizedReportFooter() {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),
      ),
      child: Center(
        child: Image.asset(
          _stdFooterAsset,
          fit: BoxFit.contain,
          height: 28,
          errorBuilder: (_, __, ___) => const Text(
            'CCC',
            style: TextStyle(
              color: Color(0xFFC10D00),
              fontWeight: FontWeight.w800,
              fontSize: 22,
              letterSpacing: 0.8,
            ),
          ),
        ),
      ),
    );
  }

  Widget _readOnlyStandardizedReportHeader({
    required String pageTitle,
    required bool showMetaBar,
    required DateTime standardizedDate,
    bool showRiskIcon = true,
  }) {
    return Container(
      height: 118,
      decoration: BoxDecoration(
        image: DecorationImage(
          image: AssetImage(ManagerChromeTheme.darkBgAsset),
          fit: BoxFit.cover,
        ),
      ),
      child: Column(
        children: [
          Expanded(
            child: Container(
              color: Colors.black.withValues(alpha: 0.14),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 22, vertical: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Transform.translate(
                            offset: const Offset(-8, 0),
                            child: SizedBox(
                              height: 50,
                              child: Image.asset(
                                _stdHeaderLogo,
                                fit: BoxFit.contain,
                                alignment: Alignment.centerLeft,
                                errorBuilder: (_, __, ___) => const Text(
                                  'KHONOLOGY',
                                  style: TextStyle(
                                    color: Color(0xFFC10D00),
                                    fontSize: 24,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 2.8,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const Padding(
                            padding: EdgeInsets.only(left: 20),
                            child: Text(
                              'PROPOSAL REPORT',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.4,
                                height: 1.0,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (showRiskIcon)
                      Align(
                        alignment: Alignment.centerRight,
                        child: Container(
                          width: 58,
                          height: 58,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.9),
                              width: 2,
                            ),
                          ),
                          padding: const EdgeInsets.all(4),
                          child: Transform.scale(
                            scale: 2.0,
                            child: Image.asset(
                              _stdRiskGateAsset,
                              fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) => const Icon(
                                Icons.health_and_safety,
                                color: Color(0xFFC10D00),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          if (!showMetaBar)
            Container(
              width: double.infinity,
              color: Colors.black.withValues(alpha: 0.22),
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.calendar_month,
                        color: Colors.white,
                        size: 14,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        DateFormat('dd/MM/yyyy').format(standardizedDate),
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
            ),
          if (showMetaBar)
            Container(
              width: double.infinity,
              color: const Color(0xFFC10D00),
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 8),
              child: pageTitle.trim().isEmpty
                  ? Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        'Date: ${DateFormat('dd/MM/yyyy').format(standardizedDate)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    )
                  : Row(
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              const Text(
                                'Title: ',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  pageTitle,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Date: ${DateFormat('dd/MM/yyyy').format(standardizedDate)}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
            ),
        ],
      ),
    );
  }

  Widget _buildAdminHeader(
    Map<String, dynamic> metadata,
    String? documentTitle,
  ) {
    final headerLogoUrl = metadata['headerLogoUrl'] as String?;
    final headerLogoPosition =
        (metadata['headerLogoPosition'] as String?) ?? 'left';
    final headerBackgroundImageUrl =
        metadata['headerBackgroundImageUrl'] as String?;

    Widget? logoWidget;
    if (headerLogoUrl != null && headerLogoUrl.trim().isNotEmpty) {
      logoWidget = SizedBox(
        height: 32,
        child: Image.network(
          headerLogoUrl,
          fit: BoxFit.contain,
        ),
      );
    }

    final titleText = documentTitle?.trim();

    return DocumentHeader(
      title: titleText != null && titleText.isNotEmpty ? titleText : null,
      subtitle: null,
      leading: headerLogoPosition == 'left' ? logoWidget : null,
      center: headerLogoPosition == 'center' ? logoWidget : null,
      trailing: headerLogoPosition == 'right' ? logoWidget : null,
      backgroundImageUrl: headerBackgroundImageUrl,
      showDivider: false,
    );
  }

  Widget _buildAdminFooter({
    required Map<String, dynamic> metadata,
    required int pageNumber,
    required int totalPages,
    required int? proposalId,
  }) {
    final footerLogoUrl = metadata['footerLogoUrl'] as String?;
    final footerLogoPosition =
        (metadata['footerLogoPosition'] as String?) ?? 'left';
    final footerPageNumberPosition =
        (metadata['footerPageNumberPosition'] as String?) ?? 'center';
    final footerProposalIdPosition =
        (metadata['footerProposalIdPosition'] as String?) ?? 'right';

    Widget? logo;
    if (footerLogoUrl != null && footerLogoUrl.trim().isNotEmpty) {
      logo = Align(
        alignment: _alignmentForFooterPosition(footerLogoPosition),
        child: SizedBox(
          width: 80,
          height: 32,
          child: Image.network(
            footerLogoUrl,
            fit: BoxFit.contain,
          ),
        ),
      );
    }

    final pageChip = Align(
      alignment: _alignmentForFooterPosition(footerPageNumberPosition),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.grey[100]!.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: Text(
          'Page $pageNumber of $totalPages',
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );

    Widget? proposalIdWidget;
    if (proposalId != null) {
      proposalIdWidget = Align(
        alignment: _alignmentForFooterPosition(footerProposalIdPosition),
        child: Text(
          'Proposal ID: $proposalId',
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
      );
    }

    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Color(0xFFE5E7EB)),
        ),
      ),
      child: Stack(
        children: [
          if (logo != null) logo,
          pageChip,
          if (proposalIdWidget != null) proposalIdWidget,
        ],
      ),
    );
  }
}

class _ClientProposalDocumentPreviewState
    extends State<ClientProposalDocumentPreview> {
  late ScrollController _controller;
  bool _ownsController = false;
  int? _lastSectionIndex;

  static const double _pageHeight = 1273;
  static const double _pageSpacing = 32;

  @override
  void initState() {
    super.initState();
    _controller = widget.scrollController ?? ScrollController();
    _ownsController = widget.scrollController == null;
    _controller.addListener(_handleScroll);
  }

  @override
  void didUpdateWidget(covariant ClientProposalDocumentPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scrollController != widget.scrollController) {
      _controller.removeListener(_handleScroll);

      if (_ownsController) {
        _controller.dispose();
      }

      _lastSectionIndex = null;
      _controller = widget.scrollController ?? ScrollController();
      _ownsController = widget.scrollController == null;
      _controller.addListener(_handleScroll);
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_handleScroll);
    if (_ownsController) {
      _controller.dispose();
    }
    super.dispose();
  }

  void _handleScroll() {
    final cb = widget.onSectionChanged;
    if (cb == null) return;

    final stride = _pageHeight + _pageSpacing;
    final offset = _controller.hasClients ? _controller.offset : 0.0;

    final raw = ((offset + (stride / 2)) / stride).floor();
    final idx = raw < 0 ? 0 : raw;

    if (_lastSectionIndex == idx) return;
    _lastSectionIndex = idx;
    cb(idx);
  }

  @override
  Widget build(BuildContext context) {
    final data =
        ClientProposalDocumentPreview.parseDocumentData(widget.proposal);
    if (data == null) {
      return SelectableText(
        ClientProposalDocumentPreview._formatContent(
            widget.proposal['content']),
        style: const TextStyle(
          color: Colors.black87,
          fontSize: 14,
          height: 1.6,
        ),
      );
    }

    final sectionsRaw = data['sections'];
    if (sectionsRaw is! List || sectionsRaw.isEmpty) {
      return SelectableText(
        ClientProposalDocumentPreview._formatContent(
            widget.proposal['content']),
        style: const TextStyle(
          color: Colors.black87,
          fontSize: 14,
          height: 1.6,
        ),
      );
    }

    final List<Map<String, dynamic>> sections = sectionsRaw
        .whereType<Map>()
        .map((s) => Map<String, dynamic>.from(s))
        .toList();

    final metadata = (data['metadata'] is Map)
        ? Map<String, dynamic>.from(data['metadata'] as Map)
        : <String, dynamic>{};

    final useStandardized = ClientProposalDocumentPreview._isTruthy(
        metadata['standardizedProposalLayout']);
    final DateTime standardizedDate =
        ClientProposalDocumentPreview._parseStandardizedDateFromMetadata(
            metadata);
    final rawDocTitle =
        (data['title'] ?? widget.proposal['title'] ?? '').toString().trim();
    final String? displayDocumentTitleForCustomHeader =
        rawDocTitle.isNotEmpty ? rawDocTitle : null;

    final headerLogoUrl = metadata['headerLogoUrl'] as String?;
    final headerBackgroundImageUrl =
        metadata['headerBackgroundImageUrl'] as String?;
    final footerLogoUrl = metadata['footerLogoUrl'] as String?;
    final showCustomHeader = !useStandardized &&
        ((headerLogoUrl != null && headerLogoUrl.trim().isNotEmpty) ||
            (headerBackgroundImageUrl != null &&
                headerBackgroundImageUrl.trim().isNotEmpty));
    final showCustomFooter = !useStandardized &&
        footerLogoUrl != null &&
        footerLogoUrl.trim().isNotEmpty;

    int? proposalId;
    final dynamic rawId = widget.proposal['id'];
    if (rawId is int) {
      proposalId = rawId;
    } else if (rawId is String) {
      proposalId = int.tryParse(rawId);
    } else if (rawId != null) {
      proposalId = int.tryParse(rawId.toString());
    }

    const double pageWidth = 900;
    const double pageHeight = _pageHeight;

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxW = constraints.maxWidth;
        final scale = maxW < pageWidth + 48 ? (maxW - 48) / pageWidth : 1.0;

        Widget wrapPage(Widget child) {
          if (scale >= 0.999) {
            return Center(child: SizedBox(width: pageWidth, child: child));
          }
          return Center(
            child: Transform.scale(
              scale: scale,
              alignment: Alignment.topCenter,
              child: SizedBox(width: pageWidth, child: child),
            ),
          );
        }

        return SingleChildScrollView(
          controller: _controller,
          child: Column(
            children: [
              ...sections.asMap().entries.map((entry) {
                final index = entry.key;
                final section = entry.value;

                final sectionPageTitle = (section['title'] ?? '').toString();
                final sectionContent = (section['content'] ?? '').toString();

                String normalize(dynamic value) {
                  return (value ?? '')
                      .toString()
                      .trim()
                      .toLowerCase()
                      .replaceAll(RegExp(r'[_\-\s]+'), '');
                }

                final String? backgroundImageUrl =
                    section['backgroundImageUrl'] as String?;

                final bool isCover = ClientProposalDocumentPreview._isTruthy(
                        section['isCoverPage']) ||
                    normalize(section['sectionType']) == 'cover' ||
                    (index == 0 && backgroundImageUrl != null);

                final int? bgColorValue = section['backgroundColor'] is int
                    ? section['backgroundColor'] as int
                    : int.tryParse(
                        section['backgroundColor']?.toString() ?? '');
                final Color backgroundColor =
                    bgColorValue != null ? Color(bgColorValue) : Colors.white;

                Widget buildScrollableSectionBody() {
                  return Expanded(
                    child: SingleChildScrollView(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 60,
                          vertical: 24,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (sectionContent.isNotEmpty)
                              SelectableText(
                                sectionContent,
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Color(0xFF1A1A1A),
                                  height: 1.8,
                                  letterSpacing: 0.2,
                                ),
                              ),
                            if (section['tables'] is List)
                              ...((section['tables'] as List)
                                  .where((t) => t is Map)
                                  .map((t) {
                                final table = DocumentTable.fromJson(
                                  Map<String, dynamic>.from(t as Map),
                                );
                                return TableWidget(
                                  sectionIndex: index,
                                  tableIndex: null,
                                  table: table,
                                  currencySymbol: 'R',
                                  readOnly: true,
                                );
                              })),
                            if (section['positionedPricingTables'] is List)
                              ...((section['positionedPricingTables'] as List)
                                  .where((p) => p is Map)
                                  .map((p) {
                                final positioned =
                                    PositionedPricingTable.fromJson(
                                  Map<String, dynamic>.from(p as Map),
                                );
                                return TableWidget(
                                  sectionIndex: index,
                                  tableIndex: null,
                                  table: positioned.table,
                                  currencySymbol: 'R',
                                  readOnly: true,
                                );
                              })),
                          ],
                        ),
                      ),
                    ),
                  );
                }

                if (useStandardized && isCover) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 32),
                    child: wrapPage(
                      SizedBox(
                        width: pageWidth,
                        height: pageHeight,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.15),
                                blurRadius: 20,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              widget._readOnlyStandardizedReportHeader(
                                pageTitle: sectionPageTitle,
                                showMetaBar: false,
                                standardizedDate: standardizedDate,
                              ),
                              Expanded(
                                child: Container(
                                  width: double.infinity,
                                  color: Colors.white,
                                  child: backgroundImageUrl == null
                                      ? const SizedBox.shrink()
                                      : Image.network(
                                          backgroundImageUrl,
                                          fit: BoxFit.cover,
                                          alignment: Alignment.topCenter,
                                        ),
                                ),
                              ),
                              widget._readOnlyStandardizedReportFooter(),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }

                return Padding(
                  padding: const EdgeInsets.only(bottom: 32),
                  child: wrapPage(
                    SizedBox(
                      width: pageWidth,
                      height: pageHeight,
                      child: Container(
                        decoration: BoxDecoration(
                          color: backgroundImageUrl == null
                              ? backgroundColor
                              : Colors.white,
                          image: backgroundImageUrl != null
                              ? DecorationImage(
                                  image: NetworkImage(backgroundImageUrl),
                                  fit: BoxFit.cover,
                                  opacity: isCover ? 1.0 : 0.7,
                                )
                              : null,
                          borderRadius: isCover
                              ? BorderRadius.zero
                              : BorderRadius.circular(4),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.15),
                              blurRadius: 20,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            if (useStandardized)
                              widget._readOnlyStandardizedReportHeader(
                                pageTitle: sectionPageTitle,
                                showMetaBar: true,
                                standardizedDate: standardizedDate,
                              )
                            else if (showCustomHeader)
                              widget._buildAdminHeader(
                                metadata,
                                displayDocumentTitleForCustomHeader,
                              ),
                            buildScrollableSectionBody(),
                            if (useStandardized)
                              widget._readOnlyStandardizedReportFooter()
                            else if (showCustomFooter)
                              widget._buildAdminFooter(
                                metadata: metadata,
                                pageNumber: index + 1,
                                totalPages: sections.length,
                                proposalId: proposalId,
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }
}
