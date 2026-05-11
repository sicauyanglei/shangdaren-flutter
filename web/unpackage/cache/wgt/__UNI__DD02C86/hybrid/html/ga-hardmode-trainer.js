// ============================================
// 困难模式AI遗传算法训练系统 - 多进程并行优化版
// ============================================

const os = require('os');
const numCPUs = os.cpus().length;

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

// ============================================
// 游戏逻辑
// ============================================

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

// ============================================
// AI出牌决策 (参数化版本)
// ============================================

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

// ============================================
// 游戏模拟
// ============================================

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
// 多进程并行评估
// ============================================

const { fork } = require('child_process');
const path = require('path');
const fs = require('fs');

let workerPool = [];
const numWorkers = Math.max(1, Math.min(numCPUs - 1, 8)); // 留一个核心给主进程

function initWorkerPool() {
  console.log(`初始化工作进程池: ${numWorkers} 个工作进程`);
  for (let i = 0; i < numWorkers; i++) {
    const worker = fork(path.join(__dirname, 'ga-worker.js'));
    workerPool.push({ worker, busy: false, id: i });
  }
}

function terminateWorkerPool() {
  for (const w of workerPool) {
    w.worker.kill();
  }
  workerPool = [];
}

// 评估结果缓存
const evaluationCache = new Map();
const MAX_CACHE_SIZE = 500;

function getCacheKey(params) {
  return Object.values(params).map(v => Math.round(v).toString()).join(',');
}

function getCachedResult(params) {
  const key = getCacheKey(params);
  return evaluationCache.get(key) || null;
}

function cacheResult(params, result) {
  const key = getCacheKey(params);
  if (evaluationCache.size >= MAX_CACHE_SIZE) {
    const firstKey = evaluationCache.keys().next().value;
    evaluationCache.delete(firstKey);
  }
  evaluationCache.set(key, result);
}

// 异步并行评估
function evaluatePopulationParallel(population, sampleSize) {
  return new Promise((resolve) => {
    const results = new Array(population.length).fill(null);
    let completed = 0;

    // 为每个个体分配工作进程
    const assignWork = () => {
      for (let i = 0; i < population.length; i++) {
        if (results[i] !== null) continue; // 已有结果（可能是缓存）

        const freeWorker = workerPool.find(w => !w.busy);
        if (!freeWorker) break;

        const individual = population[i];
        const cached = getCachedResult(individual.params);
        if (cached) {
          results[i] = cached;
          completed++;
          continue;
        }

        freeWorker.busy = true;
        const workerIndex = i;
        freeWorker.worker.send({ params: individual.params, sampleSize, index: workerIndex });

        const messageHandler = (msg) => {
          freeWorker.busy = false;
          results[msg.index] = msg.result;
          cacheResult(population[msg.index].params, msg.result);
          completed++;

          if (completed % 5 === 0 || completed === population.length) {
            process.stdout.write(`\r评估进度: ${completed}/${population.length} (缓存: ${evaluationCache.size})`);
          }

          freeWorker.worker.removeListener('message', messageHandler);
          assignWork(); // 继续分配下一个工作
        };
        freeWorker.worker.on('message', messageHandler);
      }
    };

    // 处理工作进程错误
    for (const w of workerPool) {
      w.worker.on('error', (err) => {
        console.error('工作进程错误:', err);
        w.busy = false;
      });
    }

    assignWork();

    // 等待所有评估完成
    const checkComplete = setInterval(() => {
      if (completed >= population.length) {
        clearInterval(checkComplete);
        console.log();
        resolve(results);
      }
    }, 100);
  });
}

// ============================================
// GA配置
// ============================================

const GA_CONFIG = {
  populationSize: 30,
  eliteCount: 3,
  tournamentSize: 3,
  crossoverRate: 0.85,
  mutationRate: 0.15,
  mutationScale: 0.2,
  maxGenerations: 50,
  earlyStoppingPatience: 15,
  earlyStoppingMinDelta: 0.001,
  initialSampleSize: 3000,
  middleSampleSize: 5000,
  finalSampleSize: 10000,
  useAdaptiveSampling: true,
  timeBudgetMinutes: 240,
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
// 遗传算法主类
// ============================================

class GATrainer {
  constructor(config) {
    this.config = config;
    this.population = [];
    this.bestIndividual = null;
    this.fitnessHistory = [];
    this.earlyStoppingCounter = 0;
    this.startTime = Date.now();
  }

  createBaselineIndividual() {
    const params = {};
    for (const pconfig of PARAM_CONFIG) {
      params[pconfig.name] = pconfig.base;
    }
    return { params, fitness: 0, age: 0 };
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
    return { params, fitness: 0, age: 0 };
  }

  gaussianRandom(mean, stddev) {
    let u = 0, v = 0;
    while (u === 0) u = Math.random();
    while (v === 0) v = Math.random();
    return mean + stddev * Math.sqrt(-2.0 * Math.log(u)) * Math.cos(2.0 * Math.PI * v);
  }

  initializePopulation() {
    console.log('\n初始化种群...');
    this.population = [];
    this.population.push(this.createBaselineIndividual());
    for (let i = 1; i < this.config.populationSize; i++) {
      this.population.push(this.createRandomIndividual());
    }
    console.log(`种群初始化完成: ${this.population.length} 个体`);
  }

  // 适应度计算
  calculateFitness(result, numGames) {
    if (!result || result.hu === undefined) {
      return -Infinity; // 无效结果
    }
    const huRate = result.hu / numGames;
    const tingRate = result.ting / numGames;
    const w1 = 0.7, w2 = 0.3;
    let fitness = w1 * huRate * 100 + w2 * tingRate;

    const p = huRate;
    const se = Math.sqrt(p * (1 - p) / numGames);
    if (se < 0.01) fitness += 1.5;
    else if (se < 0.015) fitness += 1.0;
    else if (se < 0.02) fitness += 0.5;

    if (result.ting > 0) {
      const tingToHu = result.hu / result.ting;
      fitness += tingToHu * 3;
    }
    return fitness;
  }

  // 锦标赛选择
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

  // 交叉
  crossover(parent1, parent2) {
    if (Math.random() > this.config.crossoverRate) {
      return Math.random() < 0.5 ? { ...parent1, params: {...parent1.params} } : { ...parent2, params: {...parent2.params} };
    }

    const child = { params: {}, fitness: 0, age: 0 };
    const eta = 20;

    for (const pconfig of PARAM_CONFIG) {
      const name = pconfig.name;
      const x1 = parent1.params[name];
      const x2 = parent2.params[name];

      if (Math.abs(x1 - x2) < 1e-10) {
        child.params[name] = x1;
        continue;
      }

      let y1, y2;
      if (x1 < x2) { y1 = x1; y2 = x2; }
      else { y1 = x2; y2 = x1; }

      const rand = Math.random();
      const beta = 1 + (2 * (y1 - pconfig.min) / (y2 - y1));
      const alpha = 2 - Math.pow(beta, -(eta + 1));

      let betaq;
      if (rand <= 1 / alpha) {
        betaq = Math.pow(rand * alpha, 1 / (eta + 1));
      } else {
        betaq = Math.pow(1 / (2 - rand * alpha), 1 / (eta + 1));
      }

      const c1 = 0.5 * ((y1 + y2) - betaq * (y2 - y1));
      child.params[name] = Math.max(pconfig.min, Math.min(pconfig.max, Math.round(c1)));
    }
    return child;
  }

  // 变异
  mutate(individual) {
    const mutated = { params: { ...individual.params }, fitness: 0, age: 0 };
    const eta = 20;
    const prob = 1 / PARAM_CONFIG.length;

    for (const pconfig of PARAM_CONFIG) {
      if (Math.random() < prob) {
        const x = mutated.params[pconfig.name];
        const xDelta = (pconfig.max - pconfig.min) * this.config.mutationScale;

        const delta_l = (x - pconfig.min) / (pconfig.max - pconfig.min);
        const delta_r = (pconfig.max - x) / (pconfig.max - pconfig.min);

        const rand = Math.random();
        let deltaq;

        if (rand < 0.5) {
          const xy = 2 * rand + (1 - 2 * rand) * Math.pow(delta_l, eta + 1);
          deltaq = Math.pow(xy, 1 / (eta + 1)) - 1;
        } else {
          const xy = 2 * (1 - rand) + 2 * (rand - 0.5) * Math.pow(delta_r, eta + 1);
          deltaq = 1 - Math.pow(xy, 1 / (eta + 1));
        }

        let newValue = x + deltaq * xDelta;
        newValue = Math.max(pconfig.min, Math.min(pconfig.max, Math.round(newValue)));
        mutated.params[pconfig.name] = newValue;
      }
    }
    return mutated;
  }

  // 生成新一代
  evolve(fitnesses) {
    const newPopulation = [];

    const sortedIndices = fitnesses
      .map((f, i) => ({ fitness: f, index: i }))
      .sort((a, b) => b.fitness - a.fitness)
      .slice(0, this.config.eliteCount)
      .map(x => x.index);

    for (const idx of sortedIndices) {
      newPopulation.push({ ...this.population[idx], params: {...this.population[idx].params} });
    }

    while (newPopulation.length < this.config.populationSize) {
      const parent1 = this.selectParent(this.population, fitnesses);
      const parent2 = this.selectParent(this.population, fitnesses);
      let child = this.crossover(parent1, parent2);
      child = this.mutate(child);
      newPopulation.push(child);
    }

    return newPopulation;
  }

  getAdaptiveSampleSize(generation) {
    if (!this.config.useAdaptiveSampling) {
      return this.config.initialSampleSize;
    }

    const progress = generation / this.config.maxGenerations;
    if (progress < 0.3) return this.config.initialSampleSize;
    else if (progress < 0.7) return this.config.middleSampleSize;
    else return this.config.finalSampleSize;
  }

  getElapsedTime() {
    return (Date.now() - this.startTime) / 60000;
  }

  // 训练主循环
  async train() {
    console.log('='.repeat(60));
    console.log('  困难模式AI遗传算法训练系统 (多进程并行)');
    console.log('='.repeat(60));
    console.log(`CPU核心数: ${numCPUs}`);
    console.log(`工作进程数: ${numWorkers}`);
    console.log(`种群大小: ${this.config.populationSize}`);
    console.log(`参数数量: ${PARAM_CONFIG.length}`);
    console.log(`最大代数: ${this.config.maxGenerations}`);
    console.log('='.repeat(60));

    initWorkerPool();

    this.initializePopulation();

    for (let gen = 0; gen < this.config.maxGenerations; gen++) {
      const genStartTime = Date.now();
      console.log(`\n${'='.repeat(60)}`);
      console.log(`第 ${gen + 1}/${this.config.maxGenerations} 代`);
      console.log(`时间: ${this.getElapsedTime().toFixed(1)}分钟`);
      console.log(`${'='.repeat(60)}`);

      const sampleSize = this.getAdaptiveSampleSize(gen);
      console.log(`采样数: ${sampleSize}`);

      const results = await evaluatePopulationParallel(this.population, sampleSize);

      const fitnesses = [];
      for (let i = 0; i < this.population.length; i++) {
        this.population[i].fitness = this.calculateFitness(results[i], sampleSize);
        this.population[i].result = results[i];
        fitnesses.push(this.population[i].fitness);
      }

      const currentBestIdx = fitnesses.indexOf(Math.max(...fitnesses));
      const currentBest = this.population[currentBestIdx];
      this.fitnessHistory.push(currentBest.fitness);

      console.log(`当前最佳适应度: ${currentBest.fitness.toFixed(4)}`);
      console.log(`当前最佳胡牌率: ${(currentBest.result.hu / sampleSize * 100).toFixed(2)}%`);
      console.log(`当前最佳听牌率: ${(currentBest.result.ting / sampleSize * 100).toFixed(2)}%`);

      if (!this.bestIndividual || currentBest.fitness > this.bestIndividual.fitness) {
        this.bestIndividual = { ...currentBest, params: {...currentBest.params} };
        console.log('*** 新的全局最佳! ***');
        this.earlyStoppingCounter = 0;
      } else {
        this.earlyStoppingCounter++;
      }

      if (this.earlyStoppingCounter >= this.config.earlyStoppingPatience) {
        console.log(`\n早停触发于第 ${gen + 1} 代 (连续${this.earlyStoppingCounter}代无提升)`);
        break;
      }

      if (gen < this.config.maxGenerations - 1) {
        this.population = this.evolve(fitnesses);
      }

      const genTime = Date.now() - genStartTime;
      console.log(`本代耗时: ${(genTime / 1000).toFixed(1)}秒`);
    }

    terminateWorkerPool();
    return this.bestIndividual;
  }
}

// ============================================
// 验证函数
// ============================================

function validateResults(bestParams, baselineParams) {
  console.log('\n' + '='.repeat(60));
  console.log('  最终验证与对比');
  console.log('='.repeat(60));

  const validationGames = 50000;

  console.log(`\n基线参数验证 (${validationGames}局):`);
  const baselineResult = simulateGame(baselineParams, validationGames);
  console.log(`  胡牌率: ${(baselineResult.hu / validationGames * 100).toFixed(2)}%`);
  console.log(`  听牌率: ${(baselineResult.ting / validationGames * 100).toFixed(2)}%`);

  console.log(`\n最佳GA参数验证 (${validationGames}局):`);
  const bestResult = simulateGame(bestParams, validationGames);
  console.log(`  胡牌率: ${(bestResult.hu / validationGames * 100).toFixed(2)}%`);
  console.log(`  听牌率: ${(bestResult.ting / validationGames * 100).toFixed(2)}%`);

  const huImprovement = (bestResult.hu - baselineResult.hu) / validationGames * 100;

  console.log(`\n改进幅度: 胡牌率 ${huImprovement >= 0 ? '+' : ''}${huImprovement.toFixed(2)}%`);

  return { baselineResult, bestResult, huImprovement };
}

// ============================================
// 主函数
// ============================================

async function main() {
  console.log('\n开始GA训练 (多进程并行版本)...\n');

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
  for (const pconfig of PARAM_CONFIG) {
    baselineParams[pconfig.name] = pconfig.base;
  }

  await validateResults(bestIndividual.params, baselineParams);

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
    config: GA_CONFIG
  };

  const resultFile = path.join(resultDir, `ga_result_${timestamp}.json`);
  fs.writeFileSync(resultFile, JSON.stringify(resultData, null, 2));
  console.log(`\n结果已保存到: ${resultFile}`);

  // 保存最新结果符号链接
  const latestFile = path.join(resultDir, 'ga_result_latest.json');
  fs.writeFileSync(latestFile, JSON.stringify(resultData, null, 2));
  console.log(`最新结果链接: ${latestFile}`);

  return bestIndividual;
}

main().catch(console.error);
