import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/neural_orb.dart';
import '../../services/voice/voice_pipeline.dart';
import '../../services/ai/ai_client.dart';
import '../../services/storage/storage_service.dart';
import '../../models/chat_message.dart';

// ── Providers ──────────────────────────────────────────────────────────────────

final voiceStateProvider = StateProvider<VoiceState>((ref) => VoiceState.idle);
final transcriptProvider = StateProvider<String>((ref) => '');
final voiceResponseProvider = StateProvider<String>((ref) => '');

// ── Screen ─────────────────────────────────────────────────────────────────────

class VoiceScreen extends ConsumerStatefulWidget {
  const VoiceScreen({super.key});

  @override
  ConsumerState<VoiceScreen> createState() => _VoiceScreenState();
}

class _VoiceScreenState extends ConsumerState<VoiceScreen>
    with TickerProviderStateMixin {
  late AnimationController _waveController;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _initPipeline();
  }

  @override
  void dispose() {
    _waveController.dispose();
    super.dispose();
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

    final messages = [
      ChatMessage(
        role: MessageRole.system,
        content: storage.systemPrompt,
      ),
      ChatMessage(
        role: MessageRole.user,
        content: transcript,
      ),
    ];

    await for (final chunk in AiClient.instance.streamChat(
      messages: messages,
      provider: storage.selectedProvider,
      modelId: storage.selectedModelId,
    )) {
      buffer.write(chunk);
      if (mounted) ref.read(voiceResponseProvider.notifier).state = buffer.toString();
    }

    await VoicePipeline.instance.speak(buffer.toString());
  }

  Future<void> _toggleListening() async {
    final state = ref.read(voiceStateProvider);
    final pipeline = VoicePipeline.instance;

    if (state == VoiceState.listening) {
      await pipeline.stopListening();
    } else {
      ref.read(transcriptProvider.notifier).state = '';
      ref.read(voiceResponseProvider.notifier).state = '';
      await pipeline.startListening();
    }
  }

  @override
  Widget build(BuildContext context) {
    final voiceState = ref.watch(voiceStateProvider);
    final transcript = ref.watch(transcriptProvider);
    final response = ref.watch(voiceResponseProvider);

    final isListening = voiceState == VoiceState.listening;
    final isThinking = voiceState == VoiceState.thinking || voiceState == VoiceState.speaking;
    final isActive = isListening || isThinking;

    return Scaffold(
      backgroundColor: AppColors.bgDeep,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
              child: Row(
                children: [
                  Text(
                    'Voice',
                    style: GoogleFonts.inter(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  if (isActive)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        gradient: AppGradients.brand,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        isListening ? 'Listening' : isThinking ? 'Thinking' : 'Speaking',
                        style: GoogleFonts.inter(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                    ),
                ],
              ),
            ),

            const Spacer(),

            // Main Orb
            GestureDetector(
              onTap: _initialized ? _toggleListening : null,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  NeuralOrb(size: 280, active: isActive),
                  AnimatedBuilder(
                    animation: _waveController,
                    builder: (_, __) => AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: isListening ? 100 + _waveController.value * 20 : 88,
                      height: isListening ? 100 + _waveController.value * 20 : 88,
                      decoration: BoxDecoration(
                        gradient: AppGradients.brand,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withAlpha(isActive ? 100 : 40),
                            blurRadius: isActive ? 40 : 20,
                            spreadRadius: isActive ? 10 : 5,
                          ),
                        ],
                      ),
                      child: Icon(
                        isListening
                            ? Icons.mic_rounded
                            : isThinking
                                ? Icons.auto_awesome_rounded
                                : Icons.mic_none_rounded,
                        color: Colors.white,
                        size: 36,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Status Text
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: Text(
                key: ValueKey(voiceState),
                _stateLabel(voiceState, _initialized),
                style: GoogleFonts.inter(
                  color: isActive ? AppColors.textPrimary : AppColors.textMuted,
                  fontSize: 16,
                  fontWeight: isActive ? FontWeight.w500 : FontWeight.w400,
                ),
                textAlign: TextAlign.center,
              ),
            ),

            const Spacer(),

            // Transcript & Response
            if (transcript.isNotEmpty || response.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Column(
                  children: [
                    if (transcript.isNotEmpty)
                      GlassCard(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('YOU', style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1)),
                            const SizedBox(height: 4),
                            Text(transcript, style: GoogleFonts.inter(color: AppColors.textPrimary, fontSize: 14, height: 1.4)),
                          ],
                        ),
                      ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.1),
                    if (response.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      GlassCard(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ShaderMask(
                              shaderCallback: (bounds) => AppGradients.brand.createShader(bounds),
                              child: Text('DEVPILOT', style: GoogleFonts.inter(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1)),
                            ),
                            const SizedBox(height: 4),
                            Text(response, style: GoogleFonts.inter(color: AppColors.textPrimary, fontSize: 14, height: 1.4)),
                          ],
                        ),
                      ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.1),
                    ],
                  ],
                ),
              ),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  String _stateLabel(VoiceState state, bool initialized) {
    if (!initialized) return 'Initializing microphone...';
    switch (state) {
      case VoiceState.idle: return 'Tap to speak';
      case VoiceState.listening: return 'Listening...';
      case VoiceState.thinking: return 'Processing your request...';
      case VoiceState.speaking: return 'Speaking response...';
    }
  }
}
