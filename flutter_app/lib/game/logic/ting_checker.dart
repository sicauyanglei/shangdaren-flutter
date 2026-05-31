import '../models/card.dart';
import '../models/meld.dart';
import '../models/player.dart';
import 'hu_calculator.dart';

class TingResult {
  final bool isTing;
  final List<Card> tingCards;
  TingResult({required this.isTing, required this.tingCards});
}

class TingChecker {
  static TingResult checkTing(Player player) {
    final hand = List<Card>.from(player.hand);
    final melds = player.melds;

    final basicResult = _checkBasicTing(hand);
    if (!basicResult.met) return TingResult(isTing: false, tingCards: []);

    final tingCards = _checkHuTypeTing(hand, melds, basicResult);
    return TingResult(isTing: tingCards.isNotEmpty, tingCards: tingCards);
  }

  static _BasicTingResult _checkBasicTing(List<Card> hand) {
    final pairCount = _countPairs(hand);
    if (pairCount >= 9) {
      return _BasicTingResult(
        met: true,
        type: _BasicTingType.ninePairs,
        dSet: [],
        eSet: [],
      );
    }

    final remaining = List<Card>.from(hand);
    final aSet = <Meld>[];
    final bSet = <Meld>[];
    final cSet = <Meld>[];
    final dSet = <Card>[];

    HuCalculator.extractJu(remaining, aSet);
    HuCalculator.extractKan(remaining, bSet);
    HuCalculator.extractDuiAndKao(remaining, cSet);
    dSet.addAll(remaining);

    if (cSet.isEmpty && dSet.length == 1) {
      return _BasicTingResult(
        met: true,
        type: _BasicTingType.singleWait,
        dSet: cSet,
        eSet: dSet,
      );
    }
    if (cSet.length == 2 && dSet.isEmpty) {
      return _BasicTingResult(
        met: true,
        type: _BasicTingType.pairWait,
        dSet: cSet,
        eSet: dSet,
      );
    }

    return _BasicTingResult(
      met: false,
      type: _BasicTingType.none,
      dSet: cSet,
      eSet: dSet,
    );
  }

  static List<Card> _checkHuTypeTing(
    List<Card> hand,
    List<Meld> melds,
    _BasicTingResult basic,
  ) {
    final tingCards = <Card>[];

    switch (basic.type) {
      case _BasicTingType.ninePairs:
        _findTingCardsForNinePairs(hand, melds, tingCards);
        break;
      case _BasicTingType.singleWait:
        _findTingCardsForSingleWait(hand, melds, basic.eSet, tingCards);
        break;
      case _BasicTingType.pairWait:
        _findTingCardsForPairWait(hand, melds, basic.dSet, tingCards);
        break;
      case _BasicTingType.none:
        break;
    }

    return tingCards;
  }

  static int _countPairs(List<Card> hand) {
    final byChar = <String, int>{};
    for (final card in hand) {
      byChar[card.character] = (byChar[card.character] ?? 0) + 1;
    }
    int pairs = 0;
    for (final count in byChar.values) {
      pairs += count ~/ 2;
    }
    return pairs;
  }

  static void _findTingCardsForNinePairs(
    List<Card> hand,
    List<Meld> melds,
    List<Card> tingCards,
  ) {
    final allChars = [
      '上',
      '大',
      '人',
      '丘',
      '乙',
      '己',
      '化',
      '三',
      '千',
      '七',
      '十',
      '土',
      '尔',
      '小',
      '生',
      '八',
      '九',
      '子',
      '佳',
      '作',
      '亡',
      '福',
      '禄',
      '寿',
    ];
    final byChar = <String, int>{};
    for (final card in hand) {
      byChar[card.character] = (byChar[card.character] ?? 0) + 1;
    }

    for (final ch in allChars) {
      final count = byChar[ch] ?? 0;
      if (count == 1 || count == 3) {
        final sentence = _charToSentence(ch);
        final position = _charToPosition(ch);
        if (sentence > 0) {
          final testCard = Card(
            id: -1,
            character: ch,
            sentence: sentence,
            position: position,
          );
          final testHand = List<Card>.from(hand);
          testHand.add(testCard);
          if (_canHu(testHand, melds)) {
            tingCards.add(testCard);
          }
        }
      }
    }
  }

  static void _findTingCardsForSingleWait(
    List<Card> hand,
    List<Meld> melds,
    List<Card> eSet,
    List<Card> tingCards,
  ) {
    if (eSet.isEmpty) return;
    final singleCard = eSet.first;

    final testHand = List<Card>.from(hand);
    final pairCard = Card(
      id: -1,
      character: singleCard.character,
      sentence: singleCard.sentence,
      position: singleCard.position,
    );
    testHand.add(pairCard);
    if (_canHu(testHand, melds)) {
      tingCards.add(pairCard);
    }

    final kaoChars = _getKaoPartners(singleCard);
    for (final ch in kaoChars) {
      final sentence = _charToSentence(ch);
      final position = _charToPosition(ch);
      if (sentence > 0) {
        final kaoCard = Card(
          id: -2,
          character: ch,
          sentence: sentence,
          position: position,
        );
        final testHand2 = List<Card>.from(hand);
        testHand2.add(kaoCard);
        if (_canHu(testHand2, melds)) {
          tingCards.add(kaoCard);
        }
      }
    }
  }

  static void _findTingCardsForPairWait(
    List<Card> hand,
    List<Meld> melds,
    List<Meld> dSet,
    List<Card> tingCards,
  ) {
    final groupSet = <int>{};
    for (final meld in dSet) {
      groupSet.add(meld.cards.first.sentence);
    }

    for (final sentence in groupSet) {
      final sentenceChars = _charToSentenceChars(sentence);
      for (final ch in sentenceChars) {
        final sentence = _charToSentence(ch);
        final position = _charToPosition(ch);
        if (sentence > 0) {
          final testCard = Card(
            id: -10,
            character: ch,
            sentence: sentence,
            position: position,
          );
          final testHand = List<Card>.from(hand);
          testHand.add(testCard);
          if (_canHu(testHand, melds)) {
            if (!tingCards.any((t) => t.character == ch)) {
              tingCards.add(testCard);
            }
          }
        }
      }
    }
  }

  static List<String> _charToSentenceChars(int sentence) {
    const sentences = [
      ['上', '大', '人'],
      ['丘', '乙', '己'],
      ['化', '三', '千'],
      ['七', '十', '土'],
      ['尔', '小', '生'],
      ['八', '九', '子'],
      ['佳', '作', '亡'],
      ['福', '禄', '寿'],
    ];
    if (sentence < 1 || sentence > 8) return [];
    return sentences[sentence - 1];
  }

  static bool _canHu(List<Card> hand, List<Meld> melds) {
    final remaining = List<Card>.from(hand);
    final aSet = <Meld>[];
    final bSet = <Meld>[];
    final cSet = <Meld>[];
    final dSet = <Card>[];

    HuCalculator.extractJu(remaining, aSet);
    HuCalculator.extractKan(remaining, bSet);
    HuCalculator.extractDuiAndKao(remaining, cSet);
    dSet.addAll(remaining);

    bool structuralOk = false;
    if (cSet.length == 1 && dSet.isEmpty) structuralOk = true;

    final pairCount = _countPairs(hand);
    if (pairCount >= 10) structuralOk = true;

    if (!structuralOk) return false;

    return HuCalculator.canHu(hand, melds);
  }

  static List<String> _getKaoPartners(Card card) {
    const sentences = [
      ['上', '大', '人'],
      ['丘', '乙', '己'],
      ['化', '三', '千'],
      ['七', '十', '土'],
      ['尔', '小', '生'],
      ['八', '九', '子'],
      ['佳', '作', '亡'],
      ['福', '禄', '寿'],
    ];
    if (card.sentence < 1 || card.sentence > 8) return [];
    return sentences[card.sentence - 1]
        .where((ch) => ch != card.character)
        .toList();
  }

  static int _charToSentence(String ch) {
    const map = {
      '上': 1,
      '大': 1,
      '人': 1,
      '丘': 2,
      '乙': 2,
      '己': 2,
      '化': 3,
      '三': 3,
      '千': 3,
      '七': 4,
      '十': 4,
      '土': 4,
      '尔': 5,
      '小': 5,
      '生': 5,
      '八': 6,
      '九': 6,
      '子': 6,
      '佳': 7,
      '作': 7,
      '亡': 7,
      '福': 8,
      '禄': 8,
      '寿': 8,
    };
    return map[ch] ?? 0;
  }

  static int _charToPosition(String ch) {
    const map = {
      '上': 0,
      '大': 1,
      '人': 2,
      '丘': 0,
      '乙': 1,
      '己': 2,
      '化': 0,
      '三': 1,
      '千': 2,
      '七': 0,
      '十': 1,
      '土': 2,
      '尔': 0,
      '小': 1,
      '生': 2,
      '八': 0,
      '九': 1,
      '子': 2,
      '佳': 0,
      '作': 1,
      '亡': 2,
      '福': 0,
      '禄': 1,
      '寿': 2,
    };
    return map[ch] ?? -1;
  }
}

enum _BasicTingType { none, ninePairs, singleWait, pairWait }

class _BasicTingResult {
  final bool met;
  final _BasicTingType type;
  final List<Meld> dSet;
  final List<Card> eSet;
  _BasicTingResult({
    required this.met,
    required this.type,
    required this.dSet,
    required this.eSet,
  });
}
