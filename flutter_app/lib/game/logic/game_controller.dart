import 'dart:async';
import 'dart:math';
import '../models/card.dart';
import '../models/meld.dart';
import '../models/player.dart';
import '../models/game_state.dart';
import '../core/audio_manager.dart';
import 'hu_calculator.dart';
import 'ting_checker.dart';
import 'score_calculator.dart';
import 'ai/ai_controller.dart';
import 'ai/ai_strategy_hard.dart';

typedef VoidCallback = void Function();
typedef IntCallback = void Function(int);
typedef CardCallback = void Function(Card);
typedef CardsCallback = void Function(List<Card>, int playerId);
typedef CardAnimCallback =
    void Function(Card card, int playerId, String animType);
typedef MeldAnimCallback =
    void Function(List<Card> cards, int playerId, String meldType);

class GameController {
  final GameState state;
  AIController aiController;
  final Random _rng = Random();

  VoidCallback? onStateChanged;
  VoidCallback? onRoundEnd;
  IntCallback? onPlayerDraw;
  CardCallback? onPlayerDiscard;
  CardsCallback? onPlayerMeld;
  VoidCallback? onShowHu;
  VoidCallback? onShowSettlement;
  VoidCallback? onLiuju;
  CardAnimCallback? onCardAnimation;
  MeldAnimCallback? onMeldAnimation;

  final AudioManager _audio = AudioManager();

  Timer? _countdownTimer;
  int _countdownTimerId = 0;
  Card? _lastDrawnCard;

  bool _hasDealerPlayedFirstTurn = false;
  bool _skipDraw = false;
  bool _isStartingRound = false;
  bool _isDealing = false;
  bool _isPaused = false;

  Map<int, List<String>>? _pendingAIResponses;
  Card? _pendingResponseCard;
  int? _pendingResponseDiscardPlayerId;

  GameController({GameState? gameState, AIController? aiCtrl})
    : state = gameState ?? GameState(),
      aiController = aiCtrl ?? AIController();

  void startGame() {
    state.reset();
    if (state.difficulty == 'hard') {
      aiController = AIController(strategy: AIStrategyHard());
    } else {
      aiController = AIController();
    }
    state.players.addAll([
      Player(id: 0, name: '玩家1', type: PlayerType.ai),
      Player(id: 1, name: '我', type: PlayerType.human),
      Player(id: 2, name: '玩家2', type: PlayerType.ai),
    ]);
    state.dealerIndex = 0;
    state.roundNumber = 0;
    state.gameStarted = true;
    startRound();
  }

  void startRound() {
    if (_isStartingRound) return;
    _isStartingRound = true;

    state.roundNumber++;
    if (state.roundNumber > 8) {
      onShowSettlement?.call();
      _isStartingRound = false;
      return;
    }

    state.isHandlingHu = false;
    state.canChi = false;
    state.canPeng = false;
    state.canZhao = false;
    state.canHu = false;
    state.isMyTurn = false;
    state.isDrawing = false;
    state.waitingForResponse = false;
    state.isDealingComplete = false;
    state.isDiscarding = false;
    state.isClosingHuMessage = false;
    state.showHuResult = false;
    state.showLiujuResult = false;
    state.showZhaoSelection = false;
    state.lastDiscardedCard = null;
    state.lastDiscardPlayerIndex = null;
    _hasDealerPlayedFirstTurn = false;
    _skipDraw = false;
    _lastDrawnCard = null;

    state.deck = Card.createDeck();
    state.deck.shuffle();

    for (final player in state.players) {
      player.hand.clear();
      player.melds.clear();
      player.discards.clear();
      player.isTing = false;
      player.tingCards.clear();
      player.piao = 0;
    }

    state.currentPlayerIndex = state.dealerIndex;
    onStateChanged?.call();

    // 进入飘分阶段或直接发牌
    _showPiaoScreen();
  }

  void _showPiaoScreen() {
    if (!state.piaoEnabled) {
      // 飘分关闭，直接发牌
      for (final player in state.players) {
        player.piao = 0;
      }
      _startDealing();
      return;
    }

    // 初始化飘分阶段
    state.isPiaoPhase = true;
    state.piaoCurrentPlayerIndex = state.dealerIndex;
    state.piaoSetCount = 0;

    // AI玩家自动设置飘分
    _processAIPiao();
    onStateChanged?.call();
  }

  void _processAIPiao() {
    // 先处理当前飘分玩家中的AI
    while (state.piaoSetCount < 3) {
      final player = state.players[state.piaoCurrentPlayerIndex];
      if (player.type == PlayerType.ai) {
        // AI随机选择飘分
        final piaoOptions = [0, 5, 10, 20];
        final randomIndex = Random().nextInt(piaoOptions.length);
        player.piao = piaoOptions[randomIndex];
        state.piaoSetCount++;
        state.piaoCurrentPlayerIndex = (state.piaoCurrentPlayerIndex + 1) % 3;
      } else {
        // 人类玩家，等待UI输入
        break;
      }
    }

    if (state.piaoSetCount >= 3) {
      // 所有玩家已设置飘分，开始发牌
      state.isPiaoPhase = false;
      _startDealing();
      return;
    }

    onStateChanged?.call();
  }

  void setPiao(int piaoValue) {
    if (!state.isPiaoPhase) return;

    final player = state.players[state.piaoCurrentPlayerIndex];
    if (player.type != PlayerType.human) return;

    player.piao = piaoValue;
    state.piaoSetCount++;
    state.piaoCurrentPlayerIndex = (state.piaoCurrentPlayerIndex + 1) % 3;

    // 继续处理AI飘分
    _processAIPiao();
  }

  void _startDealing() {
    state.isPiaoPhase = false;
    _dealCardsAnimated();
  }

  void _dealCardsAnimated() {
    _isDealing = true;
    // 注意：deck已在startRound中创建和洗牌，这里不再重新创建
    // 飘分已在startRound的_showPiaoScreen中设置，不应重置

    for (final player in state.players) {
      player.hand.clear();
      player.melds.clear();
      player.discards.clear();
      player.isTing = false;
      player.tingCards.clear();
      // piao不重置，保留飘分设置
    }

    final totalDealerCards = 20;
    final totalOtherCards = 19;
    final dealSequence = <MapEntry<int, int>>[];

    for (var i = 0; i < totalOtherCards; i++) {
      for (final player in state.players) {
        dealSequence.add(MapEntry(player.id, i * 3 + player.id));
      }
    }
    final dealer = state.players[state.dealerIndex];
    dealSequence.add(MapEntry(dealer.id, totalOtherCards * 3));

    int dealIdx = 0;
    void dealNext() {
      if (dealIdx >= dealSequence.length) {
        _isDealing = false;
        state.isDealingComplete = true;
        _rebuildPublicCardCount();
        for (final player in state.players) {
          player.sortHand();
          if (player.type == PlayerType.human) {
            player.huCount = HuCalculator.calculateTotalHu(player);
          }
        }
        onStateChanged?.call();
        Future.delayed(const Duration(milliseconds: 300), () {
          if (_isPaused || !state.gameStarted) return;
          _isStartingRound = false;
          _startTurn();
        });
        return;
      }

      final entry = dealSequence[dealIdx];
      final player = state.players[entry.key];
      if (state.deck.isNotEmpty) {
        final card = state.deck.removeLast();
        player.hand.add(card);
        onCardAnimation?.call(card, entry.key, 'deal');
      }
      onStateChanged?.call();

      dealIdx++;
      Future.delayed(const Duration(milliseconds: 30), () {
        if (_isPaused || !state.gameStarted) return;
        dealNext();
      });
    }

    dealNext();
  }

  void _startTurn() {
    if (state.deck.isEmpty && !_skipDraw) {
      _handleLiuju();
      return;
    }

    final player = state.currentTurnPlayer();

    if (player.type == PlayerType.ai) {
      state.isMyTurn = false;
      final delay = 800 + _rng.nextInt(500);
      Future.delayed(Duration(milliseconds: delay), () {
        if (_isPaused || !state.gameStarted) return;
        _processAITurn(player);
      });
    } else {
      if (_skipDraw) {
        _skipDraw = false;
        state.isMyTurn = true;
        state.isDrawing = false;
        _checkMyActionsAfterDraw();
        onStateChanged?.call();
        startCountdown();
      } else if (!_hasDealerPlayedFirstTurn &&
          state.currentPlayerIndex == state.dealerIndex) {
        _hasDealerPlayedFirstTurn = true;
        state.isMyTurn = true;
        state.isDrawing = false;
        _checkMyActionsAfterDraw();
        onStateChanged?.call();
        startCountdown();
      } else {
        _drawCardForHuman();
      }
    }
  }

  void _drawCardForHuman() {
    if (state.deck.isEmpty) {
      _handleLiuju();
      return;
    }
    state.isDrawing = true;
    state.isMyTurn = false;

    final card = state.deck.removeLast();
    _lastDrawnCard = card;
    final player = state.players[1];

    onCardAnimation?.call(card, 1, 'draw');

    state.hideTingBadge = true;
    onStateChanged?.call();

    Future.delayed(const Duration(milliseconds: 2100), () {
      if (_isPaused || !state.gameStarted) return;
      player.addCard(card);
      onPlayerDraw?.call(1);

      final tingResult = TingChecker.checkTing(player);
      player.isTing = tingResult.isTing;
      player.tingCards = tingResult.tingCards;
      player.huCount = HuCalculator.calculateTotalHu(player);

      state.isDrawing = false;
      state.isMyTurn = true;

      _checkMyActionsAfterDraw();
      state.hideTingBadge = state.canHu;

      onStateChanged?.call();
      startCountdown();
    });
  }

  void _checkMyActionsAfterDraw() {
    final player = state.players[1];
    state.canHu = _canZimo(player);
    state.isZimoOpportunity = state.canHu;
    state.canZhao = _canZhaoAfterDraw(player) && !state.canHu;
  }

  void _processAITurn(Player player) {
    if (state.deck.isEmpty) {
      _handleLiuju();
      return;
    }

    if (_skipDraw) {
      _skipDraw = false;
      _aiContinueAfterDraw(player);
      return;
    }

    if (!_hasDealerPlayedFirstTurn &&
        state.currentPlayerIndex == state.dealerIndex) {
      _hasDealerPlayedFirstTurn = true;
      _aiContinueAfterDraw(player);
      return;
    }

    final card = state.deck.removeLast();

    onCardAnimation?.call(card, player.id, 'draw');

    Future.delayed(const Duration(milliseconds: 2100), () {
      if (_isPaused || !state.gameStarted) return;
      player.addCard(card);
      onPlayerDraw?.call(player.id);

      final tingResult = TingChecker.checkTing(player);
      player.isTing = tingResult.isTing;
      player.tingCards = tingResult.tingCards;
      player.huCount = HuCalculator.calculateTotalHu(player);

      _aiContinueAfterDraw(player, drawnCard: card);
    });
  }

  void _aiContinueAfterDraw(Player player, {Card? drawnCard}) {
    if (_canZimo(player)) {
      _handleHu(player.id, isZimo: true, zimoCard: drawnCard);
      return;
    }

    if (_canZhaoAfterDraw(player)) {
      final candidates = _getZhaoCandidates(player);
      bool shouldZhao = true;
      for (final ch in candidates) {
        if (!aiController.shouldZhaoFromHand(player, ch, state)) {
          shouldZhao = false;
          break;
        }
      }
      if (shouldZhao) {
        _handleZhaoFromHand(player);
        return;
      }
    }

    final card = aiController.selectDiscard(player, state);
    _doDiscard(player, card);
  }

  void discardCard(int cardIndex) {
    final player = state.currentTurnPlayer();
    if (player.type != PlayerType.human) return;
    if (cardIndex < 0 || cardIndex >= player.hand.length) return;
    if (!state.isMyTurn) return;
    if (state.isDrawing) return;
    if (state.canChi || state.canPeng || state.canZhao || state.canHu) return;

    final card = player.hand[cardIndex];
    state.canChi = false;
    state.canPeng = false;
    state.canZhao = false;
    state.canHu = false;
    state.isDrawing = false;
    stopCountdown();
    _doDiscard(player, card);
  }

  void _doDiscard(Player player, Card card) {
    _skipDraw = false;
    stopCountdown();
    onCardAnimation?.call(card, player.id, 'discard');
    _audio.playDiscard(card.character);

    Future.delayed(const Duration(milliseconds: 350), () {
      if (_isPaused || !state.gameStarted) return;
      player.removeCard(card);
      player.discards.add(card);
      _addToPublicCount(card.character, 1);
      state.lastDiscardedCard = card;
      state.lastDiscardPlayerIndex = player.id;
      state.isMyTurn = false;

      final tingResult = TingChecker.checkTing(player);
      player.isTing = tingResult.isTing;
      player.tingCards = tingResult.tingCards;
      player.huCount = HuCalculator.calculateTotalHu(player);

      if (player.type == PlayerType.human) {
        state.hideTingBadge = !player.isTing;
      }

      onPlayerDiscard?.call(card);
      onStateChanged?.call();

      Future.delayed(const Duration(milliseconds: 800), () {
        if (_isPaused || !state.gameStarted) return;
        _checkResponses(card, player.id);
      });
    });
  }

  void _checkResponses(Card card, int discardPlayerId) {
    final responses = <int, List<String>>{};

    for (int i = 0; i < state.players.length; i++) {
      if (i == discardPlayerId) continue;
      final p = state.players[i];
      final actions = <String>[];

      if (_canHuWith(p, card) && p.isTing) {
        actions.add('hu');
      }
      if (_canZhaoWith(p, card)) {
        actions.add('zhao');
      }
      if (_canPengWith(p, card)) {
        actions.add('peng');
      }
      if (_canChiWith(p, i, card, discardPlayerId)) {
        if (p.type == PlayerType.ai && state.difficulty == 'hard') {
          if (!_shouldChiHard(p, card)) {
            responses[i] = actions;
            continue;
          }
        }
        actions.add('chi');
      }
      responses[i] = actions;
    }

    _processResponses(responses, card, discardPlayerId);
  }

  bool _shouldChiHard(Player player, Card card) {
    final sameSentence = player.hand
        .where((c) => c.sentence == card.sentence)
        .toList();

    final charCount = <String, int>{};
    for (final c in sameSentence) {
      charCount[c.character] = (charCount[c.character] ?? 0) + 1;
    }

    final allSingle = charCount.values.every((count) => count == 1);
    if (!allSingle) return true;

    final hasFullSentence = charCount.length == 3;
    if (!hasFullSentence) return true;

    return false;
  }

  void _processResponses(
    Map<int, List<String>> responses,
    Card card,
    int discardPlayerId,
  ) {
    final priorityOrder = ['hu', 'zhao', 'peng', 'chi'];

    final humanResponses = <String>[];
    final deferredAI = <int, List<String>>{};

    for (final action in priorityOrder) {
      final respondents = responses.entries
          .where((e) => e.value.contains(action))
          .map((e) => e.key)
          .toList();

      if (respondents.isEmpty) continue;

      final humanRespondent = respondents
          .where((i) => state.players[i].type == PlayerType.human)
          .toList();

      if (action == 'hu') {
        if (humanRespondent.isNotEmpty) {
          humanResponses.add('hu');
          for (final r in respondents) {
            if (state.players[r].type == PlayerType.ai) {
              deferredAI.putIfAbsent(r, () => []).add('hu');
            }
          }
          continue;
        }
        _handleHu(
          respondents.first,
          isZimo: false,
          dianpaoIndex: discardPlayerId,
        );
        return;
      }

      if (action == 'zhao') {
        if (humanRespondent.isNotEmpty) {
          humanResponses.add('zhao');
          for (final r in respondents) {
            if (state.players[r].type == PlayerType.ai) {
              deferredAI.putIfAbsent(r, () => []).add('zhao');
            }
          }
          continue;
        }
        if (humanResponses.isNotEmpty) {
          for (final r in respondents) {
            if (state.players[r].type == PlayerType.ai) {
              deferredAI.putIfAbsent(r, () => []).add('zhao');
            }
          }
          continue;
        }
        _handleZhaoRespond(respondents.first, card, discardPlayerId);
        return;
      }

      if (action == 'peng') {
        if (humanRespondent.isNotEmpty) {
          humanResponses.add('peng');
          for (final r in respondents) {
            if (state.players[r].type == PlayerType.ai) {
              deferredAI.putIfAbsent(r, () => []).add('peng');
            }
          }
          continue;
        }
        if (humanResponses.isNotEmpty) {
          for (final r in respondents) {
            if (state.players[r].type == PlayerType.ai) {
              deferredAI.putIfAbsent(r, () => []).add('peng');
            }
          }
          continue;
        }
        _handlePeng(respondents.first, card, discardPlayerId);
        return;
      }

      if (action == 'chi') {
        final nextPlayerIndex = (discardPlayerId + 1) % 3;
        if (respondents.contains(nextPlayerIndex)) {
          final p = state.players[nextPlayerIndex];
          if (p.type == PlayerType.human) {
            humanResponses.add('chi');
            continue;
          }
          if (humanResponses.isNotEmpty) {
            deferredAI.putIfAbsent(nextPlayerIndex, () => []).add('chi');
            continue;
          }
          _handleChi(nextPlayerIndex, card, discardPlayerId);
          return;
        }
      }
    }

    if (humanResponses.isEmpty) {
      _nextTurn();
      return;
    }

    _pendingAIResponses = deferredAI.isNotEmpty ? deferredAI : null;
    _pendingResponseCard = card;
    _pendingResponseDiscardPlayerId = discardPlayerId;

    for (final action in humanResponses) {
      if (action == 'hu') {
        state.canHu = true;
        state.isZimoOpportunity = false;
      }
      if (action == 'zhao') state.canZhao = true;
      if (action == 'peng') state.canPeng = true;
      if (action == 'chi') state.canChi = true;
    }
    state.waitingForResponse = true;
    state.isMyTurn = true;
    onStateChanged?.call();
    startCountdown();
  }

  void respondHu() {
    final humanIndex = state.players.indexWhere(
      (p) => p.type == PlayerType.human,
    );
    if (humanIndex < 0) return;
    stopCountdown();
    final isZimo = !state.waitingForResponse;
    state.canChi = false;
    state.canPeng = false;
    state.canZhao = false;
    state.canHu = false;
    state.waitingForResponse = false;
    _clearPendingAIResponses();
    onStateChanged?.call();
    _handleHu(
      humanIndex,
      isZimo: isZimo,
      dianpaoIndex: isZimo ? null : state.lastDiscardPlayerIndex,
      zimoCard: isZimo ? _lastDrawnCard : null,
    );
  }

  void respondZhao() {
    final humanIndex = state.players.indexWhere(
      (p) => p.type == PlayerType.human,
    );
    if (humanIndex < 0) return;
    stopCountdown();
    state.canChi = false;
    state.canPeng = false;
    state.canZhao = false;
    state.canHu = false;
    _clearPendingAIResponses();
    onStateChanged?.call();

    if (state.waitingForResponse) {
      state.waitingForResponse = false;
      if (humanIndex == 1) {
        state.hideTingBadge = true;
      }
      _handleZhaoRespond(
        humanIndex,
        state.lastDiscardedCard!,
        state.lastDiscardPlayerIndex!,
      );
    } else {
      state.canZhao = false;
      final player = state.players[humanIndex];
      final candidates = _getZhaoCandidates(player);
      if (candidates.isEmpty) return;
      if (candidates.length == 1) {
        _handleZhaoFromHand(player, character: candidates.first);
      } else {
        state.zhaoCandidates = candidates;
        state.showZhaoSelection = true;
        onStateChanged?.call();
      }
    }
  }

  void selectZhaoCharacter(String character) {
    final humanIndex = state.players.indexWhere(
      (p) => p.type == PlayerType.human,
    );
    if (humanIndex < 0) return;
    state.showZhaoSelection = false;
    state.zhaoCandidates.clear();
    _handleZhaoFromHand(state.players[humanIndex], character: character);
  }

  void respondPeng() {
    final humanIndex = state.players.indexWhere(
      (p) => p.type == PlayerType.human,
    );
    if (humanIndex < 0) return;
    stopCountdown();
    state.canChi = false;
    state.canPeng = false;
    state.canZhao = false;
    state.canHu = false;
    state.waitingForResponse = false;
    _clearPendingAIResponses();
    if (humanIndex == 1) {
      state.hideTingBadge = true;
    }
    onStateChanged?.call();
    _handlePeng(
      humanIndex,
      state.lastDiscardedCard!,
      state.lastDiscardPlayerIndex!,
    );
  }

  void respondChi() {
    final humanIndex = state.players.indexWhere(
      (p) => p.type == PlayerType.human,
    );
    if (humanIndex < 0) return;
    stopCountdown();
    state.canChi = false;
    state.canPeng = false;
    state.canZhao = false;
    state.canHu = false;
    state.waitingForResponse = false;
    _clearPendingAIResponses();
    if (humanIndex == 1) {
      state.hideTingBadge = true;
    }
    onStateChanged?.call();
    _handleChi(
      humanIndex,
      state.lastDiscardedCard!,
      state.lastDiscardPlayerIndex!,
    );
  }

  void respondPass() {
    final wasWaitingForResponse = state.waitingForResponse;
    state.canChi = false;
    state.canPeng = false;
    state.canZhao = false;
    state.canHu = false;
    state.waitingForResponse = false;
    _audio.playGuo();
    stopCountdown();

    if (wasWaitingForResponse) {
      state.isMyTurn = false;
      if (_pendingAIResponses != null && _pendingResponseCard != null) {
        final pending = _pendingAIResponses!;
        final card = _pendingResponseCard!;
        final discardId = _pendingResponseDiscardPlayerId!;
        _pendingAIResponses = null;
        _pendingResponseCard = null;
        _pendingResponseDiscardPlayerId = null;
        _processAIResponses(pending, card, discardId);
      } else {
        onStateChanged?.call();
        _nextTurn();
      }
    } else {
      state.isMyTurn = true;
      onStateChanged?.call();
      startCountdown();
    }
  }

  void _clearPendingAIResponses() {
    _pendingAIResponses = null;
    _pendingResponseCard = null;
    _pendingResponseDiscardPlayerId = null;
  }

  void _processAIResponses(
    Map<int, List<String>> responses,
    Card card,
    int discardPlayerId,
  ) {
    final priorityOrder = ['hu', 'zhao', 'peng', 'chi'];

    for (final action in priorityOrder) {
      final respondents = responses.entries
          .where((e) => e.value.contains(action))
          .map((e) => e.key)
          .toList();

      if (respondents.isEmpty) continue;

      if (action == 'hu') {
        _handleHu(
          respondents.first,
          isZimo: false,
          dianpaoIndex: discardPlayerId,
        );
        return;
      }

      if (action == 'zhao') {
        _handleZhaoRespond(respondents.first, card, discardPlayerId);
        return;
      }

      if (action == 'peng') {
        _handlePeng(respondents.first, card, discardPlayerId);
        return;
      }

      if (action == 'chi') {
        final nextPlayerIndex = (discardPlayerId + 1) % 3;
        if (respondents.contains(nextPlayerIndex)) {
          _handleChi(nextPlayerIndex, card, discardPlayerId);
          return;
        }
      }
    }

    onStateChanged?.call();
    _nextTurn();
  }

  void startCountdown([int seconds = 30]) {
    _countdownTimerId++;
    final myId = _countdownTimerId;
    _countdownTimer?.cancel();
    state.countdown = seconds;
    onStateChanged?.call();

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (myId != _countdownTimerId) {
        timer.cancel();
        return;
      }
      state.countdown--;
      onStateChanged?.call();

      final shouldPlaySound = state.isMyTurn || state.waitingForResponse;
      if (shouldPlaySound) {
        if (state.countdown == 10) {
          _audio.playHurry();
        } else if (state.countdown <= 5 && state.countdown > 0) {
          _audio.play('出牌', volumeMultiplier: 0.3);
        }
      }

      if (state.countdown <= 0) {
        timer.cancel();
        _countdownTimer = null;
        _handleTimeout();
      }
    });
  }

  void stopCountdown() {
    _countdownTimerId++;
    _countdownTimer?.cancel();
    _countdownTimer = null;
    state.countdown = 0;
    onStateChanged?.call();
  }

  void _handleTimeout() {
    if (state.waitingForResponse) {
      respondPass();
    } else if (state.isMyTurn) {
      final player = state.players[1];

      if (_lastDrawnCard != null) {
        final drawnCardIndex = player.hand.indexWhere(
          (c) => c.id == _lastDrawnCard!.id,
        );
        if (drawnCardIndex >= 0) {
          discardCard(drawnCardIndex);
          _lastDrawnCard = null;
          return;
        }
      }

      if (player.hand.isNotEmpty) {
        discardCard(player.hand.length - 1);
      }
    }
  }

  void _nextTurn() {
    state.currentPlayerIndex = (state.currentPlayerIndex + 1) % 3;
    _startTurn();
  }

  void _handleHu(
    int winnerIndex, {
    bool isZimo = false,
    int? dianpaoIndex,
    Card? zimoCard,
  }) {
    state.isHandlingHu = true;
    state.canChi = false;
    state.canPeng = false;
    state.canZhao = false;
    state.canHu = false;
    state.isMyTurn = false;

    final winner = state.players[winnerIndex];

    if (!isZimo && !winner.isTing) {
      return;
    }

    if (!isZimo && dianpaoIndex != null && state.lastDiscardedCard != null) {
      final discarder = state.players[dianpaoIndex];
      discarder.discards.remove(state.lastDiscardedCard);
      _addToPublicCount(state.lastDiscardedCard!.character, -1);
      winner.hand.add(state.lastDiscardedCard!);
    }

    final huTypeResult = HuCalculator.detectHuType(winner);

    if (isZimo) {
      _audio.playZimo();
    } else {
      _audio.playHu();
    }

    if (winner.type == PlayerType.ai) {
      _audio.playHuType(huTypeResult.name, delayMs: 1000);
    } else {
      _audio.playHuType(huTypeResult.name, delayMs: 800);
    }

    final scores = ScoreCalculator.calculateScores(
      state,
      winnerIndex,
      dianpaoIndex,
      isZimo,
      huTypeResult,
    );
    final oldScores = <int, int>{};
    for (final p in state.players) {
      oldScores[p.id] = p.score;
    }
    final scoreChanges = <int>[];
    for (final entry in scores.entries) {
      state.players[entry.key].score += entry.value;
      scoreChanges.add(entry.value);
    }

    final totalHu = HuCalculator.calculateTotalHu(winner);
    final B = totalHu ~/ 10;
    final huTypeMultiplier = isZimo ? huTypeResult.zimo : huTypeResult.dianpao;
    final displayMultiplier = B + huTypeMultiplier;
    final method = isZimo ? '自摸' : '点炮';

    state.roundHistory.add({
      'roundNumber': state.roundNumber,
      'winner': winner.name,
      'winnerIndex': winnerIndex,
      'huType': huTypeResult.name,
      'method': method,
      'multiplier': displayMultiplier,
      'score': scores[winnerIndex] ?? 0,
      'piaoScores': state.players.map((p) => p.piao).toList(),
      'isLiuJu': false,
      'scoreChanges': scoreChanges,
      'huCount': totalHu,
      'dianpaoIndex': dianpaoIndex,
    });

    if (!isZimo && dianpaoIndex != null && winnerIndex != state.dealerIndex) {
      state.dealerIndex = winnerIndex;
    }

    state.isHandlingHu = false;

    state.huResultWinnerName = winner.name;
    state.huResultWinnerIndex = winnerIndex;
    state.huResultMethod = method;
    state.huResultHuType = huTypeResult.name;
    state.huResultHuCount = totalHu;
    state.huResultMultiplier = displayMultiplier;
    state.huResultScore = scores[winnerIndex] ?? 0;
    state.huResultScoreChanges = scores;
    state.huResultOldScores = oldScores;
    state.huResultDianpaoIndex = dianpaoIndex;
    if (!isZimo &&
        dianpaoIndex != null &&
        dianpaoIndex < state.players.length) {
      state.huResultDianpaoName = state.players[dianpaoIndex].name;
      state.huResultDianpaoCard = state.lastDiscardedCard;
      state.huResultZimoCard = null;
    } else {
      state.huResultDianpaoName = null;
      state.huResultDianpaoCard = null;
      state.huResultZimoCard = zimoCard;
    }
    state.showHuResult = true;

    onShowHu?.call();
    onStateChanged?.call();
  }

  void _handleLiuju() {
    _audio.playLiuju();

    state.showLiujuResult = true;

    state.roundHistory.add({
      'roundNumber': state.roundNumber,
      'winner': null,
      'winnerIndex': -1,
      'huType': null,
      'method': null,
      'multiplier': 0,
      'score': 0,
      'piaoScores': state.players.map((p) => p.piao).toList(),
      'isLiuJu': true,
      'scoreChanges': List.filled(state.players.length, 0),
    });

    onLiuju?.call();
    onStateChanged?.call();
  }

  void handleLiujuClose() {
    if (state.roundNumber >= 8) {
      onShowSettlement?.call();
    } else {
      if (!state.gameStarted) return;
      startRound();
    }
  }

  void handleHuClose() {
    if (state.roundNumber >= 8) {
      onShowSettlement?.call();
    } else {
      if (!state.gameStarted) return;
      startRound();
    }
  }

  void pauseGame() {
    _isPaused = true;
    stopCountdown();
  }

  void resumeGame() {
    _isPaused = false;
    if (!state.gameStarted) return;
    if (state.showHuResult || state.showLiujuResult) return;

    if (state.isMyTurn && !state.isDrawing) {
      startCountdown();
    }
  }

  void _handleZhaoFromHand(Player player, {String? character}) {
    final byChar = <String, List<Card>>{};
    for (final card in player.hand) {
      byChar.putIfAbsent(card.character, () => []).add(card);
    }

    String? targetChar = character;
    if (targetChar == null) {
      for (final entry in byChar.entries) {
        if (entry.value.length == 4) {
          targetChar = entry.key;
          break;
        }
      }
    }
    if (targetChar == null) return;

    final zhaoCards = byChar[targetChar]!.sublist(0, 4);

    onMeldAnimation?.call(zhaoCards, player.id, 'zhao');
    _audio.playZhao();

    Future.delayed(const Duration(milliseconds: 1500), () {
      if (_isPaused || !state.gameStarted) return;
      final meld = Meld(
        cards: List.from(zhaoCards),
        type: MeldType.zhao,
        isJing: zhaoCards.first.isJing,
      );
      player.melds.add(meld);
      for (final c in zhaoCards) {
        player.hand.remove(c);
      }
      _addToPublicCount(targetChar!, 4);
      onPlayerMeld?.call(zhaoCards, player.id);
      onStateChanged?.call();

      _drawAfterZhao(player);
    });
  }

  void _drawAfterZhao(Player player) {
    if (state.deck.isEmpty) {
      _handleLiuju();
      return;
    }

    final card = state.deck.removeLast();

    if (player.type == PlayerType.human) {
      state.isDrawing = true;
      state.isMyTurn = false;
      state.hideTingBadge = true;
      onStateChanged?.call();

      onCardAnimation?.call(card, player.id, 'draw');

      Future.delayed(const Duration(milliseconds: 2100), () {
        if (_isPaused || !state.gameStarted) return;
        player.addCard(card);
        onPlayerDraw?.call(player.id);

        final tingResult = TingChecker.checkTing(player);
        player.isTing = tingResult.isTing;
        player.tingCards = tingResult.tingCards;
        player.huCount = HuCalculator.calculateTotalHu(player);

        state.isMyTurn = true;
        state.isDrawing = false;
        _checkMyActionsAfterDraw();
        state.hideTingBadge = state.canHu;
        onStateChanged?.call();
        startCountdown();
      });
    } else {
      player.addCard(card);
      onPlayerDraw?.call(player.id);

      final tingResult = TingChecker.checkTing(player);
      player.isTing = tingResult.isTing;
      player.tingCards = tingResult.tingCards;
      player.huCount = HuCalculator.calculateTotalHu(player);

      final delay = 800 + _rng.nextInt(500);
      Future.delayed(Duration(milliseconds: delay), () {
        if (_isPaused || !state.gameStarted) return;
        _aiContinueAfterDraw(player);
      });
    }
  }

  void _handleZhaoRespond(int playerIndex, Card card, int discardPlayerId) {
    final player = state.players[playerIndex];
    final discarder = state.players[discardPlayerId];

    final existingKan = player.melds
        .where(
          (m) =>
              m.type == MeldType.kan &&
              m.cards.first.character == card.character,
        )
        .toList();

    List<Card> zhaoCards;
    if (existingKan.isNotEmpty) {
      zhaoCards = List<Card>.from(existingKan.first.cards)..add(card);
    } else {
      final handMatching = player.hand
          .where((c) => c.character == card.character)
          .toList();
      zhaoCards = [card, ...handMatching.sublist(0, 3)];
    }

    onMeldAnimation?.call(zhaoCards, playerIndex, 'zhao');
    _audio.playZhao();

    Future.delayed(const Duration(milliseconds: 1500), () {
      if (_isPaused || !state.gameStarted) return;
      discarder.discards.remove(card);
      _addToPublicCount(card.character, -1);

      if (existingKan.isNotEmpty) {
        final oldMeld = existingKan.first;
        player.melds.remove(oldMeld);
        _addToPublicCount(card.character, -3);
        final newCards = List<Card>.from(oldMeld.cards)..add(card);
        player.melds.add(
          Meld(cards: newCards, type: MeldType.zhao, isJing: card.isJing),
        );
        _addToPublicCount(card.character, 4);
        onPlayerMeld?.call(newCards, playerIndex);
      } else {
        for (final c in zhaoCards.skip(1)) {
          player.hand.remove(c);
        }
        player.melds.add(
          Meld(
            cards: List.from(zhaoCards),
            type: MeldType.zhao,
            isJing: card.isJing,
          ),
        );
        _addToPublicCount(card.character, 4);
        onPlayerMeld?.call(zhaoCards, playerIndex);
      }

      state.canChi = false;
      state.canPeng = false;
      state.canZhao = false;
      state.canHu = false;
      state.currentPlayerIndex = playerIndex;
      onStateChanged?.call();

      _drawAfterZhao(player);
    });
  }

  void _handlePeng(int playerIndex, Card card, int discardPlayerId) {
    final player = state.players[playerIndex];

    final matching = player.hand
        .where((c) => c.character == card.character)
        .toList();
    if (matching.length >= 2) {
      final pengCards = [card, matching[0], matching[1]];

      onMeldAnimation?.call(pengCards, playerIndex, 'peng');
      _audio.playPeng();

      Future.delayed(const Duration(milliseconds: 1500), () {
        if (_isPaused || !state.gameStarted) return;
        final discarder = state.players[discardPlayerId];
        discarder.discards.remove(card);
        _addToPublicCount(card.character, -1);

        player.melds.add(
          Meld(cards: pengCards, type: MeldType.kan, isJing: card.isJing),
        );
        _addToPublicCount(matching[0].character, 1);
        _addToPublicCount(matching[1].character, 1);
        player.hand.remove(matching[0]);
        player.hand.remove(matching[1]);
        onPlayerMeld?.call(pengCards, playerIndex);

        state.canChi = false;
        state.canPeng = false;
        state.canZhao = false;
        state.canHu = false;
        state.currentPlayerIndex = playerIndex;
        _skipDraw = true;
        player.huCount = HuCalculator.calculateTotalHu(player);
        onStateChanged?.call();

        if (player.type == PlayerType.human) {
          state.isMyTurn = true;
          state.isDrawing = false;
          onStateChanged?.call();
          startCountdown();
        } else {
          final delay = 800 + _rng.nextInt(500);
          Future.delayed(Duration(milliseconds: delay), () {
            if (_isPaused || !state.gameStarted) return;
            _aiContinueAfterDraw(player);
          });
        }
      });
    }
  }

  void _handleChi(int playerIndex, Card card, int discardPlayerId) {
    final player = state.players[playerIndex];

    final chiCards = _findChiCards(player, card);
    if (chiCards != null) {
      final meldCards = [card, chiCards[0], chiCards[1]];

      onMeldAnimation?.call(meldCards, playerIndex, 'chi');
      _audio.playChi();

      Future.delayed(const Duration(milliseconds: 1500), () {
        if (_isPaused || !state.gameStarted) return;
        final discarder = state.players[discardPlayerId];
        discarder.discards.remove(card);
        _addToPublicCount(card.character, -1);

        player.melds.add(
          Meld(
            cards: meldCards,
            type: MeldType.ju,
            isJing: meldCards.any((c) => c.isJing),
          ),
        );
        _addToPublicCount(chiCards[0].character, 1);
        _addToPublicCount(chiCards[1].character, 1);
        player.hand.remove(chiCards[0]);
        player.hand.remove(chiCards[1]);
        onPlayerMeld?.call(meldCards, playerIndex);

        state.canChi = false;
        state.canPeng = false;
        state.canZhao = false;
        state.canHu = false;
        state.currentPlayerIndex = playerIndex;
        _skipDraw = true;
        player.huCount = HuCalculator.calculateTotalHu(player);
        onStateChanged?.call();

        if (player.type == PlayerType.human) {
          state.isMyTurn = true;
          state.isDrawing = false;
          onStateChanged?.call();
          startCountdown();
        } else {
          final delay = 800 + _rng.nextInt(500);
          Future.delayed(Duration(milliseconds: delay), () {
            if (_isPaused || !state.gameStarted) return;
            _aiContinueAfterDraw(player);
          });
        }
      });
    }
  }

  bool _canZimo(Player player) {
    if (player.hand.isEmpty) return false;
    return HuCalculator.canHu(player.hand, player.melds);
  }

  bool _canZhaoAfterDraw(Player player) {
    return _getZhaoCandidates(player).isNotEmpty;
  }

  List<String> _getZhaoCandidates(Player player) {
    final byChar = <String, int>{};
    for (final card in player.hand) {
      byChar[card.character] = (byChar[card.character] ?? 0) + 1;
    }
    return byChar.entries.where((e) => e.value == 4).map((e) => e.key).toList();
  }

  bool _canHuWith(Player player, Card card) {
    final testHand = List<Card>.from(player.hand)..add(card);
    return HuCalculator.canHu(testHand, player.melds);
  }

  bool _canPengWith(Player player, Card card) {
    final count = player.hand
        .where((c) => c.character == card.character)
        .length;
    return count >= 2;
  }

  bool _canZhaoWith(Player player, Card card) {
    final count = player.hand
        .where((c) => c.character == card.character)
        .length;
    return count >= 3;
  }

  bool _canChiWith(
    Player player,
    int playerIndex,
    Card card,
    int discardPlayerId,
  ) {
    final isNextPlayer = playerIndex == (discardPlayerId + 1) % 3;
    if (!isNextPlayer) return false;
    return _findChiCards(player, card) != null;
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

  void _addToPublicCount(String character, int count) {
    state.publicCardCount[character] =
        (state.publicCardCount[character] ?? 0) + count;
  }

  void _rebuildPublicCardCount() {
    state.publicCardCount.clear();
    for (final p in state.players) {
      for (final card in p.discards) {
        state.publicCardCount[card.character] =
            (state.publicCardCount[card.character] ?? 0) + 1;
      }
      for (final meld in p.melds) {
        for (final card in meld.cards) {
          state.publicCardCount[card.character] =
              (state.publicCardCount[card.character] ?? 0) + 1;
        }
      }
    }
  }
}
