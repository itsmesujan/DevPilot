import 'dart:async';
import 'package:uuid/uuid.dart';
import '../../../models/agent_models.dart';
import '../../../models/skill_models.dart';
import '../agent_orchestrator.dart';
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

  /// Dispatch a task to a specialized agent using a given skill name.
  /// Uses real AgentOrchestrator with the skill's system prompt injected.
  Stream<AgentStep> dispatchTask(String goal, String skillName) async* {
    final skills = SkillManager.instance.skills;
    final skill = skills.firstWhere(
      (s) => s.name.toLowerCase() == skillName.toLowerCase(),
      orElse: () => Skill(
        name: skillName,
        description: 'Generic assistant',
        systemPrompt: 'You are a helpful assistant.',
      ),
    );

    final subTask = AgentTask(goal: goal);
    final subAgent = SubAgent(role: skill.name, skill: skill, task: subTask);
    _activeAgents.add(subAgent);
    subTask.status = AgentStatus.running;

    yield AgentStep(thought: '${skill.avatarEmoji} [${skill.name}]: Starting on task...');

    try {
      // Run the real agent orchestrator with the skill's system prompt injected
      // via a specialized goal prefix that includes the role context
      final augmentedGoal = '${skill.systemPrompt}\n\n---\nTask: $goal';

      final orchestrator = AgentOrchestrator.instance;
      final eventStream = orchestrator.run(
        goal: augmentedGoal,
        useThinking: true,
      );

      await for (final event in eventStream) {
        if (event.type == AgentEventType.thinking && event.thinkingStep != null) {
          final step = event.thinkingStep!;
          subTask.steps.add(AgentStep(thought: step.content));
          yield AgentStep(thought: '${skill.avatarEmoji} [${skill.name}]: ${step.content}');
        } else if (event.type == AgentEventType.toolResult && event.toolResult != null) {
          final result = event.toolResult!;
          subTask.steps.add(AgentStep(thought: 'Tool: ${result.toolName}', toolOutput: result.output));
          yield AgentStep(thought: '${skill.avatarEmoji} [${skill.name}] used ${result.toolName}', toolOutput: result.output);
        } else if (event.type == AgentEventType.text) {
          subTask.finalAnswer = (subTask.finalAnswer ?? '') + event.content;
        }
      }

      subTask.status = AgentStatus.done;
      yield AgentStep(
        thought: '${skill.avatarEmoji} [${skill.name}]: Task complete.',
        toolOutput: subTask.finalAnswer ?? 'No output produced.',
      );
    } catch (e) {
      subTask.status = AgentStatus.failed;
      yield AgentStep(thought: '${skill.avatarEmoji} [${skill.name}]: Error — $e');
    } finally {
      _activeAgents.remove(subAgent);
    }
  }

  /// Run a "Council" of agents where multiple skills deliberate on a topic.
  /// Each agent responds in sequence, then a synthesis is produced.
  Stream<AgentStep> runCouncil(String topic, List<String> skillNames) async* {
    yield AgentStep(thought: '🏛️ Council convened on: "$topic"');
    yield AgentStep(thought: 'Members: ${skillNames.join(", ")}');

    final contributions = <String, String>{};

    // Sequential deliberation — each agent builds on the previous
    for (final skillName in skillNames) {
      yield AgentStep(thought: '→ Calling on $skillName...');

      String agentResult = '';
      await for (final step in dispatchTask(topic, skillName)) {
        yield step;
        if (step.toolOutput != null && step.toolOutput!.isNotEmpty) {
          agentResult = step.toolOutput!;
        }
      }
      contributions[skillName] = agentResult.isNotEmpty ? agentResult : 'No specific findings.';
    }

    yield AgentStep(thought: '⚡ All members reported. Synthesizing council findings...');

    // Build synthesis
    final synthesisBuffer = StringBuffer();
    synthesisBuffer.writeln('# Council Report: $topic\n');
    for (final entry in contributions.entries) {
      synthesisBuffer.writeln('## ${entry.key}\n${entry.value}\n');
    }

    yield AgentStep(
      thought: '✅ Council Synthesis Complete',
      toolOutput: synthesisBuffer.toString(),
    );
  }
}
