import 'package:flutter_test/flutter_test.dart';
import 'package:shangdaren_game/game/models/card.dart';
import 'package:shangdaren_game/game/models/player.dart';
import 'package:shangdaren_game/game/models/meld.dart';
import 'package:shangdaren_game/game/models/game_state.dart';
import 'package:shangdaren_game/game/logic/ai/ai_strategy_hard.dart';
import 'package:shangdaren_game/game/logic/hu_calculator.dart';

void main() {
  test('AI discard analysis for 化 issue', () {
    // 我的手牌: 上大乙乙乙己化化化千七十十土尔尔小子亡寿
    final hand = <Card>[
      Card(id: 1, character: '上', sentence: 1, position: 0),
      Card(id: 2, character: '大', sentence: 1, position: 1),
      Card(id: 3, character: '乙', sentence: 2, position: 1),
      Card(id: 4, character: '乙', sentence: 2, position: 1),
      Card(id: 5, character: '乙', sentence: 2, position: 1),
      Card(id: 6, character: '己', sentence: 2, position: 2),
      Card(id: 7, character: '化', sentence: 3, position: 0),
      Card(id: 8, character: '化', sentence: 3, position: 0),
      Card(id: 9, character: '化', sentence: 3, position: 0),
      Card(id: 10, character: '千', sentence: 3, position: 2),
      Card(id: 11, character: '七', sentence: 4, position: 0),
      Card(id: 12, character: '十', sentence: 4, position: 1),
      Card(id: 13, character: '十', sentence: 4, position: 1),
      Card(id: 14, character: '土', sentence: 4, position: 2),
      Card(id: 15, character: '尔', sentence: 5, position: 0),
      Card(id: 16, character: '尔', sentence: 5, position: 0),
      Card(id: 17, character: '小', sentence: 5, position: 1),
      Card(id: 18, character: '子', sentence: 6, position: 2),
      Card(id: 19, character: '亡', sentence: 7, position: 2),
      Card(id: 20, character: '寿', sentence: 8, position: 2),
    ];

    final melds = <Meld>[];

    final player = Player(
      id: 0,
      name: 'AI',
      type: PlayerType.ai,
      hand: hand,
      melds: melds,
    );

    HuCalculator.updateMeldHuCache(player);
    final totalHu = HuCalculator.calculateTotalHu(player);
    print('=== 胡数分析 ===');
    print('总胡数: $totalHu');
    final handHu = HuCalculator.calculateHandHu(player.hand, player.melds);
    print('手牌胡数: $handHu');

    final state = GameState();
    state.players = [
      player,
      Player(id: 1, name: 'P1', type: PlayerType.human),
      Player(id: 2, name: 'P2', type: PlayerType.human),
    ];

    // 可见牌统计（不含当前玩家手牌）
    // 玩家1组合牌"己丘乙": 己1, 丘1, 乙1
    // 玩家1弃牌"千": 千1
    // 玩家2组合牌"化三千": 化1, 三1, 千1
    state.publicCardCount = {
      '己': 1,
      '丘': 1,
      '乙': 1,
      '千': 2,
      '化': 1,
      '三': 1,
    };

    state.totalVisibleCards = state.publicCardCount.values.fold(0, (a, b) => a + b);

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
