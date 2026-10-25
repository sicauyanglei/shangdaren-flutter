/**
 * 房间管理 + 发牌器 + 游戏会话 单元测试（node test/room_test.js）
 */
const assert = require('assert');
const { RoomManager, TOTAL_ROOMS } = require('../src/room/roomManager');
const { GameSession, nextDealer, ACTION_PRIORITY } = require('../src/game/gameManager');
const { createDeck, deal, draw, CARD_CHARS } = require('../src/game/dealer');

/* ---------------- RoomManager ---------------- */

const rm = new RoomManager();
assert.strictEqual(rm.rooms.size, TOTAL_ROOMS, '应初始化 100 张牌桌');

// 加入分配最小座位
const r1 = rm.joinRoom(1, { id: 'p1', name: 'A' });
assert.ok(r1.success, '第一次加入应成功');
assert.strictEqual(r1.seat, 0);
assert.strictEqual(rm.joinRoom(1, { id: 'p2', name: 'B' }).seat, 1);
assert.strictEqual(rm.joinRoom(1, { id: 'p3', name: 'C' }).seat, 2);

// 满 3 人拒绝
assert.ok(!rm.joinRoom(1, { id: 'p4', name: 'D' }).success, '满员应拒绝');
// 重复加入 / 跨房加入拒绝
assert.ok(!rm.joinRoom(1, { id: 'p1' }).success, '已在房内应拒绝');
assert.ok(!rm.joinRoom(2, { id: 'p1' }).success, '已在其他房间应拒绝');
// 离开后可重新加入
assert.ok(rm.leaveRoom('p3'));
assert.strictEqual(rm.getRoom(1).players.length, 2);
assert.ok(rm.joinRoom(1, { id: 'p3', name: 'C' }).success, '离开后重新加入应成功');

// 准备 + 自动开始
assert.ok(rm.toggleReady(1, 'p1').ready === true);
assert.ok(rm.toggleReady(1, 'p2').ready === true);
assert.ok(!rm.checkAndStartGame(1), '2 人准备不应开始');
assert.ok(rm.toggleReady(1, 'p3').ready === true);
assert.ok(rm.checkAndStartGame(1), '3 人全准备应开始');
assert.strictEqual(rm.getRoom(1).status, 'playing');

// 游戏中拒绝加入
assert.ok(!rm.joinRoom(1, { id: 'p4' }).success, '游戏中应拒绝加入');
// 游戏中离开 → 房间重置等待、清除准备
rm.leaveRoom('p2');
assert.strictEqual(rm.getRoom(1).status, 'waiting', '游戏中离开应重置房间');
assert.strictEqual(rm.getRoom(1).players.length, 2);
assert.strictEqual(rm.getRoom(1).players[0].ready, false, '重置应清除准备状态');
assert.strictEqual(rm.getRoomOfPlayer('p2'), null, '离开后应解除映射');

/* ---------------- 发牌器 ---------------- */

const deck = createDeck();
assert.strictEqual(deck.length, 96, '牌堆应为 96 张');
assert.strictEqual(new Set(deck).size, 24, '应含 24 种字');

const { hands, remaining } = deal(deck, 0);
assert.strictEqual(hands[0].length, 20, '庄家 20 张');
assert.strictEqual(hands[1].length, 19, '闲家 19 张');
assert.strictEqual(hands[2].length, 19, '闲家 19 张');
assert.strictEqual(remaining, 38, '发牌后剩 38 张');

// 摸完即流局
for (let i = 0; i < 38; i++) assert.ok(draw(deck).card, '前 38 次摸牌应有牌');
assert.strictEqual(draw(deck), null, '牌堆空应返回 null');

/* ---------------- GameSession 响应仲裁 ---------------- */

const mockRoom = {
  players: [
    { id: 'p1', seatIndex: 0 },
    { id: 'p2', seatIndex: 1 },
    { id: 'p3', seatIndex: 2 },
  ],
};
const session = new GameSession(mockRoom, 0);
assert.strictEqual(session.phase, 'piao');

// 飘分收齐
assert.ok(!session.setPiao(0, 1));
assert.ok(!session.setPiao(1, 2));
assert.ok(session.setPiao(2, 0), '3 家飘分应收齐');

// 发牌
const dealRes = session.startDeal();
assert.strictEqual(dealRes.hands[0].length, 20);
assert.strictEqual(session.remaining, 38);
assert.strictEqual(session.phase, 'playing');
assert.strictEqual(session.currentSeat, 0, '庄家先出牌');

// 出牌 + 响应窗口
session.recordDiscard(0, '丘');
assert.ok(session.awaitingResponses);
assert.strictEqual(session.hasAllResponses(), false);
session.recordResponse(1, 'chi', ['丘', '乙', '己']);
session.recordResponse(2, 'pass');
assert.ok(session.hasAllResponses(), '两非出牌者响应后应收齐');
let best = session.resolveResponses();
assert.strictEqual(best.seat, 1, '唯一吃牌者应胜出');

// hu > peng
session.recordDiscard(0, '乙');
session.recordResponse(1, 'peng');
session.recordResponse(2, 'hu');
best = session.resolveResponses();
assert.strictEqual(best.action, 'hu');
assert.strictEqual(best.seat, 2);

// zhao > peng（且后到仍胜）
session.recordDiscard(0, '己');
session.recordResponse(2, 'peng');
session.recordResponse(1, 'zhao');
best = session.resolveResponses();
assert.strictEqual(best.action, 'zhao');
assert.strictEqual(best.seat, 1);

// 同优先级先到先得
session.recordDiscard(0, '丘');
session.recordResponse(2, 'peng');
session.recordResponse(1, 'peng');
best = session.resolveResponses();
assert.strictEqual(best.seat, 2, '同级应先到先得');

// 防重复响应
session.recordDiscard(0, '乙');
session.recordResponse(1, 'pass');
assert.ok(!session.recordResponse(1, 'hu'), '重复响应应被忽略');
session.recordResponse(2, 'pass');
assert.strictEqual(session.resolveResponses(), null, '全过应返回 null');

// 摸牌 + 流局
const card = session.drawFor(1);
assert.ok(typeof card === 'string' && CARD_CHARS.includes(card));
assert.strictEqual(session.currentSeat, 1);
session.end();
assert.strictEqual(session.phase, 'ended');

/* ---------------- 庄家流转 ---------------- */

const room2 = { lastGame: null };
assert.ok([0, 1, 2].includes(nextDealer(room2)), '首局应随机庄家');
room2.lastGame = { type: 'liuju', dealerSeat: 1, winnerSeat: null };
assert.strictEqual(nextDealer(room2), 1, '流局庄家不变');
room2.lastGame = { type: 'hu', winnerSeat: 1, dealerSeat: 1 };
assert.strictEqual(nextDealer(room2), 1, '赢家坐庄应继续');
room2.lastGame = { type: 'hu', winnerSeat: 2, dealerSeat: 1 };
assert.strictEqual(nextDealer(room2), 2, '赢家是庄家下一位时应轮转到赢家');
room2.lastGame = { type: 'hu', winnerSeat: 0, dealerSeat: 1 };
assert.strictEqual(nextDealer(room2), 2, '赢家非庄家邻位时应轮转下一位');

console.log('全部测试通过');
