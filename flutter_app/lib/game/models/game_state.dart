import 'card.dart';
import 'player.dart';

class GameState {
  List<Player> players;
  int currentPlayerIndex;
  int dealerIndex;
  int roundNumber;
  List<Card> deck;
  Card? lastDiscardedCard;
  int? lastDiscardPlayerIndex;
  bool isMyTurn;
  bool isDrawing;
  bool canChi;
  bool canPeng;
  bool canZhao;
  bool canHu;
  bool isZimoOpportunity;
  bool gameStarted;
  bool isHandlingHu;
  bool waitingForResponse;
  bool isDealingComplete;
  List<Map<String, dynamic>> roundHistory;

  // 游戏设置
  int baseScore;
  int multiplierBase;
  String difficulty;
  bool piaoEnabled;

  // 飘分阶段
  bool isPiaoPhase;
  int piaoCurrentPlayerIndex;
  int piaoSetCount;

  // 倒计时
  int countdown;
  bool isDiscarding;
  bool isClosingHuMessage;

  List<String> zhaoCandidates;
  bool showZhaoSelection;
  bool hideTingBadge;

  String? huResultWinnerName;
  int? huResultWinnerIndex;
  String? huResultMethod;
  String? huResultHuType;
  int? huResultHuCount;
  int? huResultMultiplier;
  int? huResultScore;
  int? huResultDianpaoIndex;
  String? huResultDianpaoName;
  Card? huResultDianpaoCard;
  Card? huResultZimoCard;
  Map<int, int>? huResultScoreChanges;
  Map<int, int>? huResultOldScores;
  bool showHuResult;
  bool showLiujuResult;

  Map<String, int> publicCardCount;

  GameState({
    List<Player>? players,
    this.currentPlayerIndex = 0,
    this.dealerIndex = 0,
    this.roundNumber = 1,
    List<Card>? deck,
    this.lastDiscardedCard,
    this.lastDiscardPlayerIndex,
    this.isMyTurn = false,
    this.isDrawing = false,
    this.canChi = false,
    this.canPeng = false,
    this.canZhao = false,
    this.canHu = false,
    this.isZimoOpportunity = false,
    this.gameStarted = false,
    this.isHandlingHu = false,
    this.waitingForResponse = false,
    this.isDealingComplete = false,
    List<Map<String, dynamic>>? roundHistory,
    this.baseScore = 5,
    this.multiplierBase = 2,
    this.difficulty = 'hard',
    this.piaoEnabled = false,
    this.isPiaoPhase = false,
    this.piaoCurrentPlayerIndex = 0,
    this.piaoSetCount = 0,
    this.countdown = 0,
    this.isDiscarding = false,
    this.isClosingHuMessage = false,
    List<String>? zhaoCandidates,
    this.showZhaoSelection = false,
    this.hideTingBadge = false,
    this.huResultWinnerName,
    this.huResultWinnerIndex,
    this.huResultMethod,
    this.huResultHuType,
    this.huResultHuCount,
    this.huResultMultiplier,
    this.huResultScore,
    this.huResultDianpaoIndex,
    this.huResultDianpaoName,
    this.huResultDianpaoCard,
    this.huResultZimoCard,
    this.huResultScoreChanges,
    this.huResultOldScores,
    this.showHuResult = false,
    this.showLiujuResult = false,
    Map<String, int>? publicCardCount,
  }) : players = players ?? [],
       deck = deck ?? [],
       roundHistory = roundHistory ?? [],
       zhaoCandidates = zhaoCandidates ?? [],
       publicCardCount = publicCardCount ?? {};

  void reset() {
    players = [];
    currentPlayerIndex = 0;
    dealerIndex = 0;
    roundNumber = 1;
    deck = [];
    lastDiscardedCard = null;
    lastDiscardPlayerIndex = null;
    isMyTurn = false;
    isDrawing = false;
    canChi = false;
    canPeng = false;
    canZhao = false;
    canHu = false;
    isZimoOpportunity = false;
    gameStarted = false;
    isHandlingHu = false;
    waitingForResponse = false;
    isDealingComplete = false;
    isPiaoPhase = false;
    piaoCurrentPlayerIndex = 0;
    piaoSetCount = 0;
    countdown = 0;
    isDiscarding = false;
    isClosingHuMessage = false;
    zhaoCandidates.clear();
    showZhaoSelection = false;
    hideTingBadge = false;
    huResultWinnerName = null;
    huResultWinnerIndex = null;
    huResultMethod = null;
    huResultHuType = null;
    huResultHuCount = null;
    huResultMultiplier = null;
    huResultScore = null;
    huResultDianpaoIndex = null;
    huResultDianpaoName = null;
    huResultDianpaoCard = null;
    huResultZimoCard = null;
    huResultScoreChanges = null;
    huResultOldScores = null;
    showHuResult = false;
    showLiujuResult = false;
    roundHistory.clear();
    publicCardCount.clear();
  }

  void nextRound() {
    roundNumber++;
    currentPlayerIndex = dealerIndex;
    deck = Card.createDeck();
    lastDiscardedCard = null;
    lastDiscardPlayerIndex = null;
    isMyTurn = false;
    isDrawing = false;
    canChi = false;
    canPeng = false;
    canZhao = false;
    canHu = false;
    isHandlingHu = false;
    for (final player in players) {
      player.hand.clear();
      player.melds.clear();
      player.discards.clear();
      player.isTing = false;
      player.tingCards.clear();
    }
    publicCardCount.clear();
  }

  Player currentTurnPlayer() => players[currentPlayerIndex];

  Map<String, int> buildVisibleCount(Player player) {
    final count = Map<String, int>.from(publicCardCount);
    for (final card in player.hand) {
      count[card.character] = (count[card.character] ?? 0) + 1;
    }
    return count;
  }

  int totalUnknownCards(Player player) {
    int visible = player.hand.length;
    for (final p in players) {
      visible += p.discards.length;
      for (final meld in p.melds) {
        visible += meld.cards.length;
      }
    }
    final unknown = 96 - visible;
    return unknown > 0 ? unknown : 1;
  }

  @override
  String toString() =>
      'GameState(round=$roundNumber, current=$currentPlayerIndex, deck=${deck.length})';
}
