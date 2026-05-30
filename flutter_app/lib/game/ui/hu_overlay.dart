import 'dart:math' as math;
import 'package:flutter/material.dart' hide Card;
import '../core/atlas_loader.dart';
import '../models/card.dart';
import '../models/meld.dart';
import '../models/player.dart';

class HuOverlay extends StatefulWidget {
  final Map<String, dynamic> huInfo;
  final VoidCallback? onClose;

  const HuOverlay({super.key, required this.huInfo, this.onClose});

  @override
  State<HuOverlay> createState() => _HuOverlayState();
}

class _HuOverlayState extends State<HuOverlay>
    with SingleTickerProviderStateMixin {
  double _dragOffset = 0;
  late AnimationController _glowController;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat();
  }

  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
  }

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
    final info = widget.huInfo;

    final playerName = info['playerName'] as String? ?? '';
    final methodName = info['methodName'] as String? ?? '';
    final huTypeName = info['huTypeName'] as String? ?? '';
    final huCount = info['huCount'] as int? ?? 0;
    final multiplier = info['multiplier'] as int? ?? 0;
    final score = info['score'] as int? ?? 0;
    final dianpaoName = info['dianpaoName'] as String?;
    final method = info['method'] as String? ?? '';
    final winnerHand = info['winnerHand'] as List<Card>?;
    final winnerMelds = info['winnerMelds'] as List<Meld>?;
    final huCard = info['huCard'] as Card?;
    final loserScores = info['loserScores'] as List<Map<String, dynamic>>?;

    return Stack(
      children: [
        GestureDetector(
          onTap: widget.onClose,
          child: Container(
            width: screenSize.width,
            height: screenSize.height,
            color: Colors.black.withOpacity(0.5),
          ),
        ),
        GestureDetector(
          onVerticalDragUpdate: (details) {
            setState(() => _dragOffset += details.delta.dy);
          },
          onVerticalDragEnd: _onVerticalDragEnd,
          child: Container(
            width: screenSize.width,
            height: screenSize.height,
            color: Colors.black.withOpacity(0.7),
            child: Center(
              child: SingleChildScrollView(
                child: Container(
                  constraints: BoxConstraints(
                    maxWidth: screenSize.width * 0.9,
                    maxHeight: screenSize.height * 0.9,
                  ),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0x80000000), Color(0x4D000000)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFFffd700).withOpacity(0.4),
                      width: 2,
                    ),
                  ),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned(
                        top: -screenSize.height * 0.5,
                        left: -screenSize.width * 0.5,
                        right: -screenSize.width * 0.5,
                        bottom: -screenSize.height * 0.5,
                        child: IgnorePointer(
                          child: AnimatedBuilder(
                            animation: _glowController,
                            builder: (context, child) {
                              final t = _glowController.value;
                              final pulse = (1 + math.sin(t * 2 * math.pi)) / 2;
                              return Container(
                                decoration: BoxDecoration(
                                  gradient: RadialGradient(
                                    center: Alignment.center,
                                    radius: 0.7,
                                    colors: [
                                      Color(
                                        0xFFffd700,
                                      ).withOpacity(0.05 * pulse),
                                      Colors.transparent,
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: GestureDetector(
                          onTap: widget.onClose,
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: const Color(0xFFcc0000),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.3),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            alignment: Alignment.center,
                            child: CustomPaint(
                              size: const Size(20, 20),
                              painter: _CloseIconPainter(),
                            ),
                          ),
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '\u{1F389} $playerName \u80E1\u724C!',
                            style: TextStyle(
                              fontSize: 22,
                              color: const Color(0xFFffd700),
                              shadows: [
                                Shadow(
                                  color: const Color(
                                    0xFFffd700,
                                  ).withOpacity(0.5),
                                  blurRadius: 15,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            alignment: WrapAlignment.center,
                            spacing: 8,
                            runSpacing: 4,
                            children: [
                              _buildTag(
                                '$methodName${dianpaoName != null ? " - $dianpaoName\u70B9\u70AE" : ""}',
                                Colors.white.withOpacity(0.15),
                                Colors.white,
                              ),
                              _buildTag(
                                huTypeName,
                                const Color(0xFF4ecdc4).withOpacity(0.2),
                                const Color(0xFF4ecdc4),
                              ),
                              _buildTag(
                                '\u80E1\u6570: $huCount',
                                const Color(0xFFffd700).withOpacity(0.2),
                                const Color(0xFFffd700),
                              ),
                              _buildTag(
                                '$multiplier\u500D',
                                const Color(0xFFff6b6b).withOpacity(0.2),
                                const Color(0xFFff6b6b),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          RichText(
                            text: TextSpan(
                              children: [
                                TextSpan(
                                  text: '+$score ',
                                  style: TextStyle(
                                    fontSize: 32,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFFffd700),
                                    shadows: [
                                      Shadow(
                                        color: const Color(
                                          0xFFffd700,
                                        ).withOpacity(0.4),
                                        blurRadius: 20,
                                      ),
                                    ],
                                  ),
                                ),
                                TextSpan(
                                  text: '\u5206',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: const Color(
                                      0xFFffd700,
                                    ).withOpacity(0.7),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (winnerHand != null && winnerHand.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            _buildHandDisplay(winnerHand, huCard, method),
                          ],
                          if (winnerMelds != null &&
                              winnerMelds.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            _buildMeldsDisplay(winnerMelds),
                          ],
                          if (loserScores != null &&
                              loserScores.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            _buildLosersDisplay(loserScores),
                          ],
                          const SizedBox(height: 12),
                          Container(
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                begin: Alignment(-0.7, -0.7),
                                end: Alignment(0.7, 0.7),
                                colors: [Color(0xFFffd700), Color(0xFFf0c000)],
                              ),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: widget.onClose,
                                borderRadius: BorderRadius.circular(20),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 40,
                                    vertical: 8,
                                  ),
                                  child: const Text(
                                    '\u786E\u5B9A',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF1a472a),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTag(String text, Color bgColor, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(text, style: TextStyle(fontSize: 11, color: textColor)),
    );
  }

  Widget _buildCardImage(
    String character, {
    required double width,
    required double height,
  }) {
    final pinyin = AtlasLoader.charToPinyin[character];
    if (pinyin == null) {
      return SizedBox(width: width, height: height);
    }
    final isSmall = height < 60;
    final path = isSmall
        ? 'assets/html/images/s/$pinyin.png'
        : 'assets/html/images/$pinyin.png';
    return Image.asset(
      path,
      width: width,
      height: height,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
    );
  }

  Widget _buildHandDisplay(List<Card> hand, Card? huCard, String method) {
    final sortedHand = List<Card>.from(hand);
    sortedHand.sort((a, b) {
      if (a.sentence != b.sentence) return a.sentence.compareTo(b.sentence);
      return a.position.compareTo(b.position);
    });

    final sentenceGroups = <int, Map<int, List<Card>>>{};
    for (final card in sortedHand) {
      sentenceGroups.putIfAbsent(card.sentence, () => {});
      sentenceGroups[card.sentence]!
          .putIfAbsent(card.position, () => [])
          .add(card);
    }

    if (huCard != null && sentenceGroups[huCard.sentence] != null) {
      final group = sentenceGroups[huCard.sentence]!;
      if (group[huCard.position] != null) {
        final huIdx = group[huCard.position]!.indexWhere(
          (c) => c.id == huCard.id,
        );
        if (huIdx >= 0) {
          group[huCard.position]!.removeAt(huIdx);
          final huCards = [huCard, ...group[huCard.position]!];
          final newPositions = <int, List<Card>>{};
          int posIdx = 0;
          for (int p = 0; p <= 2; p++) {
            if (p == huCard.position) continue;
            if (group[p] != null && group[p]!.isNotEmpty) {
              newPositions[posIdx] = List<Card>.from(group[p]!);
              posIdx++;
            }
          }
          newPositions[posIdx] = huCards;
          sentenceGroups[huCard.sentence] = newPositions;
        }
      }
    }

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 6,
        runSpacing: 2,
        children: sentenceGroups.entries.map((entry) {
          final positions = entry.value.entries.toList();
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: positions.asMap().entries.map((posMap) {
              final posIndex = posMap.key;
              final posEntry = posMap.value;
              final cards = posEntry.value;
              final card = cards.first;
              final count = cards.length;
              final isHuCard =
                  huCard != null && cards.any((c) => c.id == huCard.id);

              return Padding(
                padding: EdgeInsets.only(top: posIndex == 0 ? 0 : -140),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    _buildCardImage(card.character, width: 40, height: 168),
                    if (isHuCard)
                      Positioned.fill(
                        child: Center(
                          child: Text(
                            method == '\u81EA\u6478'
                                ? '\u81EA\u6478'
                                : '\u70AE',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFFFFFFFF),
                              shadows: [
                                Shadow(
                                  color: const Color(0xFFFF0000),
                                  blurRadius: 10,
                                ),
                                Shadow(
                                  color: const Color(0xFFFF0000),
                                  blurRadius: 20,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    if (count > 1)
                      Positioned(
                        top: -5,
                        right: -5,
                        child: Container(
                          width: 18,
                          height: 18,
                          decoration: const BoxDecoration(
                            color: Color(0xFFff6b6b),
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            '$count',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              );
            }).toList(),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildMeldsDisplay(List<Meld> melds) {
    if (melds.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 4,
        runSpacing: 2,
        children: melds.map((meld) {
          final sortedCards = List<Card>.from(meld.cards);
          sortedCards.sort((a, b) => a.position.compareTo(b.position));

          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
            margin: const EdgeInsets.all(1),
            decoration: BoxDecoration(
              color: const Color(0xFFffd700).withOpacity(0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: sortedCards.map((card) {
                return Container(
                  width: 20,
                  height: 84,
                  margin: const EdgeInsets.symmetric(horizontal: 0.5),
                  child: _buildCardImage(card.character, width: 20, height: 84),
                );
              }).toList(),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildLosersDisplay(List<Map<String, dynamic>> loserScores) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: loserScores.map((ls) {
        final name = ls['name'] as String? ?? '';
        final loseScore = ls['score'] as int? ?? 0;
        final loserHand = ls['hand'] as List<Card>?;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          margin: const EdgeInsets.symmetric(horizontal: 6),
          decoration: BoxDecoration(
            color: const Color(0xFFff6b6b).withOpacity(0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                name,
                style: const TextStyle(fontSize: 11, color: Color(0xFFaaaaaa)),
              ),
              if (loserHand != null && loserHand.isNotEmpty)
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 3),
                  child: Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 1,
                    children: loserHand.map((card) {
                      return SizedBox(
                        width: 16,
                        height: 36,
                        child: _buildCardImage(
                          card.character,
                          width: 16,
                          height: 36,
                        ),
                      );
                    }).toList(),
                  ),
                ),
              Text(
                '-$loseScore',
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFFff6b6b),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _CloseIconPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFFFFFFF)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final scaleX = size.width / 24;
    final scaleY = size.height / 24;

    canvas.drawLine(
      Offset(6 * scaleX, 6 * scaleY),
      Offset(18 * scaleX, 18 * scaleY),
      paint,
    );
    canvas.drawLine(
      Offset(6 * scaleX, 18 * scaleY),
      Offset(18 * scaleX, 6 * scaleY),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
