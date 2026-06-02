import 'dart:convert';
import '../../models/study_models.dart';
import '../../models/chat_message.dart';
import '../ai/ai_client.dart';
import '../storage/storage_service.dart';

class StudyAssistant {
  StudyAssistant._();
  static final StudyAssistant instance = StudyAssistant._();

  Future<List<Flashcard>> generateFlashcards({
    required String topic,
    int count = 10,
  }) async {
    final storage = StorageService.instance;
    final provider = storage.selectedProvider;
    final modelId = storage.selectedModelId;

    final prompt = '''Generate $count flashcards for the topic: "$topic".
Each flashcard must contain a front (question or key term) and a back (answer or definition).

Output ONLY a JSON array in the following format:
[
  {
    "front": "Front of card content",
    "back": "Back of card content"
  }
]''';

    final buffer = StringBuffer();
    try {
      await for (final chunk in AiClient.instance.streamChat(
        provider: provider,
        modelId: modelId,
        messages: [
          ChatMessage(role: MessageRole.user, content: prompt),
        ],
        systemPrompt: 'You are an educational assistant. Output ONLY valid JSON array.',
        temperature: 0.5,
        maxTokens: 1500,
      )) {
        buffer.write(chunk);
      }

      final responseText = buffer.toString();
      final jsonMatch = RegExp(r'\[[\s\S]*\]').firstMatch(responseText);
      if (jsonMatch != null) {
        final List<dynamic> list = jsonDecode(jsonMatch.group(0)!);
        return list.map((item) {
          return Flashcard(
            front: item['front'] as String? ?? 'Question',
            back: item['back'] as String? ?? 'Answer',
            state: CardState.newCard,
          );
        }).toList();
      }
    } catch (_) {}

    // Fallback
    return List.generate(
      count,
      (i) => Flashcard(
        front: 'Question ${i + 1} about $topic',
        back: 'Answer ${i + 1} about $topic',
        state: CardState.newCard,
      ),
    );
  }

  Future<QuizSession> generateQuiz({
    required String topic,
    required String subject,
    int questionCount = 5,
  }) async {
    final storage = StorageService.instance;
    final provider = storage.selectedProvider;
    final modelId = storage.selectedModelId;

    final prompt = '''Generate a quiz with $questionCount questions for the topic: "$topic".
Questions should be multipleChoice or trueFalse.

Output ONLY a JSON array in the following format:
[
  {
    "question": "Question text",
    "type": "multipleChoice" or "trueFalse",
    "correctAnswer": "Exact matching correct option text",
    "options": ["option 1", "option 2", "option 3", "option 4"],
    "explanation": "Why this is correct"
  }
]''';

    final buffer = StringBuffer();
    try {
      await for (final chunk in AiClient.instance.streamChat(
        provider: provider,
        modelId: modelId,
        messages: [
          ChatMessage(role: MessageRole.user, content: prompt),
        ],
        systemPrompt: 'You are an educational assistant. Output ONLY valid JSON array.',
        temperature: 0.5,
        maxTokens: 2000,
      )) {
        buffer.write(chunk);
      }

      final responseText = buffer.toString();
      final jsonMatch = RegExp(r'\[[\s\S]*\]').firstMatch(responseText);
      if (jsonMatch != null) {
        final List<dynamic> list = jsonDecode(jsonMatch.group(0)!);
        final questions = list.map((item) {
          final typeStr = item['type'] as String? ?? 'multipleChoice';
          final type = typeStr == 'trueFalse' ? QuestionType.trueFalse : QuestionType.multipleChoice;
          return QuizQuestion(
            question: item['question'] as String? ?? 'Question',
            type: type,
            correctAnswer: item['correctAnswer'] as String? ?? 'Answer',
            options: item['options'] != null ? List<String>.from(item['options']) : null,
            explanation: item['explanation'] as String?,
          );
        }).toList();

        return QuizSession(
          title: '$topic Quiz',
          subject: subject,
          questions: questions,
        );
      }
    } catch (_) {}

    // Fallback
    return QuizSession(
      title: '$topic Quiz (Fallback)',
      subject: subject,
      questions: [
        QuizQuestion(
          question: 'Is $topic an interesting topic?',
          type: QuestionType.trueFalse,
          correctAnswer: 'True',
          options: ['True', 'False'],
          explanation: 'Yes, it is very interesting!',
        )
      ],
    );
  }

  Future<String> summarizeText({required String text}) async {
    final storage = StorageService.instance;
    final provider = storage.selectedProvider;
    final modelId = storage.selectedModelId;

    final buffer = StringBuffer();
    await for (final chunk in AiClient.instance.streamChat(
      provider: provider,
      modelId: modelId,
      messages: [
        ChatMessage(role: MessageRole.user, content: 'Summarize the following text in bullet points:\n\n$text'),
      ],
      systemPrompt: 'You are a summarization assistant. Provide clean, structured markdown bullet points.',
      temperature: 0.3,
      maxTokens: 1000,
    )) {
      buffer.write(chunk);
    }
    return buffer.toString();
  }

  Future<String> explainConcept({required String concept}) async {
    final storage = StorageService.instance;
    final provider = storage.selectedProvider;
    final modelId = storage.selectedModelId;

    final buffer = StringBuffer();
    await for (final chunk in AiClient.instance.streamChat(
      provider: provider,
      modelId: modelId,
      messages: [
        ChatMessage(role: MessageRole.user, content: 'Explain the concept of "$concept" as if I am 10 years old.'),
      ],
      systemPrompt: 'You are a teaching assistant. Use analogies, simple words, and a friendly tone.',
      temperature: 0.5,
      maxTokens: 1000,
    )) {
      buffer.write(chunk);
    }
    return buffer.toString();
  }

  Future<String> generateStudyPlan({
    required String subject,
    List<String> topics = const [],
    int days = 7,
  }) async {
    final storage = StorageService.instance;
    final provider = storage.selectedProvider;
    final modelId = storage.selectedModelId;

    final buffer = StringBuffer();
    await for (final chunk in AiClient.instance.streamChat(
      provider: provider,
      modelId: modelId,
      messages: [
        ChatMessage(role: MessageRole.user, content: 'Create a $days-day study plan for "$subject" covering: ${topics.join(", ")}'),
      ],
      systemPrompt: 'You are a study coordinator. Output a structured day-by-day plan with duration estimates and specific actions.',
      temperature: 0.4,
      maxTokens: 1500,
    )) {
      buffer.write(chunk);
    }
    return buffer.toString();
  }

  Future<String> createMnemonic({required String items}) async {
    final storage = StorageService.instance;
    final provider = storage.selectedProvider;
    final modelId = storage.selectedModelId;

    final buffer = StringBuffer();
    await for (final chunk in AiClient.instance.streamChat(
      provider: provider,
      modelId: modelId,
      messages: [
        ChatMessage(role: MessageRole.user, content: 'Create a mnemonic device to help me remember the following items: $items'),
      ],
      systemPrompt: 'You are a memory coach. Offer funny, memorable acronyms or stories to remember list items.',
      temperature: 0.6,
      maxTokens: 800,
    )) {
      buffer.write(chunk);
    }
    return buffer.toString();
  }
}
