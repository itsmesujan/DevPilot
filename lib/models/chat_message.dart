import 'package:uuid/uuid.dart';

enum MessageRole { user, assistant, system, tool }

enum MessageStatus { idle, streaming, error }

class ChatMessage {
  final String id;
  final MessageRole role;
  String content;
  final DateTime createdAt;
  MessageStatus status;
  final String? modelId;
  final List<String> imageBase64List;
  bool isStreaming;
  bool hasError;

  ChatMessage({
    String? id,
    required this.role,
    required this.content,
    DateTime? createdAt,
    this.status = MessageStatus.idle,
    this.modelId,
    this.imageBase64List = const [],
    this.isStreaming = false,
    this.hasError = false,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'role': role.name,
        'content': content,
        'createdAt': createdAt.toIso8601String(),
        'modelId': modelId,
        'imageBase64List': imageBase64List,
      };

  factory ChatMessage.fromJson(Map<String, dynamic> j) => ChatMessage(
        id: j['id'] as String,
        role: MessageRole.values.byName(j['role'] as String),
        content: j['content'] as String,
        createdAt: DateTime.parse(j['createdAt'] as String),
        modelId: j['modelId'] as String?,
        imageBase64List: List<String>.from(j['imageBase64List'] ?? []),
      );
}
