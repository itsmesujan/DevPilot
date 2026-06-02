import 'package:flutter/material.dart';
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
        setState(() {
          _steps.add(step);
        });
        
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
      backgroundColor: const Color(0xFF0D0D1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0D1A),
        title: const Text('Agent Council', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Select Council Members:', style: TextStyle(color: Colors.white70)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: skills.map((s) {
                    final isSelected = _selectedSkills.contains(s.name);
                    return FilterChip(
                      label: Text(s.name),
                      selected: isSelected,
                      onSelected: (_) => _toggleSkill(s.name),
                      selectedColor: const Color(0xFF7C3AED),
                      checkmarkColor: Colors.white,
                      labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.white70),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _topicController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Enter topic for council discussion...',
                    hintStyle: const TextStyle(color: Colors.white38),
                    filled: true,
                    fillColor: const Color(0xFF1A1A2E),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    suffixIcon: IconButton(
                      icon: _isRunning 
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.send, color: Color(0xFF7C3AED)),
                      onPressed: _isRunning ? null : _runCouncil,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(color: Colors.white10),
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _steps.length,
              itemBuilder: (context, index) {
                final step = _steps[index];
                return _CouncilStepCard(step: step);
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
  const _CouncilStepCard({required this.step});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF1A1A2E),
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.psychology, color: Color(0xFF7C3AED), size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    step.thought,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            if (step.toolOutput != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white10),
                ),
                child: Text(step.toolOutput!, style: const TextStyle(color: Colors.white70, fontFamily: 'monospace')),
              ),
            ]
          ],
        ),
      ),
    );
  }
}
