import 'dart:math' as math;

import 'ai_strategy.dart';
import '../../models/card.dart';
import '../../models/game_state.dart';
import '../../models/player.dart';
import '../../models/meld.dart';
import '../ting_checker.dart';
import '../hu_calculator.dart';
import '../../core/game_logger.dart';

/// 胡牌路线类型（men-structure-score.md 规则三）
enum _RouteType {
  normal, // 普通胡
  heiYuan, // 黑元
  shiDui, // 十对
  hongYuan, // 红元
  kuHu, // 枯胡
}

/// 游戏阶段（men-structure-score.md 规则二）
enum _GamePhase {
  early, // 序盘 >60张
  mid, // 中盘 30-60张
  late, // 终盘 <30张
  flow, // 流局期 <10张
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

  // ==================== 路线相关评分体系（men-structure-score.md） ====================

  /// 路线权重
  static final Map<_RouteType, double> _routeWeight = {
    _RouteType.normal: 1.0,
    _RouteType.heiYuan: 1.3,
    _RouteType.shiDui: 1.5,
    _RouteType.hongYuan: 1.3,
    _RouteType.kuHu: 1.2,
  };

  /// 门2-7组件基础分（路线相关）[招, 坎, 句, 对, 半靠, 孤张]
  static final Map<_RouteType, List<int>> _men27ComponentScore = {
    _RouteType.normal: [100, 60, 50, 20, 10, 0],
    _RouteType.heiYuan: [10, 15, 60, 8, 30, 2],
    _RouteType.shiDui: [100, 55, 15, 50, 20, 10],
    _RouteType.hongYuan: [10, 10, 40, 10, 20, 0],
    _RouteType.kuHu: [5, 90, 10, 40, 5, 0],
  };

  /// 门1/8精字组件基础分（路线相关）[精招, 精坎, 金对, 精句, 精靠, 精单]
  static final Map<_RouteType, List<int>> _men18JingComponentScore = {
    _RouteType.normal: [200, 150, 100, 90, 50, 40],
    _RouteType.heiYuan: [5, 5, 5, 5, 5, 5],
    _RouteType.shiDui: [100, 55, 50, 15, 20, 10],
    _RouteType.hongYuan: [50, 80, 70, 90, 60, 50],
    _RouteType.kuHu: [5, 120, 50, 10, 5, 5],
  };

  /// 门1/8银字组件基础分（路线相关）[银对, 银靠, 银单]
  static final Map<_RouteType, List<int>> _men18YinComponentScore = {
    _RouteType.normal: [20, 10, 0],
    _RouteType.heiYuan: [5, 5, 5],
    _RouteType.shiDui: [50, 20, 10],
    _RouteType.hongYuan: [20, 30, 10],
    _RouteType.kuHu: [40, 5, 0],
  };

  /// 组件索引：门2-7
  static const int _idxZhao = 0; // 招
  static const int _idxKan = 1; // 坎
  static const int _idxJu = 2; // 句
  static const int _idxDui = 3; // 对
  static const int _idxKao = 4; // 半靠
  static const int _idxGu = 5; // 孤张

  /// 组件索引：门1/8精字
  static const int _idxJingZhao = 0; // 精招
  static const int _idxJingKan = 1; // 精坎
  static const int _idxJinDui = 2; // 金对
  static const int _idxJingJu = 3; // 精句
  static const int _idxJingKao = 4; // 精靠
  static const int _idxJingDan = 5; // 精单

  /// 组件索引：门1/8银字
  static const int _idxYinDui = 0; // 银对
  static const int _idxYinKao = 1; // 银靠
  static const int _idxYinDan = 2; // 银单

  /// 当前决策的主路线（缓存）
  _RouteType? _currentRoute;

  /// 路线切换冷却期（剩余回合数）
  int _routeSwitchCooldown = 0;

  /// 上次路线切换时的discards.length
  int? _lastSwitchDiscardLen;

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
    // 检测新局开始，重置十对资格和路线切换冷却
    if (_lastRoundNumber != state.roundNumber) {
      _shiDuiEligible.clear();
      _lastRoundNumber = state.roundNumber;
      _routeSwitchCooldown = 0;
      _lastSwitchDiscardLen = null;
    }

    _distanceCache.clear();
    _tingCache.clear();
    _huScoreCache.clear();
    _cachedVisibleCount = _buildVisibleCharCount(player, state);
    _cachedTotalUnknown = _totalUnknownCards(player, state);
    _cachedCharCount = _buildCharCount(player.hand);
    _cacheOwnerId = player.id;
    _currentShiDuiEnabled = _isShiDuiEligible(player);
    _currentRoute = _determineMainRoute(player, state);
  }

  /// 判定主路线（按路线判定优先级 + 动态切换）
  _RouteType _determineMainRoute(Player player, GameState state) {
    final totalHu = _evaluateHuScore(player);

    // 计算各路线潜力值
    final routePotentials = _calculateAllRoutePotentials(player, totalHu);

    // 找到潜力值最高的路线
    _RouteType bestRoute = _RouteType.normal;
    double bestPotential = routePotentials[_RouteType.normal]!;

    for (final route in _RouteType.values) {
      if (route == _RouteType.normal) continue;
      final potential = routePotentials[route]!;
      if (potential > bestPotential) {
        bestPotential = potential;
        bestRoute = route;
      }
    }

    // 动态路线切换逻辑（规则六）
    final currentRoute = _currentRoute ?? _RouteType.normal;
    if (bestRoute != currentRoute) {
      final currentPotential = routePotentials[currentRoute]!;
      // 切换条件：新路线潜力值 > 当前路线潜力值 × 1.3
      if (bestPotential > currentPotential * 1.3) {
        // 冷却期检查：3回合内不再切换
        if (_routeSwitchCooldown > 0) {
          // 冷却期内不切换，维持当前路线
          return currentRoute;
        }
        // 执行切换
        _routeSwitchCooldown = 3;
        _lastSwitchDiscardLen = player.discards.length;
        return bestRoute;
      }
    }

    // 冷却期递减（每回合-1）
    if (_routeSwitchCooldown > 0 && _lastSwitchDiscardLen != null) {
      if (player.discards.length > _lastSwitchDiscardLen!) {
        _routeSwitchCooldown--;
        _lastSwitchDiscardLen = player.discards.length;
      }
    }

    return bestRoute;
  }

  /// 计算所有路线的潜力值（规则6.2）
  /// 纳入手牌、组合牌、牌面已知张数动态评估
  /// 潜力值 = 路线权重 × (当前进度/目标进度) × 100 + 进张概率加成 - 阻塞惩罚
  Map<_RouteType, double> _calculateAllRoutePotentials(
    Player player,
    double totalHu,
  ) {
    final potentials = <_RouteType, double>{};
    final visibleCount = _cachedVisibleCount ?? {};
    final totalUnknown = _cachedTotalUnknown ?? 1;
    if (totalUnknown <= 0) {
      // 未知牌为0，所有路线潜力归零
      for (final r in _RouteType.values) {
        potentials[r] = 0.0;
      }
      return potentials;
    }

    // ============ 普通胡潜力值 ============
    potentials[_RouteType.normal] = _calcNormalRoutePotential(
      player,
      totalHu,
      visibleCount,
      totalUnknown,
    );

    // ============ 十对潜力值 ============
    potentials[_RouteType.shiDui] = _calcShiDuiRoutePotential(
      player,
      visibleCount,
      totalUnknown,
    );

    // ============ 黑元潜力值 ============
    potentials[_RouteType.heiYuan] = _calcHeiYuanRoutePotential(
      player,
      visibleCount,
      totalUnknown,
    );

    // ============ 红元潜力值 ============
    potentials[_RouteType.hongYuan] = _calcHongYuanRoutePotential(
      player,
      visibleCount,
      totalUnknown,
    );

    // ============ 枯胡潜力值 ============
    potentials[_RouteType.kuHu] = _calcKuHuRoutePotential(
      player,
      visibleCount,
      totalUnknown,
    );

    return potentials;
  }

  /// 普通胡路线潜力值
  /// 进度=当前胡数/11，进张概率加成考虑对子→坎、半靠→句、孤张→对/靠
  double _calcNormalRoutePotential(
    Player player,
    double totalHu,
    Map<String, int> visibleCount,
    int totalUnknown,
  ) {
    final hand = List<Card>.from(player.hand);
    final aSet = <Meld>[];
    final cSet = <Meld>[];
    final dSet = <Meld>[];
    HuCalculator.extractJu(hand, aSet);
    HuCalculator.extractKan(hand, cSet);
    HuCalculator.extractDuiAndKao(hand, dSet);
    // hand剩余为E集（孤张）

    double probBonus = 0;
    int deadCardCount = 0;

    // D集：对子→坎(+3胡)、半靠→句(+6胡附加)
    for (final meld in dSet) {
      if (meld.type == MeldType.dui) {
        final ch = meld.cards.first.character;
        final rem = _remainingCount(ch, visibleCount);
        if (rem > 0) {
          probBonus += (rem / totalUnknown) * 20;
        } else {
          deadCardCount++; // 死对子，无法成坎
        }
      } else if (meld.type == MeldType.kao) {
        final chars = meld.cards.map((c) => c.character).toList();
        final missing = _findMissingCharForSentence(chars);
        if (missing != null) {
          final rem = _remainingCount(missing, visibleCount);
          if (rem > 0) {
            probBonus += (rem / totalUnknown) * 25; // 半靠成句潜力更高
          } else {
            deadCardCount++; // 死半靠
          }
        }
      }
    }

    // E集：孤张→对/靠/句
    for (final card in hand) {
      final rem = _remainingCount(card.character, visibleCount);
      if (rem <= 0) {
        deadCardCount++;
        continue;
      }
      // 孤张成对概率
      probBonus += (rem / totalUnknown) * 5;
      // 同门其他字成靠潜力
      final sameSentenceChars = _groupChars[card.sentence - 1]
          .where((c) => c != card.character)
          .toList();
      for (final other in sameSentenceChars) {
        final otherRem = _remainingCount(other, visibleCount);
        if (otherRem > 0 && hand.any((c) => c.character == other)) {
          // 同门已有其他字，孤张+其他字可成靠
          probBonus += (otherRem / totalUnknown) * 8;
          break;
        }
      }
    }

    // C集：坎→招(+6胡)
    for (final meld in cSet) {
      final ch = meld.cards.first.character;
      final rem = _remainingCount(ch, visibleCount);
      if (rem > 0) {
        probBonus += (rem / totalUnknown) * 15;
      }
    }

    // 死牌惩罚：每个死牌降低路线潜力
    final deadPenalty = deadCardCount * 8.0;

    final progress = (totalHu / 11).clamp(0.0, 1.0);
    // 胡牌类型倍数层级加分：卡胡(11)倍数1 > 普通胡(12-21)倍数0
    // 台卡(22)倍数2 > 台胡(23-32)倍数1，重台卡(33)倍数7 > 重台胡(34+)倍数6
    // 概率相同时优先朝着倍数高的胡牌类型操作
    final multBonus = _huTypeMultiplierBonus(totalHu, totalHu);
    return 1.0 * progress * 100 + probBonus - deadPenalty + multBonus * 0.3;
  }

  /// 十对路线潜力值
  /// 进度=对数/9，进张概率加成考虑孤张→对、对→(无升级，十对不需要坎)
  double _calcShiDuiRoutePotential(
    Player player,
    Map<String, int> visibleCount,
    int totalUnknown,
  ) {
    if (!_currentShiDuiEnabled) return -1.0;

    final pairs = _countHandPairsUnified(player.hand);
    if (pairs < 6) return -1.0;

    // 统计孤张（手牌中数量为1的字）
    final byChar = <String, int>{};
    for (final c in player.hand) {
      byChar[c.character] = (byChar[c.character] ?? 0) + 1;
    }
    final singles = byChar.entries.where((e) => e.value == 1).toList();

    double probBonus = 0;
    int deadSingleCount = 0;

    // 孤张成对概率
    for (final entry in singles) {
      final rem = _remainingCount(entry.key, visibleCount);
      if (rem > 0) {
        probBonus += (rem / totalUnknown) * 30; // 十对路线孤张成对价值高
      } else {
        deadSingleCount++; // 死孤张，无法成对
      }
    }

    // 对子不升级（十对不需要坎），但需保护对子不被拆
    // 对子中字剩余0张时，对子本身仍有效（十对目标就是对子）
    // 无需额外惩罚

    // 死孤张惩罚：十对路线下死孤张意味着无法凑成9对
    final deadPenalty = deadSingleCount * 15.0;

    final progress = pairs / 9;
    return 1.5 * progress * 100 + probBonus - deadPenalty;
  }

  /// 黑元路线潜力值
  /// 进度=(句数+半靠数)/7，进张概率加成考虑半靠→句、孤张→半靠
  /// 阻塞惩罚：门1/8牌剩余多则难清理
  double _calcHeiYuanRoutePotential(
    Player player,
    Map<String, int> visibleCount,
    int totalUnknown,
  ) {
    final basePotential = _evaluateHeiYuanPotential(player);
    if (basePotential <= 0) return -1.0;

    // 统计句数和半靠数
    final hand = List<Card>.from(player.hand);
    final aSet = <Meld>[];
    HuCalculator.extractJu(hand, aSet);
    int sentenceCount = aSet.length;
    for (final meld in player.melds) {
      if (meld.type == MeldType.ju) sentenceCount++;
    }

    // 半靠数（手牌剩余中同门2种字各1张）
    final bySentence = <int, Set<String>>{};
    for (final c in hand) {
      bySentence.putIfAbsent(c.sentence, () => <String>{});
      bySentence[c.sentence]!.add(c.character);
    }
    int halfKaoCount = 0;
    final halfKaoMissing = <String>[]; // 半靠缺失的字
    for (final entry in bySentence.entries) {
      if (entry.value.length == 2) {
        halfKaoCount++;
        final missing = _findMissingCharForSentence(entry.value.toList());
        if (missing != null) halfKaoMissing.add(missing);
      }
    }

    // 进张概率加成：半靠→句
    double probBonus = 0;
    for (final missing in halfKaoMissing) {
      final rem = _remainingCount(missing, visibleCount);
      if (rem > 0) {
        probBonus += (rem / totalUnknown) * 35; // 黑元核心：半靠成句
      }
    }

    // 孤张→半靠潜力（同门已有1字，再摸1字成半靠）
    for (final entry in bySentence.entries) {
      if (entry.value.length == 1) {
        final sentence = entry.key;
        final otherChars = _groupChars[sentence - 1]
            .where((c) => !entry.value.contains(c))
            .toList();
        for (final other in otherChars) {
          final rem = _remainingCount(other, visibleCount);
          if (rem > 0) {
            probBonus += (rem / totalUnknown) * 12;
          }
        }
      }
    }

    // 阻塞惩罚：门1/8牌剩余张数（越多越难清理）
    int men18Count = 0;
    int men18DeadCount = 0; // 门1/8牌中剩余0张的字数（无法通过摸牌清理，只能等出）
    for (final c in player.hand) {
      if (c.sentence == 1 || c.sentence == 8) {
        men18Count++;
        final rem = _remainingCount(c.character, visibleCount);
        if (rem <= 0) men18DeadCount++;
      }
    }
    final men18Penalty = men18Count * 5.0 + men18DeadCount * 10.0;

    final progress = (sentenceCount + halfKaoCount) / 7;
    return 1.3 * progress * 100 +
        basePotential * 0.3 +
        probBonus -
        men18Penalty;
  }

  /// 红元路线潜力值
  /// 进度=门1/8精句数/2，进张概率加成考虑精靠→精句、上/福获取概率
  double _calcHongYuanRoutePotential(
    Player player,
    Map<String, int> visibleCount,
    int totalUnknown,
  ) {
    final basePotential = _evaluateHongYuanPotential(player);
    if (basePotential <= 0) return -1.0;

    // 统计门1/8精句数
    int jingJuCount = 0;
    for (final meld in player.melds) {
      if (meld.type == MeldType.ju && meld.isJing) jingJuCount++;
    }
    final hand = List<Card>.from(player.hand);
    final handASet = <Meld>[];
    HuCalculator.extractJu(hand, handASet);
    for (final meld in handASet) {
      if (meld.isJing) jingJuCount++;
    }

    // 上/福总数
    final allCards = [...player.hand, ...player.melds.expand((m) => m.cards)];
    final shangCount = allCards.where((c) => c.character == '上').length;
    final fuCount = allCards.where((c) => c.character == '福').length;
    final shangFuCount = shangCount + fuCount;

    double probBonus = 0;
    double blockPenalty = 0;

    // 上/福进张概率（需要3-6张，当前<3时需要更多）
    if (shangFuCount < 3) {
      final shangRem = _remainingCount('上', visibleCount);
      final fuRem = _remainingCount('福', visibleCount);
      if (shangRem > 0) probBonus += (shangRem / totalUnknown) * 30;
      if (fuRem > 0) probBonus += (fuRem / totalUnknown) * 30;
    }

    // 上/福超过6张则红元无望（阻塞）
    if (shangFuCount > 6) {
      blockPenalty = 200; // 严重阻塞
    }

    // 门1/8精靠→精句潜力
    final handRemaining = List<Card>.from(player.hand);
    final bySentence18 = <int, Set<String>>{};
    for (final c in handRemaining) {
      if (c.sentence == 1 || c.sentence == 8) {
        bySentence18.putIfAbsent(c.sentence, () => <String>{});
        bySentence18[c.sentence]!.add(c.character);
      }
    }
    for (final entry in bySentence18.entries) {
      if (entry.value.length == 2) {
        // 精靠，缺1字成精句
        final missing = _findMissingCharForSentence(entry.value.toList());
        if (missing != null) {
          final rem = _remainingCount(missing, visibleCount);
          if (rem > 0) {
            probBonus += (rem / totalUnknown) * 40; // 精靠成精句价值高
          } else {
            blockPenalty += 30; // 死精靠
          }
        }
      }
    }

    final progress = jingJuCount / 2;
    return 1.3 * progress * 100 +
        basePotential * 0.3 +
        probBonus -
        blockPenalty;
  }

  /// 枯胡路线潜力值
  /// 进度=坎数/6，进张概率加成考虑对子→坎
  /// 阻塞惩罚：手牌有单张（枯胡不允许单张）
  double _calcKuHuRoutePotential(
    Player player,
    Map<String, int> visibleCount,
    int totalUnknown,
  ) {
    final basePotential = _evaluateKuHuPotential(player);
    if (basePotential <= 0) return -1.0;

    // 统计坎数和对数
    int kanCount = 0;
    for (final meld in player.melds) {
      if (meld.type == MeldType.kan) kanCount++;
      if (meld.type == MeldType.zhao) kanCount++;
    }
    final byChar = <String, int>{};
    for (final c in player.hand) {
      byChar[c.character] = (byChar[c.character] ?? 0) + 1;
    }
    for (final cnt in byChar.values) {
      if (cnt >= 3) kanCount++;
    }

    double probBonus = 0;
    double blockPenalty = 0;

    // 对子→坎潜力
    for (final entry in byChar.entries) {
      if (entry.value == 2) {
        final rem = _remainingCount(entry.key, visibleCount);
        if (rem > 0) {
          probBonus += (rem / totalUnknown) * 35; // 枯胡核心：对子成坎
        } else {
          blockPenalty += 25; // 死对子，无法成坎
        }
      }
    }

    // 枯胡不允许4张同字（招），检查阻塞
    for (final entry in byChar.entries) {
      if (entry.value >= 4) {
        blockPenalty += 100; // 有招则枯胡无望
      }
    }

    final progress = kanCount / 6;
    return 1.2 * progress * 100 +
        basePotential * 0.3 +
        probBonus -
        blockPenalty;
  }

  /// 获取路线权重
  double _getRouteWeight(_RouteType route) {
    return _routeWeight[route] ?? 1.0;
  }

  /// 操作路线进度加分（规则二十四）
  /// 吃(黑元)+50, 碰(枯胡)+50, 碰(普通胡)+30, 招(普通胡)+40
  double _routeOperationBonus(String operation, _RouteType route) {
    switch (operation) {
      case 'chi':
        // 吃牌形成句，黑元路线+50（黑元需6句，吃1句=进度+1/6）
        if (route == _RouteType.heiYuan) return 50.0;
        // 红元路线吃门1/8句+30
        if (route == _RouteType.hongYuan) return 30.0;
        return 0.0;
      case 'peng':
        // 碰牌形成坎，枯胡路线+50（枯胡需6坎，碰1坎=进度+1/6）
        if (route == _RouteType.kuHu) return 50.0;
        // 普通胡路线碰坎+3胡，+30
        if (route == _RouteType.normal) return 30.0;
        return 0.0;
      case 'zhao':
        // 招牌形成招，普通胡路线+40（招+6胡）
        if (route == _RouteType.normal) return 40.0;
        return 0.0;
      default:
        return 0.0;
    }
  }

  /// 胡牌类型倍数（点炮倍数）
  /// 11胡=卡胡(1), 12-21=普通胡(0), 22=台卡(2), 23-32=台胡(1), 33=重台卡(7), 34+=重台胡(6)
  /// "卡"版本倍数高于"胡"版本，应优先瞄准"卡"阈值
  int _huTypeDianpaoMultiplier(double huCount) {
    final hu = huCount.toInt();
    if (hu < 11) return -1; // 不足胡
    if (hu == 11) return 1; // 卡胡
    if (hu >= 12 && hu <= 21) return 0; // 普通胡
    if (hu == 22) return 2; // 台卡
    if (hu >= 23 && hu <= 32) return 1; // 台胡
    if (hu == 33) return 7; // 重台卡
    if (hu >= 34) return 6; // 重台胡
    return -1;
  }

  /// 胡牌类型倍数（自摸倍数）
  int _huTypeZimoMultiplier(double huCount) {
    final hu = huCount.toInt();
    if (hu < 11) return -1;
    if (hu == 11) return 2; // 卡胡
    if (hu >= 12 && hu <= 21) return 1; // 普通胡
    if (hu == 22) return 3; // 台卡
    if (hu >= 23 && hu <= 32) return 2; // 台胡
    if (hu == 33) return 8; // 重台卡
    if (hu >= 34) return 7; // 重台胡
    return -1;
  }

  /// 胡牌类型倍数层级加分
  /// 当出牌后胡数落在"卡"阈值(11/22/33)时给予加分，
  /// 当出牌后胡数从"卡"阈值跳到"胡"范围时给予惩罚
  /// 概率相同时，优先朝着倍数高的胡牌类型操作
  double _huTypeMultiplierBonus(double huBefore, double huAfter) {
    final multBefore = _huTypeDianpaoMultiplier(huBefore);
    final multAfter = _huTypeDianpaoMultiplier(huAfter);

    // 不足胡的情况不适用
    if (multBefore < 0 || multAfter < 0) return 0;

    // 倍数提升：加分（如从普通胡0→卡胡1，或从台胡1→台卡2）
    if (multAfter > multBefore) {
      return (multAfter - multBefore) * 100.0;
    }

    // 倍数下降：惩罚（如从卡胡1→普通胡0，或从台卡2→台胡1）
    if (multAfter < multBefore) {
      return (multAfter - multBefore) * 150.0; // 惩罚更重，避免降级
    }

    // 倍数相同：检查是否接近下一个"卡"阈值
    // 越接近下一个"卡"阈值，加分越高（鼓励向高倍数门槛推进）
    final huAfterInt = huAfter.toInt();
    double thresholdBonus = 0;
    if (huAfterInt >= 12 && huAfterInt <= 21) {
      // 在普通胡范围(12-21)，越接近22(台卡)加分越高
      thresholdBonus = (huAfterInt - 11) * 5.0;
    } else if (huAfterInt >= 23 && huAfterInt <= 32) {
      // 在台胡范围(23-32)，越接近33(重台卡)加分越高
      thresholdBonus = (huAfterInt - 22) * 8.0;
    }

    return thresholdBonus;
  }

  /// 获取门2-7组件基础分（路线相关）
  int _getMen27Score(_RouteType route, int componentIdx) {
    return _men27ComponentScore[route]![componentIdx];
  }

  /// 获取门1/8精字组件基础分（路线相关）
  int _getMen18JingScore(_RouteType route, int componentIdx) {
    return _men18JingComponentScore[route]![componentIdx];
  }

  /// 获取门1/8银字组件基础分（路线相关）
  int _getMen18YinScore(_RouteType route, int componentIdx) {
    return _men18YinComponentScore[route]![componentIdx];
  }

  /// 统一的对子计数方法（消除3个重复函数）
  /// 十对路线：3张算1对+1单，4张算2对
  /// 普通路线：3张算1对，4张算2对
  int _countHandPairsUnified(List<Card> hand) {
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
    return pairs;
  }

  // ==================== 核心计算模块（men-structure-score.md 第四部分） ====================

  /// 进张难度系数（规则13.3）
  /// ≥3张=1.0, 2张=1.2, 1张=1.5, 0张=∞(返回大数)
  double _drawDifficulty(int remainingCount) {
    if (remainingCount <= 0) return 999999.0; // 死听
    if (remainingCount == 1) return 1.5;
    if (remainingCount == 2) return 1.2;
    return 1.0; // ≥3张
  }

  /// 计算听牌距离（带难度系数）
  /// 距离 = 需要的进张次数 × 进张难度系数
  double _distanceToTingWithDifficulty(
    List<Card> hand,
    List<Meld> melds,
    Map<String, int> visibleCount,
    int totalUnknown,
  ) {
    final baseDist = _distanceToTing(hand, melds);
    if (baseDist == 0) return 0.0; // 已听牌

    // 计算所需进张字的平均难度系数
    // 简化：用手牌中孤张和半靠的进张难度估算
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

    double totalDifficulty = 0;
    int pathCount = 0;

    // 对/靠的进张难度
    for (final meld in dSet) {
      if (meld.type == MeldType.dui) {
        final ch = meld.cards.first.character;
        final rem = _remainingCount(ch, visibleCount);
        totalDifficulty += _drawDifficulty(rem);
        pathCount++;
      } else if (meld.type == MeldType.kao) {
        final chars = meld.cards.map((c) => c.character).toList();
        final missing = _findMissingCharForSentence(chars);
        if (missing != null) {
          final rem = _remainingCount(missing, visibleCount);
          totalDifficulty += _drawDifficulty(rem);
          pathCount++;
        }
      }
    }

    // 孤张的进张难度（需要先成对/靠）
    for (final card in eSet) {
      final otherChars = _groupChars[card.sentence - 1]
          .where((ch) => ch != card.character)
          .toList();
      int minRem = 0;
      for (final oc in otherChars) {
        final rem = _remainingCount(oc, visibleCount);
        if (rem > minRem) minRem = rem;
      }
      totalDifficulty += _drawDifficulty(minRem);
      pathCount++;
    }

    if (pathCount == 0) return baseDist.toDouble();
    final avgDifficulty = totalDifficulty / pathCount;
    return baseDist * avgDifficulty;
  }

  /// 死听检测（规则16）
  /// 返回: 0=非死听, 1=半死听(剩余1张), 2=死听(剩余0张)
  int _detectDeadTing(Player player, Map<String, int> visibleCount) {
    if (!player.isTing) return 0;

    final tingCards = player.tingCards;
    if (tingCards.isEmpty) return 0;

    int minRem = 999;
    for (final tc in tingCards) {
      final rem = _remainingCount(tc.character, visibleCount);
      if (rem < minRem) minRem = rem;
    }

    if (minRem == 0) return 2; // 死听
    if (minRem == 1) return 1; // 半死听
    return 0; // 非死听
  }

  /// 死听检测（给定测试玩家）
  int _detectDeadTingForTest(Player testPlayer, Map<String, int> visibleCount) {
    final tingResult = _checkTingCached(testPlayer);
    if (!tingResult.isTing) return 0;

    final tingCards = tingResult.tingCards;
    if (tingCards.isEmpty) return 0;

    int minRem = 999;
    for (final tc in tingCards) {
      final rem = _remainingCount(tc.character, visibleCount);
      if (rem < minRem) minRem = rem;
    }

    if (minRem == 0) return 2; // 死听
    if (minRem == 1) return 1; // 半死听
    return 0; // 非死听
  }

  /// 死听惩罚分（规则16.3-16.4）
  double _deadTingPenalty(int deadTingLevel) {
    switch (deadTingLevel) {
      case 2:
        return -200; // 死听惩罚
      case 1:
        return -50; // 半死听惩罚
      default:
        return 0;
    }
  }

  /// 摸牌期望值（规则14）
  /// 摸牌期望值 = Σ(每张未知牌的价值 × 该牌概率)
  double _drawExpectation(
    List<Card> hand,
    List<Meld> melds,
    Map<String, int> visibleCount,
    int totalUnknown,
  ) {
    if (totalUnknown <= 0) return 0;

    double totalValue = 0;
    final route = _currentRoute ?? _RouteType.normal;

    for (final ch in _allChars) {
      final rem = _remainingCount(ch, visibleCount);
      if (rem <= 0) continue;

      final prob = rem / totalUnknown;
      final sentence = _charSentenceMap[ch]!;
      final isJingMen = sentence == 1 || sentence == 8;
      final isJingChar = ch == '上' || ch == '福';
      final isYinChar = ch == '大' || ch == '人' || ch == '禄' || ch == '寿';

      // 模拟摸到该牌后的价值
      final testHand = List<Card>.from(hand);
      testHand.add(
        Card(
          id: -1,
          character: ch,
          sentence: sentence,
          position: _charPositionMap[ch]!,
        ),
      );
      final testPlayer = Player(
        id: -1,
        name: '',
        type: PlayerType.ai,
        hand: testHand,
        melds: melds,
      );

      // 检查是否能胡牌（自摸）
      if (HuCalculator.canHu(testHand, melds)) {
        totalValue += prob * 1000;
        continue;
      }

      // 检查是否能听牌
      final tingResult = TingChecker.checkTing(testPlayer);
      if (tingResult.isTing) {
        totalValue += prob * 500;
        continue;
      }

      // 计算组件分提升
      final byChar = <String, int>{};
      for (final c in hand) {
        if (c.sentence == sentence) {
          byChar[c.character] = (byChar[c.character] ?? 0) + 1;
        }
      }
      final curCnt = byChar[ch] ?? 0;
      double componentValue = 0;

      if (curCnt == 0) {
        // 0->1: 可能成靠或孤张
        final presentChars = _groupChars[sentence - 1]
            .where((c) => (byChar[c] ?? 0) >= 1)
            .toList();
        if (presentChars.length == 2) {
          componentValue = isJingMen
              ? _getMen18JingScore(route, _idxJingJu).toDouble()
              : _getMen27Score(route, _idxJu).toDouble();
        } else if (presentChars.length == 1) {
          componentValue =
              isJingMen &&
                  (presentChars.contains('上') || presentChars.contains('福'))
              ? _getMen18JingScore(route, _idxJingKao).toDouble()
              : (isJingMen
                    ? _getMen18YinScore(route, _idxYinKao).toDouble()
                    : _getMen27Score(route, _idxKao).toDouble());
        } else {
          componentValue = isJingMen
              ? (isJingChar
                    ? _getMen18JingScore(route, _idxJingDan).toDouble()
                    : (isYinChar
                          ? _getMen18YinScore(route, _idxYinDan).toDouble()
                          : _getMen27Score(route, _idxGu).toDouble()))
              : _getMen27Score(route, _idxGu).toDouble();
        }
      } else if (curCnt == 1) {
        // 1->2: 成对
        componentValue = isJingMen && isJingChar
            ? _getMen18JingScore(route, _idxJinDui).toDouble()
            : (isJingMen && isYinChar
                  ? _getMen18YinScore(route, _idxYinDui).toDouble()
                  : _getMen27Score(route, _idxDui).toDouble());
      } else if (curCnt == 2) {
        // 2->3: 成坎
        final before = isJingMen && isJingChar
            ? _getMen18JingScore(route, _idxJinDui).toDouble()
            : (isJingMen && isYinChar
                  ? _getMen18YinScore(route, _idxYinDui).toDouble()
                  : _getMen27Score(route, _idxDui).toDouble());
        final after = isJingMen && isJingChar
            ? _getMen18JingScore(route, _idxJingKan).toDouble()
            : _getMen27Score(route, _idxKan).toDouble();
        componentValue = after - before;
      } else if (curCnt == 3) {
        // 3->4: 成招
        final before = isJingMen && isJingChar
            ? _getMen18JingScore(route, _idxJingKan).toDouble()
            : _getMen27Score(route, _idxKan).toDouble();
        final after = isJingMen && isJingChar
            ? _getMen18JingScore(route, _idxJingZhao).toDouble()
            : _getMen27Score(route, _idxZhao).toDouble();
        componentValue = after - before;
      }

      totalValue += prob * componentValue;
    }

    return totalValue;
  }

  /// 牌效评估（规则15）
  /// 单张牌效 = Σ(组合分 × 组合概率)
  double _cardEfficiency(
    Card card,
    List<Card> hand,
    Map<String, int> visibleCount,
    int totalUnknown,
  ) {
    final route = _currentRoute ?? _RouteType.normal;
    final sentence = card.sentence;
    final ch = card.character;
    final isJingMen = sentence == 1 || sentence == 8;
    final isJingChar = ch == '上' || ch == '福';
    final isYinChar = ch == '大' || ch == '人' || ch == '禄' || ch == '寿';
    final groupChars = _groupChars[sentence - 1];

    double efficiency = 0;

    // 统计同门各字张数
    final byChar = <String, int>{};
    for (final c in hand) {
      if (c.sentence == sentence) {
        byChar[c.character] = (byChar[c.character] ?? 0) + 1;
      }
    }
    final chCnt = byChar[ch] ?? 0;

    // 路径1: 摸同字成对/坎/招
    final remSelf = _remainingCount(ch, visibleCount);
    if (remSelf > 0 && totalUnknown > 0) {
      final prob = remSelf / totalUnknown;
      if (chCnt == 1) {
        // 成对
        final val = isJingMen && isJingChar
            ? _getMen18JingScore(route, _idxJinDui).toDouble()
            : (isJingMen && isYinChar
                  ? _getMen18YinScore(route, _idxYinDui).toDouble()
                  : _getMen27Score(route, _idxDui).toDouble());
        efficiency += prob * val;
      } else if (chCnt == 2) {
        // 成坎
        final val = isJingMen && isJingChar
            ? _getMen18JingScore(route, _idxJingKan).toDouble()
            : _getMen27Score(route, _idxKan).toDouble();
        efficiency += prob * (val - _getMen27Score(route, _idxDui).toDouble());
      }
    }

    // 路径2: 摸同门其他字成靠/句
    for (final oc in groupChars) {
      if (oc == ch) continue;
      final rem = _remainingCount(oc, visibleCount);
      if (rem <= 0 || totalUnknown <= 0) continue;
      final prob = rem / totalUnknown;
      final ocCnt = byChar[oc] ?? 0;

      // 如果已有2种字，摸第3种成句
      final presentChars = groupChars
          .where((c) => (byChar[c] ?? 0) >= 1)
          .toList();
      if (presentChars.length == 2 && !presentChars.contains(oc)) {
        // 成句
        final val = isJingMen
            ? _getMen18JingScore(route, _idxJingJu).toDouble()
            : _getMen27Score(route, _idxJu).toDouble();
        efficiency += prob * val;
      } else if (ocCnt == 0 && chCnt >= 1) {
        // 成靠
        final val =
            isJingMen && (ch == '上' || ch == '福' || oc == '上' || oc == '福')
            ? _getMen18JingScore(route, _idxJingKao).toDouble()
            : (isJingMen
                  ? _getMen18YinScore(route, _idxYinKao).toDouble()
                  : _getMen27Score(route, _idxKao).toDouble());
        efficiency += prob * val;
      }
    }

    return efficiency;
  }

  /// 胡数附加分（规则11，仅普通胡路线）
  double _huScoreBonus(double componentHu, int currentHu, _RouteType route) {
    if (route != _RouteType.normal) return 0;
    final huWeight = math.max(0, (11 - currentHu) / 11) * 2;
    return componentHu * huWeight;
  }

  /// 胡数资格保护（规则16.9）
  /// 出牌前胡数≥11 且 出牌后胡数<11 且 无特殊胡牌潜力 → 跳过该出牌
  bool _shouldProtectHuQualify(
    int huBefore,
    int huAfter,
    double shiDuiPotential,
    double heiYuanPotential,
    double hongYuanPotential,
    double kuHuPotential,
  ) {
    if (huBefore >= 11 && huAfter < 11) {
      // 特殊胡牌潜力>0时，不受11胡限制
      if (shiDuiPotential > 0 ||
          heiYuanPotential > 0 ||
          hongYuanPotential > 0 ||
          kuHuPotential > 0) {
        return false;
      }
      return true;
    }
    return false;
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
  /// 已统一到 _countHandPairsUnified
  int _countPairsFromHandAndMelds(List<Card> hand, List<Meld> melds) {
    return _countHandPairsUnified(hand);
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

  /// 计算某门当前能成的最大句数（每字至少1张才能成1句）
  /// byChar: 该门各字张数 {字: 张数}
  /// chars: 该门的3个字
  int _calcMaxSentences(Map<String, int> byChar, List<String> chars) {
    final presentCnt = chars.where((c) => (byChar[c] ?? 0) > 0).length;
    if (presentCnt < 3) return 0;
    int maxSentences = chars
        .map((c) => byChar[c] ?? 0)
        .reduce((a, b) => a < b ? a : b);
    return maxSentences > 2 ? 2 : maxSentences;
  }

  /// 黑元路线下计算某张牌所在门的"成句难度"分数（考虑吃牌因素）
  /// 难度越高，该牌越应优先打出
  /// byChar: 该门各字张数（出牌前状态）
  /// chars: 该门的3个字
  /// visibleCount: 牌面可见牌统计
  /// totalUnknown: 未知牌总数
  double _calcHeiYuanDifficulty(
    Map<String, int> byChar,
    List<String> chars,
    Map<String, int> visibleCount,
    int totalUnknown,
  ) {
    // 1. 当前能成最大句数（不靠吃牌）
    final maxSentences = _calcMaxSentences(byChar, chars);

    // 2. 考虑吃牌后的成句能力
    //    枚举吃1张牌的所有可能，找出最大句数增量
    int bestChiGain = 0;
    double bestChiProb = 0;
    for (final ch in chars) {
      final rem = _remainingCount(ch, visibleCount);
      if (rem == 0) continue; // 牌面无剩余，无法吃到

      // 模拟吃1张ch后的状态
      final afterByChar = Map<String, int>.from(byChar);
      afterByChar[ch] = (afterByChar[ch] ?? 0) + 1;
      final sentencesAfter = _calcMaxSentences(afterByChar, chars);
      final gain = sentencesAfter - maxSentences;

      // 选择句数增量最大的吃牌方案
      // 同增量下选概率高的
      final prob = rem / totalUnknown;
      if (gain > bestChiGain || (gain == bestChiGain && prob > bestChiProb)) {
        bestChiGain = gain;
        bestChiProb = prob;
      }
    }

    // 3. 有效句数 = 当前句数 + 吃牌增量（概率>10%才认定吃牌增量生效）
    int effectiveSentences = maxSentences;
    if (bestChiGain > 0 && bestChiProb > 0.1) {
      effectiveSentences = maxSentences + bestChiGain;
    }

    // 4. 成2句所需进张数（基于当前手牌）
    int neededFor2 = 0;
    bool insufficient = false;
    for (final ch in chars) {
      final have = byChar[ch] ?? 0;
      final need = 2 - have;
      if (need > 0) {
        neededFor2 += need;
        if (_remainingCount(ch, visibleCount) < need) {
          insufficient = true;
        }
      }
    }

    // 5. 综合难度分数
    final difficulty =
        (2 - effectiveSentences) *
            300.0 // 维度1：有效句数
            +
        neededFor2 *
            100.0 // 维度2：进张缺口
            +
        (insufficient ? 500.0 : 0.0) // 维度3：余牌不足硬阻断
        -
        bestChiProb * 150.0; // 维度4：吃牌概率高则难度降低

    return difficulty;
  }

  int _totalUnknownCards(Player player, GameState state) {
    return state.totalUnknownCards(player);
  }

  bool _isLateGame(GameState state) {
    // 规则：终盘<30张
    return state.deck.length < 30;
  }

  bool _isEarlyGame(GameState state) {
    // 规则：序盘>60张
    return state.deck.length > 60;
  }

  bool _isMidGame(GameState state) {
    // 规则：中盘30-60张
    final deck = state.deck.length;
    return deck >= 30 && deck <= 60;
  }

  bool _isFlowPeriod(GameState state) {
    // 规则：流局期<10张
    return state.deck.length < 10;
  }

  _GamePhase _getGamePhase(GameState state) {
    final deck = state.deck.length;
    if (deck < 10) return _GamePhase.flow;
    if (deck < 30) return _GamePhase.late;
    if (deck <= 60) return _GamePhase.mid;
    return _GamePhase.early;
  }

  int _countHandPairs(List<Card> hand) {
    return _countHandPairsUnified(hand);
  }

  /// 计算手牌中的对子数（十对路线专用，不从组合牌算对子）
  /// 十对要求是手牌10对，组合牌不参与十对计算
  /// 已统一到 _countHandPairsUnified
  int _countHandPairsWithMelds(Player player) {
    return _countHandPairsUnified(player.hand);
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
  double _evaluateHeiYuanPotential(Player player) {
    // 有碰(坎)或招则不能黑元
    final hasPeng = player.melds.any((m) => m.type == MeldType.kan);
    final hasZhao = player.melds.any((m) => m.type == MeldType.zhao);
    if (hasPeng || hasZhao) return -1;

    // 组合牌中有门1(上大人)或门8(福禄寿)的句，不追求黑元
    // 因为已经投入了门1/8牌到组合牌中，黑元要求无门1/8牌
    final hasGroup18Ju = player.melds.any(
      (m) =>
          m.type == MeldType.ju &&
          (m.cards.first.sentence == 1 || m.cards.first.sentence == 8),
    );
    if (hasGroup18Ju) return -1;

    // 检查所有牌（手牌+组合牌）是否都属于组2-7，且无"上"/"福"
    final allCards = [...player.hand, ...player.melds.expand((m) => m.cards)];
    bool hasGroup18 = false;
    int group18Count = 0;
    for (final c in allCards) {
      if (c.sentence == 1 || c.sentence == 8) {
        hasGroup18 = true;
        group18Count++;
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

    // 主动黑元策略：门1+门8张数<=3且总胡数<=10胡时，主动追求黑元
    // 黑元给4-5番，普通胡不足11胡给0番，所以胡数<11时应优先黑元
    // 返回较低潜力值，引导AI优先清理门1/8牌
    if (group18Count <= 3) {
      final totalHu = _evaluateHuScore(player);
      if (totalHu <= 10) {
        // 放弃黑元条件：门1/8胡数>=8 且 门1/8总张数>=4 且 2-7门手牌有超过两对
        // 门1/8胡数高+张数多说明门1/8价值大，2-7门对子多说明普通胡路线可行
        int group18Hu = 0;
        // 组合牌中门1/8的胡数
        for (final meld in player.melds) {
          if (meld.cards.first.sentence == 1 ||
              meld.cards.first.sentence == 8) {
            group18Hu += meld.getHuCount(isHand: false);
          }
        }
        // 手牌中门1/8的胡数
        final hand18Cards =
            player.hand.where((c) => c.sentence == 1 || c.sentence == 8).toList();
        if (hand18Cards.isNotEmpty) {
          final hand18Remaining = List<Card>.from(hand18Cards);
          final hand18ASet = <Meld>[];
          final hand18BSet = <Meld>[];
          final hand18CSet = <Meld>[];
          final hand18DSet = <Meld>[];
          HuCalculator.extractJu(hand18Remaining, hand18ASet);
          HuCalculator.extractZhao(hand18Remaining, hand18BSet);
          HuCalculator.extractKan(hand18Remaining, hand18CSet);
          HuCalculator.extractDuiAndKao(hand18Remaining, hand18DSet);
          for (final m in hand18ASet) {
            group18Hu += m.getHuCount(isHand: true);
          }
          for (final m in hand18BSet) {
            group18Hu += m.getHuCount(isHand: true);
          }
          for (final m in hand18CSet) {
            group18Hu += m.getHuCount(isHand: true);
          }
          for (final m in hand18DSet) {
            group18Hu += m.getHuCount(isHand: true);
          }
          for (final c in hand18Remaining) {
            // 精单(上/福)4胡，银单0胡，普单0胡
            group18Hu += (c.character == '上' || c.character == '福') ? 4 : 0;
          }
        }
        // 统计2-7门手牌中的对子数
        final byChar27 = <String, int>{};
        for (final c in player.hand) {
          if (c.sentence >= 2 && c.sentence <= 7) {
            byChar27[c.character] = (byChar27[c.character] ?? 0) + 1;
          }
        }
        final pairCount27 =
            byChar27.values.where((cnt) => cnt >= 2).length;
        if (group18Hu >= 8 && group18Count >= 4 && pairCount27 > 2) {
          return -1;
        }

        // 严格条件1：手牌中不能有招（4张同字），但允许有坎（3张同字）
        // 招（4张）无法组成句且占用过多，但坎（3张）可通过出牌拆掉转化为句
        final byChar = <String, int>{};
        for (final c in player.hand) {
          byChar[c.character] = (byChar[c.character] ?? 0) + 1;
        }
        final hasHandZhao = byChar.values.any((cnt) => cnt >= 4);
        if (hasHandZhao) return -1;

        // 如果手牌有坎，检查坎所在门是否有其他字可以组句
        // 坎只有能转化为句时才允许黑元（出掉多余的同字，保留1张组句）
        final kanChars = byChar.entries
            .where((e) => e.value == 3)
            .map((e) => e.key)
            .toList();
        for (final kanChar in kanChars) {
          final kanSentence = _charSentenceMap[kanChar]!;
          final sameSentenceOtherChars = player.hand
              .where((c) => c.sentence == kanSentence && c.character != kanChar)
              .map((c) => c.character)
              .toSet();
          // 坎所在门需要有至少1个其他字，才能通过出牌把坎转化为句
          if (sameSentenceOtherChars.isEmpty) return -1;
        }

        // 严格条件2：手牌结构需要接近黑元（6句+1靠）
        // 统计手牌中可成句的组合数（含已提取句和潜在句）
        int sentenceCount = 0;
        for (final meld in player.melds) {
          if (meld.type == MeldType.ju) sentenceCount++;
        }
        final handRemaining = List<Card>.from(player.hand);
        final handASet = <Meld>[];
        HuCalculator.extractJu(handRemaining, handASet);
        sentenceCount += handASet.length;

        // 黑元需要6句+1靠，已有句数+潜在句数（半靠）至少要达到4
        // 否则距离黑元太远，不应主动追求
        // 统计潜在句数：同门有2种不同字各1张（半靠），差1张成句
        final handRemaining2 = List<Card>.from(player.hand);
        final handASet2 = <Meld>[];
        HuCalculator.extractJu(handRemaining2, handASet2);
        final bySentence = <int, Set<String>>{};
        for (final c in handRemaining2) {
          bySentence.putIfAbsent(c.sentence, () => <String>{});
          bySentence[c.sentence]!.add(c.character);
        }
        int potentialSentences = 0;
        for (final entry in bySentence.entries) {
          if (entry.value.length == 2) {
            potentialSentences++;
          }
        }
        final totalPotentialSentences = sentenceCount + potentialSentences;
        if (totalPotentialSentences < 4) return -1;

        // 门1/8牌越少，潜力越高（越接近完全黑元）
        // 有坎时降低潜力值（需要额外出牌拆坎）
        double kanPenalty = kanChars.isNotEmpty ? 20.0 : 0.0;
        return 50.0 +
            sentenceCount * 30.0 +
            (3 - group18Count) * 10.0 -
            kanPenalty;
      }
    }

    return -1;
  }

  /// 评估红元路线潜力：返回>0表示有红元潜力
  /// 红元条件：无碰无招，组合牌全是句
  /// 组1/组8句>=3，其它门都是句子，2张半靠将牌来自门1/8，上/福总数3-6张
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
    // 门1/8牌数量越多越容易组成3个句
    final door18CardCount = allCards
        .where((c) => c.sentence == 1 || c.sentence == 8)
        .length;
    return 60.0 +
        totalSpecialSentenceCount * 50.0 +
        shangFuCount * 15.0 +
        door18CardCount * 3.0;
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
    // 记录当前最佳弃牌的对子状态：0=孤张, 1=对子以上
    // 距离相同时优先弃孤张，保留对子（与selectDiscard的综合评分保持一致）
    int bestPairStatus = 99;

    for (final card in hand) {
      final testHand = List<Card>.from(hand);
      testHand.remove(card);
      final dist = _distanceToTing(testHand, melds);
      // 该牌在手牌中的数量：1=孤张, >=2=对子以上
      final cardCount = hand.where((c) => c.character == card.character).length;
      final pairStatus = cardCount >= 2 ? 1 : 0;

      if (dist < bestDist) {
        bestDist = dist;
        bestHand = testHand;
        bestPairStatus = pairStatus;
      } else if (dist == bestDist) {
        // 距离相同时，优先弃孤张（pairStatus=0），保留对子（pairStatus=1）
        if (pairStatus < bestPairStatus) {
          bestHand = testHand;
          bestPairStatus = pairStatus;
        } else if (pairStatus == bestPairStatus &&
            visibleCount != null &&
            totalUnknown != null) {
          // 距离和对子状态都相同，优先出进张少的牌（保留进张多的牌）
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
            bestHand = testHand;
          }
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
      final tingCard = _selectDiscardWhenTing(player, state);
      if (tingCard != null) return tingCard;
      // 死听且无法切换到有效听牌，回退到综合评分重新组织牌型
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

    // 获取黑元路线潜力（用于黑元路线下的吃牌优化）
    final heiYuanPotential = _evaluateHeiYuanPotential(player);

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
      // 吃牌只消耗1张该字，而不是所有（避免破坏多余对子/坎）
      final idx = testHand.indexWhere((c) => c.character == ch);
      if (idx >= 0) {
        testHand.removeAt(idx);
      }
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
    if (tingAfter.isTing) {
      // 听牌收益考虑胡牌类型倍数：卡胡/台卡/重台卡倍数更高
      final huAfter = _evaluateHuScore(testPlayer);
      final zimoMult = _huTypeZimoMultiplier(huAfter);
      if (zimoMult > 0) {
        return 10000 + zimoMult * 200;
      }
      return 10000;
    }

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

    // 绝版孤张惩罚：吃牌后手牌中如果有绝版牌（剩余0张）且只有1张，
    // 该牌无法组成任何组合（对子/坎/句），是死牌，严重惩罚
    final bestHandCharCount = <String, int>{};
    for (final c in bestHand) {
      bestHandCharCount[c.character] =
          (bestHandCharCount[c.character] ?? 0) + 1;
    }
    // 提取bestHand中的句，用于判断字是否参与句
    final bestHandRemaining = List<Card>.from(bestHand);
    final bestHandJuSet = <Meld>[];
    HuCalculator.extractJu(bestHandRemaining, bestHandJuSet);
    final charsInJu = <String>{};
    for (final m in bestHandJuSet) {
      for (final c in m.cards) {
        charsInJu.add(c.character);
      }
    }
    for (final entry in bestHandCharCount.entries) {
      if (entry.value == 1) {
        final rem = _remainingCount(entry.key, visibleCount);
        if (rem == 0) {
          // 参与句的字不是孤张，不惩罚
          if (charsInJu.contains(entry.key)) continue;
          benefit -= 800;
        }
      }
    }

    // 黑元路线下的吃牌优化
    // 黑元需要6句+1靠，吃牌后手牌中形成半靠（而不是孤张）更接近成句
    // 但吃牌后需要有多余牌可以打（招/坎/对子/单张），否则没有必要吃
    if (heiYuanPotential > 0) {
      // 使用testHand（吃牌后未出牌前的手牌）来判断，而不是bestHand（出牌后）
      // 因为bestHand可能已经把半靠拆掉了，无法正确判断
      final testHandCharCount = <String, int>{};
      for (final c in testHand) {
        testHandCharCount[c.character] =
            (testHandCharCount[c.character] ?? 0) + 1;
      }
      // 提取testHand中的句，用于判断字是否参与句
      final testHandRemaining = List<Card>.from(testHand);
      final testHandJuSet = <Meld>[];
      HuCalculator.extractJu(testHandRemaining, testHandJuSet);
      final testHandCharsInJu = <String>{};
      for (final m in testHandJuSet) {
        for (final c in m.cards) {
          testHandCharsInJu.add(c.character);
        }
      }

      // 检查testHand中是否形成半靠（同门2张不同字，且不构成完整句）
      // 只检查吃牌所在门，因为半靠应该是由吃牌形成的（如吃八后剩八九半靠）
      final testHandBySentence = <int, Set<String>>{};
      for (final c in testHand) {
        testHandBySentence.putIfAbsent(c.sentence, () => <String>{});
        testHandBySentence[c.sentence]!.add(c.character);
      }
      bool hasHalfKao = false;
      int halfKaoSentence = -1;
      Set<String>? halfKaoChars;
      // 只检查吃牌所在门是否形成半靠
      final cardSentence = card.sentence;
      final cardSentenceChars = testHandBySentence[cardSentence];
      if (cardSentenceChars != null && cardSentenceChars.length == 2) {
        hasHalfKao = true;
        halfKaoSentence = cardSentence;
        halfKaoChars = cardSentenceChars;
      }

      // 检查半靠所需的第三个字剩余张数
      // 如果半靠所需的字剩余0张，半靠无法成句，不应该吃
      bool halfKaoCanFormSentence = true;
      if (hasHalfKao && halfKaoChars != null) {
        // 找出半靠所需的第三个字（同门中不在半靠中的字）
        final groupChars = _groupChars[halfKaoSentence - 1];
        final neededChar = groupChars.firstWhere(
          (ch) => !halfKaoChars!.contains(ch),
        );
        // 检查第三个字的剩余张数
        final rem = _remainingCount(neededChar, visibleCount);
        if (rem == 0) {
          halfKaoCanFormSentence = false;
        }
      }

      // 检查吃牌后是否有牌可以打（招/坎/对子/单张等多余牌）
      // 多余牌定义：除去完整句后剩余的招/坎/对子/单张
      // 注意：半靠中的牌不算多余牌（半靠是黑元路线的目标结构）
      bool hasExcessCard = false;
      for (final entry in testHandCharCount.entries) {
        if (entry.value >= 4) {
          hasExcessCard = true; // 招
          break;
        }
        if (entry.value >= 3) {
          hasExcessCard = true; // 坎
          break;
        }
        if (entry.value >= 2 && !testHandCharsInJu.contains(entry.key)) {
          hasExcessCard = true; // 对子（不参与句的）
          break;
        }
      }
      // 检查是否有单张（不参与句的单张，且不属于半靠）
      if (!hasExcessCard) {
        for (final entry in testHandCharCount.entries) {
          if (entry.value == 1 && !testHandCharsInJu.contains(entry.key)) {
            // 排除半靠中的牌（半靠是黑元路线的目标结构，不是多余牌）
            if (hasHalfKao &&
                halfKaoChars != null &&
                halfKaoChars.contains(entry.key)) {
              continue;
            }
            hasExcessCard = true; // 单张
            break;
          }
        }
      }

      if (hasHalfKao && hasExcessCard && halfKaoCanFormSentence) {
        // 形成半靠且有多余牌可以打且半靠可成句，给予额外加分
        // 吃牌后既多了1个句子（组合牌区），又保留了半靠（手牌），更接近黑元听牌
        benefit += 500;
      } else if (hasHalfKao && !halfKaoCanFormSentence) {
        // 半靠所需的字剩余0张，半靠无法成句，不应该吃
        // 这种情况下应该摸牌，而不是吃牌
        return -1;
      } else if (hasHalfKao && !hasExcessCard) {
        // 没有多余牌可以打，吃牌后只能打出半靠中的一张，损失半靠
        // 这种情况下没有必要吃
        return -1;
      }
    }

    // 路线进度加分（规则二十四）
    final route = _currentRoute ?? _RouteType.normal;
    benefit += _routeOperationBonus('chi', route);

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

    // 获取黑元路线潜力（用于黑元路线下的吃牌优化）
    final heiYuanPotential = _evaluateHeiYuanPotential(player);

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
      // 吃牌只消耗1张该字，而不是所有（避免破坏多余对子/坎）
      final idx = testHand.indexWhere((c) => c.character == ch);
      if (idx >= 0) {
        testHand.removeAt(idx);
      }
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
    if (tingAfter.isTing) {
      // 听牌收益考虑胡牌类型倍数：卡胡/台卡/重台卡倍数更高
      final huAfter = _evaluateHuScore(testPlayer);
      final zimoMult = _huTypeZimoMultiplier(huAfter);
      if (zimoMult > 0) {
        return 10000 + zimoMult * 200;
      }
      return 10000;
    }

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

    // 绝版孤张惩罚：吃牌后手牌中如果有绝版牌（剩余0张）且只有1张，
    // 该牌无法组成任何组合（对子/坎/句），是死牌，严重惩罚
    // 例外：该字参与了完整句（句中3种字都有），不是孤张，不惩罚
    final bestHandCharCount = <String, int>{};
    for (final c in bestHand) {
      bestHandCharCount[c.character] =
          (bestHandCharCount[c.character] ?? 0) + 1;
    }
    // 提取bestHand中的句，用于判断字是否参与句
    final bestHandRemaining = List<Card>.from(bestHand);
    final bestHandJuSet = <Meld>[];
    HuCalculator.extractJu(bestHandRemaining, bestHandJuSet);
    final charsInJu = <String>{};
    for (final m in bestHandJuSet) {
      for (final c in m.cards) {
        charsInJu.add(c.character);
      }
    }
    double juebanPenalty = 0;
    for (final entry in bestHandCharCount.entries) {
      if (entry.value == 1) {
        final rem = _remainingCount(entry.key, visibleCount);
        if (rem == 0) {
          // 参与句的字不是孤张，不惩罚
          if (charsInJu.contains(entry.key)) continue;
          juebanPenalty -= 800;
        }
      }
    }
    benefit += juebanPenalty;

    // 黑元路线下的吃牌优化
    // 黑元需要6句+1靠，吃牌后手牌中形成半靠（而不是孤张）更接近成句
    // 但吃牌后需要有多余牌可以打（招/坎/对子/单张），否则没有必要吃
    if (heiYuanPotential > 0) {
      // 使用testHand（吃牌后未出牌前的手牌）来判断，而不是bestHand（出牌后）
      // 因为bestHand可能已经把半靠拆掉了，无法正确判断
      final testHandCharCount = <String, int>{};
      for (final c in testHand) {
        testHandCharCount[c.character] =
            (testHandCharCount[c.character] ?? 0) + 1;
      }
      // 提取testHand中的句，用于判断字是否参与句
      final testHandRemaining = List<Card>.from(testHand);
      final testHandJuSet = <Meld>[];
      HuCalculator.extractJu(testHandRemaining, testHandJuSet);
      final testHandCharsInJu = <String>{};
      for (final m in testHandJuSet) {
        for (final c in m.cards) {
          testHandCharsInJu.add(c.character);
        }
      }

      // 检查testHand中是否形成半靠（同门2张不同字，且不构成完整句）
      // 只检查吃牌所在门，因为半靠应该是由吃牌形成的（如吃八后剩八九半靠）
      final testHandBySentence = <int, Set<String>>{};
      for (final c in testHand) {
        testHandBySentence.putIfAbsent(c.sentence, () => <String>{});
        testHandBySentence[c.sentence]!.add(c.character);
      }
      bool hasHalfKao = false;
      int halfKaoSentence = -1;
      Set<String>? halfKaoChars;
      // 只检查吃牌所在门是否形成半靠
      final cardSentence = card.sentence;
      final cardSentenceChars = testHandBySentence[cardSentence];
      if (cardSentenceChars != null && cardSentenceChars.length == 2) {
        hasHalfKao = true;
        halfKaoSentence = cardSentence;
        halfKaoChars = cardSentenceChars;
      }

      // 检查半靠所需的第三个字剩余张数
      // 如果半靠所需的字剩余0张，半靠无法成句，不应该吃
      bool halfKaoCanFormSentence = true;
      if (hasHalfKao && halfKaoChars != null) {
        // 找出半靠所需的第三个字（同门中不在半靠中的字）
        final groupChars = _groupChars[halfKaoSentence - 1];
        final neededChar = groupChars.firstWhere(
          (ch) => !halfKaoChars!.contains(ch),
        );
        // 检查第三个字的剩余张数
        final rem = _remainingCount(neededChar, visibleCount);
        if (rem == 0) {
          halfKaoCanFormSentence = false;
        }
      }

      // 检查吃牌后是否有牌可以打（招/坎/对子/单张等多余牌）
      // 多余牌定义：除去完整句后剩余的招/坎/对子/单张
      // 注意：半靠中的牌不算多余牌（半靠是黑元路线的目标结构）
      bool hasExcessCard = false;
      for (final entry in testHandCharCount.entries) {
        if (entry.value >= 4) {
          hasExcessCard = true; // 招
          break;
        }
        if (entry.value >= 3) {
          hasExcessCard = true; // 坎
          break;
        }
        if (entry.value >= 2 && !testHandCharsInJu.contains(entry.key)) {
          hasExcessCard = true; // 对子（不参与句的）
          break;
        }
      }
      // 检查是否有单张（不参与句的单张，且不属于半靠）
      if (!hasExcessCard) {
        for (final entry in testHandCharCount.entries) {
          if (entry.value == 1 && !testHandCharsInJu.contains(entry.key)) {
            // 排除半靠中的牌（半靠是黑元路线的目标结构，不是多余牌）
            if (hasHalfKao &&
                halfKaoChars != null &&
                halfKaoChars.contains(entry.key)) {
              continue;
            }
            hasExcessCard = true; // 单张
            break;
          }
        }
      }

      if (hasHalfKao && hasExcessCard && halfKaoCanFormSentence) {
        // 形成半靠且有多余牌可以打且半靠可成句，给予额外加分
        // 吃牌后既多了1个句子（组合牌区），又保留了半靠（手牌），更接近黑元听牌
        benefit += 500;
      } else if (hasHalfKao && !halfKaoCanFormSentence) {
        // 半靠所需的字剩余0张，半靠无法成句，不应该吃
        // 这种情况下应该摸牌，而不是吃牌
        return -1;
      } else if (hasHalfKao && !hasExcessCard) {
        // 没有多余牌可以打，吃牌后只能打出半靠中的一张，损失半靠
        // 这种情况下没有必要吃
        return -1;
      }
    }

    // 路线进度加分（规则二十四）
    final route = _currentRoute ?? _RouteType.normal;
    benefit += _routeOperationBonus('chi', route);

    return benefit;
  }

  Card? _selectDiscardWhenTing(Player player, GameState state) {
    final hand = player.hand;
    final visibleCount =
        _cachedVisibleCount ?? _buildVisibleCharCount(player, state);
    final totalUnknown =
        _cachedTotalUnknown ?? _totalUnknownCards(player, state);

    // 死听检测：所有听牌卡牌剩余张数都为0，无法通过点炮胡牌
    bool isDeadTing = false;
    if (player.tingCards.isNotEmpty) {
      isDeadTing = true;
      for (final tc in player.tingCards) {
        final rem = _remainingCount(tc.character, visibleCount);
        if (rem > 0) {
          isDeadTing = false;
          break;
        }
      }
    }

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
      // 招（4张同字）不能出，跳过
      // 手牌坎（3张同字）出1张变对子，损失3胡但可能形成听牌，不跳过
      if (_isPartOfZhao(card, hand)) continue;

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

    // 死听状态下，如果没有找到有效听牌（所有方案都是死听或不听牌），
    // 返回null让调用者回退到综合评分，重新组织牌型追求新听牌
    if (isDeadTing && (bestCard == null || bestTingCount <= 0)) {
      return null;
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

    // 调试日志：打印路线潜力值
    final totalHuDebug = _evaluateHuScore(player);
    final allCardsDebug = [
      ...player.hand,
      ...player.melds.expand((m) => m.cards),
    ];
    int group18CountDebug = 0;
    for (final c in allCardsDebug) {
      if (c.sentence == 1 || c.sentence == 8) group18CountDebug++;
    }
    GameLogger.i(
      'AI_HEIYUAN_DEBUG',
      'heiYuanPotential=$heiYuanPotential totalHu=$totalHuDebug group18Count=$group18CountDebug hand=${player.hand.map((c) => c.character).join()}',
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
        // 手牌中3张同字（手牌坎），出1张变对子，损失3胡
        // 不完全禁止，让huLoss惩罚覆盖3胡损失
        // 特殊情况下可出（如出该牌能保留精句，比出其他牌破坏精句更优时）
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
          // 非十对路线：手牌坎出1张变对子，不跳过
          // huLoss惩罚（3胡*50=150分）已覆盖损失，继续评估
          final cc = _cachedCharCount ?? _buildCharCount(hand);
          final charCount = cc[card.character] ?? 0;
          if (charCount > 3) {
            // 4张以上由_isPartOfZhao处理，此处不应到达
            scored.add(MapEntry(card, -5000));
            continue;
          }
          // charCount == 3：手牌坎，继续评估
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

          // 只有胡数资格满足且有效听牌（tingRem>0）时，才考虑作为bestTingCard
          // 死听（tingRem==0）不作为bestTingCard，让综合评分接管
          if (huQualifyMet &&
              tingRem > 0 &&
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
          // 死听（tingRem==0）时，听牌无实际价值，大幅降低评分让综合评分接管
          if (tingRem == 0) {
            tingScore -= 9000;
          }
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

      // 胡数资格保护（规则16.9）：出牌前胡数≥11 且 出牌后胡数<11 且 无特殊胡牌潜力 → 跳过
      final huBefore = _evaluateHuScore(player).toInt();
      final huAfter = _evaluateHuScore(testPlayer).toInt();
      if (_shouldProtectHuQualify(
        huBefore,
        huAfter,
        shiDuiPotential,
        heiYuanPotential,
        hongYuanPotential,
        kuHuPotential,
      )) {
        scored.add(MapEntry(card, -100000));
        continue;
      }

      // 死听检测（规则16）：出牌后导致死听/半死听时施加惩罚
      if (quickDist <= 2) {
        final deadTingLevel = _detectDeadTingForTest(testPlayer, visibleCount);
        score += _deadTingPenalty(deadTingLevel);
      }

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

    // 提前计算出牌前后胡数，用于后续胡数相关判断
    final huBefore = _evaluateHuScore(player);
    final huAfter = _evaluateHuScore(testPlayer);
    final huBeforeInt = huBefore.toInt();
    final huAfterInt = huAfter.toInt();

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
    final menScoreDelta = (menScoreAfter - menScoreBefore) * 0.3;
    score += menScoreDelta;

    // card-group-type.md 规则评分：牌型分类、保留价值排名、门间优先级、剩余张数动态调整
    // 作为出牌决策的补充评分，权重适中
    final cardGroupTypeScore = _evaluateDiscardByCardGroupType(
      player,
      cardToDiscard,
      visibleCount,
      shiDuiPotential,
      heiYuanPotential,
      hongYuanPotential,
      kuHuPotential,
      huBeforeInt,
      huAfterInt,
    );
    score += cardGroupTypeScore * 0.5;

    // 路线出牌优先级加分（规则二十）
    final routeBonus = _routeDiscardPriorityBonus(
      cardToDiscard,
      player,
      huBeforeInt,
      huAfterInt,
      visibleCount,
      totalUnknown,
    );
    score += routeBonus * 0.3;

    // 胡牌类型倍数层级加分（概率相同时优先朝着倍数高的胡牌类型操作）
    // 卡胡(11胡,倍数1) > 普通胡(12-21胡,倍数0)
    // 台卡(22胡,倍数2) > 台胡(23-32胡,倍数1)
    // 重台卡(33胡,倍数7) > 重台胡(34+胡,倍数6)
    // 仅普通胡路线适用（特殊路线不受胡数门槛限制）
    final route = _currentRoute ?? _RouteType.normal;
    if (route == _RouteType.normal &&
        shiDuiPotential <= 0 &&
        heiYuanPotential <= 0 &&
        hongYuanPotential <= 0 &&
        kuHuPotential <= 0) {
      final multBonus = _huTypeMultiplierBonus(huBefore, huAfter);
      score += multBonus * 0.5;
    }

    // 流局期防守策略（规则34）
    if (_isFlowPeriod(state)) {
      final defenseMult = _flowDefenseMultiplier(state);
      // 流局期防守权重提升
      if (_shouldDefendInFlowPeriod(player, state)) {
        // 放弃进攻，优先出安全牌
        if (_isSafeCard(cardToDiscard, player, state, visibleCount)) {
          score += 500 * defenseMult;
        }
      }
      // 流局期危险分加权
      final danger = _evaluateDanger(
        player,
        cardToDiscard,
        state,
        isLate,
        myDist: quickDist,
      );
      score -= danger * defenseMult;
    }

    double lookaheadScore = 0;
    if (distToTing <= 4) {
      lookaheadScore = _lookaheadScore(
        testHand,
        player.melds,
        visibleCount,
        totalUnknown,
        availableChars,
      );
      score += lookaheadScore;
    }

    if (shiDuiPotential > 0) {
      final testPairCount = _countHandPairsWithMelds(testPlayer);
      if (testPairCount >= 7) {
        score += testPairCount * 20.0;
      }
    }

    if (cardToDiscard.isJing) {
      // 黑元路线下，精字(上/福)是门1/8牌，需要优先打出清理，不惩罚
      if (heiYuanPotential <= 0) {
        // 胡数足够(>=11)且出牌后仍>=11时，精字惩罚大幅降低
        // 因为胡数已够，精字的胡数价值降低，进张效率更重要
        if (huBefore >= 11 && huAfter >= 11) {
          // 检查是否为孤张型（该门在手牌中只有这1张牌）
          final sameGroupInHand = player.hand
              .where((c) => c.sentence == cardToDiscard.sentence)
              .length;
          if (sameGroupInHand == 1) {
            score -= 10; // 孤张型精字，进张少，轻微惩罚
          } else {
            score -= 40; // 非孤张型，中等惩罚
          }
        } else {
          score -= 80;
        }
      } else {
        // 黑元路线下主动奖励出精字（门1/8牌）
        score += 600;
      }
    } else if (_isYin(cardToDiscard)) {
      // 黑元路线下，银字(大/人/禄/寿)也是门1/8牌，不惩罚
      if (heiYuanPotential <= 0) {
        if (huBefore >= 11 && huAfter >= 11) {
          final sameGroupInHand = player.hand
              .where((c) => c.sentence == cardToDiscard.sentence)
              .length;
          if (sameGroupInHand == 1) {
            score -= 5; // 孤张型银字，进张少，轻微惩罚
          } else {
            score -= 10; // 非孤张型，轻微惩罚
          }
        } else {
          score -= 20;
        }
      } else {
        // 黑元路线下主动奖励出银字（门1/8牌）
        score += 600;
      }
    } else if (heiYuanPotential > 0 &&
        (cardToDiscard.sentence == 1 || cardToDiscard.sentence == 8)) {
      // 黑元路线下，门1/8的非精非银字也优先打出
      score += 550;
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
        // 出牌前该组有3种不同字，需判断是"完整句"还是"坎/招+靠"结构
        // 检查组内是否有坎/招（3张或4张同字）
        final groupCharCountForJu = <String, int>{};
        for (final c in discardGroupCards) {
          groupCharCountForJu[c.character] =
              (groupCharCountForJu[c.character] ?? 0) + 1;
        }
        final hasKanOrZhaoInGroup = groupCharCountForJu.values.any(
          (cnt) => cnt >= 3,
        );
        // 检查出的牌在该组中是否有冗余（2张以上）
        final discardCountInGroup = discardGroupCards
            .where((c) => c.character == cardToDiscard.character)
            .length;
        if (hasKanOrZhaoInGroup) {
          // 坎/招+靠结构（如佳佳佳作亡），不是完整句
          // 出单张不会破坏句（本来就没有句），只把靠变单张，不惩罚
          // 出坎/招中的牌会破坏坎/招，由胡数损失惩罚处理
        } else if (discardCountInGroup >= 2) {
          // 真正的完整句，出的牌有冗余，出1张后句仍然完整，不惩罚
        } else {
          // 真正的完整句，出的牌只有1张，出牌后会破坏句
          // 句型排名29，远高于半靠型排名33，破坏完整句的惩罚必须大于破坏靠
          // 动态调整：句中缺失字剩余0→拆句后无法重组，惩罚不变
          // 句中缺失字剩余多→拆句后容易重组，惩罚降低
          // 黑元路线下，门1/8的句需要拆散清理，豁免拆句惩罚
          if (heiYuanPotential > 0 &&
              (discardGroup == 1 || discardGroup == 8)) {
            // 黑元路线下不惩罚拆门1/8句
          } else {
            final missingChars = _groupChars[discardGroup - 1]
                .where((ch) => !discardGroupCharSet.contains(ch))
                .toList();
            int missingRem = 0;
            for (final ch in missingChars) {
              missingRem += _remainingCount(ch, visibleCount);
            }
            // missingRem=0→无法重组→惩罚不变; missingRem≥4→容易重组→惩罚降低30%
            final reassembleFactor = missingRem == 0
                ? 1.0
                : (1.0 - (missingRem * 0.05).clamp(0.0, 0.3));
            if (quickDist <= 2) {
              score -= (400 * reassembleFactor).round();
            } else if (quickDist <= 4) {
              score -= (300 * reassembleFactor).round();
            } else {
              score -= (200 * reassembleFactor).round();
            }
          }
        }
      } else if (discardGroupCharSet.length == 2) {
        // 出牌前该组有2种不同字，可能是靠或对子+单张
        final discardCountInGroup = discardGroupCards
            .where((c) => c.character == cardToDiscard.character)
            .length;
        // 检查该组是否有对子
        final groupCharCount = <String, int>{};
        for (final c in discardGroupCards) {
          groupCharCount[c.character] = (groupCharCount[c.character] ?? 0) + 1;
        }
        final hasPairInGroup = groupCharCount.values.any((cnt) => cnt >= 2);
        // 判断是否为"对子+独立单张"结构：同门2种字，一种有2张(对子)，另一种有1张(单张)
        // 这种情况下，单张不是靠的一部分（对子已独立存在），出单张不会破坏靠
        // 真正的靠是2种字各1张（无对子），出任何一张都会破坏靠
        final isPairPlusSingle = hasPairInGroup && discardCountInGroup == 1;
        // 出靠的单张(discardCountInGroup==1)会破坏靠，但"对子+独立单张"不算靠
        final breaksKao = discardCountInGroup == 1 && !isPairPlusSingle;
        if (discardCountInGroup == 1) {
          // 出这张单张，检查缺失字的剩余张数
          final missingChars = _groupChars[discardGroup - 1]
              .where((ch) => !discardGroupCharSet.contains(ch))
              .toList();
          int missingRem = 0;
          for (final ch in missingChars) {
            missingRem += _remainingCount(ch, visibleCount);
          }
          if (isPairPlusSingle) {
            // 对子+独立单张：出单张不破坏靠，只是放弃进张方向
            // 惩罚很轻，因为对子仍然完整
            if (missingRem > 0) {
              if (quickDist <= 2) {
                score -= 10 + missingRem * 2;
              } else if (quickDist <= 4) {
                score -= 5 + missingRem;
              }
              // else: 无惩罚
            }
          } else if (missingRem > 0) {
            // 真正的靠：出单张会破坏靠
            // 判断靠的进张目标价值：
            // 1. 精句潜力靠：缺失字是精字(上/福)→进张成精句
            // 2. 精靠本身：当前靠含精字(上/福)，出精字不仅破坏靠还损失精靠4胡
            final isJingJuKao =
                (discardGroup == 1 || discardGroup == 8) &&
                missingChars.any((ch) => ch == '上' || ch == '福');
            final isJingKao =
                (discardGroup == 1 || discardGroup == 8) &&
                discardGroupCharSet.any((ch) => ch == '上' || ch == '福');
            if (isJingJuKao || isJingKao) {
              // 精句潜力靠或精靠(进张+4胡/本身4胡)，破坏代价更大
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
              // 半靠型排名33，低于句型排名29，惩罚必须小于破坏完整句
              // 动态调整：缺失字剩余0→拆靠后无法重组→惩罚降低(拆了损失小)
              // 缺失字剩余多→拆靠后容易重组→惩罚不变(但出牌后可再摸回)
              final kaoFactor = missingRem == 0
                  ? 0.3
                  : (1.0 - (4 - missingRem).clamp(0, 3) * 0.1);
              if (quickDist <= 2) {
                score -= (150 * kaoFactor).round();
              } else if (quickDist <= 4) {
                score -= (100 * kaoFactor).round();
              } else {
                score -= (50 * kaoFactor).round();
              }
            }
          }
        }
      }
    }

    score += (10 - distToTing) * 120;

    // 胡数不足时的出牌优先级规则（按胡牌类型灵活调整）
    // 默认(普通胡牌)：普单 > 对子+独立单张 > 普句多一张 > 普靠
    // 十对：保留对子，优先出孤张/普单，绝不出对子
    // 黑元：无碰无招，优先拆对子(避免对子变碰破坏黑元资格)
    // 红元：组1/组8句优先保留，优先出非组1/8的孤张
    // 枯胡：6坎+1对，优先出靠/句中的单张，保留对子和坎
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
        // 十对路线：保对子、招；拆坎(剩余0时)；孤张剩余0优先打出
        final rem = _remainingCount(cardToDiscard.character, visibleCount);
        if (discardGroupCharSet.length == 1) {
          // 同字组（孤张/对子/坎/招）
          if (discardCountInGroup >= 4) {
            // 招（2对），绝不出
            score -= 200;
          } else if (discardCountInGroup >= 3) {
            // 坎（1对+1多余张）
            if (rem <= 0) {
              // 剩余0，无法成招，拆坎变对
              score += 300;
            } else {
              // 有剩余，可成招，保留
              score -= 100;
            }
          } else if (discardCountInGroup >= 2) {
            // 对子，绝不出
            score -= 100;
          } else {
            // 孤张
            if (rem <= 0) {
              // 剩余0，死孤张，最优先打出
              score += 350;
            } else {
              // 有剩余，可成对，保留（低优先级打出）
              score += 100;
            }
          }
        } else if (discardGroupCharSet.length == 3) {
          // 句型/句孤张型
          if (discardCountInGroup >= 2) {
            // 句孤张型，出多余的对子张
            score += 100;
          } else {
            // 句中单张，十对不需要句
            if (rem <= 0) {
              score += 300; // 死单张，优先打出
            } else {
              score += 150; // 次优打出
            }
          }
        } else if (discardGroupCharSet.length == 2) {
          // 半靠/对+靠
          if (hasPairInGroup) {
            if (discardCountInGroup >= 2) {
              score -= 100; // 绝不出对子
            } else {
              // 出独立单张，保留对子
              if (rem <= 0) {
                score += 300; // 死单张
              } else {
                score += 150; // 次优
              }
            }
          } else {
            // 半靠，出一张变孤张
            if (rem <= 0) {
              score += 300; // 死单张
            } else {
              score += 150; // 次优
            }
          }
        }
      } else if (isHeiYuan) {
        // 黑元路线：组6句+1靠，看组句速度
        // 策略：
        //   1. 优先出1/8门牌（黑元不要门1/8牌）
        //   2. 调用"最难成句"算法，优先打出成句难度最高的牌
        //      （考虑吃牌因素，牌面余牌不足时也要优先打出）
        final isGroup18 = discardGroup == 1 || discardGroup == 8;

        // 维度1：门1/8牌优先清理（黑元核心需求）
        if (isGroup18) {
          score += 2000;
        }

        // 维度2：调用"最难成句"算法计算该门难度
        final groupCharsList = _groupChars[discardGroup - 1];
        final difficulty = _calcHeiYuanDifficulty(
          groupCharCount,
          groupCharsList,
          visibleCount,
          totalUnknown,
        );
        score += difficulty.round();

        // 维度3：坎（3张同字）离成句远，优先清理
        final isKanCharInGroup =
            groupCharCount[cardToDiscard.character] != null &&
            groupCharCount[cardToDiscard.character]! >= 3;
        if (isKanCharInGroup) {
          score += 1500;
        }
      } else if (isHongYuan) {
        // 红元路线：门1/8句≥3，其它门都是句子，2张半靠将牌来自门1/8
        final isGroup18 = discardGroup == 1 || discardGroup == 8;
        if (discardGroupCharSet.length == 1) {
          if (discardCountInGroup >= 3) {
            // 坎/招（红元不能有坎/碰/招），需要拆解
            score += 150;
            if (isGroup18) score += 50;
          } else if (isGroup18) {
            score += 150; // 门1/8孤张，可能组句
          } else {
            score += 300; // 门2-7孤张，无法组句则无用，优先出
          }
        } else if (discardGroupCharSet.length == 3) {
          if (discardCountInGroup >= 2) {
            // 句孤张型中出孤张，形成完整句
            if (isGroup18) {
              score += 250; // 门1/8句，红元核心需求(≥3句)
            } else {
              score += 200; // 门2-7句，也需要(其它门都是句子)
            }
          }
        } else if (discardGroupCharSet.length == 2) {
          if (hasPairInGroup) {
            if (discardCountInGroup == 1) {
              // 对子+靠中出靠单张
              if (isGroup18) {
                score += 40; // 门1/8半靠，可能是将牌，低优先级
              } else {
                score += 80; // 门2-7半靠，组句来源，低优先级
              }
            }
          } else {
            // 半靠中出1张
            if (isGroup18) {
              score += 40; // 门1/8半靠，可能是将牌，低优先级
            } else {
              score += 80; // 门2-7半靠，组句来源，低优先级
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
        // 默认普通胡牌路线：普单 > 对子+独立单张 > 普句多一张 > 普靠 > 拆句
        if (discardGroupCharSet.length == 1) {
          score += 200; // 普单(孤张)最优先
        } else if (discardGroupCharSet.length == 3) {
          // 检查组内是否有坎/招（3张或4张同字）
          final hasKanOrZhaoInGroup = groupCharCount.values.any(
            (cnt) => cnt >= 3,
          );
          if (discardCountInGroup >= 2) {
            // 检查是否所有字都有2张（如七七十十生生）
            // 这种情况出任何一张是拆对子，不是"句多一张"
            // 对子可以碰成坎获得胡数，胡数不足时应保留
            final allCharsHave2 = groupCharCount.values.every(
              (cnt) => cnt >= 2,
            );
            if (allCharsHave2) {
              // 对对型拆对子，排名30，优先于拆句(-200)但低于半靠(+80)
              // 动态调整：对子剩余0→死对子，加分高；剩余多→碰坎概率高，加分低
              final pairRem2 = _remainingCount(
                cardToDiscard.character,
                visibleCount,
              );
              if (pairRem2 == 0) {
                score += 80; // 死对子，优先拆
              } else if (pairRem2 == 1) {
                score += 40; // 碰坎概率低
              } else {
                score += 20; // 碰坎概率高，加分最低
              }
            } else {
              // 检查出的是否是金对/精对（上上/福福），金对8胡不能拆
              final isJingPair =
                  (discardGroup == 1 || discardGroup == 8) &&
                  (cardToDiscard.character == '上' ||
                      cardToDiscard.character == '福');
              if (isJingPair) {
                // 金对8胡，拆掉损失巨大，重罚
                score -= 300;
              } else {
                score += 120; // 普句多一张
              }
            }
          } else if (hasKanOrZhaoInGroup) {
            // 坎/招+靠结构（如佳佳佳作亡），出靠中的单张
            // 保留坎/招的胡数，出单张是正确策略，与出孤张同等优先
            score += 200;
          }
          // else: 真正的句，出单张会破坏句，不加分（由破坏句惩罚控制）
        } else if (discardGroupCharSet.length == 2) {
          if (!hasPairInGroup) {
            // 普靠：出半靠中一张，排名33，优先于拆句(排名29)
            // 胡数动态调整：<11胡优先拆半靠(加分高)，≥11胡保留半靠(加分低)
            final kaoBonus = huBefore < 11 ? 120.0 : 40.0;
            score += kaoBonus;
          } else {
            // 对子+单张：区分"对子+独立单张"和"对子+靠"
            // 检查对子是否为死对子（剩余0张，无法碰成坎）
            final pairChar = groupCharCount.entries
                .firstWhere((e) => e.value >= 2)
                .key;
            final pairRem = _remainingCount(pairChar, visibleCount);
            if (discardCountInGroup == 1) {
              // 对子+独立单张：单张不是靠的一部分，按"出单张"评分
              // 对子旁边的单张和孤张类似，应该优先出
              final missingChars = _groupChars[discardGroup - 1]
                  .where((ch) => !discardGroupCharSet.contains(ch))
                  .toList();
              final isJingJuKao =
                  (discardGroup == 1 || discardGroup == 8) &&
                  missingChars.any((ch) => ch == '上' || ch == '福');
              final isJingKao =
                  (discardGroup == 1 || discardGroup == 8) &&
                  discardGroupCharSet.any((ch) => ch == '上' || ch == '福');
              if (isJingJuKao || isJingKao) {
                // 精门的对子+单张：单张有精句潜力，施加惩罚保护
                score -= 150;
              } else if (pairRem > 0) {
                // 普通对子+独立单张：出单张是正确策略，与出孤张类似
                score += 180;
              } else {
                // 死对子旁边的单张，保留死对子无碰坎价值
                // 出单张保留死对子不加分，反而应该拆死对子
                score -= 30;
              }
            } else {
              // discardCountInGroup >= 2：拆对子
              // 对型排名32，介于半靠(33)和句型(29)之间
              // 拆对子优先于拆句，但次于拆半靠
              // 胡数动态调整：<11胡保留对子(加分低)，≥11胡优先拆对子(加分高)
              if (pairRem > 0) {
                // 对子可以碰成坎获得胡数，但拆对子仍优先于拆句
                // 胡数越少，对子碰坎价值越高，适当降低加分
                // 剩余张数越多，碰坎概率越高，适当降低加分
                final huBonus = huBefore < 11 ? 20.0 : 100.0;
                final remFactor = pairRem >= 2 ? 0.6 : 1.0;
                score += (huBonus * remFactor).roundToDouble();
              } else {
                // 死对子（剩余0张），无法碰成坎，优先拆
                score += 80;
              }
            }
          }
        }
      }
    }

    // 依赖胡数路线下，胡数≤8时，拆1/8门牌的惩罚动态调整
    // 基础惩罚大于拆句(-200)，但根据剩余张数动态调整：
    // - 精字(上/福)剩余多→保护力度大
    // - 精字剩余0→门1/8进张断，保护力度降低，接近拆句惩罚
    // - 银字(大/人/禄/寿)剩余多→有精句潜力，保护力度中等
    // - 银字剩余0→无进张，保护力度大幅降低
    // 黑元路线例外（不需要门1/8）
    final discardGroupForMenProtection = cardToDiscard.sentence;
    if (huBefore <= 8 &&
        shiDuiPotential <= 0 &&
        heiYuanPotential <= 0 &&
        (discardGroupForMenProtection == 1 ||
            discardGroupForMenProtection == 8)) {
      // 计算该门精字和银字的剩余张数
      final groupChars = _groupChars[discardGroupForMenProtection - 1];
      final jingChar = discardGroupForMenProtection == 1 ? '上' : '福';
      final jingRem = _remainingCount(jingChar, visibleCount);
      final yinChars = groupChars.where((ch) => ch != jingChar);
      final yinMinRem = yinChars
          .map((ch) => _remainingCount(ch, visibleCount))
          .reduce((a, b) => a < b ? a : b);

      // 基础惩罚：必须超过拆句(-200)
      double basePenalty = 210 + (8 - huBefore) * 20.0;

      // 精字剩余张数调整：精字剩余0→保护力度降低50%
      if (jingRem == 0) {
        basePenalty *= 0.5;
      } else if (jingRem == 1) {
        basePenalty *= 0.75;
      }

      // 银字剩余张数调整：所有银字剩余0→保护力度再降低30%
      if (yinMinRem == 0) {
        basePenalty *= 0.7;
      }

      score -= basePenalty;
    }

    // 胡数评估：计算胡数损失，供后续逻辑使用
    final huLoss = huBefore - huAfter;

    // 胡数足够(>=11)时的出牌优先级：优先出单张，保留对子/坎
    // 对子可通过碰成坎获得胡数，坎是已确定的胡数来源，都不应轻易拆
    if (huBefore >= 11 &&
        shiDuiPotential <= 0 &&
        heiYuanPotential <= 0 &&
        hongYuanPotential <= 0 &&
        kuHuPotential <= 0) {
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

      // 非黑元路线下，1/8门独张优先出条件：
      // 1. 出的是1/8门独张（该门只有1张牌）
      // 2. 出后胡数仍>=11（huAfter >= 11）
      // 3. 2-7门没有独张
      // 满足以上条件时，给予额外加分，覆盖精字保护和门1/8保护
      final isDiscardGroup18 = discardGroup == 1 || discardGroup == 8;
      final isGroup18Single =
          isDiscardGroup18 && _isSingleInGroup(player, discardGroup);
      final noSingleInGroup2To7 = !_hasSingleInGroup2To7(player);
      if (isGroup18Single && huAfter >= 11 && noSingleInGroup2To7) {
        // 1/8门独张优先出：2-7门无独张，出后胡数仍>=11
        // 给予额外加分覆盖精字保护(-100)和门1/8保护(-25)
        score += 200;
      }

      if (discardGroupCharSet.length == 1) {
        // 孤张/单张（同组只有1种字）：最优先出
        score += 200;
      } else if (discardGroupCharSet.length == 2) {
        if (hasPairInGroup) {
          // 检查对子是否为死对子（剩余0张，无法碰成坎）
          final pairChar = groupCharCount.entries
              .firstWhere((e) => e.value >= 2)
              .key;
          final pairRem = _remainingCount(pairChar, visibleCount);
          if (discardCountInGroup == 1) {
            // 对子+独立单张：出单张，保留对子，与出孤张类似优先
            if (pairRem > 0) {
              score += 200;
            } else {
              // 死对子，保留无碰坎价值，不加分
              score += 20;
            }
          } else {
            // 拆对子
            // 胡数动态调整：≥11胡优先拆对子(加分高)，保留半靠
            if (pairRem > 0) {
              score += 100; // 鼓励拆对子，保留半靠
            } else {
              // 死对子，拆掉不惩罚，反而加分
              score += 80;
            }
          }
        } else {
          // 普靠：出一张变孤张
          // 胡数动态调整：≥11胡保留半靠(加分低)，优先拆对子
          score += 20;
        }
      } else if (discardGroupCharSet.length == 3) {
        // 完整句或3种字都有
        final allCharsHave2 = groupCharCount.values.every((cnt) => cnt >= 2);
        if (allCharsHave2) {
          // 3种字都有2张（如七七十十生生）：拆对子，惩罚
          score -= 100;
        } else if (discardCountInGroup == 1) {
          // 句中单张：出单张会破坏句，但胡数够时句不是必须
          // 检查该组是否已有坎/招（3张或4张同字），已有坎/招时单张更应优先出
          // 因为坎/招是已确定的胡数来源，单张是多余的
          final hasKanOrZhaoInGroup = groupCharCount.values.any(
            (cnt) => cnt >= 3,
          );
          if (hasKanOrZhaoInGroup) {
            // 组内已有坎/招，单张是多余牌，最优先出
            score += 250;
          } else {
            score += 80;
          }
        } else {
          // 句多一张：出多余的对子张
          score += 100;
        }
      }
    }

    // 胡数评估：听牌胡型条件要求总胡数>=11（特殊胡牌类型除外）
    // 出牌导致胡数下降时惩罚，破坏胡数资格时重罚
    // 黑元路线下，打出门1/8牌(精字/银字)会损失胡数，但这是清理门1/8的必要代价
    // 黑元是特殊胡牌类型，不受11胡限制，所以不惩罚门1/8牌的胡数损失
    final isHeiYuanRoute = heiYuanPotential > 0;
    final isDiscardGroup18 =
        cardToDiscard.sentence == 1 || cardToDiscard.sentence == 8;
    // 黑元路线下，出坎（3张同字）也跳过胡数损失惩罚
    // 坎离成句远（需要同门其他字才能成句），是黑元路线的清理对象
    final isKanCharInHand =
        player.hand
            .where((c) => c.character == cardToDiscard.character)
            .length >=
        3;
    final skipHuLossPenalty =
        isHeiYuanRoute && (isDiscardGroup18 || isKanCharInHand);
    // 胡数损失权重：胡数越低，损失越严重（离11胡资格越远）
    if (huBefore < 11 && huLoss > 0 && !skipHuLossPenalty) {
      // 胡数不足11时，每损失1胡的代价更大
      score -= huLoss * 50;
    } else if (huLoss > 0 && !skipHuLossPenalty) {
      // 胡数够了(>=11)时，如果出牌后仍>=11，降低胡数损失惩罚
      // 特别是门1/8孤张，进张效率比保留胡数更重要
      if (huAfter >= 11) {
        if (isDiscardGroup18) {
          // 门1/8牌：胡数损失惩罚大幅降低，因为进张效率更重要
          final sameGroupInHand = player.hand
              .where((c) => c.sentence == cardToDiscard.sentence)
              .length;
          if (sameGroupInHand == 1) {
            // 孤张型：进张最少，惩罚最低
            score -= huLoss * 8;
          } else {
            // 非孤张型：中等惩罚
            score -= huLoss * 20;
          }
        } else {
          // 门2-7牌：胡数损失仍需惩罚，但比原来轻
          score -= huLoss * 25;
        }
      } else {
        // 出牌后胡数<11，保持重罚
        score -= huLoss * 40;
      }
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

    // 胡数足够(>=11)且出牌后仍>=11时，进张效率加分
    // 进张少的孤张优先出（因为保留它进张收益低，不如保留进张多的牌）
    if (huBefore >= 11 &&
        huAfter >= 11 &&
        shiDuiPotential <= 0 &&
        heiYuanPotential <= 0 &&
        hongYuanPotential <= 0 &&
        kuHuPotential <= 0) {
      final discardGroupForJinZhang = cardToDiscard.sentence;
      final sameGroupInHand = player.hand
          .where((c) => c.sentence == discardGroupForJinZhang)
          .length;
      if (sameGroupInHand == 1) {
        // 孤张型：计算进张数（该字剩余张数，只能进对）
        final rem = _remainingCount(cardToDiscard.character, visibleCount);
        // 进张越少，越应该出掉（保留收益低）
        if (rem <= 1) {
          score += 60; // 进张极少，强烈建议出
        } else if (rem <= 2) {
          score += 30; // 进张较少，建议出
        }
      }
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
        final groupCharSet = sameGroup.map((c) => c.character).toSet();
        if (groupCharSet.length >= 2) {
          // 搭子：保留
          score -= 30;
          if (groupCharSet.length >= 3) {
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
          // 孤张/普单：同组只有1种字，优先打出
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
        } else if (groupCharSet.length == 1) {
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
        if (groupCharSet.length == 1) {
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
      // expSteps仅估算下一步进张概率，未考虑完整路径，易高估（如dist=2但只有2张进张时算出38步）
      // 仅奖励快速路径（expSteps<10），不对慢速路径施加惩罚（距离已在potential中体现）
      score += math.max(0.0, (10 - expSteps) * 50);
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
    // 被招风险单独累积：确定性事件，不受进攻优先调整影响
    double zhaoDanger = 0;
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

      // 被招风险：对手已有3张同字坎，出该字100%被招成招（4张同字）
      // 全牌共4张同字，对手meld占3张+我手上1张=4张，出此牌必被招
      // 招牌收益：普坎2胡→普招6胡(+4胡)；精坎12胡→精招16胡(+4胡)
      for (final meld in other.melds) {
        if (meld.type == MeldType.kan &&
            meld.cards.length == 3 &&
            meld.cards.every(
              (c) => c.character == meld.cards.first.character,
            )) {
          if (meld.cards.first.character == cardToDiscard.character) {
            // 确定性被招，高额扣分（精字损失更大）
            // 累积到zhaoDanger，不受进攻优先调整影响
            if (cardToDiscard.isJing) {
              zhaoDanger += isLate ? 150 : 100;
            } else {
              zhaoDanger += isLate ? 80 : 50;
            }
          }
        }
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

    // 被招风险是确定性事件，不参与进攻优先缩减
    return danger + zhaoDanger;
  }

  // ==================== 防守策略与流局策略（规则21、34） ====================

  /// 防守阈值（规则21.2）
  double _defenseThreshold(Player player, GameState state) {
    final phase = _getGamePhase(state);
    final huScore = _evaluateHuScore(player);

    if (phase == _GamePhase.flow) {
      return 30; // 流局期：出牌风险 > 30 → 选安全牌
    }
    if (player.isTing && huScore >= 15) {
      return 50; // 已听+胡数高：出牌风险 > 50 → 选安全牌
    }
    if (player.isTing) {
      return 100; // 听牌后：出牌风险 > 100 → 选安全牌
    }
    return 200; // 未听牌：出牌风险 > 200 → 选安全牌
  }

  /// 流局期防守权重（规则34.3）
  double _flowDefenseMultiplier(GameState state) {
    final deck = state.deck.length;
    if (deck < 3) return 2.0; // 接近流局，全力防守
    if (deck < 5) return 2.0;
    if (deck < 10) return 1.5; // 流局期，防守权重提升
    return 1.0;
  }

  /// 判断是否为安全牌（规则21.1）
  bool _isSafeCard(
    Card card,
    Player player,
    GameState state,
    Map<String, int> visibleCount,
  ) {
    // 绝对安全牌：所有4张已可见
    if (_remainingCount(card.character, visibleCount) == 0) {
      return true;
    }
    // 对手已弃出的字 → 风险低
    for (int i = 0; i < state.players.length; i++) {
      if (i == player.id) continue;
      final other = state.players[i];
      if (other.discards.any((c) => c.character == card.character)) {
        return true;
      }
    }
    return false;
  }

  /// 流局策略（规则34.2）
  /// 返回是否应放弃进攻转为防守
  bool _shouldDefendInFlowPeriod(Player player, GameState state) {
    if (!_isFlowPeriod(state)) return false;

    // 未听牌→放弃进攻，全力防守
    if (!player.isTing) return true;

    // 已听牌但死听→拆听换安全牌
    final deadTingLevel = _detectDeadTing(player, _cachedVisibleCount ?? {});
    if (deadTingLevel == 2) return true; // 死听

    // 胡数不足→接受流局，减少损失
    final huScore = _evaluateHuScore(player);
    if (huScore < 11) {
      final shiDuiPotential = _evaluateShiDuiPotential(player, state);
      final heiYuanPotential = _evaluateHeiYuanPotential(player);
      final hongYuanPotential = _evaluateHongYuanPotential(player);
      final kuHuPotential = _evaluateKuHuPotential(player);
      if (shiDuiPotential <= 0 &&
          heiYuanPotential <= 0 &&
          hongYuanPotential <= 0 &&
          kuHuPotential <= 0) {
        return true; // 胡数不足且无特殊路线
      }
    }

    return false;
  }

  /// 路线出牌优先级加分（规则二十）
  double _routeDiscardPriorityBonus(
    Card card,
    Player player,
    int huBefore,
    int huAfter,
    Map<String, int> visibleCount,
    int totalUnknown,
  ) {
    final route = _currentRoute ?? _RouteType.normal;
    final ch = card.character;
    final sentence = card.sentence;
    final isJingMen = sentence == 1 || sentence == 8;
    final isJingChar = ch == '上' || ch == '福';
    final isYinChar = ch == '大' || ch == '人' || ch == '禄' || ch == '寿';

    // 统计同门各字张数
    final byChar = <String, int>{};
    for (final c in player.hand) {
      if (c.sentence == sentence) {
        byChar[c.character] = (byChar[c.character] ?? 0) + 1;
      }
    }
    final chCnt = byChar[ch] ?? 0;
    final groupChars = _groupChars[sentence - 1];
    final presentChars = groupChars
        .where((c) => (byChar[c] ?? 0) >= 1)
        .toList();
    final hasAllThree = presentChars.length == 3;

    double bonus = 0;

    switch (route) {
      case _RouteType.shiDui:
        // 十对路线出牌优先级
        // 保对子、招；拆坎(剩余0时)；孤张剩余0优先打出
        if (chCnt >= 4) {
          // 招（2对），绝不出
          bonus -= 200;
        } else if (chCnt == 3) {
          // 坎（1对+1多余张）
          final rem = _remainingCount(ch, visibleCount);
          if (rem <= 0) {
            // 剩余0，无法成招，拆坎变对
            bonus += 300;
          } else {
            // 有剩余，可成招，保留
            bonus -= 100;
          }
        } else if (chCnt == 2) {
          // 对子，绝不出
          bonus -= 100;
        } else if (chCnt == 1) {
          // 单张
          final rem = _remainingCount(ch, visibleCount);
          if (presentChars.length == 1) {
            // 孤张
            if (rem <= 0) {
              // 剩余0，死孤张，最优先打出
              bonus += 350;
            } else {
              // 有剩余，可成对，保留（低优先级打出）
              bonus += 100;
            }
          } else {
            // 半靠/句中单张（十对不需要句，出单张不影响对子）
            if (rem <= 0) {
              // 剩余0，死单张，优先打出
              bonus += 300;
            } else {
              // 有剩余，次优打出
              bonus += 150;
            }
          }
        }
        break;

      case _RouteType.heiYuan:
        // 黑元路线出牌优先级（规则20.2）
        // 黑元核心：组6句+1靠，看组句速度
        // 策略：
        //   1. 优先出1/8门牌（黑元不要门1/8牌）
        //   2. 调用"最难成句"算法，优先打出成句难度最高的牌
        //      （考虑吃牌因素，牌面余牌不足时也要优先打出）
        {
          // 维度1：门1/8牌优先清理（黑元核心需求）
          if (isJingMen) {
            bonus += 2000;
          }

          // 维度2：调用"最难成句"算法计算该门难度
          final difficulty = _calcHeiYuanDifficulty(
            byChar,
            groupChars,
            visibleCount,
            totalUnknown,
          );
          bonus += difficulty;

          // 维度3：坎（3张同字）离成句远，优先清理
          if (chCnt == 3) bonus += 1500;
        }
        break;

      case _RouteType.hongYuan:
        // 红元路线出牌优先级
        // 目标：门1/8句≥3，其它门都是句子，2张半靠将牌来自门1/8
        if (hasAllThree && chCnt == 2) {
          // 句孤张型中出孤张，形成完整句
          if (isJingMen) {
            bonus += 250; // 门1/8句，红元核心需求(≥3句)
          } else {
            bonus += 200; // 门2-7句，也需要(其它门都是句子)
          }
        } else if (chCnt >= 4) {
          // 招（红元不能有招），需要拆解
          bonus += 200;
        } else if (chCnt == 3) {
          // 坎（红元不能有坎/碰），需要拆解
          bonus += 150;
          if (isJingMen) bonus += 50;
        } else if (presentChars.length == 2 && chCnt == 1) {
          // 半靠中出1张（保留半靠用于组句或作将牌）
          if (isJingMen) {
            bonus += 40; // 门1/8半靠，可能是将牌，低优先级出
          } else {
            bonus += 80; // 门2-7半靠，组句来源，低优先级出
          }
        } else if (chCnt == 1 && presentChars.length == 1) {
          // 孤张
          if (isJingMen) {
            bonus += 150; // 门1/8孤张，可能组句
          } else {
            bonus += 300; // 门2-7孤张，无法组句则无用，优先出
          }
        } else if (chCnt == 2 && presentChars.length == 1) {
          // 纯对子（红元将牌是半靠不是对子，对子价值低）
          bonus += 50;
        } else if (chCnt == 2 && presentChars.length >= 2) {
          // 对子+靠中出对子（避免破坏对子）
          bonus -= 100;
        }
        break;

      case _RouteType.kuHu:
        // 枯胡路线出牌优先级（规则20.4）
        if (chCnt == 1) {
          // 单张
          bonus += 200;
        } else if (presentChars.length == 2 && chCnt == 1) {
          // 普靠（出一张）
          bonus += 80;
        } else if (hasAllThree && chCnt == 2) {
          // 句中单张
          bonus += 120;
        } else if (presentChars.length == 2 && chCnt == 1) {
          // 对子+靠（出靠单张）
          bonus += 100;
        } else if (chCnt == 2 &&
            presentChars.any((c) => (byChar[c] ?? 0) == 1)) {
          // 对子（出对子）- 绝不出对子
          bonus -= 150;
        }
        break;

      case _RouteType.normal:
        // 普通胡路线出牌优先级
        if (chCnt >= 4) {
          // 招，绝不出
          bonus -= 200;
        } else if (chCnt == 3) {
          if (presentChars.length >= 2) {
            // 坎+靠/坎+句（出坎中一张，清理结构）
            bonus += 200;
          }
          // 纯坎: bonus = 0 (保留3胡)
        } else if (hasAllThree && chCnt == 2) {
          // 句孤张型(2,1,1)或句半靠型(2,2,1)中出有2张的字
          final total = byChar.values.fold(0, (a, b) => a + b);
          final countOfPairs = byChar.values.where((v) => v == 2).length;
          if (total == 4 && countOfPairs == 1) {
            // 句孤张型中出孤张：形成完整句，损失0
            bonus += 200;
          } else {
            // 句半靠型中出对中1张
            bonus += 120;
          }
        } else if (presentChars.length == 2 && chCnt == 2) {
          // 对+靠/坎+对中出对子
          if (huBefore >= 11) {
            // ≥11胡：检查成句难度
            final missingChars = groupChars
                .where((c) => (byChar[c] ?? 0) == 0)
                .toList();
            final otherPresentChars = presentChars
                .where((c) => c != ch)
                .toList();
            // 检查在场的另一个字是否被坎锁定（≥3张）
            final otherLockedInKan = otherPresentChars.any(
              (c) => (byChar[c] ?? 0) >= 3,
            );
            if (missingChars.isNotEmpty) {
              final missingRem = _remainingCount(
                missingChars.first,
                visibleCount,
              );
              if (missingRem == 0 || otherLockedInKan) {
                // 缺字0剩余或另一字被坎锁定，对子无法成句，优先拆
                bonus += 120;
              } else if (missingRem == 1) {
                // 缺字仅剩1张，成句概率低
                bonus += 60;
              } else {
                // 缺字剩余多，保留对子
                bonus -= 50;
              }
            } else {
              bonus -= 50;
            }
          } else {
            bonus -= 50;
          }
        } else if (presentChars.length == 2 && chCnt == 1) {
          // 半靠或对孤张型中出单张
          final otherChars = presentChars.where((c) => c != ch).toList();
          final isDuiGuzhang = otherChars.any((c) => (byChar[c] ?? 0) >= 2);
          if (isDuiGuzhang && huBefore >= 11) {
            // 对孤张型 + ≥11胡：检查快进张潜力
            // 缺字 = 门中3字中不在场的字
            final missingChars = groupChars
                .where((c) => (byChar[c] ?? 0) == 0)
                .toList();
            int missingRem = 0;
            for (final mc in missingChars) {
              missingRem += _remainingCount(mc, visibleCount);
            }
            if (missingRem >= 2) {
              // 缺字剩余多，1张成句，保留孤张（快进张路径）
              bonus += 80;
            } else {
              // 缺字剩余少，孤张进张慢，优先出
              bonus += 200;
            }
          } else if (isDuiGuzhang) {
            // 对孤张型 + <11胡，优先出孤张
            bonus += 200;
          } else {
            // 半靠型
            if (huBefore < 11) {
              bonus += 120; // 胡数不足优先拆
            } else {
              bonus += 40; // 胡数足够保留
            }
          }
        } else if (chCnt == 2 && presentChars.length == 1) {
          // 纯对子
          if (huBefore >= 11) {
            // ≥11胡：检查成句难度（需要另外2字）
            final otherChars = groupChars.where((c) => c != ch).toList();
            int minRem = 999;
            for (final oc in otherChars) {
              final rem = _remainingCount(oc, visibleCount);
              if (rem < minRem) minRem = rem;
            }
            if (minRem == 0) {
              // 缺字有0剩余，对子无法成句，优先拆
              bonus += 120;
            } else if (minRem == 1) {
              // 缺字仅剩1张，成句概率低
              bonus += 60;
            } else {
              // 缺字剩余多，保留对子
              bonus += 20;
            }
          } else {
            final rem = _remainingCount(ch, visibleCount);
            if (rem == 0) {
              bonus += 80; // 死对子
            } else if (rem == 1) {
              bonus += 40; // 对子（剩余1张）
            } else {
              bonus += 20; // 对子（剩余≥2张）
            }
          }
        } else if (chCnt == 1 && presentChars.length == 1) {
          // 纯孤张
          bonus += 200;
        }
        // 金对惩罚
        if (isJingMen && isJingChar && chCnt == 2) {
          bonus -= 300; // 金对8胡，拆掉损失巨大
        }
        break;
    }

    return bonus;
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
    // 句是确定的面子，不需要进张，价值应接近1对(78)+1靠(130)=208
    // 句权重200，略低于对+靠，但句不需要进张，实际价值更高
    score += aSet.length * 200.0;
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
            // 对→坎增加3胡(普坎)/12胡(精坎)，进张价值高于靠(靠→句增加0胡/4胡)
            // 评分应高于靠(50+rem*20)，符合card-group-type.md对型(排名32)>半靠型(排名33)
            score += 55 + rem * 22;
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
    int totalUnknown, {
    _RouteType? route,
  }) {
    final rt = route ?? _currentRoute ?? _RouteType.normal;
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

    // 1. 组合牌分（已完成的句/坎/招）- 路线相关
    for (final meld in menMelds) {
      switch (meld.type) {
        case MeldType.zhao:
          score += meld.isJing
              ? _getMen18JingScore(rt, _idxJingZhao)
              : _getMen27Score(rt, _idxZhao);
          break;
        case MeldType.kan:
          score += meld.isJing
              ? _getMen18JingScore(rt, _idxJingKan)
              : _getMen27Score(rt, _idxKan);
          break;
        case MeldType.ju:
          score += meld.isJing
              ? _getMen18JingScore(rt, _idxJingJu)
              : _getMen27Score(rt, _idxJu);
          break;
        default:
          break;
      }
    }

    // 2. 手牌结构分（最优拆解）- 路线相关
    // 2.1 招（4张同字）
    for (final ch in groupChars) {
      if ((byChar[ch] ?? 0) >= 4) {
        score += isJingMen && (ch == '上' || ch == '福')
            ? _getMen18JingScore(rt, _idxJingZhao)
            : _getMen27Score(rt, _idxZhao);
      }
    }

    // 2.2 坎（3张同字，手牌）
    for (final ch in groupChars) {
      final cnt = byChar[ch] ?? 0;
      if (cnt >= 3 && cnt < 4) {
        score += isJingMen && (ch == '上' || ch == '福')
            ? _getMen18JingScore(rt, _idxJingKan)
            : _getMen27Score(rt, _idxKan);
      }
    }

    // 2.3 句（3字各1张）
    final hasAllThree = groupChars.every((ch) => (byChar[ch] ?? 0) >= 1);
    if (hasAllThree) {
      score += isJingMen
          ? _getMen18JingScore(rt, _idxJingJu)
          : _getMen27Score(rt, _idxJu);
    }

    // 2.4 对（2张同字）
    for (final ch in groupChars) {
      final cnt = byChar[ch] ?? 0;
      if (cnt == 2) {
        if (isJingMen && (ch == '上' || ch == '福')) {
          score += _getMen18JingScore(rt, _idxJinDui); // 金对
        } else if (isJingMen &&
            (ch == '大' || ch == '人' || ch == '禄' || ch == '寿')) {
          score += _getMen18YinScore(rt, _idxYinDui); // 银对
        } else {
          score += _getMen27Score(rt, _idxDui); // 普对
        }
      }
    }

    // 2.5 靠（2字各1张，非完整句）
    if (!hasAllThree) {
      final presentChars = groupChars
          .where((ch) => (byChar[ch] ?? 0) >= 1)
          .toList();
      final hasPair = presentChars.any((ch) => (byChar[ch] ?? 0) >= 2);
      if (presentChars.length == 2 && !hasPair) {
        final missingChar = _findMissingCharForSentence(presentChars);
        if (missingChar != null) {
          final rem = _remainingCount(missingChar, visibleCount);
          final isJingKao =
              isJingMen &&
              (presentChars.contains('上') || presentChars.contains('福'));
          if (isJingKao) {
            score += _getMen18JingScore(rt, _idxJingKao); // 精靠
          } else if (isJingMen &&
              (presentChars.contains('大') ||
                  presentChars.contains('人') ||
                  presentChars.contains('禄') ||
                  presentChars.contains('寿'))) {
            score += _getMen18YinScore(rt, _idxYinKao); // 银靠
          } else {
            score += _getMen27Score(rt, _idxKao); // 普靠
          }
          // 进张期望分（剩余张数附加分）
          if (rem > 0 && totalUnknown > 0) {
            final afterScore = isJingMen
                ? _getMen18JingScore(rt, _idxJingJu)
                : _getMen27Score(rt, _idxJu);
            final beforeScore = isJingKao
                ? _getMen18JingScore(rt, _idxJingKao)
                : (isJingMen
                      ? _getMen18YinScore(rt, _idxYinKao)
                      : _getMen27Score(rt, _idxKao));
            score += (rem / totalUnknown) * (afterScore - beforeScore);
          }
        }
      }
    }

    // 2.6 单张
    for (final ch in groupChars) {
      final cnt = byChar[ch] ?? 0;
      if (cnt == 1) {
        final presentChars = groupChars
            .where((c) => (byChar[c] ?? 0) >= 1)
            .toList();
        final hasPairInPresent = presentChars.any((c) => (byChar[c] ?? 0) >= 2);
        final isInKao = presentChars.length == 2 && !hasPairInPresent;
        final isInJu = presentChars.length >= 3;
        if (isInKao || isInJu) continue;

        if (isJingMen && (ch == '上' || ch == '福')) {
          score += _getMen18JingScore(rt, _idxJingDan); // 精单
        } else if (isJingMen &&
            (ch == '大' || ch == '人' || ch == '禄' || ch == '寿')) {
          score += _getMen18YinScore(rt, _idxYinDan); // 银单
        } else {
          score += _getMen27Score(rt, _idxGu); // 普单
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

    // 3. 进张期望分（剩余张数附加分）- 路线相关
    for (final ch in groupChars) {
      final rem = _remainingCount(ch, visibleCount);
      if (rem <= 0 || totalUnknown <= 0) continue;

      final prob = rem / totalUnknown;
      if (prob < 0.01) continue;

      double improvement = 0;
      final curCnt = byChar[ch] ?? 0;

      // 摸到后成对（1->2）
      if (curCnt == 1) {
        improvement += isJingMen && (ch == '上' || ch == '福')
            ? _getMen18JingScore(rt, _idxJinDui)
            : (isJingMen
                  ? _getMen18YinScore(rt, _idxYinDui)
                  : _getMen27Score(rt, _idxDui));
      }
      // 摸到后成坎（2->3）
      else if (curCnt == 2) {
        final beforeScore = isJingMen && (ch == '上' || ch == '福')
            ? _getMen18JingScore(rt, _idxJinDui)
            : (isJingMen
                  ? _getMen18YinScore(rt, _idxYinDui)
                  : _getMen27Score(rt, _idxDui));
        final afterScore = isJingMen && (ch == '上' || ch == '福')
            ? _getMen18JingScore(rt, _idxJingKan)
            : _getMen27Score(rt, _idxKan);
        improvement += afterScore - beforeScore;
      }
      // 摸到后成招（3->4）
      else if (curCnt == 3) {
        final beforeScore = isJingMen && (ch == '上' || ch == '福')
            ? _getMen18JingScore(rt, _idxJingKan)
            : _getMen27Score(rt, _idxKan);
        final afterScore = isJingMen && (ch == '上' || ch == '福')
            ? _getMen18JingScore(rt, _idxJingZhao)
            : _getMen27Score(rt, _idxZhao);
        improvement += afterScore - beforeScore;
      }
      // 摸到后成句/靠（0->1，且其他字有牌）
      else if (curCnt == 0) {
        final presentChars = groupChars
            .where((c) => (byChar[c] ?? 0) >= 1)
            .toList();
        if (presentChars.length == 2) {
          // 成句
          improvement += isJingMen
              ? _getMen18JingScore(rt, _idxJingJu)
              : _getMen27Score(rt, _idxJu);
        } else if (presentChars.length == 1) {
          // 成靠
          improvement +=
              isJingMen &&
                  (presentChars.contains('上') || presentChars.contains('福'))
              ? _getMen18JingScore(rt, _idxJingKao)
              : (isJingMen
                    ? _getMen18YinScore(rt, _idxYinKao)
                    : _getMen27Score(rt, _idxKao));
        }
      }

      score += prob * improvement;
    }

    return score;
  }

  /// 计算所有门的结构总分（应用路线权重）
  double _evaluateAllMenStructure(
    List<Card> hand,
    List<Meld> melds,
    Map<String, int> visibleCount,
    int totalUnknown, {
    _RouteType? route,
  }) {
    final rt = route ?? _currentRoute ?? _RouteType.normal;
    double total = 0;
    for (int s = 1; s <= 8; s++) {
      total += _evaluateMenStructure(
        s,
        hand,
        melds,
        visibleCount,
        totalUnknown,
        route: rt,
      );
    }
    // 应用路线权重
    return total * _getRouteWeight(rt);
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

  // ==================== card-group-type.md 规则实现 ====================

  /// 牌型名称枚举（对应 card-group-type.md 的34种牌型）
  static const Map<String, int> _cardGroupTypeRank = {
    '招招招型': 1,
    '招招坎型': 2,
    '招招对型': 3,
    '招坎坎型': 4,
    '招招孤张型': 5,
    '招招型': 6,
    '招坎对型': 7,
    '坎坎坎型': 8,
    '招坎孤张型': 9,
    '招坎型': 10,
    '坎坎对型': 11,
    '招对对型': 12,
    '招对孤张型': 13,
    '招对型': 14,
    '坎坎孤张型': 15,
    '坎坎型': 16,
    '招半靠型': 17,
    '招孤张型': 18,
    '招型': 19,
    '坎对对型': 20,
    '句句型': 21,
    '坎对孤张型': 22,
    '坎对型': 23,
    '坎半靠型': 24,
    '坎孤张型': 25,
    '坎型': 26,
    '句半靠型': 27,
    '句孤张型': 28,
    '句型': 29,
    '对对型': 30,
    '对孤张型': 31,
    '对型': 32,
    '半靠型': 33,
    '孤张型': 34,
  };

  /// 牌型结构分（门2-7普字基准）
  static const Map<String, int> _cardGroupTypeScore = {
    '招招招型': 300,
    '招招坎型': 260,
    '招招对型': 220,
    '招坎坎型': 220,
    '招招孤张型': 200,
    '招招型': 200,
    '招坎对型': 180,
    '坎坎坎型': 180,
    '招坎孤张型': 160,
    '招坎型': 160,
    '坎坎对型': 140,
    '招对对型': 140,
    '招对孤张型': 120,
    '招对型': 120,
    '坎坎孤张型': 120,
    '坎坎型': 120,
    '招半靠型': 110,
    '招孤张型': 100,
    '招型': 100,
    '坎对对型': 100,
    '句句型': 100,
    '坎对孤张型': 80,
    '坎对型': 80,
    '坎半靠型': 70,
    '坎孤张型': 60,
    '坎型': 60,
    '句半靠型': 60,
    '句孤张型': 50,
    '句型': 50,
    '对对型': 40,
    '对孤张型': 20,
    '对型': 20,
    '半靠型': 10,
    '孤张型': 0,
  };

  /// 对一手牌中指定门的牌型进行分类
  /// 返回牌型名称，如"句型"、"坎对型"等
  String _classifyCardGroupType(
    int sentence,
    List<Card> hand,
    Map<String, int> visibleCount,
    bool isShiDuiRoute,
  ) {
    final groupChars = _groupChars[sentence - 1];
    final byChar = <String, int>{};
    for (final ch in groupChars) {
      byChar[ch] = 0;
    }
    for (final c in hand) {
      if (c.sentence == sentence) {
        byChar[c.character] = (byChar[c.character] ?? 0) + 1;
      }
    }

    // 排序张数 (a >= b >= c)
    final counts = byChar.values.toList()..sort((a, b) => b.compareTo(a));
    final a = counts[0], b = counts[1], c = counts[2];
    final total = a + b + c;

    // 基础分类（不考虑剩余张数降级）
    String baseType = _classifyByDistribution(a, b, c, total);

    // 应用剩余张数动态调整（组件降级）
    return _applyDegradation(
      baseType,
      byChar,
      groupChars,
      visibleCount,
      isShiDuiRoute,
    );
  }

  /// 按张数分布分类（静态基准）
  String _classifyByDistribution(int a, int b, int c, int total) {
    switch (total) {
      case 0:
        return '空';
      case 1:
        return '孤张型';
      case 2:
        if (b == 0) return '对型'; // (2,0,0)
        return '半靠型'; // (1,1,0)
      case 3:
        if (c == 1) return '句型'; // (1,1,1)
        if (b == 0) return '坎型'; // (3,0,0)
        return '对孤张型'; // (2,1,0)
      case 4:
        if (a == 4) return '招型'; // (4,0,0)
        if (a == 3) return '坎孤张型'; // (3,1,0)
        if (b == 2) return '对对型'; // (2,2,0)
        return '句孤张型'; // (2,1,1)
      case 5:
        if (a == 4) return '招孤张型'; // (4,1,0)
        if (a == 3 && b == 2) return '坎对型'; // (3,2,0)
        if (a == 3) return '坎半靠型'; // (3,1,1)
        return '句半靠型'; // (2,2,1)
      case 6:
        if (a == 4 && b == 2) return '招对型'; // (4,2,0)
        if (a == 4) return '招半靠型'; // (4,1,1)
        if (a == 3 && b == 3) return '坎坎型'; // (3,3,0)
        if (a == 3) return '坎对孤张型'; // (3,2,1)
        return '句句型'; // (2,2,2)
      case 7:
        if (a == 4 && b == 3) return '招坎型'; // (4,3,0)
        if (a == 4) return '招对孤张型'; // (4,2,1)
        if (a == 3 && b == 3) return '坎坎孤张型'; // (3,3,1)
        return '坎对对型'; // (3,2,2)
      case 8:
        if (a == 4 && b == 4) return '招招型'; // (4,4,0)
        if (a == 4 && b == 3) return '招坎孤张型'; // (4,3,1)
        if (a == 4) return '招对对型'; // (4,2,2)
        return '坎坎对型'; // (3,3,2)
      case 9:
        if (a == 4 && b == 4) return '招招孤张型'; // (4,4,1)
        if (a == 4 && b == 3) return '招坎对型'; // (4,3,2)
        return '坎坎坎型'; // (3,3,3)
      case 10:
        if (a == 4 && b == 4) return '招招对型'; // (4,4,2)
        return '招坎坎型'; // (4,3,3)
      case 11:
        return '招招坎型'; // (4,4,3)
      case 12:
        return '招招招型'; // (4,4,4)
      default:
        return '空';
    }
  }

  /// 应用剩余张数动态调整（组件降级）
  String _applyDegradation(
    String baseType,
    Map<String, int> byChar,
    List<String> groupChars,
    Map<String, int> visibleCount,
    bool isShiDuiRoute,
  ) {
    // 检查每个字的剩余张数
    final remByChar = <String, int>{};
    for (final ch in groupChars) {
      remByChar[ch] = _remainingCount(ch, visibleCount);
    }

    // 十对路线下对子不降级
    if (isShiDuiRoute) {
      return baseType;
    }

    // 非十对路线：对子剩余0张降级，半靠中任一字剩余0张降级
    switch (baseType) {
      case '半靠型':
        {
          final presentChars = groupChars
              .where((ch) => byChar[ch]! >= 1)
              .toList();
          if (presentChars.any((ch) => remByChar[ch] == 0)) {
            return '孤张型';
          }
          break;
        }
      case '对孤张型':
        {
          final pairChar = groupChars.firstWhere(
            (ch) => byChar[ch]! >= 2,
            orElse: () => '',
          );
          if (pairChar.isNotEmpty && remByChar[pairChar] == 0) {
            return '孤张型';
          }
          break;
        }
      case '坎对型':
        {
          final pairChar = groupChars.firstWhere(
            (ch) => byChar[ch]! == 2,
            orElse: () => '',
          );
          if (pairChar.isNotEmpty && remByChar[pairChar] == 0) {
            return '坎孤张型';
          }
          break;
        }
      case '坎对孤张型':
        {
          final pairChar = groupChars.firstWhere(
            (ch) => byChar[ch]! == 2,
            orElse: () => '',
          );
          if (pairChar.isNotEmpty && remByChar[pairChar] == 0) {
            return '坎孤张型';
          }
          break;
        }
      case '招对型':
        {
          final pairChar = groupChars.firstWhere(
            (ch) => byChar[ch]! == 2,
            orElse: () => '',
          );
          if (pairChar.isNotEmpty && remByChar[pairChar] == 0) {
            return '招孤张型';
          }
          break;
        }
      case '招对孤张型':
        {
          final pairChar = groupChars.firstWhere(
            (ch) => byChar[ch]! == 2,
            orElse: () => '',
          );
          if (pairChar.isNotEmpty && remByChar[pairChar] == 0) {
            return '招孤张型';
          }
          break;
        }
      case '招对对型':
        {
          final pairs = groupChars.where((ch) => byChar[ch]! == 2).toList();
          if (pairs.any((ch) => remByChar[ch] == 0)) {
            return '招对孤张型';
          }
          break;
        }
      case '坎对对型':
        {
          final pairs = groupChars.where((ch) => byChar[ch]! == 2).toList();
          if (pairs.any((ch) => remByChar[ch] == 0)) {
            return '坎对孤张型';
          }
          break;
        }
      case '坎坎对型':
        {
          final pairChar = groupChars.firstWhere(
            (ch) => byChar[ch]! == 2,
            orElse: () => '',
          );
          if (pairChar.isNotEmpty && remByChar[pairChar] == 0) {
            return '坎坎孤张型';
          }
          break;
        }
      case '招坎对型':
        {
          final pairChar = groupChars.firstWhere(
            (ch) => byChar[ch]! == 2,
            orElse: () => '',
          );
          if (pairChar.isNotEmpty && remByChar[pairChar] == 0) {
            return '招坎孤张型';
          }
          break;
        }
      case '招招对型':
        {
          final pairChar = groupChars.firstWhere(
            (ch) => byChar[ch]! == 2,
            orElse: () => '',
          );
          if (pairChar.isNotEmpty && remByChar[pairChar] == 0) {
            return '招招孤张型';
          }
          break;
        }
      case '对对型':
        {
          final pairs = groupChars.where((ch) => byChar[ch]! == 2).toList();
          if (pairs.any((ch) => remByChar[ch] == 0)) {
            return '对孤张型';
          }
          break;
        }
      case '句半靠型':
        {
          final extraChar = groupChars.firstWhere(
            (ch) => byChar[ch]! == 2,
            orElse: () => '',
          );
          if (extraChar.isNotEmpty && remByChar[extraChar] == 0) {
            return '句孤张型';
          }
          break;
        }
      case '坎半靠型':
        {
          final singles = groupChars.where((ch) => byChar[ch]! == 1).toList();
          if (singles.any((ch) => remByChar[ch] == 0)) {
            return '坎孤张型';
          }
          break;
        }
      case '招半靠型':
        {
          final singles = groupChars.where((ch) => byChar[ch]! == 1).toList();
          if (singles.any((ch) => remByChar[ch] == 0)) {
            return '招孤张型';
          }
          break;
        }
    }
    return baseType;
  }

  /// 获取牌型的保留价值排名（1=最应保留，34=最应牺牲）
  int _getRetentionRank(String type) {
    return _cardGroupTypeRank[type] ?? 34;
  }

  /// 获取牌型的结构分
  int _getCardGroupTypeScore(String type) {
    return _cardGroupTypeScore[type] ?? 0;
  }

  /// 获取牌型的结构分（区分门1/8和门2-7）
  /// 门1/8含精字，组件分值不同
  int _getCardGroupTypeScoreForMen(String type, int sentence) {
    if (sentence != 1 && sentence != 8) {
      return _cardGroupTypeScore[type] ?? 0;
    }
    // 门1/8精字分值映射
    switch (type) {
      case '孤张型':
        return 40; // 精单
      case '半靠型':
        return 50; // 精靠
      case '对型':
        return 20; // 银对(大/人/禄/寿的对)
      case '对孤张型':
        return 60; // 银对+精单/银靠+精单，取最优拆解
      case '句型':
        return 90; // 精句
      case '坎型':
        return 150; // 精坎(上上上/福福福) 或 银坎
      case '招型':
        return 200; // 精招
      case '句孤张型':
        return 130; // 精句(90)+精单(40)，取最优拆解（孤张为精字时）
      case '对对型':
        return 40; // 银对+银对
      case '坎孤张型':
        return 150; // 精坎+精单 或 银坎+银单
      case '句半靠型':
        return 140; // 精句+精靠
      case '坎半靠型':
        return 200; // 精坎+精靠 或 银坎+银靠
      case '坎对型':
        return 170; // 精坎+银对 或 银坎+银对
      case '招孤张型':
        return 200; // 精招+精单
      case '招半靠型':
        return 250; // 精招+精靠
      case '招对型':
        return 220; // 精招+银对
      case '坎对孤张型':
        return 210; // 精坎/银坎+银对+精单/银单（对子比半靠更有价值）
      case '坎对对型':
        return 190; // 精坎/银坎+银对+银对
      case '招对孤张型':
        return 260; // 精招+银对+精单/银单
      default:
        return _cardGroupTypeScore[type] ?? 0;
    }
  }

  /// 根据胡牌类型路线获取门间优先级权重
  /// 返回该门的优先拆解权重（越高越优先拆）
  double _getMenPriorityByRoute(
    int sentence,
    double shiDuiPotential,
    double heiYuanPotential,
    double hongYuanPotential,
    double kuHuPotential,
    Map<String, int> visibleCount,
  ) {
    final isJingMen = sentence == 1 || sentence == 8;

    // 十对路线：门1/8和门2-7同等对待
    if (shiDuiPotential > 0) {
      return 1.0;
    }

    // 黑元路线：优先拆门1/8（精字阻碍路线）
    if (heiYuanPotential > 0) {
      if (isJingMen) return 2.0; // 优先拆
      return 0.5; // 保留门2-7
    }

    // 依赖胡数的路线（普通胡、枯胡、清枯胡、清枯重台、红元）：优先拆门2-7，保留门1/8
    // 红元路线：门1/8句优先保留
    if (hongYuanPotential > 0 || kuHuPotential > 0) {
      if (isJingMen) return 0.5; // 保留门1/8
      return 2.0; // 优先拆门2-7
    }

    // 默认普通胡牌路线：优先拆门2-7
    // 但门1/8中精字剩余0张时，保留价值降低
    if (isJingMen) {
      final jingChar = sentence == 1 ? '上' : '福';
      final jingRem = _remainingCount(jingChar, visibleCount);
      if (jingRem == 0) {
        return 1.5; // 精字无进张，门1/8保留价值降低
      }
      return 0.5; // 保留门1/8
    }
    return 2.0; // 优先拆门2-7
  }

  /// 基于card-group-type.md规则评估出牌
  /// 返回评分调整值（正值=鼓励出这张牌，负值=惩罚出这张牌）
  double _evaluateDiscardByCardGroupType(
    Player player,
    Card cardToDiscard,
    Map<String, int> visibleCount,
    double shiDuiPotential,
    double heiYuanPotential,
    double hongYuanPotential,
    double kuHuPotential,
    int huBefore,
    int huAfter,
  ) {
    final sentence = cardToDiscard.sentence;
    final hand = player.hand;
    final isShiDuiRoute = shiDuiPotential > 0;

    // 1. 分类当前牌型
    final currentType = _classifyCardGroupType(
      sentence,
      hand,
      visibleCount,
      isShiDuiRoute,
    );
    final currentRank = _getRetentionRank(currentType);
    final currentScore = _getCardGroupTypeScoreForMen(currentType, sentence);

    // 2. 分类出牌后的牌型（只移除1张匹配的牌，而非全部）
    final handAfterDiscard = List<Card>.from(hand);
    for (var i = 0; i < handAfterDiscard.length; i++) {
      if (handAfterDiscard[i].character == cardToDiscard.character &&
          handAfterDiscard[i].sentence == cardToDiscard.sentence) {
        handAfterDiscard.removeAt(i);
        break;
      }
    }
    final typeAfterDiscard = _classifyCardGroupType(
      sentence,
      handAfterDiscard,
      visibleCount,
      isShiDuiRoute,
    );
    final scoreAfterDiscard = _getCardGroupTypeScoreForMen(
      typeAfterDiscard,
      sentence,
    );

    // 3. 计算结构分损失
    final scoreLoss = currentScore - scoreAfterDiscard;

    // 3.5 形成完整句奖励：出牌后该门形成完整句（句型），给予额外奖励
    // 这鼓励从"句孤张型"等牌型中出多余张，形成完整句
    // 黑元路线例外：黑元看组句速度，保留多一张才有机会成2句，不奖励形成1句
    double formSentenceBonus = 0;
    if (typeAfterDiscard == '句型' &&
        currentType != '句型' &&
        heiYuanPotential <= 0) {
      formSentenceBonus = 100; // 形成完整句的奖励
    }

    // 4. 门间优先级权重
    double menPriority = _getMenPriorityByRoute(
      sentence,
      shiDuiPotential,
      heiYuanPotential,
      hongYuanPotential,
      kuHuPotential,
      visibleCount,
    );

    // 红元路线下，门1/8的银字(大/人/禄/寿)不保护
    // 红元需要的是上/福(3-6张)，银字对红元路线没有帮助
    // 银字无法单独组精句(需要上/福)，保留银字不如优先出掉
    if (hongYuanPotential > 0 && (sentence == 1 || sentence == 8)) {
      final isJingChar =
          cardToDiscard.character == '上' || cardToDiscard.character == '福';
      if (!isJingChar) {
        menPriority = 2.0; // 银字不保护，与门2-7同等优先拆
      }
    }

    // 5. 基础评分：保留排名越低（越应牺牲），越鼓励出牌
    // 排名34(孤张型)→最高正分(鼓励出), 排名1(招招招型)→最高负分(禁止出)
    final rankScore = (currentRank - 17.5) * 12.0; // 34→198, 1→-198

    // 6. 结构分损失惩罚：损失越大越不应该出
    final lossPenalty = -scoreLoss * 1.5;

    // 7. 门间优先级调整：优先拆的门加分，保留的门减分
    final menAdjustment = (menPriority - 1.0) * 50.0;

    // 8. 牌型内选牌优先级：含孤张优先出孤张，含半靠优先出半靠
    double cardSelectionBonus = 0;
    final byChar = <String, int>{};
    for (final ch in _groupChars[sentence - 1]) {
      byChar[ch] = 0;
    }
    for (final c in hand) {
      if (c.sentence == sentence) {
        byChar[c.character] = (byChar[c.character] ?? 0) + 1;
      }
    }
    final discardCount = byChar[cardToDiscard.character] ?? 0;

    // 判断出的牌在牌型中的角色
    final counts = byChar.values.toList()..sort((a, b) => b.compareTo(a));
    final a = counts[0], b = counts[1], c = counts[2];

    // 孤张（该字只有1张，且不是对/坎/招/句/靠的一部分）
    if (discardCount == 1) {
      // 检查是否是孤张（同门只有1种字）或对孤张型/句孤张型中的孤张
      if (a + b + c == 1) {
        // 纯孤张型
        cardSelectionBonus += 100;
      } else if (currentType.contains('孤张')) {
        // 牌型中的孤张
        if (currentType == '对孤张型' &&
            huBefore >= 11 &&
            !isShiDuiRoute &&
            heiYuanPotential <= 0) {
          // 对孤张型 + ≥11胡：检查快进张潜力
          // 缺字 = 门中3字中不在场的字
          final missingChars = _groupChars[sentence - 1]
              .where((ch) => (byChar[ch] ?? 0) == 0)
              .toList();
          int missingRem = 0;
          for (final mc in missingChars) {
            missingRem += _remainingCount(mc, visibleCount);
          }
          if (missingRem >= 2) {
            // 缺字剩余多，1张成句，保留孤张（快进张路径）
            cardSelectionBonus += 20; // 降低加分，不鼓励出
          } else {
            // 缺字剩余少，孤张进张慢，优先出
            cardSelectionBonus += 80;
          }
        } else if (currentType == '对孤张型' && heiYuanPotential > 0) {
          // 黑元路线下，对孤张型中出孤张会保留对子
          // 但黑元不需要坎（对成坎无意义），保留对不如保留半靠
          // 降低出孤张的加分，使出对中字（保留半靠）更优先
          cardSelectionBonus += 20;
        } else {
          cardSelectionBonus += 80;
        }
      } else if (currentType.contains('半靠')) {
        // 半靠中的字，出一张损失=0
        // 黑元路线下，半靠是6句+1靠中的"靠"，需要保护
        if (heiYuanPotential > 0) {
          cardSelectionBonus -= 100; // 黑元路线下惩罚出半靠
        } else {
          // 胡数动态调整：<11胡优先拆半靠(加分高)，≥11胡保留半靠(加分低)
          cardSelectionBonus += huBefore < 11 ? 80 : 30;
        }
      }
    }

    // 半靠中的字（2种字各1张，出任一张损失=0）
    if (discardCount == 1 && a == 1 && b == 1 && c == 0) {
      // 黑元路线下，半靠是6句+1靠中的"靠"，需要保护
      if (heiYuanPotential > 0) {
        cardSelectionBonus -= 100; // 黑元路线下惩罚出半靠
      } else {
        // 胡数动态调整：<11胡优先拆半靠(加分高)，≥11胡保留半靠(加分低)
        cardSelectionBonus += huBefore < 11 ? 60 : 20;
      }
    }

    // 门1/8对孤张型特例：银对时优先出对中字保留银靠（精句潜力4胡 > 普坎潜力3胡）
    if (currentType == '对孤张型' &&
        (sentence == 1 || sentence == 8) &&
        discardCount >= 2 &&
        _isYin(cardToDiscard) &&
        !isShiDuiRoute) {
      // 银对（大大/人人/禄禄/寿寿），出对中字保留银靠（大人/禄寿等）有精句潜力
      cardSelectionBonus += 100; // 高于孤张的80，优先出对中字
    }

    // 句孤张型(2,1,1)中出孤张：有2张的字，1张参与句，1张是孤张
    // 出1张后形成完整句，损失=0，应与对孤张型中出孤张同等对待
    if (currentType == '句孤张型' && discardCount == 2 && !isShiDuiRoute) {
      cardSelectionBonus += 80; // 与对孤张型中出孤张相同
    }

    // 对中一张（出对中一张，保留完整集）
    if (discardCount >= 2 && discardCount < 3) {
      // 检查是否是"含对的牌型"中出对
      if (currentType.contains('对')) {
        // 含对的牌型（包括复合类型如坎对孤张型），出对中一张
        // 但十对路线绝不出对子
        if (isShiDuiRoute) {
          cardSelectionBonus -= 200; // 十对路线重罚出对子
        } else if (heiYuanPotential > 0) {
          // 黑元路线下，对子变碰会破坏黑元资格，优先拆对子
          // 黑元需要6句+1靠，对子不能作将牌
          // 检查对子是否为死对子（同门其他字剩余张数很少，无法成句）
          final otherChars = _groupChars[sentence - 1]
              .where((ch) => ch != cardToDiscard.character)
              .toList();
          int otherRem = 0;
          for (final ch in otherChars) {
            otherRem += _remainingCount(ch, visibleCount);
          }
          // 检查出对中字后是否形成半靠（对孤张型中出对中字，保留孤张+对中剩余1张=半靠）
          // 黑元路线下半靠有成句潜力，远优于保留对子
          final formsKaoAfterDiscard = currentType == '对孤张型' &&
              otherChars.any((ch) => (byChar[ch] ?? 0) >= 1);
          if (otherRem <= 2) {
            // 死对子：同门其他字剩余很少，无法成句，黑元路线下完全无用
            cardSelectionBonus += 200; // 大幅加分，优先出死对子
          } else if (formsKaoAfterDiscard) {
            // 出对中字后形成半靠（有成句潜力），黑元路线下最优出法
            cardSelectionBonus += 150;
          } else {
            // 活对子：有成句潜力，但仍鼓励拆（黑元不要对子）
            cardSelectionBonus += 100;
          }
        } else {
          // 检查对子是否已降级（剩余0张）
          final rem = _remainingCount(cardToDiscard.character, visibleCount);
          if (rem == 0) {
            cardSelectionBonus += 80; // 死对子，优先出
          } else if (huBefore >= 11) {
            // ≥11胡：检查对子成句难度
            final otherPresentChars = _groupChars[sentence - 1]
                .where((ch) => ch != cardToDiscard.character)
                .where((ch) => (byChar[ch] ?? 0) > 0)
                .toList();
            final missingChars = _groupChars[sentence - 1]
                .where((ch) => (byChar[ch] ?? 0) == 0)
                .toList();
            // 检查另一在场字是否被坎锁定（≥3张）
            final otherLockedInKan = otherPresentChars.any(
              (ch) => (byChar[ch] ?? 0) >= 3,
            );
            int missingRem = 0;
            for (final mc in missingChars) {
              missingRem += _remainingCount(mc, visibleCount);
            }
            if (otherLockedInKan || missingRem == 0) {
              // 另一字被坎锁定或缺字0剩余，对子无法成句，优先拆
              cardSelectionBonus += 80;
            } else if (missingRem == 1) {
              // 缺字仅剩1张，成句概率低
              cardSelectionBonus += 50;
            } else {
              // 缺字剩余多，保留对子
              cardSelectionBonus += 30;
            }
          } else {
            // <11胡：保留对子
            cardSelectionBonus -= 30;
          }
        }
      }
    }

    // 绝不拆句/坎/招（除非别无选择）
    if (discardCount >= 3) {
      // 出坎/招中的牌
      if (currentType.contains('招') || currentType.contains('坎')) {
        // 黑元路线下，坎离成句远，优先拆坎
        if (heiYuanPotential > 0) {
          cardSelectionBonus += 200; // 黑元路线鼓励拆坎
        } else {
          // 检查是否是含孤张/半靠/对的复合牌型中出坎/招
          // 如果是纯坎型/招型，重罚
          if (currentType == '坎型' || currentType == '招型') {
            cardSelectionBonus -= 150; // 重罚拆纯坎/纯招
          } else if (currentType.contains('坎') || currentType.contains('招')) {
            // 复合牌型中出坎/招，仍需惩罚
            cardSelectionBonus -= 100;
          }
        }
      }
    }

    // 9. 剩余张数动态调整：进张概率低的字优先出
    final rem = _remainingCount(cardToDiscard.character, visibleCount);
    if (rem == 0) {
      // 死牌（剩余0张），优先出
      cardSelectionBonus += 50;
    } else if (rem == 1) {
      // 进张概率低，小幅优先
      cardSelectionBonus += 20;
    }

    // 10. 精字保护（门1/8的精字上/福）
    if (cardToDiscard.isJing) {
      // 精字提供高胡数，除非黑元路线，否则惩罚
      if (heiYuanPotential <= 0) {
        // 胡数足够(>=11)且出牌后仍>=11时，精字惩罚大幅降低
        // 因为胡数已够，精字的胡数价值降低，进张效率更重要
        if (huBefore >= 11 && huAfter >= 11) {
          final sameGroupInHand = player.hand
              .where((c) => c.sentence == cardToDiscard.sentence)
              .length;
          if (sameGroupInHand == 1) {
            cardSelectionBonus -= 15; // 孤张型精字，轻微惩罚
          } else {
            cardSelectionBonus -= 50; // 非孤张型，中等惩罚
          }
        } else {
          cardSelectionBonus -= 100;
        }
      }
    }

    // 11. 低胡数时门1/8保护已移至主评分函数_evaluateDiscardComprehensiveWithDist
    // 主评分函数中的惩罚(-210~-370)大于拆句惩罚(-200)，确保拆1/8门在拆句之后

    final totalScore =
        rankScore +
        lossPenalty +
        menAdjustment +
        cardSelectionBonus +
        formSentenceBonus;
    return totalScore;
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
    // 正确计算melds中的实际牌数（招是4张牌，不是3张）
    int meldCards = 0;
    for (final meld in player.melds) {
      meldCards += meld.cards.length;
    }
    return player.hand.length + meldCards;
  }

  /// 检查2-7门是否有独张（孤张）
  /// 独张：该门只有1张牌（1种字，1张）
  bool _hasSingleInGroup2To7(Player player) {
    for (var sentence = 2; sentence <= 7; sentence++) {
      final groupCards = player.hand
          .where((c) => c.sentence == sentence)
          .toList();
      if (groupCards.length == 1) {
        return true;
      }
    }
    return false;
  }

  /// 检查指定门的牌是否是独张（该门只有1张牌）
  bool _isSingleInGroup(Player player, int sentence) {
    final groupCards = player.hand
        .where((c) => c.sentence == sentence)
        .toList();
    return groupCards.length == 1;
  }

  /// 计算玩家出牌前的目标总牌数（手牌+组合牌）
  /// 基础20张，每个招+1张（招是4张牌但占1个句位）
  int _targetCardCount(Player player) {
    int zhaoCount = 0;
    for (final meld in player.melds) {
      if (meld.type == MeldType.zhao) zhaoCount++;
    }
    return 20 + zhaoCount;
  }

  /// 检查是否可以执行吃/碰/招操作
  /// 出牌后未摸牌状态（总牌数=目标-1）才能吃/碰/招别人出的牌
  bool _canOperate(Player player) {
    return _totalCardCount(player) < _targetCardCount(player);
  }

  /// 检查是否可以招自己手牌上的牌
  /// 招后补摸状态下，总牌数=目标+1（多1张补摸的牌），仍允许继续招
  bool _canZhaoFromHand(Player player, String character) {
    final totalCards = _totalCardCount(player);
    final target = _targetCardCount(player);
    // 招后补摸状态：总牌数=目标+1（含补摸的1张），允许继续招
    if (totalCards > target + 1) return false;
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
    print(
      'DEBUG shouldChi开始: card=${card.character}, hand=${player.hand.map((c) => c.character).join()}, melds=${player.melds.map((m) => m.cards.map((c) => c.character).join()).join(",")}',
    );

    // 8对以上强制走十对路线，不吃牌
    if (_currentShiDuiEnabled && _countHandPairsWithMelds(player) >= 8) {
      print('DEBUG shouldChi: 拒绝吃牌(8对以上十对路线)');
      return false;
    }

    if (_hasCompleteSentenceWithSingleCards(player, card)) {
      return false;
    }

    // 20张牌时不能吃
    if (!_canOperate(player)) return false;

    // 黑元路线下，不吃门1/8的牌（吃门1/8会形成门1/8句，破坏黑元资格）
    final heiYuanPotential = _evaluateHeiYuanPotential(player);
    if (heiYuanPotential > 0 && (card.sentence == 1 || card.sentence == 8)) {
      return false;
    }

    // 黑元路线下，吃牌后如果手牌中剩余对子无法再组成句（死对子），且没有其他多余牌可以打，不吃
    // 黑元要求无碰无招，对子只能通过组句利用；若对子的字无法组句，则是负担
    // 但如果吃牌后有多余牌可以打（包括死对子本身），允许吃牌后打出死对子
    // 例：手牌"佳佳作亡"吃"佳"形成"佳作亡"句后剩"佳佳"对子，
    // "作""亡"已被消耗，"佳佳"无法再组句，是死对子，但可以打出，所以允许吃
    if (heiYuanPotential > 0) {
      final otherChars = _getOtherCharsInGroup(card);
      final availableChars = otherChars
          .where((ch) => player.hand.any((c) => c.character == ch))
          .toList();
      if (availableChars.length >= 2) {
        // 尝试每种吃法，检查是否所有吃法都产生死对子且没有多余牌可打
        bool allWaysProduceDeadPairNoExcess = true;
        for (
          int i = 0;
          i < availableChars.length && allWaysProduceDeadPairNoExcess;
          i++
        ) {
          for (int j = i + 1; j < availableChars.length; j++) {
            final consumedChars = [availableChars[i], availableChars[j]];
            final testHand = List<Card>.from(player.hand);
            for (final ch in consumedChars) {
              final idx = testHand.indexWhere((c) => c.character == ch);
              if (idx >= 0) testHand.removeAt(idx);
            }
            // 检查手牌中是否有死对子（对子的字无法再组句）
            final charCount = <String, int>{};
            for (final c in testHand) {
              charCount[c.character] = (charCount[c.character] ?? 0) + 1;
            }
            bool hasDeadPair = false;
            for (final entry in charCount.entries) {
              if (entry.value >= 2) {
                // 检查该对子的字是否还能组句
                final sentence = _charSentenceMap[entry.key]!;
                final otherGroupChars = _groupChars[sentence - 1]
                    .where((ch) => ch != entry.key)
                    .toList();
                // 检查句的其他2个字是否在手牌中
                final hasOther1 = testHand.any(
                  (c) => c.character == otherGroupChars[0],
                );
                final hasOther2 = testHand.any(
                  (c) => c.character == otherGroupChars[1],
                );
                if (!hasOther1 || !hasOther2) {
                  // 句的其他字不在手牌中，对子无法组句，是死对子
                  hasDeadPair = true;
                  break;
                }
              }
            }
            // 即使有死对子，只要有多余牌可以打（死对子本身可以打出），就允许吃
            // 死对子可以被打出，所以不算"没有多余牌可打"
            if (!hasDeadPair) {
              allWaysProduceDeadPairNoExcess = false;
            }
          }
        }
        // 只有当所有吃法都产生死对子时才不吃（死对子可以打出，所以不再阻止吃牌）
        // 注：死对子检查的原始目的是避免吃牌后手牌中留下死对子，
        // 但如果吃牌后可以打出死对子，那么手牌中就不会留下死对子了
        // 所以这里不再因为死对子而阻止吃牌
        // if (allWaysProduceDeadPairNoExcess) return false;
      }
    }

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

    print(
      'DEBUG shouldChi: bestBenefit=$bestBenefit, availableChars=$availableChars',
    );

    // 胡数小于8且不走黑元路线时，吃牌如果破坏普通对子，不吃
    // 例外：吃后听牌（bestBenefit>=10000）时允许吃
    // 例：手牌"丘丘己"胡数<8且非黑元，吃"乙"会破坏丘对，不吃
    if (!player.isTing && bestBenefit < 10000) {
      final totalHu = _evaluateHuScore(player);
      if (totalHu < 8) {
        final heiYuanPotential = _evaluateHeiYuanPotential(player);
        if (heiYuanPotential <= 0) {
          // 1. 吃牌破坏普通对子，不吃
          if (_wouldBreakNormalPair(player, card)) {
            return false;
          }
          // 2. 低胡数且吃的不是精字时，吃牌不提升胡数则优先摸牌提高胡数
          // 例：手牌"人人丘己化千七七土尔小生八九九子禄禄寿"胡数=0，
          // 吃"子"形成八九子句但胡数仍=0，不如摸牌有机会摸到上/福（精字4胡）
          if (card.character != '上' && card.character != '福') {
            final shiDuiPotential = _evaluateShiDuiPotential(player, state);
            if (shiDuiPotential <= 0) {
              final maxHuAfterChi = _calculateMaxHuAfterChi(player, card);
              if (maxHuAfterChi <= totalHu) {
                return false;
              }
            }
          }
        }
      }
    }

    // 不走黑元/红元路线时，坎对型不拆开吃上家的牌
    // 理由：坎是完整集（3张同字），拆开损失大；坎对型有进张成坎坎型的潜力
    // 例外1：对中字剩余0张（对已降级为死对子），允许拆坎吃
    // 例外2：吃后听牌（bestBenefit>=10000）时允许吃
    // 注意：必须用实际的黑元/红元潜力判断，而非仅检查组合牌类型
    // 例：手牌"上大丘乙乙乙..."有门1牌，不能走黑元；门1句不足2组，不能走红元
    // 此时拆坎吃"己"会破坏乙乙乙坎（3胡→0胡），不应允许
    if (!player.isTing && bestBenefit < 10000) {
      final heiYuanPot = _evaluateHeiYuanPotential(player);
      final hongYuanPot = _evaluateHongYuanPotential(player);
      print(
        'DEBUG shouldChi坎破坏检查: card=${card.character}, isTing=${player.isTing}, bestBenefit=$bestBenefit, heiYuanPot=$heiYuanPot, hongYuanPot=$hongYuanPot',
      );
      if (heiYuanPot <= 0 && hongYuanPot <= 0) {
        final wouldBreakKan = _wouldBreakKan(player, card);
        print('DEBUG shouldChi坎破坏检查: wouldBreakKan=$wouldBreakKan');
        if (wouldBreakKan) {
          // 检查对中字是否剩余0张（对已降级）
          final pairRemainZero = _pairCharRemainZero(player, card, state);
          print('DEBUG shouldChi坎破坏检查: pairRemainZero=$pairRemainZero');
          if (!pairRemainZero) {
            print('DEBUG shouldChi坎破坏检查: 拒绝吃牌(破坏坎)');
            return false;
          }
        }
      }
    }

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
      print(
        'DEBUG shouldChi最终: 截胡策略, bestBenefit=$bestBenefit > -50? ${bestBenefit > -50}',
      );
      return bestBenefit > -50;
    }

    final result = bestBenefit > 0;
    print('DEBUG shouldChi最终: bestBenefit=$bestBenefit > 0? $result');
    return result;
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

  /// 检查吃牌是否会破坏普通对子
  /// 普通对子 = 2张同字（非上/福，即普对/银对，不含金对上上/福福）
  /// 吃牌消耗的2个字中，如果有任一字在手牌中恰好有2张且非上/福，
  /// 则吃牌会破坏该对子（吃掉1张后只剩1张单牌）
  /// 例：手牌"丘丘己"，吃"乙"会消耗"丘"和"己"，"丘"有2张，破坏丘对
  bool _wouldBreakNormalPair(Player player, Card card) {
    final hand = player.hand;
    final otherChars = _getOtherCharsInGroup(card);
    final availableChars = otherChars
        .where((ch) => hand.any((c) => c.character == ch))
        .toList();

    if (availableChars.length < 2) return false;

    // 提取手牌中的句，用于排除参与句的字
    // 参与句的2张牌中，1张在句中，1张是单牌，不算对子
    final handRemaining = List<Card>.from(hand);
    final handASet = <Meld>[];
    HuCalculator.extractJu(handRemaining, handASet);

    for (final ch in availableChars) {
      // 上/福的对子是金对，不属于"普通对子"
      if (ch == '上' || ch == '福') continue;
      final chCount = hand.where((c) => c.character == ch).length;
      if (chCount != 2) continue; // 恰好2张才是对子
      // 参与句的字，1张在句中，1张是单牌，不算对子
      final inJu = handASet.any((m) => m.cards.any((c) => c.character == ch));
      if (inJu) continue;
      // 该字恰好2张且非上/福，吃掉1张会破坏对子
      return true;
    }
    return false;
  }

  /// 快速判断是否还能走黑元或红元路线
  /// 组合牌中有坎或招 → 不能走黑元/红元（黑元要求无碰，红元要求无碰无招）
  bool _canHeiYuanOrHongYuan(Player player) {
    for (final m in player.melds) {
      if (m.type == MeldType.kan || m.type == MeldType.zhao) {
        return false;
      }
    }
    return true;
  }

  /// 检查吃牌是否会拆开手牌中的坎（3张同字）
  /// 坎对型如"丘丘丘乙乙"，吃"丘乙己"会从坎中拆1张丘
  bool _wouldBreakKan(Player player, Card card) {
    final hand = player.hand;
    final otherChars = _getOtherCharsInGroup(card);
    final availableChars = otherChars
        .where((ch) => hand.any((c) => c.character == ch))
        .toList();

    if (availableChars.length < 2) return false;

    // 提取手牌中的句，用于排除参与句的字
    final handRemaining = List<Card>.from(hand);
    final handASet = <Meld>[];
    HuCalculator.extractJu(handRemaining, handASet);

    for (final ch in availableChars) {
      final chCount = hand.where((c) => c.character == ch).length;
      if (chCount != 3) continue; // 恰好3张才是坎
      // 参与句的字不算坎（1张在句中，2张是对子）
      final inJu = handASet.any((m) => m.cards.any((c) => c.character == ch));
      if (inJu) continue;
      // 该字恰好3张且不参与句，吃掉1张会拆坎
      return true;
    }
    return false;
  }

  /// 检查坎对型中对中字（2张同字）的剩余张数是否为0
  /// 坎对型 = 坎(3张A) + 对(2张B)，检查B的剩余张数
  /// 如果对中字剩余0张，对已降级，此时拆坎吃是合理的
  bool _pairCharRemainZero(Player player, Card card, GameState state) {
    final hand = player.hand;
    final otherChars = _getOtherCharsInGroup(card);
    final availableChars = otherChars
        .where((ch) => hand.any((c) => c.character == ch))
        .toList();

    if (availableChars.length < 2) return false;

    final visibleCount = _buildVisibleCharCount(player, state);

    // 提取手牌中的句
    final handRemaining = List<Card>.from(hand);
    final handASet = <Meld>[];
    HuCalculator.extractJu(handRemaining, handASet);

    for (final ch in availableChars) {
      final chCount = hand.where((c) => c.character == ch).length;
      if (chCount != 2) continue; // 恰好2张是对子
      // 参与句的字不算对子
      final inJu = handASet.any((m) => m.cards.any((c) => c.character == ch));
      if (inJu) continue;
      // 检查该对中字剩余张数
      final rem = _remainingCount(ch, visibleCount);
      if (rem == 0) return true; // 对中字剩余0张，对已降级
    }
    return false;
  }

  /// 模拟吃牌后的胡数（吃牌后、出牌前），返回所有可能吃法中的最大胡数
  /// 用于判断吃牌是否提升胡数
  double _calculateMaxHuAfterChi(Player player, Card card) {
    final otherChars = _getOtherCharsInGroup(card);
    final availableChars = otherChars
        .where((ch) => player.hand.any((c) => c.character == ch))
        .toList();
    if (availableChars.length < 2) return _evaluateHuScore(player);

    double maxHu = _evaluateHuScore(player);

    // 尝试所有可能的2字组合（C(n,2)种吃法）
    for (int i = 0; i < availableChars.length; i++) {
      for (int j = i + 1; j < availableChars.length; j++) {
        final useChars = [availableChars[i], availableChars[j]];

        final testHand = List<Card>.from(player.hand);
        for (final ch in useChars) {
          final idx = testHand.indexWhere((c) => c.character == ch);
          if (idx >= 0) testHand.removeAt(idx);
        }

        final newMeld = Meld(
          cards: [
            card,
            ...useChars.map(
              (ch) => player.hand.firstWhere((c) => c.character == ch),
            ),
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

        final hu = _evaluateHuScore(testPlayer);
        if (hu > maxHu) maxHu = hu;
      }
    }

    return maxHu;
  }

  @override
  bool shouldPeng(Player player, Card card, GameState state) {
    _initCache(player, state);

    // 8对以上强制走十对路线，不碰牌
    if (_currentShiDuiEnabled && _countHandPairsWithMelds(player) >= 8) {
      return false;
    }

    final hand = player.hand;
    final sameCharCount = hand
        .where((c) => c.character == card.character)
        .length;

    if (sameCharCount < 2) return false;

    // 20张牌时不能碰
    if (!_canOperate(player)) return false;

    // 黑元路线下，不碰牌（碰会形成坎，破坏黑元资格）
    final heiYuanPotential = _evaluateHeiYuanPotential(player);
    if (heiYuanPotential > 0) {
      return false;
    }

    // 截胡策略：其他玩家快听牌时，更积极碰牌
    final opponentNearTing = _hasOpponentNearTing(state, player.id);

    if (sameCharCount >= 2) {
      // 如果手牌中已有3张同字（坎），碰牌会把坎从手牌移到组合牌区
      // 手牌坎=3胡，组合牌坎=2胡，净损失1胡
      // 但碰牌减少手牌2张，可能改善听牌距离
      // 决策：碰后听牌→碰；碰后距离改善→碰；否则不碰
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
        if (tingAfter3.isTing) {
          // 碰后听牌，继续往下评估
        } else {
          // 碰后不听牌，检查距离是否改善
          final distBefore3 = _distanceToTing(
            List<Card>.from(hand),
            player.melds,
          );
          final (_, distAfter3) = _findBestDiscardAfterMeld(
            testHand3,
            [...player.melds, newMeld3],
            visibleCount:
                _cachedVisibleCount ?? _buildVisibleCharCount(player, state),
            totalUnknown:
                _cachedTotalUnknown ?? _totalUnknownCards(player, state),
          );
          // 距离没改善（>=）则不碰，损失1胡不划算
          if (distAfter3 >= distBefore3) return false;
          // 距离改善，继续往下评估
        }
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

      // 碰后需要出牌，模拟出牌后检查是否听牌
      // 注意：碰后未出牌时手牌+组合牌=20张，不满足听牌检查条件(<20)
      // 所以必须模拟出牌后再检查听牌
      final newMelds = [...player.melds, newMeld];
      final (bestHandAfterPeng, distAfterDiscard) = _findBestDiscardAfterMeld(
        testHand,
        newMelds,
        visibleCount:
            _cachedVisibleCount ?? _buildVisibleCharCount(player, state),
        totalUnknown: _cachedTotalUnknown ?? _totalUnknownCards(player, state),
      );
      final testPlayerAfterDiscard = Player(
        id: player.id,
        name: player.name,
        type: player.type,
        hand: bestHandAfterPeng,
        melds: newMelds,
      );
      final tingAfterDiscard = _checkTingCached(testPlayerAfterDiscard);
      if (tingAfterDiscard.isTing) return true;
      if (player.isTing && !tingAfterDiscard.isTing) return false;

      // 碰牌后十对路线不可用（melds不为空），碰前距离应使用普通路线距离比较
      // 避免十对距离(较小)与普通距离(较大)的不公平比较导致不碰
      final distBefore = _currentShiDuiEnabled && player.melds.isEmpty
          ? _distanceToTingNormal(List<Card>.from(hand), player.melds)
          : _distanceToTing(List<Card>.from(hand), player.melds);

      if (distAfterDiscard > distBefore) return false;

      if (distAfterDiscard < distBefore) return true;

      // 距离不变时，门1/8精句潜力保护
      // 碰银字(大/人/禄/寿)形成普坎(3胡)，但会消耗精句组件
      // 保留禄禄寿寿+福等摸福组"福禄寿"精句(4胡) > 碰禄普坎(3胡)
      // 例：手牌"福禄禄寿寿"，碰禄后"福寿寿"无法组精句，不碰
      if (card.sentence == 1 || card.sentence == 8) {
        final isJingChar = card.character == '上' || card.character == '福';
        if (!isJingChar) {
          // 碰的是银字，检查手牌中是否有精字(上/福)可组精句
          final jingChar = card.sentence == 1 ? '上' : '福';
          final hasJing = hand.any((c) => c.character == jingChar);
          if (hasJing) {
            // 统计碰牌后该门剩余的不同字数
            final charsAfterPeng = <String>{};
            for (final c in testHand) {
              if (c.sentence == card.sentence) {
                charsAfterPeng.add(c.character);
              }
            }
            // 碰牌后不足3个不同字，无法组精句
            // 精句4胡 > 普坎3胡，保留精句潜力不碰
            if (charsAfterPeng.length < 3) {
              return false;
            }
          }
        }
      }

      // 距离不变时，比较碰牌前后胡数差值
      final huScoreBefore = _evaluateHuScore(player);
      final huScoreAfter = _evaluateHuScore(testPlayer);
      if (huScoreAfter > huScoreBefore) return true;

      // 距离和胡数都不变时，比较碰牌前后的进张数
      final vc = _cachedVisibleCount ?? _buildVisibleCharCount(player, state);
      final tu = _cachedTotalUnknown ?? _totalUnknownCards(player, state);
      // 复用之前_findBestDiscardAfterMeld的结果bestHandAfterPeng
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

      // 路线进度加分（规则二十四）：枯胡路线碰坎+50，普通胡路线碰坎+30
      // 距离和胡数都不变时，路线进度加分作为tiebreaker
      final route = _currentRoute ?? _RouteType.normal;
      final routeBonus = _routeOperationBonus('peng', route);
      if (routeBonus >= 50) return true; // 枯胡路线积极碰坎

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

    // 黑元路线下，不招牌（招会形成招，破坏黑元资格）
    final heiYuanPotential = _evaluateHeiYuanPotential(player);
    if (heiYuanPotential > 0) {
      return false;
    }

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

      // 比较招vs吃：手牌能吃上家的牌时，模拟吃牌后效果
      // 场景：手牌七七七十土，玩家出七。招七后十土成死靠（七全在招牌），
      //       吃七后七十土句在组合牌区，手牌结构更优，听牌距离更近
      final otherChars = _getOtherCharsInGroup(card);
      final availableChars = otherChars
          .where((ch) => hand.any((c) => c.character == ch))
          .toList();
      if (availableChars.length >= 2) {
        int bestChiDist = 99;
        double bestChiHu = 0;
        for (int i = 0; i < availableChars.length; i++) {
          for (int j = i + 1; j < availableChars.length; j++) {
            final consumedChars = [availableChars[i], availableChars[j]];
            final chiHand = List<Card>.from(hand);
            for (final ch in consumedChars) {
              final idx = chiHand.indexWhere((c) => c.character == ch);
              if (idx >= 0) chiHand.removeAt(idx);
            }
            final chiMeld = Meld(
              cards: [
                card,
                ...consumedChars.map(
                  (ch) => hand.firstWhere((c) => c.character == ch),
                ),
              ],
              type: MeldType.ju,
              isJing: card.isJing,
            );
            final chiMelds = [...player.melds, chiMeld];
            final vc =
                _cachedVisibleCount ?? _buildVisibleCharCount(player, state);
            final tu = _cachedTotalUnknown ?? _totalUnknownCards(player, state);
            final (_, chiDist) = _findBestDiscardAfterMeld(
              chiHand,
              chiMelds,
              visibleCount: vc,
              totalUnknown: tu,
            );
            if (chiDist < bestChiDist) {
              bestChiDist = chiDist;
              final chiPlayer = Player(
                id: player.id,
                name: player.name,
                type: player.type,
                hand: chiHand,
                melds: chiMelds,
              );
              HuCalculator.updateMeldHuCache(chiPlayer);
              bestChiHu = _evaluateHuScore(chiPlayer);
            }
          }
        }
        // 吃牌距离更短时，不招（吃牌更优）
        if (bestChiDist < distAfter) return false;
        // 距离相同时，吃后胡数已满足门槛(>=11)则倾向吃（保留手牌灵活性）
        // 招牌会把4张同字全部移走，可能破坏手牌结构（如十土成死靠）
        if (bestChiDist == distAfter &&
            bestChiHu >= 11 &&
            huZhao < bestChiHu + 5) {
          return false;
        }
      }

      // 招比碰胡数更高或距离更短时，选择招
      if (huZhao >= huPeng && distAfter <= distPeng) return true;
      if (huZhao > huPeng + 4) return true;
      if (distAfter < distPeng) return true;

      // 路线进度加分（规则二十四）：普通胡路线招+40
      // 距离和胡数都相近时，路线进度加分作为tiebreaker
      final route = _currentRoute ?? _RouteType.normal;
      final zhaoRouteBonus = _routeOperationBonus('zhao', route);
      final pengRouteBonus = _routeOperationBonus('peng', route);
      if (zhaoRouteBonus > pengRouteBonus && huZhao >= huPeng) return true;

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

    // 招后补摸状态下，总牌数可能>20，仍允许继续招
    if (!_canZhaoFromHand(player, character)) {
      return false;
    }

    // 黑元路线下，不招牌（招会形成招，破坏黑元资格）
    final heiYuanPotential = _evaluateHeiYuanPotential(player);
    if (heiYuanPotential > 0) {
      return false;
    }

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
      // 正确计算组合牌实际牌数（招是4张牌，不是3张）
      final allMelds = [...player.melds, newMeld];
      final meldCardsCount = allMelds.fold<int>(
        0,
        (sum, m) => sum + m.cards.length,
      );
      final totalCardsAfterZhao = testHand.length + meldCardsCount;
      // 招后总牌数=胡牌目标张数-1时，补摸1张可胡
      // 胡牌目标张数=20+招数（每个招多1张牌）
      final zhaoCount = allMelds.where((m) => m.type == MeldType.zhao).length;
      final huTargetCards = 20 + zhaoCount;
      if (totalCardsAfterZhao == huTargetCards - 1) {
        // 招后差1张补摸即可达到胡牌张数，检查补摸后能否自摸
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
        // 手牌4张同字自招：招后distAfterZhao==distBefore是正常的（招不改变听牌距离）
        // 但招增加胡数（精招16胡）且获得补摸机会，应该允许
        // 只有distAfterZhao > distBefore（招使听牌距离变远）时才阻止
        if (distAfterZhao > distBefore) return false;
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
