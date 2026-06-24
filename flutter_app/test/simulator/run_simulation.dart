import 'dart:io';
import 'game_simulator.dart';
import 'statistics.dart';

/// 主入口：运行模拟并输出统计报告
void main(List<String> args) {
  final gameCount = args.isNotEmpty ? int.tryParse(args[0]) ?? 100 : 100;
  final debug = args.contains('--debug');

  print('=== AI策略模拟器 ===');
  print('运行 $gameCount 组8局游戏...');
  print('');

  final simulator = GameSimulator(debugLog: debug);
  final stats = StatsCollector();

  final stopwatch = Stopwatch()..start();

  for (int i = 0; i < gameCount; i++) {
    if ((i + 1) % 10 == 0) {
      print('进度: ${i + 1}/$gameCount (${((i + 1) / gameCount * 100).toStringAsFixed(1)}%)');
    }

    try {
      final result = simulator.runGame(i);
      stats.addGameResult(result);
    } catch (e, stack) {
      print('游戏 $i 出错: $e');
      if (debug) print(stack);
    }
  }

  stopwatch.stop();
  print('');
  print('耗时: ${stopwatch.elapsed.inSeconds}秒');
  print('');

  stats.getStats().printReport();
}
