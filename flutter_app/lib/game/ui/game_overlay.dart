import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart' hide Card;
import '../models/card.dart';
import '../models/game_state.dart';
import '../models/player.dart';
import 'action_buttons.dart' show ActionButtons, GameArtButton, GameButtonType;

const double _handCardH = 224.0;
const double _handStackVisible = 52.0;
const double _designHeight = 720.0;

int _maxStackCount(List<Card> hand) {
  final sentenceGroups = <int, List<Card>>{};
  for (final card in hand) {
    sentenceGroups.putIfAbsent(card.sentence, () => []).add(card);
  }
  int maxStacks = 0;
  for (final sg in sentenceGroups.values) {
    final charGroups = <String, List<Card>>{};
    for (final card in sg) {
      charGroups.putIfAbsent(card.character, () => []).add(card);
    }
    if (charGroups.length > maxStacks) maxStacks = charGroups.length;
  }
  return maxStacks;
}

double _handTopY(List<Card> hand) {
  final maxStacks = _maxStackCount(hand);
  if (maxStacks == 0) return _designHeight;
  final totalH = (maxStacks - 1) * _handStackVisible + _handCardH;
  return _designHeight - totalH - 10;
}

class GameOverlay extends StatelessWidget {
  final GameState gameState;
  final Map<int, int> displayScores;
  final VoidCallback? onChi;
  final VoidCallback? onPeng;
  final VoidCallback? onZhao;
  final void Function(String character)? onSelectZhaoCharacter;
  final VoidCallback? onHu;
  final VoidCallback? onPass;
  final VoidCallback? onSettings;
  final void Function(int piaoValue)? onSetPiao;
  final VoidCallback? onNextRound;
  final VoidCallback? onShowSettlementFromButton;
  final void Function(double w, double h, int playerIndex)? onAvatarSizeChanged;

  const GameOverlay({
    super.key,
    required this.gameState,
    this.displayScores = const {},
    this.onChi,
    this.onPeng,
    this.onZhao,
    this.onSelectZhaoCharacter,
    this.onHu,
    this.onPass,
    this.onSettings,
    this.onSetPiao,
    this.onNextRound,
    this.onShowSettlementFromButton,
    this.onAvatarSizeChanged,
  });

  @override
  Widget build(BuildContext context) {
    if (!gameState.gameStarted) {
      return const SizedBox.shrink();
    }

    final players = gameState.players;
    final player0 = players.isNotEmpty ? players[0] : null;
    final player1 = players.length > 1 ? players[1] : null;
    final player2 = players.length > 2 ? players[2] : null;

    return Stack(
      children: [
        Positioned(
          left: 9.6,
          top: 4.8,
          child: _MeasureSize(
            playerIndex: 0,
            onSizeChanged: (size) =>
                onAvatarSizeChanged?.call(size.width, size.height, 0),
            child: _AIPlayerInfo(
              player: player0,
              dealerIndex: gameState.dealerIndex,
              currentPlayerIndex: gameState.currentPlayerIndex,
              countdown:
                  (gameState.currentPlayerIndex == 0 &&
                      !gameState.isMyTurn &&
                      !gameState.waitingForResponse)
                  ? gameState.countdown
                  : 0,
              animatingScore: displayScores[0],
            ),
          ),
        ),
        Positioned(
          right: 9.6,
          top: 4.8,
          child: _MeasureSize(
            playerIndex: 2,
            onSizeChanged: (size) =>
                onAvatarSizeChanged?.call(size.width, size.height, 2),
            child: _AIPlayerInfo(
              player: player2,
              dealerIndex: gameState.dealerIndex,
              currentPlayerIndex: gameState.currentPlayerIndex,
              countdown:
                  (gameState.currentPlayerIndex == 2 &&
                      !gameState.isMyTurn &&
                      !gameState.waitingForResponse)
                  ? gameState.countdown
                  : 0,
              animatingScore: displayScores[2],
            ),
          ),
        ),
        Positioned(
          bottom: 5,
          left: 10,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _MeasureSize(
                playerIndex: 1,
                onSizeChanged: (size) =>
                    onAvatarSizeChanged?.call(size.width, size.height, 1),
                child: _MyPlayerInfo(
                  player: player1,
                  gameState: gameState,
                  onAvatarTap: onSettings,
                  animatingScore: displayScores[1],
                ),
              ),
              if (player1?.isTing == true &&
                  !gameState.hideTingBadge &&
                  !gameState.showHuResult &&
                  !gameState.showLiujuResult)
                Transform.translate(
                  offset: const Offset(4, -4),
                  child: GameArtButton(
                    label: '听',
                    type: GameButtonType.ting,
                    onTap: null,
                  ),
                ),
            ],
          ),
        ),
        Positioned(
          bottom: _designHeight - _handTopY(player1?.hand ?? []) + 2,
          left: 0,
          right: 0,
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (gameState.canHu && gameState.isZimoOpportunity)
                  GameArtButton(
                    label: '自摸',
                    type: GameButtonType.zimo,
                    onTap: onHu,
                  ),
                if (gameState.canHu &&
                    gameState.isZimoOpportunity &&
                    (gameState.canChi ||
                        gameState.canPeng ||
                        gameState.canZhao)) ...[
                  const SizedBox(width: 14),
                  ActionButtons(
                    canChi: gameState.canChi,
                    canPeng: gameState.canPeng,
                    canZhao: gameState.canZhao,
                    canHu: false,
                    onChi: onChi,
                    onPeng: onPeng,
                    onZhao: onZhao,
                    onHu: onHu,
                    onPass: onPass,
                  ),
                ],
                if (!gameState.isZimoOpportunity)
                  ActionButtons(
                    canChi: gameState.canChi,
                    canPeng: gameState.canPeng,
                    canZhao: gameState.canZhao,
                    canHu: gameState.canHu && !gameState.isZimoOpportunity,
                    onChi: onChi,
                    onPeng: onPeng,
                    onZhao: onZhao,
                    onHu: onHu,
                    onPass: onPass,
                  ),
              ],
            ),
          ),
        ),
        Positioned(
          bottom: 9.6,
          right: 9.6,
          child: _RoundInfo(
            roundNumber: gameState.roundNumber,
            dealerName: gameState.players[gameState.dealerIndex].name,
            showHuDisplay: gameState.showHuResult || gameState.showLiujuResult,
            isLastRound: gameState.roundNumber >= 8,
            onNextRound: onNextRound,
            onShowSettlement: onShowSettlementFromButton,
            roundHistory: gameState.roundHistory,
            players: gameState.players,
          ),
        ),
        if (gameState.isPiaoPhase &&
            gameState.piaoCurrentPlayerIndex < gameState.players.length &&
            gameState.players[gameState.piaoCurrentPlayerIndex].type ==
                PlayerType.human)
          Positioned.fill(
            child: Center(child: _PiaoSelectionPopup(onSetPiao: onSetPiao)),
          ),
        if (gameState.showZhaoSelection && gameState.zhaoCandidates.isNotEmpty)
          Positioned.fill(
            child: Center(
              child: _ZhaoSelectionPopup(
                candidates: gameState.zhaoCandidates,
                onSelect: onSelectZhaoCharacter,
              ),
            ),
          ),
      ],
    );
  }
}

class _CurrentTime extends StatefulWidget {
  @override
  State<_CurrentTime> createState() => _CurrentTimeState();
}

class _CurrentTimeState extends State<_CurrentTime> {
  late Timer _timer;
  late String _timeStr;

  @override
  void initState() {
    super.initState();
    _updateTime();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _updateTime());
  }

  void _updateTime() {
    final now = DateTime.now();
    _timeStr =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Text(
        _timeStr,
        style: const TextStyle(
          fontSize: 24,
          color: Colors.white,
          fontWeight: FontWeight.w400,
          shadows: [
            Shadow(
              color: Color(0x80000000),
              blurRadius: 3,
              offset: Offset(0, 1),
            ),
          ],
        ),
      ),
    );
  }
}

class _AIPlayerInfo extends StatelessWidget {
  final Player? player;
  final int dealerIndex;
  final int currentPlayerIndex;
  final int countdown;
  final int? animatingScore;

  const _AIPlayerInfo({
    required this.player,
    required this.dealerIndex,
    required this.currentPlayerIndex,
    this.countdown = 0,
    this.animatingScore,
  });

  @override
  Widget build(BuildContext context) {
    if (player == null) return const SizedBox.shrink();

    final isDealer = player!.id == dealerIndex;
    final isCurrentTurn = player!.id == currentPlayerIndex;
    final isFemale = player!.gender == Gender.female;

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
              if (isCurrentTurn && countdown > 0)
                Positioned(
                  top: -10,
                  left: -10,
                  child: _CountdownTimer(countdown: countdown),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    player!.name,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: isCurrentTurn
                          ? const Color(0xFFffd700)
                          : Colors.white,
                    ),
                  ),
                  if (player!.piao > 0) ...[
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
                        '飘${player!.piao}',
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
                  Builder(
                    builder: (context) {
                      final scoreVal = animatingScore ?? player!.score;
                      return Row(
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
                            '$scoreVal',
                            style: TextStyle(
                              fontSize: 24,
                              color: animatingScore != null
                                  ? const Color(0xFFffd700)
                                  : scoreVal < 0
                                  ? const Color(0xFFff6b6b)
                                  : const Color(0xFF4ecdc4),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MyPlayerInfo extends StatelessWidget {
  final Player? player;
  final GameState gameState;
  final VoidCallback? onAvatarTap;
  final int? animatingScore;

  const _MyPlayerInfo({
    required this.player,
    required this.gameState,
    this.onAvatarTap,
    this.animatingScore,
  });

  @override
  Widget build(BuildContext context) {
    if (player == null) return const SizedBox.shrink();

    final isDealer = player!.id == gameState.dealerIndex;
    final isCurrentTurn = player!.id == gameState.currentPlayerIndex;
    final isFemale = player!.gender == Gender.female;

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
          Stack(
            clipBehavior: Clip.none,
            children: [
              GestureDetector(
                onTap: onAvatarTap,
                child: Container(
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
              if (gameState.canHu && gameState.isDrawing)
                Positioned(
                  top: -10,
                  right: -10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFffd700), Color(0xFFdaa520)],
                        begin: Alignment(-0.7, -0.7),
                        end: Alignment(0.7, 0.7),
                      ),
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                    child: const Text(
                      '胡',
                      style: TextStyle(
                        fontSize: 18,
                        color: Color(0xFF333333),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              if ((isCurrentTurn ||
                      gameState.canChi ||
                      gameState.canPeng ||
                      gameState.canZhao ||
                      (gameState.canHu && !gameState.isZimoOpportunity) ||
                      (gameState.canHu && gameState.isZimoOpportunity)) &&
                  gameState.countdown > 0)
                Positioned(
                  top: -10,
                  left: -10,
                  child: _CountdownTimer(countdown: gameState.countdown),
                ),
              if (player!.huCount > 0 && player!.type == PlayerType.human)
                Positioned(
                  top: -10,
                  right: -10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFffd700), Color(0xFFdaa520)],
                        begin: Alignment(-0.7, -0.7),
                        end: Alignment(0.7, 0.7),
                      ),
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                    child: Text(
                      '${player!.huCount}胡',
                      style: const TextStyle(
                        fontSize: 18,
                        color: Color(0xFF333333),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    player!.name,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: isCurrentTurn
                          ? const Color(0xFFffd700)
                          : Colors.white,
                    ),
                  ),
                  if (player!.piao > 0) ...[
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
                        '飘${player!.piao}',
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
                          '${player!.hand.length}',
                          style: const TextStyle(
                            fontSize: 24,
                            color: Color(0xFFffd700),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 2),
                  Builder(
                    builder: (context) {
                      final scoreVal = animatingScore ?? player!.score;
                      return Row(
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
                            '$scoreVal',
                            style: TextStyle(
                              fontSize: 24,
                              color: animatingScore != null
                                  ? const Color(0xFFffd700)
                                  : scoreVal < 0
                                  ? const Color(0xFFff6b6b)
                                  : const Color(0xFF4ecdc4),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RoundInfo extends StatefulWidget {
  final int roundNumber;
  final String dealerName;
  final bool showHuDisplay;
  final bool isLastRound;
  final VoidCallback? onNextRound;
  final VoidCallback? onShowSettlement;
  final List<Map<String, dynamic>> roundHistory;
  final List<dynamic> players;

  const _RoundInfo({
    required this.roundNumber,
    this.dealerName = '',
    this.showHuDisplay = false,
    this.isLastRound = false,
    this.onNextRound,
    this.onShowSettlement,
    this.roundHistory = const [],
    this.players = const [],
  });

  @override
  State<_RoundInfo> createState() => _RoundInfoState();
}

class _RoundInfoState extends State<_RoundInfo> {
  int _countdown = 60;
  Timer? _timer;

  @override
  void didUpdateWidget(covariant _RoundInfo oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.showHuDisplay && !oldWidget.showHuDisplay) {
      _startCountdown();
    } else if (!widget.showHuDisplay && oldWidget.showHuDisplay) {
      _stopCountdown();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startCountdown() {
    _countdown = 60;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_countdown <= 0) {
        timer.cancel();
        _onAutoNext();
        return;
      }
      setState(() {
        _countdown--;
      });
    });
  }

  void _stopCountdown() {
    _timer?.cancel();
    _timer = null;
    _countdown = 60;
  }

  void _onAutoNext() {
    if (!mounted) return;
    if (widget.isLastRound) {
      widget.onShowSettlement?.call();
    } else {
      widget.onNextRound?.call();
    }
  }

  void _onTap() {
    _timer?.cancel();
    _onAutoNext();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.showHuDisplay) {
      final label = widget.isLastRound ? '结算' : '下一局';
      return GestureDetector(
        onTap: _onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF1a5c2e).withOpacity(0.95),
            borderRadius: BorderRadius.circular(14.4),
            border: Border.all(color: const Color(0xFFffd700), width: 2),
          ),
          child: Text(
            '$label($_countdown秒)',
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Color(0xFFffd700),
              shadows: [Shadow(color: Color(0x80000000), blurRadius: 5)],
            ),
          ),
        ),
      );
    }

    return GestureDetector(
      onDoubleTap: () {
        if (widget.roundNumber >= 2 && widget.roundHistory.isNotEmpty) {
          _showRoundHistory(context);
        }
      },
      child: Container(
        height: 60,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.65),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFffd700).withOpacity(0.3)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFffd700).withOpacity(0.08),
              blurRadius: 12,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFffd700), Color(0xFFff8c00)],
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                widget.dealerName.isEmpty ? '庄' : widget.dealerName,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF1a0a00),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '第${widget.roundNumber}局',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFffd700),
                    shadows: [Shadow(color: Color(0x80ffd700), blurRadius: 6)],
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  width: 110,
                  height: 6,
                  decoration: BoxDecoration(
                    color: const Color(0x1AFFFFFF),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: widget.roundNumber / 8,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF4ecdc4), Color(0xFFffd700)],
                        ),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showRoundHistory(BuildContext context) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.7),
      builder: (ctx) => _RoundHistoryDialog(
        roundHistory: widget.roundHistory,
        players: widget.players,
      ),
    );
  }
}

class _PiaoSelectionPopup extends StatelessWidget {
  final void Function(int piaoValue)? onSetPiao;

  const _PiaoSelectionPopup({this.onSetPiao});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1a5c2e).withOpacity(0.95),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: const Color(0xFFffd700), width: 2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFffd700).withOpacity(0.5),
            blurRadius: 15,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            '选择飘分',
            style: TextStyle(
              fontSize: 26,
              color: Color(0xFFffd700),
              fontWeight: FontWeight.bold,
              shadows: [Shadow(color: Color(0xFFffd700), blurRadius: 8)],
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            '请选择本局飘分',
            style: TextStyle(fontSize: 20, color: Colors.white),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildPiaoButton(
                '0',
                0,
                Colors.white.withOpacity(0.3),
                Colors.white,
              ),
              const SizedBox(width: 12),
              _buildPiaoButton('5', 5, const Color(0xFF4a90e2), Colors.white),
              const SizedBox(width: 12),
              _buildPiaoButton('10', 10, const Color(0xFFf5a623), Colors.white),
              const SizedBox(width: 12),
              _buildPiaoButton('20', 20, const Color(0xFFff6b6b), Colors.white),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPiaoButton(
    String label,
    int value,
    Color bgColor,
    Color textColor,
  ) {
    return GestureDetector(
      onTap: () => onSetPiao?.call(value),
      child: Container(
        constraints: const BoxConstraints(minHeight: 64, minWidth: 72),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 4),
          ],
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 24,
              color: textColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}

class _ZhaoSelectionPopup extends StatelessWidget {
  final List<String> candidates;
  final void Function(String character)? onSelect;

  const _ZhaoSelectionPopup({required this.candidates, this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1a5c2e).withOpacity(0.95),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: const Color(0xFFffd700), width: 2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFffd700).withOpacity(0.5),
            blurRadius: 15,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            '选择招的字',
            style: TextStyle(
              fontSize: 26,
              color: Color(0xFFffd700),
              fontWeight: FontWeight.bold,
              shadows: [Shadow(color: Color(0xFFffd700), blurRadius: 8)],
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            '请选择要招的字牌',
            style: TextStyle(fontSize: 20, color: Colors.white),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: candidates.map((c) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: _buildZhaoButton(c),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildZhaoButton(String character) {
    final isJing = character == '上' || character == '福';
    return GestureDetector(
      onTap: () => onSelect?.call(character),
      child: Container(
        constraints: const BoxConstraints(minHeight: 68, minWidth: 68),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isJing
                ? [const Color(0xFFffd700), const Color(0xFFdaa520)]
                : [const Color(0xFF4a90e2), const Color(0xFF357abd)],
            begin: Alignment(-0.7, -0.7),
            end: Alignment(0.7, 0.7),
          ),
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 4),
          ],
        ),
        child: Center(
          child: Text(
            character,
            style: TextStyle(
              fontSize: 32,
              color: isJing ? const Color(0xFF333333) : Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}

class _CountdownTimer extends StatefulWidget {
  final int countdown;
  const _CountdownTimer({required this.countdown});

  @override
  State<_CountdownTimer> createState() => _CountdownTimerState();
}

class _CountdownTimerState extends State<_CountdownTimer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isCritical = widget.countdown <= 5;
    final isUrgent = widget.countdown <= 10;
    final isCaution = widget.countdown <= 20;
    final ringColor = isCritical
        ? const Color(0xCCff5050)
        : const Color(0x99ffd700);
    final bellColor = isCritical
        ? const Color(0xCCff5050)
        : const Color(0x99ffd700);

    final body = Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: isCritical
            ? const LinearGradient(
                begin: Alignment(-0.7, -0.7),
                end: Alignment(0.7, 0.7),
                colors: [Color(0xFFc0392b), Color(0xFFe74c3c)],
              )
            : isUrgent
            ? const LinearGradient(
                begin: Alignment(-0.7, -0.7),
                end: Alignment(0.7, 0.7),
                colors: [Color(0xFFe67e22), Color(0xFFf39c12)],
              )
            : isCaution
            ? const LinearGradient(
                begin: Alignment(-0.7, -0.7),
                end: Alignment(0.7, 0.7),
                colors: [Color(0xFFd4a017), Color(0xFFc49b10)],
              )
            : const LinearGradient(
                begin: Alignment(-0.7, -0.7),
                end: Alignment(0.7, 0.7),
                colors: [Color(0xFF2c3e50), Color(0xFF34495e)],
              ),
        boxShadow: isCritical
            ? [
                BoxShadow(
                  color: const Color(0xFFff5050).withOpacity(0.6),
                  blurRadius: 12,
                  spreadRadius: 2,
                ),
                BoxShadow(
                  color: Colors.black.withOpacity(0.4),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.4),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
                BoxShadow(
                  color: Colors.white.withOpacity(0.1),
                  blurRadius: 2,
                  offset: const Offset(0, 1),
                  spreadRadius: -1,
                ),
              ],
      ),
      alignment: Alignment.center,
      child: Text(
        '${widget.countdown}',
        style: TextStyle(
          fontSize: isCritical ? 16 : 14,
          fontWeight: FontWeight.bold,
          color: isCritical ? Colors.white : const Color(0xFFecf0f1),
        ),
      ),
    );

    // shake animation: 3 levels
    Widget animatedBody;
    if (isCritical) {
      // <=5s: violent shake + strong scale pulse
      animatedBody = AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final t = _controller.value * 2 * pi;
          final shakeOffset = sin(t * 2) * 4.0;
          final scaleValue = 1.0 + sin(t) * 0.1;
          return Transform.translate(
            offset: Offset(shakeOffset, 0),
            child: Transform.scale(scale: scaleValue, child: child),
          );
        },
        child: body,
      );
    } else if (isUrgent) {
      // <=10s: moderate shake + moderate scale
      animatedBody = AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final t = _controller.value * 2 * pi;
          final shakeOffset = sin(t) * 3.0;
          final scaleValue = 1.0 + sin(t) * 0.06;
          return Transform.translate(
            offset: Offset(shakeOffset, 0),
            child: Transform.scale(scale: scaleValue, child: child),
          );
        },
        child: body,
      );
    } else if (isCaution) {
      // <=20s: gentle slow shake + mild scale
      animatedBody = AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final t = _controller.value * 2 * pi;
          final shakeOffset = sin(t * 0.5) * 2.0;
          final scaleValue = 1.0 + sin(t * 0.5) * 0.03;
          return Transform.translate(
            offset: Offset(shakeOffset, 0),
            child: Transform.scale(scale: scaleValue, child: child),
          );
        },
        child: body,
      );
    } else {
      animatedBody = body;
    }

    return SizedBox(
      width: 36,
      height: 42,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Positioned(
            top: 0,
            child: Container(
              width: 10,
              height: 6,
              decoration: BoxDecoration(
                color: bellColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(2),
                  topRight: Radius.circular(2),
                ),
              ),
            ),
          ),
          Positioned(
            top: 5,
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: ringColor, width: 2),
              ),
            ),
          ),
          Positioned(top: 8, child: animatedBody),
        ],
      ),
    );
  }
}

class _RoundHistoryDialog extends StatelessWidget {
  final List<Map<String, dynamic>> roundHistory;
  final List<dynamic> players;

  const _RoundHistoryDialog({
    required this.roundHistory,
    this.players = const [],
  });

  String _fmtScore(int v) => v > 0 ? '+$v' : '$v';

  Widget _buildAvatar(Player player, double size, {bool isDealer = false}) {
    final isFemale = player.gender == Gender.female;
    return Container(
      width: size,
      height: size,
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
          width: 2,
        ),
        boxShadow: isDealer
            ? [
                BoxShadow(
                  color: const Color(0xFFffd700).withOpacity(0.5),
                  blurRadius: 8,
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
        style: TextStyle(fontSize: size * 0.5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    return Center(
      child: Container(
        constraints: BoxConstraints(
          maxWidth: screenSize.width * 0.85,
          maxHeight: screenSize.height * 0.8,
        ),
        padding: const EdgeInsets.only(
          left: 30,
          top: 20,
          right: 30,
          bottom: 15,
        ),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1a5c2e), Color(0xFF0d3018)],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFffd700), width: 3),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFffd700).withOpacity(0.4),
              blurRadius: 40,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '局结算记录',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Color(0xFFffd700),
              ),
            ),
            const SizedBox(height: 15),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: 30),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: roundHistory.map((round) {
                    final isLiuJu = round['isLiuJu'] == true;
                    return Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isLiuJu
                              ? const Color(0xFF555555).withOpacity(0.3)
                              : const Color(0xFFffd700).withOpacity(0.2),
                        ),
                      ),
                      child: isLiuJu
                          ? _buildLiuJuRound(round)
                          : _buildHuRound(round),
                    );
                  }).toList(),
                ),
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: Container(
                width: 80,
                height: 32,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF4ecdc4), Color(0xFF3db8b0)],
                    begin: Alignment(-0.7, -0.7),
                    end: Alignment(0.7, 0.7),
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    '关闭',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLiuJuRound(Map<String, dynamic> round) {
    return Stack(
      children: [
        Positioned(
          top: 0,
          right: 0,
          child: Text(
            '${round['roundNumber']}',
            style: TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.w900,
              color: const Color(0xFFffffff).withOpacity(0.06),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Center(
            child: Text(
              '第${round['roundNumber']}局  流局',
              style: const TextStyle(
                fontSize: 16,
                color: Color(0xFF888888),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHuRound(Map<String, dynamic> round) {
    final winnerIndex = round['winnerIndex'] as int;
    final scoreChanges = round['scoreChanges'] as List<dynamic>;
    final dianpaoIndex = round['dianpaoIndex'] as int?;
    final method = round['method'] as String;
    final huType = round['huType'] as String;
    final multiplier = round['multiplier'] as int;
    final isZimo = method == '自摸';
    final dealerIndex = round['dealerIndex'] as int?;

    final winner = winnerIndex < players.length
        ? players[winnerIndex] as Player
        : null;

    return Stack(
      children: [
        // round number watermark
        Positioned(
          top: 2,
          right: 8,
          child: Text(
            '${round['roundNumber']}',
            style: TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.w900,
              color: const Color(0xFFffd700).withOpacity(0.12),
            ),
          ),
        ),
        // top-right glow
        Positioned(
          top: -20,
          right: -20,
          child: Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFffd700).withOpacity(0.05),
            ),
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // header: winner avatar + hu type + method
            Row(
              children: [
                if (winner != null)
                  _buildAvatar(
                    winner,
                    32,
                    isDealer: winnerIndex == dealerIndex,
                  ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        huType,
                        style: const TextStyle(
                          fontSize: 18,
                          color: Color(0xFFffd700),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '$method · $multiplier倍',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFFaaaaaa),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // three players side by side
            Row(
              children: List.generate(players.length, (i) {
                final player = players[i] as Player;
                final sc = i < scoreChanges.length ? scoreChanges[i] as int : 0;
                final isWinner = i == winnerIndex;
                final isDianpao = !isZimo && dianpaoIndex == i;
                final isLoser = sc < 0 && !isDianpao;

                Color bgColor;
                Color borderColor;
                String role;
                Color roleColor;

                if (isWinner) {
                  bgColor = const Color(0xFFffd700).withOpacity(0.12);
                  borderColor = const Color(0xFFffd700).withOpacity(0.3);
                  role = '赢家';
                  roleColor = const Color(0xFFffd700);
                } else if (isDianpao) {
                  bgColor = const Color(0xFF4ecdc4).withOpacity(0.08);
                  borderColor = const Color(0xFF4ecdc4).withOpacity(0.15);
                  role = '点炮';
                  roleColor = const Color(0xFF4ecdc4);
                } else if (isLoser) {
                  bgColor = const Color(0xFFff6b6b).withOpacity(0.08);
                  borderColor = const Color(0xFFff6b6b).withOpacity(0.15);
                  role = '输家';
                  roleColor = const Color(0xFFff6b6b);
                } else {
                  bgColor = const Color(0xFF666666).withOpacity(0.08);
                  borderColor = const Color(0xFF666666).withOpacity(0.15);
                  role = '';
                  roleColor = const Color(0xFF666666);
                }

                return Expanded(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    padding: const EdgeInsets.symmetric(
                      vertical: 8,
                      horizontal: 4,
                    ),
                    decoration: BoxDecoration(
                      color: bgColor,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: borderColor),
                    ),
                    child: Column(
                      children: [
                        _buildAvatar(player, 26, isDealer: i == dealerIndex),
                        const SizedBox(height: 4),
                        Text(
                          player.name,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFFcccccc),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _fmtScore(sc),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: sc > 0
                                ? const Color(0xFFffd700)
                                : sc < 0
                                ? const Color(0xFFff6b6b)
                                : const Color(0xFF666666),
                          ),
                        ),
                        if (role.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            role,
                            style: TextStyle(fontSize: 10, color: roleColor),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              }),
            ),
          ],
        ),
      ],
    );
  }
}

class _MeasureSize extends StatefulWidget {
  final Widget child;
  final void Function(Size size) onSizeChanged;
  final int playerIndex;

  const _MeasureSize({
    required this.child,
    required this.onSizeChanged,
    required this.playerIndex,
  });

  @override
  State<_MeasureSize> createState() => _MeasureSizeState();
}

class _MeasureSizeState extends State<_MeasureSize> {
  Size? _oldSize;

  @override
  Widget build(BuildContext context) {
    return NotificationListener<SizeChangedLayoutNotification>(
      onNotification: (notification) {
        _postFrameCallback();
        return true;
      },
      child: SizeChangedLayoutNotifier(child: widget.child),
    );
  }

  void _postFrameCallback() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final box = context.findRenderObject() as RenderBox?;
      if (box == null || !box.hasSize) return;
      final newSize = box.size;
      if (_oldSize == null ||
          _oldSize!.width != newSize.width ||
          _oldSize!.height != newSize.height) {
        _oldSize = newSize;
        widget.onSizeChanged(newSize);
      }
    });
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _postFrameCallback());
  }
}
