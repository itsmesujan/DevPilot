import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/gradient_button.dart';
import '../../services/research/research_engine.dart';

// ── Providers ──────────────────────────────────────────────────────────────────

final researchProgressProvider = StateProvider<String>((ref) => '');
final researchRunningProvider = StateProvider<bool>((ref) => false);

// ── Screen ─────────────────────────────────────────────────────────────────────

class ResearchScreen extends ConsumerStatefulWidget {
  const ResearchScreen({super.key});

  @override
  ConsumerState<ResearchScreen> createState() => _ResearchScreenState();
}

class _ResearchScreenState extends ConsumerState<ResearchScreen> {
  final _queryController = TextEditingController();
  final _scrollController = ScrollController();
  int _maxSources = 5;

  @override
  void dispose() {
    _queryController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _startResearch() async {
    final query = _queryController.text.trim();
    if (query.isEmpty) return;

    ref.read(researchRunningProvider.notifier).state = true;
    ref.read(researchProgressProvider.notifier).state = '';

    final buffer = StringBuffer();
    await for (final chunk in ResearchEngine.instance.research(query: query, maxSources: _maxSources)) {
      if (!mounted) break;
      buffer.write(chunk);
      ref.read(researchProgressProvider.notifier).state = buffer.toString();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 100),
            curve: Curves.easeOut,
          );
        }
      });
    }

    ref.read(researchRunningProvider.notifier).state = false;
  }

  @override
  Widget build(BuildContext context) {
    final progress = ref.watch(researchProgressProvider);
    final running = ref.watch(researchRunningProvider);

    return Scaffold(
      backgroundColor: AppColors.bgDeep,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      ShaderMask(
                        shaderCallback: (bounds) => AppGradients.brand.createShader(bounds),
                        child: Text(
                          'Deep Research',
                          style: GoogleFonts.inter(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const Spacer(),
                      if (running)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            gradient: AppGradients.brand,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const SizedBox(
                                width: 10,
                                height: 10,
                                child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(Colors.white)),
                              ),
                              const SizedBox(width: 6),
                              Text('Researching', style: GoogleFonts.inter(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Searches the web, reads sources, synthesizes reports',
                    style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 13),
                  ),
                  const SizedBox(height: 16),

                  // Search input
                  GlassCard(
                    padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
                    child: Row(
                      children: [
                        Icon(Icons.travel_explore_rounded, color: AppColors.primary, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: _queryController,
                            style: GoogleFonts.inter(color: AppColors.textPrimary, fontSize: 14),
                            decoration: InputDecoration(
                              hintText: 'What do you want to research?',
                              hintStyle: GoogleFonts.inter(color: AppColors.textHint, fontSize: 14),
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              fillColor: Colors.transparent,
                              filled: false,
                            ),
                            onSubmitted: (_) => running ? null : _startResearch(),
                          ),
                        ),
                        GradientIconButton(
                          icon: Icons.arrow_forward_rounded,
                          onPressed: running ? null : _startResearch,
                          size: 40,
                        ),
                      ],
                    ),
                  ),

                  // Sources slider
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Icon(Icons.source_outlined, size: 14, color: AppColors.textMuted),
                      const SizedBox(width: 6),
                      Text(
                        'Sources: $_maxSources',
                        style: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 12),
                      ),
                      Expanded(
                        child: SliderTheme(
                          data: const SliderThemeData(
                            trackHeight: 2,
                            thumbShape: RoundSliderThumbShape(enabledThumbRadius: 6),
                          ),
                          child: Slider(
                            value: _maxSources.toDouble(),
                            min: 3,
                            max: 10,
                            divisions: 7,
                            onChanged: (v) => setState(() => _maxSources = v.round()),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const Divider(color: AppColors.border, height: 1),

            // Research output
            Expanded(
              child: progress.isEmpty
                  ? _ResearchEmptyState().animate().fadeIn(duration: 400.ms)
                  : Markdown(
                      controller: _scrollController,
                      data: progress,
                      padding: const EdgeInsets.all(20),
                      styleSheet: MarkdownStyleSheet(
                        p: GoogleFonts.inter(
                          fontSize: 14,
                          height: 1.7,
                          color: AppColors.textPrimary,
                        ),
                        h1: GoogleFonts.inter(
                          color: AppColors.primary,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                        h2: GoogleFonts.inter(
                          color: AppColors.primaryLight,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                        h3: GoogleFonts.inter(
                          color: AppColors.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                        code: GoogleFonts.robotoMono(
                          backgroundColor: AppColors.bgCard,
                          fontSize: 12,
                          color: AppColors.accent,
                        ),
                        codeblockDecoration: BoxDecoration(
                          color: AppColors.bgCard,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.border),
                        ),
                        blockquote: GoogleFonts.inter(
                          fontStyle: FontStyle.italic,
                          color: AppColors.textSecondary,
                        ),
                        blockquoteDecoration: BoxDecoration(
                          border: Border(left: BorderSide(color: AppColors.primary, width: 3)),
                        ),
                        a: const TextStyle(color: AppColors.accent),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResearchEmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                gradient: AppGradients.brand,
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: AppColors.primary.withAlpha(60), blurRadius: 30)],
              ),
              child: const Icon(Icons.travel_explore_rounded, color: Colors.white, size: 36),
            ),
            const SizedBox(height: 24),
            Text(
              'Explore Any Topic',
              style: GoogleFonts.inter(color: AppColors.textPrimary, fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              'DevPilot will break down your query,\nsearch multiple sources, and synthesize\na comprehensive research report.',
              style: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 14, height: 1.6),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                'Latest AI models',
                'Quantum computing',
                'Market analysis',
                'Medical research',
              ].map((t) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.border),
                  borderRadius: BorderRadius.circular(20),
                  color: AppColors.bgCard,
                ),
                child: Text(t, style: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 12)),
              )).toList(),
            ),
          ],
        ),
      ),
    );
  }
}
