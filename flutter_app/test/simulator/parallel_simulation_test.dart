import 'dart:async';
import 'dart:isolate';
import 'package:flutter_test/flutter_test.dart';
import 'package:shangdaren_game/game/core/game_logger_io.dart';
import 'game_simulator.dart';
import 'statistics.dart';

/// Worker configuration sent to each isolate
class WorkerConfig {
  final int gameCount;
  final int startSeed;
  final int workerId;

  WorkerConfig({
    required this.gameCount,
    required this.startSeed,
    required this.workerId,
  });
}

/// Worker result returned from each isolate (serializable)
class WorkerResult {
  final int workerId;
  final int totalGames;
  final int totalRounds;
  final int huCount;
  final int zimoCount;
  final int liujuCount;
  final Map<String, int> huTypeCount;
  final Map<int, int> winnerCount;
  final List<int> huCounts;
  final int elapsedMs;

  WorkerResult({
    required this.workerId,
    required this.totalGames,
    required this.totalRounds,
    required this.huCount,
    required this.zimoCount,
    required this.liujuCount,
    required this.huTypeCount,
    required this.winnerCount,
    required this.huCounts,
    required this.elapsedMs,
  });
}

/// Top-level worker function that runs in an isolate
/// Must be top-level (not a class method) for Isolate.run to work
Future<WorkerResult> _runSimulationWorker(WorkerConfig config) async {
  // Disable game logger in worker
  GameLogger.setEnabled(false);

  final simulator = GameSimulator();
  final stats = StatsCollector();

  final stopwatch = Stopwatch()..start();

  for (int i = 0; i < config.gameCount; i++) {
    try {
      final result = simulator.runGame(config.startSeed + i);
      stats.addGameResult(result);
    } catch (e) {
      // Silently skip errored games
    }
  }

  stopwatch.stop();

  final s = stats.getStats();
  return WorkerResult(
    workerId: config.workerId,
    totalGames: s.totalGames,
    totalRounds: s.totalRounds,
    huCount: s.huCount,
    zimoCount: s.zimoCount,
    liujuCount: s.liujuCount,
    huTypeCount: s.huTypeCount,
    winnerCount: s.winnerCount,
    huCounts: s.avgHuCount > 0 ? List<int>.from(stats.huCounts) : [],
    elapsedMs: stopwatch.elapsedMilliseconds,
  );
}

/// Aggregate results from all workers
WorkerResult _aggregateResults(List<WorkerResult> results) {
  int totalGames = 0;
  int totalRounds = 0;
  int huCount = 0;
  int zimoCount = 0;
  int liujuCount = 0;
  final huTypeCount = <String, int>{};
  final winnerCount = <int, int>{0: 0, 1: 0, 2: 0};
  final allHuCounts = <int>[];
  int totalMs = 0;

  for (final r in results) {
    totalGames += r.totalGames;
    totalRounds += r.totalRounds;
    huCount += r.huCount;
    zimoCount += r.zimoCount;
    liujuCount += r.liujuCount;
    totalMs += r.elapsedMs;
    for (final entry in r.huTypeCount.entries) {
      huTypeCount[entry.key] = (huTypeCount[entry.key] ?? 0) + entry.value;
    }
    for (final entry in r.winnerCount.entries) {
      winnerCount[entry.key] = (winnerCount[entry.key] ?? 0) + entry.value;
    }
    allHuCounts.addAll(r.huCounts);
  }

  return WorkerResult(
    workerId: -1,
    totalGames: totalGames,
    totalRounds: totalRounds,
    huCount: huCount,
    zimoCount: zimoCount,
    liujuCount: liujuCount,
    huTypeCount: huTypeCount,
    winnerCount: winnerCount,
    huCounts: allHuCounts,
    elapsedMs: totalMs,
  );
}

/// Print aggregated results
void _printAggregatedReport(WorkerResult agg, int workerCount, int wallClockMs) {
  final huRate = agg.totalRounds > 0 ? agg.huCount / agg.totalRounds * 100 : 0.0;
  final zimoRate = agg.huCount > 0 ? agg.zimoCount / agg.huCount * 100 : 0.0;
  final liujuRate = agg.totalRounds > 0 ? agg.liujuCount / agg.totalRounds * 100 : 0.0;
  final avgHu = agg.huCounts.isEmpty ? 0.0 : agg.huCounts.reduce((a, b) => a + b) / agg.huCounts.length;

  print('=== Parallel Simulation Report ===');
  print('Workers: $workerCount');
  print('Total Games: ${agg.totalGames}');
  print('Total Rounds: ${agg.totalRounds}');
  print('Wall Clock Time: ${(wallClockMs / 1000).toStringAsFixed(1)}s');
  print('Throughput: ${(agg.totalGames / (wallClockMs / 1000)).toStringAsFixed(1)} games/sec');
  print('');
  print('Hu Rate: ${huRate.toStringAsFixed(2)}% (${agg.huCount}/${agg.totalRounds})');
  print('  Zimo: ${zimoRate.toStringAsFixed(1)}% (${agg.zimoCount})');
  print('  Dianpao: ${agg.huCount - agg.zimoCount}');
  print('Liuju Rate: ${liujuRate.toStringAsFixed(2)}% (${agg.liujuCount})');
  print('Avg Hu Count: ${avgHu.toStringAsFixed(1)}');
  print('');
  print('Hu Type Distribution:');
  final sortedTypes = agg.huTypeCount.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  for (final entry in sortedTypes) {
    final pct = agg.huCount > 0 ? (entry.value / agg.huCount * 100).toStringAsFixed(1) : '0.0';
    print('  ${entry.key}: ${entry.value} ($pct%)');
  }
  print('');
  print('Winner Distribution:');
  for (int i = 0; i < 3; i++) {
    final pct = agg.huCount > 0 ? (agg.winnerCount[i]! / agg.huCount * 100).toStringAsFixed(1) : '0.0';
    print('  AI$i: ${agg.winnerCount[i]} ($pct%)');
  }
  print('');
  print('=== Report End ===');
}

void main() {
  // Configuration: adjust these for different test scales
  const int workerCount = 4;       // Number of parallel isolates
  const int gamesPerWorker = 100;  // Games per worker (total = workerCount * gamesPerWorker)

  test('parallel AI strategy simulation', () async {
    GameLogger.setEnabled(false);

    final totalGames = workerCount * gamesPerWorker;
    print('=== Parallel AI Strategy Simulator ===');
    print('Workers: $workerCount, Games/Worker: $gamesPerWorker');
    print('Total Games: $totalGames (${totalGames * 8} rounds)');
    print('');

    final stopwatch = Stopwatch()..start();

    // Spawn workers in parallel using Isolate.run
    final futures = <Future<WorkerResult>>[];
    for (int i = 0; i < workerCount; i++) {
      final config = WorkerConfig(
        gameCount: gamesPerWorker,
        startSeed: i * 100000,  // Different seed per worker
        workerId: i,
      );
      // Use Isolate.run for true parallelism across CPU cores
      futures.add(Isolate.run(() => _runSimulationWorker(config)));
    }

    // Wait for all workers to complete
    final results = await Future.wait(futures);

    stopwatch.stop();

    // Aggregate and print results
    final agg = _aggregateResults(results);
    _printAggregatedReport(agg, workerCount, stopwatch.elapsedMilliseconds);
  }, timeout: Timeout(Duration(minutes: 60)));
}
