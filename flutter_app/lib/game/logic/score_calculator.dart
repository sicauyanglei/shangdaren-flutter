import '../models/game_state.dart';
import 'hu_calculator.dart';

class ScoreCalculator {
  static Map<int, int> calculateScores(
    GameState state,
    int winnerIndex,
    int? dianpaoIndex,
    bool isZimo,
    HuTypeResult huTypeResult,
  ) {
    final result = <int, int>{};
    final winner = state.players[winnerIndex];
    final baseMultiplier = isZimo ? huTypeResult.zimo : huTypeResult.dianpao;

    for (int i = 0; i < state.players.length; i++) {
      result[i] = 0;
    }

    if (isZimo) {
      for (int i = 0; i < state.players.length; i++) {
        if (i == winnerIndex) {
          result[i] =
              2 * (state.baseScore + baseMultiplier * state.multiplierBase) +
              winner.piao * 2 +
              _sumOtherPiao(state, winnerIndex);
        } else {
          final loser = state.players[i];
          result[i] =
              -(state.baseScore +
                  baseMultiplier * state.multiplierBase +
                  loser.piao +
                  winner.piao);
        }
      }
    } else {
      final dianpao = dianpaoIndex != null ? state.players[dianpaoIndex] : null;
      for (int i = 0; i < state.players.length; i++) {
        if (i == winnerIndex) {
          result[i] =
              state.baseScore +
              baseMultiplier * state.multiplierBase +
              winner.piao +
              (dianpao?.piao ?? 0);
        } else if (i == dianpaoIndex) {
          final loser = state.players[i];
          result[i] =
              -(state.baseScore +
                  baseMultiplier * state.multiplierBase +
                  loser.piao +
                  winner.piao);
        } else {
          result[i] = 0;
        }
      }
    }

    return result;
  }

  static int _sumOtherPiao(GameState state, int winnerIndex) {
    int sum = 0;
    for (int i = 0; i < state.players.length; i++) {
      if (i != winnerIndex) {
        sum += state.players[i].piao;
      }
    }
    return sum;
  }
}
