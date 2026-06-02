import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../storage/storage_service.dart';
import '../../models/chat_message.dart';

/// Unified AI client that streams responses from 10+ providers.
/// All providers are normalized to the same Stream<String> interface.
class AiClient {
  AiClient._();
  static final AiClient instance = AiClient._();

  // ── Public entry ──────────────────────────────────────────────────────────
  Stream<String> streamChat({
    required String provider,
    required String modelId,
    required List<ChatMessage> messages,
    double temperature = 0.7,
    int maxTokens = 2048,
    String? systemPrompt,
  }) {
    switch (provider) {
      case 'openai':
      case 'openrouter':
        return _streamOpenAICompat(
          provider: provider,
          modelId: modelId,
          messages: messages,
          temperature: temperature,
          maxTokens: maxTokens,
          systemPrompt: systemPrompt,
        );
      case 'anthropic':
        return _streamAnthropic(
          modelId: modelId,
          messages: messages,
          temperature: temperature,
          maxTokens: maxTokens,
          systemPrompt: systemPrompt,
        );
      case 'gemini':
        return _streamGemini(
          modelId: modelId,
          messages: messages,
          temperature: temperature,
          maxTokens: maxTokens,
          systemPrompt: systemPrompt,
        );
      case 'mistral':
        return _streamMistral(
          modelId: modelId,
          messages: messages,
          temperature: temperature,
          maxTokens: maxTokens,
          systemPrompt: systemPrompt,
        );
      case 'deepseek':
        return _streamDeepSeek(
          modelId: modelId,
          messages: messages,
          temperature: temperature,
          maxTokens: maxTokens,
          systemPrompt: systemPrompt,
        );
      case 'groq':
        return _streamGroq(
          modelId: modelId,
          messages: messages,
          temperature: temperature,
          maxTokens: maxTokens,
          systemPrompt: systemPrompt,
        );
      case 'together':
        return _streamTogether(
          modelId: modelId,
          messages: messages,
          temperature: temperature,
          maxTokens: maxTokens,
          systemPrompt: systemPrompt,
        );
      case 'kimi':
        return _streamKimi(
          modelId: modelId,
          messages: messages,
          temperature: temperature,
          maxTokens: maxTokens,
          systemPrompt: systemPrompt,
        );
      case 'ollama':
        return _streamOllama(
          modelId: modelId,
          messages: messages,
          temperature: temperature,
          maxTokens: maxTokens,
          systemPrompt: systemPrompt,
        );
      default:
        return Stream.error('Unknown provider: $provider');
    }
  }

  // ── OpenAI-compatible (OpenAI, OpenRouter) ────────────────────────────────
  Stream<String> _streamOpenAICompat({
    required String provider,
    required String modelId,
    required List<ChatMessage> messages,
    required double temperature,
    required int maxTokens,
    String? systemPrompt,
  }) async* {
    final storage = StorageService.instance;
    final apiKey = provider == 'openrouter'
        ? await storage.openrouterKey
        : await storage.openaiKey;
    if (apiKey == null || apiKey.isEmpty) {
      throw Exception('$provider API key not set');
    }

    final baseUrl = provider == 'openrouter'
        ? 'https://openrouter.ai/api/v1/chat/completions'
        : 'https://api.openai.com/v1/chat/completions';

    final builtMessages = _buildOpenAIMessages(messages, systemPrompt);

    final request = http.Request('POST', Uri.parse(baseUrl))
      ..headers.addAll({
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiKey',
        if (provider == 'openrouter') 'HTTP-Referer': 'https://devpilot.app',
      })
      ..body = jsonEncode({
        'model': modelId,
        'messages': builtMessages,
        'temperature': temperature,
        'max_tokens': maxTokens,
        'stream': true,
      });

    final client = http.Client();
    try {
      final response = await client.send(request);
      if (response.statusCode != 200) {
        final body = await response.stream.bytesToString();
        throw Exception('$provider error ${response.statusCode}: $body');
      }
      await for (final chunk in response.stream.transform(utf8.decoder).transform(const LineSplitter())) {
        if (chunk.startsWith('data: ')) {
          final data = chunk.substring(6).trim();
          if (data == '[DONE]') break;
          try {
            final json = jsonDecode(data) as Map<String, dynamic>;
            final delta = json['choices']?[0]?['delta']?['content'];
            if (delta != null && delta is String && delta.isNotEmpty) {
              yield delta;
            }
          } catch (_) {}
        }
      }
    } finally {
      client.close();
    }
  }

  // ── Anthropic ─────────────────────────────────────────────────────────────
  Stream<String> _streamAnthropic({
    required String modelId,
    required List<ChatMessage> messages,
    required double temperature,
    required int maxTokens,
    String? systemPrompt,
  }) async* {
    final apiKey = await StorageService.instance.anthropicKey;
    if (apiKey == null || apiKey.isEmpty) throw Exception('Anthropic API key not set');

    final userMessages = messages
        .where((m) => m.role != MessageRole.system)
        .map((m) => {'role': m.role == MessageRole.user ? 'user' : 'assistant', 'content': m.content})
        .toList();

    final body = <String, dynamic>{
      'model': modelId,
      'max_tokens': maxTokens,
      'temperature': temperature,
      'stream': true,
      'messages': userMessages,
      if (systemPrompt != null) 'system': systemPrompt,
    };

    final request = http.Request('POST', Uri.parse('https://api.anthropic.com/v1/messages'))
      ..headers.addAll({
        'Content-Type': 'application/json',
        'x-api-key': apiKey,
        'anthropic-version': '2023-06-01',
      })
      ..body = jsonEncode(body);

    final client = http.Client();
    try {
      final response = await client.send(request);
      if (response.statusCode != 200) {
        final b = await response.stream.bytesToString();
        throw Exception('Anthropic error ${response.statusCode}: $b');
      }
      await for (final line in response.stream.transform(utf8.decoder).transform(const LineSplitter())) {
        if (line.startsWith('data: ')) {
          try {
            final json = jsonDecode(line.substring(6)) as Map<String, dynamic>;
            if (json['type'] == 'content_block_delta') {
              final text = json['delta']?['text'];
              if (text is String && text.isNotEmpty) yield text;
            }
          } catch (_) {}
        }
      }
    } finally {
      client.close();
    }
  }

  // ── Google Gemini ─────────────────────────────────────────────────────────
  Stream<String> _streamGemini({
    required String modelId,
    required List<ChatMessage> messages,
    required double temperature,
    required int maxTokens,
    String? systemPrompt,
  }) async* {
    final apiKey = await StorageService.instance.geminiKey;
    if (apiKey == null || apiKey.isEmpty) throw Exception('Gemini API key not set');

    final contents = messages
        .where((m) => m.role != MessageRole.system)
        .map((m) => {
              'role': m.role == MessageRole.user ? 'user' : 'model',
              'parts': [
                if (m.imageBase64List.isNotEmpty)
                  ...m.imageBase64List.map((b64) => {
                        'inlineData': {'mimeType': 'image/jpeg', 'data': b64}
                      }),
                {'text': m.content},
              ],
            })
        .toList();

    final url = 'https://generativelanguage.googleapis.com/v1beta/models/$modelId:streamGenerateContent?alt=sse&key=$apiKey';

    final request = http.Request('POST', Uri.parse(url))
      ..headers['Content-Type'] = 'application/json'
      ..body = jsonEncode({
        'contents': contents,
        'generationConfig': {'temperature': temperature, 'maxOutputTokens': maxTokens},
        if (systemPrompt != null)
          'systemInstruction': {
            'parts': [
              {'text': systemPrompt}
            ]
          },
      });

    final client = http.Client();
    try {
      final response = await client.send(request);
      if (response.statusCode != 200) {
        final b = await response.stream.bytesToString();
        throw Exception('Gemini error ${response.statusCode}: $b');
      }
      await for (final line in response.stream.transform(utf8.decoder).transform(const LineSplitter())) {
        if (line.startsWith('data: ')) {
          try {
            final json = jsonDecode(line.substring(6)) as Map<String, dynamic>;
            final text = json['candidates']?[0]?['content']?['parts']?[0]?['text'];
            if (text is String && text.isNotEmpty) yield text;
          } catch (_) {}
        }
      }
    } finally {
      client.close();
    }
  }

  // ── Mistral ───────────────────────────────────────────────────────────────
  Stream<String> _streamMistral({
    required String modelId,
    required List<ChatMessage> messages,
    required double temperature,
    required int maxTokens,
    String? systemPrompt,
  }) async* {
    final apiKey = await StorageService.instance.mistralKey;
    if (apiKey == null || apiKey.isEmpty) throw Exception('Mistral API key not set');
    yield* _streamGenericOpenAIStyle(
      url: 'https://api.mistral.ai/v1/chat/completions',
      apiKey: apiKey,
      modelId: modelId,
      messages: messages,
      temperature: temperature,
      maxTokens: maxTokens,
      systemPrompt: systemPrompt,
    );
  }

  // ── DeepSeek ──────────────────────────────────────────────────────────────
  Stream<String> _streamDeepSeek({
    required String modelId,
    required List<ChatMessage> messages,
    required double temperature,
    required int maxTokens,
    String? systemPrompt,
  }) async* {
    final apiKey = await StorageService.instance.deepseekKey;
    if (apiKey == null || apiKey.isEmpty) throw Exception('DeepSeek API key not set');
    yield* _streamGenericOpenAIStyle(
      url: 'https://api.deepseek.com/chat/completions',
      apiKey: apiKey,
      modelId: modelId,
      messages: messages,
      temperature: temperature,
      maxTokens: maxTokens,
      systemPrompt: systemPrompt,
    );
  }

  // ── Groq ──────────────────────────────────────────────────────────────────
  Stream<String> _streamGroq({
    required String modelId,
    required List<ChatMessage> messages,
    required double temperature,
    required int maxTokens,
    String? systemPrompt,
  }) async* {
    final apiKey = await StorageService.instance.groqKey;
    if (apiKey == null || apiKey.isEmpty) throw Exception('Groq API key not set');
    yield* _streamGenericOpenAIStyle(
      url: 'https://api.groq.com/openai/v1/chat/completions',
      apiKey: apiKey,
      modelId: modelId,
      messages: messages,
      temperature: temperature,
      maxTokens: maxTokens,
      systemPrompt: systemPrompt,
    );
  }

  // ── Together AI ───────────────────────────────────────────────────────────
  Stream<String> _streamTogether({
    required String modelId,
    required List<ChatMessage> messages,
    required double temperature,
    required int maxTokens,
    String? systemPrompt,
  }) async* {
    final apiKey = await StorageService.instance.togetherKey;
    if (apiKey == null || apiKey.isEmpty) throw Exception('Together AI key not set');
    yield* _streamGenericOpenAIStyle(
      url: 'https://api.together.xyz/v1/chat/completions',
      apiKey: apiKey,
      modelId: modelId,
      messages: messages,
      temperature: temperature,
      maxTokens: maxTokens,
      systemPrompt: systemPrompt,
    );
  }

  // ── Kimi (Moonshot AI) ────────────────────────────────────────────────────
  Stream<String> _streamKimi({
    required String modelId,
    required List<ChatMessage> messages,
    required double temperature,
    required int maxTokens,
    String? systemPrompt,
  }) async* {
    final apiKey = await StorageService.instance.kimiKey;
    if (apiKey == null || apiKey.isEmpty) throw Exception('Kimi API key not set');
    yield* _streamGenericOpenAIStyle(
      url: 'https://api.moonshot.cn/v1/chat/completions',
      apiKey: apiKey,
      modelId: modelId,
      messages: messages,
      temperature: temperature,
      maxTokens: maxTokens,
      systemPrompt: systemPrompt,
    );
  }

  // ── Ollama (local server) ─────────────────────────────────────────────────
  Stream<String> _streamOllama({
    required String modelId,
    required List<ChatMessage> messages,
    required double temperature,
    required int maxTokens,
    String? systemPrompt,
  }) async* {
    final baseUrl = (await StorageService.instance.ollamaUrl) ?? 'http://localhost:11434';
    yield* _streamGenericOpenAIStyle(
      url: '$baseUrl/v1/chat/completions',
      apiKey: 'ollama',
      modelId: modelId,
      messages: messages,
      temperature: temperature,
      maxTokens: maxTokens,
      systemPrompt: systemPrompt,
    );
  }

  // ── Shared OpenAI-style helper ─────────────────────────────────────────────
  Stream<String> _streamGenericOpenAIStyle({
    required String url,
    required String apiKey,
    required String modelId,
    required List<ChatMessage> messages,
    required double temperature,
    required int maxTokens,
    String? systemPrompt,
  }) async* {
    final builtMessages = _buildOpenAIMessages(messages, systemPrompt);
    final request = http.Request('POST', Uri.parse(url))
      ..headers.addAll({
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiKey',
      })
      ..body = jsonEncode({
        'model': modelId,
        'messages': builtMessages,
        'temperature': temperature,
        'max_tokens': maxTokens,
        'stream': true,
      });

    final client = http.Client();
    try {
      final response = await client.send(request);
      if (response.statusCode != 200) {
        final b = await response.stream.bytesToString();
        throw Exception('API error ${response.statusCode}: $b');
      }
      await for (final line in response.stream.transform(utf8.decoder).transform(const LineSplitter())) {
        if (line.startsWith('data: ')) {
          final data = line.substring(6).trim();
          if (data == '[DONE]') break;
          try {
            final json = jsonDecode(data) as Map<String, dynamic>;
            final delta = json['choices']?[0]?['delta']?['content'];
            if (delta is String && delta.isNotEmpty) yield delta;
          } catch (_) {}
        }
      }
    } finally {
      client.close();
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  List<Map<String, dynamic>> _buildOpenAIMessages(
    List<ChatMessage> messages,
    String? systemPrompt,
  ) {
    final result = <Map<String, dynamic>>[];
    if (systemPrompt != null && systemPrompt.isNotEmpty) {
      result.add({'role': 'system', 'content': systemPrompt});
    }
    for (final m in messages) {
      if (m.role == MessageRole.system) continue;
      if (m.imageBase64List.isNotEmpty) {
        final contentParts = <Map<String, dynamic>>[
          {'type': 'text', 'text': m.content},
          ...m.imageBase64List.map((b64) => {
                'type': 'image_url',
                'image_url': {'url': 'data:image/jpeg;base64,$b64'}
              }),
        ];
        result.add({'role': m.role.name, 'content': contentParts});
      } else {
        result.add({'role': m.role.name, 'content': m.content});
      }
    }
    return result;
  }
}
