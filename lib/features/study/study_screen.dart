import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../models/study_models.dart';
import '../../services/study/study_assistant.dart';
import '../../services/study/spaced_repetition.dart';

/// Study Mode screen with flashcards, quiz, and Pomodoro
class StudyScreen extends StatefulWidget {
  const StudyScreen({super.key});

  @override
  State<StudyScreen> createState() => _StudyScreenState();
}

class _StudyScreenState extends State<StudyScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _studyAssistant = StudyAssistant.instance;
  final _spacedRepetition = SpacedRepetition.instance;

  // Flashcard state
  FlashcardDeck? _currentDeck;
  int _currentCardIndex = 0;
  bool _showAnswer = false;

  // Quiz state
  QuizSession? _currentQuiz;
  int _currentQuestionIndex = 0;
  String? _selectedAnswer;

  // Pomodoro state
  PomodoroSession _pomodoro = PomodoroSession();
  Timer? _pomodoroTimer;

  // Generation state
  bool _isGenerating = false;
  final _topicController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  Future<void> _generateFlashcards() async {
    if (_topicController.text.isEmpty) return;

    setState(() => _isGenerating = true);

    try {
      final cards = await _studyAssistant.generateFlashcards(
        topic: _topicController.text,
        count: 10,
      );

      if (mounted) {
        setState(() {
          _currentDeck = FlashcardDeck(
            name: _topicController.text,
            subject: 'Generated',
            cards: cards,
          );
          _currentCardIndex = 0;
          _showAnswer = false;
          _isGenerating = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Generated ${cards.length} flashcards!')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isGenerating = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to generate: $e')),
        );
      }
    }
  }

  Future<void> _generateQuiz() async {
    if (_topicController.text.isEmpty) return;

    setState(() => _isGenerating = true);

    try {
      final quiz = await _studyAssistant.generateQuiz(
        topic: _topicController.text,
        subject: 'Generated',
        questionCount: 5,
      );

      if (mounted) {
        setState(() {
          _currentQuiz = quiz;
          _currentQuestionIndex = 0;
          _selectedAnswer = null;
          _isGenerating = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isGenerating = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to generate quiz: $e')),
        );
      }
    }
  }

  void _reviewCard(ReviewRating rating) {
    if (_currentDeck == null) return;

    final card = _currentDeck!.cards[_currentCardIndex];
    _spacedRepetition.reviewCard(card, rating);

    setState(() {
      _currentCardIndex++;
      _showAnswer = false;

      if (_currentCardIndex >= _currentDeck!.cards.length) {
        _currentCardIndex = 0;
      }
    });
  }

  void _startPomodoro() {
    setState(() {
      _pomodoro.startFocus();
    });

    _pomodoroTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      setState(() {
        _pomodoro.tick();

        if (_pomodoro.state == PomodoroState.idle &&
            _pomodoro.completedSessions > 0) {
          timer.cancel();
          _showPomodoroComplete();
        }
      });
    });
  }

  void _pausePomodoro() {
    _pomodoroTimer?.cancel();
    setState(() => _pomodoro.pause());
  }

  void _resumePomodoro() {
    setState(() => _pomodoro.resume());
    _startPomodoro();
  }

  void _showPomodoroComplete() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('🎉 Session Complete!'),
        content: Text(
          'Great job! You completed ${_pomodoro.completedSessions} pomodoro session(s).',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() {
                _pomodoro = PomodoroSession();
              });
            },
            child: const Text('Done'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              _startPomodoro();
            },
            child: const Text('Start Another'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Study Mode'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.home), text: 'Home'),
            Tab(icon: Icon(Icons.style), text: 'Flashcards'),
            Tab(icon: Icon(Icons.quiz), text: 'Quiz'),
            Tab(icon: Icon(Icons.timer), text: 'Pomodoro'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildHomeTab(theme),
          _buildFlashcardsTab(theme),
          _buildQuizTab(theme),
          _buildPomodoroTab(theme),
        ],
      ),
    );
  }

  Widget _buildHomeTab(ThemeData theme) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Topic Input
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '📚 What do you want to study?',
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _topicController,
                  decoration: InputDecoration(
                    hintText: 'Enter a topic (e.g., "Photosynthesis", "World War II")',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    prefixIcon: const Icon(Icons.search),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _isGenerating ? null : _generateFlashcards,
                        icon: const Icon(Icons.style),
                        label: const Text('Flashcards'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _isGenerating ? null : _generateQuiz,
                        icon: const Icon(Icons.quiz),
                        label: const Text('Quiz'),
                      ),
                    ),
                  ],
                ),
                if (_isGenerating) ...[
                  const SizedBox(height: 12),
                  const LinearProgressIndicator(),
                  const SizedBox(height: 8),
                  Center(
                    child: Text(
                      'AI is generating content...',
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),

        // Quick Actions
        Text('Quick Actions', style: theme.textTheme.titleMedium),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.5,
          children: [
            _buildActionCard(
              theme,
              icon: Icons.auto_stories,
              title: 'Summarize Text',
              subtitle: 'Paste text to summarize',
              onTap: () => _showSummarizeDialog(),
            ),
            _buildActionCard(
              theme,
              icon: Icons.lightbulb,
              title: 'Explain Concept',
              subtitle: 'Get simple explanations',
              onTap: () => _showExplainDialog(),
            ),
            _buildActionCard(
              theme,
              icon: Icons.calendar_today,
              title: 'Study Plan',
              subtitle: 'Create a study schedule',
              onTap: () => _showStudyPlanDialog(),
            ),
            _buildActionCard(
              theme,
              icon: Icons.psychology,
              title: 'Mnemonics',
              subtitle: 'Memory aids',
              onTap: () => _showMnemonicDialog(),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionCard(
    ThemeData theme, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: theme.colorScheme.primary, size: 32),
              const SizedBox(height: 8),
              Text(title, style: theme.textTheme.titleSmall),
              Text(subtitle, style: theme.textTheme.bodySmall),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFlashcardsTab(ThemeData theme) {
    if (_currentDeck == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.style_outlined,
              size: 64,
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'No flashcards yet',
              style: theme.textTheme.bodyLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Go to Home tab and generate flashcards',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      );
    }

    if (_currentDeck!.cards.isEmpty) {
      return const Center(child: Text('No cards in deck'));
    }

    final card = _currentDeck!.cards[_currentCardIndex];

    return Column(
      children: [
        // Progress
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Text(
                '${_currentCardIndex + 1} / ${_currentDeck!.cards.length}',
                style: theme.textTheme.titleMedium,
              ),
              const Spacer(),
              Text(
                'Due: ${_currentDeck!.getDueCards().length}',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
        LinearProgressIndicator(
          value: (_currentCardIndex + 1) / _currentDeck!.cards.length,
        ),
        const SizedBox(height: 24),

        // Card
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: GestureDetector(
              onTap: () => setState(() => _showAnswer = !_showAnswer),
              child: Card(
                elevation: 4,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _showAnswer ? 'Answer' : 'Question',
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _showAnswer ? card.back : card.front,
                        style: theme.textTheme.headlineSmall,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      if (!_showAnswer)
                        Text(
                          'Tap to reveal answer',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ).animate().fadeIn(duration: 300.ms),

        // Rating buttons
        if (_showAnswer)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: _buildRatingButton(
                    theme,
                    ReviewRating.again,
                    Colors.red,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildRatingButton(
                    theme,
                    ReviewRating.hard,
                    Colors.orange,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildRatingButton(
                    theme,
                    ReviewRating.good,
                    Colors.green,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildRatingButton(
                    theme,
                    ReviewRating.easy,
                    Colors.blue,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildRatingButton(
    ThemeData theme,
    ReviewRating rating,
    Color color,
  ) {
    return FilledButton(
      onPressed: () => _reviewCard(rating),
      style: FilledButton.styleFrom(
        backgroundColor: color.withValues(alpha: 0.8),
        padding: const EdgeInsets.symmetric(vertical: 16),
      ),
      child: Column(
        children: [
          Text(rating.emoji, style: const TextStyle(fontSize: 24)),
          Text(rating.label),
        ],
      ),
    );
  }

  Widget _buildQuizTab(ThemeData theme) {
    if (_currentQuiz == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.quiz_outlined,
              size: 64,
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text('No quiz yet', style: theme.textTheme.bodyLarge),
            const SizedBox(height: 8),
            Text(
              'Generate a quiz from the Home tab',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      );
    }

    if (_currentQuiz!.isCompleted) {
      return _buildQuizResults(theme);
    }

    if (_currentQuiz!.questions.isEmpty) {
      return const Center(child: Text('No questions in quiz'));
    }

    final question = _currentQuiz!.questions[_currentQuestionIndex];

    return Column(
      children: [
        // Progress
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Text(
                'Question ${_currentQuestionIndex + 1} of ${_currentQuiz!.questions.length}',
                style: theme.textTheme.titleMedium,
              ),
              const Spacer(),
              Text(
                'Score: ${_currentQuiz!.score}',
                style: theme.textTheme.bodyMedium,
              ),
            ],
          ),
        ),
        LinearProgressIndicator(
          value: (_currentQuestionIndex + 1) / _currentQuiz!.questions.length,
        ),

        // Question
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Chip(
                        label: Text(_getQuestionTypeLabel(question.type)),
                        backgroundColor: theme.colorScheme.secondaryContainer,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        question.question,
                        style: theme.textTheme.titleMedium,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Options
              if (question.options != null)
                ...question.options!.map((option) => _buildOptionTile(
                      theme,
                      option,
                      question.correctAnswer,
                    )),

              // Text input for short answer
              if (question.type == QuestionType.shortAnswer ||
                  question.type == QuestionType.fillBlank)
                TextField(
                  decoration: InputDecoration(
                    hintText: 'Your answer...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onSubmitted: (value) {
                    _currentQuiz!.submitAnswer(question.id, value);
                    _nextQuestion();
                  },
                ),
            ],
          ),
        ),

        // Navigation
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              if (_currentQuestionIndex > 0)
                OutlinedButton(
                  onPressed: () {
                    setState(() => _currentQuestionIndex--);
                  },
                  child: const Text('Previous'),
                ),
              const Spacer(),
              FilledButton(
                onPressed: () {
                  if (_selectedAnswer != null) {
                    _currentQuiz!.submitAnswer(question.id, _selectedAnswer!);
                  }
                  _nextQuestion();
                },
                child: Text(
                  _currentQuestionIndex == _currentQuiz!.questions.length - 1
                      ? 'Finish'
                      : 'Next',
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildOptionTile(
    ThemeData theme,
    String option,
    String correctAnswer,
  ) {
    final isSelected = _selectedAnswer == option;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: isSelected ? theme.colorScheme.primaryContainer : null,
      child: ListTile(
        title: Text(option),
        leading: Icon(
          isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
          color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurface.withValues(alpha: 0.5),
        ),
        onTap: () {
          setState(() => _selectedAnswer = option);
        },
      ),
    );
  }

  Widget _buildQuizResults(ThemeData theme) {
    final quiz = _currentQuiz!;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              quiz.percentage >= 70 ? '🎉' : '📚',
              style: const TextStyle(fontSize: 64),
            ),
            const SizedBox(height: 16),
            Text(
              'Quiz Complete!',
              style: theme.textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'Score: ${quiz.score} / ${quiz.totalPoints} (${quiz.percentage.toStringAsFixed(0)}%)',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Grade: ${quiz.grade}',
              style: theme.textTheme.titleLarge?.copyWith(
                color: quiz.percentage >= 70 ? Colors.green : Colors.orange,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: () {
                setState(() {
                  _currentQuiz = null;
                  _currentQuestionIndex = 0;
                });
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Take Another Quiz'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPomodoroTab(ThemeData theme) {
    final minutes = _pomodoro.remaining.inMinutes;
    final seconds = _pomodoro.remaining.inSeconds % 60;
    final isRunning = _pomodoro.state == PomodoroState.focus ||
        _pomodoro.state == PomodoroState.shortBreak ||
        _pomodoro.state == PomodoroState.longBreak;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // State indicator
          Text(
            _getPomodoroStateLabel(),
            style: theme.textTheme.titleLarge?.copyWith(
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 32),

          // Timer display
          Container(
            width: 250,
            height: 250,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: theme.colorScheme.primary,
                width: 8,
              ),
            ),
            child: Center(
              child: Text(
                '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}',
                style: theme.textTheme.displayLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ).animate(onPlay: (controller) => controller.repeat()).rotate(
                duration: 60.seconds,
                begin: 0,
                end: 0.01,
              ),
          const SizedBox(height: 48),

          // Controls
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (!isRunning && _pomodoro.state != PomodoroState.paused)
                FilledButton.icon(
                  onPressed: _startPomodoro,
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Start Focus'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 16,
                    ),
                  ),
                ),
              if (isRunning)
                FilledButton.icon(
                  onPressed: _pausePomodoro,
                  icon: const Icon(Icons.pause),
                  label: const Text('Pause'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 16,
                    ),
                  ),
                ),
              if (_pomodoro.state == PomodoroState.paused)
                FilledButton.icon(
                  onPressed: _resumePomodoro,
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Resume'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 16,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 24),

          // Stats
          Text(
            'Completed Sessions: ${_pomodoro.completedSessions}',
            style: theme.textTheme.bodyLarge,
          ),
          const SizedBox(height: 8),
          Text(
            'Focus: ${_pomodoro.focusMinutes}min • Break: ${_pomodoro.shortBreakMinutes}min',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  String _getPomodoroStateLabel() {
    switch (_pomodoro.state) {
      case PomodoroState.idle:
        return 'Ready to Focus?';
      case PomodoroState.focus:
        return '🎯 Focus Time';
      case PomodoroState.shortBreak:
        return '☕ Short Break';
      case PomodoroState.longBreak:
        return '🌴 Long Break';
      case PomodoroState.paused:
        return '⏸️ Paused';
    }
  }

  String _getQuestionTypeLabel(QuestionType type) {
    switch (type) {
      case QuestionType.multipleChoice:
        return 'Multiple Choice';
      case QuestionType.trueFalse:
        return 'True/False';
      case QuestionType.shortAnswer:
        return 'Short Answer';
      case QuestionType.essay:
        return 'Essay';
      case QuestionType.fillBlank:
        return 'Fill in the Blank';
    }
  }

  void _nextQuestion() {
    setState(() {
      _selectedAnswer = null;
      if (_currentQuestionIndex < _currentQuiz!.questions.length - 1) {
        _currentQuestionIndex++;
      } else {
        _currentQuiz!.complete();
      }
    });
  }

  void _showSummarizeDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Summarize Text'),
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: TextField(
            controller: controller,
            maxLines: null,
            decoration: const InputDecoration(
              hintText: 'Paste text to summarize...',
              border: OutlineInputBorder(),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              if (controller.text.isNotEmpty) {
                final summary = await _studyAssistant.summarizeText(
                  text: controller.text,
                );
                if (mounted) {
                  _showResultDialog('Summary', summary);
                }
              }
            },
            child: const Text('Summarize'),
          ),
        ],
      ),
    );
  }

  void _showExplainDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Explain a Concept'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'What concept do you want explained?',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              if (controller.text.isNotEmpty) {
                final explanation = await _studyAssistant.explainConcept(
                  concept: controller.text,
                );
                if (mounted) {
                  _showResultDialog('Explanation', explanation);
                }
              }
            },
            child: const Text('Explain'),
          ),
        ],
      ),
    );
  }

  void _showStudyPlanDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Generate Study Plan'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'Subject (e.g., "Biology Final Exam")',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              if (controller.text.isNotEmpty) {
                final plan = await _studyAssistant.generateStudyPlan(
                  subject: controller.text,
                  topics: [controller.text],
                  days: 7,
                );
                if (mounted) {
                  _showResultDialog('Study Plan', plan);
                }
              }
            },
            child: const Text('Generate'),
          ),
        ],
      ),
    );
  }

  void _showMnemonicDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Create Mnemonic'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'Items to remember (comma-separated)',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              if (controller.text.isNotEmpty) {
                final mnemonic = await _studyAssistant.createMnemonic(
                  items: controller.text,
                );
                if (mounted) {
                  _showResultDialog('Mnemonic', mnemonic);
                }
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  void _showResultDialog(String title, String content) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(
          child: SelectableText(content),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _topicController.dispose();
    _pomodoroTimer?.cancel();
    super.dispose();
  }
}
