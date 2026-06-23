import 'package:flutter_test/flutter_test.dart';
import 'package:shangdaren_game/game/models/card.dart';
import 'package:shangdaren_game/game/models/player.dart';
import 'package:shangdaren_game/game/models/meld.dart';
import 'package:shangdaren_game/game/models/game_state.dart';
import 'package:shangdaren_game/game/logic/ai/ai_strategy_hard.dart';
import 'package:shangdaren_game/game/logic/hu_calculator.dart';

void main() {
  test('AI discard analysis for hand 己己三千十土土小生八九九子作作亡亡', () {
    // 我的手牌: 己己三千十土土小生八九九子作作亡亡
    final hand = <Card>[
      Card(id: 1, character: '己', sentence: 2, position: 2),
      Card(id: 2, character: '己', sentence: 2, position: 2),
      Card(id: 3, character: '三', sentence: 3, position: 1),
      Card(id: 4, character: '千', sentence: 3, position: 2),
      Card(id: 5, character: '十', sentence: 4, position: 1),
      Card(id: 6, character: '土', sentence: 4, position: 2),
      Card(id: 7, character: '土', sentence: 4, position: 2),
      Card(id: 8, character: '小', sentence: 5, position: 1),
      Card(id: 9, character: '生', sentence: 5, position: 2),
      Card(id: 10, character: '八', sentence: 6, position: 0),
      Card(id: 11, character: '九', sentence: 6, position: 1),
      Card(id: 12, character: '九', sentence: 6, position: 1),
      Card(id: 13, character: '子', sentence: 6, position: 2),
      Card(id: 14, character: '作', sentence: 7, position: 1),
      Card(id: 15, character: '作', sentence: 7, position: 1),
      Card(id: 16, character: '亡', sentence: 7, position: 2),
      Card(id: 17, character: '亡', sentence: 7, position: 2),
    ];

    // 组合牌: 小尔生（句）
    final melds = <Meld>[
      Meld(
        cards: [
          Card(id: 101, character: '小', sentence: 5, position: 1),
          Card(id: 102, character: '尔', sentence: 5, position: 0),
          Card(id: 103, character: '生', sentence: 5, position: 2),
        ],
        type: MeldType.ju,
        isJing: false,
      ),
    ];

    final player = Player(
      id: 0,
      name: 'AI',
      type: PlayerType.ai,
      hand: hand,
      melds: melds,
    );

    // 计算胡数
    HuCalculator.updateMeldHuCache(player);
    final totalHu = HuCalculator.calculateTotalHu(player);
    print('=== 胡数分析 ===');
    print('总胡数: $totalHu');
    print('组合牌胡数: ${player.meldHuCount}');
    final handHu = HuCalculator.calculateHandHu(player.hand, player.melds);
    print('手牌胡数: $handHu');

    // 构建GameState
    final state = GameState();
    state.players = [
      player,
      Player(id: 1, name: 'P1', type: PlayerType.human),
      Player(id: 2, name: 'P2', type: PlayerType.human),
    ];

    // 设置publicCardCount（可见牌，不含当前玩家手牌）
    // 玩家1弃牌"乙三人人大"：乙1、三1、人2、大1
    // 玩家2组合牌"禄福寿"+"大大大"：禄1、福1、寿1、大3
    // 玩家2弃牌"寿小佳十寿"：寿2、小1、佳1、十1
    // 我组合牌"小尔生"：小1、尔1、生1
    // 我弃牌"禄人福"：禄1、人1、福1
    state.publicCardCount = {
      '乙': 1,  // 玩家1弃牌
      '三': 1,  // 玩家1弃牌
      '人': 3,  // 玩家1弃牌2 + 我弃牌1
      '大': 4,  // 玩家1弃牌1 + 玩家2组合牌3
      '禄': 2,  // 玩家2组合牌1 + 我弃牌1
      '福': 2,  // 玩家2组合牌1 + 我弃牌1
      '寿': 3,  // 玩家2组合牌1 + 玩家2弃牌2
      '小': 2,  // 玩家2弃牌1 + 我组合牌1
      '佳': 1,  // 玩家2弃牌
      '十': 1,  // 玩家2弃牌
      '尔': 1,  // 我组合牌
      '生': 1,  // 我组合牌
    };

    // 计算totalVisibleCards
    state.totalVisibleCards = state.publicCardCount.values.fold(
      0,
      (a, b) => a + b,
    );

    print('\n=== 可见牌统计 ===');
    final visibleCount = state.buildVisibleCount(player);
    for (final ch in [
      '上', '大', '人', '丘', '乙', '己',
      '化', '三', '千', '七', '十', '土',
      '尔', '小', '生', '八', '九', '子',
      '佳', '作', '亡', '福', '禄', '寿',
    ]) {
      final vis = visibleCount[ch] ?? 0;
      final rem = 4 - vis;
      print('  $ch: 可见=$vis, 剩余=$rem');
    }

    final totalUnknown = state.unknownCards(player);
    print('未知牌总数: $totalUnknown');

    // 运行AI策略
    final strategy = AIStrategyHard();
    final discard = strategy.selectDiscard(player, state);

    print('\n=== AI出牌结果 ===');
    print('选择打出: ${discard.character}');
    print('手牌: ${hand.map((c) => c.character).join()}');
  });
}
