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

  // 增量维护的全局统计
  /// 全局已见牌总数（所有公开牌+当前玩家手牌），用于快速计算unknown
  int totalVisibleCards = 0;

  /// 增量更新：某字牌公开数量变化
  void addPublicCount(String character, int count) {
    publicCardCount[character] = (publicCardCount[character] ?? 0) + count;
    totalVisibleCards += count;
  }

  /// 增量更新：某字牌公开数量减少
  void removePublicCount(String character, int count) {
    final current = publicCardCount[character] ?? 0;
    final newCount = current - count;
    if (newCount <= 0) {
      publicCardCount.remove(character);
    } else {
      publicCardCount[character] = newCount;
    }
    totalVisibleCards -= count;
    if (totalVisibleCards < 0) totalVisibleCards = 0;
  }

  /// 获取某张牌的全局剩余张数（4 - 公开数量 - 玩家手牌数量）
  int remainingCount(String character, Player player) {
    final visible = (publicCardCount[character] ?? 0) +
        player.hand.where((c) => c.character == character).length;
    final rem = 4 - visible;
    return rem > 0 ? rem : 0;
  }

  /// 获取未知牌总数（96 - 公开牌 - 当前玩家手牌）
  int unknownCards(Player player) {
    final unknown = 96 - totalVisibleCards - player.hand.length;
    return unknown > 0 ? unknown : 1;
  }

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
    totalVisibleCards = 0;
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
    totalVisibleCards = 0;
  }

  Player currentTurnPlayer() => players[currentPlayerIndex];

  /// 构建玩家可见的牌数表（公开牌 + 自己手牌）
  /// 保留旧接口兼容性，但内部使用增量维护的数据
  Map<String, int> buildVisibleCount(Player player) {
    final count = Map<String, int>.from(publicCardCount);
    for (final card in player.hand) {
      count[card.character] = (count[card.character] ?? 0) + 1;
    }
    return count;
  }

  /// 计算未知牌总数（使用增量维护的数据，避免遍历）
  int totalUnknownCards(Player player) {
    return unknownCards(player);
  }

  @override
  String toString() =>
      'GameState(round=$roundNumber, current=$currentPlayerIndex, deck=${deck.length})';
}
