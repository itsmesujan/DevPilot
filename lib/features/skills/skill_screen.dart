import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/gradient_button.dart';
import '../../models/skill_models.dart';
import '../../services/agent/skills/skill_manager.dart';

class SkillScreen extends StatefulWidget {
  const SkillScreen({super.key});

  @override
  State<SkillScreen> createState() => _SkillScreenState();
}

class _SkillScreenState extends State<SkillScreen> {
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSkills();
  }

  Future<void> _loadSkills() async {
    setState(() => _isLoading = true);
    await SkillManager.instance.initialize();
    if (mounted) setState(() => _isLoading = false);
  }

  void _showSkillEditor([Skill? existing]) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => _SkillEditor(
        skill: existing,
        onSave: (newSkill) async {
          await SkillManager.instance.saveSkill(newSkill);
          _loadSkills();
        },
      ),
    );
  }

  void _deleteSkill(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Delete Skill', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
        content: Text('Are you sure you want to delete this custom skill?', style: GoogleFonts.inter()),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await SkillManager.instance.deleteSkill(id);
      _loadSkills();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppColors.bgDeep,
        body: const Center(
          child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation(AppColors.primary)),
        ),
      );
    }

    final skills = SkillManager.instance.skills;

    return Scaffold(
      backgroundColor: AppColors.bgDeep,
      appBar: AppBar(
        backgroundColor: AppColors.bgDeep,
        title: Text('Custom Skills', style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 18)),
      ),
      body: skills.isEmpty
          ? Center(
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
                      child: const Icon(Icons.psychology_rounded, color: Colors.white, size: 36),
                    ),
                    const SizedBox(height: 24),
                    Text('No Custom Skills', style: GoogleFonts.inter(color: AppColors.textPrimary, fontSize: 20, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    Text(
                      'Create domain-expert personas for your agent.\nEach skill defines a specialized role, system prompt, and tool access.',
                      style: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 14, height: 1.5),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    GradientButton(label: 'Create First Skill', icon: Icons.add, onPressed: _showSkillEditor),
                  ],
                ).animate().fadeIn(duration: 400.ms),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: skills.length,
              itemBuilder: (context, index) {
                final skill = skills[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: GlassCard(
                    onTap: () => _showSkillEditor(skill),
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        // Avatar
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            gradient: AppGradients.brand,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Center(
                            child: Text(skill.avatarEmoji, style: const TextStyle(fontSize: 22)),
                          ),
                        ),
                        const SizedBox(width: 14),
                        // Content
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(skill.name, style: GoogleFonts.inter(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 15)),
                              const SizedBox(height: 3),
                              Text(skill.description, style: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 12), maxLines: 2, overflow: TextOverflow.ellipsis),
                              if (skill.allowedTools.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Wrap(
                                  spacing: 4,
                                  children: skill.allowedTools.take(3).map((t) => Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary.withAlpha(30),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(t, style: GoogleFonts.robotoMono(color: AppColors.primaryLight, fontSize: 10)),
                                  )).toList(),
                                ),
                              ],
                            ],
                          ),
                        ),
                        // Actions
                        Column(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, size: 18, color: AppColors.textSecondary),
                              onPressed: () => _showSkillEditor(skill),
                            ),
                            IconButton(
                              icon: Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.error.withAlpha(180)),
                              onPressed: () => _deleteSkill(skill.id),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ).animate().fadeIn(delay: Duration(milliseconds: index * 60), duration: 300.ms);
              },
            ),
      floatingActionButton: skills.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: _showSkillEditor,
              icon: const Icon(Icons.add_rounded),
              label: Text('New Skill', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
            )
          : null,
    );
  }
}

// ── Skill Editor Bottom Sheet ──────────────────────────────────────────────────

class _SkillEditor extends StatefulWidget {
  final Skill? skill;
  final Function(Skill) onSave;

  const _SkillEditor({this.skill, required this.onSave});

  @override
  State<_SkillEditor> createState() => _SkillEditorState();
}

class _SkillEditorState extends State<_SkillEditor> {
  late TextEditingController _nameCtrl;
  late TextEditingController _descCtrl;
  late TextEditingController _promptCtrl;
  late TextEditingController _toolsCtrl;
  String _emoji = '🤖';

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.skill?.name ?? '');
    _descCtrl = TextEditingController(text: widget.skill?.description ?? '');
    _promptCtrl = TextEditingController(text: widget.skill?.systemPrompt ?? '');
    _toolsCtrl = TextEditingController(text: widget.skill?.allowedTools.join(', ') ?? '');
    _emoji = widget.skill?.avatarEmoji ?? '🤖';
  }

  void _save() {
    final name = _nameCtrl.text.trim();
    final prompt = _promptCtrl.text.trim();
    if (name.isEmpty || prompt.isEmpty) return;

    final tools = _toolsCtrl.text.split(',').map((t) => t.trim()).where((t) => t.isNotEmpty).toList();

    final newSkill = Skill(
      id: widget.skill?.id,
      name: name,
      description: _descCtrl.text.trim(),
      systemPrompt: prompt,
      allowedTools: tools,
      avatarEmoji: _emoji,
    );
    widget.onSave(newSkill);
    Navigator.pop(context);
  }

  final _emojis = ['🤖', '🧠', '🔬', '💻', '📚', '🎨', '🔧', '📊', '🌐', '⚡', '🎯', '🔐'];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 24,
        right: 24,
        top: 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Row(
              children: [
                ShaderMask(
                  shaderCallback: (b) => AppGradients.brand.createShader(b),
                  child: Text(
                    widget.skill == null ? 'Create Skill' : 'Edit Skill',
                    style: GoogleFonts.inter(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700),
                  ),
                ),
                const Spacer(),
                IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close, color: AppColors.textMuted)),
              ],
            ),
            const SizedBox(height: 16),

            // Emoji picker
            Text('AVATAR', style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _emojis.map((e) => GestureDetector(
                onTap: () => setState(() => _emoji = e),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: _emoji == e ? AppGradients.brand : null,
                    color: _emoji == e ? null : AppColors.bgCard,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _emoji == e ? Colors.transparent : AppColors.border),
                  ),
                  child: Center(child: Text(e, style: const TextStyle(fontSize: 20))),
                ),
              )).toList(),
            ),
            const SizedBox(height: 20),

            TextField(
              controller: _nameCtrl,
              style: GoogleFonts.inter(color: AppColors.textPrimary),
              decoration: const InputDecoration(labelText: 'Skill Name', hintText: 'e.g., Code Reviewer'),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _descCtrl,
              style: GoogleFonts.inter(color: AppColors.textPrimary),
              decoration: const InputDecoration(labelText: 'Description', hintText: 'What does this skill specialize in?'),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _promptCtrl,
              style: GoogleFonts.inter(color: AppColors.textPrimary, fontSize: 13),
              maxLines: 4,
              decoration: const InputDecoration(labelText: 'System Prompt', hintText: 'You are an expert at...'),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _toolsCtrl,
              style: GoogleFonts.inter(color: AppColors.textPrimary),
              decoration: const InputDecoration(labelText: 'Allowed Tools (comma-separated)', hintText: 'read_file, web_search, run_code'),
            ),
            const SizedBox(height: 24),
            GradientButton(label: 'Save Skill', icon: Icons.save_rounded, onPressed: _save),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
