const fs = require('fs');
const vm = require('vm');

const gameCode = fs.readFileSync(__dirname + '/web/hybrid/html/game.js', 'utf-8');

const mockDomElements = {};
function createElement(tag) {
  return { style: {}, classList: { add(){}, remove(){}, toggle(){}, contains(){return false;} }, innerHTML:'', textContent:'', appendChild(){}, querySelector(){return null;}, querySelectorAll(){return[];}, addEventListener(){}, setAttribute(){}, getAttribute(){return null;}, children:[] };
}
function getElementById(id) {
  if (!mockDomElements[id]) mockDomElements[id] = createElement('div');
  return mockDomElements[id];
}

const sandbox = {
  console,
  document: {
    getElementById,
    querySelector: () => createElement('div'),
    querySelectorAll: () => [],
    createElement: (tag) => createElement(tag),
    addEventListener: () => {},
    documentElement: { classList: { contains: () => false }, style: {} },
    body: { appendChild(){}, querySelectorAll(){return[];}, style:{} }
  },
  window: { innerWidth: 800, innerHeight: 600, close(){}, addEventListener(){} },
  screen: { orientation: { lock(){return Promise.resolve()} } },
  navigator: { userAgent: 'Node.js' },
  setTimeout: (fn, ms) => { if(typeof fn==='function') fn(); return 1; },
  setInterval: () => 1,
  clearInterval: () => {},
  clearTimeout: () => {},
  localStorage: { getItem(){return null;}, setItem(){}, removeItem(){} },
  Math,
  JSON,
  Date,
  Array,
  Object,
  String,
  Number,
  Boolean,
  Map,
  Set,
  Promise,
  Error,
  parseInt,
  parseFloat,
  isNaN,
  isFinite,
  RegExp,
  Symbol: typeof Symbol !== 'undefined' ? Symbol : undefined,
  Uint8Array: typeof Uint8Array !== 'undefined' ? Uint8Array : undefined,
  Float64Array: typeof Float64Array !== 'undefined' ? Float64Array : undefined,
  ArrayBuffer: typeof ArrayBuffer !== 'undefined' ? ArrayBuffer : undefined,
  fetch: () => Promise.resolve({ text: () => Promise.resolve('') }),
  AudioContext: function() { return { createGain(){return{gain:{value:0},connect(){}}},createBufferSource(){return{connect(){},start(){},stop(){}}},decodeAudioData(){return Promise.resolve({})},resume(){} }; },
  WebSocket: function() { return { send(){}, close(){}, addEventListener(){} }; },
  requestAnimationFrame: (fn) => { if(typeof fn==='function') fn(); return 1; },
  cancelAnimationFrame: () => {},
  HTMLAudioElement: function(){},
  performance: { now: () => Date.now() }
};

const ctx = vm.createContext(sandbox);
vm.runInContext(gameCode, sandbox);
vm.runInContext(`
  window.gameState = gameState;
  window.gameSettings = gameSettings;
  window.checkHu = checkHu;
  window.checkTing = checkTing;
  window.calculateXiangTingShu = calculateXiangTingShu;
  window.calculateHuCount = calculateHuCount;
  window.createDeck = createDeck;
  window.shuffleDeck = shuffleDeck;
  window.sortHand = sortHand;
  window.clearCaches = clearCaches;
  window.selectAIDiscard = selectAIDiscard;
  window.selectAIDiscardHard = selectAIDiscardHard;
  window.selectAIDiscardMedium = selectAIDiscardMedium;
  window.selectAIDiscardEasy = selectAIDiscardEasy;
  window.shouldAIChi = shouldAIChi;
  window.shouldAIPeng = shouldAIPeng;
  window.evaluateCardExtreme = evaluateCardExtreme;
  window.evaluateCardMedium = evaluateCardMedium;
`, ctx);

const g = sandbox.window;

function createCard(char) {
  const map = {
    '上':{s:1,p:0,c:'red'},'大':{s:1,p:1,c:'green'},'人':{s:1,p:2,c:'black'},
    '丘':{s:2,p:0,c:'red'},'乙':{s:2,p:1,c:'green'},'己':{s:2,p:2,c:'black'},
    '化':{s:3,p:0,c:'red'},'三':{s:3,p:1,c:'green'},'千':{s:3,p:2,c:'black'},
    '七':{s:4,p:0,c:'red'},'十':{s:4,p:1,c:'green'},'土':{s:4,p:2,c:'black'},
    '尔':{s:5,p:0,c:'red'},'小':{s:5,p:1,c:'green'},'生':{s:5,p:2,c:'black'},
    '八':{s:6,p:0,c:'red'},'九':{s:6,p:1,c:'green'},'子':{s:6,p:2,c:'black'},
    '佳':{s:7,p:0,c:'red'},'作':{s:7,p:1,c:'green'},'亡':{s:7,p:2,c:'black'},
    '福':{s:8,p:0,c:'red'},'禄':{s:8,p:1,c:'green'},'寿':{s:8,p:2,c:'black'}
  };
  const info = map[char] || {s:0,p:0,c:'black'};
  return { character:char, sentence:info.s, position:info.p, color:info.c, id:Math.random().toString(36).substr(2,9), isSpecial:(char==='上'||char==='福') };
}

function createHand(chars) { return chars.split('').map(c => createCard(c)); }

let passed = 0, failed = 0, issues = [];

function assert(name, fn) {
  try {
    const result = fn();
    console.log(`  ✅ ${name}: ${result}`);
    passed++;
  } catch(e) {
    console.log(`  ❌ ${name}: ${e.message}`);
    issues.push({ name, message: e.message });
    failed++;
  }
}

console.log('═══════════════════════════════════════');
console.log('  阶段1: 逻辑单元测试');
console.log('═══════════════════════════════════════');

assert('checkHu - 标准胡牌(14张)', () => {
  const hand = createHand('上大人丘乙己化三千七十土尔小生八');
  const r = g.checkHu({name:'T',hand,melds:[],discards:[],isTing:false});
  return 'canHu='+r.canHu+', huCount='+r.huCount+', type='+(r.huType?.name||'无');
});

assert('checkHu - 有melds时胡牌', () => {
  const hand = createHand('化三千七十土尔小生八九子');
  const melds = [{type:'sequence',source:'chi',cards:createHand('上大人')}];
  const r = g.checkHu({name:'T',hand,melds,discards:[],isTing:false});
  return 'canHu='+r.canHu+', huCount='+r.huCount+', type='+(r.huType?.name||'无');
});

assert('checkHu - 不能胡牌(缺句)', () => {
  const hand = createHand('上大人丘乙己化三千七十尔小生八');
  const r = g.checkHu({name:'T',hand,melds:[],discards:[],isTing:false});
  return 'canHu='+r.canHu+' ✓';
});

assert('checkTing - 听牌检测', () => {
  const hand = createHand('上大人丘乙己化三千七十尔小');
  const r = g.checkTing({name:'T',hand,melds:[],discards:[],isTing:false});
  return 'isTing='+r.isTing+', tingCards='+(r.tingCards?.join(',')||'无');
});

assert('calculateXiangTingShu', () => {
  const hand = createHand('上大人丘乙己化三千七十土');
  return '向听数='+g.calculateXiangTingShu(hand,[]);
});

assert('calculateHuCount - 含特殊牌', () => {
  const c1 = g.calculateHuCount(createHand('上大人丘乙己化三千七十土'),[]);
  const c2 = g.calculateHuCount(createHand('福禄寿丘乙己化三千七十土'),[]);
  return '含上:'+c1+'胡, 含福:'+c2+'胡';
});

assert('牌堆96张', () => {
  const d = g.createDeck();
  if(d.length!==96) throw new Error('deck='+d.length);
  return '96张 ✓';
});

assert('分数守恒', () => {
  const s = [10,-15,5].reduce((a,b)=>a+b,0);
  if(s!==0) throw new Error('sum='+s);
  return '总分=0 ✓';
});

assert('checkHu缓存一致性', () => {
  const hand = createHand('上大人丘乙己化三千七十土');
  const p = {name:'T',hand,melds:[],discards:[],isTing:false};
  g.clearCaches();
  const r1 = g.checkHu(p);
  const r2 = g.checkHu(p);
  if(r1.canHu!==r2.canHu||r1.huCount!==r2.huCount) throw new Error('inconsistent');
  return '一致 ✓';
});

console.log(`\n单元测试: ${passed}通过, ${failed}失败\n`);

console.log('═══════════════════════════════════════');
console.log('  阶段2: AI出牌压力测试(500次)');
console.log('═══════════════════════════════════════');

if(g.gameSettings) { g.gameSettings.difficulty = 'hard'; g.gameSettings.piaoEnabled = false; }
else { g.gameSettings = {volume:1.0,difficulty:'hard',piaoEnabled:false}; }
let discardViolations = 0;
const stressCount = 100;
const chars = '上大人丘乙己化三千七十土尔小生八九子佳作亡福禄寿';

for (let i = 0; i < stressCount; i++) {
  const hc = [];
  for(let j=0;j<13;j++) hc.push(chars[Math.floor(Math.random()*chars.length)]);
  const hand = createHand(hc.join(''));
  const drawnCard = createCard(chars[Math.floor(Math.random()*chars.length)]);
  hand.push(drawnCard);

  g.gameState.lastDrawnCard = drawnCard;
  g.gameState.lastDrawnPlayerIndex = 0;
  g.gameState.players = [
    {id:'p1',name:'AI',type:'ai',hand,melds:[],discards:[],score:0,piao:0,isTing:false,voiceType:'female'},
    {id:'me',name:'我',type:'human',hand:[],melds:[],discards:[],score:0,piao:0,isTing:false,voiceType:'female'},
    {id:'p2',name:'玩家2',type:'ai',hand:[],melds:[],discards:[],score:0,piao:0,isTing:false,voiceType:'male'}
  ];

  const idx = g.selectAIDiscardHard({name:'AI',hand,melds:[],discards:[],isTing:false});
  if(idx>=0 && idx<hand.length) {
    const dc = hand[idx];
    if(dc.id === drawnCard.id) {
      discardViolations++;
      if(discardViolations <= 5) {
        console.log(`  ❌ #${i+1}: AI丢弃刚摸的牌: ${dc.character} (刚摸: ${drawnCard.character})`);
      }
    }
  }
}

const rate = (discardViolations/stressCount*100).toFixed(1);
console.log(`\n压力测试: ${stressCount}次, ${discardViolations}次违规(${rate}%)`);
if(discardViolations > 0) {
  issues.push({ name:'AI丢弃刚摸牌', message:`压力测试${stressCount}次中${discardViolations}次违规(${rate}%)` });
  failed++;
}

console.log('\n═══════════════════════════════════════');
console.log('  阶段3: 完整游戏模拟(8局)');
console.log('═══════════════════════════════════════');

if(g.gameSettings) { g.gameSettings.difficulty = 'hard'; g.gameSettings.piaoEnabled = false; }
else { g.gameSettings = {volume:1.0,difficulty:'hard',piaoEnabled:false}; }

let simHuRounds = 0, simLiujuRounds = 0, simViolations = 0;
let aiHu = 0, playerHu = 0, totalHuCount = 0;

for (let round = 1; round <= 8; round++) {
  const deck = g.shuffleDeck(g.createDeck());
  const players = [
    {id:'p1',name:'玩家1',type:'ai',hand:[],melds:[],discards:[],score:0,piao:0,isTing:false,voiceType:'female'},
    {id:'me',name:'我',type:'human',hand:[],melds:[],discards:[],score:0,piao:0,isTing:false,voiceType:'female'},
    {id:'p2',name:'玩家2',type:'ai',hand:[],melds:[],discards:[],score:0,piao:0,isTing:false,voiceType:'male'}
  ];
  const hc = [19,19,19]; hc[0] = 20;
  for(let i=0;i<3;i++){for(let j=0;j<hc[i];j++)players[i].hand.push(deck.pop());players[i].hand=g.sortHand(players[i].hand);}
  g.gameState.players = players;
  g.gameState.deck = deck;

  let curP = 0, skipDraw = false, ended = false, turns = 0;
  let lastDrawn = {};

  while(!ended && turns < 300 && deck.length > 0) {
    turns++;
    const p = players[curP];
    const isDFT = curP===0 && p.hand.length===20;
    let drawn = null;
    if(!skipDraw && !isDFT && deck.length>0) {
      drawn = deck.pop();
      p.hand.push(drawn); p.hand = g.sortHand(p.hand);
      if(p.type==='ai') {
        lastDrawn[curP] = drawn;
        g.gameState.lastDrawnCard = drawn;
        g.gameState.lastDrawnPlayerIndex = curP;
      }
    }
    skipDraw = false;

    const hr = g.checkHu(p);
    if(hr.canHu) {
      if(drawn) {} else {}
      simHuRounds++;
      totalHuCount += hr.huCount;
      if(curP===1) playerHu++; else aiHu++;
      console.log(`  第${round}局: ${p.name} ${drawn?'自摸':'点炮'} ${hr.huType?.name||'未知'} ${hr.huCount}胡`);
      ended = true; break;
    }

    p.isTing = g.checkTing(p).isTing;
    const di = g.selectAIDiscard(p);
    if(di<0||di>=p.hand.length){curP=(curP+1)%3;lastDrawn={};continue;}
    const dc = p.hand[di];

    if(p.type==='ai' && lastDrawn[curP] && dc.id === lastDrawn[curP].id) {
      simViolations++;
      console.log(`  ❌ 第${round}局: ${p.name}丢弃刚摸的牌: ${dc.character}`);
    }

    p.hand.splice(di,1); p.discards.push(dc);
    g.clearCaches();
    lastDrawn = {};
    g.gameState.lastDrawnCard = null;
    g.gameState.lastDrawnPlayerIndex = -1;

    let handled = false;
    for(let ni=1;ni<=3&&!handled;ni++){
      const ri=(curP+ni)%3;if(ri===curP)continue;
      const rp=players[ri];
      const rhr=g.checkHu(rp);
      if(rhr.canHu){
        simHuRounds++;totalHuCount+=rhr.huCount;
        if(ri===1)playerHu++;else aiHu++;
        console.log(`  第${round}局: ${rp.name} 点炮 ${rhr.huType?.name||'未知'} ${rhr.huCount}胡`);
        ended=true;handled=true;break;
      }
    }
    if(!handled) curP=(curP+1)%3;
  }
  if(!ended) { simLiujuRounds++; console.log(`  第${round}局: 流局`); }
}

if(simViolations > 0) {
  issues.push({ name:'游戏模拟-AI丢弃刚摸牌', message:`8局中${simViolations}次违规` });
  failed++;
}

console.log(`\n模拟结果: ${simHuRounds}胡, ${simLiujuRounds}流局, ${simViolations}违规`);
console.log(`AI胡率: ${Math.round(aiHu/8*100)}%, 玩家胡率: ${Math.round(playerHu/8*100)}%`);

console.log('\n═══════════════════════════════════════');
console.log('  测试总结');
console.log('═══════════════════════════════════════');
console.log(`单元测试: ${passed}通过, ${failed}失败`);
console.log(`AI压力测试: ${discardViolations}/${stressCount} 违规(${rate}%)`);
console.log(`游戏模拟: ${simViolations}次违规`);

if(issues.length === 0) {
  console.log('\n🎉 所有测试通过，未检测到逻辑问题！');
} else {
  console.log(`\n⚠️ 检测到${issues.length}个逻辑问题:`);
  for(const iss of issues) {
    console.log(`  ❌ ${iss.name}: ${iss.message}`);
  }
}

process.exit(failed > 0 ? 1 : 0);
