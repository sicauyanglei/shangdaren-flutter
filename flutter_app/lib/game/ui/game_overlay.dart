import 'dart:async';
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
          child: _AIPlayerInfo(
            player: player0,
            dealerIndex: gameState.dealerIndex,
            currentPlayerIndex: gameState.currentPlayerIndex,
            countdown: gameState.currentPlayerIndex == 0
                ? gameState.countdown
                : 0,
            animatingScore: displayScores[0],
          ),
        ),
        Positioned(
          right: 9.6,
          top: 4.8,
          child: _AIPlayerInfo(
            player: player2,
            dealerIndex: gameState.dealerIndex,
            currentPlayerIndex: gameState.currentPlayerIndex,
            countdown: gameState.currentPlayerIndex == 2
                ? gameState.countdown
                : 0,
            animatingScore: displayScores[2],
          ),
        ),
        Positioned(
          bottom: 5,
          left: 10,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _MyPlayerInfo(
                player: player1,
                gameState: gameState,
                onAvatarTap: onSettings,
                animatingScore: displayScores[1],
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
                if (gameState.canHu && gameState.isZimoOpportunity) ...[
                  const SizedBox(width: 14),
                  GameArtButton(
                    label: '自摸',
                    type: GameButtonType.zimo,
                    onTap: onHu,
                  ),
                ],
              ],
            ),
          ),
        ),
        Positioned(
          bottom: 9.6,
          right: 9.6,
          child: _RoundInfo(
            roundNumber: gameState.roundNumber,
            showHuDisplay: gameState.showHuResult || gameState.showLiujuResult,
            isLastRound: gameState.roundNumber >= 8,
            onNextRound: onNextRound,
            onShowSettlement: onShowSettlementFromButton,
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
                      : const LinearGradient(
                          colors: [Color(0xFF4a7c59), Color(0xFF2d5a3d)],
                          begin: Alignment(-0.7, -0.7),
                          end: Alignment(0.7, 0.7),
                        ),
                  border: Border.all(
                    color: isDealer
                        ? const Color(0xFFffd700)
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
                  isDealer ? '👑' : '👨‍🌾',
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
              if (isCurrentTurn)
                Positioned(
                  top: -8,
                  left: -8,
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [Color(0xFF2c3e50), Color(0xFF34495e)],
                        begin: Alignment(-0.7, -0.7),
                        end: Alignment(0.7, 0.7),
                      ),
                      border: Border.all(
                        color: const Color(0xFFffd700).withOpacity(0.6),
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.4),
                          blurRadius: 8,
                        ),
                      ],
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
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${player!.hand.length}张',
                      style: const TextStyle(
                        fontSize: 20,
                        color: Color(0xFFffd700),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${animatingScore ?? player!.score}分',
                    style: TextStyle(
                      fontSize: 20,
                      color: animatingScore != null
                          ? const Color(0xFFffd700)
                          : const Color(0xFF4ecdc4),
                    ),
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
                        : const LinearGradient(
                            colors: [Color(0xFF4a7c59), Color(0xFF2d5a3d)],
                            begin: Alignment(-0.7, -0.7),
                            end: Alignment(0.7, 0.7),
                          ),
                    border: Border.all(
                      color: isDealer
                          ? const Color(0xFFffd700)
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
                    isDealer ? '👑' : '👨‍🌾',
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
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${player!.hand.length}张',
                      style: const TextStyle(
                        fontSize: 20,
                        color: Color(0xFFffd700),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${animatingScore ?? player!.score}分',
                    style: TextStyle(
                      fontSize: 20,
                      color: animatingScore != null
                          ? const Color(0xFFffd700)
                          : const Color(0xFF4ecdc4),
                    ),
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
  final bool showHuDisplay;
  final bool isLastRound;
  final VoidCallback? onNextRound;
  final VoidCallback? onShowSettlement;

  const _RoundInfo({
    required this.roundNumber,
    this.showHuDisplay = false,
    this.isLastRound = false,
    this.onNextRound,
    this.onShowSettlement,
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

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.5),
        borderRadius: BorderRadius.circular(14.4),
      ),
      child: Text(
        '${widget.roundNumber}/8',
        style: const TextStyle(
          fontSize: 26,
          fontWeight: FontWeight.bold,
          color: Color(0xFFffd700),
          shadows: [Shadow(color: Color(0x80000000), blurRadius: 5)],
        ),
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
    final isWarning = widget.countdown <= 5;
    final ringColor = isWarning
        ? const Color(0xCCff5050)
        : const Color(0x99ffd700);
    final bellColor = isWarning
        ? const Color(0xCCff5050)
        : const Color(0x99ffd700);

    final body = Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: isWarning
            ? const LinearGradient(
                begin: Alignment(-0.7, -0.7),
                end: Alignment(0.7, 0.7),
                colors: [Color(0xFFc0392b), Color(0xFFe74c3c)],
              )
            : const LinearGradient(
                begin: Alignment(-0.7, -0.7),
                end: Alignment(0.7, 0.7),
                colors: [Color(0xFF2c3e50), Color(0xFF34495e)],
              ),
        boxShadow: [
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
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: isWarning ? Colors.white : const Color(0xFFecf0f1),
        ),
      ),
    );

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
          Positioned(
            top: 8,
            child: isWarning
                ? ScaleTransition(
                    scale: Tween<double>(begin: 1.0, end: 1.08).animate(
                      CurvedAnimation(
                        parent: _controller,
                        curve: Curves.easeInOut,
                      ),
                    ),
                    child: body,
                  )
                : body,
          ),
        ],
      ),
    );
  }
}
