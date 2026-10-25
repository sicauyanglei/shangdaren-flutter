/**
 * 游戏会话管理 —— 服务器权威：牌堆、发牌、摸牌分发、响应仲裁
 * 服务器不参与任何游戏规则判定（胡/碰/吃/招合法性由各客户端本地判定）
 */
const { createDeck, deal, draw } = require('./dealer');

/** 响应优先级：胡 > 招 > 碰 > 吃（依据 game-base.md 操作优先级） */
const ACTION_PRIORITY = { hu: 4, zhao: 3, peng: 2, chi: 1, pass: 0 };

class GameSession {
  /**
   * @param {import('../room/roomManager').Room} room
   * @param {number} dealerSeat 庄家座位 (0-2)
   */
  constructor(room, dealerSeat) {
    this.room = room;
    this.deck = createDeck();
    this.dealerSeat = dealerSeat;
    this.currentSeat = dealerSeat;
    this.phase = 'piao'; // piao | playing | ended
    this.piao = {}; // seat -> 飘分值
    this.hands = null; // seat -> string[]（发牌结果）
    this.remaining = 0; // 牌堆剩余
    this.lastDiscard = null; // { seat, card }
    this.awaitingResponses = false; // 是否处于出牌响应窗口
    this.responses = new Map(); // seat -> { action, meldCards, ts }
    this.responseTimer = null;
    this.piaoTimer = null;
  }

  /** 记录飘分；返回是否 3 家全部收齐 */
  setPiao(seat, value) {
    this.piao[seat] = Number(value) || 0;
    return Object.keys(this.piao).length >= 3;
  }

  /** 发牌（飘分收齐后调用）：庄家 20 张、闲家 19 张 */
  startDeal() {
    const { hands, remaining } = deal(this.deck, this.dealerSeat);
    this.hands = hands;
    this.remaining = remaining;
    this.phase = 'playing';
    this.currentSeat = this.dealerSeat; // 庄家直接出牌，不摸牌
    return { hands, remaining };
  }

  /** 服务器摸牌：牌堆空返回 null（流局） */
  drawFor(seat) {
    const res = draw(this.deck);
    if (!res) return null;
    this.remaining = res.remaining;
    this.currentSeat = seat;
    return res.card;
  }

  /** 记录出牌，开启响应窗口 */
  recordDiscard(seat, card) {
    this.lastDiscard = { seat, card };
    this.currentSeat = seat;
    this.responses.clear();
    this.awaitingResponses = true;
  }

  /** 记录响应（防重复）；返回是否首次记录 */
  recordResponse(seat, action, meldCards, winnerData) {
    if (this.responses.has(seat)) return false;
    this.responses.set(seat, {
      action,
      meldCards: Array.isArray(meldCards) ? meldCards : null,
      winnerData: winnerData || null,
      ts: Date.now(),
    });
    return true;
  }

  /** 除出牌者外是否全部响应完毕 */
  hasAllResponses() {
    const responders = this.room.players.filter(
      (p) => p.seatIndex !== this.lastDiscard.seat
    );
    return responders.every((p) => this.responses.has(p.seatIndex));
  }

  /**
   * 裁决响应：hu > zhao > peng > chi，同优先级先到先得
   * @returns {{ seat:number, action:string, meldCards:string[]|null, winnerData?:object|null } | null} null = 全过
   */
  resolveResponses() {
    let best = null;
    for (const [seat, resp] of this.responses) {
      if (resp.action === 'pass') continue;
      if (!best || ACTION_PRIORITY[resp.action] > ACTION_PRIORITY[best.action]) {
        best = { seat, action: resp.action, meldCards: resp.meldCards, winnerData: resp.winnerData };
      }
    }
    return best;
  }

  /** 对局结束：清理计时器 */
  end() {
    this.phase = 'ended';
    if (this.responseTimer) {
      clearTimeout(this.responseTimer);
      this.responseTimer = null;
    }
    if (this.piaoTimer) {
      clearTimeout(this.piaoTimer);
      this.piaoTimer = null;
    }
  }
}

/**
 * 依据庄家流转规则计算下一局庄家（dealer-rotation.md）：
 * - 无上一局：随机
 * - 流局：庄家不变
 * - 赢家是庄家：庄家不变（继续坐庄）
 * - 赢家不是庄家：逆时针轮转到下一位
 * @param {{ lastGame?: { type:string, winnerSeat:number|null, dealerSeat:number } }} room
 */
function nextDealer(room) {
  const last = room.lastGame;
  if (!last) return Math.floor(Math.random() * 3);
  if (last.type === 'liuju') return last.dealerSeat;
  if (last.winnerSeat === last.dealerSeat) return last.dealerSeat;
  return (last.dealerSeat + 1) % 3;
}

module.exports = { GameSession, nextDealer, ACTION_PRIORITY };
