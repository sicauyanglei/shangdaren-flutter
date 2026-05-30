import 'dart:ui';
import 'package:flame/components.dart';
import 'package:flame/flame.dart';
import 'package:flame/game.dart';
import 'package:flutter/services.dart';
import 'core/atlas_loader.dart';
import 'core/audio_manager.dart';
import 'core/game_ticker.dart';
import 'core/stretch_viewport.dart';
import 'models/card.dart';
import 'models/game_state.dart';
import 'models/meld.dart';
import 'logic/game_controller.dart';
import 'render/animation_system.dart';
import 'render/card_render.dart';
import 'render/game_board.dart';

typedef VoidCallback = void Function();
typedef IntCallback = void Function(int);
typedef CardCallback = void Function(Card);
typedef CardsCallback = void Function(List<Card>, int);
typedef CardAnimCallback =
    void Function(Card card, int playerId, String animType);
typedef MeldAnimCallback =
    void Function(List<Card> cards, int playerId, String meldType);

class ShangdarenGame extends FlameGame {
  static const double designWidth = 1280.0;
  static const double designHeight = 720.0;

  static const double avatar0ScoreX = 9.6 + 20 + 80 + 12 + 30;
  static const double avatar0ScoreY = 4.8 + 14 + 24 + 4 + 10;
  static const double avatar1ScoreX = 10 + 20 + 80 + 12 + 30;
  static const double avatar1ScoreY = 720.0 - 5 - 14 - 24 - 4 - 10;
  static const double avatar2ScoreX = 1280.0 - 9.6 - 20 - 30;
  static const double avatar2ScoreY = 4.8 + 14 + 24 + 4 + 10;
  static const double huPanelScoreX = 640.0;
  static const double huPanelScoreY = 360.0 + 50.0;

  AtlasLoader? _atlasLoader;
  GameTicker? _gameTicker;
  GameBoard? _gameBoard;
  AnimationSystem? _animationSystem;
  GameController? _gameController;

  Image? _atlasImage;
  final Map<String, Image> _smallCardImages = {};
  final Map<String, Image> _horizontalCardImages = {};
  final Map<String, Image> _handCardImages = {};
  bool _loaded = false;

  Card? _lastPlayedCard;
  int? _selectedCardIndex;
  Card? _selectedCard;

  bool _isDragging = false;
  Card? _dragCard;
  int? _dragCardIndex;
  double _dragX = 0;
  double _dragY = 0;
  double _dragOffsetX = 0;
  double _dragOffsetY = 0;
  double _dragStartX = 0;
  double _dragStartY = 0;
  double _dragOriginalX = 0;
  double _dragOriginalY = 0;
  static const double _dragThreshold = 10.0;
  bool _scoreAnimPlayed = false;

  bool get isDragging => _isDragging;
  Card? get dragCard => _dragCard;
  double get dragX => _dragX;
  double get dragY => _dragY;

  void handleDragStart(Offset globalPosition) {
    if (!_loaded || _gameController == null || _gameBoard == null) return;

    final state = _gameController!.state;
    if (!state.isMyTurn || state.isDrawing) return;
    if (state.waitingForResponse) return;
    if (state.canChi || state.canPeng || state.canZhao || state.canHu) return;

    final gamePos = camera.globalToLocal(
      Vector2(globalPosition.dx, globalPosition.dy),
    );

    final me = state.players[1];
    if (me.hand.isEmpty) return;

    final hitCard = _gameBoard!.hitTestHand(gamePos.x, gamePos.y);
    if (hitCard == null) return;

    int? hitIndex;
    for (int i = 0; i < me.hand.length; i++) {
      if (me.hand[i] == hitCard) {
        hitIndex = i;
        break;
      }
    }
    if (hitIndex == null) return;

    _dragCard = hitCard;
    _dragCardIndex = hitIndex;
    _isDragging = true;
    _dragStartX = gamePos.x;
    _dragStartY = gamePos.y;

    final cardPos = _gameBoard!.getCardPosition(hitCard);
    if (cardPos != null) {
      _dragX = cardPos.dx;
      _dragY = cardPos.dy;
      _dragOriginalX = cardPos.dx;
      _dragOriginalY = cardPos.dy;
      _dragOffsetX = gamePos.x - cardPos.dx;
      _dragOffsetY = gamePos.y - cardPos.dy;
    } else {
      _dragX = gamePos.x;
      _dragY = gamePos.y;
      _dragOriginalX = gamePos.x;
      _dragOriginalY = gamePos.y;
      _dragOffsetX = 0;
      _dragOffsetY = 0;
    }

    _selectedCard = hitCard;
    _selectedCardIndex = hitIndex;
    _syncBoard();
  }

  void handleDragUpdate(Offset globalPosition) {
    if (!_isDragging || _dragCard == null) return;

    final gamePos = camera.globalToLocal(
      Vector2(globalPosition.dx, globalPosition.dy),
    );

    _dragX = gamePos.x - _dragOffsetX;
    _dragY = gamePos.y - _dragOffsetY;
  }

  void handleDragEnd(Offset globalPosition) {
    if (!_isDragging) return;

    final gamePos = camera.globalToLocal(
      Vector2(globalPosition.dx, globalPosition.dy),
    );

    final dx = (gamePos.x - _dragStartX).abs();
    final dy = (gamePos.y - _dragStartY).abs();

    if (dx < _dragThreshold && dy < _dragThreshold) {
      final previousSelected = _selectedCard;
      _selectedCard = null;
      _selectedCardIndex = null;
      if (_dragCard != null && _dragCardIndex != null) {
        if (previousSelected == _dragCard) {
          _gameController!.discardCard(_dragCardIndex!);
        }
      }
      _isDragging = false;
      _dragCard = null;
      _dragCardIndex = null;
      _dragX = 0;
      _dragY = 0;
      _gameBoard!.setDragState(false, null, null, 0, 0);
      _gameBoard!.setSelected(1, null);
      _syncBoard();
      return;
    }

    final handArea = _gameBoard!.getPlayer1HandArea();

    final isOutside =
        gamePos.x < handArea.left ||
        gamePos.x > handArea.right ||
        gamePos.y < handArea.top ||
        gamePos.y > handArea.bottom;

    if (isOutside && _dragCardIndex != null) {
      _gameController!.discardCard(_dragCardIndex!);
    }

    _selectedCard = null;
    _selectedCardIndex = null;
    _isDragging = false;
    _dragCard = null;
    _dragCardIndex = null;
    _dragX = 0;
    _dragY = 0;
    _gameBoard!.setDragState(false, null, null, 0, 0);
    _gameBoard!.setSelected(1, null);
    _syncBoard();
  }

  void handleDragCancel() {
    _selectedCard = null;
    _selectedCardIndex = null;
    _isDragging = false;
    _dragCard = null;
    _dragCardIndex = null;
    _dragX = 0;
    _dragY = 0;
    _dragOffsetX = 0;
    _dragOffsetY = 0;
    _dragStartX = 0;
    _dragStartY = 0;
    _dragOriginalX = 0;
    _dragOriginalY = 0;
    _gameBoard!.setDragState(false, null, null, 0, 0);
    _gameBoard!.setSelected(1, null);
    _syncBoard();
  }

  void handleTapAt(Offset globalPosition) {
    if (!_loaded || _gameController == null || _gameBoard == null) return;

    final state = _gameController!.state;
    if (state.showHuResult || state.showLiujuResult) {
      final gamePos = camera.globalToLocal(
        Vector2(globalPosition.dx, globalPosition.dy),
      );
      if (_gameBoard!.hitTestHuPanelCloseBtn(gamePos.x, gamePos.y)) {
        onHuCloseFromPanel?.call();
        return;
      }
      return;
    }

    if (!state.isMyTurn || state.isDrawing) return;

    final gamePos = camera.globalToLocal(
      Vector2(globalPosition.dx, globalPosition.dy),
    );

    final me = state.players[1];
    if (me.hand.isEmpty) return;

    final hitCard = _gameBoard!.hitTestHand(gamePos.x, gamePos.y);
    if (hitCard == null) return;

    final hitIndex = me.hand.indexOf(hitCard);
    if (hitIndex < 0) return;

    _dragCard = hitCard;
    _dragCardIndex = hitIndex;
  }

  VoidCallback? onGameStateChanged;
  VoidCallback? onShowStartScreen;
  VoidCallback? onShowSettlement;
  VoidCallback? onShowHu;
  VoidCallback? onHuCloseFromPanel;
  VoidCallback? onShowLiuju;
  VoidCallback? onShowPiao;
  VoidCallback? onPiaoPhaseComplete;
  void Function(int playerId)? onScoreArrive;

  ShangdarenGame()
    : super(
        camera: CameraComponent(
          viewport: StretchViewport(
            resolution: Vector2(designWidth, designHeight),
          ),
        ),
      );

  @override
  bool get isLoaded => _loaded;

  double get viewScaleX {
    final vp = camera.viewport;
    if (vp is StretchViewport) {
      return vp.scale.x;
    }
    return camera.viewfinder.zoom;
  }

  double get viewScaleY {
    final vp = camera.viewport;
    if (vp is StretchViewport) {
      return vp.scale.y;
    }
    return camera.viewfinder.zoom;
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    camera.viewfinder.anchor = Anchor.topLeft;
    camera.viewfinder.position = Vector2.zero();

    _atlasLoader = AtlasLoader();
    await _atlasLoader!.load();

    _atlasImage = await Flame.images.load('atlas.webp');

    CardRender.atlasImage = _atlasImage;
    CardRender.atlasLoader = _atlasLoader;

    for (final entry in AtlasLoader.charToPinyin.entries) {
      final char = entry.key;
      final pinyin = entry.value;
      try {
        final data = await rootBundle.load('assets/html/images/s/$pinyin.png');
        final bytes = data.buffer.asUint8List();
        final codec = await instantiateImageCodec(bytes);
        final frame = await codec.getNextFrame();
        _smallCardImages[char] = frame.image;
      } catch (_) {}
      try {
        final data = await rootBundle.load('assets/html/images/v/$pinyin.png');
        final bytes = data.buffer.asUint8List();
        final codec = await instantiateImageCodec(bytes);
        final frame = await codec.getNextFrame();
        _horizontalCardImages[char] = frame.image;
      } catch (_) {}
      try {
        final data = await rootBundle.load('assets/html/images/$pinyin.png');
        final bytes = data.buffer.asUint8List();
        final codec = await instantiateImageCodec(bytes);
        final frame = await codec.getNextFrame();
        _handCardImages[char] = frame.image;
      } catch (_) {}
    }

    _gameTicker = GameTicker();
    _gameBoard = GameBoard();
    _animationSystem = AnimationSystem();
    _animationSystem!.atlasImage = _atlasImage;
    _animationSystem!.atlasLoader = _atlasLoader;

    _gameBoard!.setAtlas(_atlasImage!, _atlasLoader!);
    _gameBoard!.setSmallCardImages(_smallCardImages);
    _gameBoard!.setHorizontalCardImages(_horizontalCardImages);
    _gameBoard!.setHandCardImages(_handCardImages);

    world.add(_gameBoard!);
    world.add(_animationSystem!);

    _gameController = GameController();
    _gameController!.onStateChanged = _onStateChanged;
    _gameController!.onPlayerDraw = _onPlayerDraw;
    _gameController!.onPlayerDiscard = _onPlayerDiscard;
    _gameController!.onPlayerMeld = _onPlayerMeld;
    _gameController!.onShowHu = _onShowHu;
    _gameController!.onShowSettlement = _onShowSettlement;
    _gameController!.onLiuju = _onLiuju;
    _gameController!.onCardAnimation = _onCardAnimation;
    _gameController!.onMeldAnimation = _onMeldAnimation;

    await AudioManager().init();

    _loaded = true;
  }

  void startGame({
    int baseScore = 5,
    int multiplierBase = 2,
    String difficulty = 'hard',
    bool piaoEnabled = false,
  }) {
    if (!_loaded) return;
    _gameController!.state.baseScore = baseScore;
    _gameController!.state.multiplierBase = multiplierBase;
    _gameController!.state.difficulty = difficulty;
    _gameController!.state.piaoEnabled = piaoEnabled;
    _gameController!.startGame();
  }

  void startRound() {
    if (!_loaded) return;
    _lastPlayedCard = null;
    _scoreAnimPlayed = false;
    _gameBoard!.clearLastDiscard();
    _gameController!.startRound();
  }

  void discardCard(int cardIndex) {
    if (!_loaded) return;
    _gameController!.discardCard(cardIndex);
  }

  void respondHu() {
    if (!_loaded) return;
    _gameController!.respondHu();
  }

  void respondZhao() {
    if (!_loaded) return;
    _gameController!.respondZhao();
  }

  void selectZhaoCharacter(String character) {
    if (!_loaded) return;
    _gameController!.selectZhaoCharacter(character);
  }

  void respondPeng() {
    if (!_loaded) return;
    _gameController!.respondPeng();
  }

  void respondChi() {
    if (!_loaded) return;
    _gameController!.respondChi();
  }

  void respondPass() {
    if (!_loaded) return;
    _gameController!.respondPass();
  }

  void setPiao(int piaoValue) {
    if (!_loaded) return;
    _gameController!.setPiao(piaoValue);
  }

  GameState get gameState => _gameController?.state ?? GameState();
  GameController? get gameController => _gameController;

  void _onStateChanged() {
    _syncBoard();
    onGameStateChanged?.call();
  }

  void _onPlayerDraw(int playerId) {
    if (playerId == 1 && _gameController!.state.isMyTurn) {
      _gameBoard!.setTingBadge(1, false);
    }
    _syncBoard();
  }

  void _onPlayerDiscard(Card card) {
    _lastPlayedCard = card;
    _syncBoard();
  }

  void _onPlayerMeld(List<Card> cards, int playerId) {
    _lastPlayedCard = null;
    if (playerId == 1) {
      final player = _gameController!.state.players[1];
      if (player.isTing && player.tingCards.isNotEmpty) {
        _gameBoard!.setTingBadge(1, true);
      }
    }
    _syncBoard();
  }

  void _onShowHu() {
    onShowHu?.call();
    onGameStateChanged?.call();
  }

  void _onShowSettlement() {
    onShowSettlement?.call();
  }

  void _onLiuju() {
    onShowLiuju?.call();
    onGameStateChanged?.call();
  }

  void handleLiujuClose() {
    _lastPlayedCard = null;
    _scoreAnimPlayed = false;
    _gameBoard?.clearLastDiscard();
    _gameController?.handleLiujuClose();
  }

  void handleHuClose() {
    _lastPlayedCard = null;
    _scoreAnimPlayed = false;
    _gameBoard?.clearLastDiscard();
    _gameController?.handleHuClose();
  }

  void pauseGame() {
    _gameController?.pauseGame();
  }

  void resumeGame() {
    _gameController?.resumeGame();
  }

  void _onCardAnimation(Card card, int playerId, String animType) {
    if (_animationSystem == null) return;

    final state = _gameController!.state;
    double deckX, deckY;
    if (state.isDealingComplete) {
      deckX = designWidth / 2 - 40;
      deckY = 9.6;
    } else {
      deckX = designWidth / 2 - 75;
      deckY = designHeight / 2 - 17.5;
    }

    final centerX = designWidth / 2 - 20;
    final centerY = designHeight / 2 - 84;

    if (animType == 'deal') {
      double toX, toY;
      bool faceUp;
      double scale;
      if (playerId == 0) {
        final target =
            _gameBoard?.getAIHandDrawTarget(0) ?? const Offset(60, 276);
        toX = target.dx;
        toY = target.dy;
        faceUp = false;
        scale = 0.5;
      } else if (playerId == 1) {
        toX = designWidth / 2 - 20;
        toY = designHeight - 178;
        faceUp = true;
        scale = 1.0;
      } else {
        final target =
            _gameBoard?.getAIHandDrawTarget(2) ?? const Offset(1220, 276);
        toX = target.dx;
        toY = target.dy;
        faceUp = false;
        scale = 0.5;
      }
      _animationSystem!.flyCard(
        card: card,
        fromX: deckX,
        fromY: deckY,
        toX: toX,
        toY: toY,
        faceUp: faceUp,
        scaleX: scale,
        scaleY: scale,
        duration: 0.2,
      );
    } else if (animType == 'draw') {
      double handX, handY;
      bool faceUp;
      double handScale;
      bool showMo;
      double? handDestW;
      double? handDestH;
      if (playerId == 0) {
        final target =
            _gameBoard?.getAIHandDrawTarget(0) ?? const Offset(60, 276);
        handX = target.dx;
        handY = target.dy;
        faceUp = false;
        handScale = 0.5;
        showMo = false;
        handDestW = GameBoard.meldCardW;
        handDestH = GameBoard.meldCardH;
      } else if (playerId == 1) {
        handX = designWidth / 2 - 20;
        handY = designHeight - 178;
        faceUp = true;
        handScale = 1.0;
        showMo = true;
      } else {
        final target =
            _gameBoard?.getAIHandDrawTarget(2) ?? const Offset(1220, 276);
        handX = target.dx;
        handY = target.dy;
        faceUp = false;
        handScale = 0.5;
        showMo = false;
        handDestW = GameBoard.meldCardW;
        handDestH = GameBoard.meldCardH;
      }
      _animationSystem!.drawCardAnim(
        card: card,
        deckX: deckX,
        deckY: deckY,
        centerX: centerX,
        centerY: centerY,
        handX: handX,
        handY: handY,
        faceUp: faceUp,
        handScale: handScale,
        showMoLabel: showMo,
        handDestW: handDestW,
        handDestH: handDestH,
      );
    } else if (animType == 'discard') {
      double fromX, fromY;
      if (playerId == 0) {
        final target =
            _gameBoard?.getAIHandDrawTarget(0) ?? const Offset(60, 276);
        fromX = target.dx;
        fromY = target.dy;
      } else if (playerId == 1) {
        fromX = designWidth / 2 - 20;
        fromY = designHeight - 178;
      } else {
        final target =
            _gameBoard?.getAIHandDrawTarget(2) ?? const Offset(1220, 276);
        fromX = target.dx;
        fromY = target.dy;
      }
      _animationSystem!.flyCard(
        card: card,
        fromX: fromX,
        fromY: fromY,
        toX: centerX,
        toY: centerY,
        faceUp: true,
        duration: 0.3,
      );
    }
  }

  void _onMeldAnimation(List<Card> cards, int playerId, String meldType) {
    if (_animationSystem == null || _gameBoard == null) return;

    if (playerId == 1) {
      _gameBoard!.setTingBadge(1, false);
    }

    final centerX = designWidth / 2;
    final centerY = designHeight / 2;

    double discardX = centerX - 15;
    double discardY = 5.0;
    double playerHandX = centerX;
    double playerHandY = designHeight - 178;

    if (playerId == 0) {
      final target =
          _gameBoard?.getAIHandDrawTarget(0) ?? const Offset(60, 276);
      playerHandX = target.dx;
      playerHandY = target.dy;
    } else if (playerId == 2) {
      final target =
          _gameBoard?.getAIHandDrawTarget(2) ?? const Offset(1220, 276);
      playerHandX = target.dx;
      playerHandY = target.dy;
    }

    final meldTypeEnum = meldType == 'chi'
        ? MeldType.ju
        : meldType == 'peng'
        ? MeldType.kan
        : meldType == 'zhao'
        ? MeldType.zhao
        : MeldType.kan;
    final isJing = cards.any((c) => c.isJing);
    final meld = Meld(cards: cards, type: meldTypeEnum, isJing: isJing);
    _gameBoard!.addMeld(playerId, meld);

    final meldList = _gameBoard!.getPlayerMelds(playerId);
    final meldPositions = <Offset>[];
    final meldScales = <double>[];
    final savedPositions = <Vector2>[];
    final startIdx = meldList.length - cards.length;
    for (int i = startIdx; i < meldList.length; i++) {
      final cr = meldList[i];
      savedPositions.add(Vector2.copy(cr.position));
      meldPositions.add(Offset(cr.position.x, cr.position.y));
      meldScales.add(cr.isMeldCard ? 0.25 : 0.25);
      cr.position.setValues(-2000, -2000);
    }

    _animationSystem!.meldAnim(
      cards: cards,
      playerId: playerId,
      meldType: meldType,
      centerX: centerX,
      centerY: centerY,
      discardX: discardX,
      discardY: discardY,
      playerHandX: playerHandX,
      playerHandY: playerHandY,
      meldPositions: meldPositions,
      meldScales: meldScales,
      onComplete: () {
        for (int i = 0; i < savedPositions.length; i++) {
          final cr = meldList[startIdx + i];
          cr.position.setFrom(savedPositions[i]);
        }
      },
    );
  }

  void _syncBoard() {
    if (_gameController == null || _gameBoard == null) return;
    final state = _gameController!.state;
    _gameBoard!.clearAll();
    _gameBoard!.dealingComplete = state.isDealingComplete;
    _gameBoard!.lastPlayedCard = _lastPlayedCard;

    _gameBoard!.showHuDisplay = state.showHuResult || state.showLiujuResult;

    _gameBoard!.setHuResult(
      show: state.showHuResult,
      winnerName: state.huResultWinnerName ?? '',
      winnerIndex: state.huResultWinnerIndex ?? -1,
      method: state.huResultMethod ?? '',
      huTypeName: state.huResultHuType ?? '',
      huCountVal: state.huResultHuCount ?? 0,
      multiplier: state.huResultMultiplier ?? 0,
      score: state.huResultScore ?? 0,
      dianpaoIndex: state.huResultDianpaoIndex ?? -1,
      dianpaoName: state.huResultDianpaoName ?? '',
      dianpaoCard: state.huResultDianpaoCard,
      zimoCard: state.huResultZimoCard,
      scoreChanges: state.huResultScoreChanges ?? {},
      playerNames: state.players.map((p) => p.name).toList(),
    );

    for (int i = 0; i < state.players.length; i++) {
      final player = state.players[i];
      _gameBoard!.setPlayerHand(i, player.hand);
      _gameBoard!.setPlayerDiscards(i, player.discards);
      _gameBoard!.setPlayerMelds(i, player.melds);
      if (state.showHuResult || state.showLiujuResult) {
        _gameBoard!.setTingBadge(i, false);
      } else if (i == 1 && state.hideTingBadge && state.isMyTurn) {
        _gameBoard!.setTingBadge(1, false);
      } else if (i == 1 &&
          player.isTing &&
          player.tingCards.isNotEmpty &&
          !state.canHu) {
        _gameBoard!.setTingBadges(i, player.tingCards, true);
      }
    }

    // 更新选中状态
    if (_selectedCard != null) {
      _gameBoard!.setSelected(1, _selectedCard);
    }

    _gameBoard!.setDeckCount(state.deck.length);

    if (state.showHuResult &&
        state.huResultScore != null &&
        !_scoreAnimPlayed) {
      _scoreAnimPlayed = true;
      _triggerScoreAnimation();
    }
  }

  void _triggerScoreAnimation() {
    if (_animationSystem == null ||
        _gameController == null ||
        _gameBoard == null) {
      return;
    }

    final state = _gameController!.state;
    final winnerIndex = state.huResultWinnerIndex ?? -1;
    final scoreChangesMap = state.huResultScoreChanges;

    if (winnerIndex < 0 || scoreChangesMap == null) return;

    final scoreChanges = <Map<String, dynamic>>[];
    final fromPositions = <Offset>[];
    final targetPositions = <Offset>[];
    final playerIds = <int>[];

    final targetX = [avatar0ScoreX, avatar1ScoreX, avatar2ScoreX];
    final targetY = [avatar0ScoreY, avatar1ScoreY, avatar2ScoreY];

    final panelPositions = _gameBoard!.getHuPanelScorePositions(
      winnerIndex,
      scoreChangesMap,
    );

    int posIdx = 0;
    for (int i = 0; i < 3; i++) {
      final s = scoreChangesMap[i] ?? 0;
      if (s == 0) continue;
      if (i == winnerIndex) {
        scoreChanges.add({'score': s, 'isGain': true});
      } else {
        scoreChanges.add({'score': -s, 'isGain': false});
      }
      if (posIdx < panelPositions.length) {
        fromPositions.add(panelPositions[posIdx]);
      } else {
        fromPositions.add(Offset(huPanelScoreX, huPanelScoreY));
      }
      targetPositions.add(Offset(targetX[i], targetY[i]));
      playerIds.add(i);
      posIdx++;
    }

    if (scoreChanges.isEmpty) return;

    _animationSystem!.scoreChangeAnim(
      scoreChanges: scoreChanges,
      fromPositions: fromPositions,
      targetPositions: targetPositions,
      onArrive: (index) {
        if (index < playerIds.length) {
          onScoreArrive?.call(playerIds[index]);
        }
      },
    );
  }

  @override
  void update(double dt) {
    super.update(dt);
    _gameTicker?.update(dt);
    if (_gameBoard != null) {
      _gameBoard!.setDragState(
        _isDragging,
        _dragCard,
        _dragCardIndex,
        _dragX,
        _dragY,
      );
    }
  }
}
