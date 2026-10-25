import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

import 'seat_mapper.dart';
import 'ws_client.dart';

/// 房间玩家信息
class OnlinePlayerInfo {
  final int seat;
  final String name;
  final bool ready;

  const OnlinePlayerInfo({
    required this.seat,
    required this.name,
    required this.ready,
  });
}

/// 房间公开信息（对应服务器 publicRoom）
class OnlineRoomInfo {
  final int id;
  final String status; // waiting | playing
  final List<OnlinePlayerInfo> players;

  const OnlineRoomInfo({
    required this.id,
    required this.status,
    required this.players,
  });

  int get playerCount => players.length;
}

/// 服务器 `game:action:result` 事件
class OnlineActionResult {
  final String result; // pass | claim | zhao-self
  final String? action; // claim 时为 peng/chi/zhao
  final int? seat;
  final int? nextSeat;
  final String? card;
  final String? character;
  final List<String>? meldCards;

  const OnlineActionResult({
    required this.result,
    this.action,
    this.seat,
    this.nextSeat,
    this.card,
    this.character,
    this.meldCards,
  });
}

/// 服务器 `game:hu` 事件
class OnlineHuEvent {
  final int seat; // 赢家服务器座位
  final String? card; // 点炮牌/自摸牌字面
  final int? fromSeat; // 点炮者座位；自摸为 null
  final bool zimo;
  final Map<String, dynamic>? winnerData; // 赢家客户端计算的结算数据

  const OnlineHuEvent({
    required this.seat,
    this.card,
    this.fromSeat,
    required this.zimo,
    this.winnerData,
  });
}

/// 大厅阶段事件回调（由大厅 UI 实现）
abstract class LobbyDelegate {
  /// 房间列表刷新
  void onRoomList(List<OnlineRoomInfo> rooms) {}

  /// 成功加入房间
  void onRoomJoined(OnlineRoomInfo room, int mySeat) {}

  /// 加入房间失败
  void onRoomJoinFailed(String message) {}

  /// 离开房间（主动或被重置）
  void onRoomLeft() {}

  /// 房间状态变化（人员/准备状态/对局状态）
  void onRoomUpdated(OnlineRoomInfo room) {}

  /// 3 人全准备，对局即将开始（UI 切换到游戏界面）
  void onGameStarting(int dealerSeat) {}

  /// 连接断开
  void onConnectionClosed(String reason) {}

  /// 服务器错误消息（toast 提示）
  void onServerError(String message) {}
}

/// 对局阶段事件回调（由 GameController 实现）
abstract class OnlineGameDelegate {
  /// 对局开始（飘分阶段前）：设置玩家/庄家
  void onOnlineGameStart(int dealerSeat, List<OnlinePlayerInfo> players) {}

  /// 某座位飘分上报
  void onOnlinePiaoUpdate(int seat, int piao) {}

  /// 发牌（私有）：hand 为我的手牌字面
  void onOnlineDeal(
    int dealerSeat,
    List<String> hand,
    Map<int, int> piao,
    int remaining,
  ) {}

  /// 其他玩家摸牌（广播，只有牌背）
  void onOnlineDraw(int seat, int remaining) {}

  /// 我摸牌（私有，含字面）
  void onOnlineDrawSelf(String card, int remaining) {}

  /// 其他玩家出牌（我自己的出牌本地即时处理，服务器回声被过滤）
  void onOnlineDiscard(int seat, String card) {}

  /// 响应裁决：全过 / 他人碰吃招认领 / 自己招手牌（zhao-self 自身回声被过滤）
  void onOnlineActionResult(OnlineActionResult result) {}

  /// 胡牌（点炮/自摸统一入口）
  void onOnlineHu(OnlineHuEvent event) {}

  /// 流局
  void onOnlineLiuju() {}

  /// 对局中玩家掉线（对局中止）
  void onOnlinePlayerDisconnect(int seat, String name) {}
}

/// 联机同步管理器：连接/认证/房间/对局事件路由
class GameSyncManager {
  static const _prefsPlayerIdKey = 'online_player_id';
  static const _prefsPlayerNameKey = 'online_player_name';

  final WsClient _ws = WsClient();
  final Random _random = Random();

  LobbyDelegate? lobby;
  OnlineGameDelegate? game;

  String playerId = '';
  String playerName = '玩家';
  int? roomId;
  int? mySeat;

  SeatMapper? _seatMapper;

  /// 对局开始事件缓存：room:game:start 早于游戏委托挂载时暂存，挂载后补发
  int? _pendingDealerSeat;
  List<OnlinePlayerInfo>? _pendingPlayers;

  GameSyncManager();

  bool get inRoom => roomId != null;
  bool get isConnected => _ws.isConnected;
  SeatMapper get seatMapper => _seatMapper ?? const SeatMapper(0);

  /* ------------------------- 连接与身份 ------------------------- */

  /// 连接服务器（失败抛异常，由调用方提示）
  Future<void> connect(String url, String name) async {
    playerName = name.trim().isEmpty ? '玩家${100 + _random.nextInt(900)}' : name.trim();
    await _ensureIdentity();
    _ws.onMessage = _handleMessage;
    _ws.onClosed = (reason) => lobby?.onConnectionClosed(reason);
    await _ws.connect(url);
    _ws.send({'type': 'auth', 'playerId': playerId, 'name': playerName});
  }

  Future<void> disconnect() async {
    _clearRoom();
    await _ws.close();
  }

  Future<void> _ensureIdentity() async {
    if (playerId.isNotEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    playerId = prefs.getString(_prefsPlayerIdKey) ?? '';
    if (playerId.isEmpty) {
      playerId = 'p${DateTime.now().millisecondsSinceEpoch}_${_random.nextInt(99999)}';
      await prefs.setString(_prefsPlayerIdKey, playerId);
    }
    final savedName = prefs.getString(_prefsPlayerNameKey);
    if (savedName != null && savedName.isNotEmpty) {
      playerName = savedName;
    } else {
      await prefs.setString(_prefsPlayerNameKey, playerName);
    }
  }

  /* ------------------------- 发送接口 ------------------------- */

  void requestRoomList() => _ws.send({'type': 'room:list'});

  void joinRoom(int id) => _ws.send({'type': 'room:join', 'roomId': id});

  void leaveRoom() => _ws.send({'type': 'room:leave'});

  /// 准备/取消准备（服务器为切换语义）
  void toggleReady() => _ws.send({'type': 'room:ready'});

  /// 飘分上报
  void sendPiao(int piao) => _ws.send({'type': 'game:piao', 'piao': piao});

  /// 出牌（本地已即时处理，服务器广播校验）
  void sendDiscard(String card) =>
      _ws.send({'type': 'game:action', 'action': 'discard', 'card': card});

  /// 招自己手牌上的 4 张同字牌（本地已即时处理）
  void sendZhaoSelf(String character) => _ws.send({
        'type': 'game:action',
        'action': 'zhao-self',
        'character': character,
      });

  /// 自摸胡上报（含结算数据，服务器广播后各端统一处理）
  void sendZimoHu(String card, Map<String, dynamic>? winnerData) => _ws.send({
        'type': 'game:action',
        'action': 'hu',
        'card': card,
        'zimo': true,
        if (winnerData != null) 'winnerData': winnerData,
      });

  /// 对他人弃牌的响应（胡/招/碰/吃/过）——本地不处理，等服务器裁决
  void sendClaim(
    String action, {
    List<String>? meldCards,
    Map<String, dynamic>? winnerData,
  }) =>
      _ws.send({
        'type': 'game:action:request',
        'action': action,
        if (meldCards != null) 'meldCards': meldCards,
        if (winnerData != null) 'winnerData': winnerData,
      });

  /* ------------------------- 消息路由 ------------------------- */

  void _handleMessage(Map<String, dynamic> msg) {
    final type = msg['type'] as String? ?? '';
    switch (type) {
      case 'auth:ok':
        requestRoomList();
        break;

      case 'error':
        lobby?.onServerError((msg['message'] as String?) ?? '未知错误');
        break;

      case 'room:list':
        final rooms = <OnlineRoomInfo>[];
        final raw = msg['rooms'];
        if (raw is List) {
          for (final r in raw) {
            if (r is Map<String, dynamic>) rooms.add(_parseRoom(r));
          }
        }
        lobby?.onRoomList(rooms);
        break;

      case 'room:joined':
        roomId = _asInt(msg['roomId']);
        final seat = _asInt(msg['seat']) ?? 0;
        mySeat = seat;
        _seatMapper = SeatMapper(seat);
        lobby?.onRoomJoined(_parseRoom(msg['room']), seat);
        break;

      case 'room:join:failed':
        lobby?.onRoomJoinFailed((msg['message'] as String?) ?? '加入房间失败');
        break;

      case 'room:left':
        _clearRoom();
        lobby?.onRoomLeft();
        break;

      case 'room:player:joined':
      case 'room:player:left':
      case 'room:player:ready':
        // 细粒度事件忽略，room:update 会随后到达
        break;

      case 'room:update':
        final room = _parseRoom(msg['room']);
        lobby?.onRoomUpdated(room);
        break;

      case 'room:game:start':
        final dealerSeat = _asInt(msg['dealerSeat']) ?? 0;
        final players = <OnlinePlayerInfo>[];
        final rawPlayers = msg['players'];
        if (rawPlayers is List) {
          for (final p in rawPlayers) {
            if (p is Map<String, dynamic>) {
              players.add(OnlinePlayerInfo(
                seat: _asInt(p['seat']) ?? 0,
                name: (p['name'] as String?) ?? '玩家',
                ready: true,
              ));
            }
          }
        }
        // 缓存对局开始事件；大厅回调内可能同步挂载游戏委托，避免重复分发
        _pendingDealerSeat = dealerSeat;
        _pendingPlayers = players;
        lobby?.onGameStarting(dealerSeat);
        _tryDispatchGameStart();
        break;

      case 'game:piao:update':
        game?.onOnlinePiaoUpdate(
          _asInt(msg['seat']) ?? 0,
          _asInt(msg['piao']) ?? 0,
        );
        break;

      case 'game:started':
        // 发牌明细走私有 game:deal，这里忽略
        break;

      case 'game:deal':
        final hand = <String>[];
        final rawHand = msg['hand'];
        if (rawHand is List) {
          for (final c in rawHand) {
            if (c is String) hand.add(c);
          }
        }
        final piao = <int, int>{};
        final rawPiao = msg['piao'];
        if (rawPiao is Map) {
          rawPiao.forEach((key, value) {
            final seat = int.tryParse(key.toString());
            final v = _asInt(value);
            if (seat != null && v != null) piao[seat] = v;
          });
        }
        game?.onOnlineDeal(
          _asInt(msg['dealerSeat']) ?? 0,
          hand,
          piao,
          _asInt(msg['remaining']) ?? 0,
        );
        break;

      case 'game:draw':
        final seat = _asInt(msg['seat']);
        // 自己的摸牌走私有 game:draw:self，广播回声过滤
        if (seat != null && seat != mySeat) {
          game?.onOnlineDraw(seat, _asInt(msg['remaining']) ?? 0);
        }
        break;

      case 'game:draw:self':
        game?.onOnlineDrawSelf(
          (msg['card'] as String?) ?? '',
          _asInt(msg['remaining']) ?? 0,
        );
        break;

      case 'game:action:discard':
        final seat = _asInt(msg['seat']);
        // 自己的出牌本地已即时处理，广播回声过滤
        if (seat != null && seat != mySeat) {
          game?.onOnlineDiscard(seat, (msg['card'] as String?) ?? '');
        }
        break;

      case 'game:action:result':
        final result = (msg['result'] as String?) ?? 'pass';
        final seat = _asInt(msg['seat']);
        // 自己招手牌的回声已被本地处理，过滤
        if (result == 'zhao-self' && seat == mySeat) break;
        final meldCards = <String>[];
        final rawMeld = msg['meldCards'];
        if (rawMeld is List) {
          for (final c in rawMeld) {
            if (c is String) meldCards.add(c);
          }
        }
        game?.onOnlineActionResult(OnlineActionResult(
          result: result,
          action: msg['action'] as String?,
          seat: seat,
          nextSeat: _asInt(msg['nextSeat']),
          card: msg['card'] as String?,
          character: msg['character'] as String?,
          meldCards: meldCards.isEmpty ? null : meldCards,
        ));
        break;

      case 'game:hu':
        game?.onOnlineHu(OnlineHuEvent(
          seat: _asInt(msg['seat']) ?? 0,
          card: msg['card'] as String?,
          fromSeat: _asInt(msg['fromSeat']),
          zimo: msg['zimo'] == true,
          winnerData: msg['winnerData'] is Map<String, dynamic>
              ? msg['winnerData'] as Map<String, dynamic>
              : null,
        ));
        break;

      case 'game:liuju':
        game?.onOnlineLiuju();
        break;

      case 'game:player:disconnect':
        _clearRoom();
        game?.onOnlinePlayerDisconnect(
          _asInt(msg['seat']) ?? 0,
          (msg['name'] as String?) ?? '',
        );
        lobby?.onRoomLeft();
        break;

      default:
        break;
    }
  }

  /* ------------------------- 内部工具 ------------------------- */

  /// 挂载游戏阶段委托（GameController），并补发缓存的对局开始事件
  void attachGameDelegate(OnlineGameDelegate delegate) {
    game = delegate;
    _tryDispatchGameStart();
  }

  void detachGameDelegate() {
    game = null;
  }

  void _tryDispatchGameStart() {
    if (_pendingDealerSeat == null || _pendingPlayers == null) return;
    if (game == null) return;
    final dealerSeat = _pendingDealerSeat!;
    final players = _pendingPlayers!;
    _pendingDealerSeat = null;
    _pendingPlayers = null;
    game!.onOnlineGameStart(dealerSeat, players);
  }

  void _clearRoom() {
    roomId = null;
    mySeat = null;
    _seatMapper = null;
  }

  static int? _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  static OnlineRoomInfo _parseRoom(dynamic room) {
    final players = <OnlinePlayerInfo>[];
    var id = 0;
    var status = 'waiting';
    if (room is Map) {
      id = _asInt(room['id']) ?? 0;
      status = (room['status'] as String?) ?? 'waiting';
      final rawPlayers = room['players'];
      if (rawPlayers is List) {
        for (final p in rawPlayers) {
          if (p is Map) {
            players.add(OnlinePlayerInfo(
              seat: _asInt(p['seat']) ?? 0,
              name: (p['name'] as String?) ?? '玩家',
              ready: p['ready'] == true,
            ));
          }
        }
      }
    }
    return OnlineRoomInfo(id: id, status: status, players: players);
  }
}
