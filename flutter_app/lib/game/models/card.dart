import 'dart:math';

class Card {
  final int id;
  final String character;
  final int sentence;
  final int position;

  Card({
    required this.id,
    required this.character,
    required this.sentence,
    required this.position,
  });

  bool get isJing => character == '上' || character == '福';

  static List<Card> createDeck() {
    const characters = [
      ['上', '大', '人'],
      ['丘', '乙', '己'],
      ['化', '三', '千'],
      ['七', '十', '土'],
      ['尔', '小', '生'],
      ['八', '九', '子'],
      ['佳', '作', '亡'],
      ['福', '禄', '寿'],
    ];

    final deck = <Card>[];
    var id = 0;

    for (var s = 0; s < characters.length; s++) {
      for (var p = 0; p < characters[s].length; p++) {
        for (var c = 0; c < 4; c++) {
          deck.add(Card(
            id: id++,
            character: characters[s][p],
            sentence: s + 1,
            position: p,
          ));
        }
      }
    }

    deck.shuffle(Random());
    return deck;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Card && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Card($character, s=$sentence, p=$position)';
}
