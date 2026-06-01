import 'package:flutter/material.dart' hide Card;
import '../models/card.dart';
import '../models/meld.dart';
import '../models/player.dart';

class LiujuOverlay extends StatefulWidget {
  final List<Player> players;
  final VoidCallback? onClose;

  const LiujuOverlay({super.key, required this.players, this.onClose});

  @override
  State<LiujuOverlay> createState() => _LiujuOverlayState();
}

class _LiujuOverlayState extends State<LiujuOverlay> {
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
                    minWidth: 680,
                    maxWidth: screenSize.width * 0.85,
                    maxHeight: screenSize.height * 0.9,
                  ),
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1a5c2e).withOpacity(0.95),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: const Color(0xFFffd700),
                      width: 3,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFffd700).withOpacity(0.5),
                        blurRadius: 20,
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          Text(
                            '流局',
                            style: TextStyle(
                              fontSize: 72,
                              color: const Color(0xFFffd700),
                              fontWeight: FontWeight.bold,
                              shadows: [
                                Shadow(
                                  color: const Color(
                                    0xFFffd700,
                                  ).withOpacity(0.5),
                                  blurRadius: 10,
                                ),
                              ],
                            ),
                          ),
                          Positioned(
                            top: 0,
                            right: 0,
                            child: GestureDetector(
                              onTap: widget.onClose,
                              child: Container(
                                width: 56,
                                height: 56,
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.15),
                                  shape: BoxShape.circle,
                                ),
                                alignment: Alignment.center,
                                child: const Icon(
                                  Icons.close,
                                  color: Color(0xFFffd700),
                                  size: 32,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        '牌堆已空，本局结束',
                        style: TextStyle(fontSize: 30, color: Colors.white70),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        '庄家不变，继续坐庄',
                        style: TextStyle(fontSize: 22, color: Colors.white54),
                      ),
                      const SizedBox(height: 12),
                      _buildPlayersHands(),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: 260,
                        height: 68,
                        child: ElevatedButton(
                          onPressed: widget.onClose,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFffd700),
                            foregroundColor: const Color(0xFF1a472a),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                          child: const Text(
                            '确定',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
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

  Widget _buildPlayersHands() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: widget.players.map((player) {
          return Container(
            margin: const EdgeInsets.symmetric(vertical: 4),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  player.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFffd700),
                    fontSize: 22,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _buildHandCards(player)),
                    if (player.melds.isNotEmpty) ...[
                      Container(
                        margin: const EdgeInsets.only(left: 12),
                        padding: const EdgeInsets.only(left: 10),
                        decoration: const BoxDecoration(
                          border: Border(
                            left: BorderSide(
                              color: Color(0x4Dffffff),
                              width: 3,
                            ),
                          ),
                        ),
                        child: _buildMeldCards(player.melds),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildHandCards(Player player) {
    final sortedHand = List<Card>.from(player.hand);
    sortedHand.sort((a, b) {
      if (a.sentence != b.sentence) return a.sentence.compareTo(b.sentence);
      return a.position.compareTo(b.position);
    });

    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: sortedHand.map((card) => _buildSmallCard(card)).toList(),
    );
  }

  Widget _buildMeldCards(List<Meld> melds) {
    final sortedCards = <Card>[];
    for (final meld in melds) {
      final sortedMeldCards = List<Card>.from(meld.cards);
      sortedMeldCards.sort((a, b) => a.position.compareTo(b.position));
      sortedCards.addAll(sortedMeldCards);
    }

    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: sortedCards.map((card) => _buildSmallCard(card)).toList(),
    );
  }

  Widget _buildSmallCard(Card card) {
    final isJing = card.isJing;
    Color bgColor;
    Color borderColor;
    if (isJing) {
      bgColor = const Color(0xFFcc0000);
      borderColor = const Color(0xFFff4444);
    } else if (card.sentence == 1 || card.sentence == 8) {
      bgColor = const Color(0xFFcc0000);
      borderColor = const Color(0xFFff4444);
    } else {
      bgColor = const Color(0xFF228822);
      borderColor = const Color(0xFF33bb33);
    }

    return Container(
      width: 48,
      height: 72,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(2),
        border: Border.all(color: borderColor, width: 1),
        boxShadow: isJing
            ? [
                BoxShadow(
                  color: const Color(0xFFd32f2f).withOpacity(0.6),
                  blurRadius: 3,
                ),
              ]
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 1,
                  offset: const Offset(1, 1),
                ),
              ],
      ),
      alignment: Alignment.center,
      child: Text(
        card.character,
        style: const TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    );
  }
}
