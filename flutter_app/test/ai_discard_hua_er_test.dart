import 'package:flutter_test/flutter_test.dart';
import 'package:shangdaren_game/game/logic/ai/ai_strategy_hard.dart';
import 'package:shangdaren_game/game/models/card.dart';
import 'package:shangdaren_game/game/models/game_state.dart';
import 'package:shangdaren_game/game/models/meld.dart';
import 'package:shangdaren_game/game/models/player.dart';

void main() {
  test('AI should discard 尔 instead of 化 to preserve pair potential', () {
    // 场景：
    // 玩家1-组合牌"",弃牌"佳"
    // 玩家2-组合牌"三三三,小小小",弃牌"化丘"
    // 我-组合牌"",弃牌"化",手牌"丘乙己己化化三千十土尔尔尔八八九九子佳亡"
    //
    // 手牌分门：
    // 门2(丘乙己): 丘、乙、己己（4张）
    // 门3(化三千): 化化、三、千（4张）
    // 门4(七十土): 十、土（2张，半靠）
    // 门5(尔小生): 尔尔尔（3张，坎）
    // 门6(八九十): 八八、九九、子（5张）
    // 门7(佳作亡): 佳、亡（2张，半靠）
    //
    // 分析：
    // 出"化"：门3形成句(1胡确定)，但损失化化对子碰坎机会(潜在3胡)
    // 出"尔"：门5从坎(3胡)变对子(潜在3胡)，门3保持对子+半靠(潜在3胡)
    // 出"尔"保留更多潜在胡数

    final hand = <Card>[
      // 门2(丘乙己): 丘、乙、己己
      Card(id: 1, character: '丘', sentence: 2, position: 0),
      Card(id: 2, character: '乙', sentence: 2, position: 1),
      Card(id: 3, character: '己', sentence: 2, position: 2),
      Card(id: 4, character: '己', sentence: 2, position: 2),
      // 门3(化三千): 化化、三、千
      Card(id: 5, character: '化', sentence: 3, position: 0),
      Card(id: 6, character: '化', sentence: 3, position: 0),
      Card(id: 7, character: '三', sentence: 3, position: 1),
      Card(id: 8, character: '千', sentence: 3, position: 2),
      // 门4(七十土): 十、土（半靠）
      Card(id: 9, character: '十', sentence: 4, position: 1),
      Card(id: 10, character: '土', sentence: 4, position: 2),
      // 门5(尔小生): 尔尔尔（坎）
      Card(id: 11, character: '尔', sentence: 5, position: 0),
      Card(id: 12, character: '尔', sentence: 5, position: 0),
      Card(id: 13, character: '尔', sentence: 5, position: 0),
      // 门6(八九十): 八八、九九、子
      Card(id: 14, character: '八', sentence: 6, position: 0),
      Card(id: 15, character: '八', sentence: 6, position: 0),
      Card(id: 16, character: '九', sentence: 6, position: 1),
      Card(id: 17, character: '九', sentence: 6, position: 1),
      Card(id: 18, character: '子', sentence: 6, position: 2),
      // 门7(佳作亡): 佳、亡（半靠）
      Card(id: 19, character: '佳', sentence: 7, position: 0),
      Card(id: 20, character: '亡', sentence: 7, position: 2),
    ];

    final player = Player(
      id: 0,
      name: 'AI',
      type: PlayerType.ai,
      hand: hand,
      melds: [],
      discards: [Card(id: 501, character: '化', sentence: 3, position: 0)],
    );

    // 玩家1-组合牌"",弃牌"佳"
    final p1 = Player(
      id: 1,
      name: 'P1',
      type: PlayerType.ai,
      hand: [],
      melds: [],
      discards: [Card(id: 511, character: '佳', sentence: 7, position: 0)],
    );

    // 玩家2-组合牌"三三三,小小小",弃牌"化丘"
    final p2 = Player(
      id: 2,
      name: 'P2',
      type: PlayerType.ai,
      hand: [],
      melds: [
        Meld(
          cards: [
            Card(id: 301, character: '三', sentence: 3, position: 1),
            Card(id: 302, character: '三', sentence: 3, position: 1),
            Card(id: 303, character: '三', sentence: 3, position: 1),
          ],
          type: MeldType.kan,
          isJing: false,
        ),
        Meld(
          cards: [
            Card(id: 304, character: '小', sentence: 5, position: 1),
            Card(id: 305, character: '小', sentence: 5, position: 1),
            Card(id: 306, character: '小', sentence: 5, position: 1),
          ],
          type: MeldType.kan,
          isJing: false,
        ),
      ],
      discards: [
        Card(id: 521, character: '化', sentence: 3, position: 0),
        Card(id: 522, character: '丘', sentence: 2, position: 0),
      ],
    );

    // publicCardCount: 已公开的牌
    final publicCardCount = <String, int>{
      // 我的弃牌
      '化': 1,
      // 玩家1弃牌
      '佳': 1,
      // 玩家2弃牌
      '丘': 1,
      // 玩家2组合牌
      '三': 3,
      '小': 3,
    };

    final state = GameState(publicCardCount: publicCardCount);
    state.totalVisibleCards = publicCardCount.values.fold(0, (a, b) => a + b);
    state.players = [player, p1, p2];

    final strategy = AIStrategyHard();

    final selected = strategy.selectDiscard(player, state);
    print('AI选择出: ${selected.character} (门${selected.sentence})');

    // AI应该出"尔"而不是"化"
    // 出"尔"：门5从坎(3胡)变对子(潜在3胡)，门3保持对子+半靠(潜在3胡)
    // 出"化"：门3形成句(1胡)，但损失化化对子碰坎机会(潜在3胡)
    // 出"尔"保留更多潜在胡数
    expect(
      selected.character,
      equals('尔'),
      reason: '应出尔(拆坎变对子，保留碰坎潜力)，而不是化(损失对子碰坎机会)',
    );
  });
}
