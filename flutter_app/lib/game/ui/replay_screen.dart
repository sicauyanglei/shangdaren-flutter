import 'dart:async';
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

class _ReplayScreenState extends State<ReplayScreen> {
  List<List<Card>> _hands = <List<Card>>[];
  List<List<Card>> _discards = <List<Card>>[];
  List<List<Meld>> _melds = <List<Meld>>[];

  int _currentActionIndex = -1;
  bool _isPlaying = false;
  bool _isPaused = false;
  double _speed = 1.0;
  Timer? _timer;
  String _statusText = '';
  int _viewPlayerIndex = 1; // 主视角玩家，默认人类玩家

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

  // 头像位置常量 - 与game_overlay.dart一致
  static const double aiAvatarLeft = 9.6;
  static const double aiAvatarTop = 4.8;
  static const double myAvatarLeft = 10.0;
  static const double myAvatarBottom = 5.0;

  @override
  void initState() {
    super.initState();
    _initHands();
    _statusText = '第${widget.replay.roundNumber}局回放 - 就绪';
  }

  void _initHands() {
    _hands = <List<Card>>[<Card>[], <Card>[], <Card>[]];
    _discards = <List<Card>>[<Card>[], <Card>[], <Card>[]];
    _melds = <List<Meld>>[<Meld>[], <Meld>[], <Meld>[]];
    for (int i = 0; i < widget.replay.initialHands.length; i++) {
      _hands[i] = GameRecorder.deserializeHand(widget.replay.initialHands[i]);
      _sortHand(i);
    }
  }

  void _startReplay() {
    if (_currentActionIndex >= widget.replay.actions.length - 1) {
      _initHands();
      _currentActionIndex = -1;
    }
    _isPlaying = true;
    _isPaused = false;
    _playNextAction();
  }

  void _pauseReplay() {
    _isPaused = true;
    _isPlaying = false;
    _timer?.cancel();
    setState(() {
      _statusText =
          '已暂停 - 第${_currentActionIndex + 1}/${widget.replay.actions.length}步';
    });
  }

  void _stopReplay() {
    _timer?.cancel();
    _isPlaying = false;
    _isPaused = false;
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
        _statusText = '回放结束';
      });
      return;
    }
    _currentActionIndex++;
    final action = widget.replay.actions[_currentActionIndex];
    _applyAction(action);
    final playerName = widget
        .replay
        .playerNames[action.playerIndex >= 0 ? action.playerIndex : 0];
    setState(() {
      _statusText =
          '${_actionLabel(action.type, playerName)} - ${_currentActionIndex + 1}/${widget.replay.actions.length}';
    });
    final delay = (800 / _speed).round();
    _timer = Timer(Duration(milliseconds: delay), () {
      if (mounted && _isPlaying && !_isPaused) _playNextAction();
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
        break;
      case 'discard':
        final card = _deserializeCard(action.data['card']);
        _hands[pi].removeWhere((Card c) => c.id == card.id);
        _discards[pi].add(card);
        break;
      case 'chi':
        final fromCard = _deserializeCard(action.data['fromCard']);
        final chiCards = _deserializeCardList(action.data['cards']);
        for (final c in chiCards) {
          _hands[pi].removeWhere((Card h) => h.id == c.id);
        }
        final fromIdx = action.data['fromPlayerIndex'] as int;
        _discards[fromIdx].removeWhere((Card d) => d.id == fromCard.id);
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
    super.dispose();
  }

  /// 获取缩放比例
  double _getScale(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return size.width / designWidth;
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
          // 底部 - 头像（先渲染，z-order最低）
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
          // 底部 - 组合牌+弃牌+手牌（先渲染，避免遮挡左右玩家）
          Positioned(
            left: myAvatarLeft * scale,
            bottom: (myAvatarBottom + 108 + avatarToMeldGap) * scale,
            child: Transform.scale(
              scale: scale,
              alignment: Alignment.bottomLeft,
              child: _buildBottomMeldsDiscardsAndHand(positions[2]),
            ),
          ),
          // 左上 - 头像（后渲染，z-order高于底部）
          Positioned(
            left: aiAvatarLeft * scale,
            top: aiAvatarTop * scale,
            child: Transform.scale(
              scale: scale,
              alignment: Alignment.topLeft,
              child: _buildAvatarArea(positions[0], isLeft: true),
            ),
          ),
          // 左上 - 组合牌+弃牌（后渲染，确保不被底部手牌遮挡）
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
          // 中间状态文字
          Positioned(
            top: designHeight * 0.4 * scale,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _statusText,
                  style: const TextStyle(fontSize: 14, color: Colors.white70),
                ),
              ),
            ),
          ),
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
    final score = widget.replay.playerScores[playerIndex];
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
    return SizedBox(
      width: leftMaxW,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (hand.isNotEmpty) ...[
            _buildAIHand(hand, isRight: false),
            const SizedBox(height: aiHandToMeldGap),
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
    return SizedBox(
      width: rightMaxW,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (hand.isNotEmpty) ...[
            _buildAIHand(hand, isRight: true),
            const SizedBox(height: aiHandToMeldGap),
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

  /// 底部玩家组合牌+弃牌+手牌
  Widget _buildBottomMeldsDiscardsAndHand(int playerIndex) {
    final melds = _melds[playerIndex];
    final discards = _discards[playerIndex];
    final hand = _hands[playerIndex];
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
        // 手牌 - 不限制宽度，允许超过leftMaxW
        _buildMainHand(hand),
      ],
    );
  }

  /// AI玩家手牌 - 使用组合牌区显示方式
  /// 按sentence(门)分组，每门内不同字横向层叠(偏移17px)，同字层叠显示右上角计数
  /// 组间间隔2px，每行最多3组，超过换行
  Widget _buildAIHand(List<Card> cards, {required bool isRight}) {
    if (cards.isEmpty) return const SizedBox.shrink();

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

      // 横向层叠不同字(偏移meldStackVisible)，同字层叠显示计数
      final List<Widget> cardWidgets = [];
      for (int ci = 0; ci < sortedChars.length; ci++) {
        final chars = charGroups[sortedChars[ci]]!;
        cardWidgets.add(
          Positioned(
            left: ci * meldStackVisible,
            top: 0,
            child: _buildAIHandMeldCard(chars[0], chars.length),
          ),
        );
      }

      final groupW =
          (sortedChars.length - 1) * meldStackVisible + meldCardW;
      groupWidgets.add(
        SizedBox(
          width: groupW,
          height: meldCardH,
          child: Stack(clipBehavior: Clip.none, children: cardWidgets),
        ),
      );
      groupWidths.add(groupW);
    }

    // 多行布局，每行最多3组，组间间隔2px
    final List<Widget> rows = [];
    List<Widget> currentGroups = [];
    double currentRowWidth = 0;
    int groupCountInRow = 0;
    final maxW = isRight ? rightMaxW : leftMaxW;

    for (int i = 0; i < groupWidgets.length; i++) {
      final gw = groupWidgets[i];
      final groupW = groupWidths[i];
      final newWidth =
          currentGroups.isEmpty ? groupW : currentRowWidth + 2 + groupW;
      if (groupCountInRow >= 3 ||
          (currentGroups.isNotEmpty && newWidth > maxW)) {
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
      if (currentGroups.isNotEmpty) {
        currentGroups.add(const SizedBox(width: 2));
        currentRowWidth += 2;
      }
      currentGroups.add(gw);
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
      crossAxisAlignment:
          isRight ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: rows,
    );
  }

  /// AI玩家手牌单张卡牌(组合牌样式) - 34x56，多张时右上角显示数量徽章
  Widget _buildAIHandMeldCard(Card card, int stackCount) {
    final pinyin = AtlasLoader.charToPinyin[card.character];
    final badgeR = meldCardW * 0.35;
    return Container(
      width: meldCardW,
      height: meldCardH,
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
              width: meldCardW,
              height: meldCardH,
              fit: BoxFit.contain,
            )
          else
            Container(color: Colors.white),
          if (stackCount > 1)
            Positioned(
              left: meldCardW - badgeR * 2,
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
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(3),
      ),
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
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(2),
      ),
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

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (int i = 0; i < sentenceWidgets.length; i++) ...[
          if (i > 0) const SizedBox(width: handSentenceGap),
          sentenceWidgets[i],
        ],
      ],
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
              _buildSpeedButton(1.0),
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

  Widget _buildSpeedButton(double speed) {
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
          '${speed.toInt()}x',
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
