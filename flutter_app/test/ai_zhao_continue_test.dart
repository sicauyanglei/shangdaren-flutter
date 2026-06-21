import 'package:flutter_test/flutter_test.dart';
import 'package:shangdaren_game/game/logic/ai/ai_strategy_hard.dart';
import 'package:shangdaren_game/game/models/card.dart';
import 'package:shangdaren_game/game/models/game_state.dart';
import 'package:shangdaren_game/game/models/meld.dart';
import 'package:shangdaren_game/game/models/player.dart';

void main() {
  test('AI should continue to zhao 子 after zhao 九', () {
    // 场景：招完"九"后，手牌还有4个"子"，可以继续招"子"
    // 玩家1-组合牌"八八八",弃牌"尔作"
    // 玩家2-组合牌"十七土,土七十",弃牌"上"
    // 我-组合牌"丘丘丘,九九九九",弃牌"大",手牌"人人尔小生子子子子福福禄禄寿"

    final hand = <Card>[
      // 门1: 人人(对子)
      Card(id: 1, character: '人', sentence: 1, position: 2),
      Card(id: 2, character: '人', sentence: 1, position: 2),
      // 门2: 尔(孤张)
      Card(id: 3, character: '尔', sentence: 5, position: 0),
      // 门5: 小生(靠)
      Card(id: 4, character: '小', sentence: 5, position: 1),
      Card(id: 5, character: '生', sentence: 5, position: 2),
      // 门6: 子子子子(4张同字，可以招)
      Card(id: 6, character: '子', sentence: 6, position: 2),
      Card(id: 7, character: '子', sentence: 6, position: 2),
      Card(id: 8, character: '子', sentence: 6, position: 2),
      Card(id: 9, character: '子', sentence: 6, position: 2),
      // 门8: 福福禄禄寿
      Card(id: 10, character: '福', sentence: 8, position: 0),
      Card(id: 11, character: '福', sentence: 8, position: 0),
      Card(id: 12, character: '禄', sentence: 8, position: 1),
      Card(id: 13, character: '禄', sentence: 8, position: 1),
      Card(id: 14, character: '寿', sentence: 8, position: 2),
    ];

    // 组合牌：丘丘丘（坎）、九九九九（招）
    final melds = <Meld>[
      Meld(
        cards: [
          Card(id: 101, character: '丘', sentence: 2, position: 0),
          Card(id: 102, character: '丘', sentence: 2, position: 0),
          Card(id: 103, character: '丘', sentence: 2, position: 0),
        ],
        type: MeldType.kan,
        isJing: false,
      ),
      Meld(
        cards: [
          Card(id: 201, character: '九', sentence: 6, position: 1),
          Card(id: 202, character: '九', sentence: 6, position: 1),
          Card(id: 203, character: '九', sentence: 6, position: 1),
          Card(id: 204, character: '九', sentence: 6, position: 1),
        ],
        type: MeldType.zhao,
        isJing: false,
      ),
    ];

    final player = Player(
      id: 0,
      name: 'AI',
      type: PlayerType.ai,
      hand: hand,
      melds: melds,
      discards: [Card(id: 501, character: '大', sentence: 1, position: 1)],
    );

    // 玩家1-组合牌"八八八",弃牌"尔作"
    final p1 = Player(
      id: 1,
      name: 'P1',
      type: PlayerType.ai,
      hand: [],
      melds: [
        Meld(
          cards: [
            Card(id: 301, character: '八', sentence: 8, position: 2),
            Card(id: 302, character: '八', sentence: 8, position: 2),
            Card(id: 303, character: '八', sentence: 8, position: 2),
          ],
          type: MeldType.kan,
          isJing: false,
        ),
      ],
      discards: [
        Card(id: 311, character: '尔', sentence: 5, position: 0),
        Card(id: 312, character: '作', sentence: 7, position: 1),
      ],
    );

    // 玩家2-组合牌"十七土,土七十",弃牌"上"
    final p2 = Player(
      id: 2,
      name: 'P2',
      type: PlayerType.ai,
      hand: [],
      melds: [
        Meld(
          cards: [
            Card(id: 401, character: '十', sentence: 4, position: 1),
            Card(id: 402, character: '七', sentence: 4, position: 0),
            Card(id: 403, character: '土', sentence: 4, position: 2),
          ],
          type: MeldType.ju,
          isJing: false,
        ),
        Meld(
          cards: [
            Card(id: 411, character: '土', sentence: 4, position: 2),
            Card(id: 412, character: '七', sentence: 4, position: 0),
            Card(id: 413, character: '十', sentence: 4, position: 1),
          ],
          type: MeldType.ju,
          isJing: false,
        ),
      ],
      discards: [Card(id: 421, character: '上', sentence: 1, position: 0)],
    );

    // 设置publicCardCount
    final publicCardCount = <String, int>{
      '八': 3,
      '尔': 1,
      '作': 1,
      '十': 2,
      '七': 2,
      '土': 2,
      '上': 1,
      '大': 1,
      '丘': 3,
      '九': 4,
    };

    final state = GameState(publicCardCount: publicCardCount);
    state.totalVisibleCards = 3 + 1 + 1 + 2 + 2 + 2 + 1 + 1 + 3 + 4;
    state.players = [player, p1, p2];

    final strategy = AIStrategyHard();

    // 检查AI是否应该招"子"
    final shouldZhao = strategy.shouldZhaoFromHand(player, '子', state);

    // AI应该招"子"，因为手牌中有4张"子"
    expect(shouldZhao, isTrue, reason: '招完九后补摸，手牌中有4张子，应该可以继续招子');
  });
}
