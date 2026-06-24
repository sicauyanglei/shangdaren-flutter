import 'package:shangdaren_game/game/models/card.dart';
import 'package:shangdaren_game/game/models/player.dart';
import 'package:shangdaren_game/game/models/meld.dart';

/// 单次决策记录
class DecisionRecord {
  final int gameId;
  final int roundNumber;
  final int playerId;
  final String handBefore; // 出牌前手牌
  final List<String> meldsDesc; // 组合牌描述
  final String discardedChar; // 出的牌
  final int huBefore; // 出牌前胡数
  final String routeType; // 路线类型
  final String cardGroupType; // 牌型分类
  final int remainingOfDiscarded; // 出的牌的剩余张数
  final String reason; // 决策原因

  DecisionRecord({
    required this.gameId,
    required this.roundNumber,
    required this.playerId,
    required this.handBefore,
    required this.meldsDesc,
    required this.discardedChar,
    required this.huBefore,
    required this.routeType,
    required this.cardGroupType,
    required this.remainingOfDiscarded,
    required this.reason,
  });

  @override
  String toString() {
    return '游戏$gameId 局$roundNumber 玩家$playerId: 手牌=$handBefore 出=$discardedChar 胡数=$huBefore 路线=$routeType 牌型=$cardGroupType 剩余=$remainingOfDiscarded';
  }
}

/// 决策记录收集器
class DecisionLogger {
  static final DecisionLogger _instance = DecisionLogger._();
  factory DecisionLogger() => _instance;
  DecisionLogger._();

  bool enabled = false;
  final List<DecisionRecord> records = [];

  void clear() => records.clear();

  void log(DecisionRecord record) {
    if (enabled) records.add(record);
  }

  /// 按牌型分组统计
  Map<String, List<DecisionRecord>> groupByCardType() {
    final groups = <String, List<DecisionRecord>>{};
    for (final r in records) {
      groups.putIfAbsent(r.cardGroupType, () => []).add(r);
    }
    return groups;
  }

  /// Print decision analysis report
  void printAnalysis() {
    print('=== Decision Analysis Report ===');
    print('Total Decisions: ${records.length}');
    print('');

    final groups = groupByCardType();
    final sortedGroups = groups.entries.toList()
      ..sort((a, b) => b.value.length.compareTo(a.value.length));

    for (final entry in sortedGroups) {
      final type = entry.key;
      final decisions = entry.value;
      print('Type: $type (${decisions.length} times)');

      // Count discard distribution
      final charCount = <String, int>{};
      for (final d in decisions) {
        charCount[d.discardedChar] = (charCount[d.discardedChar] ?? 0) + 1;
      }
      final sortedChars = charCount.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      for (final c in sortedChars.take(5)) {
        final pct = (c.value / decisions.length * 100).toStringAsFixed(1);
        print('  Discard ${c.key}: ${c.value} ($pct%)');
      }
      print('');
    }
  }
}

/// 牌型分类工具
class CardGroupClassifier {
  /// 分类手牌中某门牌的牌型
  static String classify(List<Card> hand, int sentence) {
    final cards = hand.where((c) => c.sentence == sentence).toList();
    if (cards.isEmpty) return '空';

    final byChar = <String, int>{};
    for (final c in cards) {
      byChar[c.character] = (byChar[c.character] ?? 0) + 1;
    }

    final counts = byChar.values.toList()..sort((a, b) => b.compareTo(a));
    final presentCount = byChar.length;

    // 按张数分类
    final total = cards.length;
    if (total == 1) return '孤张型';
    if (total == 2) {
      if (presentCount == 1) return '对型';
      return '半靠型';
    }
    if (total == 3) {
      if (presentCount == 1) return '坎型';
      if (presentCount == 2) return '对孤张型';
      return '句型';
    }
    if (total == 4) {
      if (presentCount == 1) return '招型';
      if (counts[0] == 3) return '坎孤张型';
      if (presentCount == 2 && counts[0] == 2) return '对对型';
      return '句孤张型';
    }
    if (total == 5) {
      if (counts[0] == 4) return '招孤张型';
      if (counts[0] == 3 && presentCount == 2) return '坎对型';
      if (counts[0] == 3) return '坎半靠型';
      if (counts[0] == 2 && presentCount == 3) return '句半靠型';
      return '其他5张';
    }
    if (total == 6) {
      if (counts[0] == 4) return '招对型/招半靠型';
      if (counts[0] == 3 && presentCount == 2) return '坎坎型';
      if (presentCount == 3) return '句句型';
      return '其他6张';
    }
    return '${total}张';
  }

  /// 获取出牌所在的门牌型
  static String classifyDiscard(List<Card> hand, Card discard) {
    return classify(hand, discard.sentence);
  }
}
