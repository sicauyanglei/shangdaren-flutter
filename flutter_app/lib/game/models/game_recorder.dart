import 'dart:convert';
import 'card.dart';
import 'meld.dart';
import 'player.dart';

/// 单步操作记录
class ReplayAction {
  final String
  type; // deal, draw, discard, chi, peng, zhao, zhao_from_hand, hu, zimo, liuju, piao
  final int playerIndex;
  final Map<String, dynamic> data;

  ReplayAction({
    required this.type,
    required this.playerIndex,
    required this.data,
  });

  Map<String, dynamic> toJson() => {
    'type': type,
    'playerIndex': playerIndex,
    'data': data,
  };

  factory ReplayAction.fromJson(Map<String, dynamic> json) => ReplayAction(
    type: json['type'] as String,
    playerIndex: json['playerIndex'] as int,
    data: Map<String, dynamic>.from(json['data'] as Map),
  );
}

/// 单局回放数据
class RoundReplay {
  final int roundNumber;
  final int dealerIndex;
  final List<String> playerNames;
  final List<Gender> playerGenders;
  final List<int> playerPiao;
  final List<int> playerScores; // 局开始时各玩家总分
  final List<Map<String, dynamic>> initialHands; // 初始手牌
  final List<ReplayAction> actions;
  final String? resultType; // hu / liuju
  final Map<String, dynamic>? resultData;

  RoundReplay({
    required this.roundNumber,
    required this.dealerIndex,
    required this.playerNames,
    required this.playerGenders,
    required this.playerPiao,
    required this.playerScores,
    required this.initialHands,
    required this.actions,
    this.resultType,
    this.resultData,
  });

  Map<String, dynamic> toJson() => {
    'roundNumber': roundNumber,
    'dealerIndex': dealerIndex,
    'playerNames': playerNames,
    'playerGenders': playerGenders.map((g) => g.index).toList(),
    'playerPiao': playerPiao,
    'playerScores': playerScores,
    'initialHands': initialHands,
    'actions': actions.map((a) => a.toJson()).toList(),
    'resultType': resultType,
    'resultData': resultData,
  };

  factory RoundReplay.fromJson(Map<String, dynamic> json) => RoundReplay(
    roundNumber: json['roundNumber'] as int,
    dealerIndex: json['dealerIndex'] as int,
    playerNames: List<String>.from(json['playerNames'] as List),
    playerGenders: List<int>.from(
      json['playerGenders'] as List,
    ).map((i) => Gender.values[i]).toList(),
    playerPiao: List<int>.from(json['playerPiao'] as List),
    playerScores: List<int>.from(json['playerScores'] as List),
    initialHands: List<Map<String, dynamic>>.from(
      (json['initialHands'] as List).map(
        (e) => Map<String, dynamic>.from(e as Map),
      ),
    ),
    actions: (json['actions'] as List)
        .map((a) => ReplayAction.fromJson(a as Map<String, dynamic>))
        .toList(),
    resultType: json['resultType'] as String?,
    resultData: json['resultData'] != null
        ? Map<String, dynamic>.from(json['resultData'] as Map)
        : null,
  );

  String toJsonString() => jsonEncode(toJson());

  static RoundReplay fromJsonString(String s) =>
      RoundReplay.fromJson(jsonDecode(s) as Map<String, dynamic>);
}

/// 游戏录制器
class GameRecorder {
  static final GameRecorder _instance = GameRecorder._internal();
  factory GameRecorder() => _instance;
  GameRecorder._internal();

  bool _enabled = false;
  bool get enabled => _enabled;

  RoundReplay? _currentRound;
  final List<RoundReplay> _roundReplays = [];
  List<RoundReplay> get roundReplays => _roundReplays;

  void setEnabled(bool v) {
    _enabled = v;
    if (!v) {
      _currentRound = null;
      _roundReplays.clear();
    }
  }

  /// 开始录制新一局
  void startRound(int roundNumber, int dealerIndex, List<Player> players) {
    if (!_enabled) return;
    _currentRound = RoundReplay(
      roundNumber: roundNumber,
      dealerIndex: dealerIndex,
      playerNames: players.map((p) => p.name).toList(),
      playerGenders: players.map((p) => p.gender).toList(),
      playerPiao: players.map((p) => p.piao).toList(),
      playerScores: players.map((p) => p.score).toList(),
      initialHands: players.map((p) => _serializeHand(p.hand)).toList(),
      actions: [],
    );
  }

  /// 记录发牌完成后的初始手牌
  void recordInitialHands(List<Player> players) {
    if (!_enabled || _currentRound == null) return;
    _currentRound!.initialHands.clear();
    _currentRound!.initialHands.addAll(
      players.map((p) => _serializeHand(p.hand)).toList(),
    );
  }

  /// 记录飘分
  void recordPiao(int playerIndex, int piaoValue) {
    if (!_enabled || _currentRound == null) return;
    _currentRound!.actions.add(
      ReplayAction(
        type: 'piao',
        playerIndex: playerIndex,
        data: {'piao': piaoValue},
      ),
    );
  }

  /// 记录摸牌
  void recordDraw(int playerIndex, Card card) {
    if (!_enabled || _currentRound == null) return;
    _currentRound!.actions.add(
      ReplayAction(
        type: 'draw',
        playerIndex: playerIndex,
        data: {'card': _serializeCard(card)},
      ),
    );
  }

  /// 记录出牌
  void recordDiscard(int playerIndex, Card card) {
    if (!_enabled || _currentRound == null) return;
    _currentRound!.actions.add(
      ReplayAction(
        type: 'discard',
        playerIndex: playerIndex,
        data: {'card': _serializeCard(card)},
      ),
    );
  }

  /// 记录吃
  void recordChi(
    int playerIndex,
    List<Card> chiCards,
    Card fromCard,
    int fromPlayerIndex,
  ) {
    if (!_enabled || _currentRound == null) return;
    _currentRound!.actions.add(
      ReplayAction(
        type: 'chi',
        playerIndex: playerIndex,
        data: {
          'cards': chiCards.map(_serializeCard).toList(),
          'fromCard': _serializeCard(fromCard),
          'fromPlayerIndex': fromPlayerIndex,
        },
      ),
    );
  }

  /// 记录碰
  void recordPeng(int playerIndex, Card card, int fromPlayerIndex) {
    if (!_enabled || _currentRound == null) return;
    _currentRound!.actions.add(
      ReplayAction(
        type: 'peng',
        playerIndex: playerIndex,
        data: {
          'card': _serializeCard(card),
          'fromPlayerIndex': fromPlayerIndex,
        },
      ),
    );
  }

  /// 记录招（别人出的牌）
  void recordZhao(int playerIndex, Card card, int fromPlayerIndex) {
    if (!_enabled || _currentRound == null) return;
    _currentRound!.actions.add(
      ReplayAction(
        type: 'zhao',
        playerIndex: playerIndex,
        data: {
          'card': _serializeCard(card),
          'fromPlayerIndex': fromPlayerIndex,
        },
      ),
    );
  }

  /// 记录招（自己手牌的4张）
  void recordZhaoFromHand(int playerIndex, String character, List<Card> cards) {
    if (!_enabled || _currentRound == null) return;
    _currentRound!.actions.add(
      ReplayAction(
        type: 'zhao_from_hand',
        playerIndex: playerIndex,
        data: {
          'character': character,
          'cards': cards.map(_serializeCard).toList(),
        },
      ),
    );
  }

  /// 记录点炮胡
  void recordHu(
    int winnerIndex,
    int dianpaoIndex,
    Card card,
    String huType,
    int multiplier,
  ) {
    if (!_enabled || _currentRound == null) return;
    _currentRound!.actions.add(
      ReplayAction(
        type: 'hu',
        playerIndex: winnerIndex,
        data: {
          'dianpaoIndex': dianpaoIndex,
          'card': _serializeCard(card),
          'huType': huType,
          'multiplier': multiplier,
        },
      ),
    );
  }

  /// 记录自摸
  void recordZimo(int winnerIndex, Card card, String huType, int multiplier) {
    if (!_enabled || _currentRound == null) return;
    _currentRound!.actions.add(
      ReplayAction(
        type: 'zimo',
        playerIndex: winnerIndex,
        data: {
          'card': _serializeCard(card),
          'huType': huType,
          'multiplier': multiplier,
        },
      ),
    );
  }

  /// 记录流局
  void recordLiuju() {
    if (!_enabled || _currentRound == null) return;
    _currentRound!.actions.add(
      ReplayAction(type: 'liuju', playerIndex: -1, data: {}),
    );
  }

  /// 结束本局录制
  void endRound({String? resultType, Map<String, dynamic>? resultData}) {
    if (!_enabled || _currentRound == null) return;
    _currentRound = RoundReplay(
      roundNumber: _currentRound!.roundNumber,
      dealerIndex: _currentRound!.dealerIndex,
      playerNames: _currentRound!.playerNames,
      playerGenders: _currentRound!.playerGenders,
      playerPiao: _currentRound!.playerPiao,
      playerScores: _currentRound!.playerScores,
      initialHands: _currentRound!.initialHands,
      actions: _currentRound!.actions,
      resultType: resultType,
      resultData: resultData,
    );
    _roundReplays.add(_currentRound!);
    _currentRound = null;
  }

  /// 获取指定局的回放数据
  RoundReplay? getRoundReplay(int roundNumber) {
    for (final r in _roundReplays) {
      if (r.roundNumber == roundNumber) return r;
    }
    return null;
  }

  /// 清除所有录制数据
  void clear() {
    _currentRound = null;
    _roundReplays.clear();
  }

  // 序列化辅助
  static Map<String, dynamic> _serializeCard(Card c) => {
    'id': c.id,
    'character': c.character,
    'sentence': c.sentence,
    'position': c.position,
  };

  static Card _deserializeCard(Map<String, dynamic> m) => Card(
    id: m['id'] as int,
    character: m['character'] as String,
    sentence: m['sentence'] as int,
    position: m['position'] as int,
  );

  static Map<String, dynamic> _serializeHand(List<Card> hand) => {
    'cards': hand.map(_serializeCard).toList(),
  };

  static List<Card> deserializeHand(Map<String, dynamic> m) =>
      (m['cards'] as List)
          .map((c) => _deserializeCard(c as Map<String, dynamic>))
          .toList();

  static Card deserializeCard(Map<String, dynamic> m) => _deserializeCard(m);
}
