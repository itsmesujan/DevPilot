import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/voice/voice_pipeline.dart';
import '../../services/ai/ai_client.dart';
import '../../services/storage/storage_service.dart';
import '../../models/chat_message.dart';

// ── Providers ─────────────────────────────────────────────────────────────────

final voiceStateProvider = StateProvider<VoiceState>((ref) => VoiceState.idle);
final transcriptProvider = StateProvider<String>((ref) => '');
final voiceResponseProvider = StateProvider<String>((ref) => '');

// ── Screen ────────────────────────────────────────────────────────────────────

class VoiceScreen extends ConsumerStatefulWidget {
  const VoiceScreen({super.key});

  @override
  ConsumerState<VoiceScreen> createState() => _VoiceScreenState();
}

class _VoiceScreenState extends ConsumerState<VoiceScreen>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _initPipeline();
  }

  Future<void> _initPipeline() async {
    final pipeline = VoicePipeline.instance;
    pipeline.onStateChanged = (state) {
      if (mounted) ref.read(voiceStateProvider.notifier).state = state;
      if (state == VoiceState.thinking) _handleThinking();
    };
    pipeline.onTranscript = (text) {
      if (mounted) ref.read(transcriptProvider.notifier).state = text;
    };
    await pipeline.init();
    setState(() => _initialized = true);
  }

  Future<void> _handleThinking() async {
    final transcript = ref.read(transcriptProvider);
    if (transcript.isEmpty) return;

    ref.read(voiceResponseProvider.notifier).state = '';
    final storage = StorageService.instance;
    final buffer = StringBuffer();

    await for (final chunk in AiClient.instance.streamChat(
      provider: storage.selectedProvider,
      modelId: storage.selectedModelId,
      messages: [ChatMessage(role: MessageRole.user, content: transcript)],
      systemPrompt: storage.systemPrompt,
    )) {
      buffer.write(chunk);
      if (mounted) {
        ref.read(voiceResponseProvider.notifier).state = buffer.toString();
      }
    }

    final response = buffer.toString().trim();
    if (response.isNotEmpty) {
      await VoicePipeline.instance.speak(response);
    }
  }

  Future<void> _toggleMic() async {
    final state = ref.read(voiceStateProvider);
    if (state == VoiceState.idle) {
      ref.read(transcriptProvider.notifier).state = '';
      ref.read(voiceResponseProvider.notifier).state = '';
      await VoicePipeline.instance.startListening();
    } else if (state == VoiceState.listening) {
      await VoicePipeline.instance.stopListening();
    } else if (state == VoiceState.speaking) {
      await VoicePipeline.instance.stopListening();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final voiceState = ref.watch(voiceStateProvider);
    final transcript = ref.watch(transcriptProvider);
    final response = ref.watch(voiceResponseProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Voice Assistant')),
      body: Column(
        children: [
          const SizedBox(height: 40),
          // Animated mic button
          GestureDetector(
            onTap: _initialized ? _toggleMic : null,
            child: AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                final isActive = voiceState == VoiceState.listening ||
                    voiceState == VoiceState.speaking;
                final scale = isActive
                    ? 1.0 + (_pulseController.value * 0.12)
                    : 1.0;
                return Transform.scale(
                  scale: scale,
                  child: child,
                );
              },
              child: _MicButton(state: voiceState),
            ),
          ),
          const SizedBox(height: 24),
          // State label
          Text(
            _stateLabel(voiceState),
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 32),
          // Transcript card
          if (transcript.isNotEmpty)
            _BubbleCard(
              label: 'You said',
              text: transcript,
              color: theme.colorScheme.primaryContainer,
              textColor: theme.colorScheme.onPrimaryContainer,
            ),
          // Response card
          if (response.isNotEmpty)
            _BubbleCard(
              label: 'DevPilot',
              text: response,
              color: theme.colorScheme.secondaryContainer,
              textColor: theme.colorScheme.onSecondaryContainer,
            ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.only(bottom: 24),
            child: Text(
              'Tap the mic to start speaking',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: Colors.white38),
            ),
          ),
        ],
      ),
    );
  }

  String _stateLabel(VoiceState s) {
    switch (s) {
      case VoiceState.idle:
        return 'Tap to speak';
      case VoiceState.listening:
        return 'Listening…';
      case VoiceState.thinking:
        return 'Thinking…';
      case VoiceState.speaking:
        return 'Speaking…';
    }
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _MicButton extends StatelessWidget {
  final VoiceState state;
  const _MicButton({required this.state});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isActive =
        state == VoiceState.listening || state == VoiceState.thinking;
    final isSpeaking = state == VoiceState.speaking;

    return Container(
      width: 96,
      height: 96,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isActive
            ? theme.colorScheme.primary
            : isSpeaking
                ? theme.colorScheme.secondary
                : theme.colorScheme.surfaceContainerHighest,
        boxShadow: [
          if (isActive)
            BoxShadow(
              color: theme.colorScheme.primary.withAlpha(100),
              blurRadius: 24,
              spreadRadius: 4,
            ),
        ],
      ),
      child: Icon(
        isActive
            ? Icons.mic
            : isSpeaking
                ? Icons.volume_up
                : Icons.mic_none,
        size: 40,
        color: isActive || isSpeaking ? Colors.white : Colors.white54,
      ),
    );
  }
}

class _BubbleCard extends StatelessWidget {
  final String label;
  final String text;
  final Color color;
  final Color textColor;
  const _BubbleCard(
      {required this.label,
      required this.text,
      required this.color,
      required this.textColor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: textColor.withAlpha(160))),
            const SizedBox(height: 4),
            Text(text, style: TextStyle(color: textColor, fontSize: 15)),
          ],
        ),
      ),
    );
  }
}
