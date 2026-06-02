import 'package:flutter/material.dart';
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
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  void _showSkillEditor([Skill? existing]) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E1E2E),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
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
        backgroundColor: const Color(0xFF1E1E2E),
        title: const Text('Delete Skill', style: TextStyle(color: Colors.white)),
        content: const Text('Are you sure you want to delete this custom skill?', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
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
      return const Scaffold(
        backgroundColor: Color(0xFF0D0D1A),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final skills = SkillManager.instance.skills;

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0D1A),
        title: const Text('Custom Skills', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: skills.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.psychology_outlined, size: 72, color: Colors.white24),
                  const SizedBox(height: 16),
                  const Text('No Custom Skills', style: TextStyle(color: Colors.white60, fontSize: 18)),
                  const SizedBox(height: 8),
                  const Text('Create domain-expert personas for your agent.', style: TextStyle(color: Colors.white38)),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7C3AED)),
                    onPressed: _showSkillEditor,
                    icon: const Icon(Icons.add),
                    label: const Text('Create Skill'),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: skills.length,
              itemBuilder: (context, index) {
                final skill = skills[index];
                return Card(
                  color: const Color(0xFF1A1A2E),
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(color: Colors.white10),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    title: Text(skill.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(skill.description, style: const TextStyle(color: Colors.white70)),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, color: Colors.white54),
                          onPressed: () => _showSkillEditor(skill),
                        ),
                        IconButton(
                          icon: Icon(Icons.delete_outline, color: Colors.red[400]),
                          onPressed: () => _deleteSkill(skill.id),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: skills.isNotEmpty
          ? FloatingActionButton(
              backgroundColor: const Color(0xFF7C3AED),
              onPressed: () => _showSkillEditor(),
              child: const Icon(Icons.add),
            )
          : null,
    );
  }
}

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

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.skill?.name ?? '');
    _descCtrl = TextEditingController(text: widget.skill?.description ?? '');
    _promptCtrl = TextEditingController(text: widget.skill?.systemPrompt ?? '');
    _toolsCtrl = TextEditingController(text: widget.skill?.allowedTools.join(', ') ?? '');
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
    );
    widget.onSave(newSkill);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 24,
        right: 24,
        top: 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.skill == null ? 'Create Skill' : 'Edit Skill',
            style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _nameCtrl,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(labelText: 'Skill Name', hintText: 'e.g., Code Reviewer'),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _descCtrl,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(labelText: 'Description', hintText: 'What does this skill do?'),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _promptCtrl,
            style: const TextStyle(color: Colors.white),
            maxLines: 4,
            decoration: const InputDecoration(labelText: 'System Prompt', hintText: 'You are an expert at...'),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _toolsCtrl,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(labelText: 'Allowed Tools (comma separated)', hintText: 'read_file, web_search'),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7C3AED), padding: const EdgeInsets.symmetric(vertical: 16)),
            onPressed: _save,
            child: const Text('Save Skill'),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
