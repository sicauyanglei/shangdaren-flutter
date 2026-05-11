// 困难模式AI自动化测试
// 测试AI玩家是否会卡死

// 模拟游戏设置
const gameSettings = {
  difficulty: 'hard'
};

// 模拟游戏状态
let gameState = {
  players: [],
  deck: [],
  currentPlayerIndex: 0,
  lastDiscardedCard: null,
  lastDiscardPlayerIndex: -1,
  isGameOver: false
};

// 初始化游戏状态
function initGameState() {
  const ALL_CHARACTERS = ['上', '大', '人', '丘', '乙', '己', '化', '三', '千', '七', '十', '土', '尔', '小', '生', '八', '九', '子', '佳', '作', '亡', '福', '禄', '寿'];

  // 创建牌堆
  const deck = [];
  for (const char of ALL_CHARACTERS) {
    for (let i = 0; i < 4; i++) {
      deck.push({
        character: char,
        sentence: getSentenceInfo(char).sentence,
        position: getSentenceInfo(char).position,
        color: getSentenceInfo(char).color,
        id: Math.random().toString(36).substr(2, 9)
      });
    }
  }

  // 洗牌
  shuffleArray(deck);

  // 创建4个玩家
  const playerNames = ['玩家1', '玩家2', '玩家3', '玩家4'];
  gameState.players = playerNames.map((name, index) => ({
    name,
    hand: [],
    discards: [],
    melds: [],
    isTing: false,
    piao: 0
  }));

  // 发牌
  for (let i = 0; i < 16; i++) {
    for (let p = 0; p < 4; p++) {
      if (deck.length > 0) {
        gameState.players[p].hand.push(deck.pop());
      }
    }
  }

  gameState.deck = deck;
  gameState.currentPlayerIndex = 0;
  gameState.isGameOver = false;

  return gameState;
}

function shuffleArray(array) {
  for (let i = array.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    [array[i], array[j]] = [array[j], array[i]];
  }
}

function getSentenceInfo(char) {
  const cardMap = {
    '上': { sentence: 1, position: 0, color: 'red' },
    '大': { sentence: 1, position: 1, color: 'green' },
    '人': { sentence: 1, position: 2, color: 'black' },
    '丘': { sentence: 2, position: 0, color: 'red' },
    '乙': { sentence: 2, position: 1, color: 'green' },
    '己': { sentence: 2, position: 2, color: 'black' },
    '化': { sentence: 3, position: 0, color: 'red' },
    '三': { sentence: 3, position: 1, color: 'green' },
    '千': { sentence: 3, position: 2, color: 'black' },
    '七': { sentence: 4, position: 0, color: 'red' },
    '十': { sentence: 4, position: 1, color: 'green' },
    '土': { sentence: 4, position: 2, color: 'black' },
    '尔': { sentence: 5, position: 0, color: 'red' },
    '小': { sentence: 5, position: 1, color: 'green' },
    '生': { sentence: 5, position: 2, color: 'black' },
    '八': { sentence: 6, position: 0, color: 'red' },
    '九': { sentence: 6, position: 1, color: 'green' },
    '子': { sentence: 6, position: 2, color: 'black' },
    '佳': { sentence: 7, position: 0, color: 'red' },
    '作': { sentence: 7, position: 1, color: 'green' },
    '亡': { sentence: 7, position: 2, color: 'black' },
    '福': { sentence: 8, position: 0, color: 'red' },
    '禄': { sentence: 8, position: 1, color: 'green' },
    '寿': { sentence: 8, position: 2, color: 'black' }
  };
  return cardMap[char] || { sentence: 0, position: 0, color: 'black' };
}

// 超时检测辅助函数
function withTimeout(fn, timeoutMs, name) {
  return new Promise((resolve, reject) => {
    const timeoutId = setTimeout(() => {
      reject(new Error(`${name} 执行超时 (${timeoutMs}ms)`));
    }, timeoutMs);

    try {
      const result = fn();
      clearTimeout(timeoutId);
      resolve(result);
    } catch (e) {
      clearTimeout(timeoutId);
      reject(e);
    }
  });
}

// 测试AI出牌选择
async function testAIDiscard() {
  console.log('\n========== 测试AI出牌选择 ==========');

  const testCases = [
    {
      name: '正常手牌',
      hand: '上丘乙己化三尔小生八九十土',
      melds: []
    },
    {
      name: '有组合牌',
      hand: '丘乙己化三尔小生八九十土',
      melds: [{ type: 'sequence', cards: createHand('上大大'), huValue: 0 }]
    },
    {
      name: '有碰牌',
      hand: '丘乙己化三尔小生八九十土',
      melds: [{ type: 'triplet', cards: createHand('七七七'), huValue: 2 }]
    },
    {
      name: '多组合牌',
      hand: '丘乙己化三尔小生八九十土',
      melds: [
        { type: 'sequence', cards: createHand('上大大'), huValue: 0 },
        { type: 'triplet', cards: createHand('七七七'), huValue: 2 }
      ]
    },
    {
      name: '听牌状态',
      hand: '上丘乙己化三尔小生八九十',
      melds: [{ type: 'triplet', cards: createHand('土土土'), huValue: 2 }]
    },
    {
      name: '大量手牌',
      hand: '上上丘丘乙乙己己化三尔尔小生生',
      melds: []
    },
    {
      name: '全不同字',
      hand: '上大人丘乙己化三千七',
      melds: []
    },
    {
      name: '全同字',
      hand: '上上上上丘丘丘丘乙乙乙乙己',
      melds: []
    }
  ];

  let passed = 0;
  let failed = 0;

  for (const tc of testCases) {
    try {
      console.log(`\n测试: ${tc.name}`);
      console.log(`手牌: ${tc.hand}`);

      const player = {
        name: 'AI测试玩家',
        hand: createHand(tc.hand),
        melds: tc.melds,
        discards: [],
        isTing: false
      };

      // 模拟其他玩家的状态
      gameState.players = [
        player,
        { name: '对手1', hand: createHand('福禄寿丘乙己化三千'), discards: [], melds: [], isTing: false },
        { name: '对手2', hand: createHand('七八九十土尔小生八'), discards: [], melds: [], isTing: false }
      ];
      gameState.deck = Array(50).fill(null).map(() => ({
        character: '上',
        id: Math.random().toString(36).substr(2, 9)
      }));

      // 测试selectAIDiscardHard
      const result = await withTimeout(() => {
        const index = selectAIDiscardHard(player);
        return index;
      }, 3000, `selectAIDiscardHard(${tc.name})`);

      console.log(`选择出牌索引: ${result}, 牌: ${player.hand[result]?.character}`);
      passed++;
      console.log(`✓ ${tc.name} 测试通过`);

    } catch (e) {
      failed++;
      console.log(`✗ ${tc.name} 测试失败: ${e.message}`);
    }
  }

  return { passed, failed };
}

// 测试AI吃牌判断
async function testAIChi() {
  console.log('\n========== 测试AI吃牌判断 ==========');

  const testCases = [
    {
      name: '可以吃-普通',
      hand: '上丘乙己化三尔小生八九十土',
      card: '大',
      expected: true
    },
    {
      name: '可以吃-特殊句',
      hand: '上丘乙己化三尔小生八九十土',
      card: '人',
      expected: true
    },
    {
      name: '不能吃-缺牌',
      hand: '上丘己化三尔小生八九十土',
      card: '大',
      expected: false
    },
    {
      name: '可以吃-第二句',
      hand: '上丘乙己化三尔小生八九十土',
      card: '乙',
      expected: true
    }
  ];

  let passed = 0;
  let failed = 0;

  for (const tc of testCases) {
    try {
      console.log(`\n测试: ${tc.name}`);
      console.log(`手牌: ${tc.hand}, 吃的牌: ${tc.card}`);

      const player = {
        name: 'AI测试玩家',
        hand: createHand(tc.hand),
        melds: []
      };

      const card = createCard(tc.card);
      card.id = Math.random().toString(36).substr(2, 9);

      gameState.players = [player];
      gameState.currentPlayerIndex = 0;

      const result = await withTimeout(() => {
        return shouldAIChi(player, card);
      }, 2000, `shouldAIChi(${tc.name})`);

      const status = result === tc.expected ? 'pass' : 'fail';
      if (status === 'pass') {
        passed++;
        console.log(`✓ ${tc.name} 测试通过 (结果: ${result})`);
      } else {
        failed++;
        console.log(`✗ ${tc.name} 测试失败 (预期: ${tc.expected}, 实际: ${result})`);
      }

    } catch (e) {
      failed++;
      console.log(`✗ ${tc.name} 测试失败: ${e.message}`);
    }
  }

  return { passed, failed };
}

// 测试AI碰牌判断
async function testAIPeng() {
  console.log('\n========== 测试AI碰牌判断 ==========');

  const testCases = [
    {
      name: '可以碰',
      hand: '上丘乙己化三尔小生八九十土',
      card: '上',
      expected: true
    },
    {
      name: '不能碰-只有1张',
      hand: '上丘乙己化三尔小生八九十土',
      card: '大',
      expected: false
    },
    {
      name: '可以碰-精牌',
      hand: '上丘乙己化三尔小生八九十土',
      card: '福',
      expected: true
    }
  ];

  let passed = 0;
  let failed = 0;

  for (const tc of testCases) {
    try {
      console.log(`\n测试: ${tc.name}`);
      console.log(`手牌: ${tc.hand}, 碰的牌: ${tc.card}`);

      const player = {
        name: 'AI测试玩家',
        hand: createHand(tc.hand),
        melds: []
      };

      const card = createCard(tc.card);
      card.id = Math.random().toString(36).substr(2, 9);

      gameState.players = [player];
      gameState.currentPlayerIndex = 0;

      const result = await withTimeout(() => {
        return shouldAIPeng(player, card);
      }, 2000, `shouldAIPeng(${tc.name})`);

      const status = result === tc.expected ? 'pass' : 'fail';
      if (status === 'pass') {
        passed++;
        console.log(`✓ ${tc.name} 测试通过 (结果: ${result})`);
      } else {
        failed++;
        console.log(`✗ ${tc.name} 测试失败 (预期: ${tc.expected}, 实际: ${result})`);
      }

    } catch (e) {
      failed++;
      console.log(`✗ ${tc.name} 测试失败: ${e.message}`);
    }
  }

  return { passed, failed };
}

// 测试AI招牌判断
async function testAIZhao() {
  console.log('\n========== 测试AI招牌判断 ==========');

  const testCases = [
    {
      name: '可以招牌-3张',
      hand: '上上上丘乙己化三尔小生八九十',
      card: '上',
      expected: true
    },
    {
      name: '不能招牌-只有2张',
      hand: '上上丘乙己化三尔小生八九十土',
      card: '上',
      expected: false
    },
    {
      name: '可以招牌-4张',
      hand: '上上上上丘乙己化三尔小生八',
      card: '上',
      expected: true
    }
  ];

  let passed = 0;
  let failed = 0;

  for (const tc of testCases) {
    try {
      console.log(`\n测试: ${tc.name}`);
      console.log(`手牌: ${tc.hand}, 招牌: ${tc.card}`);

      const player = {
        name: 'AI测试玩家',
        hand: createHand(tc.hand),
        melds: []
      };

      const card = createCard(tc.card);
      card.id = Math.random().toString(36).substr(2, 9);

      gameState.players = [player];
      gameState.currentPlayerIndex = 0;

      const result = await withTimeout(() => {
        return shouldAIZhao(player, card);
      }, 2000, `shouldAIZhao(${tc.name})`);

      console.log(`结果: ${result}`);

    } catch (e) {
      failed++;
      console.log(`✗ ${tc.name} 测试失败: ${e.message}`);
    }
  }

  return { passed, failed };
}

// 测试增强版危险牌检测
async function testDangerousCardDetection() {
  console.log('\n========== 测试增强版危险牌检测 ==========');

  const testCases = [
    {
      name: '对手听牌-危险牌',
      hand: '上丘乙己化三尔小生八九十土',
      opponentTing: true,
      opponentTingCards: ['上', '大', '人'],
      card: '上',
      expectDangerous: true
    },
    {
      name: '对手听牌-安全牌',
      hand: '上丘乙己化三尔小生八九十土',
      opponentTing: true,
      opponentTingCards: ['七', '八', '九'],
      card: '上',
      expectDangerous: false
    },
    {
      name: '牌池已空-安全',
      hand: '上丘乙己化三尔小生八九十土',
      opponentTing: true,
      opponentTingCards: ['上'],
      card: '上',
      globalDiscards: ['上', '上', '上', '上'],
      expectDangerous: false
    }
  ];

  let passed = 0;
  let failed = 0;

  for (const tc of testCases) {
    try {
      console.log(`\n测试: ${tc.name}`);

      const player = {
        name: 'AI测试玩家',
        hand: createHand(tc.hand),
        melds: []
      };

      const opponent = {
        name: '对手',
        hand: createHand('福禄寿丘乙己化三千'),
        discards: tc.globalDiscards || [],
        melds: [],
        isTing: tc.opponentTing
      };

      const card = createCard(tc.card);
      card.id = Math.random().toString(36).substr(2, 9);

      gameState.players = [
        player,
        opponent,
        { name: '对手2', hand: [], discards: [], melds: [], isTing: false }
      ];
      gameState.currentPlayerIndex = 0;

      const result = await withTimeout(() => {
        const dangerScore = checkDangerousCardEnhanced(card, player.hand, player);
        return dangerScore;
      }, 2000, `checkDangerousCardEnhanced(${tc.name})`);

      const isDangerous = result < 0;
      const status = isDangerous === tc.expectDangerous ? 'pass' : 'fail';

      if (status === 'pass') {
        passed++;
        console.log(`✓ ${tc.name} 测试通过 (危险分数: ${result})`);
      } else {
        failed++;
        console.log(`✗ ${tc.name} 测试失败 (预期危险: ${tc.expectDangerous}, 实际危险: ${isDangerous}, 分数: ${result})`);
      }

    } catch (e) {
      failed++;
      console.log(`✗ ${tc.name} 测试失败: ${e.message}`);
    }
  }

  return { passed, failed };
}

// 模拟多轮游戏测试
async function testMultipleRounds() {
  console.log('\n========== 模拟多轮游戏测试 ==========');

  initGameState();

  const maxRounds = 50;
  let round = 0;
  let maxTurnsPerRound = 20;
  let totalTurns = 0;

  try {
    while (round < maxRounds && !gameState.isGameOver) {
      round++;

      console.log(`\n--- 第${round}轮 ---`);

      // 设置随机玩家为当前玩家
      gameState.currentPlayerIndex = round % 4;

      const currentPlayer = gameState.players[gameState.currentPlayerIndex];

      // 如果手牌为空或极少，补充手牌
      while (currentPlayer.hand.length < 8) {
        if (gameState.deck.length === 0) {
          gameState.isGameOver = true;
          break;
        }
        currentPlayer.hand.push(gameState.deck.pop());
      }

      if (currentPlayer.hand.length === 0) {
        break;
      }

      // 模拟多回合
      let turns = 0;
      while (turns < maxTurnsPerRound && currentPlayer.hand.length > 0) {
        turns++;
        totalTurns++;

        // 模拟AI出牌
        const discardIndex = await withTimeout(() => {
          return selectAIDiscardHard(currentPlayer);
        }, 3000, `第${round}轮第${turns}回合出牌`);

        if (discardIndex < 0 || discardIndex >= currentPlayer.hand.length) {
          console.log(`警告: 出牌索引${discardIndex}无效，手牌长度${currentPlayer.hand.length}`);
          break;
        }

        const discardedCard = currentPlayer.hand.splice(discardIndex, 1)[0];
        currentPlayer.discards.push(discardedCard);
        gameState.lastDiscardedCard = discardedCard;

        console.log(`${currentPlayer.name} 出牌: ${discardedCard.character} (回合${turns})`);

        // 检查是否有人胡牌
        if (totalTurns > 100) {
          console.log('达到最大回合数，退出测试');
          break;
        }

        // 摸牌
        if (gameState.deck.length > 0 && currentPlayer.hand.length < 16) {
          currentPlayer.hand.push(gameState.deck.pop());
        }

        if (gameState.deck.length === 0) {
          console.log('牌堆已空');
          break;
        }
      }

      console.log(`第${round}轮完成，执行了${turns}回合`);
    }

    console.log(`\n✓ 多轮游戏测试完成: ${round}轮, ${totalTurns}回合`);
    return { passed: 1, failed: 0, rounds: round, turns: totalTurns };

  } catch (e) {
    console.log(`\n✗ 多轮游戏测试失败: ${e.message}`);
    return { passed: 0, failed: 1, error: e.message };
  }
}

// 辅助函数
function createCard(char) {
  const info = getSentenceInfo(char);
  return {
    character: char,
    sentence: info.sentence,
    position: info.position,
    color: info.color,
    id: Math.random().toString(36).substr(2, 9)
  };
}

function createHand(chars) {
  return chars.split('').map(c => createCard(c));
}

// 主测试函数
async function runAllTests() {
  console.log('========================================');
  console.log('  困难模式AI自动化测试');
  console.log('========================================');
  console.log(`开始时间: ${new Date().toLocaleTimeString()}`);

  let totalPassed = 0;
  let totalFailed = 0;

  try {
    // 测试AI出牌
    const discardResult = await testAIDiscard();
    totalPassed += discardResult.passed;
    totalFailed += discardResult.failed;

    // 测试AI吃牌
    const chiResult = await testAIChi();
    totalPassed += chiResult.passed;
    totalFailed += chiResult.failed;

    // 测试AI碰牌
    const pengResult = await testAIPeng();
    totalPassed += pengResult.passed;
    totalFailed += pengResult.failed;

    // 测试AI招牌
    const zhaoResult = await testAIZhao();
    totalPassed += zhaoResult.passed;
    totalFailed += zhaoResult.failed;

    // 测试危险牌检测
    const dangerResult = await testDangerousCardDetection();
    totalPassed += dangerResult.passed;
    totalFailed += dangerResult.failed;

    // 多轮游戏测试
    const multiResult = await testMultipleRounds();
    totalPassed += multiResult.passed;
    totalFailed += multiResult.failed;

  } catch (e) {
    console.log(`\n测试过程出错: ${e.message}`);
    console.log(e.stack);
  }

  console.log('\n========================================');
  console.log('  测试结果汇总');
  console.log('========================================');
  console.log(`通过: ${totalPassed}`);
  console.log(`失败: ${totalFailed}`);
  console.log(`总计: ${totalPassed + totalFailed}`);
  console.log(`结束时间: ${new Date().toLocaleTimeString()}`);

  if (totalFailed === 0) {
    console.log('\n✓ 所有测试通过！AI未发现卡死问题。');
  } else {
    console.log(`\n✗ 有${totalFailed}项测试失败，请检查。`);
  }

  return { passed: totalPassed, failed: totalFailed };
}

// 导出测试函数
if (typeof module !== 'undefined' && module.exports) {
  module.exports = { runAllTests, testAIDiscard, testAIChi, testAIPeng, testAIZhao, testDangerousCardDetection, testMultipleRounds };
} else {
  window.runAllTests = runAllTests;
  window.testAIDiscard = testAIDiscard;
  window.testAIChi = testAIChi;
  window.testAIPeng = testAIPeng;
  window.testAIZhao = testAIZhao;
  window.testDangerousCardDetection = testDangerousCardDetection;
  window.testMultipleRounds = testMultipleRounds;
}
