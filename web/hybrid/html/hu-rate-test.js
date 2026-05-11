// 胡牌概率对比测试 - 改进版
// 模拟真实游戏流程：摸牌、出牌、吃碰杠

const ALL_CHARACTERS = ['上', '大', '人', '丘', '乙', '己', '化', '三', '千', '七', '十', '土', '尔', '小', '生', '八', '九', '子', '佳', '作', '亡', '福', '禄', '寿'];

// 牌的句子和位置信息
const cardMap = {
  '上': {s:1,p:0,c:'red'},'大':{s:1,p:1,c:'green'},'人':{s:1,p:2,c:'black'},
  '丘':{s:2,p:0,c:'red'},'乙':{s:2,p:1,c:'green'},'己':{s:2,p:2,c:'black'},
  '化':{s:3,p:0,c:'red'},'三':{s:3,p:1,c:'green'},'千':{s:3,p:2,c:'black'},
  '七':{s:4,p:0,c:'red'},'十':{s:4,p:1,c:'green'},'土':{s:4,p:2,c:'black'},
  '尔':{s:5,p:0,c:'red'},'小':{s:5,p:1,c:'green'},'生':{s:5,p:2,c:'black'},
  '八':{s:6,p:0,c:'red'},'九':{s:6,p:1,c:'green'},'子':{s:6,p:2,c:'black'},
  '佳':{s:7,p:0,c:'red'},'作':{s:7,p:1,c:'green'},'亡':{s:7,p:2,c:'black'},
  '福':{s:8,p:0,c:'red'},'禄':{s:8,p:1,c:'green'},'寿':{s:8,p:2,c:'black'}
};

function createCard(char) {
  const info = cardMap[char] || {s:0,p:0,c:'black'};
  return { character: char, sentence: info.s, position: info.p, color: info.c, id: Math.random().toString(36).substr(2, 9) };
}

function createHand(chars) {
  return chars.split('').map(c => createCard(c));
}

function shuffleArray(array) {
  for (let i = array.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    [array[i], array[j]] = [array[j], array[i]];
  }
}

// 统计手牌中的字数
function countChars(hand) {
  const counts = {};
  for (const card of hand) {
    counts[card.character] = (counts[card.character] || 0) + 1;
  }
  return counts;
}

// 统计每句话的牌
function getSentenceGroups(hand) {
  const groups = {};
  for (const card of hand) {
    if (!groups[card.sentence]) {
      groups[card.sentence] = { 0: 0, 1: 0, 2: 0, chars: [] };
    }
    groups[card.sentence][card.position]++;
    groups[card.sentence].chars.push(card.character);
  }
  return groups;
}

// 计算完整句子数
function countCompleteSentences(hand) {
  const groups = getSentenceGroups(hand);
  let complete = 0;
  let partial = 0;
  let unused = 0;

  for (const s of Object.keys(groups)) {
    const g = groups[s];
    const total = g[0] + g[1] + g[2];
    if (g[0] > 0 && g[1] > 0 && g[2] > 0) {
      complete++;
    } else if (total > 0) {
      partial++;
      unused += total;
    }
  }
  return { complete, partial, unused };
}

// 简化胡数计算
function calculateSimpleHuCount(hand) {
  let huCount = 0;
  const counts = countChars(hand);

  for (const [char, count] of Object.entries(counts)) {
    const info = cardMap[char];
    if (!info) continue;
    if (info.c === 'red') huCount += count * 2;
    else if (info.c === 'green') huCount += count * 3;
    else huCount += count * 4;
  }

  return huCount;
}

// 检测是否可以听牌（简化版：4完整句+2张散牌 或 5完整句）
function canTing(hand) {
  const { complete, partial, unused } = countCompleteSentences(hand);

  // 4完整句+最多2张散牌 = 可以听
  if (complete >= 4 && unused <= 2) return true;
  // 5完整句 = 可以听
  if (complete >= 5) return true;
  // 3完整句+1坎+2张散牌 = 可以听
  if (complete >= 3 && partial >= 1 && unused <= 2) return true;

  return false;
}

// 找到可以听的牌
function findTingCards(hand) {
  const tingCards = [];
  const counts = countChars(hand);

  for (const char of ALL_CHARACTERS) {
    // 检查牌池中是否还有
    const remaining = 4 - (counts[char] || 0);
    if (remaining <= 0) continue;

    // 模拟摸这张牌后是否能胡
    const testHand = [...hand.map(c => c.character), char];
    const huCount = calculateSimpleHuCount(testHand.map(c => createCard(c)));
    if (huCount >= 11 && canTing(testHand.map(c => createCard(c)))) {
      tingCards.push(char);
    }
  }

  return tingCards;
}

// 检测是否可以胡
function canHu(hand) {
  const huCount = calculateSimpleHuCount(hand);
  return huCount >= 11 && canTing(hand);
}

// 简单出牌策略（优化前）
function simpleDiscard(hand) {
  const counts = countChars(hand);
  const groups = getSentenceGroups(hand);

  // 优先打出：1.单张 2.非完整句中的牌 3.红字
  let bestToDiscard = null;
  let minScore = Infinity;

  for (const card of hand) {
    const info = cardMap[card.character];
    const count = counts[card.character];
    const group = groups[card.sentence];

    let score = 0;

    // 单张优先出
    if (count === 1) score -= 10;

    // 完整句中的牌不舍
    if (group[0] > 0 && group[1] > 0 && group[2] > 0) {
      score += 20;
    }

    // 红字次优先出
    if (info.c === 'red') score -= 5;
    else if (info.c === 'green') score -= 3;
    else score -= 1;

    // 位置越靠后越优先出
    score -= info.p;

    if (score < minScore) {
      minScore = score;
      bestToDiscard = card;
    }
  }

  return bestToDiscard || hand[0];
}

// 智能出牌策略（优化后）
function smartDiscard(hand) {
  const counts = countChars(hand);
  const groups = getSentenceGroups(hand);
  const form = countCompleteSentences(hand);

  // 优先打出对胡牌贡献最小的牌
  let bestToDiscard = null;
  let minContribution = Infinity;

  for (const card of hand) {
    const info = cardMap[card.character];
    const count = counts[card.character];
    const group = groups[card.sentence];

    let contribution = 0;

    // 完整句中的牌贡献高
    if (group[0] > 0 && group[1] > 0 && group[2] > 0) {
      contribution += 10;
      // 如果完整句数已经达到4个，完整句中的牌贡献更高
      if (form.complete >= 4) contribution += 15;
    }

    // 特殊句（第1句、第8句）贡献高
    if (info.s === 1 || info.s === 8) contribution += 5;

    // 单张贡献低
    if (count === 1) contribution -= 15;

    // 红字贡献较低
    if (info.c === 'red') contribution -= 3;
    else if (info.c === 'green') contribution -= 2;

    // 保留组成句子的潜力
    const otherInSentence = hand.filter(c =>
      c.sentence === card.sentence && c.character !== card.character
    );
    if (otherInSentence.length > 0) {
      // 牌组中有其他同句牌，保留
      contribution += 10;
    }

    // 摸起概率低的牌优先出
    if (count >= 3) contribution += 5;

    if (contribution < minContribution) {
      minContribution = contribution;
      bestToDiscard = card;
    }
  }

  return bestToDiscard || hand[0];
}

// 模拟一次游戏
function simulateGame(strategy, maxTurns = 300) {
  const stats = {
    totalGames: 1,
    huCount: 0,
    tingCount: 0,
    turnsPlayed: 0,
    huRate: 0,
    avgTurnsToTing: 0,
    huByType: { zimo: 0, dianpao: 0 }
  };

  let turnsToTing = 0;
  let reachedTing = false;

  // 创建牌堆
  const deck = [];
  for (const char of ALL_CHARACTERS) {
    for (let i = 0; i < 4; i++) {
      deck.push(createCard(char));
    }
  }
  shuffleArray(deck);

  // 初始化玩家
  const players = [
    { hand: [], melds: [], name: 'AI', isTing: false, tingCards: [] },
    { hand: [], melds: [], name: '对手1', isTing: false },
    { hand: [], melds: [], name: '对手2', isTing: false }
  ];

  // 发牌（每人13张）
  for (let i = 0; i < 13; i++) {
    for (const player of players) {
      if (deck.length > 0) {
        player.hand.push(deck.pop());
      }
    }
  }

  let turn = 0;
  let lastDiscard = null;
  let lastDiscardPlayer = -1;

  while (turn < maxTurns && deck.length > 0) {
    turn++;

    for (let p = 0; p < 3; p++) {
      const player = players[p];

      if (player.hand.length === 0) continue;

      // AI玩家
      if (p === 0) {
        // 检查是否可以胡
        if (canHu(player.hand)) {
          stats.huCount++;
          stats.huRate = stats.huCount * 100;
          return stats;
        }

        // 检查是否可以听牌
        if (!reachedTing) {
          const tingCards = findTingCards(player.hand);
          if (tingCards.length > 0) {
            stats.tingCount++;
            turnsToTing = turn;
            reachedTing = true;
            player.isTing = true;
            player.tingCards = tingCards;
          }
        }

        // 选择出牌
        const discardFunc = strategy === 'smart' ? smartDiscard : simpleDiscard;
        const toDiscard = discardFunc(player.hand);
        const idx = player.hand.findIndex(c => c.id === toDiscard.id);

        if (idx !== -1) {
          lastDiscard = player.hand.splice(idx, 1)[0];
          lastDiscardPlayer = p;
        }

        // 摸牌
        if (deck.length > 0) {
          player.hand.push(deck.pop());
        }

      } else {
        // 对手简单策略
        const discardFunc = strategy === 'smart' ? smartDiscard : simpleDiscard;
        const toDiscard = discardFunc(player.hand);
        const idx = player.hand.findIndex(c => c.id === toDiscard.id);

        if (idx !== -1) {
          lastDiscard = player.hand.splice(idx, 1)[0];
          lastDiscardPlayer = p;
        }

        // 对手摸牌
        if (deck.length > 0) {
          player.hand.push(deck.pop());
        }
      }
    }
  }

  stats.turnsPlayed = turn;
  stats.avgTurnsToTing = turnsToTing;
  return stats;
}

// 主测试
async function runTest() {
  console.log('========================================');
  console.log('  AI胡牌概率对比测试');
  console.log('========================================\n');

  const gamesPerStrategy = 200;
  const simpleStats = { huCount: 0, tingCount: 0, totalTurns: 0, games: gamesPerStrategy };
  const smartStats = { huCount: 0, tingCount: 0, totalTurns: 0, games: gamesPerStrategy };

  console.log(`测试每种策略 ${gamesPerStrategy} 局游戏...\n`);

  // 测试简单策略
  console.log('【简单策略】模拟中...');
  for (let i = 0; i < gamesPerStrategy; i++) {
    const result = simulateGame('simple');
    simpleStats.huCount += result.huCount;
    simpleStats.tingCount += result.tingCount;
    simpleStats.totalTurns += result.turnsPlayed;
    if (i % 50 === 0) process.stdout.write('.');
  }
  console.log(' 完成\n');

  // 测试智能策略
  console.log('【智能策略】模拟中...');
  for (let i = 0; i < gamesPerStrategy; i++) {
    const result = simulateGame('smart');
    smartStats.huCount += result.huCount;
    smartStats.tingCount += result.tingCount;
    smartStats.totalTurns += result.turnsPlayed;
    if (i % 50 === 0) process.stdout.write('.');
  }
  console.log(' 完成\n');

  // 汇总结果
  const simpleHuRate = (simpleStats.huCount / simpleStats.games * 100).toFixed(1);
  const smartHuRate = (smartStats.huCount / smartStats.games * 100).toFixed(1);
  const simpleTingRate = (simpleStats.tingCount / simpleStats.games * 100).toFixed(1);
  const smartTingRate = (smartStats.tingCount / smartStats.games * 100).toFixed(1);

  console.log('========================================');
  console.log('  测试结果汇总');
  console.log('========================================');
  console.log('\n简单策略（优化前）:');
  console.log(`  胡牌率: ${simpleHuRate}% (${simpleStats.huCount}/${simpleStats.games})`);
  console.log(`  听牌率: ${simpleTingRate}% (${simpleStats.tingCount}/${simpleStats.games})`);

  console.log('\n智能策略（优化后）:');
  console.log(`  胡牌率: ${smartHuRate}% (${smartStats.huCount}/${smartStats.games})`);
  console.log(`  听牌率: ${smartTingRate}% (${smartStats.tingCount}/${smartStats.games})`);

  console.log('\n========================================');
  console.log('  提升幅度');
  console.log('========================================');
  const huRateDiff = (smartStats.huCount - simpleStats.huCount);
  const tingRateDiff = smartStats.tingCount - simpleStats.tingCount;
  console.log(`  胡牌率提升: ${huRateDiff >= 0 ? '+' : ''}${huRateDiff} 局 (${smartHuRate}% vs ${simpleHuRate}%)`);
  console.log(`  听牌率提升: ${tingRateDiff >= 0 ? '+' : ''}${tingRateDiff} 局 (${smartTingRate}% vs ${simpleTingRate}%)`);

  if (smartStats.huCount > simpleStats.huCount) {
    const improvement = ((smartStats.huCount - simpleStats.huCount) / Math.max(1, simpleStats.huCount) * 100).toFixed(1);
    console.log(`\n  胡牌概率相对提升: ${improvement}%`);
  }
}

runTest();
