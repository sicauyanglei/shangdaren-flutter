import 'dart:async';
import 'ai_strategy.dart';
import 'ai_strategy_simple.dart';
import '../../models/card.dart';
import '../../models/game_state.dart';
import '../../models/player.dart';

class AIController {
  final AIStrategy _strategy;
  final Duration _thinkDelay;

  AIController({AIStrategy? strategy, Duration? thinkDelay})
    : _strategy = strategy ?? AIStrategySimple(),
      _thinkDelay = thinkDelay ?? const Duration(milliseconds: 500);

  Card selectDiscard(Player player, GameState state) {
    return _strategy.selectDiscard(player, state);
  }

  Future<Card> selectDiscardAsync(Player player, GameState state) async {
    await Future.delayed(_thinkDelay);
    return _strategy.selectDiscard(player, state);
  }

  Future<String?> shouldRespondAsync(
    Player player,
    Card card,
    GameState state,
    List<String> availableActions,
  ) async {
    await Future.delayed(_thinkDelay);

    if (availableActions.contains('hu') &&
        _strategy.shouldHu(player, card, state)) {
      return 'hu';
    }

    if (availableActions.contains('zhao') &&
        _strategy.shouldZhao(player, card, state)) {
      return 'zhao';
    }

    if (availableActions.contains('peng') &&
        _strategy.shouldPeng(player, card, state)) {
      return 'peng';
    }

    if (availableActions.contains('chi') &&
        _strategy.shouldChi(player, card, state)) {
      return 'chi';
    }

    return null;
  }

  bool shouldZhaoFromHand(Player player, String character, GameState state) {
    return _strategy.shouldZhaoFromHand(player, character, state);
  }
}
