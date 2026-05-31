import 'ai_strategy.dart';
import '../../models/card.dart';
import '../../models/game_state.dart';
import '../../models/player.dart';
import '../../models/meld.dart';
import '../ting_checker.dart';
import '../hu_calculator.dart';

class AIStrategyHard extends AIStrategy {
  static const List<List<String>> _groupChars = [
    ['上', '大', '人'],
    ['丘', '乙', '己'],
    ['化', '三', '千'],
    ['七', '十', '土'],
    ['尔', '小', '生'],
    ['八', '九', '子'],
    ['佳', '作', '亡'],
    ['福', '禄', '寿'],
  ];

  static const List<String> _allChars = [
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

  static final Map<String, int> _charSentenceMap = {
    for (int i = 0; i < _groupChars.length; i++)
      for (final ch in _groupChars[i]) ch: i + 1,
  };

  static final Map<String, int> _charPositionMap = {
    for (int i = 0; i < _groupChars.length; i++)
      for (int j = 0; j < _groupChars[i].length; j++) _groupChars[i][j]: j,
  };

  Map<String, int> _buildVisibleCharCount(Player player, GameState state) {
    return state.buildVisibleCount(player);
  }

  int _remainingCount(String character, Map<String, int> visibleCount) {
    final rem = 4 - (visibleCount[character] ?? 0);
    return rem > 0 ? rem : 0;
  }

  /// 使用GameState增量方法快速获取剩余张数
  int _remainingCountFast(String character, Player player, GameState state) {
    return state.remainingCount(character, player);
  }

  int _totalUnknownCards(Player player, GameState state) {
    return state.totalUnknownCards(player);
  }

  bool _isLateGame(GameState state) {
    return state.deck.length < 20;
  }

  bool _isEarlyGame(GameState state) {
    return state.deck.length > 50;
  }

  int _countHandPairs(List<Card> hand) {
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

  int _countHandPairsWithMelds(Player player) {
    final byChar = <String, int>{};
    for (final card in player.hand) {
      byChar[card.character] = (byChar[card.character] ?? 0) + 1;
    }
    int pairs = 0;
    for (final count in byChar.values) {
      if (count == 2) pairs++;
      if (count == 4) pairs += 2;
    }
    for (final meld in player.melds) {
      if (meld.type == MeldType.kan) pairs++;
      if (meld.type == MeldType.zhao) pairs += 2;
    }
    return pairs;
  }

  bool _isPartOfKan(Card card, List<Card> hand) {
    int count = 0;
    for (final c in hand) {
      if (c.character == card.character) count++;
    }
    return count >= 3;
  }

  bool _isPartOfZhao(Card card, List<Card> hand) {
    int count = 0;
    for (final c in hand) {
      if (c.character == card.character) count++;
    }
    return count >= 4;
  }

  double _evaluateShiDuiPotential(
    Player player,
    GameState state, {
    Map<String, int>? visibleCount,
    int? totalUnknown,
  }) {
    final pairCount = _countHandPairsWithMelds(player);
    if (pairCount < 7) return -1;

    final vc = visibleCount ?? _buildVisibleCharCount(player, state);
    final tu = totalUnknown ?? _totalUnknownCards(player, state);

    final byChar = <String, int>{};
    for (final card in player.hand) {
      byChar[card.character] = (byChar[card.character] ?? 0) + 1;
    }

    double prob = 0;
    for (final entry in byChar.entries) {
      if (entry.value == 1) {
        final rem = _remainingCount(entry.key, vc);
        if (rem > 0) prob += rem / tu;
      }
    }

    double score = pairCount * 80.0 + prob * 200;
    if (pairCount >= 9) score += 500;
    if (pairCount >= 8) score += 200;

    return score;
  }

  double _evaluateHuScore(Player player) {
    return HuCalculator.calculateTotalHu(player) * 1.0;
  }

  @override
  Card selectDiscard(Player player, GameState state) {
    final hand = player.hand;
    if (hand.length <= 1) return hand.first;

    if (player.isTing) {
      return _selectDiscardWhenTing(player, state);
    }

    return _selectDiscardOptimized(player, state);
  }

  /// 评估吃牌后的手牌质量
  double _evaluateChiBenefit(Player player, Card card, GameState state) {
    final hand = player.hand;
    final neededChars = _getOtherCharsInGroup(card);
    final hasAll = neededChars.every(
      (ch) => hand.any((c) => c.character == ch),
    );
    if (!hasAll) return -1;

    // 评估吃牌前被消耗的牌在其他组合中的价值
    double consumptionCost = 0;
    final visibleCount = _buildVisibleCharCount(player, state);
    for (final ch in neededChars) {
      // 检查该字是否参与了其他靠/对组合
      final sameGroupInHand = hand
          .where((c) => c.sentence == _charSentenceMap[ch] && c.character != ch)
          .toList();
      // 如果该字有同组伙伴（靠/半搭子），吃掉会损失进张
      if (sameGroupInHand.length >= 1) {
        consumptionCost += 30;
      }
      // 如果该字在手牌中有2张以上，吃掉1张损失较小
      final chCount = hand.where((c) => c.character == ch).length;
      if (chCount >= 2) {
        consumptionCost -= 20; // 多张时吃掉影响小
      }
    }

    final testHand = List<Card>.from(hand);
    for (final ch in neededChars) {
      testHand.removeWhere((c) => c.character == ch);
    }

    final newMeld = Meld(
      cards: [
        card,
        ...neededChars.map((ch) => hand.firstWhere((c) => c.character == ch)),
      ],
      type: MeldType.ju,
      isJing: card.isJing,
    );

    final testPlayer = Player(
      id: player.id,
      name: player.name,
      type: player.type,
      hand: testHand,
      melds: [...player.melds, newMeld],
    );

    // 吃牌后听牌，极大收益
    final tingAfter = TingChecker.checkTing(testPlayer);
    if (tingAfter.isTing) return 10000;

    final distBefore = _distanceToTing(List<Card>.from(hand), player.melds);
    final distAfter = _distanceToTing(testHand, [...player.melds, newMeld]);

    // 距离减小才有正收益
    if (distAfter >= distBefore) return -1;

    double benefit = (distBefore - distAfter) * 200.0;

    // 吃牌后接近听牌，额外加分
    if (distAfter <= 2) benefit += 500;
    if (distAfter <= 4) benefit += 200;

    // 评估吃牌后手牌的胡数
    benefit += _evaluateHuScore(testPlayer) * 2;

    // 评估吃牌后手牌的进张概率
    final totalUnknown = _totalUnknownCards(player, state);
    double chiAfterProb = 0;
    for (final c in testHand) {
      final rem = _remainingCount(c.character, visibleCount);
      if (rem > 0) chiAfterProb += rem / totalUnknown;
    }
    benefit += chiAfterProb * 50;

    // 扣除消耗成本
    benefit -= consumptionCost;

    return benefit;
  }

  Card _selectDiscardWhenTing(Player player, GameState state) {
    final hand = player.hand;
    final visibleCount = _buildVisibleCharCount(player, state);
    final totalUnknown = _totalUnknownCards(player, state);

    // 对每张手牌，模拟出牌后检查听牌结果
    Card? bestCard;
    int bestTingCount = -1;
    double bestTingProb = -1;
    double bestHuScore = -1;

    for (final card in hand) {
      if (_isPartOfKan(card, hand)) continue;

      final testHand = List<Card>.from(hand);
      testHand.remove(card);

      final testPlayer = Player(
        id: player.id,
        name: player.name,
        type: player.type,
        hand: testHand,
        melds: player.melds,
      );

      final tingResult = TingChecker.checkTing(testPlayer);
      if (!tingResult.isTing) continue;

      // 计算听牌进张数和进张概率
      int tingCount = 0;
      double tingProb = 0;
      final seenChars = <String>{};
      for (final tc in tingResult.tingCards) {
        if (seenChars.contains(tc.character)) continue;
        seenChars.add(tc.character);
        final rem = _remainingCount(tc.character, visibleCount);
        if (rem > 0) {
          tingCount += rem;
          tingProb += rem / totalUnknown;
        }
      }

      final huScore = _evaluateHuScore(testPlayer);

      // 优先选择听牌数多的，其次进张概率高的，再次胡数高的
      if (tingCount > bestTingCount ||
          (tingCount == bestTingCount && tingProb > bestTingProb) ||
          (tingCount == bestTingCount &&
              tingProb == bestTingProb &&
              huScore > bestHuScore)) {
        bestCard = card;
        bestTingCount = tingCount;
        bestTingProb = tingProb;
        bestHuScore = huScore;
      }
    }

    // 如果找到听牌出牌，返回
    if (bestCard != null) return bestCard;

    // 没有听牌出牌时（不应该发生），用简单策略
    final tingCards = player.tingCards;
    final tingChars = tingCards.map((c) => c.character).toSet();
    final safeCards = <Card>[];
    for (final card in hand) {
      if (!tingChars.contains(card.character)) {
        safeCards.add(card);
      }
    }
    if (safeCards.isNotEmpty) {
      safeCards.sort((a, b) {
        return _discardPriority(b).compareTo(_discardPriority(a));
      });
      return safeCards.first;
    }

    // 兜底：出剩余最多的牌
    final scored = <MapEntry<Card, double>>[];
    for (final card in hand) {
      double score = 0;
      final rem = _remainingCount(card.character, visibleCount);
      score += rem * 10;
      if (card.isJing) score -= 100;
      scored.add(MapEntry(card, score));
    }
    scored.sort((a, b) => b.value.compareTo(a.value));
    return scored.first.key;
  }

  Card _selectDiscardOptimized(Player player, GameState state) {
    final hand = player.hand;
    if (hand.length <= 1) return hand.first;

    final visibleCount = _buildVisibleCharCount(player, state);
    final totalUnknown = _totalUnknownCards(player, state);
    final isLate = _isLateGame(state);

    // 先检查是否有听牌出牌，选择听牌面最宽的
    Card? bestTingCard;
    int bestTingRem = -1;
    double bestTingProb = -1;
    double bestTingHu = -1;
    for (final card in hand) {
      if (_isPartOfKan(card, hand)) continue;

      final testHand = List<Card>.from(hand);
      testHand.remove(card);
      final testPlayer = Player(
        id: player.id,
        name: player.name,
        type: player.type,
        hand: testHand,
        melds: player.melds,
      );
      final tingResult = TingChecker.checkTing(testPlayer);
      if (tingResult.isTing) {
        // 计算听牌进张数和概率
        int tingRem = 0;
        double tingProb = 0;
        final seenChars = <String>{};
        for (final tc in tingResult.tingCards) {
          if (seenChars.contains(tc.character)) continue;
          seenChars.add(tc.character);
          final rem = _remainingCount(tc.character, visibleCount);
          if (rem > 0) {
            tingRem += rem;
            tingProb += rem / totalUnknown;
          }
        }
        final huScore = _evaluateHuScore(testPlayer);
        // 优先选进张多的，其次概率高的，再次胡数高的
        if (tingRem > bestTingRem ||
            (tingRem == bestTingRem && tingProb > bestTingProb) ||
            (tingRem == bestTingRem &&
                tingProb == bestTingProb &&
                huScore > bestTingHu)) {
          bestTingCard = card;
          bestTingRem = tingRem;
          bestTingProb = tingProb;
          bestTingHu = huScore;
        }
      }
    }
    if (bestTingCard != null) return bestTingCard;

    final shiDuiPotential = _evaluateShiDuiPotential(
      player,
      state,
      visibleCount: visibleCount,
      totalUnknown: totalUnknown,
    );

    final availableChars = _buildAvailableChars(visibleCount);

    // 对所有手牌进行深度评估
    final scored = <MapEntry<Card, double>>[];
    for (final card in hand) {
      double score = _evaluateDiscardComprehensive(
        player,
        card,
        state,
        visibleCount,
        totalUnknown,
        isLate,
        shiDuiPotential,
        availableChars,
      );

      // 2步前瞻：评估出牌后抽到各种牌的距离改善
      if (hand.length > 3) {
        score += _twoStepLookahead(
          player,
          card,
          state,
          visibleCount,
          totalUnknown,
          availableChars,
        );
      }

      scored.add(MapEntry(card, score));
    }

    scored.sort((a, b) => b.value.compareTo(a.value));
    return scored.first.key;
  }

  /// 2步前瞻：评估出牌后，抽到各种牌时距离的改善
  double _twoStepLookahead(
    Player player,
    Card cardToDiscard,
    GameState state,
    Map<String, int> visibleCount,
    int totalUnknown,
    List<String> availableChars,
  ) {
    final testHand = List<Card>.from(player.hand);
    testHand.remove(cardToDiscard);
    final melds = player.melds;

    final handGroups = <int>{};
    for (final card in testHand) {
      handGroups.add(card.sentence);
    }

    double totalScore = 0;
    final distBefore = _distanceToTing(testHand, melds);

    for (final ch in availableChars) {
      final sentence = _charSentenceMap[ch];
      if (sentence == null) continue;

      // 只考虑手牌中已有的句组，或者孤张的句组
      if (!handGroups.contains(sentence)) {
        // 孤张也可能有用，但概率低
        final rem = _remainingCount(ch, visibleCount);
        if (rem <= 0) continue;
        final prob = rem / totalUnknown;
        if (prob < 0.02) continue; // 降低阈值，更多孤张进张被考虑

        final position = _charPositionMap[ch] ?? -1;
        if (position < 0) continue;

        final simHand = List<Card>.from(testHand);
        simHand.add(
          Card(id: -100, character: ch, sentence: sentence, position: position),
        );
        final dist = _distanceToTing(simHand, melds);
        final improvement = distBefore - dist;
        if (improvement > 0) {
          totalScore += prob * improvement * 60; // 略微提高权重
        }
        continue;
      }

      final rem = _remainingCount(ch, visibleCount);
      if (rem <= 0) continue;

      final prob = rem / totalUnknown;
      if (prob < 0.01) continue; // 降低阈值，不遗漏低概率高价值进张

      final position = _charPositionMap[ch] ?? -1;
      if (position < 0) continue;

      final simHand = List<Card>.from(testHand);
      simHand.add(
        Card(id: -100, character: ch, sentence: sentence, position: position),
      );
      final dist = _distanceToTing(simHand, melds);

      if (dist <= 0) {
        // 抽到这张牌后听牌
        totalScore += prob * 1000; // 提高听牌奖励
      } else {
        final improvement = distBefore - dist;
        if (improvement > 0) {
          totalScore += prob * improvement * 100; // 提高权重
        }
      }
    }

    return totalScore;
  }

  List<String> _buildAvailableChars(Map<String, int> visibleCount) {
    final result = <String>[];
    for (final ch in _allChars) {
      if (_remainingCount(ch, visibleCount) > 0) {
        result.add(ch);
      }
    }
    return result;
  }

  double _evaluateDiscardComprehensive(
    Player player,
    Card cardToDiscard,
    GameState state,
    Map<String, int> visibleCount,
    int totalUnknown,
    bool isLate,
    double shiDuiPotential,
    List<String> availableChars,
  ) {
    final testHand = List<Card>.from(player.hand);
    testHand.remove(cardToDiscard);

    final testPlayer = Player(
      id: player.id,
      name: player.name,
      type: player.type,
      hand: testHand,
      melds: player.melds,
    );

    final quickDist = _distanceToTing(testHand, player.melds);

    if (quickDist <= 2) {
      final tingResult = TingChecker.checkTing(testPlayer);

      if (tingResult.isTing) {
        double tingProb = 0;
        int effectiveTingCount = 0;
        final seenChars = <String>{};
        for (final tc in tingResult.tingCards) {
          if (seenChars.contains(tc.character)) continue;
          seenChars.add(tc.character);
          final rem = _remainingCount(tc.character, visibleCount);
          if (rem > 0) {
            tingProb += rem / totalUnknown;
            effectiveTingCount++;
          }
        }
        double score = 10000 + tingProb * 1000 + effectiveTingCount * 100;

        score += _evaluateHuScore(testPlayer) * 5;

        if (isLate) score += 2000;

        return score;
      }
    }

    final (potential, distToTing) = _evaluateHandPotentialAndDistance(
      testHand,
      player.melds,
      visibleCount,
      totalUnknown,
    );

    double score = potential;

    if (distToTing <= 4) {
      score += _lookaheadScore(
        testHand,
        player.melds,
        visibleCount,
        totalUnknown,
        availableChars,
      );
    }

    if (shiDuiPotential > 0) {
      final testPairCount = _countHandPairsWithMelds(testPlayer);
      if (testPairCount >= 7) {
        score += testPairCount * 20.0;
      }
    }

    if (cardToDiscard.isJing) {
      score -= 80;
    } else if (_isYin(cardToDiscard)) {
      score -= 20;
    }

    if (_isPartOfKan(cardToDiscard, player.hand)) {
      score -= 500;
    }
    if (_isPartOfZhao(cardToDiscard, player.hand)) {
      score -= 1000;
    }

    score += (10 - distToTing) * 80;

    if (isLate) {
      score += (10 - distToTing) * 100;
      if (distToTing <= 2) {
        score += 500;
      }
    }

    // 步骤10：早期策略 - 更注重收集同组牌，保留有潜力的组合
    if (_isEarlyGame(state)) {
      // 早期保留同组半搭子（2张不同字）
      final sameGroup = player.hand
          .where((c) => c.sentence == cardToDiscard.sentence)
          .toList();
      final groupCharSet = sameGroup.map((c) => c.character).toSet();
      if (groupCharSet.length >= 2) {
        // 惩罚打出半搭子中的牌
        score -= 30;
        // 同组3种字差1张成句，更不应打出
        if (groupCharSet.length >= 3) {
          score -= 20;
        }
      }
      // 早期保留有进张的孤张
      final otherChars = _groupChars[cardToDiscard.sentence - 1]
          .where((ch) => ch != cardToDiscard.character)
          .toList();
      int partnerRem = 0;
      for (final ch in otherChars) {
        partnerRem += _remainingCount(ch, visibleCount);
      }
      if (partnerRem > 0) {
        // 惩罚打出有进张的孤张
        score -= partnerRem * 3;
      }
      // 早期精牌孤张更应保留
      if (cardToDiscard.isJing) {
        score -= 20;
      }
    }

    // 步骤9：防守意识 - 评估出牌的危险性
    score -= _evaluateDanger(player, cardToDiscard, state, isLate);

    return score;
  }

  /// 评估出牌的危险性（被具他人胡牌的概率）
  double _evaluateDanger(
    Player player,
    Card cardToDiscard,
    GameState state,
    bool isLate,
  ) {
    double danger = 0;
    final ch = cardToDiscard.character;
    final isMidGame = state.deck.length >= 20 && state.deck.length <= 50;

    // 检查其他玩家的弃牌和面子，推测他们可能听什么
    for (int i = 0; i < state.players.length; i++) {
      if (i == player.id) continue;
      final other = state.players[i];

      // 如果对方已经听牌，出牌更危险
      if (other.isTing) {
        // 对方听牌时，出任何牌都可能点炮
        // 但某些牌更危险：对方已碰/招的字相关牌
        final otherMeldChars = <String>{};
        for (final meld in other.melds) {
          for (final c in meld.cards) {
            otherMeldChars.add(c.character);
          }
        }

        // 如果出的牌和对方面子同组，更危险
        final sameGroupChars = _groupChars[cardToDiscard.sentence - 1];
        for (final mc in sameGroupChars) {
          if (otherMeldChars.contains(mc)) {
            danger += isLate ? 60 : 40;
            break;
          }
        }

        // 对方听牌时，出精牌最危险
        if (cardToDiscard.isJing) {
          danger += isLate ? 100 : 60;
        }

        // 出阴牌也较危险（阴牌容易被胡）
        if (_isYin(cardToDiscard)) {
          danger += isLate ? 40 : 20;
        }

        // 基础危险分
        danger += isLate ? 40 : 20;

        // 通过对方面子推断可能听的牌
        // 对方碰/招了某字，可能听同组其他字
        for (final meld in other.melds) {
          final meldSentence = meld.cards.first.sentence;
          if (meldSentence == cardToDiscard.sentence) {
            // 出的牌和对方面子同组，极危险
            danger += isLate ? 50 : 30;
          }
        }
      }

      // 对方未听牌但面子多时，也有一定危险
      if (!other.isTing && other.melds.length >= 3) {
        danger += isLate ? 15 : 8;
      }

      // 中期：通过弃牌推断对方可能收集的句组
      if (isMidGame && !other.isTing) {
        // 统计对方弃牌中缺少的句组（可能正在收集）
        final discardGroups = <int>{};
        for (final dc in other.discards) {
          discardGroups.add(dc.sentence);
        }
        final meldGroups = <int>{};
        for (final meld in other.melds) {
          meldGroups.add(meld.cards.first.sentence);
        }
        // 如果出的牌属于对方已收集但未弃过的组
        if (meldGroups.contains(cardToDiscard.sentence) &&
            !discardGroups.contains(cardToDiscard.sentence)) {
          danger += 10;
        }
      }
    }

    // 如果自己已经听牌，进攻优先，减少防守惩罚
    if (player.isTing) {
      danger *= 0.2;
    }

    // 如果自己距离听牌很近（距离<=2），进攻优先
    final myDist = _distanceToTing(List<Card>.from(player.hand), player.melds);
    if (myDist <= 2) {
      danger *= 0.3;
    }

    return danger;
  }

  (double potential, int distance) _evaluateHandPotentialAndDistance(
    List<Card> hand,
    List<Meld> melds,
    Map<String, int> visibleCount,
    int totalUnknown,
  ) {
    final remaining = List<Card>.from(hand);
    final aSet = <Meld>[];
    final bSet = <Meld>[];
    final cSet = <Meld>[];
    final dSet = <Meld>[];
    final eSet = <Card>[];

    HuCalculator.extractJu(remaining, aSet);
    HuCalculator.extractZhao(remaining, bSet);
    HuCalculator.extractKan(remaining, cSet);
    HuCalculator.extractDuiAndKao(remaining, dSet);
    eSet.addAll(remaining);

    int totalMelds = aSet.length + bSet.length + cSet.length;
    for (final m in melds) {
      if (m.type == MeldType.ju ||
          m.type == MeldType.kan ||
          m.type == MeldType.zhao) {
        totalMelds++;
      }
    }

    int neededMelds = 6 - totalMelds;
    if (neededMelds < 0) neededMelds = 0;

    int usefulDuiKao = 0;
    for (final meld in dSet) {
      if (meld.type == MeldType.kao || meld.type == MeldType.dui) {
        usefulDuiKao++;
      }
    }

    int distance = neededMelds * 2 - usefulDuiKao;
    if (distance < 0) distance = 0;
    if (distance > 10) distance = 10;

    final pairCount = _countHandPairs(hand);
    if (pairCount >= 9) {
      double prob = 0;
      final byChar = <String, int>{};
      for (final card in hand) {
        byChar[card.character] = (byChar[card.character] ?? 0) + 1;
      }
      for (final entry in byChar.entries) {
        if (entry.value == 1 || entry.value == 3) {
          final rem = _remainingCount(entry.key, visibleCount);
          if (rem > 0) prob += rem / totalUnknown;
        }
      }
      return (500 + prob * 200, distance);
    }

    double score = 0;
    score += aSet.length * 100.0;
    score += bSet.length * 150.0;
    score += cSet.length * 120.0;

    for (final meld in aSet) {
      if (meld.isJing) score += 20;
    }
    for (final meld in bSet) {
      if (meld.isJing) score += 30;
    }
    for (final meld in cSet) {
      if (meld.isJing) score += 25;
    }

    // 评估对和靠，增加进张概率权重
    for (final meld in dSet) {
      if (meld.type == MeldType.dui) {
        final ch = meld.cards.first.character;
        final inJu = aSet.any((m) => m.cards.any((c) => c.character == ch));
        if (inJu) {
          score += 30;
        } else {
          final rem = _remainingCount(ch, visibleCount);
          if (rem >= 1) {
            // 对的进张：需要第3张变成刻，进张数=rem
            // 进张概率高的对更有价值
            score += 25 + rem * 8;
          } else {
            // 没有进张的对价值很低
            score += 5;
          }
        }
        if (meld.isJing) score += 15;
      } else if (meld.type == MeldType.kao) {
        final chars = meld.cards.map((c) => c.character).toList();
        final missingChar = _findMissingCharForSentence(chars);
        if (missingChar != null) {
          final rem = _remainingCount(missingChar, visibleCount);
          if (rem >= 1) {
            // 靠的进张：需要缺的那1张，进张数=rem
            // 进张概率高的靠更有价值
            score += 40 + rem * 15;
          } else {
            // 没有进张的靠价值极低
            score += 2;
          }
        } else {
          score += 50;
        }
        if (meld.isJing) score += 10;
      }
    }

    // 评估孤张牌的价值，考虑半搭子（同组2张不同字但未被提取为靠）
    for (final card in eSet) {
      final sameGroup = hand.where((c) => c.sentence == card.sentence).toList();
      final groupCharSet = sameGroup.map((c) => c.character).toSet();

      if (groupCharSet.length >= 2) {
        // 半搭子：同组有2-3种不同字，可以组成靠或句
        final missingChars = _groupChars[card.sentence - 1]
            .where((ch) => !groupCharSet.contains(ch))
            .toList();
        double missingProb = 0;
        int totalRem = 0;
        for (final ch in missingChars) {
          final rem = _remainingCount(ch, visibleCount);
          if (rem > 0) {
            missingProb += rem / totalUnknown;
            totalRem += rem;
          }
        }
        // 半搭子进张概率高，大幅加分
        score += missingProb * 50 + totalRem * 3;

        // 如果同组有3种字，说明差1张就能成句，价值极高
        if (groupCharSet.length >= 3) {
          score += 30;
        }
      } else {
        // 孤张：同组只有1种字
        final otherChars = _groupChars[card.sentence - 1]
            .where((ch) => ch != card.character)
            .toList();
        double partnerProb = 0;
        int partnerRem = 0;
        for (final ch in otherChars) {
          final rem = _remainingCount(ch, visibleCount);
          if (rem > 0) {
            partnerProb += rem / totalUnknown;
            partnerRem += rem;
          }
        }
        // 孤张进张概率低，但有进张时仍有一定价值
        score -= 10; // 减少惩罚
        score += partnerProb * 10 + partnerRem * 1;

        // 同组其他牌已被出完的孤张价值极低
        if (partnerRem == 0) {
          score -= 30;
        }
      }

      if (card.isJing) {
        score += 20; // 精牌孤张价值更高
      } else if (_isYin(card)) {
        score += 3;
      }
    }

    if (dSet.isEmpty && eSet.length == 1) {
      final singleChar = eSet.first.character;
      final rem = _remainingCount(singleChar, visibleCount);
      score += 150 + rem * 20;

      final kaoChars = _groupChars[eSet.first.sentence - 1]
          .where((ch) => ch != singleChar)
          .toList();
      for (final ch in kaoChars) {
        final r = _remainingCount(ch, visibleCount);
        if (r > 0) score += r * 10;
      }
    } else if (dSet.length == 2 && eSet.isEmpty) {
      double pairProb = 0;
      for (final meld in dSet) {
        if (meld.type == MeldType.dui) {
          final ch = meld.cards.first.character;
          final rem = _remainingCount(ch, visibleCount);
          if (rem > 0) pairProb += rem / totalUnknown;
        } else if (meld.type == MeldType.kao) {
          final chars = meld.cards.map((c) => c.character).toList();
          final missing = _findMissingCharForSentence(chars);
          if (missing != null) {
            final rem = _remainingCount(missing, visibleCount);
            if (rem > 0) pairProb += rem / totalUnknown;
          }
        }
      }
      score += 130 + pairProb * 100;
    }

    if (pairCount >= 7 && pairCount < 9) {
      final byChar = <String, int>{};
      for (final card in hand) {
        byChar[card.character] = (byChar[card.character] ?? 0) + 1;
      }
      int singlesNeedingPair = 0;
      double pairProb = 0;
      for (final entry in byChar.entries) {
        if (entry.value == 1) {
          singlesNeedingPair++;
          final rem = _remainingCount(entry.key, visibleCount);
          if (rem > 0) pairProb += rem / totalUnknown;
        }
      }
      if (singlesNeedingPair <= 10 - pairCount) {
        score += pairCount * 30 + pairProb * 100;
      }
    }

    score += (10 - distance) * 30;

    return (score, distance);
  }

  int _distanceToTing(List<Card> hand, List<Meld> melds) {
    // 先检查十对距离
    final pairDist = _distanceToTingShiDui(hand, melds);
    final normalDist = _distanceToTingNormal(hand, melds);
    return pairDist < normalDist ? pairDist : normalDist;
  }

  /// 十对听牌距离
  int _distanceToTingShiDui(List<Card> hand, List<Meld> melds) {
    final byChar = <String, int>{};
    for (final card in hand) {
      byChar[card.character] = (byChar[card.character] ?? 0) + 1;
    }
    // 计算已有刻/招中的对子数
    int meldPairs = 0;
    for (final m in melds) {
      if (m.type == MeldType.kan) meldPairs += 1; // 刻=1对+1单
      if (m.type == MeldType.zhao) meldPairs += 2; // 招=2对
    }

    int pairs = 0;
    int singles = 0;
    int triples = 0;
    for (final count in byChar.values) {
      if (count >= 4) {
        pairs += 2;
      } else if (count == 3) {
        pairs += 1;
        triples++;
      } else if (count == 2) {
        pairs++;
      } else {
        singles++;
      }
    }
    pairs += meldPairs;

    // 十对需要10对，距离 = 10 - pairs
    int dist = 10 - pairs;
    if (dist < 0) dist = 0;
    if (dist > 10) dist = 10;
    return dist;
  }

  /// 普通胡听牌距离
  int _distanceToTingNormal(List<Card> hand, List<Meld> melds) {
    final remaining = List<Card>.from(hand);
    final aSet = <Meld>[];
    final bSet = <Meld>[];
    final cSet = <Meld>[];
    final dSet = <Meld>[];
    final eSet = <Card>[];

    HuCalculator.extractJu(remaining, aSet);
    HuCalculator.extractZhao(remaining, bSet);
    HuCalculator.extractKan(remaining, cSet);
    HuCalculator.extractDuiAndKao(remaining, dSet);
    eSet.addAll(remaining);

    int totalMelds = aSet.length + bSet.length + cSet.length;
    for (final m in melds) {
      if (m.type == MeldType.ju ||
          m.type == MeldType.kan ||
          m.type == MeldType.zhao) {
        totalMelds++;
      }
    }

    int neededMelds = 6 - totalMelds;
    if (neededMelds < 0) neededMelds = 0;

    int usefulDuiKao = 0;
    for (final meld in dSet) {
      if (meld.type == MeldType.kao || meld.type == MeldType.dui) {
        usefulDuiKao++;
      }
    }

    // 孤张中可能有同组2张的，可以组成靠
    int potentialKaoFromSingles = 0;
    final singleByGroup = <int, List<Card>>{};
    for (final card in eSet) {
      singleByGroup.putIfAbsent(card.sentence, () => []).add(card);
    }
    for (final entry in singleByGroup.entries) {
      if (entry.value.length >= 2) {
        // 同组2张孤张可以组成靠
        potentialKaoFromSingles += entry.value.length ~/ 2;
      }
    }

    int dist = neededMelds * 2 - usefulDuiKao - potentialKaoFromSingles;
    if (dist < 0) dist = 0;
    if (dist > 10) dist = 10;
    return dist;
  }

  double _lookaheadScore(
    List<Card> testHand,
    List<Meld> melds,
    Map<String, int> visibleCount,
    int totalUnknown,
    List<String> availableChars,
  ) {
    double totalScore = 0;

    final handGroups = <int>{};
    for (final card in testHand) {
      handGroups.add(card.sentence);
    }

    for (final ch in availableChars) {
      final sentence = _charSentenceMap[ch];
      if (sentence == null) continue;

      if (!handGroups.contains(sentence)) continue;

      final rem = _remainingCount(ch, visibleCount);
      if (rem <= 0) continue;

      final prob = rem / totalUnknown;
      if (prob < 0.01) continue; // 降低阈值，不遗漏有价值的进张

      final position = _charPositionMap[ch] ?? -1;
      if (position < 0) continue;

      final simHand = List<Card>.from(testHand);
      simHand.add(
        Card(id: -100, character: ch, sentence: sentence, position: position),
      );

      final dist = _distanceToTing(simHand, melds);
      if (dist <= 0) {
        totalScore += prob * 500;
      } else {
        totalScore += prob * (10 - dist) * 20;
      }
    }

    return totalScore;
  }

  String? _findMissingCharForSentence(List<String> existingChars) {
    if (existingChars.length != 2) return null;
    final sentence = _charSentenceMap[existingChars.first];
    if (sentence == null) return null;
    final fullGroup = _groupChars[sentence - 1];
    for (final ch in fullGroup) {
      if (!existingChars.contains(ch)) return ch;
    }
    return null;
  }

  int _discardPriority(Card card) {
    if (card.isJing) return 0;
    if (_isYin(card)) return 1;
    return 2;
  }

  bool _isYin(Card card) {
    return card.character == '大' ||
        card.character == '人' ||
        card.character == '禄' ||
        card.character == '寿';
  }

  List<String> _getOtherCharsInGroup(Card card) {
    return _groupChars[card.sentence - 1]
        .where((ch) => ch != card.character)
        .toList();
  }

  @override
  bool shouldChi(Player player, Card card, GameState state) {
    if (_hasCompleteSentenceWithSingleCards(player, card)) {
      return false;
    }

    final benefit = _evaluateChiBenefit(player, card, state);
    if (benefit < 0) return false;

    if (player.isTing) return benefit >= 10000;

    return benefit > 0;
  }

  /// 检查手牌中是否已有包含出牌的完整一句，且每个字都只有1张
  /// 例如：手牌有"丘乙己"各1张，上家出"丘"，则返回true
  bool _hasCompleteSentenceWithSingleCards(Player player, Card card) {
    final hand = player.hand;
    final sentence = card.sentence;
    final groupChars = _groupChars[sentence - 1];

    // 统计手牌中该句组每个字的数量
    final charCount = <String, int>{};
    for (final ch in groupChars) {
      charCount[ch] = 0;
    }
    for (final c in hand) {
      if (c.sentence == sentence && charCount.containsKey(c.character)) {
        charCount[c.character] = charCount[c.character]! + 1;
      }
    }

    // 检查是否该句组3个字在手牌中都有，且每个字都只有1张
    final allPresent = charCount.values.every((count) => count >= 1);
    final allSingle = charCount.values.every((count) => count == 1);

    // 出的牌也属于这个句组
    return allPresent && allSingle && groupChars.contains(card.character);
  }

  @override
  bool shouldPeng(Player player, Card card, GameState state) {
    final hand = player.hand;
    final sameCharCount = hand
        .where((c) => c.character == card.character)
        .length;

    if (sameCharCount < 1) return false;

    if (sameCharCount >= 2) {
      final testHand = List<Card>.from(hand);
      final matching = testHand
          .where((c) => c.character == card.character)
          .take(2)
          .toList();
      for (final m in matching) {
        testHand.remove(m);
      }

      final newMeld = Meld(
        cards: [card, ...matching],
        type: MeldType.kan,
        isJing: card.isJing,
      );

      final testPlayer = Player(
        id: player.id,
        name: player.name,
        type: player.type,
        hand: testHand,
        melds: [...player.melds, newMeld],
      );

      final tingAfter = TingChecker.checkTing(testPlayer);

      if (tingAfter.isTing) return true;
      if (player.isTing && !tingAfter.isTing) return false;

      final distBefore = _distanceToTing(List<Card>.from(hand), player.melds);
      final distAfter = _distanceToTing(testHand, [...player.melds, newMeld]);

      // 碰牌后距离不增加才碰
      if (distAfter > distBefore) return false;

      // 碰牌后距离减小或不变，且手牌较少时更倾向碰
      if (distAfter < distBefore) return true;

      // 距离不变时，评估碰牌后手牌质量和进张损失
      final huScoreAfter = _evaluateHuScore(testPlayer);
      if (huScoreAfter > 0) return true;

      // 评估碰牌前的进张（该字参与的其他组合价值）
      final charInHand = hand
          .where((c) => c.character == card.character)
          .length;
      if (charInHand >= 2) {
        // 手牌有2张同字，碰掉后少了1张可用的牌
        // 检查该字同组的其他字在手牌中是否有
        final otherChars = _groupChars[card.sentence - 1]
            .where((ch) => ch != card.character)
            .toList();
        for (final ch in otherChars) {
          if (hand.any((c) => c.character == ch)) {
            // 该字有同组伙伴，碰掉可能破坏靠/句组合
            // 距离不变时不碰，保留灵活性
            return false;
          }
        }
      }

      // 手牌较少时更倾向碰
      return testHand.length <= 6;
    }

    // sameCharCount == 1: 只有一张同字牌，碰需要用2张
    // 这种情况实际是"碰"用1张手牌+出牌组成刻
    if (sameCharCount == 1) {
      final existingCard = hand.firstWhere(
        (c) => c.character == card.character,
      );

      // 检查该字是否参与已有的句/靠组合
      final remaining = List<Card>.from(hand);
      final aSet = <Meld>[];
      final bSet = <Meld>[];
      final cSet = <Meld>[];
      final dSet = <Meld>[];
      HuCalculator.extractJu(remaining, aSet);
      HuCalculator.extractZhao(remaining, bSet);
      HuCalculator.extractKan(remaining, cSet);
      HuCalculator.extractDuiAndKao(remaining, dSet);

      // 如果该字参与了句，碰掉会破坏句
      final inJu = aSet.any(
        (m) => m.cards.any((c) => c.character == card.character),
      );
      final inKao = dSet.any(
        (m) =>
            m.type == MeldType.kao &&
            m.cards.any((c) => c.character == card.character),
      );
      if (inJu || inKao) return false;

      final testHand = List<Card>.from(hand);
      testHand.removeWhere((c) => c.character == card.character);

      final newMeld = Meld(
        cards: [card, existingCard, existingCard],
        type: MeldType.kan,
        isJing: card.isJing,
      );

      final testPlayer = Player(
        id: player.id,
        name: player.name,
        type: player.type,
        hand: testHand,
        melds: [...player.melds, newMeld],
      );

      final tingAfter = TingChecker.checkTing(testPlayer);
      if (tingAfter.isTing) return true;

      final distBefore = _distanceToTing(List<Card>.from(hand), player.melds);
      final distAfter = _distanceToTing(testHand, [...player.melds, newMeld]);
      return distAfter <= distBefore;
    }

    return false;
  }

  @override
  bool shouldZhao(Player player, Card card, GameState state) {
    return _evaluateZhaoBenefit(player, card.character, state);
  }

  @override
  bool shouldZhaoFromHand(Player player, String character, GameState state) {
    return _evaluateZhaoBenefit(player, character, state);
  }

  bool _evaluateZhaoBenefit(Player player, String character, GameState state) {
    final hand = player.hand;
    final sameCharCount = hand.where((c) => c.character == character).length;

    // 只有3张同字牌时，检查是否有已有的刻可以招
    if (sameCharCount < 3) {
      final existingKan = player.melds.where(
        (m) => m.type == MeldType.kan && m.cards.first.character == character,
      );
      if (existingKan.isNotEmpty) return true; // 补招已有刻

      // 没有4张同字牌也没有已有刻，不能招
      return false;
    }

    // 有4张同字牌，评估招的收益
    final testHand = List<Card>.from(hand);
    final zhaoCards = testHand
        .where((c) => c.character == character)
        .take(4)
        .toList();
    for (final c in zhaoCards) {
      testHand.remove(c);
    }

    final newMeld = Meld(
      cards: zhaoCards,
      type: MeldType.zhao,
      isJing: zhaoCards.first.isJing,
    );

    final testPlayer = Player(
      id: player.id,
      name: player.name,
      type: player.type,
      hand: testHand,
      melds: [...player.melds, newMeld],
    );

    final tingAfter = TingChecker.checkTing(testPlayer);

    if (tingAfter.isTing) return true;
    if (player.isTing && !tingAfter.isTing) return false;

    final distBefore = _distanceToTing(List<Card>.from(hand), player.melds);
    final distAfter = _distanceToTing(testHand, [...player.melds, newMeld]);

    // 招牌后距离不能增加太多
    if (distAfter > distBefore + 1) return false;

    // 4张同字牌如果不招，只能组成1个刻+1张单牌，招了变成1个招
    // 招的胡数更高，通常值得招
    final huBefore = _evaluateHuScore(player);
    final huAfter = _evaluateHuScore(testPlayer);
    if (huAfter >= huBefore) return true;

    // 距离不变或减小也值得招
    return distAfter <= distBefore;
  }

  @override
  bool shouldHu(
    Player player,
    Card card,
    GameState state, {
    bool isZimo = false,
  }) {
    return true;
  }

  Map<String, int> _buildCharCount(List<Card> hand) {
    final result = <String, int>{};
    for (final card in hand) {
      result[card.character] = (result[card.character] ?? 0) + 1;
    }
    return result;
  }

  Map<int, Set<String>> _buildGroupCharSet(List<Card> hand) {
    final result = <int, Set<String>>{};
    for (final card in hand) {
      result.putIfAbsent(card.sentence, () => <String>{});
      result[card.sentence]!.add(card.character);
    }
    return result;
  }
}
