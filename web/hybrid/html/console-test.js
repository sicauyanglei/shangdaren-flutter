// 困难模式胡牌效率测试 - 控制台版本
// 使用方法：在浏览器控制台中粘贴此代码并执行

(function() {
  const TEST_GAMES = 1000;

  const stats = {
    totalGames: 0,
    AIWinGames: 0,
    humanWinGames: 0,
    AIPais: 0,
    humanPais: 0,
    aiWinByZimo: 0,
    aiWinByPai: 0,
    totalZimo: 0,
    totalDianpao: 0,
    turnsToHu: [],
    huCounts: []
  };

  // 复制game.js中的辅助函数
  function getSentenceInfo(char) {
    const cardMap = {
      '上': { sentence: 1, position: 0 }, '大': { sentence: 1, position: 1 }, '人': { sentence: 1, position: 2 },
      '丘': { sentence: 2, position: 0 }, '乙': { sentence: 2, position: 1 }, '己': { sentence: 2, position: 2 },
      '化': { sentence: 3, position: 0 }, '三': { sentence: 3, position: 1 }, '千': { sentence: 3, position: 2 },
      '七': { sentence: 4, position: 0 }, '十': { sentence: 4, position: 1 }, '土': { sentence: 4, position: 2 },
      '尔': { sentence: 5, position: 0 }, '小': { sentence: 5, position: 1 }, '生': { sentence: 5, position: 2 },
      '八': { sentence: 6, position: 0 }, '九': { sentence: 6, position: 1 }, '子': { sentence: 6, position: 2 },
      '佳': { sentence: 7, position: 0 }, '作': { sentence: 7, position: 1 }, '亡': { sentence: 7, position: 2 },
      '福': { sentence: 8, position: 0 }, '禄': { sentence: 8, position: 1 }, '寿': { sentence: 8, position: 2 }
    };
    return cardMap[char] || { sentence: 0, position: 0 };
  }

  function shuffle(arr) {
    for (let i = arr.length - 1; i > 0; i--) {
      const j = Math.floor(Math.random() * (i + 1));
      [arr[i], arr[j]] = [arr[j], arr[i]];
    }
    return arr;
  }

  function initGame() {
    const CHARS = ['上','大','人','丘','乙','己','化','三','千','七','十','土','尔','小','生','八','九','子','佳','作','亡','福','禄','寿'];
    const deck = [];
    for (const c of CHARS) {
      for (let i = 0; i < 4; i++) {
        deck.push({ character: c, sentence: getSentenceInfo(c).sentence, position: getSentenceInfo(c).position, id: Math.random().toString(36).substr(2,9) });
      }
    }
    shuffle(deck);

    const names = ['AI-0', '人类', 'AI-1', 'AI-2'];
    const gs = window.gameState;
    gs.players = names.map((n, idx) => ({
      name: n, hand: [], discards: [], melds: [], isTing: false, isAI: idx !== 1, piao: 0
    }));

    for (let i = 0; i < 16; i++) {
      for (let p = 0; p < 4; p++) {
        if (deck.length > 0) gs.players[p].hand.push(deck.pop());
      }
    }

    gs.deck = deck;
    gs.currentPlayerIndex = Math.floor(Math.random() * 4);
    gs.isGameOver = false;
    gs.lastDiscardedCard = null;
    gs.lastDiscardPlayerIndex = -1;

    for (const p of gs.players) {
      const r = window.checkTing(p);
      p.isTing = r.isTing;
    }
  }

  function doTurn() {
    const gs = window.gameState;
    const p = gs.players[gs.currentPlayerIndex];

    if (gs.deck.length > 0) {
      p.hand.push(gs.deck.pop());
      const r = window.checkTing(p);
      p.isTing = r.isTing;
    }

    const hr = window.checkHu(p);
    if (hr.canHu) {
      return { end: true, winner: gs.currentPlayerIndex, type: 'zimo', hu: hr };
    }

    if (p.isAI) {
      const idx = window.selectAIDiscard(p);
      if (idx >= 0 && idx < p.hand.length) {
        const card = p.hand.splice(idx, 1)[0];
        p.discards.push(card);
        gs.lastDiscardedCard = card;
        gs.lastDiscardPlayerIndex = gs.currentPlayerIndex;

        for (let i = 0; i < 4; i++) {
          if (i === gs.lastDiscardPlayerIndex) continue;
          const op = gs.players[i];
          const hr2 = window.checkHu(op, card, true);
          if (op.isTing && hr2.canHu) {
            return { end: true, winner: i, type: 'dianpao', loser: gs.currentPlayerIndex, hu: hr2 };
          }
        }
      }
    }

    gs.currentPlayerIndex = (gs.currentPlayerIndex + 1) % 4;
    return { end: false };
  }

  function printStats() {
    console.log('\n========== 测试结果 ==========');
    console.log('总局数:', stats.totalGames);
    console.log('AI胡牌率:', (stats.AIWinGames / stats.totalGames * 100).toFixed(1) + '%', '(' + stats.AIWinGames + '/' + stats.totalGames + ')');
    console.log('AI自摸率:', (stats.AIWinGames > 0 ? stats.aiWinByZimo / stats.AIWinGames * 100 : 0).toFixed(1) + '%');
    console.log('AI点炮率:', (stats.totalGames > 0 ? stats.AIPais / stats.totalGames * 100 : 0).toFixed(1) + '%');
    console.log('平均胡牌回合:', (stats.turnsToHu.length > 0 ? stats.turnsToHu.reduce((a,b)=>a+b,0) / stats.turnsToHu.length : 0).toFixed(1));
    console.log('平均胡数:', (stats.huCounts.length > 0 ? stats.huCounts.reduce((a,b)=>a+b,0) / stats.huCounts.length : 0).toFixed(1));
    console.log('人类胡牌:', stats.humanWinGames);
    console.log('人类点炮AI:', stats.humanPais);
    console.log('=============================\n');
  }

  async function runTests(games) {
    console.log('开始测试 ' + games + ' 局困难模式胡牌效率...');
    const startTime = Date.now();

    for (let i = 0; i < games; i++) {
      initGame();
      let turn = 0;
      while (turn < 200) {
        turn++;
        const result = doTurn();
        if (result.end) {
          if (result.type === 'zimo') {
            stats.totalZimo++;
            if (result.winner !== 1) {
              stats.AIWinGames++;
              stats.aiWinByZimo++;
              stats.turnsToHu.push(turn);
              stats.huCounts.push(result.hu.huCount);
            } else {
              stats.humanWinGames++;
            }
          } else {
            stats.totalDianpao++;
            if (result.winner !== 1) {
              stats.AIWinGames++;
              stats.aiWinByPai++;
              stats.AIPais++;
              stats.turnsToHu.push(turn);
              stats.huCounts.push(result.hu.huCount);
            } else {
              stats.humanWinGames++;
              stats.humanPais++;
            }
          }
          stats.totalGames++;
          break;
        }
      }

      if (stats.totalGames % 100 === 0) {
        console.log('已完成:', stats.totalGames, '局');
        printStats();
      }
    }

    const elapsed = ((Date.now() - startTime) / 1000).toFixed(1);
    console.log('\n测试完成! 耗时:', elapsed, '秒');
    printStats();
  }

  // 导出到window
  window.huTest = { run: runTests, stats };

  console.log('胡牌效率测试已加载! 使用 huTest.run(1000) 开始测试1000局');
})();
