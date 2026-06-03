import 'package:uuid/uuid.dart';

class Skill {
  final String id;
  final String name;
  final String description;
  final String systemPrompt;
  final List<String> allowedTools;
  final String avatarEmoji;

  Skill({
    String? id,
    required this.name,
    required this.description,
    required this.systemPrompt,
    this.allowedTools = const [],
    this.avatarEmoji = '🤖',
  }) : id = id ?? const Uuid().v4();

  factory Skill.fromJson(Map<String, dynamic> json) {
    return Skill(
      id: json['id'] as String?,
      name: json['name'] as String,
      description: json['description'] as String? ?? '',
      systemPrompt: json['systemPrompt'] as String,
      allowedTools: (json['allowedTools'] as List?)?.cast<String>() ?? [],
      avatarEmoji: json['avatarEmoji'] as String? ?? '🤖',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'systemPrompt': systemPrompt,
        'allowedTools': allowedTools,
        'avatarEmoji': avatarEmoji,
      };
}
