import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../ai/ai_client.dart';
import '../storage/storage_service.dart';
import '../storage/app_database.dart';
import '../../models/chat_message.dart';
import '../../models/memory_models.dart';
import 'package:uuid/uuid.dart';

class ResearchEngine {
  ResearchEngine._();
  static final ResearchEngine instance = ResearchEngine._();

  Stream<String> research({
    required String query,
    int maxSources = 5,
  }) async* {
    yield '**Starting deep research:** $query\n\n';

    // Step 1: Decompose query
    yield '**Step 1/4** — Decomposing query into sub-questions...\n';
    final subQuestions = await _decomposeQuery(query);
    yield 'Sub-questions:\n${subQuestions.map((q) => '- $q').join('\n')}\n\n';

    // Step 2: Parallel web searches
    yield '**Step 2/4** — Searching the web...\n';
    final sources = <ResearchSource>[];
    for (final q in subQuestions.take(maxSources)) {
      yield 'Searching: *$q*\n';
      final results = await _search(q);
      sources.addAll(results);
      await Future.delayed(const Duration(milliseconds: 300));
    }
    yield 'Found ${sources.length} sources.\n\n';

    // Step 3: Summarize each source
    yield '**Step 3/4** — Summarizing sources...\n';
    final summaries = <String>[];
    for (final src in sources.take(maxSources)) {
      yield 'Reading: ${src.url}\n';
      final summary = await _summarizeSource(src.url, query);
      summaries.add('**${src.title}** (${src.url})\n$summary');
    }
    yield '\n';

    // Step 4: Synthesize
    yield '**Step 4/4** — Synthesizing final report...\n\n';
    yield '---\n\n';
    final synthesis = await _synthesize(query, summaries);
    yield synthesis;

    // Save report
    AppDatabase.instance.insertReport(
      id: const Uuid().v4(),
      query: query,
      sources: jsonEncode(sources.map((s) => {'url': s.url, 'title': s.title}).toList()),
      synthesis: synthesis,
      createdAt: DateTime.now().toIso8601String(),
    );

    yield '\n\n---\n*Sources: ${sources.map((s) => s.url).join(', ')}*\n';
  }

  Future<List<String>> _decomposeQuery(String query) async {
    final provider = StorageService.instance.selectedProvider;
    final modelId = StorageService.instance.selectedModelId;

    final buffer = StringBuffer();
    await for (final chunk in AiClient.instance.streamChat(
      provider: provider,
      modelId: modelId,
      messages: [
        ChatMessage(
          role: MessageRole.user,
          content: 'Break this research query into 3-4 specific sub-questions, one per line, no numbering:\n\n$query',
        )
      ],
      systemPrompt: 'You are a research assistant. Output ONLY the sub-questions, one per line.',
      temperature: 0.3,
      maxTokens: 256,
    )) {
      buffer.write(chunk);
    }

    return buffer
        .toString()
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty && l.length > 5)
        .take(4)
        .toList();
  }

  Future<List<ResearchSource>> _search(String query) async {
    final encoded = Uri.encodeQueryComponent(query);
    final url = 'https://api.duckduckgo.com/?q=$encoded&format=json&no_redirect=1&no_html=1';
    try {
      final resp = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 8));
      if (resp.statusCode != 200) return [];
      final json = jsonDecode(resp.body) as Map<String, dynamic>;
      final results = <ResearchSource>[];

      final abstractText = json['AbstractText'] as String? ?? '';
      final abstractUrl = json['AbstractURL'] as String? ?? '';
      if (abstractText.isNotEmpty && abstractUrl.isNotEmpty) {
        results.add(ResearchSource(
          url: abstractUrl,
          title: json['Heading'] as String? ?? query,
          summary: abstractText,
          relevance: 1.0,
        ));
      }

      final related = json['RelatedTopics'] as List? ?? [];
      for (final t in related.take(3)) {
        if (t is Map) {
          final text = t['Text'] as String? ?? '';
          final firstUrl = t['FirstURL'] as String? ?? '';
          if (text.isNotEmpty && firstUrl.isNotEmpty) {
            results.add(ResearchSource(url: firstUrl, title: text.split(' - ').first, summary: text, relevance: 0.7));
          }
        }
      }
      return results;
    } catch (_) {
      return [];
    }
  }

  Future<String> _summarizeSource(String url, String query) async {
    final provider = StorageService.instance.selectedProvider;
    final modelId = StorageService.instance.selectedModelId;

    String pageText = '';
    try {
      final jinaUrl = 'https://r.jina.ai/$url';
      final resp = await http.get(Uri.parse(jinaUrl), headers: {'Accept': 'text/plain'})
          .timeout(const Duration(seconds: 12));
      if (resp.statusCode == 200) {
        pageText = resp.body.length > 3000 ? resp.body.substring(0, 3000) : resp.body;
      }
    } catch (_) {
      return 'Could not read source.';
    }

    if (pageText.isEmpty) return 'Empty source.';

    final buffer = StringBuffer();
    await for (final chunk in AiClient.instance.streamChat(
      provider: provider,
      modelId: modelId,
      messages: [
        ChatMessage(
          role: MessageRole.user,
          content: 'Summarize this page in 3-4 sentences relevant to: "$query"\n\n$pageText',
        )
      ],
      systemPrompt: 'You are a research summarizer. Be concise and factual.',
      temperature: 0.2,
      maxTokens: 300,
    )) {
      buffer.write(chunk);
    }
    return buffer.toString().trim();
  }

  Future<String> _synthesize(String query, List<String> summaries) async {
    final provider = StorageService.instance.selectedProvider;
    final modelId = StorageService.instance.selectedModelId;

    final buffer = StringBuffer();
    await for (final chunk in AiClient.instance.streamChat(
      provider: provider,
      modelId: modelId,
      messages: [
        ChatMessage(
          role: MessageRole.user,
          content: '''Write a comprehensive research report on: "$query"

Based on these source summaries:
${summaries.join('\n\n---\n\n')}

Format as:
# [Title]
## Summary
[2-3 paragraph overview]
## Key Findings
- [bullet points]
## Conclusion
[1 paragraph]''',
        )
      ],
      systemPrompt: 'You are an expert research analyst. Write clear, well-structured reports with citations.',
      temperature: 0.4,
      maxTokens: 1500,
    )) {
      buffer.write(chunk);
    }
    return buffer.toString().trim();
  }
}
