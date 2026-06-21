import 'package:flutter_test/flutter_test.dart';
import 'package:shangdaren_game/game/logic/ai/ai_strategy_hard.dart';
import 'package:shangdaren_game/game/models/card.dart';
import 'package:shangdaren_game/game/models/game_state.dart';
import 'package:shangdaren_game/game/models/meld.dart';
import 'package:shangdaren_game/game/models/player.dart';

void main() {
  test('AI should discard 十 to form 七十五 sentence', () {
    // 场景：
    // 玩家1-组合牌"大上人"，弃牌""
    // 玩家2-组合牌""，弃牌""
    // 我-组合牌"乙乙乙"，弃牌"小"，手牌"上人己己七十十土九子佳佳作福福禄寿"

    final hand = <Card>[
      // 门1: 上、人（差大）
      Card(id: 1, character: '上', sentence: 1, position: 0),
      Card(id: 2, character: '人', sentence: 1, position: 2),
      // 门2: 己己（对子，乙已在melds）
      Card(id: 3, character: '己', sentence: 2, position: 2),
      Card(id: 4, character: '己', sentence: 2, position: 2),
      // 门4: 七、十十、土（出十可成句七十五）
      Card(id: 5, character: '七', sentence: 4, position: 0),
      Card(id: 6, character: '十', sentence: 4, position: 1),
      Card(id: 7, character: '十', sentence: 4, position: 1),
      Card(id: 8, character: '土', sentence: 4, position: 2),
      // 门6: 九、子（差八）
      Card(id: 9, character: '九', sentence: 6, position: 1),
      Card(id: 10, character: '子', sentence: 6, position: 2),
      // 门7: 佳佳、作（差亡）
      Card(id: 11, character: '佳', sentence: 7, position: 0),
      Card(id: 12, character: '佳', sentence: 7, position: 0),
      Card(id: 13, character: '作', sentence: 7, position: 1),
      // 门8: 福福、禄、寿（可成句）
      Card(id: 14, character: '福', sentence: 8, position: 0),
      Card(id: 15, character: '福', sentence: 8, position: 0),
      Card(id: 16, character: '禄', sentence: 8, position: 1),
      Card(id: 17, character: '寿', sentence: 8, position: 2),
    ];

    final melds = <Meld>[
      Meld(
        cards: [
          Card(id: 101, character: '乙', sentence: 2, position: 1),
          Card(id: 102, character: '乙', sentence: 2, position: 1),
          Card(id: 103, character: '乙', sentence: 2, position: 1),
        ],
        type: MeldType.kan,
        isJing: false,
      ),
    ];

    final player = Player(
      id: 0,
      name: 'AI',
      type: PlayerType.ai,
      hand: hand,
      melds: melds,
      discards: [Card(id: 501, character: '小', sentence: 5, position: 1)],
    );

    // 玩家1-组合牌"大上人"
    final p1 = Player(
      id: 1,
      name: 'P1',
      type: PlayerType.ai,
      hand: [],
      melds: [
        Meld(
          cards: [
            Card(id: 301, character: '大', sentence: 1, position: 1),
            Card(id: 302, character: '上', sentence: 1, position: 0),
            Card(id: 303, character: '人', sentence: 1, position: 2),
          ],
          type: MeldType.ju,
          isJing: false,
        ),
      ],
      discards: [],
    );

    // 玩家2-无组合牌
    final p2 = Player(
      id: 2,
      name: 'P2',
      type: PlayerType.ai,
      hand: [],
      melds: [],
      discards: [],
    );

    // publicCardCount: 我的手牌+组合牌+弃牌，玩家1组合牌
    final publicCardCount = <String, int>{
      '乙': 3,
      '小': 1,
      '大': 1,
      '上': 1,
      '人': 1,
    };

    final state = GameState(publicCardCount: publicCardCount);
    state.totalVisibleCards = 3 + 1 + 1 + 1 + 1;
    state.players = [player, p1, p2];

    final strategy = AIStrategyHard();

    final selected = strategy.selectDiscard(player, state);
    print('AI选择出: ${selected.character}');

    // AI应该出"十"，因为出十后门4形成"七十五"句
    expect(selected.character, '十',
        reason: '出十可形成七十五句，比保留十十对子更优');
  });
}
