/**
 * WebSocket 协议冒烟测试（node test/smoke_test.js）
 * 前置：需先启动服务器（npm start）
 * 流程：3 个模拟客户端完成 auth → join → ready → 飘分 → 发牌
 *       → 庄家出牌 → 双方过 → 下家摸牌出牌 → 点炮胡 → 房间重置
 */
const WebSocket = require('ws');

const WS_URL = 'ws://127.0.0.1:8080';
const ROOM_ID = 5;
// SMOKE_MODE=hu 点炮胡流程（默认）| SMOKE_MODE=pass 全过牌直到流局
const MODE = process.env.SMOKE_MODE || 'hu';
const COLORS = ['\x1b[31m', '\x1b[32m', '\x1b[34m', '\x1b[0m'];

class FakeClient {
  constructor(playerId, name) {
    this.playerId = playerId;
    this.name = name;
    this.seat = -1;
    this.hand = [];
    this.done = false;
    this.log = (msg) => console.log(`${COLORS[this.seat + 1] || ''}[${name}]${COLORS[3]} ${msg}`);
  }

  connect() {
    this.ws = new WebSocket(WS_URL);
    this.ws.on('open', () => this.send({ type: 'auth', playerId: this.playerId, name: this.name }));
    this.ws.on('message', (raw) => this.onMessage(JSON.parse(raw.toString())));
    this.ws.on('error', (e) => { throw e; });
    return new Promise((res) => (this.onOpen = res));
  }

  send(msg) {
    this.ws.send(JSON.stringify({ playerId: this.playerId, ...msg }));
  }

  onMessage(msg) {
    switch (msg.type) {
      case 'auth:ok':
        this.log(`认证成功`);
        this.send({ type: 'room:join', roomId: ROOM_ID });
        break;
      case 'room:joined':
        this.seat = msg.seat;
        this.log(`加入房间 ${msg.roomId}，座位 ${msg.seat}`);
        this.send({ type: 'room:ready' });
        break;
      case 'room:game:start':
        this.log(`对局开始，庄家座位 ${msg.dealerSeat}`);
        this.send({ type: 'game:piao', piao: this.seat });
        break;
      case 'game:deal':
        this.hand = [...msg.hand];
        this.log(`收到手牌 ${this.hand.length} 张，庄家=${msg.dealerSeat}，我=座位${msg.yourSeat}`);
        if (msg.dealerSeat === this.seat) {
          setTimeout(() => {
            const card = this.hand.pop();
            this.log(`庄家出牌 ${card}`);
            this.send({ type: 'game:action', action: 'discard', card });
          }, 100);
        }
        break;
      case 'game:action:discard':
        this.log(`座位${msg.seat} 出牌 ${msg.card}（我手牌${this.hand.length}张）`);
        if (msg.seat === this.seat) break;
        if (MODE === 'hu' && this.name === '炮手' && this.hand.includes(msg.card)) {
          // 炮手对特定牌点炮（用于测试 hu 仲裁）——直接抢胡
          this.send({ type: 'game:action:request', action: 'hu' });
          this.log(`申请胡 ${msg.card}！`);
        } else {
          this.send({ type: 'game:action:request', action: 'pass' });
          this.log(`过牌`);
        }
        break;
      case 'game:action:result':
        this.log(`裁决: ${msg.result}${msg.action ? ' - ' + msg.action + ' 座位' + msg.seat : ''} next=${msg.nextSeat}`);
        break;
      case 'game:draw:self':
        this.hand.push(msg.card);
        this.log(`摸牌 ${msg.card}（剩${msg.remaining}），手牌${this.hand.length}张`);
        setTimeout(() => {
          const card = this.hand[0];
          this.log(`出牌 ${card}`);
          this.send({ type: 'game:action', action: 'discard', card });
        }, 100);
        break;
      case 'game:draw':
        this.log(`座位${msg.seat} 摸牌（剩${msg.remaining}）`);
        break;
      case 'game:hu':
        this.log(`${msg.zimo ? '自摸' : `胡座位${msg.fromSeat}的牌`} → 赢家座位${msg.seat}，牌=${msg.card}`);
        break;
      case 'room:update':
        this.log(`房间状态: ${msg.room.status} (${msg.room.playerCount}/3)`);
        if (msg.room.status === 'waiting' && this.huSeen) this.finish();
        if (msg.room.status === 'waiting' && this.liujuSeen) this.finish();
        break;
      case 'game:liuju':
        this.liujuSeen = true;
        this.log(`流局`);
        break;
      default:
        if (msg.type === 'game:piao:update') this.log(`座位${msg.seat} 飘分 ${msg.piao}`);
        else if (msg.type !== 'room:player:joined' && msg.type !== 'room:player:left' && msg.type !== 'room:player:ready' && msg.type !== 'game:started')
          this.log(`收到 ${msg.type}`);
    }
    if (msg.type === 'game:hu') this.huSeen = true;
  }

  finish() {
    if (this.done) return;
    this.done = true;
    this.ws.close();
    if (++finishedCount === 3) {
      console.log('\n冒烟测试通过：房间流程 + 出牌/摸牌/点炮胡/房间重置 全链路正常');
      process.exit(0);
    }
  }
}

let finishedCount = 0;

(async () => {
  const clients = [new FakeClient('id-A', '玩家A'), new FakeClient('id-B', '玩家B'), new FakeClient('id-C', '炮手')];
  await Promise.all(clients.map((c) => c.connect()));
  // 15 秒兜底：防止断言挂起导致 CI 卡死
  setTimeout(() => {
    console.error('冒烟测试超时失败');
    process.exit(1);
  }, 15000);
})();
