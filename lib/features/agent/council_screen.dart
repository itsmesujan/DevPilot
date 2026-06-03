import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/gradient_button.dart';
import '../../core/widgets/neural_orb.dart';
import '../../core/widgets/typing_indicator.dart';
import '../../services/agent/orchestration/multi_agent_orchestrator.dart';
import '../../models/agent_models.dart';
import '../../services/agent/skills/skill_manager.dart';

class CouncilScreen extends StatefulWidget {
  const CouncilScreen({super.key});

  @override
  State<CouncilScreen> createState() => _CouncilScreenState();
}

class _CouncilScreenState extends State<CouncilScreen> {
  final _topicController = TextEditingController();
  final _scrollController = ScrollController();
  final List<String> _selectedSkills = [];

  bool _isRunning = false;
  final List<AgentStep> _steps = [];

  @override
  void dispose() {
    _topicController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _toggleSkill(String name) {
    setState(() {
      if (_selectedSkills.contains(name)) {
        _selectedSkills.remove(name);
      } else {
        _selectedSkills.add(name);
      }
    });
  }

  Future<void> _runCouncil() async {
    if (_topicController.text.isEmpty || _selectedSkills.isEmpty) return;

    setState(() {
      _isRunning = true;
      _steps.clear();
    });

    try {
      await for (final step in MultiAgentOrchestrator.instance.runCouncil(
        _topicController.text,
        _selectedSkills,
      )) {
        if (!mounted) break;
        setState(() => _steps.add(step));

        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
          );
        }
      }
    } finally {
      if (mounted) setState(() => _isRunning = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final skills = SkillManager.instance.skills;

    return Scaffold(
      backgroundColor: AppColors.bgDeep,
      appBar: AppBar(
        backgroundColor: AppColors.bgDeep,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, size: 18),
          onPressed: () => context.go('/agent'),
        ),
        title: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                gradient: AppGradients.brand,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.groups_rounded, color: Colors.white, size: 16),
            ),
            const SizedBox(width: 10),
            Text('Agent Council', style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 18)),
          ],
        ),
        actions: [
          if (_isRunning)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(AppColors.primary)),
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // Configuration Section
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: GlassCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'COUNCIL MEMBERS',
                    style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.2),
                  ),
                  const SizedBox(height: 10),
                  skills.isEmpty
                      ? Text(
                          'No skills yet. Create skills from the drawer → Custom Skills.',
                          style: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 13),
                        )
                      : Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: skills.map((s) {
                            final isSelected = _selectedSkills.contains(s.name);
                            return GestureDetector(
                              onTap: () => _toggleSkill(s.name),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  gradient: isSelected ? AppGradients.brand : null,
                                  color: isSelected ? null : AppColors.bgCard,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: isSelected ? Colors.transparent : AppColors.border,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(s.avatarEmoji, style: const TextStyle(fontSize: 14)),
                                    const SizedBox(width: 6),
                                    Text(
                                      s.name,
                                      style: GoogleFonts.inter(
                                        color: isSelected ? Colors.white : AppColors.textSecondary,
                                        fontSize: 12,
                                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                  const SizedBox(height: 14),
                  const Divider(color: AppColors.border, height: 1),
                  const SizedBox(height: 14),
                  Text(
                    'DISCUSSION TOPIC',
                    style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.2),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _topicController,
                    style: GoogleFonts.inter(color: AppColors.textPrimary, fontSize: 14),
                    maxLines: 2,
                    minLines: 1,
                    decoration: InputDecoration(
                      hintText: 'What should the council deliberate on?',
                      hintStyle: GoogleFonts.inter(color: AppColors.textHint, fontSize: 13),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      fillColor: Colors.transparent,
                      filled: false,
                    ),
                  ),
                  const SizedBox(height: 12),
                  GradientButton(
                    label: _isRunning ? 'Council in session...' : 'Convene Council',
                    icon: _isRunning ? null : Icons.groups_rounded,
                    isLoading: _isRunning,
                    onPressed: _isRunning || _selectedSkills.isEmpty ? null : _runCouncil,
                  ),
                ],
              ),
            ),
          ),

          const Divider(color: AppColors.border, height: 1),

          // Discussion Feed
          Expanded(
            child: _steps.isEmpty && !_isRunning
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const NeuralOrb(size: 100, active: false),
                        const SizedBox(height: 16),
                        Text('Select agents and enter a topic\nto convene the council.', style: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 14, height: 1.5), textAlign: TextAlign.center),
                      ],
                    ).animate().fadeIn(duration: 400.ms),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: _steps.length + (_isRunning ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == _steps.length) {
                        return const Padding(
                          padding: EdgeInsets.all(16),
                          child: Center(child: TypingIndicator()),
                        );
                      }
                      final step = _steps[index];
                      return _CouncilStepCard(step: step, index: index);
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _CouncilStepCard extends StatelessWidget {
  final AgentStep step;
  final int index;
  const _CouncilStepCard({required this.step, required this.index});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GlassCard(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    gradient: AppGradients.brand,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text('${index + 1}', style: GoogleFonts.inter(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    step.thought,
                    style: GoogleFonts.inter(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            if (step.toolOutput != null && step.toolOutput!.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.border),
                ),
                child: Text(
                  step.toolOutput!,
                  style: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 13, height: 1.5),
                ),
              ),
            ],
          ],
        ),
      ),
    ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.05);
  }
}
