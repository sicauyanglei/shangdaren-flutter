import 'card.dart';
import 'meld.dart';
import '../logic/ting_checker.dart';

enum PlayerType { human, ai }

enum Gender { male, female }

class Player {
  final int id;
  final String name;
  final PlayerType type;
  Gender gender;
  final List<Card> hand;
  final List<Meld> melds;
  final List<Card> discards;
  int score;
  int piao;
  bool isTing;
  List<Card> tingCards;
  TingType tingType;
  int huCount;
  int meldHuCount;

  Player({
    required this.id,
    required this.name,
    required this.type,
    this.gender = Gender.male,
    List<Card>? hand,
    List<Meld>? melds,
    List<Card>? discards,
    this.score = 0,
    this.piao = 0,
    this.isTing = false,
    List<Card>? tingCards,
    this.tingType = TingType.none,
    this.huCount = 0,
    this.meldHuCount = 0,
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
