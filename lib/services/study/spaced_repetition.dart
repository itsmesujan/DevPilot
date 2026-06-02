import '../../models/study_models.dart';

/// SM-2 Spaced Repetition Algorithm Implementation
/// Based on the SuperMemo SM-2 algorithm
/// https://www.supermemo.com/en/archives1990-2015/english/ol/sm2
class SpacedRepetition {
  SpacedRepetition._();
  static final SpacedRepetition instance = SpacedRepetition._();

  // Configuration
  static const int _learningStepsMinutes = 1; // First learning step
  static const int _graduatingIntervalDays = 1; // Interval after passing learning
  static const int _easyIntervalDays = 4; // Interval for "easy" rating
  static const double _startingEase = 2.5;
  static const double _minimumEase = 1.3;
  static const int _lapseThreshold = 3; // Lapses before card becomes leech

  /// Process a review and update the card's scheduling
  void reviewCard(Flashcard card, ReviewRating rating) {
    card.reviews++;

    switch (card.state) {
      case CardState.newCard:
      case CardState.learning:
        _reviewLearningCard(card, rating);
        break;
      case CardState.review:
      case CardState.mature:
        _reviewReviewCard(card, rating);
        break;
      case CardState.suspended:
        // Don't process suspended cards
        break;
    }
  }

  /// Review a card in learning state
  void _reviewLearningCard(Flashcard card, ReviewRating rating) {
    switch (rating) {
      case ReviewRating.again:
        // Failed - reset learning steps
        card.interval = 0;
        card.dueDate = DateTime.now().add(const Duration(minutes: _learningStepsMinutes));
        card.state = CardState.learning;
        card.lapses++;
        break;

      case ReviewRating.hard:
        // Hard - repeat learning step
        card.interval = 0;
        card.dueDate = DateTime.now().add(const Duration(minutes: _learningStepsMinutes * 2));
        card.state = CardState.learning;
        break;

      case ReviewRating.good:
        // Good - graduate to review
        card.interval = _graduatingIntervalDays;
        card.dueDate = DateTime.now().add(Duration(days: card.interval));
        card.state = CardState.review;
        card.easeFactor = _startingEase;
        break;

      case ReviewRating.easy:
        // Easy - skip to longer interval
        card.interval = _easyIntervalDays;
        card.dueDate = DateTime.now().add(Duration(days: card.interval));
        card.state = CardState.review;
        card.easeFactor = _startingEase + 0.2;
        break;
    }
  }

  /// Review a card in review state
  void _reviewReviewCard(Flashcard card, ReviewRating rating) {
    switch (rating) {
      case ReviewRating.again:
        // Failed - relearn
        card.lapses++;
        card.interval = 1;
        card.dueDate = DateTime.now().add(const Duration(minutes: 10));
        card.state = CardState.learning;
        // Reduce ease factor
        card.easeFactor = (card.easeFactor - 0.2).clamp(_minimumEase, 3.0);
        
        // Check for leech (too many lapses)
        if (card.lapses >= _lapseThreshold) {
          card.state = CardState.suspended;
        }
        break;

      case ReviewRating.hard:
        // Hard - shorter interval, reduce ease
        card.interval = (card.interval * 1.2).round().clamp(1, 365);
        card.dueDate = DateTime.now().add(Duration(days: card.interval));
        card.easeFactor = (card.easeFactor - 0.15).clamp(_minimumEase, 3.0);
        break;

      case ReviewRating.good:
        // Good - normal interval
        card.interval = (card.interval * card.easeFactor).round().clamp(1, 365);
        card.dueDate = DateTime.now().add(Duration(days: card.interval));
        
        // Check if card is mature (interval >= 21 days)
        if (card.interval >= 21) {
          card.state = CardState.mature;
        }
        break;

      case ReviewRating.easy:
        // Easy - longer interval, increase ease
        card.interval = (card.interval * card.easeFactor * 1.3).round().clamp(1, 365);
        card.dueDate = DateTime.now().add(Duration(days: card.interval));
        card.easeFactor = (card.easeFactor + 0.15).clamp(_minimumEase, 3.0);
        
        if (card.interval >= 21) {
          card.state = CardState.mature;
        }
        break;
    }
  }

  /// Calculate next intervals for all rating options
  Map<ReviewRating, ReviewPreview> getPreview(Flashcard card) {
    final previews = <ReviewRating, ReviewPreview>{};
    
    for (final rating in ReviewRating.values) {
      final testCard = Flashcard(
        front: card.front,
        back: card.back,
        easeFactor: card.easeFactor,
        interval: card.interval,
        reviews: card.reviews,
        lapses: card.lapses,
        dueDate: card.dueDate,
        state: card.state,
      );
      
      reviewCard(testCard, rating);
      
      previews[rating] = ReviewPreview(
        interval: testCard.interval,
        dueDate: testCard.dueDate,
        state: testCard.state,
        easeFactor: testCard.easeFactor,
      );
    }
    
    return previews;
  }

  /// Get optimal cards to study right now
  List<Flashcard> getStudyQueue(FlashcardDeck deck, {int maxCards = 20}) {
    final queue = <Flashcard>[];
    
    // First: due cards (highest priority)
    final due = deck.getDueCards();
    queue.addAll(due.take(maxCards));
    
    // Second: new cards (if room left)
    if (queue.length < maxCards) {
      final newCards = deck.getNewCards();
      final remaining = maxCards - queue.length;
      queue.addAll(newCards.take(remaining));
    }
    
    return queue;
  }

  /// Estimate time to complete study session
  Duration estimateStudyTime(List<Flashcard> cards) {
    // Average: 10 seconds per card
    return Duration(seconds: cards.length * 10);
  }

  /// Calculate retention rate for a deck
  double calculateRetentionRate(FlashcardDeck deck) {
    if (deck.totalReviews == 0) return 0;
    
    final mature = deck.cards.where((c) => c.state == CardState.mature).length;
    final total = deck.cards.length;
    
    return total > 0 ? mature / total : 0;
  }

  /// Predict when all cards will be mature
  DateTime? predictCompletion(FlashcardDeck deck) {
    if (deck.cards.isEmpty) return null;
    
    final nonMature = deck.cards.where((c) => c.state != CardState.mature).toList();
    if (nonMature.isEmpty) return DateTime.now();
    
    // Find the latest due date among non-mature cards
    final latestDue = nonMature
        .map((c) => c.dueDate)
        .reduce((a, b) => a.isAfter(b) ? a : b);
    
    // Add estimated time for remaining reviews
    final estimatedDays = nonMature.length ~/ 10; // ~10 cards mature per day
    return latestDue.add(Duration(days: estimatedDays));
  }
}

class ReviewPreview {
  final int interval;
  final DateTime dueDate;
  final CardState state;
  final double easeFactor;

  ReviewPreview({
    required this.interval,
    required this.dueDate,
    required this.state,
    required this.easeFactor,
  });

  String get intervalText {
    if (interval == 0) return '< 1 day';
    if (interval == 1) return '1 day';
    if (interval < 30) return '$interval days';
    if (interval < 365) return '${interval ~/ 30} months';
    return '${interval ~/ 365} years';
  }
}