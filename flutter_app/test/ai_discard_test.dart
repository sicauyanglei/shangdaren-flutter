import 'package:flutter_test/flutter_test.dart';
import 'package:shangdaren_game/game/models/card.dart';
import 'package:shangdaren_game/game/models/player.dart';
import 'package:shangdaren_game/game/models/meld.dart';
import 'package:shangdaren_game/game/models/game_state.dart';
import 'package:shangdaren_game/game/logic/ai/ai_strategy_hard.dart';
import 'package:shangdaren_game/game/logic/hu_calculator.dart';

void main() {
  test('AI discard analysis for hand 上大丘乙十土土土尔生佳佳禄禄', () {
    // 构建手牌
    final hand = <Card>[
      Card(id: 1, character: '上', sentence: 1, position: 0),
      Card(id: 2, character: '大', sentence: 1, position: 1),
      Card(id: 3, character: '丘', sentence: 2, position: 0),
      Card(id: 4, character: '乙', sentence: 2, position: 1),
      Card(id: 5, character: '十', sentence: 4, position: 1),
      Card(id: 6, character: '土', sentence: 4, position: 2),
      Card(id: 7, character: '土', sentence: 4, position: 2),
      Card(id: 8, character: '土', sentence: 4, position: 2),
      Card(id: 9, character: '尔', sentence: 5, position: 0),
      Card(id: 10, character: '生', sentence: 5, position: 2),
      Card(id: 11, character: '佳', sentence: 7, position: 0),
      Card(id: 12, character: '佳', sentence: 7, position: 0),
      Card(id: 13, character: '禄', sentence: 8, position: 1),
      Card(id: 14, character: '禄', sentence: 8, position: 1),
    ];

    // 构建组合牌
    final melds = <Meld>[
      Meld(
        cards: [
          Card(id: 101, character: '九', sentence: 6, position: 0),
          Card(id: 102, character: '八', sentence: 6, position: 0),
          Card(id: 103, character: '子', sentence: 6, position: 2),
        ],
        type: MeldType.ju,
        isJing: false,
      ),
      Meld(
        cards: [
          Card(id: 104, character: '作', sentence: 7, position: 1),
          Card(id: 105, character: '作', sentence: 7, position: 1),
          Card(id: 106, character: '作', sentence: 7, position: 1),
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
    // 弃牌: 乙人(玩家1) + 子九(玩家2) + 八七(我)
    // 玩家1组合牌: 化三千
    // 玩家2组合牌: 己丘乙 + 己己己
    // 我的组合牌: 九八子 + 作作作
    state.publicCardCount = {
      '乙': 2, // 弃牌1 + 玩家2组合牌1
      '人': 1, // 玩家1弃牌
      '子': 2, // 弃牌1 + 我的组合牌1
      '九': 2, // 弃牌1 + 我的组合牌1
      '八': 2, // 弃牌1 + 我的组合牌1
      '七': 1, // 我弃牌
      '化': 1, // 玩家1组合牌
      '三': 1, // 玩家1组合牌
      '千': 1, // 玩家1组合牌
      '己': 4, // 玩家2组合牌(1+3)
      '丘': 1, // 玩家2组合牌
      '作': 3, // 我的组合牌
    };

    // 计算totalVisibleCards
    state.totalVisibleCards = state.publicCardCount.values.fold(
      0,
      (a, b) => a + b,
    );

    print('\n=== 可见牌统计 ===');
    final visibleCount = state.buildVisibleCount(player);
    for (final ch in [
      '上',
      '大',
      '人',
      '丘',
      '乙',
      '己',
      '化',
      '三',
      '千',
      '七',
      '十',
      '土',
      '尔',
      '小',
      '生',
      '八',
      '九',
      '子',
      '佳',
      '作',
      '福',
      '禄',
      '寿',
    ]) {
      final vis = visibleCount[ch] ?? 0;
      final rem = 4 - vis;
      print('  $ch: 可见=$vis, 剩余=$rem');
    }

    final totalUnknown = state.unknownCards(player);
    print('未知牌总数: $totalUnknown');

    // 分析打出"上"和"大"后的手牌结构
    print('\n=== 打出"上"后的手牌分析 ===');
    final handWithoutShang = List<Card>.from(hand)..removeAt(0);
    _analyzeHand(handWithoutShang, melds, visibleCount, totalUnknown);

    print('\n=== 打出"大"后的手牌分析 ===');
    final handWithoutDa = List<Card>.from(hand)..removeAt(1);
    _analyzeHand(handWithoutDa, melds, visibleCount, totalUnknown);

    // 运行AI策略
    final strategy = AIStrategyHard();
    final discard = strategy.selectDiscard(player, state);

    print('\n=== AI出牌结果 ===');
    print('选择打出: ${discard.character}');
    print('手牌: ${hand.map((c) => c.character).join()}');
  });
}

void _analyzeHand(
  List<Card> hand,
  List<Meld> melds,
  Map<String, int> visibleCount,
  int totalUnknown,
) {
  final remaining = List<Card>.from(hand);
  final aSet = <Meld>[];
  final bSet = <Meld>[];
  final cSet = <Meld>[];
  final dSet = <Meld>[];
  final eSet = <Card>[];

  HuCalculator.extractJu(remaining, aSet);
  HuCalculator.extractZhao(remaining, bSet);
  HuCalculator.extractKan(remaining, cSet);
  HuCalculator.extractDuiAndKao(remaining, dSet);
  eSet.addAll(remaining);

  print(
    '  句: ${aSet.map((m) => m.cards.map((c) => c.character).join()).join(",")}',
  );
  print(
    '  招: ${bSet.map((m) => m.cards.map((c) => c.character).join()).join(",")}',
  );
  print(
    '  坎: ${cSet.map((m) => m.cards.map((c) => c.character).join()).join(",")}',
  );
  print(
    '  对/靠: ${dSet.map((m) => "${m.type == MeldType.dui ? "对" : "靠"}${m.cards.map((c) => c.character).join()}${m.isJing ? "(精)" : ""}").join(",")}',
  );
  print('  单张: ${eSet.map((c) => c.character).join()}');

  final handHu = HuCalculator.calculateHandHu(hand, melds);
  print('  手牌胡数: $handHu');
}
