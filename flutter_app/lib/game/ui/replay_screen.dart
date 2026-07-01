import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart' hide Card;
import '../core/atlas_loader.dart';
import '../models/card.dart';
import '../models/meld.dart';
import '../models/player.dart';
import '../models/game_recorder.dart';

class ReplayScreen extends StatefulWidget {
  final RoundReplay replay;
  final VoidCallback? onClose;

  const ReplayScreen({super.key, required this.replay, this.onClose});

  @override
  State<ReplayScreen> createState() => _ReplayScreenState();
}

/// 飞牌动画状态
class _FlyCard {
  final Card card;
  final bool faceUp;
  final double fromX, fromY;
  final double toX, toY;
  final double fromScale, toScale;
  final double fromW, fromH;
  final double toW, toH;
  double progress; // 0..1
  final Duration duration;
  final Duration delay;
  bool started;
  bool flash; // 到达后是否闪烁

  _FlyCard({
    required this.card,
    this.faceUp = true,
    required this.fromX,
    required this.fromY,
    required this.toX,
    required this.toY,
    this.fromScale = 1.0,
    this.toScale = 1.0,
    required this.fromW,
    required this.fromH,
    required this.toW,
    required this.toH,
    this.progress = 0,
    required this.duration,
    this.delay = Duration.zero,
    this.started = false,
    this.flash = false,
  });
}

/// 胡牌徽章信息
class _HuBadgeInfo {
  final String text;
  final bool isPrimary;
  _HuBadgeInfo({required this.text, required this.isPrimary});
}

/// 飞分动画状态
class _FlyingScore {
  final int scoreChange;
  final bool isGain;
  final double fromX, fromY;
  final double toX, toY;
  double progress; // 0..1
  final Duration duration;
  bool started;
  _FlyingScore({
    required this.scoreChange,
    required this.isGain,
    required this.fromX,
    required this.fromY,
    required this.toX,
    required this.toY,
    this.progress = 0,
    required this.duration,
    this.started = false,
  });
}

class _ReplayScreenState extends State<ReplayScreen>
    with TickerProviderStateMixin {
  List<List<Card>> _hands = <List<Card>>[];
  List<List<Card>> _discards = <List<Card>>[];
  List<List<Meld>> _melds = <List<Meld>>[];

  int _currentActionIndex = -1;
  bool _isPlaying = false;
  bool _isPaused = false;
  double _speed = 0.5;
  Timer? _timer;
  String _statusText = '';
  int _viewPlayerIndex = 1; // 主视角玩家，默认人类玩家

  // 飞牌动画系统
  final List<_FlyCard> _flyingCards = [];
  AnimationController? _animController;
  Timer? _animTimer;
  bool _animInProgress = false;
  // 闪烁的弃牌（最后出的牌）
  int _flashPlayerIndex = -1;
  int _flashCardId = -1;
  // 中央出牌区当前显示的牌（小牌堆下方，与正常牌局一致）
  Card? _centerCard;
  // 摸牌标记（最后摸的牌ID，用于主视角显示"摸"字）
  int _moCardId = -1;

  // 牌堆剩余张数（小牌堆显示）
  int _deckCount = 0;

  // 回放结束后的结果面板
  bool _showResult = false;

  // 飞分动画系统
  final List<_FlyingScore> _flyingScores = [];
  Timer? _scoreAnimTimer;
  bool _scoreAnimPlayed = false;

  // 回放完成后的显示分数（初始=回放开始分数，完成后加上scoreChanges）
  late List<int> _displayScores;

  // 牌局页面设计尺寸
  static const double designWidth = 1280.0;
  static const double designHeight = 720.0;

  // 卡牌尺寸 - 与GameBoard一致
  static const double handCardW = 60.0;
  static const double handCardH = 224.0;
  static const double handStackVisible = 64.0;
  static const double handSentenceGap = 2.0;
  static const double smallCardW = 28.0;
  static const double smallCardH = 48.0;
  static const double meldCardW = 34.0;
  static const double meldCardH = 56.0;
  static const double meldStackVisible = 17.0;
  static const double meldRowGap = 0.0;
  static const double discardCardGap = 1.0;
  static const double discardRowGap = 0.0;
  static const int maxDiscardPerRow = 8;
  static const double meldToDiscardGap = 1.0;
  static const double avatarToMeldGap = 6.0;
  static const double aiHandToMeldGap = 2.0;
  static const double leftMaxW = 340.0;
  static const double rightMaxW = 280.0;

  // 胡牌显示时的AI手牌尺寸 - 与GameBoard一致
  static const double huDisplayCardW = 42.0;
  static const double huDisplayCardH = 68.0;
  static const double huDisplayStackVisible = 20.0;

  // 头像位置常量 - 与game_overlay.dart一致
  static const double aiAvatarLeft = 9.6;
  static const double aiAvatarTop = 4.8;
  static const double myAvatarLeft = 10.0;
  static const double myAvatarBottom = 5.0;

  @override
  void initState() {
    super.initState();
    _initHands();
    _displayScores = List<int>.from(widget.replay.playerScores);
    _statusText = '第${widget.replay.roundNumber}局回放 - 就绪';
  }

  void _initHands() {
    _hands = <List<Card>>[<Card>[], <Card>[], <Card>[]];
    _discards = <List<Card>>[<Card>[], <Card>[], <Card>[]];
    _melds = <List<Meld>>[<Meld>[], <Meld>[], <Meld>[]];
    int dealtCount = 0;
    for (int i = 0; i < widget.replay.initialHands.length; i++) {
      _hands[i] = GameRecorder.deserializeHand(widget.replay.initialHands[i]);
      _sortHand(i);
      dealtCount += _hands[i].length;
    }
    // 总牌数96张，减去已发到各玩家手牌的张数
    _deckCount = 96 - dealtCount;
  }

  void _startReplay() {
    if (_currentActionIndex >= widget.replay.actions.length - 1) {
      _initHands();
      _currentActionIndex = -1;
    }
    _isPlaying = true;
    _isPaused = false;
    _showResult = false;
    _playNextAction();
  }

  void _pauseReplay() {
    _isPaused = true;
    _isPlaying = false;
    _timer?.cancel();
    _animTimer?.cancel();
    _flyingCards.clear();
    _animInProgress = false;
    setState(() {
      _statusText =
          '已暂停 - 第${_currentActionIndex + 1}/${widget.replay.actions.length}步';
    });
  }

  void _stopReplay() {
    _timer?.cancel();
    _animTimer?.cancel();
    _scoreAnimTimer?.cancel();
    _flyingCards.clear();
    _flyingScores.clear();
    _animInProgress = false;
    _scoreAnimPlayed = false;
    _isPlaying = false;
    _isPaused = false;
    _showResult = false;
    _displayScores = List<int>.from(widget.replay.playerScores);
    _initHands();
    _currentActionIndex = -1;
    setState(() {
      _statusText = '第${widget.replay.roundNumber}局回放 - 就绪';
    });
    widget.onClose?.call();
  }

  void _playNextAction() {
    if (!_isPlaying || _isPaused) return;
    if (_currentActionIndex >= widget.replay.actions.length - 1) {
      _isPlaying = false;
      setState(() {
        _showResult = true;
        _statusText = '回放结束';
      });
      // 触发飞分动画
      if (!_scoreAnimPlayed) {
        _scoreAnimPlayed = true;
        _triggerScoreAnimation();
      }
      return;
    }
    _currentActionIndex++;
    final action = widget.replay.actions[_currentActionIndex];
    final playerName = widget
        .replay
        .playerNames[action.playerIndex >= 0 ? action.playerIndex : 0];
    setState(() {
      _statusText =
          '${_actionLabel(action.type, playerName)} - ${_currentActionIndex + 1}/${widget.replay.actions.length}';
    });
    // 先播放动画，动画完成后应用状态变更
    _playActionWithAnimation(action);
  }

  /// 获取玩家在设计坐标系中的手牌位置
  Offset _playerHandPos(int playerIndex) {
    final positions = _positionMap;
    if (playerIndex == positions[2]) {
      // 底部主视角
      return const Offset(640, 580);
    } else if (playerIndex == positions[0]) {
      // 左上
      return const Offset(60, 276);
    } else {
      // 右上
      return const Offset(1220, 276);
    }
  }

  /// 获取玩家在设计坐标系中的组合牌位置
  Offset _playerMeldPos(int playerIndex) {
    final positions = _positionMap;
    if (playerIndex == positions[2]) {
      // 底部主视角 - 组合牌在头像上方
      return const Offset(135, 600);
    } else if (playerIndex == positions[0]) {
      // 左上
      return const Offset(60, 180);
    } else {
      // 右上
      return const Offset(1220, 180);
    }
  }

  /// 牌堆位置
  static const _deckPos = Offset(600, 9.6);

  /// 中央出牌区
  static const _centerPos = Offset(620, 276);

  /// 卡牌尺寸常量
  static const double _flyHandCardW = 56.0;
  static const double _flyHandCardH = 224.0;
  static const double _flySmallCardW = 28.0;
  static const double _flySmallCardH = 48.0;
  static const double _flyMeldCardW = 34.0;
  static const double _flyMeldCardH = 56.0;

  void _playActionWithAnimation(ReplayAction action) {
    _flyingCards.clear();
    _animInProgress = true;
    _moCardId = -1;

    final speedFactor = 1.0 / _speed;
    final pi = action.playerIndex;

    switch (action.type) {
      case 'draw':
        _startDrawAnimation(action, pi, speedFactor);
        break;
      case 'discard':
        _startDiscardAnimation(action, pi, speedFactor);
        break;
      case 'chi':
        _startMeldAnimation(action, pi, 'chi', speedFactor);
        break;
      case 'peng':
        _startMeldAnimation(action, pi, 'peng', speedFactor);
        break;
      case 'zhao':
        _startMeldAnimation(action, pi, 'zhao', speedFactor);
        break;
      case 'zhao_from_hand':
        _startZhaoFromHandAnimation(action, pi, speedFactor);
        break;
      case 'hu':
      case 'zimo':
        _startHuAnimation(action, pi, speedFactor);
        break;
      default:
        // piao, liuju等无动画
        _applyAction(action);
        _animInProgress = false;
        setState(() {});
        _scheduleNext();
        break;
    }
  }

  /// 摸牌动画：牌堆 → 中央 → 手牌
  void _startDrawAnimation(ReplayAction action, int pi, double sf) {
    final card = _deserializeCard(action.data['card']);
    final handPos = _playerHandPos(pi);
    final isMain = pi == _positionMap[2];
    final faceUp = isMain;
    final cardW = isMain ? _flyHandCardW : _flyMeldCardW;
    final cardH = isMain ? _flyHandCardH : _flyMeldCardH;

    // 阶段1: 牌堆 → 中央 (0.3s)
    _flyingCards.add(
      _FlyCard(
        card: card,
        faceUp: false,
        fromX: _deckPos.dx,
        fromY: _deckPos.dy,
        toX: _centerPos.dx,
        toY: _centerPos.dy,
        fromW: 160,
        fromH: 40,
        toW: 160,
        toH: 40,
        duration: Duration(milliseconds: (300 * sf).round()),
      ),
    );
    // 阶段2: 中央 → 手牌 (0.4s, 延迟0.3s)
    _flyingCards.add(
      _FlyCard(
        card: card,
        faceUp: faceUp,
        fromX: _centerPos.dx,
        fromY: _centerPos.dy,
        toX: handPos.dx,
        toY: handPos.dy,
        fromW: 160,
        fromH: 40,
        toW: cardW,
        toH: cardH,
        duration: Duration(milliseconds: (400 * sf).round()),
        delay: Duration(milliseconds: (300 * sf).round()),
      ),
    );

    if (isMain) _moCardId = card.id;
    _runAnimation(
      action,
      totalDuration: Duration(milliseconds: (700 * sf).round()),
    );
  }

  /// 出牌动画：手牌 → 中央(闪烁)
  void _startDiscardAnimation(ReplayAction action, int pi, double sf) {
    final card = _deserializeCard(action.data['card']);
    final handPos = _playerHandPos(pi);
    final isMain = pi == _positionMap[2];
    final fromW = isMain ? _flyHandCardW : _flyMeldCardW;
    final fromH = isMain ? _flyHandCardH : _flyMeldCardH;

    _flyingCards.add(
      _FlyCard(
        card: card,
        faceUp: true,
        fromX: handPos.dx,
        fromY: handPos.dy,
        toX: _centerPos.dx,
        toY: _centerPos.dy,
        fromW: fromW,
        fromH: fromH,
        toW: _flySmallCardW * 1.5,
        toH: _flySmallCardH * 1.5,
        duration: Duration(milliseconds: (400 * sf).round()),
        flash: true,
      ),
    );

    _runAnimation(
      action,
      totalDuration: Duration(milliseconds: (600 * sf).round()),
    );
  }

  /// 吃/碰/招动画：弃牌区的牌+手牌的牌 → 中央展示 → 组合牌区
  /// 与正常牌局一致：先飞到中央展示，停留后再飞到组合牌区
  void _startMeldAnimation(
    ReplayAction action,
    int pi,
    String meldType,
    double sf,
  ) {
    final meldPos = _playerMeldPos(pi);
    final handPos = _playerHandPos(pi);
    final isMain = pi == _positionMap[2];
    final fromW = isMain ? _flyHandCardW : _flyMeldCardW;
    final fromH = isMain ? _flyHandCardH : _flyMeldCardH;

    // 准备所有牌（fromCard在第一位）
    final fromCard = _deserializeCard(
      action.data['fromCard'] ?? action.data['card'],
    );
    List<Card> handCards;
    if (meldType == 'chi') {
      handCards = _deserializeCardList(action.data['cards']);
    } else {
      // peng: 2张, zhao: 3张
      final card = _deserializeCard(action.data['card']);
      final count = meldType == 'peng' ? 2 : 3;
      handCards = [];
      for (int i = 0; i < count; i++) {
        handCards.add(card);
      }
    }
    final allCards = <Card>[fromCard, ...handCards];

    // 中央展示区参数（与正常牌局一致）
    final centerX = designWidth / 2; // 640
    final centerY = designHeight / 2; // 360
    final meldCenterY = centerY * 0.64; // 230.4
    const meldCardW = 28.0; // 中央展示牌宽（0.5缩放）
    const meldCardH = 112.0; // 中央展示牌高
    const gap = 2.0;
    final totalW = allCards.length * meldCardW + (allCards.length - 1) * gap;
    final startX = centerX - totalW / 2;

    // 时长参数
    final flyDuration = 400 * sf; // 飞入中央时长
    final showDuration = 450 * sf; // 中央停留时长
    final toMeldDuration = 300 * sf; // 飞到组合牌区时长
    final toMeldStagger = 80 * sf; // 交错启动间隔

    // 阶段1：所有牌飞到中央展示区
    for (int i = 0; i < allCards.length; i++) {
      final card = allCards[i];
      Offset fromPos;
      double fW, fH;
      if (i == 0) {
        // fromCard来自弃牌区（中央）
        fromPos = _centerPos;
        fW = _flySmallCardW * 1.5;
        fH = _flySmallCardH * 1.5;
      } else {
        // 手牌来自手牌区
        fromPos = handPos;
        fW = fromW;
        fH = fromH;
      }
      _flyingCards.add(
        _FlyCard(
          card: card,
          faceUp: true,
          fromX: fromPos.dx,
          fromY: fromPos.dy,
          toX: startX + i * (meldCardW + gap),
          toY: meldCenterY,
          fromW: fW,
          fromH: fH,
          toW: meldCardW,
          toH: meldCardH,
          duration: Duration(milliseconds: flyDuration.round()),
        ),
      );
    }

    // 阶段3：从中央飞到组合牌区（交错启动）
    for (int i = 0; i < allCards.length; i++) {
      final card = allCards[i];
      final delay = flyDuration + showDuration + i * toMeldStagger;
      _flyingCards.add(
        _FlyCard(
          card: card,
          faceUp: true,
          fromX: startX + i * (meldCardW + gap),
          fromY: meldCenterY,
          toX: meldPos.dx + i * (_flyMeldCardW * 0.5),
          toY: meldPos.dy,
          fromW: meldCardW,
          fromH: meldCardH,
          toW: _flyMeldCardW,
          toH: _flyMeldCardH,
          duration: Duration(milliseconds: toMeldDuration.round()),
          delay: Duration(milliseconds: delay.round()),
        ),
      );
    }

    // 总时长 = 飞入 + 停留 + 交错 + 飞出
    final totalDuration =
        flyDuration +
        showDuration +
        (allCards.length - 1) * toMeldStagger +
        toMeldDuration;
    _runAnimation(
      action,
      totalDuration: Duration(milliseconds: totalDuration.round()),
    );
  }

  /// 手牌招动画：手牌4张 → 中央展示 → 组合牌区
  void _startZhaoFromHandAnimation(ReplayAction action, int pi, double sf) {
    final meldPos = _playerMeldPos(pi);
    final handPos = _playerHandPos(pi);
    final isMain = pi == _positionMap[2];
    final fromW = isMain ? _flyHandCardW : _flyMeldCardW;
    final fromH = isMain ? _flyHandCardH : _flyMeldCardH;
    final cards = _deserializeCardList(action.data['cards']);

    // 中央展示区参数
    final centerX = designWidth / 2;
    final centerY = designHeight / 2;
    final meldCenterY = centerY * 0.64;
    const meldCardW = 28.0;
    const meldCardH = 112.0;
    const gap = 2.0;
    final totalW = cards.length * meldCardW + (cards.length - 1) * gap;
    final startX = centerX - totalW / 2;

    // 时长参数
    final flyDuration = 400 * sf;
    final showDuration = 450 * sf;
    final toMeldDuration = 300 * sf;
    final toMeldStagger = 80 * sf;

    // 阶段1：手牌飞到中央展示区
    for (int i = 0; i < cards.length; i++) {
      _flyingCards.add(
        _FlyCard(
          card: cards[i],
          faceUp: true,
          fromX: handPos.dx + (i - 1) * 10,
          fromY: handPos.dy,
          toX: startX + i * (meldCardW + gap),
          toY: meldCenterY,
          fromW: fromW,
          fromH: fromH,
          toW: meldCardW,
          toH: meldCardH,
          duration: Duration(milliseconds: flyDuration.round()),
        ),
      );
    }

    // 阶段3：从中央飞到组合牌区
    for (int i = 0; i < cards.length; i++) {
      final delay = flyDuration + showDuration + i * toMeldStagger;
      _flyingCards.add(
        _FlyCard(
          card: cards[i],
          faceUp: true,
          fromX: startX + i * (meldCardW + gap),
          fromY: meldCenterY,
          toX: meldPos.dx + i * (_flyMeldCardW * 0.5),
          toY: meldPos.dy,
          fromW: meldCardW,
          fromH: meldCardH,
          toW: _flyMeldCardW,
          toH: _flyMeldCardH,
          duration: Duration(milliseconds: toMeldDuration.round()),
          delay: Duration(milliseconds: delay.round()),
        ),
      );
    }

    final totalDuration =
        flyDuration +
        showDuration +
        (cards.length - 1) * toMeldStagger +
        toMeldDuration;
    _runAnimation(
      action,
      totalDuration: Duration(milliseconds: totalDuration.round()),
    );
  }

  /// 胡牌/自摸动画：牌飞到中央展示
  void _startHuAnimation(ReplayAction action, int pi, double sf) {
    final card = _deserializeCard(action.data['card']);
    final handPos = _playerHandPos(pi);
    final isMain = pi == _positionMap[2];
    final fromW = isMain ? _flyHandCardW : _flyMeldCardW;
    final fromH = isMain ? _flyHandCardH : _flyMeldCardH;

    // 点炮：从出牌者位置飞到胡牌者
    // 自摸：从手牌位置飞到中央
    final fromPos = action.type == 'zimo' ? handPos : _centerPos;

    _flyingCards.add(
      _FlyCard(
        card: card,
        faceUp: true,
        fromX: fromPos.dx,
        fromY: fromPos.dy,
        toX: _centerPos.dx,
        toY: _centerPos.dy,
        fromW: fromW,
        fromH: fromH,
        toW: _flyHandCardW * 0.8,
        toH: _flyHandCardH * 0.8,
        duration: Duration(milliseconds: (600 * sf).round()),
        flash: true,
      ),
    );

    _runAnimation(
      action,
      totalDuration: Duration(milliseconds: (900 * sf).round()),
    );
  }

  /// 运行动画，完成后应用状态变更并继续下一步
  void _runAnimation(ReplayAction action, {required Duration totalDuration}) {
    final startTime = DateTime.now();
    _animTimer?.cancel();

    void tick() {
      final elapsed = DateTime.now().difference(startTime);
      for (final fc in _flyingCards) {
        if (!fc.started) {
          if (elapsed >= fc.delay) {
            fc.started = true;
          } else {
            continue;
          }
        }
        if (fc.started) {
          final localElapsed = elapsed - fc.delay;
          fc.progress =
              (localElapsed.inMilliseconds / fc.duration.inMilliseconds).clamp(
                0.0,
                1.0,
              );
        }
      }
      setState(() {});

      if (elapsed >= totalDuration) {
        _animTimer?.cancel();
        _flyingCards.clear();
        _applyAction(action);
        _animInProgress = false;
        setState(() {});
        _scheduleNext();
      }
    }

    _animTimer = Timer.periodic(
      const Duration(milliseconds: 16),
      (_) => tick(),
    );
  }

  void _scheduleNext() {
    final delay = (600 / _speed).round();
    _timer = Timer(Duration(milliseconds: delay), () {
      if (mounted && _isPlaying && !_isPaused) _playNextAction();
    });
  }

  /// 触发飞分动画
  void _triggerScoreAnimation() {
    final resultData = widget.replay.resultData;
    if (resultData == null) return;
    if (widget.replay.resultType != 'hu') return;

    final int winnerIndex = resultData['winnerIndex'] as int? ?? -1;
    final Map? scoreChanges = resultData['scoreChanges'] as Map?;
    if (winnerIndex < 0 || scoreChanges == null) return;

    final positions = _positionMap;
    _flyingScores.clear();

    // 胡牌面板中心位置（设计坐标）- 面板宽度360，居中
    // 分数行大约在面板中部偏下
    final panelCenterX = designWidth / 2;
    final panelScoreY = 180.0;

    // 各玩家头像分数位置（设计坐标）
    final targetPositions = <int, Offset>{};
    for (int i = 0; i < 3; i++) {
      if (i == positions[2]) {
        // 底部玩家：头像在左下角
        targetPositions[i] = Offset(
          myAvatarLeft + 200,
          designHeight - myAvatarBottom - 50,
        );
      } else if (i == positions[0]) {
        // 左上玩家
        targetPositions[i] = Offset(aiAvatarLeft + 200, aiAvatarTop + 90);
      } else {
        // 右上玩家
        targetPositions[i] = Offset(
          designWidth - aiAvatarLeft - 200,
          aiAvatarTop + 90,
        );
      }
    }

    for (int i = 0; i < 3; i++) {
      final dynamic raw = scoreChanges[i] ?? scoreChanges[i.toString()];
      final change = (raw is int) ? raw : (int.tryParse('$raw') ?? 0);
      if (change == 0) continue;

      final target = targetPositions[i]!;
      _flyingScores.add(
        _FlyingScore(
          scoreChange: change,
          isGain: change > 0,
          fromX: panelCenterX,
          fromY: panelScoreY,
          toX: target.dx,
          toY: target.dy,
          duration: const Duration(milliseconds: 1500),
        ),
      );
    }

    if (_flyingScores.isEmpty) return;

    // 启动飞分动画定时器
    final startTime = DateTime.now();
    _scoreAnimTimer?.cancel();
    _scoreAnimTimer = Timer.periodic(const Duration(milliseconds: 16), (_) {
      final elapsed = DateTime.now().difference(startTime);
      for (final fs in _flyingScores) {
        fs.started = true;
        fs.progress = (elapsed.inMilliseconds / fs.duration.inMilliseconds)
            .clamp(0.0, 1.0);
      }
      setState(() {});

      if (elapsed >= const Duration(milliseconds: 1500)) {
        _scoreAnimTimer?.cancel();
        _flyingScores.clear();
        // 更新显示分数为最终分数
        for (int i = 0; i < _displayScores.length; i++) {
          final dynamic raw = scoreChanges[i] ?? scoreChanges[i.toString()];
          final change = (raw is int) ? raw : (int.tryParse('$raw') ?? 0);
          _displayScores[i] += change;
        }
        setState(() {});
      }
    });
  }

  String _actionLabel(String type, String playerName) {
    switch (type) {
      case 'draw':
        return '$playerName 摸牌';
      case 'discard':
        return '$playerName 出牌';
      case 'chi':
        return '$playerName 吃';
      case 'peng':
        return '$playerName 碰';
      case 'zhao':
        return '$playerName 招';
      case 'zhao_from_hand':
        return '$playerName 招(手牌)';
      case 'hu':
        return '$playerName 胡';
      case 'zimo':
        return '$playerName 自摸';
      case 'liuju':
        return '流局';
      case 'piao':
        return '$playerName 飘分';
      default:
        return type;
    }
  }

  void _applyAction(ReplayAction action) {
    final pi = action.playerIndex;
    switch (action.type) {
      case 'draw':
        final card = _deserializeCard(action.data['card']);
        _hands[pi].add(card);
        _sortHand(pi);
        if (_deckCount > 0) _deckCount--;
        break;
      case 'discard':
        final card = _deserializeCard(action.data['card']);
        _hands[pi].removeWhere((Card c) => c.id == card.id);
        _discards[pi].add(card);
        _centerCard = card; // 中央出牌区显示这张牌
        break;
      case 'chi':
        final fromCard = _deserializeCard(action.data['fromCard']);
        final chiCards = _deserializeCardList(action.data['cards']);
        for (final c in chiCards) {
          _hands[pi].removeWhere((Card h) => h.id == c.id);
        }
        final fromIdx = action.data['fromPlayerIndex'] as int;
        _discards[fromIdx].removeWhere((Card d) => d.id == fromCard.id);
        _centerCard = null; // 被吃掉，清除中央牌
        _melds[pi].add(
          Meld(
            cards: chiCards,
            type: MeldType.ju,
            isJing: chiCards.any((Card c) => c.isJing),
          ),
        );
        break;
      case 'peng':
        final card = _deserializeCard(action.data['card']);
        final fromIdx = action.data['fromPlayerIndex'] as int;
        int removed = 0;
        _hands[pi].removeWhere((Card h) {
          if (removed < 2 && h.character == card.character) {
            removed++;
            return true;
          }
          return false;
        });
        _discards[fromIdx].removeWhere((Card d) => d.id == card.id);
        _centerCard = null; // 被碰掉，清除中央牌
        final pengCards = <Card>[card];
        for (int i = 0; i < 2; i++) {
          pengCards.add(
            Card(
              id: -1 - pi * 100 - i,
              character: card.character,
              sentence: card.sentence,
              position: card.position,
            ),
          );
        }
        _melds[pi].add(
          Meld(cards: pengCards, type: MeldType.kan, isJing: card.isJing),
        );
        break;
      case 'zhao':
        final card = _deserializeCard(action.data['card']);
        final fromIdx = action.data['fromPlayerIndex'] as int;
        int removed = 0;
        _hands[pi].removeWhere((Card h) {
          if (removed < 3 && h.character == card.character) {
            removed++;
            return true;
          }
          return false;
        });
        _discards[fromIdx].removeWhere((Card d) => d.id == card.id);
        _centerCard = null; // 被招走，清除中央牌
        final zhaoCards = <Card>[card];
        for (int i = 0; i < 3; i++) {
          zhaoCards.add(
            Card(
              id: -2 - pi * 100 - i,
              character: card.character,
              sentence: card.sentence,
              position: card.position,
            ),
          );
        }
        _melds[pi].add(
          Meld(cards: zhaoCards, type: MeldType.zhao, isJing: card.isJing),
        );
        break;
      case 'zhao_from_hand':
        final cards = _deserializeCardList(action.data['cards']);
        for (final c in cards) {
          _hands[pi].removeWhere((Card h) => h.id == c.id);
        }
        _centerCard = null;
        _melds[pi].add(
          Meld(
            cards: cards,
            type: MeldType.zhao,
            isJing: cards.any((Card c) => c.isJing),
          ),
        );
        break;
      case 'hu':
      case 'zimo':
        final card = _deserializeCard(action.data['card']);
        _hands[pi].add(card);
        _sortHand(pi);
        _centerCard = null; // 胡牌后清除中央牌
        // 自摸从牌堆摸牌，点炮从弃牌摸牌
        if (action.type == 'zimo' && _deckCount > 0) _deckCount--;
        break;
    }
  }

  Card _deserializeCard(dynamic m) =>
      GameRecorder.deserializeCard(m as Map<String, dynamic>);
  List<Card> _deserializeCardList(dynamic list) => (list as List)
      .map(
        (dynamic c) => GameRecorder.deserializeCard(c as Map<String, dynamic>),
      )
      .toList();
  void _sortHand(int pi) {
    _hands[pi].sort((Card a, Card b) {
      if (a.sentence != b.sentence) return a.sentence.compareTo(b.sentence);
      return a.position.compareTo(b.position);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _animTimer?.cancel();
    _scoreAnimTimer?.cancel();
    _animController?.dispose();
    super.dispose();
  }

  /// 获取缩放比例
  double _getScale(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return size.width / designWidth;
  }

  /// 计算底部主视角手牌顶部Y坐标（设计坐标）
  /// 手牌底部在设计坐标 designHeight + 80（因为 bottom: -80）
  double _mainHandTopY(List<Card> hand) {
    final groups = <int, List<Card>>{};
    for (final card in hand) {
      groups.putIfAbsent(card.sentence, () => []).add(card);
    }
    int maxStack = 0;
    for (final g in groups.values) {
      final charGroups = <String, List<Card>>{};
      for (final c in g) {
        charGroups.putIfAbsent(c.character, () => []).add(c);
      }
      if (charGroups.length > maxStack) maxStack = charGroups.length;
    }
    if (maxStack == 0) return designHeight;
    final groupH = (maxStack - 1) * handStackVisible + handCardH;
    return designHeight + 120 - groupH;
  }

  /// 根据主视角获取位置映射
  /// 返回 [leftPlayerIndex, rightPlayerIndex, bottomPlayerIndex]
  List<int> get _positionMap {
    switch (_viewPlayerIndex) {
      case 0:
        return [1, 2, 0]; // 玩家0主视角：1左 2右 0底
      case 2:
        return [0, 1, 2]; // 玩家2主视角：0左 1右 2底
      default:
        return [0, 2, 1]; // 人类玩家主视角：0左 2右 1底
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final scale = _getScale(context);
    final positions = _positionMap;

    return Container(
      width: size.width,
      height: size.height,
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment.center,
          radius: 0.7,
          colors: [Color(0xFF1a5c2e), Color(0xFF0d3d1a), Color(0xFF062810)],
          stops: [0.0, 0.5, 1.0],
        ),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // 底部 - 头像
          Positioned(
            left: myAvatarLeft * scale,
            bottom: myAvatarBottom * scale,
            child: Transform.scale(
              scale: scale,
              alignment: Alignment.bottomLeft,
              child: _buildAvatarArea(
                positions[2],
                isLeft: true,
                isBottom: true,
              ),
            ),
          ),
          // 底部 - 组合牌+弃牌（在头像上方）
          Positioned(
            left: myAvatarLeft * scale,
            bottom: (myAvatarBottom + 108 + avatarToMeldGap) * scale,
            child: Transform.scale(
              scale: scale,
              alignment: Alignment.bottomLeft,
              child: _buildBottomMeldsAndDiscards(positions[2]),
            ),
          ),
          // 底部 - 手牌（水平居中，与正常牌局一致，底部超出屏幕120px）
          Positioned(
            left: 0,
            right: 0,
            bottom: -120 * scale,
            child: Transform.scale(
              scale: scale,
              alignment: Alignment.bottomCenter,
              child: _buildMainHand(_hands[positions[2]]),
            ),
          ),
          // 左上 - 头像
          Positioned(
            left: aiAvatarLeft * scale,
            top: aiAvatarTop * scale,
            child: Transform.scale(
              scale: scale,
              alignment: Alignment.topLeft,
              child: _buildAvatarArea(positions[0], isLeft: true),
            ),
          ),
          // 左上 - 组合牌+弃牌
          Positioned(
            left: aiAvatarLeft * scale,
            top: (aiAvatarTop + 108 + avatarToMeldGap) * scale,
            child: Transform.scale(
              scale: scale,
              alignment: Alignment.topLeft,
              child: _buildLeftMeldsAndDiscards(positions[0]),
            ),
          ),
          // 右上 - 头像
          Positioned(
            right: aiAvatarLeft * scale,
            top: aiAvatarTop * scale,
            child: Transform.scale(
              scale: scale,
              alignment: Alignment.topRight,
              child: _buildAvatarArea(positions[1], isLeft: false),
            ),
          ),
          // 右上 - 组合牌+弃牌
          Positioned(
            right: aiAvatarLeft * scale,
            top: (aiAvatarTop + 108 + avatarToMeldGap) * scale,
            child: Transform.scale(
              scale: scale,
              alignment: Alignment.topRight,
              child: _buildRightMeldsAndDiscards(positions[1]),
            ),
          ),
          // 小牌堆指示器（顶部居中，与正常游戏一致）
          if (_deckCount > 0) _buildDeckIndicator(scale),
          // 中央出牌区（小牌堆下方，显示当前出的牌，与正常游戏一致）
          if (_centerCard != null && _flyingCards.isEmpty)
            _buildCenterCard(scale),
          // 飞牌动画Overlay层
          if (_flyingCards.isNotEmpty) _buildFlyingCardOverlay(scale),
          // 结果面板（胡牌/流局）
          if (_showResult)
            _buildResultOverlay(scale, _mainHandTopY(_hands[positions[2]])),
          // 胡牌徽章（赢家/点炮者头像旁边）
          if (_showResult && widget.replay.resultType == 'hu')
            ..._buildHuBadges(scale, positions),
          // 飞分动画Overlay层
          if (_flyingScores.isNotEmpty) _buildFlyingScoreOverlay(scale),
          // 控制栏
          _buildControls(),
        ],
      ),
    );
  }

  /// 构建头像区域 - 与game_overlay.dart的_AIPlayerInfo/_MyPlayerInfo一致
  Widget _buildAvatarArea(
    int playerIndex, {
    required bool isLeft,
    bool isBottom = false,
  }) {
    final isDealer = widget.replay.dealerIndex == playerIndex;
    final piao = widget.replay.playerPiao[playerIndex];
    final name = widget.replay.playerNames[playerIndex];
    final score = _displayScores[playerIndex];
    final gender = widget.replay.playerGenders[playerIndex];
    final isFemale = gender == Gender.female;
    final handCount = _hands[playerIndex].length;

    return Container(
      constraints: const BoxConstraints(minWidth: 250),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.5),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.2), width: 2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 头像
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: isDealer
                      ? const LinearGradient(
                          colors: [Color(0xFFffd700), Color(0xFFdaa520)],
                          begin: Alignment(-0.7, -0.7),
                          end: Alignment(0.7, 0.7),
                        )
                      : isFemale
                      ? const LinearGradient(
                          colors: [Color(0xFF8b4789), Color(0xFF6a2c6a)],
                          begin: Alignment(-0.7, -0.7),
                          end: Alignment(0.7, 0.7),
                        )
                      : const LinearGradient(
                          colors: [Color(0xFF4a7c59), Color(0xFF2d5a3d)],
                          begin: Alignment(-0.7, -0.7),
                          end: Alignment(0.7, 0.7),
                        ),
                  border: Border.all(
                    color: isDealer
                        ? const Color(0xFFffd700)
                        : isFemale
                        ? const Color(0xFFb06aab)
                        : const Color(0xFF6b9b7a),
                    width: 3,
                  ),
                  boxShadow: isDealer
                      ? [
                          BoxShadow(
                            color: const Color(0xFFffd700).withOpacity(0.7),
                            blurRadius: 15,
                          ),
                        ]
                      : null,
                ),
                alignment: Alignment.center,
                child: Text(
                  isDealer
                      ? '👑'
                      : isFemale
                      ? '👩‍🌾'
                      : '👨‍🌾',
                  style: TextStyle(
                    fontSize: 40,
                    color: isDealer ? const Color(0xFF333333) : Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Positioned(
                bottom: -8,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: isDealer
                          ? const Color(0xFFff6b6b)
                          : const Color(0xFF4ecdc4),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      isDealer ? '庄家' : '闲家',
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),
          // 信息列
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  if (piao > 0) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 14,
                        minHeight: 14,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFff6b6b),
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                      child: Text(
                        '飘$piao',
                        style: const TextStyle(
                          fontSize: 18,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 24,
                          height: 24,
                          child: FittedBox(
                            fit: BoxFit.contain,
                            child: Text('🃏', style: TextStyle(fontSize: 20)),
                          ),
                        ),
                        Text(
                          '$handCount',
                          style: const TextStyle(
                            fontSize: 24,
                            color: Color(0xFFffd700),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 2),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 24,
                        height: 24,
                        child: FittedBox(
                          fit: BoxFit.contain,
                          child: Text('💰', style: TextStyle(fontSize: 20)),
                        ),
                      ),
                      Text(
                        '$score',
                        style: TextStyle(
                          fontSize: 24,
                          color: score < 0
                              ? const Color(0xFFff6b6b)
                              : const Color(0xFF4ecdc4),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 左侧玩家组合牌+弃牌
  Widget _buildLeftMeldsAndDiscards(int playerIndex) {
    final melds = _melds[playerIndex];
    final discards = _discards[playerIndex];
    final hand = _hands[playerIndex];
    final handMeldGap = _showResult ? 20.0 : aiHandToMeldGap;
    return SizedBox(
      width: leftMaxW,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (hand.isNotEmpty) ...[
            _buildAIHand(hand, isRight: false),
            SizedBox(height: handMeldGap),
          ],
          if (melds.isNotEmpty) ...[
            _buildMeldsArea(melds, isRight: false),
            const SizedBox(height: meldToDiscardGap),
          ],
          if (discards.isNotEmpty) _buildDiscardsArea(discards, isRight: false),
        ],
      ),
    );
  }

  /// 右侧玩家组合牌+弃牌
  Widget _buildRightMeldsAndDiscards(int playerIndex) {
    final melds = _melds[playerIndex];
    final discards = _discards[playerIndex];
    final hand = _hands[playerIndex];
    final handMeldGap = _showResult ? 20.0 : aiHandToMeldGap;
    return SizedBox(
      width: rightMaxW,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (hand.isNotEmpty) ...[
            _buildAIHand(hand, isRight: true),
            SizedBox(height: handMeldGap),
          ],
          if (melds.isNotEmpty) ...[
            _buildMeldsArea(melds, isRight: true),
            const SizedBox(height: meldToDiscardGap),
          ],
          if (discards.isNotEmpty) _buildDiscardsArea(discards, isRight: true),
        ],
      ),
    );
  }

  /// 底部玩家组合牌+弃牌（不含手牌，手牌单独居中定位）
  Widget _buildBottomMeldsAndDiscards(int playerIndex) {
    final melds = _melds[playerIndex];
    final discards = _discards[playerIndex];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // 弃牌在上方
        if (discards.isNotEmpty) ...[
          SizedBox(
            width: leftMaxW,
            child: _buildDiscardsArea(discards, isRight: false),
          ),
          const SizedBox(height: meldToDiscardGap),
        ],
        if (melds.isNotEmpty) ...[
          SizedBox(
            width: leftMaxW,
            child: _buildMeldsArea(melds, isRight: false),
          ),
          const SizedBox(height: aiHandToMeldGap),
        ],
      ],
    );
  }

  /// AI玩家手牌 - 使用组合牌区显示方式
  /// 按sentence(门)分组，每门内不同字横向层叠(偏移17px)，同字层叠显示右上角计数
  /// 组间间隔2px，每行最多3组，超过换行
  Widget _buildAIHand(List<Card> cards, {required bool isRight}) {
    if (cards.isEmpty) return const SizedBox.shrink();

    // 胡牌显示时使用更大的卡牌尺寸
    final cw = _showResult ? huDisplayCardW : meldCardW;
    final ch = _showResult ? huDisplayCardH : meldCardH;
    final sv = _showResult ? huDisplayStackVisible : meldStackVisible;

    // 按sentence(门)分组
    final sentenceGroups = <int, List<Card>>{};
    for (final card in cards) {
      sentenceGroups.putIfAbsent(card.sentence, () => []).add(card);
    }
    final sortedSentences = sentenceGroups.keys.toList()..sort();

    // 为每个门构建组widget
    final List<Widget> groupWidgets = [];
    final List<double> groupWidths = [];
    for (final sKey in sortedSentences) {
      final group = sentenceGroups[sKey]!;
      // 按字分组
      final charGroups = <String, List<Card>>{};
      for (final c in group) {
        charGroups.putIfAbsent(c.character, () => []).add(c);
      }
      // 按position排序
      final sortedChars = charGroups.keys.toList()
        ..sort((a, b) {
          final pa = charGroups[a]!.first.position;
          final pb = charGroups[b]!.first.position;
          return pa.compareTo(pb);
        });

      // 横向层叠不同字(偏移sv)，同字层叠显示计数
      // 卡牌在下层，数字徽章在上层（不被相邻卡牌覆盖）
      final List<Widget> cardWidgets = [];
      final List<Widget> badgeWidgets = [];
      final badgeR = cw * 0.35;
      for (int ci = 0; ci < sortedChars.length; ci++) {
        final chars = charGroups[sortedChars[ci]]!;
        final stackCount = chars.length;
        cardWidgets.add(
          Positioned(
            left: ci * sv,
            top: 0,
            child: _buildAIHandMeldCard(chars[0], 1, cardW: cw, cardH: ch),
          ),
        );
        // 徽章单独放最上层，不参与折叠
        if (stackCount > 1) {
          badgeWidgets.add(
            Positioned(
              left: ci * sv + cw - badgeR * 2,
              top: 0,
              child: Container(
                width: badgeR * 2,
                height: badgeR * 2,
                decoration: const BoxDecoration(
                  color: Color(0xFFFF4444),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  '$stackCount',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: badgeR * 0.9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          );
        }
      }

      final groupW = (sortedChars.length - 1) * sv + cw;
      groupWidgets.add(
        SizedBox(
          width: groupW,
          height: ch,
          child: Stack(
            clipBehavior: Clip.none,
            children: [...cardWidgets, ...badgeWidgets],
          ),
        ),
      );
      groupWidths.add(groupW);
    }

    // 单行布局：所有门组放在一行内，组间间隔2px
    return Row(
      mainAxisSize: MainAxisSize.min,
      textDirection: isRight ? TextDirection.rtl : TextDirection.ltr,
      children: [
        for (int i = 0; i < groupWidgets.length; i++) ...[
          if (i > 0) const SizedBox(width: 2),
          groupWidgets[i],
        ],
      ],
    );
  }

  /// AI玩家手牌单张卡牌(组合牌样式) - 默认34x56，多张时右上角显示数量徽章
  Widget _buildAIHandMeldCard(
    Card card,
    int stackCount, {
    double? cardW,
    double? cardH,
  }) {
    final w = cardW ?? meldCardW;
    final h = cardH ?? meldCardH;
    final pinyin = AtlasLoader.charToPinyin[card.character];
    final badgeR = w * 0.35;
    return Container(
      width: w,
      height: h,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(3),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.25),
            blurRadius: 2,
            offset: const Offset(1, 2),
          ),
        ],
      ),
      clipBehavior: Clip.hardEdge,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          if (pinyin != null)
            Image.asset(
              'assets/html/images/s/$pinyin.png',
              width: w,
              height: h,
              fit: BoxFit.contain,
            )
          else
            Container(color: Colors.white),
          if (stackCount > 1)
            Positioned(
              left: w - badgeR * 2,
              top: 0,
              child: Container(
                width: badgeR * 2,
                height: badgeR * 2,
                decoration: const BoxDecoration(
                  color: Color(0xFFFF4444),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  '$stackCount',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: badgeR * 0.9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// 组合牌区域 - 与GameBoard布局一致
  Widget _buildMeldsArea(List<Meld> melds, {required bool isRight}) {
    final groups = <List<Card>>[];
    for (final meld in melds) {
      groups.add(meld.cards);
    }
    return _buildMeldsFromGroups(groups, isRight);
  }

  Widget _buildMeldsFromGroups(List<List<Card>> groups, bool isRight) {
    final List<Widget> rows = [];
    List<Widget> currentGroups = [];
    double currentRowWidth = 0;
    int groupCountInRow = 0;
    final maxW = isRight ? rightMaxW : leftMaxW;

    for (final group in groups) {
      final groupW = (group.length - 1) * meldStackVisible + meldCardW + 2;
      if (groupCountInRow >= 3 ||
          (currentGroups.isNotEmpty && currentRowWidth + groupW > maxW)) {
        rows.add(
          Row(
            mainAxisSize: MainAxisSize.min,
            textDirection: isRight ? TextDirection.rtl : TextDirection.ltr,
            children: currentGroups,
          ),
        );
        currentGroups = [];
        currentRowWidth = 0;
        groupCountInRow = 0;
      }
      currentGroups.add(_buildMeldGroupWidget(group, isRight));
      currentRowWidth += groupW;
      groupCountInRow++;
    }
    if (currentGroups.isNotEmpty) {
      rows.add(
        Row(
          mainAxisSize: MainAxisSize.min,
          textDirection: isRight ? TextDirection.rtl : TextDirection.ltr,
          children: currentGroups,
        ),
      );
    }

    return Column(
      crossAxisAlignment: isRight
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: rows,
    );
  }

  Widget _buildMeldGroupWidget(List<Card> cards, bool isRight) {
    final groupW = (cards.length - 1) * meldStackVisible + meldCardW;
    return Padding(
      padding: const EdgeInsets.only(right: 2),
      child: SizedBox(
        width: groupW,
        height: meldCardH,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            for (int i = 0; i < cards.length; i++)
              Positioned(
                left: i * meldStackVisible,
                top: 0,
                child: _buildMeldCard(cards[i]),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMeldCard(Card card) {
    final pinyin = AtlasLoader.charToPinyin[card.character];
    return Container(
      width: meldCardW,
      height: meldCardH,
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(3)),
      clipBehavior: Clip.hardEdge,
      child: pinyin != null
          ? Image.asset(
              'assets/html/images/s/$pinyin.png',
              width: meldCardW,
              height: meldCardH,
              fit: BoxFit.contain,
            )
          : Container(color: Colors.white),
    );
  }

  /// 弃牌区域 - 与GameBoard布局一致
  Widget _buildDiscardsArea(List<Card> cards, {required bool isRight}) {
    final List<Widget> rows = [];
    for (int i = 0; i < cards.length; i += maxDiscardPerRow) {
      final rowCards = cards.sublist(
        i,
        i + maxDiscardPerRow > cards.length
            ? cards.length
            : i + maxDiscardPerRow,
      );
      final List<Widget> cardWidgets = [];
      for (int j = 0; j < rowCards.length; j++) {
        final card = rowCards[j];
        cardWidgets.add(
          Padding(
            padding: EdgeInsets.only(left: j > 0 ? discardCardGap : 0),
            child: _buildDiscardCard(card),
          ),
        );
      }
      rows.add(
        Row(
          mainAxisSize: MainAxisSize.min,
          textDirection: isRight ? TextDirection.rtl : TextDirection.ltr,
          children: cardWidgets,
        ),
      );
    }
    return Column(
      crossAxisAlignment: isRight
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: rows,
    );
  }

  Widget _buildDiscardCard(Card card) {
    final pinyin = AtlasLoader.charToPinyin[card.character];
    return Container(
      width: smallCardW,
      height: smallCardH,
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(2)),
      clipBehavior: Clip.hardEdge,
      child: pinyin != null
          ? Image.asset(
              'assets/html/images/s/$pinyin.png',
              width: smallCardW,
              height: smallCardH,
              fit: BoxFit.contain,
            )
          : Container(color: Colors.white.withOpacity(0.85)),
    );
  }

  /// 主视角手牌 - 与GameBoard._layoutPlayer1Hand一致
  /// 60x224竖牌，同字竖向叠放(偏移64px)，按sentence分组
  Widget _buildMainHand(List<Card> cards) {
    // 按sentence分组
    final groups = <int, List<Card>>{};
    for (final card in cards) {
      groups.putIfAbsent(card.sentence, () => []).add(card);
    }
    final sortedKeys = groups.keys.toList()..sort();

    final List<Widget> sentenceWidgets = [];
    for (final sKey in sortedKeys) {
      final group = groups[sKey]!;
      // 按字分组叠放
      final charGroups = <String, List<Card>>{};
      for (final c in group) {
        charGroups.putIfAbsent(c.character, () => []).add(c);
      }
      // 按position排序
      final sortedChars = charGroups.keys.toList()
        ..sort((a, b) {
          final pa = charGroups[a]!.first.position;
          final pb = charGroups[b]!.first.position;
          return pa.compareTo(pb);
        });

      final List<Widget> cardWidgets = [];
      for (int ci = 0; ci < sortedChars.length; ci++) {
        final chars = charGroups[sortedChars[ci]]!;
        for (int i = 0; i < chars.length; i++) {
          final pinyin = AtlasLoader.charToPinyin[chars[i].character];
          cardWidgets.add(
            Positioned(
              top: ci * handStackVisible,
              left: 0,
              child: Container(
                width: handCardW,
                height: handCardH,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.4),
                      blurRadius: 6,
                      offset: const Offset(3, 3),
                    ),
                  ],
                ),
                clipBehavior: Clip.hardEdge,
                child: pinyin != null
                    ? Image.asset(
                        'assets/html/images/$pinyin.png',
                        width: handCardW,
                        height: handCardH,
                        fit: BoxFit.fill,
                      )
                    : Container(color: Colors.white),
              ),
            ),
          );
        }
      }

      final maxStack = sortedChars.length;
      final groupH = maxStack > 0
          ? (maxStack - 1) * handStackVisible + handCardH
          : 0.0;

      sentenceWidgets.add(
        SizedBox(
          width: handCardW,
          height: groupH,
          child: Stack(clipBehavior: Clip.none, children: cardWidgets),
        ),
      );
    }

    return Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (int i = 0; i < sentenceWidgets.length; i++) ...[
            if (i > 0) const SizedBox(width: handSentenceGap),
            sentenceWidgets[i],
          ],
        ],
      ),
    );
  }

  /// 构建飞牌动画Overlay层
  Widget _buildFlyingCardOverlay(double scale) {
    return Positioned.fill(
      child: IgnorePointer(
        child: Stack(
          clipBehavior: Clip.none,
          children: _flyingCards.where((fc) => fc.started).map((fc) {
            final t = fc.progress;
            // easeInOutCubic
            final eased = t < 0.5
                ? 4 * t * t * t
                : 1 - math.pow(1 - t, 3) * 1.0;
            final x = fc.fromX + (fc.toX - fc.fromX) * eased;
            final y = fc.fromY + (fc.toY - fc.fromY) * eased;
            final w = fc.fromW + (fc.toW - fc.fromW) * eased;
            final h = fc.fromH + (fc.toH - fc.fromH) * eased;

            final pinyin = AtlasLoader.charToPinyin[fc.card.character];

            return Positioned(
              left: x * scale,
              top: y * scale,
              child: Container(
                width: w * scale,
                height: h * scale,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.5),
                      blurRadius: 8,
                      offset: const Offset(2, 4),
                    ),
                  ],
                ),
                clipBehavior: Clip.hardEdge,
                child: fc.faceUp && pinyin != null
                    ? Image.asset(
                        'assets/html/images/$pinyin.png',
                        width: w * scale,
                        height: h * scale,
                        fit: BoxFit.fill,
                      )
                    : Container(
                        color: const Color(0xFF2d5a3d),
                        child: Center(
                          child: Container(
                            width: w * scale * 0.6,
                            height: h * scale * 0.6,
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: const Color(0xFF4a8a5e),
                                width: 2,
                              ),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                      ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  /// 构建飞分动画Overlay层
  Widget _buildFlyingScoreOverlay(double scale) {
    return Positioned.fill(
      child: IgnorePointer(
        child: Stack(
          clipBehavior: Clip.none,
          children: _flyingScores.where((fs) => fs.started).map((fs) {
            final t = fs.progress;
            // easeInOutCubic
            final eased = t < 0.5
                ? 4 * t * t * t
                : 1 - math.pow(1 - t, 3) * 1.0;
            final x = fs.fromX + (fs.toX - fs.fromX) * eased;
            final y = fs.fromY + (fs.toY - fs.fromY) * eased;

            final scoreText = fs.scoreChange > 0
                ? '+${fs.scoreChange}'
                : '${fs.scoreChange}';
            final color = fs.isGain
                ? const Color(0xFFffd700)
                : const Color(0xFFff6b6b);

            return Positioned(
              left: x * scale,
              top: y * scale,
              child: Transform.scale(
                scale: scale,
                alignment: Alignment.topLeft,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: color, width: 1.5),
                    boxShadow: [
                      BoxShadow(color: color.withOpacity(0.6), blurRadius: 8),
                    ],
                  ),
                  child: Text(
                    scoreText,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: color,
                      shadows: [
                        Shadow(color: color.withOpacity(0.8), blurRadius: 6),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  /// 构建胡牌徽章列表（赢家/点炮者头像旁边）
  List<Widget> _buildHuBadges(double scale, List<int> positions) {
    final resultData = widget.replay.resultData;
    if (resultData == null) return [];

    final int winnerIndex = resultData['winnerIndex'] as int? ?? -1;
    final String huType = resultData['huType'] as String? ?? '';
    final String method = resultData['method'] as String? ?? '';
    final int dianpaoIndex = resultData['dianpaoIndex'] as int? ?? -1;
    final Map? scoreChanges = resultData['scoreChanges'] as Map?;

    final List<Widget> badgeWidgets = [];

    // 只显示赢家和点炮者徽章（与正常牌局窗口一致，不显示其他输家徽章）
    for (int i = 0; i < widget.replay.playerNames.length; i++) {
      final isWinner = i == winnerIndex;
      final isDianpao = i == dianpaoIndex && method == '点炮';

      if (!isWinner && !isDianpao) continue;

      final badges = <_HuBadgeInfo>[];
      if (isWinner) {
        // 赢家：自摸 + 胡型
        if (method == '自摸') {
          badges.add(_HuBadgeInfo(text: '自摸', isPrimary: true));
        }
        badges.add(_HuBadgeInfo(text: huType, isPrimary: false));
      } else if (isDianpao) {
        // 点炮者
        badges.add(_HuBadgeInfo(text: '点炮', isPrimary: true));
      }

      badgeWidgets.add(
        _buildPlayerHuBadge(
          playerIndex: i,
          badges: badges,
          scale: scale,
          positions: positions,
        ),
      );
    }

    return badgeWidgets;
  }

  /// 构建单个玩家的胡牌徽章（定位在头像旁边）
  Widget _buildPlayerHuBadge({
    required int playerIndex,
    required List<_HuBadgeInfo> badges,
    required double scale,
    required List<int> positions,
  }) {
    const double badgeGap = 4.0;
    const double padH = 10.0;
    const double padV = 6.0;
    const double fontSize = 18.0;
    const double badgeH = fontSize + padV * 2;
    const double badgeGapFromAvatar = 10.0;

    // 计算徽章总宽度
    double totalW = 0;
    final badgeWidths = <double>[];
    for (final badge in badges) {
      final tp = TextPainter(
        text: TextSpan(
          text: badge.text,
          style: const TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w900,
            color: Colors.white,
            letterSpacing: 1,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final w = tp.width + padH * 2;
      badgeWidths.add(w);
      totalW += w;
    }
    totalW += (badges.length - 1) * badgeGap;

    // 根据玩家位置确定徽章位置
    // positions = [leftPlayerIndex, rightPlayerIndex, bottomPlayerIndex]
    double left, top;
    bool isRight = false;

    if (playerIndex == positions[0]) {
      // 左上玩家：徽章在头像右侧
      left = (aiAvatarLeft + 260 + badgeGapFromAvatar) * scale;
      top = (aiAvatarTop + 108 - badgeH) * scale;
      isRight = false;
    } else if (playerIndex == positions[2]) {
      // 底部玩家：徽章在头像右侧
      left = (myAvatarLeft + 260 + badgeGapFromAvatar) * scale;
      top = (designHeight - myAvatarBottom - 108) * scale;
      isRight = false;
    } else {
      // 右上玩家：徽章在头像左侧
      left =
          (designWidth - aiAvatarLeft - 260 - badgeGapFromAvatar - totalW) *
          scale;
      top = (aiAvatarTop + 108 - badgeH) * scale;
      isRight = true;
    }

    return Positioned(
      left: left,
      top: top,
      child: Transform.scale(
        scale: scale,
        alignment: Alignment.topLeft,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (int i = 0; i < badges.length; i++) ...[
              if (i > 0) const SizedBox(width: badgeGap),
              _buildSingleBadge(badges[i], badgeWidths[i], badgeH, padH, padV),
            ],
          ],
        ),
      ),
    );
  }

  /// 构建单个徽章widget
  Widget _buildSingleBadge(
    _HuBadgeInfo badge,
    double badgeW,
    double badgeH,
    double padH,
    double padV,
  ) {
    // 颜色方案 - 与game_board.dart一致
    List<Color> bgColors;
    Color borderColor;
    Color innerBorderColor;
    Color glowColor;

    if (badge.isPrimary && badge.text == '自摸') {
      bgColors = const [Color(0xFF6a1b9a), Color(0xFF9c27b0)];
      borderColor = const Color(0xFFffd700);
      innerBorderColor = const Color(0xFFce93d8);
      glowColor = const Color(0xFFce93d8);
    } else if (badge.isPrimary && badge.text == '点炮') {
      bgColors = const [Color(0xFFe65100), Color(0xFFff8f00)];
      borderColor = const Color(0xFFffd700);
      innerBorderColor = const Color(0xFFffcc80);
      glowColor = const Color(0xFFffb74d);
    } else {
      bgColors = const [Color(0xFFc62828), Color(0xFFef5350)];
      borderColor = const Color(0xFFffd700);
      innerBorderColor = const Color(0xFFFF8A80);
      glowColor = const Color(0xFFff6b6b);
    }

    return Container(
      width: badgeW,
      height: badgeH,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: bgColors,
          begin: Alignment(-0.6, -0.6),
          end: Alignment(0.6, 0.6),
        ),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor, width: 2),
        boxShadow: [
          BoxShadow(color: glowColor.withOpacity(0.3), blurRadius: 10),
        ],
      ),
      child: Container(
        margin: const EdgeInsets.all(1.5),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(7),
          border: Border.all(
            color: innerBorderColor.withOpacity(0.4),
            width: 1,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          badge.text,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: Colors.white,
            letterSpacing: 1,
            shadows: [
              Shadow(color: borderColor.withOpacity(0.6), blurRadius: 4),
            ],
          ),
        ),
      ),
    );
  }

  /// 构建回放结束后的结果面板（胡牌/流局）
  Widget _buildResultOverlay(double scale, double mainHandTopY) {
    final resultType = widget.replay.resultType;
    final resultData = widget.replay.resultData;
    final isLiuju = resultType == 'liuju';

    // 胡牌信息
    final int winnerIndex = resultData?['winnerIndex'] as int? ?? -1;
    final String winnerName = winnerIndex >= 0
        ? widget.replay.playerNames[winnerIndex]
        : '';
    final String huType = resultData?['huType'] as String? ?? '';
    final String method = resultData?['method'] as String? ?? '';
    final int dianpaoIndex = resultData?['dianpaoIndex'] as int? ?? -1;
    final int huCount = resultData?['huCount'] as int? ?? 0;
    final int multiplier = resultData?['multiplier'] as int? ?? 1;
    final Map? scoreChanges = resultData?['scoreChanges'] as Map?;

    // 胡型颜色
    Color huTypeColor = _getHuTypeColor(huType);

    // 面板定位在屏幕上半部分，确保不遮挡非主视角玩家手牌区域
    final panelW = 360.0;
    final panelTop = 100.0;

    // 倍数显示：0倍不显示，1倍显示为0.5倍
    final multiplierText = multiplier == 0
        ? null
        : (multiplier == 1 ? '0.5倍' : '$multiplier倍');

    return Positioned(
      left: (designWidth / 2 - panelW / 2) * scale,
      top: panelTop * scale,
      child: Transform.scale(
        scale: scale,
        alignment: Alignment.topLeft,
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: panelW,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xF01a472a),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFffd700), width: 2),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFffd700).withOpacity(0.3),
                  blurRadius: 16,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 标题
                Text(
                  isLiuju ? '流局' : '$winnerName 胡牌!',
                  style: TextStyle(
                    fontSize: 18,
                    color: const Color(0xFFffd700),
                    fontWeight: FontWeight.bold,
                    shadows: [
                      Shadow(
                        color: const Color(0xFFffd700).withOpacity(0.5),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                ),
                if (isLiuju) ...[
                  const SizedBox(height: 6),
                  const Text(
                    '牌堆已空，本局结束',
                    style: TextStyle(fontSize: 14, color: Colors.white70),
                  ),
                ] else ...[
                  const SizedBox(height: 8),
                  // 胡牌信息行：方法 + 胡型 + 胡数 + 倍数
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    alignment: WrapAlignment.center,
                    children: [
                      _buildResultTag(
                        method,
                        Colors.white,
                        Colors.white.withOpacity(0.1),
                      ),
                      _buildResultTag(
                        huType,
                        huTypeColor,
                        huTypeColor.withOpacity(0.2),
                      ),
                      _buildResultTag(
                        '$huCount胡',
                        const Color(0xFFffd700),
                        const Color(0x33ffd700),
                      ),
                      if (multiplierText != null)
                        _buildResultTag(
                          multiplierText,
                          const Color(0xFFff6b6b),
                          const Color(0x33ff6b6b),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // 玩家分数变化
                  if (scoreChanges != null)
                    ..._buildScoreChanges(
                      scoreChanges,
                      winnerIndex,
                      dianpaoIndex,
                      method,
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 构建结果标签
  Widget _buildResultTag(String text, Color textColor, Color bgColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: textColor.withOpacity(0.4), width: 1),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 14,
          color: textColor,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  /// 构建分数变化行
  List<Widget> _buildScoreChanges(
    Map scoreChanges,
    int winnerIndex,
    int dianpaoIndex,
    String method,
  ) {
    final widgets = <Widget>[];
    for (int i = 0; i < widget.replay.playerNames.length; i++) {
      final name = widget.replay.playerNames[i];
      // 兼容 int 键（内存访问）和 String 键（JSON 反序列化）
      final dynamic raw = scoreChanges[i] ?? scoreChanges[i.toString()];
      final change = (raw is int) ? raw : (int.tryParse('$raw') ?? 0);
      final isWinner = i == winnerIndex;
      final isDianpao = i == dianpaoIndex && method == '点炮';
      final label = isWinner
          ? '赢家'
          : (isDianpao ? '点炮' : (change < 0 ? '输家' : ''));

      // 分数显示：0时显示"0"而不是"+0"
      final scoreText = change == 0
          ? '0'
          : (change > 0 ? '+$change' : '$change');

      widgets.add(
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              name,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: isWinner ? const Color(0xFFffd700) : Colors.white70,
              ),
            ),
            if (label.isNotEmpty) ...[
              const SizedBox(width: 3),
              Text(
                '($label)',
                style: TextStyle(
                  fontSize: 10,
                  color: isDianpao ? const Color(0xFFff6b6b) : Colors.white54,
                ),
              ),
            ],
            const SizedBox(width: 6),
            Text(
              scoreText,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: isWinner
                    ? const Color(0xFFffd700)
                    : change < 0
                    ? const Color(0xFFff6b6b)
                    : Colors.white,
              ),
            ),
          ],
        ),
      );
      if (i < widget.replay.playerNames.length - 1) {
        widgets.add(const SizedBox(width: 16));
      }
    }
    return [
      Wrap(
        spacing: 16,
        runSpacing: 6,
        alignment: WrapAlignment.center,
        children: widgets,
      ),
    ];
  }

  /// 胡型颜色
  Color _getHuTypeColor(String huTypeName) {
    switch (huTypeName) {
      case '清枯重台卡':
      case '清枯重台胡':
        return const Color(0xFFff2d2d);
      case '枯重台卡':
      case '枯重台胡':
      case '清枯台胡':
      case '清枯台卡':
        return const Color(0xFFe040fb);
      case '十对':
        return const Color(0xFFff9800);
      case '枯台胡':
      case '清枯胡':
      case '枯胡':
      case '重台卡':
      case '重台胡':
        return const Color(0xFFff6b6b);
      case '红元精':
      case '红元2精':
      case '红元3精':
      case '红元4精':
      case '黑元':
        return const Color(0xFFab47bc);
      case '清卡胡':
      case '清胡':
      case '卡胡':
        return const Color(0xFF4ecdc4);
      case '台卡':
      case '台胡':
        return const Color(0xFF42a5f5);
      default:
        return const Color(0xFF4ecdc4);
    }
  }

  /// 构建小牌堆指示器（顶部居中，与正常游戏一致）
  /// 参考game_board.dart的_renderDeck和_renderDeckIndicator
  Widget _buildDeckIndicator(double scale) {
    // 与GameBoard一致：deckCardW=160, deckCardH=40, scale=0.5（发牌完成后）
    const deckCardW = 160.0;
    const deckCardH = 40.0;
    const deckScale = 0.5;
    final displayW = deckCardW * deckScale; // 80
    final displayH = deckCardH * deckScale; // 20
    // 牌堆位置：designWidth/2 居中，y=9.6
    final deckX = designWidth / 2 - displayW / 2;
    const deckY = 9.6;

    // 根据剩余张数决定显示层数（与GameBoard._getDeckLayerCount一致）
    int layerCount;
    if (_deckCount >= 60) {
      layerCount = 10;
    } else if (_deckCount >= 50) {
      layerCount = 8;
    } else if (_deckCount >= 40) {
      layerCount = 7;
    } else if (_deckCount >= 30) {
      layerCount = 6;
    } else if (_deckCount >= 20) {
      layerCount = 5;
    } else if (_deckCount >= 10) {
      layerCount = 4;
    } else if (_deckCount >= 5) {
      layerCount = 3;
    } else {
      layerCount = 2;
    }

    return Positioned(
      left: deckX * scale,
      top: deckY * scale,
      child: Transform.scale(
        scale: scale,
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: displayW + (layerCount - 1) * 4 * deckScale,
          height: displayH + (layerCount - 1) * 1 * deckScale,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // 牌堆层叠（每层偏移4px*deckScale, 1px*deckScale）
              for (int i = 0; i < layerCount; i++)
                Positioned(
                  left: i * 4 * deckScale,
                  top: i * 1 * deckScale,
                  child: Opacity(
                    opacity: 0.4 + (i / layerCount) * 0.6,
                    child: Image.asset(
                      'assets/html/images/back.png',
                      width: displayW,
                      height: displayH,
                      fit: BoxFit.fill,
                    ),
                  ),
                ),
              // 牌堆数字（居中显示）
              Positioned(
                left: 0,
                top: 0,
                width: displayW + (layerCount - 1) * 4 * deckScale,
                height: displayH + (layerCount - 1) * 1 * deckScale,
                child: Center(
                  child: Text(
                    '$_deckCount',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24 * deckScale,
                      fontWeight: FontWeight.w900,
                      shadows: [
                        Shadow(
                          color: const Color(0xFFffd700),
                          blurRadius: 12 * deckScale,
                        ),
                        Shadow(
                          color: const Color(0xFFffd700),
                          blurRadius: 6 * deckScale,
                        ),
                        Shadow(
                          color: Colors.black.withOpacity(0.95),
                          blurRadius: 3 * deckScale,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 构建中央出牌区（小牌堆下方，显示当前出的牌，与正常游戏一致）
  /// 正常牌局：横向牌 160×40，位置左上角(560, 55)，中心(640, 75)
  Widget _buildCenterCard(double scale) {
    final card = _centerCard!;
    final pinyin = AtlasLoader.charToPinyin[card.character];
    // 与正常牌局 _renderPlayedCards 完全一致：横向牌 160×40，左上角(560, 55)
    const cardW = 160.0; // hCardW
    const cardH = 40.0; // hCardH
    const left = 560.0; // designWidth/2 - hCardW/2
    const top = 55.0;

    return Positioned(
      left: left * scale,
      top: top * scale,
      child: Transform.scale(
        scale: scale,
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: cardW,
          height: cardH,
          child: pinyin != null
              ? Image.asset(
                  'assets/html/images/v/$pinyin.png',
                  width: cardW,
                  height: cardH,
                  fit: BoxFit.contain,
                )
              : Container(color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildControls() {
    return Positioned(
      bottom: 4,
      right: 8,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // 上面一排：播放 1x 2x 3x 结束
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                onTap: () {
                  if (_isPlaying && !_isPaused) {
                    _pauseReplay();
                  } else {
                    _startReplay();
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4ecdc4).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: const Color(0xFF4ecdc4).withOpacity(0.5),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _isPlaying && !_isPaused
                            ? Icons.pause
                            : Icons.play_arrow,
                        size: 14,
                        color: const Color(0xFF4ecdc4),
                      ),
                      const SizedBox(width: 2),
                      Text(
                        _isPlaying && !_isPaused ? '暂停' : '播放',
                        style: const TextStyle(
                          fontSize: 10,
                          color: Color(0xFF4ecdc4),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 4),
              _buildSpeedButton(0.5, label: '1x'),
              const SizedBox(width: 3),
              _buildSpeedButton(2.0),
              const SizedBox(width: 3),
              _buildSpeedButton(3.0),
              const SizedBox(width: 4),
              GestureDetector(
                onTap: _stopReplay,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF4444).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: const Color(0xFFFF4444).withOpacity(0.5),
                    ),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.stop, size: 14, color: Color(0xFFFF4444)),
                      SizedBox(width: 2),
                      Text(
                        '结束',
                        style: TextStyle(
                          fontSize: 10,
                          color: Color(0xFFFF4444),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          // 下面一排：玩家1 我 玩家2 第几局 回放模式
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildViewSwitchButton(0, '玩家1'),
              const SizedBox(width: 3),
              _buildViewSwitchButton(1, '我'),
              const SizedBox(width: 3),
              _buildViewSwitchButton(2, '玩家2'),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF4ecdc4).withOpacity(0.25),
                  borderRadius: BorderRadius.circular(3),
                  border: Border.all(
                    color: const Color(0xFF4ecdc4).withOpacity(0.6),
                    width: 1,
                  ),
                ),
                child: Text(
                  '第${widget.replay.roundNumber}局',
                  style: const TextStyle(
                    fontSize: 9,
                    color: Color(0xFF4ecdc4),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 3),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF4444).withOpacity(0.25),
                  borderRadius: BorderRadius.circular(3),
                  border: Border.all(
                    color: const Color(0xFFFF4444).withOpacity(0.6),
                    width: 1,
                  ),
                ),
                child: const Text(
                  '回放模式',
                  style: TextStyle(
                    fontSize: 9,
                    color: Color(0xFFFF6666),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildViewSwitchButton(int playerIndex, String label) {
    final isActive = _viewPlayerIndex == playerIndex;
    return GestureDetector(
      onTap: () => setState(() => _viewPlayerIndex = playerIndex),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isActive
              ? const Color(0xFFffd700).withOpacity(0.3)
              : Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isActive
                ? const Color(0xFFffd700)
                : Colors.white.withOpacity(0.15),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: isActive
                ? const Color(0xFFffd700)
                : Colors.white.withOpacity(0.5),
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildSpeedButton(double speed, {String? label}) {
    final isActive = _speed == speed;
    return GestureDetector(
      onTap: () => setState(() => _speed = speed),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isActive
              ? const Color(0xFFffd700).withOpacity(0.3)
              : Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isActive
                ? const Color(0xFFffd700)
                : Colors.white.withOpacity(0.15),
          ),
        ),
        child: Text(
          label ?? (speed % 1 == 0 ? '${speed.toInt()}x' : '${speed}x'),
          style: TextStyle(
            fontSize: 10,
            color: isActive
                ? const Color(0xFFffd700)
                : Colors.white.withOpacity(0.5),
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
