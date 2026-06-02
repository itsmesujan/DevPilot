import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:file_picker/file_picker.dart';
import 'package:uuid/uuid.dart';

import '../../models/chat_message.dart';
import '../../services/ai/ai_client.dart';
import '../../services/storage/storage_service.dart';
import '../../services/storage/app_database.dart';
import '../../services/memory/memory_service.dart';
import '../../services/local/local_llm_service.dart';
import '../../services/voice/voice_pipeline.dart';

// ── Providers ─────────────────────────────────────────────────────────────────

final sessionIdProvider = StateProvider<String>((ref) => const Uuid().v4());

/// When true, messages are routed to the on-device local LLM instead of cloud.
final useLocalInferenceProvider = StateProvider<bool>((ref) => false);

final chatMessagesProvider =
    StateNotifierProvider<ChatNotifier, List<ChatMessage>>((ref) {
  return ChatNotifier(ref.watch(sessionIdProvider));
});

final attachedImagesProvider = StateProvider<List<String>>((ref) => []);
final isDictatingProvider = StateProvider<bool>((ref) => false);

class ChatNotifier extends StateNotifier<List<ChatMessage>> {
  final String sessionId;
  ChatNotifier(this.sessionId) : super([]) {
    _loadHistory();
  }

  void _loadHistory() {
    final rows = AppDatabase.instance.getMessages(sessionId);
    state = rows
        .map((r) => ChatMessage(
              id: r['id'] as String,
              role: MessageRole.values.byName(r['role'] as String),
              content: r['content'] as String,
              createdAt: DateTime.parse(r['created_at'] as String),
            ))
        .toList();
  }

  Future<void> sendMessage(String text, {List<String> imageBase64List = const [], bool useLocal = false}) async {
    if (text.trim().isEmpty && imageBase64List.isEmpty) return;

    final storage = StorageService.instance;

    // Add user message
    final userMsg = ChatMessage(
      role: MessageRole.user,
      content: text.trim(),
      imageBase64List: imageBase64List,
    );
    state = [...state, userMsg];
    AppDatabase.instance.insertMessage(
      id: userMsg.id,
      sessionId: sessionId,
      role: 'user',
      content: userMsg.content,
      createdAt: userMsg.createdAt.toIso8601String(),
    );

    // Add placeholder assistant message
    final assistantMsg = ChatMessage(
      role: MessageRole.assistant,
      content: '',
      isStreaming: true,
    );
    state = [...state, assistantMsg];

    try {
      // Recall relevant memories
      final memories = await MemoryService.instance.search(text, topK: 3);
      String memoryContext = '';
      if (memories.isNotEmpty) {
        memoryContext = '\n\nRelevant memory:\n${memories.map((m) => '- ${m.content}').join('\n')}';
      }

      final systemPrompt = storage.systemPrompt + memoryContext;

      final buffer = StringBuffer();

      // Route to local or cloud inference
      final stream = useLocal && LocalLlmService.instance.isModelLoaded
          ? LocalLlmService.instance.generateChat(
              messages: [
                {'role': 'system', 'content': systemPrompt},
                ...state
                    .where((m) => !m.isStreaming)
                    .map((m) => {'role': m.role.name, 'content': m.content}),
              ],
              temperature: storage.temperature,
              maxTokens: storage.maxContextTokens,
            )
          : AiClient.instance.streamChat(
              provider: storage.selectedProvider,
              modelId: storage.selectedModelId,
              messages: state.where((m) => !m.isStreaming).toList(),
              systemPrompt: systemPrompt,
              temperature: storage.temperature,
              maxTokens: storage.maxContextTokens,
            );

      await for (final chunk in stream) {
        buffer.write(chunk);
        final updated = assistantMsg..content = buffer.toString();
        state = [
          ...state.where((m) => m.id != assistantMsg.id),
          updated,
        ];
      }

      final finalMsg = assistantMsg
        ..isStreaming = false
        ..content = buffer.toString();
      state = [
        ...state.where((m) => m.id != assistantMsg.id),
        finalMsg,
      ];

      AppDatabase.instance.insertMessage(
        id: finalMsg.id,
        sessionId: sessionId,
        role: 'assistant',
        content: finalMsg.content,
        createdAt: finalMsg.createdAt.toIso8601String(),
      );

      // Store in episodic memory
      await MemoryService.instance.storeEpisodic(
        content: 'User: $text\nAssistant: ${finalMsg.content.substring(0, finalMsg.content.length.clamp(0, 200))}',
        sessionId: sessionId,
      );
    } catch (e) {
      final errMsg = assistantMsg
        ..isStreaming = false
        ..hasError = true
        ..content = 'Error: $e';
      state = [
        ...state.where((m) => m.id != assistantMsg.id),
        errMsg,
      ];
    }
  }

  void clearSession() {
    state = [];
  }
}

// ── UI ────────────────────────────────────────────────────────────────────────

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final _focusNode = FocusNode();
  bool _sending = false;

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    final attached = ref.read(attachedImagesProvider);
    if ((text.isEmpty && attached.isEmpty) || _sending) return;

    _controller.clear();
    ref.read(attachedImagesProvider.notifier).state = []; // Clear previews immediately
    setState(() => _sending = true);

    final useLocal = ref.read(useLocalInferenceProvider);
    await ref.read(chatMessagesProvider.notifier).sendMessage(
          text,
          imageBase64List: attached,
          useLocal: useLocal,
        );

    setState(() => _sending = false);
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    final messages = ref.watch(chatMessagesProvider);
    final theme = Theme.of(context);
    final storage = StorageService.instance;
    final useLocal = ref.watch(useLocalInferenceProvider);
    final localLoaded = LocalLlmService.instance.isModelLoaded;

    if (messages.isNotEmpty) _scrollToBottom();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('DevPilot', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            Text(
              useLocal && localLoaded
                  ? 'On-device · ${LocalLlmService.instance.loadedModelId ?? ""}'
                  : '${storage.selectedProvider} · ${storage.selectedModelId}',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                fontSize: 10,
              ),
            ),
          ],
        ),
        actions: [
          // Local inference toggle — only shown when a model is loaded on device
          if (localLoaded)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: FilterChip(
                label: const Text('Local', style: TextStyle(fontSize: 11)),
                avatar: const Icon(Icons.memory, size: 14),
                selected: useLocal,
                onSelected: (v) =>
                    ref.read(useLocalInferenceProvider.notifier).state = v,
                visualDensity: VisualDensity.compact,
              ),
            ),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 20),
            onPressed: () => ref.read(chatMessagesProvider.notifier).clearSession(),
            tooltip: 'Clear chat',
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: messages.isEmpty
                ? _EmptyState(
                    controller: _controller,
                    focusNode: _focusNode,
                    ref: ref,
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: messages.length,
                    itemBuilder: (_, i) => _ChatBubble(message: messages[i]),
                  ),
          ),
          _InputBar(
            controller: _controller,
            focusNode: _focusNode,
            sending: _sending,
            onSend: _send,
          ),
        ],
      ),
    );
  }
}

// ── Empty State ──────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final WidgetRef ref;

  const _EmptyState({
    required this.controller,
    required this.focusNode,
    required this.ref,
  });

  Widget _buildSuggestionCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String text,
  }) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.25),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: theme.colorScheme.outline.withValues(alpha: 0.08),
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          controller.text = text;
          focusNode.requestFocus();
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: theme.colorScheme.primary, size: 22),
              const SizedBox(height: 8),
              Text(
                title,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 2),
              Expanded(
                child: Text(
                  text,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    fontSize: 11,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 48),
          // Gradient Welcome Header
          ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              colors: [
                Color(0xFF6C63FF),
                Color(0xFF00D4AA),
                Color(0xFFFF5C8A),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ).createShader(bounds),
            child: Text(
              'How can I help you today?',
              style: theme.textTheme.headlineMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
              textAlign: TextAlign.center,
            ),
          ).animate().fadeIn(duration: 600.ms).scale(begin: const Offset(0.95, 0.95), duration: 600.ms, curve: Curves.easeOut),
          const SizedBox(height: 8),
          Text(
            'Your multimodal on-device AI operations center',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
            textAlign: TextAlign.center,
          ).animate().fadeIn(delay: 200.ms, duration: 400.ms),
          const SizedBox(height: 48),
          // Grid suggestions
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.55,
            children: [
              _buildSuggestionCard(
                context,
                icon: Icons.school_outlined,
                title: 'Spaced Repetition',
                text: 'Explain the SM-2 scheduling algorithm simply',
              ),
              _buildSuggestionCard(
                context,
                icon: Icons.code,
                title: 'Fix a Bug',
                text: 'Find relative import path issues in Flutter packages',
              ),
              _buildSuggestionCard(
                context,
                icon: Icons.palette_outlined,
                title: 'Creative Prompt',
                text: 'Create a detail-rich GGUF image model art prompt',
              ),
              _buildSuggestionCard(
                context,
                icon: Icons.settings_voice_outlined,
                title: 'Local Whisper',
                text: 'How does on-device speech translation work?',
              ),
            ],
          ).animate().slideY(begin: 0.1, duration: 400.ms, curve: Curves.easeOut).fadeIn(duration: 400.ms),
        ],
      ),
    );
  }
}

// ── Chat Bubble ──────────────────────────────────────────────────────────────

class _ChatBubble extends ConsumerWidget {
  final ChatMessage message;
  const _ChatBubble({required this.message});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isUser = message.role == MessageRole.user;
    final theme = Theme.of(context);

    if (isUser) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (message.imageBase64List.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: message.imageBase64List.map((b64) {
                          return ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.memory(
                              base64Decode(b64),
                              width: 120,
                              height: 120,
                              fit: BoxFit.cover,
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          theme.colorScheme.primary,
                          theme.colorScheme.primary.withValues(alpha: 0.85),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(18),
                        topRight: Radius.circular(18),
                        bottomLeft: Radius.circular(18),
                        bottomRight: Radius.circular(4),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: theme.colorScheme.primary.withValues(alpha: 0.15),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        )
                      ],
                    ),
                    child: Text(
                      message.content,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ).animate().fadeIn(duration: 250.ms).slideY(begin: 0.05, duration: 250.ms, curve: Curves.easeOut);
    } else {
      // Assistant response (bubble-free, Gemini style)
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Glowing Avatar
            Container(
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    Color(0xFF6C63FF),
                    Color(0xFF00D4AA),
                    Color(0xFFFF5C8A),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              padding: const EdgeInsets.all(2),
              child: CircleAvatar(
                radius: 14,
                backgroundColor: theme.colorScheme.surface,
                child: Icon(
                  Icons.auto_awesome,
                  size: 13,
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (message.isStreaming && message.content.isEmpty)
                    const _GeminiLoader()
                  else ...[
                    MarkdownBody(
                      data: message.content + (message.isStreaming ? ' ▋' : ''),
                      styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
                        p: TextStyle(color: theme.colorScheme.onSurface, fontSize: 14, height: 1.5),
                        code: TextStyle(
                          backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
                          fontFamily: 'monospace',
                          fontSize: 12,
                        ),
                        codeblockDecoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.08)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Action controls
                    if (!message.isStreaming && message.content.isNotEmpty)
                      _AssistantActionsRow(content: message.content),
                  ],
                ],
              ),
            ),
          ],
        ),
      ).animate().fadeIn(duration: 300.ms);
    }
  }
}

// ── Assistant Quick Actions ──────────────────────────────────────────────────

class _AssistantActionsRow extends StatefulWidget {
  final String content;
  const _AssistantActionsRow({required this.content});

  @override
  State<_AssistantActionsRow> createState() => _AssistantActionsRowState();
}

class _AssistantActionsRowState extends State<_AssistantActionsRow> {
  bool _copied = false;
  bool _speaking = false;

  void _copy() {
    Clipboard.setData(ClipboardData(text: widget.content));
    setState(() => _copied = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  Future<void> _speak() async {
    final voice = VoicePipeline.instance;
    if (_speaking) {
      await voice.stopSpeaking();
      setState(() => _speaking = false);
    } else {
      setState(() => _speaking = true);
      await voice.speak(widget.content);
      voice.onStateChanged = (state) {
        if (state == VoiceState.idle && mounted) {
          setState(() => _speaking = false);
        }
      };
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        IconButton(
          icon: Icon(
            _copied ? Icons.check_circle_outline : Icons.copy_all_outlined,
            size: 16,
            color: _copied ? Colors.green : theme.colorScheme.onSurface.withValues(alpha: 0.5),
          ),
          onPressed: _copy,
          tooltip: 'Copy response',
          visualDensity: VisualDensity.compact,
        ),
        IconButton(
          icon: Icon(
            _speaking ? Icons.volume_off_outlined : Icons.volume_up_outlined,
            size: 16,
            color: _speaking ? theme.colorScheme.primary : theme.colorScheme.onSurface.withValues(alpha: 0.5),
          ),
          onPressed: _speak,
          tooltip: _speaking ? 'Stop reading' : 'Read aloud',
          visualDensity: VisualDensity.compact,
        ),
      ],
    );
  }
}

// ── Gemini Style Loader ──────────────────────────────────────────────────────

class _GeminiLoader extends StatefulWidget {
  const _GeminiLoader();

  @override
  State<_GeminiLoader> createState() => _GeminiLoaderState();
}

class _GeminiLoaderState extends State<_GeminiLoader>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Container(
            height: 3,
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(2),
              gradient: LinearGradient(
                colors: const [
                  Color(0xFF6C63FF),
                  Color(0xFF00D4AA),
                  Color(0xFFFF5C8A),
                  Color(0xFF6C63FF),
                ],
                begin: Alignment(-2.0 + _controller.value * 4.0, 0.0),
                end: Alignment(0.0 + _controller.value * 4.0, 0.0),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ── Input Bar ────────────────────────────────────────────────────────────────

class _InputBar extends ConsumerWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool sending;
  final VoidCallback onSend;

  const _InputBar({
    required this.controller,
    required this.focusNode,
    required this.sending,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final attachedImages = ref.watch(attachedImagesProvider);
    final isDictating = ref.watch(isDictatingProvider);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Horizontal Image Preview list
            if (attachedImages.isNotEmpty) ...[
              Container(
                height: 72,
                margin: const EdgeInsets.only(bottom: 10),
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: attachedImages.length,
                  itemBuilder: (context, index) {
                    final bytes = base64Decode(attachedImages[index]);
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.memory(
                              bytes,
                              width: 64,
                              height: 64,
                              fit: BoxFit.cover,
                            ),
                          ),
                          Positioned(
                            top: 2,
                            right: 2,
                            child: GestureDetector(
                              onTap: () {
                                ref.read(attachedImagesProvider.notifier).update((state) {
                                  return [...state]..removeAt(index);
                                });
                              },
                              child: Container(
                                decoration: const BoxDecoration(
                                  color: Colors.black87,
                                  shape: BoxShape.circle,
                                ),
                                padding: const EdgeInsets.all(3),
                                child: const Icon(
                                  Icons.close,
                                  size: 12,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
            // Capsule Input Box
            Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: isDictating
                      ? theme.colorScheme.primary
                      : theme.colorScheme.outline.withValues(alpha: 0.12),
                  width: 1.5,
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              child: Row(
                children: [
                  // Attachment button
                  IconButton(
                    icon: Icon(
                      Icons.add_photo_alternate_outlined,
                      color: theme.colorScheme.primary,
                      size: 22,
                    ),
                    onPressed: () => _pickImage(ref),
                    tooltip: 'Attach images',
                  ),
                  // Mic button
                  IconButton(
                    icon: Icon(
                      isDictating ? Icons.mic : Icons.mic_none,
                      color: isDictating ? Colors.red : theme.colorScheme.primary,
                      size: 22,
                    ),
                    onPressed: () => _toggleDictation(ref, controller),
                    tooltip: isDictating ? 'Stop listening' : 'Voice type',
                  ),
                  const SizedBox(width: 4),
                  // Text input field
                  Expanded(
                    child: TextField(
                      controller: controller,
                      focusNode: focusNode,
                      minLines: 1,
                      maxLines: 6,
                      textInputAction: TextInputAction.newline,
                      decoration: const InputDecoration(
                        hintText: 'Message DevPilot...',
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 8),
                        fillColor: Colors.transparent,
                        filled: false,
                      ),
                      onSubmitted: (_) => onSend(),
                    ),
                  ),
                  const SizedBox(width: 4),
                  // Send button
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: sending
                        ? SizedBox(
                            width: 32,
                            height: 32,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: theme.colorScheme.primary,
                            ),
                          )
                        : IconButton.filled(
                            onPressed: onSend,
                            icon: const Icon(Icons.arrow_upward_rounded, size: 20),
                            style: IconButton.styleFrom(
                              padding: const EdgeInsets.all(10),
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Helper Actions ───────────────────────────────────────────────────────────

Future<void> _pickImage(WidgetRef ref) async {
  try {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: true,
    );
    if (result != null && result.files.isNotEmpty) {
      for (final file in result.files) {
        if (file.path != null) {
          final bytes = await File(file.path!).readAsBytes();
          final base64 = base64Encode(bytes);
          ref.read(attachedImagesProvider.notifier).update((state) => [...state, base64]);
        }
      }
    }
  } catch (_) {}
}

Future<void> _toggleDictation(WidgetRef ref, TextEditingController controller) async {
  final voice = VoicePipeline.instance;
  final isDictating = ref.read(isDictatingProvider);

  if (isDictating) {
    await voice.stopListening();
    ref.read(isDictatingProvider.notifier).state = false;
  } else {
    await voice.init();
    voice.onTranscript = (text) {
      if (text.isNotEmpty) {
        controller.text = '${controller.text} $text'.trim();
      }
    };
    voice.onStateChanged = (state) {
      if (state == VoiceState.idle) {
        ref.read(isDictatingProvider.notifier).state = false;
      }
    };
    ref.read(isDictatingProvider.notifier).state = true;
    await voice.startListening();
  }
}
