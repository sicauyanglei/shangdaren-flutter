const fs = require('fs');
const vm = require('vm');

const gameCode = fs.readFileSync(__dirname + '/web/hybrid/html/game.js', 'utf-8');

const mockDomElements = {};
function createElement(tag) {
  return { style:{}, classList:{add(){},remove(){},toggle(){},contains(){return false;}}, innerHTML:'',textContent:'', appendChild(){}, querySelector(){return null;}, querySelectorAll(){return[];}, addEventListener(){}, setAttribute(){}, getAttribute(){return null;}, children:[], dataset:{} };
}
function getElementById(id) {
  if (!mockDomElements[id]) mockDomElements[id] = createElement('div');
  return mockDomElements[id];
}

const sandbox = {
  console: { log(){}, error(){}, warn(){} },
  document: { getElementById, querySelector:()=>createElement('div'), querySelectorAll:()=>[], createElement:(tag)=>createElement(tag), addEventListener(){}, documentElement:{classList:{contains:()=>false},style:{}}, body:{appendChild(){},querySelectorAll:()=>[],style:{}} },
  window: { innerWidth:800, innerHeight:600, close(){}, addEventListener(){} },
  screen: { orientation:{lock:()=>Promise.resolve()}} ,
  navigator: { userAgent:'Node.js' },
  setTimeout:(fn,ms)=>{if(typeof fn==='function')fn();return 1;},
  setInterval:()=>1, clearInterval:()=>{}, clearTimeout:()=>{},
  localStorage:{getItem:()=>null,setItem(){},removeItem(){}},
  Math, JSON, Date, Array, Object, String, Number, Boolean, Map, Set, Promise, Error,
  parseInt, parseFloat, isNaN, isFinite, RegExp,
  fetch:()=>Promise.resolve({text:()=>Promise.resolve('')}),
  AudioContext:function(){return{createGain(){return{gain:{value:0},connect(){}}},createBufferSource(){return{connect(){},start(){},stop(){}}},decodeAudioData:()=>Promise.resolve({}),resume(){}};},
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
  window.createDeck = createDeck;
  window.shuffleDeck = shuffleDeck;
  window.sortHand = sortHand;
  window.clearCaches = clearCaches;
  window.selectAIDiscardHard = selectAIDiscardHard;
  window.selectAIDiscardMedium = selectAIDiscardMedium;
  window.shouldAIChi = shouldAIChi;
  window.shouldAIPeng = shouldAIPeng;
  window.canPlayerChi = canPlayerChi;
  window.canPlayerPeng = canPlayerPeng;
  window.canPlayerZhao = canPlayerZhao;
`, ctx);

const g = sandbox.window;

const charMap = {
  '\u4e0a':{s:1,p:0},'\u5927':{s:1,p:1},'\u4eba':{s:1,p:2},
  '\u4e18':{s:2,p:0},'\u4e59':{s:2,p:1},'\u5df1':{s:2,p:2},
  '\u5316':{s:3,p:0},'\u4e09':{s:3,p:1},'\u5343':{s:3,p:2},
  '\u4e03':{s:4,p:0},'\u5341':{s:4,p:1},'\u571f':{s:4,p:2},
  '\u5c14':{s:5,p:0},'\u5c0f':{s:5,p:1},'\u751f':{s:5,p:2},
  '\u516b':{s:6,p:0},'\u4e5d':{s:6,p:1},'\u5b50':{s:6,p:2},
  '\u4f73':{s:7,p:0},'\u4f5c':{s:7,p:1},'\u4ea1':{s:7,p:2},
  '\u798f':{s:8,p:0},'\u7984':{s:8,p:1},'\u5bff':{s:8,p:2}
};
const charNames = {
  '\u4e0a':'上','\u5927':'大','\u4eba':'人',
  '\u4e18':'丘','\u4e59':'乙','\u5df1':'己',
  '\u5316':'化','\u4e09':'三','\u5343':'千',
  '\u4e03':'七','\u5341':'十','\u571f':'土',
  '\u5c14':'尔','\u5c0f':'小','\u751f':'生',
  '\u516b':'八','\u4e5d':'九','\u5b50':'子',
  '\u4f73':'佳','\u4f5c':'作','\u4ea1':'亡',
  '\u798f':'福','\u7984':'禄','\u5bff':'寿'
};

let cardIdCounter = 0;
function createCard(char) {
  const info = charMap[char]||{s:0,p:0};
  const isSpecial = char==='\u4e0a'||char==='\u798f';
  return {character:char,sentence:info.s,position:info.p,color:'black',id:'c'+(cardIdCounter++),isSpecial};
}

function makeHand(arr) {
  return arr.map(c => createCard(c));
}

function meldCount(melds) {
  return melds.length * 3;
}

function totalCount(player) {
  return player.hand.length + meldCount(player.melds);
}

if(g.gameSettings) { g.gameSettings.difficulty = 'hard'; g.gameSettings.piaoEnabled = false; }
else { g.gameSettings = {volume:1.0,difficulty:'hard',piaoEnabled:false}; }

let totalTests = 0;
let passedTests = 0;
let failedTests = 0;

function assert(condition, name, detail) {
  totalTests++;
  if (condition) {
    passedTests++;
  } else {
    failedTests++;
    console.log('FAIL: ' + name);
    if (detail) console.log('  -> ' + detail);
  }
}

console.log('========================================');
console.log('  Hand Count Test Suite');
console.log('  Rule: after discard, hand + melds*3 = 19');
console.log('========================================\n');

console.log('--- Test 1: Dealer initial hand (20 cards) ---');
{
  const hand = makeHand(['\u4e0a','\u5927','\u4eba','\u4e18','\u4e59','\u5df1','\u5316','\u4e09','\u5343','\u4e03','\u5341','\u571f','\u5c14','\u5c0f','\u751f','\u516b','\u4e5d','\u5b50','\u4f73','\u4f5c']);
  assert(hand.length === 20, 'Dealer has 20 cards', 'actual: ' + hand.length);
}

console.log('--- Test 2: Non-dealer initial hand (19 cards) ---');
{
  const hand = makeHand(['\u4e0a','\u5927','\u4eba','\u4e18','\u4e59','\u5df1','\u5316','\u4e09','\u5343','\u4e03','\u5341','\u571f','\u5c14','\u5c0f','\u751f','\u516b','\u4e5d','\u5b50','\u4f73']);
  assert(hand.length === 19, 'Non-dealer has 19 cards', 'actual: ' + hand.length);
}

console.log('--- Test 3: Dealer first turn discard ---');
{
  const hand = makeHand(['\u4e0a','\u5927','\u4eba','\u4e18','\u4e59','\u5df1','\u5316','\u4e09','\u5343','\u4e03','\u5341','\u571f','\u5c14','\u5c0f','\u751f','\u516b','\u4e5d','\u5b50','\u4f73','\u4f5c']);
  const player = {id:'p0',name:'Dealer',type:'ai',hand,melds:[],discards:[],score:0,piao:0,isTing:false,voiceType:'female'};
  g.gameState.dealerIndex = 0;
  g.gameState.hasDealerPlayedFirstTurn = false;
  g.gameState.currentPlayerIndex = 0;
  g.gameState.skipDraw = false;
  g.gameState.lastDrawnCard = null;
  g.gameState.lastDrawnPlayerIndex = -1;
  g.gameState.players = [player,
    {id:'p1',name:'Me',type:'human',hand:[],melds:[],discards:[],score:0,piao:0,isTing:false,voiceType:'female'},
    {id:'p2',name:'P2',type:'ai',hand:[],melds:[],discards:[],score:0,piao:0,isTing:false,voiceType:'male'}
  ];

  const idx = g.selectAIDiscardHard(player);
  hand.splice(idx, 1);
  const total = hand.length + meldCount(player.melds);
  assert(total === 19, 'Dealer after first discard = 19', 'actual: ' + total);
}

console.log('--- Test 4: Non-dealer draw then discard ---');
{
  const hand = makeHand(['\u4e0a','\u5927','\u4eba','\u4e18','\u4e59','\u5df1','\u5316','\u4e09','\u5343','\u4e03','\u5341','\u571f','\u5c14','\u5c0f','\u751f','\u516b','\u4e5d','\u5b50','\u4f73']);
  const drawnCard = createCard('\u798f');
  hand.push(drawnCard);
  const player = {id:'p1',name:'Player',type:'ai',hand,melds:[],discards:[],score:0,piao:0,isTing:false,voiceType:'female'};
  g.gameState.lastDrawnCard = drawnCard;
  g.gameState.lastDrawnPlayerIndex = 1;
  g.gameState.players = [
    {id:'p0',name:'Dealer',type:'ai',hand:[],melds:[],discards:[],score:0,piao:0,isTing:false,voiceType:'female'},
    player,
    {id:'p2',name:'P2',type:'ai',hand:[],melds:[],discards:[],score:0,piao:0,isTing:false,voiceType:'male'}
  ];

  assert(hand.length === 20, 'After draw = 20', 'actual: ' + hand.length);
  const idx = g.selectAIDiscardHard(player);
  hand.splice(idx, 1);
  assert(totalCount(player) === 19, 'After discard = 19', 'actual: ' + totalCount(player));
}

console.log('--- Test 5: Chi (eat) - meld counts as 3 ---');
{
  const hand = makeHand(['\u4e0a','\u5927','\u4eba','\u4e18','\u4e59','\u5df1','\u5316','\u4e09','\u5343','\u4e03','\u5341','\u5c14','\u5c0f','\u751f','\u516b','\u4e5d','\u5b50','\u4f73','\u4f5c']);
  assert(hand.length === 19, 'Before chi = 19', 'actual: ' + hand.length);
  
  const discardCard = createCard('\u571f');
  const player = {id:'p1',name:'Player',type:'ai',hand:[...hand],melds:[],discards:[],score:0,piao:0,isTing:false,voiceType:'female'};
  
  const chiCards = player.hand.filter(c => c.sentence === 4 && c.position !== 2);
  for (const c of chiCards.slice(0, 2)) {
    const idx = player.hand.findIndex(h => h.id === c.id);
    if (idx !== -1) player.hand.splice(idx, 1);
  }
  player.melds.push({type:'sequence',cards:[discardCard, ...chiCards.slice(0,2)],source:'chi',huValue:0});
  
  assert(player.hand.length === 17, 'After chi hand = 17 (19-2)', 'actual: ' + player.hand.length);
  assert(meldCount(player.melds) === 3, 'Chi meld counts as 3', 'actual: ' + meldCount(player.melds));
  assert(totalCount(player) === 20, 'After chi before discard = 20', 'actual: ' + totalCount(player));
  
  const idx = g.selectAIDiscardHard(player);
  player.hand.splice(idx, 1);
  assert(totalCount(player) === 19, 'After chi+discard = 19', 'actual: ' + totalCount(player));
}

console.log('--- Test 6: Peng (triplet) - meld counts as 3 ---');
{
  const hand = makeHand(['\u4e0a','\u5927','\u4eba','\u4e18','\u4e59','\u5df1','\u5316','\u4e09','\u5343','\u4e03','\u4e03','\u5c14','\u5c0f','\u751f','\u516b','\u4e5d','\u5b50','\u4f73']);
  assert(hand.length === 18, 'Before peng = 18', 'actual: ' + hand.length);
  
  const discardCard = createCard('\u4e03');
  const player = {id:'p1',name:'Player',type:'ai',hand:[...hand],melds:[],discards:[],score:0,piao:0,isTing:false,voiceType:'female'};
  
  const matchingCards = player.hand.filter(c => c.character === '\u4e03').slice(0, 2);
  for (const c of matchingCards) {
    const idx = player.hand.findIndex(h => h.id === c.id);
    if (idx !== -1) player.hand.splice(idx, 1);
  }
  player.melds.push({type:'triplet',cards:[discardCard, ...matchingCards],source:'peng',huValue:2});
  
  assert(player.hand.length === 16, 'After peng hand = 16 (18-2)', 'actual: ' + player.hand.length);
  assert(meldCount(player.melds) === 3, 'Peng meld counts as 3', 'actual: ' + meldCount(player.melds));
  assert(totalCount(player) === 19, 'After peng before discard = 19', 'actual: ' + totalCount(player));
}

console.log('--- Test 7: Zhao (quartet) - meld counts as 3, needs replacement ---');
{
  const hand = makeHand(['\u4e0a','\u5927','\u4eba','\u4e18','\u4e59','\u5df1','\u5316','\u4e09','\u5343','\u4e03','\u4e03','\u4e03','\u5c14','\u5c0f','\u751f','\u516b','\u4e5d','\u5b50','\u4f73']);
  assert(hand.length === 19, 'Before zhao = 19', 'actual: ' + hand.length);
  
  const discardCard = createCard('\u4e03');
  const player = {id:'p1',name:'Player',type:'ai',hand:[...hand],melds:[],discards:[],score:0,piao:0,isTing:false,voiceType:'female'};
  
  const matchingCards = player.hand.filter(c => c.character === '\u4e03');
  assert(matchingCards.length === 3, 'Hand has 3 qix + discard 1 = 4 zhao', 'actual: ' + matchingCards.length);
  
  for (const c of matchingCards) {
    const idx = player.hand.findIndex(h => h.id === c.id);
    if (idx !== -1) player.hand.splice(idx, 1);
  }
  player.melds.push({type:'quartet',cards:[discardCard, ...matchingCards],source:'zhao',huValue:6});
  
  assert(player.hand.length === 16, 'After zhao hand = 16 (19-3)', 'actual: ' + player.hand.length);
  assert(meldCount(player.melds) === 3, 'Zhao meld counts as 3', 'actual: ' + meldCount(player.melds));
  assert(totalCount(player) === 19, 'After zhao before replacement = 19', 'actual: ' + totalCount(player));
  
  const replacementCard = createCard('\u798f');
  player.hand.push(replacementCard);
  assert(totalCount(player) === 20, 'After replacement before discard = 20', 'actual: ' + totalCount(player));
  
  const idx = g.selectAIDiscardHard(player);
  player.hand.splice(idx, 1);
  assert(totalCount(player) === 19, 'After zhao+replacement+discard = 19', 'actual: ' + totalCount(player));
}

console.log('--- Test 8: Multiple chi - hand + melds*3 after discard ---');
{
  const hand = makeHand(['\u4e18','\u4e59','\u5df1','\u5c14','\u5c0f','\u751f','\u516b','\u4e5d','\u5b50','\u4f73','\u4f5c','\u798f','\u7984','\u5bff']);
  const melds = [
    {type:'sequence',cards:makeHand(['\u4e0a','\u5927','\u4eba']),source:'chi',huValue:4},
    {type:'sequence',cards:makeHand(['\u5316','\u4e09','\u5343']),source:'chi',huValue:0}
  ];
  const player = {id:'p1',name:'Player',type:'ai',hand:[...hand],melds,discards:[],score:0,piao:0,isTing:false,voiceType:'female'};
  
  assert(hand.length === 14, 'After 2 chi hand = 14', 'actual: ' + hand.length);
  assert(meldCount(player.melds) === 6, '2 chi melds = 6', 'actual: ' + meldCount(player.melds));
  assert(totalCount(player) === 20, 'After 2 chi before discard = 20', 'actual: ' + totalCount(player));
  
  const idx = g.selectAIDiscardHard(player);
  player.hand.splice(idx, 1);
  assert(totalCount(player) === 19, 'After 2 chi+discard = 19', 'actual: ' + totalCount(player));
}

console.log('--- Test 9: Chi+Peng+Zhao combination ---');
{
  const hand = makeHand(['\u5c14','\u5c0f','\u751f','\u516b','\u4e5d','\u5b50']);
  const melds = [
    {type:'sequence',cards:makeHand(['\u4e0a','\u5927','\u4eba']),source:'chi',huValue:4},
    {type:'triplet',cards:makeHand(['\u5343','\u5343','\u5343']),source:'peng',huValue:2},
    {type:'quartet',cards:makeHand(['\u4e03','\u4e03','\u4e03','\u4e03']),source:'zhao',huValue:6}
  ];
  const player = {id:'p1',name:'Player',type:'ai',hand:[...hand],melds,discards:[],score:0,piao:0,isTing:false,voiceType:'female'};
  
  assert(hand.length === 6, 'Hand = 6', 'actual: ' + hand.length);
  assert(meldCount(player.melds) === 9, 'Chi(3)+Peng(3)+Zhao(3) = 9', 'actual: ' + meldCount(player.melds));
  assert(totalCount(player) === 15, 'Total = 15', 'actual: ' + totalCount(player));
}

console.log('--- Test 10: User reported case - 21 cards bug ---');
{
  const hand = makeHand(['\u4e0a','\u4e0a','\u5341','\u4f5c','\u7984','\u5bff']);
  const melds = [
    {type:'sequence',cards:makeHand(['\u5316','\u4e09','\u5343']),source:'chi',huValue:0},
    {type:'triplet',cards:makeHand(['\u4e03','\u4e03','\u4e03']),source:'peng',huValue:2},
    {type:'sequence',cards:makeHand(['\u5316','\u4e09','\u5343']),source:'chi',huValue:0},
    {type:'sequence',cards:makeHand(['\u5c14','\u5c0f','\u751f']),source:'chi',huValue:0},
    {type:'sequence',cards:makeHand(['\u4e03','\u5341','\u571f']),source:'chi',huValue:0}
  ];
  const player = {id:'p1',name:'Player',type:'human',hand:[...hand],melds,discards:[],score:0,piao:0,isTing:false,voiceType:'female'};
  
  const total = totalCount(player);
  console.log('  User case: hand=' + hand.length + ', melds=' + melds.length + ', meldCount=' + meldCount(player.melds) + ', total=' + total);
  assert(total === 21, 'User reported 21 cards (BUG)', 'actual: ' + total);
}

console.log('--- Test 11: Correct 5 meld case ---');
{
  const hand = makeHand(['\u4e0a','\u5341','\u4f5c']);
  const melds = [
    {type:'sequence',cards:makeHand(['\u5316','\u4e09','\u5343']),source:'chi',huValue:0},
    {type:'triplet',cards:makeHand(['\u4e03','\u4e03','\u4e03']),source:'peng',huValue:2},
    {type:'sequence',cards:makeHand(['\u5c14','\u5c0f','\u751f']),source:'chi',huValue:0},
    {type:'sequence',cards:makeHand(['\u4e18','\u4e59','\u5df1']),source:'chi',huValue:0},
    {type:'sequence',cards:makeHand(['\u516b','\u4e5d','\u5b50']),source:'chi',huValue:0}
  ];
  const player = {id:'p1',name:'Player',type:'human',hand:[...hand],melds,discards:[],score:0,piao:0,isTing:false,voiceType:'female'};
  
  const total = totalCount(player);
  console.log('  Correct case: hand=' + hand.length + ', melds=' + melds.length + ', meldCount=' + meldCount(player.melds) + ', total=' + total);
  assert(total === 18, '5 melds + 3 hand = 18 (need draw to reach 19)', 'actual: ' + total);
}

console.log('--- Test 12: Dealer chi then discard (dealer has 19 after first discard) ---');
{
  const hand = makeHand(['\u4e0a','\u5927','\u4eba','\u4e18','\u4e59','\u5df1','\u5316','\u4e09','\u5343','\u4e03','\u5341','\u5c14','\u5c0f','\u751f','\u516b','\u4e5d','\u5b50','\u4f73','\u4f5c']);
  assert(hand.length === 19, 'Dealer after first discard = 19', 'actual: ' + hand.length);
  const player = {id:'p0',name:'Dealer',type:'ai',hand:[...hand],melds:[],discards:[],score:0,piao:0,isTing:false,voiceType:'female'};
  g.gameState.dealerIndex = 0;
  g.gameState.hasDealerPlayedFirstTurn = true;
  g.gameState.currentPlayerIndex = 0;
  g.gameState.skipDraw = true;
  g.gameState.lastDrawnCard = null;
  g.gameState.lastDrawnPlayerIndex = -1;
  g.gameState.players = [player,
    {id:'p1',name:'Me',type:'human',hand:[],melds:[],discards:[],score:0,piao:0,isTing:false,voiceType:'female'},
    {id:'p2',name:'P2',type:'ai',hand:[],melds:[],discards:[],score:0,piao:0,isTing:false,voiceType:'male'}
  ];

  const chiCards = player.hand.filter(c => c.sentence === 4 && c.position !== 2).slice(0, 2);
  for (const c of chiCards) {
    const idx = player.hand.findIndex(h => h.id === c.id);
    if (idx !== -1) player.hand.splice(idx, 1);
  }
  const discardCard = createCard('\u571f');
  player.melds.push({type:'sequence',cards:[discardCard, ...chiCards],source:'chi',huValue:0});
  
  assert(totalCount(player) === 20, 'Dealer after chi (skipDraw, before discard) = 20', 'actual: ' + totalCount(player));
  
  const idx = g.selectAIDiscardHard(player);
  player.hand.splice(idx, 1);
  assert(totalCount(player) === 19, 'Dealer after chi+discard = 19', 'actual: ' + totalCount(player));
}

console.log('--- Test 13: Zhao then replacement then another zhao ---');
{
  const hand = makeHand(['\u4e0a','\u5927','\u4eba','\u4e18','\u4e59','\u5df1','\u5316','\u4e09','\u5343','\u4e03','\u4e03','\u4e03','\u798f','\u798f','\u798f','\u516b','\u4e5d','\u5b50','\u4f73']);
  assert(hand.length === 19, 'Before zhao = 19', 'actual: ' + hand.length);
  
  const player = {id:'p1',name:'Player',type:'ai',hand:[...hand],melds:[],discards:[],score:0,piao:0,isTing:false,voiceType:'female'};
  
  const matchingCards = player.hand.filter(c => c.character === '\u4e03');
  for (const c of matchingCards) {
    const idx = player.hand.findIndex(h => h.id === c.id);
    if (idx !== -1) player.hand.splice(idx, 1);
  }
  player.melds.push({type:'quartet',cards:makeHand(['\u4e03','\u4e03','\u4e03','\u4e03']),source:'zhao',huValue:6});
  
  const replacementCard = createCard('\u798f');
  player.hand.push(replacementCard);
  
  assert(totalCount(player) === 20, 'After zhao+replacement = 20', 'actual: ' + totalCount(player));
  
  const matchingCards2 = player.hand.filter(c => c.character === '\u798f');
  if (matchingCards2.length === 4) {
    for (const c of matchingCards2) {
      const idx = player.hand.findIndex(h => h.id === c.id);
      if (idx !== -1) player.hand.splice(idx, 1);
    }
    player.melds.push({type:'quartet',cards:makeHand(['\u798f','\u798f','\u798f','\u798f']),source:'zhao',huValue:16});
    
    const replacementCard2 = createCard('\u5bff');
    player.hand.push(replacementCard2);
    
    assert(totalCount(player) === 20, 'After 2nd zhao+replacement = 20', 'actual: ' + totalCount(player));
    
    const idx = g.selectAIDiscardHard(player);
    player.hand.splice(idx, 1);
    assert(totalCount(player) === 19, 'After 2 zhao+replacement+discard = 19', 'actual: ' + totalCount(player));
  } else {
    console.log('  SKIP: Not enough fu cards for 2nd zhao test');
  }
}

console.log('--- Test 14: Stress test - valid game states ---');
{
  const allChars = ['\u4e0a','\u5927','\u4eba','\u4e18','\u4e59','\u5df1','\u5316','\u4e09','\u5343','\u4e03','\u5341','\u571f','\u5c14','\u5c0f','\u751f','\u516b','\u4e5d','\u5b50','\u4f73','\u4f5c','\u4ea1','\u798f','\u7984','\u5bff'];
  let violations = 0;
  const iterations = 500;
  
  for (let i = 0; i < iterations; i++) {
    const numMelds = Math.floor(Math.random() * 5);
    const handSize = 19 - numMelds * 3;
    
    if (handSize < 1) continue;
    
    const handCards = [];
    for (let j = 0; j < handSize; j++) handCards.push(allChars[Math.floor(Math.random() * allChars.length)]);
    const hand = handCards.map(c => createCard(c));
    const drawnCard = createCard(allChars[Math.floor(Math.random() * allChars.length)]);
    hand.push(drawnCard);
    
    const melds = [];
    for (let m = 0; m < numMelds; m++) {
      melds.push({type:'sequence',cards:makeHand(['\u4e0a','\u5927','\u4eba']),source:'chi',huValue:0});
    }
    
    const player = {id:'p1',name:'AI',type:'ai',hand,melds,discards:[],score:0,piao:0,isTing:false,voiceType:'female'};
    g.gameState.lastDrawnCard = drawnCard;
    g.gameState.lastDrawnPlayerIndex = 0;
    g.gameState.players = [player,
      {id:'me',name:'Me',type:'human',hand:[],melds:[],discards:[],score:0,piao:0,isTing:false,voiceType:'female'},
      {id:'p2',name:'P2',type:'ai',hand:[],melds:[],discards:[],score:0,piao:0,isTing:false,voiceType:'male'}
    ];
    
    const beforeTotal = totalCount(player);
    const idx = g.selectAIDiscardHard(player);
    if (idx >= 0 && idx < hand.length) {
      hand.splice(idx, 1);
      const afterTotal = totalCount(player);
      if (afterTotal !== 19) {
        violations++;
        if (violations <= 3) {
          console.log('  Violation #' + violations + ': total=' + afterTotal + ', hand=' + hand.length + ', melds=' + meldCount(melds) + ', numMelds=' + numMelds + ', beforeTotal=' + beforeTotal);
        }
      }
    }
  }
  
  assert(violations === 0, 'Stress test ' + iterations + ' iterations no violations', 'violations: ' + violations);
}

console.log('--- Test 15: skipDraw flag verification ---');
{
  g.gameState.skipDraw = true;
  g.gameState.hasDealerPlayedFirstTurn = true;
  g.gameState.dealerIndex = 0;
  g.gameState.currentPlayerIndex = 1;
  g.gameState.deck = [createCard('\u798f')];
  
  const shouldSkipDraw = g.gameState.skipDraw;
  const isDealerFirstTurn = g.gameState.currentPlayerIndex === g.gameState.dealerIndex && 
                            !g.gameState.hasDealerPlayedFirstTurn;
  const shouldDraw = !shouldSkipDraw && !isDealerFirstTurn && g.gameState.deck.length > 0;
  
  assert(shouldDraw === false, 'skipDraw=true should not draw', 'shouldDraw: ' + shouldDraw);
}

console.log('--- Test 16: hasDealerPlayedFirstTurn flag ---');
{
  g.gameState.hasDealerPlayedFirstTurn = false;
  g.gameState.dealerIndex = 0;
  g.gameState.currentPlayerIndex = 0;
  
  const isDealerFirstTurn1 = g.gameState.currentPlayerIndex === g.gameState.dealerIndex && 
                             !g.gameState.hasDealerPlayedFirstTurn;
  assert(isDealerFirstTurn1 === true, 'First turn: isDealerFirstTurn = true');
  
  g.gameState.hasDealerPlayedFirstTurn = true;
  const isDealerFirstTurn2 = g.gameState.currentPlayerIndex === g.gameState.dealerIndex && 
                             !g.gameState.hasDealerPlayedFirstTurn;
  assert(isDealerFirstTurn2 === false, 'After first turn: isDealerFirstTurn = false');
}

console.log('\n========================================');
console.log('  Results: ' + passedTests + '/' + totalTests + ' passed');
console.log('  Passed: ' + passedTests + ', Failed: ' + failedTests + ', Total: ' + totalTests);
console.log('========================================');

process.exit(failedTests > 0 ? 1 : 0);
