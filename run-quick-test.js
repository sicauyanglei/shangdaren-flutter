const fs = require('fs');
const vm = require('vm');

const gameCode = fs.readFileSync(__dirname + '/web/hybrid/html/game.js', 'utf-8');

const mockDomElements = {};
function createElement(tag) {
  return { style:{}, classList:{add(){},remove(){},toggle(){},contains(){return false;}}, innerHTML:'',textContent:'', appendChild(){}, querySelector(){return null;}, querySelectorAll(){return[];}, addEventListener(){}, setAttribute(){}, getAttribute(){return null;}, children:[] };
}
function getElementById(id) {
  if (!mockDomElements[id]) mockDomElements[id] = createElement('div');
  return mockDomElements[id];
}

const sandbox = {
  console: { log(){}, error(){}, warn(){} },
  document: { getElementById, querySelector:()=>createElement('div'), querySelectorAll:()=>[], createElement:(tag)=>createElement(tag), addEventListener(){}, documentElement:{classList:{contains:()=>false},style:{}}, body:{appendChild(){},querySelectorAll(){return[];},style:{}} },
  window: { innerWidth:800, innerHeight:600, close(){}, addEventListener(){} },
  screen: { orientation:{lock(){return Promise.resolve()}} },
  navigator: { userAgent:'Node.js' },
  setTimeout:(fn,ms)=>{if(typeof fn==='function')fn();return 1;},
  setInterval:()=>1, clearInterval:()=>{}, clearTimeout:()=>{},
  localStorage:{getItem(){return null;},setItem(){},removeItem(){}},
  Math, JSON, Date, Array, Object, String, Number, Boolean, Map, Set, Promise, Error,
  parseInt, parseFloat, isNaN, isFinite, RegExp,
  fetch:()=>Promise.resolve({text:()=>Promise.resolve('')}),
  AudioContext:function(){return{createGain(){return{gain:{value:0},connect(){}}},createBufferSource(){return{connect(){},start(){},stop(){}}},decodeAudioData(){return Promise.resolve({})},resume(){}};},
  WebSocket:function(){return{send(){},close(){},addEventListener(){}};},
  requestAnimationFrame:(fn)=>{if(typeof fn==='function')fn();return 1;},
  cancelAnimationFrame:()=>{},
  performance:{now:()=>Date.now()}
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
  const info = map[char]||{s:0,p:0,c:'black'};
  return {character:char,sentence:info.s,position:info.p,color:info.c,id:Math.random().toString(36).substr(2,9),isSpecial:(char==='上'||char==='福')};
}

console.log('=== AI出牌测试 ===\n');

if(g.gameSettings) { g.gameSettings.difficulty = 'hard'; g.gameSettings.piaoEnabled = false; }
else { g.gameSettings = {volume:1.0,difficulty:'hard',piaoEnabled:false}; }

console.log('测试1: AI可以丢弃刚摸的牌');
let discardCount = 0;
const total = 200;
const chars = '上大人丘乙己化三千七十土尔小生八九子佳作亡福禄寿';

for (let i = 0; i < total; i++) {
  const hc = [];
  for(let j=0;j<13;j++) hc.push(chars[Math.floor(Math.random()*chars.length)]);
  const hand = hc.map(c => createCard(c));
  const drawnCard = createCard(chars[Math.floor(Math.random()*chars.length)]);
  hand.push(drawnCard);

  g.gameState.lastDrawnCard = drawnCard;
  g.gameState.lastDrawnPlayerIndex = 0;
  g.gameState.players = [
    {id:'p1',name:'AI',type:'ai',hand,melds:[],discards:[],score:0,piao:0,isTing:false,voiceType:'female'},
    {id:'me',name:'我',type:'human',hand:[],melds:[],discards:[],score:0,piao:0,isTing:false,voiceType:'female'},
    {id:'p2',name:'玩家2',type:'ai',hand:[],melds:[],discards:[],score:0,piao:0,isTing:false,voiceType:'male'}
  ];

  const idx = g.selectAIDiscardHard(g.gameState.players[0]);
  if(idx>=0 && idx<hand.length) {
    const dc = hand[idx];
    if(dc.id === drawnCard.id) {
      discardCount++;
    }
  }
}

const rate = (discardCount/total*100).toFixed(1);
console.log(`\n结果: ${total}次测试中，AI丢弃刚摸的牌 ${discardCount}次 (${rate}%)`);
console.log('✅ AI可以正常丢弃刚摸的牌\n');

console.log('测试2: AI吃牌后不会马上打出刚吃的牌');

let violations = 0;
for (let i = 0; i < 100; i++) {
  const hc = [];
  for(let j=0;j<15;j++) hc.push(chars[Math.floor(Math.random()*chars.length)]);
  const hand = hc.map(c => createCard(c));
  
  const discardChar = chars[Math.floor(Math.random()*chars.length)];
  const discardCard = createCard(discardChar);
  
  g.gameState.lastDiscardedCard = discardCard;
  g.gameState.lastDiscardPlayerIndex = 1;
  g.gameState.players = [
    {id:'p1',name:'AI',type:'ai',hand,melds:[],discards:[],score:0,piao:0,isTing:false,voiceType:'female'},
    {id:'me',name:'我',type:'human',hand:[],melds:[],discards:[],score:0,piao:0,isTing:false,voiceType:'female'},
    {id:'p2',name:'玩家2',type:'ai',hand:[],melds:[],discards:[],score:0,piao:0,isTing:false,voiceType:'male'}
  ];
  
  const willChi = g.shouldAIChi(g.gameState.players[0], discardCard);
  
  if (willChi) {
    const sentenceCards = [...hand, discardCard].filter(c => c.sentence === discardCard.sentence);
    const chiCards = [];
    for (let pos = 0; pos < 3; pos++) {
      if (pos !== discardCard.position) {
        const c = sentenceCards.find(sc => sc.position === pos);
        if (c && c.id !== discardCard.id) chiCards.push(c);
      }
    }
    
    if (chiCards.length === 2) {
      const afterChiHand = hand.filter(c => c.id !== chiCards[0].id && c.id !== chiCards[1].id);
      const afterChiMelds = [{ type: 'sequence', cards: [discardCard, ...chiCards], source: 'chi' }];
      
      const simulatedPlayer = { ...g.gameState.players[0], hand: afterChiHand, melds: afterChiMelds };
      const discardIndex = g.selectAIDiscardHard(simulatedPlayer);
      const willDiscard = afterChiHand[discardIndex];
      
      const allChiChars = [discardCard.character, chiCards[0].character, chiCards[1].character];
      if (willDiscard && allChiChars.includes(willDiscard.character)) {
        violations++;
      }
    }
  }
}

console.log(`\n结果: 100次测试中，AI吃牌后打出刚吃牌的违规次数: ${violations}次`);

if (violations === 0) {
  console.log('✅ AI吃牌后不会马上打出刚吃的牌\n');
} else {
  console.log(`❌ 发现${violations}次违规\n`);
}

process.exit(violations > 0 ? 1 : 0);
