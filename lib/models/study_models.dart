import 'package:uuid/uuid.dart';

/// Represents a flashcard deck (collection of flashcards)
class FlashcardDeck {
  final String id;
  final String name;
  final String subject;
  final String? description;
  final List<Flashcard> cards;
  final DateTime createdAt;
  DateTime lastStudied;
  int totalReviews;

  FlashcardDeck({
    String? id,
    required this.name,
    required this.subject,
    this.description,
    List<Flashcard>? cards,
    DateTime? createdAt,
    DateTime? lastStudied,
    this.totalReviews = 0,
  })  : id = id ?? const Uuid().v4(),
        cards = cards ?? [],
        createdAt = createdAt ?? DateTime.now(),
        lastStudied = lastStudied ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'subject': subject,
        'description': description,
        'cards': cards.map((c) => c.toJson()).toList(),
        'createdAt': createdAt.toIso8601String(),
        'lastStudied': lastStudied.toIso8601String(),
        'totalReviews': totalReviews,
      };

  factory FlashcardDeck.fromJson(Map<String, dynamic> json) => FlashcardDeck(
        id: json['id'] as String,
        name: json['name'] as String,
        subject: json['subject'] as String,
        description: json['description'] as String?,
        cards: (json['cards'] as List?)
                ?.map((c) => Flashcard.fromJson(c))
                .toList() ??
            [],
        createdAt: DateTime.parse(json['createdAt'] as String),
        lastStudied: DateTime.parse(json['lastStudied'] as String),
        totalReviews: json['totalReviews'] as int? ?? 0,
      );

  int get cardCount => cards.length;

  /// Get cards due for review based on spaced repetition
  List<Flashcard> getDueCards() {
    final now = DateTime.now();
    return cards.where((c) => c.dueDate.isBefore(now) || c.dueDate.isAtSameMomentAs(now)).toList()
      ..sort((a, b) => a.dueDate.compareTo(b.dueDate));
  }

  /// Get new cards (never reviewed)
  List<Flashcard> getNewCards() {
    return cards.where((c) => c.reviews == 0).toList();
  }

  /// Get learning statistics
  DeckStats getStats() {
    final due = getDueCards().length;
    final newCards = getNewCards().length;
    final learning = cards.where((c) => c.state == CardState.learning).length;
    final mature = cards.where((c) => c.state == CardState.mature).length;

    return DeckStats(
      totalCards: cards.length,
      dueCards: due,
      newCards: newCards,
      learningCards: learning,
      matureCards: mature,
    );
  }
}

/// Represents a single flashcard
class Flashcard {
  final String id;
  final String front;
  final String back;
  final List<String> tags;
  final DateTime createdAt;

  // Spaced repetition fields (SM-2 algorithm)
  double easeFactor;
  int interval; // days
  int reviews;
  int lapses;
  DateTime dueDate;
  CardState state;

  Flashcard({
    String? id,
    required this.front,
    required this.back,
    this.tags = const [],
    DateTime? createdAt,
    this.easeFactor = 2.5,
    this.interval = 0,
    this.reviews = 0,
    this.lapses = 0,
    DateTime? dueDate,
    this.state = CardState.newCard,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now(),
        dueDate = dueDate ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'front': front,
        'back': back,
        'tags': tags,
        'createdAt': createdAt.toIso8601String(),
        'easeFactor': easeFactor,
        'interval': interval,
        'reviews': reviews,
        'lapses': lapses,
        'dueDate': dueDate.toIso8601String(),
        'state': state.name,
      };

  factory Flashcard.fromJson(Map<String, dynamic> json) => Flashcard(
        id: json['id'] as String,
        front: json['front'] as String,
        back: json['back'] as String,
        tags: List<String>.from(json['tags'] ?? []),
        createdAt: DateTime.parse(json['createdAt'] as String),
        easeFactor: (json['easeFactor'] as num?)?.toDouble() ?? 2.5,
        interval: json['interval'] as int? ?? 0,
        reviews: json['reviews'] as int? ?? 0,
        lapses: json['lapses'] as int? ?? 0,
        dueDate: DateTime.parse(json['dueDate'] as String),
        state: CardState.values.byName(json['state'] as String? ?? 'newCard'),
      );
}

/// Card learning state
enum CardState {
  newCard,
  learning,
  review,
  mature,
  suspended,
}

/// Review quality rating (SM-2 algorithm)
enum ReviewRating {
  again,  // 0 - Complete failure
  hard,   // 1 - Incorrect but easy to remember
  good,   // 2 - Correct with effort
  easy,   // 3 - Perfect recall
}

extension ReviewRatingExtension on ReviewRating {
  int get quality {
    switch (this) {
      case ReviewRating.again:
        return 0;
      case ReviewRating.hard:
        return 2;
      case ReviewRating.good:
        return 4;
      case ReviewRating.easy:
        return 5;
    }
  }

  String get label {
    switch (this) {
      case ReviewRating.again:
        return 'Again';
      case ReviewRating.hard:
        return 'Hard';
      case ReviewRating.good:
        return 'Good';
      case ReviewRating.easy:
        return 'Easy';
    }
  }

  String get emoji {
    switch (this) {
      case ReviewRating.again:
        return '😵';
      case ReviewRating.hard:
        return '😰';
      case ReviewRating.good:
        return '👍';
      case ReviewRating.easy:
        return '🎉';
    }
  }
}

/// Deck statistics
class DeckStats {
  final int totalCards;
  final int dueCards;
  final int newCards;
  final int learningCards;
  final int matureCards;

  DeckStats({
    required this.totalCards,
    required this.dueCards,
    required this.newCards,
    required this.learningCards,
    required this.matureCards,
  });

  double get progressPercent =>
      totalCards > 0 ? (matureCards / totalCards) * 100 : 0;
}

/// Quiz question
class QuizQuestion {
  final String id;
  final String question;
  final QuestionType type;
  final String? context;
  final String correctAnswer;
  final List<String>? options; // For multiple choice
  final int points;
  final String? explanation;

  QuizQuestion({
    String? id,
    required this.question,
    required this.type,
    this.context,
    required this.correctAnswer,
    this.options,
    this.points = 1,
    this.explanation,
  }) : id = id ?? const Uuid().v4();

  Map<String, dynamic> toJson() => {
        'id': id,
        'question': question,
        'type': type.name,
        'context': context,
        'correctAnswer': correctAnswer,
        'options': options,
        'points': points,
        'explanation': explanation,
      };

  factory QuizQuestion.fromJson(Map<String, dynamic> json) => QuizQuestion(
        id: json['id'] as String,
        question: json['question'] as String,
        type: QuestionType.values.byName(json['type'] as String),
        context: json['context'] as String?,
        correctAnswer: json['correctAnswer'] as String,
        options: json['options'] != null
            ? List<String>.from(json['options'])
            : null,
        points: json['points'] as int? ?? 1,
        explanation: json['explanation'] as String?,
      );

  bool checkAnswer(String answer) {
    switch (type) {
      case QuestionType.multipleChoice:
      case QuestionType.trueFalse:
        return answer.toLowerCase().trim() == correctAnswer.toLowerCase().trim();
      case QuestionType.shortAnswer:
        return answer.toLowerCase().trim().contains(correctAnswer.toLowerCase().trim());
      case QuestionType.essay:
        return answer.length > 50; // Basic check for essays
      case QuestionType.fillBlank:
        return answer.toLowerCase().trim() == correctAnswer.toLowerCase().trim();
    }
  }
}

/// Question type
enum QuestionType {
  multipleChoice,
  trueFalse,
  shortAnswer,
  essay,
  fillBlank,
}

/// Quiz session
class QuizSession {
  final String id;
  final String title;
  final String subject;
  final List<QuizQuestion> questions;
  final DateTime startedAt;
  DateTime? completedAt;
  final Map<String, String> answers; // questionId -> answer
  int score;

  QuizSession({
    String? id,
    required this.title,
    required this.subject,
    required this.questions,
    DateTime? startedAt,
    this.completedAt,
    Map<String, String>? answers,
    this.score = 0,
  })  : id = id ?? const Uuid().v4(),
        startedAt = startedAt ?? DateTime.now(),
        answers = answers ?? {};

  bool get isCompleted => completedAt != null;

  int get totalPoints => questions.fold<int>(0, (sum, q) => sum + q.points);

  double get percentage => totalPoints > 0 ? (score / totalPoints) * 100 : 0;

  String get grade {
    if (percentage >= 90) return 'A';
    if (percentage >= 80) return 'B';
    if (percentage >= 70) return 'C';
    if (percentage >= 60) return 'D';
    return 'F';
  }

  void submitAnswer(String questionId, String answer) {
    answers[questionId] = answer;
    final question = questions.firstWhere((q) => q.id == questionId);
    if (question.checkAnswer(answer)) {
      score += question.points;
    }
  }

  void complete() {
    completedAt = DateTime.now();
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'subject': subject,
        'questions': questions.map((q) => q.toJson()).toList(),
        'startedAt': startedAt.toIso8601String(),
        'completedAt': completedAt?.toIso8601String(),
        'answers': answers,
        'score': score,
      };
}

/// Study session record
class StudySession {
  final String id;
  final SessionType type;
  final String subject;
  final Duration duration;
  final DateTime startedAt;
  final int cardsReviewed;
  final int correctAnswers;
  final String? notes;

  StudySession({
    String? id,
    required this.type,
    required this.subject,
    required this.duration,
    DateTime? startedAt,
    this.cardsReviewed = 0,
    this.correctAnswers = 0,
    this.notes,
  }) : id = id ?? const Uuid().v4(),
        startedAt = startedAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'subject': subject,
        'duration': duration.inSeconds,
        'startedAt': startedAt.toIso8601String(),
        'cardsReviewed': cardsReviewed,
        'correctAnswers': correctAnswers,
        'notes': notes,
      };
}

/// Study session type
enum SessionType {
  flashcard,
  quiz,
  pomodoro,
  reading,
  notes,
}

/// Study note
class StudyNote {
  final String id;
  final String title;
  final String content;
  final String subject;
  final List<String> tags;
  final String? aiSummary;
  final DateTime createdAt;
  DateTime updatedAt;

  StudyNote({
    String? id,
    required this.title,
    required this.content,
    required this.subject,
    this.tags = const [],
    this.aiSummary,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'content': content,
        'subject': subject,
        'tags': tags,
        'aiSummary': aiSummary,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };
}

/// Pomodoro session state
enum PomodoroState {
  idle,
  focus,
  shortBreak,
  longBreak,
  paused,
}

/// Pomodoro timer session
class PomodoroSession {
  final int focusMinutes;
  final int shortBreakMinutes;
  final int longBreakMinutes;
  final int sessionsBeforeLongBreak;
  int completedSessions;
  PomodoroState state;
  DateTime? startTime;
  Duration remaining;

  PomodoroSession({
    this.focusMinutes = 25,
    this.shortBreakMinutes = 5,
    this.longBreakMinutes = 15,
    this.sessionsBeforeLongBreak = 4,
    this.completedSessions = 0,
    this.state = PomodoroState.idle,
    this.startTime,
    Duration? remaining,
  }) : remaining = remaining ?? Duration(minutes: focusMinutes);

  bool get shouldTakeLongBreak =>
      completedSessions > 0 && completedSessions % sessionsBeforeLongBreak == 0;

  void startFocus() {
    state = PomodoroState.focus;
    startTime = DateTime.now();
    remaining = Duration(minutes: focusMinutes);
  }

  void startBreak() {
    if (shouldTakeLongBreak) {
      state = PomodoroState.longBreak;
      remaining = Duration(minutes: longBreakMinutes);
    } else {
      state = PomodoroState.shortBreak;
      remaining = Duration(minutes: shortBreakMinutes);
    }
    startTime = DateTime.now();
  }

  void pause() {
    if (state != PomodoroState.idle) {
      state = PomodoroState.paused;
    }
  }

  void resume() {
    if (state == PomodoroState.paused) {
      state = PomodoroState.focus; // Simplified
      startTime = DateTime.now();
    }
  }

  void completeSession() {
    completedSessions++;
    state = PomodoroState.idle;
  }

  void tick() {
    if (state != PomodoroState.idle && state != PomodoroState.paused) {
      remaining -= const Duration(seconds: 1);
      if (remaining.inSeconds <= 0) {
        if (state == PomodoroState.focus) {
          completeSession();
        } else {
          state = PomodoroState.idle;
        }
      }
    }
  }
}