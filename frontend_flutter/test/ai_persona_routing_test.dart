import 'package:flutter_test/flutter_test.dart';
import 'package:lukens/models/ai_persona_routing.dart';

void main() {
  group('AiPersonaRouting', () {
    test('empty selection sends no headers', () {
      final r = AiPersonaRouting(
        routingProviderOrEmpty: '',
        routingModelTrimmed: '',
        byokEnabledByProvider: {},
        storedKeysByProvider: {},
      );
      expect(r.toOutboundHeaders(), isEmpty);
    });

    test('sends provider + model', () {
      final r = AiPersonaRouting(
        routingProviderOrEmpty: 'openai',
        routingModelTrimmed: 'gpt-4o',
        byokEnabledByProvider: {'openai': false},
        storedKeysByProvider: {},
      );
      final h = r.toOutboundHeaders();
      expect(h['X-AI-Provider'], 'openai');
      expect(h['X-AI-Model'], 'gpt-4o');
      expect(h.containsKey('X-Provider-Api-Key'), isFalse);
    });

    test('backend default still sends first eligible BYOK key', () {
      final r = AiPersonaRouting(
        routingProviderOrEmpty: '',
        routingModelTrimmed: '',
        byokEnabledByProvider: {'openai': true, 'anthropic': false},
        storedKeysByProvider: {'openai': 'sk-test'},
      );
      final h = r.toOutboundHeaders();
      expect(h.containsKey('X-AI-Provider'), isFalse);
      expect(h['X-Provider-Api-Key'], 'sk-test');
    });

    test('backend default prefers hf_inference over openai key order', () {
      final r = AiPersonaRouting(
        routingProviderOrEmpty: '',
        routingModelTrimmed: '',
        byokEnabledByProvider: {'hf_inference': true, 'openai': true},
        storedKeysByProvider: {
          'hf_inference': 'hf-secret',
          'openai': 'sk-o',
        },
      );
      final h = r.toOutboundHeaders();
      expect(h['X-Provider-Api-Key'], 'hf-secret');
    });

    test('sends BYOK key for active provider only when enabled', () {
      final r = AiPersonaRouting(
        routingProviderOrEmpty: 'anthropic',
        routingModelTrimmed: 'claude',
        byokEnabledByProvider: {'anthropic': true, 'openai': true},
        storedKeysByProvider: {
          'anthropic': 'sk-ant',
          'openai': 'sk-o',
        },
      );
      final h = r.toOutboundHeaders();
      expect(h['X-Provider-Api-Key'], 'sk-ant');
    });
  });
}
