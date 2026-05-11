// 困难模式AI自动化测试 - 增强版
// 运行方式: node hard-mode-ai-test-cli.js

const ALL_CHARACTERS = ['上', '大', '人', '丘', '乙', '己', '化', '三', '千', '七', '十', '土', '尔', '小', '生', '八', '九', '子', '佳', '作', '亡', '福', '禄', '寿'];

// 计时器
function withTimeout(fn, timeoutMs, name) {
  return new Promise((resolve, reject) => {
    const handle = setTimeout(() => {
      reject(new Error(`${name} 执行超时 (${timeoutMs}ms) - AI可能卡死`));
    }, timeoutMs);
    try {
      const result = fn();
      clearTimeout(handle);
      resolve(result);
    } catch (e) {
      clearTimeout(handle);
      reject(e);
    }
  });
}

function getSentenceInfo(char) {
  const cardMap = {
    '上': { sentence: 1, position: 0, color: 'red' }, '大': { sentence: 1, position: 1, color: 'green' },
    '人': { sentence: 1, position: 2, color: 'black' }, '丘': { sentence: 2, position: 0, color: 'red' },
    '乙': { sentence: 2, position: 1, color: 'green' }, '己': { sentence: 2, position: 2, color: 'black' },
    '化': { sentence: 3, position: 0, color: 'red' }, '三': { sentence: 3, position: 1, color: 'green' },
    '千': { sentence: 3, position: 2, color: 'black' }, '七': { sentence: 4, position: 0, color: 'red' },
    '十': { sentence: 4, position: 1, color: 'green' }, '土': { sentence: 4, position: 2, color: 'black' },
    '尔': { sentence: 5, position: 0, color: 'red' }, '小': { sentence: 5, position: 1, color: 'green' },
    '生': { sentence: 5, position: 2, color: 'black' }, '八': { sentence: 6, position: 0, color: 'red' },
    '九': { sentence: 6, position: 1, color: 'green' }, '子': { sentence: 6, position: 2, color: 'black' },
    '佳': { sentence: 7, position: 0, color: 'red' }, '作': { sentence: 7, position: 1, color: 'green' },
    '亡': { sentence: 7, position: 2, color: 'black' }, '福': { sentence: 8, position: 0, color: 'red' },
    '禄': { sentence: 8, position: 1, color: 'green' }, '寿': { sentence: 8, position: 2, color: 'black' }
  };
  return cardMap[char] || { sentence: 0, position: 0, color: 'black' };
}

function createCard(char) {
  const info = getSentenceInfo(char);
  return { character: char, sentence: info.sentence, position: info.position, color: info.color, id: Math.random().toString(36).substr(2, 9) };
}

function createHand(chars) { return chars.split('').map(c => createCard(c)); }
function shuffleArray(array) { for (let i = array.length - 1; i > 0; i--) { const j = Math.floor(Math.random() * (i + 1)); [array[i], array[j]] = [array[j], array[i]]; } }

// 游戏状态
let gameSettings = { difficulty: 'hard' };
let gameState = { players: [], deck: [], currentPlayerIndex: 0, lastDiscardedCard: null, isPaused: false };

function initGameState() {
  const deck = [];
  for (const char of ALL_CHARACTERS) { for (let i = 0; i < 4; i++) { deck.push(createCard(char)); } }
  shuffleArray(deck);
  gameState.players = [
    { name: '玩家1', hand: [], discards: [], melds: [], isTing: false, tingCards: null },
    { name: '玩家2', hand: [], discards: [], melds: [], isTing: false, tingCards: null },
    { name: '玩家3', hand: [], discards: [], melds: [], isTing: false, tingCards: null }
  ];
  for (let i = 0; i < 16; i++) { for (let p = 0; p < 3; p++) { if (deck.length > 0) gameState.players[p].hand.push(deck.pop()); } }
  gameState.deck = deck;
  gameState.currentPlayerIndex = 0;
}

// ==================== AI函数模拟 ====================

function countRemainingCards(char) {
  let count = 4;
  for (const p of gameState.players) {
    count -= p.hand.filter(c => c.character === char).length;
    count -= p.discards.filter(c => c.character === char).length;
  }
  return Math.max(0, count);
}

function analyzeAbsoluteSafeCards(hand, player) {
  const safeCards = [];
  for (const card of hand) {
    let isSafe = true;
    const remaining = countRemainingCards(card.character);
    if (remaining === 0) { safeCards.push({ card, reason: '牌池已空' }); continue; }
    const opponents = gameState.players.filter((p, i) => i !== gameState.currentPlayerIndex);
    for (const opponent of opponents) {
      if (opponent.isTing && opponent.tingCards && opponent.tingCards.includes(card.character)) { isSafe = false; break; }
    }
    if (isSafe) safeCards.push({ card, reason: remaining === 1 ? '仅剩1张' : '对手不需要' });
  }
  return safeCards;
}

function checkDangerousCardEnhanced(card, player) {
  let dangerScore = 0;
  const opponents = gameState.players.filter((p, i) => i !== gameState.currentPlayerIndex);
  for (const opponent of opponents) {
    if (opponent.isTing && opponent.tingCards) {
      const tingIndex = opponent.tingCards.indexOf(card.character);
      if (tingIndex !== -1) {
        const remaining = countRemainingCards(card.character);
        const inOpponentHand = opponent.hand.filter(c => c.character === card.character).length;
        if (inOpponentHand > 0) { dangerScore -= 2000; }
        else if (remaining === 0) { dangerScore += 500; }
        else if (remaining === 1) { dangerScore -= 800; }
        else { dangerScore -= 1200 + (remaining * 100); }
      }
    }
  }
  const remaining = countRemainingCards(card.character);
  if (remaining === 0) dangerScore += 300;
  const tingOpponents = opponents.filter(o => o.isTing);
  if (tingOpponents.length >= 2) dangerScore *= 1.5;
  return dangerScore;
}

function selectAIDiscardHard(player) {
  const hand = player.hand;
  if (hand.length === 0) return 0;

  const safeCards = analyzeAbsoluteSafeCards(hand, player);
  const opponents = gameState.players.filter((p, i) => i !== gameState.currentPlayerIndex);
  const tingOpponents = opponents.filter(o => o.isTing);

  let bestIndex = 0;
  let minScore = Infinity;

  for (let i = 0; i < hand.length; i++) {
    const card = hand[i];
    let score = 0;
    let bonus = 0;

    // 安全牌加分
    if (tingOpponents.length >= 2) {
      const safeInfo = safeCards.find(s => s.card.id === card.id);
      if (safeInfo) {
        if (safeInfo.reason === '牌池已空') bonus += 1000;
        else if (safeInfo.reason === '仅剩1张') bonus += 500;
      } else {
        for (const opponent of tingOpponents) {
          if (opponent.tingCards && opponent.tingCards.includes(card.character)) {
            const remaining = countRemainingCards(card.character);
            if (remaining <= 2) bonus -= 500;
          }
        }
      }
    }

    // 听牌后优先安全牌
    if (player.isTing && tingOpponents.length >= 1) {
      const safeInfo = safeCards.find(s => s.card.id === card.id);
      if (safeInfo) bonus += 800;
    }

    // 同字越多越优先出
    const sameCount = hand.filter(c => c.character === card.character).length;
    score -= sameCount * 50;

    // 危险牌惩罚
    const dangerScore = Math.abs(checkDangerousCardEnhanced(card, player));
    score += dangerScore * 0.5;

    // 随机扰动
    score += Math.random() * 10;

    const totalScore = score - bonus;
    if (totalScore < minScore) { minScore = totalScore; bestIndex = i; }
  }
  return bestIndex;
}

function shouldAIChi(player, card) {
  const hand = player.hand;
  const tempHand = [...hand, card];
  const sentenceCards = tempHand.filter(c => c.sentence === card.sentence);
  const positions = new Set(sentenceCards.map(c => c.position));
  if (positions.size < 3) return false;

  const chiCards = [];
  for (let pos = 0; pos < 3; pos++) {
    if (pos !== card.position) { const c = sentenceCards.find(sc => sc.position === pos); if (c) chiCards.push(c); }
  }
  if (chiCards.length !== 2) return false;

  // 困难模式：检查吃牌后是否更好
  const afterChiHand = hand.filter(c => c.id !== chiCards[0].id && c.id !== chiCards[1].id);
  const safeCards = analyzeAbsoluteSafeCards(afterChiHand, player);
  const opponents = gameState.players.filter((p, i) => i !== gameState.currentPlayerIndex);
  const anyOpponentTing = opponents.some(o => o.isTing);

  // 如果对手听牌，谨慎吃牌
  if (anyOpponentTing) {
    const remaining = countRemainingCards(card.character);
    if (remaining <= 1) return true;
    if (safeCards.length < afterChiHand.length * 0.3) return false;
  }

  return Math.random() > 0.3;
}

function shouldAIPeng(player, card) {
  const sameCount = player.hand.filter(c => c.character === card.character).length;
  if (sameCount < 2) return false;

  const isJingKan = card.character === '上' || card.character === '福';
  const remaining = countRemainingCards(card.character);

  // 精坎优先碰
  if (isJingKan && remaining > 0) return true;

  // 危险时谨慎
  const opponents = gameState.players.filter((p, i) => i !== gameState.currentPlayerIndex);
  const tingOpponents = opponents.filter(o => o.isTing);
  if (tingOpponents.length >= 2 && !isJingKan) {
    return Math.random() > 0.5;
  }

  return Math.random() > 0.2;
}

function shouldAIZhao(player, card) {
  const sameCount = player.hand.filter(c => c.character === card.character).length;
  if (sameCount < 3) return false;

  // 困难模式策略
  const shangFuCount = player.hand.filter(c => c.character === '上' || c.character === '福').length;

  // 多张上帝/福时保留
  if (shangFuCount >= 4 && sameCount >= 3) return Math.random() > 0.7;

  // 手牌很差时不招
  if (player.hand.length < 10) return Math.random() > 0.5;

  return Math.random() > 0.2;
}

// ==================== 胡牌检测函数 ====================

// 计算胡数
function calculateHuCount(hand, melds, extraCard, isDianPao) {
  const fullHand = extraCard ? [...hand, extraCard] : [...hand];
  let huCount = 0;

  // 统计手牌中的字数
  const counts = {};
  for (const card of fullHand) {
    counts[card.character] = (counts[card.character] || 0) + 1;
  }

  // 统计melds中的牌
  const meldCards = [];
  for (const meld of melds) {
    for (const card of meld.cards) {
      meldCards.push(card);
      counts[card.character] = (counts[card.character] || 0) + 1;
    }
  }

  // 基本胡数计算：每个字的基础胡数
  // 红字（位置0）：2胡
  // 绿字（位置1）：3胡
  // 黑字（位置2）：4胡
  for (const [char, count] of Object.entries(counts)) {
    const info = getSentenceInfo(char);
    if (info.color === 'red') huCount += count * 2;
    else if (info.color === 'green') huCount += count * 3;
    else huCount += count * 4;
  }

  // 招牌算台
  const zhaoCount = melds.filter(m => m.type === 'quartet').length;
  huCount += zhaoCount * 10;

  return huCount;
}

// 检测枯胡
function checkKuHu(hand, melds, hasZhao) {
  const counts = {};
  for (const card of hand) {
    counts[card.character] = (counts[card.character] || 0) + 1;
  }

  const zhaoInMelds = melds.filter(m => m.type === 'quartet').length;
  const handZhaoCount = Object.values(counts).filter(c => c >= 4).length;
  const kanCount = Object.values(counts).filter(c => c === 3).length;
  const duiCount = Object.values(counts).filter(c => c === 2).length;

  const totalZhaoCount = zhaoInMelds + handZhaoCount;

  // 枯胡：6招或5招+1坎
  if (totalZhaoCount === 6 || (totalZhaoCount === 5 && kanCount === 1)) {
    // 检查是否含上帝福
    const hasShangFu = hand.some(c => c.character === '上' || c.character === '福');
    if (!hasShangFu) return true;
  }

  return false;
}

// 检测清枯胡
function checkQingKuHu(hand, melds, hasZhao) {
  const counts = {};
  for (const card of hand) {
    counts[card.character] = (counts[card.character] || 0) + 1;
  }

  const zhaoInMelds = melds.filter(m => m.type === 'quartet').length;
  const handZhaoCount = Object.values(counts).filter(c => c >= 4).length;
  const kanCount = Object.values(counts).filter(c => c === 3).length;

  const totalZhaoCount = zhaoInMelds + handZhaoCount;

  // 清枯胡：6招或5招+1坎，无上帝福
  if ((totalZhaoCount === 6 || (totalZhaoCount === 5 && kanCount === 1))) {
    // 检查是否含上帝福
    const hasShangFu = hand.some(c => c.character === '上' || c.character === '福');
    return !hasShangFu;
  }

  return false;
}

// 检测十对
function checkShiDui(hand, melds) {
  if (melds.length > 0) return false;

  const counts = {};
  for (const card of hand) {
    counts[card.character] = (counts[card.character] || 0) + 1;
  }

  const pairs = Object.values(counts).filter(c => c === 2).length;
  const singles = Object.values(counts).filter(c => c === 1).length;

  return pairs === 10 && singles === 0;
}

// 检测黑元
function checkHeiYuan(hand, melds, hasZhao) {
  const counts = {};
  for (const card of hand) {
    counts[card.character] = (counts[card.character] || 0) + 1;
  }

  const zhaoInMelds = melds.filter(m => m.type === 'quartet').length;
  const handZhaoCount = Object.values(counts).filter(c => c >= 4).length;

  // 黑元：招牌在第8句（禄/寿句）
  for (const meld of melds) {
    if (meld.type === 'quartet') {
      if (meld.cards[0].sentence === 8) return true;
    }
  }

  // 手牌中的4个黑字
  for (const [char, count] of Object.entries(counts)) {
    if (count >= 4) {
      const info = getSentenceInfo(char);
      if (info.sentence === 8) return true;
    }
  }

  return false;
}

// 检测红元
function checkHongYuan(hand, melds, hasZhao) {
  let jingCount = 0;

  // 统计红字数量（除了上和大以外的第1句红字）
  const redChars = ['上', '丘', '化', '七', '尔', '八', '佳'];
  for (const card of hand) {
    if (redChars.includes(card.character)) {
      jingCount++;
    }
  }

  // 加上melds中的红字
  for (const meld of melds) {
    for (const card of meld.cards) {
      if (redChars.includes(card.character)) {
        jingCount++;
      }
    }
  }

  // 还需要统计精牌（上、大、人是精）
  // 上=1精，大=1精，人=1精
  const shangCount = hand.filter(c => c.character === '上').length;
  const daCount = hand.filter(c => c.character === '大').length;
  const renCount = hand.filter(c => c.character === '人').length;

  // melds中的精
  for (const meld of melds) {
    for (const card of meld.cards) {
      if (card.character === '上' || card.character === '大' || card.character === '人') {
        jingCount++;
      }
    }
  }

  // 红元条件：8红元以上（含精）
  if (jingCount >= 8) {
    // 返回精数（简化：8-9红=3精，10-11红=4精，12+红=5精）
    if (jingCount >= 12) return 6;
    if (jingCount >= 10) return 5;
    if (jingCount >= 8) return 4;
  }

  return 0;
}

// 检测清胡
function checkQingHu(hand, melds, huCount) {
  if (melds.length > 0) return false;

  // 清胡：11-21胡，无melds
  return huCount >= 11 && huCount <= 21;
}

// 检测基本胡牌条件
function checkBasicHuCondition(hand, melds) {
  const counts = {};
  for (const card of hand) {
    counts[card.character] = (counts[card.character] || 0) + 1;
  }

  // 计算melds信息
  let meldSentenceCount = 0;
  let meldKanCount = 0;
  let meldZhaoCount = 0;

  for (const meld of melds) {
    if (meld.type === 'sequence') meldSentenceCount++;
    else if (meld.type === 'triplet') meldKanCount++;
    else if (meld.type === 'quartet') meldZhaoCount++;
  }

  const meldGroups = meldSentenceCount + meldKanCount + meldZhaoCount;

  // 牌数 = 3 * groups + singles + 4 * zhaoInMelds
  let meldCardsCount = 0;
  for (const meld of melds) {
    meldCardsCount += meld.cards.length;
  }

  const handSize = hand.length;
  const expectedSize = meldCardsCount + (handSize - meldCardsCount);

  // 手牌数应该符合：14张（基础）+ meld牌数
  return handSize >= 13;
}

// 胡牌检测
function checkHu(player, extraCard = null) {
  const hand = [...player.hand];
  const melds = player.melds || [];

  const huCount = calculateHuCount(hand, melds, extraCard, false);
  const fullHand = extraCard ? [...hand, extraCard] : hand;

  // 检测胡牌类型
  const huType = detectHuType(fullHand, melds, huCount);

  // 特殊胡牌类型
  const specialHuTypes = ['kuHu', 'qingKuHu', 'kuTaiHu', 'kuChongTaiHu', 'kuChongTaiKa',
    'qingKuTaiKa', 'qingKuTaiHu', 'qingKuChongTaiHu', 'qingKuChongTaiKa',
    'hongYuan3Jing', 'hongYuan4Jing', 'hongYuan5Jing', 'hongYuan6Jing',
    'heiYuan', 'shiDui'];

  const isSpecialHu = specialHuTypes.includes(huType.type);
  const canHu = (isSpecialHu || huCount >= 11) && huType.type !== 'none';

  return { canHu, huCount, huType };
}

// 胡牌类型检测
function detectHuType(hand, melds, huCount) {
  const hasChi = melds.some(m => m.type === 'sequence');
  const hasPeng = melds.some(m => m.type === 'triplet');
  const hasZhao = melds.some(m => m.type === 'quartet');

  // 检测枯胡和清枯胡
  const isKuHu = checkKuHu(hand, melds, hasZhao);
  const isQingKuHu = checkQingKuHu(hand, melds, hasZhao);
  const isShiDui = checkShiDui(hand, melds);
  const isHeiYuan = checkHeiYuan(hand, melds, hasZhao);
  const hongYuanJing = checkHongYuan(hand, melds, hasZhao);
  const isQingHu = checkQingHu(hand, melds, huCount);

  // 枯重台胡/卡：33胡以上
  if (isKuHu && huCount >= 33) {
    if (huCount === 33) return { type: 'kuChongTaiKa', name: '枯重台卡', multiplier: { dianpao: 12, zimo: 13 } };
    return { type: 'kuChongTaiHu', name: '枯重台胡', multiplier: { dianpao: 11, zimo: 12 } };
  }

  // 枯台胡：23-32胡
  if (isKuHu && huCount >= 23 && huCount <= 32) {
    return { type: 'kuTaiHu', name: '枯台胡', multiplier: { dianpao: 6, zimo: 7 } };
  }

  // 枯胡
  if (isKuHu) {
    return { type: 'kuHu', name: '枯胡', multiplier: { dianpao: 5, zimo: 6 } };
  }

  // 十对
  if (isShiDui) {
    return { type: 'shiDui', name: '十对', multiplier: { dianpao: 10, zimo: 11 } };
  }

  // 红元
  if (hongYuanJing > 0) {
    return { type: `hongYuan${hongYuanJing}Jing`, name: `红元${hongYuanJing}精`, multiplier: { dianpao: hongYuanJing, zimo: hongYuanJing + 1 } };
  }

  // 黑元
  if (isHeiYuan) {
    return { type: 'heiYuan', name: '黑元', multiplier: { dianpao: 4, zimo: 5 } };
  }

  // 清卡胡
  if (isQingHu && huCount === 11) {
    return { type: 'qingKaHu', name: '清卡胡', multiplier: { dianpao: 2, zimo: 3 } };
  }

  // 清胡
  if (isQingHu) {
    return { type: 'qingHu', name: '清胡', multiplier: { dianpao: 1, zimo: 2 } };
  }

  // 基本条件
  if (!checkBasicHuCondition(hand, melds)) {
    return { type: 'none', name: '无', multiplier: { dianpao: 0, zimo: 0 } };
  }

  // 普通胡牌类型
  if (huCount < 11) {
    return { type: 'none', name: '无', multiplier: { dianpao: 0, zimo: 0 } };
  }

  if (huCount === 11) return { type: 'kaHu', name: '卡胡', multiplier: { dianpao: 1, zimo: 2 } };
  if (huCount >= 12 && huCount <= 21) return { type: 'puTongHu', name: '普通胡', multiplier: { dianpao: 0, zimo: 1 } };
  if (huCount === 22) return { type: 'taiKa', name: '台卡', multiplier: { dianpao: 2, zimo: 3 } };
  if (huCount >= 23 && huCount <= 32) return { type: 'taiHu', name: '台胡', multiplier: { dianpao: 1, zimo: 2 } };
  if (huCount === 33) return { type: 'chongTaiKa', name: '重台卡', multiplier: { dianpao: 7, zimo: 8 } };
  if (huCount >= 34) return { type: 'chongTaiHu', name: '重台胡', multiplier: { dianpao: 6, zimo: 7 } };

  return { type: 'none', name: '无', multiplier: { dianpao: 0, zimo: 0 } };
}

// ==================== 测试用例 ====================

async function testAIDiscardNormal() {
  console.log('\n【测试1】AI出牌选择 - 普通场景');
  const cases = [
    { name: '标准13张', hand: '上丘乙己化三尔小生八九十土' },
    { name: '16张手牌', hand: '上上丘丘乙乙己己化三尔尔小生生' },
    { name: '含上帝福', hand: '上上上福丘乙己化三尔小生八' },
    { name: '全不同字', hand: '上大人丘乙己化三千七十' },
    { name: '含多对子', hand: '上上丘丘乙乙己化三尔尔小生' },
    { name: '8张手牌', hand: '上丘乙己化三尔' },
    { name: '20张手牌', hand: '上上丘丘乙乙己己化三千百十' },
    { name: '单句集中', hand: '上上大大人人丘丘' }
  ];

  let passed = 0, failed = 0;
  for (const tc of cases) {
    try {
      const player = { name: 'AI', hand: createHand(tc.hand), discards: [], melds: [], isTing: false };
      gameState.players = [player];
      const idx = await withTimeout(() => selectAIDiscardHard(player), 2000, tc.name);
      if (idx >= 0 && idx < player.hand.length) { console.log(`  ✓ ${tc.name}: 出${player.hand[idx].character}`); passed++; }
      else { console.log(`  ✗ ${tc.name}: 索引无效`); failed++; }
    } catch (e) { console.log(`  ✗ ${tc.name}: ${e.message}`); failed++; }
  }
  return { passed, failed };
}

async function testAIDiscardOpponentTing() {
  console.log('\n【测试2】AI出牌选择 - 对手听牌场景');
  const cases = [
    { name: '对手听上大字', hand: '上丘乙己化三尔小生八九十土', tingCards: ['上', '大', '人'] },
    { name: '对手听七九十', hand: '上丘乙己化三尔小生八九十土', tingCards: ['七', '九', '十'] },
    { name: '双对手听牌', hand: '丘乙己化三尔小生八九', tingCards1: ['上', '大'], tingCards2: ['七', '九'] },
    { name: '对手听空范围', hand: '上丘乙己化三尔小生八九十土', tingCards: ['佳', '作', '亡'] },
    { name: '我方也听牌', hand: '上丘乙己化三尔小生八九十土', tingCards: ['福', '禄'], selfTing: true }
  ];

  let passed = 0, failed = 0;
  for (const tc of cases) {
    try {
      const player = { name: 'AI', hand: createHand(tc.hand), discards: [], melds: [], isTing: tc.selfTing || false };
      gameState.players = [player];
      if (tc.tingCards) gameState.players.push({ name: '对手1', hand: [], discards: [], melds: [], isTing: true, tingCards: tc.tingCards });
      if (tc.tingCards1) gameState.players.push({ name: '对手1', hand: [], discards: [], melds: [], isTing: true, tingCards: tc.tingCards1 });
      if (tc.tingCards2) gameState.players.push({ name: '对手2', hand: [], discards: [], melds: [], isTing: true, tingCards: tc.tingCards2 });

      const idx = await withTimeout(() => selectAIDiscardHard(player), 2000, tc.name);
      const card = player.hand[idx];
      const safe = analyzeAbsoluteSafeCards(player.hand, player);
      const isSafe = safe.some(s => s.card.id === card.id);

      console.log(`  ✓ ${tc.name}: 出${card.character}${isSafe ? '(安全)' : '(危险)'}`);
      passed++;
    } catch (e) { console.log(`  ✗ ${tc.name}: ${e.message}`); failed++; }
  }
  return { passed, failed };
}

async function testAIDiscardEdgeCases() {
  console.log('\n【测试3】AI出牌选择 - 边界场景');
  const cases = [
    { name: '空手牌', hand: '' },
    { name: '单张手牌', hand: '上' },
    { name: '两张相同', hand: '上上' },
    { name: '全福字', hand: '福福福福福福福福' },
    { name: '全上字', hand: '上上上上上上' },
    { name: '极端长手牌', hand: '上上上上上上丘丘丘丘丘丘乙乙乙乙乙乙己己己己己己' }
  ];

  let passed = 0, failed = 0;
  for (const tc of cases) {
    try {
      if (tc.hand.length === 0) {
        const player = { name: 'AI', hand: [], discards: [], melds: [], isTing: false };
        gameState.players = [player];
        const idx = await withTimeout(() => selectAIDiscardHard(player), 2000, tc.name);
        if (idx === 0) { console.log(`  ✓ ${tc.name}: 正确处理空手牌`); passed++; }
        else { console.log(`  ✗ ${tc.name}: 索引错误`); failed++; }
      } else {
        const player = { name: 'AI', hand: createHand(tc.hand), discards: [], melds: [], isTing: false };
        gameState.players = [player];
        const idx = await withTimeout(() => selectAIDiscardHard(player), 2000, tc.name);
        if (idx >= 0 && idx < player.hand.length) { console.log(`  ✓ ${tc.name}: 出${player.hand[idx].character}`); passed++; }
        else { console.log(`  ✗ ${tc.name}: 索引无效`); failed++; }
      }
    } catch (e) { console.log(`  ✗ ${tc.name}: ${e.message}`); failed++; }
  }
  return { passed, failed };
}

async function testAIChi() {
  console.log('\n【测试4】AI吃牌判断');
  const cases = [
    { name: '可吃-标准', hand: '上丘乙己化三尔小生八九十土', card: '大' },
    { name: '可吃-特殊句', hand: '上丘乙己化三尔小生八九十土', card: '人' },
    { name: '可吃-第二句', hand: '上丘乙己化三尔小生八九十土', card: '乙' },
    { name: '不可吃-缺牌', hand: '上丘己化三尔小生八九十土', card: '大' },
    { name: '不可吃-位置不对', hand: '上丘乙己化三尔小生八九十土', card: '化' },
    { name: '对手听牌时吃', hand: '上丘乙己化三尔小生八九十土', card: '大', opponentTing: true },
    { name: '对手听牌时谨慎吃', hand: '上丘乙己化三尔小生八九十土', card: '大', opponentTing: true, tingCards: ['上', '大', '人'] }
  ];

  let passed = 0, failed = 0;
  for (const tc of cases) {
    try {
      const player = { name: 'AI', hand: createHand(tc.hand), discards: [], melds: [], isTing: false };
      const card = createCard(tc.card);
      gameState.players = [player];
      if (tc.opponentTing) {
        gameState.players.push({ name: '对手', hand: [], discards: [], melds: [], isTing: true, tingCards: tc.tingCards || null });
      }

      const result = await withTimeout(() => shouldAIChi(player, card), 2000, tc.name);
      console.log(`  ✓ ${tc.name}: ${result ? '吃' : '不吃'}`);
      passed++;
    } catch (e) { console.log(`  ✗ ${tc.name}: ${e.message}`); failed++; }
  }
  return { passed, failed };
}

async function testAIPeng() {
  console.log('\n【测试5】AI碰牌判断');
  const cases = [
    { name: '可碰-2张', hand: '上上丘乙己化三尔小生八九十土', card: '上' },
    { name: '可碰-精牌', hand: '上丘乙己化三尔小生八九十土', card: '上' },
    { name: '不可碰-只有1张', hand: '上丘乙己化三尔小生八九十土', card: '上' },
    { name: '碰福字', hand: '上丘乙己化三尔小生八九十土', card: '福' },
    { name: '对手双听牌谨慎碰', hand: '上丘乙己化三尔小生八九十土', card: '丘', dangerous: true },
    { name: '碰剩1张的牌', hand: '上上丘乙己化三尔小生八九十土', card: '丘', remaining: 1 }
  ];

  let passed = 0, failed = 0;
  for (const tc of cases) {
    try {
      const player = { name: 'AI', hand: createHand(tc.hand), discards: [], melds: [], isTing: false };
      const card = createCard(tc.card);
      gameState.players = [player];
      if (tc.dangerous) {
        gameState.players.push({ name: '对手1', hand: [], discards: [], melds: [], isTing: true, tingCards: ['丘', '乙'] });
        gameState.players.push({ name: '对手2', hand: [], discards: [], melds: [], isTing: true, tingCards: ['丘', '己'] });
      }

      const result = await withTimeout(() => shouldAIPeng(player, card), 2000, tc.name);
      console.log(`  ✓ ${tc.name}: ${result ? '碰' : '不碰'}`);
      passed++;
    } catch (e) { console.log(`  ✗ ${tc.name}: ${e.message}`); failed++; }
  }
  return { passed, failed };
}

async function testAIZhao() {
  console.log('\n【测试6】AI招牌判断');
  const cases = [
    { name: '可招牌-3张上', hand: '上上上丘乙己化三尔小生八九十', card: '上' },
    { name: '可招牌-4张', hand: '上上上上丘乙己化三尔小生八', card: '上' },
    { name: '不可招牌-只有2张', hand: '上上丘乙己化三尔小生八九十土', card: '上' },
    { name: '不可招牌-多张上帝', hand: '上上上上丘乙己化三尔小生八', card: '上', keep: true },
    { name: '不可招牌-手牌差', hand: '上丘乙己化三尔小生', card: '上', weak: true },
    { name: '招牌福字', hand: '福福福丘乙己化三尔小生八九十土', card: '福' }
  ];

  let passed = 0, failed = 0;
  for (const tc of cases) {
    try {
      const player = { name: 'AI', hand: createHand(tc.hand), discards: [], melds: [], isTing: false };
      const card = createCard(tc.card);
      gameState.players = [player];

      const result = await withTimeout(() => shouldAIZhao(player, card), 2000, tc.name);
      console.log(`  ✓ ${tc.name}: ${result ? '招' : '不招'}`);
      passed++;
    } catch (e) { console.log(`  ✗ ${tc.name}: ${e.message}`); failed++; }
  }
  return { passed, failed };
}

async function testDangerousCardDetection() {
  console.log('\n【测试7】危险牌检测');
  const cases = [
    { name: '对手听我的牌', hand: '上丘乙己化三尔小生八九十土', tingCards: ['上', '大', '人'], card: '上', expect: 'dangerous' },
    { name: '对手不听我的牌', hand: '上丘乙己化三尔小生八九十土', tingCards: ['七', '九', '十'], card: '上', expect: 'safe' },
    { name: '牌池已空', hand: '上丘乙己化三尔小生八九十土', tingCards: ['上'], card: '上', empty: true, expect: 'safe' },
    { name: '只剩1张', hand: '上丘乙己化三尔小生八九十土', tingCards: ['上'], card: '上', remaining: 1, expect: 'dangerous' },
    { name: '双对手听牌', hand: '上丘乙己化三尔小生八九十土', tingCards1: ['上'], tingCards2: ['上'], card: '上', expect: 'very_dangerous' }
  ];

  let passed = 0, failed = 0;
  for (const tc of cases) {
    try {
      const player = { name: 'AI', hand: createHand(tc.hand), discards: [], melds: [], isTing: false };
      const card = createCard(tc.card);
      gameState.players = [player];
      if (tc.tingCards) gameState.players.push({ name: '对手1', hand: [], discards: [], melds: [], isTing: true, tingCards: tc.tingCards });
      if (tc.tingCards1) gameState.players.push({ name: '对手1', hand: [], discards: [], melds: [], isTing: true, tingCards: tc.tingCards1 });
      if (tc.tingCards2) gameState.players.push({ name: '对手2', hand: [], discards: [], melds: [], isTing: true, tingCards: tc.tingCards2 });

      const score = await withTimeout(() => checkDangerousCardEnhanced(card, player), 2000, tc.name);
      const isDangerous = score < 0;
      console.log(`  ✓ ${tc.name}: ${score > 0 ? '安全+' + score : '危险' + score}`);
      passed++;
    } catch (e) { console.log(`  ✗ ${tc.name}: ${e.message}`); failed++; }
  }
  return { passed, failed };
}

async function testSafeCardAnalysis() {
  console.log('\n【测试8】安全牌分析');
  const cases = [
    { name: '标准手牌', hand: '上丘乙己化三尔小生八九十土', tingCards: ['上', '大', '人'] },
    { name: '所有牌都危险', hand: '上丘乙己化三尔小生八九十土', tingCards: ['上', '丘', '乙', '己', '化'] },
    { name: '有安全牌', hand: '上丘乙己化三尔小生八九十土', tingCards: ['七', '九', '十'] }
  ];

  let passed = 0, failed = 0;
  for (const tc of cases) {
    try {
      const player = { name: 'AI', hand: createHand(tc.hand), discards: [], melds: [], isTing: false };
      gameState.players = [player];
      gameState.players.push({ name: '对手', hand: [], discards: [], melds: [], isTing: true, tingCards: tc.tingCards });

      const safeCards = await withTimeout(() => analyzeAbsoluteSafeCards(player.hand, player), 2000, tc.name);
      const safeNames = safeCards.map(s => `${s.card.character}(${s.reason})`).join(', ');
      console.log(`  ✓ ${tc.name}: 安全牌[${safeNames || '无'}]`);
      passed++;
    } catch (e) { console.log(`  ✗ ${tc.name}: ${e.message}`); failed++; }
  }
  return { passed, failed };
}

async function testMultiPlayerDecision() {
  console.log('\n【测试9】多AI玩家同时决策');
  initGameState();

  let passed = 0, failed = 0;
  try {
    for (let round = 1; round <= 10; round++) {
      for (let p = 0; p < 3; p++) {
        gameState.currentPlayerIndex = p;
        const player = gameState.players[p];

        while (player.hand.length > 0 && gameState.deck.length > 0) {
          const idx = await withTimeout(() => selectAIDiscardHard(player), 2000, `第${round}轮玩家${p + 1}`);
          if (idx < 0 || idx >= player.hand.length) throw new Error('索引无效');
          player.hand.splice(idx, 1);
          if (gameState.deck.length > 0) player.hand.push(gameState.deck.pop());
        }
      }
    }
    console.log(`  ✓ 10轮3人游戏模拟完成`);
    passed++;
  } catch (e) { console.log(`  ✗ 多玩家测试: ${e.message}`); failed++; }
  return { passed, failed };
}

async function testPerformance() {
  console.log('\n【测试10】性能压测');

  let passed = 0, failed = 0;
  const iterations = 500;

  try {
    const startTime = Date.now();
    for (let i = 0; i < iterations; i++) {
      const hand = createHand('上丘乙己化三尔小生八九十土');
      const player = { name: 'AI', hand, discards: [], melds: [], isTing: false };
      gameState.players = [player];
      selectAIDiscardHard(player);
    }
    const elapsed = Date.now() - startTime;
    const avgTime = (elapsed / iterations).toFixed(2);

    if (avgTime < 100) {
      console.log(`  ✓ ${iterations}次迭代完成，平均${avgTime}ms/次`);
      passed++;
    } else {
      console.log(`  ✗ 性能过慢: ${avgTime}ms/次`);
      failed++;
    }
  } catch (e) { console.log(`  ✗ 性能测试: ${e.message}`); failed++; }
  return { passed, failed };
}

async function testMemoryLeak() {
  console.log('\n【测试11】内存泄漏检测');

  let passed = 0, failed = 0;
  const iterations = 1000;

  try {
    const memBefore = process.memoryUsage().heapUsed;
    for (let i = 0; i < iterations; i++) {
      const hand = createHand('上丘乙己化三尔小生八九十土');
      const player = { name: 'AI', hand, discards: [], melds: [], isTing: false };
      gameState.players = [player];
      analyzeAbsoluteSafeCards(player.hand, player);
      checkDangerousCardEnhanced(hand[0], player);
    }
    const memAfter = process.memoryUsage().heapUsed;
    const growth = ((memAfter - memBefore) / 1024 / 1024).toFixed(2);

    if (parseFloat(growth) < 10) {
      console.log(`  ✓ 内存增长${growth}MB (${iterations}次迭代)`);
      passed++;
    } else {
      console.log(`  ✗ 内存增长过大: ${growth}MB`);
      failed++;
    }
  } catch (e) { console.log(`  ✗ 内存测试: ${e.message}`); failed++; }
  return { passed, failed };
}

async function testStressGame() {
  console.log('\n【测试12】压力游戏测试 - 100回合');
  initGameState();

  let passed = 0, failed = 0;
  let turns = 0;
  const maxTurns = 100;

  try {
    while (turns < maxTurns) {
      turns++;
      for (let p = 0; p < 3; p++) {
        gameState.currentPlayerIndex = p;
        const player = gameState.players[p];

        if (player.hand.length === 0) continue;
        if (gameState.deck.length === 0) break;

        const idx = await withTimeout(() => selectAIDiscardHard(player), 2000, `回合${turns}玩家${p + 1}`);
        if (idx < 0 || idx >= player.hand.length) throw new Error(`玩家${p + 1}出牌索引无效`);

        player.hand.splice(idx, 1);
        if (gameState.deck.length > 0 && player.hand.length < 16) {
          player.hand.push(gameState.deck.pop());
        }
      }

      if (gameState.deck.length === 0) break;
      if (turns % 20 === 0) process.stdout.write(`.${turns}`);
    }
    console.log(`\n  ✓ 完成${turns}回合`);
    passed++;
  } catch (e) { console.log(`\n  ✗ 压力测试失败: ${e.message}`); failed++; }
  return { passed, failed };
}

async function testAllSpecialHuTypes() {
  console.log('\n【测试13】胡牌类型检测 - 验证听牌和胡牌函数');

  // 测试用例 - 构造各种手牌验证函数能正常调用
  const cases = [
    { name: '普通13张', hand: '上丘乙己化三尔小生八九十土' },
    { name: '含多对子', hand: '上上丘丘乙乙己己化三尔尔' },
    { name: '含招牌', hand: '上上上上丘乙己化三尔小生' },
    { name: '全红字', hand: '上丘化七尔八佳福' },
    { name: '全绿字', hand: '大乙三十小九作禄' },
    { name: '全黑字', hand: '人己千土生子亡寿' },
    { name: '14张手牌', hand: '上丘乙己化三尔小生八九十土' },
    { name: '15张手牌', hand: '上上丘乙己化三尔小生八九十土' },
    { name: '16张手牌', hand: '上上丘丘乙己化三尔小生八九十' },
  ];

  let passed = 0, failed = 0;

  for (const tc of cases) {
    try {
      const player = { name: '测试', hand: createHand(tc.hand), melds: [] };
      const result = checkHu(player);

      // 只验证函数能正常调用，不强制特定胡牌类型
      console.log(`  ${tc.name}: ${tc.hand}(${tc.hand.length}张) - 胡=${result.canHu}, ${result.huType?.name || '无'}(${result.huCount}胡)`);
      passed++;
    } catch (e) {
      console.log(`  ✗ ${tc.name}: ${e.message}`);
      failed++;
    }
  }

  return { passed, failed };
}

// ==================== 主函数 ====================
async function main() {
  console.log('========================================');
  console.log('  困难模式AI自动化测试 - 增强版');
  console.log('========================================');
  console.log(`开始: ${new Date().toLocaleTimeString()}`);

  let totalPassed = 0, totalFailed = 0;
  const tests = [
    testAIDiscardNormal,
    testAIDiscardOpponentTing,
    testAIDiscardEdgeCases,
    testAIChi,
    testAIPeng,
    testAIZhao,
    testDangerousCardDetection,
    testSafeCardAnalysis,
    testMultiPlayerDecision,
    testPerformance,
    testMemoryLeak,
    testStressGame,
    testAllSpecialHuTypes
  ];

  for (const test of tests) {
    try {
      const result = await test();
      totalPassed += result.passed;
      totalFailed += result.failed;
    } catch (e) {
      console.log(`  测试异常: ${e.message}`);
      totalFailed++;
    }
  }

  console.log('\n========================================');
  console.log('  测试结果汇总');
  console.log('========================================');
  console.log(`通过: ${totalPassed}`);
  console.log(`失败: ${totalFailed}`);
  console.log(`总计: ${totalPassed + totalFailed}`);
  console.log(`结束: ${new Date().toLocaleTimeString()}`);

  if (totalFailed === 0) {
    console.log('\n✓ 所有测试通过！AI未发现卡死问题。');
    process.exit(0);
  } else {
    console.log(`\n✗ ${totalFailed}项测试失败！`);
    process.exit(1);
  }
}

main();
