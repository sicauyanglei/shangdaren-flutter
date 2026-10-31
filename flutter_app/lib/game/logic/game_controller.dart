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
import '../network/game_sync_manager.dart';
import '../network/seat_mapper.dart';

typedef VoidCallback = void Function();
typedef IntCallback = void Function(int);
typedef CardCallback = void Function(Card);
typedef CardsCallback = void Function(List<Card>, int playerId);
typedef CardAnimCallback =
    void Function(Card card, int playerId, String animType);
typedef MeldAnimCallback =
    void Function(List<Card> cards, int playerId, String meldType);

class GameController implements OnlineGameDelegate {
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

  // ---------------- 联机（3真人对战） ----------------
  /// 联机同步管理器（单机为 null）
  GameSyncManager? _syncManager;

  /// 联机对局结束（面板关闭/掉线）后通知 UI 返回大厅
  void Function(String reason)? onOnlineGameEnd;

  bool get _online => state.isOnline && _syncManager != null;
  SeatMapper get _mapper => _syncManager!.seatMapper;

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

  // ===== 热座模式状态 =====
  bool get _hotSeat => state.isHotSeat;
  // 交接屏目标玩家（对象引用，旋转不失效）
  Player? _hsHandoffPlayer;
  // 交接完成后继续执行的流程
  VoidCallback? _hsPendingAfterHandoff;
  // 顺序询问队列（出牌后按回合顺序询问其余两家）
  List<MapEntry<Player, List<String>>>? _hsAskQueue;
  Card? _hsAskCard;
  Player? _hsAskDiscarder;
  String? _hsPendingClaimAction;
  Player? _hsPendingClaimPlayer;

  GameController({GameState? gameState, AIController? aiCtrl})
    : state = gameState ?? GameState(),
      aiController = aiCtrl ?? AIController();

  void startGame() {
    print('=== GameController.startGame called ===');
    state.reset();
    // 单机模式：确保清除联机/热座状态
    state.isOnline = false;
    state.isHotSeat = false;
    _hsResetState();
    _syncManager?.detachGameDelegate();
    _syncManager = null;
    _isStartingRound = false;
    // 回放数据始终录制，与"游戏录制(视频)"设置解耦
    GameRecorder().setEnabled(true);
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

  /// 热座模式：3名真人共用一台设备轮流操作。
  /// 持机人始终位于 players[1]（本地视角底部、手牌正面朝上），
  /// 其余两家手牌背面朝上。轮到谁就把设备交给谁，视角随持机人旋转。
  void startHotSeatGame() {
    print('=== GameController.startHotSeatGame called ===');
    state.reset();
    state.isOnline = false;
    state.isHotSeat = true;
    _hsResetState();
    _syncManager?.detachGameDelegate();
    _syncManager = null;
    _isStartingRound = false;
    // 热座视角会旋转，回放数据索引会错乱，禁用录制
    GameRecorder().setEnabled(false);
    GameRecorder().clear();
    state.players.addAll([
      Player(
        id: 0,
        name: '玩家甲',
        type: PlayerType.human,
        gender: _rng.nextBool() ? Gender.male : Gender.female,
      ),
      Player(
        id: 1,
        name: '玩家乙',
        type: PlayerType.human,
        gender: _rng.nextBool() ? Gender.male : Gender.female,
      ),
      Player(
        id: 2,
        name: '玩家丙',
        type: PlayerType.human,
        gender: _rng.nextBool() ? Gender.male : Gender.female,
      ),
    ]);
    state.dealerIndex = Random().nextInt(3);
    state.roundNumber = 0;
    state.gameStarted = true;
    print('=== hotseat calling startRound ===');
    startRound();
  }

  void _hsResetState() {
    _hsHandoffPlayer = null;
    _hsPendingAfterHandoff = null;
    _hsAskQueue = null;
    _hsAskCard = null;
    _hsAskDiscarder = null;
    _hsPendingClaimAction = null;
    _hsPendingClaimPlayer = null;
    state.hsHandoffName = null;
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

    // 热座模式：每局发牌前交接给庄家，防止上一持机人看到庄家手牌
    if (_hotSeat) {
      _hsResetAskState();
      _hsShowHandoff(state.players[state.dealerIndex], _showPiaoScreen);
      return;
    }

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
        // 热座模式：飘分者不在持机位时，交接设备后再弹飘分弹窗
        if (_hotSeat && state.piaoCurrentPlayerIndex != 1) {
          _hsShowHandoff(player, () {
            // 交接后飘分者已在 players[1]，弹窗条件成立自动显示
          });
          return;
        }
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

    if (_online) {
      // 联机：上报服务器，全员飘完后服务器统一发牌
      state.isPiaoPhase = false;
      _syncManager!.sendPiao(piaoValue);
      onStateChanged?.call();
      return;
    }

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
    // 联机：回合推进由服务器事件驱动，本地不启动回合
    if (state.isOnline) return;
    if (state.deck.isEmpty && !_skipDraw) {
      _handleLiuju();
      return;
    }

    // 热座：当前行动者不在持机位时，先交接设备（旋转后其位于 players[1]）
    if (_hotSeat && state.currentPlayerIndex != 1) {
      _hsShowHandoff(state.currentTurnPlayer(), _startTurn);
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
    if (_online) {
      // 联机：出牌上报服务器，由服务器广播给其他玩家
      _syncManager!.sendDiscard(discardCard.character);
    }
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

    // 联机：其他玩家的响应由服务器仲裁，本地不检查
    if (_online) return;

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
    if (state.isOnline) return;
    // 热座：按回合顺序逐家询问（轮到谁就交接给谁）
    if (_hotSeat) {
      _hsCheckResponses(card, discardPlayerId);
      return;
    }
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
    final humanIndex = _hotSeat
        ? 1
        : state.players.indexWhere((p) => p.type == PlayerType.human);
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

    // 热座：点炮认领走询问状态机（可能被更高优先级截胡，统一延迟应用）
    if (_hotSeat && !isZimo) {
      _hsAcceptClaim('hu');
      return;
    }

    if (_online) {
      // 联机：胡牌上报服务器，各端等 game:hu 广播统一展示
      final winner = state.players[humanIndex];
      final huCard = isZimo ? _lastDrawnCard : state.lastDiscardedCard;
      final winnerData = _buildOnlineWinnerData(
        winner,
        huCard: huCard,
        isZimo: isZimo,
        dianpaoIndex: isZimo ? null : state.lastDiscardPlayerIndex,
      );
      if (isZimo) {
        _syncManager!.sendZimoHu(huCard?.character ?? '', winnerData);
      } else {
        _syncManager!.sendClaim('hu', winnerData: winnerData);
      }
      return;
    }

    _handleHu(
      humanIndex,
      isZimo: isZimo,
      dianpaoIndex: isZimo ? null : state.lastDiscardPlayerIndex,
      zimoCard: isZimo ? _lastDrawnCard : null,
    );
  }

  void respondZhao() {
    final humanIndex = _hotSeat
        ? 1
        : state.players.indexWhere((p) => p.type == PlayerType.human);
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
      // 热座：招认领走询问状态机
      if (_hotSeat) {
        _hsAcceptClaim('zhao');
        return;
      }
      if (_online) {
        // 联机：招认领上报服务器，等裁决后各端统一执行
        _syncManager!.sendClaim(
          'zhao',
          meldCards: [state.lastDiscardedCard!.character],
        );
        onStateChanged?.call();
        return;
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
    final humanIndex = _hotSeat
        ? 1
        : state.players.indexWhere((p) => p.type == PlayerType.human);
    if (humanIndex < 0) return;
    // 手动选择招字重置超时计数
    state.timeoutCount = 0;
    state.showZhaoSelection = false;
    state.zhaoCandidates.clear();
    _handleZhaoFromHand(state.players[humanIndex], character: character);
  }

  void respondPeng() {
    final humanIndex = _hotSeat
        ? 1
        : state.players.indexWhere((p) => p.type == PlayerType.human);
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
    // 热座：碰认领走询问状态机
    if (_hotSeat) {
      _hsAcceptClaim('peng');
      return;
    }
    if (_online) {
      // 联机：碰认领上报服务器，等裁决后各端统一执行
      _syncManager!.sendClaim(
        'peng',
        meldCards: [state.lastDiscardedCard!.character],
      );
      return;
    }
    _handlePeng(
      humanIndex,
      state.lastDiscardedCard!,
      state.lastDiscardPlayerIndex!,
    );
  }

  void respondChi() {
    final humanIndex = _hotSeat
        ? 1
        : state.players.indexWhere((p) => p.type == PlayerType.human);
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
    // 热座：吃认领走询问状态机
    if (_hotSeat) {
      _hsAcceptClaim('chi');
      return;
    }
    if (_online) {
      // 联机：吃认领上报服务器（meldCards=完整句3字按position排序），等裁决后各端统一执行
      final me = state.players[humanIndex];
      final chiCards = _findChiCards(me, state.lastDiscardedCard!);
      if (chiCards == null) return;
      final juCards = [chiCards[0], chiCards[1], state.lastDiscardedCard!]
        ..sort((a, b) => a.position.compareTo(b.position));
      _syncManager!.sendClaim(
        'chi',
        meldCards: juCards.map((c) => c.character).toList(),
      );
      return;
    }
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

    if (_online && wasWaitingForResponse) {
      // 联机：过牌上报服务器，由服务器收齐后裁决推进
      state.isMyTurn = false;
      _syncManager!.sendClaim('pass');
      onStateChanged?.call();
      return;
    }

    if (wasWaitingForResponse) {
      state.isMyTurn = false;
      // 热座：过牌 → 询问下一家
      if (_hotSeat) {
        _hsAskNext();
        return;
      }
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

  // ==================== 热座模式核心 ====================

  void _hsResetAskState() {
    _hsAskQueue = null;
    _hsAskCard = null;
    _hsAskDiscarder = null;
    _hsPendingClaimAction = null;
    _hsPendingClaimPlayer = null;
  }

  /// 显示交接屏：全屏遮罩"请将设备交给玩家X"，点击后旋转视角并继续挂起流程
  void _hsShowHandoff(Player player, VoidCallback after) {
    stopCountdown();
    state.canChi = false;
    state.canPeng = false;
    state.canZhao = false;
    state.canHu = false;
    state.waitingForResponse = false;
    state.isMyTurn = false;
    state.isDrawing = false;
    _hsHandoffPlayer = player;
    _hsPendingAfterHandoff = after;
    state.hsHandoffName = player.name;
    onStateChanged?.call();
  }

  /// UI 在玩家点击交接屏后调用：旋转视角至接机人并继续挂起的流程
  void completeHotSeatHandoff() {
    if (!state.isHotSeat) return;
    final player = _hsHandoffPlayer;
    if (player == null || state.hsHandoffName == null) return;
    _hsHandoffPlayer = null;
    state.hsHandoffName = null;
    final after = _hsPendingAfterHandoff;
    _hsPendingAfterHandoff = null;
    final idx = state.players.indexOf(player);
    if (idx >= 0 && idx != 1) {
      _hsRotateTo(idx);
    }
    onStateChanged?.call();
    after?.call();
  }

  /// 视角旋转：把当前 local targetIdx 的玩家移到持机位 players[1]。
  /// 数组重排 + 所有索引字段 remap + player.id 重排（id 即数组下标）。
  /// 3人循环顺序在旋转下保持不变。
  void _hsRotateTo(int targetIdx) {
    final old = List<Player>.from(state.players);
    final shift = (targetIdx - 1 + 3) % 3;
    for (var j = 0; j < 3; j++) {
      state.players[j] = old[(j + shift) % 3];
    }
    int mapIdx(int i) => (i - shift + 3) % 3;
    state.currentPlayerIndex = mapIdx(state.currentPlayerIndex);
    state.dealerIndex = mapIdx(state.dealerIndex);
    if (state.nextDealerIndex != null) {
      state.nextDealerIndex = mapIdx(state.nextDealerIndex!);
    }
    if (state.lastDiscardPlayerIndex != null) {
      state.lastDiscardPlayerIndex = mapIdx(state.lastDiscardPlayerIndex!);
    }
    state.piaoCurrentPlayerIndex = mapIdx(state.piaoCurrentPlayerIndex);
    if (state.huResultWinnerIndex != null) {
      state.huResultWinnerIndex = mapIdx(state.huResultWinnerIndex!);
    }
    if (state.huResultDianpaoIndex != null) {
      state.huResultDianpaoIndex = mapIdx(state.huResultDianpaoIndex!);
    }
    if (state.huResultScoreChanges != null) {
      state.huResultScoreChanges = state.huResultScoreChanges!.map(
        (k, v) => MapEntry(mapIdx(k), v),
      );
    }
    if (state.huResultOldScores != null) {
      state.huResultOldScores = state.huResultOldScores!.map(
        (k, v) => MapEntry(mapIdx(k), v),
      );
    }
    for (var j = 0; j < 3; j++) {
      state.players[j].id = j;
    }
    // 跨视角敏感的临时状态（上一持机人的摸牌高亮）
    _lastDrawnCard = null;
  }

  /// 热座响应仲裁：按出牌者之后的回合顺序逐家询问。
  /// 询问对象、认领者、出牌者均用 Player 引用（旋转不失效）。
  void _hsCheckResponses(Card card, int discardPlayerId) {
    _hsResetAskState();
    final discarder = state.players[discardPlayerId];
    final queue = <MapEntry<Player, List<String>>>[];
    for (var k = 1; k <= 2; k++) {
      final i = (discardPlayerId + k) % 3;
      final p = state.players[i];
      final acts = <String>[];
      if (_canHuWith(p, card) && p.isTing) acts.add('hu');
      if (_canZhaoWith(p, card)) acts.add('zhao');
      if (_canPengWith(p, card)) acts.add('peng');
      if (_canChiWith(p, i, card, discardPlayerId) &&
          !_hasCompleteSentenceWithSingleCards(p, card)) {
        acts.add('chi');
      }
      if (acts.isNotEmpty) queue.add(MapEntry(p, acts));
    }
    if (queue.isEmpty) {
      _nextTurn();
      return;
    }
    _hsAskQueue = queue;
    _hsAskCard = card;
    _hsAskDiscarder = discarder;
    _hsAskNext();
  }

  /// 询问下一家；全部问完后统一裁决。
  /// 支配优化：已有认领时，不可能超越当前认领优先级的玩家直接跳过。
  void _hsAskNext() {
    if (_hsAskQueue == null) return; // 不在询问流程中
    const prio = {'hu': 4, 'zhao': 3, 'peng': 2, 'chi': 1};
    while (_hsAskQueue!.isNotEmpty) {
      final item = _hsAskQueue!.removeAt(0);
      if (_hsPendingClaimAction != null) {
        final best = item.value
            .map((a) => prio[a]!)
            .reduce((a, b) => a > b ? a : b);
        if (best <= prio[_hsPendingClaimAction!]!) continue;
      }
      final i = state.players.indexOf(item.key);
      if (i != 1) {
        _hsShowHandoff(item.key, () => _hsShowResponseButtons(item.value));
      } else {
        _hsShowResponseButtons(item.value);
      }
      return;
    }
    _hsResolveResponses();
  }

  /// 询问流程中显示响应按钮（此时被询问者已在持机位 players[1]）
  void _hsShowResponseButtons(List<String> acts) {
    state.canHu = acts.contains('hu');
    state.isZimoOpportunity = false;
    state.canZhao = acts.contains('zhao');
    state.canPeng = acts.contains('peng');
    state.canChi = acts.contains('chi');
    state.waitingForResponse = true;
    state.isMyTurn = true;
    onStateChanged?.call();
    startCountdown();
  }

  /// 玩家认领动作（当前持机人即认领者），继续询问剩余玩家
  void _hsAcceptClaim(String action) {
    _hsPendingClaimAction = action;
    _hsPendingClaimPlayer = state.players[1];
    onStateChanged?.call();
    _hsAskNext();
  }

  /// 全部询问完成：应用优先级最高的认领；无认领则进入下家回合
  void _hsResolveResponses() {
    final action = _hsPendingClaimAction;
    final claimer = _hsPendingClaimPlayer;
    final card = _hsAskCard;
    final discarder = _hsAskDiscarder;
    _hsResetAskState();

    if (action == null || claimer == null || card == null || discarder == null) {
      _nextTurn();
      return;
    }

    void apply() {
      final claimIdx = state.players.indexOf(claimer);
      final discardIdx = state.players.indexOf(discarder);
      if (claimIdx < 0 || discardIdx < 0) {
        _nextTurn();
        return;
      }
      if (action == 'hu') {
        _handleHu(claimIdx, isZimo: false, dianpaoIndex: discardIdx);
      } else if (action == 'zhao') {
        _handleZhaoRespond(claimIdx, card, discardIdx);
      } else if (action == 'peng') {
        _handlePeng(claimIdx, card, discardIdx);
      } else if (action == 'chi') {
        _handleChi(claimIdx, card, discardIdx);
      }
    }

    // 认领者不在持机位（视角已被后续询问转走）→ 交接回认领者再应用
    if (state.players.indexOf(claimer) != 1) {
      _hsShowHandoff(claimer, apply);
    } else {
      apply();
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

    if (_online) {
      // 联机：超时只能过牌/自动出牌，全部走服务器（禁止本地策略直接胡/碰/吃）
      if (state.waitingForResponse) {
        respondPass();
      } else if (state.isMyTurn) {
        state.canChi = false;
        state.canPeng = false;
        state.canZhao = false;
        state.canHu = false;
        final player = state.players[1];
        if (_lastDrawnCard != null) {
          final idx = player.hand.indexWhere(
            (c) => c.id == _lastDrawnCard!.id,
          );
          if (idx >= 0) {
            discardCard(idx);
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
      return;
    }

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
        state.players[((state.lastDiscardPlayerIndex ?? 0) + 1) % 3].gender,
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
    // 联机：单局制，面板关闭后由 UI 返回大厅
    if (_online) {
      _finishOnlineGame();
      return;
    }
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
    // 联机：单局制，面板关闭后由 UI 返回大厅
    if (_online) {
      _finishOnlineGame();
      return;
    }
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
    // 联机对局由服务器事件驱动，不做本地暂停（避免漏处理服务器事件）
    if (_online) return;
    _isPaused = true;
    stopCountdown();
  }

  void resumeGame() {
    _isPaused = false;
    // 联机对局完全由服务器事件驱动（含延迟回调），本地恢复会造成双重执行
    if (state.isOnline) return;
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

    if (_online) {
      // 联机：招手牌上报服务器，补牌由服务器下发（game:draw:self）
      _syncManager!.sendZhaoSelf(targetChar!);
    }

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
      if (_online) return; // 联机：招后补牌由服务器下发
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

  /* ==================== 联机（3真人对战） ==================== */

  int _onlineCardSeq = 1000000;

  /// 联机对局入口：挂载同步管理器，后续流程全部由服务器事件驱动
  void startOnlineGame(GameSyncManager mgr) {
    state.reset();
    state.isOnline = true;
    state.isHotSeat = false;
    _hsResetState();
    // 联机统一计分参数（各端一致，保证赢家计算的 winnerData 全端相同）
    state.baseScore = 5;
    state.multiplierBase = 2;
    state.piaoEnabled = true;
    _isStartingRound = false;
    _isPaused = false;
    _lastDrawnCard = null;
    _skipDraw = false;
    _hasDealerPlayedFirstTurn = false;
    _onlineCardSeq = 1000000;
    stopCountdown();
    _syncManager = mgr;
    mgr.attachGameDelegate(this);
    onStateChanged?.call();
  }

  /// 联机用唯一 id 重建牌对象（服务器只下发字面）
  Card _newOnlineCard(String character) {
    final proto = Card.buildFromCharacter(character);
    return Card(
      id: _onlineCardSeq++,
      character: character,
      sentence: proto.sentence,
      position: proto.position,
    );
  }

  /// 其他玩家手牌的牌背占位（只维持数量，不参与判定与显示字面）
  Card _newDummyCard() => _newOnlineCard('上');

  /// 联机对局收尾：面板关闭/掉线后由 UI 返回大厅
  void _finishOnlineGame() {
    stopCountdown();
    state.showHuResult = false;
    state.showLiujuResult = false;
    state.gameStarted = false;
    _syncManager?.detachGameDelegate();
    _syncManager = null;
    state.isOnline = false;
    onOnlineGameEnd?.call('对局结束');
  }

  /// 构建胡牌结算数据（赢家客户端计算，随 game:hu 广播给各端统一展示）
  Map<String, dynamic> _buildOnlineWinnerData(
    Player winner, {
    Card? huCard,
    bool isZimo = false,
    int? dianpaoIndex,
  }) {
    final winnerIndex = state.players.indexOf(winner);
    // 点炮时胡牌暂不在手，临时加入用于检测（与 _handleHu 最终状态一致）
    final inserted = !isZimo && huCard != null && !winner.hand.contains(huCard);
    if (inserted) winner.hand.add(huCard!);
    final huTypeResult = HuCalculator.detectHuType(
      winner,
      paoCard: isZimo ? null : huCard,
    );
    final scores = ScoreCalculator.calculateScores(
      state,
      winnerIndex,
      dianpaoIndex,
      isZimo,
      huTypeResult,
    );
    final totalHu = HuCalculator.calculateTotalHu(
      winner,
      paoCard: isZimo ? null : huCard,
    );
    final handChars = winner.hand.map((c) => c.character).toList();
    if (inserted) winner.hand.remove(huCard!);

    // 分数变动以服务器座位为键，各端收到后转回本地视角
    final scoreChanges = <String, int>{};
    scores.forEach((localIndex, value) {
      scoreChanges['${_mapper.toServer(localIndex)}'] = value;
    });
    return {
      'hand': handChars,
      'huType': huTypeResult.name,
      'huCount': totalHu,
      'multiplier': isZimo ? huTypeResult.zimo : huTypeResult.dianpao,
      'scoreChanges': scoreChanges,
    };
  }

  @override
  void onOnlineGameStart(int dealerSeat, List<OnlinePlayerInfo> players) {
    state.isOnline = true;
    state.gameStarted = true;
    state.roundNumber = 1;
    state.showHuResult = false;
    state.showLiujuResult = false;
    state.isDealingComplete = false;
    state.lastDiscardedCard = null;
    state.lastDiscardPlayerIndex = null;
    state.nextDealerIndex = null;
    state.dealerIndex = _mapper.toLocal(dealerSeat);
    state.currentPlayerIndex = state.dealerIndex;
    _lastDrawnCard = null;
    _hasDealerPlayedFirstTurn = false;
    _skipDraw = false;
    stopCountdown();

    // 按本地视角重排玩家：players[1] 恒为"我"
    final arranged = List<Player>.generate(
      3,
      (i) => Player(id: i, name: '玩家$i', type: PlayerType.remote),
    );
    for (final info in players) {
      final local = _mapper.toLocal(info.seat);
      if (local < 0 || local > 2) continue;
      arranged[local] = Player(
        id: local,
        name: _mapper.isMe(info.seat) ? '我' : info.name,
        type: local == 1 ? PlayerType.human : PlayerType.remote,
        gender: _rng.nextBool() ? Gender.male : Gender.female,
      );
    }
    state.players
      ..clear()
      ..addAll(arranged);

    // 飘分阶段：服务器收集全员飘分后统一发牌
    if (state.piaoEnabled) {
      state.isPiaoPhase = true;
      state.piaoCurrentPlayerIndex = 1;
      state.piaoSetCount = 0;
    } else {
      state.isPiaoPhase = false;
      for (final p in state.players) {
        p.piao = 0;
      }
      _syncManager!.sendPiao(0);
    }
    onStateChanged?.call();
  }

  @override
  void onOnlinePiaoUpdate(int seat, int piao) {
    final local = _mapper.toLocal(seat);
    if (local < 0 || local >= state.players.length) return;
    state.players[local].piao = piao;
    onStateChanged?.call();
  }

  @override
  void onOnlineDeal(
    int dealerSeat,
    List<String> hand,
    Map<int, int> piao,
    int remaining,
  ) {
    state.isPiaoPhase = false;
    final me = state.players[1];
    me.hand.clear();
    for (final ch in hand) {
      me.hand.add(_newOnlineCard(ch));
    }
    me.sortHand();
    piao.forEach((seat, value) {
      final local = _mapper.toLocal(seat);
      if (local >= 0 && local < state.players.length) {
        state.players[local].piao = value;
      }
    });
    // 服务器牌堆只下发剩余数，用占位牌维护牌堆显示
    state.deck = List.generate(remaining, (_) => _newDummyCard());
    state.isDealingComplete = true;
    state.humanDrawRecords.clear();
    state.currentPlayerIndex = _mapper.toLocal(dealerSeat);
    _rebuildPublicCardCount();
    me.huCount = HuCalculator.calculateTotalHu(me);
    onStateChanged?.call();

    // 庄家先出牌（不摸牌）；我是庄家则直接进入出牌回合
    if (_mapper.isMe(dealerSeat)) {
      state.isMyTurn = true;
      state.isDrawing = false;
      _checkMyActionsAfterDraw(skipZimoCheck: true); // 20张可招手牌，不能自摸
      onStateChanged?.call();
      startCountdown();
    }
  }

  @override
  void onOnlineDraw(int seat, int remaining) {
    final local = _mapper.toLocal(seat);
    if (local < 0 || local >= state.players.length) return;
    state.deck = List.generate(remaining, (_) => _newDummyCard());
    state.currentPlayerIndex = local;
    state.isMyTurn = false;
    final player = state.players[local];
    player.hand.add(_newDummyCard());
    onCardAnimation?.call(_newDummyCard(), local, 'draw');
    onStateChanged?.call();
  }

  @override
  void onOnlineDrawSelf(String card, int remaining) {
    if (card.isEmpty) return;
    state.deck = List.generate(remaining, (_) => _newDummyCard());
    final c = _newOnlineCard(card);
    final player = state.players[1];
    state.isDrawing = true;
    state.isMyTurn = false;
    state.currentPlayerIndex = 1;
    _lastDrawnCard = c;
    _pendingDrawCard = c;
    _pendingDrawPlayerId = 1;
    final version = ++_drawVersion;
    onCardAnimation?.call(c, 1, 'draw');
    state.hideTingBadge = true;
    onStateChanged?.call();
    Future.delayed(const Duration(milliseconds: 2100), () {
      if (!state.gameStarted) return;
      if (_drawVersion != version) return;
      if (state.showHuResult || state.showLiujuResult) return;
      _completeDrawForHuman(c, player);
    });
  }

  @override
  void onOnlineDiscard(int seat, String card) {
    final local = _mapper.toLocal(seat);
    if (local < 0 || local >= state.players.length || card.isEmpty) return;
    if (local == 1) return; // 自己的出牌本地已处理（防御）
    final player = state.players[local];
    final c = _newOnlineCard(card);
    if (player.hand.isNotEmpty) player.hand.removeLast();
    player.discards.add(c);
    _addToPublicCount(c.character, 1);
    state.lastDiscardedCard = c;
    state.lastDiscardPlayerIndex = local;
    state.currentPlayerIndex = local;
    state.isMyTurn = false;
    _lastDrawnCard = null;
    onCardAnimation?.call(c, local, 'discard');
    onPlayerDiscard?.call(c);
    onStateChanged?.call();

    // 计算我方可响应的操作（胡/招/碰/吃）
    final me = state.players[1];
    final actions = <String>[];
    if (me.isTing && _canHuWith(me, c)) actions.add('hu');
    if (_canZhaoWith(me, c)) actions.add('zhao');
    if (_canPengWith(me, c)) actions.add('peng');
    if (_canChiWith(me, 1, c, local) &&
        !_hasCompleteSentenceWithSingleCards(me, c)) {
      actions.add('chi');
    }

    if (actions.isEmpty) {
      // 无可响应操作自动过牌（服务器需收齐响应才能推进）
      _syncManager!.sendClaim('pass');
      return;
    }

    for (final action in actions) {
      if (action == 'hu') {
        state.canHu = true;
        state.isZimoOpportunity = false;
      } else if (action == 'zhao') {
        state.canZhao = true;
      } else if (action == 'peng') {
        state.canPeng = true;
      } else if (action == 'chi') {
        state.canChi = true;
      }
    }
    state.waitingForResponse = true;
    state.isMyTurn = true;
    onStateChanged?.call();
    startCountdown();
  }

  @override
  void onOnlineActionResult(OnlineActionResult result) {
    switch (result.result) {
      case 'pass':
        state.waitingForResponse = false;
        state.isMyTurn = false;
        state.canChi = false;
        state.canPeng = false;
        state.canZhao = false;
        state.canHu = false;
        stopCountdown();
        onStateChanged?.call();
        break;
      case 'claim':
        if (result.seat == null || result.action == null) return;
        _applyOnlineClaim(result);
        break;
      case 'zhao-self':
        if (result.seat == null) return;
        _applyOnlineZhaoSelf(result);
        break;
    }
  }

  /// 其他玩家招自己手牌的 4 张同字牌（自己的回声已被过滤）
  void _applyOnlineZhaoSelf(OnlineActionResult result) {
    final local = _mapper.toLocal(result.seat!);
    if (local < 0 || local >= state.players.length) return;
    if (local == 1) return; // 自己的招手牌已本地处理
    final character = result.character;
    if (character == null || character.isEmpty) return;
    final player = state.players[local];
    var removed = 0;
    for (var i = player.hand.length - 1; i >= 0 && removed < 4; i--) {
      player.hand.removeAt(i);
      removed++;
    }
    final zhaoCards = List.generate(4, (_) => _newOnlineCard(character));
    player.melds.add(
      Meld(
        cards: zhaoCards,
        type: MeldType.zhao,
        isJing: zhaoCards.first.isJing,
      ),
    );
    HuCalculator.updateMeldHuCache(player);
    _addToPublicCount(character, 4);
    state.currentPlayerIndex = local;
    onPlayerMeld?.call(zhaoCards, local);
    onStateChanged?.call();
    // 招后服务器会补发摸牌事件
  }

  /// 执行服务器裁决的碰/吃/招认领（对包括我在内的所有客户端统一生效）
  void _applyOnlineClaim(OnlineActionResult result) {
    final seatLocal = _mapper.toLocal(result.seat!);
    if (seatLocal < 0 || seatLocal >= state.players.length) return;
    final isMe = seatLocal == 1;
    final player = state.players[seatLocal];
    final discarderIdx = state.lastDiscardPlayerIndex;
    final claimedCard = state.lastDiscardedCard;
    if (discarderIdx == null || claimedCard == null) return;
    final discarder = state.players[discarderIdx];
    final char = claimedCard.character;

    state.waitingForResponse = false;
    state.isMyTurn = false;
    state.canChi = false;
    state.canPeng = false;
    state.canZhao = false;
    state.canHu = false;
    stopCountdown();

    // 招认领且已有坎：坎升级为招（无需动牌数）
    if (result.action == 'zhao') {
      final existingKan = player.melds
          .where(
            (m) => m.type == MeldType.kan && m.cards.first.character == char,
          )
          .toList();
      if (existingKan.isNotEmpty) {
        discarder.discards.remove(claimedCard);
        _addToPublicCount(char, -1);
        final oldMeld = existingKan.first;
        player.melds.remove(oldMeld);
        _addToPublicCount(char, -3);
        final newCards = List<Card>.from(oldMeld.cards)..add(claimedCard);
        player.melds.add(
          Meld(cards: newCards, type: MeldType.zhao, isJing: claimedCard.isJing),
        );
        HuCalculator.updateMeldHuCache(player);
        _addToPublicCount(char, 4);
        state.currentPlayerIndex = seatLocal;
        onPlayerMeld?.call(newCards, seatLocal);
        onStateChanged?.call();
        return; // 招后由服务器补发摸牌
      }
    }

    List<Card> meldCards;
    MeldType meldType;
    int handRemoveCount;
    if (result.action == 'peng') {
      meldCards = [claimedCard, _newOnlineCard(char), _newOnlineCard(char)];
      meldType = MeldType.kan;
      handRemoveCount = 2;
    } else if (result.action == 'zhao') {
      meldCards = [
        claimedCard,
        _newOnlineCard(char),
        _newOnlineCard(char),
        _newOnlineCard(char),
      ];
      meldType = MeldType.zhao;
      handRemoveCount = 3;
    } else if (result.action == 'chi') {
      final chars = (result.meldCards != null && result.meldCards!.isNotEmpty)
          ? result.meldCards!
          : [char];
      meldCards = chars.map(_newOnlineCard).toList();
      meldType = MeldType.ju;
      handRemoveCount = chars.where((c) => c != char).length;
    } else {
      return;
    }

    // 从弃牌区移除被认领的牌
    discarder.discards.remove(claimedCard);
    _addToPublicCount(char, -1);

    // 从认领者手牌移除对应牌
    if (isMe) {
      if (result.action == 'chi') {
        for (final c in meldCards) {
          if (c.character == char) continue;
          final idx = player.hand.indexWhere((h) => h.character == c.character);
          if (idx >= 0) player.hand.removeAt(idx);
        }
      } else {
        var removed = 0;
        for (var i = player.hand.length - 1;
            i >= 0 && removed < handRemoveCount;
            i--) {
          if (player.hand[i].character == char) {
            player.hand.removeAt(i);
            removed++;
          }
        }
      }
    } else {
      // 其他玩家手牌为牌背占位，按数量移除
      var removed = 0;
      for (var i = player.hand.length - 1;
          i >= 0 && removed < handRemoveCount;
          i--) {
        player.hand.removeAt(i);
        removed++;
      }
    }

    player.melds.add(
      Meld(
        cards: meldCards,
        type: meldType,
        isJing: meldCards.any((c) => c.isJing),
      ),
    );
    HuCalculator.updateMeldHuCache(player);
    for (final c in meldCards) {
      _addToPublicCount(c.character, 1);
    }
    state.currentPlayerIndex = seatLocal;
    onPlayerMeld?.call(meldCards, seatLocal);

    if (isMe) {
      final tingResult = TingChecker.checkTing(player);
      player.isTing = tingResult.isTing;
      player.tingCards = tingResult.tingCards;
      player.tingType = tingResult.tingType;
      player.huCount = HuCalculator.calculateTotalHu(player);
    }
    onStateChanged?.call();

    if (meldType == MeldType.zhao) {
      return; // 招后由服务器补发摸牌
    }

    // 碰/吃：认领者不摸牌直接出牌
    if (isMe) {
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
    }
  }

  @override
  void onOnlineHu(OnlineHuEvent event) {
    final winnerLocal = _mapper.toLocal(event.seat);
    final dianpaoLocal = event.fromSeat != null
        ? _mapper.toLocal(event.fromSeat!)
        : null;
    if (winnerLocal == 1) {
      // 我是赢家：本地状态完整，直接结算（分数与广播的 winnerData 一致）
      _handleHu(
        1,
        isZimo: event.zimo,
        dianpaoIndex: dianpaoLocal,
        zimoCard: event.zimo ? _lastDrawnCard : null,
      );
      return;
    }
    _handleOnlineHuRemote(event, winnerLocal, dianpaoLocal);
  }

  /// 其他玩家胡牌：用广播的 winnerData 重建赢家手牌并统一结算
  void _handleOnlineHuRemote(
    OnlineHuEvent event,
    int winnerLocal,
    int? dianpaoLocal,
  ) {
    stopCountdown();
    state.isHandlingHu = true;
    state.canChi = false;
    state.canPeng = false;
    state.canZhao = false;
    state.canHu = false;
    state.isMyTurn = false;
    state.waitingForResponse = false;

    final winner = state.players[winnerLocal];
    final data = event.winnerData;

    // 重建赢家手牌（含胡牌那张，供胡牌面板明牌显示）
    winner.hand.clear();
    final handChars = data?['hand'];
    if (handChars is List) {
      for (final ch in handChars) {
        if (ch is String) winner.hand.add(_newOnlineCard(ch));
      }
    }
    winner.sortHand();

    // 点炮：弃牌区的牌归入赢家（重建手牌已含该牌，弃牌区需移除）
    if (!event.zimo &&
        dianpaoLocal != null &&
        state.lastDiscardedCard != null) {
      final discarder = state.players[dianpaoLocal];
      discarder.discards.remove(state.lastDiscardedCard);
      _addToPublicCount(state.lastDiscardedCard!.character, -1);
    }

    // 结算数据：优先使用赢家客户端计算并广播的 winnerData
    final huTypeName = (data?['huType'] as String?) ?? '';
    final totalHu = (data?['huCount'] as num?)?.toInt() ?? 0;
    final displayMultiplier = (data?['multiplier'] as num?)?.toInt() ?? 0;
    final scoreChanges = <int, int>{};
    final rawChanges = data?['scoreChanges'];
    if (rawChanges is Map) {
      rawChanges.forEach((key, value) {
        final seat = int.tryParse(key.toString());
        final v = value is int
            ? value
            : (value is num ? value.toInt() : null);
        if (seat != null && v != null) {
          final local = _mapper.toLocal(seat);
          if (local >= 0 && local < state.players.length) {
            scoreChanges[local] = v;
          }
        }
      });
    }
    if (scoreChanges.isEmpty) {
      // 兜底：winnerData 缺失时本地计算（手牌已重建，结果一致）
      final huTypeResult = HuCalculator.detectHuType(
        winner,
        paoCard: event.zimo ? null : state.lastDiscardedCard,
      );
      scoreChanges.addAll(
        ScoreCalculator.calculateScores(
          state,
          winnerLocal,
          dianpaoLocal,
          event.zimo,
          huTypeResult,
        ),
      );
    }

    if (event.zimo) {
      _audio.playZimo(
        voiceType: AudioManager.voiceTypeFromGender(winner.gender),
      );
    } else {
      _audio.playHu(voiceType: AudioManager.voiceTypeFromGender(winner.gender));
    }
    if (huTypeName.isNotEmpty) {
      _audio.playHuType(
        huTypeName,
        voiceType: AudioManager.voiceTypeFromGender(winner.gender),
        delayMs: 800,
      );
    }

    final oldScores = <int, int>{};
    for (final p in state.players) {
      oldScores[p.id] = p.score;
    }
    for (final entry in scoreChanges.entries) {
      state.players[entry.key].score += entry.value;
    }

    winner.huCount = totalHu;
    final method = event.zimo ? '自摸' : '点炮';
    state.roundHistory.add({
      'roundNumber': state.roundNumber,
      'winner': winner.name,
      'winnerIndex': winnerLocal,
      'huType': huTypeName,
      'method': method,
      'multiplier': displayMultiplier,
      'score': scoreChanges[winnerLocal] ?? 0,
      'piaoScores': state.players.map((p) => p.piao).toList(),
      'isLiuJu': false,
      'scoreChanges': List<int>.from(
        state.players.map((p) => scoreChanges[p.id] ?? 0),
      ),
      'huCount': totalHu,
      'dianpaoIndex': dianpaoLocal,
      'dealerIndex': state.dealerIndex,
    });

    state.huResultWinnerName = winner.name;
    state.huResultWinnerIndex = winnerLocal;
    state.huResultMethod = method;
    state.huResultHuType = huTypeName;
    state.huResultHuCount = totalHu;
    state.huResultMultiplier = displayMultiplier;
    state.huResultScore = scoreChanges[winnerLocal] ?? 0;
    state.huResultScoreChanges = scoreChanges;
    state.huResultOldScores = oldScores;
    state.huResultDianpaoIndex = dianpaoLocal;
    if (!event.zimo && dianpaoLocal != null) {
      state.huResultDianpaoName = state.players[dianpaoLocal].name;
      state.huResultDianpaoCard = state.lastDiscardedCard;
      state.huResultZimoCard = null;
    } else {
      state.huResultDianpaoName = null;
      state.huResultDianpaoCard = null;
      state.huResultZimoCard = (event.card != null && event.card!.isNotEmpty)
          ? _newOnlineCard(event.card!)
          : null;
    }
    state.isHandlingHu = false;
    state.showHuResult = true;
    onShowHu?.call();
    onStateChanged?.call();
  }

  @override
  void onOnlineLiuju() {
    state.waitingForResponse = false;
    state.canChi = false;
    state.canPeng = false;
    state.canZhao = false;
    state.canHu = false;
    state.isMyTurn = false;
    _handleLiuju();
  }

  @override
  void onOnlinePlayerDisconnect(int seat, String name) {
    stopCountdown();
    state.showHuResult = false;
    state.showLiujuResult = false;
    state.gameStarted = false;
    _syncManager?.detachGameDelegate();
    _syncManager = null;
    state.isOnline = false;
    onOnlineGameEnd?.call(
      name.isEmpty ? '有玩家掉线，对局已结束' : '玩家「$name」掉线，对局已结束',
    );
  }
}
