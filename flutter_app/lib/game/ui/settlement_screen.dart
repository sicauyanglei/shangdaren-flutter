import 'package:flutter/material.dart';
import '../models/player.dart';
import '../models/game_recording.dart';

class SettlementScreen extends StatefulWidget {
  final List<Player> players;
  final List<Map<String, dynamic>> roundResults;
  final GameRecording? recording; // 录制数据
  final void Function(RoundRecording)? onReplayRound; // 回放回调
  final VoidCallback? onClose;

  const SettlementScreen({
    super.key,
    required this.players,
    required this.roundResults,
    this.recording,
    this.onReplayRound,
    this.onClose,
  });

  @override
  State<SettlementScreen> createState() => _SettlementScreenState();
}

class _SettlementScreenState extends State<SettlementScreen> {
  double _dragOffset = 0;

  void _onVerticalDragEnd(DragEndDetails details) {
    if (_dragOffset.abs() > 100) {
      widget.onClose?.call();
    } else {
      setState(() => _dragOffset = 0);
    }
  }

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

    return GestureDetector(
      onVerticalDragUpdate: (details) {
        setState(() => _dragOffset += details.delta.dy);
      },
      onVerticalDragEnd: _onVerticalDragEnd,
      child: Container(
        width: screenSize.width,
        height: screenSize.height,
        color: Colors.black.withOpacity(0.95),
        child: Center(
          child: Container(
            constraints: BoxConstraints(
              maxWidth: screenSize.width * 0.9,
              maxHeight: screenSize.height * 0.9,
            ),
            padding: const EdgeInsets.only(
              left: 30,
              top: 20,
              right: 30,
              bottom: 16,
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
                  spreadRadius: 0,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  '游戏结算',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFffd700),
                  ),
                ),
                const SizedBox(height: 14),
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.only(bottom: 40),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildTotalScores(),
                        const SizedBox(height: 14),
                        _buildRoundResults(),
                      ],
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: Container(
                    width: 90,
                    height: 36,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF4ecdc4), Color(0xFF3db8b0)],
                        begin: Alignment(-0.7, -0.7),
                        end: Alignment(0.7, 0.7),
                      ),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: ElevatedButton(
                      onPressed: widget.onClose,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      child: const Text(
                        '确认',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTotalScores() {
    final totalScores = widget.players.map((p) => p.score).toList();
    final maxScore = totalScores.isEmpty
        ? 0
        : totalScores.reduce((a, b) => a > b ? a : b);
    final minScore = totalScores.isEmpty
        ? 0
        : totalScores.reduce((a, b) => a < b ? a : b);
    final range = (maxScore - minScore).abs();
    if (range == 0) {
      // all same score
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFffd700).withOpacity(0.08),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: const Color(0xFFffd700), width: 2),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: widget.players.asMap().entries.map((entry) {
          final index = entry.key;
          final player = entry.value;
          final score = totalScores[index];
          final isWinner = score == maxScore;
          final barPct = range == 0
              ? 0.5
              : ((score - minScore) / range).clamp(0.05, 1.0);

          return Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
              decoration: BoxDecoration(
                color: isWinner
                    ? const Color(0xFFffd700).withOpacity(0.2)
                    : Colors.black.withOpacity(0.3),
                borderRadius: BorderRadius.circular(12),
                border: isWinner
                    ? Border.all(color: const Color(0xFFffd700), width: 2)
                    : Border.all(color: Colors.transparent, width: 2),
              ),
              child: Column(
                children: [
                  if (isWinner)
                    const Text('👑', style: TextStyle(fontSize: 18))
                  else
                    const SizedBox(height: 18),
                  const SizedBox(height: 4),
                  _buildAvatar(player, 40),
                  const SizedBox(height: 4),
                  Text(
                    player.name,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFFcccccc),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${_fmtScore(score)}',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: score >= 0
                          ? const Color(0xFFffd700)
                          : const Color(0xFFff6b6b),
                    ),
                  ),
                  const SizedBox(height: 4),
                  // score bar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: SizedBox(
                      width: 80,
                      height: 6,
                      child: LinearProgressIndicator(
                        value: barPct,
                        backgroundColor: Colors.white.withOpacity(0.1),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          score >= 0
                              ? const Color(0xFFffd700)
                              : const Color(0xFFff6b6b),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildRoundResults() {
    return Column(
      children: widget.roundResults.asMap().entries.map((entry) {
        final index = entry.key;
        final round = entry.value;
        final isLiuJu = round['isLiuJu'] == true;
        // 获取对应的录制数据
        final roundRecording = widget.recording != null &&
                index < widget.recording!.rounds.length
            ? widget.recording!.rounds[index]
            : null;
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
              ? _buildLiuJuRound(round, roundRecording)
              : _buildHuRound(round, roundRecording),
        );
      }).toList(),
    );
  }

  Widget _buildLiuJuRound(Map<String, dynamic> round, [RoundRecording? roundRecording]) {
    return Stack(
      children: [
        // round number watermark
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
          child: Row(
            children: [
              Expanded(
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
              if (roundRecording != null)
                _buildReplayButton(roundRecording),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHuRound(Map<String, dynamic> round, [RoundRecording? roundRecording]) {
    final winnerIndex = round['winnerIndex'] as int;
    final winner = widget.players[winnerIndex];
    final scoreChanges = round['scoreChanges'] as List<dynamic>;
    final dianpaoIndex = round['dianpaoIndex'] as int?;
    final method = round['method'] as String;
    final huType = round['huType'] as String;
    final multiplier = round['multiplier'] as int;
    final isZimo = method == '自摸';
    final dealerIndex = round['dealerIndex'] as int?;

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
                _buildAvatar(winner, 32, isDealer: winnerIndex == dealerIndex),
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
                if (roundRecording != null)
                  _buildReplayButton(roundRecording),
              ],
            ),
            const SizedBox(height: 8),
            // three players side by side
            Row(
              children: List.generate(widget.players.length, (i) {
                final player = widget.players[i];
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

  Widget _buildReplayButton(RoundRecording roundRecording) {
    return GestureDetector(
      onTap: () => widget.onReplayRound?.call(roundRecording),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF4ecdc4), Color(0xFF3db8b0)],
            begin: Alignment(-0.7, -0.7),
            end: Alignment(0.7, 0.7),
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF4ecdc4).withOpacity(0.3),
              blurRadius: 8,
            ),
          ],
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.play_circle_outline, size: 16, color: Colors.white),
            SizedBox(width: 4),
            Text(
              '回放',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
