import 'package:flutter_test/flutter_test.dart';
import 'package:shangdaren_game/game/logic/ai/ai_strategy_hard.dart';
import 'package:shangdaren_game/game/models/card.dart';
import 'package:shangdaren_game/game/models/game_state.dart';
import 'package:shangdaren_game/game/models/meld.dart';
import 'package:shangdaren_game/game/models/player.dart';

void main() {
  test('黑元路线下手牌八九九子+其他门有多余牌（对子+单张），玩家1出八，AI应该吃八', () {
    // 场景：
    // 手牌"八九九子" + 4句 + 1对子（佳佳）+ 1单张（作）
    // 其他门除去句子后存在对子和单张（有多余牌可以打）
    // 玩家1出八，吃八后组成"八九子"句，手牌剩"八九"半靠 + 4句 + 1对子 + 1单张
    // 吃牌后可以打出对子或单张，既多了1句又保留半靠，更接近黑元听牌

    final hand = <Card>[
      // 门2: 丘乙己（句）
      Card(id: 1, character: '丘', sentence: 2, position: 0),
      Card(id: 2, character: '乙', sentence: 2, position: 1),
      Card(id: 3, character: '己', sentence: 2, position: 2),
      // 门3: 化三千（句）
      Card(id: 4, character: '化', sentence: 3, position: 0),
      Card(id: 5, character: '三', sentence: 3, position: 1),
      Card(id: 6, character: '千', sentence: 3, position: 2),
      // 门4: 七十土（句）
      Card(id: 7, character: '七', sentence: 4, position: 0),
      Card(id: 8, character: '十', sentence: 4, position: 1),
      Card(id: 9, character: '土', sentence: 4, position: 2),
      // 门5: 尔小生（句）
      Card(id: 10, character: '尔', sentence: 5, position: 0),
      Card(id: 11, character: '小', sentence: 5, position: 1),
      Card(id: 12, character: '生', sentence: 5, position: 2),
      // 门6: 八九九子（1句+1孤张，或1对+1半靠）
      Card(id: 13, character: '八', sentence: 6, position: 0),
      Card(id: 14, character: '九', sentence: 6, position: 1),
      Card(id: 15, character: '九', sentence: 6, position: 1),
      Card(id: 16, character: '子', sentence: 6, position: 2),
      // 门7: 佳佳作（对子+单张，有多余牌可以打）
      Card(id: 17, character: '佳', sentence: 7, position: 0),
      Card(id: 18, character: '佳', sentence: 7, position: 0),
      Card(id: 19, character: '作', sentence: 7, position: 1),
    ];

    final player = Player(
      id: 0,
      name: 'AI',
      type: PlayerType.ai,
      hand: hand,
      melds: [],
      discards: [],
    );

    // 玩家1出八
    final card = Card(id: 100, character: '八', sentence: 6, position: 0);

    final p1 = Player(
      id: 1,
      name: 'P1',
      type: PlayerType.ai,
      hand: [],
      melds: [],
      discards: [],
    );

    final p2 = Player(
      id: 2,
      name: 'P2',
      type: PlayerType.ai,
      hand: [],
      melds: [],
      discards: [],
    );

    final publicCardCount = <String, int>{
      '八': 1, // 玩家1出的八
    };

    final state = GameState(publicCardCount: publicCardCount);
    state.totalVisibleCards = 1;
    state.players = [player, p1, p2];

    final strategy = AIStrategyHard();

    final shouldChi = strategy.shouldChi(player, card, state);
    print('场景1-其他门有多余牌: AI是否吃八: $shouldChi');

    // AI应该吃八，因为吃八后组成"八九子"句，手牌剩"八九"半靠
    // 吃牌后可以打出对子或单张，既多了1句又保留半靠，更接近黑元听牌
    expect(shouldChi, true,
        reason: '黑元路线下，其他门有多余牌可打，吃八组成八九子句，手牌剩八九半靠，比孤张更接近成句');
  });

  test('黑元路线下手牌八九九子+其他门都是完整句，玩家1出八，AI不应该吃八', () {
    // 场景：
    // 手牌"八九九子" + 5句 = 5句+1孤张（九）
    // 其他门都是完整句，没有多余牌可以打
    // 玩家1出八，吃八后组成"八九子"句，手牌剩"八九"半靠 + 5句
    // 吃牌后只能打出"八九"半靠中的一张，损失半靠，没有必要吃

    final hand = <Card>[
      // 门2: 丘乙己（句）
      Card(id: 1, character: '丘', sentence: 2, position: 0),
      Card(id: 2, character: '乙', sentence: 2, position: 1),
      Card(id: 3, character: '己', sentence: 2, position: 2),
      // 门3: 化三千（句）
      Card(id: 4, character: '化', sentence: 3, position: 0),
      Card(id: 5, character: '三', sentence: 3, position: 1),
      Card(id: 6, character: '千', sentence: 3, position: 2),
      // 门4: 七十土（句）
      Card(id: 7, character: '七', sentence: 4, position: 0),
      Card(id: 8, character: '十', sentence: 4, position: 1),
      Card(id: 9, character: '土', sentence: 4, position: 2),
      // 门5: 尔小生（句）
      Card(id: 10, character: '尔', sentence: 5, position: 0),
      Card(id: 11, character: '小', sentence: 5, position: 1),
      Card(id: 12, character: '生', sentence: 5, position: 2),
      // 门6: 八九九子（1句+1孤张，或1对+1半靠）
      Card(id: 13, character: '八', sentence: 6, position: 0),
      Card(id: 14, character: '九', sentence: 6, position: 1),
      Card(id: 15, character: '九', sentence: 6, position: 1),
      Card(id: 16, character: '子', sentence: 6, position: 2),
      // 门7: 佳作亡（句）
      Card(id: 17, character: '佳', sentence: 7, position: 0),
      Card(id: 18, character: '作', sentence: 7, position: 1),
      Card(id: 19, character: '亡', sentence: 7, position: 2),
    ];

    final player = Player(
      id: 0,
      name: 'AI',
      type: PlayerType.ai,
      hand: hand,
      melds: [],
      discards: [],
    );

    // 玩家1出八
    final card = Card(id: 100, character: '八', sentence: 6, position: 0);

    final p1 = Player(
      id: 1,
      name: 'P1',
      type: PlayerType.ai,
      hand: [],
      melds: [],
      discards: [],
    );

    final p2 = Player(
      id: 2,
      name: 'P2',
      type: PlayerType.ai,
      hand: [],
      melds: [],
      discards: [],
    );

    final publicCardCount = <String, int>{
      '八': 1, // 玩家1出的八
    };

    final state = GameState(publicCardCount: publicCardCount);
    state.totalVisibleCards = 1;
    state.players = [player, p1, p2];

    final strategy = AIStrategyHard();

    final shouldChi = strategy.shouldChi(player, card, state);
    print('场景2-其他门都是完整句: AI是否吃八: $shouldChi');

    // AI不应该吃八，因为其他门都是完整句，没有多余牌可以打
    // 吃牌后只能打出"八九"半靠中的一张，损失半靠，没有必要吃
    expect(shouldChi, false,
        reason: '黑元路线下，其他门都是完整句无多余牌可打，吃八后只能打出半靠，损失大于收益');
  });

  test('黑元路线下子剩余0张时，玩家1出八，AI不应该吃八应该摸牌', () {
    // 场景：
    // 手牌"八九九子" + 4句 + 1对子（佳佳）+ 1单张（作）
    // 其他门除去句子后存在对子和单张（有多余牌可以打）
    // 但是牌面上"子"剩余0张（已见4张），半靠"八九"无法成句
    // 玩家1出八，AI不应该吃八，应该摸牌
    // 因为半靠"八九"需要"子"才能成句，"子"为0张时半靠无价值

    final hand = <Card>[
      // 门2: 丘乙己（句）
      Card(id: 1, character: '丘', sentence: 2, position: 0),
      Card(id: 2, character: '乙', sentence: 2, position: 1),
      Card(id: 3, character: '己', sentence: 2, position: 2),
      // 门3: 化三千（句）
      Card(id: 4, character: '化', sentence: 3, position: 0),
      Card(id: 5, character: '三', sentence: 3, position: 1),
      Card(id: 6, character: '千', sentence: 3, position: 2),
      // 门4: 七十土（句）
      Card(id: 7, character: '七', sentence: 4, position: 0),
      Card(id: 8, character: '十', sentence: 4, position: 1),
      Card(id: 9, character: '土', sentence: 4, position: 2),
      // 门5: 尔小生（句）
      Card(id: 10, character: '尔', sentence: 5, position: 0),
      Card(id: 11, character: '小', sentence: 5, position: 1),
      Card(id: 12, character: '生', sentence: 5, position: 2),
      // 门6: 八九九子（1句+1孤张，或1对+1半靠）
      Card(id: 13, character: '八', sentence: 6, position: 0),
      Card(id: 14, character: '九', sentence: 6, position: 1),
      Card(id: 15, character: '九', sentence: 6, position: 1),
      Card(id: 16, character: '子', sentence: 6, position: 2),
      // 门7: 佳佳作（对子+单张，有多余牌可以打）
      Card(id: 17, character: '佳', sentence: 7, position: 0),
      Card(id: 18, character: '佳', sentence: 7, position: 0),
      Card(id: 19, character: '作', sentence: 7, position: 1),
    ];

    final player = Player(
      id: 0,
      name: 'AI',
      type: PlayerType.ai,
      hand: hand,
      melds: [],
      discards: [],
    );

    // 玩家1出八
    final card = Card(id: 100, character: '八', sentence: 6, position: 0);

    final p1 = Player(
      id: 1,
      name: 'P1',
      type: PlayerType.ai,
      hand: [],
      melds: [],
      discards: [],
    );

    final p2 = Player(
      id: 2,
      name: 'P2',
      type: PlayerType.ai,
      hand: [],
      melds: [],
      discards: [],
    );

    // 牌面上"子"已见4张：手牌1张 + 其他玩家组合牌3张
    // 这样"子"剩余0张，半靠"八九"无法成句
    final publicCardCount = <String, int>{
      '八': 1, // 玩家1出的八
      '子': 4, // 已见4张（手牌1+其他玩家组合牌3），剩余0张
    };

    final state = GameState(publicCardCount: publicCardCount);
    state.totalVisibleCards = 5;
    state.players = [player, p1, p2];

    final strategy = AIStrategyHard();

    final shouldChi = strategy.shouldChi(player, card, state);
    print('场景3-子剩余0张: AI是否吃八: $shouldChi');

    // AI不应该吃八，因为"子"剩余0张，半靠"八九"无法成句
    // 这种情况下应该摸牌，而不是吃牌
    expect(shouldChi, false,
        reason: '黑元路线下，子剩余0张时半靠八九无法成句，应该摸牌而不是吃八');
  });
}
