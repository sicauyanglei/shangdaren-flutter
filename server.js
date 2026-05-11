const WebSocket = require('ws');
const http = require('http');
const fs = require('fs');
const path = require('path');

const HTTP_PORT = 8081;
const WS_PORT = 8080;

const recentLogs = [];
const MAX_LOGS = 100;

function addLog(type, msg) {
  const entry = { time: new Date().toISOString(), type, msg: typeof msg === 'string' ? msg : JSON.stringify(msg) };
  recentLogs.push(entry);
  if (recentLogs.length > MAX_LOGS) recentLogs.shift();
  console.log(`[${type}]`, entry.msg);
}

// ==================== 牌的常量定义 ====================
const CARD_SENTENCES = {
  '上': 1, '大': 1, '人': 1,
  '丘': 2, '乙': 2, '己': 2,
  '化': 3, '三': 3, '千': 3,
  '七': 4, '十': 4, '土': 4,
  '尔': 5, '小': 5, '生': 5,
  '八': 6, '九': 6, '子': 6,
  '佳': 7, '作': 7, '亡': 7,
  '福': 8, '禄': 8, '寿': 8
};

const CARD_POSITIONS = {
  '上': 0, '大': 1, '人': 2,
  '丘': 0, '乙': 1, '己': 2,
  '化': 0, '三': 1, '千': 2,
  '七': 0, '十': 1, '土': 2,
  '尔': 0, '小': 1, '生': 2,
  '八': 0, '九': 1, '子': 2,
  '佳': 0, '作': 1, '亡': 2,
  '福': 0, '禄': 1, '寿': 2
};

const SPECIAL_CARDS = ['上', '福'];
const TURN_TIMEOUT_MS = 30000;
const PIAO_TIMEOUT_MS = 10000;

// ==================== 全局存储 ====================
const rooms = new Map();
const sessions = new Map();
const smsCodes = new Map();
const turnTimers = new Map();
const piaoTimers = new Map();

// ==================== 工具函数 ====================
function generateToken() {
  return 'token_' + Date.now().toString(36) + '_' + Math.random().toString(36).substr(2, 16);
}

function createDeck() {
  const deck = [];
  const chars = Object.keys(CARD_SENTENCES);
  for (const char of chars) {
    for (let i = 0; i < 4; i++) {
      deck.push({
        id: `${char}-${deck.length}`,
        character: char,
        sentence: CARD_SENTENCES[char],
        position: CARD_POSITIONS[char],
        isSpecial: SPECIAL_CARDS.includes(char)
      });
    }
  }
  return deck;
}

function shuffleDeck(deck) {
  for (let i = deck.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    [deck[i], deck[j]] = [deck[j], deck[i]];
  }
  return deck;
}

// ==================== 房间管理 ====================
function createRoom(id) {
  return {
    id,
    players: [],
    status: 'waiting',
    createdAt: Date.now()
  };
}

function getRoomInfo(roomId) {
  const room = rooms.get(roomId);
  if (!room) return null;
  return {
    id: room.id,
    players: room.players.map(p => ({
      id: p.id,
      name: p.name,
      ready: p.ready,
      seatIndex: p.seatIndex
    })),
    status: room.status,
    playerCount: room.players.length
  };
}

function getAllRoomsInfo() {
  const info = [];
  for (let i = 1; i <= 100; i++) {
    const room = rooms.get(i);
    if (room) {
      info.push(getRoomInfo(i));
    } else {
      info.push({ id: i, players: [], status: 'waiting', playerCount: 0 });
    }
  }
  return info;
}

function joinRoom(roomId, player) {
  let room = rooms.get(roomId);
  if (!room) {
    room = createRoom(roomId);
    rooms.set(roomId, room);
  }
  if (room.status === 'playing') {
    return { success: false, message: '游戏已经开始' };
  }
  if (room.players.length >= 3) {
    return { success: false, message: '房间已满' };
  }
  const existing = room.players.find(p => p.id === player.id);
  if (existing) {
    return { success: true, message: '已在此房间', room: getRoomInfo(roomId) };
  }
  room.players.push({
    id: player.id,
    name: player.name,
    ready: false,
    seatIndex: room.players.length,
    ws: null,
    piao: null,
    hand: [],
    melds: [],
    discards: [],
    score: 0,
    isTing: false
  });
  return { success: true, message: '加入成功', room: getRoomInfo(roomId) };
}

function leaveRoom(roomId, playerId) {
  const room = rooms.get(roomId);
  if (!room) return { success: false, message: '房间不存在' };
  if (room.status === 'playing') return { success: false, message: '游戏已经开始' };
  const idx = room.players.findIndex(p => p.id === playerId);
  if (idx === -1) return { success: false, message: '不在此房间' };
  room.players.splice(idx, 1);
  room.players.forEach((p, i) => p.seatIndex = i);
  if (room.players.length === 0) {
    clearTurnTimer(roomId);
    clearPiaoTimer(roomId);
    rooms.delete(roomId);
  }
  return { success: true, message: '离开成功' };
}

function toggleReady(roomId, playerId) {
  const room = rooms.get(roomId);
  if (!room) return { success: false, message: '房间不存在', ready: false };
  if (room.status === 'playing') return { success: false, message: '游戏已经开始', ready: false };
  const player = room.players.find(p => p.id === playerId);
  if (!player) return { success: false, message: '不在此房间', ready: false };
  player.ready = !player.ready;
  return { success: true, ready: player.ready };
}

function checkAndStartGame(roomId) {
  const room = rooms.get(roomId);
  if (!room) return false;
  if (room.players.length !== 3) return false;
  if (!room.players.every(p => p.ready)) return false;
  return true;
}

// ==================== 游戏状态管理 ====================
function initGameState(room) {
  const deck = shuffleDeck(createDeck());
  const hands = [[], [], []];

  // 每人发13张牌
  for (let i = 0; i < 13; i++) {
    for (let j = 0; j < 3; j++) {
      hands[j].push(deck.pop());
    }
  }

  room.game = {
    status: 'piao', // piao -> dealing -> playing -> roundEnd
    deck: deck,
    players: room.players.map((p, i) => ({
      id: p.id,
      seatIndex: i,
      hand: hands[i],
      melds: [],
      discards: [],
      piao: null,
      isTing: false,
      score: p.score || 0
    })),
    dealerIndex: 0,
    currentPlayerIndex: 0,
    lastDiscardedCard: null,
    lastDiscardPlayerIndex: -1,
    roundNumber: 1,
    pendingAction: null,
    turnStartTime: null,
    piaoResults: [null, null, null],
    piaoCountdown: 3 // 还剩多少玩家需要飘
  };
}

function broadcastToRoom(room, msg) {
  if (!room) return;
  room.players.forEach(p => {
    if (p.ws && p.ws.readyState === WebSocket.OPEN) {
      p.ws.send(JSON.stringify(msg));
    }
  });
}

function sendToPlayer(playerId, msg) {
  for (const room of rooms.values()) {
    const player = room.players.find(p => p.id === playerId);
    if (player && player.ws && player.ws.readyState === WebSocket.OPEN) {
      player.ws.send(JSON.stringify(msg));
      return;
    }
  }
}

// ==================== 操作检查 ====================
function canPlayerChi(player, card) {
  if (player.melds.some(m => m.type === 'sequence')) return false;
  const sentenceCards = player.hand.filter(c => c.sentence === card.sentence);
  if (sentenceCards.length < 2) return false;
  const positions = new Set(sentenceCards.map(c => c.position));
  if (card.position === 0) return positions.has(1) && positions.has(2);
  if (card.position === 1) return positions.has(0) && positions.has(2);
  if (card.position === 2) return positions.has(0) && positions.has(1);
  return false;
}

function canPlayerPeng(player, card) {
  if (player.melds.some(m => m.type === 'triplet')) return false;
  const count = player.hand.filter(c => c.character === card.character).length;
  return count >= 2;
}

function canPlayerZhao(player, card) {
  if (player.melds.some(m => m.type === 'quartet')) return false;
  const count = player.hand.filter(c => c.character === card.character).length;
  return count >= 3;
}

function canPlayerHu(player, card) {
  const hand = card ? [...player.hand, card] : [...player.hand];
  // 简化检查：手牌数达到14（或者13+1）且有组合牌
  // 实际胡牌判断需要更复杂的算法，这里简化处理
  if (hand.length < 14) return false;
  return true;
}

function checkResponses(room, card, excludePlayerIndex) {
  const responses = [];
  const isNextPlayer = true; // 上家出牌，下家才能吃

  for (let i = 0; i < 3; i++) {
    if (i === excludePlayerIndex) continue;
    const player = room.game.players[i];
    const canHu = canPlayerHu(player, card);
    const canZhao = canPlayerZhao(player, card);
    const canPeng = canPlayerPeng(player, card);
    const canChi = isNextPlayer && canPlayerChi(player, card);

    responses.push({
      playerIndex: i,
      canHu,
      canZhao,
      canPeng,
      canChi
    });
  }

  return responses;
}

// ==================== 回合控制 ====================
function clearTurnTimer(roomId) {
  if (turnTimers.has(roomId)) {
    clearTimeout(turnTimers.get(roomId));
    turnTimers.delete(roomId);
  }
}

function clearPiaoTimer(roomId) {
  if (piaoTimers.has(roomId)) {
    clearTimeout(piaoTimers.get(roomId));
    piaoTimers.delete(roomId);
  }
}

function startTurn(room) {
  clearTurnTimer(room.id);
  room.game.status = 'playing';
  room.game.turnStartTime = Date.now();

  const currentPlayer = room.game.players[room.game.currentPlayerIndex];

  // 如果是AI玩家，自动出牌
  // 注意：这里需要判断是AI还是人类玩家
  // 由于服务器不知道客户端类型，我们让客户端自己决定
  // 客户端收到 game:turn 后，如果是AI则自动执行

  broadcastToRoom(room, {
    type: 'game:turn',
    playerIndex: room.game.currentPlayerIndex,
    deadline: Date.now() + TURN_TIMEOUT_MS,
    deckCount: room.game.deck.length
  });

  // 设置超时
  turnTimers.set(room.id, setTimeout(() => {
    handleTurnTimeout(room);
  }, TURN_TIMEOUT_MS));
}

function handleTurnTimeout(room) {
  // 超时默认过
  const currentPlayer = room.game.players[room.game.currentPlayerIndex];

  if (room.game.pendingAction) {
    // 有人在等待响应，视为放弃响应
    room.game.pendingAction = null;
  }

  // 如果是当前玩家超时，自动出一张牌
  // 简化处理：出一张手牌中的最后一张
  if (currentPlayer.hand.length > 0) {
    const cardToDiscard = currentPlayer.hand.pop();
    room.game.lastDiscardedCard = cardToDiscard;
    room.game.lastDiscardPlayerIndex = room.game.currentPlayerIndex;
    currentPlayer.discards.push(cardToDiscard);

    broadcastToRoom(room, {
      type: 'game:discard',
      playerIndex: room.game.currentPlayerIndex,
      card: cardToDiscard,
      deckCount: room.game.deck.length
    });

    // 检查响应
    const responses = checkResponses(room, cardToDiscard, room.game.currentPlayerIndex);
    const humanResponse = responses.find(r => r.canHu || r.canZhao || r.canPeng || r.canChi);

    if (humanResponse) {
      // 有玩家可以响应
      room.game.pendingAction = {
        type: 'response',
        card: cardToDiscard,
        allowedPlayers: responses.filter(r => r.canHu || r.canZhao || r.canPeng || r.canChi).map(r => r.playerIndex),
        deadline: Date.now() + TURN_TIMEOUT_MS
      };

      broadcastToRoom(room, {
        type: 'game:response:query',
        card: cardToDiscard,
        responses: responses,
        deadline: room.game.pendingAction.deadline
      });
    } else {
      // 无人响应，进入下一回合
      moveToNextPlayer(room);
    }
  }
}

function moveToNextPlayer(room) {
  room.game.currentPlayerIndex = (room.game.currentPlayerIndex + 1) % 3;
  startTurn(room);
}

// ==================== 操作执行 ====================
function executePiao(room, playerIndex, piaoValue) {
  const player = room.game.players[playerIndex];
  player.piao = piaoValue;
  room.game.piaoResults[playerIndex] = piaoValue;
  room.game.piaoCountdown--;

  broadcastToRoom(room, {
    type: 'game:piao:result',
    playerIndex: playerIndex,
    piao: piaoValue
  });

  // 检查是否所有人都飘完了
  if (room.game.piaoCountdown === 0) {
    // 开始发牌
    startDealing(room);
  } else {
    // 通知下一个飘分的玩家
    const nextPiaoPlayer = room.game.piaoResults.findIndex(p => p === null);
    if (nextPiaoPlayer !== -1) {
      broadcastToRoom(room, {
        type: 'game:piao:turn',
        playerIndex: nextPiaoPlayer,
        deadline: Date.now() + PIAO_TIMEOUT_MS
      });

      clearPiaoTimer(room.id);
      piaoTimers.set(room.id, setTimeout(() => {
        // 超时默认飘0
        executePiao(room, nextPiaoPlayer, 0);
      }, PIAO_TIMEOUT_MS));
    }
  }
}

function startDealing(room) {
  room.game.status = 'dealing';
  const hands = [[], [], []];
  const deck = room.game.deck;

  // 每人发13张牌
  for (let i = 0; i < 13; i++) {
    for (let j = 0; j < 3; j++) {
      hands[j].push(deck.pop());
    }
  }

  room.game.players.forEach((p, i) => {
    p.hand = hands[i];
  });

  // 发送游戏开始消息，包含每个人的手牌
  room.players.forEach((p, i) => {
    if (p.ws && p.ws.readyState === WebSocket.OPEN) {
      // 计算玩家在游戏中的实际索引
      const gamePlayerIndex = room.game.players.findIndex(gp => gp.id === p.id);
      p.ws.send(JSON.stringify({
        type: 'game:start',
        players: room.game.players.map((gp, idx) => ({
          id: gp.id,
          name: gp.name,
          seatIndex: idx,
          score: gp.score
        })),
        mySeatIndex: gamePlayerIndex,
        myHand: room.game.players[gamePlayerIndex].hand,
        dealerIndex: room.game.dealerIndex,
        deckCount: deck.length,
        piaoResults: room.game.piaoResults
      }));
    }
  });

  // 延迟一点后开始第一回合
  setTimeout(() => {
    startTurn(room);
  }, 2000);
}

function executeDiscard(room, playerIndex, cardIndex, cardChar) {
  const player = room.game.players[playerIndex];

  // 找到要出的牌
  let card;
  if (cardChar) {
    const idx = player.hand.findIndex(c => c.character === cardChar);
    if (idx !== -1) {
      card = player.hand.splice(idx, 1)[0];
    }
  } else if (cardIndex >= 0 && cardIndex < player.hand.length) {
    card = player.hand.splice(cardIndex, 1)[0];
  }

  if (!card) {
    sendToPlayer(player.id, { type: 'game:error', message: '无效的出牌' });
    return false;
  }

  player.discards.push(card);
  room.game.lastDiscardedCard = card;
  room.game.lastDiscardPlayerIndex = playerIndex;
  room.game.pendingAction = null;

  clearTurnTimer(room.id);

  broadcastToRoom(room, {
    type: 'game:discard',
    playerIndex: playerIndex,
    card: card,
    deckCount: room.game.deck.length
  });

  // 检查响应
  const responses = checkResponses(room, card, playerIndex);
  const validResponses = responses.filter(r => r.canHu || r.canZhao || r.canPeng || r.canChi);

  if (validResponses.length > 0) {
    room.game.pendingAction = {
      type: 'response',
      card: card,
      responses: responses,
      deadline: Date.now() + TURN_TIMEOUT_MS
    };

    broadcastToRoom(room, {
      type: 'game:response:query',
      card: card,
      responses: responses,
      deadline: room.game.pendingAction.deadline
    });

    // 设置响应超时
    turnTimers.set(room.id, setTimeout(() => {
      handleResponseTimeout(room);
    }, TURN_TIMEOUT_MS));
  } else {
    // 无人响应，摸牌后进入下一玩家
    setTimeout(() => {
      drawCard(room, playerIndex);
    }, 500);
  }

  return true;
}

function handleResponseTimeout(room) {
  // 所有人放弃响应，当前玩家摸牌后继续
  if (room.game.pendingAction) {
    const lastDiscardPlayer = room.game.lastDiscardPlayerIndex;
    room.game.pendingAction = null;
    setTimeout(() => {
      drawCard(room, lastDiscardPlayer);
    }, 500);
  }
}

function drawCard(room, playerIndex) {
  const player = room.game.players[playerIndex];

  if (room.game.deck.length === 0) {
    // 牌堆空了，流局
    handleLiuJu(room);
    return;
  }

  const card = room.game.deck.pop();
  player.hand.push(card);

  broadcastToRoom(room, {
    type: 'game:draw',
    playerIndex: playerIndex,
    card: card,
    deckCount: room.game.deck.length
  });

  // 检查能否自摸
  // 简化处理：暂时不检查自摸，直接进入下一玩家
  // 实际应该调用 checkHu

  setTimeout(() => {
    moveToNextPlayer(room);
  }, 500);
}

function executeChi(room, playerIndex, card) {
  const player = room.game.players[playerIndex];

  // 找到手牌中能吃成句子的牌
  const sentenceCards = player.hand.filter(c => c.sentence === card.sentence);
  if (sentenceCards.length < 2) {
    sendToPlayer(player.id, { type: 'game:error', message: '无法吃牌' });
    return false;
  }

  // 移除手牌中的两张牌
  const toRemove = [card];
  for (const sc of sentenceCards) {
    if (toRemove.length < 3 && sc.position !== card.position) {
      toRemove.push(sc);
    }
  }

  for (const c of toRemove) {
    const idx = player.hand.findIndex(hc => hc.id === c.id);
    if (idx !== -1) player.hand.splice(idx, 1);
  }

  player.melds.push({
    type: 'sequence',
    cards: toRemove
  });

  room.game.pendingAction = null;

  broadcastToRoom(room, {
    type: 'game:action:result',
    action: 'chi',
    playerIndex: playerIndex,
    success: true,
    meld: { type: 'sequence', cards: toRemove },
    card: card
  });

  // 吃牌后，该玩家继续出牌
  setTimeout(() => {
    startTurn(room);
  }, 1000);

  return true;
}

function executePeng(room, playerIndex, card) {
  const player = room.game.players[playerIndex];

  // 找到手牌中相同的牌
  const sameCards = player.hand.filter(c => c.character === card.character);
  if (sameCards.length < 2) {
    sendToPlayer(player.id, { type: 'game:error', message: '无法碰牌' });
    return false;
  }

  // 移除手牌中的两张牌
  const toRemove = [card];
  for (const sc of sameCards) {
    if (toRemove.length < 3 && sc.id !== card.id) {
      toRemove.push(sc);
    }
  }

  for (const c of toRemove) {
    const idx = player.hand.findIndex(hc => hc.id === c.id);
    if (idx !== -1) player.hand.splice(idx, 1);
  }

  player.melds.push({
    type: 'triplet',
    cards: toRemove
  });

  room.game.pendingAction = null;

  broadcastToRoom(room, {
    type: 'game:action:result',
    action: 'peng',
    playerIndex: playerIndex,
    success: true,
    meld: { type: 'triplet', cards: toRemove },
    card: card
  });

  // 碰牌后，该玩家继续出牌
  setTimeout(() => {
    startTurn(room);
  }, 1000);

  return true;
}

function executeZhao(room, playerIndex, card) {
  const player = room.game.players[playerIndex];

  // 找到手牌中相同的牌
  const sameCards = player.hand.filter(c => c.character === card.character);
  if (sameCards.length < 3) {
    sendToPlayer(player.id, { type: 'game:error', message: '无法招牌' });
    return false;
  }

  // 移除手牌中的三张牌
  const toRemove = [card];
  for (const sc of sameCards) {
    if (toRemove.length < 4 && sc.id !== card.id) {
      toRemove.push(sc);
    }
  }

  for (const c of toRemove) {
    const idx = player.hand.findIndex(hc => hc.id === c.id);
    if (idx !== -1) player.hand.splice(idx, 1);
  }

  player.melds.push({
    type: 'quartet',
    cards: toRemove
  });

  room.game.pendingAction = null;

  broadcastToRoom(room, {
    type: 'game:action:result',
    action: 'zhao',
    playerIndex: playerIndex,
    success: true,
    meld: { type: 'quartet', cards: toRemove },
    card: card
  });

  // 招牌后，该玩家继续出牌
  setTimeout(() => {
    startTurn(room);
  }, 1000);

  return true;
}

function executeHu(room, playerIndex, isZimo, card) {
  // 胡牌处理
  // 简化处理：直接结束当前回合
  room.game.status = 'roundEnd';
  clearTurnTimer(room.id);

  const huPlayer = room.game.players[playerIndex];
  let totalScore = 0;
  const settlements = [];

  // 计算分数
  for (let i = 0; i < 3; i++) {
    if (i === playerIndex) {
      settlements.push({ playerIndex: i, score: totalScore, isWinner: true });
    } else {
      settlements.push({ playerIndex: i, score: 0, isWinner: false });
    }
  }

  broadcastToRoom(room, {
    type: 'game:hu',
    playerIndex: playerIndex,
    isZimo: isZimo,
    card: card,
    settlements: settlements
  });

  setTimeout(() => {
    endRound(room);
  }, 3000);
}

function handleLiuJu(room) {
  // 流局处理
  room.game.status = 'roundEnd';
  clearTurnTimer(room.id);

  broadcastToRoom(room, {
    type: 'game:liuju',
    deckCount: 0
  });

  setTimeout(() => {
    endRound(room);
  }, 3000);
}

function endRound(room) {
  room.game.roundNumber++;

  if (room.game.roundNumber > 8) {
    // 8局结束，游戏结束
    room.status = 'waiting';
    room.game = null;

    const finalScores = room.players.map((p, i) => ({
      id: p.id,
      name: p.name,
      totalScore: room.game ? room.game.players[i].score : p.score
    }));

    broadcastToRoom(room, {
      type: 'game:end',
      players: finalScores
    });
  } else {
    // 开始下一回合
    initGameState(room);
    startDealing(room);
  }
}

// ==================== HTTP 服务器 ====================
const httpServer = http.createServer((req, res) => {
  const url = new URL(req.url, `http://localhost:${HTTP_PORT}`);
  const pathname = url.pathname;

  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization');

  if (req.method === 'OPTIONS') {
    res.writeHead(200);
    res.end();
    return;
  }

  if (pathname === '/api/player/send-sms' && req.method === 'POST') {
    let body = '';
    req.on('data', chunk => body += chunk);
    req.on('end', () => {
      try {
        const { phone } = JSON.parse(body);
        if (!phone || !/^1[3-9]\d{9}$/.test(phone)) {
          res.writeHead(400, { 'Content-Type': 'application/json' });
          res.end(JSON.stringify({ success: false, message: '手机号格式错误' }));
          return;
        }
        const code = Math.floor(100000 + Math.random() * 900000).toString();
        smsCodes.set(phone, { code, expiresAt: Date.now() + 60000 });
        addLog('SMS', `${phone}: ${code}`);
        res.writeHead(200, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ success: true, message: '发送成功' }));
      } catch (e) {
        res.writeHead(400, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ success: false, message: '请求格式错误' }));
      }
    });
    return;
  }

  if (pathname === '/api/player/login' && req.method === 'POST') {
    let body = '';
    req.on('data', chunk => body += chunk);
    req.on('end', () => {
      try {
        const { phone, code } = JSON.parse(body);
        if (!phone || !code) {
          res.writeHead(400, { 'Content-Type': 'application/json' });
          res.end(JSON.stringify({ success: false, message: '参数错误' }));
          return;
        }
        const stored = smsCodes.get(phone);
        if (!stored || stored.code !== code || Date.now() > stored.expiresAt) {
          res.writeHead(401, { 'Content-Type': 'application/json' });
          res.end(JSON.stringify({ success: false, message: '验证码错误或已过期' }));
          return;
        }
        smsCodes.delete(phone);
        let player = { id: 'player_' + Date.now().toString(36), phone, username: '玩家' + phone.slice(-4), createdAt: Date.now() };
        sessions.forEach((s, t) => { if (s.phone === phone) { sessions.delete(t); } });
        const token = generateToken();
        sessions.set(token, { playerId: player.id, username: player.username, phone: player.phone });
        res.writeHead(200, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ success: true, token, playerId: player.id, username: player.username }));
      } catch (e) {
        res.writeHead(400, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ success: false, message: '请求格式错误' }));
      }
    });
    return;
  }

  if (pathname === '/api/player/logout' && req.method === 'POST') {
    const token = (req.headers['authorization'] || '').replace('Bearer ', '');
    if (token) sessions.delete(token);
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ success: true }));
    return;
  }

  if (pathname === '/api/player/online' && req.method === 'GET') {
    const players = [];
    sessions.forEach(s => players.push({ playerId: s.playerId, username: s.username }));
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ success: true, players }));
    return;
  }

  if (pathname === '/api/rooms' && req.method === 'GET') {
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ success: true, rooms: getAllRoomsInfo() }));
    return;
  }

  if (pathname === '/api/logs' && req.method === 'GET') {
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ success: true, logs: recentLogs }));
    return;
  }

  let filePath = path.join(__dirname, 'web', pathname === '/' ? 'lobby.html' : pathname);
  const ext = path.extname(filePath);
  const types = { '.html': 'text/html', '.js': 'application/javascript', '.css': 'text/css', '.png': 'image/png', '.jpg': 'image/jpeg' };

  fs.readFile(filePath, (err, content) => {
    if (err) {
      res.writeHead(404);
      res.end('Not found');
    } else {
      res.writeHead(200, { 'Content-Type': types[ext] || 'text/plain' });
      res.end(content);
    }
  });
});

// ==================== WebSocket 服务器 ====================
const wss = new WebSocket.Server({ server: httpServer });

wss.on('connection', (ws) => {
  ws.isAlive = true;
  ws.on('pong', () => { ws.isAlive = true; });

  ws.on('message', (data) => {
    try {
      const msg = JSON.parse(data);
      addLog('WS', `${msg.type}: ${JSON.stringify(msg)}`);

      switch (msg.type) {
        case 'auth':
          ws.playerId = msg.playerId;
          ws.playerName = msg.playerName || '玩家';
          ws.roomId = null;
          ws.send(JSON.stringify({ type: 'auth', success: true, playerId: ws.playerId }));
          break;

        case 'room:list':
          ws.send(JSON.stringify({ type: 'room:list', rooms: getAllRoomsInfo() }));
          break;

        case 'room:join': {
          const result = joinRoom(msg.roomId, { id: ws.playerId, name: ws.playerName });
          if (result.success) {
            ws.roomId = msg.roomId;
            // 保存ws引用
            const room = rooms.get(msg.roomId);
            const player = room.players.find(p => p.id === ws.playerId);
            if (player) player.ws = ws;

            ws.send(JSON.stringify({ type: 'room:joined', room: result.room }));
            wss.clients.forEach(c => {
              if (c.readyState === WebSocket.OPEN) {
                c.send(JSON.stringify({ type: 'room:update', room: result.room }));
              }
            });
          } else {
            ws.send(JSON.stringify({ type: 'room:error', message: result.message }));
          }
          break;
        }

        case 'room:leave': {
          if (ws.roomId) {
            const room = rooms.get(ws.roomId);
            if (room) {
              const player = room.players.find(p => p.id === ws.playerId);
              if (player) player.ws = null;
            }
            const result = leaveRoom(ws.roomId, ws.playerId);
            if (result.success) {
              const roomInfo = rooms.has(ws.roomId) ? getRoomInfo(ws.roomId) : { id: ws.roomId, players: [], status: 'waiting', playerCount: 0 };
              wss.clients.forEach(c => {
                if (c.readyState === WebSocket.OPEN) {
                  c.send(JSON.stringify({ type: 'room:update', room: roomInfo }));
                }
              });
              ws.send(JSON.stringify({ type: 'room:left' }));
              ws.roomId = null;
            } else {
              ws.send(JSON.stringify({ type: 'room:error', message: result.message }));
            }
          }
          break;
        }

        case 'room:ready': {
          if (ws.roomId) {
            const result = toggleReady(ws.roomId, ws.playerId);
            if (result.success) {
              const room = getRoomInfo(ws.roomId);
              wss.clients.forEach(c => {
                if (c.readyState === WebSocket.OPEN) {
                  c.send(JSON.stringify({ type: 'room:update', room }));
                }
              });
              if (checkAndStartGame(ws.roomId)) {
                const roomData = rooms.get(ws.roomId);
                roomData.status = 'playing';

                // 初始化游戏状态
                initGameState(roomData);

                // 发送 room:game:start 让客户端跳转到游戏页面
                broadcastToRoom(roomData, {
                  type: 'room:game:start',
                  players: roomData.players.map(p => ({ id: p.id, name: p.name, seatIndex: p.seatIndex })),
                  roomId: roomData.id
                });
              }
            } else {
              ws.send(JSON.stringify({ type: 'room:error', message: result.message }));
            }
          }
          break;
        }

        case 'room:heartbeat':
          ws.send(JSON.stringify({ type: 'room:heartbeat', timestamp: Date.now() }));
          break;

        // ==================== 游戏消息 ====================
        case 'game:piao': {
          if (!ws.roomId) break;
          const room = rooms.get(ws.roomId);
          if (!room || !room.game || room.game.status !== 'piao') break;

          const playerIndex = room.game.players.findIndex(p => p.id === ws.playerId);
          if (playerIndex === -1) break;

          // 检查是否是当前需要飘的玩家
          const piaoPlayer = room.game.piaoResults.findIndex(p => p === null);
          if (piaoPlayer !== playerIndex) break;

          clearPiaoTimer(room.id);
          executePiao(room, playerIndex, msg.piao);
          break;
        }

        case 'game:action': {
          if (!ws.roomId) break;
          const room = rooms.get(ws.roomId);
          if (!room || !room.game || room.game.status !== 'playing') break;

          const playerIndex = room.game.players.findIndex(p => p.id === ws.playerId);
          if (playerIndex === -1) break;

          const action = msg.action;

          if (action === 'discard') {
            // 出牌
            if (playerIndex !== room.game.currentPlayerIndex) {
              ws.send(JSON.stringify({ type: 'game:error', message: '不是你的回合' }));
              break;
            }
            executeDiscard(room, playerIndex, msg.cardIndex, msg.cardChar);
          } else if (action === 'chi' || action === 'peng' || action === 'zhao' || action === 'hu') {
            // 响应动作
            if (!room.game.pendingAction) {
              ws.send(JSON.stringify({ type: 'game:error', message: '没有待响应的动作' }));
              break;
            }

            if (!room.game.pendingAction.allowedPlayers.includes(playerIndex)) {
              ws.send(JSON.stringify({ type: 'game:error', message: '你不能执行这个动作' }));
              break;
            }

            if (action === 'chi') {
              executeChi(room, playerIndex, room.game.pendingAction.card);
            } else if (action === 'peng') {
              executePeng(room, playerIndex, room.game.pendingAction.card);
            } else if (action === 'zhao') {
              executeZhao(room, playerIndex, room.game.pendingAction.card);
            } else if (action === 'hu') {
              executeHu(room, playerIndex, false, room.game.pendingAction.card);
            }
          } else if (action === 'pass') {
            // 放弃响应
            if (room.game.pendingAction && room.game.pendingAction.allowedPlayers.includes(playerIndex)) {
              // 从允许列表中移除
              room.game.pendingAction.allowedPlayers = room.game.pendingAction.allowedPlayers.filter(i => i !== playerIndex);

              // 检查是否所有人都放弃了
              if (room.game.pendingAction.allowedPlayers.length === 0) {
                room.game.pendingAction = null;
                // 无人响应，摸牌后继续
                setTimeout(() => {
                  drawCard(room, room.game.lastDiscardPlayerIndex);
                }, 500);
              }
            }
          }
          break;
        }

        case 'game:draw': {
          // 玩家请求摸牌（在自己回合时）
          if (!ws.roomId) break;
          const room = rooms.get(ws.roomId);
          if (!room || !room.game || room.game.status !== 'playing') break;

          const playerIndex = room.game.players.findIndex(p => p.id === ws.playerId);
          if (playerIndex !== room.game.currentPlayerIndex) break;

          clearTurnTimer(room.id);
          drawCard(room, playerIndex);
          break;
        }

        case 'game:reconnect': {
          // 断线重连
          if (!msg.roomId || !msg.playerId) break;

          const room = rooms.get(msg.roomId);
          if (!room || !room.game) {
            ws.send(JSON.stringify({ type: 'game:error', message: '房间不存在或游戏已结束' }));
            break;
          }

          // 更新ws引用
          const player = room.players.find(p => p.id === msg.playerId);
          if (player) {
            player.ws = ws;
            ws.roomId = msg.roomId;
            ws.playerId = msg.playerId;

            // 发送完整游戏状态
            const gamePlayerIndex = room.game.players.findIndex(p => p.id === msg.playerId);
            ws.send(JSON.stringify({
              type: 'game:sync',
              success: true,
              gameState: {
                status: room.game.status,
                players: room.game.players.map((p, i) => ({
                  id: p.id,
                  name: p.name,
                  seatIndex: i,
                  score: p.score,
                  piao: p.piao,
                  melds: p.melds,
                  discards: p.discards,
                  isTing: p.isTing
                })),
                mySeatIndex: gamePlayerIndex,
                myHand: room.game.players[gamePlayerIndex].hand,
                deckCount: room.game.deck.length,
                currentPlayerIndex: room.game.currentPlayerIndex,
                lastDiscardedCard: room.game.lastDiscardedCard,
                lastDiscardPlayerIndex: room.game.lastDiscardPlayerIndex,
                dealerIndex: room.game.dealerIndex,
                roundNumber: room.game.roundNumber,
                pendingAction: room.game.pendingAction,
                piaoResults: room.game.piaoResults
              },
              serverTime: Date.now()
            }));
          }
          break;
        }
      }
    } catch (e) {
      console.error('[WS] Error:', e);
    }
  });

  ws.on('close', () => {
    if (ws.roomId && ws.playerId) {
      const room = rooms.get(ws.roomId);
      if (room) {
        const player = room.players.find(p => p.id === ws.playerId);
        if (player) player.ws = null;

        // 如果游戏正在进行，通知其他玩家
        if (room.game && room.game.status === 'playing') {
          broadcastToRoom(room, {
            type: 'game:player:disconnect',
            playerId: ws.playerId,
            playerIndex: room.game.players.findIndex(p => p.id === ws.playerId)
          });
        }
      }

      const result = leaveRoom(ws.roomId, ws.playerId);
      if (result.success) {
        const roomInfo = rooms.has(ws.roomId) ? getRoomInfo(ws.roomId) : { id: ws.roomId, players: [], status: 'waiting', playerCount: 0 };
        wss.clients.forEach(c => {
          if (c.readyState === WebSocket.OPEN && c.roomId === ws.roomId) {
            c.send(JSON.stringify({ type: 'room:update', room: roomInfo }));
          }
        });
      }
    }
  });
});

setInterval(() => {
  wss.clients.forEach(ws => {
    if (!ws.isAlive) return ws.terminate();
    ws.isAlive = false;
    ws.ping();
  });
}, 30000);

httpServer.listen(HTTP_PORT, () => {
  console.log(`HTTP: http://localhost:${HTTP_PORT}`);
  console.log(`WS: ws://localhost:${WS_PORT}`);
});
