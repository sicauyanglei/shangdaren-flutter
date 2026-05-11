// 安卓手机音频修复
let audioContext = null;
let audioInitialized = false;
let voicesLoaded = false;
let lastSpeakTime = 0;

// 检测是否是安卓设备
function isAndroid() {
  return /Android/i.test(navigator.userAgent);
}

// 初始化语音合成
function initSpeechSynthesis() {
  if (!('speechSynthesis' in window)) {
    console.warn('speechSynthesis not supported');
    return false;
  }
  
  // 加载语音列表
  const loadVoices = () => {
    const voices = speechSynthesis.getVoices();
    if (voices.length > 0) {
      voicesLoaded = true;
      console.log('语音列表已加载, 数量:', voices.length);
      // 查找中文语音
      const zhVoice = voices.find(v => v.lang.includes('zh'));
      if (zhVoice) {
        console.log('找到中文语音:', zhVoice.name);
      }
    }
  };
  
  // 立即尝试加载
  loadVoices();
  
  // 监听语音列表变化
  speechSynthesis.onvoiceschanged = loadVoices;
  
  return true;
}

// 初始化Web Audio
function initAudioContext() {
  if (audioContext) return audioContext;
  
  try {
    const AudioContextClass = window.AudioContext || window.webkitAudioContext;
    if (AudioContextClass) {
      audioContext = new AudioContextClass();
      console.log('AudioContext已创建, state:', audioContext.state);
    }
  } catch (e) {
    console.error('AudioContext创建失败:', e);
  }
  
  return audioContext;
}

// 恢复AudioContext（安卓需要用户交互后才能播放）
async function resumeAudioContext() {
  if (!audioContext) {
    initAudioContext();
  }
  
  if (audioContext && audioContext.state === 'suspended') {
    try {
      await audioContext.resume();
      console.log('AudioContext已恢复, state:', audioContext.state);
    } catch (e) {
      console.error('AudioContext恢复失败:', e);
    }
  }
}

// 播放语音（使用本地音频文件）
async function speakText(text, playerIndex = -1) {
  console.log('speakText called:', text, 'playerIndex:', playerIndex);
  
  // 防止重复播放
  const now = Date.now();
  if (now - lastSpeakTime < 300) {
    console.log('播放间隔太短，跳过');
    return;
  }
  lastSpeakTime = now;
  
  // 确保AudioContext已初始化
  if (!audioContext) {
    initAudioContext();
  }
  await resumeAudioContext();
  
  // 播放本地音频文件
  await playLocalAudio(text, playerIndex);
}

// 音频文件映射
const audioFileMap = {
  // 游戏操作
  '吃': 'chi', '碰': 'peng', '招': 'zhao', '胡': 'hu', '自摸': 'zimo', '出牌': 'chupai',
  
  // 胡牌类型
  '枯胡': 'kuhu', '清枯胡': 'qingkuhu', '枯重台卡': 'kuchongtaika', '枯重台胡': 'kuchongtaihu',
  '清枯台卡': 'qingkutaika', '十对': 'shidui', '黑元': 'heiyuan', '红元': 'hongyuan',
  '卡胡': 'kahu', '普通胡': 'putonghu', '台卡': 'taika', '台胡': 'taihu',
  '重台卡': 'chongtaika', '重台胡': 'chongtaihu',
  
  // 24个字牌
  '上': 'shang', '大': 'da', '人': 'ren', '丘': 'qiu', '乙': 'yi', '己': 'ji',
  '化': 'hua', '三': 'san', '千': 'qian', '七': 'qi', '十': 'shi', '土': 'tu',
  '尔': 'er', '小': 'xiao', '生': 'sheng', '八': 'ba', '九': 'jiu', '子': 'zi',
  '佳': 'jia', '作': 'zuo', '亡': 'wang', '福': 'fu', '禄': 'lu', '寿': 'shou'
};

// 播放本地音频文件
async function playLocalAudio(text, playerIndex = -1) {
  const fileName = audioFileMap[text];
  if (!fileName) {
    console.log('未找到音频文件映射:', text);
    return;
  }
  
  // 获取指定玩家或当前玩家的声音类型
  let voiceType = 'male';
  const idx = playerIndex >= 0 ? playerIndex : gameState.currentPlayerIndex;
  if (idx >= 0 && gameState.players[idx]) {
    voiceType = gameState.players[idx].voiceType || 'male';
  }
  
  const audioPath = `audio/${voiceType}/${fileName}.mp3`;
  console.log('播放音频:', audioPath, '声音类型:', voiceType, '玩家索引:', idx);
  
  try {
    const audio = new Audio(audioPath);
    audio.volume = 1.0;
    
    return new Promise((resolve) => {
      const timeout = setTimeout(() => {
        console.log('音频播放超时');
        resolve();
      }, 3000);
      
      audio.oncanplaythrough = () => {
        console.log('音频加载完成');
      };
      
      audio.onplay = () => {
        console.log('音频开始播放');
      };
      
      audio.onended = () => {
        clearTimeout(timeout);
        console.log('音频播放结束');
        resolve();
      };
      
      audio.onerror = (e) => {
        clearTimeout(timeout);
        console.error('音频播放错误:', e, '路径:', audioPath);
        // 如果本地文件不存在，尝试使用SpeechSynthesis
        playWithSpeechSynthesis(text).then(resolve);
      };
      
      audio.play().catch(e => {
        clearTimeout(timeout);
        console.error('audio.play错误:', e);
        playWithSpeechSynthesis(text).then(resolve);
      });
    });
    
  } catch (e) {
    console.error('playLocalAudio错误:', e);
    return playWithSpeechSynthesis(text);
  }
}

// 使用SpeechSynthesis作为备用
async function playWithSpeechSynthesis(text) {
  if (!('speechSynthesis' in window)) {
    console.warn('SpeechSynthesis不支持');
    return;
  }
  
  try {
    speechSynthesis.cancel();
    await new Promise(resolve => setTimeout(resolve, 50));
    
    const utterance = new SpeechSynthesisUtterance(text);
    utterance.lang = 'zh-CN';
    utterance.rate = 0.9;
    utterance.volume = 1.0;
    
    const voices = speechSynthesis.getVoices();
    const zhVoice = voices.find(v => v.lang.includes('zh') || v.lang.includes('CN'));
    if (zhVoice) {
      utterance.voice = zhVoice;
    }
    
    return new Promise((resolve) => {
      const timeout = setTimeout(() => {
        console.log('SpeechSynthesis超时');
        resolve();
      }, 3000);
      
      utterance.onend = () => {
        clearTimeout(timeout);
        console.log('SpeechSynthesis播放结束');
        resolve();
      };
      
      utterance.onerror = () => {
        clearTimeout(timeout);
        resolve();
      };
      
      speechSynthesis.speak(utterance);
    });
    
  } catch (e) {
    console.error('SpeechSynthesis错误:', e);
  }
}

// 根据文字播放不同音效
function playSoundEffect(text) {
  console.log('playSoundEffect called:', text, 'audioContext:', audioContext ? audioContext.state : 'null');
  
  if (!audioContext) {
    console.error('AudioContext未初始化');
    return;
  }
  
  // 如果AudioContext被暂停，先恢复
  if (audioContext.state === 'suspended') {
    console.log('AudioContext被暂停，尝试恢复...');
    audioContext.resume().then(() => {
      console.log('AudioContext已恢复');
      doPlaySound(text);
    }).catch(e => {
      console.error('AudioContext恢复失败:', e);
    });
  } else {
    doPlaySound(text);
  }
}

// 实际播放音效
function doPlaySound(text) {
  console.log('doPlaySound called:', text);
  
  try {
    // 根据不同文字设置不同频率
    const frequencyMap = {
      '吃': 523,
      '碰': 659,
      '招': 784,
      '胡': 880,
      '自摸': 1047,
      '出牌': 440,
      '快点吧，我等的花儿都谢了': 330,
      '枯胡': 587,
      '清枯胡': 698,
      '枯重台卡': 784,
      '枯重台胡': 880,
      '清枯台卡': 698,
      '十对': 523,
      '黑元': 440,
      '红元': 523,
      '卡胡': 392,
      '普通胡': 440,
      '台卡': 523,
      '台胡': 587,
      '重台卡': 659,
      '重台胡': 698
    };
    
    // 获取频率，默认440Hz
    let frequency = 440;
    for (const key in frequencyMap) {
      if (text.includes(key)) {
        frequency = frequencyMap[key];
        break;
      }
    }
    
    const oscillator = audioContext.createOscillator();
    const gainNode = audioContext.createGain();
    
    oscillator.connect(gainNode);
    gainNode.connect(audioContext.destination);
    
    oscillator.frequency.value = frequency;
    oscillator.type = 'sine';
    
    // 音量包络 - 使用更简单的方式
    const currentTime = audioContext.currentTime;
    gainNode.gain.setValueAtTime(0.5, currentTime);
    gainNode.gain.exponentialRampToValueAtTime(0.01, currentTime + 0.3);
    
    oscillator.start(currentTime);
    oscillator.stop(currentTime + 0.3);
    
    console.log('音效已播放:', text, '频率:', frequency);
    
  } catch (e) {
    console.error('播放音效失败:', e);
  }
}

// 播放蜂鸣音效（备用方案）
function playBeepSound() {
  playSoundEffect('beep');
}

// 播放按钮音效
async function playButtonSound(text, playerIndex = -1) {
  console.log('playButtonSound called:', text, 'playerIndex:', playerIndex);
  await speakText(text, playerIndex);
}

// 初始化音频系统（在用户交互时调用）
async function initAudioOnUserInteraction() {
  if (audioInitialized) return;
  audioInitialized = true;
  
  console.log('initAudioOnUserInteraction called');
  
  // 初始化语音合成
  initSpeechSynthesis();
  
  // 初始化并恢复AudioContext
  initAudioContext();
  await resumeAudioContext();
  
  // 播放一个静音音效来激活音频系统
  if (audioContext && audioContext.state === 'running') {
    try {
      const oscillator = audioContext.createOscillator();
      const gainNode = audioContext.createGain();
      oscillator.connect(gainNode);
      gainNode.connect(audioContext.destination);
      oscillator.frequency.value = 440;
      gainNode.gain.value = 0.01;
      oscillator.start();
      oscillator.stop(audioContext.currentTime + 0.05);
      console.log('静音音效已播放，音频系统已激活');
    } catch (e) {
      console.error('播放静音音效失败:', e);
    }
  }
  
  // 安卓特殊：预加载语音
  if (isAndroid() && 'speechSynthesis' in window) {
    // 触发语音列表加载
    speechSynthesis.getVoices();
  }
}

// 监听用户交互事件（只触发一次）
function setupAudioListeners() {
  const events = ['click', 'touchstart', 'touchend', 'pointerdown'];
  const handler = (e) => {
    initAudioOnUserInteraction();
    // 第一次交互后移除监听器
    events.forEach(ev => {
      document.removeEventListener(ev, handler, true);
    });
  };
  
  events.forEach(ev => {
    document.addEventListener(ev, handler, true);
  });
}

setupAudioListeners();

// 页面加载时初始化
document.addEventListener('DOMContentLoaded', () => {
  initSpeechSynthesis();
  initAudioContext();
});

async function lockScreenOrientation() {
  try {
    if (screen.orientation && screen.orientation.lock) {
      await screen.orientation.lock('landscape');
      console.log('屏幕方向已锁定为横屏');
      // 屏幕方向锁定后重新初始化音频
      audioInitialized = false;
      initAudioOnUserInteraction();
    }
  } catch (err) {
    console.log('屏幕方向锁定失败:', err);
  }
}

document.addEventListener('DOMContentLoaded', () => {
  lockScreenOrientation();
});

if (screen.orientation) {
  screen.orientation.addEventListener('change', () => {
    console.log('屏幕方向变化:', screen.orientation.type);
    // 屏幕方向变化后重新初始化音频
    audioInitialized = false;
    initAudioOnUserInteraction();
  });
}

let wakeLock = null;

async function requestWakeLock() {
  try {
    if ('wakeLock' in navigator && document.visibilityState === 'visible') {
      wakeLock = await navigator.wakeLock.request('screen');
      console.log('屏幕常亮已启用');
      
      wakeLock.addEventListener('release', () => {
        console.log('屏幕常亮已释放');
      });
    }
  } catch (err) {
    console.log('屏幕常亮请求失败:', err);
  }
}

async function releaseWakeLock() {
  if (wakeLock) {
    await wakeLock.release();
    wakeLock = null;
  }
}

document.addEventListener('visibilitychange', async () => {
  if (document.visibilityState === 'visible') {
    await requestWakeLock();
  }
});

document.addEventListener('DOMContentLoaded', () => {
  requestWakeLock();
});

const CARD_COLORS = {
  red: ['上', '丘', '化', '七', '尔', '八', '佳', '福'],
  green: ['大', '乙', '三', '十', '小', '九', '作', '禄'],
  black: ['人', '己', '千', '土', '生', '子', '亡', '寿']
};

const CARD_SENTENCES = {
  '上': 1, '大': 1, '人': 1,
  '丘': 2, '乙': 2, '己': 2,
  '化': 3, '三': 3, '千': 3,
  '七': 4, '十': 4, '土': 4,
  '尔': 5, '小': 5, '生': 5,
  '八': 6, '九': 6, '子': 6,
  '佳': 7, '作': 7, '亡': 7,
  '福': 8, '禄': 8, '寿': 8
};

const CARD_POSITIONS = {
  '上': 0, '大': 1, '人': 2,
  '丘': 0, '乙': 1, '己': 2,
  '化': 0, '三': 1, '千': 2,
  '七': 0, '十': 1, '土': 2,
  '尔': 0, '小': 1, '生': 2,
  '八': 0, '九': 1, '子': 2,
  '佳': 0, '作': 1, '亡': 2,
  '福': 0, '禄': 1, '寿': 2
};

const CARD_PINYIN = {
  '上': 'shang', '大': 'da', '人': 'ren',
  '丘': 'qiu', '乙': 'yi', '己': 'ji',
  '化': 'hua', '三': 'san', '千': 'qian',
  '七': 'qi', '十': 'shi', '土': 'tu',
  '尔': 'er', '小': 'xiao', '生': 'sheng',
  '八': 'ba', '九': 'jiu', '子': 'zi',
  '佳': 'jia', '作': 'zuo', '亡': 'wang',
  '福': 'fu', '禄': 'lu', '寿': 'shou'
};

const SPECIAL_CARDS = ['上', '福'];

let gameState = {
  deck: [],
  players: [
    { id: 'player1', name: '玩家1', type: 'ai', hand: [], melds: [], discards: [], score: 0, piao: 0, isTing: false },
    { id: 'me', name: '我', type: 'human', hand: [], melds: [], discards: [], score: 0, piao: 0, isTing: false },
    { id: 'player2', name: '玩家2', type: 'ai', hand: [], melds: [], discards: [], score: 0, piao: 0, isTing: false }
  ],
  currentPlayerIndex: 0,
  dealerIndex: 0,
  roundNumber: 0,
  sessionNumber: 1,
  lastDiscardedCard: null,
  lastDiscardPlayerIndex: -1,
  lastDrawnCard: null,
  selectedCardIndex: -1,
  countdown: 30,
  countdownTimer: null,
  isMyTurn: false,
  waitingForResponse: false,
  canChi: false,
  canPeng: false,
  canZhao: false,
  canHu: false,
  skipDraw: false,
  isDrawing: false,
  baseScore: 5,
  multiplierBase: 2,
  playerVoices: ['female', 'male', 'female'],
  roundHistory: []
};

function selectOption(type, value) {
  gameState[type] = value;
  
  const buttonsContainer = document.getElementById(`${type}Buttons`);
  const buttons = buttonsContainer.querySelectorAll('.option-btn');
  buttons.forEach(btn => {
    btn.classList.toggle('selected', parseInt(btn.dataset.value) === value);
  });
}

function getCardColor(char) {
  if (CARD_COLORS.red.includes(char)) return 'red';
  if (CARD_COLORS.green.includes(char)) return 'green';
  return 'black';
}

function isSpecialCard(char) {
  return SPECIAL_CARDS.includes(char);
}

function createDeck() {
  const deck = [];
  const chars = Object.keys(CARD_SENTENCES);
  for (const char of chars) {
    for (let i = 0; i < 4; i++) {
      deck.push({
        id: `${char}-${deck.length}`,
        character: char,
        sentence: CARD_SENTENCES[char],
        position: CARD_POSITIONS[char],
        color: getCardColor(char),
        isSpecial: isSpecialCard(char)
      });
    }
  }
  return deck;
}

function shuffleDeck(deck) {
  for (let i = deck.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    [deck[i], deck[j]] = [deck[j], deck[i]];
  }
  return deck;
}

function sortHand(hand) {
  return hand.sort((a, b) => {
    if (a.sentence !== b.sentence) return a.sentence - b.sentence;
    return a.position - b.position;
  });
}

async function enterFullscreenAndLockOrientation() {
  try {
    const docEl = document.documentElement;
    
    if (docEl.requestFullscreen) {
      await docEl.requestFullscreen();
    } else if (docEl.webkitRequestFullscreen) {
      await docEl.webkitRequestFullscreen();
    } else if (docEl.mozRequestFullScreen) {
      await docEl.mozRequestFullScreen();
    } else if (docEl.msRequestFullscreen) {
      await docEl.msRequestFullscreen();
    }
    
    console.log('已进入全屏模式');
    
    // 全屏后立即初始化音频
    initAudioOnUserInteraction();
    
    await new Promise(resolve => setTimeout(resolve, 100));
    
    if (screen.orientation && screen.orientation.lock) {
      try {
        await screen.orientation.lock('landscape');
        console.log('屏幕方向已锁定为横屏');
        // 屏幕方向锁定后再次初始化音频
        initAudioOnUserInteraction();
      } catch (e) {
        console.log('屏幕方向锁定不支持:', e);
      }
    }
    
    return true;
  } catch (err) {
    console.log('全屏模式失败:', err);
    return false;
  }
}

function startGame() {
  initAudioContext();
  
  const startScreen = document.getElementById('startScreen');
  const gameContainer = document.querySelector('.game-container');
  
  startScreen.classList.add('hidden');
  startScreen.style.display = 'none';
  
  gameContainer.style.display = '';
  
  enterFullscreenAndLockOrientation().catch(err => {
    console.log('全屏或锁定方向失败:', err);
  });
  
  startRound();
}

let piaoCountdown = 10;
let piaoCountdownTimer = null;
let currentPiaoPlayerIndex = 0;

function showPiaoScreen() {
  currentPiaoPlayerIndex = gameState.dealerIndex;
  showPlayerPiaoScreen();
}

function showPlayerPiaoScreen() {
  const player = gameState.players[currentPiaoPlayerIndex];

  const playerIds = ['player1', 'my', 'player2'];
  const playerId = playerIds[currentPiaoPlayerIndex];
  
  console.log('showPlayerPiaoScreen - currentPiaoPlayerIndex:', currentPiaoPlayerIndex, 'playerId:', playerId);
  
  const piaoPopup = document.getElementById(`${playerId}PiaoPopup`);
  
  if (!piaoPopup) {
    console.error('Missing piao popup element');
    return;
  }
  
  piaoPopup.classList.remove('hidden');
  
  showPiaoCountdownTimer(currentPiaoPlayerIndex);
  
  if (player.type === 'ai') {
    setTimeout(() => {
      const piaoOptions = [0, 5, 10, 20];
      const randomIndex = Math.floor(Math.random() * piaoOptions.length);
      const piao = piaoOptions[randomIndex];
      player.piao = piao;
      updatePlayerPiaoBadge(currentPiaoPlayerIndex);
      hidePiaoCountdownTimer(currentPiaoPlayerIndex);
      setTimeout(() => {
        piaoPopup.classList.add('hidden');
        moveToNextPiaoPlayer();
      }, 500);
    }, 800);
  } else {
    console.log('Showing piao options for human player');
    piaoCountdown = 10;
    if (piaoCountdownTimer) {
      clearInterval(piaoCountdownTimer);
    }
    piaoCountdownTimer = setInterval(() => {
      piaoCountdown--;
      console.log('飘分倒计时:', piaoCountdown);
      updatePiaoCountdownDisplay(currentPiaoPlayerIndex, piaoCountdown);
      if (piaoCountdown <= 0) {
        clearInterval(piaoCountdownTimer);
        piaoCountdownTimer = null;
        setPiao(0);
      }
    }, 1000);
  }
}

function showPiaoCountdownTimer(playerIndex) {
  const playerIds = ['player1', 'my', 'player2'];
  const playerId = playerIds[playerIndex];
  const avatarEl = document.getElementById(`${playerId}Avatar`);
  
  if (!avatarEl) return;
  
  let timerEl = avatarEl.querySelector('.player-timer');
  if (!timerEl) {
    timerEl = document.createElement('div');
    timerEl.className = 'player-timer';
    avatarEl.appendChild(timerEl);
  }
  
  timerEl.textContent = '10';
  timerEl.style.display = 'flex';
}

function updatePiaoCountdownDisplay(playerIndex, countdown) {
  const playerIds = ['player1', 'my', 'player2'];
  const playerId = playerIds[playerIndex];
  const avatarEl = document.getElementById(`${playerId}Avatar`);
  
  if (!avatarEl) return;
  
  const timerEl = avatarEl.querySelector('.player-timer');
  if (timerEl) {
    timerEl.textContent = countdown > 0 ? countdown : '';
    if (countdown <= 3 && countdown > 0) {
      timerEl.classList.add('warning');
    } else {
      timerEl.classList.remove('warning');
    }
  }
}

function hidePiaoCountdownTimer(playerIndex) {
  const playerIds = ['player1', 'my', 'player2'];
  const playerId = playerIds[playerIndex];
  const avatarEl = document.getElementById(`${playerId}Avatar`);
  
  if (!avatarEl) return;
  
  const timerEl = avatarEl.querySelector('.player-timer');
  if (timerEl) {
    timerEl.style.display = 'none';
  }
}

function updatePlayerPiaoBadge(playerIndex) {
  console.log('=== updatePlayerPiaoBadge ===');
  console.log('playerIndex:', playerIndex);
  
  const player = gameState.players[playerIndex];
  const playerIds = ['player1', 'my', 'player2'];
  const playerId = playerIds[playerIndex];
  
  console.log('playerId:', playerId);
  console.log('player.piao:', player.piao);
  
  const piaoBadge = document.getElementById(`${playerId}Piao`);
  console.log('piaoBadge element:', piaoBadge);
  console.log('All elements with Piao:', document.querySelectorAll('[id$="Piao"]'));
  
  console.log('=== 界面元素ID列表 ===');
  console.log('玩家1名字:', document.getElementById('player1Name'));
  console.log('玩家1飘分:', document.getElementById('player1Piao'));
  console.log('玩家1倒计时:', document.getElementById('player1Timer'));
  console.log('玩家2名字:', document.getElementById('player2Name'));
  console.log('玩家2飘分:', document.getElementById('player2Piao'));
  console.log('玩家2倒计时:', document.getElementById('player2Timer'));
  console.log('我的名字:', document.getElementById('myName'));
  console.log('我的飘分:', document.getElementById('myPiao'));
  console.log('我的倒计时:', document.getElementById('myTimer'));
  
  if (piaoBadge) {
    if (player.piao > 0) {
      piaoBadge.textContent = `飘${player.piao}分`;
      piaoBadge.classList.remove('hidden');
      
      if (player.piao === 5) {
        piaoBadge.style.background = 'linear-gradient(145deg, #4a90e2, #357abd)';
      } else if (player.piao === 10) {
        piaoBadge.style.background = 'linear-gradient(145deg, #f5a623, #e09000)';
      } else if (player.piao === 20) {
        piaoBadge.style.background = 'linear-gradient(145deg, #ff6b6b, #e55555)';
      }
    } else {
      piaoBadge.textContent = '';
      piaoBadge.classList.remove('hidden');
      piaoBadge.style.background = 'linear-gradient(145deg, #6c757d, #5a6268)';
    }
    console.log('piaoBadge updated, textContent:', piaoBadge.textContent);
    console.log('piaoBadge classes:', piaoBadge.className);
  } else {
    console.error('piaoBadge not found for playerId:', playerId);
    console.log('Trying to find element with querySelector:', document.querySelector(`#${playerId}Piao`));
  }
}

function updatePiaoCountdown() {
  const countdownEl = document.getElementById('piaoCountdown');
  if (countdownEl) {
    countdownEl.textContent = piaoCountdown > 0 ? `${piaoCountdown}秒` : '';
  }
}

function setPiao(piao) {
  if (piaoCountdownTimer) {
    clearInterval(piaoCountdownTimer);
    piaoCountdownTimer = null;
  }
  
  hidePiaoCountdownTimer(currentPiaoPlayerIndex);
  
  const player = gameState.players[currentPiaoPlayerIndex];
  player.piao = piao;
  
  const playerIds = ['player1', 'my', 'player2'];
  const playerId = playerIds[currentPiaoPlayerIndex];
  const piaoPopup = document.getElementById(`${playerId}PiaoPopup`);
  
  updatePlayerPiaoBadge(currentPiaoPlayerIndex);
  
  setTimeout(() => {
    piaoPopup.classList.add('hidden');
    moveToNextPiaoPlayer();
  }, 300);
}

function moveToNextPiaoPlayer() {
  currentPiaoPlayerIndex = (currentPiaoPlayerIndex + 1) % 3;
  
  if (currentPiaoPlayerIndex === gameState.dealerIndex) {
    startDealingAnimation();
  } else {
    showPlayerPiaoScreen();
  }
}

function startRound() {
  gameState.roundNumber++;
  gameState.deck = shuffleDeck(createDeck());
  gameState.lastDiscardedCard = null;
  gameState.lastDiscardPlayerIndex = -1;
  gameState.lastDrawnCard = null;
  gameState.selectedCardIndex = -1;
  gameState.isMyTurn = false;
  gameState.waitingForResponse = false;
  gameState.currentPlayerIndex = 0;
  gameState.countdown = 0;
  gameState.canChi = false;
  gameState.canPeng = false;
  gameState.canZhao = false;
  gameState.canHu = false;
  gameState.skipDraw = false;
  gameState.isDrawing = false;
  
  if (gameState.countdownTimer) {
    clearInterval(gameState.countdownTimer);
    gameState.countdownTimer = null;
  }
  
  if (gameState.roundNumber === 1) {
    gameState.players.forEach((player, index) => {
      player.voiceType = Math.random() > 0.5 ? 'male' : 'female';
      console.log(`玩家${index + 1}声音类型: ${player.voiceType}`);
    });
  }
  
  const deckStack = document.getElementById('deckStack');
  if (deckStack) {
    deckStack.style.transition = 'none';
    deckStack.style.transform = 'translateY(0)';
  }
  
  const centerArea = document.querySelector('.center-area');
  if (centerArea) {
    centerArea.classList.remove('moved-up');
  }
  
  for (const player of gameState.players) {
    player.hand = [];
    player.melds = [];
    player.discards = [];
    player.piao = 0;
    player.isTing = false;
  }
  
  document.querySelectorAll('.player-piao-badge').forEach(el => {
    el.classList.add('hidden');
  });
  
  updateAvatars();
  document.getElementById('roundNum').textContent = `${gameState.roundNumber}/8`;
  updateDeckStack();
  
  showPiaoScreen();
}

function startDealingAnimation() {
  console.log('开始发牌动画...');
  console.log('牌堆数量:', gameState.deck.length);
  
  document.querySelectorAll('.piao-setting-popup').forEach(el => {
    el.classList.add('hidden');
  });
  
  const overlay = document.getElementById('dealingOverlay');
  const mask = document.getElementById('dealingMask');
  overlay.style.display = 'flex';
  mask.style.display = 'block';
  
  updateDeckStack();
  
  const dealerIndex = gameState.dealerIndex;
  const handCounts = [19, 19, 19];
  handCounts[dealerIndex] = 20;
  
  console.log('庄家索引:', dealerIndex, '各玩家手牌数:', handCounts);
  
  let totalDealt = 0;
  const totalCards = 20 + 19 + 19;
  
  const dealNextCard = () => {
    let playerIndex = -1;
    
    for (let i = 0; i < 3; i++) {
      const p = (totalDealt + i) % 3;
      if (gameState.players[p].hand.length < handCounts[p]) {
        playerIndex = p;
        break;
      }
    }
    
    if (playerIndex === -1 || totalDealt >= totalCards) {
      finishDealing();
      return;
    }
    
    const card = gameState.deck.shift();
    if (card) {
      gameState.players[playerIndex].hand.push(card);
      updateDeckStack();
      
      if (playerIndex === 1) {
        renderMyHand();
      }
    }
    
    totalDealt++;
    
    if (totalDealt < totalCards) {
      setTimeout(dealNextCard, 30);
    } else {
      setTimeout(finishDealing, 200);
    }
  };
  
  setTimeout(dealNextCard, 300);
}

function createFlyingCard(startX, startY, target, reveal, cardData) {
  const card = document.createElement('div');
  card.style.position = 'fixed';
  card.style.left = startX + 'px';
  card.style.top = startY + 'px';
  card.style.width = '35px';
  card.style.height = '147px';
  card.style.borderRadius = '4px';
  card.style.boxShadow = '0 4px 15px rgba(0,0,0,0.5)';
  card.style.zIndex = '9999';
  card.style.pointerEvents = 'none';
  
  if (reveal && cardData) {
    const pinyin = CARD_PINYIN[cardData.character];
    card.style.backgroundImage = `url('images/${pinyin}.png')`;
    card.style.backgroundSize = 'contain';
    card.style.backgroundPosition = 'center';
    card.style.backgroundRepeat = 'no-repeat';
    card.style.backgroundColor = 'transparent';
    card.style.border = 'none';
  } else {
    card.style.backgroundImage = `url('images/back.png')`;
    card.style.backgroundSize = 'contain';
    card.style.backgroundPosition = 'center';
    card.style.backgroundRepeat = 'no-repeat';
  }
  
  document.body.appendChild(card);
  
  setTimeout(() => {
    card.style.transition = 'all 0.2s ease-out';
    card.style.left = target.x + 'px';
    card.style.top = target.y + 'px';
  }, 20);
  
  setTimeout(() => {
    card.remove();
  }, 250);
}

function finishDealing() {
  console.log('完成发牌，整理手牌');
  
  const overlay = document.getElementById('dealingOverlay');
  const mask = document.getElementById('dealingMask');
  overlay.style.display = 'none';
  mask.style.display = 'none';
  
  const centerArea = document.querySelector('.center-area');
  if (centerArea) {
    centerArea.classList.add('moved-up');
    centerArea.classList.add('dealing-complete');
  }
  
  for (let i = 0; i < gameState.players.length; i++) {
    gameState.players[i].hand = sortHand(gameState.players[i].hand);
    console.log('玩家', i, '手牌数:', gameState.players[i].hand.length);
  }
  
  gameState.currentPlayerIndex = gameState.dealerIndex;
  gameState.lastDrawnCard = null;
  
  renderMyHand();
  
  console.log('=== 发牌完成后的手牌数量 ===');
  for (let i = 0; i < 3; i++) {
    console.log(`玩家${i}(${gameState.players[i].name})手牌数:`, gameState.players[i].hand.length);
    console.log(`玩家${i}(${gameState.players[i].name})手牌:`, gameState.players[i].hand.map(c => c.character).join(''));
  }
  
  document.getElementById('player1HandCount').textContent = gameState.players[0].hand.length;
  document.getElementById('myHandCount').textContent = gameState.players[1].hand.length;
  document.getElementById('player2HandCount').textContent = gameState.players[2].hand.length;
  
  updateDeckStack();
  
  setTimeout(() => {
    startTurn();
  }, 300);
}

function updateDeckStack() {
  const deckStack = document.getElementById('deckStack');
  const deckCount = gameState.deck.length;
  
  let cardCount = 1;
  if (deckCount >= 60) {
    cardCount = 10;
  } else if (deckCount >= 50) {
    cardCount = 8;
  } else if (deckCount >= 40) {
    cardCount = 7;
  } else if (deckCount >= 30) {
    cardCount = 6;
  } else if (deckCount >= 20) {
    cardCount = 5;
  } else if (deckCount >= 10) {
    cardCount = 4;
  } else if (deckCount >= 5) {
    cardCount = 3;
  } else if (deckCount > 0) {
    cardCount = 2;
  }
  
  let html = '';
  for (let i = 0; i < cardCount; i++) {
    const top = i * 1;
    const left = i * 4;
    const opacity = 0.4 + (i / cardCount) * 0.6;
    const rotate = (Math.random() - 0.5) * 1;
    html += `<div class="deck-card" style="top:${top}px;left:${left}px;opacity:${opacity};transform:rotate(${rotate}deg);"></div>`;
  }
  html += `<span class="deck-count-overlay">${deckCount}</span>`;
  
  deckStack.innerHTML = html;
}

function renderMyHand() {
  const me = gameState.players[1];
  const handEl = document.getElementById('myHand');
  handEl.innerHTML = '';
  
  const sentenceGroups = {};
  for (let i = 0; i < me.hand.length; i++) {
    const card = me.hand[i];
    if (!sentenceGroups[card.sentence]) {
      sentenceGroups[card.sentence] = {};
    }
    if (!sentenceGroups[card.sentence][card.position]) {
      sentenceGroups[card.sentence][card.position] = [];
    }
    sentenceGroups[card.sentence][card.position].push({ card, index: i });
  }
  
  for (let sentence = 1; sentence <= 8; sentence++) {
    if (!sentenceGroups[sentence]) continue;
    
    const groupEl = document.createElement('div');
    groupEl.className = 'sentence-group';
    
    for (let pos = 0; pos <= 2; pos++) {
      if (!sentenceGroups[sentence][pos]) continue;
      
      const cards = sentenceGroups[sentence][pos];
      const stackEl = document.createElement('div');
      stackEl.className = 'card-stack';
      
      const card = cards[0].card;
      const cardEl = createCardImageElement(card);
      
      const isSelected = cards.some(c => c.index === gameState.selectedCardIndex);
      if (isSelected) {
        cardEl.style.transform = 'translateY(-20px)';
        cardEl.style.boxShadow = '0 8px 25px rgba(255,215,0,0.8), 0 0 30px rgba(255,215,0,0.6)';
        cardEl.style.border = '3px solid #ffd700';
        cardEl.style.borderRadius = '6px';
      }
      
      cardEl.onclick = function() { selectCard(cards[0].index); };
      
      function startDrag(clientX, clientY) {
        if (!gameState.isMyTurn) return;
        
        const cardIndex = cards[0].index;
        const cardRect = cardEl.getBoundingClientRect();
        const offsetX = clientX - cardRect.left;
        const offsetY = clientY - cardRect.top;
        
        const dragCard = cardEl.cloneNode(true);
        dragCard.style.position = 'fixed';
        dragCard.style.zIndex = '10000';
        dragCard.style.left = cardRect.left + 'px';
        dragCard.style.top = cardRect.top + 'px';
        dragCard.style.transform = 'none';
        dragCard.style.boxShadow = '0 10px 30px rgba(0,0,0,0.5)';
        dragCard.style.pointerEvents = 'none';
        
        const chuLabel = document.createElement('div');
        chuLabel.textContent = '出';
        chuLabel.style.position = 'absolute';
        chuLabel.style.left = '50%';
        chuLabel.style.top = '50%';
        chuLabel.style.transform = 'translate(-50%, -50%)';
        chuLabel.style.fontSize = '28px';
        chuLabel.style.fontWeight = 'bold';
        chuLabel.style.color = '#fff';
        chuLabel.style.textShadow = '0 0 10px #ff0000, 0 0 20px #ff0000';
        chuLabel.style.zIndex = '10001';
        chuLabel.style.pointerEvents = 'none';
        dragCard.appendChild(chuLabel);
        
        document.body.appendChild(dragCard);
        
        cardEl.style.opacity = '0.3';
        
        return { dragCard, offsetX, offsetY, cardIndex };
      }
      
      function moveDrag(dragCard, clientX, clientY, offsetX, offsetY) {
        dragCard.style.left = (clientX - offsetX) + 'px';
        dragCard.style.top = (clientY - offsetY) + 'px';
      }
      
      function endDrag(dragCard, clientX, clientY) {
        const handRect = handEl.getBoundingClientRect();
        const isOutside = clientY < handRect.top || 
                         clientY > handRect.bottom ||
                         clientX < handRect.left || 
                         clientX > handRect.right;
        
        dragCard.remove();
        cardEl.style.opacity = '';
        
        if (isOutside) {
          gameState.selectedCardIndex = cardIndex;
          discardAction();
        } else {
          renderMyHand();
        }
      }
      
      let dragState = null;
      let cardIndex = null;
      
      cardEl.onmousedown = function(e) {
        e.preventDefault();
        dragState = startDrag(e.clientX, e.clientY);
        if (!dragState) return;
        cardIndex = dragState.cardIndex;
        
        function onMouseMove(ev) {
          moveDrag(dragState.dragCard, ev.clientX, ev.clientY, dragState.offsetX, dragState.offsetY);
        }
        
        function onMouseUp(ev) {
          document.removeEventListener('mousemove', onMouseMove);
          document.removeEventListener('mouseup', onMouseUp);
          endDrag(dragState.dragCard, ev.clientX, ev.clientY);
          dragState = null;
        }
        
        document.addEventListener('mousemove', onMouseMove);
        document.addEventListener('mouseup', onMouseUp);
      };
      
      cardEl.ontouchstart = function(e) {
        e.preventDefault();
        const touch = e.touches[0];
        dragState = startDrag(touch.clientX, touch.clientY);
        if (!dragState) return;
        cardIndex = dragState.cardIndex;
      };
      
      cardEl.ontouchmove = function(e) {
        e.preventDefault();
        if (dragState) {
          const touch = e.touches[0];
          moveDrag(dragState.dragCard, touch.clientX, touch.clientY, dragState.offsetX, dragState.offsetY);
        }
      };
      
      cardEl.ontouchend = function(e) {
        e.preventDefault();
        if (dragState) {
          const touch = e.changedTouches[0];
          endDrag(dragState.dragCard, touch.clientX, touch.clientY);
          dragState = null;
        }
      };
      
      cardEl.ontouchcancel = function(e) {
        if (dragState) {
          dragState.dragCard.remove();
          cardEl.style.opacity = '';
          dragState = null;
        }
      };
      
      stackEl.appendChild(cardEl);
      
      if (cards.length > 1) {
        const countEl = document.createElement('div');
        countEl.className = 'card-count';
        countEl.textContent = cards.length;
        countEl.style.pointerEvents = 'none';
        stackEl.appendChild(countEl);
      }
      
      groupEl.appendChild(stackEl);
    }
    
    handEl.appendChild(groupEl);
  }
}

function createCardImageElement(card) {
  const div = document.createElement('div');
  const pinyin = CARD_PINYIN[card.character];
  div.style.backgroundImage = `url('images/${pinyin}.png')`;
  div.style.backgroundSize = 'contain';
  div.style.backgroundPosition = 'center';
  div.style.backgroundRepeat = 'no-repeat';
  div.style.width = '40px';
  div.style.height = '168px';
  div.style.cursor = 'pointer';
  div.style.backgroundColor = 'transparent';
  div.style.border = 'none';
  div.style.borderRadius = '4px';
  div.style.boxShadow = '0 2px 4px rgba(0,0,0,0.2)';
  div.dataset.character = card.character;
  return div;
}

function startTurn() {
  console.log('=== 开始回合 ===');
  zimoAnnounced = false;
  const currentPlayer = gameState.players[gameState.currentPlayerIndex];
  const isDealerFirstTurn = gameState.currentPlayerIndex === gameState.dealerIndex && 
                            currentPlayer.hand.length === 20;
  
  console.log('当前玩家:', currentPlayer.name, '类型:', currentPlayer.type);
  console.log('是否庄家首回合:', isDealerFirstTurn);
  console.log('当前玩家手牌数:', currentPlayer.hand.length);
  console.log('牌堆数量:', gameState.deck.length);
  console.log('当前玩家索引:', gameState.currentPlayerIndex);
  console.log('庄家索引:', gameState.dealerIndex);
  console.log('是否是人类玩家:', currentPlayer.type === 'human');
  console.log('是否不是庄家首回合:', !isDealerFirstTurn);
  console.log('牌堆是否不为空:', gameState.deck.length > 0);
  
  gameState.canChi = false;
  gameState.canPeng = false;
  gameState.canZhao = false;
  gameState.canHu = false;
  
  updateCurrentPlayerUI();
  startCountdown();
  
  if (currentPlayer.type === 'human') {
    console.log('>>> 我的回合 <<<');
    gameState.isMyTurn = true;
    
    console.log('摸牌条件检查:');
    console.log('- isDealerFirstTurn:', isDealerFirstTurn);
    console.log('- gameState.deck.length:', gameState.deck.length);
    console.log('- skipDraw:', gameState.skipDraw);
    console.log('- 条件结果:', !gameState.skipDraw && !isDealerFirstTurn && gameState.deck.length > 0);
    
    if (!gameState.skipDraw && !isDealerFirstTurn && gameState.deck.length > 0 && !gameState.isDrawing) {
      console.log('摸牌...');
      console.log('摸牌前手牌数:', currentPlayer.hand.length);
      gameState.isDrawing = true;
      const drawnCard = gameState.deck.pop();
      gameState.lastDrawnCard = drawnCard;
      updateDeckStack();
      
      const tingBadge = document.getElementById('tingBadge');
      const zimoBadge = document.getElementById('zimoBadge');
      tingBadge.classList.add('hidden');
      zimoBadge.classList.add('hidden');
      
      animateDrawCard(1, drawnCard, () => {
        currentPlayer.hand.push(drawnCard);
        currentPlayer.hand = sortHand(currentPlayer.hand);
        renderMyHand();
        gameState.isDrawing = false;
        gameState.isMyTurn = true;
        console.log('摸牌完成，手牌数:', currentPlayer.hand.length);
        
        const tingResult = checkTing(currentPlayer);
        currentPlayer.isTing = tingResult.isTing;
        
        const huResult = checkHu(currentPlayer);
        const canZimo = currentPlayer.isTing && huResult.canHu;
        
        console.log('摸牌后检查 - isTing:', currentPlayer.isTing, 'canHu:', huResult.canHu, 'canZimo:', canZimo);
        
        updateHuBadgeDisplay();
        
        if (canZimo) {
          console.log('显示自摸徽章');
          zimoBadge.classList.remove('hidden');
          zimoAnnounced = false;
          playZimoAnnouncement();
        }
        
        startCountdown();
        updateActionButtons();
      });
    } else {
      const reason = gameState.skipDraw ? '碰牌/吃牌后' : (isDealerFirstTurn ? '庄家首回合' : (gameState.isDrawing ? '正在摸牌' : '牌堆为空'));
      console.log('不摸牌，原因:', reason);
      gameState.skipDraw = false;
      gameState.lastDrawnCard = null;
      const tingResult = checkTing(currentPlayer);
      currentPlayer.isTing = tingResult.isTing;
      updateTingBadge();
      updateHuBadgeDisplay();
      updateActionButtons();
    }
  } else {
    console.log('>>> AI回合 <<<');
    gameState.isMyTurn = false;
    setTimeout(() => processAITurn(), 800 + Math.random() * 500);
  }
}

function updateTingBadge() {
  const tingBadge = document.getElementById('tingBadge');
  const zimoBadge = document.getElementById('zimoBadge');
  const me = gameState.players[1];
  
  console.log('updateTingBadge - isTing:', me.isTing);
  
  const huResult = checkHu(me);
  const canZimo = me.isTing && huResult.canHu && gameState.isMyTurn;
  
  console.log('updateTingBadge - canZimo:', canZimo, 'huResult.canHu:', huResult.canHu);
  
  zimoBadge.classList.add('hidden');
  tingBadge.classList.add('hidden');
  
  if (canZimo) {
    zimoBadge.classList.remove('hidden');
    zimoAnnounced = false;
    playZimoAnnouncement();
  }
}

let zimoAnnounced = false;

function playZimoAnnouncement() {
  if (zimoAnnounced) return;
  zimoAnnounced = true;
  speakText('自摸');
}

function handleZimoClick() {
  const me = gameState.players[1];
  const huResult = checkHu(me);
  if (me.isTing && huResult.canHu && gameState.isMyTurn) {
    handleHu(1, 'zimo');
  }
}

function playDiscardSound(card, playerIndex = 1) {
  console.log('playDiscardSound called, card:', card ? card.character : 'null', 'playerIndex:', playerIndex);
  
  // 确保音频系统已初始化
  initAudioContext();
  resumeAudioContext();
  
  try {
    // 播放语音
    if (card && card.character) {
      playVoice(card.character, playerIndex);
    }
  } catch (e) {
    console.log('playDiscardSound error:', e);
  }
}

async function playVoice(text, playerIndex = 1) {
  console.log('playVoice called - text:', text, 'playerIndex:', playerIndex);
  
  // 使用本地音频文件播放
  await speakText(text, playerIndex);
}

function startCountdown() {
  stopCountdown();
  gameState.countdown = 30;
  updateCountdownUI();
  
  gameState.countdownTimer = setInterval(() => {
    gameState.countdown--;
    updateCountdownUI();
    
    if (gameState.countdown === 5 && gameState.isMyTurn) {
      speakText('快点吧，我等的花儿都谢了');
    }
    
    if (gameState.countdown <= 0) {
      handleTimeout();
    }
  }, 1000);
}

function stopCountdown() {
  if (gameState.countdownTimer) {
    clearInterval(gameState.countdownTimer);
    gameState.countdownTimer = null;
  }
  gameState.countdown = 0;
  updateCountdownUI();
}

function updateCountdownUI() {
  document.querySelectorAll('.player-timer').forEach(el => {
    el.classList.add('hidden');
    el.classList.remove('warning');
    el.textContent = '';
  });
  
  if (gameState.countdown > 0) {
    let timerEl = null;
    
    if (gameState.waitingForResponse) {
      timerEl = document.getElementById('myTimer');
    } else {
      const timerIds = ['player1Timer', 'myTimer', 'player2Timer'];
      timerEl = document.getElementById(timerIds[gameState.currentPlayerIndex]);
    }
    
    if (timerEl) {
      timerEl.classList.remove('hidden');
      timerEl.textContent = gameState.countdown;
      if (gameState.countdown <= 5) {
        timerEl.classList.add('warning');
      }
    }
  }
}

function handleTimeout() {
  stopCountdown();
  
  if (gameState.waitingForResponse) {
    passAction();
  } else if (gameState.isMyTurn) {
    const me = gameState.players[1];
    
    if (me.hand.length > 0) {
      if (gameState.lastDrawnCard) {
        const lastDrawnIndex = me.hand.findIndex(c => c.id === gameState.lastDrawnCard.id);
        if (lastDrawnIndex !== -1) {
          discardCard(1, lastDrawnIndex);
          return;
        }
      }
      discardCard(1, me.hand.length - 1);
    }
  }
}

function processAITurn() {
  console.log('=== processAITurn ===');
  const player = gameState.players[gameState.currentPlayerIndex];
  const isDealerFirstTurn = gameState.currentPlayerIndex === gameState.dealerIndex && 
                            player.hand.length === 20;
  
  console.log('玩家:', player.name, '手牌数:', player.hand.length, '庄家首回合:', isDealerFirstTurn);
  console.log('skipDraw:', gameState.skipDraw);
  
  if (!gameState.skipDraw && !isDealerFirstTurn && gameState.deck.length > 0) {
    const drawnCard = gameState.deck.pop();
    updateDeckStack();
    
    animateDrawCard(gameState.currentPlayerIndex, drawnCard, () => {
      player.hand.push(drawnCard);
      player.hand = sortHand(player.hand);
      updateUI();
      continueAITurn(player);
    });
  } else {
    gameState.skipDraw = false;
    continueAITurn(player);
  }
}

function continueAITurn(player) {
  const tingResult = checkTing(player);
  player.isTing = tingResult.isTing;
  console.log('听牌:', player.isTing);
  
  const huResult = checkHu(player);
  console.log('胡牌:', huResult.canHu);
  
  if (player.isTing && huResult.canHu) {
    handleHu(gameState.currentPlayerIndex, 'zimo');
    return;
  }
  
  console.log('选择要出的牌...');
  const cardToDiscard = selectAIDiscard(player);
  console.log('选择的牌索引:', cardToDiscard);
  
  if (cardToDiscard < 0 || cardToDiscard >= player.hand.length) {
    console.error('continueAITurn: 无效的牌索引', cardToDiscard);
    moveToNextPlayer();
    return;
  }
  
  discardCard(gameState.currentPlayerIndex, cardToDiscard);
}

function selectAIDiscard(player) {
  if (!player.hand || player.hand.length === 0) {
    console.error('selectAIDiscard: 手牌为空');
    return -1;
  }
  
  const scoredCards = player.hand.map((card, index) => ({
    card,
    index,
    score: evaluateCard(card, player.hand)
  }));
  
  scoredCards.sort((a, b) => a.score - b.score);
  return scoredCards[0].index;
}

function evaluateCard(card, hand) {
  let score = 0;
  
  if (card.isSpecial) score += 100;
  
  const sameCount = hand.filter(c => c.character === card.character).length;
  if (sameCount >= 2) score += 50 * sameCount;
  
  const sentenceCards = hand.filter(c => c.sentence === card.sentence);
  if (sentenceCards.length >= 2) score += 30;
  
  return score;
}

function discardCard(playerIndex, cardIndex) {
  console.log('=== 出牌 ===');
  console.log('玩家索引:', playerIndex, '牌索引:', cardIndex);
  
  const player = gameState.players[playerIndex];
  const card = player.hand[cardIndex];
  
  console.log('出牌:', card.character);
  
  player.hand.splice(cardIndex, 1);
  player.discards.push(card);
  
  gameState.lastDiscardedCard = card;
  gameState.lastDiscardPlayerIndex = playerIndex;
  
  playDiscardSound(card, playerIndex);
  
  animateDiscardCard(playerIndex, card);
  
  if (playerIndex === 1) {
    stopCountdown();
    gameState.isMyTurn = false;
    gameState.selectedCardIndex = -1;
  }
  
  const tingResult = checkTing(player);
  player.isTing = tingResult.isTing;
  
  if (playerIndex === 1) {
    const tingBadge = document.getElementById('tingBadge');
    const zimoBadge = document.getElementById('zimoBadge');
    zimoBadge.classList.add('hidden');
    if (player.isTing) {
      tingBadge.classList.remove('hidden');
    } else {
      tingBadge.classList.add('hidden');
    }
    updateHuBadgeDisplay();
  }
  
  updateUI();
  
  console.log('准备调用checkResponses');
  setTimeout(() => {
    console.log('=== setTimeout回调 ===');
    console.log('调用checkResponses');
    checkResponses();
  }, 400);
}

function animateDiscardCard(playerIndex, card) {
  let startX, startY;
  const centerX = window.innerWidth / 2;
  const centerY = window.innerHeight / 2;
  
  if (playerIndex === 0) {
    startX = 60;
    startY = centerY - 73;
  } else if (playerIndex === 1) {
    startX = centerX - 17;
    startY = window.innerHeight - 180;
  } else {
    startX = window.innerWidth - 95;
    startY = centerY - 73;
  }
  
  const targetX = centerX - 17;
  const targetY = centerY - 73;
  
  const flyingCard = document.createElement('div');
  flyingCard.style.position = 'fixed';
  flyingCard.style.left = startX + 'px';
  flyingCard.style.top = startY + 'px';
  flyingCard.style.width = '35px';
  flyingCard.style.height = '147px';
  flyingCard.style.borderRadius = '4px';
  flyingCard.style.boxShadow = '0 4px 15px rgba(0,0,0,0.5)';
  flyingCard.style.zIndex = '9999';
  flyingCard.style.pointerEvents = 'none';
  
  if (playerIndex === 1) {
    const pinyin = CARD_PINYIN[card.character];
    flyingCard.style.backgroundImage = `url('images/${pinyin}.png')`;
    flyingCard.style.backgroundSize = 'contain';
    flyingCard.style.backgroundPosition = 'center';
    flyingCard.style.backgroundRepeat = 'no-repeat';
    flyingCard.style.backgroundColor = 'transparent';
    flyingCard.style.border = 'none';
  } else {
    flyingCard.style.backgroundImage = `url('images/mcard.png')`;
    flyingCard.style.backgroundSize = 'contain';
    flyingCard.style.backgroundPosition = 'center';
    flyingCard.style.backgroundRepeat = 'no-repeat';
  }
  
  document.body.appendChild(flyingCard);
  
  setTimeout(() => {
    flyingCard.style.transition = 'all 0.3s ease-out';
    flyingCard.style.left = targetX + 'px';
    flyingCard.style.top = targetY + 'px';
  }, 20);
  
  setTimeout(() => {
    flyingCard.remove();
    showDiscardedCard(playerIndex, card);
  }, 350);
}

function animateMeldCards(playerIndex, cards, meldType, callback) {
  const centerX = window.innerWidth / 2;
  const centerY = window.innerHeight / 2;
  
  const discardX = centerX - 17;
  const discardY = centerY - 73;
  
  const actionButtons = document.getElementById('actionButtons');
  const actionRect = actionButtons ? actionButtons.getBoundingClientRect() : { left: centerX - 100, top: window.innerHeight - 100, width: 200, height: 44 };
  
  const meldCenterX = actionRect.left + actionRect.width / 2;
  const meldCenterY = actionRect.top - 30;
  
  let targetX, targetY;
  if (playerIndex === 0) {
    targetX = 10;
    targetY = centerY + 50;
  } else if (playerIndex === 1) {
    targetX = centerX - 100;
    targetY = window.innerHeight - 60;
  } else {
    targetX = window.innerWidth - 110;
    targetY = centerY + 50;
  }
  
  const flyingCards = [];
  const cardWidth = 30;
  const cardHeight = 42;
  const gap = 2;
  
  const meldContainer = document.createElement('div');
  meldContainer.style.position = 'fixed';
  meldContainer.style.display = 'flex';
  meldContainer.style.gap = gap + 'px';
  meldContainer.style.zIndex = '10000';
  meldContainer.style.pointerEvents = 'none';
  
  cards.forEach((card, index) => {
    const flyingCard = document.createElement('div');
    flyingCard.style.width = cardWidth + 'px';
    flyingCard.style.height = cardHeight + 'px';
    flyingCard.style.borderRadius = '4px';
    flyingCard.style.boxShadow = '0 2px 8px rgba(0,0,0,0.4)';
    flyingCard.style.display = 'flex';
    flyingCard.style.alignItems = 'center';
    flyingCard.style.justifyContent = 'center';
    flyingCard.style.fontSize = '16px';
    flyingCard.style.fontWeight = 'bold';
    
    const pinyin = CARD_PINYIN[card.character];
    flyingCard.style.backgroundImage = `url('images/${pinyin}.png')`;
    flyingCard.style.backgroundSize = 'contain';
    flyingCard.style.backgroundPosition = 'center';
    flyingCard.style.backgroundRepeat = 'no-repeat';
    flyingCard.style.backgroundColor = 'transparent';
    flyingCard.style.border = '2px solid';
    
    if (card.character === '上' || card.character === '福') {
      flyingCard.style.borderColor = '#FFD700';
    } else {
      flyingCard.style.borderColor = '#333';
    }
    
    let startX, startY;
    if (index === 0) {
      startX = discardX;
      startY = discardY;
    } else {
      if (playerIndex === 0) {
        startX = 60;
        startY = centerY - 73;
      } else if (playerIndex === 1) {
        startX = centerX - 17;
        startY = window.innerHeight - 180;
      } else {
        startX = window.innerWidth - 95;
        startY = centerY - 73;
      }
    }
    
    const singleFlyingCard = document.createElement('div');
    singleFlyingCard.style.position = 'fixed';
    singleFlyingCard.style.width = cardWidth + 'px';
    singleFlyingCard.style.height = cardHeight + 'px';
    singleFlyingCard.style.borderRadius = '4px';
    singleFlyingCard.style.boxShadow = '0 2px 8px rgba(0,0,0,0.4)';
    singleFlyingCard.style.zIndex = '10000';
    singleFlyingCard.style.pointerEvents = 'none';
    singleFlyingCard.style.backgroundImage = `url('images/${pinyin}.png')`;
    singleFlyingCard.style.backgroundSize = 'contain';
    singleFlyingCard.style.backgroundPosition = 'center';
    singleFlyingCard.style.backgroundRepeat = 'no-repeat';
    singleFlyingCard.style.backgroundColor = 'transparent';
    singleFlyingCard.style.border = '2px solid';
    
    if (card.character === '上' || card.character === '福') {
      singleFlyingCard.style.borderColor = '#FFD700';
    } else {
      singleFlyingCard.style.borderColor = '#333';
    }
    
    singleFlyingCard.style.left = startX + 'px';
    singleFlyingCard.style.top = startY + 'px';
    
    document.body.appendChild(singleFlyingCard);
    flyingCards.push({ single: singleFlyingCard, meld: flyingCard, card });
    meldContainer.appendChild(flyingCard);
  });
  
  const playedCards = document.getElementById('playedCards');
  if (playedCards) playedCards.innerHTML = '';
  
  setTimeout(() => {
    flyingCards.forEach((item, index) => {
      item.single.style.transition = 'all 0.4s ease-out';
      item.single.style.left = (meldCenterX - cardWidth / 2 + (index - Math.floor(cards.length / 2)) * (cardWidth + gap)) + 'px';
      item.single.style.top = (meldCenterY - cardHeight / 2) + 'px';
    });
  }, 20);
  
  setTimeout(() => {
    flyingCards.forEach(item => item.single.remove());
    
    meldContainer.style.left = (meldCenterX - (cards.length * cardWidth + (cards.length - 1) * gap) / 2) + 'px';
    meldContainer.style.top = (meldCenterY - cardHeight / 2) + 'px';
    meldContainer.style.transition = 'all 0.3s ease-out';
    
    document.body.appendChild(meldContainer);
  }, 500);
  
  setTimeout(() => {
    meldContainer.style.transition = 'all 0.5s ease-in-out';
    meldContainer.style.left = targetX + 'px';
    meldContainer.style.top = targetY + 'px';
  }, 900);
  
  setTimeout(() => {
    meldContainer.remove();
    if (callback) callback();
  }, 1500);
}

function animateDrawCard(playerIndex, card, callback) {
  const deckStack = document.getElementById('deckStack');
  const deckRect = deckStack ? deckStack.getBoundingClientRect() : { left: window.innerWidth / 2, top: window.innerHeight / 2 };
  
  const startX = deckRect.left + deckRect.width / 2 - 17;
  const startY = deckRect.top;
  
  let targetX, targetY;
  const centerX = window.innerWidth / 2;
  const centerY = window.innerHeight / 2;
  
  if (playerIndex === 0) {
    targetX = 60;
    targetY = centerY - 73;
  } else if (playerIndex === 1) {
    targetX = centerX - 17;
    targetY = window.innerHeight - 180;
  } else {
    targetX = window.innerWidth - 95;
    targetY = centerY - 73;
  }
  
  const flyingCard = document.createElement('div');
  flyingCard.style.position = 'fixed';
  flyingCard.style.left = startX + 'px';
  flyingCard.style.top = startY + 'px';
  flyingCard.style.width = '35px';
  flyingCard.style.height = '147px';
  flyingCard.style.borderRadius = '4px';
  flyingCard.style.boxShadow = '0 4px 15px rgba(0,0,0,0.5)';
  flyingCard.style.zIndex = '9999';
  flyingCard.style.pointerEvents = 'none';
  
  const pinyin = CARD_PINYIN[card.character];
  
  const moLabel = document.createElement('div');
  moLabel.textContent = '摸';
  moLabel.style.position = 'absolute';
  moLabel.style.top = '50%';
  moLabel.style.left = '50%';
  moLabel.style.transform = 'translate(-50%, -50%)';
  moLabel.style.fontSize = '20px';
  moLabel.style.fontWeight = 'bold';
  moLabel.style.color = '#ffd700';
  moLabel.style.textShadow = '0 0 10px rgba(255,215,0,0.8), 0 0 20px rgba(255,0,0,0.6)';
  moLabel.style.background = 'rgba(0,0,0,0.7)';
  moLabel.style.padding = '5px 10px';
  moLabel.style.borderRadius = '8px';
  moLabel.style.border = '2px solid #ffd700';
  moLabel.style.zIndex = '10000';
  
  if (playerIndex === 1) {
    flyingCard.style.backgroundImage = `url('images/${pinyin}.png')`;
    flyingCard.appendChild(moLabel);
  } else {
    flyingCard.style.backgroundImage = `url('images/mcard.png')`;
  }
  flyingCard.style.backgroundSize = 'contain';
  flyingCard.style.backgroundPosition = 'center';
  flyingCard.style.backgroundRepeat = 'no-repeat';
  flyingCard.style.backgroundColor = 'transparent';
  flyingCard.style.border = 'none';
  
  document.body.appendChild(flyingCard);
  
  setTimeout(() => {
    flyingCard.style.transition = 'all 1s ease-out';
    flyingCard.style.left = targetX + 'px';
    flyingCard.style.top = targetY + 'px';
  }, 1000);
  
  setTimeout(() => {
    flyingCard.remove();
    if (callback) callback();
  }, 2050);
}

function showDiscardedCard(playerIndex, card) {
  const playedCardsEl = document.getElementById('playedCards');
  
  if (playedCardsEl) {
    playedCardsEl.innerHTML = '';
    
    const cardEl = document.createElement('div');
    cardEl.className = 'card';
    const pinyin = CARD_PINYIN[card.character];
    cardEl.style.backgroundImage = `url('images/v/${pinyin}.png')`;
    cardEl.style.backgroundSize = 'contain';
    cardEl.style.backgroundPosition = 'center';
    cardEl.style.backgroundRepeat = 'no-repeat';
    cardEl.style.width = '120px';
    cardEl.style.height = '30px';
    cardEl.style.border = 'none';
    cardEl.style.boxShadow = 'none';
    playedCardsEl.appendChild(cardEl);
  }
  
  let discardEl;
  if (playerIndex === 0) {
    discardEl = document.getElementById('player1Discard');
  } else if (playerIndex === 1) {
    discardEl = document.getElementById('myDiscard');
  } else {
    discardEl = document.getElementById('player2Discard');
  }
  
  if (discardEl) {
    // 检查是否已经添加过相同的牌（避免重复添加）
    const lastCard = discardEl.lastElementChild;
    if (lastCard && lastCard.dataset.cardId === card.id) {
      console.log('跳过重复添加:', card.character, card.id);
      return;
    }
    
    const cardEl = createSmallCardElement(card);
    discardEl.appendChild(cardEl);
    
    if (discardEl.children.length > 8) {
      discardEl.removeChild(discardEl.firstChild);
    }
  }
}

function createSmallCardElement(card) {
  const div = document.createElement('div');
  const pinyin = CARD_PINYIN[card.character];
  div.style.backgroundImage = `url('images/s/${pinyin}.png')`;
  div.style.backgroundSize = 'contain';
  div.style.backgroundPosition = 'center';
  div.style.backgroundRepeat = 'no-repeat';
  div.style.width = '20px';
  div.style.height = '35px';
  div.style.cursor = 'default';
  div.dataset.character = card.character;
  div.dataset.cardId = card.id;
  return div;
}

function checkResponses() {
  const card = gameState.lastDiscardedCard;
  if (!card) {
    console.log('没有出牌');
    return;
  }
  
  console.log('=== 检查响应 ===');
  console.log('出牌:', card.character, '出牌者索引:', gameState.lastDiscardPlayerIndex);
  
  const responses = [];
  
  for (let i = 0; i < gameState.players.length; i++) {
    if (i === gameState.lastDiscardPlayerIndex) continue;
    
    const player = gameState.players[i];
    const huResult = checkHu(player, card, true);
    const canHu = player.isTing && huResult.canHu;
    const canZhao = canPlayerZhao(player, card);
    const canPeng = canPlayerPeng(player, card);
    const isNextPlayer = i === (gameState.lastDiscardPlayerIndex + 1) % 3;
    const canChiResult = canPlayerChi(player, card);
    const canChi = isNextPlayer && canChiResult;
    
    console.log('玩家', i, '(', player.name, ') - 胡:', canHu, '招:', canZhao, '碰:', canPeng, '吃:', canChi, '是下家:', isNextPlayer);
    
    responses.push({ playerIndex: i, canHu, canZhao, canPeng, canChi });
  }
  
  // 按优先级检查：胡 > 招 > 碰 > 吃
  // 1. 先检查是否有玩家可以"胡"
  const huResponses = responses.filter(r => r.canHu);
  if (huResponses.length > 0) {
    const humanHu = huResponses.find(r => r.playerIndex === 1);
    if (humanHu) {
      // 人类玩家可以胡，显示操作按钮
      console.log('>>> 人类玩家可以胡，显示操作按钮 <<<');
      showResponseButtons(responses, 1);
      return;
    } else {
      // AI玩家可以胡，直接处理
      handleHu(huResponses[0].playerIndex, 'dianpao');
      return;
    }
  }
  
  // 2. 检查是否有玩家可以"招"
  const zhaoResponses = responses.filter(r => r.canZhao);
  if (zhaoResponses.length > 0) {
    const humanZhao = zhaoResponses.find(r => r.playerIndex === 1);
    if (humanZhao) {
      // 人类玩家可以招，显示操作按钮
      console.log('>>> 人类玩家可以招，显示操作按钮 <<<');
      showResponseButtons(responses, 1);
      return;
    } else {
      // AI玩家可以招，直接处理
      performZhao(zhaoResponses[0].playerIndex);
      return;
    }
  }
  
  // 3. 检查是否有玩家可以"碰"
  const pengResponses = responses.filter(r => r.canPeng);
  if (pengResponses.length > 0) {
    const humanPeng = pengResponses.find(r => r.playerIndex === 1);
    if (humanPeng) {
      // 人类玩家可以碰，显示操作按钮
      console.log('>>> 人类玩家可以碰，显示操作按钮 <<<');
      showResponseButtons(responses, 1);
      return;
    } else {
      // AI玩家可以碰，随机决定是否碰
      if (Math.random() > 0.3) {
        performPeng(pengResponses[0].playerIndex);
        return;
      } else {
        // AI玩家决定不碰，继续检查吃牌
      console.log('AI玩家决定不碰，继续检查吃牌');
      }
    }
  }
  
  // 4. 检查是否有玩家可以"吃"
  const chiResponses = responses.filter(r => r.canChi);
  if (chiResponses.length > 0) {
    const humanChi = chiResponses.find(r => r.playerIndex === 1);
    if (humanChi) {
      // 人类玩家可以吃，显示操作按钮
      console.log('>>> 人类玩家可以吃，显示操作按钮 <<<');
      showResponseButtons(responses, 1);
      return;
    } else {
      // AI玩家可以吃，直接处理
      performChi(chiResponses[0].playerIndex);
      return;
    }
  }
  
  console.log('无人响应，进入下一玩家');
  moveToNextPlayer();
}

function showResponseButtons(responses, humanPlayerIndex) {
  const humanResponse = responses.find(r => r.playerIndex === humanPlayerIndex);
  console.log('我的响应:', humanResponse);
  console.log('是否有操作:', humanResponse && (humanResponse.canHu || humanResponse.canZhao || humanResponse.canPeng || humanResponse.canChi));
  
  if (humanResponse && (humanResponse.canHu || humanResponse.canZhao || humanResponse.canPeng || humanResponse.canChi)) {
    console.log('>>> 显示操作按钮 <<<');
    gameState.waitingForResponse = true;
    gameState.canHu = humanResponse.canHu;
    gameState.canZhao = humanResponse.canZhao;
    gameState.canPeng = humanResponse.canPeng;
    gameState.canChi = humanResponse.canChi;
    startCountdown();
    updateActionButtons();
  }
}

function canPlayerChi(player, card) {
  const sentenceCards = player.hand.filter(c => c.sentence === card.sentence);
  console.log('吃牌检查 - 牌:', card.character, '句子:', card.sentence, '手牌中同句牌数:', sentenceCards.length, '位置:', card.position);
  
  if (sentenceCards.length < 2) return false;
  
  const positions = new Set(sentenceCards.map(c => c.position));
  console.log('手牌中位置:', ...positions, '出牌位置:', card.position);
  
  if (card.position === 0) return positions.has(1) && positions.has(2);
  if (card.position === 1) return positions.has(0) && positions.has(2);
  if (card.position === 2) return positions.has(0) && positions.has(1);
  
  return false;
}

function canPlayerPeng(player, card) {
  const count = player.hand.filter(c => c.character === card.character).length;
  console.log('碰牌检查 - 玩家:', player.name, '牌:', card.character, '手牌中同字数:', count);
  return count >= 2;
}

function canPlayerZhao(player, card) {
  const count = player.hand.filter(c => c.character === card.character).length;
  console.log('招牌检查 - 玩家:', player.name, '牌:', card.character, '手牌中同字数:', count);
  return count === 3;
}

function checkHu(player, extraCard = null, isDianPao = false) {
  const hand = extraCard ? [...player.hand, extraCard] : [...player.hand];
  const huCount = calculateHuCount(player.hand, player.melds, extraCard, isDianPao);
  
  const huType = detectHuType(hand, player.melds, huCount);
  
  const timestamp = new Date().toLocaleString();
  console.log('=== 胡牌判断 ===');
  console.log('时间:', timestamp);
  console.log('玩家:', player.name);
  console.log('手牌:', hand.map(c => c.character).join(''));
  console.log('组合牌:', player.melds.map(m => m.cards.map(c => c.character).join('')).join(' | '));
  console.log('总胡数:', huCount);
  console.log('胡牌类型:', huType.name, '(' + huType.type + ')');
  
  // 特殊胡牌类型不需要满足胡数条件
  const specialHuTypes = ['kuHu', 'qingKuHu', 'kuTaiHu', 'kuChongTaiHu', 'kuChongTaiKa', 'qingKuTaiKa', 'qingKuTaiHu', 'qingKuChongTaiHu', 'qingKuChongTaiKa', 'hongYuan3Jing', 'hongYuan4Jing', 'hongYuan5Jing', 'hongYuan6Jing', 'heiYuan', 'shiDui'];
  const isSpecialHu = specialHuTypes.includes(huType.type);
  
  console.log('是否特殊胡牌:', isSpecialHu);
  console.log('能否胡牌:', (isSpecialHu || huCount >= 11) && huType.type !== 'none');
  console.log('================');
  
  return {
    canHu: (isSpecialHu || huCount >= 11) && huType.type !== 'none',
    huCount,
    huType
  };
}

function isZhaoUsedInSentence(hand, melds) {
  const zhaoMelds = melds.filter(m => m.type === 'quartet');
  if (zhaoMelds.length === 0) return false;
  
  const allCards = [...hand, ...melds.flatMap(m => m.cards)];
  
  for (const zhaoMeld of zhaoMelds) {
    const zhaoChar = zhaoMeld.cards[0].character;
    const zhaoSentence = zhaoMeld.cards[0].sentence;
    
    const sentenceCards = allCards.filter(c => c.sentence === zhaoSentence);
    const positions = new Set(sentenceCards.map(c => c.position));
    
    if (positions.size === 3) {
      return true;
    }
  }
  
  return false;
}

function checkQingKuChongTai(hand, melds) {
  const zhaoCount = melds.filter(m => m.type === 'quartet').length;
  const hasShangFu = melds.some(m => m.cards.some(c => c.character === '上' || c.character === '福'));
  
  if (hasShangFu) return null;
  
  const counts = {};
  for (const card of hand) {
    counts[card.character] = (counts[card.character] || 0) + 1;
  }
  
  const handZhaoCount = Object.values(counts).filter(c => c >= 4).length;
  const handKanCount = Object.values(counts).filter(c => c === 3).length;
  const handDuiCount = Object.values(counts).filter(c => c === 2).length;
  
  const totalZhaoCount = zhaoCount + handZhaoCount;
  
  if (totalZhaoCount === 6 && handDuiCount === 1) {
    return 'qingKuChongTaiHu';
  }
  
  if (totalZhaoCount === 5 && handKanCount === 1 && handDuiCount === 1) {
    return 'qingKuChongTaiKa';
  }
  
  let halfKaoCount = 0;
  for (let sentence = 1; sentence <= 8; sentence++) {
    const sentenceCards = hand.filter(c => c.sentence === sentence);
    const positions = new Set(sentenceCards.map(c => c.position));
    if (positions.size === 2 && !sentenceCards.some(c => c.character === '上' || c.character === '福')) {
      halfKaoCount++;
    }
  }
  
  if (totalZhaoCount === 6 && halfKaoCount === 1) {
    return 'qingKuChongTaiHu';
  }
  
  if (totalZhaoCount === 5 && handKanCount === 1 && halfKaoCount === 1) {
    return 'qingKuChongTaiKa';
  }
  
  return null;
}

function detectHuType(hand, melds, huCount) {
  const actualHuCount = huCount;
  const hasChi = melds.some(m => m.type === 'sequence');
  const hasPeng = melds.some(m => m.type === 'triplet');
  const hasZhao = melds.some(m => m.type === 'quartet');
  
  const effectiveHasZhao = hasZhao && !isZhaoUsedInSentence(hand, melds);
  
  const counts = {};
  for (const card of hand) {
    counts[card.character] = (counts[card.character] || 0) + 1;
  }
  
  const allCards = [...hand, ...melds.flatMap(m => m.cards)];
  const shangCount = allCards.filter(c => c.character === '上').length;
  const fuCount = allCards.filter(c => c.character === '福').length;
  const shangFuCount = shangCount + fuCount;
  const hasShangFu = shangFuCount > 0;
  
  const hasShangDaRen = allCards.some(c => c.sentence === 1);
  const hasFuLuShou = allCards.some(c => c.sentence === 8);
  
  const isKuHu = checkKuHu(hand, melds, effectiveHasZhao);
  const isQingKuHu = checkQingKuHu(hand, melds, effectiveHasZhao);
  const isQingYiSe = checkQingYiSe(allCards);
  const isShiDui = checkShiDui(hand);
  const isHeiYuan = checkHeiYuan(hand, melds, effectiveHasZhao);
  const hongYuanJing = checkHongYuan(hand, melds, effectiveHasZhao);
  const isQingHu = checkQingHu(hand, melds, actualHuCount);
  
  const qingKuChongTaiResult = checkQingKuChongTai(hand, melds);
  
  if (qingKuChongTaiResult === 'qingKuChongTaiKa') {
    return { type: 'qingKuChongTaiKa', name: '清枯重台卡', multiplier: { dianpao: 14, zimo: 15 } };
  }
  
  if (qingKuChongTaiResult === 'qingKuChongTaiHu') {
    return { type: 'qingKuChongTaiHu', name: '清枯重台胡', multiplier: { dianpao: 13, zimo: 14 } };
  }
  
  if (isQingKuHu && actualHuCount >= 23 && actualHuCount <= 32) {
    return { type: 'qingKuTaiHu', name: '清枯台胡', multiplier: { dianpao: 7, zimo: 8 } };
  }
  
  if (isKuHu && actualHuCount === 33) {
    return { type: 'kuChongTaiKa', name: '枯重台卡', multiplier: { dianpao: 12, zimo: 13 } };
  }
  
  if (isKuHu && actualHuCount >= 34) {
    return { type: 'kuChongTaiHu', name: '枯重台胡', multiplier: { dianpao: 11, zimo: 12 } };
  }
  
  if (isKuHu && actualHuCount >= 23 && actualHuCount <= 32) {
    return { type: 'kuTaiHu', name: '枯台胡', multiplier: { dianpao: 6, zimo: 7 } };
  }
  
  if (isQingKuHu && actualHuCount === 22) {
    return { type: 'qingKuTaiKa', name: '清枯台卡', multiplier: { dianpao: 8, zimo: 9 } };
  }
  
  if (isQingKuHu) {
    return { type: 'qingKuHu', name: '清枯胡', multiplier: { dianpao: 6, zimo: 7 } };
  }
  
  if (isKuHu) {
    return { type: 'kuHu', name: '枯胡', multiplier: { dianpao: 5, zimo: 6 } };
  }
  
  if (isShiDui) {
    return { type: 'shiDui', name: '十对', multiplier: { dianpao: 10, zimo: 11 } };
  }
  
  if (hongYuanJing > 0) {
    return { type: `hongYuan${hongYuanJing}Jing`, name: `红元${hongYuanJing}精`, multiplier: { dianpao: hongYuanJing, zimo: hongYuanJing + 1 } };
  }
  
  if (isHeiYuan) {
    return { type: 'heiYuan', name: '黑元', multiplier: { dianpao: 4, zimo: 5 } };
  }
  
  // 检查清胡条件（除了胡数范围）
  const qingHuConditions = checkQingHuConditions(hand, melds);
  
  // 清卡胡：清胡条件（除了胡数范围）都满足 + 胡数正好11胡
  if (qingHuConditions && actualHuCount === 11) {
    return { type: 'qingKaHu', name: '清卡胡', multiplier: { dianpao: 2, zimo: 3 } };
  }
  
  // 清胡：清胡条件全部满足（包括胡数在11-21之间）
  if (isQingHu) {
    return { type: 'qingHu', name: '清胡', multiplier: { dianpao: 1, zimo: 2 } };
  }
  
  const meetsBasicCondition = checkBasicHuCondition(hand, melds);
  
  if (!meetsBasicCondition) {
    return { type: 'none', name: '无', multiplier: { dianpao: 0, zimo: 0 } };
  }
  
  // 添加胡数检查：如果胡数不足11胡，不能胡牌
  if (actualHuCount < 11) {
    return { type: 'none', name: '无', multiplier: { dianpao: 0, zimo: 0 } };
  }
  
  if (actualHuCount === 11) {
    return { type: 'kaHu', name: '卡胡', multiplier: { dianpao: 1, zimo: 2 } };
  }
  if (actualHuCount >= 12 && actualHuCount <= 21) {
    return { type: 'puTongHu', name: '普通胡', multiplier: { dianpao: 0, zimo: 1 } };
  }
  if (actualHuCount === 22) {
    return { type: 'taiKa', name: '台卡', multiplier: { dianpao: 2, zimo: 3 } };
  }
  if (actualHuCount >= 23 && actualHuCount <= 32) {
    return { type: 'taiHu', name: '台胡', multiplier: { dianpao: 1, zimo: 2 } };
  }
  if (actualHuCount === 33) {
    return { type: 'chongTaiKa', name: '重台卡', multiplier: { dianpao: 7, zimo: 8 } };
  }
  if (actualHuCount >= 34) {
    return { type: 'chongTaiHu', name: '重台胡', multiplier: { dianpao: 6, zimo: 7 } };
  }
  
  return { type: 'none', name: '无', multiplier: { dianpao: 0, zimo: 0 } };
}

function checkBasicHuCondition(hand, melds) {
  const counts = {};
  for (const card of hand) {
    counts[card.character] = (counts[card.character] || 0) + 1;
  }
  
  const usedCardIds = new Set();
  let sentenceCount = 0;
  let kanCount = 0;
  let zhaoCount = 0;
  
  let changed = true;
  while (changed) {
    changed = false;
    for (let sentence = 1; sentence <= 8; sentence++) {
      const sentenceCards = hand.filter(c => c.sentence === sentence && !usedCardIds.has(c.id));
      const positions = new Set(sentenceCards.map(c => c.position));
      
      if (positions.size === 3) {
        sentenceCount++;
        const pos0Card = sentenceCards.find(c => c.position === 0);
        const pos1Card = sentenceCards.find(c => c.position === 1);
        const pos2Card = sentenceCards.find(c => c.position === 2);
        
        if (pos0Card) usedCardIds.add(pos0Card.id);
        if (pos1Card) usedCardIds.add(pos1Card.id);
        if (pos2Card) usedCardIds.add(pos2Card.id);
        
        changed = true;
      }
    }
  }
  
  const afterSentence = hand.filter(c => !usedCardIds.has(c.id));
  
  const afterSentenceCounts = {};
  for (const card of afterSentence) {
    afterSentenceCounts[card.character] = (afterSentenceCounts[card.character] || 0) + 1;
  }
  
  for (const [char, count] of Object.entries(afterSentenceCounts)) {
    if (count === 3) {
      kanCount++;
      const kanCards = afterSentence.filter(c => c.character === char);
      kanCards.forEach(c => usedCardIds.add(c.id));
    }
  }
  
  const afterKan = hand.filter(c => !usedCardIds.has(c.id));
  
  const afterKanCounts = {};
  for (const card of afterKan) {
    afterKanCounts[card.character] = (afterKanCounts[card.character] || 0) + 1;
  }
  
  for (const [char, count] of Object.entries(afterKanCounts)) {
    if (count >= 4) {
      zhaoCount++;
      const zhaoCards = afterKan.filter(c => c.character === char);
      zhaoCards.forEach(c => usedCardIds.add(c.id));
    }
  }
  
  const remainingCards = hand.filter(c => !usedCardIds.has(c.id));
  
  if (remainingCards.length !== 2) {
    return false;
  }
  
  const [card1, card2] = remainingCards;
  
  if (card1.character === card2.character) {
    return true;
  }
  
  if (card1.sentence === card2.sentence && card1.position !== card2.position) {
    return true;
  }
  
  return false;
}

function checkKuHu(hand, melds, effectiveHasZhao) {
  const hasChi = melds.some(m => m.type === 'sequence');
  if (hasChi) return false;
  
  const allCards = [...hand, ...melds.flatMap(m => m.cards)];
  const hasShangFu = allCards.some(c => c.character === '上' || c.character === '福');
  if (!hasShangFu) return false;
  
  const counts = {};
  for (const card of hand) {
    counts[card.character] = (counts[card.character] || 0) + 1;
  }
  
  for (const count of Object.values(counts)) {
    if (count === 1) {
      return false;
    }
  }
  
  let kanCount = 0;
  let duiCount = 0;
  
  for (const count of Object.values(counts)) {
    if (count === 3) {
      kanCount++;
    } else if (count === 2) {
      duiCount++;
    }
  }
  
  for (const meld of melds) {
    if (meld.type === 'triplet') {
      kanCount++;
    } else if (meld.type === 'quartet' && effectiveHasZhao) {
      kanCount++;
    }
  }
  
  return kanCount >= 4 && duiCount === 1;
}

function checkQingKuHu(hand, melds, effectiveHasZhao) {
  const hasChi = melds.some(m => m.type === 'sequence');
  if (hasChi) return false;
  
  const allCards = [...hand, ...melds.flatMap(m => m.cards)];
  const hasShangFu = allCards.some(c => c.character === '上' || c.character === '福');
  if (hasShangFu) return false;
  
  const counts = {};
  for (const card of hand) {
    counts[card.character] = (counts[card.character] || 0) + 1;
  }
  
  for (const count of Object.values(counts)) {
    if (count === 1) {
      return false;
    }
  }
  
  let kanCount = 0;
  let duiCount = 0;
  
  for (const count of Object.values(counts)) {
    if (count === 3) {
      kanCount++;
    } else if (count === 2) {
      duiCount++;
    }
  }
  
  for (const meld of melds) {
    if (meld.type === 'triplet') {
      kanCount++;
    } else if (meld.type === 'quartet' && effectiveHasZhao) {
      kanCount++;
    }
  }
  
  return kanCount >= 4 && duiCount === 1;
}

function checkQingYiSe(cards) {
  const colors = new Set();
  for (const card of cards) {
    if (card.position === 0) colors.add('red');
    else if (card.position === 1) colors.add('green');
    else if (card.position === 2) colors.add('black');
  }
  return colors.size === 1;
}

function checkShiDui(hand) {
  const counts = {};
  for (const card of hand) {
    counts[card.character] = (counts[card.character] || 0) + 1;
  }
  
  let duiCount = 0;
  for (const count of Object.values(counts)) {
    if (count === 2) {
      duiCount++;
    } else if (count === 4) {
      duiCount += 2;
    }
  }
  
  return duiCount === 10;
}

function checkHeiYuan(hand, melds, effectiveHasZhao) {
  const hasPeng = melds.some(m => m.type === 'triplet');
  const hasZhao = melds.some(m => m.type === 'quartet');
  
  console.log('=== 黑元检查 ===');
  console.log('hasPeng:', hasPeng, 'hasZhao:', hasZhao, 'effectiveHasZhao:', effectiveHasZhao);
  
  if (hasPeng || (hasZhao && effectiveHasZhao)) {
    console.log('黑元失败: 有碰牌或有效招牌');
    return false;
  }
  
  const sentencePatternResult = checkSentencePattern(hand, melds);
  console.log('句子模式检查结果:', sentencePatternResult);
  
  if (!sentencePatternResult) {
    console.log('黑元失败: 句子模式不满足');
    return false;
  }
  
  const allCards = [...hand, ...melds.flatMap(m => m.cards)];
  
  const hasShangDaRen = allCards.some(c => c.sentence === 1);
  const hasFuLuShou = allCards.some(c => c.sentence === 8);
  
  console.log('hasShangDaRen:', hasShangDaRen, 'hasFuLuShou:', hasFuLuShou);
  
  if (hasShangDaRen || hasFuLuShou) {
    console.log('黑元失败: 有上大人或福禄寿句子');
    return false;
  }
  
  const shangCount = allCards.filter(c => c.character === '上').length;
  const fuCount = allCards.filter(c => c.character === '福').length;
  
  console.log('shangCount:', shangCount, 'fuCount:', fuCount);
  console.log('黑元结果:', shangCount === 0 && fuCount === 0);
  
  return shangCount === 0 && fuCount === 0;
}

function checkSentencePattern(hand, melds) {
  console.log('=== 句子模式检查 ===');
  console.log('手牌:', hand.map(c => c.character).join(''));
  
  const cards = [...hand];
  const usedCardIds = new Set();
  
  let foundGroup = true;
  while (foundGroup) {
    foundGroup = false;
    
    for (let sentence = 1; sentence <= 8; sentence++) {
      const sentenceCards = cards.filter(c => c.sentence === sentence && !usedCardIds.has(c.id));
      
      const pos0Cards = sentenceCards.filter(c => c.position === 0);
      const pos1Cards = sentenceCards.filter(c => c.position === 1);
      const pos2Cards = sentenceCards.filter(c => c.position === 2);
      
      if (pos0Cards.length > 0 && pos1Cards.length > 0 && pos2Cards.length > 0) {
        usedCardIds.add(pos0Cards[0].id);
        usedCardIds.add(pos1Cards[0].id);
        usedCardIds.add(pos2Cards[0].id);
        foundGroup = true;
        console.log(`句子${sentence}: 组成一组，移除 ${pos0Cards[0].character}${pos1Cards[0].character}${pos2Cards[0].character}`);
      }
    }
  }
  
  const remainingCards = cards.filter(c => !usedCardIds.has(c.id));
  console.log('剩余牌:', remainingCards.map(c => c.character).join(''));
  console.log('剩余牌数:', remainingCards.length);
  
  if (remainingCards.length !== 2) {
    console.log('句子模式失败: 剩余牌不是2张');
    return false;
  }
  
  const [card1, card2] = remainingCards;
  console.log(`剩余牌: ${card1.character}(句子${card1.sentence},位置${card1.position}) + ${card2.character}(句子${card2.sentence},位置${card2.position})`);
  
  if (card1.sentence === card2.sentence && card1.position !== card2.position) {
    console.log('句子模式成功: 剩余两张是半靠');
    return true;
  }
  
  console.log('句子模式失败: 剩余两张不是半靠');
  return false;
}

function checkHongYuan(hand, melds, effectiveHasZhao) {
  const hasPeng = melds.some(m => m.type === 'triplet');
  const hasZhao = melds.some(m => m.type === 'quartet');
  
  if (hasPeng || (hasZhao && effectiveHasZhao)) return 0;
  
  if (melds.length > 0) {
    const allSequences = melds.every(m => m.type === 'sequence');
    if (!allSequences) return 0;
  }
  
  const usedCardIds = new Set();
  let handShangDaRenSentence = false;
  let handFuLuShouSentence = false;
  
  let foundGroup = true;
  while (foundGroup) {
    foundGroup = false;
    
    for (let sentence = 1; sentence <= 8; sentence++) {
      const sentenceCards = hand.filter(c => c.sentence === sentence && !usedCardIds.has(c.id));
      
      const pos0Cards = sentenceCards.filter(c => c.position === 0);
      const pos1Cards = sentenceCards.filter(c => c.position === 1);
      const pos2Cards = sentenceCards.filter(c => c.position === 2);
      
      if (pos0Cards.length > 0 && pos1Cards.length > 0 && pos2Cards.length > 0) {
        usedCardIds.add(pos0Cards[0].id);
        usedCardIds.add(pos1Cards[0].id);
        usedCardIds.add(pos2Cards[0].id);
        foundGroup = true;
        
        if (sentence === 1) handShangDaRenSentence = true;
        if (sentence === 8) handFuLuShouSentence = true;
      }
    }
  }
  
  const remainingCards = hand.filter(c => !usedCardIds.has(c.id));
  
  if (remainingCards.length !== 2) return 0;
  
  const [card1, card2] = remainingCards;
  if (card1.character === card2.character) return 0;
  if (card1.sentence !== card2.sentence) return 0;
  if (card1.position === card2.position) return 0;
  
  let meldShangDaRenSentence = 0;
  let meldFuLuShouSentence = 0;
  
  for (const meld of melds) {
    if (meld.type === 'sequence') {
      const sentence = meld.cards[0].sentence;
      if (sentence === 1) meldShangDaRenSentence++;
      if (sentence === 8) meldFuLuShouSentence++;
    }
  }
  
  let shangDaRenSentenceCount = 0;
  let fuLuShouSentenceCount = 0;
  
  if (handShangDaRenSentence) shangDaRenSentenceCount++;
  if (handFuLuShouSentence) fuLuShouSentenceCount++;
  shangDaRenSentenceCount += meldShangDaRenSentence;
  fuLuShouSentenceCount += meldFuLuShouSentence;
  
  const totalSpecialSentenceCount = shangDaRenSentenceCount + fuLuShouSentenceCount;
  
  if (totalSpecialSentenceCount < 2) return 0;
  
  if (totalSpecialSentenceCount === 2) {
    const halfKaoSentence = remainingCards[0].sentence;
    if (halfKaoSentence !== 1 && halfKaoSentence !== 8) return 0;
  }
  
  const allCards = [...hand, ...melds.flatMap(m => m.cards)];
  const shangCount = allCards.filter(c => c.character === '上').length;
  const fuCount = allCards.filter(c => c.character === '福').length;
  const shangFuCount = shangCount + fuCount;
  
  if (shangFuCount >= 3 && shangFuCount <= 6) {
    return shangFuCount;
  }
  
  return 0;
}

function checkQingHu(hand, melds, huCount){
  const allCards = [...hand, ...melds.flatMap(m => m.cards)];
  
  const shangCount = allCards.filter(c => c.character === '上').length;
  const fuCount = allCards.filter(c => c.character === '福').length;
  
  if (shangCount > 0 || fuCount > 0) return false;
  
  const hasShangDaRenHalfKao = checkHalfKao(hand, melds, 1);
  const hasFuLuShouHalfKao = checkHalfKao(hand, melds, 8);
  
  if (hasShangDaRenHalfKao || hasFuLuShouHalfKao) return false;
  
  if (huCount < 11 || huCount > 21) return false;
  
  // 第6条：检查手牌移除句子和坎后是否只剩两张牌（半靠或对子）
  return checkQingHuRemainingCards(hand);
}

// 检查清胡条件（除了胡数范围）
function checkQingHuConditions(hand, melds) {
  const allCards = [...hand, ...melds.flatMap(m => m.cards)];
  
  // 条件1：不能有"上"字牌
  const shangCount = allCards.filter(c => c.character === '上').length;
  if (shangCount > 0) return false;
  
  // 条件2：不能有"福"字牌
  const fuCount = allCards.filter(c => c.character === '福').length;
  if (fuCount > 0) return false;
  
  // 条件3：不能有"上大人"半靠
  const hasShangDaRenHalfKao = checkHalfKao(hand, melds, 1);
  if (hasShangDaRenHalfKao) return false;
  
  // 条件4：不能有"福禄寿"半靠
  const hasFuLuShouHalfKao = checkHalfKao(hand, melds, 8);
  if (hasFuLuShouHalfKao) return false;
  
  // 条件5：总胡数必须>=11
  const huCount = calculateHuCount(hand, melds);
  if (huCount < 11) return false;
  
  // 条件6：检查手牌移除句子和坎后是否只剩两张牌（半靠或对子）
  return checkQingHuRemainingCards(hand);
}

function checkQingHuRemainingCards(hand) {
  const cards = [...hand];
  const usedIndices = new Set();
  
  let foundGroup = true;
  while (foundGroup) {
    foundGroup = false;
    
    for (let sentence = 1; sentence <= 8; sentence++) {
      const sentenceIndices = [];
      const positions = new Set();
      
      for (let i = 0; i < cards.length; i++) {
        if (usedIndices.has(i)) continue;
        if (cards[i].sentence === sentence && !positions.has(cards[i].position)) {
          sentenceIndices.push(i);
          positions.add(cards[i].position);
        }
      }
      
      if (positions.size === 3) {
        sentenceIndices.forEach(idx => usedIndices.add(idx));
        foundGroup = true;
      }
    }
  }
  
  const remainingCards = cards.filter((c, i) => !usedIndices.has(i));
  
  if (remainingCards.length !== 2) {
    return false;
  }
  
  const card1 = remainingCards[0];
  const card2 = remainingCards[1];
  
  if (card1.sentence === card2.sentence && card1.position !== card2.position) {
    return true;
  }
  
  if (card1.character === card2.character) {
    return true;
  }
  
  return false;
}

function checkHalfKao(hand, melds, sentence) {
  const sentenceCards = hand.filter(c => c.sentence === sentence);
  if (sentenceCards.length === 2) {
    return true;
  }
  
  for (const meld of melds) {
    if (meld.type === 'sequence' && meld.cards[0].sentence === sentence) {
      return true;
    }
  }
  
  return false;
}

function calculateHuCount(hand, melds, huCard = null, isDianPao = false) {
  let hu = 0;
  
  // 组合牌胡数计算
  for (const meld of melds) {
    hu += meld.huValue;
    console.log(`组合牌(${meld.type}): ${meld.huValue}胡`);
  }
  
  // 手牌胡数计算
  // 先对手牌所有的卡牌进行编号
  const cards = [...hand];
  if (huCard) cards.push(huCard);
  
  const usedCardIds = new Set();
  
  console.log('=== 手牌胡数计算过程 ===');
  console.log('手牌:', cards.map(c => c.character).join(''));
  if (isDianPao && huCard) {
    console.log('点炮牌:', huCard.character);
  }
  
  // 1. 移除所有的"句"/"精句"（完整句子）
  let foundSentence = true;
  while (foundSentence) {
    foundSentence = false;
    for (let sentence = 1; sentence <= 8; sentence++) {
      const sentenceCards = cards.filter(c => c.sentence === sentence && !usedCardIds.has(c.id));
      
      const pos0Cards = sentenceCards.filter(c => c.position === 0);
      const pos1Cards = sentenceCards.filter(c => c.position === 1);
      const pos2Cards = sentenceCards.filter(c => c.position === 2);
      
      if (pos0Cards.length > 0 && pos1Cards.length > 0 && pos2Cards.length > 0) {
        foundSentence = true;
        
        const isJingJu = sentence === 1 || sentence === 8;
        const hasShang = pos0Cards[0].character === '上' || pos1Cards[0].character === '上' || pos2Cards[0].character === '上';
        const hasFu = pos0Cards[0].character === '福' || pos1Cards[0].character === '福' || pos2Cards[0].character === '福';
        
        if (isJingJu && (hasShang || hasFu)) {
          hu += 4;
          console.log(`精句(${pos0Cards[0].character}${pos1Cards[0].character}${pos2Cards[0].character}): 4胡`);
        } else {
          console.log(`句(${pos0Cards[0].character}${pos1Cards[0].character}${pos2Cards[0].character}): 0胡`);
        }
        
        usedCardIds.add(pos0Cards[0].id);
        usedCardIds.add(pos1Cards[0].id);
        usedCardIds.add(pos2Cards[0].id);
      }
    }
  }
  
  // 2. 移除所有的"招"/"精招"（4张相同）
  const remainingAfterJu = cards.filter(c => !usedCardIds.has(c.id));
  const countsAfterJu = {};
  for (const card of remainingAfterJu) {
    countsAfterJu[card.character] = (countsAfterJu[card.character] || 0) + 1;
  }
  
  for (const [char, count] of Object.entries(countsAfterJu)) {
    if (count >= 4) {
      const isJingZhao = char === '上' || char === '福';
      if (isJingZhao) {
        hu += 16;
        console.log(`精招(${char}${count}张): 16胡`);
      } else {
        hu += 6;
        console.log(`招(${char}${count}张): 6胡`);
      }
      
      const zhaoCards = remainingAfterJu.filter(c => c.character === char);
      zhaoCards.forEach(c => usedCardIds.add(c.id));
    }
  }
  
  // 3. 移除所有的"坎"/"精坎"（3张相同）
  const remainingAfterZhao = cards.filter(c => !usedCardIds.has(c.id));
  const countsAfterZhao = {};
  for (const card of remainingAfterZhao) {
    countsAfterZhao[card.character] = (countsAfterZhao[card.character] || 0) + 1;
  }
  
  for (const [char, count] of Object.entries(countsAfterZhao)) {
    if (count >= 3) {
      const isJingKan = char === '上' || char === '福';
      if (isJingKan) {
        hu += 12;
        console.log(`精坎(${char}${count}张): 12胡`);
      } else {
        // 点炮胡牌时，如果点炮牌不是上/福，出现在坎中，算2胡
        const isDianPaoKan = isDianPao && huCard && huCard.character === char && char !== '上' && char !== '福';
        if (isDianPaoKan) {
          hu += 2;
          console.log(`点炮坎(${char}${count}张): 2胡`);
        } else {
          hu += 3;
          console.log(`坎(${char}${count}张): 3胡`);
        }
      }
      
      const kanCards = remainingAfterZhao.filter(c => c.character === char);
      kanCards.slice(0, 3).forEach(c => usedCardIds.add(c.id));
    }
  }
  
  // 4. 移除所有的"对"/"金对"/"靠"/"精靠"/"银靠"
  const remainingAfterKan = cards.filter(c => !usedCardIds.has(c.id));
  
  // 4.1 先处理对子/金对（2张相同）
  const countsAfterKan = {};
  for (const card of remainingAfterKan) {
    countsAfterKan[card.character] = (countsAfterKan[card.character] || 0) + 1;
  }
  
  for (const [char, count] of Object.entries(countsAfterKan)) {
    if (count >= 2) {
      const isJinDui = char === '上' || char === '福';
      if (isJinDui) {
        hu += 8;
        console.log(`金对(${char}${count}张): 8胡`);
      } else {
        console.log(`对(${char}${count}张): 0胡`);
      }
      
      const duiCards = remainingAfterKan.filter(c => c.character === char);
      duiCards.slice(0, 2).forEach(c => usedCardIds.add(c.id));
    }
  }
  
  // 4.2 处理靠/精靠/银靠（2张不同但同组）
  let foundKao = true;
  while (foundKao) {
    foundKao = false;
    const remainingAfterDui = cards.filter(c => !usedCardIds.has(c.id));
    
    for (let sentence = 1; sentence <= 8; sentence++) {
      const sentenceCards = remainingAfterDui.filter(c => c.sentence === sentence && !usedCardIds.has(c.id));
      
      if (sentenceCards.length === 2 && sentenceCards[0].character !== sentenceCards[1].character) {
        foundKao = true;
        const hasShang = sentenceCards.some(c => c.character === '上');
        const hasFu = sentenceCards.some(c => c.character === '福');
        const isDaRen = sentenceCards.some(c => c.character === '大') && sentenceCards.some(c => c.character === '人');
        const isLuShou = sentenceCards.some(c => c.character === '禄') && sentenceCards.some(c => c.character === '寿');
        
        if ((sentence === 1 || sentence === 8) && (hasShang || hasFu)) {
          // 精靠：组1/组8且含上/福
          hu += 4;
          console.log(`精靠(${sentenceCards.map(c => c.character).join('')}): 4胡`);
        } else if (isDaRen || isLuShou) {
          // 银靠：大人、禄寿
          console.log(`银靠(${sentenceCards.map(c => c.character).join('')}): 0胡`);
        } else {
          // 靠：其他
          console.log(`靠(${sentenceCards.map(c => c.character).join('')}): 0胡`);
        }
        
        sentenceCards.forEach(c => usedCardIds.add(c.id));
      }
    }
  }
  
  // 5. 处理单字/精单
  const remainingCards = cards.filter(c => !usedCardIds.has(c.id));
  
  for (const card of remainingCards) {
    if (card.character === '上' || card.character === '福') {
      hu += 4;
      console.log(`精单(${card.character}): 4胡`);
    } else {
      console.log(`单(${card.character}): 0胡`);
    }
  }
  
  console.log(`总胡数: ${hu}胡`);
  console.log('==================');
  
  return hu;
}

function performChi(playerIndex) {
  const player = gameState.players[playerIndex];
  const card = gameState.lastDiscardedCard;
  
  console.log(`【${player.name}】吃牌: ${card.character}, 手牌: ${player.hand.length} -> ${player.hand.length - 2}`);
  
  playButtonSound('吃', playerIndex);
  
  const sentenceCards = player.hand.filter(c => c.sentence === card.sentence);
  let chiCards = [card];
  
  if (card.position === 0) {
    const pos1Card = sentenceCards.find(c => c.position === 1);
    const pos2Card = sentenceCards.find(c => c.position === 2);
    if (!pos1Card || !pos2Card) {
      console.error('performChi: 找不到完整的吃牌组合');
      return;
    }
    chiCards.push(pos1Card, pos2Card);
  } else if (card.position === 1) {
    const pos0Card = sentenceCards.find(c => c.position === 0);
    const pos2Card = sentenceCards.find(c => c.position === 2);
    if (!pos0Card || !pos2Card) {
      console.error('performChi: 找不到完整的吃牌组合');
      return;
    }
    chiCards.push(pos0Card, pos2Card);
  } else {
    const pos0Card = sentenceCards.find(c => c.position === 0);
    const pos1Card = sentenceCards.find(c => c.position === 1);
    if (!pos0Card || !pos1Card) {
      console.error('performChi: 找不到完整的吃牌组合');
      return;
    }
    chiCards.push(pos0Card, pos1Card);
  }
  
  // 播放吃牌动画
  animateMeldCards(playerIndex, chiCards, 'chi', () => {
    for (const c of chiCards) {
      if (c !== card) {
        const idx = player.hand.findIndex(h => h.id === c.id);
        if (idx !== -1) player.hand.splice(idx, 1);
      }
    }
    
    console.log('吃牌后手牌数:', player.hand.length);
    
    const orderedCards = [];
    const pos0Card = chiCards.find(c => c.position === 0);
    const pos1Card = chiCards.find(c => c.position === 1);
    const pos2Card = chiCards.find(c => c.position === 2);
    
    if (pos0Card) orderedCards.push(pos0Card);
    if (pos1Card) orderedCards.push(pos1Card);
    if (pos2Card) orderedCards.push(pos2Card);
    
    const hasShangOrFu = orderedCards.some(c => c.character === '上' || c.character === '福');
    const isJingJu = (orderedCards[0].sentence === 1 || orderedCards[0].sentence === 8) && hasShangOrFu;
    const huValue = isJingJu ? 4 : 0;
    
    player.melds.push({
      type: 'sequence',
      cards: orderedCards,
      source: 'chi',
      huValue: huValue
    });
    
    player.isTing = false;
    if (playerIndex === 1) {
      const tingBadge = document.getElementById('tingBadge');
      const zimoBadge = document.getElementById('zimoBadge');
      tingBadge.classList.add('hidden');
      zimoBadge.classList.add('hidden');
    }
    
    removeLastDiscard();
    gameState.lastDiscardedCard = null;
    gameState.currentPlayerIndex = playerIndex;
    gameState.waitingForResponse = false;
    gameState.skipDraw = true;
    
    updateUI();
    
    gameState.canChi = false;
    gameState.canPeng = false;
    gameState.canZhao = false;
    gameState.canHu = false;
    
    updateCurrentPlayerUI();
    startCountdown();
    
    if (player.type === 'human') {
      gameState.isMyTurn = true;
      const tingResult = checkTing(player);
      player.isTing = tingResult.isTing;
      updateHuBadgeDisplay();
      updateActionButtons();
    } else {
      gameState.isMyTurn = false;
      setTimeout(() => processAITurn(), 800 + Math.random() * 500);
    }
  });
}

function performPeng(playerIndex) {
  const player = gameState.players[playerIndex];
  const card = gameState.lastDiscardedCard;
  
  console.log(`=== 【${player.name}】碰牌 ===`);
  console.log('碰牌前手牌数:', player.hand.length);
  console.log('碰牌:', card.character);
  
  playButtonSound('碰', playerIndex);
  
  const matchingCards = player.hand.filter(c => c.character === card.character).slice(0, 2);
  const pengCards = [card, ...matchingCards];
  
  // 播放碰牌动画
  animateMeldCards(playerIndex, pengCards, 'peng', () => {
    for (const c of matchingCards) {
      const idx = player.hand.findIndex(h => h.id === c.id);
      if (idx !== -1) player.hand.splice(idx, 1);
    }
    
    console.log('碰牌后手牌数:', player.hand.length);
    
    const isSpecial = card.character === '上' || card.character === '福';
    player.melds.push({
      type: 'triplet',
      cards: pengCards,
      source: 'peng',
      huValue: isSpecial ? 12 : 2
    });
    
    player.isTing = false;
    if (playerIndex === 1) {
      const tingBadge = document.getElementById('tingBadge');
      const zimoBadge = document.getElementById('zimoBadge');
      tingBadge.classList.add('hidden');
      zimoBadge.classList.add('hidden');
    }
    
    removeLastDiscard();
    gameState.lastDiscardedCard = null;
    gameState.currentPlayerIndex = playerIndex;
    gameState.waitingForResponse = false;
    gameState.skipDraw = true;
    
    updateUI();
    
    gameState.canChi = false;
    gameState.canPeng = false;
    gameState.canZhao = false;
    gameState.canHu = false;
    
    updateCurrentPlayerUI();
    startCountdown();
    
    if (player.type === 'human') {
      gameState.isMyTurn = true;
      const tingResult = checkTing(player);
      player.isTing = tingResult.isTing;
      updateHuBadgeDisplay();
      updateActionButtons();
    } else {
      gameState.isMyTurn = false;
      setTimeout(() => processAITurn(), 800 + Math.random() * 500);
    }
  });
}

function performZhao(playerIndex, char = null) {
  const player = gameState.players[playerIndex];
  
  console.log(`=== 【${player.name}】招牌 ===`);
  console.log('招牌前手牌数:', player.hand.length);
  console.log('招牌:', char || gameState.lastDiscardedCard?.character);
  
  playButtonSound('招', playerIndex);
  
  let zhaoCards;
  let isFromDiscard = false;
  
  if (char) {
    zhaoCards = player.hand.filter(c => c.character === char).slice(0, 4);
    for (const c of zhaoCards) {
      const idx = player.hand.findIndex(h => h.id === c.id);
      if (idx !== -1) player.hand.splice(idx, 1);
    }
  } else {
    const card = gameState.lastDiscardedCard;
    if (!card) {
      console.error('performZhao: 没有可招的牌');
      return;
    }
    isFromDiscard = true;
    const matchingCards = player.hand.filter(c => c.character === card.character);
    zhaoCards = [card, ...matchingCards];
    
    // 播放招牌动画
    animateMeldCards(playerIndex, zhaoCards, 'zhao', () => {
      for (const c of matchingCards) {
        const idx = player.hand.findIndex(h => h.id === c.id);
        if (idx !== -1) player.hand.splice(idx, 1);
      }
      
      removeLastDiscard();
      gameState.lastDiscardedCard = null;
      
      finishZhao(playerIndex, player, zhaoCards);
    });
    return;
  }
  
  finishZhao(playerIndex, player, zhaoCards);
}

function finishZhao(playerIndex, player, zhaoCards) {
  console.log('招牌后手牌数:', player.hand.length);
  
  const isSpecial = zhaoCards[0].character === '上' || zhaoCards[0].character === '福';
  player.melds.push({
    type: 'quartet',
    cards: zhaoCards,
    source: 'zhao',
    huValue: isSpecial ? 16 : 6
  });
  
  player.isTing = false;
  if (playerIndex === 1) {
    const tingBadge = document.getElementById('tingBadge');
    const zimoBadge = document.getElementById('zimoBadge');
    tingBadge.classList.add('hidden');
    zimoBadge.classList.add('hidden');
  }
  
  gameState.currentPlayerIndex = playerIndex;
  gameState.waitingForResponse = false;
  gameState.skipDraw = true;
  
  updateUI();
  
  if (gameState.deck.length > 0) {
    const drawnCard = gameState.deck.pop();
    updateDeckStack();
    
    animateDrawCard(playerIndex, drawnCard, () => {
      player.hand.push(drawnCard);
      player.hand = sortHand(player.hand);
      gameState.lastDrawnCard = drawnCard;
      updateUI();
      
      if (playerIndex === 1) {
        gameState.isMyTurn = true;
        const tingResult = checkTing(player);
        player.isTing = tingResult.isTing;
        
        const huResult = checkHu(player);
        const canZimo = player.isTing && huResult.canHu;
        
        console.log('招牌补牌后检查 - isTing:', player.isTing, 'canHu:', huResult.canHu, 'canZimo:', canZimo);
        
        const tingBadge = document.getElementById('tingBadge');
        const zimoBadge = document.getElementById('zimoBadge');
        tingBadge.classList.add('hidden');
        zimoBadge.classList.add('hidden');
        
        updateHuBadgeDisplay();
        
        if (canZimo) {
          console.log('招牌补牌后显示自摸徽章');
          zimoBadge.classList.remove('hidden');
          zimoAnnounced = false;
          playZimoAnnouncement();
        }
        
        startCountdown();
        updateActionButtons();
      } else {
        startTurn();
      }
    });
  } else {
    console.log('荒庄，庄家不变，庄家索引:', gameState.dealerIndex);
    
    // 记录流局统计信息
    const roundInfo = {
      roundNumber: gameState.roundNumber,
      winner: null,
      winnerIndex: -1,
      huType: null,
      method: null,
      score: 0,
      piaoScores: gameState.players.map(p => p.piao),
      isLiuJu: true,
      scoreChanges: [0, 0, 0]
    };
    gameState.roundHistory.push(roundInfo);
    
    showMessage('流局', '牌堆已空，本局结束', true);
  }
}

function handleHu(playerIndex, method) {
  stopCountdown();
  
  gameState.isMyTurn = false;
  gameState.waitingForResponse = false;
  gameState.selectedCardIndex = -1;
  
  const tingBadge = document.getElementById('tingBadge');
  const zimoBadge = document.getElementById('zimoBadge');
  if (tingBadge) tingBadge.classList.add('hidden');
  if (zimoBadge) zimoBadge.classList.add('hidden');
  
  const player = gameState.players[playerIndex];
  const huCard = method === 'dianpao' ? gameState.lastDiscardedCard : null;
  const isDianPao = method === 'dianpao';
  const huResult = checkHu(player, huCard, isDianPao);
  
  console.log('=== 胡牌信息 ===');
  console.log('胡牌类型:', huResult.huType);
  console.log('胡数:', huResult.huCount);
  console.log('胡牌方式:', method);
  
  // 播放胡牌语音 - 播报胡牌类型
  playButtonSound('胡', playerIndex);
  speakText(huResult.huType.name, playerIndex);
  
  // 获取对应胡牌方式的倍数
  const baseMultiplier = method === 'zimo' ? huResult.huType.multiplier.zimo : huResult.huType.multiplier.dianpao;
  const displayMultiplier = baseMultiplier;
  
  const winner = player;
  const winnerPiao = winner.piao;
  
  const scoresBefore = gameState.players.map(p => p.score);
  let score = 0;
  
  if (method === 'zimo') {
    // 自摸：
    // 每个输家输的分数 = 底分 + 倍数 × 倍数基数分 + 飘分(输家飘分 + 赢家飘分)
    // 赢家分数 = 2 ×（底分 + 倍数 × 倍数基数分）+ 飘分(赢家飘分*2 + 其它两个玩家飘分之和)
    
    const otherPiaoSum = gameState.players.reduce((sum, p, i) => {
      return i !== playerIndex ? sum + p.piao : sum;
    }, 0);
    
    const winnerScore = 2 * (gameState.baseScore + baseMultiplier * gameState.multiplierBase) + winnerPiao * 2 + otherPiaoSum;
    
    for (let i = 0; i < gameState.players.length; i++) {
      if (i !== playerIndex) {
        const loser = gameState.players[i];
        const loserScore = gameState.baseScore + baseMultiplier * gameState.multiplierBase + loser.piao + winnerPiao;
        loser.score -= loserScore;
      }
    }
    
    winner.score += winnerScore;
    score = winnerScore;
  } else {
    // 点炮：
    // 输牌人分数 = 底分 + 倍数 × 倍数基数分 + 飘分(点炮人飘分 + 赢家飘分)
    // 赢牌人分数 = 底分 + 倍数 × 倍数基数分 + 飘分(赢家飘分 + 点炮人飘分)
    // 两者相等
    
    if (gameState.lastDiscardPlayerIndex < 0 || gameState.lastDiscardPlayerIndex >= gameState.players.length) {
      console.error('handleHu: 无效的点炮玩家索引');
      return;
    }
    const dianPaoPlayer = gameState.players[gameState.lastDiscardPlayerIndex];
    if (!dianPaoPlayer) {
      console.error('handleHu: 找不到点炮玩家');
      return;
    }
    const dianPaoPiao = dianPaoPlayer.piao;
    
    const loserScore = gameState.baseScore + baseMultiplier * gameState.multiplierBase + dianPaoPiao + winnerPiao;
    dianPaoPlayer.score -= loserScore;
    
    winner.score += loserScore;
    score = loserScore;
  }
  
  const huTypeName = huResult.huType.name;
  const methodName = method === 'zimo' ? '自摸' : '点炮';
  const dianPaoPlayer = method === 'dianpao' ? gameState.players[gameState.lastDiscardPlayerIndex] : null;
  
  // 计算输家的分数
  const loserScores = [];
  if (method === 'zimo') {
    // 自摸：两家都输
    for (let i = 0; i < gameState.players.length; i++) {
      if (i !== playerIndex) {
        const loser = gameState.players[i];
        const loserScore = gameState.baseScore + baseMultiplier * gameState.multiplierBase + loser.piao + winnerPiao;
        loserScores.push({ name: loser.name, score: loserScore });
      }
    }
  } else {
    // 点炮：只有点炮人输
    if (dianPaoPlayer) {
      const loserScore = gameState.baseScore + baseMultiplier * gameState.multiplierBase + dianPaoPlayer.piao + winnerPiao;
      loserScores.push({ name: dianPaoPlayer.name, score: loserScore });
    }
  }
  
  // 记录本局统计信息
  const roundInfo = {
    roundNumber: gameState.roundNumber,
    winner: player.name,
    winnerIndex: playerIndex,
    huType: huTypeName,
    method: methodName,
    multiplier: displayMultiplier,
    score: score,
    piaoScores: gameState.players.map(p => p.piao),
    isLiuJu: false,
    scoreChanges: gameState.players.map((p, i) => p.score - scoresBefore[i])
  };
  gameState.roundHistory.push(roundInfo);
  
  if (playerIndex !== gameState.dealerIndex) {
    gameState.dealerIndex = (gameState.dealerIndex + 1) % 3;
    console.log('庄家轮换，新庄家索引:', gameState.dealerIndex);
  } else {
    console.log('庄家胡牌，庄家不变');
  }
  
  showHuMessage(player, huResult, methodName, huTypeName, score, dianPaoPlayer, method, huCard, displayMultiplier, loserScores);
  
  updateUI();
}

function showHuMessage(player, huResult, methodName, huTypeName, score, dianPaoPlayer, method, huCard, multiplier, loserScores) {
  const overlay = document.getElementById('dealingOverlay');
  const mask = document.getElementById('dealingMask');
  
  if (!overlay || !mask) {
    console.error('showHuMessage: 找不到必要的DOM元素');
    return;
  }
  
  overlay.classList.remove('hidden');
  mask.classList.remove('hidden');
  overlay.style.display = 'flex';
  mask.style.display = 'block';
  
  let displayHand = [...player.hand];
  let displayHuCard = huCard;
  
  if (method === 'zimo' && !huCard && player.hand.length > 0) {
    displayHuCard = player.hand[player.hand.length - 1];
  }
  
  if (huCard && method === 'dianpao') {
    displayHand.push(huCard);
  }
  
  const sortedHand = sortHand(displayHand);
  
  const sentenceGroups = {};
  for (const card of sortedHand) {
    if (!sentenceGroups[card.sentence]) {
      sentenceGroups[card.sentence] = {};
    }
    if (!sentenceGroups[card.sentence][card.position]) {
      sentenceGroups[card.sentence][card.position] = [];
    }
    sentenceGroups[card.sentence][card.position].push(card);
  }
  
  let handHtml = '';
  let maxCardsInSentence = 0;
  for (let sentence = 1; sentence <= 8; sentence++) {
    if (!sentenceGroups[sentence]) continue;
    
    const posCount = Object.keys(sentenceGroups[sentence]).length;
    if (posCount > maxCardsInSentence) maxCardsInSentence = posCount;
    
    handHtml += '<div style="display: flex; flex-direction: column; gap: 2px; position: relative; margin: 0 3px;">';
    
    for (let pos = 0; pos <= 2; pos++) {
      if (!sentenceGroups[sentence][pos]) continue;
      
      const cards = sentenceGroups[sentence][pos];
      const pinyin = CARD_PINYIN[cards[0].character];
      
      const isHuCard = displayHuCard && cards.some(c => c.id === displayHuCard.id);
      const labelHtml = isHuCard ? `<div style="position: absolute; left: 50%; top: 50%; transform: translate(-50%, -50%); font-size: 16px; font-weight: bold; color: #fff; text-shadow: 0 0 10px #ff0000, 0 0 20px #ff0000; z-index: 10;">${method === 'zimo' ? '自摸' : '炮'}</div>` : '';
      
      handHtml += `
        <div style="position: relative; width: 40px; height: 168px; margin-bottom: -140px;">
          <div style="background-image: url('images/${pinyin}.png'); background-size: contain; background-position: center; background-repeat: no-repeat; width: 40px; height: 168px;"></div>
          ${labelHtml}
          ${cards.length > 1 ? `<div style="position: absolute; top: -5px; right: -5px; width: 18px; height: 18px; background: #ff6b6b; color: #fff; border-radius: 50%; font-size: 11px; font-weight: bold; display: flex; align-items: center; justify-content: center;">${cards.length}</div>` : ''}
        </div>
      `;
    }
    
    handHtml += '</div>';
  }
  
  const handAreaHeight = 168 + (maxCardsInSentence - 1) * 28;
  
  let meldsHtml = '';
  if (player.melds.length > 0) {
    meldsHtml = '<div style="margin-top: 25px;"><div style="font-size: 16px; color: #ffd700; margin-bottom: 12px;">组合牌:</div><div style="display: flex; flex-wrap: wrap; justify-content: center; gap: 4px; background: rgba(0,0,0,0.3); padding: 4px; border-radius: 10px;">';
    
    for (const meld of player.melds) {
      for (const card of meld.cards) {
        const pinyin = CARD_PINYIN[card.character];
        meldsHtml += `<div style="background-image: url('images/s/${pinyin}.png'); background-size: contain; background-position: center; background-repeat: no-repeat; width: 20px; height: 84px;"></div>`;
      }
    }
    
    meldsHtml += '</div></div>';
  }
  
  let losersHandHtml = '';
  const winnerIndex = gameState.players.findIndex(p => p === player);
  for (let i = 0; i < gameState.players.length; i++) {
    if (i === winnerIndex) continue;
    
    const loser = gameState.players[i];
    if (loser.hand.length === 0) continue;
    
    losersHandHtml += `<div style="margin-top: 20px; padding: 10px; background: rgba(0,0,0,0.2); border-radius: 10px;">`;
    losersHandHtml += `<div style="font-size: 14px; color: #aaa; margin-bottom: 8px;">${loser.name}的手牌:</div>`;
    losersHandHtml += `<div style="display: flex; flex-wrap: wrap; justify-content: center; gap: 2px;">`;
    
    const sortedHand = sortHand([...loser.hand]);
    for (const card of sortedHand) {
      const pinyin = CARD_PINYIN[card.character];
      losersHandHtml += `<div style="background-image: url('images/s/${pinyin}.png'); background-size: contain; background-position: center; background-repeat: no-repeat; width: 18px; height: 60px;"></div>`;
    }
    
    losersHandHtml += `</div></div>`;
  }
  
  let loserScoresHtml = '';
  if (loserScores && loserScores.length > 0) {
    loserScoresHtml = '<div style="margin-top: 15px; display: flex; justify-content: center; gap: 20px;">';
    for (const ls of loserScores) {
      loserScoresHtml += `<span style="color: #ff6b6b; font-size: 14px;">${ls.name}: -${ls.score}</span>`;
    }
    loserScoresHtml += '</div>';
  }
  
  const html = `
    <div style="text-align: center; padding: 20px;">
      <div style="font-size: 24px; color: #ffd700; margin-bottom: 15px;">${player.name} 胡牌!</div>
      <div style="display: flex; justify-content: center; align-items: center; gap: 14px; font-size: 10px; margin-bottom: 15px;">
        <span style="color: #fff;">${methodName}${dianPaoPlayer ? ` - ${dianPaoPlayer.name}点炮` : ''}</span>
        <span style="color: #4ecdc4;">${huTypeName}</span>
        <span style="color: #ffd700;">胡数: ${huResult.huCount}</span>
        <span style="color: #ff6b6b;">倍数: ${multiplier}倍</span>
        <span style="color: #4ecdc4;">得分: +${score}</span>
      </div>
      <div style="display: flex; flex-wrap: wrap; justify-content: center; gap: 8px; margin: 15px 0; padding: 10px; background: rgba(0,0,0,0.3); border-radius: 10px; min-height: ${handAreaHeight}px;">
        ${handHtml}
      </div>
      ${meldsHtml}
      ${losersHandHtml}
      ${loserScoresHtml}
      <button id="huConfirmBtn" class="btn btn-primary" style="margin-top: 15px; pointer-events: auto; z-index: 3001;">确定</button>
    </div>
  `;
  
  overlay.querySelector('.dealing-text').innerHTML = html;
  
  const confirmBtn = document.getElementById('huConfirmBtn');
  if (confirmBtn) {
    confirmBtn.addEventListener('click', closeHuMessage);
  }
}

function closeHuMessage() {
  const overlay = document.getElementById('dealingOverlay');
  const mask = document.getElementById('dealingMask');
  
  if (overlay) {
    overlay.style.display = 'none';
    const dealingText = overlay.querySelector('.dealing-text');
    if (dealingText) dealingText.innerHTML = '';
  }
  if (mask) mask.style.display = 'none';
  
  stopCountdown();
  
  gameState.isMyTurn = false;
  gameState.waitingForResponse = false;
  gameState.selectedCardIndex = -1;
  gameState.canHu = false;
  gameState.canZhao = false;
  gameState.canPeng = false;
  gameState.canChi = false;
  gameState.isDrawing = false;
  gameState.skipDraw = false;
  
  const container = document.getElementById('actionButtons');
  if (container) container.innerHTML = '';
  
  const elementIds = ['myHand', 'player1Discard', 'myDiscard', 'player2Discard', 
                      'player1Melds', 'myMelds', 'player2Melds', 'playedCards'];
  elementIds.forEach(id => {
    const el = document.getElementById(id);
    if (el) el.innerHTML = '';
  });
  
  document.querySelectorAll('body > div[style*="position: fixed"][style*="z-index: 9999"]').forEach(el => el.remove());
  document.querySelectorAll('body > div[style*="position: fixed"][style*="z-index: 10000"]').forEach(el => el.remove());
  
  const zimoBadge = document.getElementById('zimoBadge');
  if (zimoBadge) zimoBadge.classList.add('hidden');
  
  document.getElementById('player1HandCount').textContent = '0';
  document.getElementById('myHandCount').textContent = '0';
  document.getElementById('player2HandCount').textContent = '0';
  document.getElementById('player1Score').textContent = gameState.players[0].score;
  document.getElementById('myScore').textContent = gameState.players[1].score;
  document.getElementById('player2Score').textContent = gameState.players[2].score;
  
  const huBadge = document.getElementById('myHuBadge');
  if (huBadge) huBadge.classList.add('hidden');
  
  const tingBadge = document.getElementById('tingBadge');
  tingBadge.classList.add('hidden');
  
  // 检查是否需要显示结算页面
  if (gameState.roundNumber >= 8) {
    showSettlementPage();
    return;
  }
  
  startRound();
}

function removeLastDiscard() {
  const discardPlayer = gameState.players[gameState.lastDiscardPlayerIndex];
  if (discardPlayer && discardPlayer.discards.length > 0) {
    discardPlayer.discards.pop();
  }
}

function moveToNextPlayer() {
  console.log('=== 进入下一玩家 ===');
  gameState.currentPlayerIndex = (gameState.currentPlayerIndex + 1) % 3;
  gameState.lastDiscardedCard = null;
  gameState.waitingForResponse = false;
  gameState.canHu = false;
  gameState.canZhao = false;
  gameState.canPeng = false;
  gameState.canChi = false;
  gameState.skipDraw = false;
  
  console.log('当前玩家索引:', gameState.currentPlayerIndex);
  console.log('玩家类型:', gameState.players[gameState.currentPlayerIndex].type);
  
  if (gameState.deck.length === 0) {
    console.log('荒庄，庄家不变，庄家索引:', gameState.dealerIndex);
    showMessage('流局', '牌堆已空，本局结束', true);
    return;
  }
  
  startTurn();
}

function passAction() {
  stopCountdown();
  gameState.waitingForResponse = false;
  
  // 保存当前可操作状态
  const canHu = gameState.canHu;
  const canZhao = gameState.canZhao;
  const canPeng = gameState.canPeng;
  const canChi = gameState.canChi;
  
  gameState.canHu = false;
  gameState.canZhao = false;
  gameState.canPeng = false;
  gameState.canChi = false;
  updateActionButtons();
  
  // 人类玩家放弃操作后，检查AI玩家是否可以执行操作
  // 按优先级：胡 > 招 > 碰 > 吃
  const card = gameState.lastDiscardedCard;
  if (!card) {
    moveToNextPlayer();
    return;
  }
  
  // 检查AI玩家是否可以执行更高优先级的操作
  for (let i = 0; i < gameState.players.length; i++) {
    if (i === 1 || i === gameState.lastDiscardPlayerIndex) continue;
    
    const player = gameState.players[i];
    
    // 如果人类玩家放弃了胡，检查AI是否可以胡
    if (canHu) {
      const huResult = checkHu(player, card, true);
      if (player.isTing && huResult.canHu) {
        console.log('AI玩家', player.name, '可以胡');
        handleHu(i, 'dianpao');
        return;
      }
    }
  }
  
  // 如果人类玩家放弃了招，检查AI是否可以招
  if (canZhao) {
    for (let i = 0; i < gameState.players.length; i++) {
      if (i === 1 || i === gameState.lastDiscardPlayerIndex) continue;
      const player = gameState.players[i];
      if (canPlayerZhao(player, card)) {
        console.log('AI玩家', player.name, '可以招');
        performZhao(i);
        return;
      }
    }
  }
  
  // 如果人类玩家放弃了碰，检查AI是否可以碰
  if (canPeng) {
    for (let i = 0; i < gameState.players.length; i++) {
      if (i === 1 || i === gameState.lastDiscardPlayerIndex) continue;
      const player = gameState.players[i];
      if (canPlayerPeng(player, card) && Math.random() > 0.3) {
        console.log('AI玩家', player.name, '可以碰');
        performPeng(i);
        return;
      }
    }
  }
  
  // 如果人类玩家放弃了吃，检查AI是否可以吃
  if (canChi) {
    const isNextPlayer = 1 === (gameState.lastDiscardPlayerIndex + 1) % 3;
    if (!isNextPlayer) {
      for (let i = 0; i < gameState.players.length; i++) {
        if (i === 1 || i === gameState.lastDiscardPlayerIndex) continue;
        const player = gameState.players[i];
        const isAI = i === (gameState.lastDiscardPlayerIndex + 1) % 3;
        if (isAI && canPlayerChi(player, card)) {
          console.log('AI玩家', player.name, '可以吃');
          performChi(i);
          return;
        }
      }
    }
  }
  
  // 无人响应，进入下一玩家
  moveToNextPlayer();
}

function chiAction() {
  if (!gameState.canChi) return;
  stopCountdown();
  performChi(1);
}

function pengAction() {
  if (!gameState.canPeng) return;
  stopCountdown();
  performPeng(1);
}

function zhaoAction() {
  if (!gameState.canZhao) return;
  stopCountdown();
  performZhao(1);
}

function huAction() {
  if (!gameState.canHu) return;
  stopCountdown();
  handleHu(1, 'dianpao');
}

function discardAction() {
  if (!gameState.isMyTurn || gameState.selectedCardIndex < 0) return;
  
  const me = gameState.players[1];
  
  const huResult = checkHu(me);
  if (huResult.canHu) {
    handleHu(1, 'zimo');
    return;
  }
  
  const selectedIndex = gameState.selectedCardIndex;
  gameState.selectedCardIndex = -1;
  gameState.isMyTurn = false;
  
  const container = document.getElementById('actionButtons');
  container.innerHTML = '';
  
  discardCard(1, selectedIndex);
}

function selectCard(index) {
  if (!gameState.isMyTurn) return;
  
  gameState.selectedCardIndex = index;
  updateMyHand();
}

function updateActionButtons() {
  const container = document.getElementById('actionButtons');
  container.innerHTML = '';
  
  console.log('=== 更新操作按钮 ===');
  console.log('waitingForResponse:', gameState.waitingForResponse);
  console.log('isMyTurn:', gameState.isMyTurn);
  console.log('canChi:', gameState.canChi);
  console.log('canPeng:', gameState.canPeng);
  console.log('canZhao:', gameState.canZhao);
  console.log('canHu:', gameState.canHu);
  
  const tingBadge = document.getElementById('tingBadge');
  const me = gameState.players[1];
  
  if (gameState.waitingForResponse) {
    console.log('显示响应按钮');
    
    if (gameState.canHu && me.isTing) {
      createButton(container, '胡', 'btn-danger', huAction);
      if (tingBadge) tingBadge.classList.add('hidden');
    } else {
      if (tingBadge && me.isTing) tingBadge.classList.remove('hidden');
    }
    if (gameState.canChi) {
      createButton(container, '吃', 'btn-primary', chiAction);
    }
    if (gameState.canPeng) {
      createButton(container, '碰', 'btn-primary', pengAction);
    }
    if (gameState.canZhao) {
      createButton(container, '招', 'btn-warning', zhaoAction);
    }
    createButton(container, '过', 'btn-secondary', passAction);
  } else if (gameState.isMyTurn) {
    console.log('显示我的回合按钮');
    
    const counts = {};
    for (const card of me.hand) {
      counts[card.character] = (counts[card.character] || 0) + 1;
    }
    
    let hasFourOfAKind = false;
    for (const count of Object.values(counts)) {
      if (count >= 4) {
        hasFourOfAKind = true;
        break;
      }
    }
    
    if (hasFourOfAKind) {
      createButton(container, '招', 'btn-warning', () => {
        for (const [char, count] of Object.entries(counts)) {
          if (count >= 4) {
            performZhao(1, char);
            break;
          }
        }
      });
    }
    
    if (gameState.selectedCardIndex >= 0) {
      createButton(container, '出牌', 'btn-primary', discardAction);
    }
  } else {
    console.log('不显示任何按钮');
  }
}

function createButton(container, text, className, onClick) {
  const btn = document.createElement('button');
  btn.className = `btn ${className}`;
  btn.textContent = text;
  btn.onclick = () => {
    if (text !== '出牌') {
      playButtonSound(text);
    }
    onClick();
  };
  container.appendChild(btn);
}

function updateCurrentPlayerUI() {
  const names = document.querySelectorAll('.player-name');
  names.forEach((el, i) => {
    el.classList.toggle('current', i === gameState.currentPlayerIndex);
  });
}

function updateAvatars() {
  const avatarIds = ['player1Avatar', 'myAvatar', 'player2Avatar'];
  
  avatarIds.forEach((id, index) => {
    const avatar = document.getElementById(id);
    if (avatar) {
      const avatarIcon = avatar.querySelector('.avatar-icon');
      const roleBadge = avatar.querySelector('.role-badge');
      
      if (index === gameState.dealerIndex) {
        avatar.className = 'player-avatar landlord';
        if (avatarIcon) avatarIcon.textContent = '👑';
        if (roleBadge) roleBadge.textContent = '庄家';
      } else {
        avatar.className = 'player-avatar farmer';
        if (avatarIcon) avatarIcon.textContent = '👨‍🌾';
        if (roleBadge) roleBadge.textContent = '闲家';
      }
    }
  });
}

function updateUI() {
  console.log('updateUI - 开始');
  updatePlayerArea(0, 'player1');
  updatePlayerArea(1, 'my');
  updatePlayerArea(2, 'player2');
  updateDeckStack();
  console.log('updateUI - 结束');
}

function updatePlayerArea(playerIndex, prefix) {
  console.log('updatePlayerArea - playerIndex:', playerIndex, 'prefix:', prefix);
  const player = gameState.players[playerIndex];
  
  const handCountEl = document.getElementById(`${prefix}HandCount`);
  const scoreEl = document.getElementById(`${prefix}Score`);
  const meldsEl = document.getElementById(`${prefix}Melds`);
  const piaoEl = document.getElementById(`${prefix}Piao`);
  
  if (handCountEl) handCountEl.textContent = player.hand.length;
  if (scoreEl) scoreEl.textContent = player.score;
  if (piaoEl) {
    if (player.piao > 0) {
      piaoEl.textContent = `飘${player.piao}分`;
      piaoEl.classList.remove('hidden');
    } else {
      piaoEl.classList.add('hidden');
    }
  }
  
  if (meldsEl) {
    meldsEl.innerHTML = '';
    const sortedMelds = [...player.melds].sort((a, b) => {
      const minSentenceA = a.cards.length > 0 ? Math.min(...a.cards.map(c => c.sentence)) : 0;
      const minSentenceB = b.cards.length > 0 ? Math.min(...b.cards.map(c => c.sentence)) : 0;
      return minSentenceA - minSentenceB;
    });
    
    for (const meld of sortedMelds) {
      const meldDiv = document.createElement('div');
      meldDiv.className = 'meld-group';
      
      const cardsDiv = document.createElement('div');
      cardsDiv.className = 'meld-cards';
      for (const card of meld.cards) {
        cardsDiv.appendChild(createSmallCardElement(card));
      }
      
      meldDiv.appendChild(cardsDiv);
      
      meldsEl.appendChild(meldDiv);
    }
  }
  
  const discardsEl = document.getElementById(`${prefix}Discard`);
  if (discardsEl) {
    discardsEl.innerHTML = '';
    for (const card of player.discards) {
      discardsEl.appendChild(createSmallCardElement(card));
    }
  }
  
  if (playerIndex === 1) {
    console.log('更新我的手牌区域...');
    updateMyHand();
    
    const tingBadge = document.getElementById('tingBadge');
    const tingResult = checkTing(player);
    tingBadge.classList.toggle('hidden', !tingResult.isTing);
    
    const huBadge = document.getElementById('myHuBadge');
    const displayHuCount = calculateDisplayHuCount(player);
    if (huBadge) {
      if (displayHuCount > 0) {
        huBadge.textContent = `${displayHuCount}胡`;
        huBadge.classList.remove('hidden');
      } else {
        huBadge.classList.add('hidden');
      }
    }
  }
}

function calculateDisplayHuCount(player) {
  let hu = 0;
  
  for (const meld of player.melds) {
    if (meld.huValue) {
      hu += meld.huValue;
    }
  }
  
  const hand = player.hand;
  
  const shangCount = hand.filter(c => c.character === '上').length;
  const fuCount = hand.filter(c => c.character === '福').length;
  hu += (shangCount + fuCount) * 4;
  
  const counts = {};
  for (const card of hand) {
    if (card.character !== '上' && card.character !== '福') {
      counts[card.character] = (counts[card.character] || 0) + 1;
    }
  }
  
  for (const count of Object.values(counts)) {
    if (count === 4) {
      hu += 6;
    } else if (count === 3) {
      hu += 3;
    }
  }
  
  return hu;
}

function updateHuBadgeDisplay() {
  const player = gameState.players[1];
  const huBadge = document.getElementById('myHuBadge');
  const displayHuCount = calculateDisplayHuCount(player);
  if (huBadge) {
    if (displayHuCount > 0) {
      huBadge.textContent = `${displayHuCount}胡`;
      huBadge.classList.remove('hidden');
    } else {
      huBadge.classList.add('hidden');
    }
  }
}

function updateMyHand() {
  renderMyHand();
}

function createCardElement(card, small = false) {
  const div = document.createElement('div');
  div.className = `card ${card.color}${small ? ' small' : ''}${card.isSpecial ? ' special' : ''}`;
  div.textContent = card.character;
  return div;
}

function checkTing(player) {
  const hand = [...player.hand];
  const melds = player.melds;
  const huCount = calculateHuCount(hand, melds);
  
  console.log('==============================');
  console.log(`【${player.name}】听牌检测`);
  console.log('==============================');
  console.log('手牌:', hand.map(c => c.character).join(''));
  console.log('组合牌:', melds.length > 0 ? melds.map(m => m.cards.map(c => c.character).join('')).join(' | ') : '无');
  console.log('胡数:', huCount);
  console.log('手牌数量:', hand.length);
  
  const allCharacters = ['上', '大', '人', '丘', '乙', '己', '化', '三', '千', '七', '十', '土', '尔', '小', '生', '八', '九', '子', '佳', '作', '亡', '福', '禄', '寿'];
  
  let foundTing = false;
  let tingCards = [];
  
  for (const char of allCharacters) {
    const testCard = createCardByCharacter(char);
    if (!testCard) continue;
    
    const testHandWithDraw = [...hand, testCard];
    const testHuCount = calculateHuCount(testHandWithDraw, melds);
    const huType = determineHuType(testHandWithDraw, melds, testHuCount);
    
    if (huType.type !== 'none') {
      if (['kuHu', 'qingKuHu', 'kuTaiHu', 'kuChongTaiHu', 'kuChongTaiKa', 'qingKuTaiKa', 'qingKuTaiHu', 'qingKuChongTaiHu', 'qingKuChongTaiKa', 'hongYuan3Jing', 'hongYuan4Jing', 'hongYuan5Jing', 'hongYuan6Jing', 'heiYuan', 'shiDui'].includes(huType.type)) {
        console.log(`  摸"${char}" -> 特殊胡牌: ${huType.name}`);
        tingCards.push(char);
        foundTing = true;
      } else {
        const basicResult = checkBasicHuCondition(testHandWithDraw, melds);
        if (basicResult && testHuCount >= 11) {
          console.log(`  摸"${char}" -> 普通胡牌: ${huType.name}, 胡数: ${testHuCount}`);
          tingCards.push(char);
          foundTing = true;
        }
      }
    }
  }
  
  if (foundTing) {
    console.log(`>>> 【${player.name}】听牌! 听牌: ${tingCards.join(',')} <<<`);
  } else {
    console.log(`>>> 【${player.name}】不听牌 <<<`);
  }
  console.log('==============================');
  
  return { isTing: foundTing, tingCards };
}

function createCardByCharacter(char) {
  const cardMap = {
    '上': { character: '上', sentence: 1, position: 0, color: 'red' },
    '大': { character: '大', sentence: 1, position: 1, color: 'green' },
    '人': { character: '人', sentence: 1, position: 2, color: 'black' },
    '丘': { character: '丘', sentence: 2, position: 0, color: 'red' },
    '乙': { character: '乙', sentence: 2, position: 1, color: 'green' },
    '己': { character: '己', sentence: 2, position: 2, color: 'black' },
    '化': { character: '化', sentence: 3, position: 0, color: 'red' },
    '三': { character: '三', sentence: 3, position: 1, color: 'green' },
    '千': { character: '千', sentence: 3, position: 2, color: 'black' },
    '七': { character: '七', sentence: 4, position: 0, color: 'red' },
    '十': { character: '十', sentence: 4, position: 1, color: 'green' },
    '土': { character: '土', sentence: 4, position: 2, color: 'black' },
    '尔': { character: '尔', sentence: 5, position: 0, color: 'red' },
    '小': { character: '小', sentence: 5, position: 1, color: 'green' },
    '生': { character: '生', sentence: 5, position: 2, color: 'black' },
    '八': { character: '八', sentence: 6, position: 0, color: 'red' },
    '九': { character: '九', sentence: 6, position: 1, color: 'green' },
    '子': { character: '子', sentence: 6, position: 2, color: 'black' },
    '佳': { character: '佳', sentence: 7, position: 0, color: 'red' },
    '作': { character: '作', sentence: 7, position: 1, color: 'green' },
    '亡': { character: '亡', sentence: 7, position: 2, color: 'black' },
    '福': { character: '福', sentence: 8, position: 0, color: 'red' },
    '禄': { character: '禄', sentence: 8, position: 1, color: 'green' },
    '寿': { character: '寿', sentence: 8, position: 2, color: 'black' }
  };
  
  return cardMap[char] || null;
}

function calculateExpectedHu(hand, melds) {
  const counts = {};
  for (const card of hand) {
    counts[card.character] = (counts[card.character] || 0) + 1;
  }
  
  const usedChars = new Set();
  let sentenceCount = 0;
  let halfKaoList = [];
  
  for (let sentence = 1; sentence <= 8; sentence++) {
    const sentenceCards = hand.filter(c => c.sentence === sentence && !usedChars.has(c.character));
    const positions = new Set(sentenceCards.map(c => c.position));
    
    if (positions.size === 3) {
      sentenceCount++;
      sentenceCards.forEach(c => usedChars.add(c.character));
    } else if (positions.size === 2) {
      halfKaoList.push(sentenceCards);
      sentenceCards.forEach(c => usedChars.add(c.character));
    }
  }
  
  let duiList = [];
  for (const [char, count] of Object.entries(counts)) {
    if (usedChars.has(char)) continue;
    if (count === 2) {
      const card = hand.find(c => c.character === char);
      duiList.push({ char, card });
    }
  }
  
  const leftoverCount = halfKaoList.length + duiList.length;
  
  if (leftoverCount === 2 && halfKaoList.length === 2) {
    for (const halfKao of halfKaoList) {
      const hasDaRen = halfKao.some(c => c.character === '大' || c.character === '人');
      const hasLuShou = halfKao.some(c => c.character === '禄' || c.character === '寿');
      if (hasDaRen || hasLuShou) {
        return 4;
      }
    }
    return 0;
  }
  
  if (leftoverCount === 2 && duiList.length === 2) {
    const hasShangFu = duiList.some(d => d.char === '上' || d.char === '福');
    if (hasShangFu) {
      return 4;
    }
    return 3;
  }
  
  if (leftoverCount === 2 && halfKaoList.length === 1 && duiList.length === 1) {
    const halfKao = halfKaoList[0];
    const hasDaRen = halfKao.some(c => c.character === '大' || c.character === '人');
    const hasFuLu = halfKao.some(c => c.character === '福' || c.character === '禄');
    if (hasDaRen || hasFuLu) {
      return 4;
    }
    
    const dui = duiList[0];
    if (dui.char === '上' || dui.char === '福') {
      return 4;
    }
    return 3;
  }
  
  if (leftoverCount === 0) {
    for (const [char, count] of Object.entries(counts)) {
      if (count === 1) {
        if (['上', '大', '人', '福', '禄', '寿'].includes(char)) {
          return 4;
        }
      }
    }
  }
  
  return 0;
}

function determineHuType(hand, melds, huCount = null) {
  const allCards = [...hand, ...melds.flatMap(m => m.cards)];
  const actualHuCount = huCount !== null ? huCount : calculateHuCount(hand, melds);
  
  const effectiveHasZhao = isZhaoUsedInSentence(hand, melds) ? false : melds.some(m => m.type === 'quartet');
  
  if (checkShiDui(hand)) {
    return { type: 'shiDui', name: '十对' };
  }
  
  const hongYuanJing = checkHongYuan(hand, melds, effectiveHasZhao);
  if (hongYuanJing > 0) {
    return { type: `hongYuan${hongYuanJing}Jing`, name: `红元${hongYuanJing}精` };
  }
  
  if (checkHeiYuan(hand, melds, effectiveHasZhao)) {
    return { type: 'heiYuan', name: '黑元' };
  }
  
  if (actualHuCount < 11) {
    return { type: 'none', name: '无' };
  }
  
  if (checkKuHu(hand, melds, effectiveHasZhao)) {
    return { type: 'kuHu', name: '枯胡' };
  }
  
  if (checkQingKuHu(hand, melds, effectiveHasZhao)) {
    return { type: 'qingKuHu', name: '清枯胡' };
  }
  
  const basicResult = checkBasicHuCondition(hand, melds);
  if (basicResult) {
    return { type: 'basic', name: '基本胡' };
  }
  
  return { type: 'none', name: '无' };
}

function checkQingKuHu(hand, melds, effectiveHasZhao) {
  const hasChi = melds.some(m => m.type === 'sequence');
  const hasPeng = melds.some(m => m.type === 'triplet');
  const hasZhao = melds.some(m => m.type === 'quartet');
  
  if (hasChi || hasPeng || (hasZhao && effectiveHasZhao)) return false;
  
  const allCards = [...hand, ...melds.flatMap(m => m.cards)];
  const shangCount = allCards.filter(c => c.character === '上').length;
  const fuCount = allCards.filter(c => c.character === '福').length;
  
  if (shangCount > 0 || fuCount > 0) return false;
  
  const hasShangDaRen = allCards.some(c => c.sentence === 1);
  const hasFuLuShou = allCards.some(c => c.sentence === 8);
  
  if (hasShangDaRen || hasFuLuShou) return false;
  
  const counts = {};
  for (const card of hand) {
    counts[card.character] = (counts[card.character] || 0) + 1;
  }
  
  let kanCount = 0;
  let duiCount = 0;
  
  for (const count of Object.values(counts)) {
    if (count >= 3) {
      kanCount++;
    } else if (count === 2) {
      duiCount++;
    }
  }
  
  return kanCount >= 4 && duiCount === 1;
}

function addHistory(playerName, cardChar) {
  const historyList = document.getElementById('historyList');
  if (!historyList) return;
  const item = document.createElement('div');
  item.className = 'history-item';
  item.innerHTML = `<span class="player-name">${playerName}</span>: <span class="card-char">${cardChar}</span>`;
  historyList.insertBefore(item, historyList.firstChild);
}

function showMessage(title, content, isLiuJu = false) {
  document.getElementById('messageTitle').textContent = title;
  document.getElementById('messageContent').textContent = content;
  document.getElementById('messageArea').classList.add('show');
  document.getElementById('messageArea').dataset.liuju = isLiuJu;
}

function closeMessage() {
  const messageArea = document.getElementById('messageArea');
  const isLiuJu = messageArea.dataset.liuju === 'true';
  messageArea.classList.remove('show');
  messageArea.dataset.liuju = 'false';
  
  stopCountdown();
  
  gameState.isMyTurn = false;
  gameState.waitingForResponse = false;
  gameState.selectedCardIndex = -1;
  gameState.canHu = false;
  gameState.canZhao = false;
  gameState.canPeng = false;
  gameState.canChi = false;
  
  const container = document.getElementById('actionButtons');
  container.innerHTML = '';
  
  document.getElementById('myHand').innerHTML = '';
  document.getElementById('player1Discard').innerHTML = '';
  document.getElementById('myDiscard').innerHTML = '';
  document.getElementById('player2Discard').innerHTML = '';
  document.getElementById('player1Melds').innerHTML = '';
  document.getElementById('myMelds').innerHTML = '';
  document.getElementById('player2Melds').innerHTML = '';
  document.getElementById('playedCards').innerHTML = '';
  
  document.getElementById('player1HandCount').textContent = '0';
  document.getElementById('myHandCount').textContent = '0';
  document.getElementById('player2HandCount').textContent = '0';
  
  const tingBadge = document.getElementById('tingBadge');
  tingBadge.classList.add('hidden');
  
  const zimoBadge = document.getElementById('zimoBadge');
  zimoBadge.classList.add('hidden');
  
  // 检查是否8局结束
  if (gameState.roundNumber >= 8) {
    showSettlementPage();
    return;
  }
  
  // 流局时庄家不变
  if (isLiuJu) {
    console.log('流局，庄家不变，庄家索引:', gameState.dealerIndex);
    startRound();
  } else {
    // 正常结束，换庄
    gameState.dealerIndex = (gameState.dealerIndex + 1) % 3;
    startRound();
  }
}

function showSettlementPage() {
  const settlementPage = document.getElementById('settlementPage');
  const settlementContent = document.getElementById('settlementContent');
  
  let html = '<div class="settlement-rounds">';
  
  // 每局统计
  for (let i = 0; i < gameState.roundHistory.length; i++) {
    const round = gameState.roundHistory[i];
    html += `<div class="settlement-round">`;
    
    if (round.isLiuJu) {
      html += `<div class="round-header">第${round.roundNumber}局 流局</div>`;
      html += `<div class="round-result liuju">流局</div>`;
    } else {
      html += `<div class="round-header">第${round.roundNumber}局</div>`;
      html += `<div class="round-result">`;
      html += `<div class="winner">赢家: ${round.winner}</div>`;
      html += `<div class="hu-type">${round.huType} ${round.method}</div>`;
      html += `<div class="multiplier">倍数: ${round.multiplier}倍</div>`;
      
      // 计算输家输的总分
      let totalLoserScore = 0;
      if (round.scoreChanges) {
        for (let j = 0; j < gameState.players.length; j++) {
          if (j !== round.winnerIndex) {
            totalLoserScore += Math.abs(round.scoreChanges[j]);
          }
        }
      }
      
      // 验证赢家得分是否等于输家输的总分
      const isScoreValid = round.score === totalLoserScore;
      const validIcon = isScoreValid ? '✓' : '✗';
      const validColor = isScoreValid ? '#4ecdc4' : '#ff6b6b';
      
      html += `<div class="score">得分: ${round.score}分 <span style="color: ${validColor}; font-size: 12px;">(${validIcon} 输家共${totalLoserScore}分)</span></div>`;
      
      // 显示输的玩家信息
      if (round.scoreChanges) {
        html += `<div class="loser-info">`;
        for (let j = 0; j < gameState.players.length; j++) {
          if (j !== round.winnerIndex) {
            const change = round.scoreChanges[j];
            html += `<span class="loser">${gameState.players[j].name}输: ${Math.abs(change)}分</span>`;
          }
        }
        html += `</div>`;
      }
      
      html += `<div class="piao-scores">飘分: 玩家1(${round.piaoScores[0]}) 我(${round.piaoScores[1]}) 玩家2(${round.piaoScores[2]})</div>`;
      html += `</div>`;
    }
    
    html += `</div>`;
  }
  
  html += '</div>';
  
  // 总计
  const totalScores = gameState.players.map(p => p.score);
  const maxScore = Math.max(...totalScores);
  const winners = gameState.players.filter((p, i) => totalScores[i] === maxScore);
  
  // 验证总分之和是否为0
  const totalSum = totalScores.reduce((sum, s) => sum + s, 0);
  const isTotalValid = totalSum === 0;
  const totalValidIcon = isTotalValid ? '✓' : '✗';
  const totalValidColor = isTotalValid ? '#4ecdc4' : '#ff6b6b';
  
  html += '<div class="settlement-total">';
  html += `<div class="total-header">总结算 <span style="color: ${totalValidColor}; font-size: 12px;">(${totalValidIcon} 总分之和=${totalSum})</span></div>`;
  html += '<div class="total-scores">';
  
  for (let i = 0; i < gameState.players.length; i++) {
    const player = gameState.players[i];
    const score = totalScores[i];
    const isWinner = score === maxScore;
    html += `<div class="player-total ${isWinner ? 'winner' : ''}">`;
    html += `<span class="player-name">${player.name}</span>`;
    html += `<span class="player-score">${score >= 0 ? '+' : ''}${score}分</span>`;
    html += `</div>`;
  }
  
  html += '</div>';
  html += `<div class="winner-announce">赢家: ${winners.map(w => w.name).join(', ')}</div>`;
  html += '</div>';
  
  settlementContent.innerHTML = html;
  settlementPage.classList.add('show');
}

function closeSettlement() {
  const settlementPage = document.getElementById('settlementPage');
  settlementPage.classList.remove('show');
  
  // 完全重置游戏状态
  gameState.roundHistory = [];
  gameState.roundNumber = 0;
  gameState.sessionNumber++;
  gameState.deck = [];
  gameState.lastDiscardedCard = null;
  gameState.lastDiscardPlayerIndex = -1;
  gameState.lastDrawnCard = null;
  gameState.selectedCardIndex = -1;
  gameState.isMyTurn = false;
  gameState.waitingForResponse = false;
  gameState.currentPlayerIndex = 0;
  gameState.countdown = 0;
  gameState.dealerIndex = 0;
  gameState.canChi = false;
  gameState.canPeng = false;
  gameState.canZhao = false;
  gameState.canHu = false;
  gameState.skipDraw = false;
  gameState.isDrawing = false;
  
  if (gameState.countdownTimer) {
    clearInterval(gameState.countdownTimer);
    gameState.countdownTimer = null;
  }
  
  // 重置玩家状态
  for (const player of gameState.players) {
    player.score = 0;
    player.piao = 0;
    player.hand = [];
    player.melds = [];
    player.discards = [];
    player.isTing = false;
    player.tingCards = [];
  }
  
  // 更新UI
  updateUI();
  
  // 显示开始屏幕，隐藏游戏容器
  const startScreen = document.getElementById('startScreen');
  const gameContainer = document.querySelector('.game-container');
  const settlementPageEl = document.getElementById('settlementPage');
  
  startScreen.classList.remove('hidden');
  startScreen.style.display = '';
  startScreen.style.visibility = 'visible';
  
  gameContainer.style.display = 'none';
  settlementPageEl.style.display = 'none';
  settlementPageEl.classList.remove('show');
  
  // 更新局数显示
  document.getElementById('roundNum').textContent = '1/8';
  
  console.log('结算页面已关闭，游戏已重置');
}

document.addEventListener('DOMContentLoaded', () => {
  gameState.deck = createDeck();
  updateUI();
  
  initSwipeToClose();
});

function initSwipeToClose() {
  const swipeElements = [
    { id: 'messageArea', closeFn: closeMessage },
    { id: 'settlementPage', closeFn: closeSettlement }
  ];
  
  swipeElements.forEach(({ id, closeFn }) => {
    const element = document.getElementById(id);
    if (!element) return;
    
    let startX = 0;
    let startY = 0;
    let isSwiping = false;
    
    element.addEventListener('touchstart', (e) => {
      startX = e.touches[0].clientX;
      startY = e.touches[0].clientY;
      isSwiping = true;
    }, { passive: true });
    
    element.addEventListener('touchmove', (e) => {
      if (!isSwiping) return;
      
      const currentX = e.touches[0].clientX;
      const currentY = e.touches[0].clientY;
      const diffX = currentX - startX;
      const diffY = currentY - startY;
      
      if (Math.abs(diffX) > Math.abs(diffY) && Math.abs(diffX) > 50) {
        const windowWidth = window.innerWidth;
        const edgeThreshold = 50;
        
        if (startX > windowWidth - edgeThreshold && diffX > 100) {
          isSwiping = false;
          closeFn();
        } else if (startX < edgeThreshold && diffX < -100) {
          isSwiping = false;
          closeFn();
        } else if (currentX < -50 || currentX > windowWidth + 50) {
          isSwiping = false;
          closeFn();
        }
      }
    }, { passive: true });
    
    element.addEventListener('touchend', () => {
      isSwiping = false;
    }, { passive: true });
  });
}

document.addEventListener('contextmenu', (e) => {
  e.preventDefault();
  e.stopPropagation();
  return false;
});

document.addEventListener('selectstart', (e) => {
  e.preventDefault();
  return false;
});

document.addEventListener('dragstart', (e) => {
  e.preventDefault();
  return false;
});

document.addEventListener('touchstart', (e) => {
  if (e.touches.length > 1) {
    e.preventDefault();
  }
}, { passive: false });

document.addEventListener('gesturestart', (e) => {
  e.preventDefault();
});

document.addEventListener('gesturechange', (e) => {
  e.preventDefault();
});

document.addEventListener('gestureend', (e) => {
  e.preventDefault();
});
