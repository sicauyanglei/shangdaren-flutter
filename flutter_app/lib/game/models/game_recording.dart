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
  final int elapsedMs; // 距本局开始的毫秒数

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

/// 单局录制数据
class RoundRecording {
  final int roundNumber;
  final int dealerIndex;
  final List<int> deckOrder; // 牌堆中卡牌ID的顺序（最后一个先被摸）
  final List<int> playerGenders; // 0=male, 1=female
  final List<int> playerScores; // 本局开始时的分数
  final List<int> playerPiao; // 飘分值
  final int baseScore;
  final int multiplierBase;
  final String difficulty;
  final bool piaoEnabled;
  final List<RecordedAction> actions;
  // 本局结果
  final Map<String, dynamic>? roundResult;

  RoundRecording({
    required this.roundNumber,
    required this.dealerIndex,
    required this.deckOrder,
    required this.playerGenders,
    required this.playerScores,
    required this.playerPiao,
    required this.baseScore,
    required this.multiplierBase,
    required this.difficulty,
    required this.piaoEnabled,
    required this.actions,
    this.roundResult,
  });

  Map<String, dynamic> toJson() => {
    'roundNumber': roundNumber,
    'dealerIndex': dealerIndex,
    'deckOrder': deckOrder,
    'playerGenders': playerGenders,
    'playerScores': playerScores,
    'playerPiao': playerPiao,
    'baseScore': baseScore,
    'multiplierBase': multiplierBase,
    'difficulty': difficulty,
    'piaoEnabled': piaoEnabled,
    'actions': actions.map((a) => a.toJson()).toList(),
    'roundResult': roundResult,
  };

  factory RoundRecording.fromJson(Map<String, dynamic> json) {
    return RoundRecording(
      roundNumber: json['roundNumber'] as int? ?? 1,
      dealerIndex: json['dealerIndex'] as int? ?? 0,
      deckOrder: List<int>.from(json['deckOrder'] as List? ?? []),
      playerGenders: List<int>.from(json['playerGenders'] as List? ?? [0, 0, 0]),
      playerScores: List<int>.from(json['playerScores'] as List? ?? [0, 0, 0]),
      playerPiao: List<int>.from(json['playerPiao'] as List? ?? [0, 0, 0]),
      baseScore: json['baseScore'] as int? ?? 5,
      multiplierBase: json['multiplierBase'] as int? ?? 2,
      difficulty: json['difficulty'] as String? ?? 'hard',
      piaoEnabled: json['piaoEnabled'] as bool? ?? false,
      actions: (json['actions'] as List?)
              ?.map((a) => RecordedAction.fromJson(a as Map<String, dynamic>))
              .toList() ??
          [],
      roundResult: json['roundResult'] as Map<String, dynamic>?,
    );
  }
}

/// 整场游戏录制（包含多局）
class GameRecording {
  final String id;
  final DateTime createdAt;
  final List<RoundRecording> rounds;

  GameRecording({
    required this.id,
    required this.createdAt,
    required this.rounds,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'createdAt': createdAt.toIso8601String(),
    'rounds': rounds.map((r) => r.toJson()).toList(),
  };

  factory GameRecording.fromJson(Map<String, dynamic> json) {
    return GameRecording(
      id: json['id'] as String? ?? '',
      createdAt: DateTime.parse(
        json['createdAt'] as String? ?? DateTime.now().toIso8601String(),
      ),
      rounds: (json['rounds'] as List?)
              ?.map((r) => RoundRecording.fromJson(r as Map<String, dynamic>))
              .toList() ??
          [],
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

  /// 获取游戏总时长（秒）
  int get durationSeconds {
    if (rounds.isEmpty) return 0;
    int total = 0;
    for (final r in rounds) {
      if (r.actions.isNotEmpty) {
        total += r.actions.last.elapsedMs;
      }
    }
    return total ~/ 1000;
  }

  /// 获取格式化的时长
  String get formattedDuration {
    final secs = durationSeconds;
    final m = secs ~/ 60;
    final s = secs % 60;
    return '${m}分${s.toString().padLeft(2, '0')}秒';
  }
}
