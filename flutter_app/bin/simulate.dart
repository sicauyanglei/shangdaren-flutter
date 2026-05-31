
import 'dart:math';
import '../lib/game/models/card.dart';
import '../lib/game/models/player.dart';
import '../lib/game/models/meld.dart';
import '../lib/game/models/game_state.dart';
import '../lib/game/logic/hu_calculator.dart';
import '../lib/game/logic/ting_checker.dart';
import '../lib/game/logic/ai/ai_controller.dart';
import '../lib/game/logic/ai/ai_strategy_hard.dart';
import '../lib/game/logic/ai/ai_strategy_simple.dart';

/// 纯逻辑麻将模拟器 - 无UI依赖，同步执行
class MahjongSimulator {
  final GameState state = GameState();
  late final AIController aiHard;
  late final AIController aiSimple;
  final Random _rng = Random();

  // 统计
  int totalGames = 0;
  int liujuCount = 0;
  final Map<int, int> hardWinCount = {}; // hard策略AI的胡牌次数
  final Map<int, int> simpleWinCount = {}; // simple策略AI的胡牌次数
  final Map<int, int> totalHuCount = {}; // 每个玩家的胡牌总次数
  final Map<int, int> zimoCount = {}; // 自摸次数
  final Map<int, int> dianpaoCount = {}; // 点炮次数

  MahjongSimulator() {
    aiHard = AIController(strategy: AIStrategyHard());
    aiSimple = AIController();
  }

  /// 模拟一局游戏
  /// player0: hard AI, player1: simple AI, player2: simple AI
  void simulateOneGame() {
    // 初始化
    state.roundNumber = 0;
    state.dealerIndex = 0;
    state.gameStarted = true;
    state.publicCardCount.clear();
    state.totalVisibleCards = 0;

    state.players.clear();
    state.players.addAll([
      Player(id: 0, name: 'HardAI', type: PlayerType.ai),
      Player(id: 1, name: 'SimpleAI1', type: PlayerType.ai),
      Player(id: 2, name: 'SimpleAI2', type: PlayerType.ai),
    ]);

    // 发牌
    state.deck = Card.createDeck();
    state.deck.shuffle(Random(_rng.nextInt(100000)));

    for (final player in state.players) {
      player.hand.clear();
      player.melds.clear();
      player.discards.clear();
      player.isTing = false;
      player.tingCards.clear();
    }

    // 庄家20张，其他19张
    for (int i = 0; i < 19; i++) {
      for (final player in state.players) {
        if (state.deck.isNotEmpty) {
          player.hand.add(state.deck.removeLast());
        }
      }
    }
    // 庄家多1张
    if (state.deck.isNotEmpty) {
      state.players[state.dealerIndex].hand.add(state.deck.removeLast());
    }

    for (final player in state.players) {
      player.sortHand();
    }

    // 重建公开牌计数
    _rebuildPublicCardCount();

    // 开始游戏循环
    state.currentPlayerIndex = state.dealerIndex;
    bool needDraw = false; // 当前玩家是否需要摸牌
    int maxIterations = 500; // 防止无限循环
    int iterations = 0;

    while (state.deck.isNotEmpty && iterations < maxIterations) {
      iterations++;
      var player = state.players[state.currentPlayerIndex];

      // 摸牌（庄家首回合不摸，碰/招/吃后不摸直接出牌）
      if (needDraw && state.deck.isNotEmpty) {
        final drawnCard = state.deck.removeLast();
        player.addCard(drawnCard);

        // 更新听牌状态
        final tingResult0 = TingChecker.checkTing(player);
        player.isTing = tingResult0.isTing;
        player.tingCards = tingResult0.tingCards;
      }
      needDraw = true; // 下次循环默认需要摸牌

      // 重新获取player引用（addCard可能改变状态）
      player = state.players[state.currentPlayerIndex];

      // 检查自摸
      if (_canZimo(player)) {
        _recordWin(state.currentPlayerIndex, true);
        return;
      }

      // 检查招（手牌中4张同字）
      final zhaoCandidates = _getZhaoCandidates(player);
      if (zhaoCandidates.isNotEmpty) {
        final shouldZhao = _getAIController(state.currentPlayerIndex)
            .shouldZhaoFromHand(player, zhaoCandidates.first, state);
        if (shouldZhao) {
          _handleZhaoFromHand(player, zhaoCandidates.first);
          // 招后继续当前玩家出牌（不摸牌）
          needDraw = false;
          continue;
        }
      }

      // 出牌
      final controller = _getAIController(state.currentPlayerIndex);
      final cardToDiscard = controller.selectDiscard(player, state);
      player.removeCard(cardToDiscard);
      player.discards.add(cardToDiscard);
      state.addPublicCount(cardToDiscard.character, 1);

      // 更新听牌状态
      final tingResult = TingChecker.checkTing(player);
      player.isTing = tingResult.isTing;
      player.tingCards = tingResult.tingCards;

      // 检查其他玩家是否可以胡/碰/招/吃
      bool handled = false;

      // 优先检查胡
      for (int i = 0; i < state.players.length; i++) {
        if (i == state.currentPlayerIndex) continue;
        final other = state.players[i];
        if (_canHuWith(other, cardToDiscard) && other.isTing) {
          _recordWin(i, false);
          return;
        }
      }

      // 检查招
      for (int i = 0; i < state.players.length; i++) {
        if (i == state.currentPlayerIndex) continue;
        final other = state.players[i];
        if (_canZhaoWith(other, cardToDiscard)) {
          final shouldZhao = _getAIController(i)
              .shouldZhao(other, cardToDiscard, state);
          if (shouldZhao) {
            _handleZhaoRespond(i, cardToDiscard, state.currentPlayerIndex);
            state.currentPlayerIndex = i;
            handled = true;
            break;
          }
        }
      }

      // 检查碰
      if (!handled) {
        for (int i = 0; i < state.players.length; i++) {
          if (i == state.currentPlayerIndex) continue;
          final other = state.players[i];
          if (_canPengWith(other, cardToDiscard)) {
            final shouldPeng = _getAIController(i)
                .shouldPeng(other, cardToDiscard, state);
            if (shouldPeng) {
              _handlePeng(i, cardToDiscard, state.currentPlayerIndex);
              state.currentPlayerIndex = i;
              handled = true;
              break;
            }
          }
        }
      }

      // 检查吃（只有下家可以吃）
      if (!handled) {
        final nextPlayerIndex = (state.currentPlayerIndex + 1) % 3;
        final nextPlayer = state.players[nextPlayerIndex];
        final chiCards = _findChiCards(nextPlayer, cardToDiscard);
        if (chiCards != null) {
          final shouldChi = _getAIController(nextPlayerIndex)
              .shouldChi(nextPlayer, cardToDiscard, state);
          if (shouldChi) {
            _handleChi(nextPlayerIndex, cardToDiscard, state.currentPlayerIndex);
            state.currentPlayerIndex = nextPlayerIndex;
            handled = true;
          }
        }
      }

      if (handled) {
        // 碰/招/吃后，当前玩家直接出牌，不摸牌
        needDraw = false;
      } else {
        // 正常轮转，下一个玩家摸牌后出牌
        state.currentPlayerIndex = (state.currentPlayerIndex + 1) % 3;
        needDraw = true;
      }
    }

    // 流局
    liujuCount++;
  }

  AIController _getAIController(int playerIndex) {
    // player0 使用 hard 策略，其他使用 simple 策略
    return playerIndex == 0 ? aiHard : aiSimple;
  }

  bool _canZimo(Player player) {
    if (player.hand.isEmpty) return false;
    return HuCalculator.canHu(player.hand, player.melds);
  }

  bool _canHuWith(Player player, Card card) {
    final testHand = List<Card>.from(player.hand)..add(card);
    return HuCalculator.canHu(testHand, player.melds);
  }

  bool _canPengWith(Player player, Card card) {
    final count = player.hand.where((c) => c.character == card.character).length;
    return count >= 2;
  }

  bool _canZhaoWith(Player player, Card card) {
    final count = player.hand.where((c) => c.character == card.character).length;
    return count >= 3;
  }

  List<String> _getZhaoCandidates(Player player) {
    final byChar = <String, int>{};
    for (final card in player.hand) {
      byChar[card.character] = (byChar[card.character] ?? 0) + 1;
    }
    return byChar.entries.where((e) => e.value == 4).map((e) => e.key).toList();
  }

  List<Card>? _findChiCards(Player player, Card card) {
    final sameSentence = player.hand
        .where((c) => c.sentence == card.sentence)
        .toList();
    if (sameSentence.length < 2) return null;

    final positions = <int, Card>{};
    for (final c in sameSentence) {
      positions[c.position] = c;
    }

    final needed1 = (card.position - 1);
    final needed2 = (card.position + 1);
    if (needed1 >= 0 &&
        needed2 <= 2 &&
        positions.containsKey(needed1) &&
        positions.containsKey(needed2)) {
      return [positions[needed1]!, positions[needed2]!];
    }

    final needed3 = (card.position - 2);
    final needed4 = (card.position - 1);
    if (needed3 >= 0 &&
        needed4 >= 0 &&
        positions.containsKey(needed3) &&
        positions.containsKey(needed4)) {
      return [positions[needed3]!, positions[needed4]!];
    }

    final needed5 = (card.position + 1);
    final needed6 = (card.position + 2);
    if (needed5 <= 2 &&
        needed6 <= 2 &&
        positions.containsKey(needed5) &&
        positions.containsKey(needed6)) {
      return [positions[needed5]!, positions[needed6]!];
    }

    return null;
  }

  void _handleZhaoFromHand(Player player, String character) {
    final zhaoCards = player.hand
        .where((c) => c.character == character)
        .take(4)
        .toList();
    if (zhaoCards.length < 4) return;

    final meld = Meld(
      cards: List.from(zhaoCards),
      type: MeldType.zhao,
      isJing: zhaoCards.first.isJing,
    );
    player.melds.add(meld);
    for (final c in zhaoCards) {
      player.hand.remove(c);
    }
    state.addPublicCount(character, 4);

    // 招后摸牌
    if (state.deck.isNotEmpty) {
      final drawnCard = state.deck.removeLast();
      player.addCard(drawnCard);
      final tingResult = TingChecker.checkTing(player);
      player.isTing = tingResult.isTing;
      player.tingCards = tingResult.tingCards;
    }
  }

  void _handleZhaoRespond(int playerIndex, Card card, int discardPlayerId) {
    final player = state.players[playerIndex];
    final discarder = state.players[discardPlayerId];

    // 检查是否有已有的刻可以补招
    final existingKan = player.melds
        .where((m) =>
            m.type == MeldType.kan && m.cards.first.character == card.character)
        .toList();

    // 从弃牌中移除
    discarder.discards.remove(card);
    state.removePublicCount(card.character, 1);

    if (existingKan.isNotEmpty) {
      final oldMeld = existingKan.first;
      player.melds.remove(oldMeld);
      state.removePublicCount(card.character, 3);
      final newCards = List<Card>.from(oldMeld.cards)..add(card);
      player.melds.add(
        Meld(cards: newCards, type: MeldType.zhao, isJing: card.isJing),
      );
      state.addPublicCount(card.character, 4);
    } else {
      final handMatching = player.hand
          .where((c) => c.character == card.character)
          .toList();
      if (handMatching.length >= 3) {
        final zhaoCards = [card, ...handMatching.sublist(0, 3)];
        for (final c in handMatching.sublist(0, 3)) {
          player.hand.remove(c);
        }
        player.melds.add(
          Meld(cards: List.from(zhaoCards), type: MeldType.zhao, isJing: card.isJing),
        );
        state.addPublicCount(card.character, 4);
      }
    }

    // 招后摸牌
    if (state.deck.isNotEmpty) {
      final drawnCard = state.deck.removeLast();
      player.addCard(drawnCard);
      final tingResult = TingChecker.checkTing(player);
      player.isTing = tingResult.isTing;
      player.tingCards = tingResult.tingCards;
    }
  }

  void _handlePeng(int playerIndex, Card card, int discardPlayerId) {
    final player = state.players[playerIndex];
    final discarder = state.players[discardPlayerId];

    final matching = player.hand
        .where((c) => c.character == card.character)
        .toList();
    if (matching.length < 2) return;

    final pengCards = [card, matching[0], matching[1]];

    discarder.discards.remove(card);
    state.removePublicCount(card.character, 1);

    player.melds.add(
      Meld(cards: pengCards, type: MeldType.kan, isJing: card.isJing),
    );
    state.addPublicCount(matching[0].character, 1);
    state.addPublicCount(matching[1].character, 1);
    player.hand.remove(matching[0]);
    player.hand.remove(matching[1]);

    player.huCount = HuCalculator.calculateTotalHu(player);
  }

  void _handleChi(int playerIndex, Card card, int discardPlayerId) {
    final player = state.players[playerIndex];
    final discarder = state.players[discardPlayerId];

    final chiCards = _findChiCards(player, card);
    if (chiCards == null) return;

    final meldCards = [card, chiCards[0], chiCards[1]];

    discarder.discards.remove(card);
    state.removePublicCount(card.character, 1);

    player.melds.add(
      Meld(
        cards: meldCards,
        type: MeldType.ju,
        isJing: meldCards.any((c) => c.isJing),
      ),
    );
    state.addPublicCount(chiCards[0].character, 1);
    state.addPublicCount(chiCards[1].character, 1);
    player.hand.remove(chiCards[0]);
    player.hand.remove(chiCards[1]);

    player.huCount = HuCalculator.calculateTotalHu(player);
  }

  void _recordWin(int winnerIndex, bool isZimo) {
    totalGames++;
    totalHuCount[winnerIndex] = (totalHuCount[winnerIndex] ?? 0) + 1;
    if (isZimo) {
      zimoCount[winnerIndex] = (zimoCount[winnerIndex] ?? 0) + 1;
    } else {
      dianpaoCount[winnerIndex] = (dianpaoCount[winnerIndex] ?? 0) + 1;
    }
  }

  void _rebuildPublicCardCount() {
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

  void printResults() {
    print('\n========== 模拟结果 ==========');
    print('总局数: $totalGames');
    print('流局数: $liujuCount');
    print('');

    for (int i = 0; i < 3; i++) {
      final name = state.players[i].name;
      final wins = totalHuCount[i] ?? 0;
      final zimo = zimoCount[i] ?? 0;
      final dianpao = dianpaoCount[i] ?? 0;
      final winRate = totalGames > 0 ? (wins / totalGames * 100).toStringAsFixed(1) : '0.0';
      print('$name: 胡牌$wins局 ($winRate%), 自摸$zimo, 点炮$dianpao');
    }

    final hardWins = totalHuCount[0] ?? 0;
    final simpleWins1 = totalHuCount[1] ?? 0;
    final simpleWins2 = totalHuCount[2] ?? 0;
    final totalSimpleWins = simpleWins1 + simpleWins2;
    final hardRate = totalGames > 0 ? hardWins / totalGames * 100 : 0.0;
    final simpleAvgRate = totalGames > 0 ? totalSimpleWins / 2 / totalGames * 100 : 0.0;
    print('');
    print('HardAI胜率: ${hardRate.toStringAsFixed(1)}%');
    print('SimpleAI平均胜率: ${simpleAvgRate.toStringAsFixed(1)}%');
    print('HardAI相对提升: ${simpleAvgRate > 0 ? ((hardRate - simpleAvgRate) / simpleAvgRate * 100).toStringAsFixed(1) : "N/A"}%');
  }
}

void main() {
  final simulator = MahjongSimulator();
  final gameCount = 1000;

  print('开始模拟 $gameCount 局 (HardAI vs 2x SimpleAI)...');
  final startTime = DateTime.now();

  for (int i = 0; i < gameCount; i++) {
    simulator.simulateOneGame();
    if ((i + 1) % 100 == 0) {
      final elapsed = DateTime.now().difference(startTime).inSeconds;
      final hardWins = simulator.totalHuCount[0] ?? 0;
      final rate = (i + 1) > 0 ? hardWins / (i + 1) * 100 : 0.0;
      print('  已完成 ${i + 1} 局, HardAI胜率: ${rate.toStringAsFixed(1)}%, 耗时: ${elapsed}s');
    }
  }

  simulator.printResults();

  final totalTime = DateTime.now().difference(startTime).inSeconds;
  print('\n总耗时: ${totalTime}s');
}
