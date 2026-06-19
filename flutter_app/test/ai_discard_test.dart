import 'package:flutter_test/flutter_test.dart';
import 'package:shangdaren_game/game/models/card.dart';
import 'package:shangdaren_game/game/models/player.dart';
import 'package:shangdaren_game/game/models/game_state.dart';
import 'package:shangdaren_game/game/logic/ai/ai_strategy_hard.dart';

void main() {
  test('analyze discard choice', () {
    // 手牌：上大人人丘丘化化三千千七十尔八子作作福福
    final handStr = '上大人人丘丘化化三千千七十尔八子作作福福';
    var id = 0;
    final hand = <Card>[];
    for (final ch in handStr.split('')) {
      final sentence = _getSentence(ch);
      final position = _getPosition(ch);
      hand.add(Card(
        id: id++,
        character: ch,
        sentence: sentence,
        position: position,
      ));
    }

    // 弃牌：人（1张）
    final discards = <Card>[
      Card(id: id++, character: '人', sentence: 1, position: 2),
    ];

    final player = Player(
      id: 0,
      name: '我',
      type: PlayerType.ai,
      hand: hand,
      discards: discards,
    );

    // 构建GameState
    final state = GameState(
      players: [player],
      currentPlayerIndex: 0,
      dealerIndex: 0,
      roundNumber: 1,
      deck: List.filled(38, Card(id: 999, character: '上', sentence: 1, position: 0)),
    );
    state.publicCardCount = {'人': 1};
    state.totalVisibleCards = 1;

    final ai = AIStrategyHard();
    final result = ai.selectDiscard(player, state);
    print('Selected discard: ${result.character}');
  });
}

int _getSentence(String ch) {
  const groups = [
    ['上', '大', '人'],
    ['丘', '乙', '己'],
    ['化', '三', '千'],
    ['七', '十', '土'],
    ['尔', '小', '生'],
    ['八', '九', '子'],
    ['佳', '作', '亡'],
    ['福', '禄', '寿'],
  ];
  for (var i = 0; i < groups.length; i++) {
    if (groups[i].contains(ch)) return i + 1;
  }
  return 0;
}

int _getPosition(String ch) {
  const groups = [
    ['上', '大', '人'],
    ['丘', '乙', '己'],
    ['化', '三', '千'],
    ['七', '十', '土'],
    ['尔', '小', '生'],
    ['八', '九', '子'],
    ['佳', '作', '亡'],
    ['福', '禄', '寿'],
  ];
  for (var i = 0; i < groups.length; i++) {
    for (var j = 0; j < groups[i].length; j++) {
      if (groups[i][j] == ch) return j;
    }
  }
  return 0;
}
