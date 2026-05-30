import '../../models/card.dart';
import '../../models/game_state.dart';
import '../../models/player.dart';

abstract class AIStrategy {
  Card selectDiscard(Player player, GameState state);

  bool shouldChi(Player player, Card card, GameState state);

  bool shouldPeng(Player player, Card card, GameState state);

  bool shouldZhao(Player player, Card card, GameState state);

  bool shouldZhaoFromHand(Player player, String character, GameState state);

  bool shouldHu(
    Player player,
    Card card,
    GameState state, {
    bool isZimo = false,
  });
}
