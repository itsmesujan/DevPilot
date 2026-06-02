import 'package:uuid/uuid.dart';

enum WorkflowNodeType { trigger, llm, tool, condition, output }

enum WorkflowStatus { idle, running, paused, done, failed }

class WorkflowNode {
  final String id;
  final WorkflowNodeType type;
  final String label;
  final Map<String, dynamic> config;
  final List<String> nextIds;

  WorkflowNode({
    String? id,
    required this.type,
    required this.label,
    this.config = const {},
    this.nextIds = const [],
  }) : id = id ?? const Uuid().v4();
}

class Workflow {
  final String id;
  final String name;
  final String description;
  final List<WorkflowNode> nodes;
  WorkflowStatus status;
  final DateTime createdAt;
  DateTime? lastRunAt;
  bool isScheduled;
  String? cronExpression;

  Workflow({
    String? id,
    required this.name,
    this.description = '',
    List<WorkflowNode>? nodes,
    this.status = WorkflowStatus.idle,
    DateTime? createdAt,
    this.lastRunAt,
    this.isScheduled = false,
    this.cronExpression,
  })  : id = id ?? const Uuid().v4(),
        nodes = nodes ?? [],
        createdAt = createdAt ?? DateTime.now();
}
