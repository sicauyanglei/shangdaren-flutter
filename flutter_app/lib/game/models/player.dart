import 'card.dart';
import 'meld.dart';

enum PlayerType { human, ai }

class Player {
  final int id;
  final String name;
  final PlayerType type;
  final List<Card> hand;
  final List<Meld> melds;
  final List<Card> discards;
  int score;
  int piao;
  bool isTing;
  List<Card> tingCards;
  int huCount;

  Player({
    required this.id,
    required this.name,
    required this.type,
    List<Card>? hand,
    List<Meld>? melds,
    List<Card>? discards,
    this.score = 0,
    this.piao = 0,
    this.isTing = false,
    List<Card>? tingCards,
    this.huCount = 0,
  }) : hand = hand ?? [],
       melds = melds ?? [],
       discards = discards ?? [],
       tingCards = tingCards ?? [];

  void sortHand() {
    hand.sort((a, b) {
      if (a.sentence != b.sentence) return a.sentence.compareTo(b.sentence);
      return a.position.compareTo(b.position);
    });
  }

  void removeCard(Card card) {
    hand.remove(card);
  }

  void addCard(Card card) {
    hand.add(card);
    sortHand();
  }

  @override
  String toString() =>
      'Player($name, hand=${hand.length}, melds=${melds.length})';
}
