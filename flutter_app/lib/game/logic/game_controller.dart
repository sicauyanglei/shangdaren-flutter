import 'dart:async';
import 'dart:math';
import '../core/game_logger.dart';
import '../models/card.dart';
import '../models/meld.dart';
import '../models/player.dart';
import '../models/game_state.dart';
import '../models/game_recording.dart';
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

  // ========== 录制相关 ==========
  bool _isRecording = false;
  bool get isRecording => _isRecording;
  Stopwatch? _roundStopwatch; // 每局独立的计时器
  List<RecordedAction> _currentRoundActions = [];
  List<RoundRecording> _completedRoundRecordings = [];
  List<int> _currentRoundDeckOrder = [];
  int _currentRoundDealerIndex = 0;
  List<int> _currentRoundPlayerGenders = [];
  List<int> _currentRoundPlayerScores = [];
  List<int> _currentRoundPlayerPiao = [];
  int _currentRoundBaseScore = 5;
  int _currentRoundMultiplierBase = 2;
  String _currentRoundDifficulty = 'hard';
  bool _currentRoundPiaoEnabled = false;
  Map<String, dynamic>? _currentRoundResult;

  // ========== 回放相关 ==========
  bool _isReplayMode = false;
  bool get isReplayMode => _isReplayMode;
  int _replayViewingPlayer = 1; // 回放视角（0/1/2）
  int get replayViewingPlayer => _replayViewingPlayer;
  List<RecordedAction> _replayActions = [];
  int _replayActionIndex = 0;
  double _replaySpeed = 1.0;
  double get replaySpeed => _replaySpeed;
  bool _replayPaused = false;
  bool get replayPaused => _replayPaused;
  Timer? _replayTimer;
  VoidCallback? onReplayStateChanged;

  // 每个玩家的操作延迟（毫秒），默认1000ms
  List<int> _replayPlayerDelays = [1000, 1000, 1000];
  List<int> get replayPlayerDelays => List.unmodifiable(_replayPlayerDelays);

  void setReplayPlayerDelay(int playerIndex, int delayMs) {
    if (playerIndex < 0 || playerIndex >= 3) return;
    _replayPlayerDelays[playerIndex] = delayMs.clamp(200, 5000);
    onReplayStateChanged?.call();
  }

  GameController({GameState? gameState, AIController? aiCtrl})
    : state = gameState ?? GameState(),
      aiController = aiCtrl ?? AIController();

  /// 开始录制
  void startRecording() {
    _isRecording = true;
    _completedRoundRecordings = [];
  }

  /// 停止录制并返回整场录制数据
  GameRecording? stopRecording() {
    if (!_isRecording) return null;
    _isRecording = false;
    _roundStopwatch?.stop();
    _roundStopwatch = null;

    // 保存当前未完成的局
    _finalizeCurrentRoundRecording();

    if (_completedRoundRecordings.isEmpty) return null;

    final recording = GameRecording(
      id: 'rec_${DateTime.now().millisecondsSinceEpoch}',
      createdAt: DateTime.now(),
      rounds: List.from(_completedRoundRecordings),
    );
    _completedRoundRecordings = [];
    return recording;
  }

  /// 开始新一局的录制
  void _startRoundRecording() {
    if (!_isRecording) return;
    _roundStopwatch = Stopwatch()..start();
    _currentRoundActions = [];
    _currentRoundDealerIndex = state.dealerIndex;
    _currentRoundPlayerGenders = state.players.map((p) => p.gender == Gender.male ? 0 : 1).toList();
    _currentRoundPlayerScores = state.players.map((p) => p.score).toList();
    _currentRoundPlayerPiao = state.players.map((p) => p.piao).toList();
    _currentRoundBaseScore = state.baseScore;
    _currentRoundMultiplierBase = state.multiplierBase;
    _currentRoundDifficulty = state.difficulty;
    _currentRoundPiaoEnabled = state.piaoEnabled;
    _currentRoundResult = null;
  }

  /// 完成当前局的录制
  void _finalizeCurrentRoundRecording() {
    if (!_isRecording || _currentRoundDeckOrder.isEmpty) return;
    _roundStopwatch?.stop();

    _completedRoundRecordings.add(RoundRecording(
      roundNumber: state.roundNumber,
      dealerIndex: _currentRoundDealerIndex,
      deckOrder: List.from(_currentRoundDeckOrder),
      playerGenders: List.from(_currentRoundPlayerGenders),
      playerScores: List.from(_currentRoundPlayerScores),
      playerPiao: List.from(_currentRoundPlayerPiao),
      baseScore: _currentRoundBaseScore,
      multiplierBase: _currentRoundMultiplierBase,
      difficulty: _currentRoundDifficulty,
      piaoEnabled: _currentRoundPiaoEnabled,
      actions: List.from(_currentRoundActions),
      roundResult: _currentRoundResult,
    ));

    _currentRoundActions = [];
    _currentRoundDeckOrder = [];
  }

  /// 记录一个动作
  void _recordAction(RecordedActionType type, int playerIndex, Map<String, dynamic> data) {
    if (!_isRecording || _roundStopwatch == null) return;
    _currentRoundActions.add(RecordedAction(
      type: type,
      playerIndex: playerIndex,
      data: data,
      elapsedMs: _roundStopwatch!.elapsedMilliseconds,
    ));
  }

  /// 记录本局结果
  void _recordRoundResult(Map<String, dynamic> result) {
    _currentRoundResult = result;
  }

  /// 开始回放单局
  void startRoundReplay(RoundRecording roundRecording) {
    _isReplayMode = true;
    _replayActions = List.from(roundRecording.actions);
    _replayActionIndex = 0;
    _replaySpeed = 1.0;
    _replayPaused = false;
    _replayViewingPlayer = 1;

    // 使用录制的设置初始化
    state.baseScore = roundRecording.baseScore;
    state.multiplierBase = roundRecording.multiplierBase;
    state.difficulty = roundRecording.difficulty;
    state.piaoEnabled = roundRecording.piaoEnabled;

    // 使用录制的牌堆顺序
    _customDeckOrder = roundRecording.deckOrder;
    _customDealerIndex = roundRecording.dealerIndex;
    _customPlayerGenders = roundRecording.playerGenders;
    _customPlayerScores = roundRecording.playerScores;
    _customPlayerPiao = roundRecording.playerPiao;

    // 开始游戏
    startGame();

    // 启动回放驱动
    _startReplayDriver();
  }

  /// 退出回放模式
  void exitReplay() {
    _isReplayMode = false;
    _replayTimer?.cancel();
    _replayTimer = null;
    _replayActions = [];
    _replayActionIndex = 0;
    _replayPaused = false;
    _replayPlayerDelays = [1000, 1000, 1000];
    onReplayStateChanged?.call();
  }

  /// 回放暂停/继续
  void toggleReplayPause() {
    _replayPaused = !_replayPaused;
    onReplayStateChanged?.call();
    if (!_replayPaused) {
      _scheduleNextReplayAction();
    }
  }

  /// 设置回放速度
  void setReplaySpeed(double speed) {
    _replaySpeed = speed;
    onReplayStateChanged?.call();
  }

  /// 切换回放视角
  void setReplayViewingPlayer(int playerIndex) {
    _replayViewingPlayer = playerIndex;
    onReplayStateChanged?.call();
  }

  /// 回放单步前进
  void replayStepForward() {
    if (_replayActionIndex >= _replayActions.length) return;
    _replayPaused = true;
    _executeReplayAction(_replayActions[_replayActionIndex]);
    _replayActionIndex++;
    onReplayStateChanged?.call();
    // 单步模式下不自动调度下一步
  }

  /// 获取回放进度 (0.0 ~ 1.0)
  double get replayProgress {
    if (_replayActions.isEmpty) return 0;
    return _replayActionIndex / _replayActions.length;
  }

  /// 获取当前回放动作索引
  int get replayCurrentIndex => _replayActionIndex;

  /// 获取回放动作总数
  int get replayTotalActions => _replayActions.length;

  List<int>? _customDeckOrder;
  int? _customDealerIndex;
  List<int>? _customPlayerGenders;
  List<int>? _customPlayerScores;
  List<int>? _customPlayerPiao;

  void _startReplayDriver() {
    _replayTimer?.cancel();
    // 使用Future.delayed链式驱动，根据每个玩家的操作延迟来控制回放节奏
    _scheduleNextReplayAction();
  }

  void _scheduleNextReplayAction() {
    if (!_isReplayMode || _replayPaused) return;
    if (_replayActionIndex >= _replayActions.length) return;

    // 等待发牌完成
    if (!state.isDealingComplete || _isStartingRound || _isDealing) {
      Future.delayed(const Duration(milliseconds: 200), _scheduleNextReplayAction);
      return;
    }
    if (state.showHuResult || state.showLiujuResult) return;

    // 获取当前动作对应的玩家延迟
    final nextAction = _replayActions[_replayActionIndex];
    final playerDelay = _replayPlayerDelays[nextAction.playerIndex];
    final adjustedDelay = (playerDelay / _replaySpeed).round().clamp(50, 5000);

    Future.delayed(Duration(milliseconds: adjustedDelay), () {
      if (!_isReplayMode || _replayPaused) return;
      _feedNextReplayAction();
    });
  }

  void _feedNextReplayAction() {
    if (_replayActionIndex >= _replayActions.length) return;

    // 回放模式下，检查游戏是否在等待输入
    final waitingForInput = state.isMyTurn || state.waitingForResponse || state.isPiaoPhase ||
        (state.currentTurnPlayer().type == PlayerType.ai && !state.isDrawing && !state.showHuResult && !state.showLiujuResult);
    if (!waitingForInput) {
      // 游戏状态还没准备好，稍后重试
      Future.delayed(const Duration(milliseconds: 100), _scheduleNextReplayAction);
      return;
    }

    final action = _replayActions[_replayActionIndex];
    _executeReplayAction(action);
    _replayActionIndex++;
    onReplayStateChanged?.call();

    // 调度下一个动作
    _scheduleNextReplayAction();
  }

  void _executeReplayAction(RecordedAction action) {
    final player = state.players.isNotEmpty && action.playerIndex < state.players.length
        ? state.players[action.playerIndex]
        : null;

    switch (action.type) {
      case RecordedActionType.piao:
        setPiao(action.data['value'] as int? ?? 0);
        break;
      case RecordedActionType.discard:
        final cardId = action.data['cardId'] as int?;
        if (cardId != null && player != null) {
          final cardIndex = player.hand.indexWhere((c) => c.id == cardId);
          if (cardIndex >= 0) {
            if (player.type == PlayerType.human) {
              discardCard(cardIndex);
            } else {
              // AI玩家出牌，直接调用_doDiscard
              _doDiscard(player, player.hand[cardIndex]);
            }
          }
        }
        break;
      case RecordedActionType.hu:
      case RecordedActionType.zimo:
        // 人类玩家的胡/自摸由回放驱动器喂入
        // AI玩家的胡由_processResponses自动处理，跳过
        if (player != null && player.type == PlayerType.human) {
          respondHu();
        }
        break;
      case RecordedActionType.zhao:
        // 人类玩家的招由回放驱动器喂入
        // AI玩家的招由_processResponses自动处理，跳过
        if (player != null && player.type == PlayerType.human) {
          respondZhao();
        }
        break;
      case RecordedActionType.zhaoFromHand:
        // 手牌招（摸牌后招自己手牌的4张同字）
        if (player != null && player.type == PlayerType.human) {
          final character = action.data['character'] as String?;
          if (character != null) {
            selectZhaoCharacter(character);
          } else {
            respondZhao();
          }
        } else if (player != null && player.type == PlayerType.ai) {
          // AI手牌招，直接调用
          final character = action.data['character'] as String?;
          _handleZhaoFromHand(player, character: character);
        }
        break;
      case RecordedActionType.selectZhao:
        final ch = action.data['character'] as String?;
        if (ch != null) {
          selectZhaoCharacter(ch);
        }
        break;
      case RecordedActionType.peng:
        // 人类玩家的碰由回放驱动器喂入
        // AI玩家的碰由_processResponses自动处理，跳过
        if (player != null && player.type == PlayerType.human) {
          respondPeng();
        }
        break;
      case RecordedActionType.chi:
        // 人类玩家的吃由回放驱动器喂入
        // AI玩家的吃由_processResponses自动处理，跳过
        if (player != null && player.type == PlayerType.human) {
          respondChi();
        }
        break;
      case RecordedActionType.pass:
        // 人类玩家的过由回放驱动器喂入
        if (player != null && player.type == PlayerType.human) {
          respondPass();
        }
        break;
      case RecordedActionType.liuju:
      case RecordedActionType.roundEnd:
        // 这些是标记性动作，不需要执行
        break;
    }
  }

  void startGame() {
    print('=== GameController.startGame called ===');
    state.reset();
    _isStartingRound = false;
    if (state.difficulty == 'hard') {
      aiController = AIController(strategy: AIStrategyHard());
    } else {
      aiController = AIController();
    }

    // 使用自定义性别或随机性别
    final genders = _customPlayerGenders;
    state.players.addAll([
      Player(
        id: 0,
        name: '玩家1',
        type: PlayerType.ai,
        gender: genders != null && genders.length > 0
            ? (genders[0] == 0 ? Gender.male : Gender.female)
            : (_rng.nextBool() ? Gender.male : Gender.female),
      ),
      Player(
        id: 1,
        name: '我',
        type: PlayerType.human,
        gender: genders != null && genders.length > 1
            ? (genders[1] == 0 ? Gender.male : Gender.female)
            : (_rng.nextBool() ? Gender.male : Gender.female),
      ),
      Player(
        id: 2,
        name: '玩家2',
        type: PlayerType.ai,
        gender: genders != null && genders.length > 2
            ? (genders[2] == 0 ? Gender.male : Gender.female)
            : (_rng.nextBool() ? Gender.male : Gender.female),
      ),
    ]);

    // 使用自定义庄家或随机庄家
    state.dealerIndex = _customDealerIndex ?? Random().nextInt(3);
    state.roundNumber = 0;
    state.gameStarted = true;

    // 录制初始状态
    if (_isRecording) {
      _currentRoundDealerIndex = state.dealerIndex;
      _currentRoundPlayerGenders = state.players.map((p) => p.gender == Gender.male ? 0 : 1).toList();
    }

    // 回放模式：设置分数和飘分
    if (_isReplayMode) {
      if (_customPlayerScores != null && _customPlayerScores!.length == 3) {
        for (int i = 0; i < 3; i++) {
          state.players[i].score = _customPlayerScores![i];
        }
      }
      if (_customPlayerPiao != null && _customPlayerPiao!.length == 3) {
        for (int i = 0; i < 3; i++) {
          state.players[i].piao = _customPlayerPiao![i];
        }
      }
      _customPlayerScores = null;
      _customPlayerPiao = null;
    }

    // 清除自定义设置
    _customDealerIndex = null;
    _customPlayerGenders = null;

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

    state.deck = Card.createDeck();
    // 使用自定义牌堆顺序或随机洗牌
    if (_customDeckOrder != null && _customDeckOrder!.isNotEmpty) {
      // 根据录制的牌堆ID顺序重建牌堆
      final allCards = Card.createDeck(); // 创建一个完整的牌堆用于查找
      final cardMap = <int, Card>{for (final c in allCards) c.id: c};
      state.deck = _customDeckOrder!
          .map((id) => cardMap[id])
          .whereType<Card>()
          .toList();
      _customDeckOrder = null;
    } else {
      state.deck.shuffle();
    }

    // 录制牌堆顺序
    if (_isRecording) {
      _currentRoundDeckOrder = state.deck.map((c) => c.id).toList();
    }

    // 完成上一局录制，开始新一局录制
    if (_isRecording && state.roundNumber > 1) {
      _finalizeCurrentRoundRecording();
    }
    if (_isRecording) {
      _startRoundRecording();
    }

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
    if (!state.piaoEnabled || _isReplayMode) {
      // 飘分关闭或回放模式，直接发牌
      // 回放模式下飘分已从_customPlayerPiao设置
      if (!state.piaoEnabled) {
        for (final player in state.players) {
          player.piao = 0;
        }
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
        if (_isReplayMode) {
          // 回放模式下，AI飘分由回放驱动器喂入，不自动执行
          break;
        }
        // AI随机选择飘分
        final piaoOptions = [0, 5, 10, 20];
        final randomIndex = Random().nextInt(piaoOptions.length);
        final piaoValue = piaoOptions[randomIndex];
        player.piao = piaoValue;
        _recordAction(RecordedActionType.piao, state.piaoCurrentPlayerIndex, {'value': piaoValue});
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
    if (player.type != PlayerType.human && !_isReplayMode) return;

    _recordAction(RecordedActionType.piao, state.piaoCurrentPlayerIndex, {'value': piaoValue});
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
      if (_isReplayMode) {
        // 回放模式下，AI操作由回放驱动器喂入，不自动执行
        startCountdown();
      } else {
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
      }
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
      } else if (_getTotalCardCount(state.players[1]) >= 20) {
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

    if (_getTotalCardCount(player) >= 20) {
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
    if (player.type != PlayerType.human && !_isReplayMode) return;
    if (cardIndex < 0 || cardIndex >= player.hand.length) return;
    if (!state.isMyTurn && !_isReplayMode) return;
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
    // 录制出牌动作（AI和人类玩家都记录）
    _recordAction(RecordedActionType.discard, player.id, {'cardId': discardCard.id});
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
    final humanIndex = state.players.indexWhere(
      (p) => p.type == PlayerType.human,
    );
    _recordAction(RecordedActionType.pass, humanIndex >= 0 ? humanIndex : 1, {});
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
    if (state.waitingForResponse) {
      respondPass();
    } else if (state.isMyTurn) {
      // 超时时先清除招等操作状态，再出牌
      if (state.canZhao || state.canChi || state.canPeng || state.canHu) {
        state.canChi = false;
        state.canPeng = false;
        state.canZhao = false;
        state.canHu = false;
      }

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
    _recordAction(
      isZimo ? RecordedActionType.zimo : RecordedActionType.hu,
      winnerIndex,
      {'isZimo': isZimo, 'dianpaoIndex': dianpaoIndex},
    );
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

    // 录制本局结果
    _recordRoundResult(state.roundHistory.last);

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
    _recordAction(RecordedActionType.liuju, 0, {});
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

    // 录制本局结果
    _recordRoundResult(state.roundHistory.last);

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
    _recordAction(RecordedActionType.zhaoFromHand, player.id, {'character': character});
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
    _recordAction(RecordedActionType.zhao, playerIndex, {'cardId': card.id});
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
    _recordAction(RecordedActionType.peng, playerIndex, {'cardId': card.id});

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
      _addToPublicCount(card.character, -1);

      player.melds.add(
        Meld(cards: pengCards, type: MeldType.kan, isJing: card.isJing),
      );
      HuCalculator.updateMeldHuCache(player);
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
    _recordAction(RecordedActionType.chi, playerIndex, {'cardId': card.id});

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
      _addToPublicCount(card.character, -1);

      player.melds.add(
        Meld(
          cards: meldCards,
          type: MeldType.ju,
          isJing: meldCards.any((c) => c.isJing),
        ),
      );
      HuCalculator.updateMeldHuCache(player);
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
    if (_getTotalCardCount(player) < 20) return false;
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
    return player.hand.length + player.melds.length * 3;
  }

  bool _canHuWith(Player player, Card card) {
    if (_getTotalCardCount(player) >= 20) return false;
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
    if (_getTotalCardCount(player) >= 20) return false;
    final count = player.hand
        .where((c) => c.character == card.character)
        .length;
    return count >= 2;
  }

  bool _canZhaoWith(Player player, Card card) {
    if (_getTotalCardCount(player) != 19) return false;
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
    if (_getTotalCardCount(player) >= 20) return false;
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
