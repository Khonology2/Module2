import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/ai_persona_routing.dart';
import 'auth_service.dart';

/// Device-only persona AI routing prefs (never sent to Flutter backend / DB).
class AiPersonaSettingsStore {
  AiPersonaSettingsStore._();

  static String _prefsPrefix() {
    final u = AuthService.currentUser;
    final slug = (u?['username'] ?? u?['email'] ?? 'guest').toString();
    var safe = slug.replaceAll(RegExp(r'[^a-zA-Z0-9._@-]'), '_');
    if (safe.length > 120) {
      safe = safe.substring(0, 120);
    }
    return 'ai_persona_router_v1__$safe';
  }

  static Future<AiPersonaRouting> load() async {
    final p = await SharedPreferences.getInstance();
    final key = _prefsPrefix();
    final raw = p.getString(key);
    if (raw == null || raw.trim().isEmpty) {
      return AiPersonaRouting(
        routingProviderOrEmpty: '',
        routingModelTrimmed: '',
        byokEnabledByProvider: {},
        storedKeysByProvider: {},
      );
    }
    try {
      final map = json.decode(raw) as Map<String, dynamic>;
      final bp = map['byok'];
      final ks = map['keys'];
      return AiPersonaRouting(
        routingProviderOrEmpty: (map['provider'] ?? '').toString(),
        routingModelTrimmed: (map['model'] ?? '').toString(),
        byokEnabledByProvider:
            bp is Map ? bp.map((k, v) => MapEntry('$k'.toLowerCase(), v == true)) : {},
        storedKeysByProvider: ks is Map
            ? ks.map((k, v) => MapEntry('$k'.toLowerCase(), '$v'))
            : {},
      );
    } catch (_) {
      return AiPersonaRouting(
        routingProviderOrEmpty: '',
        routingModelTrimmed: '',
        byokEnabledByProvider: {},
        storedKeysByProvider: {},
      );
    }
  }

  static Future<void> save(AiPersonaRouting routing) async {
    final p = await SharedPreferences.getInstance();
    final key = _prefsPrefix();
    final payload = json.encode({
      'provider': routing.routingProviderOrEmpty,
      'model': routing.routingModelTrimmed,
      'byok': routing.byokEnabledByProvider,
      'keys': routing.storedKeysByProvider,
    });
    await p.setString(key, payload);
    if (!kReleaseMode) {
      debugPrint('[AiPersonaSettingsStore] Saved routing persona key=$key '
          '(no secret values logged).');
    }
  }

  static Future<Map<String, String>> outboundHeaders() async {
    final s = await load();
    final h = s.toOutboundHeaders();
    return h;
  }
}
