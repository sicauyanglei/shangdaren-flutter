import 'ai_strategy.dart';
import '../../models/card.dart';
import '../../models/game_state.dart';
import '../../models/player.dart';
import '../../models/meld.dart';
import '../ting_checker.dart';
import '../hu_calculator.dart';

class HandStats {
  final Map<String, int> charCount;
  final Map<int, Map<int, int>> sentencePosCount;
  final Map<int, int> sentenceTotal;
  final int totalCards;

  HandStats({
    required this.charCount,
    required this.sentencePosCount,
    required this.sentenceTotal,
    required this.totalCards,
  });

  static HandStats build(List<Card> hand) {
    final cc = <String, int>{};
    final spc = <int, Map<int, int>>{};
    final st = <int, int>{};
    for (final card in hand) {
      cc[card.character] = (cc[card.character] ?? 0) + 1;
      spc.putIfAbsent(card.sentence, () => {});
      spc[card.sentence]![card.position] =
          (spc[card.sentence]![card.position] ?? 0) + 1;
      st[card.sentence] = (st[card.sentence] ?? 0) + 1;
    }
    return HandStats(
      charCount: cc,
      sentencePosCount: spc,
      sentenceTotal: st,
      totalCards: hand.length,
    );
  }

  int charTotal(String ch) => charCount[ch] ?? 0;

  bool isKan(String ch) => charTotal(ch) >= 3;

  bool isZhao(String ch) => charTotal(ch) >= 4;

  bool hasSentence(int s) => sentenceTotal.containsKey(s);

  int sentenceCardCount(int s) => sentenceTotal[s] ?? 0;

  int posCount(int sentence, int position) =>
      sentencePosCount[sentence]?[position] ?? 0;

  Set<int> positionsInSentence(int sentence) =>
      sentencePosCount[sentence]?.keys.toSet() ?? {};

  int distinctCharsInSentence(int sentence) =>
      sentencePosCount[sentence]?.length ?? 0;
}

class _OpponentInfo {
  final bool isTing;
  final int meldCount;
  final Set<String> meldChars;
  final Set<int> meldSentences;
  final Set<String> discardChars;
  final Set<int> discardSentences;

  _OpponentInfo({
    required this.isTing,
    required this.meldCount,
    required this.meldChars,
    required this.meldSentences,
    required this.discardChars,
    required this.discardSentences,
  });
}

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

  Map<int, int> _distanceCache = {};
  Map<int, TingResult> _tingCache = {};
  Map<int, double> _huScoreCache = {};
  Map<String, int>? _cachedVisibleCount;
  int? _cachedTotalUnknown;
  HandStats? _cachedHandStats;
  int? _cacheOwnerId;

  List<_OpponentInfo>? _opponentInfos;

  void _buildOpponentInfos(Player player, GameState state) {
    _opponentInfos = [];
    for (int i = 0; i < state.players.length; i++) {
      if (i == player.id) continue;
      final other = state.players[i];
      final meldChars = <String>{};
      final meldSentences = <int>{};
      for (final meld in other.melds) {
        for (final c in meld.cards) {
          meldChars.add(c.character);
        }
        meldSentences.add(meld.cards.first.sentence);
      }
      final discardChars = <String>{};
      final discardSentences = <int>{};
      for (final dc in other.discards) {
        discardChars.add(dc.character);
        discardSentences.add(dc.sentence);
      }
      _opponentInfos!.add(_OpponentInfo(
        isTing: other.isTing,
        meldCount: other.melds.length,
        meldChars: meldChars,
        meldSentences: meldSentences,
        discardChars: discardChars,
        discardSentences: discardSentences,
      ));
    }
  }

  TingResult _checkTingCached(Player testPlayer) {
    int hash = testPlayer.melds.length;
    for (final card in testPlayer.hand) {
      hash = hash * 31 + card.id;
    }
    for (final m in testPlayer.melds) {
      hash = hash * 17 + m.cards.first.id;
    }
    final cached = _tingCache[hash];
    if (cached != null) return cached;
    final result = TingChecker.checkTing(testPlayer);
    _tingCache[hash] = result;
    return result;
  }

  Map<String, int> _buildVisibleCharCount(Player player, GameState state) {
    return state.buildVisibleCount(player);
  }

  void _initCache(Player player, GameState state) {
    _distanceCache.clear();
    _tingCache.clear();
    _huScoreCache.clear();
    _cachedVisibleCount = _buildVisibleCharCount(player, state);
    _cachedTotalUnknown = _totalUnknownCards(player, state);
    _cachedHandStats = HandStats.build(player.hand);
    _buildOpponentInfos(player, state);
    _cacheOwnerId = player.id;
  }

  int _handCacheKey(List<Card> hand, List<Meld> melds) {
    int hash = melds.length * 1000;
    for (final card in hand) {
      hash = hash * 31 + card.id;
    }
    for (final m in melds) {
      hash = hash * 17 + m.type.index * 100 + m.cards.first.id;
    }
    return hash;
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
    final stats = _cachedHandStats;
    if (stats != null) return stats.isKan(card.character);
    int count = 0;
    for (final c in hand) {
      if (c.character == card.character) count++;
    }
    return count >= 3;
  }

  bool _isPartOfZhao(Card card, List<Card> hand) {
    final stats = _cachedHandStats;
    if (stats != null) return stats.isZhao(card.character);
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
    final hash =
        player.hand.fold(0, (a, c) => a ^ c.id) ^
        player.melds.fold(0, (a, m) => a ^ m.cards.first.id);
    final cached = _huScoreCache[hash];
    if (cached != null) return cached;
    final result = HuCalculator.calculateTotalHu(player) * 1.0;
    _huScoreCache[hash] = result;
    return result;
  }

  (List<Card> bestHand, int bestDist) _findBestDiscardAfterMeld(
    List<Card> hand,
    List<Meld> melds,
  ) {
    if (hand.isEmpty) return (hand, _distanceToTing(hand, melds));

    int bestDist = 99;
    List<Card> bestHand = hand;

    for (final card in hand) {
      final testHand = List<Card>.from(hand);
      testHand.remove(card);
      final dist = _distanceToTing(testHand, melds);
      if (dist < bestDist) {
        bestDist = dist;
        bestHand = testHand;
      }
    }

    return (bestHand, bestDist);
  }

  @override
  Card selectDiscard(Player player, GameState state) {
    final hand = player.hand;
    if (hand.length <= 1) return hand.first;

    _initCache(player, state);

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
    final tingAfter = _checkTingCached(testPlayer);
    if (tingAfter.isTing) return 10000;

    final distBefore = _distanceToTing(List<Card>.from(hand), player.melds);

    final newMelds = [...player.melds, newMeld];
    final (bestHand, distAfterDiscard) = _findBestDiscardAfterMeld(
      testHand,
      newMelds,
    );

    if (distAfterDiscard >= distBefore + 1) return -1;

    double benefit = (distBefore - distAfterDiscard) * 250.0;

    if (distAfterDiscard <= 2) benefit += 600;
    if (distAfterDiscard <= 4) benefit += 250;

    final bestPlayer = Player(
      id: player.id,
      name: player.name,
      type: player.type,
      hand: bestHand,
      melds: newMelds,
    );
    benefit += _evaluateHuScore(bestPlayer) * 2;

    final totalUnknown = _totalUnknownCards(player, state);
    double chiAfterProb = 0;
    for (final c in bestHand) {
      final rem = _remainingCount(c.character, visibleCount);
      if (rem > 0) chiAfterProb += rem / totalUnknown;
    }
    benefit += chiAfterProb * 50;

    double chiBeforeProb = 0;
    for (final c in hand) {
      final rem = _remainingCount(c.character, visibleCount);
      if (rem > 0) chiBeforeProb += rem / totalUnknown;
    }
    final probLoss = chiBeforeProb - chiAfterProb;
    benefit -= probLoss * 80;

    benefit -= consumptionCost;

    return benefit;
  }

  Card _selectDiscardWhenTing(Player player, GameState state) {
    final hand = player.hand;
    final visibleCount =
        _cachedVisibleCount ?? _buildVisibleCharCount(player, state);
    final totalUnknown =
        _cachedTotalUnknown ?? _totalUnknownCards(player, state);

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

      final tingResult = _checkTingCached(testPlayer);
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

    final visibleCount =
        _cachedVisibleCount ?? _buildVisibleCharCount(player, state);
    final totalUnknown =
        _cachedTotalUnknown ?? _totalUnknownCards(player, state);
    final isLate = _isLateGame(state);

    final shiDuiPotential = _evaluateShiDuiPotential(
      player,
      state,
      visibleCount: visibleCount,
      totalUnknown: totalUnknown,
    );

    final availableChars = _buildAvailableChars(visibleCount);

    Card? bestTingCard;
    int bestTingRem = -1;
    double bestTingProb = -1;
    double bestTingHu = -1;
    final scored = <MapEntry<Card, double>>[];

    for (final card in hand) {
      if (_isPartOfZhao(card, hand)) {
        scored.add(MapEntry(card, -10000));
        continue;
      }
      if (_isPartOfKan(card, hand)) {
        scored.add(MapEntry(card, -5000));
        continue;
      }

      final testHand = List<Card>.from(hand);
      testHand.remove(card);
      final testPlayer = Player(
        id: player.id,
        name: player.name,
        type: player.type,
        hand: testHand,
        melds: player.melds,
      );

      final quickDist = _distanceToTing(testHand, player.melds);

      if (quickDist <= 2) {
        final tingResult = _checkTingCached(testPlayer);
        if (tingResult.isTing) {
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

          double tingScore = 10000 + tingProb * 1400;
          final effectiveTingCount = seenChars.length;
          tingScore += effectiveTingCount * 140;
          tingScore += huScore * 8;
          if (isLate) tingScore += 2800;
          scored.add(MapEntry(card, tingScore));
          continue;
        }
      }

      double score = _evaluateDiscardComprehensiveWithDist(
        player,
        card,
        testHand,
        testPlayer,
        quickDist,
        state,
        visibleCount,
        totalUnknown,
        isLate,
        shiDuiPotential,
        availableChars,
      );

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

    if (bestTingCard != null) return bestTingCard;

    scored.sort((a, b) => b.value.compareTo(a.value));
    return scored.first.key;
  }

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

    final distBefore = _distanceToTing(testHand, melds);
    if (distBefore > 6) return 0;

    final handGroups = <int>{};
    for (final card in testHand) {
      handGroups.add(card.sentence);
    }

    double totalScore = 0;

    for (final ch in availableChars) {
      final sentence = _charSentenceMap[ch];
      if (sentence == null) continue;

      final rem = _remainingCount(ch, visibleCount);
      if (rem <= 0) continue;

      final prob = rem / totalUnknown;

      if (!handGroups.contains(sentence)) {
        if (prob < 0.03) continue;

        final position = _charPositionMap[ch] ?? -1;
        if (position < 0) continue;

        final simHand = List<Card>.from(testHand);
        simHand.add(
          Card(id: -100, character: ch, sentence: sentence, position: position),
        );
        final dist = _distanceToTing(simHand, melds);
        final improvement = distBefore - dist;
        if (improvement > 0) {
          totalScore += prob * improvement * 75;
        }
        continue;
      }

      if (prob < 0.01) continue;

      final position = _charPositionMap[ch] ?? -1;
      if (position < 0) continue;

      final simHand = List<Card>.from(testHand);
      simHand.add(
        Card(id: -100, character: ch, sentence: sentence, position: position),
      );
      final dist = _distanceToTing(simHand, melds);

      if (dist <= 0) {
        totalScore += prob * 1200;
      } else {
        final improvement = distBefore - dist;
        if (improvement > 0) {
          totalScore += prob * improvement * 120;
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

  double _evaluateDiscardComprehensiveWithDist(
    Player player,
    Card cardToDiscard,
    List<Card> testHand,
    Player testPlayer,
    int quickDist,
    GameState state,
    Map<String, int> visibleCount,
    int totalUnknown,
    bool isLate,
    double shiDuiPotential,
    List<String> availableChars,
  ) {
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

    score += (10 - distToTing) * 125;

    if (isLate) {
      score += (10 - distToTing) * 145;
      if (distToTing <= 2) {
        score += 700;
      }
    }

    if (_isEarlyGame(state)) {
      final sameGroup = player.hand
          .where((c) => c.sentence == cardToDiscard.sentence)
          .toList();
      final groupCharSet = sameGroup.map((c) => c.character).toSet();
      if (groupCharSet.length >= 2) {
        score -= 30;
        if (groupCharSet.length >= 3) {
          score -= 20;
        }
      }
      final otherChars = _groupChars[cardToDiscard.sentence - 1]
          .where((ch) => ch != cardToDiscard.character)
          .toList();
      int partnerRem = 0;
      for (final ch in otherChars) {
        partnerRem += _remainingCount(ch, visibleCount);
      }
      if (partnerRem > 0) {
        score -= partnerRem * 3;
      }
      if (cardToDiscard.isJing) {
        score -= 20;
      }
    }

    score -= _evaluateDanger(
      player,
      cardToDiscard,
      state,
      isLate,
      myDist: distToTing,
    );

    if (distToTing > 0 && distToTing <= 4) {
      final expSteps = _expectedStepsToTing(
        testHand,
        player.melds,
        visibleCount,
        totalUnknown,
      );
      score += (10 - expSteps) * 50;
    }

    return score;
  }

  double _expectedStepsToTing(
    List<Card> hand,
    List<Meld> melds,
    Map<String, int> visibleCount,
    int totalUnknown,
  ) {
    final currentDist = _distanceToTing(hand, melds);
    if (currentDist <= 0) return 0;

    double totalImproveProb = 0;
    final handGroups = <int>{};
    for (final card in hand) {
      handGroups.add(card.sentence);
    }

    for (final ch in _allChars) {
      final sentence = _charSentenceMap[ch];
      if (sentence == null) continue;
      if (!handGroups.contains(sentence)) continue;

      final rem = _remainingCount(ch, visibleCount);
      if (rem <= 0) continue;

      final prob = rem / totalUnknown;
      final position = _charPositionMap[ch] ?? -1;
      if (position < 0) continue;

      final simHand = List<Card>.from(hand);
      simHand.add(
        Card(id: -100, character: ch, sentence: sentence, position: position),
      );
      final newDist = _distanceToTing(simHand, melds);
      final improvement = currentDist - newDist;
      if (improvement > 0) {
        totalImproveProb += prob * improvement;
      }
    }

    if (totalImproveProb <= 0.01) return currentDist * 2.0;
    return currentDist / totalImproveProb;
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
      final tingResult = _checkTingCached(testPlayer);

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

  double _evaluateDanger(
    Player player,
    Card cardToDiscard,
    GameState state,
    bool isLate, {
    int? myDist,
  }) {
    double danger = 0;
    final isMidGame = state.deck.length >= 20 && state.deck.length <= 50;
    final sameGroupChars = _groupChars[cardToDiscard.sentence - 1];
    final cardSentence = cardToDiscard.sentence;

    final opponents = _opponentInfos;
    if (opponents == null) return 0;

    for (final opp in opponents) {
      if (opp.isTing) {
        for (final mc in sameGroupChars) {
          if (opp.meldChars.contains(mc)) {
            danger += isLate ? 45 : 30;
            break;
          }
        }

        if (cardToDiscard.isJing) {
          danger += isLate ? 75 : 45;
        }

        if (_isYin(cardToDiscard)) {
          danger += isLate ? 30 : 15;
        }

        danger += isLate ? 30 : 15;

        if (opp.meldSentences.contains(cardSentence)) {
          danger += isLate ? 38 : 22;
        }
      }

      if (!opp.isTing && opp.meldCount >= 3) {
        danger += isLate ? 11 : 6;
      }

      if (isMidGame && !opp.isTing) {
        if (opp.meldSentences.contains(cardSentence) &&
            !opp.discardSentences.contains(cardSentence)) {
          danger += 7;
        }
      }

      int discardedByOther = 0;
      for (final gc in sameGroupChars) {
        if (opp.discardChars.contains(gc)) discardedByOther++;
      }
      if (discardedByOther == 0 && opp.meldCount > 0) {
        danger += isLate ? 11 : 6;
      }

      for (final gc in sameGroupChars) {
        if (opp.meldChars.contains(gc) && !opp.discardChars.contains(gc)) {
          danger += isLate ? 15 : 9;
          break;
        }
      }
    }

    if (player.isTing) {
      danger *= 0.12;
    }

    final actualMyDist =
        myDist ?? _distanceToTing(List<Card>.from(player.hand), player.melds);
    if (actualMyDist <= 2) {
      danger *= 0.2;
    } else if (actualMyDist <= 4) {
      danger *= 0.45;
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
    final key = _handCacheKey(hand, melds);
    final cached = _distanceCache[key];
    if (cached != null) return cached;

    final pairDist = _distanceToTingShiDui(hand, melds);
    final normalDist = _distanceToTingNormal(hand, melds);
    final result = pairDist < normalDist ? pairDist : normalDist;
    _distanceCache[key] = result;
    return result;
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
    int bestDist = 10;

    for (int mode = 0; mode < 2; mode++) {
      final remaining = List<Card>.from(hand);
      final aSet = <Meld>[];
      final bSet = <Meld>[];
      final cSet = <Meld>[];
      final dSet = <Meld>[];
      final eSet = <Card>[];

      HuCalculator.extractJu(remaining, aSet);
      HuCalculator.extractZhao(remaining, bSet);
      HuCalculator.extractKan(remaining, cSet);

      if (mode == 0) {
        HuCalculator.extractDuiAndKao(remaining, dSet);
      } else {
        HuCalculator.extractKaoFirst(remaining, dSet);
      }
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

      int potentialKaoFromSingles = 0;
      final singleByGroup = <int, List<Card>>{};
      for (final card in eSet) {
        singleByGroup.putIfAbsent(card.sentence, () => []).add(card);
      }
      for (final entry in singleByGroup.entries) {
        if (entry.value.length >= 2) {
          potentialKaoFromSingles += entry.value.length ~/ 2;
        }
      }

      int dist = neededMelds * 2 - usefulDuiKao - potentialKaoFromSingles;
      if (dist < 0) dist = 0;
      if (dist > 10) dist = 10;
      if (dist < bestDist) bestDist = dist;
    }

    return bestDist;
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
        totalScore += prob * 650;
      } else {
        totalScore += prob * (10 - dist) * 28;
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
    if (benefit < -30) return false;

    if (player.isTing) return benefit >= 7000;

    return benefit > -10;
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

      final tingAfter = _checkTingCached(testPlayer);

      if (tingAfter.isTing) return true;
      if (player.isTing && !tingAfter.isTing) return false;

      final distBefore = _distanceToTing(List<Card>.from(hand), player.melds);
      final newMelds = [...player.melds, newMeld];
      final (_, distAfterDiscard) = _findBestDiscardAfterMeld(
        testHand,
        newMelds,
      );

      if (distAfterDiscard > distBefore) return false;

      if (distAfterDiscard < distBefore) return true;

      final huScoreAfter = _evaluateHuScore(testPlayer);
      if (huScoreAfter > 0) return true;

      final charInHand = hand
          .where((c) => c.character == card.character)
          .length;
      if (charInHand >= 2) {
        final otherChars = _groupChars[card.sentence - 1]
            .where((ch) => ch != card.character)
            .toList();
        int partnerInHand = 0;
        for (final ch in otherChars) {
          if (hand.any((c) => c.character == ch)) {
            partnerInHand++;
          }
        }
        if (partnerInHand >= 2) {
          return false;
        }
      }

      return testHand.length <= 7;
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

      final tingAfter = _checkTingCached(testPlayer);
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

    if (sameCharCount < 3) {
      final existingKan = player.melds.where(
        (m) => m.type == MeldType.kan && m.cards.first.character == character,
      );
      if (existingKan.isNotEmpty) return true;

      return false;
    }

    if (sameCharCount >= 4) {
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

      final tingAfter = _checkTingCached(testPlayer);

      if (tingAfter.isTing) return true;
      if (player.isTing && !tingAfter.isTing) return false;

      final distBefore = _distanceToTing(List<Card>.from(hand), player.melds);
      final distAfter = _distanceToTing(testHand, [...player.melds, newMeld]);

      if (distAfter > distBefore + 1) return false;

      final kanHand = List<Card>.from(hand);
      final kanCards = kanHand
          .where((c) => c.character == character)
          .take(3)
          .toList();
      for (final c in kanCards) {
        kanHand.remove(c);
      }
      final kanMeld = Meld(
        cards: kanCards,
        type: MeldType.kan,
        isJing: kanCards.first.isJing,
      );
      final kanPlayer = Player(
        id: player.id,
        name: player.name,
        type: player.type,
        hand: kanHand,
        melds: [...player.melds, kanMeld],
      );

      final huZhao = _evaluateHuScore(testPlayer);
      final huKan = _evaluateHuScore(kanPlayer);
      final distKan = _distanceToTing(kanHand, [...player.melds, kanMeld]);

      if (huZhao >= huKan && distAfter <= distKan) return true;
      if (huZhao > huKan + 4) return true;
      if (distAfter < distKan) return true;

      return distAfter <= distBefore;
    }

    return true;
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

}
