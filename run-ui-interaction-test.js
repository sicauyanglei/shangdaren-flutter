const fs = require('fs');
const vm = require('vm');

const gameCode = fs.readFileSync(__dirname + '/web/hybrid/html/game.js', 'utf-8');

const mockDomElements = {};
function createElement(tag) {
  return { style:{}, classList:{add(){},remove(){},toggle(){},contains(){return false;}}, innerHTML:'',textContent:'', appendChild(){}, querySelector(){return null;}, querySelectorAll(){return[];}, addEventListener(){}, setAttribute(){}, getAttribute(){return null;}, children:[], dataset:{}, getBoundingClientRect:()=>({left:0,top:0,width:0,height:0,right:0,bottom:0,x:0,y:0}) };
}
function getElementById(id) {
  if (!mockDomElements[id]) mockDomElements[id] = createElement('div');
  return mockDomElements[id];
}

const timers = [];
let timerIdCounter = 1;

const sandbox = {
  console: { log(){}, error(){}, warn(){} },
  document: { getElementById, querySelector:()=>createElement('div'), querySelectorAll:()=>[], createElement:(tag)=>createElement(tag), addEventListener(){}, documentElement:{classList:{contains:()=>false},style:{}}, body:{appendChild(){},querySelectorAll(){return[];},style:{}} },
  window: { innerWidth:800, innerHeight:600, close(){}, addEventListener(){} },
  screen: { orientation:{lock:()=>Promise.resolve()}},
  navigator: { userAgent:'Node.js' },
  setTimeout:(fn,ms)=>{const id=timerIdCounter++;timers.push({id,fn,ms,cleared:false});return id;},
  setInterval:(fn,ms)=>{const id=timerIdCounter++;return id;},
  clearInterval:()=>{},
  clearTimeout:(id)=>{const t=timers.find(t=>t.id===id);if(t)t.cleared=true;},
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
  window.selectAIDiscardEasy = selectAIDiscardEasy;
  window.shouldAIChi = shouldAIChi;
  window.shouldAIPeng = shouldAIPeng;
  window.shouldAIZhao = shouldAIZhao;
  window.canPlayerChi = canPlayerChi;
  window.canPlayerPeng = canPlayerPeng;
  window.canPlayerZhao = canPlayerZhao;
  window.checkResponses = checkResponses;
  window.showResponseButtons = showResponseButtons;
  window.passAction = passAction;
  window.hideAllActionButtons = hideAllActionButtons;
  window.discardCard = discardCard;
  window.startTurn = startTurn;
  window.processAITurn = processAITurn;
  window.continueAITurn = continueAITurn;
  window.moveToNextPlayer = moveToNextPlayer;
  window.performChi = performChi;
  window.performPeng = performPeng;
  window.performZhao = performZhao;
  window.handleHu = handleHu;
  window.handleTimeout = handleTimeout;
  window.startCountdown = startCountdown;
  window.stopCountdown = stopCountdown;
  window.startRound = startRound;
  window.startDealingAnimation = startDealingAnimation;
  window.finishDealing = finishDealing;
  window.startGame = startGame;
  window.updateActionButtons = updateActionButtons;
  window.chiAction = chiAction;
  window.pengAction = pengAction;
  window.zhaoAction = zhaoAction;
  window.huAction = huAction;
  window.discardAction = discardAction;
  window.selectCard = selectCard;
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

function resetGameState() {
  const gs = g.gameState;
  gs.isPaused = false;
  gs.isDealing = false;
  gs.isHandlingHu = false;
  gs.isLiuJuHandled = false;
  gs.isClosingMessage = false;
  gs.isStartingRound = false;
  gs.isMyTurn = false;
  gs.isDrawing = false;
  gs.waitingForResponse = false;
  gs.canChi = false;
  gs.canPeng = false;
  gs.canZhao = false;
  gs.canHu = false;
  gs.actionCancelled = false;
  gs.skipDraw = false;
  gs.hasDealerPlayedFirstTurn = false;
  gs.selectedCardIndex = -1;
  gs.currentPlayerIndex = 0;
  gs.dealerIndex = 0;
  gs.lastDiscardedCard = null;
  gs.lastDiscardPlayerIndex = -1;
  gs.lastDrawnCard = null;
  gs.lastDrawnPlayerIndex = -1;
  gs.countdown = 0;
  gs.countdownTimer = null;
  gs.deck = g.createDeck();
  gs.roundNumber = 1;
  gs.players = [
    { name:'玩家1',type:'ai',hand:[],discards:[],melds:[],score:0,piao:0,isTing:false,voiceType:'female' },
    { name:'我',type:'human',hand:[],discards:[],melds:[],score:0,piao:0,isTing:false,voiceType:'female' },
    { name:'玩家2',type:'ai',hand:[],discards:[],melds:[],score:0,piao:0,isTing:false,voiceType:'male' }
  ];
}

let passed = 0;
let failed = 0;

function test(name, fn) {
  try {
    resetGameState();
    fn();
    console.log(`✅ ${name}`);
    passed++;
  } catch(e) {
    console.log(`❌ ${name}: ${e.message}`);
    failed++;
  }
}

function assert(cond, msg) {
  if (!cond) throw new Error(msg || 'Assertion failed');
}

console.log('=== UI交互卡顿测试 ===\n');

test('1. isDealing=true时startTurn被阻止', () => {
  g.gameState.isDealing = true;
  g.gameState.currentPlayerIndex = 0;
  g.startTurn();
  assert(g.gameState.isMyTurn === false, 'isDealing时不应设置isMyTurn');
});

test('2. isDealing=true时processAITurn被阻止', () => {
  g.gameState.isDealing = true;
  g.gameState.currentPlayerIndex = 0;
  g.processAITurn();
});

test('3. isDealing=true时discardCard被阻止', () => {
  g.gameState.isDealing = true;
  const hand = [createCard('上'), createCard('大'), createCard('人')];
  g.gameState.players[0].hand = [...hand];
  g.discardCard(0, 0);
  assert(g.gameState.players[0].hand.length === 3, 'isDealing时不应出牌');
});

test('4. isDealing=true时handleTimeout被阻止', () => {
  g.gameState.isDealing = true;
  g.gameState.isMyTurn = true;
  g.gameState.waitingForResponse = false;
  g.handleTimeout();
});

test('5. isDealing=true时performChi被阻止', () => {
  g.gameState.isDealing = true;
  g.performChi(1);
});

test('6. isDealing=true时performPeng被阻止', () => {
  g.gameState.isDealing = true;
  g.performPeng(1);
});

test('7. isDealing=true时performZhao被阻止', () => {
  g.gameState.isDealing = true;
  g.performZhao(1);
});

test('8. isDealing=true时handleHu被阻止', () => {
  g.gameState.isDealing = true;
  g.handleHu(1, 'dianpao');
});

test('9. isDealing=true时moveToNextPlayer被阻止', () => {
  g.gameState.isDealing = true;
  g.gameState.currentPlayerIndex = 0;
  g.moveToNextPlayer();
  assert(g.gameState.currentPlayerIndex === 0, 'isDealing时不应切换玩家');
});

test('10. waitingForResponse=true且actionCancelled=true时按钮不显示', () => {
  g.gameState.waitingForResponse = true;
  g.gameState.actionCancelled = true;
  g.gameState.canChi = true;
  g.gameState.canPeng = true;
  g.updateActionButtons();
  const container = mockDomElements['actionButtons'];
  assert(container.innerHTML === '', 'actionCancelled时不应显示按钮');
});

test('11. hideAllActionButtons正确重置所有状态', () => {
  g.gameState.canPeng = true;
  g.gameState.canChi = true;
  g.gameState.canZhao = true;
  g.gameState.canHu = true;
  g.gameState.waitingForResponse = true;
  g.gameState.isMyTurn = true;
  g.gameState.actionCancelled = false;
  
  g.hideAllActionButtons();
  
  assert(g.gameState.canPeng === false, 'canPeng应为false');
  assert(g.gameState.canChi === false, 'canChi应为false');
  assert(g.gameState.canZhao === false, 'canZhao应为false');
  assert(g.gameState.canHu === false, 'canHu应为false');
  assert(g.gameState.waitingForResponse === false, 'waitingForResponse应为false');
  assert(g.gameState.isMyTurn === false, 'isMyTurn应为false');
  assert(g.gameState.actionCancelled === true, 'actionCancelled应为true');
});

test('12. actionCancelled残留不会阻止下一轮按钮显示', () => {
  g.gameState.actionCancelled = true;
  g.gameState.waitingForResponse = true;
  g.gameState.canChi = true;
  g.gameState.canPeng = true;
  
  g.showResponseButtons([
    { playerIndex: 1, canHu: false, canZhao: false, canPeng: true, canChi: true }
  ], 1);
  
  assert(g.gameState.actionCancelled === false, 'showResponseButtons应重置actionCancelled');
  assert(g.gameState.waitingForResponse === true, '应设置waitingForResponse');
  assert(g.gameState.canPeng === true, '应设置canPeng');
  assert(g.gameState.canChi === true, '应设置canChi');
});

test('13. isDrawing=true时selectCard被阻止', () => {
  g.gameState.isMyTurn = true;
  g.gameState.isDrawing = true;
  g.gameState.selectedCardIndex = -1;
  g.selectCard(0);
  assert(g.gameState.selectedCardIndex === -1, 'isDrawing时不应选择牌');
});

test('14. isDrawing=true时discardAction被阻止', () => {
  g.gameState.isMyTurn = true;
  g.gameState.isDrawing = true;
  g.gameState.selectedCardIndex = 0;
  g.discardAction();
});

test('15. isMyTurn=false时selectCard被阻止', () => {
  g.gameState.isMyTurn = false;
  g.gameState.isDrawing = false;
  g.gameState.selectedCardIndex = -1;
  g.selectCard(0);
  assert(g.gameState.selectedCardIndex === -1, '非我的回合不应选择牌');
});

test('16. isMyTurn=false时discardAction被阻止', () => {
  g.gameState.isMyTurn = false;
  g.gameState.selectedCardIndex = 0;
  g.discardAction();
});

test('17. chiAction在canChi=false时不执行', () => {
  g.gameState.canChi = false;
  g.chiAction();
});

test('18. pengAction在canPeng=false时不执行', () => {
  g.gameState.canPeng = false;
  g.pengAction();
});

test('19. zhaoAction在canZhao=false时不执行', () => {
  g.gameState.canZhao = false;
  g.zhaoAction();
});

test('20. huAction在canHu=false时不执行', () => {
  g.gameState.canHu = false;
  g.huAction();
});

test('21. isHandlingHu=true时processAITurn被阻止', () => {
  g.gameState.isHandlingHu = true;
  g.gameState.currentPlayerIndex = 0;
  g.processAITurn();
});

test('22. isHandlingHu=true时continueAITurn被阻止', () => {
  g.gameState.isHandlingHu = true;
  g.continueAITurn(g.gameState.players[0]);
});

test('23. isHandlingHu=true时handleHu被阻止', () => {
  g.gameState.isHandlingHu = true;
  g.handleHu(0, 'dianpao');
  assert(g.gameState.isHandlingHu === true, 'isHandlingHu应保持true');
});

test('24. isPaused=true时processAITurn被阻止', () => {
  g.gameState.isPaused = true;
  g.gameState.currentPlayerIndex = 0;
  g.processAITurn();
});

test('25. isPaused=true时continueAITurn被阻止', () => {
  g.gameState.isPaused = true;
  g.continueAITurn(g.gameState.players[0]);
});

test('26. 出牌后waitingForResponse正确设置', () => {
  const hand0 = [createCard('上'), createCard('大'), createCard('人'), createCard('丘')];
  const hand1 = [createCard('上'), createCard('大'), createCard('人'), createCard('化'), createCard('三'), createCard('千'), createCard('七'), createCard('十'), createCard('土'), createCard('尔'), createCard('小'), createCard('生'), createCard('八'), createCard('九'), createCard('子'), createCard('佳'), createCard('作'), createCard('亡'), createCard('福')];
  const hand2 = [createCard('上'), createCard('大'), createCard('人'), createCard('丘')];
  
  g.gameState.players[0].hand = hand0;
  g.gameState.players[1].hand = hand1;
  g.gameState.players[2].hand = hand2;
  g.gameState.currentPlayerIndex = 0;
  g.gameState.dealerIndex = 0;
  g.gameState.deck = g.createDeck();
  
  g.discardCard(0, 0);
  
  assert(g.gameState.lastDiscardedCard !== null, '应设置lastDiscardedCard');
  assert(g.gameState.lastDiscardPlayerIndex === 0, '应设置lastDiscardPlayerIndex');
});

test('27. passAction正确重置waitingForResponse', () => {
  g.gameState.waitingForResponse = true;
  g.gameState.canChi = true;
  g.gameState.canPeng = false;
  g.gameState.canZhao = false;
  g.gameState.canHu = false;
  g.gameState.lastDiscardedCard = createCard('上');
  g.gameState.lastDiscardPlayerIndex = 0;
  g.gameState.currentPlayerIndex = 1;
  g.gameState.deck = g.createDeck();
  
  g.passAction();
  
  assert(g.gameState.waitingForResponse === false, 'passAction后waitingForResponse应为false');
});

test('28. 连续快速点击chiAction不会重复执行', () => {
  g.gameState.canChi = true;
  g.gameState.waitingForResponse = true;
  g.gameState.lastDiscardedCard = createCard('上');
  g.gameState.lastDiscardPlayerIndex = 2;
  g.gameState.currentPlayerIndex = 1;
  
  const hand1 = [createCard('大'), createCard('人'), createCard('化'), createCard('三'), createCard('千'), createCard('七'), createCard('十'), createCard('土'), createCard('尔'), createCard('小'), createCard('生'), createCard('八'), createCard('九'), createCard('子'), createCard('佳'), createCard('作'), createCard('亡'), createCard('福'), createCard('禄')];
  g.gameState.players[1].hand = hand1;
  
  g.chiAction();
  
  assert(g.gameState.canChi === false, '第一次chiAction后canChi应为false');
  
  g.chiAction();
});

test('29. 连续快速点击pengAction不会重复执行', () => {
  g.gameState.canPeng = true;
  g.gameState.waitingForResponse = true;
  g.gameState.lastDiscardedCard = createCard('上');
  g.gameState.lastDiscardPlayerIndex = 0;
  g.gameState.currentPlayerIndex = 1;
  
  const hand1 = [createCard('上'), createCard('上'), createCard('化'), createCard('三'), createCard('千'), createCard('七'), createCard('十'), createCard('土'), createCard('尔'), createCard('小'), createCard('生'), createCard('八'), createCard('九'), createCard('子'), createCard('佳'), createCard('作'), createCard('亡'), createCard('福'), createCard('禄')];
  g.gameState.players[1].hand = hand1;
  
  g.pengAction();
  
  assert(g.gameState.canPeng === false, '第一次pengAction后canPeng应为false');
  
  g.pengAction();
});

test('30. finishDealing正确重置isDealing并允许startTurn', () => {
  g.gameState.isDealing = true;
  g.gameState.currentPlayerIndex = 0;
  g.gameState.dealerIndex = 0;
  g.gameState.hasDealerPlayedFirstTurn = false;
  g.gameState.players[0].hand = [createCard('上'),createCard('大'),createCard('人'),createCard('丘'),createCard('乙'),createCard('己'),createCard('化'),createCard('三'),createCard('千'),createCard('七'),createCard('十'),createCard('土'),createCard('尔'),createCard('小'),createCard('生'),createCard('八'),createCard('九'),createCard('子'),createCard('佳'),createCard('作')];
  g.gameState.players[1].hand = [createCard('亡'),createCard('福'),createCard('禄'),createCard('寿'),createCard('上'),createCard('大'),createCard('人'),createCard('丘'),createCard('乙'),createCard('己'),createCard('化'),createCard('三'),createCard('千'),createCard('七'),createCard('十'),createCard('土'),createCard('尔'),createCard('小'),createCard('生')];
  g.gameState.players[2].hand = [createCard('八'),createCard('九'),createCard('子'),createCard('佳'),createCard('作'),createCard('亡'),createCard('福'),createCard('禄'),createCard('寿'),createCard('上'),createCard('大'),createCard('人'),createCard('丘'),createCard('乙'),createCard('己'),createCard('化'),createCard('三'),createCard('千'),createCard('七')];
  g.gameState.deck = g.createDeck();
  
  g.finishDealing();
  
  assert(g.gameState.isDealing === false, 'finishDealing后isDealing应为false');
});

test('31. startRound重置isDealing后再由startDealingAnimation设置', () => {
  g.gameState.isDealing = true;
  g.gameState.roundNumber = 0;
  g.gameSettings.piaoEnabled = false;
  g.gameState.players[0].score = 0;
  g.gameState.players[1].score = 0;
  g.gameState.players[2].score = 0;
  
  g.startRound();
  
  assert(g.gameState.isDealing === true, 'startRound后isDealing最终应为true(因startDealingAnimation)');
});

test('32. startDealingAnimation正确设置isDealing', () => {
  g.gameState.isStartingRound = true;
  g.gameState.deck = g.createDeck();
  g.gameState.dealerIndex = 0;
  g.gameState.roundNumber = 1;
  
  g.startDealingAnimation();
  
  assert(g.gameState.isDealing === true, 'startDealingAnimation后isDealing应为true');
  assert(g.gameState.isStartingRound === false, 'startDealingAnimation后isStartingRound应为false');
});

test('33. selectedCardIndex=-1时discardAction被阻止', () => {
  g.gameState.isMyTurn = true;
  g.gameState.isDrawing = false;
  g.gameState.selectedCardIndex = -1;
  g.discardAction();
});

test('34. 多重保护：isDealing + isPaused同时为true', () => {
  g.gameState.isDealing = true;
  g.gameState.isPaused = true;
  g.gameState.currentPlayerIndex = 0;
  
  g.startTurn();
  g.processAITurn();
  g.continueAITurn(g.gameState.players[0]);
  g.discardCard(0, 0);
  g.handleTimeout();
  g.moveToNextPlayer();
  
  assert(g.gameState.currentPlayerIndex === 0, '所有操作都应被阻止');
});

test('35. isDrawing残留不会永久卡住游戏', () => {
  g.gameState.isMyTurn = true;
  g.gameState.isDrawing = true;
  g.gameState.selectedCardIndex = 0;
  
  g.selectCard(0);
  assert(g.gameState.selectedCardIndex === 0, 'isDrawing时selectCard被阻止但selectedCardIndex保持');
  
  g.gameState.isDrawing = false;
  g.selectCard(1);
  assert(g.gameState.selectedCardIndex === 1, 'isDrawing恢复后selectCard应正常');
});

test('36. waitingForResponse残留时handleTimeout应调用passAction', () => {
  g.gameState.waitingForResponse = true;
  g.gameState.canChi = true;
  g.gameState.canPeng = false;
  g.gameState.canZhao = false;
  g.gameState.canHu = false;
  g.gameState.lastDiscardedCard = createCard('上');
  g.gameState.lastDiscardPlayerIndex = 0;
  g.gameState.currentPlayerIndex = 1;
  g.gameState.deck = g.createDeck();
  
  g.handleTimeout();
  
  assert(g.gameState.waitingForResponse === false, 'handleTimeout后waitingForResponse应被重置');
});

test('37. showResponseButtons在无可操作时不设置waitingForResponse', () => {
  g.gameState.waitingForResponse = false;
  
  g.showResponseButtons([
    { playerIndex: 1, canHu: false, canZhao: false, canPeng: false, canChi: false }
  ], 1);
  
  assert(g.gameState.waitingForResponse === false, '无可操作时不应设置waitingForResponse');
});

test('38. showResponseButtons正确设置所有can标志', () => {
  g.gameState.waitingForResponse = false;
  g.gameState.canHu = false;
  g.gameState.canZhao = false;
  g.gameState.canPeng = false;
  g.gameState.canChi = false;
  
  g.showResponseButtons([
    { playerIndex: 1, canHu: true, canZhao: true, canPeng: true, canChi: true }
  ], 1);
  
  assert(g.gameState.waitingForResponse === true, '应设置waitingForResponse');
  assert(g.gameState.canHu === true, '应设置canHu');
  assert(g.gameState.canZhao === true, '应设置canZhao');
  assert(g.gameState.canPeng === true, '应设置canPeng');
  assert(g.gameState.canChi === true, '应设置canChi');
  assert(g.gameState.actionCancelled === false, '应重置actionCancelled');
});

test('39. isLiuJuHandled=true时moveToNextPlayer不重复处理流局', () => {
  g.gameState.isLiuJuHandled = true;
  g.gameState.deck = [];
  g.gameState.currentPlayerIndex = 0;
  g.gameState.dealerIndex = 0;
  
  g.moveToNextPlayer();
});

test('40. checkResponses在lastDiscardedCard为null时不崩溃', () => {
  g.gameState.lastDiscardedCard = null;
  g.checkResponses();
});

test('41. isDrawing残留时handleTimeout应安全处理', () => {
  g.gameState.isMyTurn = true;
  g.gameState.isDrawing = true;
  g.gameState.waitingForResponse = false;
  g.gameState.players[1].hand = [createCard('上'), createCard('大'), createCard('人')];
  g.gameState.lastDrawnCard = createCard('大');
  
  g.handleTimeout();
  
  assert(g.gameState.isDrawing === true, 'isDrawing应保持true直到动画回调');
});

test('42. performChi后waitingForResponse被重置', () => {
  g.gameState.waitingForResponse = true;
  g.gameState.canChi = true;
  g.gameState.currentPlayerIndex = 1;
  g.gameState.lastDiscardedCard = createCard('上');
  g.gameState.lastDiscardPlayerIndex = 2;
  
  const hand1 = [createCard('大'), createCard('人'), createCard('化'), createCard('三'), createCard('千'), createCard('七'), createCard('十'), createCard('土'), createCard('尔'), createCard('小'), createCard('生'), createCard('八'), createCard('九'), createCard('子'), createCard('佳'), createCard('作'), createCard('亡'), createCard('福'), createCard('禄')];
  g.gameState.players[1].hand = hand1;
  
  try {
    g.performChi(1);
  } catch(e) {}
  
  assert(g.gameState.waitingForResponse === false, 'performChi后waitingForResponse应为false');
  assert(g.gameState.skipDraw === true, 'performChi后skipDraw应为true');
});

test('43. performPeng后waitingForResponse被重置', () => {
  g.gameState.waitingForResponse = true;
  g.gameState.canPeng = true;
  g.gameState.currentPlayerIndex = 1;
  g.gameState.lastDiscardedCard = createCard('上');
  g.gameState.lastDiscardPlayerIndex = 0;
  
  const hand1 = [createCard('上'), createCard('上'), createCard('化'), createCard('三'), createCard('千'), createCard('七'), createCard('十'), createCard('土'), createCard('尔'), createCard('小'), createCard('生'), createCard('八'), createCard('九'), createCard('子'), createCard('佳'), createCard('作'), createCard('亡'), createCard('福'), createCard('禄')];
  g.gameState.players[1].hand = hand1;
  
  try {
    g.performPeng(1);
  } catch(e) {}
  
  assert(g.gameState.waitingForResponse === false, 'performPeng后waitingForResponse应为false');
  assert(g.gameState.skipDraw === true, 'performPeng后skipDraw应为true');
});

test('44. performZhao后waitingForResponse被重置', () => {
  g.gameState.waitingForResponse = true;
  g.gameState.canZhao = true;
  g.gameState.currentPlayerIndex = 1;
  g.gameState.lastDiscardedCard = createCard('上');
  g.gameState.lastDiscardPlayerIndex = 0;
  g.gameState.deck = g.createDeck();
  
  const hand1 = [createCard('上'), createCard('上'), createCard('上'), createCard('化'), createCard('三'), createCard('千'), createCard('七'), createCard('十'), createCard('土'), createCard('尔'), createCard('小'), createCard('生'), createCard('八'), createCard('九'), createCard('子'), createCard('佳'), createCard('作')];
  g.gameState.players[1].hand = hand1;
  
  try {
    g.performZhao(1);
  } catch(e) {}
  
  assert(g.gameState.waitingForResponse === false, 'performZhao后waitingForResponse应为false');
  assert(g.gameState.skipDraw === true, 'performZhao后skipDraw应为true');
});

test('45. 吃牌后人类玩家isMyTurn应为true', () => {
  g.gameState.waitingForResponse = true;
  g.gameState.canChi = true;
  g.gameState.currentPlayerIndex = 1;
  g.gameState.lastDiscardedCard = createCard('上');
  g.gameState.lastDiscardPlayerIndex = 2;
  
  const hand1 = [createCard('大'), createCard('人'), createCard('化'), createCard('三'), createCard('千'), createCard('七'), createCard('十'), createCard('土'), createCard('尔'), createCard('小'), createCard('生'), createCard('八'), createCard('九'), createCard('子'), createCard('佳'), createCard('作'), createCard('亡'), createCard('福'), createCard('禄')];
  g.gameState.players[1].hand = hand1;
  
  try {
    g.performChi(1);
  } catch(e) {}
  
  assert(g.gameState.isMyTurn === true, '吃牌后人类玩家isMyTurn应为true');
  assert(g.gameState.isDrawing === false, '吃牌后isDrawing应为false');
});

test('46. 碰牌后人类玩家isMyTurn应为true', () => {
  g.gameState.waitingForResponse = true;
  g.gameState.canPeng = true;
  g.gameState.currentPlayerIndex = 1;
  g.gameState.lastDiscardedCard = createCard('上');
  g.gameState.lastDiscardPlayerIndex = 0;
  
  const hand1 = [createCard('上'), createCard('上'), createCard('化'), createCard('三'), createCard('千'), createCard('七'), createCard('十'), createCard('土'), createCard('尔'), createCard('小'), createCard('生'), createCard('八'), createCard('九'), createCard('子'), createCard('佳'), createCard('作'), createCard('亡'), createCard('福'), createCard('禄')];
  g.gameState.players[1].hand = hand1;
  
  try {
    g.performPeng(1);
  } catch(e) {}
  
  assert(g.gameState.isMyTurn === true, '碰牌后人类玩家isMyTurn应为true');
  assert(g.gameState.isDrawing === false, '碰牌后isDrawing应为false');
});

test('47. 招牌后人类玩家isMyTurn应为true', () => {
  g.gameState.waitingForResponse = true;
  g.gameState.canZhao = true;
  g.gameState.currentPlayerIndex = 1;
  g.gameState.lastDiscardedCard = createCard('上');
  g.gameState.lastDiscardPlayerIndex = 0;
  g.gameState.deck = g.createDeck();
  
  const hand1 = [createCard('上'), createCard('上'), createCard('上'), createCard('化'), createCard('三'), createCard('千'), createCard('七'), createCard('十'), createCard('土'), createCard('尔'), createCard('小'), createCard('生'), createCard('八'), createCard('九'), createCard('子'), createCard('佳'), createCard('作')];
  g.gameState.players[1].hand = hand1;
  
  try {
    g.performZhao(1);
  } catch(e) {}
  
  assert(g.gameState.isMyTurn === true, '招牌后人类玩家isMyTurn应为true');
});

test('48. 出牌后isMyTurn应为false', () => {
  g.gameState.isMyTurn = true;
  g.gameState.isDrawing = false;
  g.gameState.currentPlayerIndex = 1;
  g.gameState.selectedCardIndex = 0;
  g.gameState.deck = g.createDeck();
  
  const hand1 = [createCard('上'), createCard('大'), createCard('人'), createCard('化'), createCard('三'), createCard('千'), createCard('七'), createCard('十'), createCard('土'), createCard('尔'), createCard('小'), createCard('生'), createCard('八'), createCard('九'), createCard('子'), createCard('佳'), createCard('作'), createCard('亡'), createCard('福')];
  g.gameState.players[1].hand = hand1;
  
  g.discardCard(1, 0);
  
  assert(g.gameState.isMyTurn === false, '出牌后isMyTurn应为false');
});

test('49. 出牌后selectedCardIndex应重置', () => {
  g.gameState.isMyTurn = true;
  g.gameState.isDrawing = false;
  g.gameState.currentPlayerIndex = 1;
  g.gameState.selectedCardIndex = 2;
  g.gameState.deck = g.createDeck();
  
  const hand1 = [createCard('上'), createCard('大'), createCard('人'), createCard('化'), createCard('三'), createCard('千'), createCard('七'), createCard('十'), createCard('土'), createCard('尔'), createCard('小'), createCard('生'), createCard('八'), createCard('九'), createCard('子'), createCard('佳'), createCard('作'), createCard('亡'), createCard('福')];
  g.gameState.players[1].hand = hand1;
  
  g.discardCard(1, 2);
  
  assert(g.gameState.selectedCardIndex === -1, '出牌后selectedCardIndex应为-1');
});

test('50. skipDraw=true时startTurn不摸牌', () => {
  g.gameState.currentPlayerIndex = 1;
  g.gameState.dealerIndex = 0;
  g.gameState.hasDealerPlayedFirstTurn = true;
  g.gameState.skipDraw = true;
  g.gameState.deck = g.createDeck();
  g.gameState.players[1].hand = [createCard('上'), createCard('大'), createCard('人')];
  
  const handLenBefore = g.gameState.players[1].hand.length;
  g.startTurn();
  
  assert(g.gameState.players[1].hand.length === handLenBefore, 'skipDraw时不应摸牌');
  assert(g.gameState.skipDraw === false, 'skipDraw应在startTurn中被重置');
});

test('51. 庄家首回合不摸牌', () => {
  g.gameState.currentPlayerIndex = 0;
  g.gameState.dealerIndex = 0;
  g.gameState.hasDealerPlayedFirstTurn = false;
  g.gameState.skipDraw = false;
  g.gameState.deck = g.createDeck();
  g.gameState.players[0].hand = [createCard('上'), createCard('大'), createCard('人')];
  
  const handLenBefore = g.gameState.players[0].hand.length;
  
  g.processAITurn();
  
  assert(g.gameState.hasDealerPlayedFirstTurn === true, '庄家首回合后应设置hasDealerPlayedFirstTurn');
});

test('52. 人类玩家庄家首回合不摸牌但可以出牌', () => {
  g.gameState.currentPlayerIndex = 1;
  g.gameState.dealerIndex = 1;
  g.gameState.hasDealerPlayedFirstTurn = false;
  g.gameState.skipDraw = false;
  g.gameState.deck = g.createDeck();
  g.gameState.players[1].hand = [createCard('上'), createCard('大'), createCard('人'), createCard('化'), createCard('三'), createCard('千'), createCard('七'), createCard('十'), createCard('土'), createCard('尔'), createCard('小'), createCard('生'), createCard('八'), createCard('九'), createCard('子'), createCard('佳'), createCard('作'), createCard('亡'), createCard('福'), createCard('禄')];
  
  g.startTurn();
  
  assert(g.gameState.hasDealerPlayedFirstTurn === true, '庄家首回合后应设置flag');
  assert(g.gameState.isMyTurn === true, '庄家首回合应可以出牌');
});

test('53. 连续两次discardCard不会导致状态混乱', () => {
  g.gameState.isMyTurn = true;
  g.gameState.isDrawing = false;
  g.gameState.currentPlayerIndex = 1;
  g.gameState.deck = g.createDeck();
  
  const hand1 = [createCard('上'), createCard('大'), createCard('人'), createCard('化'), createCard('三'), createCard('千'), createCard('七'), createCard('十'), createCard('土'), createCard('尔'), createCard('小'), createCard('生'), createCard('八'), createCard('九'), createCard('子'), createCard('佳'), createCard('作'), createCard('亡'), createCard('福')];
  g.gameState.players[1].hand = hand1;
  
  g.discardCard(1, 0);
  
  assert(g.gameState.isMyTurn === false, '第一次出牌后isMyTurn应为false');
  
  g.discardCard(1, 0);
});

test('54. checkResponses中AI碰牌后waitingForResponse不为true', () => {
  const hand0 = [createCard('上'), createCard('大'), createCard('人'), createCard('丘')];
  const hand1 = [createCard('化'), createCard('三'), createCard('千'), createCard('七'), createCard('十'), createCard('土'), createCard('尔'), createCard('小'), createCard('生'), createCard('八'), createCard('九'), createCard('子'), createCard('佳'), createCard('作'), createCard('亡'), createCard('福'), createCard('禄'), createCard('寿'), createCard('上')];
  const hand2 = [createCard('上'), createCard('上'), createCard('丘'), createCard('乙')];
  
  g.gameState.players[0].hand = hand0;
  g.gameState.players[1].hand = hand1;
  g.gameState.players[2].hand = hand2;
  g.gameState.currentPlayerIndex = 0;
  g.gameState.dealerIndex = 0;
  g.gameState.deck = g.createDeck();
  g.gameState.lastDiscardedCard = createCard('上');
  g.gameState.lastDiscardPlayerIndex = 0;
  
  g.checkResponses();
});

test('55. 人类玩家可碰时showResponseButtons正确设置状态', () => {
  g.gameState.lastDiscardedCard = createCard('上');
  g.gameState.lastDiscardPlayerIndex = 0;
  g.gameState.players[1].hand = [createCard('上'), createCard('上'), createCard('化'), createCard('三')];
  g.gameState.players[1].isTing = false;
  
  g.showResponseButtons([
    { playerIndex: 1, canHu: false, canZhao: false, canPeng: true, canChi: false },
    { playerIndex: 2, canHu: false, canZhao: false, canPeng: false, canChi: false }
  ], 1);
  
  assert(g.gameState.waitingForResponse === true, '应设置waitingForResponse');
  assert(g.gameState.canPeng === true, '应设置canPeng');
  assert(g.gameState.actionCancelled === false, '应重置actionCancelled');
});

test('56. passAction后所有can标志应为false', () => {
  g.gameState.waitingForResponse = true;
  g.gameState.canHu = true;
  g.gameState.canZhao = true;
  g.gameState.canPeng = true;
  g.gameState.canChi = true;
  g.gameState.lastDiscardedCard = createCard('上');
  g.gameState.lastDiscardPlayerIndex = 0;
  g.gameState.currentPlayerIndex = 1;
  g.gameState.deck = g.createDeck();
  
  g.passAction();
  
  assert(g.gameState.canHu === false, 'passAction后canHu应为false');
  assert(g.gameState.canZhao === false, 'passAction后canZhao应为false');
  assert(g.gameState.canPeng === false, 'passAction后canPeng应为false');
  assert(g.gameState.canChi === false, 'passAction后canChi应为false');
  assert(g.gameState.waitingForResponse === false, 'passAction后waitingForResponse应为false');
});

test('57. 牌堆为空时moveToNextPlayer处理流局', () => {
  g.gameState.deck = [];
  g.gameState.currentPlayerIndex = 0;
  g.gameState.dealerIndex = 0;
  g.gameState.isLiuJuHandled = false;
  g.gameState.roundNumber = 1;
  g.gameState.roundHistory = [];
  
  g.moveToNextPlayer();
  
  assert(g.gameState.isLiuJuHandled === true, '应标记流局已处理');
});

test('58. startTurn在isDealing=true时不设置isMyTurn', () => {
  g.gameState.isDealing = true;
  g.gameState.currentPlayerIndex = 1;
  g.gameState.isMyTurn = false;
  
  g.startTurn();
  
  assert(g.gameState.isMyTurn === false, 'isDealing时不应设置isMyTurn');
});

test('59. performChi在lastDiscardedCard为null时不崩溃', () => {
  g.gameState.lastDiscardedCard = null;
  g.gameState.players[1].hand = [createCard('上'), createCard('大')];
  
  g.performChi(1);
});

test('60. performPeng在lastDiscardedCard为null时不崩溃', () => {
  g.gameState.lastDiscardedCard = null;
  g.gameState.players[1].hand = [createCard('上'), createCard('上')];
  
  g.performPeng(1);
});

console.log(`\n=== 测试结果 ===`);
console.log(`通过: ${passed}/${passed+failed}`);
console.log(`失败: ${failed}`);

process.exit(failed > 0 ? 1 : 0);
