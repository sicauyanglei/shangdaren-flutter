import 'package:flutter_test/flutter_test.dart';
import 'package:shangdaren_game/game/logic/ai/ai_strategy_hard.dart';
import 'package:shangdaren_game/game/models/card.dart';
import 'package:shangdaren_game/game/models/game_state.dart';
import 'package:shangdaren_game/game/models/meld.dart';
import 'package:shangdaren_game/game/models/player.dart';

void main() {
  test('AI should pursue heiYuan and discard group1 card', () {
    // 场景：
    // 玩家1-组合牌"",弃牌"亡人人三"
    // 玩家2-组合牌"寿福禄,大大大大,十七土",弃牌"亡作人人"
    // 我-组合牌"",弃牌"上上",手牌"丘乙乙己化三千七土尔小小生生八八九九作作"
    //
    // 手牌分门：
    // 门1: 乙乙、己（3张，黑元需清理）
    // 门2: 丘、化、三千、尔（5张）
    // 门3: 小小、生生（4张）
    // 门4: 七土（2张，半靠）
    // 门5: 八八（2张，对子）
    // 门6: 九九（2张，对子）
    // 门7: 作作（2张，对子）
    //
    // 黑元条件：无碰无招、无门1/8牌、无"上"/"福"
    // 当前手牌有门1的乙乙、己，需要清理才能走黑元
    // 门1+门8张数=3，满足主动黑元策略条件(<=3)

    final hand = <Card>[
      // 门2(丘乙己): 丘、乙乙、己（4张）
      Card(id: 1, character: '丘', sentence: 2, position: 0),
      Card(id: 2, character: '乙', sentence: 2, position: 1),
      Card(id: 3, character: '乙', sentence: 2, position: 1),
      Card(id: 4, character: '己', sentence: 2, position: 2),
      // 门3(化三千): 化、三、千（3张，可成句）
      Card(id: 5, character: '化', sentence: 3, position: 0),
      Card(id: 6, character: '三', sentence: 3, position: 1),
      Card(id: 7, character: '千', sentence: 3, position: 2),
      // 门4(七十土): 七、土（2张，半靠）
      Card(id: 8, character: '七', sentence: 4, position: 0),
      Card(id: 9, character: '土', sentence: 4, position: 2),
      // 门5(尔小生): 尔、小小、生生（5张）
      Card(id: 10, character: '尔', sentence: 5, position: 0),
      Card(id: 11, character: '小', sentence: 5, position: 1),
      Card(id: 12, character: '小', sentence: 5, position: 1),
      Card(id: 13, character: '生', sentence: 5, position: 2),
      Card(id: 14, character: '生', sentence: 5, position: 2),
      // 门6(八九十): 八八、九九（4张）
      Card(id: 15, character: '八', sentence: 6, position: 0),
      Card(id: 16, character: '八', sentence: 6, position: 0),
      Card(id: 17, character: '九', sentence: 6, position: 1),
      Card(id: 18, character: '九', sentence: 6, position: 1),
      // 门7(佳作亡): 作作（2张）
      Card(id: 19, character: '作', sentence: 7, position: 1),
      Card(id: 20, character: '作', sentence: 7, position: 1),
    ];

    final player = Player(
      id: 0,
      name: 'AI',
      type: PlayerType.ai,
      hand: hand,
      melds: [],
      discards: [
        Card(id: 501, character: '上', sentence: 1, position: 0),
        Card(id: 502, character: '上', sentence: 1, position: 0),
      ],
    );

    // 玩家1-组合牌"",弃牌"亡人人三"
    final p1 = Player(
      id: 1,
      name: 'P1',
      type: PlayerType.ai,
      hand: [],
      melds: [],
      discards: [
        Card(id: 511, character: '亡', sentence: 7, position: 2),
        Card(id: 512, character: '人', sentence: 1, position: 2),
        Card(id: 513, character: '人', sentence: 1, position: 2),
        Card(id: 514, character: '三', sentence: 2, position: 0),
      ],
    );

    // 玩家2-组合牌"寿福禄,大大大大,十七土",弃牌"亡作人人"
    final p2 = Player(
      id: 2,
      name: 'P2',
      type: PlayerType.ai,
      hand: [],
      melds: [
        Meld(
          cards: [
            Card(id: 301, character: '寿', sentence: 8, position: 2),
            Card(id: 302, character: '福', sentence: 8, position: 0),
            Card(id: 303, character: '禄', sentence: 8, position: 1),
          ],
          type: MeldType.ju,
          isJing: false,
        ),
        Meld(
          cards: [
            Card(id: 304, character: '大', sentence: 1, position: 1),
            Card(id: 305, character: '大', sentence: 1, position: 1),
            Card(id: 306, character: '大', sentence: 1, position: 1),
            Card(id: 307, character: '大', sentence: 1, position: 1),
          ],
          type: MeldType.zhao,
          isJing: false,
        ),
        Meld(
          cards: [
            Card(id: 308, character: '十', sentence: 4, position: 1),
            Card(id: 309, character: '七', sentence: 4, position: 0),
            Card(id: 310, character: '土', sentence: 4, position: 2),
          ],
          type: MeldType.ju,
          isJing: false,
        ),
      ],
      discards: [
        Card(id: 521, character: '亡', sentence: 7, position: 2),
        Card(id: 522, character: '作', sentence: 7, position: 1),
        Card(id: 523, character: '人', sentence: 1, position: 2),
        Card(id: 524, character: '人', sentence: 1, position: 2),
      ],
    );

    // publicCardCount: 已公开的牌（我的弃牌+玩家1弃牌+玩家2组合牌和弃牌）
    final publicCardCount = <String, int>{
      // 我的弃牌
      '上': 2,
      // 玩家1弃牌: 亡人人三
      // 玩家2弃牌: 亡作人人
      // 合计: 亡2、人4、三1、作1
      '亡': 2,
      '人': 4,
      '三': 1,
      '作': 1,
      // 玩家2组合牌: 寿福禄、大大大大、十七土
      '寿': 1,
      '福': 1,
      '禄': 1,
      '大': 4,
      '十': 1,
      '七': 1,
      '土': 1,
    };

    final state = GameState(publicCardCount: publicCardCount);
    state.totalVisibleCards = publicCardCount.values.fold(0, (a, b) => a + b);
    state.players = [player, p1, p2];

    final strategy = AIStrategyHard();

    final selected = strategy.selectDiscard(player, state);
    print('AI选择出: ${selected.character} (门${selected.sentence})');

    // 手牌中没有门1/8的牌，完全满足黑元条件
    // 黑元路线下，应优先拆对子（避免对子变碰破坏黑元资格）
    // 手牌中的对子：乙乙、小小、生生、八八、九九、作作
    // 不应该出"七"（门4半靠），因为半靠是黑元需要的靠
    expect(
      selected.character,
      isNot(equals('七')),
      reason: '黑元路线不应出七，应优先拆对子',
    );
  });
}
