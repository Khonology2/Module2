/// Persona-local AI routing (HF Space provider-router). Kept device-only via [AiPersonaSettingsStore].
class AiPersonaRouting {
  AiPersonaRouting({
    required this.routingProviderOrEmpty,
    required this.routingModelTrimmed,
    required this.byokEnabledByProvider,
    required this.storedKeysByProvider,
  });

  /// Canonical ids matching backend allowlist (empty string = no X-AI-Provider).
  final String routingProviderOrEmpty;
  final String routingModelTrimmed;
  final Map<String, bool> byokEnabledByProvider;
  final Map<String, String> storedKeysByProvider;

  static const List<String> providerIds = [
    '',
    'local',
    'hf_inference',
    'openai',
    'anthropic',
    'openrouter',
  ];

  static String labelFor(String id) {
    switch (id) {
      case '':
        return 'Backend default (no override)';
      case 'local':
        return 'Local';
      case 'hf_inference':
        return 'HF Inference';
      case 'openai':
        return 'OpenAI';
      case 'anthropic':
        return 'Anthropic';
      case 'openrouter':
        return 'OpenRouter';
      default:
        return id;
    }
  }

  static const int maxModelChars = 120;
  static const int maxStoredKeyChars = 256;

  AiPersonaRouting copyWith({
    String? routingProviderOrEmpty,
    String? routingModelTrimmed,
    Map<String, bool>? byokEnabledByProvider,
    Map<String, String>? storedKeysByProvider,
  }) {
    return AiPersonaRouting(
      routingProviderOrEmpty:
          routingProviderOrEmpty ?? this.routingProviderOrEmpty,
      routingModelTrimmed: routingModelTrimmed ?? this.routingModelTrimmed,
      byokEnabledByProvider:
          Map<String, bool>.from(byokEnabledByProvider ?? this.byokEnabledByProvider),
      storedKeysByProvider: Map<String, String>.from(
        storedKeysByProvider ?? this.storedKeysByProvider,
      ),
    );
  }

  /// Outbound backend headers — never includes empty values.
  ///
  /// When [routingProviderOrEmpty] is empty ("backend default"), this still sends
  /// [X-Provider-Api-Key] for the **first** provider (canonical order below) that
  /// has BYOK enabled **and** a stored key — the backend allows a lone API key header.
  Map<String, String> toOutboundHeaders() {
    final h = <String, String>{};
    final p = routingProviderOrEmpty.trim().toLowerCase();
    if (p.isNotEmpty) {
      h['X-AI-Provider'] = p;
    }
    final m = routingModelTrimmed.trim();
    if (m.isNotEmpty && m.length <= maxModelChars) {
      h['X-AI-Model'] = m;
    }
    final activePid = routingProviderOrEmpty.trim().toLowerCase();

    if (activePid.isNotEmpty) {
      if (byokEnabledByProvider[activePid] == true) {
        final kRaw = storedKeysByProvider[activePid]?.trim() ?? '';
        if (kRaw.isNotEmpty && kRaw.length <= maxStoredKeyChars) {
          h['X-Provider-Api-Key'] = kRaw;
        }
      }
    } else {
      const canonicalByokOrder = [
        'hf_inference',
        'openai',
        'anthropic',
        'openrouter',
      ];
      for (final pid in canonicalByokOrder) {
        if (byokEnabledByProvider[pid] != true) continue;
        final kRaw = storedKeysByProvider[pid]?.trim() ?? '';
        if (kRaw.isNotEmpty && kRaw.length <= maxStoredKeyChars) {
          h['X-Provider-Api-Key'] = kRaw;
          break;
        }
      }
    }

    return h;
  }
}
