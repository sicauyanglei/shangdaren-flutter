import 'dart:math' as math;

import 'ai_strategy.dart';
import '../../models/card.dart';
import '../../models/game_state.dart';
import '../../models/player.dart';
import '../../models/meld.dart';
import '../ting_checker.dart';
import '../hu_calculator.dart';
import '../../core/game_logger.dart';

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

  final Map<String, int> _distanceCache = {};
  final Map<String, TingResult> _tingCache = {};
  final Map<String, double> _huScoreCache = {};
  Map<String, int>? _cachedVisibleCount;
  int? _cachedTotalUnknown;
  Map<String, int>? _cachedCharCount;
  int? _cacheOwnerId;

  // 十对路线资格跟踪
  // 记录每个玩家是否已获得十对路线资格（发牌后6对 或 前3回合内出现6对）
  final Map<int, bool> _shiDuiEligible = {};
  int? _lastRoundNumber;
  // 当前决策玩家的十对路线是否启用
  bool _currentShiDuiEnabled = false;

  String _tingCacheKey(Player player) {
    return _handCacheKey(player.hand, player.melds);
  }

  TingResult _checkTingCached(Player testPlayer) {
    final key = _tingCacheKey(testPlayer);
    final cached = _tingCache[key];
    if (cached != null) return cached;
    final result = TingChecker.checkTing(testPlayer);
    _tingCache[key] = result;
    return result;
  }

  Map<String, int> _buildVisibleCharCount(Player player, GameState state) {
    return state.buildVisibleCount(player);
  }

  void _initCache(Player player, GameState state) {
    // 检测新局开始，重置十对资格
    if (_lastRoundNumber != state.roundNumber) {
      _shiDuiEligible.clear();
      _lastRoundNumber = state.roundNumber;
    }

    _distanceCache.clear();
    _tingCache.clear();
    _huScoreCache.clear();
    _cachedVisibleCount = _buildVisibleCharCount(player, state);
    _cachedTotalUnknown = _totalUnknownCards(player, state);
    _cachedCharCount = _buildCharCount(player.hand);
    _cacheOwnerId = player.id;
    _currentShiDuiEnabled = _isShiDuiEligible(player);
  }

  /// 检查玩家是否有资格走十对路线
  /// 条件1：发牌后手牌至少6对（discards.length==0时检查）
  /// 条件2：前3个回合内（discards.length<=3）手牌出现6对以上
  /// 禁用条件：组合牌区已有牌
  bool _isShiDuiEligible(Player player) {
    // 组合牌区有牌，彻底不考虑十对路线
    if (player.melds.isNotEmpty) return false;

    // 已经获得资格
    if (_shiDuiEligible[player.id] == true) return true;

    final pairCount = _countHandPairsWithMelds(player);

    // 前3个回合内（含发牌时）持续检查
    if (player.discards.length <= 3) {
      if (pairCount >= 6) {
        _shiDuiEligible[player.id] = true;
        return true;
      }
      return false;
    }

    // 超过3个回合且未达到6对，不再考虑十对路线
    return false;
  }

  /// 从手牌计算对子数（十对路线专用，不从组合牌算对子）
  /// 十对要求是手牌10对，组合牌不参与十对计算
  int _countPairsFromHandAndMelds(List<Card> hand, List<Meld> melds) {
    final byChar = <String, int>{};
    for (final card in hand) {
      byChar[card.character] = (byChar[card.character] ?? 0) + 1;
    }
    int pairs = 0;
    for (final count in byChar.values) {
      if (count == 2) pairs++;
      if (count == 3) pairs++; // 三张可拆成1对+1单
      if (count == 4) pairs += 2;
    }
    // 十对只看手牌，不从组合牌算对子
    return pairs;
  }

  String _handCacheKey(List<Card> hand, List<Meld> melds) {
    final byChar = <String, int>{};
    for (final card in hand) {
      byChar[card.character] = (byChar[card.character] ?? 0) + 1;
    }
    final keys = byChar.keys.toList()..sort();
    final buf = StringBuffer();
    for (final k in keys) {
      buf.write('$k${byChar[k]}');
    }
    buf.write('m${melds.length}');
    for (final m in melds) {
      buf.write('${m.type.index}${m.cards.first.character}${m.isJing ? 1 : 0}');
    }
    return buf.toString();
  }

  int _remainingCount(String character, Map<String, int> visibleCount) {
    final rem = 4 - (visibleCount[character] ?? 0);
    return rem > 0 ? rem : 0;
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

  /// 计算手牌中的对子数（十对路线专用，不从组合牌算对子）
  /// 十对要求是手牌10对，组合牌不参与十对计算
  int _countHandPairsWithMelds(Player player) {
    final byChar = <String, int>{};
    for (final card in player.hand) {
      byChar[card.character] = (byChar[card.character] ?? 0) + 1;
    }
    int pairs = 0;
    for (final count in byChar.values) {
      if (count == 2) pairs++;
      if (count == 3) pairs++; // 三张可拆成1对+1单，十对路线中算1对
      if (count == 4) pairs += 2;
    }
    // 十对只看手牌，不从组合牌算对子
    return pairs;
  }

  bool _isPartOfKan(Card card, List<Card> hand) {
    final cc = _cachedCharCount;
    if (cc != null) return (cc[card.character] ?? 0) >= 3;
    int count = 0;
    for (final c in hand) {
      if (c.character == card.character) count++;
    }
    return count >= 3;
  }

  bool _isPartOfZhao(Card card, List<Card> hand) {
    final cc = _cachedCharCount;
    if (cc != null) return (cc[card.character] ?? 0) >= 4;
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
    // 必须有十对路线资格
    if (!_isShiDuiEligible(player)) return -1;

    final pairCount = _countHandPairsWithMelds(player);
    if (pairCount < 6) return -1;

    final vc = visibleCount ?? _buildVisibleCharCount(player, state);
    final tu = totalUnknown ?? _totalUnknownCards(player, state);

    final byChar = <String, int>{};
    for (final card in player.hand) {
      byChar[card.character] = (byChar[card.character] ?? 0) + 1;
    }

    double prob = 0;
    int zeroRemCount = 0;
    for (final entry in byChar.entries) {
      if (entry.value == 1) {
        final rem = _remainingCount(entry.key, vc);
        if (rem > 0 && tu > 0) {
          prob += rem / tu;
        } else {
          zeroRemCount++;
        }
      }
    }

    double score = pairCount * 80.0 + prob * 200;
    if (pairCount >= 9) score += 500;
    if (pairCount >= 8) score += 200;

    // 需要凑对的单牌剩余张数为0时，十对路线可行性大幅降低
    // zeroRemCount>=2时十对路线已不可能完成，直接返回-1
    if (zeroRemCount >= 2) {
      return -1;
    } else if (zeroRemCount == 1) {
      score -= 60;
    }

    return score;
  }

  /// 评估黑元路线潜力：返回>0表示有黑元潜力
  /// 黑元条件：无碰无招（或招但effectiveHasZhao=false），且所有牌都不属于组1/组8，且无"上"/"福"
  /// 主动黑元策略：发牌后门1+门8张数<=3且总胡数<=4胡时，主动追求黑元，优先清理门1/8牌
  double _evaluateHeiYuanPotential(Player player) {
    // 有碰则不能黑元
    final hasPeng = player.melds.any((m) => m.type == MeldType.kan);
    if (hasPeng) return -1;

    // 检查所有牌（手牌+组合牌）是否都属于组2-7，且无"上"/"福"
    final allCards = [...player.hand, ...player.melds.expand((m) => m.cards)];
    bool hasGroup18 = false;
    int group18Count = 0;
    for (final c in allCards) {
      if (c.sentence == 1 || c.sentence == 8) {
        hasGroup18 = true;
        group18Count++;
      }
      if (c.character == '上' || c.character == '福') {
        // 有精字，检查是否还能清理
      }
    }

    // 满足黑元路线的基本条件（无门1/8牌），返回一个正值表示有潜力
    // 潜力值与已有句数相关，越多句潜力越大
    if (!hasGroup18) {
      int sentenceCount = 0;
      for (final meld in player.melds) {
        if (meld.type == MeldType.ju) sentenceCount++;
      }
      // 手牌中的句数估算
      final handRemaining = List<Card>.from(player.hand);
      final handASet = <Meld>[];
      HuCalculator.extractJu(handRemaining, handASet);
      sentenceCount += handASet.length;

      return 100.0 + sentenceCount * 50.0;
    }

    // 主动黑元策略：门1+门8张数<=3且总胡数<=4胡时，主动追求黑元
    // 返回较低潜力值，引导AI优先清理门1/8牌
    if (group18Count <= 3) {
      final totalHu = _evaluateHuScore(player);
      if (totalHu <= 4) {
        // 返回主动黑元潜力，值低于完全黑元(100)，但足以触发黑元路线加分
        int sentenceCount = 0;
        for (final meld in player.melds) {
          if (meld.type == MeldType.ju) sentenceCount++;
        }
        final handRemaining = List<Card>.from(player.hand);
        final handASet = <Meld>[];
        HuCalculator.extractJu(handRemaining, handASet);
        sentenceCount += handASet.length;
        // 门1/8牌越少，潜力越高（越接近完全黑元）
        return 50.0 + sentenceCount * 30.0 + (3 - group18Count) * 10.0;
      }
    }

    return -1;
  }

  /// 评估红元路线潜力：返回>0表示有红元潜力
  /// 红元条件：无碰无招（或招但effectiveHasZhao=false），组合牌全是句
  /// 组1/组8句>=2，上/福总数3-6张，6句+1靠结构
  double _evaluateHongYuanPotential(Player player) {
    final hasPeng = player.melds.any((m) => m.type == MeldType.kan);
    final hasZhao = player.melds.any((m) => m.type == MeldType.zhao);
    if (hasPeng || hasZhao) return -1;

    // 组合牌必须全是句
    if (player.melds.isNotEmpty &&
        !player.melds.every((m) => m.type == MeldType.ju)) {
      return -1;
    }

    int shangDaRenSentenceCount = 0;
    int fuLuShouSentenceCount = 0;
    int totalSentenceCount = 0;

    for (final meld in player.melds) {
      if (meld.type == MeldType.ju) {
        totalSentenceCount++;
        final sentence = meld.cards.first.sentence;
        if (sentence == 1) shangDaRenSentenceCount++;
        if (sentence == 8) fuLuShouSentenceCount++;
      }
    }

    // 手牌中的句数估算
    final handRemaining = List<Card>.from(player.hand);
    final usedIds = <int>{};
    bool foundGroup = true;
    while (foundGroup) {
      foundGroup = false;
      for (var s = 1; s <= 8; s++) {
        final sentenceCards = handRemaining
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
    if (totalSpecialSentenceCount < 2) return -1;

    final allCards = [...player.hand, ...player.melds.expand((m) => m.cards)];
    final shangCount = allCards.where((c) => c.character == '上').length;
    final fuCount = allCards.where((c) => c.character == '福').length;
    final shangFuCount = shangCount + fuCount;

    if (shangFuCount < 3 || shangFuCount > 6) return -1;

    // 红元潜力与特殊句数和上/福数量正相关
    return 80.0 + totalSpecialSentenceCount * 40.0 + shangFuCount * 15.0;
  }

  /// 评估枯胡路线潜力：返回>0表示有枯胡潜力
  /// 枯胡条件：无吃，有上/福，手牌无单张无4张，6坎+1对
  double _evaluateKuHuPotential(Player player) {
    final hasChi = player.melds.any((m) => m.type == MeldType.ju);
    if (hasChi) return -1;

    final allCards = [...player.hand, ...player.melds.expand((m) => m.cards)];
    if (!allCards.any((c) => c.character == '上' || c.character == '福')) {
      return -1;
    }

    final counts = <String, int>{};
    for (final card in player.hand) {
      counts[card.character] = (counts[card.character] ?? 0) + 1;
    }

    for (final count in counts.values) {
      if (count == 1) return -1;
      if (count >= 4) return -1;
    }

    int kanCount = 0;
    int duiCount = 0;
    int zhaoCount = 0;

    for (final count in counts.values) {
      if (count == 3) {
        kanCount++;
      } else if (count == 2) {
        duiCount++;
      }
    }

    for (final meld in player.melds) {
      if (meld.type == MeldType.kan) {
        kanCount++;
      } else if (meld.type == MeldType.zhao) {
        zhaoCount++;
      }
    }

    // 枯胡需要6坎+1对，评估接近程度
    final totalKanZhao = kanCount + zhaoCount;
    if (totalKanZhao + duiCount < 5) return -1;

    // 距离目标：6坎+1对
    final dist = (6 - totalKanZhao).abs() + (1 - duiCount).abs();
    if (dist > 3) return -1;

    return 120.0 - dist * 30.0;
  }

  double _evaluateHuScore(Player player) {
    final key = _handCacheKey(player.hand, player.melds);
    final cached = _huScoreCache[key];
    if (cached != null) return cached;
    // 确保meldHuCount已正确初始化，避免新建Player对象时meldHuCount=0导致胡数计算错误
    if (player.melds.isNotEmpty && player.meldHuCount == 0) {
      HuCalculator.updateMeldHuCache(player);
    }
    final result = HuCalculator.calculateTotalHu(player) * 1.0;
    _huScoreCache[key] = result;
    return result;
  }

  (List<Card> bestHand, int bestDist) _findBestDiscardAfterMeld(
    List<Card> hand,
    List<Meld> melds, {
    Map<String, int>? visibleCount,
    int? totalUnknown,
  }) {
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
      } else if (dist == bestDist &&
          visibleCount != null &&
          totalUnknown != null) {
        // 距离相同时，优先出进张少的牌（保留进张多的牌）
        final discardGroup = card.sentence;
        int discardRem = 0;
        for (final ch in _groupChars[discardGroup - 1]) {
          if (!testHand.any((c) => c.character == ch)) {
            discardRem += _remainingCount(ch, visibleCount);
          }
        }
        final bestCard = bestHand.isNotEmpty
            ? hand.firstWhere(
                (c) => !bestHand.contains(c),
                orElse: () => hand.first,
              )
            : hand.first;
        final bestGroup = bestCard.sentence;
        int bestRem = 0;
        for (final ch in _groupChars[bestGroup - 1]) {
          if (!bestHand.any((c) => c.character == ch)) {
            bestRem += _remainingCount(ch, visibleCount);
          }
        }
        // 出进张少的牌，保留进张多的
        if (discardRem < bestRem) {
          bestDist = dist;
          bestHand = testHand;
        }
      }
    }

    return (bestHand, bestDist);
  }

  @override
  Card selectDiscard(Player player, GameState state) {
    final hand = player.hand;
    if (hand.isEmpty) throw StateError('Empty hand');
    if (hand.length == 1) return hand.first;

    _initCache(player, state);

    if (player.isTing) {
      return _selectDiscardWhenTing(player, state);
    }

    return _selectDiscardOptimized(player, state);
  }

  /// 评估吃牌后的手牌质量（指定消耗的字）
  double _evaluateChiBenefitWithChars(
    Player player,
    Card card,
    List<String> neededChars,
    GameState state,
  ) {
    final hand = player.hand;
    final hasAll = neededChars.every(
      (ch) => hand.any((c) => c.character == ch),
    );
    if (!hasAll) return -1;

    // 评估吃牌前被消耗的牌在其他组合中的价值
    double consumptionCost = 0;
    final visibleCount = _buildVisibleCharCount(player, state);

    // 一次性提取手牌的所有组合，避免重复计算
    final handRemaining0 = List<Card>.from(hand);
    final handASet0 = <Meld>[];
    final handCSet0 = <Meld>[];
    HuCalculator.extractJu(handRemaining0, handASet0);
    HuCalculator.extractKan(handRemaining0, handCSet0);

    for (final ch in neededChars) {
      final chCount = hand.where((c) => c.character == ch).length;

      // 检查该字是否参与了已有的句组合
      final inJu = handASet0.any((m) => m.cards.any((c) => c.character == ch));
      if (inJu) {
        consumptionCost += 80;
      }

      // 检查该字是否参与了已有的坎组合（3张同字）
      // 吃掉1张会破坏坎，坎在手牌=3胡，损失很大
      final inKan = handCSet0.any((m) => m.cards.any((c) => c.character == ch));
      if (inKan) {
        // 破坏坎的代价：3胡损失 + 重组困难
        consumptionCost += 100;
      }

      // 检查该字是否有对子，吃掉会破坏对子
      if (chCount >= 2 && !inJu && !inKan) {
        final rem = _remainingCount(ch, visibleCount);
        consumptionCost += 20 + rem * 5;
      }

      // 检查该字是否参与了其他靠组合
      final sameGroupInHand = hand
          .where((c) => c.sentence == _charSentenceMap[ch] && c.character != ch)
          .toList();
      if (sameGroupInHand.isNotEmpty && chCount < 2) {
        consumptionCost += 30;
      }
      if (chCount >= 2 && !inKan) {
        consumptionCost -= 20;
      }

      // 剩余张数越少，吃掉该牌的代价越高（稀缺牌价值更大）
      final chRem = _remainingCount(ch, visibleCount);
      if (chRem == 0) {
        consumptionCost += 30; // 绝版牌，吃掉后无法再获得
      } else if (chRem <= 1) {
        consumptionCost += 15;
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

    final tingAfter = _checkTingCached(testPlayer);
    if (tingAfter.isTing) return 10000;

    final distBefore = _distanceToTing(List<Card>.from(hand), player.melds);
    final normalBefore = _distanceToTingNormal(hand, player.melds);
    final newMelds = [...player.melds, newMeld];
    final totalUnknown = _totalUnknownCards(player, state);
    final (bestHand, distAfterDiscard) = _findBestDiscardAfterMeld(
      testHand,
      newMelds,
      visibleCount: visibleCount,
      totalUnknown: totalUnknown,
    );

    if (distAfterDiscard > distBefore) {
      // 吃牌可能破坏十对路线但改善普通路线
      // 如果普通路线距离不增加，仍然允许吃牌
      final normalAfter = _distanceToTingNormal(bestHand, newMelds);
      if (normalAfter > normalBefore) return -1;
    }

    double benefit = (distBefore - distAfterDiscard) * 300.0;
    if (distAfterDiscard == distBefore) benefit += 100;
    if (distAfterDiscard <= 2) benefit += 800;
    if (distAfterDiscard <= 4) benefit += 300;

    final bestPlayer = Player(
      id: player.id,
      name: player.name,
      type: player.type,
      hand: bestHand,
      melds: newMelds,
    );
    benefit += _evaluateHuScore(bestPlayer) * 8;
    if (newMeld.isJing) benefit += 80;

    double chiAfterProb = 0;
    if (totalUnknown > 0) {
      for (final c in bestHand) {
        final rem = _remainingCount(c.character, visibleCount);
        if (rem > 0) chiAfterProb += rem / totalUnknown;
      }
    }
    benefit += chiAfterProb * 80;

    double chiBeforeProb = 0;
    if (totalUnknown > 0) {
      for (final c in hand) {
        final rem = _remainingCount(c.character, visibleCount);
        if (rem > 0) chiBeforeProb += rem / totalUnknown;
      }
    }
    final probLoss = chiBeforeProb - chiAfterProb;
    benefit -= probLoss * 50;
    benefit -= consumptionCost;

    return benefit;
  }

  /// 评估吃牌后的手牌质量（自动选择消耗的字）
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

    // 一次性提取手牌的所有组合，避免重复计算
    final handRemaining0 = List<Card>.from(hand);
    final handASet0 = <Meld>[];
    final handCSet0 = <Meld>[];
    HuCalculator.extractJu(handRemaining0, handASet0);
    HuCalculator.extractKan(handRemaining0, handCSet0);

    for (final ch in neededChars) {
      final chCount = hand.where((c) => c.character == ch).length;

      // 检查该字是否参与了已有的句组合
      final inJu = handASet0.any((m) => m.cards.any((c) => c.character == ch));
      if (inJu) {
        // 吃牌破坏了已有的句，代价很高
        consumptionCost += 80;
      }

      // 检查该字是否参与了已有的坎组合（3张同字）
      // 吃掉1张会破坏坎，坎在手牌=3胡，损失很大
      final inKan = handCSet0.any((m) => m.cards.any((c) => c.character == ch));
      if (inKan) {
        // 破坏坎的代价：3胡损失 + 重组困难
        consumptionCost += 100;
      }

      // 检查该字是否有对子，吃掉会破坏对子
      if (chCount >= 2 && !inJu && !inKan) {
        // 对子被吃掉1张变单张，损失对子价值
        final rem = _remainingCount(ch, visibleCount);
        // 对子变坎的进张数，如果进张多损失更大
        consumptionCost += 20 + rem * 5;
      }

      // 检查该字是否参与了其他靠组合
      final sameGroupInHand = hand
          .where((c) => c.sentence == _charSentenceMap[ch] && c.character != ch)
          .toList();
      if (sameGroupInHand.isNotEmpty && chCount < 2) {
        consumptionCost += 30;
      }
      // 如果该字在手牌中有2张以上，吃掉1张损失较小
      if (chCount >= 2 && !inKan) {
        consumptionCost -= 20;
      }

      // 剩余张数越少，吃掉该牌的代价越高（稀缺牌价值更大）
      final chRem = _remainingCount(ch, visibleCount);
      if (chRem == 0) {
        consumptionCost += 30; // 绝版牌，吃掉后无法再获得
      } else if (chRem <= 1) {
        consumptionCost += 15;
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
    final totalUnknown = _totalUnknownCards(player, state);
    final (bestHand, distAfterDiscard) = _findBestDiscardAfterMeld(
      testHand,
      newMelds,
      visibleCount: visibleCount,
      totalUnknown: totalUnknown,
    );

    if (distAfterDiscard > distBefore) {
      // 吃牌可能破坏十对路线但改善普通路线
      // 如果普通路线距离不增加，仍然允许吃牌
      final normalBefore = _distanceToTingNormal(hand, player.melds);
      final normalAfter = _distanceToTingNormal(bestHand, newMelds);
      if (normalAfter > normalBefore) return -1;
    }

    double benefit = (distBefore - distAfterDiscard) * 300.0;

    // 距离不变时也有基础收益（吃牌增加面子，向胡牌推进）
    if (distAfterDiscard == distBefore) {
      benefit += 100;
    }

    if (distAfterDiscard <= 2) benefit += 800;
    if (distAfterDiscard <= 4) benefit += 300;

    final bestPlayer = Player(
      id: player.id,
      name: player.name,
      type: player.type,
      hand: bestHand,
      melds: newMelds,
    );
    benefit += _evaluateHuScore(bestPlayer) * 8;

    // 精句额外加分
    if (newMeld.isJing) benefit += 80;

    double chiAfterProb = 0;
    if (totalUnknown > 0) {
      for (final c in bestHand) {
        final rem = _remainingCount(c.character, visibleCount);
        if (rem > 0) chiAfterProb += rem / totalUnknown;
      }
    }
    benefit += chiAfterProb * 80;

    double chiBeforeProb = 0;
    if (totalUnknown > 0) {
      for (final c in hand) {
        final rem = _remainingCount(c.character, visibleCount);
        if (rem > 0) chiBeforeProb += rem / totalUnknown;
      }
    }
    final probLoss = chiBeforeProb - chiAfterProb;
    benefit -= probLoss * 50;

    benefit -= consumptionCost;

    return benefit;
  }

  Card _selectDiscardWhenTing(Player player, GameState state) {
    final hand = player.hand;
    final visibleCount =
        _cachedVisibleCount ?? _buildVisibleCharCount(player, state);
    final totalUnknown =
        _cachedTotalUnknown ?? _totalUnknownCards(player, state);

    // 出牌前的胡数，用于胡数资格保护
    final huBefore = _evaluateHuScore(player);
    // 检查特殊胡牌类型潜力（十对、黑元、红元、枯胡不受胡数>=11限制）
    final shiDuiPotential = _evaluateShiDuiPotential(
      player,
      state,
      visibleCount: visibleCount,
      totalUnknown: totalUnknown,
    );
    final heiYuanPotential = _evaluateHeiYuanPotential(player);
    final hongYuanPotential = _evaluateHongYuanPotential(player);
    final kuHuPotential = _evaluateKuHuPotential(player);

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

      // 胡数资格保护：出牌破坏胡数资格时跳过（特殊胡牌类型除外）
      final huAfter = _evaluateHuScore(testPlayer);
      if (huBefore >= 11 &&
          huAfter < 11 &&
          shiDuiPotential <= 0 &&
          heiYuanPotential <= 0 &&
          hongYuanPotential <= 0 &&
          kuHuPotential <= 0) {
        continue;
      }

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
          if (totalUnknown > 0) tingProb += rem / totalUnknown;
        }
      }

      // 单钓听限制：单钓听时，不能胡单钓的这张字（只能自摸）
      // 降低单钓听的听牌数评估，因为点炮不可胡
      if (tingResult.tingType == TingType.singleWait) {
        // 单钓听只有自摸有效，点炮不可胡
        // 将听牌数减半评估，因为点炮场景无法胡牌
        tingCount = (tingCount * 0.5).ceil();
        tingProb *= 0.5;
      }

      // 复用前面计算的huAfter，避免重复计算
      final huScore = huAfter;

      // 检查特殊胡型潜力（高胡数路线给予额外加分）
      // 使用_evaluateHuScore确保meldHuCount已正确初始化
      final totalHu = huScore.toInt();
      double specialHuBonus = 0;
      if (totalHu >= 20)
        specialHuBonus += 150;
      else if (totalHu >= 15)
        specialHuBonus += 80;

      // 优先选择听牌数多的，进张数相近(差距<=1)时优先高胡数路线
      // 简化为明确的优先级链，避免条件覆盖漏洞
      final effectiveScore = huScore + specialHuBonus;
      bool shouldSelect = false;
      if (bestCard == null) {
        shouldSelect = true;
      } else if (tingCount > bestTingCount + 1) {
        // 听牌数多2张以上，直接选
        shouldSelect = true;
      } else if (tingCount == bestTingCount + 1) {
        // 听牌数多1张，只要胡数不低于当前（允许持平）
        shouldSelect = effectiveScore >= bestHuScore;
      } else if (tingCount == bestTingCount) {
        if (tingProb > bestTingProb + 0.001) {
          // 听牌数相同，进张概率更高
          shouldSelect = true;
        } else if ((tingProb - bestTingProb).abs() <= 0.001) {
          // 进张概率相同，选胡数更高的
          shouldSelect = effectiveScore > bestHuScore;
        }
      } else if (tingCount + 1 == bestTingCount) {
        // 听牌数少1张，需要胡数显著更高才选
        shouldSelect = effectiveScore > bestHuScore + 8;
      }

      if (shouldSelect) {
        bestCard = card;
        bestTingCount = tingCount;
        bestTingProb = tingProb;
        bestHuScore = effectiveScore;
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
    if (hand.isEmpty) throw StateError('Empty hand');
    if (hand.length == 1) return hand.first;

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

    // 黑元路线潜力（特殊胡牌类型，不受胡数>=11限制）
    final heiYuanPotential = _evaluateHeiYuanPotential(player);
    // 红元路线潜力（特殊胡牌类型）
    final hongYuanPotential = _evaluateHongYuanPotential(player);
    // 枯胡路线潜力（特殊胡牌类型）
    final kuHuPotential = _evaluateKuHuPotential(player);

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
        // 十对路线中，坎的字牌剩余为0时（无法变招），允许拆坎变对子
        if (shiDuiPotential > 0) {
          final kanRem = _remainingCount(card.character, visibleCount);
          if (kanRem <= 0) {
            // 坎剩余为0，不保护，继续评估（拆坎出单张，保留对子）
          } else {
            scored.add(MapEntry(card, -5000));
            continue;
          }
        } else {
          scored.add(MapEntry(card, -5000));
          continue;
        }
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
              if (totalUnknown > 0) tingProb += rem / totalUnknown;
            }
          }
          final huScore = _evaluateHuScore(testPlayer);

          // 胡数资格保护：听牌但胡数不足时，降低听牌评分
          // 特殊胡牌类型（十对、黑元、红元、枯胡）不受胡数>=11限制
          double huQualifyPenalty = 0;
          bool huQualifyMet = true;
          if (huScore < 11 &&
              shiDuiPotential <= 0 &&
              heiYuanPotential <= 0 &&
              hongYuanPotential <= 0 &&
              kuHuPotential <= 0) {
            // 听牌但胡数不足，无法胡牌，大幅降低评分
            huQualifyPenalty = -8000;
            huQualifyMet = false;
          }

          // 只有胡数资格满足时，才考虑作为bestTingCard
          if (huQualifyMet &&
              (tingRem > bestTingRem ||
                  (tingRem == bestTingRem && tingProb > bestTingProb) ||
                  (tingRem == bestTingRem &&
                      tingProb == bestTingProb &&
                      huScore > bestTingHu))) {
            bestTingCard = card;
            bestTingRem = tingRem;
            bestTingProb = tingProb;
            bestTingHu = huScore;
          }

          double tingScore = 10000 + tingProb * 2000;
          final effectiveTingCount = seenChars.length;
          tingScore += effectiveTingCount * 200;
          tingScore += huScore * 10;
          if (isLate) tingScore += 3000;
          tingScore += huQualifyPenalty;
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
        heiYuanPotential,
        hongYuanPotential,
        kuHuPotential,
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

    // 调试日志：打印所有候选牌的评分
    final handStr = hand.map((c) => c.character).join();
    GameLogger.i(
      'AI_DISCARD',
      'selectDiscard: hand=$handStr, melds=${player.melds.map((m) => m.cards.map((c) => c.character).join()).join(',')}',
    );
    for (final entry in scored) {
      GameLogger.i(
        'AI_DISCARD',
        '  card=${entry.key.character} score=${entry.value.toStringAsFixed(1)}',
      );
    }
    GameLogger.i('AI_DISCARD', '  => selected: ${scored.first.key.character}');

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
    if (distBefore > 5) return 0;

    final handGroups = <int>{};
    for (final card in testHand) {
      handGroups.add(card.sentence);
    }

    double totalScore = 0;

    for (final ch in availableChars) {
      final sentence = _charSentenceMap[ch];
      if (sentence == null) continue;

      final rem = _remainingCount(ch, visibleCount);
      if (rem <= 0 || totalUnknown <= 0) continue;

      final prob = rem / totalUnknown;

      // 剩余张数越少，摸到后的价值越高（稀缺性加成）
      // rem=1时加成1.5倍，rem=2时加成1.2倍，rem>=3时无加成
      double scarcityBonus = 1.0;
      if (rem == 1) {
        scarcityBonus = 1.5;
      } else if (rem == 2) {
        scarcityBonus = 1.2;
      }

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
          totalScore += prob * improvement * 60 * scarcityBonus;
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
        totalScore += prob * 1000 * scarcityBonus;
      } else {
        final improvement = distBefore - dist;
        if (improvement > 0) {
          totalScore += prob * improvement * 100 * scarcityBonus;
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
    double heiYuanPotential,
    double hongYuanPotential,
    double kuHuPotential,
  ) {
    final (potential, distToTing) = _evaluateHandPotentialAndDistance(
      testHand,
      player.melds,
      visibleCount,
      totalUnknown,
    );

    double score = potential;

    // 门结构评分补充（按 men-structure-score.md 规则）
    // 计算出牌后所有门的结构总分变化，作为细粒度门级评估
    final menScoreAfter = _evaluateAllMenStructure(
      testHand,
      player.melds,
      visibleCount,
      totalUnknown,
    );
    final menScoreBefore = _evaluateAllMenStructure(
      player.hand,
      player.melds,
      visibleCount,
      totalUnknown,
    );
    // 门结构分变化作为补充评分，权重适中避免覆盖主评分
    score += (menScoreAfter - menScoreBefore) * 0.3;

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

    // 破坏完整句惩罚：出牌导致手牌中某个完整句被拆散时，施加惩罚
    // 完整句是已确定的面子，拆散它意味着需要重新摸牌来补回，代价很大
    {
      final discardGroup = cardToDiscard.sentence;
      final discardGroupCards = player.hand
          .where((c) => c.sentence == discardGroup)
          .toList();
      final discardGroupCharSet = discardGroupCards
          .map((c) => c.character)
          .toSet();
      if (discardGroupCharSet.length == 3) {
        // 该组有3种字，检查出牌的字是否真的会破坏句
        // 只有当出牌的字只有1张时，出掉才会破坏句(3字各1张=完整句)
        // 如果出牌的字有2张以上，出1张后仍保留1张，句不破坏(句+对子结构)
        final discardCountInGroup = discardGroupCards
            .where((c) => c.character == cardToDiscard.character)
            .length;
        if (discardCountInGroup == 1) {
          // 出牌的字只有1张，出掉会破坏句，施加惩罚
          // 惩罚力度：距离越近越不应该拆句
          if (quickDist <= 2) {
            score -= 300;
          } else if (quickDist <= 4) {
            score -= 200;
          } else {
            score -= 100;
          }
        }
        // discardCountInGroup >= 2 时，出1张不破坏句(句+对子结构)，不惩罚
      } else if (discardGroupCharSet.length == 2) {
        // 出牌前该组有2种不同字，可能是靠或对子+单张
        final discardCountInGroup = discardGroupCards
            .where((c) => c.character == cardToDiscard.character)
            .length;
        // 出靠的单张(discardCountInGroup==1)会破坏靠，无论是否有对子
        // 纯靠(无对子)或对子+靠(有对子)出单张都破坏靠
        final breaksKao = discardCountInGroup == 1;
        if (breaksKao) {
          // 出这张牌会破坏靠，检查缺失字的剩余张数
          final missingChars = _groupChars[discardGroup - 1]
              .where((ch) => !discardGroupCharSet.contains(ch))
              .toList();
          int missingRem = 0;
          for (final ch in missingChars) {
            missingRem += _remainingCount(ch, visibleCount);
          }
          if (missingRem > 0) {
            // 判断靠的进张目标价值：精句(4胡) vs 普句(0胡)
            // 门1(上大人)/门8(福禄寿)中，缺失字是精字(上/福)→进张成精句
            final isJingJuKao =
                (discardGroup == 1 || discardGroup == 8) &&
                missingChars.any((ch) => ch == '上' || ch == '福');
            if (isJingJuKao) {
              // 精句潜力靠(进张+4胡)，破坏代价更大
              // 胡数不足时尤其应该保护
              final huBefore = _evaluateHuScore(player);
              final huWeight = huBefore < 11 ? 1.5 : 1.0;
              if (quickDist <= 2) {
                score -= (250 + missingRem * 25) * huWeight;
              } else if (quickDist <= 4) {
                score -= (200 + missingRem * 20) * huWeight;
              } else {
                score -= (150 + missingRem * 15) * huWeight;
              }
            } else {
              // 普句靠(进张+0胡)，破坏代价较小
              if (quickDist <= 2) {
                score -= 200 + missingRem * 20;
              } else if (quickDist <= 4) {
                score -= 150 + missingRem * 15;
              } else {
                score -= 100 + missingRem * 10;
              }
            }
          }
        }
      }
    }

    score += (10 - distToTing) * 120;

    // 胡数不足时的出牌优先级规则（按胡牌类型灵活调整）
    // 默认(普通胡牌)：普单 > 普句多一张 > 普靠 > 对子+靠(保留对子)
    // 十对：保留对子，优先出孤张/普单，绝不出对子
    // 黑元：无碰无招，优先拆对子(避免对子变碰破坏黑元资格)
    // 红元：组1/组8句优先保留，优先出非组1/8的孤张
    // 枯胡：6坎+1对，优先出靠/句中的单张，保留对子和坎
    final huBefore = _evaluateHuScore(player);
    if (huBefore < 11) {
      final discardGroup = cardToDiscard.sentence;
      final discardGroupCards = player.hand
          .where((c) => c.sentence == discardGroup)
          .toList();
      final discardGroupCharSet = discardGroupCards
          .map((c) => c.character)
          .toSet();
      final discardCountInGroup = discardGroupCards
          .where((c) => c.character == cardToDiscard.character)
          .length;
      final groupCharCount = <String, int>{};
      for (final c in discardGroupCards) {
        groupCharCount[c.character] = (groupCharCount[c.character] ?? 0) + 1;
      }
      final hasPairInGroup = groupCharCount.values.any((cnt) => cnt >= 2);
      final isShiDui = shiDuiPotential > 0;
      final isHeiYuan = heiYuanPotential > 0;
      final isHongYuan = hongYuanPotential > 0;
      final isKuHu = kuHuPotential > 0;

      if (isShiDui) {
        // 十对路线：保留对子，优先出孤张
        if (discardGroupCharSet.length == 1) {
          score += 250; // 孤张最优先
        } else if (discardGroupCharSet.length == 3) {
          if (discardCountInGroup >= 2) {
            score += 100; // 普句多一张，出多余的对子张
          } else {
            score -= 50; // 出单张会破坏句，但十对不需要句
          }
        } else if (discardGroupCharSet.length == 2) {
          if (hasPairInGroup) {
            if (discardCountInGroup >= 2) {
              score -= 100; // 十对路线绝不出对子
            } else {
              score += 150; // 出靠的单张，保留对子
            }
          } else {
            score += 80; // 普靠，出一张变孤张
          }
        }
      } else if (isHeiYuan) {
        // 黑元路线：无碰无招，优先拆对子(对子变碰会破坏黑元)
        // 主动黑元阶段：优先清理门1/8牌，加速向黑元目标推进
        final isGroup18 = discardGroup == 1 || discardGroup == 8;
        if (isGroup18) {
          // 出门1/8的牌，大幅加分，优先清理
          if (discardCountInGroup == 1) {
            score += 300; // 门1/8孤张，最优先清理
          } else if (discardCountInGroup >= 2) {
            score += 200; // 门1/8对子，也优先清理（黑元不需要门1/8对子）
          }
        } else if (discardGroupCharSet.length == 1) {
          if (discardCountInGroup == 1) {
            score += 150; // 门2-7孤张，次优先
          } else if (discardCountInGroup >= 2) {
            score += 100; // 优先拆对子
          }
        } else if (discardGroupCharSet.length == 3) {
          if (discardCountInGroup >= 2) {
            score += 120; // 普句多一张
          }
        } else if (discardGroupCharSet.length == 2) {
          if (hasPairInGroup) {
            if (discardCountInGroup >= 2) {
              score += 100; // 优先拆对子
            } else {
              score += 30; // 保留对子次之
            }
          } else {
            score += 50; // 普靠
          }
        }
      } else if (isHongYuan) {
        // 红元路线：组1/组8句优先保留，优先出非组1/8的孤张
        final isGroup18 = discardGroup == 1 || discardGroup == 8;
        if (discardGroupCharSet.length == 1) {
          if (isGroup18) {
            score += 100; // 组1/8孤张，仍可凑句，次优
          } else {
            score += 200; // 非组1/8孤张，最优先
          }
        } else if (discardGroupCharSet.length == 3) {
          if (discardCountInGroup >= 2) {
            if (isGroup18) {
              score += 60; // 组1/8句多一张，保留句优先
            } else {
              score += 120; // 非组1/8句多一张
            }
          }
        } else if (discardGroupCharSet.length == 2) {
          if (hasPairInGroup) {
            if (discardCountInGroup == 1) {
              score += 60; // 保留对子，出靠单张
            }
          }
        }
      } else if (isKuHu) {
        // 枯胡路线：6坎+1对，保留对子和坎，优先出靠/句中的单张
        if (discardGroupCharSet.length == 1) {
          // 孤张在枯胡路线中价值低(枯胡不要单张)，但出掉可减少手牌
          // 如果该字有3张(坎)，不出；2张(对子)，不出；1张，出
          final selfCount = groupCharCount[cardToDiscard.character] ?? 0;
          if (selfCount == 1) {
            score += 200; // 单张最优先出
          }
        } else if (discardGroupCharSet.length == 2) {
          if (hasPairInGroup) {
            if (discardCountInGroup == 1) {
              score += 100; // 出靠的单张，保留对子
            } else {
              score -= 150; // 枯胡保留对子，不出对子
            }
          } else {
            score += 80; // 普靠，出一张
          }
        } else if (discardGroupCharSet.length == 3) {
          // 句在枯胡路线中价值低(枯胡要坎不要句)
          if (discardCountInGroup == 1) {
            score += 120; // 出句中的单张
          }
        }
      } else {
        // 默认普通胡牌路线：普单 > 普句多一张 > 普靠 > 对子+靠(保留对子)
        if (discardGroupCharSet.length == 1) {
          score += 200; // 普单(孤张)最优先
        } else if (discardGroupCharSet.length == 3) {
          // 检查是否是"坎+靠"结构（某字>=3，其余各1张）
          // "坎+靠"中坎已是完整面子，靠单张应按孤张/靠单张处理，不按句处理
          final hasKanOrZhao = groupCharCount.values.any((cnt) => cnt >= 3);
          if (hasKanOrZhao && discardCountInGroup == 1) {
            // 坎+靠：出靠单张，坎已是完整面子不参与靠
            // 靠的进张价值主要是进坎字组招，概率取决于坎字剩余张数
            final kanChar = groupCharCount.entries
                .firstWhere((e) => e.value >= 3)
                .key;
            final kanRem = _remainingCount(kanChar, visibleCount);
            if (kanRem <= 0) {
              score += 200; // 坎字已出完，靠无进张价值，优先出
            } else if (kanRem <= 1) {
              score += 150; // 坎字剩余少，靠进张概率低，优先出
            } else {
              score += 80; // 坎字还有剩余，靠有进张价值（可组招），稍后出
            }
          } else if (discardCountInGroup >= 2) {
            score += 120; // 普句多一张
          }
        } else if (discardGroupCharSet.length == 2) {
          if (!hasPairInGroup) {
            // 普靠：不加分，靠破坏靠惩罚控制
          } else {
            // 对子+靠：保留对子，出靠的单张
            if (discardCountInGroup == 1) {
              // 检查该靠是否有精句潜力(门1/8，缺失字是精字上/福)
              // 有精句潜力的银靠单张不应打出(进张+4胡，胡数不足时尤其珍贵)
              final missingChars = _groupChars[discardGroup - 1]
                  .where((ch) => !discardGroupCharSet.contains(ch))
                  .toList();
              final isJingJuKao =
                  (discardGroup == 1 || discardGroup == 8) &&
                  missingChars.any((ch) => ch == '上' || ch == '福');
              if (isJingJuKao) {
                // 精句潜力靠的单张，施加惩罚保护
                // 此处已在 huBefore < 11 块内，胡数不足时精句4胡尤其珍贵
                score -= 150;
              } else {
                score += 60;
              }
            }
          }
        }
      }
    }

    // 胡数评估：听牌胡型条件要求总胡数>=11（特殊胡牌类型除外）
    // 出牌导致胡数下降时惩罚，破坏胡数资格时重罚
    final huAfter = _evaluateHuScore(testPlayer);
    final huLoss = huBefore - huAfter;
    // 胡数损失权重：胡数越低，损失越严重（离11胡资格越远）
    if (huBefore < 11 && huLoss > 0) {
      // 胡数不足11时，每损失1胡的代价更大
      score -= huLoss * 50;
    } else if (huLoss > 0) {
      // 胡数够了(>=11)时，损失精靠/精对等高胡数牌型仍需重罚
      // 精靠4胡、金对8胡等破坏代价大，权重提高到40
      score -= huLoss * 40;
    }
    // 十对、黑元、红元、枯胡路线是特殊胡牌类型，不受胡数>=11限制
    if (huBefore >= 11 &&
        huAfter < 11 &&
        shiDuiPotential <= 0 &&
        heiYuanPotential <= 0 &&
        hongYuanPotential <= 0 &&
        kuHuPotential <= 0) {
      // 出牌破坏了胡牌的胡数资格，重罚
      score -= 600;
    }

    if (isLate) {
      score += (10 - distToTing) * 150;
      if (distToTing <= 2) {
        score += 800;
      }
    }

    final isEarlyGame = _isEarlyGame(state);

    // 十对路线：关注牌局上所有人的组合牌和弃牌
    // 如果某张牌剩余为0（无法再凑对），优先打出
    // 如果坎的字牌剩余为0（无法变招），优先拆坎变对子
    if (shiDuiPotential > 0) {
      final charCount = <String, int>{};
      for (final c in player.hand) {
        charCount[c.character] = (charCount[c.character] ?? 0) + 1;
      }
      final discardCharCount = charCount[cardToDiscard.character] ?? 0;
      final discardRem = _remainingCount(cardToDiscard.character, visibleCount);

      if (discardCharCount == 1 && discardRem <= 0) {
        // 单张且剩余为0，无法凑对，优先打出
        score += 100;
      }
      if (discardCharCount == 3 && discardRem <= 0) {
        // 坎且剩余为0，无法变招，拆坎变对子+单张
        // 优先拆坎（高于单张），因为坎占meld位置只有一次上牌机会
        score += 150;
      }
      if (discardCharCount >= 2) {
        // 打出有对子的牌在十对路线中惩罚
        score -= 60;
      }
      if (discardCharCount == 1 && discardRem > 0) {
        // 孤张但还能凑对，可以打出
        score += 30;
      }
    }

    if (isEarlyGame) {
      // 早期组牌方向规划：明确走句路线还是十对路线
      final pairCount = _countHandPairsWithMelds(player);
      final isShiDuiRoute = pairCount >= 6;

      if (isShiDuiRoute) {
        // 十对路线：保留对子，打出孤张破坏对子组合的牌
        final charCount = <String, int>{};
        for (final c in player.hand) {
          charCount[c.character] = (charCount[c.character] ?? 0) + 1;
        }
        final discardCharCount = charCount[cardToDiscard.character] ?? 0;
        if (discardCharCount >= 2) {
          // 打出有对子的牌在十对路线中惩罚更大
          score -= 60;
        }
        if (discardCharCount == 1) {
          // 孤张在十对路线中更应打出
          score += 30;
        }
      } else {
        // 句路线：保留同组搭子，优先出孤张/普单
        final sameGroup = player.hand
            .where((c) => c.sentence == cardToDiscard.sentence)
            .toList();
        // 统计同组每个字的张数，用于排除已是坎/招的字
        final groupCharCount = <String, int>{};
        for (final c in sameGroup) {
          groupCharCount[c.character] = (groupCharCount[c.character] ?? 0) + 1;
        }
        // 真正参与搭子判断的字：张数<3的字（排除已是坎/招的字）
        // "坎+单"（如七七七+十）中，坎已是完整面子，单张应按孤张处理
        final effectiveGroupCharSet = groupCharCount.entries
            .where((e) => e.value < 3)
            .map((e) => e.key)
            .toSet();
        if (effectiveGroupCharSet.length >= 2) {
          // 搭子：保留
          score -= 30;
          if (effectiveGroupCharSet.length >= 3) {
            // 完整句：出对子中的一张不破坏句，不额外惩罚
            // 只有出单张（会破坏句）才额外惩罚
            final discardCountInGroup = sameGroup
                .where((c) => c.character == cardToDiscard.character)
                .length;
            if (discardCountInGroup < 2) {
              score -= 20;
            }
          }
        } else {
          // 孤张/普单：同组只有1种字（或除坎外只有1种字），优先打出
          score += 40;
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
        } else if (effectiveGroupCharSet.length == 1) {
          // 孤张且同组其他字已出完，无进张价值，最优先打出
          score += 30;
        }
        if (cardToDiscard.isJing) {
          score -= 20;
        }
      }
      if (cardToDiscard.isJing) {
        score -= 20;
      }
    }

    if (!isEarlyGame && !isLate) {
      // 中局策略：平衡进攻和防守
      // 保留有进张的搭子，拆掉进张少的搭子
      final charCount = <String, int>{};
      for (final c in player.hand) {
        charCount[c.character] = (charCount[c.character] ?? 0) + 1;
      }
      final discardCharCount = charCount[cardToDiscard.character] ?? 0;
      final sameGroup = player.hand
          .where((c) => c.sentence == cardToDiscard.sentence)
          .toList();
      final groupCharSet = sameGroup.map((c) => c.character).toSet();
      // 中局出对子中的一张代价较大
      // 但完整句（3种字）中的多余对子，出掉不破坏句，代价较小
      if (discardCharCount >= 2 && groupCharSet.length < 3) {
        score -= 15;
      }
      // 中局优先出孤张/普单（非十对路线）
      if (discardCharCount == 1 && shiDuiPotential <= 0) {
        // 判断是否是真正的孤张：同组中除坎/招（张数>=3）外的字是否只有1种
        // "坎+单"（如七七七+十）中，单张应按孤张处理，因为坎已是完整面子不参与搭子
        final effectiveGroupChars = <String>{};
        for (final ch in groupCharSet) {
          if ((charCount[ch] ?? 0) < 3) {
            effectiveGroupChars.add(ch);
          }
        }
        if (effectiveGroupChars.length == 1) {
          // 孤张/普单：优先打出
          score += 30;
        }
      }
    }

    // 组进张效率比较：优先拆进张少的组，保留进张多的组
    // 计算出牌所在组的进张数，与其他组的进张数比较
    final discardGroup = cardToDiscard.sentence;
    final discardGroupCards = player.hand
        .where((c) => c.sentence == discardGroup)
        .toList();
    final discardGroupCharSet = discardGroupCards
        .map((c) => c.character)
        .toSet();

    // 只在手牌中该组有搭子潜力时才比较（2种以上不同字，或有对子）
    final discardGroupHasPair = discardGroupCharSet.any(
      (ch) => discardGroupCards.where((c) => c.character == ch).length >= 2,
    );
    // 完整的句（3种字都有）不参与组进张效率比较，避免拆句
    // 即使同组还有多余对子，句已完整属于强组，进张少不代表弱组
    final discardGroupIsCompleteSentence = discardGroupCharSet.length == 3;
    if ((discardGroupCharSet.length >= 2 || discardGroupHasPair) &&
        !discardGroupIsCompleteSentence) {
      // 计算出牌所在组的进张数
      int discardGroupRem = 0;
      for (final ch in _groupChars[discardGroup - 1]) {
        if (!discardGroupCharSet.contains(ch)) {
          discardGroupRem += _remainingCount(ch, visibleCount);
        }
      }
      // 加上同组已有字的剩余数（对子变坎的进张）
      for (final ch in discardGroupCharSet) {
        final count = discardGroupCards.where((c) => c.character == ch).length;
        if (count >= 2) {
          discardGroupRem += _remainingCount(ch, visibleCount);
        }
      }

      // 计算其他组的进张数
      final otherGroups = <int>{};
      for (final c in player.hand) {
        if (c.sentence != discardGroup) {
          otherGroups.add(c.sentence);
        }
      }

      for (final g in otherGroups) {
        final gCards = player.hand.where((c) => c.sentence == g).toList();
        final gCharSet = gCards.map((c) => c.character).toSet();
        // 组内有2种以上不同字，或者有对子（对子有变坎潜力）
        final hasPair = gCharSet.any(
          (ch) => gCards.where((c) => c.character == ch).length >= 2,
        );
        if (gCharSet.length < 2 && !hasPair) continue; // 孤张组不比较

        int gRem = 0;
        for (final ch in _groupChars[g - 1]) {
          if (!gCharSet.contains(ch)) {
            gRem += _remainingCount(ch, visibleCount);
          }
        }
        for (final ch in gCharSet) {
          final count = gCards.where((c) => c.character == ch).length;
          if (count >= 2) {
            gRem += _remainingCount(ch, visibleCount);
          }
        }

        // 如果出牌所在组进张比其他组少，加分（鼓励拆弱组）
        // 如果出牌所在组进张比其他组多，减分（不拆强组）
        final diff = gRem - discardGroupRem;
        if (diff > 0) {
          // 其他组进张更多，出当前组的牌（拆弱组）是好的
          score += diff * 5;
        } else if (diff < 0) {
          // 当前组进张更多，出当前组的牌（拆强组）是不好的
          score += diff * 5;
        }
      }
    }

    score -= _evaluateDanger(
      player,
      cardToDiscard,
      state,
      isLate,
      myDist: distToTing,
    );

    // 安全出牌优先：当自己距离听牌较远时，优先出对手不要的组的牌
    if (distToTing >= 4) {
      // 检查出的牌的组是否被对手弃过（说明对手不要该组）
      int safeGroupCount = 0;
      for (int i = 0; i < state.players.length; i++) {
        if (i == player.id) continue;
        final other = state.players[i];
        final discardedThisGroup = other.discards.any(
          (dc) => dc.sentence == cardToDiscard.sentence,
        );
        if (discardedThisGroup) safeGroupCount++;
      }
      score += safeGroupCount * 15;
    }

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
      if (rem <= 0 || totalUnknown <= 0) continue;

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

  /// 评估出牌的危险性（被具他人胡牌的概率）
  double _evaluateDanger(
    Player player,
    Card cardToDiscard,
    GameState state,
    bool isLate, {
    int? myDist,
  }) {
    double danger = 0;
    final isMidGame = state.deck.length >= 20 && state.deck.length <= 50;
    final myVisibleCount =
        _cachedVisibleCount ?? _buildVisibleCharCount(player, state);

    // 缓存同组字列表，避免重复构建
    final sameGroupChars = _groupChars[cardToDiscard.sentence - 1];

    // 检查其他玩家的弃牌和面子，推测他们可能听什么
    for (int i = 0; i < state.players.length; i++) {
      if (i == player.id) continue;
      final other = state.players[i];

      // 使用AI自己视角的剩余张数（不获取对手手牌信息）
      final selfVisibleCount = myVisibleCount;

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
        danger += isLate ? 25 : 12;

        // 剩余张数越少，出这张牌越危险（对手可能在等这张）
        // 使用AI自己视角的剩余张数（不获取对手手牌）
        final selfChRem = _remainingCount(
          cardToDiscard.character,
          selfVisibleCount,
        );
        if (selfChRem == 1) {
          // 自己视角只剩1张（就是我出的这张），极危险
          danger += isLate ? 50 : 30;
        } else if (selfChRem == 2) {
          danger += isLate ? 25 : 15;
        }

        // 通过对方面子推断可能听的牌
        // 对方碰/招了某字，可能听同组其他字
        for (final meld in other.melds) {
          final meldSentence = meld.cards.first.sentence;
          if (meldSentence == cardToDiscard.sentence) {
            // 出的牌和对方面子同组，极危险
            danger += isLate ? 50 : 30;
          }
        }

        // 对方听牌时，结合同组字的可见性评估
        // 同组字在自己视角剩余越少，对手越可能在等这张
        int groupRemFromSelfView = 0;
        for (final gc in sameGroupChars) {
          groupRemFromSelfView += _remainingCount(gc, selfVisibleCount);
        }
        // 同组剩余张数少，对手更可能需要这张
        if (groupRemFromSelfView <= 2) {
          danger += isLate ? 30 : 18;
        } else if (groupRemFromSelfView <= 4) {
          danger += isLate ? 15 : 8;
        }
      }

      // 对方未听牌但面子多时，也有一定危险
      if (!other.isTing && other.melds.length >= 3) {
        danger += isLate ? 15 : 8;
      }

      if (isMidGame && !other.isTing) {
        final discardGroups = <int>{};
        for (final dc in other.discards) {
          discardGroups.add(dc.sentence);
        }
        final meldGroups = <int>{};
        for (final meld in other.melds) {
          meldGroups.add(meld.cards.first.sentence);
        }
        if (meldGroups.contains(cardToDiscard.sentence) &&
            !discardGroups.contains(cardToDiscard.sentence)) {
          danger += 10;
        }
      }

      // 对手弃牌序列分析：近期弃同组牌越多，越不需要该组
      final otherDiscardChars = <String>{};
      int otherDiscardSameGroupCount = 0;
      int recentSameGroupDiscardCount = 0;
      final recentDiscards = other.discards.length > 5
          ? other.discards.sublist(other.discards.length - 5)
          : other.discards;
      for (final dc in other.discards) {
        otherDiscardChars.add(dc.character);
        if (dc.sentence == cardToDiscard.sentence) {
          otherDiscardSameGroupCount++;
        }
      }
      // 统计最近5轮弃牌中同组字的数量
      for (final dc in recentDiscards) {
        if (dc.sentence == cardToDiscard.sentence) {
          recentSameGroupDiscardCount++;
        }
      }

      // 对手近期（最近5轮）弃了同组字，说明不需要该组，降低危险
      if (recentSameGroupDiscardCount >= 1) {
        danger -= isLate ? 8 : 5;
      }

      // 对手弃了同组2种以上字，不太可能要该组，降低危险
      if (otherDiscardSameGroupCount >= 2) {
        danger -= isLate ? 10 : 6;
      }

      // 对手没有弃过同组字且有面子，可能需要该组
      if (otherDiscardSameGroupCount == 0 && other.melds.isNotEmpty) {
        danger += isLate ? 15 : 8;
      }

      final otherMeldChars = <String>{};
      for (final meld in other.melds) {
        for (final c in meld.cards) {
          otherMeldChars.add(c.character);
        }
      }
      for (final gc in sameGroupChars) {
        if (otherMeldChars.contains(gc) && !otherDiscardChars.contains(gc)) {
          danger += isLate ? 20 : 12;
          break;
        }
      }

      // 结合剩余张数推断对手需求
      // 对手组合牌区有同组牌，且该组剩余张数少，对手更可能需要
      if (otherMeldChars.any(
        (mc) => _charSentenceMap[mc] == cardToDiscard.sentence,
      )) {
        int groupRem = 0;
        for (final gc in sameGroupChars) {
          groupRem += _remainingCount(gc, myVisibleCount);
        }
        // 同组剩余少，对手更迫切需要
        if (groupRem <= 2) {
          danger += isLate ? 20 : 12;
        } else if (groupRem <= 4) {
          danger += isLate ? 10 : 5;
        }
      }
    }

    // 喂牌意识：评估出的牌被下家吃的概率
    final nextPlayerIndex = (player.id + 1) % state.players.length;
    if (nextPlayerIndex != player.id) {
      final nextPlayer = state.players[nextPlayerIndex];
      final nextMeldChars = <String>{};
      for (final meld in nextPlayer.melds) {
        for (final c in meld.cards) {
          nextMeldChars.add(c.character);
        }
      }
      bool nextHasSameGroup = false;
      for (final gc in sameGroupChars) {
        if (nextMeldChars.contains(gc)) {
          nextHasSameGroup = true;
          break;
        }
      }
      if (nextHasSameGroup) {
        danger += isLate ? 15 : 8;
        final feedMyDist =
            myDist ??
            _distanceToTing(List<Card>.from(player.hand), player.melds);
        if (feedMyDist >= 5) {
          danger += 10;
        }
      }

      // 下家弃牌中同组字的统计
      int nextDiscardSameGroupCount = 0;
      final nextDiscardGroups = <int>{};
      for (final dc in nextPlayer.discards) {
        nextDiscardGroups.add(dc.sentence);
        if (dc.sentence == cardToDiscard.sentence) {
          nextDiscardSameGroupCount++;
        }
      }
      // 下家弃了同组字越多，越不要该组，喂牌风险越低
      if (nextDiscardSameGroupCount >= 2) {
        danger -= isLate ? 8 : 4;
      }
      if (!nextDiscardGroups.contains(cardToDiscard.sentence) &&
          nextPlayer.melds.isNotEmpty) {
        danger += isLate ? 12 : 6;
      }
      if (nextPlayer.hand.length >= 16 && nextHasSameGroup) {
        danger += 5;
      }

      // 结合剩余张数评估喂牌风险
      // 如果同组字剩余很少，下家即使想要也难以凑齐，风险降低
      if (nextHasSameGroup) {
        int groupRem = 0;
        for (final gc in sameGroupChars) {
          groupRem += _remainingCount(gc, myVisibleCount);
        }
        if (groupRem <= 1) {
          danger -= isLate ? 10 : 5;
        }
      }
    }

    // 如果自己已经听牌，进攻优先，大幅减少防守惩罚
    if (player.isTing) {
      danger *= 0.1;
    }

    // 如果自己距离听牌很近（距离<=2），进攻优先
    final actualMyDist =
        myDist ?? _distanceToTing(List<Card>.from(player.hand), player.melds);
    if (actualMyDist <= 2) {
      danger *= 0.15;
    } else if (actualMyDist <= 4) {
      danger *= 0.4;
    } else if (actualMyDist <= 6) {
      danger *= 0.6;
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
    // 修正：当靠/对数量超过需要的面子数时，多余部分仅用于听牌条件，
    // 不应使距离低于neededMelds（仍需neededMelds张牌来完成面子）
    if (neededMelds > 0 && distance < neededMelds) {
      distance = neededMelds;
    }
    // 听牌条件检查（不依赖neededMelds，因为听牌条件只分析手牌，不考虑组合牌）
    // 单钓听：C=0且D=1（dSet为空且eSet有1张单牌）
    // 普通听：C=2且D=0（dSet有2个对/靠且eSet为空）
    if (eSet.length == 1 && dSet.isEmpty) {
      distance = 0; // 单钓听
    } else if (dSet.length == 2 && eSet.isEmpty) {
      distance = 0; // 普通听
    }
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
          if (rem > 0 && totalUnknown > 0) prob += rem / totalUnknown;
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
          score += 40;
        } else {
          final rem = _remainingCount(ch, visibleCount);
          if (rem >= 1) {
            // 对的进张：需要第3张变成刻，进张数=rem
            // 进张概率高的对更有价值
            score += 30 + rem * 12;
          } else {
            // 没有进张的对价值很低
            score += 3;
          }
          // 对+同组单牌协同加分：对子+同组单牌有两条进张路线
          // 摸同字成坎（已在对的评分中），摸缺字成句（此处加分）
          // 句进张价值应与靠的进张价值对等(rem*20)，因为两者进张结果完全相同
          final duiSentence = meld.cards.first.sentence;
          final sameGroupSingles = eSet
              .where((c) => c.sentence == duiSentence && c.character != ch)
              .toList();
          if (sameGroupSingles.isNotEmpty) {
            final groupChars = _groupChars[duiSentence - 1];
            final presentChars = <String>{ch};
            for (final s in sameGroupSingles) {
              presentChars.add(s.character);
            }
            for (final gc in groupChars) {
              if (!presentChars.contains(gc)) {
                final missingRem = _remainingCount(gc, visibleCount);
                score += missingRem * 20;
              }
            }
          }
        }
        if (meld.isJing) score += 20;
      } else if (meld.type == MeldType.kao) {
        final chars = meld.cards.map((c) => c.character).toList();
        final missingChar = _findMissingCharForSentence(chars);
        if (missingChar != null) {
          final rem = _remainingCount(missingChar, visibleCount);
          if (rem >= 1) {
            // 靠的进张：需要缺的那1张，进张数=rem
            // 进张概率高的靠更有价值
            score += 50 + rem * 20;
          } else {
            // 没有进张的靠价值极低，更积极打出
            score -= 10;
          }
        } else {
          score += 60;
        }
        if (meld.isJing) score += 15;
      }
    }

    // 评估孤张牌的价值，考虑半搭子（同组2张不同字但未被提取为靠）
    // 注意：同组判断应使用提取后的remaining（eSet），而非原始hand
    // 因为对子/靠已被提取，同组的对子牌无法再与单牌组成靠
    for (final card in eSet) {
      final sameGroup = eSet.where((c) => c.sentence == card.sentence).toList();
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
            if (totalUnknown > 0) missingProb += rem / totalUnknown;
            totalRem += rem;
          }
        }
        // 半搭子进张概率高，大幅加分
        score += missingProb * 80 + totalRem * 5;

        // 如果同组有3种字，说明差1张就能成句，价值极高
        if (groupCharSet.length >= 3) {
          score += 50;
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
            if (totalUnknown > 0) partnerProb += rem / totalUnknown;
            partnerRem += rem;
          }
        }
        // 孤张进张概率低，更积极打出
        score -= 20;
        score += partnerProb * 8 + partnerRem * 1;
        // 同组其他字剩余为0时，孤张几乎无价值，更积极打出
        if (partnerRem == 0) {
          score -= 50;
        }
      }

      if (card.isJing) {
        score += 20; // 精牌孤张价值更高
      } else if (_isYin(card)) {
        score += 3;
        // 组1(上大人)/组8(福禄寿)的银牌有精句潜力（精句4胡 vs 普句0胡）
        // 仅在总胡数不足11时才加分，鼓励保留银牌等待精句补足胡数
        // 胡数已够时按正常估值，避免过度保留银牌
        if (card.sentence == 1 || card.sentence == 8) {
          final testPlayer = Player(
            id: -1,
            name: '',
            type: PlayerType.ai,
            hand: List<Card>.from(hand),
            melds: List<Meld>.from(melds),
          );
          // 确保meldHuCount已正确初始化
          if (testPlayer.melds.isNotEmpty) {
            HuCalculator.updateMeldHuCache(testPlayer);
          }
          final totalHu = HuCalculator.calculateTotalHu(testPlayer);
          if (totalHu < 11) {
            score += 15; // 精句潜力加分
          }
        }
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
          if (rem > 0 && totalUnknown > 0) pairProb += rem / totalUnknown;
        } else if (meld.type == MeldType.kao) {
          final chars = meld.cards.map((c) => c.character).toList();
          final missing = _findMissingCharForSentence(chars);
          if (missing != null) {
            final rem = _remainingCount(missing, visibleCount);
            if (rem > 0 && totalUnknown > 0) pairProb += rem / totalUnknown;
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
          if (rem > 0 && totalUnknown > 0) pairProb += rem / totalUnknown;
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

    final pairs = _countPairsFromHandAndMelds(hand, melds);

    // 组合牌区有牌时，彻底不考虑十对路线
    // 十对路线未启用时，不考虑十对路线
    // 8对以上时，强制走十对路线（不考虑其它胡牌类型）
    final bool useShiDui = melds.isEmpty && _currentShiDuiEnabled;
    final bool forceShiDui = useShiDui && pairs >= 8;

    int result;
    if (forceShiDui) {
      // 8对以上，强制走十对路线
      result = _distanceToTingShiDui(hand, melds);
    } else if (useShiDui) {
      final pairDist = _distanceToTingShiDui(hand, melds);
      final normalDist = _distanceToTingNormal(hand, melds);
      result = pairDist < normalDist ? pairDist : normalDist;
    } else {
      // 十对路线不可用，只走普通路线
      result = _distanceToTingNormal(hand, melds);
    }

    // 当结构距离较近时，检查胡数条件
    // 听牌胡型条件要求总胡数>=11（特殊胡牌类型除外）
    // 若胡数不足，增加距离惩罚，避免AI追求不可达的听牌路线
    if (result <= 2) {
      final testPlayer = Player(
        id: -1,
        name: '',
        type: PlayerType.ai,
        hand: List<Card>.from(hand),
        melds: List<Meld>.from(melds),
      );
      // 确保meldHuCount已正确初始化
      if (testPlayer.melds.isNotEmpty) {
        HuCalculator.updateMeldHuCache(testPlayer);
      }
      final totalHu = HuCalculator.calculateTotalHu(testPlayer);
      final isShiDui = _countHandPairsWithMelds(testPlayer) >= 7;
      final isHeiYuan = _evaluateHeiYuanPotential(testPlayer) > 0;
      if (totalHu < 11 && !isShiDui && !isHeiYuan) {
        // 胡数不足且非特殊胡型，根据胡数差距动态增加距离惩罚
        // 差距越大惩罚越重，避免AI追求不可达的听牌路线
        final huGap = 11 - totalHu;
        final penalty = math.max(0, huGap ~/ 2);
        result += penalty;
        if (result > 10) result = 10;
      }
    }

    _distanceCache[key] = result;
    return result;
  }

  /// 十对听牌距离（到听牌的距离，非到胡牌的距离）
  /// 十对听牌条件：手牌9对（即9对+1单张），所以9对=听牌（距离0）
  /// 十对只看手牌，不从组合牌算对子
  int _distanceToTingShiDui(List<Card> hand, List<Meld> melds) {
    final byChar = <String, int>{};
    for (final card in hand) {
      byChar[card.character] = (byChar[card.character] ?? 0) + 1;
    }
    // 十对只看手牌，不从组合牌算对子

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

    // 十对听牌条件：9对=听牌，距离 = 9 - pairs
    // 9对时距离0（已听牌），10对时距离-1（已胡牌）也按0处理
    int dist = 9 - pairs;
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
      final singleByGroup = <int, Set<String>>{};
      for (final card in eSet) {
        // 靠不含上/福，跳过
        if (card.character == '上' || card.character == '福') continue;
        singleByGroup.putIfAbsent(card.sentence, () => <String>{});
        singleByGroup[card.sentence]!.add(card.character);
      }
      for (final entry in singleByGroup.entries) {
        // 只统计同组中不同字的单牌数量，相同字不能组成靠
        final uniqueChars = entry.value.length;
        if (uniqueChars >= 2) {
          potentialKaoFromSingles += uniqueChars ~/ 2;
        }
      }

      int dist = neededMelds * 2 - usefulDuiKao - potentialKaoFromSingles;

      // 修正：当靠/对数量超过需要的面子数时，多余部分仅用于听牌条件，
      // 不应使距离低于neededMelds（仍需neededMelds张牌来完成面子）
      if (neededMelds > 0 && dist < neededMelds) {
        dist = neededMelds;
      }

      // 听牌条件检查（不依赖neededMelds，因为听牌条件只分析手牌，不考虑组合牌）
      // 单钓听：C=0且D=1（dSet为空且eSet有1张单牌）
      // 普通听：C=2且D=0（dSet有2个对/靠且eSet为空）
      if (eSet.length == 1 && dSet.isEmpty) {
        dist = 0; // 单钓听
      } else if (dSet.length == 2 && eSet.isEmpty) {
        dist = 0; // 普通听
      }

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
      if (rem <= 0 || totalUnknown <= 0) continue;

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

  /// 门结构评分（按 men-structure-score.md 规则）
  /// 计算指定门的手牌结构分，考虑牌型胡数、结构完整度、进张概率
  /// sentence: 门号(1-8)
  /// hand: 手牌（全部门，方法内部按sentence筛选）
  /// melds: 组合牌（全部门，方法内部按sentence筛选）
  /// visibleCount: 已知牌计数
  /// totalUnknown: 未知牌总数
  double _evaluateMenStructure(
    int sentence,
    List<Card> hand,
    List<Meld> melds,
    Map<String, int> visibleCount,
    int totalUnknown,
  ) {
    // 筛选该门的手牌和组合牌
    final menHand = hand.where((c) => c.sentence == sentence).toList();
    final menMelds = melds
        .where((m) => m.cards.first.sentence == sentence)
        .toList();

    final isJingMen = sentence == 1 || sentence == 8;
    final groupChars = _groupChars[sentence - 1];

    // 按字统计手牌张数
    final byChar = <String, int>{};
    for (final card in menHand) {
      byChar[card.character] = (byChar[card.character] ?? 0) + 1;
    }

    double score = 0;

    // 1. 组合牌分（已完成的句/坎/招）
    for (final meld in menMelds) {
      switch (meld.type) {
        case MeldType.zhao:
          score += meld.isJing ? 200 : 100; // 精招200 / 普招100
          break;
        case MeldType.kan:
          score += meld.isJing ? 150 : 50; // 精坎150 / 普坎(组合)50
          break;
        case MeldType.ju:
          score += meld.isJing ? 90 : 50; // 精句90 / 普句50
          break;
        default:
          break;
      }
    }

    // 2. 手牌结构分（最优拆解）
    // 按张数分布计算，考虑招/坎/句/对/靠/单

    // 2.1 招（4张同字）
    for (final ch in groupChars) {
      if ((byChar[ch] ?? 0) >= 4) {
        score += isJingMen && (ch == '上' || ch == '福') ? 200 : 100;
      }
    }

    // 2.2 坎（3张同字，手牌）
    for (final ch in groupChars) {
      final cnt = byChar[ch] ?? 0;
      if (cnt >= 3 && cnt < 4) {
        score += isJingMen && (ch == '上' || ch == '福') ? 150 : 60;
      }
    }

    // 2.3 句（3字各1张）
    final hasAllThree = groupChars.every((ch) => (byChar[ch] ?? 0) >= 1);
    if (hasAllThree) {
      score += isJingMen ? 90 : 50;
    }

    // 2.4 对（2张同字，非金对）
    for (final ch in groupChars) {
      final cnt = byChar[ch] ?? 0;
      if (cnt == 2) {
        if (isJingMen && (ch == '上' || ch == '福')) {
          score += 100; // 金对
        } else if (isJingMen &&
            (ch == '大' || ch == '人' || ch == '禄' || ch == '寿')) {
          score += 20; // 银对
        } else {
          score += 20; // 普对
        }
      }
    }

    // 2.5 靠（2字各1张，非完整句）
    // 只有当3字不齐全时才评估靠
    // 靠的判断排除已是坎/招的字（张数>=3），因为坎已是完整面子不参与靠
    // "坎+单"（如七七七+十）中，十应按孤张处理，不和七组成靠
    if (!hasAllThree) {
      final presentChars = groupChars.where((ch) {
        final cnt = byChar[ch] ?? 0;
        return cnt >= 1 && cnt < 3;
      }).toList();
      if (presentChars.length == 2) {
        final missingChar = _findMissingCharForSentence(presentChars);
        if (missingChar != null) {
          final rem = _remainingCount(missingChar, visibleCount);
          final isJingKao =
              isJingMen &&
              (presentChars.contains('上') || presentChars.contains('福'));
          if (isJingKao) {
            score += 50; // 精靠
          } else if (isJingMen &&
              (presentChars.contains('大') ||
                  presentChars.contains('人') ||
                  presentChars.contains('禄') ||
                  presentChars.contains('寿'))) {
            score += 10; // 银靠
          } else {
            score += 10; // 普靠
          }
          // 进张期望分
          if (rem > 0 && totalUnknown > 0) {
            score += (rem / totalUnknown) * 50;
          }
        }
      }
    }

    // 2.6 单张
    for (final ch in groupChars) {
      final cnt = byChar[ch] ?? 0;
      if (cnt == 1) {
        // 检查是否在靠或句中已计算（排除坎/招的字）
        final presentChars = groupChars.where((c) {
          final cCnt = byChar[c] ?? 0;
          return cCnt >= 1 && cCnt < 3;
        }).toList();
        if (presentChars.length >= 2) continue; // 已在靠/句中

        if (isJingMen && (ch == '上' || ch == '福')) {
          score += 40; // 精单
        } else if (isJingMen &&
            (ch == '大' || ch == '人' || ch == '禄' || ch == '寿')) {
          score += 0; // 银单
        } else {
          score += 0; // 普单
          // 孤张进张概率低，略微减分
          final otherChars = groupChars.where((c) => c != ch).toList();
          int partnerRem = 0;
          for (final oc in otherChars) {
            partnerRem += _remainingCount(oc, visibleCount);
          }
          if (partnerRem == 0) {
            score -= 20; // 无进张可能的孤张
          }
        }
      }
    }

    // 3. 进张期望分（所有可能进张的结构提升）
    // 模拟摸到每张可能的牌后的结构分提升
    for (final ch in groupChars) {
      final rem = _remainingCount(ch, visibleCount);
      if (rem <= 0 || totalUnknown <= 0) continue;

      final prob = rem / totalUnknown;
      if (prob < 0.01) continue;

      // 模拟摸到该牌后的结构
      final simByChar = Map<String, int>.from(byChar);
      simByChar[ch] = (simByChar[ch] ?? 0) + 1;

      // 计算摸牌后的结构分（简化版，只看关键变化）
      double improvement = 0;

      // 摸到后成对（1->2）
      if ((byChar[ch] ?? 0) == 1) {
        improvement += isJingMen && (ch == '上' || ch == '福') ? 100 : 20;
      }
      // 摸到后成坎（2->3）
      else if ((byChar[ch] ?? 0) == 2) {
        improvement += isJingMen && (ch == '上' || ch == '福') ? 150 : 60;
      }
      // 摸到后成招（3->4）
      else if ((byChar[ch] ?? 0) == 3) {
        improvement += isJingMen && (ch == '上' || ch == '福') ? 200 : 100;
      }
      // 摸到后成句/靠（0->1，且其他字有牌）
      else if ((byChar[ch] ?? 0) == 0) {
        final presentChars = groupChars
            .where((c) => (byChar[c] ?? 0) >= 1)
            .toList();
        if (presentChars.length == 2) {
          // 成句
          improvement += isJingMen ? 90 : 50;
        } else if (presentChars.length == 1) {
          // 成靠
          improvement +=
              isJingMen &&
                  (presentChars.contains('上') || presentChars.contains('福'))
              ? 50
              : 10;
        }
      }

      score += prob * improvement;
    }

    return score;
  }

  /// 计算所有门的结构总分
  double _evaluateAllMenStructure(
    List<Card> hand,
    List<Meld> melds,
    Map<String, int> visibleCount,
    int totalUnknown,
  ) {
    double total = 0;
    for (int s = 1; s <= 8; s++) {
      total += _evaluateMenStructure(
        s,
        hand,
        melds,
        visibleCount,
        totalUnknown,
      );
    }
    return total;
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

  /// 计算玩家总牌数（手牌+组合牌）
  int _totalCardCount(Player player) {
    return player.hand.length + player.melds.length * 3;
  }

  /// 检查是否可以执行吃/碰/招操作
  /// 20张牌时不能吃、不能碰、不能招别人出的牌
  bool _canOperate(Player player) {
    return _totalCardCount(player) < 20;
  }

  /// 检查是否可以招自己手牌上的牌
  /// 19张牌时不能招自己手牌上的4张同字牌
  bool _canZhaoFromHand(Player player, String character) {
    final totalCards = _totalCardCount(player);
    if (totalCards == 19) {
      final sameCharCount = player.hand
          .where((c) => c.character == character)
          .length;
      if (sameCharCount >= 4) return false;
    }
    return true;
  }

  List<String> _getOtherCharsInGroup(Card card) {
    return _groupChars[card.sentence - 1]
        .where((ch) => ch != card.character)
        .toList();
  }

  @override
  bool shouldChi(Player player, Card card, GameState state) {
    _initCache(player, state);

    // 8对以上强制走十对路线，不吃牌
    if (_currentShiDuiEnabled && _countHandPairsWithMelds(player) >= 8) {
      return false;
    }

    // 黑元路线：不吃门1/8的牌（吃门1/8句会破坏黑元资格）
    final heiYuanPotential = _evaluateHeiYuanPotential(player);
    if (heiYuanPotential > 0 && (card.sentence == 1 || card.sentence == 8)) {
      return false;
    }

    if (_hasCompleteSentenceWithSingleCards(player, card)) {
      return false;
    }

    // 20张牌时不能吃
    if (!_canOperate(player)) return false;

    // 尝试所有可能的吃法，选最优
    final otherChars = _getOtherCharsInGroup(card);
    final availableChars = otherChars
        .where((ch) => player.hand.any((c) => c.character == ch))
        .toList();

    if (availableChars.length < 2) return false;

    double bestBenefit = -1;
    // 如果3种字都有，尝试2种吃法
    if (availableChars.length == 2) {
      bestBenefit = _evaluateChiBenefit(player, card, state);
    } else {
      // 3种字都有，比较2种吃法
      for (int i = 0; i < availableChars.length; i++) {
        for (int j = i + 1; j < availableChars.length; j++) {
          final benefit = _evaluateChiBenefitWithChars(player, card, [
            availableChars[i],
            availableChars[j],
          ], state);
          if (benefit > bestBenefit) bestBenefit = benefit;
        }
      }
    }

    if (bestBenefit < 0) return false;

    // 吃后听牌（bestBenefit>=10000）时允许吃
    if (player.isTing) return bestBenefit >= 10000;

    // 破坏完整句保护：吃牌会破坏手牌中已有的纯单张完整句（3种字都只有1张）时，
    // 除非吃后听牌，否则不吃
    // 注意：只有当3种字都只有1张时才是真正的"纯单张完整句"，
    // 有2张以上的情况吃牌只是把句转移到组合牌区，不构成破坏
    if (bestBenefit < 10000) {
      final cardSentence = card.sentence;
      final sentenceCards = player.hand
          .where((c) => c.sentence == cardSentence)
          .toList();
      final sentenceChars = sentenceCards.map((c) => c.character).toSet();
      // 手牌中该组3种字都有=完整句
      if (sentenceChars.length == 3) {
        // 检查是否是纯单张完整句（每字都只有1张）
        final allSingle = sentenceChars.every(
          (ch) => sentenceCards.where((c) => c.character == ch).length == 1,
        );
        // 只有纯单张完整句才保护，有2张以上的允许吃（句转移到组合牌区）
        if (allSingle) {
          return false;
        }
      }
    }

    // 截胡策略：其他玩家快听牌时，更积极吃牌加速自己
    if (_hasOpponentNearTing(state, player.id)) {
      return bestBenefit > -50;
    }

    return bestBenefit > 0;
  }

  /// 检查是否有对手快听牌（距离<=2或已听牌）
  bool _hasOpponentNearTing(GameState state, int myId) {
    for (int i = 0; i < state.players.length; i++) {
      if (i == myId) continue;
      final other = state.players[i];
      if (other.isTing) return true;
      if (other.melds.length >= 3) return true;
    }
    return false;
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
    _initCache(player, state);

    // 8对以上强制走十对路线，不碰牌
    if (_currentShiDuiEnabled && _countHandPairsWithMelds(player) >= 8) {
      return false;
    }

    // 黑元路线：不碰牌（碰牌会破坏黑元资格）
    final heiYuanPotential = _evaluateHeiYuanPotential(player);
    if (heiYuanPotential > 0) {
      return false;
    }

    final hand = player.hand;
    final sameCharCount = hand
        .where((c) => c.character == card.character)
        .length;

    if (sameCharCount < 2) return false;

    // 20张牌时不能碰
    if (!_canOperate(player)) return false;

    // 截胡策略：其他玩家快听牌时，更积极碰牌
    final opponentNearTing = _hasOpponentNearTing(state, player.id);

    if (sameCharCount >= 2) {
      // 如果手牌中已有3张同字（坎），碰牌会破坏坎，几乎总是不划算
      // 坎在手牌=3胡，碰后坎在组合牌=2胡，净损失1胡，且剩余1张单牌大概率被丢弃
      // 除非碰后听牌
      if (sameCharCount >= 3) {
        final testHand3 = List<Card>.from(hand);
        final matching3 = testHand3
            .where((c) => c.character == card.character)
            .take(2)
            .toList();
        for (final m in matching3) {
          testHand3.remove(m);
        }
        final newMeld3 = Meld(
          cards: [card, ...matching3],
          type: MeldType.kan,
          isJing: card.isJing,
        );
        final testPlayer3 = Player(
          id: player.id,
          name: player.name,
          type: player.type,
          hand: testHand3,
          melds: [...player.melds, newMeld3],
        );
        final tingAfter3 = _checkTingCached(testPlayer3);
        if (!tingAfter3.isTing) return false;
        // 碰后听牌才碰，继续往下评估
      }

      // 检查碰牌是否会破坏手牌中已有的句/靠组合
      final remaining = List<Card>.from(hand);
      final aSet = <Meld>[];
      final bSet = <Meld>[];
      final cSet = <Meld>[];
      final dSet = <Meld>[];
      HuCalculator.extractJu(remaining, aSet);
      HuCalculator.extractZhao(remaining, bSet);
      HuCalculator.extractKan(remaining, cSet);
      HuCalculator.extractDuiAndKao(remaining, dSet);

      // 如果该字参与了句，碰掉2张会破坏句
      final inJu = aSet.any(
        (m) => m.cards.any((c) => c.character == card.character),
      );
      // 如果该字参与了靠，碰掉2张会破坏靠
      final inKao = dSet.any(
        (m) =>
            m.type == MeldType.kao &&
            m.cards.any((c) => c.character == card.character),
      );
      // 碰牌破坏句/靠时，结合剩余张数评估损失
      if (inJu || inKao) {
        // 自己胡数较少且快轮到自己摸牌时，对破坏句子的碰牌更保守
        // 只有确实不破坏句子的碰才碰；同句组有2+2冗余时例外（如化三三千千，碰三还剩千千对子）
        if (inJu) {
          final selfHu = _evaluateHuScore(player);
          final isNextToDraw =
              state.lastDiscardPlayerIndex != null &&
              (state.lastDiscardPlayerIndex! + 1) % 3 == player.id;
          if (selfHu < 11 && isNextToDraw) {
            // 检查同句组是否有冗余对子（碰掉该字后，同句组其他字还有对子）
            final pengSentence = card.sentence;
            final otherCharCounts = <String, int>{};
            for (final c in hand) {
              if (c.sentence == pengSentence && c.character != card.character) {
                otherCharCounts[c.character] =
                    (otherCharCounts[c.character] ?? 0) + 1;
              }
            }
            final hasRedundancyPair = otherCharCounts.values.any(
              (cnt) => cnt >= 2,
            );
            // 无冗余对子（如化三三千，碰三后只剩化千靠），不碰
            if (!hasRedundancyPair) return false;
          }
        }

        final visibleCount = _buildVisibleCharCount(player, state);

        // 计算被破坏的句/靠中缺失字的剩余张数
        int missingRem = 0;
        if (inJu) {
          // 找到包含该字的句，计算句中其他字的剩余张数
          for (final m in aSet) {
            if (m.cards.any((c) => c.character == card.character)) {
              for (final mc in m.cards) {
                if (mc.character != card.character) {
                  missingRem += _remainingCount(mc.character, visibleCount);
                }
              }
              break;
            }
          }
        }
        if (inKao) {
          for (final m in dSet) {
            if (m.type == MeldType.kao &&
                m.cards.any((c) => c.character == card.character)) {
              for (final mc in m.cards) {
                if (mc.character != card.character) {
                  missingRem += _remainingCount(mc.character, visibleCount);
                }
              }
              break;
            }
          }
        }

        // 剩余张数为0：无法重组，碰牌损失极大，严格限制
        // 剩余张数少：重组困难，碰牌需谨慎
        // 剩余张数多：重组容易，碰牌可接受
        final testHandCheck = List<Card>.from(hand);
        final matchingCheck = testHandCheck
            .where((c) => c.character == card.character)
            .take(2)
            .toList();
        for (final m in matchingCheck) {
          testHandCheck.remove(m);
        }
        final newMeldCheck = Meld(
          cards: [card, ...matchingCheck],
          type: MeldType.kan,
          isJing: card.isJing,
        );
        final testPlayerCheck = Player(
          id: player.id,
          name: player.name,
          type: player.type,
          hand: testHandCheck,
          melds: [...player.melds, newMeldCheck],
        );
        final tingCheck = _checkTingCached(testPlayerCheck);

        // 胡数够了(>=11)时，破坏完整句的碰牌门槛更高
        // 只有碰后听牌或距离改善才碰，不为增加胡数破坏句子
        if (inJu) {
          final selfHu = _evaluateHuScore(player);
          if (selfHu >= 11 && !tingCheck.isTing) {
            final distBeforeCheck = _distanceToTing(
              List<Card>.from(hand),
              player.melds,
            );
            final distAfterCheck = _distanceToTing(testHandCheck, [
              ...player.melds,
              newMeldCheck,
            ]);
            // 胡数够了，距离没改善(distAfter >= distBefore)不碰
            if (distAfterCheck >= distBeforeCheck) return false;
          }
        }

        if (missingRem == 0) {
          // 缺失字已出完，无法重组，必须碰后听牌才碰
          if (!tingCheck.isTing) return false;
        } else if (missingRem <= 2) {
          // 缺失字少，重组困难，碰后需接近听牌
          if (!tingCheck.isTing) {
            final distBefore = _distanceToTing(
              List<Card>.from(hand),
              player.melds,
            );
            final distAfter = _distanceToTing(testHandCheck, [
              ...player.melds,
              newMeldCheck,
            ]);
            if (distAfter > distBefore) return false;
          }
        } else {
          // 缺失字多(>2)，重组容易，但仍需评估碰后听牌距离
          // 破坏完整句的代价较高，碰后距离不能增加
          if (!tingCheck.isTing) {
            final distBefore = _distanceToTing(
              List<Card>.from(hand),
              player.melds,
            );
            final distAfter = _distanceToTing(testHandCheck, [
              ...player.melds,
              newMeldCheck,
            ]);
            // 破坏句后距离增加，不碰
            if (distAfter > distBefore) return false;
          }
        }
      }

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
        visibleCount:
            _cachedVisibleCount ?? _buildVisibleCharCount(player, state),
        totalUnknown: _cachedTotalUnknown ?? _totalUnknownCards(player, state),
      );

      if (distAfterDiscard > distBefore) return false;

      if (distAfterDiscard < distBefore) return true;

      // 距离不变时，比较碰牌前后胡数差值
      final huScoreBefore = _evaluateHuScore(player);
      final huScoreAfter = _evaluateHuScore(testPlayer);
      if (huScoreAfter > huScoreBefore) return true;

      // 距离和胡数都不变时，比较碰牌前后的进张数
      final vc = _cachedVisibleCount ?? _buildVisibleCharCount(player, state);
      final tu = _cachedTotalUnknown ?? _totalUnknownCards(player, state);
      final (bestHandAfterPeng, _) = _findBestDiscardAfterMeld(
        testHand,
        newMelds,
        visibleCount: vc,
        totalUnknown: tu,
      );
      double entryAfterPeng = 0;
      for (final ch in _allChars) {
        final sentence = _charSentenceMap[ch];
        if (sentence == null) continue;
        if (!bestHandAfterPeng.any((c) => c.sentence == sentence)) continue;
        final rem = _remainingCount(ch, vc);
        if (rem > 0 && tu > 0) entryAfterPeng += rem / tu;
      }
      double entryBefore = 0;
      for (final ch in _allChars) {
        final sentence = _charSentenceMap[ch];
        if (sentence == null) continue;
        if (!hand.any((c) => c.sentence == sentence)) continue;
        final rem = _remainingCount(ch, vc);
        if (rem > 0 && tu > 0) entryBefore += rem / tu;
      }
      // 碰后进张数减少太多时不碰
      if (entryAfterPeng < entryBefore * 0.7) return false;

      // 碰牌增加面子，倾向碰（放宽条件：手牌<=14即可）
      // 截胡策略：对手快听牌时更积极碰
      if (opponentNearTing) return true;
      return testHand.length <= 14;
    }

    // sameCharCount < 2: 碰需要手牌中有2张同字牌+出牌1张=3张
    // 手牌中同字牌不足2张时，不满足碰的条件
    return false;
  }

  @override
  bool shouldZhao(Player player, Card card, GameState state) {
    _initCache(player, state);

    // 8对以上强制走十对路线，不招别人出的牌
    if (_currentShiDuiEnabled && _countHandPairsWithMelds(player) >= 8) {
      return false;
    }

    // 20张牌时不能招别人出的牌
    if (!_canOperate(player)) return false;

    final hand = player.hand;
    final sameCharCount = hand
        .where((c) => c.character == card.character)
        .length;

    // 别人出牌时，手牌3张+出牌1张=4张，可以招
    // 这种情况_evaluateZhaoBenefit会因sameCharCount==3返回false
    // 需要单独处理：模拟招牌后的效果
    if (sameCharCount == 3) {
      final testHand = List<Card>.from(hand);
      final zhaoCards = testHand
          .where((c) => c.character == card.character)
          .take(3)
          .toList();
      for (final c in zhaoCards) {
        testHand.remove(c);
      }
      // 招牌：4张同字移到组合牌区（手牌3张+出牌1张）
      final newMeld = Meld(
        cards: [card, ...zhaoCards],
        type: MeldType.zhao,
        isJing: card.isJing,
      );
      final testPlayer = Player(
        id: player.id,
        name: player.name,
        type: player.type,
        hand: testHand,
        melds: [...player.melds, newMeld],
      );
      HuCalculator.updateMeldHuCache(testPlayer);

      final tingAfter = _checkTingCached(testPlayer);
      if (tingAfter.isTing) return true;
      if (player.isTing && !tingAfter.isTing) return false;

      final distBefore = _distanceToTing(List<Card>.from(hand), player.melds);
      final distAfter = _distanceToTing(testHand, [...player.melds, newMeld]);
      if (distAfter > distBefore + 1) return false;

      // 比较招vs碰的胡数
      final huZhao = _evaluateHuScore(testPlayer);

      // 碰牌模拟：手牌取2张+出牌1张=3张坎
      final pengHand = List<Card>.from(hand);
      final pengCards = pengHand
          .where((c) => c.character == card.character)
          .take(2)
          .toList();
      for (final c in pengCards) {
        pengHand.remove(c);
      }
      final pengMeld = Meld(
        cards: [card, ...pengCards],
        type: MeldType.kan,
        isJing: card.isJing,
      );
      final pengPlayer = Player(
        id: player.id,
        name: player.name,
        type: player.type,
        hand: pengHand,
        melds: [...player.melds, pengMeld],
      );
      HuCalculator.updateMeldHuCache(pengPlayer);
      final huPeng = _evaluateHuScore(pengPlayer);
      final distPeng = _distanceToTing(pengHand, [...player.melds, pengMeld]);

      // 招比碰胡数更高或距离更短时，选择招
      if (huZhao >= huPeng && distAfter <= distPeng) return true;
      if (huZhao > huPeng + 4) return true;
      if (distAfter < distPeng) return true;

      // 招后补摸一张牌可能改善，倾向招
      final visibleCount =
          _cachedVisibleCount ?? _buildVisibleCharCount(player, state);
      final totalUnknown =
          _cachedTotalUnknown ?? _totalUnknownCards(player, state);
      double drawImproveProb = 0;
      final handGroups = <int>{};
      for (final c in testHand) {
        handGroups.add(c.sentence);
      }
      for (final ch in _allChars) {
        final sentence = _charSentenceMap[ch];
        if (sentence == null || !handGroups.contains(sentence)) continue;
        final rem = _remainingCount(ch, visibleCount);
        if (rem <= 0 || totalUnknown <= 0) continue;
        final prob = rem / totalUnknown;
        final position = _charPositionMap[ch] ?? -1;
        if (position < 0) continue;
        final simHand = List<Card>.from(testHand)
          ..add(
            Card(
              id: -100,
              character: ch,
              sentence: sentence,
              position: position,
            ),
          );
        final simDist = _distanceToTing(simHand, [...player.melds, newMeld]);
        if (simDist < distAfter) {
          drawImproveProb += prob * (distAfter - simDist);
        }
      }
      if (drawImproveProb > 0.3) return true;

      return false;
    }

    return _evaluateZhaoBenefit(player, card.character, state);
  }

  @override
  bool shouldZhaoFromHand(Player player, String character, GameState state) {
    _initCache(player, state);

    // 8对以上强制走十对路线，不招自己手牌上的牌
    if (_currentShiDuiEnabled && _countHandPairsWithMelds(player) >= 8) {
      return false;
    }

    // 19张牌时不能招自己手牌上的4张同字牌
    if (!_canZhaoFromHand(player, character)) return false;

    return _evaluateZhaoBenefit(player, character, state, isFromHand: true);
  }

  bool _evaluateZhaoBenefit(
    Player player,
    String character,
    GameState state, {
    bool isFromHand = false,
  }) {
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
      // 手牌中有4张同字，可以招
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
      HuCalculator.updateMeldHuCache(testPlayer);

      final tingAfter = _checkTingCached(testPlayer);

      if (tingAfter.isTing) return true;
      if (player.isTing && !tingAfter.isTing) return false;

      // 招后补摸一张牌可能自摸，优先招
      final totalCardsAfterZhao =
          testHand.length + ([...player.melds, newMeld]).length * 3;
      if (totalCardsAfterZhao == 19) {
        // 招后19张，补摸1张变20张，检查补摸后能否自摸
        final visibleCount =
            _cachedVisibleCount ?? _buildVisibleCharCount(player, state);
        final totalUnknown =
            _cachedTotalUnknown ?? _totalUnknownCards(player, state);
        for (final ch in _allChars) {
          final sentence = _charSentenceMap[ch];
          if (sentence == null) continue;
          final position = _charPositionMap[ch] ?? -1;
          if (position < 0) continue;
          final rem = _remainingCount(ch, visibleCount);
          if (rem <= 0) continue;
          final simCard = Card(
            id: -100,
            character: ch,
            sentence: sentence,
            position: position,
          );
          final simHand = List<Card>.from(testHand)..add(simCard);
          if (HuCalculator.canHu(simHand, [...player.melds, newMeld])) {
            return true;
          }
        }
      }

      // 招牌会改变牌流（补摸1张），当对手快听牌时需要考虑
      if (_hasOpponentNearTing(state, player.id) && !tingAfter.isTing) {
        // 对手快听牌但自己招后没听牌，招牌可能加速对手
        // 降低招的意愿
        final distBefore = _distanceToTing(List<Card>.from(hand), player.melds);
        final distAfterZhao = _distanceToTing(testHand, [
          ...player.melds,
          newMeld,
        ]);
        if (distAfterZhao >= distBefore) return false;
      }

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
      HuCalculator.updateMeldHuCache(kanPlayer);

      final huZhao = _evaluateHuScore(testPlayer);
      final huKan = _evaluateHuScore(kanPlayer);
      final distKan = _distanceToTing(kanHand, [...player.melds, kanMeld]);

      if (huZhao >= huKan && distAfter <= distKan) return true;
      if (huZhao > huKan + 4) return true;
      if (distAfter < distKan) return true;

      // 招牌后补摸一张牌的进张概率收益
      // 招后手牌少4张补摸1张，相当于获得一次摸牌机会
      final visibleCount =
          _cachedVisibleCount ?? _buildVisibleCharCount(player, state);
      final totalUnknown =
          _cachedTotalUnknown ?? _totalUnknownCards(player, state);
      double drawImproveProb = 0;
      final handGroups = <int>{};
      for (final card in testHand) {
        handGroups.add(card.sentence);
      }
      for (final ch in _allChars) {
        final sentence = _charSentenceMap[ch];
        if (sentence == null || !handGroups.contains(sentence)) continue;
        final rem = _remainingCount(ch, visibleCount);
        if (rem <= 0 || totalUnknown <= 0) continue;
        final prob = rem / totalUnknown;
        final position = _charPositionMap[ch] ?? -1;
        if (position < 0) continue;
        final simHand = List<Card>.from(testHand)
          ..add(
            Card(
              id: -100,
              character: ch,
              sentence: sentence,
              position: position,
            ),
          );
        final simDist = _distanceToTing(simHand, [...player.melds, newMeld]);
        if (simDist < distAfter) {
          drawImproveProb += prob * (distAfter - simDist);
        }
      }
      // 补摸改善概率较高时，更倾向招
      if (drawImproveProb > 0.3) return true;

      // distAfter <= distBefore 时，需要综合判断
      // 比较招后vs不招（出牌后）的手牌质量
      if (distAfter <= distBefore) {
        // 检查招的牌是否参与了手牌中的句组合
        // 如果4张同字中有牌参与了句，招会破坏句结构
        final handRemaining = List<Card>.from(hand);
        final handASet = <Meld>[];
        final handBSet = <Meld>[];
        final handCSet = <Meld>[];
        final handDSet = <Meld>[];
        HuCalculator.extractJu(handRemaining, handASet);
        HuCalculator.extractZhao(handRemaining, handBSet);
        HuCalculator.extractKan(handRemaining, handCSet);
        HuCalculator.extractDuiAndKao(handRemaining, handDSet);

        final inJu = handASet.any(
          (m) => m.cards.any((c) => c.character == character),
        );
        // 招的牌参与了句，招后句被破坏
        if (inJu) {
          // 计算被破坏句中其他字的剩余张数
          final vc =
              _cachedVisibleCount ?? _buildVisibleCharCount(player, state);
          int juMissingRem = 0;
          for (final m in handASet) {
            if (m.cards.any((c) => c.character == character)) {
              for (final mc in m.cards) {
                if (mc.character != character) {
                  juMissingRem += _remainingCount(mc.character, vc);
                }
              }
              break;
            }
          }
          // 剩余张数为0：句无法重组，招牌损失极大
          if (juMissingRem == 0) {
            // 坎保留1张可以继续参与句，招把4张全部移走
            if (distKan <= distAfter) return false;
            return huZhao > huKan + 4;
          }
          // 剩余张数少：重组困难，倾向坎而非招
          if (juMissingRem <= 2) {
            if (distKan < distAfter) return false;
            if (distKan == distAfter && huKan >= huZhao) return false;
            return huZhao > huKan;
          }
          // 剩余张数多：重组容易，按正常逻辑
          if (distKan < distAfter) return false;
          if (distKan == distAfter && huKan >= huZhao) return false;
          return huZhao > huKan;
        }

        return true;
      }
      return false;
    }

    // sameCharCount == 3: 手牌中有3张同字
    // shouldZhao（别人出牌）：3张+别人1张=4张，可以招（已在shouldZhao中单独处理）
    // shouldZhaoFromHand（自己手牌）：只有3张，不能招（招需要4张）
    if (sameCharCount == 3) {
      // isFromHand=true表示招自己手牌，3张不够，返回false
      // isFromHand=false理论上不会走到这里（shouldZhao已处理==3的情况）
      // 但作为安全兜底，也返回false
      return false;
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
    // 单钓听限制：单钓听时，不能胡单钓的这张字（只能自摸）
    // 直接使用player.tingType，避免重复计算，确保与TingChecker结果一致
    if (!isZimo && player.isTing && player.tingType == TingType.singleWait) {
      // 单钓听时，不能胡单钓的这张字
      // 单钓的字是tingCards中的第一张（唯一需要凑对的字）
      if (player.tingCards.isNotEmpty) {
        final singleChar = player.tingCards.first.character;
        if (card.character == singleChar) {
          return false;
        }
      }
    }
    return true;
  }

  Map<String, int> _buildCharCount(List<Card> hand) {
    final result = <String, int>{};
    for (final card in hand) {
      result[card.character] = (result[card.character] ?? 0) + 1;
    }
    return result;
  }
}
