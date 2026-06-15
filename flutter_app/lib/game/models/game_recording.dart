import 'dart:convert';

/// 录制动作类型
enum RecordedActionType {
  piao, // 设置飘分
  discard, // 出牌
  hu, // 胡牌（点炮）
  zimo, // 自摸
  zhao, // 招（别人出的牌）
  zhaoFromHand, // 招（自己手牌）
  selectZhao, // 选择招的字
  peng, // 碰
  chi, // 吃
  pass, // 过
  liuju, // 流局
  roundEnd, // 局结束
}

/// 录制的单个动作
class RecordedAction {
  final RecordedActionType type;
  final int playerIndex;
  final Map<String, dynamic> data;
  final int elapsedMs; // 距游戏开始的毫秒数

  RecordedAction({
    required this.type,
    required this.playerIndex,
    required this.data,
    required this.elapsedMs,
  });

  Map<String, dynamic> toJson() => {
    'type': type.name,
    'playerIndex': playerIndex,
    'data': data,
    'elapsedMs': elapsedMs,
  };

  factory RecordedAction.fromJson(Map<String, dynamic> json) {
    return RecordedAction(
      type: RecordedActionType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => RecordedActionType.pass,
      ),
      playerIndex: json['playerIndex'] as int? ?? 0,
      data: Map<String, dynamic>.from(json['data'] as Map? ?? {}),
      elapsedMs: json['elapsedMs'] as int? ?? 0,
    );
  }

  @override
  String toString() =>
      'RecordedAction(${type.name}, p=$playerIndex, data=$data, t=${elapsedMs}ms)';
}

/// 游戏录制记录
class GameRecording {
  final String id;
  final DateTime createdAt;
  final int baseScore;
  final int multiplierBase;
  final String difficulty;
  final bool piaoEnabled;
  final int dealerIndex;
  final List<int> playerGenders; // 0=male, 1=female
  final List<int> deckOrder; // 牌堆中卡牌ID的顺序（最后一个先被摸）
  final List<RecordedAction> actions;

  /// 录制结果摘要（最后一局的结果）
  String? resultSummary;

  GameRecording({
    required this.id,
    required this.createdAt,
    required this.baseScore,
    required this.multiplierBase,
    required this.difficulty,
    required this.piaoEnabled,
    required this.dealerIndex,
    required this.playerGenders,
    required this.deckOrder,
    required this.actions,
    this.resultSummary,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'createdAt': createdAt.toIso8601String(),
    'baseScore': baseScore,
    'multiplierBase': multiplierBase,
    'difficulty': difficulty,
    'piaoEnabled': piaoEnabled,
    'dealerIndex': dealerIndex,
    'playerGenders': playerGenders,
    'deckOrder': deckOrder,
    'actions': actions.map((a) => a.toJson()).toList(),
    'resultSummary': resultSummary,
  };

  factory GameRecording.fromJson(Map<String, dynamic> json) {
    return GameRecording(
      id: json['id'] as String? ?? '',
      createdAt: DateTime.parse(
        json['createdAt'] as String? ?? DateTime.now().toIso8601String(),
      ),
      baseScore: json['baseScore'] as int? ?? 5,
      multiplierBase: json['multiplierBase'] as int? ?? 2,
      difficulty: json['difficulty'] as String? ?? 'hard',
      piaoEnabled: json['piaoEnabled'] as bool? ?? false,
      dealerIndex: json['dealerIndex'] as int? ?? 0,
      playerGenders: List<int>.from(json['playerGenders'] as List? ?? [0, 0, 0]),
      deckOrder: List<int>.from(json['deckOrder'] as List? ?? []),
      actions: (json['actions'] as List?)
              ?.map((a) => RecordedAction.fromJson(a as Map<String, dynamic>))
              .toList() ??
          [],
      resultSummary: json['resultSummary'] as String?,
    );
  }

  String toJsonString() => jsonEncode(toJson());

  factory GameRecording.fromJsonString(String str) {
    return GameRecording.fromJson(
      jsonDecode(str) as Map<String, dynamic>,
    );
  }

  /// 获取格式化的创建时间
  String get formattedDate {
    final m = createdAt.month.toString().padLeft(2, '0');
    final d = createdAt.day.toString().padLeft(2, '0');
    final h = createdAt.hour.toString().padLeft(2, '0');
    final min = createdAt.minute.toString().padLeft(2, '0');
    return '$m-$d $h:$min';
  }

  /// 获取游戏时长（秒）
  int get durationSeconds {
    if (actions.isEmpty) return 0;
    return actions.last.elapsedMs ~/ 1000;
  }

  /// 获取格式化的时长
  String get formattedDuration {
    final secs = durationSeconds;
    final m = secs ~/ 60;
    final s = secs % 60;
    return '${m}分${s.toString().padLeft(2, '0')}秒';
  }
}
