/**
 * 牌桌管理器 —— 100 张牌桌、每桌 3 人、准备状态、自动开始
 * （依据 multiplayer-room skill 规范实现）
 */

const TOTAL_ROOMS = 100;

/** 房间状态：waiting 等待中 | ready 已满/已准备 | playing 游戏中 */
class RoomManager {
  constructor() {
    /** @type {Map<number, any>} roomId -> Room */
    this.rooms = new Map();
    /** @type {Map<string, number>} playerId -> roomId */
    this.playerRoomMap = new Map();

    for (let i = 1; i <= TOTAL_ROOMS; i++) {
      this.rooms.set(i, {
        id: i,
        players: [], // [{ id, name, ready, seatIndex, ws }]
        status: 'waiting',
        createdAt: Date.now(),
        game: null, // 游戏会话状态（playing 时存在）
      });
    }
  }

  /** 获取房间 */
  getRoom(roomId) {
    return this.rooms.get(roomId);
  }

  /** 公开信息（不含 ws 与游戏内部状态） */
  publicRoom(room) {
    return {
      id: room.id,
      status: room.status,
      playerCount: room.players.length,
      players: room.players.map((p) => ({
        seat: p.seatIndex,
        name: p.name,
        ready: p.ready,
      })),
    };
  }

  /** 所有房间公开列表 */
  getAllRooms() {
    return [...this.rooms.values()].map((r) => this.publicRoom(r));
  }

  /** 玩家所在房间 */
  getRoomOfPlayer(playerId) {
    const roomId = this.playerRoomMap.get(playerId);
    if (roomId == null) return null;
    const room = this.rooms.get(roomId);
    if (!room) return null;
    return room;
  }

  /**
   * 加入牌桌
   * @returns {{ success: boolean, message?: string, room?: any, seat?: number }}
   */
  joinRoom(roomId, player) {
    const room = this.rooms.get(roomId);
    if (!room) return { success: false, message: '房间不存在' };
    if (this.playerRoomMap.has(player.id)) {
      const cur = this.playerRoomMap.get(player.id);
      if (cur === roomId) return { success: false, message: '已在该房间中' };
      return { success: false, message: '已在其他房间中' };
    }
    if (room.status === 'playing') return { success: false, message: '游戏进行中，无法加入' };
    if (room.players.length >= 3) return { success: false, message: '房间已满(3人)' };

    // 分配最小可用座位
    const used = new Set(room.players.map((p) => p.seatIndex));
    let seat = 0;
    while (used.has(seat)) seat++;
    player.seatIndex = seat;
    player.ready = false;
    room.players.push(player);
    this.playerRoomMap.set(player.id, roomId);
    return { success: true, room, seat };
  }

  /**
   * 离开牌桌（等待中可离开；游戏中离开将中止对局）
   * @returns {{ room?: any, player?: any, wasPlaying?: boolean } | null}
   */
  leaveRoom(playerId) {
    const room = this.getRoomOfPlayer(playerId);
    if (!room) return null;
    const player = room.players.find((p) => p.id === playerId);
    const wasPlaying = room.status === 'playing';
    room.players = room.players.filter((p) => p.id !== playerId);
    this.playerRoomMap.delete(playerId);

    if (wasPlaying) {
      // 中止对局，重置为等待状态
      this.resetRoomToWaiting(room);
    } else if (room.players.length === 0) {
      room.status = 'waiting';
    }
    return { room, player, wasPlaying };
  }

  /** 重置房间为等待状态（保留仍在场的玩家，清除准备） */
  resetRoomToWaiting(room) {
    room.status = 'waiting';
    room.game = null;
    room.players.forEach((p) => {
      p.ready = false;
    });
  }

  /**
   * 切换准备状态
   * @returns {{ room: any, player: any, ready: boolean } | null}
   */
  toggleReady(roomId, playerId) {
    const room = this.rooms.get(roomId);
    if (!room) return null;
    const player = room.players.find((p) => p.id === playerId);
    if (!player) return null;
    if (room.status === 'playing') return null;
    player.ready = !player.ready;
    return { room, player, ready: player.ready };
  }

  /**
   * 自动开始游戏检测：正好 3 人且全部准备
   * @returns {boolean} 是否成功开始
   */
  checkAndStartGame(roomId) {
    const room = this.rooms.get(roomId);
    if (!room) return false;
    if (room.players.length !== 3) return false;
    if (!room.players.every((p) => p.ready)) return false;
    if (room.status === 'playing') return false;
    room.status = 'playing';
    return true;
  }

  /** 通过连接找玩家 */
  findPlayer(playerId) {
    const room = this.getRoomOfPlayer(playerId);
    if (!room) return null;
    return room.players.find((p) => p.id === playerId) || null;
  }
}

module.exports = { RoomManager, TOTAL_ROOMS };
