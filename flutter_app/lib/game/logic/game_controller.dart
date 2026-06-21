import 'dart:async';
import 'dart:math';
import '../core/game_logger.dart';
import '../models/card.dart';
import '../models/meld.dart';
import '../models/player.dart';
import '../models/game_state.dart';
import '../models/game_recorder.dart';
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
  Card? get lastDrawnCard => _lastDrawnCard;
  void clearLastDrawnCard() => _lastDrawnCard = null;

  bool _hasDealerPlayedFirstTurn = false;
  bool _skipDraw = false;
  bool _isStartingRound = false;
  bool _isDealing = false;
  bool _isPaused = false;
  bool _isFromTimeout = false;

  Card? _pendingDrawCard;
  int? _pendingDrawPlayerId;

  Card? _pendingDiscardCard;
  int? _pendingDiscardPlayerId;

  VoidCallback? _pendingMeldAction;
  bool get hasPendingMeldAction => _pendingMeldAction != null;

  Map<int, List<String>>? _pendingAIResponses;
  Card? _pendingResponseCard;
  int? _pendingResponseDiscardPlayerId;

  bool _pendingCheckResponse = false;
  Card? _pendingCheckResponseCard;
  int? _pendingCheckResponsePlayerId;

  bool _pendingAITurn = false;
  int? _pendingAITurnPlayerId;
  bool _pendingAIContinue = false;
  int? _pendingAIContinuePlayerId;
  bool _pendingAIContinueSkipZimo = false;

  int _drawVersion = 0;
  int _discardVersion = 0;
  int _drawAfterZhaoVersion = 0;
  int _aiTurnVersion = 0;
  int _aiContinueVersion = 0;
  int _checkResponseVersion = 0;
  int _meldActionVersion = 0;

  GameController({GameState? gameState, AIController? aiCtrl})
    : state = gameState ?? GameState(),
      aiController = aiCtrl ?? AIController();

  void startGame() {
    print('=== GameController.startGame called ===');
    state.reset();
    _isStartingRound = false;
    GameRecorder().setEnabled(AudioManager().recordingEnabled);
    GameRecorder().clear();
    if (state.difficulty == 'hard') {
      aiController = AIController(strategy: AIStrategyHard());
    } else {
      aiController = AIController();
    }
    state.players.addAll([
      Player(
        id: 0,
        name: '玩家1',
        type: PlayerType.ai,
        gender: _rng.nextBool() ? Gender.male : Gender.female,
      ),
      Player(
        id: 1,
        name: '我',
        type: PlayerType.human,
        gender: _rng.nextBool() ? Gender.male : Gender.female,
      ),
      Player(
        id: 2,
        name: '玩家2',
        type: PlayerType.ai,
        gender: _rng.nextBool() ? Gender.male : Gender.female,
      ),
    ]);
    state.dealerIndex = Random().nextInt(3);
    state.roundNumber = 0;
    state.gameStarted = true;
    print('=== calling startRound ===');
    startRound();
    print('=== startRound done ===');
  }

  void startRound() {
    print('=== startRound called, _isStartingRound=$_isStartingRound ===');
    for (final p in state.players) {
      GameLogger.i('SCORE', 'startRound ENTER: player${p.id} score=${p.score}');
    }
    if (_isStartingRound) return;
    _isStartingRound = true;
    _isPaused = false;

    // 重置托管状态（每局开始重新计数超时）
    // AI策略测试开关打开时，人类玩家自动进入托管状态
    if (AudioManager().aiStrategyTestEnabled) {
      state.isAutoHosting = true;
    } else {
      state.isAutoHosting = false;
    }
    state.timeoutCount = 0;

    state.roundNumber++;
    GameRecorder().startRound(
      state.roundNumber,
      state.dealerIndex,
      state.players,
    );
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
    _pendingDrawCard = null;
    _pendingDrawPlayerId = null;
    _pendingDiscardCard = null;
    _pendingDiscardPlayerId = null;
    _pendingMeldAction = null;
    _pendingCheckResponse = false;
    _pendingCheckResponseCard = null;
    _pendingCheckResponsePlayerId = null;
    _pendingAITurn = false;
    _pendingAITurnPlayerId = null;
    _pendingAIContinue = false;
    _pendingAIContinuePlayerId = null;
    _pendingAIContinueSkipZimo = false;
    _clearPendingAIResponses();

    _drawVersion++;
    _discardVersion++;
    _drawAfterZhaoVersion++;
    _aiTurnVersion++;
    _aiContinueVersion++;
    _checkResponseVersion++;
    _meldActionVersion++;
    stopCountdown();

    // 清空摸牌记录，避免新一局包含上一局数据
    state.humanDrawRecords.clear();

    state.deck = Card.createDeck();
    state.deck.shuffle();

    for (final player in state.players) {
      GameLogger.i(
        'SCORE',
        'startRound player${player.id}: score=${player.score}',
      );
      player.hand.clear();
      player.melds.clear();
      player.discards.clear();
      player.isTing = false;
      player.tingCards.clear();
      player.tingType = TingType.none;
      player.piao = 0;
      player.huCount = 0;
      player.meldHuCount = 0;
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
        GameRecorder().recordPiao(player.id, player.piao);
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
    GameRecorder().recordPiao(player.id, piaoValue);
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
      player.tingType = TingType.none;
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
        GameRecorder().recordInitialHands(state.players);
        onStateChanged?.call();
        Future.delayed(const Duration(milliseconds: 300), () {
          if (!state.gameStarted) return;
          if (_isPaused) {
            // paused时先不启动回合，resumeGame会处理
            return;
          }
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
        if (!state.gameStarted) return;
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
      startCountdown();
      final version = ++_aiTurnVersion;
      _pendingAITurn = true;
      _pendingAITurnPlayerId = player.id;
      final delay = 800 + _rng.nextInt(500);
      Future.delayed(Duration(milliseconds: delay), () {
        if (_isPaused || !state.gameStarted) return;
        if (_aiTurnVersion != version) return;
        if (state.showHuResult || state.showLiujuResult) return;
        _pendingAITurn = false;
        _pendingAITurnPlayerId = null;
        _processAITurn(player);
      });
    } else {
      if (_skipDraw) {
        _skipDraw = false;
        state.isMyTurn = true;
        state.isDrawing = false;
        _checkMyActionsAfterDraw(skipZimoCheck: true);
        onStateChanged?.call();
        startCountdown();
      } else if (!_hasDealerPlayedFirstTurn &&
          state.currentPlayerIndex == state.dealerIndex) {
        _hasDealerPlayedFirstTurn = true;
        state.isMyTurn = true;
        state.isDrawing = false;
        _checkMyActionsAfterDraw(skipZimoCheck: true);
        onStateChanged?.call();
        startCountdown();
      } else if (_getTotalCardCount(state.players[1]) >=
          _getTargetCardCount(state.players[1])) {
        state.isMyTurn = true;
        state.isDrawing = false;
        _checkMyActionsAfterDraw(skipZimoCheck: true);
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
    _pendingDrawCard = card;
    _pendingDrawPlayerId = 1;
    final player = state.players[1];
    final version = ++_drawVersion;

    onCardAnimation?.call(card, 1, 'draw');

    state.hideTingBadge = true;
    onStateChanged?.call();

    Future.delayed(const Duration(milliseconds: 2100), () {
      if (_isPaused || !state.gameStarted) return;
      if (_drawVersion != version) return;
      if (state.showHuResult || state.showLiujuResult) return;
      _completeDrawForHuman(card, player);
    });
  }

  void _completeDrawForHuman(Card card, Player player) {
    _pendingDrawCard = null;
    _pendingDrawPlayerId = null;
    player.addCard(card);
    GameRecorder().recordDraw(player.id, card);
    // AI策略测试：记录人类玩家摸牌（最多保存3张）
    state.humanDrawRecords.add(card.character);
    if (state.humanDrawRecords.length > 3) {
      state.humanDrawRecords.removeAt(0);
    }
    onPlayerDraw?.call(1);

    final tingResult = TingChecker.checkTing(player);
    player.isTing = tingResult.isTing;
    player.tingCards = tingResult.tingCards;
    player.tingType = tingResult.tingType;
    player.huCount = HuCalculator.calculateTotalHu(player);

    state.isDrawing = false;
    state.isMyTurn = true;

    _checkMyActionsAfterDraw();
    state.hideTingBadge = state.canHu;

    onStateChanged?.call();
    startCountdown();
  }

  void _checkMyActionsAfterDraw({bool skipZimoCheck = false}) {
    final player = state.players[1];
    state.canHu = !skipZimoCheck && _canZimo(player);
    state.isZimoOpportunity = state.canHu;
    state.canZhao = _canZhaoAfterDraw(player);
  }

  void _processAITurn(Player player) {
    if (state.currentTurnPlayer().id != player.id) return;

    if (state.deck.isEmpty) {
      _handleLiuju();
      return;
    }

    if (_skipDraw) {
      _skipDraw = false;
      _aiContinueAfterDraw(player, skipZimoCheck: true);
      return;
    }

    if (!_hasDealerPlayedFirstTurn &&
        state.currentPlayerIndex == state.dealerIndex) {
      _hasDealerPlayedFirstTurn = true;
      _aiContinueAfterDraw(player, skipZimoCheck: true);
      return;
    }

    if (_getTotalCardCount(player) >= _getTargetCardCount(player)) {
      _aiContinueAfterDraw(player, skipZimoCheck: true);
      return;
    }

    final card = state.deck.removeLast();
    _pendingDrawCard = card;
    _pendingDrawPlayerId = player.id;
    state.isDrawing = true;
    final version = ++_drawVersion;

    onCardAnimation?.call(card, player.id, 'draw');

    Future.delayed(const Duration(milliseconds: 2100), () {
      if (_isPaused || !state.gameStarted) return;
      if (_drawVersion != version) return;
      if (state.showHuResult || state.showLiujuResult) return;
      _completeDrawForAI(card, player);
    });
  }

  void _completeDrawForAI(Card card, Player player) {
    _pendingDrawCard = null;
    _pendingDrawPlayerId = null;
    state.isDrawing = false;
    player.addCard(card);
    GameRecorder().recordDraw(player.id, card);
    onPlayerDraw?.call(player.id);

    final tingResult = TingChecker.checkTing(player);
    player.isTing = tingResult.isTing;
    player.tingCards = tingResult.tingCards;
    player.tingType = tingResult.tingType;
    player.huCount = HuCalculator.calculateTotalHu(player);

    _aiContinueAfterDraw(player, drawnCard: card);
  }

  void _completeDrawAfterZhaoForHuman(Card card, Player player) {
    _pendingDrawCard = null;
    _pendingDrawPlayerId = null;
    _lastDrawnCard = card;
    player.addCard(card);
    onPlayerDraw?.call(player.id);

    final tingResult = TingChecker.checkTing(player);
    player.isTing = tingResult.isTing;
    player.tingCards = tingResult.tingCards;
    player.tingType = tingResult.tingType;
    player.huCount = HuCalculator.calculateTotalHu(player);

    state.isMyTurn = true;
    state.isDrawing = false;
    _checkMyActionsAfterDraw();
    state.hideTingBadge = state.canHu;
    onStateChanged?.call();
    startCountdown();
  }

  void _aiContinueAfterDraw(
    Player player, {
    Card? drawnCard,
    bool skipZimoCheck = false,
    bool skipZhaoCheck = false,
  }) {
    if (player.hand.isEmpty) {
      _nextTurn();
      return;
    }

    if (!skipZimoCheck && _canZimo(player)) {
      _handleHu(player.id, isZimo: true, zimoCard: drawnCard);
      return;
    }

    if (!skipZhaoCheck && _canZhaoAfterDraw(player)) {
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

    // 手动出牌重置超时计数
    if (!_isFromTimeout) {
      state.timeoutCount = 0;
    }
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
    Card discardCard = card;
    if (!player.hand.contains(discardCard)) {
      if (player.hand.isNotEmpty) {
        discardCard = player.hand.last;
      } else {
        return;
      }
    }
    _skipDraw = false;
    stopCountdown();
    onCardAnimation?.call(discardCard, player.id, 'discard');
    _audio.playDiscard(
      discardCard.character,
      voiceType: AudioManager.voiceTypeFromGender(player.gender),
    );

    _pendingDiscardCard = discardCard;
    _pendingDiscardPlayerId = player.id;
    final version = ++_discardVersion;

    Future.delayed(const Duration(milliseconds: 350), () {
      if (_isPaused || !state.gameStarted) return;
      if (_discardVersion != version) return;
      if (state.showHuResult || state.showLiujuResult) return;
      _completeDiscard(player, discardCard);
    });
  }

  void _completeDiscard(Player player, Card card) {
    _pendingDiscardCard = null;
    _pendingDiscardPlayerId = null;
    player.removeCard(card);
    player.discards.add(card);
    GameRecorder().recordDiscard(player.id, card);
    _addToPublicCount(card.character, 1);
    state.lastDiscardedCard = card;
    state.lastDiscardPlayerIndex = player.id;
    state.isMyTurn = false;
    _lastDrawnCard = null;

    final tingResult = TingChecker.checkTing(player);
    player.isTing = tingResult.isTing;
    player.tingCards = tingResult.tingCards;
    player.tingType = tingResult.tingType;
    player.huCount = HuCalculator.calculateTotalHu(player);

    if (player.type == PlayerType.human) {
      state.hideTingBadge = !player.isTing;
    }

    onPlayerDiscard?.call(card);
    onStateChanged?.call();

    _pendingCheckResponse = true;
    _pendingCheckResponseCard = card;
    _pendingCheckResponsePlayerId = player.id;
    final version = ++_checkResponseVersion;
    Future.delayed(const Duration(milliseconds: 800), () {
      if (_isPaused || !state.gameStarted) return;
      if (_checkResponseVersion != version) return;
      if (state.showHuResult || state.showLiujuResult) return;
      _checkResponses(card, player.id);
    });
  }

  void _checkResponses(Card card, int discardPlayerId) {
    _pendingCheckResponse = false;
    _pendingCheckResponseCard = null;
    _pendingCheckResponsePlayerId = null;

    final responses = <int, List<String>>{};

    for (int i = 0; i < state.players.length; i++) {
      if (i == discardPlayerId) continue;
      final p = state.players[i];
      final actions = <String>[];

      if (_canHuWith(p, card) && p.isTing) {
        actions.add('hu');
      }

      // AI玩家使用策略判断碰/招/吃
      if (p.type == PlayerType.ai) {
        if (_canZhaoWith(p, card)) {
          if (aiController.shouldZhao(p, card, state)) {
            actions.add('zhao');
          }
        }
        if (_canPengWith(p, card)) {
          if (aiController.shouldPeng(p, card, state)) {
            actions.add('peng');
          }
        }
        if (_canChiWith(p, i, card, discardPlayerId)) {
          if (aiController.shouldChi(p, card, state)) {
            actions.add('chi');
          }
        }
      } else {
        if (_canZhaoWith(p, card)) {
          actions.add('zhao');
        }
        if (_canPengWith(p, card)) {
          actions.add('peng');
        }
        if (_canChiWith(p, i, card, discardPlayerId)) {
          if (!_hasCompleteSentenceWithSingleCards(p, card)) {
            actions.add('chi');
          }
        }
      }

      responses[i] = actions;
    }

    _processResponses(responses, card, discardPlayerId);
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
    state.timeoutCount = 0;
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
    state.timeoutCount = 0;
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
      if (candidates.isEmpty) {
        state.isMyTurn = true;
        onStateChanged?.call();
        startCountdown();
        return;
      }
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
    // 手动选择招字重置超时计数
    state.timeoutCount = 0;
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
    state.timeoutCount = 0;
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
    state.timeoutCount = 0;
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
    // 手动过牌重置超时计数（超时触发的过牌不重置）
    if (!_isFromTimeout) {
      state.timeoutCount = 0;
    }
    state.canChi = false;
    state.canPeng = false;
    state.canZhao = false;
    state.canHu = false;
    state.waitingForResponse = false;
    _audio.playGuo(
      voiceType: AudioManager.voiceTypeFromGender(state.players[1].gender),
    );
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
        _clearPendingAIResponses();
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

  void startCountdown([int? seconds]) {
    // 玩家出牌倒计时固定30秒
    seconds ??= 30;
    // 托管状态下使用短倒计时，仅保留动画时间
    if (state.isAutoHosting && (state.isMyTurn || state.waitingForResponse)) {
      seconds = 2;
    }
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
          _audio.playHurry(
            voiceType: AudioManager.voiceTypeFromGender(
              state.players[1].gender,
            ),
          );
        }
        // 跑秒音效：3级频率
        if (state.countdown <= 5 && state.countdown > 0) {
          _audio.playTickFast();
        } else if (state.countdown <= 10 && state.countdown > 5) {
          _audio.playTickMedium();
        } else if (state.countdown <= 20 && state.countdown > 10) {
          _audio.playTickSlow();
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
    // 非托管状态下累计超时次数，连续3次进入托管（需开启倒计时托管功能）
    if (!state.isAutoHosting && AudioManager().autoHostingEnabled) {
      state.timeoutCount++;
      if (state.timeoutCount >= 3) {
        state.isAutoHosting = true;
      }
    }
    _isFromTimeout = true;
    final useAiStrategy =
        state.isAutoHosting && AudioManager().autoHostingStrategy == 'ai';

    if (state.waitingForResponse) {
      if (useAiStrategy) {
        _autoHostRespondToDiscard();
      } else {
        respondPass();
      }
    } else if (state.isMyTurn) {
      // 超时时先清除招等操作状态，再出牌
      if (state.canZhao || state.canChi || state.canPeng || state.canHu) {
        state.canChi = false;
        state.canPeng = false;
        state.canZhao = false;
        state.canHu = false;
      }

      final player = state.players[1];

      if (useAiStrategy) {
        // AI托管策略：检查自摸、招，然后用AI选择出牌
        if (_canZimo(player)) {
          _handleHu(player.id, isZimo: true, zimoCard: _lastDrawnCard);
          _isFromTimeout = false;
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
            _isFromTimeout = false;
            return;
          }
        }
        final card = aiController.selectDiscard(player, state);
        _doDiscard(player, card);
        _isFromTimeout = false;
        return;
      }

      // 非AI托管：简单出牌（打出最后摸的牌或最后一张）
      if (_lastDrawnCard != null) {
        final drawnCardIndex = player.hand.indexWhere(
          (c) => c.id == _lastDrawnCard!.id,
        );
        if (drawnCardIndex >= 0) {
          discardCard(drawnCardIndex);
          _lastDrawnCard = null;
          _isFromTimeout = false;
          return;
        }
      }

      if (player.hand.isNotEmpty) {
        discardCard(player.hand.length - 1);
      }
    }
    _isFromTimeout = false;
  }

  /// AI托管策略：响应其他玩家的出牌
  void _autoHostRespondToDiscard() {
    final player = state.players[1];
    final card = state.lastDiscardedCard;
    final discardPlayerId = state.lastDiscardPlayerIndex;
    if (card == null || discardPlayerId == null) {
      respondPass();
      return;
    }

    // 检查胡牌（需满足听牌条件）
    if (_canHuWith(player, card) && player.isTing) {
      stopCountdown();
      state.timeoutCount = 0;
      state.canChi = false;
      state.canPeng = false;
      state.canZhao = false;
      state.canHu = false;
      state.waitingForResponse = false;
      _clearPendingAIResponses();
      onStateChanged?.call();
      _handleHu(1, isZimo: false, dianpaoIndex: discardPlayerId);
      return;
    }

    // 检查招
    if (_canZhaoWith(player, card)) {
      if (aiController.shouldZhao(player, card, state)) {
        stopCountdown();
        state.timeoutCount = 0;
        state.canChi = false;
        state.canPeng = false;
        state.canZhao = false;
        state.canHu = false;
        state.waitingForResponse = false;
        _clearPendingAIResponses();
        onStateChanged?.call();
        _handleZhaoRespond(1, card, discardPlayerId);
        return;
      }
    }

    // 检查碰
    if (_canPengWith(player, card)) {
      if (aiController.shouldPeng(player, card, state)) {
        stopCountdown();
        state.timeoutCount = 0;
        state.canChi = false;
        state.canPeng = false;
        state.canZhao = false;
        state.canHu = false;
        state.waitingForResponse = false;
        _clearPendingAIResponses();
        onStateChanged?.call();
        _handlePeng(1, card, discardPlayerId);
        return;
      }
    }

    // 检查吃
    if (_canChiWith(player, 1, card, discardPlayerId)) {
      if (aiController.shouldChi(player, card, state)) {
        stopCountdown();
        state.timeoutCount = 0;
        state.canChi = false;
        state.canPeng = false;
        state.canZhao = false;
        state.canHu = false;
        state.waitingForResponse = false;
        _clearPendingAIResponses();
        onStateChanged?.call();
        _handleChi(1, card, discardPlayerId);
        return;
      }
    }

    respondPass();
  }

  /// 取消托管，恢复人类玩家手动操作
  void cancelAutoHosting() {
    state.isAutoHosting = false;
    state.timeoutCount = 0;
    onStateChanged?.call();
  }

  /// 手动进入托管状态（AI策略测试）
  void enterAutoHosting() {
    state.isAutoHosting = true;
    state.timeoutCount = 0;
    onStateChanged?.call();
    // 立即触发托管逻辑
    if (state.isMyTurn || state.waitingForResponse) {
      _handleTimeout();
    }
  }

  void _nextTurn() {
    if (state.showHuResult || state.showLiujuResult) return;
    state.currentPlayerIndex = (state.currentPlayerIndex + 1) % 3;
    _startTurn();
  }

  void _handleHu(
    int winnerIndex, {
    bool isZimo = false,
    int? dianpaoIndex,
    Card? zimoCard,
  }) {
    if (state.showHuResult) return;
    stopCountdown();
    state.isHandlingHu = true;
    state.canChi = false;
    state.canPeng = false;
    state.canZhao = false;
    state.canHu = false;
    state.isMyTurn = false;

    final winner = state.players[winnerIndex];

    if (!isZimo && !winner.isTing) {
      state.isHandlingHu = false;
      state.waitingForResponse = false;
      state.isDrawing = false;
      _clearPendingAIResponses();
      onStateChanged?.call();
      _nextTurn();
      return;
    }

    if (!isZimo && dianpaoIndex != null && state.lastDiscardedCard != null) {
      final discarder = state.players[dianpaoIndex];
      discarder.discards.remove(state.lastDiscardedCard);
      _addToPublicCount(state.lastDiscardedCard!.character, -1);
      winner.hand.add(state.lastDiscardedCard!);
    }

    final huTypeResult = HuCalculator.detectHuType(
      winner,
      paoCard: isZimo ? null : state.lastDiscardedCard,
    );

    if (isZimo) {
      _audio.playZimo(
        voiceType: AudioManager.voiceTypeFromGender(winner.gender),
      );
    } else {
      _audio.playHu(voiceType: AudioManager.voiceTypeFromGender(winner.gender));
    }

    if (winner.type == PlayerType.ai) {
      _audio.playHuType(
        huTypeResult.name,
        voiceType: AudioManager.voiceTypeFromGender(winner.gender),
        delayMs: 1000,
      );
    } else {
      _audio.playHuType(
        huTypeResult.name,
        voiceType: AudioManager.voiceTypeFromGender(winner.gender),
        delayMs: 800,
      );
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
      GameLogger.i(
        'SCORE',
        'player${entry.key}: ${state.players[entry.key].score} + ${entry.value} = ${state.players[entry.key].score + entry.value}',
      );
      state.players[entry.key].score += entry.value;
      scoreChanges.add(entry.value);
    }

    final totalHu = HuCalculator.calculateTotalHu(
      winner,
      paoCard: isZimo ? null : state.lastDiscardedCard,
    );
    winner.huCount = totalHu;
    final huTypeMultiplier = isZimo ? huTypeResult.zimo : huTypeResult.dianpao;
    final displayMultiplier = huTypeMultiplier;
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
      'dealerIndex': state.dealerIndex,
    });

    // 录制胡牌
    if (isZimo) {
      GameRecorder().recordZimo(
        winnerIndex,
        zimoCard ?? state.lastDiscardedCard!,
        huTypeResult.name,
        displayMultiplier,
      );
    } else {
      GameRecorder().recordHu(
        winnerIndex,
        dianpaoIndex!,
        state.lastDiscardedCard!,
        huTypeResult.name,
        displayMultiplier,
      );
    }
    GameRecorder().endRound(
      resultType: 'hu',
      resultData: {
        'winnerIndex': winnerIndex,
        'huType': huTypeResult.name,
        'method': method,
        if (dianpaoIndex != null) 'dianpaoIndex': dianpaoIndex,
        'huCount': totalHu,
        'multiplier': displayMultiplier,
        'scoreChanges': scores,
      },
    );

    // 庄家轮转延迟到胡牌面板关闭后执行，这里先记录下一局庄家
    if (winnerIndex != state.dealerIndex) {
      state.nextDealerIndex = (state.dealerIndex + 1) % 3;
    } else {
      state.nextDealerIndex = state.dealerIndex;
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
    if (state.showLiujuResult) return;
    stopCountdown();
    GameRecorder().recordLiuju();
    GameRecorder().endRound(resultType: 'liuju');
    _audio.playLiuju(
      voiceType: AudioManager.voiceTypeFromGender(
        state.players[(state.lastDiscardPlayerIndex! + 1) % 3].gender,
      ),
    );

    state.showLiujuResult = true;
    // 清除上一局胡牌结果数据，防止流局时显示残留的"炮"/"自摸"标签
    state.huResultWinnerName = null;
    state.huResultWinnerIndex = null;
    state.huResultMethod = null;
    state.huResultHuType = null;
    state.huResultHuCount = null;
    state.huResultMultiplier = null;
    state.huResultScore = null;
    state.huResultDianpaoIndex = null;
    state.huResultDianpaoName = null;
    state.huResultDianpaoCard = null;
    state.huResultZimoCard = null;
    state.huResultScoreChanges = null;
    state.huResultOldScores = null;

    // 流局庄家不变
    state.nextDealerIndex = state.dealerIndex;

    for (final p in state.players) {
      p.huCount = HuCalculator.calculateTotalHu(p);
    }

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
      'dealerIndex': state.dealerIndex,
    });

    onLiuju?.call();
    onStateChanged?.call();
  }

  void handleLiujuClose() {
    // 庄家轮转在面板关闭后执行
    if (state.nextDealerIndex != null) {
      state.dealerIndex = state.nextDealerIndex!;
      state.nextDealerIndex = null;
    }
    if (state.roundNumber >= 8) {
      onShowSettlement?.call();
    } else {
      if (!state.gameStarted) return;
      startRound();
    }
  }

  void handleHuClose() {
    // 庄家轮转在面板关闭后执行
    if (state.nextDealerIndex != null) {
      state.dealerIndex = state.nextDealerIndex!;
      state.nextDealerIndex = null;
    }
    if (state.roundNumber >= 8) {
      onShowSettlement?.call();
    } else {
      if (!state.gameStarted) return;
      for (final p in state.players) {
        GameLogger.i(
          'SCORE',
          'handleHuClose BEFORE startRound: player${p.id} score=${p.score}',
        );
      }
      startRound();
      for (final p in state.players) {
        GameLogger.i(
          'SCORE',
          'handleHuClose AFTER startRound: player${p.id} score=${p.score}',
        );
      }
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
    if (state.isHandlingHu) return;

    // 发牌动画完成但_startTurn被paused跳过的情况
    if (_isStartingRound && !_isDealing && state.isDealingComplete) {
      _isStartingRound = false;
      _startTurn();
      return;
    }

    if (_isDealing || _isStartingRound) return;

    if (state.waitingForResponse) {
      if (state.lastDiscardedCard != null &&
          state.lastDiscardPlayerIndex != null &&
          (state.canHu || state.canZhao || state.canPeng || state.canChi)) {
        onStateChanged?.call();
        startCountdown();
      } else {
        state.waitingForResponse = false;
        _nextTurn();
      }
      return;
    }

    if (state.isDrawing) {
      if (_pendingDrawCard != null && _pendingDrawPlayerId != null) {
        _drawVersion++;
        _drawAfterZhaoVersion++;
        final player = state.players[_pendingDrawPlayerId!];
        if (_pendingDrawPlayerId == 1) {
          if (_skipDraw) {
            _completeDrawAfterZhaoForHuman(_pendingDrawCard!, player);
          } else {
            _completeDrawForHuman(_pendingDrawCard!, player);
          }
        } else {
          _completeDrawForAI(_pendingDrawCard!, player);
        }
      } else {
        state.isDrawing = false;
        if (state.isMyTurn) {
          _checkMyActionsAfterDraw();
          onStateChanged?.call();
          startCountdown();
        } else {
          _startTurn();
        }
      }
      return;
    }

    if (_pendingDiscardCard != null && _pendingDiscardPlayerId != null) {
      _discardVersion++;
      final player = state.players[_pendingDiscardPlayerId!];
      _completeDiscard(player, _pendingDiscardCard!);
      return;
    }

    if (_pendingMeldAction != null) {
      _meldActionVersion++;
      _pendingMeldAction!.call();
      _pendingMeldAction = null;
      return;
    }

    if (_pendingCheckResponse &&
        _pendingCheckResponseCard != null &&
        _pendingCheckResponsePlayerId != null) {
      _checkResponseVersion++;
      _checkResponses(
        _pendingCheckResponseCard!,
        _pendingCheckResponsePlayerId!,
      );
      return;
    }

    // AI回合被paused跳过的情况
    if (_pendingAITurn && _pendingAITurnPlayerId != null) {
      _aiTurnVersion++;
      _pendingAITurn = false;
      final player = state.players[_pendingAITurnPlayerId!];
      _pendingAITurnPlayerId = null;
      _processAITurn(player);
      return;
    }

    // AI碰/吃/招后继续被paused跳过的情况
    if (_pendingAIContinue && _pendingAIContinuePlayerId != null) {
      _aiContinueVersion++;
      _pendingAIContinue = false;
      final player = state.players[_pendingAIContinuePlayerId!];
      _pendingAIContinuePlayerId = null;
      final skipZimo = _pendingAIContinueSkipZimo;
      _pendingAIContinueSkipZimo = false;
      _aiContinueAfterDraw(player, skipZimoCheck: skipZimo);
      return;
    }

    if (state.isMyTurn) {
      _checkMyActionsAfterDraw();
      onStateChanged?.call();
      startCountdown();
      return;
    }

    _startTurn();
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
    if (targetChar == null) {
      state.canChi = false;
      state.canPeng = false;
      state.canZhao = false;
      state.canHu = false;
      state.isDrawing = false;
      onStateChanged?.call();
      if (player.type == PlayerType.human) {
        state.isMyTurn = true;
        startCountdown();
      } else {
        final card = aiController.selectDiscard(player, state);
        _doDiscard(player, card);
      }
      return;
    }

    final zhaoCards = byChar[targetChar]!.sublist(0, 4);

    onMeldAnimation?.call(zhaoCards, player.id, 'zhao');
    _audio.playZhao(voiceType: AudioManager.voiceTypeFromGender(player.gender));

    final meldVersion = ++_meldActionVersion;
    _pendingMeldAction = () {
      final meld = Meld(
        cards: List.from(zhaoCards),
        type: MeldType.zhao,
        isJing: zhaoCards.first.isJing,
      );
      player.melds.add(meld);
      HuCalculator.updateMeldHuCache(player);
      for (final c in zhaoCards) {
        player.hand.remove(c);
      }
      _addToPublicCount(targetChar!, 4);
      GameRecorder().recordZhaoFromHand(player.id, targetChar!, zhaoCards);
      onPlayerMeld?.call(zhaoCards, player.id);
      onStateChanged?.call();
      _pendingMeldAction = null;
      _drawAfterZhao(player);
    };

    Future.delayed(const Duration(milliseconds: 1500), () {
      if (_isPaused || !state.gameStarted) return;
      if (_meldActionVersion != meldVersion) return;
      _pendingMeldAction?.call();
      _pendingMeldAction = null;
    });
  }

  void _drawAfterZhao(Player player) {
    if (state.deck.isEmpty) {
      _handleLiuju();
      return;
    }

    final card = state.deck.removeLast();
    final version = ++_drawAfterZhaoVersion;

    if (player.type == PlayerType.human) {
      state.isDrawing = true;
      state.isMyTurn = false;
      state.hideTingBadge = true;
      onStateChanged?.call();

      onCardAnimation?.call(card, player.id, 'draw');

      _pendingDrawCard = card;
      _pendingDrawPlayerId = player.id;

      Future.delayed(const Duration(milliseconds: 2100), () {
        if (_isPaused || !state.gameStarted) return;
        if (_drawAfterZhaoVersion != version) return;
        if (state.showHuResult || state.showLiujuResult) return;
        _completeDrawAfterZhaoForHuman(card, player);
      });
    } else {
      player.addCard(card);
      onPlayerDraw?.call(player.id);

      final tingResult = TingChecker.checkTing(player);
      player.isTing = tingResult.isTing;
      player.tingCards = tingResult.tingCards;
      player.huCount = HuCalculator.calculateTotalHu(player);

      final version = ++_aiContinueVersion;
      _pendingAIContinue = true;
      _pendingAIContinuePlayerId = player.id;
      _pendingAIContinueSkipZimo = false;
      final delay = 800 + _rng.nextInt(500);
      Future.delayed(Duration(milliseconds: delay), () {
        if (_isPaused || !state.gameStarted) return;
        if (_aiContinueVersion != version) return;
        _pendingAIContinue = false;
        _pendingAIContinuePlayerId = null;
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
      if (handMatching.length < 3) {
        state.canChi = false;
        state.canPeng = false;
        state.canZhao = false;
        state.canHu = false;
        onStateChanged?.call();
        _nextTurn();
        return;
      }
      zhaoCards = [card, ...handMatching.sublist(0, 3)];
    }

    onMeldAnimation?.call(zhaoCards, playerIndex, 'zhao');
    _audio.playZhao(voiceType: AudioManager.voiceTypeFromGender(player.gender));

    final meldVersion = ++_meldActionVersion;
    _pendingMeldAction = () {
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
        HuCalculator.updateMeldHuCache(player);
        _addToPublicCount(card.character, 4);
        onPlayerMeld?.call(newCards, playerIndex);
        GameRecorder().recordZhao(playerIndex, card, discardPlayerId);
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
        HuCalculator.updateMeldHuCache(player);
        _addToPublicCount(card.character, 4);
        onPlayerMeld?.call(zhaoCards, playerIndex);
        GameRecorder().recordZhao(playerIndex, card, discardPlayerId);
      }

      state.canChi = false;
      state.canPeng = false;
      state.canZhao = false;
      state.canHu = false;
      state.currentPlayerIndex = playerIndex;
      onStateChanged?.call();
      _pendingMeldAction = null;

      _drawAfterZhao(player);
    };

    Future.delayed(const Duration(milliseconds: 1500), () {
      if (_isPaused || !state.gameStarted) return;
      if (_meldActionVersion != meldVersion) return;
      _pendingMeldAction?.call();
      _pendingMeldAction = null;
    });
  }

  void _handlePeng(int playerIndex, Card card, int discardPlayerId) {
    final player = state.players[playerIndex];

    final matching = player.hand
        .where((c) => c.character == card.character)
        .toList();
    if (matching.length < 2) {
      state.canChi = false;
      state.canPeng = false;
      state.canZhao = false;
      state.canHu = false;
      onStateChanged?.call();
      _nextTurn();
      return;
    }
    final pengCards = [card, matching[0], matching[1]];

    onMeldAnimation?.call(pengCards, playerIndex, 'peng');
    _audio.playPeng(voiceType: AudioManager.voiceTypeFromGender(player.gender));

    final meldVersion = ++_meldActionVersion;
    _pendingMeldAction = () {
      final discarder = state.players[discardPlayerId];
      discarder.discards.remove(card);
      // card从弃牌堆移到melds，publicCardCount净变化为0（-1+1）
      _addToPublicCount(card.character, -1);

      player.melds.add(
        Meld(cards: pengCards, type: MeldType.kan, isJing: card.isJing),
      );
      HuCalculator.updateMeldHuCache(player);
      // melds中的3张牌都需要计入publicCardCount
      // card：从弃牌堆移到melds，需要+1补回上面的-1
      // matching[0]/[1]：从手牌移到melds，需要+1
      _addToPublicCount(card.character, 1);
      _addToPublicCount(matching[0].character, 1);
      _addToPublicCount(matching[1].character, 1);
      player.hand.remove(matching[0]);
      player.hand.remove(matching[1]);
      GameRecorder().recordPeng(playerIndex, card, discardPlayerId);
      onPlayerMeld?.call(pengCards, playerIndex);

      state.canChi = false;
      state.canPeng = false;
      state.canZhao = false;
      state.canHu = false;
      state.currentPlayerIndex = playerIndex;
      _skipDraw = true;
      final tingResult = TingChecker.checkTing(player);
      player.isTing = tingResult.isTing;
      player.tingCards = tingResult.tingCards;
      player.huCount = HuCalculator.calculateTotalHu(player);
      onStateChanged?.call();
      _pendingMeldAction = null;

      if (player.type == PlayerType.human) {
        state.isMyTurn = true;
        state.isDrawing = false;
        if (_canZhaoAfterDraw(player)) {
          state.canZhao = true;
          final candidates = _getZhaoCandidates(player);
          state.zhaoCandidates = candidates;
          state.showZhaoSelection = candidates.length > 1;
        }
        onStateChanged?.call();
        startCountdown();
      } else {
        final version = ++_aiContinueVersion;
        _pendingAIContinue = true;
        _pendingAIContinuePlayerId = player.id;
        _pendingAIContinueSkipZimo = true;
        final delay = 800 + _rng.nextInt(500);
        Future.delayed(Duration(milliseconds: delay), () {
          if (_isPaused || !state.gameStarted) return;
          if (_aiContinueVersion != version) return;
          _pendingAIContinue = false;
          _pendingAIContinuePlayerId = null;
          _aiContinueAfterDraw(
            player,
            skipZimoCheck: true,
            skipZhaoCheck: false,
          );
        });
      }
    };

    Future.delayed(const Duration(milliseconds: 1500), () {
      if (_isPaused || !state.gameStarted) return;
      if (_meldActionVersion != meldVersion) return;
      _pendingMeldAction?.call();
      _pendingMeldAction = null;
    });
  }

  void _handleChi(int playerIndex, Card card, int discardPlayerId) {
    final player = state.players[playerIndex];

    final chiCards = _findChiCards(player, card);
    if (chiCards == null) {
      state.canChi = false;
      state.canPeng = false;
      state.canZhao = false;
      state.canHu = false;
      onStateChanged?.call();
      _nextTurn();
      return;
    }
    final meldCards = [card, chiCards[0], chiCards[1]];

    onMeldAnimation?.call(meldCards, playerIndex, 'chi');
    _audio.playChi(voiceType: AudioManager.voiceTypeFromGender(player.gender));

    final meldVersion = ++_meldActionVersion;
    _pendingMeldAction = () {
      final discarder = state.players[discardPlayerId];
      discarder.discards.remove(card);
      // card从弃牌堆移到melds，publicCardCount净变化为0（-1+1）
      // 这里只做-1移除弃牌堆计数，melds中的card计数在下面统一添加
      _addToPublicCount(card.character, -1);

      player.melds.add(
        Meld(
          cards: meldCards,
          type: MeldType.ju,
          isJing: meldCards.any((c) => c.isJing),
        ),
      );
      HuCalculator.updateMeldHuCache(player);
      // melds中的3张牌都需要计入publicCardCount
      // card：从弃牌堆移到melds，需要+1补回上面的-1
      // chiCards[0]/[1]：从手牌移到melds，需要+1
      _addToPublicCount(card.character, 1);
      _addToPublicCount(chiCards[0].character, 1);
      _addToPublicCount(chiCards[1].character, 1);
      player.hand.remove(chiCards[0]);
      player.hand.remove(chiCards[1]);
      GameRecorder().recordChi(playerIndex, meldCards, card, discardPlayerId);
      onPlayerMeld?.call(meldCards, playerIndex);

      state.canChi = false;
      state.canPeng = false;
      state.canZhao = false;
      state.canHu = false;
      state.currentPlayerIndex = playerIndex;
      _skipDraw = true;
      final tingResult = TingChecker.checkTing(player);
      player.isTing = tingResult.isTing;
      player.tingCards = tingResult.tingCards;
      player.huCount = HuCalculator.calculateTotalHu(player);
      onStateChanged?.call();
      _pendingMeldAction = null;

      if (player.type == PlayerType.human) {
        state.isMyTurn = true;
        state.isDrawing = false;
        if (_canZhaoAfterDraw(player)) {
          state.canZhao = true;
          final candidates = _getZhaoCandidates(player);
          state.zhaoCandidates = candidates;
          state.showZhaoSelection = candidates.length > 1;
        }
        onStateChanged?.call();
        startCountdown();
      } else {
        final version = ++_aiContinueVersion;
        _pendingAIContinue = true;
        _pendingAIContinuePlayerId = player.id;
        _pendingAIContinueSkipZimo = true;
        final delay = 800 + _rng.nextInt(500);
        Future.delayed(Duration(milliseconds: delay), () {
          if (_isPaused || !state.gameStarted) return;
          if (_aiContinueVersion != version) return;
          _pendingAIContinue = false;
          _pendingAIContinuePlayerId = null;
          _aiContinueAfterDraw(
            player,
            skipZimoCheck: true,
            skipZhaoCheck: false,
          );
        });
      }
    };

    Future.delayed(const Duration(milliseconds: 1500), () {
      if (_isPaused || !state.gameStarted) return;
      if (_meldActionVersion != meldVersion) return;
      _pendingMeldAction?.call();
      _pendingMeldAction = null;
    });
  }

  bool _canZimo(Player player) {
    if (player.hand.isEmpty) return false;
    return HuCalculator.canHuOptimized(player.hand, player.melds);
  }

  bool _canZhaoAfterDraw(Player player) {
    if (_getTotalCardCount(player) < _getTargetCardCount(player)) return false;
    return _getZhaoCandidates(player).isNotEmpty;
  }

  List<String> _getZhaoCandidates(Player player) {
    final byChar = <String, int>{};
    for (final card in player.hand) {
      byChar[card.character] = (byChar[card.character] ?? 0) + 1;
    }
    return byChar.entries.where((e) => e.value == 4).map((e) => e.key).toList();
  }

  int _getTotalCardCount(Player player) {
    // 正确计算melds中的实际牌数（招是4张牌，不是3张）
    int meldCards = 0;
    for (final meld in player.melds) {
      meldCards += meld.cards.length;
    }
    return player.hand.length + meldCards;
  }

  /// 计算玩家出牌前的目标总牌数（手牌+组合牌）
  /// 基础20张，每个招+1张（招是4张牌但占1个句位）
  int _getTargetCardCount(Player player) {
    int zhaoCount = 0;
    for (final meld in player.melds) {
      if (meld.type == MeldType.zhao) zhaoCount++;
    }
    return 20 + zhaoCount;
  }

  bool _canHuWith(Player player, Card card) {
    // 胡别人出的牌：此时总牌数=目标-1（出牌后未摸牌状态）
    if (_getTotalCardCount(player) != _getTargetCardCount(player) - 1) {
      return false;
    }
    // 单钓听限制：不能胡单钓的这张字
    if (player.tingType == TingType.singleWait) {
      final singleCard = player.tingCards.isNotEmpty
          ? player.tingCards.first
          : null;
      if (singleCard != null && card.character == singleCard.character) {
        return false;
      }
    }
    final testHand = List<Card>.from(player.hand)..add(card);
    return HuCalculator.canHuOptimized(testHand, player.melds, paoCard: card);
  }

  bool _canPengWith(Player player, Card card) {
    // 碰别人出的牌：此时总牌数=目标-1（出牌后未摸牌状态）
    if (_getTotalCardCount(player) >= _getTargetCardCount(player)) {
      return false;
    }
    final count = player.hand
        .where((c) => c.character == card.character)
        .length;
    return count >= 2;
  }

  bool _canZhaoWith(Player player, Card card) {
    // 招别人出的牌：此时总牌数=目标-1（出牌后未摸牌状态）
    if (_getTotalCardCount(player) != _getTargetCardCount(player) - 1) {
      return false;
    }
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
    if (_getTotalCardCount(player) >= _getTargetCardCount(player)) {
      return false;
    }
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

  bool _hasCompleteSentenceWithSingleCards(Player player, Card card) {
    final hand = player.hand;
    final sentence = card.sentence;
    final groupChars = _groupChars[sentence - 1];

    final charCount = <String, int>{};
    for (final ch in groupChars) {
      charCount[ch] = 0;
    }
    for (final c in hand) {
      if (c.sentence == sentence && charCount.containsKey(c.character)) {
        charCount[c.character] = charCount[c.character]! + 1;
      }
    }

    final allPresent = charCount.values.every((count) => count >= 1);
    final allSingle = charCount.values.every((count) => count == 1);

    return allPresent && allSingle && groupChars.contains(card.character);
  }

  void _addToPublicCount(String character, int count) {
    state.addPublicCount(character, count);
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
}
