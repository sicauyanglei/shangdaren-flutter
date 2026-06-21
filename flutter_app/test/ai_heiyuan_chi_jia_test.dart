import 'package:flutter_test/flutter_test.dart';
import 'package:shangdaren_game/game/logic/ai/ai_strategy_hard.dart';
import 'package:shangdaren_game/game/models/card.dart';
import 'package:shangdaren_game/game/models/game_state.dart';
import 'package:shangdaren_game/game/models/meld.dart';
import 'package:shangdaren_game/game/models/player.dart';

void main() {
  test('AI should not chi 佳 in heiYuan route (leaves 佳佳 pair)', () {
    // 场景：黑元路线，手牌"上丘乙己三千千十十尔尔小九子佳佳作亡"
    // 玩家1-组合牌"禄禄禄",弃牌"小己"
    // 玩家2-组合牌"",弃牌"生福丘"
    // 我-组合牌"",弃牌"寿人人"
    // 有人出"佳"，AI不应吃（吃后剩佳佳对子，黑元路线下对子是负担）

    final hand = <Card>[
      // 门1: 上(精字，黑元要清理)
      Card(id: 1, character: '上', sentence: 1, position: 0),
      // 门2: 丘乙己(句)
      Card(id: 2, character: '丘', sentence: 2, position: 0),
      Card(id: 3, character: '乙', sentence: 2, position: 1),
      Card(id: 4, character: '己', sentence: 2, position: 2),
      // 门3: 三千千(千千对子+三)
      Card(id: 5, character: '三', sentence: 3, position: 1),
      Card(id: 6, character: '千', sentence: 3, position: 2),
      Card(id: 7, character: '千', sentence: 3, position: 2),
      // 门4: 十十(对子)
      Card(id: 8, character: '十', sentence: 4, position: 1),
      Card(id: 9, character: '十', sentence: 4, position: 1),
      // 门5: 尔尔小(尔尔对子+小)
      Card(id: 10, character: '尔', sentence: 5, position: 0),
      Card(id: 11, character: '尔', sentence: 5, position: 0),
      Card(id: 12, character: '小', sentence: 5, position: 1),
      // 门6: 九子(靠)
      Card(id: 13, character: '九', sentence: 6, position: 1),
      Card(id: 14, character: '子', sentence: 6, position: 2),
      // 门7: 佳佳作亡(佳佳对子+作+亡)
      Card(id: 15, character: '佳', sentence: 7, position: 0),
      Card(id: 16, character: '佳', sentence: 7, position: 0),
      Card(id: 17, character: '作', sentence: 7, position: 1),
      Card(id: 18, character: '亡', sentence: 7, position: 2),
    ];

    final player = Player(
      id: 0,
      name: 'AI',
      type: PlayerType.ai,
      hand: hand,
      melds: [],
      discards: [
        Card(id: 501, character: '寿', sentence: 8, position: 2),
        Card(id: 502, character: '人', sentence: 1, position: 2),
        Card(id: 503, character: '人', sentence: 1, position: 2),
      ],
    );

    // 玩家1-组合牌"禄禄禄",弃牌"小己"
    final p1 = Player(
      id: 1,
      name: 'P1',
      type: PlayerType.ai,
      hand: [],
      melds: [
        Meld(
          cards: [
            Card(id: 201, character: '禄', sentence: 8, position: 1),
            Card(id: 202, character: '禄', sentence: 8, position: 1),
            Card(id: 203, character: '禄', sentence: 8, position: 1),
          ],
          type: MeldType.kan,
          isJing: false,
        ),
      ],
      discards: [
        Card(id: 211, character: '小', sentence: 5, position: 1),
        Card(id: 212, character: '己', sentence: 2, position: 2),
      ],
    );

    // 玩家2-组合牌"",弃牌"生福丘"
    final p2 = Player(
      id: 2,
      name: 'P2',
      type: PlayerType.ai,
      hand: [],
      melds: [],
      discards: [
        Card(id: 311, character: '生', sentence: 5, position: 2),
        Card(id: 312, character: '福', sentence: 8, position: 0),
        Card(id: 313, character: '丘', sentence: 2, position: 0),
      ],
    );

    // 设置publicCardCount
    // 玩家1组合牌：禄3
    // 玩家1弃牌：小1+己1
    // 玩家2弃牌：生1+福1+丘1
    // 我弃牌：寿1+人2
    final publicCardCount = <String, int>{
      '禄': 3,
      '小': 1,
      '己': 1,
      '生': 1,
      '福': 1,
      '丘': 1,
      '寿': 1,
      '人': 2,
    };

    final state = GameState(publicCardCount: publicCardCount);
    // totalVisibleCards = 3+1+1+1+1+1+1+2 = 11
    state.totalVisibleCards = 11;
    state.players = [player, p1, p2];

    final strategy = AIStrategyHard();

    // 有人出"佳"，AI是否应该吃
    final jiaCard = Card(id: 999, character: '佳', sentence: 7, position: 0);
    final shouldChi = strategy.shouldChi(player, jiaCard, state);
    print('AI是否吃佳: $shouldChi');

    // 打印黑元潜力
    // 手牌中门1/8牌：上(1张)
    // 黑元路线下，吃佳后剩佳佳对子，对子可能变碰破坏黑元资格
    // 应该不吃
    expect(
      shouldChi,
      isFalse,
      reason: '黑元路线下吃佳后剩佳佳对子，对子是负担，不应吃',
    );
  });
}
