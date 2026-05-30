import 'card.dart';

enum MeldType { ju, kan, zhao, dui, kao }

class Meld {
  final List<Card> cards;
  final MeldType type;
  final bool isJing;

  Meld({
    required this.cards,
    required this.type,
    required this.isJing,
  });

  int getHuCount({bool isHand = true, bool isPao = false}) {
    switch (type) {
      case MeldType.ju:
        return isJing ? 4 : 0;
      case MeldType.kan:
        if (isJing) return 12;
        if (isPao) return 2;
        return isHand ? 3 : 2;
      case MeldType.zhao:
        return isJing ? 16 : 6;
      case MeldType.dui:
        return isJing ? 8 : 0;
      case MeldType.kao:
        return isJing ? 4 : 0;
    }
  }

  @override
  String toString() => 'Meld(${type.name}, isJing=$isJing, cards=$cards)';
}
