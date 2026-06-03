import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/gradient_button.dart';
import '../../core/widgets/neural_orb.dart';
import '../../core/widgets/typing_indicator.dart';
import '../../services/agent/agent_orchestrator.dart';
import '../../models/agent_models.dart';

class AgentScreen extends StatefulWidget {
  const AgentScreen({super.key});

  @override
  State<AgentScreen> createState() => _AgentScreenState();
}

class _AgentScreenState extends State<AgentScreen> {
  final _goalController = TextEditingController();
  final _scrollController = ScrollController();
  final _orchestrator = AgentOrchestrator.instance;

  bool _isRunning = false;
  String _finalAnswer = '';
  String? _lastError;
  final List<AgentEvent> _events = [];
  final List<ThinkingStep> _thinkingSteps = [];
  final List<ToolResult> _toolResults = [];

  @override
  void dispose() {
    _goalController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _runAgent() async {
    if (_goalController.text.isEmpty) return;

    setState(() {
      _isRunning = true;
      _events.clear();
      _thinkingSteps.clear();
      _toolResults.clear();
      _finalAnswer = '';
    });

    try {
      await for (final event in _orchestrator.run(
        goal: _goalController.text,
        useThinking: true,
      )) {
        if (!mounted) break;

        setState(() {
          _events.add(event);

          if (event.thinkingStep != null) {
            _thinkingSteps.add(event.thinkingStep!);
          }
          if (event.toolResult != null) {
            _toolResults.add(event.toolResult!);
          }
          if (event.type == AgentEventType.text) {
            _finalAnswer += event.content;
          }
        });

        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
          );
        }
      }
    } catch (e) {
      if (mounted) setState(() {
        _lastError = 'Agent error: $e';
        _isRunning = false;
      });
    } finally {
      if (mounted) setState(() => _isRunning = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDeep,
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                gradient: AppGradients.brand,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.smart_toy_rounded, color: Colors.white, size: 16),
            ),
            const SizedBox(width: 10),
            Text('Agent', style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 18)),
          ],
        ),
        actions: [
          if (_isRunning)
            Container(
              margin: const EdgeInsets.only(right: 8),
              width: 24,
              height: 24,
              child: const CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation(AppColors.primary),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.groups_rounded, size: 22),
            tooltip: 'Agent Council',
            onPressed: () => context.go('/council'),
          ),
        ],
      ),
      body: Column(
        children: [
          // Input Section
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: GlassCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const NeuralOrb(size: 36, active: true),
                      const SizedBox(width: 10),
                      Text(
                        'Mission Briefing',
                        style: GoogleFonts.inter(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _goalController,
                    style: GoogleFonts.inter(color: AppColors.textPrimary, fontSize: 15),
                    maxLines: 3,
                    minLines: 1,
                    decoration: InputDecoration(
                      hintText: 'What should the agent accomplish?',
                      hintStyle: GoogleFonts.inter(color: AppColors.textHint, fontSize: 14),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      fillColor: Colors.transparent,
                      filled: false,
                    ),
                    onSubmitted: (_) => _isRunning ? null : _runAgent(),
                  ),
                  const SizedBox(height: 12),
                  GradientButton(
                    label: _isRunning ? 'Running...' : 'Execute Mission',
                    icon: _isRunning ? null : Icons.play_arrow_rounded,
                    isLoading: _isRunning,
                    onPressed: _isRunning ? null : _runAgent,
                  ),
                ],
              ),
            ),
          ),

          // Events / Timeline
          Expanded(
            child: _lastError != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: GlassCard(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 40),
                            const SizedBox(height: 12),
                            Text(_lastError!, style: GoogleFonts.inter(color: AppColors.error, fontSize: 13), textAlign: TextAlign.center),
                            const SizedBox(height: 16),
                            GradientButton(label: 'Try Again', icon: Icons.refresh_rounded, onPressed: () => setState(() => _lastError = null)),
                          ],
                        ),
                      ),
                    ),
                  )
                : _events.isEmpty && !_isRunning
                    ? _AgentEmptyState()
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _events.length + (_finalAnswer.isNotEmpty ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index == _events.length && _finalAnswer.isNotEmpty) {
                            return _FinalAnswerCard(answer: _finalAnswer);
                          }
                          final event = _events[index];
                          if (event.thinkingStep != null) {
                            return _ThinkingStepCard(step: event.thinkingStep!, index: index);
                          }
                          if (event.toolResult != null) {
                            return _ToolResultCard(result: event.toolResult!);
                          }
                          return _StatusCard(content: event.content, isLast: index == _events.length - 1 && _isRunning);
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

// ─── Empty State ──────────────────────────────────────────────────────────────

class _AgentEmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            NeuralOrb(size: 120, active: false),
            const SizedBox(height: 24),
            Text(
              'Ready for Mission',
              style: GoogleFonts.inter(
                color: AppColors.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Describe a complex goal above.\nThe agent will plan, reason, and use tools to complete it.',
              style: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 14, height: 1.5),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                _SuggestionChip('Research a topic'),
                _SuggestionChip('Analyze a file'),
                _SuggestionChip('Write & run code'),
                _SuggestionChip('Multi-step task'),
              ],
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 400.ms);
  }
}

class _SuggestionChip extends StatelessWidget {
  final String label;
  const _SuggestionChip(this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(20),
        color: AppColors.bgCard,
      ),
      child: Text(label, style: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 12)),
    );
  }
}

// ─── Timeline Cards ───────────────────────────────────────────────────────────

class _ThinkingStepCard extends StatelessWidget {
  final ThinkingStep step;
  final int index;
  const _ThinkingStepCard({required this.step, required this.index});

  @override
  Widget build(BuildContext context) {
    final color = _colorForType(step.type);
    final icon = _iconForType(step.type);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline connector
          Column(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: color.withAlpha(30),
                  shape: BoxShape.circle,
                  border: Border.all(color: color.withAlpha(80)),
                ),
                child: Icon(icon, color: color, size: 16),
              ),
              Container(width: 1, height: 20, color: AppColors.border),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: GlassCard(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    step.type.displayName,
                    style: GoogleFonts.inter(color: color, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.5),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    step.content,
                    style: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 13, height: 1.4),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms).slideX(begin: -0.05);
  }

  Color _colorForType(ThinkingType type) {
    switch (type) {
      case ThinkingType.understanding: return AppColors.textSecondary;
      case ThinkingType.planning: return AppColors.accent;
      case ThinkingType.toolPlanning: return AppColors.warning;
      case ThinkingType.reasoning: return AppColors.primary;
      case ThinkingType.toolDecision: return AppColors.warning;
      case ThinkingType.toolExecution: return AppColors.info;
      case ThinkingType.toolResult: return AppColors.success;
      case ThinkingType.reflection: return AppColors.primaryLight;
      case ThinkingType.synthesis: return AppColors.accentLight;
      case ThinkingType.finalAnswer: return AppColors.success;
      case ThinkingType.error: return AppColors.error;
    }
  }

  IconData _iconForType(ThinkingType type) {
    switch (type) {
      case ThinkingType.understanding: return Icons.visibility_outlined;
      case ThinkingType.planning: return Icons.map_outlined;
      case ThinkingType.toolPlanning: return Icons.build_outlined;
      case ThinkingType.reasoning: return Icons.psychology_outlined;
      case ThinkingType.toolDecision: return Icons.devices_outlined;
      case ThinkingType.toolExecution: return Icons.play_arrow_rounded;
      case ThinkingType.toolResult: return Icons.check_circle_outline;
      case ThinkingType.reflection: return Icons.auto_fix_high_outlined;
      case ThinkingType.synthesis: return Icons.merge_type_outlined;
      case ThinkingType.finalAnswer: return Icons.flag_outlined;
      case ThinkingType.error: return Icons.error_outline;
    }
  }
}

class _ToolResultCard extends StatelessWidget {
  final ToolResult result;
  const _ToolResultCard({required this.result});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 44),
      child: GlassCard(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.terminal_rounded, size: 14, color: result.success ? AppColors.success : AppColors.error),
                const SizedBox(width: 6),
                Text(
                  result.toolName,
                style: GoogleFonts.robotoMono(
                    color: result.success ? AppColors.success : AppColors.error,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Text(
                  '${result.duration.inMilliseconds}ms',
                  style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 11),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                result.output.length > 200 ? '${result.output.substring(0, 200)}…' : result.output,
                style: GoogleFonts.robotoMono(color: AppColors.textSecondary, fontSize: 11, height: 1.4),
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 250.ms);
  }
}

class _StatusCard extends StatelessWidget {
  final String content;
  final bool isLast;
  const _StatusCard({required this.content, required this.isLast});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          if (isLast)
            const Padding(
              padding: EdgeInsets.only(right: 12, left: 4),
              child: TypingIndicator(),
            )
          else
            const SizedBox(width: 16),
          Expanded(
            child: Text(
              content,
              style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

class _FinalAnswerCard extends StatelessWidget {
  final String answer;
  const _FinalAnswerCard({required this.answer});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: GlassCard(
        borderRadius: BorderRadius.circular(16),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ShaderMask(
                  shaderCallback: (bounds) => AppGradients.brand.createShader(bounds),
                  child: const Icon(Icons.flag_rounded, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 8),
                ShaderMask(
                  shaderCallback: (bounds) => AppGradients.brand.createShader(bounds),
                  child: Text(
                    'Mission Complete',
                    style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(color: AppColors.border),
            const SizedBox(height: 12),
            Text(
              answer,
              style: GoogleFonts.inter(color: AppColors.textPrimary, fontSize: 14, height: 1.6),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 500.ms).scale(begin: const Offset(0.97, 0.97));
  }
}
