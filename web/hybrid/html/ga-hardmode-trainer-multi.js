// ============================================
// 困难模式AI遗传算法训练系统 - 多进程并行版
// 使用child_process实现真正的多进程并行
// ============================================

const { fork } = require('child_process');
const path = require('path');
const os = require('os');
const fs = require('fs');

const ALL_CHARACTERS = ['上', '大', '人', '丘', '乙', '己', '化', '三', '千', '七', '十', '土', '尔', '小', '生', '八', '九', '子', '佳', '作', '亡', '福', '禄', '寿'];
const cardMap = {
  '上': {s:1,p:0},'大':{s:1,p:1},'人':{s:1,p:2},
  '丘':{s:2,p:0},'乙':{s:2,p:1},'己':{s:2,p:2},
  '化':{s:3,p:0},'三':{s:3,p:1},'千':{s:3,p:2},
  '七':{s:4,p:0},'十':{s:4,p:1},'土':{s:4,p:2},
  '尔':{s:5,p:0},'小':{s:5,p:1},'生':{s:5,p:2},
  '八':{s:6,p:0},'九':{s:6,p:1},'子':{s:6,p:2},
  '佳':{s:7,p:0},'作':{s:7,p:1},'亡':{s:7,p:2},
  '福':{s:8,p:0},'禄':{s:8,p:1},'寿':{s:8,p:2}
};

function createCard(char) {
  const info = cardMap[char] || {s:0,p:0};
  return { character: char, sentence: info.s, position: info.p, id: Math.random().toString(36).substr(2, 9) };
}

function shuffleArray(array) {
  for (let i = array.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    [array[i], array[j]] = [array[j], array[i]];
  }
}

function calculateHuCount(hand, melds) {
  melds = melds || [];
  let hu = 0;
  for (const meld of melds) hu += meld.huValue || 0;
  const cards = [...hand];
  const usedCardIds = new Set();

  let foundSentence = true;
  while (foundSentence) {
    foundSentence = false;
    for (let sentence = 1; sentence <= 8; sentence++) {
      const sentenceCards = cards.filter(c => c.sentence === sentence && !usedCardIds.has(c.id));
      const pos0 = sentenceCards.filter(c => c.position === 0);
      const pos1 = sentenceCards.filter(c => c.position === 1);
      const pos2 = sentenceCards.filter(c => c.position === 2);
      if (pos0.length > 0 && pos1.length > 0 && pos2.length > 0) {
        foundSentence = true;
        const isJingJu = sentence === 1 || sentence === 8;
        const hasShang = pos0[0].character === '上' || pos1[0].character === '上' || pos2[0].character === '上';
        const hasFu = pos0[0].character === '福' || pos1[0].character === '福' || pos2[0].character === '福';
        if (isJingJu && (hasShang || hasFu)) hu += 4;
        usedCardIds.add(pos0[0].id); usedCardIds.add(pos1[0].id); usedCardIds.add(pos2[0].id);
      }
    }
  }

  const remainingAfterJu = cards.filter(c => !usedCardIds.has(c.id));
  const countsAfterJu = {};
  for (const card of remainingAfterJu) countsAfterJu[card.character] = (countsAfterJu[card.character] || 0) + 1;
  for (const [char, count] of Object.entries(countsAfterJu)) {
    if (count >= 4) { hu += char === '上' || char === '福' ? 16 : 6; remainingAfterJu.filter(c => c.character === char).forEach(c => usedCardIds.add(c.id)); }
  }

  const remainingAfterZhao = cards.filter(c => !usedCardIds.has(c.id));
  const countsAfterZhao = {};
  for (const card of remainingAfterZhao) countsAfterZhao[card.character] = (countsAfterZhao[card.character] || 0) + 1;
  for (const [char, count] of Object.entries(countsAfterZhao)) {
    if (count >= 3) { hu += char === '上' || char === '福' ? 12 : 3; remainingAfterZhao.filter(c => c.character === char).slice(0, 3).forEach(c => usedCardIds.add(c.id)); }
  }

  const remainingAfterKan = cards.filter(c => !usedCardIds.has(c.id));
  const countsAfterKan = {};
  for (const card of remainingAfterKan) countsAfterKan[card.character] = (countsAfterKan[card.character] || 0) + 1;
  for (const [char, count] of Object.entries(countsAfterKan)) {
    if (count >= 2) { hu += char === '上' || char === '福' ? 8 : 0; remainingAfterKan.filter(c => c.character === char).slice(0, 2).forEach(c => usedCardIds.add(c.id)); }
  }

  return hu;
}

function detectHuType(hand, melds) {
  const counts = {};
  for (const card of hand) counts[card.character] = (counts[card.character] || 0) + 1;
  let isQing = true;
  for (const card of hand) { if (card.character === '上' || card.character === '福') { isQing = false; break; } }
  const zhaoCount = Object.values(counts).filter(c => c >= 4).length;
  const kanCount = Object.values(counts).filter(c => c >= 3).length;
  if (zhaoCount >= 6) return { type: 'kuChongTaiHu' };
  if (zhaoCount >= 5 && kanCount >= 1) return { type: 'kuChongTaiKa' };
  if (isQing && zhaoCount >= 5) return { type: 'qingKuChongTaiHu' };
  if (kanCount >= 6) return { type: 'kuHu' };
  if (kanCount >= 5) return { type: 'taiHu' };
  if (kanCount >= 4) return { type: 'chongTaiHu' };
  if (kanCount >= 3) return { type: 'kaHu' };
  return { type: 'puTongHu' };
}

function checkHu(hand, melds) {
  const huCount = calculateHuCount(hand, melds);
  const huType = detectHuType(hand, melds);
  const specialHuTypes = ['kuHu', 'qingKuHu', 'kuTaiHu', 'kuChongTaiHu', 'kuChongTaiKa', 'qingKuTaiKa', 'qingKuTaiHu', 'qingKuChongTaiHu', 'qingKuChongTaiKa'];
  const canHu = (specialHuTypes.includes(huType.type) || huCount >= 11) && huType.type !== 'none';
  return { canHu, huCount, huType };
}

function analyzeHandGroups(hand, melds) {
  const meldSentenceCount = (melds || []).filter(m => m.type === 'sequence').length;
  const meldKanCount = (melds || []).filter(m => m.type === 'triplet').length;
  const meldZhaoCount = (melds || []).filter(m => m.type === 'quartet').length;
  const usedCardIds = new Set();
  for (const meld of melds || []) for (const card of meld.cards) usedCardIds.add(card.id);

  let sentenceCount = meldSentenceCount, kanCount = meldKanCount, zhaoCount = meldZhaoCount;
  for (let sentence = 1; sentence <= 8; sentence++) {
    const sentenceCards = hand.filter(c => c.sentence === sentence && !usedCardIds.has(c.id));
    const pos0 = sentenceCards.filter(c => c.position === 0);
    const pos1 = sentenceCards.filter(c => c.position === 1);
    const pos2 = sentenceCards.filter(c => c.position === 2);
    while (pos0.length > 0 && pos1.length > 0 && pos2.length > 0) {
      usedCardIds.add(pos0[0].id); usedCardIds.add(pos1[0].id); usedCardIds.add(pos2[0].id);
      pos0.shift(); pos1.shift(); pos2.shift();
      sentenceCount++;
    }
  }

  const remainingCards = hand.filter(c => !usedCardIds.has(c.id));
  const counts = {};
  for (const card of remainingCards) counts[card.character] = (counts[card.character] || 0) + 1;
  for (const [char, count] of Object.entries(counts)) {
    if (count >= 4) { zhaoCount++; remainingCards.filter(c => c.character === char).forEach(c => usedCardIds.add(c.id)); }
    else if (count === 3) { kanCount++; remainingCards.filter(c => c.character === char).forEach(c => usedCardIds.add(c.id)); }
  }

  const finalRemaining = hand.filter(c => !usedCardIds.has(c.id));
  const pairs = [], singles = [];
  const finalCounts = {};
  for (const card of finalRemaining) finalCounts[card.character] = (finalCounts[card.character] || 0) + 1;
  for (const [char, count] of Object.entries(finalCounts)) {
    if (count === 2) pairs.push(finalRemaining.find(c => c.character === char));
    else if (count === 1) singles.push(finalRemaining.find(c => c.character === char));
  }

  return { sentenceCount, kanCount, zhaoCount, pairs, singles, totalGroups: sentenceCount + kanCount + zhaoCount };
}

function calculateXiangTingShu(hand, melds) {
  const { sentenceCount, kanCount, zhaoCount, pairs, singles, totalGroups } = analyzeHandGroups(hand, melds);
  if (pairs.length >= 9 && singles.length <= 2) return singles.length === 0 ? 0 : singles.length;
  if (totalGroups >= 6 && singles.length === 1) return 1;
  if (totalGroups === 5 && pairs.length >= 2) return 1;
  if (totalGroups === 5 && pairs.length === 1) return 2;
  if (totalGroups === 4) return 3;
  if (totalGroups === 3) return 4;
  return Math.max(1, 6 - totalGroups);
}

function findTingCards(hand, melds = []) {
  const tingCards = [];
  for (const char of ALL_CHARACTERS) {
    const testCard = createCard(char);
    const testHand = [...hand.map(c => ({...c})), testCard];
    if (checkHu(testHand, melds).canHu) tingCards.push(char);
  }
  return tingCards;
}

function selectAIDiscard(player, params) {
  const melds = player.melds || [];
  const hand = player.hand;
  const { sameFour, sameThree, sameTwo, single, tingImprovement, makesTing, tingWidth, nearTing, specialCard, specialSentence } = params;

  if (checkHu(hand, melds).canHu) return 0;

  const currentXT = calculateXiangTingShu(hand, melds);
  const currentTingResult = findTingCards(hand, melds);
  const isCurrentlyTing = currentTingResult.length > 0;

  const counts = {};
  for (const card of hand) counts[card.character] = (counts[card.character] || 0) + 1;

  const scoredCards = [];
  for (let i = 0; i < hand.length; i++) {
    const card = hand[i];
    const tempHand = hand.filter((_, idx) => idx !== i);
    const afterXT = calculateXiangTingShu(tempHand, melds);
    const tingImprovementVal = currentXT - afterXT;
    const afterTingResult = findTingCards(tempHand, melds);
    const willBeTing = afterTingResult.length > 0;

    let score = 0;
    const sameCharCount = counts[card.character];

    if (sameCharCount >= 4) score += sameFour;
    else if (sameCharCount === 3) score += sameThree;
    else if (sameCharCount === 2) score += sameTwo;
    else score += single;

    if (card.character === '福' || card.character === '寿' || card.character === '禄') score += specialCard;
    if (card.sentence === 1 || card.sentence === 8) score += specialSentence;

    if (tingImprovementVal > 0) score += tingImprovementVal * tingImprovement;
    if (willBeTing && !isCurrentlyTing) {
      score += makesTing;
      score += afterTingResult.length * tingWidth;
    }
    if (currentXT <= 2 && sameCharCount === 1) {
      const hasPair = hand.some(c => c.character === card.character && c.id !== card.id);
      const hasAdjacent = hand.some(c => c.sentence === card.sentence && Math.abs(c.position - card.position) === 1);
      if (!hasPair && !hasAdjacent) score += nearTing;
    }
    if (currentXT === 1) score += nearTing;

    scoredCards.push({ card, index: i, score, makesTing: willBeTing && !isCurrentlyTing });
  }

  const makesTingCards = scoredCards.filter(c => c.makesTing);
  if (makesTingCards.length > 0) {
    makesTingCards.sort((a, b) => b.score - a.score);
    return makesTingCards[0].index;
  }

  scoredCards.sort((a, b) => b.score - a.score);
  return scoredCards[0].index;
}

function simulateGame(params, numGames) {
  let totalHu = 0, totalTing = 0;

  for (let g = 0; g < numGames; g++) {
    const deck = [];
    for (const char of ALL_CHARACTERS) for (let i = 0; i < 4; i++) deck.push(createCard(char));
    shuffleArray(deck);

    const players = [
      { name: 'AI', hand: [], melds: [], isTing: false },
      { name: '对手1', hand: [], melds: [], isTing: false },
      { name: '对手2', hand: [], melds: [], isTing: false },
      { name: '对手3', hand: [], melds: [], isTing: false }
    ];

    for (let i = 0; i < 16; i++) {
      for (const player of players) {
        if (deck.length > 0) player.hand.push(deck.pop());
      }
    }

    let lastDiscardedCard = null, lastDiscardPlayer = -1;
    let turn = 0;
    let gameEnded = false;

    while (turn < 300 && deck.length > 0 && !gameEnded) {
      turn++;
      for (let p = 0; p < 4 && !gameEnded; p++) {
        const player = players[p];
        if (player.hand.length === 0) continue;

        if (p === 0) {
          if (!player.isTing) {
            const tingCards = findTingCards(player.hand, player.melds);
            if (tingCards.length > 0) { totalTing++; player.isTing = true; player.tingCards = tingCards; }
          }

          if (lastDiscardedCard && lastDiscardPlayer !== p) {
            const pengCount = player.hand.filter(c => c.character === lastDiscardedCard.character).length;
            if (pengCount >= 2 && Math.random() < 0.6) {
              const pengCards = player.hand.filter(c => c.character === lastDiscardedCard.character).slice(0, 2);
              player.hand = player.hand.filter(c => !pengCards.some(pc => pc.id === c.id));
              player.melds.push({ type: 'triplet', cards: [...pengCards, lastDiscardedCard], huValue: 2 });
              if (deck.length > 0) player.hand.push(deck.pop());
              continue;
            }
          }

          const discardIndex = selectAIDiscard(player, params);
          if (discardIndex < 0 || discardIndex >= player.hand.length) discardIndex = 0;
          const discardedCard = player.hand.splice(discardIndex, 1)[0];
          lastDiscardedCard = discardedCard;
          lastDiscardPlayer = p;

          if (deck.length > 0) player.hand.push(deck.pop());

          if (checkHu(player.hand, player.melds).canHu) { totalHu++; gameEnded = true; break; }

        } else {
          const counts = {};
          for (const card of player.hand) counts[card.character] = (counts[card.character] || 0) + 1;
          let discardIdx = 0, minCount = Infinity;
          for (let i = 0; i < player.hand.length; i++) {
            if (counts[player.hand[i].character] < minCount) { minCount = counts[player.hand[i].character]; discardIdx = i; }
          }
          const discardedCard = player.hand.splice(discardIdx, 1)[0];
          lastDiscardedCard = discardedCard;
          lastDiscardPlayer = p;
          if (deck.length > 0) player.hand.push(deck.pop());
        }
      }
    }
  }
  return { hu: totalHu, ting: totalTing };
}

// ============================================
// 配置
// ============================================

const GA_CONFIG = {
  populationSize: 24,
  eliteCount: 2,
  tournamentSize: 3,
  crossoverRate: 0.85,
  mutationRate: 0.2,
  mutationScale: 0.25,
  maxGenerations: 25,
  earlyStoppingPatience: 6,
  earlyStoppingMinDelta: 0.001,
  sampleSize: 2000,
  timeBudgetMinutes: 90,
  numWorkers: Math.max(1, Math.floor(os.cpus().length / 2)), // 使用一半CPU核心
};

const PARAM_CONFIG = [
  { name: 'sameFour', base: 200, min: 100, max: 400 },
  { name: 'sameThree', base: 120, min: 60, max: 250 },
  { name: 'sameTwo', base: 50, min: 20, max: 120 },
  { name: 'single', base: -40, min: -100, max: 20 },
  { name: 'tingImprovement', base: 1000, min: 500, max: 2000 },
  { name: 'makesTing', base: 2000, min: 1000, max: 4000 },
  { name: 'tingWidth', base: 150, min: 80, max: 300 },
  { name: 'nearTing', base: 300, min: 150, max: 600 },
  { name: 'specialCard', base: 50, min: 20, max: 100 },
  { name: 'specialSentence', base: 30, min: 10, max: 60 },
];

// ============================================
// 辅助类
// ============================================

class EvaluationCache {
  constructor(maxSize = 200) {
    this.cache = new Map();
    this.maxSize = maxSize;
  }

  fingerprint(params) {
    return Object.values(params).map(v => Math.round(v).toString()).join(',');
  }

  get(params) {
    const key = this.fingerprint(params);
    return this.cache.has(key) ? this.cache.get(key) : null;
  }

  set(params, result) {
    if (this.cache.size >= this.maxSize) {
      const firstKey = this.cache.keys().next().value;
      this.cache.delete(firstKey);
    }
    this.cache.set(this.fingerprint(params), result);
  }
}

class EarlyStoppingMonitor {
  constructor(patience = 6, minDelta = 0.001) {
    this.patience = patience;
    this.minDelta = minDelta;
    this.counter = 0;
    this.bestFitness = -Infinity;
  }

  check(currentFitness) {
    if (currentFitness > this.bestFitness + this.minDelta) {
      this.bestFitness = currentFitness;
      this.counter = 0;
      return false;
    }
    this.counter++;
    return this.counter >= this.patience;
  }
}

class TimeBudgetManager {
  constructor(totalTimeMinutes = 90) {
    this.totalMs = totalTimeMinutes * 60 * 1000;
    this.startTime = Date.now();
  }

  getProgress() {
    const elapsed = Date.now() - this.startTime;
    return Math.min(100, (elapsed / this.totalMs * 100)).toFixed(1);
  }
}

// ============================================
// 多进程评估器
// ============================================

class ParallelEvaluator {
  constructor(numWorkers) {
    this.numWorkers = numWorkers;
    this.workers = [];
    this.taskQueue = [];
    this.results = new Map();
  }

  async evaluateBatch(individuals, numGames) {
    const chunks = this.splitIntoChunks(individuals, this.numWorkers);
    const promises = chunks.map((chunk, idx) => this.evaluateChunk(chunk, numGames, idx));
    const results = await Promise.all(promises);
    return results.flat();
  }

  splitIntoChunks(arr, numChunks) {
    const chunks = [];
    const chunkSize = Math.ceil(arr.length / numChunks);
    for (let i = 0; i < arr.length; i += chunkSize) {
      chunks.push(arr.slice(i, i + chunkSize));
    }
    return chunks;
  }

  evaluateChunk(chunk, numGames, workerId) {
    return new Promise((resolve) => {
      // 创建子进程评估这一批个体
      const childScript = `
        const path = require('path');
        const workDir = '${path.dirname(__filename)}';
        process.chdir(workDir);

        // 重新定义游戏逻辑 (简化版)
        const ALL_CHARACTERS = ['上', '大', '人', '丘', '乙', '己', '化', '三', '千', '七', '十', '土', '尔', '小', '生', '八', '九', '子', '佳', '作', '亡', '福', '禄', '寿'];
        const cardMap = {
          '上': {s:1,p:0},'大':{s:1,p:1},'人':{s:1,p:2},
          '丘':{s:2,p:0},'乙':{s:2,p:1},'己':{s:2,p:2},
          '化':{s:3,p:0},'三':{s:3,p:1},'千':{s:3,p:2},
          '七':{s:4,p:0},'十':{s:4,p:1},'土':{s:4,p:2},
          '尔':{s:5,p:0},'小':{s:5,p:1},'生':{s:5,p:2},
          '八':{s:6,p:0},'九':{s:6,p:1},'子':{s:6,p:2},
          '佳':{s:7,p:0},'作':{s:7,p:1},'亡':{s:7,p:2},
          '福':{s:8,p:0},'禄':{s:8,p:1},'寿':{s:8,p:2}
        };

        function createCard(char) {
          const info = cardMap[char] || {s:0,p:0};
          return { character: char, sentence: info.s, position: info.p, id: Math.random().toString(36).substr(2, 9) };
        }

        function shuffleArray(array) {
          for (let i = array.length - 1; i > 0; i--) {
            const j = Math.floor(Math.random() * (i + 1));
            [array[i], array[j]] = [array[j], array[i]];
          }
        }

        function calculateHuCount(hand, melds) {
          melds = melds || [];
          let hu = 0;
          for (const meld of melds) hu += meld.huValue || 0;
          const cards = [...hand];
          const usedCardIds = new Set();
          let foundSentence = true;
          while (foundSentence) {
            foundSentence = false;
            for (let sentence = 1; sentence <= 8; sentence++) {
              const sentenceCards = cards.filter(c => c.sentence === sentence && !usedCardIds.has(c.id));
              const pos0 = sentenceCards.filter(c => c.position === 0);
              const pos1 = sentenceCards.filter(c => c.position === 1);
              const pos2 = sentenceCards.filter(c => c.position === 2);
              if (pos0.length > 0 && pos1.length > 0 && pos2.length > 0) {
                foundSentence = true;
                const isJingJu = sentence === 1 || sentence === 8;
                const hasShang = pos0[0].character === '上' || pos1[0].character === '上' || pos2[0].character === '上';
                const hasFu = pos0[0].character === '福' || pos1[0].character === '福' || pos2[0].character === '福';
                if (isJingJu && (hasShang || hasFu)) hu += 4;
                usedCardIds.add(pos0[0].id); usedCardIds.add(pos1[0].id); usedCardIds.add(pos2[0].id);
              }
            }
          }
          const remainingAfterJu = cards.filter(c => !usedCardIds.has(c.id));
          const countsAfterJu = {};
          for (const card of remainingAfterJu) countsAfterJu[card.character] = (countsAfterJu[card.character] || 0) + 1;
          for (const [char, count] of Object.entries(countsAfterJu)) {
            if (count >= 4) { hu += char === '上' || char === '福' ? 16 : 6; }
          }
          const remainingAfterZhao = cards.filter(c => !usedCardIds.has(c.id));
          const countsAfterZhao = {};
          for (const card of remainingAfterZhao) countsAfterZhao[card.character] = (countsAfterZhao[card.character] || 0) + 1;
          for (const [char, count] of Object.entries(countsAfterZhao)) {
            if (count >= 3) { hu += char === '上' || char === '福' ? 12 : 3; }
          }
          const remainingAfterKan = cards.filter(c => !usedCardIds.has(c.id));
          const countsAfterKan = {};
          for (const card of remainingAfterKan) countsAfterKan[card.character] = (countsAfterKan[card.character] || 0) + 1;
          for (const [char, count] of Object.entries(countsAfterKan)) {
            if (count >= 2) { hu += char === '上' || char === '福' ? 8 : 0; }
          }
          return hu;
        }

        function detectHuType(hand, melds) {
          const counts = {};
          for (const card of hand) counts[card.character] = (counts[card.character] || 0) + 1;
          let isQing = true;
          for (const card of hand) { if (card.character === '上' || card.character === '福') { isQing = false; break; } }
          const zhaoCount = Object.values(counts).filter(c => c >= 4).length;
          const kanCount = Object.values(counts).filter(c => c >= 3).length;
          if (zhaoCount >= 6) return { type: 'kuChongTaiHu' };
          if (zhaoCount >= 5 && kanCount >= 1) return { type: 'kuChongTaiKa' };
          if (isQing && zhaoCount >= 5) return { type: 'qingKuChongTaiHu' };
          if (kanCount >= 6) return { type: 'kuHu' };
          if (kanCount >= 5) return { type: 'taiHu' };
          if (kanCount >= 4) return { type: 'chongTaiHu' };
          if (kanCount >= 3) return { type: 'kaHu' };
          return { type: 'puTongHu' };
        }

        function checkHu(hand, melds) {
          const huCount = calculateHuCount(hand, melds);
          const huType = detectHuType(hand, melds);
          const specialHuTypes = ['kuHu', 'qingKuHu', 'kuTaiHu', 'kuChongTaiHu', 'kuChongTaiKa', 'qingKuTaiKa', 'qingKuTaiHu', 'qingKuChongTaiHu', 'qingKuChongTaiKa'];
          const canHu = (specialHuTypes.includes(huType.type) || huCount >= 11) && huType.type !== 'none';
          return { canHu, huCount, huType };
        }

        function analyzeHandGroups(hand, melds) {
          const usedCardIds = new Set();
          for (const meld of melds || []) for (const card of meld.cards) usedCardIds.add(card.id);
          let sentenceCount = 0, kanCount = 0, zhaoCount = 0;
          for (let sentence = 1; sentence <= 8; sentence++) {
            const sentenceCards = hand.filter(c => c.sentence === sentence && !usedCardIds.has(c.id));
            const pos0 = sentenceCards.filter(c => c.position === 0);
            const pos1 = sentenceCards.filter(c => c.position === 1);
            const pos2 = sentenceCards.filter(c => c.position === 2);
            while (pos0.length > 0 && pos1.length > 0 && pos2.length > 0) {
              usedCardIds.add(pos0[0].id); usedCardIds.add(pos1[0].id); usedCardIds.add(pos2[0].id);
              pos0.shift(); pos1.shift(); pos2.shift();
              sentenceCount++;
            }
          }
          const remainingCards = hand.filter(c => !usedCardIds.has(c.id));
          const counts = {};
          for (const card of remainingCards) counts[card.character] = (counts[card.character] || 0) + 1;
          for (const [char, count] of Object.entries(counts)) {
            if (count >= 4) { zhaoCount++; }
            else if (count === 3) { kanCount++; }
          }
          return { sentenceCount, kanCount, zhaoCount };
        }

        function calculateXiangTingShu(hand, melds) {
          const { sentenceCount, kanCount, zhaoCount } = analyzeHandGroups(hand, melds);
          const totalGroups = sentenceCount + kanCount + zhaoCount;
          if (totalGroups >= 6) return 0;
          if (totalGroups === 5) return 1;
          if (totalGroups === 4) return 2;
          if (totalGroups === 3) return 3;
          return Math.max(1, 6 - totalGroups);
        }

        function findTingCards(hand, melds = []) {
          const tingCards = [];
          for (const char of ALL_CHARACTERS) {
            const testCard = createCard(char);
            const testHand = [...hand.map(c => ({...c})), testCard];
            if (checkHu(testHand, melds).canHu) tingCards.push(char);
          }
          return tingCards;
        }

        function selectAIDiscard(player, params) {
          const melds = player.melds || [];
          const hand = player.hand;
          if (checkHu(hand, melds).canHu) return 0;
          const currentXT = calculateXiangTingShu(hand, melds);
          const counts = {};
          for (const card of hand) counts[card.character] = (counts[card.character] || 0) + 1;
          let bestIdx = 0, bestScore = -Infinity;
          for (let i = 0; i < hand.length; i++) {
            const card = hand[i];
            const tempHand = hand.filter((_, idx) => idx !== i);
            const afterXT = calculateXiangTingShu(tempHand, melds);
            const tingImprovementVal = currentXT - afterXT;
            const afterTingResult = findTingCards(tempHand, melds);
            const willBeTing = afterTingResult.length > 0;
            let score = 0;
            const sameCharCount = counts[card.character];
            if (sameCharCount >= 4) score += params.sameFour;
            else if (sameCharCount === 3) score += params.sameThree;
            else if (sameCharCount === 2) score += params.sameTwo;
            else score += params.single;
            if (card.character === '福' || card.character === '寿' || card.character === '禄') score += params.specialCard;
            if (card.sentence === 1 || card.sentence === 8) score += params.specialSentence;
            if (tingImprovementVal > 0) score += tingImprovementVal * params.tingImprovement;
            if (willBeTing) { score += params.makesTing; score += afterTingResult.length * params.tingWidth; }
            if (score > bestScore) { bestScore = score; bestIdx = i; }
          }
          return bestIdx;
        }

        function simulateGame(params, numGames) {
          let totalHu = 0, totalTing = 0;
          for (let g = 0; g < numGames; g++) {
            const deck = [];
            for (const char of ALL_CHARACTERS) for (let i = 0; i < 4; i++) deck.push(createCard(char));
            shuffleArray(deck);
            const players = [
              { name: 'AI', hand: [], melds: [], isTing: false },
              { name: '对手1', hand: [], melds: [], isTing: false },
              { name: '对手2', hand: [], melds: [], isTing: false },
              { name: '对手3', hand: [], melds: [], isTing: false }
            ];
            for (let i = 0; i < 16; i++) {
              for (const player of players) {
                if (deck.length > 0) player.hand.push(deck.pop());
              }
            }
            let lastDiscardedCard = null, lastDiscardPlayer = -1;
            let turn = 0, gameEnded = false;
            while (turn < 300 && deck.length > 0 && !gameEnded) {
              turn++;
              for (let p = 0; p < 4 && !gameEnded; p++) {
                const player = players[p];
                if (player.hand.length === 0) continue;
                if (p === 0) {
                  if (!player.isTing) {
                    const tingCards = findTingCards(player.hand, player.melds);
                    if (tingCards.length > 0) { totalTing++; player.isTing = true; }
                  }
                  if (lastDiscardedCard && lastDiscardPlayer !== p) {
                    const pengCount = player.hand.filter(c => c.character === lastDiscardedCard.character).length;
                    if (pengCount >= 2 && Math.random() < 0.6) {
                      const pengCards = player.hand.filter(c => c.character === lastDiscardedCard.character).slice(0, 2);
                      player.hand = player.hand.filter(c => !pengCards.some(pc => pc.id === c.id));
                      player.melds.push({ type: 'triplet', cards: [...pengCards, lastDiscardedCard], huValue: 2 });
                      if (deck.length > 0) player.hand.push(deck.pop());
                      continue;
                    }
                  }
                  const discardIndex = selectAIDiscard(player, params);
                  if (discardIndex < 0 || discardIndex >= player.hand.length) discardIndex = 0;
                  const discardedCard = player.hand.splice(discardIndex, 1)[0];
                  lastDiscardedCard = discardedCard;
                  lastDiscardPlayer = p;
                  if (deck.length > 0) player.hand.push(deck.pop());
                  if (checkHu(player.hand, player.melds).canHu) { totalHu++; gameEnded = true; break; }
                } else {
                  const counts = {};
                  for (const card of player.hand) counts[card.character] = (counts[card.character] || 0) + 1;
                  let discardIdx = 0, minCount = Infinity;
                  for (let i = 0; i < player.hand.length; i++) {
                    if (counts[player.hand[i].character] < minCount) { minCount = counts[player.hand[i].character]; discardIdx = i; }
                  }
                  const discardedCard = player.hand.splice(discardIdx, 1)[0];
                  lastDiscardedCard = discardedCard;
                  lastDiscardPlayer = p;
                  if (deck.length > 0) player.hand.push(deck.pop());
                }
              }
            }
          }
          return { hu: totalHu, ting: totalTing };
        }

        const params = JSON.parse('${JSON.stringify(chunk.map(i => i.params))}');
        const numGames = ${numGames};
        const results = params.map(p => simulateGame(p, numGames));
        console.log('WORKER_DONE:' + JSON.stringify(results));
        process.exit(0);
      `;

      const child = fork(childScript, { stdio: ['pipe', 'pipe', 'pipe', 'ipc'] });

      let output = '';
      child.stdout.on('data', (data) => { output += data.toString(); });
      child.stderr.on('data', (data) => { /* ignore */ });

      child.on('close', () => {
        const match = output.match(/WORKER_DONE:(.+)/);
        if (match) {
          try {
            const results = JSON.parse(match[1]);
            resolve(chunk.map((ind, i) => ({
              ...ind,
              ...results[i],
              games: numGames
            })));
          } catch (e) {
            console.error('Parse error:', e);
            resolve(chunk.map(ind => ({ ...ind, hu: 0, ting: 0, games: numGames })));
          }
        } else {
          resolve(chunk.map(ind => ({ ...ind, hu: 0, ting: 0, games: numGames })));
        }
      });

      child.on('error', () => {
        resolve(chunk.map(ind => ({ ...ind, hu: 0, ting: 0, games: numGames })));
      });

      // 超时处理
      setTimeout(() => {
        child.kill();
        resolve(chunk.map(ind => ({ ...ind, hu: 0, ting: 0, games: numGames })));
      }, 300000); // 5分钟超时
    });
  }
}

// ============================================
// GA主类
// ============================================

class GATrainer {
  constructor(config) {
    this.config = config;
    this.population = [];
    this.bestIndividual = null;
    this.evaluationCache = new EvaluationCache();
    this.earlyStopping = new EarlyStoppingMonitor(config.earlyStoppingPatience, config.earlyStoppingMinDelta);
    this.timeBudget = new TimeBudgetManager(config.timeBudgetMinutes);
    this.evaluator = new ParallelEvaluator(config.numWorkers);
  }

  createBaselineIndividual() {
    const params = {};
    for (const pconfig of PARAM_CONFIG) params[pconfig.name] = pconfig.base;
    return { params, fitness: 0 };
  }

  createRandomIndividual() {
    const params = {};
    for (const pconfig of PARAM_CONFIG) {
      const range = pconfig.max - pconfig.min;
      const sigma = range * 0.2;
      let value;
      do {
        value = pconfig.base + this.gaussianRandom(0, sigma);
        value = Math.max(pconfig.min, Math.min(pconfig.max, value));
      } while (Math.abs(value - pconfig.base) < range * 0.05);
      params[pconfig.name] = Math.round(value);
    }
    return { params, fitness: 0 };
  }

  gaussianRandom(mean, stddev) {
    let u = 0, v = 0;
    while (u === 0) u = Math.random();
    while (v === 0) v = Math.random();
    return mean + stddev * Math.sqrt(-2.0 * Math.log(u)) * Math.cos(2.0 * Math.PI * v);
  }

  initializePopulation() {
    console.log('\n初始化种群...');
    this.population = [this.createBaselineIndividual()];
    for (let i = 1; i < this.config.populationSize; i++) {
      this.population.push(this.createRandomIndividual());
    }
    console.log(`种群初始化完成: ${this.population.length} 个体`);
  }

  evaluateIndividual(individual, numGames) {
    const cached = this.evaluationCache.get(individual.params);
    if (cached) return cached;
    const result = simulateGame(individual.params, numGames);
    const evaluated = { ...result, fitness: calculateFitness(result, numGames), games: numGames };
    this.evaluationCache.set(individual.params, evaluated);
    return evaluated;
  }

  async evaluatePopulationParallel(individuals, numGames) {
    return await this.evaluator.evaluateBatch(individuals, numGames);
  }

  selectParent(population, fitnesses) {
    const tournamentSize = this.config.tournamentSize;
    const tournament = [];
    const indices = new Set();
    while (tournament.length < tournamentSize) {
      const idx = Math.floor(Math.random() * population.length);
      if (!indices.has(idx)) {
        indices.add(idx);
        tournament.push({ individual: population[idx], fitness: fitnesses[idx] });
      }
    }
    tournament.sort((a, b) => b.fitness - a.fitness);
    return tournament[0].individual;
  }

  crossover(parent1, parent2) {
    if (Math.random() > this.config.crossoverRate) {
      return Math.random() < 0.5 ? { ...parent1, params: {...parent1.params} } : { ...parent2, params: {...parent2.params} };
    }
    const child = { params: {}, fitness: 0 };
    const eta = 15;
    for (const pconfig of PARAM_CONFIG) {
      const name = pconfig.name;
      const x1 = parent1.params[name];
      const x2 = parent2.params[name];
      if (Math.abs(x1 - x2) < 1e-10) { child.params[name] = x1; continue; }
      let y1 = x1 < x2 ? x1 : x2;
      let y2 = x1 < x2 ? x2 : x1;
      const rand = Math.random();
      const beta = 1 + (2 * (y1 - pconfig.min) / (y2 - y1));
      const alpha = 2 - Math.pow(beta, -(eta + 1));
      let betaq = rand <= 1 / alpha ? Math.pow(rand * alpha, 1 / (eta + 1)) : Math.pow(1 / (2 - rand * alpha), 1 / (eta + 1));
      const c1 = 0.5 * ((y1 + y2) - betaq * (y2 - y1));
      child.params[name] = Math.max(pconfig.min, Math.min(pconfig.max, Math.round(c1)));
    }
    return child;
  }

  mutate(individual) {
    const mutated = { params: { ...individual.params }, fitness: 0 };
    const eta = 15;
    const prob = 1 / PARAM_CONFIG.length;
    for (const pconfig of PARAM_CONFIG) {
      if (Math.random() < prob) {
        const x = mutated.params[pconfig.name];
        const xDelta = (pconfig.max - pconfig.min) * this.config.mutationScale;
        const delta_l = (x - pconfig.min) / (pconfig.max - pconfig.min);
        const delta_r = (pconfig.max - x) / (pconfig.max - pconfig.min);
        const rand = Math.random();
        let deltaq = rand < 0.5
          ? Math.pow(2 * rand + (1 - 2 * rand) * Math.pow(delta_l, eta + 1), 1 / (eta + 1)) - 1
          : 1 - Math.pow(2 * (1 - rand) + 2 * (rand - 0.5) * Math.pow(delta_r, eta + 1), 1 / (eta + 1));
        mutated.params[pconfig.name] = Math.max(pconfig.min, Math.min(pconfig.max, Math.round(x + deltaq * xDelta)));
      }
    }
    return mutated;
  }

  evolve(fitnesses) {
    const newPopulation = [];
    const sortedIndices = fitnesses.map((f, i) => ({ f, i })).sort((a, b) => b.f - a.f).slice(0, this.config.eliteCount).map(x => x.i);
    for (const idx of sortedIndices) {
      newPopulation.push({ ...this.population[idx], params: {...this.population[idx].params} });
    }
    while (newPopulation.length < this.config.populationSize) {
      const parent1 = this.selectParent(this.population, fitnesses);
      const parent2 = this.selectParent(this.population, fitnesses);
      newPopulation.push(this.mutate(this.crossover(parent1, parent2)));
    }
    return newPopulation;
  }

  async train() {
    console.log('='.repeat(60));
    console.log('  困难模式AI遗传算法训练系统 (多进程并行版)');
    console.log('='.repeat(60));
    console.log(`种群大小: ${this.config.populationSize}`);
    console.log(`参数数量: ${PARAM_CONFIG.length}`);
    console.log(`最大代数: ${this.config.maxGenerations}`);
    console.log(`并行进程数: ${this.config.numWorkers}`);
    console.log(`每代采样: ${this.config.sampleSize}局`);
    console.log('='.repeat(60));

    this.initializePopulation();

    for (let gen = 0; gen < this.config.maxGenerations; gen++) {
      const genStartTime = Date.now();
      console.log(`\n${'='.repeat(60)}`);
      console.log(`第 ${gen + 1}/${this.config.maxGenerations} 代`);
      console.log(`时间进度: ${this.timeBudget.getProgress()}%`);
      console.log(`${'='.repeat(60)}`);

      const sampleSize = this.config.sampleSize;
      const genStart = Date.now();

      // 使用并行评估
      const evaluatedPopulation = await this.evaluatePopulationParallel(this.population, sampleSize);
      const fitnesses = [];

      for (let i = 0; i < evaluatedPopulation.length; i++) {
        this.population[i].fitness = calculateFitness(evaluatedPopulation[i], sampleSize);
        evaluatedPopulation[i].fitness = this.population[i].fitness;
        fitnesses.push(this.population[i].fitness);
      }

      const currentBestIdx = fitnesses.indexOf(Math.max(...fitnesses));
      const currentBest = this.population[currentBestIdx];
      const evaluatedBest = evaluatedPopulation[currentBestIdx];

      console.log(`当前最佳适应度: ${currentBest.fitness.toFixed(4)}`);
      console.log(`当前最佳胡牌率: ${(evaluatedBest.hu / sampleSize * 100).toFixed(2)}%`);
      console.log(`当前最佳听牌率: ${(evaluatedBest.ting / sampleSize * 100).toFixed(2)}%`);

      if (!this.bestIndividual || currentBest.fitness > this.bestIndividual.fitness) {
        this.bestIndividual = { ...currentBest, params: {...currentBest.params} };
        console.log('*** 新的全局最佳! ***');
      }

      if (this.earlyStopping.check(currentBest.fitness)) {
        console.log(`\n早停触发于第 ${gen + 1} 代`);
        break;
      }

      if (gen < this.config.maxGenerations - 1) {
        this.population = this.evolve(fitnesses);
      }

      const genTime = Date.now() - genStartTime;
      console.log(`本代耗时: ${(genTime / 1000).toFixed(1)}秒 (评估: ${(genTime / 1000).toFixed(1)}秒)`);
    }

    return this.bestIndividual;
  }
}

function calculateFitness(result, numGames) {
  const huRate = result.hu / numGames;
  const tingRate = result.ting / numGames;
  const w1 = 0.7, w2 = 0.3;
  let fitness = w1 * huRate * 100 + w2 * tingRate;
  if (result.ting > 0) fitness += (result.hu / result.ting) * 3;
  return fitness;
}

async function main() {
  console.log('\n开始GA训练 (多进程并行版)...\n');

  const trainer = new GATrainer(GA_CONFIG);
  const startTime = Date.now();
  const bestIndividual = await trainer.train();
  const totalTime = Date.now() - startTime;

  console.log('\n' + '='.repeat(60));
  console.log('  训练完成');
  console.log('='.repeat(60));
  console.log(`\n总耗时: ${(totalTime / 60000).toFixed(1)} 分钟`);
  console.log(`最佳适应度: ${bestIndividual.fitness.toFixed(4)}`);

  console.log('\n最佳参数组合:');
  console.log('-'.repeat(40));
  for (const [key, value] of Object.entries(bestIndividual.params)) {
    console.log(`  ${key.padEnd(25)}: ${value}`);
  }

  const baselineParams = {};
  for (const pconfig of PARAM_CONFIG) baselineParams[pconfig.name] = pconfig.base;

  console.log('\n' + '='.repeat(60));
  console.log('  最终验证');
  console.log('='.repeat(60));

  const validationGames = 20000;
  console.log(`\n基线参数验证 (${validationGames}局):`);
  const baselineResult = simulateGame(baselineParams, validationGames);
  console.log(`  胡牌率: ${(baselineResult.hu / validationGames * 100).toFixed(2)}%`);
  console.log(`  听牌率: ${(baselineResult.ting / validationGames * 100).toFixed(2)}%`);

  console.log(`\n最佳GA参数验证 (${validationGames}局):`);
  const bestResult = simulateGame(bestIndividual.params, validationGames);
  console.log(`  胡牌率: ${(bestResult.hu / validationGames * 100).toFixed(2)}%`);
  console.log(`  听牌率: ${(bestResult.ting / validationGames * 100).toFixed(2)}%`);

  const huImprovement = (bestResult.hu - baselineResult.hu) / validationGames * 100;
  const tingImprovement = (bestResult.ting - baselineResult.ting) / validationGames * 100;

  console.log(`\n改进幅度:`);
  console.log(`  胡牌率: ${huImprovement >= 0 ? '+' : ''}${huImprovement.toFixed(2)}%`);
  console.log(`  听牌率: ${tingImprovement >= 0 ? '+' : ''}${tingImprovement.toFixed(2)}%`);

  console.log('\n' + '='.repeat(60));
  console.log('  可复制的参数');
  console.log('='.repeat(60));
  console.log(JSON.stringify(bestIndividual.params, null, 2));

  // 保存结果到文件
  const timestamp = new Date().toISOString().replace(/[:.]/g, '-').slice(0, 19);
  const resultDir = path.join(__dirname, 'ga_results');
  if (!fs.existsSync(resultDir)) {
    fs.mkdirSync(resultDir, { recursive: true });
  }

  const resultData = {
    timestamp: new Date().toISOString(),
    totalTimeMinutes: (totalTime / 60000).toFixed(1),
    generations: trainer.fitnessHistory.length,
    bestFitness: bestIndividual.fitness,
    bestParams: bestIndividual.params,
    fitnessHistory: trainer.fitnessHistory,
    baselineParams: baselineParams,
    validation: {
      baselineHuRate: (baselineResult.hu / validationGames * 100).toFixed(2) + '%',
      baselineTingRate: (baselineResult.ting / validationGames * 100).toFixed(2) + '%',
      bestHuRate: (bestResult.hu / validationGames * 100).toFixed(2) + '%',
      bestTingRate: (bestResult.ting / validationGames * 100).toFixed(2) + '%',
      huImprovement: huImprovement >= 0 ? '+' + huImprovement.toFixed(2) + '%' : huImprovement.toFixed(2) + '%',
      tingImprovement: tingImprovement >= 0 ? '+' + tingImprovement.toFixed(2) + '%' : tingImprovement.toFixed(2) + '%'
    },
    config: GA_CONFIG
  };

  const resultFile = path.join(resultDir, `ga_result_multi_${timestamp}.json`);
  fs.writeFileSync(resultFile, JSON.stringify(resultData, null, 2));
  console.log(`\n结果已保存到: ${resultFile}`);

  const latestFile = path.join(resultDir, 'ga_result_multi_latest.json');
  fs.writeFileSync(latestFile, JSON.stringify(resultData, null, 2));
  console.log(`最新结果链接: ${latestFile}`);

  return bestIndividual;
}

main().catch(console.error);
