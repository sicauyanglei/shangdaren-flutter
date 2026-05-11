// 困难模式胡牌效率专项测试
// 测试AI玩家的胡牌率、自摸率、点炮率等指标

const gameSettings = {
  difficulty: 'hard'
};

let gameState = {
  players: [],
  deck: [],
  currentPlayerIndex: 0,
  lastDiscardedCard: null,
  lastDiscardPlayerIndex: -1,
  isGameOver: false
};

// 统计结果
const stats = {
  totalGames: 0,
  AIWinGames: 0,       // AI总胡牌次数
  humanWinGames: 0,    // 人类胡牌次数
  AIPais: 0,           // AI点炮次数
  humanPais: 0,        // 人类点炮次数
  totalZimo: 0,        // 总自摸次数
  totalDianpao: 0,     // 总点炮次数
  aiWinByZimo: 0,      // AI自摸次数
  aiWinByPai: 0,       // AI点炮胡次数
  huRates: [],          // 每局AI的胡牌率
  turnsToHu: [],        // 胡牌所需回合数
  huCounts: []          // AI累计胡数
};

// 初始化游戏
function initGame() {
  const ALL_CHARACTERS = ['上', '大', '人', '丘', '乙', '己', '化', '三', '千', '七', '十', '土', '尔', '小', '生', '八', '九', '子', '佳', '作', '亡', '福', '禄', '寿'];

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

  shuffleArray(deck);

  const playerNames = ['AI-0', '人类', 'AI-1', 'AI-2'];
  gameState.players = playerNames.map((name, index) => ({
    name,
    hand: [],
    discards: [],
    melds: [],
    isTing: false,
    isAI: index !== 1,
    piao: 0,
    huCount: 0
  }));

  for (let i = 0; i < 16; i++) {
    for (let p = 0; p < 4; p++) {
      if (deck.length > 0) {
        gameState.players[p].hand.push(deck.pop());
      }
    }
  }

  gameState.deck = deck;
  gameState.currentPlayerIndex = Math.floor(Math.random() * 4);
  gameState.isGameOver = false;
  gameState.lastDiscardedCard = null;
  gameState.lastDiscardPlayerIndex = -1;
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

// 模拟一局游戏
async function simulateGame(gameNum) {
  initGame();
  let turn = 0;
  const maxTurns = 200;
  let huOccurred = false;
  let huPlayer = -1;
  let huType = '';
  let huCard = null;

  while (!gameState.isGameOver && turn < maxTurns) {
    turn++;

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

    // AI玩家摸牌
    if (!currentPlayer.isAI && gameState.deck.length > 0) {
      currentPlayer.hand.push(gameState.deck.pop());
    }

    // 检查自摸
    const huResult = checkHu(currentPlayer);
    if (huResult.canHu) {
      huOccurred = true;
      huPlayer = gameState.currentPlayerIndex;
      huType = 'zimo';
      stats.totalZimo++;
      if (currentPlayer.isAI) {
        stats.AIWinGames++;
        stats.aiWinByZimo++;
        stats.turnsToHu.push(turn);
        stats.huCounts.push(huResult.huCount);
      } else {
        stats.humanWinGames++;
      }
      break;
    }

    // AI出牌
    if (currentPlayer.isAI) {
      const discardIndex = selectAIDiscard(currentPlayer);
      if (discardIndex < 0 || discardIndex >= currentPlayer.hand.length) {
        moveToNextPlayer();
        continue;
      }
      const discardedCard = currentState.hand.splice(discardIndex, 1)[0];
      currentPlayer.discards.push(discardedCard);
      gameState.lastDiscardedCard = discardedCard;
      gameState.lastDiscardPlayerIndex = gameState.currentPlayerIndex;

      // 检查其他玩家是否可以胡（点炮）
      for (let i = 0; i < 4; i++) {
        if (i === gameState.lastDiscardPlayerIndex) continue;
        const otherPlayer = gameState.players[i];
        const otherHuResult = checkHu(otherPlayer, discardedCard, true);
        if (otherPlayer.isTing && otherHuResult.canHu) {
          huOccurred = true;
          huPlayer = i;
          huType = 'dianpao';
          stats.totalDianpao++;
          if (otherPlayer.isAI) {
            stats.AIWinGames++;
            stats.aiWinByPai++;
            stats.AIPais++;
            stats.turnsToHu.push(turn);
            stats.huCounts.push(otherHuResult.huCount);
          } else {
            stats.humanWinGames++;
            stats.humanPais++;
          }
          break;
        }
      }
      if (huOccurred) break;
    }

    moveToNextPlayer();
  }

  stats.totalGames++;

  if (gameNum % 100 === 0) {
    printStats(gameNum);
  }

  return { huOccurred, huPlayer, huType, turn };
}

function moveToNextPlayer() {
  gameState.currentPlayerIndex = (gameState.currentPlayerIndex + 1) % 4;
}

function printStats(gameNum) {
  const aiWinRate = stats.totalGames > 0 ? (stats.AIWinGames / stats.totalGames * 100).toFixed(1) : 0;
  const avgTurns = stats.turnsToHu.length > 0 ? (stats.turnsToHu.reduce((a, b) => a + b, 0) / stats.turnsToHu.length).toFixed(1) : 0;
  const avgHuCount = stats.huCounts.length > 0 ? (stats.huCounts.reduce((a, b) => a + b, 0) / stats.huCounts.length).toFixed(1) : 0;
  const zimoRate = stats.AIWinGames > 0 ? (stats.aiWinByZimo / stats.AIWinGames * 100).toFixed(1) : 0;
  const paiRate = stats.totalGames > 0 ? (stats.AIPais / stats.totalGames * 100).toFixed(1) : 0;

  console.log('\n========== 游戏局数:', gameNum, '==========');
  console.log('AI胡牌率:', aiWinRate + '%', '(' + stats.AIWinGames + '/' + stats.totalGames + ')');
  console.log('AI自摸率:', zimoRate + '%', '(' + stats.aiWinByZimo + '/' + stats.AIWinGames + ')');
  console.log('AI点炮率:', paiRate + '%', '(' + stats.AIPais + '/' + stats.totalGames + ')');
  console.log('平均胡牌回合:', avgTurns);
  console.log('平均胡数:', avgHuCount);
  console.log('人类胡牌:', stats.humanWinGames);
}

// 简化版的AI出牌（用于测试）
function selectAIDiscard(player) {
  if (gameSettings.difficulty === 'hard' && typeof selectAIDiscardHard === 'function') {
    return selectAIDiscardHard(player);
  }

  // 默认随机出牌
  return Math.floor(Math.random() * player.hand.length);
}

// 简化版的胡牌检测
function checkHu(player, extraCard = null, isDianPao = false) {
  const hand = [...(player.hand || [])];
  if (extraCard) hand.push(extraCard);
  const melds = player.melds || [];

  if (hand.length < 2) return { canHu: false, huCount: 0, huType: { type: 'none', name: '无' } };

  // 简单检测：手牌是否为完整句子组合
  const counts = {};
  for (const card of hand) {
    counts[card.character] = (counts[card.character] || 0) + 1;
  }

  // 检查是否能胡（简化版）
  let pairs = 0;
  let singles = 0;
  for (const count of Object.values(counts)) {
    if (count === 2) pairs++;
    else if (count === 1) singles++;
  }

  // 简单判断：2个对子+一些单牌可能可以胡
  if (pairs >= 1 && singles <= 4) {
    const huCount = calculateSimpleHuCount(hand, melds);
    return {
      canHu: huCount >= 11 || isSpecialHu(hand),
      huCount: huCount,
      huType: getSimpleHuType(hand, melds)
    };
  }

  return { canHu: false, huCount: 0, huType: { type: 'none', name: '无' } };
}

function calculateSimpleHuCount(hand, melds) {
  let count = 0;
  for (const meld of melds) {
    count += meld.huValue || 0;
  }
  return Math.min(count, 30);
}

function isSpecialHu(hand) {
  return false;
}

function getSimpleHuType(hand, melds) {
  return { type: 'normal', name: '普通胡' };
}

// 运行测试
async function runTest(numGames = 1000) {
  console.log('========================================');
  console.log('  困难模式胡牌效率专项测试');
  console.log('========================================');
  console.log('测试局数:', numGames);
  console.log('开始时间:', new Date().toLocaleTimeString());

  for (let i = 1; i <= numGames; i++) {
    await simulateGame(i);

    if (i % 500 === 0) {
      await new Promise(resolve => setTimeout(resolve, 10));
    }
  }

  console.log('\n========================================');
  console.log('  最终测试结果');
  console.log('========================================');
  printStats(numGames);
  console.log('结束时间:', new Date().toLocaleTimeString());

  return stats;
}

// 导出
if (typeof module !== 'undefined' && module.exports) {
  module.exports = { runTest, stats };
} else {
  window.runTest = runTest;
  window.stats = stats;
}
