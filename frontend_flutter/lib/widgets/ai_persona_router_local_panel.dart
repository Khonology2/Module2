import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/ai_persona_routing.dart';
import '../services/ai_persona_settings_store.dart';
import '../theme/manager_theme_controller.dart';

/// Cursor-style dark block: default provider/model + expandable API Keys (device-only prefs).
class AiPersonaRouterLocalPanel extends StatefulWidget {
  const AiPersonaRouterLocalPanel({
    super.key,
    this.embedInGlass = false,
    this.managerChrome,
  });

  /// When true, drops the inner card shell so content sits flush on a parent glass sheet.
  /// Pass [managerChrome] so fields and text follow light/dark manager chrome.
  final bool embedInGlass;
  final ManagerChromeTheme? managerChrome;

  @override
  AiPersonaRouterLocalPanelState createState() => AiPersonaRouterLocalPanelState();
}

class AiPersonaRouterLocalPanelState extends State<AiPersonaRouterLocalPanel> {
  bool _loading = true;
  bool _busySave = false;
  String _selectedProvider = '';
  late TextEditingController _modelController;
  late TextEditingController _searchController;
  final Map<String, bool> _byokEnabled = {};
  final Map<String, TextEditingController> _keyCtrls = {};
  final Map<String, bool> _hasStoredKey = {};

  List<String> get _providersWithOptionalKeys {
    return AiPersonaRouting.providerIds
        .where((id) => id.isNotEmpty && id != 'local')
        .toList(growable: false);
  }

  @override
  void initState() {
    super.initState();
    _modelController = TextEditingController();
    _searchController = TextEditingController();
    for (final id in _providersWithOptionalKeys) {
      _byokEnabled[id] = false;
      _hasStoredKey[id] = false;
      _keyCtrls[id] = TextEditingController();
    }
    _hydrate();
  }

  Future<void> _hydrate() async {
    final s = await AiPersonaSettingsStore.load();
    if (!mounted) return;
    setState(() {
      _selectedProvider = s.routingProviderOrEmpty;
      _modelController.text = s.routingModelTrimmed;
      for (final id in _providersWithOptionalKeys) {
        _byokEnabled[id] = s.byokEnabledByProvider[id] ?? false;
        final has = (s.storedKeysByProvider[id] ?? '').trim().isNotEmpty;
        _hasStoredKey[id] = has;
        _keyCtrls[id]?.clear();
      }
      _loading = false;
    });
  }

  @override
  void dispose() {
    _modelController.dispose();
    _searchController.dispose();
    for (final c in _keyCtrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  /// Called from Settings "Save Changes" for the AI tab. Validates and persists locally only.
  Future<bool> saveToDevice() async {
    final scaffold = ScaffoldMessenger.maybeOf(context);
    final trimmedModel = _modelController.text.trim();
    if (trimmedModel.length > AiPersonaRouting.maxModelChars) {
      scaffold?.showSnackBar(
        SnackBar(
          content: Text(
            'Model id must be at most ${AiPersonaRouting.maxModelChars} characters.',
          ),
        ),
      );
      return false;
    }
    for (final id in _providersWithOptionalKeys) {
      final entered = (_keyCtrls[id]?.text ?? '').trim();
      if (entered.isNotEmpty && entered.length > AiPersonaRouting.maxStoredKeyChars) {
        scaffold?.showSnackBar(
          SnackBar(
            content: Text(
              '${AiPersonaRouting.labelFor(id)} key is too long (max '
              '${AiPersonaRouting.maxStoredKeyChars}).',
            ),
          ),
        );
        return false;
      }
    }

    setState(() => _busySave = true);
    try {
      final existing = await AiPersonaSettingsStore.load();
      final nextKeys = Map<String, String>.from(existing.storedKeysByProvider);
      for (final id in _providersWithOptionalKeys) {
        final entered = (_keyCtrls[id]?.text ?? '').trim();
        if (entered.isNotEmpty) {
          nextKeys[id] = entered;
        }
        if (!(_byokEnabled[id] ?? false)) {
          nextKeys.remove(id);
        }
      }

      final next = AiPersonaRouting(
        routingProviderOrEmpty: _selectedProvider,
        routingModelTrimmed: trimmedModel,
        byokEnabledByProvider: Map<String, bool>.from(_byokEnabled),
        storedKeysByProvider: nextKeys,
      );
      await AiPersonaSettingsStore.save(next);
      if (!mounted) return false;
      for (final c in _keyCtrls.values) {
        c.clear();
      }
      setState(() {
        for (final id in _providersWithOptionalKeys) {
          _hasStoredKey[id] = (nextKeys[id] ?? '').trim().isNotEmpty;
        }
      });
      return true;
    } finally {
      if (mounted) setState(() => _busySave = false);
    }
  }

  Widget _cursorProviderColumn({
    required String id,
    required Color headlineColor,
    required Color fieldTextColor,
    required Color iconMuted,
    required Color linkBlue,
  }) {
    final name = AiPersonaRouting.labelFor(id);
    final enabled = _byokEnabled[id] ?? false;
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  '$name API Key',
                  style: GoogleFonts.poppins(
                    color: headlineColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Switch(
                value: enabled,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                onChanged: (v) => setState(() => _byokEnabled[id] = v),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _cursorProviderHelp(id, iconMuted, linkBlue),
          const SizedBox(height: 14),
          if (enabled && _hasStoredKey[id] == true)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                'A key is already stored on this device. Enter a new value only to replace it.',
                style: GoogleFonts.poppins(
                  fontSize: 11.5,
                  color: iconMuted,
                  height: 1.35,
                ),
              ),
            ),
          TextField(
            controller: _keyCtrls[id],
            enabled: enabled,
            obscureText: enabled,
            enableSuggestions: false,
            autocorrect: false,
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: enabled ? fieldTextColor : iconMuted,
            ),
            decoration: InputDecoration(
              hintText: enabled
                  ? 'Enter your $name API key'
                  : 'Turn on the switch above to enter your API key',
              isDense: true,
              hintStyle: GoogleFonts.poppins(color: iconMuted, fontSize: 13),
              filled: true,
              fillColor: enabled
                  ? null
                  : iconMuted.withValues(alpha: 0.10),
            ),
          ),
        ],
      ),
    );
  }

  /// Cursor-style muted body + blue underline phrase under each provider toggle row.
  Widget _cursorProviderHelp(String id, Color mutedText, Color linkBlue) {
    final name = AiPersonaRouting.labelFor(id);
    return RichText(
      text: TextSpan(
        style: GoogleFonts.poppins(
          color: mutedText,
          fontSize: 12.5,
          height: 1.48,
          fontWeight: FontWeight.w400,
        ),
        children: [
          const TextSpan(text: 'Add your '),
          TextSpan(
            text: '$name API key',
            style: GoogleFonts.poppins(
              color: linkBlue,
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
              decoration: TextDecoration.underline,
              decorationColor: linkBlue,
              height: 1.48,
            ),
          ),
          TextSpan(
            text: id == 'hf_inference'
                ? ' for Hugging Face Inference (BYOK). Never leaves this device.'
                : ' for BYOK on this provider. Never leaves this device.',
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: CircularProgressIndicator(
            color: ManagerChromeTheme.accentRed,
          ),
        ),
      );
    }

    const bg = Color(0xFF1E1E1E);
    const borderDark = Color(0x33FFFFFF);
    final ManagerChromeTheme? mc = widget.managerChrome;
    final bool embed = widget.embedInGlass && mc != null;
    final ManagerChromeTheme? glass = embed ? mc : null;
    final bool isGlassLight = glass != null && glass.isDark == false;

    final Color subtleBorder = glass?.divider ?? borderDark;
    final Color fieldFill =
        glass?.fieldFill ?? const Color(0xFF2A2A2A);

    Widget filterChip(String pid) {
      final label = AiPersonaRouting.labelFor(pid);
      final Color labelFg =
          isGlassLight ? glass.textPrimary : const Color(0xFFE2E8F0);
      final Color chipBg =
          isGlassLight ? glass.fieldFill : const Color(0xFF252525);
      final Color chipBorder = _selectedProvider == pid
          ? const Color(0xFF22C55E)
          : (isGlassLight ? glass.fieldBorder : borderDark);
      return FilterChip(
        label: Text(
          label == 'Backend default (no override)' ? 'Backend default' : label,
          style: GoogleFonts.poppins(fontSize: 12, color: labelFg),
        ),
        selected: _selectedProvider == pid,
        onSelected: (_) => setState(() => _selectedProvider = pid),
        selectedColor: const Color(0xFF22C55E).withValues(alpha: 0.35),
        backgroundColor: chipBg,
        side: BorderSide(color: chipBorder),
      );
    }

    final q = _searchController.text.trim().toLowerCase();
    final filteredProviders = AiPersonaRouting.providerIds.where((pid) {
      if (q.isEmpty) return true;
      final label = AiPersonaRouting.labelFor(pid).toLowerCase();
      return label.contains(q) || pid.contains(q);
    }).toList();

    final Color titleColor =
        isGlassLight ? glass.textPrimary : Colors.white;
    final Color bodyMuted = isGlassLight
        ? glass.textSecondary
        : Colors.white.withValues(alpha: 0.75);
    final Color labelSoft =
        isGlassLight ? glass.textSecondary : const Color(0xFFCBD5F5);
    final Color iconMuted =
        isGlassLight ? glass.textMuted : const Color(0xFF94A3B8);
    final Color dividerColor =
        isGlassLight ? glass.divider : const Color(0x33FFFFFF);

    final ThemeData localTheme = isGlassLight
        ? Theme.of(context).copyWith(
            inputDecorationTheme: InputDecorationTheme(
              filled: true,
              fillColor: fieldFill,
              hintStyle: TextStyle(color: glass.textMuted),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: BorderSide(color: glass.fieldBorder),
              ),
            ),
            switchTheme: SwitchThemeData(
              thumbColor: WidgetStateProperty.resolveWith((states) =>
                  states.contains(WidgetState.selected)
                      ? Colors.white
                      : Colors.grey),
              trackColor: WidgetStateProperty.resolveWith((states) =>
                  states.contains(WidgetState.selected)
                      ? const Color(0xFF22C55E)
                      : const Color(0xFF3F3F46)),
            ),
          )
        : ThemeData.dark(useMaterial3: true).copyWith(
            inputDecorationTheme: InputDecorationTheme(
              filled: true,
              fillColor: fieldFill,
              hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: BorderSide(color: subtleBorder),
              ),
            ),
            switchTheme: SwitchThemeData(
              thumbColor: WidgetStateProperty.resolveWith((states) =>
                  states.contains(WidgetState.selected)
                      ? Colors.white
                      : Colors.grey),
              trackColor: WidgetStateProperty.resolveWith((states) =>
                  states.contains(WidgetState.selected)
                      ? const Color(0xFF22C55E)
                      : const Color(0xFF3F3F46)),
            ),
          );

    final Color linkBlue = isGlassLight
        ? ManagerChromeTheme.leftAccentBlue
        : const Color(0xFF4D9EFF);
    final Color headlineOnCursor =
        isGlassLight ? glass.textPrimary : Colors.white;

    final Widget inner = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'API Keys',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: titleColor,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Optional keys for each provider. Leave off if the workspace already supplies them.'
              '\n\nBackend default route still forwards your BYOK key: the first enabled provider in '
              'order HF Inference → OpenAI → Anthropic → OpenRouter that has a saved key.',
              style: GoogleFonts.poppins(
                fontSize: 12,
                height: 1.45,
                color: iconMuted,
              ),
            ),
            const SizedBox(height: 18),
            for (final id in _providersWithOptionalKeys)
              _cursorProviderColumn(
                id: id,
                headlineColor: headlineOnCursor,
                fieldTextColor: headlineOnCursor,
                iconMuted: iconMuted,
                linkBlue: linkBlue,
              ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Divider(height: 1, thickness: 1, color: dividerColor),
        ),
        Text(
          'Models',
          style: GoogleFonts.poppins(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: titleColor,
          ),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _searchController,
          onChanged: (_) => setState(() {}),
          style: GoogleFonts.poppins(fontSize: 13, color: headlineOnCursor),
          decoration: InputDecoration(
            hintText: 'Add or search model',
            isDense: true,
            hintStyle: GoogleFonts.poppins(color: iconMuted, fontSize: 13),
            suffixIcon: Icon(Icons.refresh, color: iconMuted, size: 20),
          ),
          onSubmitted: (_) => setState(() {}),
        ),
        const SizedBox(height: 16),
        Text(
          'Default route',
          style: GoogleFonts.poppins(
            color: bodyMuted,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: filteredProviders.map(filterChip).toList(),
        ),
        const SizedBox(height: 20),
        Text(
          'Model id (optional)',
          style: GoogleFonts.poppins(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: labelSoft,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _modelController,
          obscureText: false,
          style: GoogleFonts.poppins(fontSize: 13, color: headlineOnCursor),
          decoration: InputDecoration(
            hintText: 'e.g. gpt-4o-mini',
            hintStyle: GoogleFonts.poppins(color: iconMuted, fontSize: 13),
          ),
        ),
        if (_busySave)
          Padding(
            padding: const EdgeInsets.only(top: 20),
            child: LinearProgressIndicator(
              minHeight: 2,
              color: ManagerChromeTheme.accentRed,
            ),
          ),
      ],
    );

    return Theme(
      data: localTheme,
      child: embed
          ? Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 8),
              child: inner,
            )
          : Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: borderDark),
              ),
              child: inner,
            ),
    );
  }
}
