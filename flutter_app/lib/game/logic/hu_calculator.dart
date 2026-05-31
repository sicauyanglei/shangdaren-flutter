import '../models/card.dart';
import '../models/meld.dart';
import '../models/player.dart';

class HuCalculator {
  static const _yinChars = ['大', '人', '禄', '寿'];

  static bool isYinChar(String ch) => _yinChars.contains(ch);

  static bool canHu(List<Card> hand, List<Meld> melds) {
    if (!_checkStructural(hand)) return false;

    final meldHu = calculateMeldHu(melds);
    final handHu = calculateHandHu(hand, melds);
    final totalHu = meldHu + handHu;

    if (totalHu >= 11) return true;

    final hasZhao = melds.any((m) => m.type == MeldType.zhao);
    final effectiveHasZhao = hasZhao && !_isZhaoUsedInSentence(hand, melds);

    if (_checkShiDui(hand, melds)) return true;
    if (_checkHeiYuan(hand, melds, effectiveHasZhao)) return true;
    if (_checkHongYuan(hand, melds, effectiveHasZhao) > 0) return true;
    if (_checkKuHu(hand, melds, effectiveHasZhao)) return true;
    if (_checkQingKuHu(hand, melds, effectiveHasZhao)) return true;
    if (_checkQingKuChongTai(hand, melds) != null) return true;

    return false;
  }

  static bool _checkStructural(List<Card> hand) {
    final remaining = List<Card>.from(hand);
    final aSet = <Meld>[];
    final bSet = <Meld>[];
    final cSet = <Meld>[];
    final dSet = <Card>[];

    extractJu(remaining, aSet);
    extractKan(remaining, bSet);
    extractDuiAndKao(remaining, cSet);
    dSet.addAll(remaining);

    if (cSet.length == 1 && dSet.isEmpty) return true;

    final byChar = <String, int>{};
    for (final card in hand) {
      byChar[card.character] = (byChar[card.character] ?? 0) + 1;
    }
    int pairCount = 0;
    for (final count in byChar.values) {
      pairCount += count ~/ 2;
    }
    if (pairCount >= 10) return true;

    return false;
  }

  static int calculateTotalHu(Player player, {bool isPao = false}) {
    final meldHu = calculateMeldHu(player.melds, isPao: isPao);
    final handHu = calculateHandHu(player.hand, player.melds);
    return meldHu + handHu;
  }

  static int calculateMeldHu(List<Meld> melds, {bool isPao = false}) {
    int total = 0;
    for (final meld in melds) {
      total += meld.getHuCount(isHand: false, isPao: isPao);
    }
    return total;
  }

  static int calculateHandHu(List<Card> hand, List<Meld> melds) {
    if (hand.isEmpty) return 0;

    final remaining = List<Card>.from(hand);
    final aSet = <Meld>[];
    final bSet = <Meld>[];
    final cSet = <Meld>[];
    final dSet = <Meld>[];
    final eSet = <Card>[];

    extractJu(remaining, aSet);
    extractZhao(remaining, bSet);
    extractKan(remaining, cSet);
    extractDuiAndKao(remaining, dSet);
    eSet.addAll(remaining);

    int hu = 0;
    for (final m in aSet) {
      hu += m.getHuCount(isHand: true);
    }
    for (final m in bSet) {
      hu += m.getHuCount(isHand: true);
    }
    for (final m in cSet) {
      hu += m.getHuCount(isHand: true);
    }
    for (final m in dSet) {
      hu += m.getHuCount(isHand: true);
    }
    for (final card in eSet) {
      hu += _singleHu(card);
    }

    hu += _calculateBonus(aSet, dSet, eSet);

    return hu;
  }

  static void extractJu(List<Card> remaining, List<Meld> out) {
    final bySentence = <int, List<Card>>{};
    for (final card in remaining) {
      bySentence.putIfAbsent(card.sentence, () => []).add(card);
    }

    for (var s = 1; s <= 8; s++) {
      final cards = bySentence[s];
      if (cards == null) continue;

      final byPos = <int, List<Card>>{};
      for (final c in cards) {
        byPos.putIfAbsent(c.position, () => []).add(c);
      }

      final positions = byPos.keys.toList()..sort();
      if (positions.length >= 3) {
        final juCards = <Card>[];
        for (final pos in positions) {
          if (byPos[pos]!.isNotEmpty) {
            juCards.add(byPos[pos]!.removeLast());
          }
        }
        if (juCards.length == 3) {
          final hasJing = juCards.any((c) => c.isJing);
          out.add(Meld(cards: juCards, type: MeldType.ju, isJing: hasJing));
          for (final c in juCards) {
            remaining.remove(c);
          }
          extractJu(remaining, out);
          return;
        } else {
          for (final c in juCards) {
            final posList = byPos[c.position];
            if (posList != null) posList.add(c);
          }
        }
      }
    }
  }

  static void extractZhao(List<Card> remaining, List<Meld> out) {
    final byChar = <String, List<Card>>{};
    for (final card in remaining) {
      byChar.putIfAbsent(card.character, () => []).add(card);
    }

    for (final entry in byChar.entries) {
      if (entry.value.length >= 4) {
        final zhaoCards = entry.value.sublist(0, 4);
        out.add(
          Meld(
            cards: zhaoCards,
            type: MeldType.zhao,
            isJing: zhaoCards.first.isJing,
          ),
        );
        for (final c in zhaoCards) {
          remaining.remove(c);
        }
        extractZhao(remaining, out);
        return;
      }
    }
  }

  static void extractKan(List<Card> remaining, List<Meld> out) {
    final byChar = <String, List<Card>>{};
    for (final card in remaining) {
      byChar.putIfAbsent(card.character, () => []).add(card);
    }

    for (final entry in byChar.entries) {
      if (entry.value.length >= 3) {
        final kanCards = entry.value.sublist(0, 3);
        out.add(
          Meld(
            cards: kanCards,
            type: MeldType.kan,
            isJing: kanCards.first.isJing,
          ),
        );
        for (final c in kanCards) {
          remaining.remove(c);
        }
        extractKan(remaining, out);
        return;
      }
    }
  }

  static void extractDuiAndKao(List<Card> remaining, List<Meld> out) {
    final byChar = <String, List<Card>>{};
    for (final card in remaining) {
      byChar.putIfAbsent(card.character, () => []).add(card);
    }

    for (final entry in byChar.entries) {
      if (entry.value.length >= 2) {
        final duiCards = entry.value.sublist(0, 2);
        out.add(
          Meld(
            cards: duiCards,
            type: MeldType.dui,
            isJing: duiCards.first.isJing,
          ),
        );
        for (final c in duiCards) {
          remaining.remove(c);
        }
        extractDuiAndKao(remaining, out);
        return;
      }
    }

    final bySentence = <int, List<Card>>{};
    for (final card in remaining) {
      bySentence.putIfAbsent(card.sentence, () => []).add(card);
    }

    for (var s = 1; s <= 8; s++) {
      final cards = bySentence[s];
      if (cards == null || cards.length < 2) continue;

      final byPos = <int, Card>{};
      for (final c in cards) {
        byPos[c.position] = c;
      }

      final positions = byPos.keys.toList()..sort();
      for (var i = 0; i < positions.length - 1; i++) {
        for (var j = i + 1; j < positions.length; j++) {
          final p1 = positions[i];
          final p2 = positions[j];
          if (p1 == p2) continue;
          final c1 = byPos[p1]!;
          final c2 = byPos[p2]!;
          final hasJing = c1.isJing || c2.isJing;
          out.add(Meld(cards: [c1, c2], type: MeldType.kao, isJing: hasJing));
          remaining.remove(c1);
          remaining.remove(c2);
          extractDuiAndKao(remaining, out);
          return;
        }
      }
    }
  }

  static int _singleHu(Card card) {
    if (card.isJing) return 4;
    if (isYinChar(card.character)) return 0;
    return 0;
  }

  static HuTypeResult detectHuType(Player player) {
    final hand = player.hand;
    final melds = player.melds;
    final huCount = calculateTotalHu(player);

    final hasChi = melds.any((m) => m.type == MeldType.ju);
    final hasPeng = melds.any((m) => m.type == MeldType.kan);
    final hasZhao = melds.any((m) => m.type == MeldType.zhao);
    final effectiveHasZhao = hasZhao && !_isZhaoUsedInSentence(hand, melds);

    final allCards = [...hand, ...melds.expand((m) => m.cards)];
    final shangCount = allCards.where((c) => c.character == '上').length;
    final fuCount = allCards.where((c) => c.character == '福').length;
    final hasShangFu = shangCount + fuCount > 0;

    final isKuHu = _checkKuHu(hand, melds, effectiveHasZhao);
    final isQingKuHu = _checkQingKuHu(hand, melds, effectiveHasZhao);
    final isShiDui = _checkShiDui(hand, melds);
    final isHeiYuan = _checkHeiYuan(hand, melds, effectiveHasZhao);
    final hongYuanJing = _checkHongYuan(hand, melds, effectiveHasZhao);
    final isQingHu = _checkQingHu(hand, melds, huCount);

    final qingKuChongTaiResult = _checkQingKuChongTai(hand, melds);

    if (qingKuChongTaiResult == 'qingKuChongTaiKa') {
      return HuTypeResult(
        type: 'qingKuChongTaiKa',
        name: '清枯重台卡',
        dianpao: 14,
        zimo: 15,
      );
    }
    if (qingKuChongTaiResult == 'qingKuChongTaiHu') {
      return HuTypeResult(
        type: 'qingKuChongTaiHu',
        name: '清枯重台胡',
        dianpao: 13,
        zimo: 14,
      );
    }
    if (isQingKuHu && huCount >= 23 && huCount <= 32) {
      return HuTypeResult(
        type: 'qingKuTaiHu',
        name: '清枯台胡',
        dianpao: 7,
        zimo: 8,
      );
    }
    if (isKuHu && huCount == 33) {
      return HuTypeResult(
        type: 'kuChongTaiKa',
        name: '枯重台卡',
        dianpao: 12,
        zimo: 13,
      );
    }
    if (isKuHu && huCount >= 34) {
      return HuTypeResult(
        type: 'kuChongTaiHu',
        name: '枯重台胡',
        dianpao: 11,
        zimo: 12,
      );
    }
    if (isKuHu && huCount >= 23 && huCount <= 32) {
      return HuTypeResult(type: 'kuTaiHu', name: '枯台胡', dianpao: 6, zimo: 7);
    }
    if (isQingKuHu && huCount == 22) {
      return HuTypeResult(
        type: 'qingKuTaiKa',
        name: '清枯台卡',
        dianpao: 8,
        zimo: 9,
      );
    }
    if (isQingKuHu) {
      return HuTypeResult(type: 'qingKuHu', name: '清枯胡', dianpao: 6, zimo: 7);
    }
    if (isKuHu) {
      return HuTypeResult(type: 'kuHu', name: '枯胡', dianpao: 5, zimo: 6);
    }
    if (isShiDui) {
      return HuTypeResult(type: 'shiDui', name: '十对', dianpao: 10, zimo: 11);
    }
    if (hongYuanJing > 0) {
      return HuTypeResult(
        type: 'hongYuan${hongYuanJing}Jing',
        name: '红元$hongYuanJing精',
        dianpao: hongYuanJing,
        zimo: hongYuanJing + 1,
      );
    }
    if (isHeiYuan) {
      return HuTypeResult(type: 'heiYuan', name: '黑元', dianpao: 4, zimo: 5);
    }

    final isQingHuCond = _checkQingHuConditions(hand, melds);
    if (isQingHuCond && huCount == 11) {
      return HuTypeResult(type: 'qingKaHu', name: '清卡胡', dianpao: 2, zimo: 3);
    }
    if (isQingHu) {
      return HuTypeResult(type: 'qingHu', name: '清胡', dianpao: 1, zimo: 2);
    }

    if (huCount < 11) {
      return HuTypeResult(type: 'none', name: '无', dianpao: 0, zimo: 0);
    }
    if (huCount == 11) {
      return HuTypeResult(type: 'kaHu', name: '卡胡', dianpao: 1, zimo: 2);
    }
    if (huCount >= 12 && huCount <= 21) {
      return HuTypeResult(type: 'puTongHu', name: '普通胡', dianpao: 0, zimo: 1);
    }
    if (huCount == 22) {
      return HuTypeResult(type: 'taiKa', name: '台卡', dianpao: 2, zimo: 3);
    }
    if (huCount >= 23 && huCount <= 32) {
      return HuTypeResult(type: 'taiHu', name: '台胡', dianpao: 1, zimo: 2);
    }
    if (huCount == 33) {
      return HuTypeResult(type: 'chongTaiKa', name: '重台卡', dianpao: 7, zimo: 8);
    }
    if (huCount >= 34) {
      return HuTypeResult(type: 'chongTaiHu', name: '重台胡', dianpao: 6, zimo: 7);
    }

    return HuTypeResult(type: 'none', name: '无', dianpao: 0, zimo: 0);
  }

  static bool _isZhaoUsedInSentence(List<Card> hand, List<Meld> melds) {
    final zhaoMelds = melds.where((m) => m.type == MeldType.zhao).toList();
    if (zhaoMelds.isEmpty) return false;

    final allCards = [...hand, ...melds.expand((m) => m.cards)];

    for (final zhaoMeld in zhaoMelds) {
      final zhaoSentence = zhaoMeld.cards.first.sentence;
      final sentenceCards = allCards.where((c) => c.sentence == zhaoSentence);
      final positions = sentenceCards.map((c) => c.position).toSet();
      if (positions.length == 3) return true;
    }
    return false;
  }

  static bool _checkKuHu(
    List<Card> hand,
    List<Meld> melds,
    bool effectiveHasZhao,
  ) {
    final hasChi = melds.any((m) => m.type == MeldType.ju);
    if (hasChi) return false;

    final allCards = [...hand, ...melds.expand((m) => m.cards)];
    if (!allCards.any((c) => c.character == '上' || c.character == '福')) {
      return false;
    }

    final counts = <String, int>{};
    for (final card in hand) {
      counts[card.character] = (counts[card.character] ?? 0) + 1;
    }

    for (final count in counts.values) {
      if (count == 1) return false;
      if (count >= 4) return false;
    }

    int kanCount = 0;
    int duiCount = 0;
    int zhaoCount = 0;

    for (final count in counts.values) {
      if (count == 3) {
        kanCount++;
      } else if (count == 2)
        duiCount++;
    }

    for (final meld in melds) {
      if (meld.type == MeldType.kan) {
        kanCount++;
      } else if (meld.type == MeldType.zhao)
        zhaoCount++;
    }

    return (kanCount + zhaoCount) == 6 && duiCount == 1;
  }

  static bool _checkQingKuHu(
    List<Card> hand,
    List<Meld> melds,
    bool effectiveHasZhao,
  ) {
    final hasChi = melds.any((m) => m.type == MeldType.ju);
    if (hasChi) return false;

    final allCards = [...hand, ...melds.expand((m) => m.cards)];
    if (allCards.any((c) => c.character == '上' || c.character == '福')) {
      return false;
    }

    final counts = <String, int>{};
    for (final card in hand) {
      counts[card.character] = (counts[card.character] ?? 0) + 1;
    }

    for (final count in counts.values) {
      if (count == 1) return false;
      if (count >= 4) return false;
    }

    int kanCount = 0;
    int duiCount = 0;
    int zhaoCount = 0;

    for (final count in counts.values) {
      if (count == 3) {
        kanCount++;
      } else if (count == 2)
        duiCount++;
    }

    for (final meld in melds) {
      if (meld.type == MeldType.kan) {
        kanCount++;
      } else if (meld.type == MeldType.zhao)
        zhaoCount++;
    }

    return (kanCount + zhaoCount) == 6 && duiCount == 1;
  }

  static bool _checkShiDui(List<Card> hand, List<Meld> melds) {
    final counts = <String, int>{};
    for (final card in hand) {
      counts[card.character] = (counts[card.character] ?? 0) + 1;
    }

    int duiCount = 0;
    for (final count in counts.values) {
      if (count == 2) {
        duiCount++;
      } else if (count == 4)
        duiCount += 2;
    }

    for (final meld in melds) {
      if (meld.type == MeldType.kan) {
        duiCount += 1;
      } else if (meld.type == MeldType.zhao)
        duiCount += 2;
    }

    return duiCount == 10;
  }

  static bool _checkHeiYuan(
    List<Card> hand,
    List<Meld> melds,
    bool effectiveHasZhao,
  ) {
    final hasPeng = melds.any((m) => m.type == MeldType.kan);
    final hasZhao = melds.any((m) => m.type == MeldType.zhao);

    if (hasPeng || (hasZhao && effectiveHasZhao)) return false;

    final allCards = [...hand, ...melds.expand((m) => m.cards)];
    if (allCards.any((c) => c.sentence == 1 || c.sentence == 8)) return false;
    if (allCards.any((c) => c.character == '上' || c.character == '福')) {
      return false;
    }

    return _checkSentencePattern(hand, melds);
  }

  static bool _checkSentencePattern(List<Card> hand, List<Meld> melds) {
    final cards = List<Card>.from(hand);
    final usedIds = <int>{};

    int meldSentenceCount = 0;
    for (final meld in melds) {
      if (meld.type == MeldType.ju) meldSentenceCount++;
    }

    final neededSentences = 6 - meldSentenceCount;

    bool foundGroup = true;
    while (foundGroup) {
      foundGroup = false;
      for (var s = 1; s <= 8; s++) {
        final sentenceCards = cards
            .where((c) => c.sentence == s && !usedIds.contains(c.id))
            .toList();
        final pos0 = sentenceCards.where((c) => c.position == 0).toList();
        final pos1 = sentenceCards.where((c) => c.position == 1).toList();
        final pos2 = sentenceCards.where((c) => c.position == 2).toList();

        if (pos0.isNotEmpty && pos1.isNotEmpty && pos2.isNotEmpty) {
          usedIds.add(pos0.first.id);
          usedIds.add(pos1.first.id);
          usedIds.add(pos2.first.id);
          foundGroup = true;
        }
      }
    }

    final remaining = cards.where((c) => !usedIds.contains(c.id)).toList();
    final handSentenceCount = (cards.length - remaining.length) ~/ 3;

    if (handSentenceCount == neededSentences && remaining.length == 2) {
      final c1 = remaining[0];
      final c2 = remaining[1];
      if (c1.sentence == c2.sentence && c1.position != c2.position) {
        return true;
      }
    }

    return false;
  }

  static int _checkHongYuan(
    List<Card> hand,
    List<Meld> melds,
    bool effectiveHasZhao,
  ) {
    final hasPeng = melds.any((m) => m.type == MeldType.kan);
    final hasZhao = melds.any((m) => m.type == MeldType.zhao);

    if (hasPeng || (hasZhao && effectiveHasZhao)) return 0;

    if (melds.isNotEmpty) {
      if (!melds.every((m) => m.type == MeldType.ju)) return 0;
    }

    int shangDaRenSentenceCount = 0;
    int fuLuShouSentenceCount = 0;
    int totalSentenceCount = 0;

    for (final meld in melds) {
      if (meld.type == MeldType.ju) {
        totalSentenceCount++;
        final sentence = meld.cards.first.sentence;
        if (sentence == 1) shangDaRenSentenceCount++;
        if (sentence == 8) fuLuShouSentenceCount++;
      }
    }

    final usedIds = <int>{};

    bool foundGroup = true;
    while (foundGroup) {
      foundGroup = false;
      for (var s = 1; s <= 8; s++) {
        final sentenceCards = hand
            .where((c) => c.sentence == s && !usedIds.contains(c.id))
            .toList();
        final pos0 = sentenceCards.where((c) => c.position == 0).toList();
        final pos1 = sentenceCards.where((c) => c.position == 1).toList();
        final pos2 = sentenceCards.where((c) => c.position == 2).toList();

        if (pos0.isNotEmpty && pos1.isNotEmpty && pos2.isNotEmpty) {
          usedIds.add(pos0.first.id);
          usedIds.add(pos1.first.id);
          usedIds.add(pos2.first.id);
          foundGroup = true;
          totalSentenceCount++;
          if (s == 1) shangDaRenSentenceCount++;
          if (s == 8) fuLuShouSentenceCount++;
        }
      }
    }

    final totalSpecialSentenceCount =
        shangDaRenSentenceCount + fuLuShouSentenceCount;
    if (totalSpecialSentenceCount < 2) return 0;

    final remaining = hand.where((c) => !usedIds.contains(c.id)).toList();
    if (remaining.length != 2) return 0;
    if (totalSentenceCount != 6) return 0;

    final c1 = remaining[0];
    final c2 = remaining[1];
    final isHalfKao =
        c1.sentence == c2.sentence &&
        c1.position != c2.position &&
        c1.character != c2.character;
    if (!isHalfKao) return 0;

    final allCards = [...hand, ...melds.expand((m) => m.cards)];
    final shangCount = allCards.where((c) => c.character == '上').length;
    final fuCount = allCards.where((c) => c.character == '福').length;
    final shangFuCount = shangCount + fuCount;

    if (shangFuCount >= 3 && shangFuCount <= 6) {
      return shangFuCount;
    }

    return 0;
  }

  static bool _checkQingHu(List<Card> hand, List<Meld> melds, int huCount) {
    final allCards = [...hand, ...melds.expand((m) => m.cards)];
    final shangCount = allCards.where((c) => c.character == '上').length;
    final fuCount = allCards.where((c) => c.character == '福').length;

    if (shangCount > 0 || fuCount > 0) return false;

    if (_hasHalfKao(hand, melds, 1) || _hasHalfKao(hand, melds, 8)) {
      return false;
    }

    if (huCount < 11 || huCount > 21) return false;

    return _checkQingHuRemaining(hand);
  }

  static bool _checkQingHuConditions(List<Card> hand, List<Meld> melds) {
    final allCards = [...hand, ...melds.expand((m) => m.cards)];
    if (allCards.any((c) => c.character == '上')) return false;
    if (allCards.any((c) => c.character == '福')) return false;
    if (_hasHalfKao(hand, melds, 1)) return false;
    if (_hasHalfKao(hand, melds, 8)) return false;
    return _checkQingHuRemaining(hand);
  }

  static bool _hasHalfKao(List<Card> hand, List<Meld> melds, int sentence) {
    for (final meld in melds) {
      if (meld.type == MeldType.kao && meld.cards.first.sentence == sentence) {
        return true;
      }
    }
    for (int i = 0; i < hand.length - 1; i++) {
      for (int j = i + 1; j < hand.length; j++) {
        final c1 = hand[i];
        final c2 = hand[j];
        if (c1.sentence == sentence &&
            c2.sentence == sentence &&
            c1.position != c2.position &&
            c1.character != c2.character) {
          return true;
        }
      }
    }
    return false;
  }

  static bool _checkQingHuRemaining(List<Card> hand) {
    final cards = List<Card>.from(hand);
    final usedIds = <int>{};

    bool foundGroup = true;
    while (foundGroup) {
      foundGroup = false;
      for (var s = 1; s <= 8; s++) {
        final sentenceCards = cards
            .where((c) => c.sentence == s && !usedIds.contains(c.id))
            .toList();
        final pos0 = sentenceCards.where((c) => c.position == 0).toList();
        final pos1 = sentenceCards.where((c) => c.position == 1).toList();
        final pos2 = sentenceCards.where((c) => c.position == 2).toList();

        if (pos0.isNotEmpty && pos1.isNotEmpty && pos2.isNotEmpty) {
          usedIds.add(pos0.first.id);
          usedIds.add(pos1.first.id);
          usedIds.add(pos2.first.id);
          foundGroup = true;
        }
      }
    }

    final remaining = cards.where((c) => !usedIds.contains(c.id)).toList();

    final byChar = <String, int>{};
    for (final card in remaining) {
      byChar[card.character] = (byChar[card.character] ?? 0) + 1;
    }
    for (final count in byChar.values) {
      if (count >= 3) {
        usedIds.clear();
        return _checkQingHuRemainingWithKan(cards);
      }
    }

    if (remaining.length == 2) {
      final c1 = remaining[0];
      final c2 = remaining[1];
      if (c1.character == c2.character) return true;
      if (c1.sentence == c2.sentence && c1.position != c2.position) return true;
    }

    return false;
  }

  static bool _checkQingHuRemainingWithKan(List<Card> cards) {
    final remaining = List<Card>.from(cards);
    final aSet = <Meld>[];
    final cSet = <Meld>[];
    final dSet = <Meld>[];

    extractJu(remaining, aSet);
    extractKan(remaining, cSet);
    extractDuiAndKao(remaining, dSet);

    return remaining.isEmpty || (remaining.length == 2 && dSet.isNotEmpty);
  }

  static String? _checkQingKuChongTai(List<Card> hand, List<Meld> melds) {
    final zhaoCount = melds.where((m) => m.type == MeldType.zhao).length;
    final hasShangFu = melds.any(
      (m) => m.cards.any((c) => c.character == '上' || c.character == '福'),
    );

    if (hasShangFu) return null;

    final counts = <String, int>{};
    for (final card in hand) {
      counts[card.character] = (counts[card.character] ?? 0) + 1;
    }

    final handZhaoCount = counts.values.where((c) => c >= 4).length;
    final handKanCount = counts.values.where((c) => c == 3).length;
    final handDuiCount = counts.values.where((c) => c == 2).length;

    final totalZhaoCount = zhaoCount + handZhaoCount;

    if (totalZhaoCount == 6 && handDuiCount == 1) {
      return 'qingKuChongTaiHu';
    }
    if (totalZhaoCount == 5 && handKanCount == 1 && handDuiCount == 1) {
      return 'qingKuChongTaiKa';
    }

    int halfKaoCount = 0;
    for (var s = 1; s <= 8; s++) {
      final sentenceCards = hand.where((c) => c.sentence == s).toList();
      final positions = sentenceCards.map((c) => c.position).toSet();
      if (positions.length == 2 &&
          !sentenceCards.any((c) => c.character == '上' || c.character == '福')) {
        halfKaoCount++;
      }
    }

    if (totalZhaoCount == 6 && halfKaoCount == 1) {
      return 'qingKuChongTaiHu';
    }
    if (totalZhaoCount == 5 && handKanCount == 1 && halfKaoCount == 1) {
      return 'qingKuChongTaiKa';
    }

    return null;
  }

  static int _calculateBonus(
    List<Meld> aSet,
    List<Meld> dSet,
    List<Card> eSet,
  ) {
    int bonus = 0;

    final aCharCount = <String, int>{};
    for (final meld in aSet) {
      for (final card in meld.cards) {
        aCharCount[card.character] = (aCharCount[card.character] ?? 0) + 1;
      }
    }

    for (final meld in dSet) {
      if (meld.type == MeldType.dui && !meld.isJing) {
        final ch = meld.cards.first.character;
        final count = aCharCount[ch] ?? 0;
        if (count == 1) bonus += 3;
      }
      if (meld.type == MeldType.kao && !meld.isJing) {
        for (final card in meld.cards) {
          final count = aCharCount[card.character] ?? 0;
          if (count == 2) {
            bonus += 6;
            break;
          }
        }
      }
    }

    for (final card in eSet) {
      if (card.isJing) continue;
      final count = aCharCount[card.character] ?? 0;
      if (count == 2) bonus += 3;
    }

    final aSentenceCount = <int, int>{};
    for (final meld in aSet) {
      if (meld.type == MeldType.ju) {
        final s = meld.cards.first.sentence;
        aSentenceCount[s] = (aSentenceCount[s] ?? 0) + 1;
      }
    }
    aSentenceCount.forEach((s, count) {
      if (count >= 3) {
        if (s == 1 || s == 8) {
          bonus += 6;
        } else {
          bonus += 9;
        }
      }
    });

    return bonus;
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

class HuTypeResult {
  final String type;
  final String name;
  final int dianpao;
  final int zimo;

  const HuTypeResult({
    required this.type,
    required this.name,
    required this.dianpao,
    required this.zimo,
  });
}
