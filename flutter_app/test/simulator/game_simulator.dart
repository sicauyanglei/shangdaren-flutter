import 'dart:math';
import 'package:shangdaren_game/game/models/card.dart';
import 'package:shangdaren_game/game/models/player.dart';
import 'package:shangdaren_game/game/models/meld.dart';
import 'package:shangdaren_game/game/models/game_state.dart';
import 'package:shangdaren_game/game/logic/hu_calculator.dart';
import 'package:shangdaren_game/game/logic/ting_checker.dart';
import 'package:shangdaren_game/game/logic/ai/ai_strategy_hard.dart';
import 'package:shangdaren_game/game/logic/ai/ai_strategy.dart';
import 'decision_logger.dart';
/// 单局游戏结果
class RoundResult {
  final int winnerIndex;
  final bool isZimo;
  final int? dianpaoIndex;
  final String huType;
  final int huCount;
  final bool isLiuju;
  final List<int> scoreChanges;

  RoundResult({
    required this.winnerIndex,
    required this.isZimo,
    this.dianpaoIndex,
    required this.huType,
    required this.huCount,
    required this.isLiuju,
    required this.scoreChanges,
  });
}

/// 一组8局游戏结果
class GameResult {
  final int gameIndex;
  final List<RoundResult> rounds;
  final List<int> finalScores;

  GameResult({
    required this.gameIndex,
    required this.rounds,
    required this.finalScores,
  });

  int get huCount => rounds.where((r) => !r.isLiuju).length;
  int get liujuCount => rounds.where((r) => r.isLiuju).length;
  int get zimoCount => rounds.where((r) => r.isZimo).length;
}

/// 无UI游戏模拟器
class GameSimulator {
  final Random _rng = Random();
  final AIStrategy _aiStrategy;
  final bool debugLog;
  final DecisionLogger _logger = DecisionLogger();
  int _currentGameId = 0;
  int _currentRound = 0;

  GameSimulator({AIStrategy? aiStrategy, this.debugLog = false})
      : _aiStrategy = aiStrategy ?? AIStrategyHard();

  /// 运行一组8局游戏
  GameResult runGame(int gameIndex) {
    _currentGameId = gameIndex;
    final players = List.generate(3, (i) => Player(
      id: i,
      name: 'AI$i',
      type: PlayerType.ai,
      gender: _rng.nextBool() ? Gender.male : Gender.female,
    ));

    var dealerIndex = _rng.nextInt(3);
    final rounds = <RoundResult>[];

    for (int round = 1; round <= 8; round++) {
      final result = _runRound(players, dealerIndex, round);
      rounds.add(result);

      // 庄家轮转
      if (result.isLiuju) {
        // 流局：庄家不变
      } else if (result.winnerIndex == dealerIndex) {
        // 庄家赢：继续坐庄
      } else {
        // 庄家没赢：逆时针轮转
        dealerIndex = (dealerIndex + 1) % 3;
      }
    }

    return GameResult(
      gameIndex: gameIndex,
      rounds: rounds,
      finalScores: players.map((p) => p.score).toList(),
    );
  }

  /// 运行一局游戏
  RoundResult _runRound(List<Player> players, int dealerIndex, int roundNumber) {
    _currentRound = roundNumber;
    // 重置玩家状态
    for (final p in players) {
      p.hand.clear();
      p.melds.clear();
      p.discards.clear();
      p.isTing = false;
      p.tingCards.clear();
      p.tingType = TingType.none;
      p.huCount = 0;
      p.meldHuCount = 0;
    }

    // 洗牌发牌
    final deck = Card.createDeck();
    int deckIdx = 0;

    // 庄家20张，闲家19张
    for (int i = 0; i < 3; i++) {
      final count = (i == dealerIndex) ? 20 : 19;
      for (int j = 0; j < count; j++) {
        players[i].hand.add(deck[deckIdx++]);
      }
    }

    // 构建GameState
    final state = GameState(
      players: players,
      currentPlayerIndex: dealerIndex,
      dealerIndex: dealerIndex,
      roundNumber: roundNumber,
      deck: deck.sublist(deckIdx),
      baseScore: 5,
      multiplierBase: 2,
      difficulty: 'hard',
    );

    // 初始化公开牌计数
    _rebuildPublicCount(state);

    // 检查庄家初始招
    _checkInitialZhao(players[dealerIndex], state);

    // 游戏主循环
    var currentPlayer = dealerIndex;
    bool skipDraw = false; // 碰/吃后跳过摸牌
    bool dealerFirstTurn = true;

    while (state.deck.isNotEmpty || !skipDraw) {
      // 检查流局
      if (state.deck.isEmpty && !skipDraw) {
        return RoundResult(
          winnerIndex: -1,
          isZimo: false,
          huType: '',
          huCount: 0,
          isLiuju: true,
          scoreChanges: [0, 0, 0],
        );
      }

      final player = players[currentPlayer];

      // 摸牌或跳过
      Card? drawnCard;
      if (!skipDraw && !dealerFirstTurn) {
        if (state.deck.isEmpty) {
          return RoundResult(
            winnerIndex: -1,
            isZimo: false,
            huType: '',
            huCount: 0,
            isLiuju: true,
            scoreChanges: [0, 0, 0],
          );
        }
        drawnCard = state.deck.removeLast();
        player.hand.add(drawnCard);
        _addPublicCount(state, drawnCard.character, 1);
        HuCalculator.updateMeldHuCache(player);
      }
      skipDraw = false;
      dealerFirstTurn = false;

      // 检查自摸
      if (_canZimo(player)) {
        final huType = HuCalculator.detectHuType(player, paoCard: null);
        final huCount = HuCalculator.calculateTotalHu(player);
        final scoreChanges = _calculateScores(players, currentPlayer, true, null, huType);
        _applyScores(players, scoreChanges);
        return RoundResult(
          winnerIndex: currentPlayer,
          isZimo: true,
          huType: huType.name,
          huCount: huCount,
          isLiuju: false,
          scoreChanges: scoreChanges,
        );
      }

      // 检查手牌招
      final zhaoChars = _getZhaoCandidates(player);
      if (zhaoChars.isNotEmpty && _getTotalCardCount(player) >= _getTargetCardCount(player)) {
        // AI决定是否招
        for (final ch in zhaoChars) {
          if (_aiStrategy.shouldZhaoFromHand(player, ch, state)) {
            _handleZhaoFromHand(player, ch, state);
            // 招后补摸
            if (state.deck.isNotEmpty) {
              drawnCard = state.deck.removeLast();
              player.hand.add(drawnCard);
              _addPublicCount(state, drawnCard.character, 1);
              HuCalculator.updateMeldHuCache(player);
            }
            // 重新检查自摸
            if (_canZimo(player)) {
              final huType = HuCalculator.detectHuType(player, paoCard: null);
              final huCount = HuCalculator.calculateTotalHu(player);
              final scoreChanges = _calculateScores(players, currentPlayer, true, null, huType);
              _applyScores(players, scoreChanges);
              return RoundResult(
                winnerIndex: currentPlayer,
                isZimo: true,
                huType: huType.name,
                huCount: huCount,
                isLiuju: false,
                scoreChanges: scoreChanges,
              );
            }
            break;
          }
        }
      }

      // AI出牌决策
      final handBeforeStr = player.hand.map((c) => c.character).join();
      final huBefore = HuCalculator.calculateTotalHu(player);
      final discardCard = _aiStrategy.selectDiscard(player, state);
      final cardGroupType = CardGroupClassifier.classifyDiscard(player.hand, discardCard);

      // 记录决策
      if (_logger.enabled) {
        _logger.log(DecisionRecord(
          gameId: _currentGameId,
          roundNumber: _currentRound,
          playerId: player.id,
          handBefore: handBeforeStr,
          meldsDesc: player.melds.map((m) => m.cards.map((c) => c.character).join()).toList(),
          discardedChar: discardCard.character,
          huBefore: huBefore,
          routeType: 'normal',
          cardGroupType: cardGroupType,
          remainingOfDiscarded: 4 - (state.publicCardCount[discardCard.character] ?? 0),
          reason: '',
        ));
      }

      player.hand.remove(discardCard);
      player.discards.add(discardCard);
      state.lastDiscardedCard = discardCard;
      state.lastDiscardPlayerIndex = currentPlayer;

      // 出牌后检查听牌
      final tingResult = TingChecker.checkTing(player);
      player.isTing = tingResult.isTing;
      player.tingCards = tingResult.tingCards;
      player.tingType = tingResult.tingType;

      // 检查其他玩家响应（胡>招>碰>吃）
      final response = _checkResponses(players, discardCard, currentPlayer, state);
      if (response != null) {
        if (response.isHu) {
          final winner = response.responderIndex!;
          final dianpao = currentPlayer;
          final huType = HuCalculator.detectHuType(players[winner], paoCard: discardCard);
          final huCount = HuCalculator.calculateTotalHu(players[winner], paoCard: discardCard);
          final scoreChanges = _calculateScores(players, winner, false, dianpao, huType);
          _applyScores(players, scoreChanges);
          return RoundResult(
            winnerIndex: winner,
            isZimo: false,
            dianpaoIndex: dianpao,
            huType: huType.name,
            huCount: huCount,
            isLiuju: false,
            scoreChanges: scoreChanges,
          );
        } else if (response.isZhao) {
          _handleZhaoRespond(players[response.responderIndex!], discardCard, state);
          currentPlayer = response.responderIndex!;
          skipDraw = true;
          continue;
        } else if (response.isPeng) {
          _handlePeng(players[response.responderIndex!], discardCard, state);
          currentPlayer = response.responderIndex!;
          skipDraw = true;
          continue;
        } else if (response.isChi) {
          _handleChi(players[response.responderIndex!], discardCard, state);
          currentPlayer = response.responderIndex!;
          skipDraw = true;
          continue;
        }
      }

      // 下一玩家
      currentPlayer = (currentPlayer + 1) % 3;
    }

    // 流局
    return RoundResult(
      winnerIndex: -1,
      isZimo: false,
      huType: '',
      huCount: 0,
      isLiuju: true,
      scoreChanges: [0, 0, 0],
    );
  }

  /// 检查庄家初始招
  void _checkInitialZhao(Player player, GameState state) {
    final zhaoChars = _getZhaoCandidates(player);
    for (final ch in zhaoChars) {
      if (_aiStrategy.shouldZhaoFromHand(player, ch, state)) {
        _handleZhaoFromHand(player, ch, state);
        // 招后补摸
        if (state.deck.isNotEmpty) {
          final card = state.deck.removeLast();
          player.hand.add(card);
          _addPublicCount(state, card.character, 1);
          HuCalculator.updateMeldHuCache(player);
        }
      }
    }
  }

  /// 检查自摸
  bool _canZimo(Player player) {
    if (player.hand.isEmpty) return false;
    return HuCalculator.canHu(player.hand, player.melds);
  }

  /// 获取招字候选
  List<String> _getZhaoCandidates(Player player) {
    final byChar = <String, int>{};
    for (final card in player.hand) {
      byChar[card.character] = (byChar[card.character] ?? 0) + 1;
    }
    return byChar.entries.where((e) => e.value == 4).map((e) => e.key).toList();
  }

  /// 总牌数
  int _getTotalCardCount(Player player) {
    int meldCards = 0;
    for (final meld in player.melds) {
      meldCards += meld.cards.length;
    }
    return player.hand.length + meldCards;
  }

  /// 目标牌数
  int _getTargetCardCount(Player player) {
    int zhaoCount = 0;
    for (final meld in player.melds) {
      if (meld.type == MeldType.zhao) zhaoCount++;
    }
    return 20 + zhaoCount;
  }

  /// 手牌招
  void _handleZhaoFromHand(Player player, String character, GameState state) {
    final zhaoCards = player.hand.where((c) => c.character == character).take(4).toList();
    for (final c in zhaoCards) {
      player.hand.remove(c);
    }
    player.melds.add(Meld(
      cards: zhaoCards,
      type: MeldType.zhao,
      isJing: zhaoCards.first.isJing,
    ));
    HuCalculator.updateMeldHuCache(player);
  }

  /// 招别人出的牌
  void _handleZhaoRespond(Player player, Card card, GameState state) {
    final zhaoCards = player.hand.where((c) => c.character == card.character).take(3).toList();
    for (final c in zhaoCards) {
      player.hand.remove(c);
    }
    player.melds.add(Meld(
      cards: [...zhaoCards, card],
      type: MeldType.zhao,
      isJing: card.isJing,
    ));
    HuCalculator.updateMeldHuCache(player);
    _addPublicCount(state, card.character, 4);
  }

  /// 碰
  void _handlePeng(Player player, Card card, GameState state) {
    final pengCards = player.hand.where((c) => c.character == card.character).take(2).toList();
    for (final c in pengCards) {
      player.hand.remove(c);
    }
    player.melds.add(Meld(
      cards: [...pengCards, card],
      type: MeldType.kan,
      isJing: card.isJing,
    ));
    HuCalculator.updateMeldHuCache(player);
    _addPublicCount(state, card.character, 3);
  }

  /// 吃
  void _handleChi(Player player, Card card, GameState state) {
    final chiCards = _findChiCards(player, card);
    if (chiCards == null) return;
    for (final c in chiCards) {
      player.hand.remove(c);
    }
    player.melds.add(Meld(
      cards: [...chiCards, card],
      type: MeldType.ju,
      isJing: card.isJing || chiCards.any((c) => c.isJing),
    ));
    HuCalculator.updateMeldHuCache(player);
    _addPublicCount(state, card.character, 1);
    for (final c in chiCards) {
      _addPublicCount(state, c.character, 1);
    }
  }

  /// 找吃的两张牌
  List<Card>? _findChiCards(Player player, Card card) {
    final sameSentence = player.hand.where((c) => c.sentence == card.sentence).toList();
    if (sameSentence.length < 2) return null;

    final positions = <int, Card>{};
    for (final c in sameSentence) {
      positions[c.position] = c;
    }

    final needed1 = (card.position - 1);
    final needed2 = (card.position + 1);
    if (needed1 >= 0 && needed2 <= 2 && positions.containsKey(needed1) && positions.containsKey(needed2)) {
      return [positions[needed1]!, positions[needed2]!];
    }

    final needed3 = (card.position - 2);
    final needed4 = (card.position - 1);
    if (needed3 >= 0 && needed4 >= 0 && positions.containsKey(needed3) && positions.containsKey(needed4)) {
      return [positions[needed3]!, positions[needed4]!];
    }

    final needed5 = (card.position + 1);
    final needed6 = (card.position + 2);
    if (needed5 <= 2 && needed6 <= 2 && positions.containsKey(needed5) && positions.containsKey(needed6)) {
      return [positions[needed5]!, positions[needed6]!];
    }

    return null;
  }

  /// 检查其他玩家响应
  _Response? _checkResponses(List<Player> players, Card card, int discardPlayerId, GameState state) {
    // 按优先级检查：胡>招>碰>吃
    // 人类玩家优先级高于AI玩家

    // 先检查所有玩家的胡
    for (int i = 0; i < 3; i++) {
      if (i == discardPlayerId) continue;
      final player = players[i];
      if (_canHuWith(player, card, state)) {
        if (_aiStrategy.shouldHu(player, card, state, isZimo: false)) {
          return _Response(isHu: true, responderIndex: i);
        }
      }
    }

    // 检查招
    for (int i = 0; i < 3; i++) {
      if (i == discardPlayerId) continue;
      final player = players[i];
      if (_canZhaoWith(player, card)) {
        if (_aiStrategy.shouldZhao(player, card, state)) {
          return _Response(isZhao: true, responderIndex: i);
        }
      }
    }

    // 检查碰
    for (int i = 0; i < 3; i++) {
      if (i == discardPlayerId) continue;
      final player = players[i];
      if (_canPengWith(player, card)) {
        if (_aiStrategy.shouldPeng(player, card, state)) {
          return _Response(isPeng: true, responderIndex: i);
        }
      }
    }

    // 检查吃（只有下家可以吃）
    final nextPlayer = (discardPlayerId + 1) % 3;
    final player = players[nextPlayer];
    if (_canChiWith(player, card, nextPlayer, discardPlayerId)) {
      if (_aiStrategy.shouldChi(player, card, state)) {
        return _Response(isChi: true, responderIndex: nextPlayer);
      }
    }

    return null;
  }

  bool _canHuWith(Player player, Card card, GameState state) {
    if (_getTotalCardCount(player) != _getTargetCardCount(player) - 1) return false;
    // 单钓听限制
    if (player.tingType == TingType.singleWait) {
      final singleCard = player.tingCards.isNotEmpty ? player.tingCards.first : null;
      if (singleCard != null && card.character == singleCard.character) return false;
    }
    final testHand = List<Card>.from(player.hand)..add(card);
    return HuCalculator.canHu(testHand, player.melds, paoCard: card);
  }

  bool _canPengWith(Player player, Card card) {
    if (_getTotalCardCount(player) >= _getTargetCardCount(player)) return false;
    final count = player.hand.where((c) => c.character == card.character).length;
    return count >= 2;
  }

  bool _canZhaoWith(Player player, Card card) {
    if (_getTotalCardCount(player) != _getTargetCardCount(player) - 1) return false;
    final count = player.hand.where((c) => c.character == card.character).length;
    return count >= 3;
  }

  bool _canChiWith(Player player, Card card, int playerIndex, int discardPlayerId) {
    if (_getTotalCardCount(player) >= _getTargetCardCount(player)) return false;
    final isNextPlayer = playerIndex == (discardPlayerId + 1) % 3;
    if (!isNextPlayer) return false;
    return _findChiCards(player, card) != null;
  }

  /// 计算分数（简化版）
  List<int> _calculateScores(List<Player> players, int winnerIndex, bool isZimo, int? dianpaoIndex, HuTypeResult huType) {
    final scores = [0, 0, 0];
    final baseScore = 5;
    final multiplierBase = 2;
    final B = huType.dianpao;

    if (isZimo) {
      // 自摸：赢家 2*(底分+(B+1)*基数)，输家 底分+(B+1)*基数
      final loserScore = baseScore + (B + 1) * multiplierBase;
      final winnerScore = 2 * (baseScore + (B + 1) * multiplierBase);
      for (int i = 0; i < 3; i++) {
        if (i == winnerIndex) {
          scores[i] = winnerScore;
        } else {
          scores[i] = -loserScore;
        }
      }
    } else {
      // 点炮：赢家 底分+B*基数，输家(点炮者) 底分+B*基数
      final change = baseScore + B * multiplierBase;
      scores[winnerIndex] = change;
      if (dianpaoIndex != null) {
        scores[dianpaoIndex] = -change;
      }
    }
    return scores;
  }

  /// 应用分数
  void _applyScores(List<Player> players, List<int> scoreChanges) {
    for (int i = 0; i < 3; i++) {
      players[i].score += scoreChanges[i];
    }
  }

  /// 重建公开牌计数
  void _rebuildPublicCount(GameState state) {
    state.publicCardCount.clear();
    state.totalVisibleCards = 0;
    for (final p in state.players) {
      for (final card in p.discards) {
        state.addPublicCount(card.character, 1);
      }
      for (final meld in p.melds) {
        for (final card in meld.cards) {
          state.addPublicCount(card.character, 1);
        }
      }
    }
  }

  /// 添加公开牌计数
  void _addPublicCount(GameState state, String character, int count) {
    state.addPublicCount(character, count);
  }
}

/// 响应
class _Response {
  final bool isHu;
  final bool isZhao;
  final bool isPeng;
  final bool isChi;
  final int? responderIndex;

  _Response({
    this.isHu = false,
    this.isZhao = false,
    this.isPeng = false,
    this.isChi = false,
    this.responderIndex,
  });
}
