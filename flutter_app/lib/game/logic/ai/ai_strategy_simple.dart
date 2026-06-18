import 'ai_strategy.dart';
import '../../models/card.dart';
import '../../models/game_state.dart';
import '../../models/player.dart';
import '../hu_calculator.dart';

class AIStrategySimple extends AIStrategy {
  @override
  Card selectDiscard(Player player, GameState state) {
    final hand = player.hand;
    if (hand.length <= 1) return hand.first;

    // 确保meldHuCount已正确初始化
    if (player.melds.isNotEmpty && player.meldHuCount == 0) {
      HuCalculator.updateMeldHuCache(player);
    }
    final huBefore = HuCalculator.calculateTotalHu(player);

    final charCount = _buildCharCount(hand);
    final groupCharSet = _buildGroupCharSet(hand);

    final isolated = <Card>[];
    final kao = <Card>[];
    final dui = <Card>[];

    for (final card in hand) {
      final count = charCount[card.character]!;
      if (count >= 3) continue;
      if (count == 2) {
        dui.add(card);
        continue;
      }
      final charsInGroup = groupCharSet[card.sentence]!;
      if (charsInGroup.length >= 3) continue;
      if (charsInGroup.length == 2) {
        kao.add(card);
      } else {
        isolated.add(card);
      }
    }

    // 胡数资格保护：如果出牌前胡数>=11，过滤掉会导致胡数<11的牌
    final safeCards = <Card>[];
    if (huBefore >= 11) {
      for (final card in hand) {
        final testHand = List<Card>.from(hand);
        testHand.remove(card);
        final testPlayer = Player(
          id: player.id,
          name: player.name,
          type: player.type,
          hand: testHand,
          melds: player.melds,
        );
        HuCalculator.updateMeldHuCache(testPlayer);
        final huAfter = HuCalculator.calculateTotalHu(testPlayer);
        if (huAfter >= 11) {
          safeCards.add(card);
        }
      }
    }

    // 如果有安全牌，优先从安全牌中选择
    if (safeCards.isNotEmpty) {
      // 从安全牌中筛选孤张
      final safeIsolated = isolated.where(safeCards.contains).toList();
      if (safeIsolated.isNotEmpty) {
        safeIsolated.sort(
          (a, b) => _discardPriority(b).compareTo(_discardPriority(a)),
        );
        return safeIsolated.first;
      }
      // 从安全牌中筛选靠
      final safeKao = kao.where(safeCards.contains).toList();
      if (safeKao.isNotEmpty) {
        safeKao.sort((a, b) => _discardPriority(b).compareTo(_discardPriority(a)));
        return safeKao.first;
      }
      // 从安全牌中筛选对子
      final safeDui = dui.where(safeCards.contains).toList();
      if (safeDui.isNotEmpty) {
        safeDui.sort((a, b) => _discardPriority(b).compareTo(_discardPriority(a)));
        return safeDui.first;
      }
      // 安全牌中随机选一张
      safeCards.sort((a, b) => _discardPriority(b).compareTo(_discardPriority(a)));
      return safeCards.first;
    }

    if (isolated.isNotEmpty) {
      isolated.sort(
        (a, b) => _discardPriority(b).compareTo(_discardPriority(a)),
      );
      return isolated.first;
    }

    if (kao.isNotEmpty) {
      kao.sort((a, b) => _discardPriority(b).compareTo(_discardPriority(a)));
      return kao.first;
    }

    if (dui.isNotEmpty) {
      dui.sort((a, b) => _discardPriority(b).compareTo(_discardPriority(a)));
      return dui.first;
    }

    return hand.last;
  }

  Map<String, int> _buildCharCount(List<Card> hand) {
    final result = <String, int>{};
    for (final card in hand) {
      result[card.character] = (result[card.character] ?? 0) + 1;
    }
    return result;
  }

  Map<int, Set<String>> _buildGroupCharSet(List<Card> hand) {
    final result = <int, Set<String>>{};
    for (final card in hand) {
      result.putIfAbsent(card.sentence, () => <String>{});
      result[card.sentence]!.add(card.character);
    }
    return result;
  }

  int _discardPriority(Card card) {
    if (card.isJing) return 0;
    if (_isYin(card)) return 1;
    return 2;
  }

  bool _isYin(Card card) {
    return card.character == '大' ||
        card.character == '人' ||
        card.character == '禄' ||
        card.character == '寿';
  }

  List<String> _getOtherCharsInGroup(Card card) {
    const groupChars = [
      ['上', '大', '人'],
      ['丘', '乙', '己'],
      ['化', '三', '千'],
      ['七', '十', '土'],
      ['尔', '小', '生'],
      ['八', '九', '子'],
      ['佳', '作', '亡'],
      ['福', '禄', '寿'],
    ];
    return groupChars[card.sentence - 1]
        .where((ch) => ch != card.character)
        .toList();
  }

  @override
  bool shouldChi(Player player, Card card, GameState state) {
    final hand = player.hand;
    final neededChars = _getOtherCharsInGroup(card);
    final hasAll = neededChars.every(
      (ch) => hand.any((c) => c.character == ch),
    );
    if (!hasAll) return false;

    final charCount = _buildCharCount(hand);
    for (final ch in neededChars) {
      final count = charCount[ch];
      if (count != null && count >= 2) return false;
    }

    return true;
  }

  @override
  bool shouldPeng(Player player, Card card, GameState state) {
    final hand = player.hand;
    final sameCharCount = hand
        .where((c) => c.character == card.character)
        .length;

    if (sameCharCount >= 2) return true;

    if (sameCharCount == 1) {
      final existingCard = hand.firstWhere(
        (c) => c.character == card.character,
      );
      final groupCharSet = _buildGroupCharSet(hand);
      final charsInGroup = groupCharSet[existingCard.sentence]!;
      if (charsInGroup.length >= 3) return false;
      return true;
    }

    return false;
  }

  @override
  bool shouldZhao(Player player, Card card, GameState state) {
    return true;
  }

  @override
  bool shouldZhaoFromHand(Player player, String character, GameState state) {
    return true;
  }

  @override
  bool shouldHu(
    Player player,
    Card card,
    GameState state, {
    bool isZimo = false,
  }) {
    return true;
  }
}
