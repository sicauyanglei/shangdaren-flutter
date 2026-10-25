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

  /// 24 个字的门-位置表（sentence 1-8，position 0-2）
  static const List<List<String>> allCharacters = [
    ['上', '大', '人'],
    ['丘', '乙', '己'],
    ['化', '三', '千'],
    ['七', '十', '土'],
    ['尔', '小', '生'],
    ['八', '九', '子'],
    ['佳', '作', '亡'],
    ['福', '禄', '寿'],
  ];

  /// 按字面与副本序号（0-3）重建牌，id 与 createDeck 的编号方案一致。
  /// 联机模式服务器只下发字面，客户端用它重建牌对象。
  static Card buildFromCharacter(String character, {int copy = 0}) {
    for (var s = 0; s < allCharacters.length; s++) {
      for (var p = 0; p < allCharacters[s].length; p++) {
        if (allCharacters[s][p] == character) {
          return Card(
            id: (s * 3 + p) * 4 + (copy % 4),
            character: character,
            sentence: s + 1,
            position: p,
          );
        }
      }
    }
    throw ArgumentError('未知字面: $character');
  }

  static List<Card> createDeck() {
    final deck = <Card>[];
    var id = 0;

    for (var s = 0; s < allCharacters.length; s++) {
      for (var p = 0; p < allCharacters[s].length; p++) {
        for (var c = 0; c < 4; c++) {
          deck.add(Card(
            id: id++,
            character: allCharacters[s][p],
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
