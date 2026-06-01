import 'package:flutter/material.dart';
import '../models/player.dart';

class SettlementScreen extends StatefulWidget {
  final List<Player> players;
  final List<Map<String, dynamic>> roundResults;
  final VoidCallback? onClose;

  const SettlementScreen({
    super.key,
    required this.players,
    required this.roundResults,
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
              left: 40,
              top: 25,
              right: 40,
              bottom: 60,
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
            child: Stack(
              children: [
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      '游戏结算',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFffd700),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Flexible(
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildTotalScores(),
                            const SizedBox(height: 20),
                            _buildRoundResults(),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
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

  Widget _buildRoundResults() {
    return Column(
      children: widget.roundResults.map((round) {
        final isLiuJu = round['isLiuJu'] == true;
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(15),
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.3),
            borderRadius: BorderRadius.circular(10),
            border: Border(
              left: BorderSide(color: const Color(0xFFffd700), width: 4),
            ),
          ),
          child: isLiuJu
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '第${round['roundNumber']}局 流局',
                      style: const TextStyle(
                        fontSize: 18,
                        color: Color(0xFFffd700),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '流局',
                      style: TextStyle(
                        color: Color(0xFFaaaaaa),
                        fontStyle: FontStyle.italic,
                        fontSize: 14,
                      ),
                    ),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '第${round['roundNumber']}局',
                      style: const TextStyle(
                        fontSize: 18,
                        color: Color(0xFFffd700),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildRoundResultContent(round),
                  ],
                ),
        );
      }).toList(),
    );
  }

  Widget _buildRoundResultContent(Map<String, dynamic> round) {
    final scoreChanges = round['scoreChanges'] as List<dynamic>?;
    final piaoScores = round['piaoScores'] as List<dynamic>?;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            style: const TextStyle(fontSize: 14, height: 1.6),
            children: [
              const TextSpan(text: '赢家: '),
              TextSpan(
                text: '${round['winner']}',
                style: const TextStyle(
                  color: Color(0xFF4ecdc4),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        Text(
          '${round['huType']} ${round['method']}',
          style: const TextStyle(
            color: Color(0xFFff6b6b),
            fontSize: 14,
            height: 1.6,
          ),
        ),
        RichText(
          text: TextSpan(
            style: const TextStyle(fontSize: 14, height: 1.6),
            children: [
              const TextSpan(text: '倍数: '),
              TextSpan(
                text: '${round['multiplier']}倍',
                style: const TextStyle(
                  color: Color(0xFF4ecdc4),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        Text(
          '得分: ${round['score']}分',
          style: const TextStyle(
            color: Color(0xFFffd700),
            fontSize: 14,
            height: 1.6,
          ),
        ),
        if (scoreChanges != null) ...[
          const SizedBox(height: 5),
          Wrap(
            spacing: 10,
            runSpacing: 4,
            children: List.generate(widget.players.length, (j) {
              if (j == round['winnerIndex']) return const SizedBox.shrink();
              final change = scoreChanges.length > j
                  ? scoreChanges[j] as int
                  : 0;
              if (change == 0) return const SizedBox.shrink();
              return Text(
                '${widget.players[j].name}输: ${change.abs()}分',
                style: const TextStyle(color: Color(0xFFff6b6b), fontSize: 13),
              );
            }),
          ),
        ],
        if (piaoScores != null && piaoScores.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              '飘分: ${widget.players.asMap().entries.map((e) => '${e.value.name}(${piaoScores.length > e.key ? piaoScores[e.key] : 0})').join(' ')}',
              style: const TextStyle(color: Color(0xFFaaaaaa), fontSize: 12),
            ),
          ),
      ],
    );
  }

  Widget _buildTotalScores() {
    final totalScores = widget.players.map((p) => p.score).toList();
    final maxScore = totalScores.isEmpty
        ? 0
        : totalScores.reduce((a, b) => a > b ? a : b);
    final winners = widget.players
        .asMap()
        .entries
        .where((e) => totalScores[e.key] == maxScore)
        .map((e) => e.value.name)
        .toList();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFffd700).withOpacity(0.1),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: const Color(0xFFffd700), width: 2),
      ),
      child: Column(
        children: [
          const Text(
            '总结算',
            style: TextStyle(
              fontSize: 24,
              color: Color(0xFFffd700),
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 15),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: widget.players.asMap().entries.map((entry) {
              final index = entry.key;
              final player = entry.value;
              final score = totalScores[index];
              final isWinner = score == maxScore;

              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: isWinner
                      ? const Color(0xFFffd700).withOpacity(0.3)
                      : Colors.black.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(10),
                  border: isWinner
                      ? Border.all(color: const Color(0xFFffd700), width: 2)
                      : null,
                ),
                child: Column(
                  children: [
                    Text(
                      player.name,
                      style: const TextStyle(fontSize: 16, color: Colors.white),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '${score >= 0 ? '+' : ''}$score分',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: isWinner
                            ? const Color(0xFFffd700)
                            : const Color(0xFF4ecdc4),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 15),
          Text(
            '赢家: ${winners.join(', ')}',
            style: const TextStyle(
              fontSize: 20,
              color: Color(0xFFffd700),
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
