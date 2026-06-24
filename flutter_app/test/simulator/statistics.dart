import 'game_simulator.dart';

/// 统计结果
class SimulationStats {
  final int totalGames;
  final int totalRounds;
  final int huCount;
  final int zimoCount;
  final int dianpaoCount;
  final int liujuCount;
  final Map<String, int> huTypeCount;
  final Map<int, int> winnerCount;
  final double avgHuCount;
  final double avgRoundsPerGame;

  SimulationStats({
    required this.totalGames,
    required this.totalRounds,
    required this.huCount,
    required this.zimoCount,
    required this.dianpaoCount,
    required this.liujuCount,
    required this.huTypeCount,
    required this.winnerCount,
    required this.avgHuCount,
    required this.avgRoundsPerGame,
  });

  double get huRate => totalRounds > 0 ? huCount / totalRounds : 0;
  double get zimoRate => huCount > 0 ? zimoCount / huCount : 0;
  double get liujuRate => totalRounds > 0 ? liujuCount / totalRounds : 0;

  void printReport() {
    print('=== Simulation Stats Report ===');
    print('Total Games: $totalGames');
    print('Total Rounds: $totalRounds');
    print('Avg Rounds/Game: ${avgRoundsPerGame.toStringAsFixed(1)}');
    print('');
    print('Hu Count: $huCount (${(huRate * 100).toStringAsFixed(1)}%)');
    print('  Zimo: $zimoCount (${(zimoRate * 100).toStringAsFixed(1)}%)');
    print('  Dianpao: $dianpaoCount');
    print('Liuju Count: $liujuCount (${(liujuRate * 100).toStringAsFixed(1)}%)');
    print('');
    print('Avg Hu Count: ${avgHuCount.toStringAsFixed(1)}');
    print('');
    print('Hu Type Distribution:');
    final sortedTypes = huTypeCount.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    for (final entry in sortedTypes) {
      final pct = huCount > 0 ? (entry.value / huCount * 100).toStringAsFixed(1) : '0.0';
      print('  ${entry.key}: ${entry.value} ($pct%)');
    }
    print('');
    print('Winner Distribution:');
    for (int i = 0; i < 3; i++) {
      final pct = huCount > 0 ? (winnerCount[i]! / huCount * 100).toStringAsFixed(1) : '0.0';
      print('  AI$i: ${winnerCount[i]} ($pct%)');
    }
    print('');
    print('=== Report End ===');
  }
}

/// 统计收集器
class StatsCollector {
  int totalGames = 0;
  int totalRounds = 0;
  int huCount = 0;
  int zimoCount = 0;
  int dianpaoCount = 0;
  int liujuCount = 0;
  final Map<String, int> huTypeCount = {};
  final Map<int, int> winnerCount = {0: 0, 1: 0, 2: 0};
  final List<int> huCounts = [];

  void addGameResult(GameResult result) {
    totalGames++;
    totalRounds += result.rounds.length;
    huCount += result.huCount;
    liujuCount += result.liujuCount;
    zimoCount += result.zimoCount;
    dianpaoCount += result.huCount - result.zimoCount;

    for (final round in result.rounds) {
      if (!round.isLiuju) {
        huTypeCount[round.huType] = (huTypeCount[round.huType] ?? 0) + 1;
        winnerCount[round.winnerIndex] = (winnerCount[round.winnerIndex] ?? 0) + 1;
        huCounts.add(round.huCount);
      }
    }
  }

  SimulationStats getStats() {
    final avgHu = huCounts.isEmpty ? 0.0 : huCounts.reduce((a, b) => a + b) / huCounts.length;
    final avgRounds = totalGames > 0 ? totalRounds / totalGames : 0.0;

    return SimulationStats(
      totalGames: totalGames,
      totalRounds: totalRounds,
      huCount: huCount,
      zimoCount: zimoCount,
      dianpaoCount: dianpaoCount,
      liujuCount: liujuCount,
      huTypeCount: Map.from(huTypeCount),
      winnerCount: Map.from(winnerCount),
      avgHuCount: avgHu,
      avgRoundsPerGame: avgRounds,
    );
  }
}
