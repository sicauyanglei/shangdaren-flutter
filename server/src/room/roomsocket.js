/**
 * WebSocket 房间 + 游戏同步服务器（默认端口 8080）
 *
 * 消息协议（JSON：{ type, ...payload }）：
 *   Client → Server:
 *     auth               { playerId, name }
 *     room:list          {}
 *     room:join          { roomId }
 *     room:leave         {}
 *     room:ready         {}
 *     game:piao          { piao }
 *     game:action        { action: 'discard', card }                     出牌
 *                        { action: 'hu', card, zimo: true, winnerData? } 自摸胡
 *                        { action: 'zhao-self', character }               招自己手牌4张
 *     game:action:request { action: 'hu'|'zhao'|'peng'|'chi'|'pass', meldCards?, winnerData? }
 *
 *   Server → Client:
 *     auth:ok / error
 *     room:list { rooms }
 *     room:join:failed { roomId, message }
 *     room:joined { roomId, seat, room }
 *     room:left { roomId }
 *     room:player:joined { roomId, seat, name }
 *     room:player:left { roomId, seat, name }
 *     room:player:ready { roomId, seat, ready }
 *     room:update { room }
 *     room:game:start { roomId, dealerSeat, players }
 *     game:piao:update { roomId, seat, piao }
 *     game:started { roomId, dealerSeat, remaining, piao }
 *     game:deal { roomId, yourSeat, dealerSeat, hand, piao, remaining }   （私有）
 *     game:draw { roomId, seat, remaining }
 *     game:draw:self { roomId, card, remaining }                            （私有）
 *     game:action:discard { roomId, seat, card }
 *     game:action:result { roomId, result: 'pass'|'claim'|'zhao-self', nextSeat?, action?, seat?, card?, character?, meldCards? }
 *     game:hu { roomId, seat, card, fromSeat, zimo, winnerData }           点炮 fromSeat=出牌者；自摸 fromSeat=null
 *     game:liuju { roomId }
 *     game:player:disconnect { roomId, seat, name }
 */
const { WebSocketServer } = require('ws');
const { GameSession, nextDealer } = require('../game/gameManager');

/** 出牌响应窗口（未响应者视为过牌） */
const RESPONSE_TIMEOUT_MS = 30_000;
/** 飘分窗口（未上报者视为飘 0 分） */
const PIAO_TIMEOUT_MS = 30_000;
/** 心跳间隔（无 pong 判死连接） */
const HEARTBEAT_MS = 30_000;

class RoomSocketServer {
  /**
   * @param {import('./roomManager').RoomManager} roomManager
   * @param {number} port
   */
  constructor(roomManager, port = 8080) {
    this.roomManager = roomManager;
    this.port = port;
    /** @type {Map<string, import('ws').WebSocket>} playerId -> ws */
    this.sockets = new Map();

    this.wss = new WebSocketServer({ port });
    this.wss.on('connection', (ws) => this._onConnection(ws));

    this.heartbeatTimer = setInterval(() => {
      for (const ws of this.wss.clients) {
        if (ws.isAlive === false) {
          ws.terminate();
          continue;
        }
        ws.isAlive = false;
        ws.ping();
      }
    }, HEARTBEAT_MS);
  }

  /* ------------------------- 连接管理 ------------------------- */

  _onConnection(ws) {
    ws.isAlive = true;
    ws.on('pong', () => {
      ws.isAlive = true;
    });
    ws.on('message', (raw) => this._onMessage(ws, raw));
    ws.on('close', () => this._onClose(ws));
  }

  _onMessage(ws, raw) {
    let msg;
    try {
      msg = JSON.parse(raw.toString());
    } catch {
      return this._send(ws, { type: 'error', message: '消息格式错误' });
    }
    if (msg.type === 'auth') return this._handleAuth(ws, msg);

    const playerId = ws.playerId;
    if (!playerId) return this._send(ws, { type: 'error', message: '请先发送 auth 认证' });

    switch (msg.type) {
      case 'room:list':
        return this._handleRoomList(ws);
      case 'room:join':
        return this._handleRoomJoin(ws, playerId, msg);
      case 'room:leave':
        return this._handleRoomLeave(ws, playerId, true);
      case 'room:ready':
        return this._handleRoomReady(ws, playerId);
      case 'game:piao':
        return this._handleGamePiao(ws, playerId, msg);
      case 'game:action':
        return this._handleGameAction(ws, playerId, msg);
      case 'game:action:request':
        return this._handleActionRequest(ws, playerId, msg);
      default:
        return this._send(ws, { type: 'error', message: `未知消息类型: ${msg.type}` });
    }
  }

  _handleAuth(ws, msg) {
    const playerId = String(msg.playerId || '');
    const name = String(msg.name || '玩家').slice(0, 16);
    if (!playerId) return this._send(ws, { type: 'error', message: 'auth 缺少 playerId' });

    // 顶号：断开同 playerId 旧连接（close 回调中会执行离开房间逻辑）
    const old = this.sockets.get(playerId);
    if (old && old !== ws) old.terminate();

    ws.playerId = playerId;
    ws.playerName = name;
    this.sockets.set(playerId, ws);
    this._send(ws, { type: 'auth:ok', playerId, name });
  }

  _onClose(ws) {
    const playerId = ws.playerId;
    if (playerId && this.sockets.get(playerId) === ws) {
      this.sockets.delete(playerId);
      this._handleRoomLeave(ws, playerId, false);
    }
  }

  /* ------------------------- 房间事件 ------------------------- */

  _handleRoomList(ws) {
    this._send(ws, { type: 'room:list', rooms: this.roomManager.getAllRooms() });
  }

  _handleRoomJoin(ws, playerId, msg) {
    const roomId = Number(msg.roomId);
    const player = {
      id: playerId,
      name: ws.playerName || '玩家',
      ready: false,
      seatIndex: -1,
    };
    const result = this.roomManager.joinRoom(roomId, player);
    if (!result.success) {
      return this._send(ws, { type: 'room:join:failed', roomId, message: result.message });
    }
    this._send(ws, {
      type: 'room:joined',
      roomId,
      seat: result.seat,
      room: this.roomManager.publicRoom(result.room),
    });
    this._roomBroadcast(result.room, {
      type: 'room:player:joined',
      roomId,
      seat: result.seat,
      name: player.name,
    });
    this._roomBroadcast(result.room, {
      type: 'room:update',
      room: this.roomManager.publicRoom(result.room),
    });
  }

  /**
   * 离开房间（主动或断线）
   * @param {boolean} explicit 是否为主动 room:leave
   */
  _handleRoomLeave(ws, playerId, explicit) {
    const room = this.roomManager.getRoomOfPlayer(playerId);
    if (!room) {
      if (explicit) this._send(ws, { type: 'room:left', success: false, message: '不在任何房间' });
      return;
    }
    const player = room.players.find((p) => p.id === playerId);
    const seat = player ? player.seatIndex : -1;
    const name = player ? player.name : '';
    const wasPlaying = room.status === 'playing';

    this.roomManager.leaveRoom(playerId);

    if (explicit) this._send(ws, { type: 'room:left', roomId: room.id, success: true });
    if (wasPlaying) {
      // 游戏因玩家离开而中止
      this._roomBroadcast(room, { type: 'game:player:disconnect', roomId: room.id, seat, name });
    }
    this._roomBroadcast(room, { type: 'room:player:left', roomId: room.id, seat, name });
    this._roomBroadcast(room, {
      type: 'room:update',
      room: this.roomManager.publicRoom(room),
    });
  }

  _handleRoomReady(ws, playerId) {
    const room = this.roomManager.getRoomOfPlayer(playerId);
    if (!room) return this._send(ws, { type: 'error', message: '不在房间中' });
    const result = this.roomManager.toggleReady(room.id, playerId);
    if (!result) return this._send(ws, { type: 'error', message: '无法切换准备状态' });

    this._roomBroadcast(room, {
      type: 'room:player:ready',
      roomId: room.id,
      seat: result.player.seatIndex,
      ready: result.ready,
    });
    this._roomBroadcast(room, {
      type: 'room:update',
      room: this.roomManager.publicRoom(room),
    });

    if (this.roomManager.checkAndStartGame(room.id)) {
      this._startGame(room);
    }
  }

  /* ------------------------- 对局流程 ------------------------- */

  /** 3 人全准备 → 开始对局：确定庄家，进入飘分阶段 */
  _startGame(room) {
    const dealerSeat = nextDealer(room);
    const session = new GameSession(room, dealerSeat);
    room.game = session;

    this._roomBroadcast(room, {
      type: 'room:game:start',
      roomId: room.id,
      dealerSeat,
      players: room.players.map((p) => ({ seat: p.seatIndex, name: p.name })),
      room: this.roomManager.publicRoom(room),
    });

    // 飘分超时：未上报者按飘 0 处理
    session.piaoTimer = setTimeout(() => {
      if (room.game !== session || session.phase !== 'piao') return;
      for (const p of room.players) {
        if (!(p.seatIndex in session.piao)) session.piao[p.seatIndex] = 0;
      }
      this._startDeal(room);
    }, PIAO_TIMEOUT_MS);
  }

  _handleGamePiao(ws, playerId, msg) {
    const room = this.roomManager.getRoomOfPlayer(playerId);
    const session = room ? room.game : null;
    if (!room || !session || session.phase !== 'piao') {
      return this._send(ws, { type: 'error', message: '当前不在飘分阶段' });
    }
    const player = room.players.find((p) => p.id === playerId);
    if (player.seatIndex in session.piao) return; // 已上报，忽略

    const all = session.setPiao(player.seatIndex, msg.piao);
    this._roomBroadcast(room, {
      type: 'game:piao:update',
      roomId: room.id,
      seat: player.seatIndex,
      piao: session.piao[player.seatIndex],
    });
    if (all) this._startDeal(room);
  }

  /** 飘分收齐 → 发牌 */
  _startDeal(room) {
    const session = room.game;
    if (!session || session.phase !== 'piao') return;
    if (session.piaoTimer) {
      clearTimeout(session.piaoTimer);
      session.piaoTimer = null;
    }
    const { hands, remaining } = session.startDeal();

    this._roomBroadcast(room, {
      type: 'game:started',
      roomId: room.id,
      dealerSeat: session.dealerSeat,
      remaining,
      piao: session.piao,
    });
    for (const p of room.players) {
      this._sendTo(p.id, {
        type: 'game:deal',
        roomId: room.id,
        yourSeat: p.seatIndex,
        dealerSeat: session.dealerSeat,
        hand: hands[p.seatIndex],
        piao: session.piao,
        remaining,
      });
    }
  }

  /** 客户端动作：出牌 / 自摸胡 */
  _handleGameAction(ws, playerId, msg) {
    const room = this.roomManager.getRoomOfPlayer(playerId);
    const session = room ? room.game : null;
    if (!room || !session) return this._send(ws, { type: 'error', message: '当前无对局' });
    const player = room.players.find((p) => p.id === playerId);
    const seat = player.seatIndex;

    switch (msg.action) {
      case 'discard': {
        if (session.phase !== 'playing' || session.awaitingResponses) {
          return this._send(ws, { type: 'error', message: '当前不能出牌' });
        }
        if (session.currentSeat !== seat) {
          return this._send(ws, { type: 'error', message: '还没轮到你出牌' });
        }
        if (typeof msg.card !== 'string' || !msg.card) {
          return this._send(ws, { type: 'error', message: '出牌数据错误' });
        }
        session.recordDiscard(seat, msg.card);
        this._roomBroadcast(room, {
          type: 'game:action:discard',
          roomId: room.id,
          seat,
          card: msg.card,
        });
        // 响应超时：窗口内未响应者视为过牌
        session.responseTimer = setTimeout(() => {
          if (room.game !== session || !session.awaitingResponses) return;
          for (const p of room.players) {
            if (p.seatIndex === session.lastDiscard.seat) continue;
            if (!session.responses.has(p.seatIndex)) {
              session.responses.set(p.seatIndex, { action: 'pass', meldCards: null, ts: Date.now() });
            }
          }
          this._resolveResponses(room);
        }, RESPONSE_TIMEOUT_MS);
        return;
      }
      case 'zhao-self': {
        // 招自己手牌上的 4 张同字牌（摸牌后 20 张时），招完服务器补摸一张
        if (session.phase !== 'playing' || session.awaitingResponses) {
          return this._send(ws, { type: 'error', message: '当前不能招' });
        }
        if (session.currentSeat !== seat) {
          return this._send(ws, { type: 'error', message: '还没轮到你操作' });
        }
        if (typeof msg.character !== 'string' || !msg.character) {
          return this._send(ws, { type: 'error', message: '招字数据错误' });
        }
        this._roomBroadcast(room, {
          type: 'game:action:result',
          roomId: room.id,
          result: 'zhao-self',
          seat,
          character: msg.character,
        });
        // 招后补摸一张（牌堆空则流局）
        this._serverDraw(room, seat);
        return;
      }
      case 'hu': {
        // 自摸胡（含摸牌后、招补摸后的自摸）：服务器不判定，广播后结束
        if (session.phase !== 'playing') {
          return this._send(ws, { type: 'error', message: '当前无对局' });
        }
        this._roomBroadcast(room, {
          type: 'game:hu',
          roomId: room.id,
          seat,
          card: msg.card || null,
          fromSeat: null,
          zimo: true,
          winnerData: msg.winnerData || null,
        });
        this._endGame(room, { type: 'hu', winnerSeat: seat, dealerSeat: session.dealerSeat });
        return;
      }
      default:
        return this._send(ws, { type: 'error', message: `未知动作: ${msg.action}` });
    }
  }

  /** 其他玩家对最后一张弃牌的响应（胡/招/碰/吃/过） */
  _handleActionRequest(ws, playerId, msg) {
    const room = this.roomManager.getRoomOfPlayer(playerId);
    const session = room ? room.game : null;
    if (!room || !session || session.phase !== 'playing') return;
    if (!session.awaitingResponses || !session.lastDiscard) return;

    const player = room.players.find((p) => p.id === playerId);
    const seat = player.seatIndex;
    if (seat === session.lastDiscard.seat) return; // 出牌者不能响应

    const valid = ['hu', 'zhao', 'peng', 'chi', 'pass'];
    if (!valid.includes(msg.action)) {
      return this._send(ws, { type: 'error', message: '非法响应动作' });
    }
    session.recordResponse(seat, msg.action, msg.meldCards, msg.winnerData);
    // 胡牌最高优先级，立即裁决，不等其他响应者
    if (msg.action === 'hu' || session.hasAllResponses()) {
      if (session.responseTimer) {
        clearTimeout(session.responseTimer);
        session.responseTimer = null;
      }
      this._resolveResponses(room);
    }
  }

  /** 全部响应收齐后裁决 */
  _resolveResponses(room) {
    const session = room.game;
    session.awaitingResponses = false;
    const best = session.resolveResponses();

    if (!best) {
      // 全过：下家逆时针顺序摸牌
      const nextSeat = (session.lastDiscard.seat + 1) % 3;
      this._roomBroadcast(room, {
        type: 'game:action:result',
        roomId: room.id,
        result: 'pass',
        nextSeat,
      });
      this._serverDraw(room, nextSeat);
      return;
    }

    if (best.action === 'hu') {
      this._roomBroadcast(room, {
        type: 'game:hu',
        roomId: room.id,
        seat: best.seat,
        card: session.lastDiscard.card,
        fromSeat: session.lastDiscard.seat,
        zimo: false,
        winnerData: best.winnerData || null,
      });
      this._endGame(room, {
        type: 'hu',
        winnerSeat: best.seat,
        dealerSeat: session.dealerSeat,
      });
      return;
    }

    // 碰 / 吃 / 招：胜出者获得牌权（客户端本地执行组合逻辑）
    session.currentSeat = best.seat;
    session.responses.clear();
    this._roomBroadcast(room, {
      type: 'game:action:result',
      roomId: room.id,
      result: 'claim',
      action: best.action,
      seat: best.seat,
      card: session.lastDiscard.card,
      meldCards: best.meldCards || undefined,
    });
    if (best.action === 'zhao') {
      // 招后补摸一张（招牌数规则：招完 19+1-4+3=19，补摸变 20）
      this._serverDraw(room, best.seat);
    }
    // 碰/吃 胜者直接出牌，不摸牌
  }

  /** 服务器摸牌：广播摸牌事件 + 私发具体牌面；牌堆空则流局 */
  _serverDraw(room, seat) {
    const session = room.game;
    const card = session.drawFor(seat);
    if (card === null) {
      this._roomBroadcast(room, { type: 'game:liuju', roomId: room.id });
      this._endGame(room, { type: 'liuju', dealerSeat: session.dealerSeat });
      return;
    }
    this._roomBroadcast(room, {
      type: 'game:draw',
      roomId: room.id,
      seat,
      remaining: session.remaining,
    });
    const player = room.players.find((p) => p.seatIndex === seat);
    if (player) {
      this._sendTo(player.id, {
        type: 'game:draw:self',
        roomId: room.id,
        card,
        remaining: session.remaining,
      });
    }
  }

  /** 对局结束：记录结果（供庄家流转）、重置房间为等待 */
  _endGame(room, result) {
    const session = room.game;
    if (session) session.end();
    room.lastGame = {
      type: result.type,
      winnerSeat: result.winnerSeat == null ? null : result.winnerSeat,
      dealerSeat: result.dealerSeat,
    };
    this.roomManager.resetRoomToWaiting(room);
    this._roomBroadcast(room, {
      type: 'room:update',
      room: this.roomManager.publicRoom(room),
    });
  }

  /* ------------------------- 发送辅助 ------------------------- */

  _send(ws, msg) {
    if (ws.readyState === 1) ws.send(JSON.stringify(msg));
  }

  _sendTo(playerId, msg) {
    const ws = this.sockets.get(playerId);
    if (ws) this._send(ws, msg);
  }

  /** 房间内广播（发给当前房间内所有在线玩家） */
  _roomBroadcast(room, msg) {
    const data = JSON.stringify(msg);
    for (const p of room.players) {
      const ws = this.sockets.get(p.id);
      if (ws) ws.send(data);
    }
  }
}

module.exports = { RoomSocketServer, RESPONSE_TIMEOUT_MS, PIAO_TIMEOUT_MS };
