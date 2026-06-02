import 'dart:async';
import 'package:uuid/uuid.dart';
import '../../../models/agent_models.dart';
import '../../../models/skill_models.dart';
import '../agent_service.dart';
import '../skills/skill_manager.dart';

/// Represents a specialized sub-agent spawned for a specific task.
class SubAgent {
  final String id;
  final String role;
  final Skill skill;
  final AgentTask task;
  AgentStatus get status => task.status;

  SubAgent({required this.role, required this.skill, required this.task})
      : id = const Uuid().v4();
}

/// Orchestrates multiple sub-agents to solve complex goals in parallel or sequence.
class MultiAgentOrchestrator {
  MultiAgentOrchestrator._();
  static final MultiAgentOrchestrator instance = MultiAgentOrchestrator._();

  final List<SubAgent> _activeAgents = [];
  List<SubAgent> get activeAgents => List.unmodifiable(_activeAgents);

  /// Dispatch a task to a specialized agent using a given skill.
  Stream<AgentStep> dispatchTask(String goal, String skillName) async* {
    final skills = SkillManager.instance.skills;
    final skill = skills.firstWhere(
      (s) => s.name.toLowerCase() == skillName.toLowerCase(),
      orElse: () => Skill(
        name: 'Fallback',
        description: 'Generic fallback',
        systemPrompt: 'You are a helpful assistant.',
      ),
    );

    final subTask = AgentTask(goal: goal);
    final subAgent = SubAgent(role: skill.name, skill: skill, task: subTask);
    _activeAgents.add(subAgent);

    // Provide the skill's system prompt to the underlying agent service.
    // In a real implementation, we'd spawn a fresh AgentService instance or 
    // inject the system prompt temporarily. For now, we simulate execution.
    
    subTask.status = AgentStatus.running;
    
    yield AgentStep(thought: 'Orchestrator: Dispatched to [${skill.name}] for goal: $goal');
    
    // Simulate specialized agent execution
    await Future.delayed(const Duration(seconds: 1));
    yield AgentStep(thought: '[${skill.name}]: Analyzing requirements...');
    
    await Future.delayed(const Duration(seconds: 1));
    yield AgentStep(thought: '[${skill.name}]: Processing task using allowed tools: ${skill.allowedTools.join(", ")}');
    
    await Future.delayed(const Duration(seconds: 1));
    
    subTask.finalAnswer = 'Completed specialized task: $goal';
    subTask.status = AgentStatus.done;
    
    yield AgentStep(thought: 'Orchestrator: [${skill.name}] finished.');
    
    // Clean up
    _activeAgents.remove(subAgent);
  }

  /// Run a "Council" of agents where multiple skills debate or collaborate.
  Stream<AgentStep> runCouncil(String topic, List<String> skillNames) async* {
    yield AgentStep(thought: 'Orchestrator: Convening council on "$topic" with ${skillNames.join(", ")}');
    
    final results = <String, String>{};
    
    // Run them in parallel
    final futures = skillNames.map((name) async {
       String result = '';
       await for (final step in dispatchTask(topic, name)) {
         // ignore intermediate steps to avoid clogging stream
       }
       // Retrieve final result from activeAgents (simulated here)
       result = 'Report from $name on $topic';
       return MapEntry(name, result);
    });

    final completed = await Future.wait(futures);
    for (final entry in completed) {
      results[entry.key] = entry.value;
      yield AgentStep(thought: 'Council Member [${entry.key}] submitted findings.');
    }

    yield AgentStep(thought: 'Orchestrator: Council concluded. Synthesizing results.');
    
    // Synthesize
    await Future.delayed(const Duration(seconds: 1));
    yield AgentStep(
      thought: 'Synthesis Complete',
      toolOutput: results.values.join('\n\n'),
    );
  }
}
