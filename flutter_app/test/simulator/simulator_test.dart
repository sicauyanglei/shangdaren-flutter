import 'package:flutter_test/flutter_test.dart';
import 'package:shangdaren_game/game/core/game_logger_io.dart';
import 'game_simulator.dart';
import 'statistics.dart';
import 'decision_logger.dart';

void main() {
  test('run AI strategy simulation', () {
    // Disable game logger to speed up
    GameLogger.setEnabled(false);

    final gameCount = 20;

    print('=== AI Strategy Simulator ===');
    print('Running $gameCount games (8 rounds each)...');
    print('');

    final simulator = GameSimulator();
    final stats = StatsCollector();
    DecisionLogger().enabled = true;
    DecisionLogger().clear();

    final stopwatch = Stopwatch()..start();

    for (int i = 0; i < gameCount; i++) {
      if ((i + 1) % 5 == 0 || i == 0) {
        print('Progress: ${i + 1}/$gameCount');
      }

      try {
        final result = simulator.runGame(i);
        stats.addGameResult(result);
      } catch (e, stack) {
        print('Game $i error: $e');
        if (i < 3) print(stack);
      }
    }

    stopwatch.stop();
    print('');
    print('Time: ${stopwatch.elapsed.inSeconds}s (avg ${(stopwatch.elapsed.inMilliseconds / gameCount).toStringAsFixed(0)}ms/game)');
    print('');

    stats.getStats().printReport();

    print('');
    DecisionLogger().printAnalysis();
  });
}
