import 'package:flutter_test/flutter_test.dart';
import 'package:shangdaren_game/game/logic/ai/ai_strategy_hard.dart';
import 'package:shangdaren_game/game/logic/ai/ai_strategy_simple.dart';
import 'package:shangdaren_game/game/models/card.dart';
import 'package:shangdaren_game/game/models/game_state.dart';
import 'package:shangdaren_game/game/models/meld.dart';
import 'package:shangdaren_game/game/models/player.dart';

void main() {
  test('AI should not discard 七 after drawing 七', () {
    // 场景：手牌"上人己己己化化化七土土尔尔小生生亡福福福"，摸了个七
    // 玩家1-组合牌"子子子,三化千,生尔小",弃牌"丘土八三千丘生"
    // 玩家2-组合牌"七七七七",弃牌"十尔八"
    // 我-组合牌"",弃牌"乙三十作"

    final hand = <Card>[
      // 门1: 上人(靠)
      Card(id: 1, character: '上', sentence: 1, position: 0),
      Card(id: 2, character: '人', sentence: 1, position: 2),
      // 门2: 己己己(坎)
      Card(id: 3, character: '己', sentence: 2, position: 2),
      Card(id: 4, character: '己', sentence: 2, position: 2),
      Card(id: 5, character: '己', sentence: 2, position: 2),
      // 门3: 化化化(坎)
      Card(id: 6, character: '化', sentence: 3, position: 0),
      Card(id: 7, character: '化', sentence: 3, position: 0),
      Card(id: 8, character: '化', sentence: 3, position: 0),
      // 门4: 七土土
      Card(id: 9, character: '七', sentence: 4, position: 0),
      Card(id: 10, character: '土', sentence: 4, position: 2),
      Card(id: 11, character: '土', sentence: 4, position: 2),
      // 门5: 尔尔小生生
      Card(id: 12, character: '尔', sentence: 5, position: 0),
      Card(id: 13, character: '尔', sentence: 5, position: 0),
      Card(id: 14, character: '小', sentence: 5, position: 1),
      Card(id: 15, character: '生', sentence: 5, position: 2),
      Card(id: 16, character: '生', sentence: 5, position: 2),
      // 门7: 亡 (孤张)
      Card(id: 17, character: '亡', sentence: 7, position: 2),
      // 门8: 福福福(坎)
      Card(id: 18, character: '福', sentence: 8, position: 1),
      Card(id: 19, character: '福', sentence: 8, position: 1),
      Card(id: 20, character: '福', sentence: 8, position: 1),
    ];

    // 摸了个七
    final drawnCard = Card(id: 999, character: '七', sentence: 4, position: 0);

    // 我的弃牌：乙三十作
    final myDiscards = <Card>[
      Card(id: 501, character: '乙', sentence: 2, position: 1),
      Card(id: 502, character: '三', sentence: 3, position: 1),
      Card(id: 503, character: '十', sentence: 4, position: 1),
      Card(id: 504, character: '作', sentence: 7, position: 1),
    ];

    final player = Player(
      id: 0,
      name: 'AI',
      type: PlayerType.ai,
      hand: hand,
      melds: [],
      discards: myDiscards,
    );

    // 玩家1-组合牌"子子子,三化千,生尔小",弃牌"丘土八三千丘生"
    final p1 = Player(
      id: 1,
      name: 'P1',
      type: PlayerType.ai,
      hand: [],
      melds: [
        Meld(
          cards: [
            Card(id: 201, character: '子', sentence: 6, position: 2),
            Card(id: 202, character: '子', sentence: 6, position: 2),
            Card(id: 203, character: '子', sentence: 6, position: 2),
          ],
          type: MeldType.kan,
          isJing: false,
        ),
        Meld(
          cards: [
            Card(id: 204, character: '三', sentence: 3, position: 1),
            Card(id: 205, character: '化', sentence: 3, position: 0),
            Card(id: 206, character: '千', sentence: 3, position: 2),
          ],
          type: MeldType.ju,
          isJing: false,
        ),
        Meld(
          cards: [
            Card(id: 207, character: '生', sentence: 5, position: 2),
            Card(id: 208, character: '尔', sentence: 5, position: 0),
            Card(id: 209, character: '小', sentence: 5, position: 1),
          ],
          type: MeldType.ju,
          isJing: false,
        ),
      ],
      discards: [
        Card(id: 211, character: '丘', sentence: 7, position: 0),
        Card(id: 212, character: '土', sentence: 4, position: 2),
        Card(id: 213, character: '八', sentence: 6, position: 0),
        Card(id: 214, character: '三', sentence: 3, position: 1),
        Card(id: 215, character: '千', sentence: 3, position: 2),
        Card(id: 216, character: '丘', sentence: 7, position: 0),
        Card(id: 217, character: '生', sentence: 5, position: 2),
      ],
    );

    // 玩家2-组合牌"七七七七",弃牌"十尔八"
    // 注意：每种字只有4张，玩家2组合4张七则我无法摸到七
    // 假设是"七七七"（3张坎），七还剩1张
    final p2 = Player(
      id: 2,
      name: 'P2',
      type: PlayerType.ai,
      hand: [],
      melds: [
        Meld(
          cards: [
            Card(id: 301, character: '七', sentence: 4, position: 0),
            Card(id: 302, character: '七', sentence: 4, position: 0),
            Card(id: 303, character: '七', sentence: 4, position: 0),
          ],
          type: MeldType.kan,
          isJing: false,
        ),
      ],
      discards: [
        Card(id: 311, character: '十', sentence: 4, position: 1),
        Card(id: 312, character: '尔', sentence: 5, position: 0),
        Card(id: 313, character: '八', sentence: 6, position: 0),
      ],
    );

    // 设置publicCardCount
    // 玩家1组合牌：子3+三1+化1+千1+生1+尔1+小1
    // 玩家1弃牌：丘2+土1+八1+三1+千1+生1
    // 玩家2组合牌：七3
    // 玩家2弃牌：十1+尔1+八1
    // 我弃牌：乙1+三1+十1+作1
    final publicCardCount = <String, int>{
      '子': 3,
      '三': 1 + 1 + 1, // 玩家1组合1+弃牌1+我弃牌1 = 3
      '化': 1,
      '千': 1 + 1, // 玩家1组合1+弃牌1 = 2
      '生': 1 + 1, // 玩家1组合1+弃牌1 = 2
      '尔': 1 + 1, // 玩家1组合1+玩家2弃牌1 = 2
      '小': 1,
      '丘': 2,
      '土': 1,
      '八': 1 + 1, // 玩家1弃牌1+玩家2弃牌1 = 2
      '七': 3,
      '十': 1 + 1, // 玩家2弃牌1+我弃牌1 = 2
      '乙': 1,
      '作': 1,
      '亡': 0, // 亡剩余3张，非绝版
    };

    final state = GameState(publicCardCount: publicCardCount);
    // totalVisibleCards = 3+3+1+2+2+2+1+2+1+2+3+2+1+1+0 = 26
    state.totalVisibleCards = 26;
    state.players = [player, p1, p2];

    final strategy = AIStrategyHard();
    // 先把摸的牌加入手牌
    player.hand.add(drawnCard);
    final discard = strategy.selectDiscard(player, state);
    print('AI(Hard)选择出: ${discard?.character}');

    // 也测试Simple策略
    final player2 = Player(
      id: 0,
      name: 'AI',
      type: PlayerType.ai,
      hand: List<Card>.from(hand)..add(drawnCard),
      melds: [],
      discards: myDiscards,
    );
    final strategySimple = AIStrategySimple();
    final discardSimple = strategySimple.selectDiscard(player2, state);
    print('AI(Simple)选择出: ${discardSimple?.character}');

    print('手牌: ${player.hand.map((c) => c.character).join()}');
    print('摸牌: ${drawnCard.character}');

    // 七剩余0张（玩家2组合4张），摸的七是绝版牌
    // 但出七后手牌门4只剩土土对子，门4结构变差
    // 应该出亡（孤张）或其他更差的牌
    expect(
      discard?.character,
      isNot('七'),
      reason: '七虽然剩余0张，但出七会破坏门4的七土土靠组合，应出亡等孤张',
    );
  });
}
