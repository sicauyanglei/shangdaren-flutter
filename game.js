// 微信浏览器检测
function isWechatBrowser() {
  const ua = navigator.userAgent.toLowerCase();
  return ua.includes('micromessenger') || ua.includes('wechat');
}

// 应用微信横屏模式
function applyWechatLandscapeMode() {
  if (isWechatBrowser()) {
    const html = document.documentElement;
    const body = document.body;
    
    html.classList.add('wechat-landscape');
    
    // 动态计算并设置尺寸
    function updateSize() {
      const screenWidth = window.screen.width;
      const screenHeight = window.screen.height;
      const innerWidth = window.innerWidth;
      const innerHeight = window.innerHeight;
      
      // 使用屏幕尺寸或窗口尺寸中较大的值
      const width = Math.max(screenWidth, innerWidth, 320);
      const height = Math.max(screenHeight, innerHeight, 480);
      
      // 设置html和body的尺寸
      html.style.width = height + 'px';
      html.style.height = width + 'px';
      body.style.width = height + 'px';
      body.style.height = width + 'px';
    }
    
    updateSize();
    
    // 监听窗口变化
    window.addEventListener('resize', updateSize);
    window.addEventListener('orientationchange', function() {
      setTimeout(updateSize, 100);
    });
    
    // 禁用页面滚动
    document.body.style.overflow = 'hidden';
  }
}

// 移除微信横屏模式
function removeWechatLandscapeMode() {
  document.documentElement.classList.remove('wechat-landscape');
  document.body.style.overflow = '';
}

function showWechatGuide() {
  const guide = document.getElementById('wechatGuide');
  if (guide) {
    guide.style.display = 'flex';
  }
}

function hideWechatGuide() {
  const guide = document.getElementById('wechatGuide');
  if (guide) {
    guide.style.display = 'none';
  }
}

// 横屏检测
function isPortrait() {
  // 优先使用 screen.orientation API
  if (screen.orientation) {
    const type = screen.orientation.type;
    return type === 'portrait-primary' || type === 'portrait-secondary';
  }
  
  // 备选方案1: 使用 screen.width/height (物理屏幕尺寸)
  if (screen.width && screen.height) {
    return screen.height > screen.width;
  }
  
  // 备选方案2: 使用 window.innerWidth/innerHeight
  const ratio = window.devicePixelRatio || 1;
  const width = window.innerWidth * ratio;
  const height = window.innerHeight * ratio;
  return height > width;
}

function checkOrientation() {
  // 横屏提示已禁用
  return;
}

// 强制隐藏横屏提示
function hideRotatePrompt() {
  const rotatePrompt = document.getElementById('rotatePrompt');
  if (rotatePrompt) {
    rotatePrompt.classList.remove('show');
  }
}

// 永久隐藏横屏提示（用户主动关闭）
function hideRotatePromptForever() {
  const rotatePrompt = document.getElementById('rotatePrompt');
  if (rotatePrompt) {
    rotatePrompt.classList.remove('show');
  }
  // 记录用户已关闭提示，本次游戏不再显示
  if (typeof sessionStorage !== 'undefined') {
    sessionStorage.setItem('rotatePromptClosed', 'true');
  }
}

// 检查用户是否已关闭横屏提示
function isRotatePromptClosedByUser() {
  if (typeof sessionStorage !== 'undefined') {
    return sessionStorage.getItem('rotatePromptClosed') === 'true';
  }
  return false;
}

// 页面加载时检测微信并应用横屏模式
if (isWechatBrowser()) {
  document.addEventListener('DOMContentLoaded', function() {
    applyWechatLandscapeMode();
  });
}

// 横屏检测初始化
document.addEventListener('DOMContentLoaded', function() {
  checkOrientation();
  window.addEventListener('resize', checkOrientation);
  window.addEventListener('orientationchange', function() {
    setTimeout(checkOrientation, 100);
  });
});

// 安卓手机音频修复
let audioContext = null;
let audioInitialized = false;
let voicesLoaded = false;

// 日志系统 - 避免控制台日志过多导致页面卡死
const gameLogs = [];
const MAX_LOGS = 5000;
const DEBUG_MODE = !(/Android|webOS|iPhone|iPad|iPod|BlackBerry|IEMobile|Opera Mini/i.test(navigator.userAgent) ||
         (window.innerWidth <= 1024 && 'ontouchstart' in window));

const originalConsoleLog = console.log;
const originalConsoleError = console.error;
const originalConsoleWarn = console.warn;

function addLog(level, ...args) {
  const timestamp = new Date().toISOString();
  const message = args.map(a => {
    if (typeof a === 'object') {
      try {
        return JSON.stringify(a);
      } catch (e) {
        return String(a);
      }
    }
    return String(a);
  }).join(' ');
  
  const logEntry = `[${timestamp}] [${level}] ${message}`;
  
  gameLogs.push(logEntry);
  if (gameLogs.length > MAX_LOGS) {
    gameLogs.shift();
  }
  
  if (DEBUG_MODE || level === 'ERROR') {
    if (level === 'ERROR') {
      originalConsoleError.apply(console, args);
    } else if (level === 'WARN') {
      originalConsoleWarn.apply(console, args);
    } else {
      originalConsoleLog.apply(console, args);
    }
  }
}

console.log = (...args) => addLog('INFO', ...args);
console.error = (...args) => addLog('ERROR', ...args);
console.warn = (...args) => addLog('WARN', ...args);

function exportLogsToFile() {
  const logContent = gameLogs.join('\n');
  // 添加UTF-8 BOM (Byte Order Mark) 帮助Windows正确识别编码
  const BOM = '\uFEFF';
  const blob = new Blob([BOM + logContent], { type: 'text/plain;charset=utf-8' });
  const url = URL.createObjectURL(blob);
  const a = document.createElement('a');
  a.href = url;
  const now = new Date();
  const dateStr = `${now.getFullYear()}${String(now.getMonth() + 1).padStart(2, '0')}${String(now.getDate()).padStart(2, '0')}`;
  const timeStr = `${String(now.getHours()).padStart(2, '0')}${String(now.getMinutes()).padStart(2, '0')}${String(now.getSeconds()).padStart(2, '0')}`;
  a.download = `report_${dateStr}_${timeStr}.log`;
  document.body.appendChild(a);
  a.click();
  document.body.removeChild(a);
  URL.revokeObjectURL(url);
  console.log('日志已导出到文件');
}

function clearLogs() {
  gameLogs.length = 0;
  console.log('日志已清除');
}

function getLogCount() {
  return gameLogs.length;
}

// 系统设置
let gameSettings = {
  volume: 1.0,
  difficulty: 'hard',
  piaoEnabled: false
};

// 测试音效函数 - 在控制台输入 testAudio('化') 或 testAudio('八') 来测试
function testAudio(text) {
  speakText(text, 1); // 使用玩家1（我）的声音类型
  return `正在播放: ${text}`;
}

// 通用滑动关闭功能
function setupSwipeToClose(element, onCloseCallback) {
  if (!element) return;
  
  let startX = 0;
  let startY = 0;
  let currentX = 0;
  let isDragging = false;
  
  const threshold = window.innerWidth * 0.3;
  
  // 定义事件处理函数
  const touchstartHandler = (e) => {
    startX = e.touches[0].clientX;
    startY = e.touches[0].clientY;
    isDragging = true;
    element.style.transition = 'none';
  };
  
  const touchmoveHandler = (e) => {
    if (!isDragging) return;
    currentX = e.touches[0].clientX;
    const deltaX = currentX - startX;
    const deltaY = Math.abs(e.touches[0].clientY - startY);
    
    if (deltaY < Math.abs(deltaX) && Math.abs(deltaX) > 10) {
      element.style.transform = `translateX(${deltaX}px)`;
      element.style.opacity = 1 - Math.abs(deltaX) / (window.innerWidth * 0.5);
    }
  };
  
  const touchendHandler = (e) => {
    if (!isDragging) return;
    isDragging = false;
    
    const deltaX = currentX - startX;
    element.style.transition = 'transform 0.3s ease, opacity 0.3s ease';
    
    if (Math.abs(deltaX) > threshold) {
      element.style.transform = `translateX(${deltaX > 0 ? window.innerWidth : -window.innerWidth}px)`;
      element.style.opacity = '0';
      setTimeout(() => {
        element.style.transform = '';
        element.style.opacity = '';
        if (onCloseCallback) onCloseCallback();
      }, 300);
    } else {
      element.style.transform = '';
      element.style.opacity = '';
    }
  };
  
  const mousedownHandler = (e) => {
    startX = e.clientX;
    startY = e.clientY;
    isDragging = true;
    element.style.transition = 'none';
  };
  
  const mousemoveHandler = (e) => {
    if (!isDragging) return;
    currentX = e.clientX;
    const deltaX = currentX - startX;
    const deltaY = Math.abs(e.clientY - startY);
    
    if (deltaY < Math.abs(deltaX) && Math.abs(deltaX) > 10) {
      element.style.transform = `translateX(${deltaX}px)`;
      element.style.opacity = 1 - Math.abs(deltaX) / (window.innerWidth * 0.5);
    }
  };
  
  const mouseupHandler = (e) => {
    if (!isDragging) return;
    isDragging = false;
    
    const deltaX = currentX - startX;
    element.style.transition = 'transform 0.3s ease, opacity 0.3s ease';
    
    if (Math.abs(deltaX) > threshold) {
      element.style.transform = `translateX(${deltaX > 0 ? window.innerWidth : -window.innerWidth}px)`;
      element.style.opacity = '0';
      setTimeout(() => {
        element.style.transform = '';
        element.style.opacity = '';
        if (onCloseCallback) onCloseCallback();
      }, 300);
    } else {
      element.style.transform = '';
      element.style.opacity = '';
    }
  };
  
  const mouseleaveHandler = () => {
    if (isDragging) {
      isDragging = false;
      element.style.transition = 'transform 0.3s ease, opacity 0.3s ease';
      element.style.transform = '';
      element.style.opacity = '';
    }
  };
  
  // 保存事件处理函数的引用
  element._swipeHandler = {
    touchstart: touchstartHandler,
    touchmove: touchmoveHandler,
    touchend: touchendHandler,
    mousedown: mousedownHandler,
    mousemove: mousemoveHandler,
    mouseup: mouseupHandler,
    mouseleave: mouseleaveHandler
  };
  
  // 添加事件监听器
  element.addEventListener('touchstart', touchstartHandler, { passive: true });
  element.addEventListener('touchmove', touchmoveHandler, { passive: true });
  element.addEventListener('touchend', touchendHandler, { passive: true });
  element.addEventListener('mousedown', mousedownHandler);
  element.addEventListener('mousemove', mousemoveHandler);
  element.addEventListener('mouseup', mouseupHandler);
  element.addEventListener('mouseleave', mouseleaveHandler);
}

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
      // 不立即启动，等待用户交互后恢复
    }
  } catch (e) {
    console.warn('AudioContext创建延迟，将在用户交互后初始化');
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
    } catch (e) {
      console.error('AudioContext恢复失败:', e);
    }
  }
}

// 播放语音（使用本地音频文件）
async function speakText(text, playerIndex = -1) {
  if (!audioContext) {
    initAudioContext();
  }
  await resumeAudioContext();
  
  const huTypes = ['枯胡', '清枯胡', '枯台胡', '枯重台卡', '枯重台胡', '清枯台卡', '清枯台胡', '清枯重台卡', '清枯重台胡', '十对', '黑元', '红元', '红元3精', '红元4精', '红元5精', '红元6精', '清胡', '清卡胡', '卡胡', '普通胡', '台卡', '台胡', '重台卡', '重台胡'];
  const isHuType = huTypes.includes(text);
  const volumeMultiplier = isHuType ? 1.5 : 1.0;
  
  await playLocalAudio(text, playerIndex, volumeMultiplier);
}

// 音频文件映射
const audioFileMap = {
  // 游戏操作
  '吃': 'chi', '碰': 'peng', '招': 'zhao', '胡': 'hu', '自摸': 'zimo', '出牌': 'chupai', '过': 'guo',
  '快点吧': 'kuaidianba', '流局': 'liuju',
  
  // 胡牌类型
  '枯胡': 'kuhu', '清枯胡': 'qingkuhu', 
  '枯台胡': 'kutaihu', '枯重台卡': 'kuchongtaika', '枯重台胡': 'kuchongtaihu',
  '清枯台卡': 'qingkutaika', '清枯台胡': 'qingkutaihu',
  '清枯重台卡': 'qingkuchongtaika', '清枯重台胡': 'qingkuchongtaihu',
  '十对': 'shidui', '黑元': 'heiyuan', 
  '红元': 'hongyuan', '红元3精': 'hongyuan3jing', '红元4精': 'hongyuan4jing', 
  '红元5精': 'hongyuan5jing', '红元6精': 'hongyuan6jing',
  '清胡': 'qinghu', '清卡胡': 'qingkahu',
  '卡胡': 'kahu', '普通胡': 'putonghu', 
  '台卡': 'taika', '台胡': 'taihu',
  '重台卡': 'chongtaika', '重台胡': 'chongtaihu',
  
  // 24个字牌
  '上': 'shang', '大': 'da', '人': 'ren', '丘': 'qiu', '乙': 'yi', '己': 'ji',
  '化': 'hua', '三': 'san', '千': 'qian', '七': 'qi', '十': 'shi', '土': 'tu',
  '尔': 'er', '小': 'xiao', '生': 'sheng', '八': 'ba', '九': 'jiu', '子': 'zi',
  '佳': 'jia', '作': 'zuo', '亡': 'wang', '福': 'fu', '禄': 'lu', '寿': 'shou'
};

// 音频缓存
const audioPreloaded = new Map();

function preloadAudioFiles() {
  const voiceTypes = ['male', 'female'];
  for (const [text, fileName] of Object.entries(audioFileMap)) {
    for (const voiceType of voiceTypes) {
      const audioKey = `${voiceType}/${fileName}`;
      const audioPath = `audio/${audioKey}.mp3`;
      const audio = new Audio(audioPath);
      audio.preload = 'auto';
      audio.load();
      audioPreloaded.set(audioKey, audio);
    }
  }
}

async function playLocalAudio(text, playerIndex = -1, volumeMultiplier = 1.0) {
  const fileName = audioFileMap[text];
  if (!fileName) return;
  
  let voiceType = 'male';
  const idx = playerIndex >= 0 ? playerIndex : gameState.currentPlayerIndex;
  if (idx >= 0 && gameState.players[idx]) {
    voiceType = gameState.players[idx].voiceType || 'male';
  }
  
  const audioKey = `${voiceType}/${fileName}`;
  const audioPath = `audio/${audioKey}.mp3`;
  
  return new Promise((resolve) => {
    const audio = new Audio(audioPath);
    audio.volume = Math.min(gameSettings.volume * volumeMultiplier, 1.0);
    
    let hasResolved = false;
    
    const safeResolve = () => {
      if (!hasResolved) {
        hasResolved = true;
        resolve();
      }
    };
    
    const timeout = setTimeout(() => {
      safeResolve();
    }, 3000);
    
    audio.onended = () => {
      clearTimeout(timeout);
      safeResolve();
    };
    
    audio.onerror = () => {
      clearTimeout(timeout);
      safeResolve();
    };
    
    audio.play().then(() => {
    }).catch(() => {
      clearTimeout(timeout);
      const preloaded = audioPreloaded.get(audioKey);
      if (preloaded) {
        preloaded.currentTime = 0;
        preloaded.volume = Math.min(gameSettings.volume * volumeMultiplier, 1.0);
        preloaded.onended = () => { clearTimeout(timeout); safeResolve(); };
        preloaded.onerror = () => { clearTimeout(timeout); safeResolve(); };
        preloaded.play().catch(() => safeResolve());
      } else {
        safeResolve();
      }
    });
  });
}

// 使用SpeechSynthesis作为备用
async function playWithSpeechSynthesis(text) {
  if (!('speechSynthesis' in window)) {
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
      console.log('使用语音:', zhVoice.name);
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

// 播放倒计时滴答音效
// level: 0=正常, 1=警告(6-10秒), 2=紧急(<=5秒)
function playTickSound(level = 0) {
  if (!audioContext) {
    initAudioContext();
  }
  
  try {
    if (audioContext.state === 'suspended') {
      audioContext.resume();
    }
    
    const oscillator = audioContext.createOscillator();
    const gainNode = audioContext.createGain();
    
    oscillator.connect(gainNode);
    gainNode.connect(audioContext.destination);
    
    if (level === 2) {
      // 紧急（<=5秒）：最高频率，方波，最急促
      oscillator.frequency.value = 1047; // C6
      oscillator.type = 'square';
      gainNode.gain.setValueAtTime(gameSettings.volume * 0.35, audioContext.currentTime);
      gainNode.gain.exponentialRampToValueAtTime(0.01, audioContext.currentTime + 0.1);
      oscillator.start(audioContext.currentTime);
      oscillator.stop(audioContext.currentTime + 0.1);
    } else if (level === 1) {
      // 警告（6-10秒）：较高频率，方波
      oscillator.frequency.value = 880; // A5
      oscillator.type = 'square';
      gainNode.gain.setValueAtTime(gameSettings.volume * 0.3, audioContext.currentTime);
      gainNode.gain.exponentialRampToValueAtTime(0.01, audioContext.currentTime + 0.15);
      oscillator.start(audioContext.currentTime);
      oscillator.stop(audioContext.currentTime + 0.15);
    } else {
      // 正常（>10秒）：柔和滴答声
      oscillator.frequency.value = 523; // C5
      oscillator.type = 'sine';
      gainNode.gain.setValueAtTime(gameSettings.volume * 0.15, audioContext.currentTime);
      gainNode.gain.exponentialRampToValueAtTime(0.01, audioContext.currentTime + 0.08);
      oscillator.start(audioContext.currentTime);
      oscillator.stop(audioContext.currentTime + 0.08);
    }
  } catch (e) {
    console.error('播放滴答音效失败:', e);
  }
}

async function playButtonSound(text, playerIndex = -1) {
  await speakText(text, playerIndex);
}

// 初始化音频系统（在用户交互时调用）
async function initAudioOnUserInteraction() {
  if (audioInitialized) return;
  audioInitialized = true;
  
  console.log('initAudioOnUserInteraction called');
  
  initSpeechSynthesis();
  
  initAudioContext();
  await resumeAudioContext();
  
  preloadAudioFiles();
  
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

function isMobileDevice() {
  return /Android|webOS|iPhone|iPad|iPod|BlackBerry|IEMobile|Opera Mini/i.test(navigator.userAgent) ||
         (window.innerWidth <= 1024 && 'ontouchstart' in window);
}

document.addEventListener('DOMContentLoaded', () => {
  initSpeechSynthesis();
  initAudioContext();
});

async function lockScreenOrientation() {
  if (!isMobileDevice()) {
    return;
  }
  try {
    if (screen.orientation && screen.orientation.lock) {
      await screen.orientation.lock('landscape');
      audioInitialized = false;
      initAudioOnUserInteraction();
    }
  } catch (err) {
  }
}

document.addEventListener('DOMContentLoaded', () => {
  lockScreenOrientation();
});

if (screen.orientation && isMobileDevice()) {
  screen.orientation.addEventListener('change', () => {
    console.log('屏幕方向变化:', screen.orientation.type);
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
  const startScreen = document.getElementById('startScreen');
  const isGameActive = startScreen && startScreen.classList.contains('hidden');
  
  if (document.visibilityState === 'hidden') {
    // 应用切走，暂停游戏
    if (isGameActive && !gameState.isPaused) {
      pauseGame();
    }
  } else if (document.visibilityState === 'visible') {
    // 应用切回，恢复游戏
    await requestWakeLock();
    
    if (isGameActive && gameState.isPaused) {
      resumeGame();
    }
    
    if (!isMobileDevice()) {
      return;
    }
    
    const isStartScreenVisible = startScreen && !startScreen.classList.contains('hidden');
    
    if (isGameActive || isStartScreenVisible) {
      console.log('切回游戏页面，重新进入全屏模式');
      try {
        const docEl = document.documentElement;
        
        if (!document.fullscreenElement && !document.webkitFullscreenElement && 
            !document.mozFullScreenElement && !document.msFullscreenElement) {
          if (docEl.requestFullscreen) {
            await docEl.requestFullscreen();
          } else if (docEl.webkitRequestFullscreen) {
            await docEl.webkitRequestFullscreen();
          } else if (docEl.mozRequestFullScreen) {
            await docEl.mozRequestFullScreen();
          } else if (docEl.msRequestFullscreen) {
            await docEl.msRequestFullscreen();
          }
          console.log('已重新进入全屏模式');
        }
      } catch (err) {
        console.log('重新进入全屏失败:', err);
      }
    }
  }
});

// 暂停游戏
function pauseGame() {
  if (gameState.isPaused) return;
  
  console.log('游戏已暂停');
  gameState.isPaused = true;
  
  // 保存并暂停出牌倒计时
  if (gameState.countdownTimer) {
    gameState.pausedCountdown = gameState.countdown;
    clearInterval(gameState.countdownTimer);
    gameState.countdownTimer = null;
  }
  
  // 保存并暂停飘分倒计时
  if (piaoCountdownTimer) {
    gameState.pausedPiaoCountdown = piaoCountdown;
    gameState.pausedPiaoPlayerIndex = currentPiaoPlayerIndex;
    gameState.isPiaoPhase = true;
    clearInterval(piaoCountdownTimer);
    piaoCountdownTimer = null;
  }
  
  // 显示暂停提示
  showPauseOverlay();
}

// 恢复游戏
function resumeGame() {
  if (!gameState.isPaused) return;
  
  console.log('游戏已恢复');
  gameState.isPaused = false;
  
  // 隐藏暂停提示
  hidePauseOverlay();
  
  // 恢复飘分倒计时（优先处理飘分阶段）
  if (gameState.isPiaoPhase && gameState.pausedPiaoCountdown > 0) {
    const savedPiaoPlayerIndex = gameState.pausedPiaoPlayerIndex;
    piaoCountdown = gameState.pausedPiaoCountdown;
    
    // 重新显示飘分弹窗
    const playerIds = ['player1', 'my', 'player2'];
    const playerId = playerIds[savedPiaoPlayerIndex];
    const piaoPopup = document.getElementById(`${playerId}PiaoPopup`);
    if (piaoPopup) {
      piaoPopup.classList.remove('hidden');
    }
    
    // 重新显示倒计时
    showPiaoCountdownTimer(savedPiaoPlayerIndex);
    updatePiaoCountdownDisplay(savedPiaoPlayerIndex, piaoCountdown);
    
    piaoCountdownTimer = setInterval(() => {
      piaoCountdown--;
      updatePiaoCountdownDisplay(savedPiaoPlayerIndex, piaoCountdown);
      
      if (piaoCountdown <= 3 && piaoCountdown > 0) {
        playTickSound(2);
      } else if (piaoCountdown > 3) {
        playTickSound(1);
      }
      
      if (piaoCountdown <= 0) {
        clearInterval(piaoCountdownTimer);
        piaoCountdownTimer = null;
        setPiao(0);
      }
    }, 1000);
    
    gameState.isPiaoPhase = false;
    gameState.pausedPiaoCountdown = 0;
    gameState.pausedPiaoPlayerIndex = -1;
    return; // 飘分阶段不恢复出牌倒计时
  }
  
  // 恢复出牌倒计时
  if (gameState.pausedCountdown > 0) {
    // 确保先清除现有的定时器
    if (gameState.countdownTimer) {
      clearInterval(gameState.countdownTimer);
      gameState.countdownTimer = null;
    }
    gameState.countdown = gameState.pausedCountdown;
    gameState.countdownTimer = setInterval(() => {
      gameState.countdown--;
      updateCountdownUI();
      
      if (gameState.countdown === 10 && gameState.isMyTurn && !gameState.testMode) {
        speakText('快点吧');
      } else if (gameState.countdown <= 5 && gameState.countdown > 0) {
        playTickSound(2);
      } else if (gameState.countdown > 5 && gameState.countdown < 10) {
        playTickSound(1);
      } else if (gameState.countdown > 10) {
        playTickSound(0);
      }
      
      if (gameState.countdown <= 0) {
        handleTimeout();
      }
    }, 1000);
    updateCountdownUI();
  }
  
  // 如果当前是AI的回合且没有在等待响应，继续AI操作
  const currentPlayer = gameState.players[gameState.currentPlayerIndex];
  if (currentPlayer && currentPlayer.type === 'ai' && !gameState.waitingForResponse && !gameState.isHandlingHu && !gameState.isDealing) {
    setTimeout(() => {
      if (!gameState.isPaused && !gameState.isHandlingHu && !gameState.isDealing) {
        processAITurn();
      }
    }, 500);
  }
}

// 显示暂停遮罩
function showPauseOverlay() {
  let overlay = document.getElementById('pauseOverlay');
  if (!overlay) {
    overlay = document.createElement('div');
    overlay.id = 'pauseOverlay';
    overlay.style.cssText = `
      position: fixed;
      top: 0;
      left: 0;
      width: 100%;
      height: 100%;
      background: rgba(0, 0, 0, 0.8);
      display: flex;
      flex-direction: column;
      align-items: center;
      justify-content: center;
      z-index: 9999;
      color: #fff;
      font-size: 2rem;
      font-weight: bold;
    `;
    overlay.innerHTML = `
      <div style="font-size: 3rem; margin-bottom: 1rem;">⏸️</div>
      <div>游戏已暂停</div>
      <div style="font-size: 1rem; margin-top: 1rem; opacity: 0.7;">点击屏幕继续游戏</div>
    `;
    overlay.addEventListener('click', resumeGame);
    document.body.appendChild(overlay);
  } else {
    overlay.style.display = 'flex';
  }
}

// 隐藏暂停遮罩
function hidePauseOverlay() {
  const overlay = document.getElementById('pauseOverlay');
  if (overlay) {
    overlay.style.display = 'none';
  }
}

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

// 获取玩家区域位置（适配微信横屏模式）
function getPlayerPosition(playerIndex) {
  const isWechatLandscape = document.documentElement.classList.contains('wechat-landscape');
  
  // 微信横屏模式：CSS旋转后，坐标系需要交换
  // 视觉宽度 = window.innerHeight, 视觉高度 = window.innerWidth
  if (isWechatLandscape) {
    const visualW = window.innerHeight;
    const visualH = window.innerWidth;
    const centerX = visualW / 2;
    const centerY = visualH / 2;
    
    // 旋转后玩家位置映射：
    // player0(原左边) -> 上边, player1(原下边) -> 右边, player2(原右边) -> 下边
    // 但由于是fixed定位+旋转，需要用原始坐标系
    if (playerIndex === 0) {
      // 原左边玩家 -> 旋转后视觉上边，但fixed坐标还是原左边位置
      return { x: 30, y: centerY - 50 };
    } else if (playerIndex === 1) {
      // 原下边玩家 -> 旋转后视觉右边
      return { x: centerX - 20, y: window.innerHeight - 100 };
    } else {
      // 原右边玩家 -> 旋转后视觉下边
      return { x: window.innerWidth - 60, y: centerY - 50 };
    }
  }
  
  // 正常模式
  const w = window.innerWidth;
  const h = window.innerHeight;
  const centerX = w / 2;
  const centerY = h / 2;
  
  if (playerIndex === 0) {
    return { x: 60, y: centerY - 73 };
  } else if (playerIndex === 1) {
    return { x: centerX - 17, y: h - 180 };
  } else {
    return { x: w - 95, y: centerY - 73 };
  }
}

// 获取牌堆位置
function getDeckPosition() {
  const deckStack = document.getElementById('deckStack');
  if (deckStack) {
    const rect = deckStack.getBoundingClientRect();
    return { x: rect.left + rect.width / 2 - 17, y: rect.top };
  }
  const isWechatLandscape = document.documentElement.classList.contains('wechat-landscape');
  if (isWechatLandscape) {
    return { x: window.innerHeight * 0.15, y: window.innerWidth * 0.1 };
  }
  return { x: window.innerWidth / 2, y: window.innerHeight / 2 };
}

// 获取中央位置
function getCenterPosition() {
  const isWechatLandscape = document.documentElement.classList.contains('wechat-landscape');
  if (isWechatLandscape) {
    return { x: window.innerHeight / 2 - 17, y: window.innerWidth / 2 - 73 };
  }
  return { x: window.innerWidth / 2 - 17, y: window.innerHeight / 2 - 73 };
}

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
  lastDrawnPlayerIndex: -1,
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
  hasDealerPlayedFirstTurn: false,
  isDealing: false,
  baseScore: 5,
  multiplierBase: 2,
  playerVoices: ['female', 'male', 'female'],
  roundHistory: [],
  testMode: false,
  isPaused: false,
  pausedCountdown: 0,
  pausedPiaoCountdown: 0,
  pausedPiaoPlayerIndex: -1,
  isPiaoPhase: false,
  gameStarted: false
};

function startTestMode() {
  gameState.testMode = true;
  console.log('=== 测试模式已启用 ===');
  console.log('- 人类玩家超时2秒自动出牌');
  console.log('- 胡牌/流局页面自动2秒后关闭');
  console.log('- 第8局结算页面可导出日志');
  startGame();
}

function stopTestMode() {
  gameState.testMode = false;
  console.log('=== 测试模式已关闭 ===');
}

function selectOption(type, value) {
  if (type === 'difficulty') {
    gameSettings.difficulty = value;
    localStorage.setItem('gameDifficulty', value);
  } else if (type === 'piaoEnabled') {
    gameSettings.piaoEnabled = value;
    localStorage.setItem('piaoEnabled', String(value));
  } else {
    gameState[type] = value;
  }
  
  const buttonsContainer = document.getElementById(`${type}Buttons`);
  if (buttonsContainer) {
    const buttons = buttonsContainer.querySelectorAll('.option-btn');
    buttons.forEach(btn => {
      const btnValue = btn.dataset.value;
      let isSelected = false;
      if (type === 'piaoEnabled') {
        isSelected = btnValue === String(value);
      } else if (btnValue === String(value) || btnValue === value) {
        isSelected = true;
      }
      btn.classList.toggle('selected', isSelected);
    });
  }
  
  console.log(`设置已更新: ${type} = ${value}`);
}

function loadGameSettings() {
  const savedDifficulty = localStorage.getItem('gameDifficulty');
  if (savedDifficulty && ['easy', 'medium', 'hard'].includes(savedDifficulty)) {
    gameSettings.difficulty = savedDifficulty;
  }
  
  const savedPiaoEnabled = localStorage.getItem('piaoEnabled');
  if (savedPiaoEnabled !== null) {
    gameSettings.piaoEnabled = savedPiaoEnabled === 'true';
  }
  
  console.log('加载游戏设置:', gameSettings);
  
  updateSettingsUI();
}

function updateSettingsUI() {
  const difficultyButtons = document.getElementById('difficultyButtons');
  if (difficultyButtons) {
    const buttons = difficultyButtons.querySelectorAll('.option-btn');
    buttons.forEach(btn => {
      btn.classList.toggle('selected', btn.dataset.value === gameSettings.difficulty);
    });
  }
  
  const piaoEnabledButtons = document.getElementById('piaoEnabledButtons');
  if (piaoEnabledButtons) {
    const buttons = piaoEnabledButtons.querySelectorAll('.option-btn');
    buttons.forEach(btn => {
      btn.classList.toggle('selected', btn.dataset.value === String(gameSettings.piaoEnabled));
    });
  }
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
  if (!isMobileDevice()) {
    console.log('Windows设备，跳过全屏功能');
    initAudioOnUserInteraction();
    return true;
  }
  
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
    
    initAudioOnUserInteraction();
    
    await new Promise(resolve => setTimeout(resolve, 100));
    
    if (screen.orientation && screen.orientation.lock) {
      try {
        await screen.orientation.lock('landscape');
        initAudioOnUserInteraction();
      } catch (e) {
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
  
  gameState.gameStarted = true;
  checkOrientation();
  
  enterFullscreenAndLockOrientation().catch(err => {
    console.log('全屏或锁定方向失败:', err);
  });
  
  startRound();
}

function startTestFromRound8() {
  console.log('=== 开始测试第8局 ===');
  initAudioContext();
  
  const startScreen = document.getElementById('startScreen');
  const gameContainer = document.querySelector('.game-container');
  
  startScreen.classList.add('hidden');
  startScreen.style.display = 'none';
  
  gameContainer.style.display = '';
  
  gameState.gameStarted = true;
  checkOrientation();
  
  enterFullscreenAndLockOrientation().catch(err => {
    console.log('全屏或锁定方向失败:', err);
  });
  
  // 初始化玩家
  gameState.players = [
    { name: '玩家1', type: 'ai', hand: [], discards: [], melds: [], score: 0, piao: 0, voiceType: 'female', isTing: false },
    { name: '我', type: 'human', hand: [], discards: [], melds: [], score: 0, piao: 0, voiceType: 'female', isTing: false },
    { name: '玩家2', type: 'ai', hand: [], discards: [], melds: [], score: 0, piao: 0, voiceType: 'male', isTing: false }
  ];
  
  // 设置 roundNumber 为 7，这样 startRound 会递增到 8
  gameState.roundNumber = 7;
  
  // 模拟前7局的记录
  gameState.roundHistory = [
    { roundNumber: 1, winner: '玩家1', winnerIndex: 0, huType: '台卡', method: '点炮', multiplier: 1, score: 10, piaoScores: [0, 5, 0], isLiuJu: false, scoreChanges: [10, -15, 5] },
    { roundNumber: 2, winner: '我', winnerIndex: 1, huType: '普通胡', method: '自摸', multiplier: 2, score: 20, piaoScores: [0, 5, 0], isLiuJu: false, scoreChanges: [-10, 20, -10] },
    { roundNumber: 3, winner: null, winnerIndex: -1, huType: null, method: null, multiplier: 0, score: 0, piaoScores: [0, 0, 0], isLiuJu: true, scoreChanges: [0, 0, 0] },
    { roundNumber: 4, winner: '玩家2', winnerIndex: 2, huType: '台胡', method: '点炮', multiplier: 2, score: 15, piaoScores: [0, 0, 5], isLiuJu: false, scoreChanges: [5, -20, 15] },
    { roundNumber: 5, winner: '玩家1', winnerIndex: 0, huType: '清枯胡', method: '自摸', multiplier: 4, score: 30, piaoScores: [5, 0, 0], isLiuJu: false, scoreChanges: [30, -15, -15] },
    { roundNumber: 6, winner: '我', winnerIndex: 1, huType: '枯台胡', method: '点炮', multiplier: 3, score: 25, piaoScores: [0, 5, 0], isLiuJu: false, scoreChanges: [-25, 25, 0] },
    { roundNumber: 7, winner: '玩家2', winnerIndex: 2, huType: '重台卡', method: '自摸', multiplier: 3, score: 20, piaoScores: [0, 0, 5], isLiuJu: false, scoreChanges: [-10, -10, 20] }
  ];
  
  // 设置分数
  gameState.players[0].score = 0;
  gameState.players[1].score = -15;
  gameState.players[2].score = 15;
  
  console.log('模拟前7局记录完成');
  console.log('roundHistory:', JSON.stringify(gameState.roundHistory));
  console.log('玩家分数:', gameState.players.map(p => ({ name: p.name, score: p.score })));
  
  // 开始第8局
  startRound();
}

let piaoCountdown = 10;
let piaoCountdownTimer = null;
let currentPiaoPlayerIndex = 0;
let piaoSetCount = 0;

function showPiaoScreen() {
  console.log('====== showPiaoScreen 开始 ======');
  console.log('庄家索引:', gameState.dealerIndex);
  console.log('飘分设置开关:', gameSettings.piaoEnabled);
  
  if (!gameSettings.piaoEnabled) {
    console.log('飘分设置已关闭，所有玩家飘分设为0，直接开始发牌');
    for (const player of gameState.players) {
      player.piao = 0;
    }
    startDealingAnimation();
    return;
  }
  
  console.log('重置 piaoSetCount 为 0');
  currentPiaoPlayerIndex = gameState.dealerIndex;
  piaoSetCount = 0;
  
  console.log('开始显示第一个玩家的飘分页面');
  showPlayerPiaoScreen();
}

function showPlayerPiaoScreen() {
  console.log('====== showPlayerPiaoScreen 开始 ======');
  console.log('currentPiaoPlayerIndex:', currentPiaoPlayerIndex);
  console.log('piaoSetCount:', piaoSetCount);
  
  // 先隐藏所有飘分弹窗，确保只有一个弹窗显示
  document.querySelectorAll('.piao-setting-popup').forEach(el => {
    el.classList.add('hidden');
  });
  
  const player = gameState.players[currentPiaoPlayerIndex];
  console.log('当前玩家:', player.name, '类型:', player.type);

  const playerIds = ['player1', 'my', 'player2'];
  const playerId = playerIds[currentPiaoPlayerIndex];
  
  const piaoPopup = document.getElementById(`${playerId}PiaoPopup`);
  
  if (!piaoPopup) {
    console.log('错误: 找不到飘分弹窗, playerId:', playerId);
    return;
  }
  
  piaoPopup.classList.remove('hidden');
  console.log('显示飘分弹窗:', playerId);
  
  showPiaoCountdownTimer(currentPiaoPlayerIndex);
  
  if (player.type === 'ai') {
    console.log('AI玩家设置飘分, 索引:', currentPiaoPlayerIndex);
    setTimeout(() => {
      const piaoOptions = [0, 5, 10, 20];
      const randomIndex = Math.floor(Math.random() * piaoOptions.length);
      const piao = piaoOptions[randomIndex];
      player.piao = piao;
      piaoSetCount++; // 增加已设置飘分的玩家计数
      console.log('AI玩家飘分设置完成, piao:', piao, 'piaoSetCount:', piaoSetCount);
      updatePlayerPiaoBadge(currentPiaoPlayerIndex);
      hidePiaoCountdownTimer(currentPiaoPlayerIndex);
      setTimeout(() => {
        piaoPopup.classList.add('hidden');
        moveToNextPiaoPlayer();
      }, 500);
    }, 800);
  } else {
    console.log('Showing piao options for human player');
    console.log('测试模式:', gameState.testMode);
    piaoCountdown = gameState.testMode ? 1 : 10;
    console.log('倒计时初始值:', piaoCountdown);
    
    if (piaoCountdownTimer) {
      console.log('清除旧的倒计时定时器');
      clearInterval(piaoCountdownTimer);
    }
    
    console.log('开始倒计时, 每秒减少1');
    piaoCountdownTimer = setInterval(() => {
      piaoCountdown--;
      console.log('飘分倒计时:', piaoCountdown);
      updatePiaoCountdownDisplay(currentPiaoPlayerIndex, piaoCountdown);
      
      // 播放滴答音效（飘分倒计时较短，使用警告和紧急级别）
      if (piaoCountdown <= 3 && piaoCountdown > 0) {
        playTickSound(2); // 紧急
      } else if (piaoCountdown > 3) {
        playTickSound(1); // 警告
      }
      
      if (piaoCountdown <= 0) {
        console.log('倒计时结束，自动设置飘分为0');
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
  const player = gameState.players[playerIndex];
  const playerIds = ['player1', 'my', 'player2'];
  const playerId = playerIds[playerIndex];
  
  const piaoBadge = document.getElementById(`${playerId}Piao`);
  
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
  }
}

function updatePiaoCountdown() {
  const countdownEl = document.getElementById('piaoCountdown');
  if (countdownEl) {
    countdownEl.textContent = piaoCountdown > 0 ? `${piaoCountdown}秒` : '';
  }
}

function setPiao(piao) {
  console.log('====== setPiao 被调用 ======');
  console.log('设置飘分:', piao);
  console.log('currentPiaoPlayerIndex:', currentPiaoPlayerIndex);
  console.log('调用时 piaoSetCount:', piaoSetCount);
  
  const player = gameState.players[currentPiaoPlayerIndex];
  
  // 防止同一玩家重复设置飘分
  if (player.piao !== undefined && player.piao !== null) {
    console.log('警告: 该玩家已设置飘分，跳过重复调用');
    return;
  }
  
  if (piaoCountdownTimer) {
    console.log('清除倒计时定时器');
    clearInterval(piaoCountdownTimer);
    piaoCountdownTimer = null;
  }
  
  hidePiaoCountdownTimer(currentPiaoPlayerIndex);
  
  player.piao = piao;
  piaoSetCount++; // 增加已设置飘分的玩家计数
  console.log('设置后 piaoSetCount:', piaoSetCount);
  
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
  console.log('====== moveToNextPiaoPlayer ======');
  console.log('当前 piaoSetCount:', piaoSetCount);
  
  // 检查是否所有玩家都设置了飘分
  if (piaoSetCount >= 3) {
    console.log('所有玩家已设置飘分，开始发牌动画');
    startDealingAnimation();
    return;
  }
  
  currentPiaoPlayerIndex = (currentPiaoPlayerIndex + 1) % 3;
  console.log('下一个玩家索引:', currentPiaoPlayerIndex);
  showPlayerPiaoScreen();
}

function startRound() {
  
  // 防止重复调用
  if (gameState.isStartingRound) {
    console.log('警告: startRound 已经在执行中，跳过重复调用');
    return;
  }
  gameState.isStartingRound = true;
  
  // 重置胡牌处理标志
  gameState.isHandlingHu = false;
  
  // 重置流局处理标志
  gameState.isLiuJuHandled = false;
  
  // 重置消息关闭标志
  gameState.isClosingMessage = false;
  
  // 清除飘分倒计时定时器，防止竞态问题
  if (piaoCountdownTimer) {
    clearInterval(piaoCountdownTimer);
    piaoCountdownTimer = null;
  }
  
  gameState.roundNumber++;
  
  // 检查是否已经完成8局（在递增后检查）
  if (gameState.roundNumber > 8) {
    gameState.isStartingRound = false;
    showSettlementPage();
    return;
  }
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
  gameState.hasDealerPlayedFirstTurn = false;
  gameState.isDealing = false;
  
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
    player.piao = undefined; // 重置为undefined，表示未设置飘分
    player.isTing = false;
  }
  
  document.querySelectorAll('.player-piao-badge').forEach(el => {
    el.classList.add('hidden');
  });
  
  updateAvatars();
  document.getElementById('roundNum').textContent = `${gameState.roundNumber}/8`;
  updateDeckStack();
  
  // 每一局都显示飘分页面
  // 注意：isStartingRound 标志在 showPiaoScreen 完成后会被重置
  showPiaoScreen();
}

function startDealingAnimation() {
  console.log('开始发牌动画...');
  console.log('牌堆数量:', gameState.deck.length);
  
  gameState.isDealing = true;
  
  // 重置标志，允许下一局调用 startRound
  gameState.isStartingRound = false;
  
  // 清除飘分倒计时定时器，防止竞态问题
  if (piaoCountdownTimer) {
    clearInterval(piaoCountdownTimer);
    piaoCountdownTimer = null;
  }
  
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
    // 如果游戏暂停，延迟执行
    if (gameState.isPaused) {
      setTimeout(dealNextCard, 100);
      return;
    }
    
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
  
  gameState.isDealing = false;
  
  // 清除飘分倒计时定时器，防止竞态问题
  if (piaoCountdownTimer) {
    clearInterval(piaoCountdownTimer);
    piaoCountdownTimer = null;
  }
  
  // 确保隐藏所有飘分弹窗
  console.log('隐藏飘分弹窗前:');
  document.querySelectorAll('.piao-setting-popup').forEach(el => {
    console.log('飘分弹窗:', el.id, 'hidden:', el.classList.contains('hidden'));
  });
  
  document.querySelectorAll('.piao-setting-popup').forEach(el => {
    el.classList.add('hidden');
  });
  
  console.log('隐藏飘分弹窗后:');
  document.querySelectorAll('.piao-setting-popup').forEach(el => {
    console.log('飘分弹窗:', el.id, 'hidden:', el.classList.contains('hidden'));
  });
  
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
  
  updateHandCount('player1HandCount', gameState.players[0].hand.length);
  updateHandCount('myHandCount', gameState.players[1].hand.length);
  updateHandCount('player2HandCount', gameState.players[2].hand.length);
  
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
        // 必须等待摸牌动画完成后才能拖拽出牌
        if (!gameState.isMyTurn || gameState.isDrawing) {
          console.log('不能拖拽出牌: isMyTurn=', gameState.isMyTurn, 'isDrawing=', gameState.isDrawing);
          return;
        }
        
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
  if (gameState.isDealing) {
    console.log('发牌中，跳过startTurn');
    return;
  }
  
  zimoAnnounced = false;
  const currentPlayer = gameState.players[gameState.currentPlayerIndex];
  const isDealerFirstTurn = gameState.currentPlayerIndex === gameState.dealerIndex && 
                            !gameState.hasDealerPlayedFirstTurn;
  
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
  gameState.actionCancelled = false;
  
  updateCurrentPlayerUI();
  
  if (currentPlayer.type === 'human') {
    startCountdown();
  }
  
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
        
        // 更新手牌数量显示
        updateHandCount('myHandCount', currentPlayer.hand.length);
        
        const huResult = checkHu(currentPlayer);
        const canZimo = huResult.canHu;
        
        console.log('摸牌后检查 - canHu:', huResult.canHu, 'canZimo:', canZimo);
        
        const tingResult = checkTing(currentPlayer);
        currentPlayer.isTing = tingResult.isTing;
        
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
      if (isDealerFirstTurn) {
        gameState.hasDealerPlayedFirstTurn = true;
      }
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
  const canZimo = huResult.canHu && gameState.isMyTurn;
  
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
  // 不再自动播放"自摸"，等点击自摸徽章时再播放
  // if (zimoAnnounced) return;
  // zimoAnnounced = true;
  // speakText('自摸');
}

function handleZimoClick() {
  const me = gameState.players[1];
  const huResult = checkHu(me);
  console.log('handleZimoClick - canHu:', huResult.canHu, 'isMyTurn:', gameState.isMyTurn);
  if (huResult.canHu && gameState.isMyTurn) {
    // 隐藏听牌徽章
    const tingBadge = document.getElementById('tingBadge');
    if (tingBadge) tingBadge.classList.add('hidden');
    // 人类玩家点击自摸徽章时播放"自摸"音效
    playButtonSound('自摸', 1);
    handleHu(1, 'zimo');
  }
}

async function playDiscardSound(card, playerIndex = 1) {
  initAudioContext();
  await resumeAudioContext();
  
  try {
    if (card && card.character) {
      await playVoice(card.character, playerIndex);
    }
  } catch (e) {
    console.log('playDiscardSound error:', e);
  }
}

async function playVoice(text, playerIndex = 1) {
  await speakText(text, playerIndex);
}

function startCountdown() {
  stopCountdown();
  gameState.countdown = gameState.testMode ? 2 : 30;
  updateCountdownUI();
  
  gameState.countdownTimer = setInterval(() => {
    gameState.countdown--;
    updateCountdownUI();
    
    // 从20秒开始播放滴答音效
    if (gameState.countdown === 10 && gameState.isMyTurn && !gameState.testMode) {
      // 最后10秒时播放"快点吧"
      speakText('快点吧');
    } else if (gameState.countdown <= 5 && gameState.countdown > 0) {
      // <=5秒：紧急滴答音效（最急促）
      playTickSound(2);
    } else if (gameState.countdown > 5 && gameState.countdown <= 10) {
      // 6-10秒：警告滴答音效
      playTickSound(1);
    } else if (gameState.countdown > 10 && gameState.countdown <= 20) {
      // 11-20秒：正常滴答音效
      playTickSound(0);
    }
    // >20秒：不播放音效
    
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
  console.log('updateCountdownUI - countdown:', gameState.countdown, 'currentPlayerIndex:', gameState.currentPlayerIndex, 'waitingForResponse:', gameState.waitingForResponse);
  
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
  if (gameState.isDealing) {
    return;
  }
  
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
  if (gameState.isDealing) {
    console.log('发牌中，跳过AI操作');
    return;
  }
  
  if (gameState.isPaused) {
    return;
  }
  
  // 如果已经处理了胡牌，不再继续操作
  if (gameState.isHandlingHu) {
    return;
  }
  
  const player = gameState.players[gameState.currentPlayerIndex];
  const isDealerFirstTurn = gameState.currentPlayerIndex === gameState.dealerIndex && 
                            !gameState.hasDealerPlayedFirstTurn;
  
  if (!gameState.skipDraw && !isDealerFirstTurn && gameState.deck.length > 0) {
    const drawnCard = gameState.deck.pop();
    updateDeckStack();
    
    animateDrawCard(gameState.currentPlayerIndex, drawnCard, () => {
      player.hand.push(drawnCard);
      player.hand = sortHand(player.hand);
      gameState.lastDrawnCard = drawnCard;
      gameState.lastDrawnPlayerIndex = gameState.currentPlayerIndex;
      updateUI();
      continueAITurn(player);
    });
  } else {
    if (isDealerFirstTurn) {
      gameState.hasDealerPlayedFirstTurn = true;
    }
    gameState.skipDraw = false;
    gameState.lastDrawnCard = null;
    gameState.lastDrawnPlayerIndex = -1;
    continueAITurn(player);
  }
}

function continueAITurn(player) {
  if (gameState.isDealing) {
    return;
  }
  
  if (gameState.isPaused) {
    return;
  }
  
  // 如果已经处理了胡牌，不再继续操作
  if (gameState.isHandlingHu) {
    return;
  }
  
  const tingResult = checkTing(player);
  player.isTing = tingResult.isTing;
  
  const huResult = checkHu(player);
  console.log('AI胡牌检测 - 玩家:', player.name, '手牌数:', player.hand.length, '胡数:', huResult.huCount, '胡牌类型:', huResult.huType.name, '能否胡牌:', huResult.canHu);
  
  if (huResult.canHu) {
    handleHu(gameState.currentPlayerIndex, 'zimo');
    return;
  }
  
  const cardToDiscard = selectAIDiscard(player);
  
  if (cardToDiscard < 0 || cardToDiscard >= player.hand.length) {
    moveToNextPlayer();
    return;
  }
  
  discardCard(gameState.currentPlayerIndex, cardToDiscard);
}

function selectAIDiscard(player) {
  if (!player.hand || player.hand.length === 0) {
    return -1;
  }
  
  const difficulty = gameSettings.difficulty;
  
  if (difficulty === 'easy') {
    // 简单模式：随机出牌
    return selectAIDiscardEasy(player);
  } else if (difficulty === 'medium') {
    // 中等模式：基础策略
    return selectAIDiscardMedium(player);
  } else {
    // 困难模式：高级策略
    return selectAIDiscardHard(player);
  }
}

// 简单模式：随机出牌
function selectAIDiscardEasy(player) {
  const randomIndex = Math.floor(Math.random() * player.hand.length);
  console.log('简单模式: 随机选择索引', randomIndex);
  return randomIndex;
}

// 中等模式：基础策略
function selectAIDiscardMedium(player) {
  const scoredCards = player.hand.map((card, index) => ({
    card,
    index,
    score: evaluateCardMedium(card, player.hand, player)
  }));
  
  scoredCards.sort((a, b) => a.score - b.score);
  console.log('中等模式: 选择索引', scoredCards[0].index, '分数', scoredCards[0].score);
  return scoredCards[0].index;
}

// 困难模式：高级策略 - 优先保证胡牌
function selectAIDiscardHard(player) {
  const huResult = checkHu(player);
  if (huResult.canHu) {
    console.log('困难模式: 已经可以胡牌，选择最优出牌');
  }
  
  const lastChiMeld = player.melds && player.melds.length > 0 && player.melds[player.melds.length - 1];
  const recentChiCards = lastChiMeld && lastChiMeld.type === 'sequence' && lastChiMeld.source === 'chi' 
    ? lastChiMeld.cards.map(c => c.character) 
    : [];
  const recentChiSentence = lastChiMeld && lastChiMeld.type === 'sequence' && lastChiMeld.source === 'chi'
    ? lastChiMeld.cards[0].sentence
    : -1;
  const lastPengMeld = player.melds && player.melds.length > 0 && player.melds[player.melds.length - 1];
  const recentPengChar = lastPengMeld && lastPengMeld.type === 'triplet' && lastPengMeld.source === 'peng'
    ? lastPengMeld.cards[0].character
    : null;
  const isDrawnPlayer = gameState.lastDrawnCard && gameState.lastDrawnPlayerIndex === gameState.players.indexOf(player);
  const drawnCardId = isDrawnPlayer ? gameState.lastDrawnCard.id : null;
  
  const scoredCards = player.hand.map((card, index) => {
    let bonus = 0;
    if (recentChiCards.includes(card.character)) {
      bonus += 10000;
      console.log('困难模式: 保护刚吃牌相关的牌', card.character, '加分10000');
    } else if (card.sentence === recentChiSentence && recentChiSentence > 0) {
      bonus += 5000;
      console.log('困难模式: 保护刚吃牌同句的牌', card.character, '加分5000');
    }
    if (card.character === recentPengChar) {
      bonus += 10000;
      console.log('困难模式: 保护刚碰牌相关的牌', card.character, '加分10000');
    }
    
    return {
      card,
      index,
      score: evaluateCardExtreme(card, player.hand, player) + bonus
    };
  });
  
  scoredCards.sort((a, b) => a.score - b.score);
  console.log('困难模式(极限): 选择索引', scoredCards[0].index, '分数', scoredCards[0].score);
  return scoredCards[0].index;
}

// 中等模式：基础策略
function selectAIDiscardMedium(player) {
  const lastChiMeld = player.melds && player.melds.length > 0 && player.melds[player.melds.length - 1];
  const recentChiCards = lastChiMeld && lastChiMeld.type === 'sequence' && lastChiMeld.source === 'chi' 
    ? lastChiMeld.cards.map(c => c.character) 
    : [];
  const recentChiSentence = lastChiMeld && lastChiMeld.type === 'sequence' && lastChiMeld.source === 'chi'
    ? lastChiMeld.cards[0].sentence
    : -1;
  const isDrawnPlayer = gameState.lastDrawnCard && gameState.lastDrawnPlayerIndex === gameState.players.indexOf(player);
  const drawnCardId = isDrawnPlayer ? gameState.lastDrawnCard.id : null;
  
  const scoredCards = player.hand.map((card, index) => {
    let bonus = 0;
    if (recentChiCards.includes(card.character)) {
      bonus += 10000;
      console.log('中等模式: 保护刚吃牌相关的牌', card.character, '加分10000');
    } else if (card.sentence === recentChiSentence) {
      bonus += 5000;
      console.log('中等模式: 保护刚吃牌同句的牌', card.character, '加分5000');
    }
    
    return {
      card,
      index,
      score: evaluateCardMedium(card, player.hand, player) + bonus
    };
  });
  
  scoredCards.sort((a, b) => a.score - b.score);
  console.log('中等模式: 选择索引', scoredCards[0].index, '分数', scoredCards[0].score);
  return scoredCards[0].index;
}

// 中等模式评分
function evaluateCardMedium(card, hand, player) {
  let score = 0;
  
  if (card.isSpecial) score += 150;
  
  const sameCount = hand.filter(c => c.character === card.character).length;
  if (sameCount >= 4) score += 200;
  else if (sameCount >= 3) score += 150;
  else if (sameCount >= 2) score += 80;
  
  const sentenceCards = hand.filter(c => c.sentence === card.sentence);
  const sentenceChars = {};
  sentenceCards.forEach(c => {
    sentenceChars[c.position] = (sentenceChars[c.position] || 0) + 1;
  });
  
  const hasCompleteSentence = sentenceChars[0] && sentenceChars[1] && sentenceChars[2];
  if (hasCompleteSentence) {
    score += 100;
    if (card.sentence === 1 || card.sentence === 8) {
      score += 50;
    }
  } else {
    const missingPositions = [0, 1, 2].filter(p => !sentenceChars[p]);
    if (missingPositions.length === 1) {
      score += 40;
    } else if (missingPositions.length === 2) {
      score += 15;
    }
  }
  
  const currentXiangTing = calculateXiangTingShu(hand, player.melds || []);
  const tempHand = hand.filter(c => c.id !== card.id);
  const afterDiscardXiangTing = calculateXiangTingShu(tempHand, player.melds || []);
  
  if (afterDiscardXiangTing < currentXiangTing) {
    score -= 500;
  } else if (afterDiscardXiangTing > currentXiangTing) {
    score += 400;
  }
  
  const tingPrediction = predictTingAfterDiscard(card, hand, { ...player, melds: player.melds || [] });
  if (tingPrediction.canTing) {
    score -= 300 + tingPrediction.tingCount * 50;
  }
  
  if (player.isTing) {
    if (sameCount === 1 && !card.isSpecial) {
      score -= 100;
    }
    if (sameCount >= 2 || card.isSpecial || hasCompleteSentence) {
      score += 80;
    }
  }
  
  const currentHuCount = calculateHuCount(hand, player.melds || []);
  if (currentHuCount < 11) {
    if (card.character === '上' || card.character === '福') {
      score += 100;
    }
    if (sameCount >= 3) {
      score += 80;
    }
  }
  
  return score;
}

// 困难模式评分 - 更智能的策略，优先保证胡牌
function evaluateCardHard(card, hand, player) {
  let score = 0;
  
  const playerWithMelds = { ...player, melds: player.melds || [] };
  const melds = player.melds || [];
  
  const huResult = checkHu(playerWithMelds);
  if (huResult.canHu) {
    if (card.character === '上' || card.character === '福') score += 800;
    const sameCount = hand.filter(c => c.character === card.character).length;
    if (sameCount >= 2) score += 500;
    
    const sentenceCards = hand.filter(c => c.sentence === card.sentence);
    const sentenceChars = {};
    sentenceCards.forEach(c => {
      sentenceChars[c.position] = (sentenceChars[c.position] || 0) + 1;
    });
    if (sentenceChars[0] && sentenceChars[1] && sentenceChars[2]) {
      score += 400;
    }
    
    if (sameCount === 1 && card.character !== '上' && card.character !== '福') {
      score -= 300;
    }
    
    return score;
  }
  
  const currentXiangTing = calculateXiangTingShu(hand, melds);
  
  const tempHand = hand.filter(c => c.id !== card.id);
  const afterDiscardXiangTing = calculateXiangTingShu(tempHand, melds);
  
  if (afterDiscardXiangTing < currentXiangTing) {
    const improvement = currentXiangTing - afterDiscardXiangTing;
    score -= improvement * 5000;
  } else if (afterDiscardXiangTing > currentXiangTing) {
    const penalty = afterDiscardXiangTing - currentXiangTing;
    score += penalty * 4000;
  }
  
  const tingPrediction = predictTingAfterDiscard(card, hand, playerWithMelds);
  if (tingPrediction.canTing) {
    const tingBonus = 2000 + tingPrediction.tingCount * 300;
    score -= tingBonus;
    
    const highValueTing = tingPrediction.tingCards.filter(c => c === '上' || c === '福').length;
    score -= highValueTing * 200;
    
    const enhancedHuType = predictBestHuTypeEnhanced(tempHand, melds);
    if (enhancedHuType.score > 0) {
      score -= enhancedHuType.score * 0.5;
    }
  }
  
  const huTypePrediction = predictHuTypeAfterDiscard(card, hand, playerWithMelds);
  if (huTypePrediction.score > 0) {
    score -= huTypePrediction.score;
  }
  
  const jinZhangValue = calculateJinZhangValueEnhanced(card, hand, playerWithMelds);
  score -= jinZhangValue;
  
  const dangerScore = checkDangerousCardEnhanced(card, hand, playerWithMelds);
  score += dangerScore;
  
  const safetyScore = analyzeCardSafety(card, hand, playerWithMelds);
  score += safetyScore * 0.5;
  
  const tingWidthScore = optimizeTingWidthOptimized(card, hand, player);
  score -= tingWidthScore * 1.2;
  
  const structureScore = analyzeHandStructureEnhanced(card, hand, playerWithMelds);
  score += structureScore;
  
  const specialHuPotential = evaluateSpecialHuPotential(hand, melds);
  const tempSpecialHuPotential = evaluateSpecialHuPotential(tempHand, melds);
  if (tempSpecialHuPotential > specialHuPotential) {
    score -= (tempSpecialHuPotential - specialHuPotential) * 0.8;
  } else if (tempSpecialHuPotential < specialHuPotential) {
    score += (specialHuPotential - tempSpecialHuPotential) * 1.2;
  }
  
  if (card.character === '上' || card.character === '福') {
    const shangFuCount = hand.filter(c => c.character === '上' || c.character === '福').length;
    const hasPengZhao = melds.some(m => m.type === 'triplet' || m.type === 'quartet');
    
    if (!hasPengZhao && shangFuCount >= 3 && shangFuCount <= 6) {
      const sentenceGroups = {};
      hand.forEach(c => {
        if (!sentenceGroups[c.sentence]) {
          sentenceGroups[c.sentence] = { 0: 0, 1: 0, 2: 0 };
        }
        sentenceGroups[c.sentence][c.position]++;
      });
      
      const hasShangDaRen = sentenceGroups[1] && 
        sentenceGroups[1][0] > 0 && sentenceGroups[1][1] > 0 && sentenceGroups[1][2] > 0;
      const hasFuLuShou = sentenceGroups[8] && 
        sentenceGroups[8][0] > 0 && sentenceGroups[8][1] > 0 && sentenceGroups[8][2] > 0;
      
      if (hasShangDaRen || hasFuLuShou) {
        score += 1200;
      }
    }
    
    if (shangFuCount <= 3) {
      score += 800;
    } else if (shangFuCount <= 5) {
      score += 500;
    } else {
      score += 200;
    }
  }
  
  const sameCount = hand.filter(c => c.character === card.character).length;
  if (sameCount >= 4) {
    score += 700;
  } else if (sameCount === 3) {
    score += 600;
  } else if (sameCount === 2) {
    score += 300;
  }
  
  const sentenceCards = hand.filter(c => c.sentence === card.sentence);
  const sentenceChars = {};
  sentenceCards.forEach(c => {
    sentenceChars[c.position] = (sentenceChars[c.position] || 0) + 1;
  });
  
  const hasCompleteSentence = sentenceChars[0] && sentenceChars[1] && sentenceChars[2];
  if (hasCompleteSentence) {
    score += 350;
    if (card.sentence === 1 || card.sentence === 8) {
      score += 250;
    }
  } else {
    const missingPositions = [0, 1, 2].filter(p => !sentenceChars[p]);
    if (missingPositions.length === 1) {
      const missingPos = missingPositions[0];
      const missingChar = getSentenceCharacters(card.sentence)[missingPos];
      const remaining = countRemainingCards(missingChar);
      if (remaining > 0) {
        score += 200 + remaining * 30;
      } else {
        score += 20;
      }
    } else if (missingPositions.length === 2) {
      score += 15;
    }
  }
  
  const remaining = countRemainingCards(card.character);
  score -= remaining * 35;
  
  if (player.isTing) {
    if (sameCount === 1 && card.character !== '上' && card.character !== '福') {
      score -= 600;
    }
    if (sameCount >= 2 || card.character === '上' || card.character === '福' || hasCompleteSentence) {
      score += 500;
    }
    
    const tingResult = checkTing({ hand: hand.filter(c => c.id !== card.id), melds: melds });
    if (!tingResult.isTing) {
      score += 1500;
    }
  }
  
  const opponents = gameState.players.filter((p, i) => i !== gameState.currentPlayerIndex);
  let opponentTingCount = 0;
  let maxOpponentHuMultiplier = 0;
  
  opponents.forEach(opponent => {
    if (opponent.isTing) {
      opponentTingCount++;
      score -= 200;
      
      const opponentWithMelds = { ...opponent, melds: opponent.melds || [] };
      const opponentTingResult = checkTing(opponentWithMelds);
      
      if (opponentTingResult.tingCards && opponentTingResult.tingCards.includes(card.character)) {
        score -= 1500;
        
        const testPlayer = { hand: [...opponent.hand, card], melds: opponent.melds || [] };
        const opponentHuResult = checkHu(testPlayer, card, true);
        if (opponentHuResult.canHu && opponentHuResult.huType) {
          const multiplier = opponentHuResult.huType.multiplier?.dianpao || 1;
          maxOpponentHuMultiplier = Math.max(maxOpponentHuMultiplier, multiplier);
          score -= multiplier * 300;
        }
      }
      
      const recentDiscards = opponent.discards.slice(-5);
      if (recentDiscards.some(c => c.sentence === card.sentence)) {
        score += 80;
      }
    }
  });
  
  if (opponentTingCount >= 2) {
    if (remaining === 0) {
      score += 300;
    } else if (remaining === 1) {
      score += 150;
    } else {
      score -= 150 + maxOpponentHuMultiplier * 100;
    }
  }
  
  const deckRemaining = gameState.deck.length;
  if (deckRemaining < 20) {
    if (sameCount >= 2 || card.character === '上' || card.character === '福') {
      score += 150;
    }
    
    if (opponentTingCount > 0 && remaining === 0) {
      score += 200;
    }
  } else if (deckRemaining > 60) {
    if (sameCount === 1 && card.character !== '上' && card.character !== '福') {
      score -= 80;
    }
  }
  
  const currentHuCount = calculateHuCount(hand, melds);
  const afterDiscardHuCount = calculateHuCount(tempHand, melds);
  
  if (currentHuCount < 11) {
    const neededHu = 11 - currentHuCount;
    const potentialHuGain = calculatePotentialHuGain(card, hand, melds);
    if (potentialHuGain >= neededHu) {
      score += 300;
    }
    
    if (afterDiscardHuCount < currentHuCount) {
      score += 400;
    }
  }
  
  if (currentHuCount >= 11 && afterDiscardHuCount < 11) {
    score += 800;
  }
  
  if (currentHuCount >= 22 && afterDiscardHuCount < 22) {
    score += 300;
  }
  
  return score;
}

const ALL_CHARACTERS = ['上', '大', '人', '丘', '乙', '己', '化', '三', '千', '七', '十', '土', '尔', '小', '生', '八', '九', '子', '佳', '作', '亡', '福', '禄', '寿'];

let remainingCardsCache = null;
let remainingCardsCacheTime = 0;

function invalidateRemainingCardsCache() {
  remainingCardsCache = null;
}

function countRemainingCards(character) {
  if (remainingCardsCache && Date.now() - remainingCardsCacheTime < 100) {
    return remainingCardsCache.get(character) || 0;
  }
  
  if (!remainingCardsCache) {
    remainingCardsCache = new Map();
  }
  
  const counts = {};
  for (const char of ALL_CHARACTERS) {
    counts[char] = 4;
  }
  
  for (const p of gameState.players) {
    if (p.hand) {
      for (const c of p.hand) {
        counts[c.character] = (counts[c.character] || 4) - 1;
      }
    }
    if (p.discards) {
      for (const c of p.discards) {
        counts[c.character] = (counts[c.character] || 4) - 1;
      }
    }
    if (p.melds) {
      for (const m of p.melds) {
        for (const c of m.cards) {
          counts[c.character] = (counts[c.character] || 4) - 1;
        }
      }
    }
  }
  
  for (const [char, count] of Object.entries(counts)) {
    remainingCardsCache.set(char, count);
  }
  remainingCardsCacheTime = Date.now();
  
  return remainingCardsCache.get(character) || 0;
}

function countAllRemainingCards() {
  if (remainingCardsCache && Date.now() - remainingCardsCacheTime < 100) {
    return remainingCardsCache;
  }
  
  countRemainingCards('上');
  return remainingCardsCache;
}

function getGamePhase() {
  const deckRemaining = gameState.deck ? gameState.deck.length : 0;
  if (deckRemaining > 60) return 'early';
  if (deckRemaining > 30) return 'middle';
  if (deckRemaining > 10) return 'late';
  return 'end';
}

function calculateWinProbability(hand, melds) {
  const xiangTing = calculateXiangTingShu(hand, melds);
  if (xiangTing === 0) {
    const tingResult = checkTing({ hand, melds });
    if (tingResult.isTing && tingResult.tingCards) {
      let totalProbability = 0;
      for (const char of tingResult.tingCards) {
        const remaining = countRemainingCards(char);
        totalProbability += remaining * 0.25;
      }
      return Math.min(1, totalProbability);
    }
  }
  
  const baseProbability = Math.max(0, 1 - xiangTing * 0.15);
  const huCount = calculateHuCount(hand, melds);
  const huFactor = huCount >= 11 ? 1 : Math.max(0.3, huCount / 11);
  
  return baseProbability * huFactor;
}

function calculateExpectedValue(hand, melds) {
  const huTypePrediction = predictBestHuTypeEnhanced(hand, melds);
  const winProb = calculateWinProbability(hand, melds);
  
  if (huTypePrediction.score > 0 && huTypePrediction.huType) {
    const multiplier = huTypePrediction.huType.multiplier?.zimo || 1;
    return multiplier * winProb * 100;
  }
  
  return winProb * 50;
}

function predictOpponentTing(opponent) {
  if (opponent.isTing) {
    const opponentWithMelds = { ...opponent, melds: opponent.melds || [] };
    const tingResult = checkTing(opponentWithMelds);
    return {
      isTing: true,
      tingCards: tingResult.tingCards || [],
      probability: 1
    };
  }
  
  const handSize = opponent.hand ? opponent.hand.length : 0;
  const melds = opponent.melds || [];
  const meldCount = melds.length;
  
  if (handSize <= 5 && meldCount >= 3) {
    return {
      isTing: false,
      tingCards: [],
      probability: 0.7,
      dangerLevel: 'high'
    };
  }
  
  if (handSize <= 8 && meldCount >= 2) {
    return {
      isTing: false,
      tingCards: [],
      probability: 0.4,
      dangerLevel: 'medium'
    };
  }
  
  return {
    isTing: false,
    tingCards: [],
    probability: 0.1,
    dangerLevel: 'low'
  };
}

function calculateCardDangerScore(card, player) {
  let dangerScore = 0;
  const opponents = gameState.players.filter((p, i) => i !== gameState.currentPlayerIndex);
  
  for (const opponent of opponents) {
    const prediction = predictOpponentTing(opponent);
    
    if (prediction.isTing && prediction.tingCards.includes(card.character)) {
      const opponentWithMelds = { ...opponent, melds: opponent.melds || [] };
      const huResult = checkHu(opponentWithMelds, card, true);
      
      if (huResult.canHu && huResult.huType) {
        const multiplier = huResult.huType.multiplier?.dianpao || 1;
        dangerScore += multiplier * 500;
      } else {
        dangerScore += 300;
      }
    } else if (prediction.dangerLevel === 'high') {
      const recentDiscards = opponent.discards ? opponent.discards.slice(-8) : [];
      const sameSentenceDiscards = recentDiscards.filter(c => c.sentence === card.sentence);
      
      if (sameSentenceDiscards.length === 0) {
        dangerScore += 150;
      }
      
      if (card.character === '上' || card.character === '福') {
        dangerScore += 100;
      }
    } else if (prediction.dangerLevel === 'medium') {
      dangerScore += 50;
    }
  }
  
  return dangerScore;
}

function calculateOptimalDiscard(hand, melds) {
  const phase = getGamePhase();
  const huCount = calculateHuCount(hand, melds);
  const xiangTing = calculateXiangTingShu(hand, melds);
  
  return {
    phase,
    huCount,
    xiangTing,
    shouldPrioritizeSpeed: phase === 'late' || phase === 'end',
    shouldPrioritizeValue: phase === 'early' && huCount < 11,
    shouldDefend: phase === 'late' || phase === 'end'
  };
}

function evaluateCardExtreme(card, hand, player) {
  let score = 0;
  const melds = player.melds || [];
  const phase = getGamePhase();
  const deckRemaining = gameState.deck ? gameState.deck.length : 96;
  
  const playerWithMelds = { ...player, melds };
  
  const huResult = checkHu(playerWithMelds);
  if (huResult.canHu) {
    const huType = huResult.huType?.type || 'puTongHu';
    const multiplier = huResult.huType?.multiplier?.zimo || 1;
    
    const sameCount = hand.filter(c => c.character === card.character).length;
    
    if (sameCount === 1 && card.character !== '上' && card.character !== '福') {
      const otherCards = hand.filter(c => c.id !== card.id);
      const otherSameCount = {};
      otherCards.forEach(c => {
        otherSameCount[c.character] = (otherSameCount[c.character] || 0) + 1;
      });
      
      let hasOtherPair = Object.values(otherSameCount).some(count => count >= 2);
      let hasOtherTriplet = Object.values(otherSameCount).some(count => count >= 3);
      
      if (!hasOtherPair && !hasOtherTriplet) {
        score -= 500;
      }
    }
    
    if (card.character === '上' || card.character === '福') {
      score += multiplier * 300;
    }
    
    if (sameCount >= 2) {
      score += multiplier * 200;
    }
    
    const sentenceCards = hand.filter(c => c.sentence === card.sentence);
    const sentenceChars = {};
    sentenceCards.forEach(c => {
      sentenceChars[c.position] = (sentenceChars[c.position] || 0) + 1;
    });
    if (sentenceChars[0] && sentenceChars[1] && sentenceChars[2]) {
      score += multiplier * 150;
    }
    
    return score;
  }
  
  const tempHand = hand.filter(c => c.id !== card.id);
  const currentXiangTing = calculateXiangTingShu(hand, melds);
  const afterDiscardXiangTing = calculateXiangTingShu(tempHand, melds);
  
  if (afterDiscardXiangTing < currentXiangTing) {
    const improvement = currentXiangTing - afterDiscardXiangTing;
    score -= improvement * 1000;
  } else if (afterDiscardXiangTing > currentXiangTing) {
    const penalty = afterDiscardXiangTing - currentXiangTing;
    score += penalty * 600;
  }
  
  const tingPrediction = predictTingAfterDiscard(card, hand, playerWithMelds);
  if (tingPrediction.canTing) {
    let tingBonus = 2000;

    let totalRemaining = 0;
    let highValueTingCount = 0;

    for (const tingChar of tingPrediction.tingCards) {
      const remaining = countRemainingCards(tingChar);
      totalRemaining += remaining;

      if (tingChar === '上' || tingChar === '福') {
        highValueTingCount++;
      }
    }

    tingBonus += totalRemaining * 150;
    tingBonus += highValueTingCount * 100;

    const enhancedHuType = predictBestHuTypeEnhanced(tempHand, melds);
    if (enhancedHuType.score > 0) {
      tingBonus += enhancedHuType.score * 0.5;
    }

    score -= tingBonus;
  }
  
  const beforeExpectedValue = calculateExpectedValue(hand, melds);
  const afterExpectedValue = calculateExpectedValue(tempHand, melds);
  score += (beforeExpectedValue - afterExpectedValue) * 50;
  
  const dangerScore = calculateCardDangerScore(card, player);
  score += dangerScore;
  
  const specialHuPotential = evaluateSpecialHuPotential(hand, melds);
  const tempSpecialHuPotential = evaluateSpecialHuPotential(tempHand, melds);
  if (tempSpecialHuPotential > specialHuPotential) {
    score -= (tempSpecialHuPotential - specialHuPotential) * 1.0;
  } else if (tempSpecialHuPotential < specialHuPotential) {
    score += (specialHuPotential - tempSpecialHuPotential) * 1.5;
  }
  
  if (card.character === '上' || card.character === '福') {
    const shangFuCount = hand.filter(c => c.character === '上' || c.character === '福').length;
    const hasPengZhao = melds.some(m => m.type === 'triplet' || m.type === 'quartet');
    
    if (!hasPengZhao && shangFuCount >= 3 && shangFuCount <= 6) {
      const sentenceGroups = {};
      hand.forEach(c => {
        if (!sentenceGroups[c.sentence]) {
          sentenceGroups[c.sentence] = { 0: 0, 1: 0, 2: 0 };
        }
        sentenceGroups[c.sentence][c.position]++;
      });
      
      const hasShangDaRen = sentenceGroups[1] && 
        sentenceGroups[1][0] > 0 && sentenceGroups[1][1] > 0 && sentenceGroups[1][2] > 0;
      const hasFuLuShou = sentenceGroups[8] && 
        sentenceGroups[8][0] > 0 && sentenceGroups[8][1] > 0 && sentenceGroups[8][2] > 0;
      
      if (hasShangDaRen || hasFuLuShou) {
        score += 1500;
      }
    }
    
    if (shangFuCount <= 3) {
      score += 1000;
    } else if (shangFuCount <= 5) {
      score += 600;
    } else {
      score += 250;
    }
  }
  
  const sameCount = hand.filter(c => c.character === card.character).length;
  if (sameCount >= 4) {
    score += 200;
  } else if (sameCount === 3) {
    score += 120;
  } else if (sameCount === 2) {
    score += 50;
  }
  
  const sentenceCards = hand.filter(c => c.sentence === card.sentence);
  const sentenceChars = {};
  sentenceCards.forEach(c => {
    sentenceChars[c.position] = (sentenceChars[c.position] || 0) + 1;
  });
  
  const hasCompleteSentence = sentenceChars[0] && sentenceChars[1] && sentenceChars[2];
  if (hasCompleteSentence) {
    score += 400;
    if (card.sentence === 1 || card.sentence === 8) {
      score += 30;
    }
  } else {
    const missingPositions = [0, 1, 2].filter(p => !sentenceChars[p]);
    if (missingPositions.length === 1) {
      const missingPos = missingPositions[0];
      const missingChar = getSentenceCharacters(card.sentence)[missingPos];
      const remaining = countRemainingCards(missingChar);
      if (remaining > 0) {
        score += 250 + remaining * 40;
      } else {
        score += 25;
      }
    } else if (missingPositions.length === 2) {
      score += 20;
    }
  }
  
  const remaining = countRemainingCards(card.character);
  score -= remaining * 120;
  
  const afterDiscardJinZhang = calculateTotalJinZhang(tempHand, melds);
  const currentJinZhang = calculateTotalJinZhang(hand, melds);
  score += (currentJinZhang - afterDiscardJinZhang) * 15;
  
  const currentHuCount = calculateHuCount(hand, melds);
  const afterDiscardHuCount = calculateHuCount(tempHand, melds);
  
  if (currentHuCount < 11) {
    const neededHu = 11 - currentHuCount;
    const potentialHuGain = calculatePotentialHuGain(card, hand, melds);
    if (potentialHuGain >= neededHu) {
      score += 400;
    }
    
    if (afterDiscardHuCount < currentHuCount) {
      score += 500;
    }
  }
  
  if (currentHuCount >= 11 && afterDiscardHuCount < 11) {
    score += 1000;
  }
  
  if (currentHuCount >= 22 && afterDiscardHuCount < 22) {
    score += 400;
  }
  
  if (player.isTing) {
    if (sameCount === 1 && card.character !== '上' && card.character !== '福') {
      score -= 800;
    }
    if (sameCount >= 2 || card.character === '上' || card.character === '福' || hasCompleteSentence) {
      score += 600;
    }
    
    const tingResult = checkTing({ hand: tempHand, melds });
    if (!tingResult.isTing) {
      score += 2000;
    }
    
    const cardRemaining = countRemainingCards(card.character);
    if (cardRemaining === 0) {
      score -= 3000;
    } else if (cardRemaining <= 1) {
      score -= 1500;
    } else if (cardRemaining <= 2) {
      score -= 500;
    } else {
      score += cardRemaining * 200;
    }
    
    const opponents = gameState.players.filter((p, i) => i !== gameState.currentPlayerIndex);
    const anyOpponentTing = opponents.some(o => o.isTing);
    if (anyOpponentTing) {
      const cardDanger = calculateCardDangerScore(card, player);
      score += cardDanger * 2;
    }
  }
  
  if (phase === 'late' || phase === 'end') {
    score += dangerScore * 0.5;
    
    if (remaining === 0) {
      score += 300;
    }
  }
  
  if (phase === 'early') {
    if (sameCount === 1 && card.character !== '上' && card.character !== '福') {
      score -= 100;
    }
  }
  
  const sentenceCardsInHand = hand.filter(c => c.sentence === card.sentence && c.id !== card.id);
  const hasPairInSentence = sentenceCardsInHand.some(c => c.position !== card.position);
  if (hasPairInSentence && sameCount === 1) {
    const missingPos = [0, 1, 2].find(p => {
      const posCards = sentenceCardsInHand.filter(c => c.position === p);
      return posCards.length === 0 && p !== card.position;
    });
    if (missingPos !== undefined) {
      const missingChar = getSentenceCharacters(card.sentence)[missingPos];
      const missingRemaining = countRemainingCards(missingChar);
      if (missingRemaining > 0) {
        score -= missingRemaining * 80;
      }
    }
  }
  
  const handAnalysis = analyzeHandForTing(hand, melds);
  const isCardInPair = handAnalysis.pairs && handAnalysis.pairs.some(p => p.character === card.character);
  const isCardInHalfKao = handAnalysis.halfKaos && handAnalysis.halfKaos.some(hk => 
    hk.card1 && hk.card1.character === card.character || 
    hk.card2 && hk.card2.character === card.character
  );
  if (isCardInPair) {
    score -= 300;
  }
  if (isCardInHalfKao) {
    score -= 200;
  }
  
  return score;
}

function calculateJinZhangValueEnhanced(card, hand, player) {
  let value = 0;
  
  const tempHand = hand.filter(c => c.id !== card.id);
  const currentXiangTing = calculateXiangTingShu(hand, player.melds || []);
  
  for (const char of ALL_CHARACTERS) {
    const remaining = countRemainingCards(char);
    if (remaining <= 0) continue;
    
    const testCard = createCardByCharacter(char);
    if (!testCard) continue;
    
    const testHand = [...tempHand, testCard];
    const tempPlayer = { ...player, hand: testHand, melds: player.melds || [] };
    
    const tingResult = checkTing(tempPlayer);
    const huResult = checkHu(tempPlayer);
    const newXiangTing = calculateXiangTingShu(testHand, player.melds || []);
    
    if (huResult.canHu) {
      const multiplier = huResult.huType?.multiplier?.zimo || 1;
      value += remaining * 30 * multiplier;
    } else if (tingResult.isTing) {
      value += remaining * 20;
    } else if (newXiangTing < currentXiangTing) {
      value += remaining * 12;
    } else if (newXiangTing === currentXiangTing && currentXiangTing <= 2) {
      value += remaining * 5;
    }
  }
  
  return value;
}

function predictHuTypeAfterDiscard(card, hand, player) {
  let score = 0;
  let bestHuType = null;
  
  const tempHand = hand.filter(c => c.id !== card.id);
  
  for (const char of ALL_CHARACTERS) {
    const testCard = createCardByCharacter(char);
    if (!testCard) continue;
    
    const testHand = [...tempHand, testCard];
    const tempPlayer = { hand: testHand, melds: player.melds || [] };
    
    const huResult = checkHu(tempPlayer);
    if (huResult.canHu) {
      const multiplier = huResult.huType?.multiplier?.zimo || 1;
      const remaining = countRemainingCards(char);
      const huScore = multiplier * 100 * remaining;
      
      if (huScore > score) {
        score = huScore;
        bestHuType = huResult.huType;
      }
    }
  }
  
  return { score, huType: bestHuType };
}

function checkDangerousCardEnhanced(card, hand, player) {
  let dangerScore = 0;
  
  const opponents = gameState.players.filter((p, i) => i !== gameState.currentPlayerIndex);
  
  for (const opponent of opponents) {
    const opponentWithMelds = { ...opponent, melds: opponent.melds || [] };
    const tingResult = checkTing(opponentWithMelds);
    
    if (tingResult.isTing && tingResult.tingCards) {
      if (tingResult.tingCards.includes(card.character)) {
        dangerScore -= 1000;
        
        const huResult = checkHu(opponentWithMelds, card, true);
        if (huResult.canHu) {
          const multiplier = huResult.huType?.multiplier?.dianpao || 1;
          dangerScore -= multiplier * 200;
        }
      }
    }
    
    const opponentMelds = opponent.melds || [];
    for (const meld of opponentMelds) {
      if (meld.type === 'triplet' || meld.type === 'quartet') {
        if (card.sentence === meld.cards[0].sentence) {
          dangerScore -= 50;
        }
      }
    }
    
    const recentDiscards = opponent.discards.slice(-8);
    const sameSentenceDiscards = recentDiscards.filter(c => c.sentence === card.sentence);
    if (sameSentenceDiscards.length === 0) {
      dangerScore -= 30;
    }
    
    if (opponent.hand.length <= 5) {
      dangerScore -= 40;
    }
  }
  
  return dangerScore;
}

function analyzeHandStructureEnhanced(card, hand, player) {
  let score = 0;
  
  const tempHand = hand.filter(c => c.id !== card.id);
  
  const sentenceGroups = {};
  hand.forEach(c => {
    if (!sentenceGroups[c.sentence]) {
      sentenceGroups[c.sentence] = { 0: 0, 1: 0, 2: 0 };
    }
    sentenceGroups[c.sentence][c.position]++;
  });
  
  const currentGroup = sentenceGroups[card.sentence];
  if (currentGroup) {
    const groupCompleteness = (currentGroup[0] > 0 ? 1 : 0) + 
                              (currentGroup[1] > 0 ? 1 : 0) + 
                              (currentGroup[2] > 0 ? 1 : 0);
    
    if (groupCompleteness === 3) {
      score += 200;
    } else if (groupCompleteness === 2) {
      score += 120;
    } else if (groupCompleteness === 1) {
      const otherCardsInGroup = hand.filter(c => 
        c.sentence === card.sentence && c.id !== card.id);
      if (otherCardsInGroup.length === 0) {
        score += 30;
      }
    }
  }
  
  const specialSentenceCount = (sentenceGroups[1] ? 
    ((sentenceGroups[1][0] > 0 ? 1 : 0) + (sentenceGroups[1][1] > 0 ? 1 : 0) + (sentenceGroups[1][2] > 0 ? 1 : 0)) : 0) +
    (sentenceGroups[8] ? 
    ((sentenceGroups[8][0] > 0 ? 1 : 0) + (sentenceGroups[8][1] > 0 ? 1 : 0) + (sentenceGroups[8][2] > 0 ? 1 : 0)) : 0);
  
  if (specialSentenceCount >= 4) {
    if (card.sentence === 1 || card.sentence === 8) {
      score += 150;
    }
  }
  
  const shangCount = hand.filter(c => c.character === '上').length;
  const fuCount = hand.filter(c => c.character === '福').length;
  const shangFuTotal = shangCount + fuCount;
  
  if (shangFuTotal >= 3 && shangFuTotal <= 6) {
    if (card.character === '上' || card.character === '福') {
      score += 300;
    }
  }
  
  const hasShangDaRen = sentenceGroups[1] && 
    sentenceGroups[1][0] > 0 && sentenceGroups[1][1] > 0 && sentenceGroups[1][2] > 0;
  const hasFuLuShou = sentenceGroups[8] && 
    sentenceGroups[8][0] > 0 && sentenceGroups[8][1] > 0 && sentenceGroups[8][2] > 0;
  
  if (hasShangDaRen || hasFuLuShou) {
    const melds = player.melds || [];
    const hasPengZhao = melds.some(m => m.type === 'triplet' || m.type === 'quartet');
    
    if (!hasPengZhao && shangFuTotal >= 3) {
      score -= 200;
    }
  }
  
  return score;
}

function calculateCardEfficiency(card, hand, player) {
  let efficiency = 0;
  
  const tempHand = hand.filter(c => c.id !== card.id);
  
  const sentenceCards = tempHand.filter(c => c.sentence === card.sentence);
  const positions = {};
  sentenceCards.forEach(c => {
    positions[c.position] = (positions[c.position] || 0) + 1;
  });
  
  if (positions[0] && positions[1] && positions[2]) {
    efficiency += 120;
  } else {
    const missingPositions = [0, 1, 2].filter(p => !positions[p]);
    if (missingPositions.length === 1) {
      const missingPos = missingPositions[0];
      const missingChar = getSentenceCharacters(card.sentence)[missingPos];
      const inDiscards = gameState.players.reduce((sum, p) => 
        sum + p.discards.filter(c => c.character === missingChar).length, 0);
      const inMelds = gameState.players.reduce((sum, p) => 
        sum + (p.melds || []).reduce((mSum, m) => 
          mSum + m.cards.filter(c => c.character === missingChar).length, 0), 0);
      const remaining = 4 - inDiscards - inMelds;
      
      if (remaining > 0) {
        efficiency += 60 + remaining * 20;
      }
    } else if (missingPositions.length === 2) {
      let totalRemaining = 0;
      for (const missingPos of missingPositions) {
        const missingChar = getSentenceCharacters(card.sentence)[missingPos];
        const inDiscards = gameState.players.reduce((sum, p) => 
          sum + p.discards.filter(c => c.character === missingChar).length, 0);
        const inMelds = gameState.players.reduce((sum, p) => 
          sum + (p.melds || []).reduce((mSum, m) => 
            mSum + m.cards.filter(c => c.character === missingChar).length, 0), 0);
        totalRemaining += 4 - inDiscards - inMelds;
      }
      efficiency += totalRemaining * 5;
    }
  }
  
  const sameCount = tempHand.filter(c => c.character === card.character).length;
  if (sameCount >= 3) {
    efficiency += 100;
  } else if (sameCount === 2) {
    efficiency += 50;
  }
  
  const currentXiangTing = calculateXiangTingShu(hand, player.melds || []);
  const newXiangTing = calculateXiangTingShu(tempHand, player.melds || []);
  
  if (newXiangTing < currentXiangTing) {
    efficiency += 200;
  }
  
  const multiWayScore = calculateMultiWayValue(tempHand, player.melds || []);
  efficiency += multiWayScore;
  
  return efficiency;
}

function calculateMultiWayValue(hand, melds) {
  let value = 0;
  
  const sentenceGroups = {};
  hand.forEach(c => {
    if (!sentenceGroups[c.sentence]) {
      sentenceGroups[c.sentence] = { 0: 0, 1: 0, 2: 0 };
    }
    sentenceGroups[c.sentence][c.position]++;
  });
  
  for (const [sentence, group] of Object.entries(sentenceGroups)) {
    const posCount = (group[0] > 0 ? 1 : 0) + (group[1] > 0 ? 1 : 0) + (group[2] > 0 ? 1 : 0);
    
    if (posCount === 3) {
      value += 30;
    } else if (posCount === 2) {
      const missingPositions = [0, 1, 2].filter(p => group[p] === 0);
      const missingPos = missingPositions[0];
      const missingChar = getSentenceCharacters(parseInt(sentence))[missingPos];
      const inDiscards = gameState.players.reduce((sum, p) => 
        sum + p.discards.filter(c => c.character === missingChar).length, 0);
      const inMelds = gameState.players.reduce((sum, p) => 
        sum + (p.melds || []).reduce((mSum, m) => 
          mSum + m.cards.filter(c => c.character === missingChar).length, 0), 0);
      const remaining = 4 - inDiscards - inMelds;
      
      if (remaining > 0) {
        value += 15 + remaining * 5;
      }
    }
  }
  
  const counts = {};
  hand.forEach(c => {
    counts[c.character] = (counts[c.character] || 0) + 1;
  });
  
  for (const [char, count] of Object.entries(counts)) {
    if (count >= 2) {
      const inDiscards = gameState.players.reduce((sum, p) => 
        sum + p.discards.filter(c => c.character === char).length, 0);
      const inMelds = gameState.players.reduce((sum, p) => 
        sum + (p.melds || []).reduce((mSum, m) => 
          mSum + m.cards.filter(c => c.character === char).length, 0), 0);
      const remaining = 4 - count - inDiscards - inMelds;
      
      if (remaining > 0) {
        value += remaining * 8;
      }
    }
  }
  
  return value;
}

function analyzeHandStructure(card, hand, player) {
  let score = 0;
  
  const tempHand = hand.filter(c => c.id !== card.id);
  
  const sentenceGroups = {};
  tempHand.forEach(c => {
    if (!sentenceGroups[c.sentence]) {
      sentenceGroups[c.sentence] = { 0: 0, 1: 0, 2: 0, total: 0 };
    }
    sentenceGroups[c.sentence][c.position]++;
    sentenceGroups[c.sentence].total++;
  });
  
  let completeSentences = 0;
  let nearCompleteSentences = 0;
  let partialSentences = 0;
  let isolatedCards = 0;
  
  for (const [sentence, group] of Object.entries(sentenceGroups)) {
    const hasAll = group[0] > 0 && group[1] > 0 && group[2] > 0;
    const hasTwo = (group[0] > 0 ? 1 : 0) + (group[1] > 0 ? 1 : 0) + (group[2] > 0 ? 1 : 0) === 2;
    
    if (hasAll) {
      completeSentences++;
    } else if (hasTwo) {
      nearCompleteSentences++;
    } else if (group.total >= 2) {
      partialSentences++;
    } else {
      isolatedCards++;
    }
  }
  
  score += completeSentences * 60;
  score += nearCompleteSentences * 35;
  score += partialSentences * 15;
  score -= isolatedCards * 25;
  
  const originalGroups = {};
  hand.forEach(c => {
    if (!originalGroups[c.sentence]) {
      originalGroups[c.sentence] = { 0: 0, 1: 0, 2: 0, total: 0 };
    }
    originalGroups[c.sentence][c.position]++;
    originalGroups[c.sentence].total++;
  });
  
  let originalComplete = 0;
  let originalNearComplete = 0;
  
  for (const [sentence, group] of Object.entries(originalGroups)) {
    const hasAll = group[0] > 0 && group[1] > 0 && group[2] > 0;
    const hasTwo = (group[0] > 0 ? 1 : 0) + (group[1] > 0 ? 1 : 0) + (group[2] > 0 ? 1 : 0) === 2;
    
    if (hasAll) originalComplete++;
    else if (hasTwo) originalNearComplete++;
  }
  
  if (completeSentences < originalComplete) {
    score += 120;
  }
  if (nearCompleteSentences < originalNearComplete) {
    score += 60;
  }
  
  const flexibilityScore = calculateHandFlexibility(tempHand);
  score -= flexibilityScore;
  
  return score;
}

function calculateHandFlexibility(hand) {
  let flexibility = 0;
  
  const sentenceGroups = {};
  hand.forEach(c => {
    if (!sentenceGroups[c.sentence]) {
      sentenceGroups[c.sentence] = new Set();
    }
    sentenceGroups[c.sentence].add(c.position);
  });
  
  for (const [sentence, positions] of Object.entries(sentenceGroups)) {
    if (positions.size === 2) {
      flexibility += 20;
    } else if (positions.size === 1) {
      flexibility += 5;
    }
  }
  
  const counts = {};
  hand.forEach(c => {
    counts[c.character] = (counts[c.character] || 0) + 1;
  });
  
  for (const [char, count] of Object.entries(counts)) {
    if (count === 2) {
      flexibility += 15;
    } else if (count >= 3) {
      flexibility += 25;
    }
  }
  
  return flexibility;
}

function calculateJinZhangValueOptimized(card, hand, player) {
  let value = 0;
  
  const tempHand = hand.filter(c => c.id !== card.id);
  
  const currentXiangTing = calculateXiangTingShu(hand, player.melds || []);
  
  const sentenceChars = getSentenceCharacters(card.sentence);
  
  for (const char of sentenceChars) {
    const testCard = createCardByCharacter(char);
    if (!testCard) continue;
    
    const testHand = [...tempHand, testCard];
    const tempPlayer = { ...player, hand: testHand, melds: player.melds || [] };
    
    const tingResult = checkTing(tempPlayer);
    const huResult = checkHu(tempPlayer);
    const newXiangTing = calculateXiangTingShu(testHand, player.melds || []);
    
    if (tingResult.isTing || huResult.canHu) {
      const inHand = tempHand.filter(c => c.character === char).length;
      const inDiscards = gameState.players.reduce((sum, p) => 
        sum + p.discards.filter(c => c.character === char).length, 0);
      const remaining = 4 - inHand - inDiscards;
      
      if (remaining > 0) {
        if (huResult.canHu) {
          value += remaining * 20;
        } else if (tingResult.isTing) {
          value += remaining * 15;
        }
      }
    }
    
    if (newXiangTing < currentXiangTing) {
      const inHand = tempHand.filter(c => c.character === char).length;
      const inDiscards = gameState.players.reduce((sum, p) => 
        sum + p.discards.filter(c => c.character === char).length, 0);
      const remaining = 4 - inHand - inDiscards;
      
      if (remaining > 0) {
        value += remaining * 8;
      }
    }
  }
  
  return value;
}

function optimizeTingWidthOptimized(card, hand, player) {
  let score = 0;
  
  const tempHand = hand.filter(c => c.id !== card.id);
  const tempPlayer = { ...player, hand: tempHand };
  
  const tingResult = checkTing(tempPlayer);
  
  if (tingResult.isTing && tingResult.tingCards) {
    const tingCount = tingResult.tingCards.length;
    
    score += tingCount * 80;
    
    let totalRemaining = 0;
    let highValueTingCount = 0;
    
    for (const tingChar of tingResult.tingCards) {
      const inHand = tempHand.filter(c => c.character === tingChar).length;
      const inDiscards = gameState.players.reduce((sum, p) => 
        sum + p.discards.filter(c => c.character === tingChar).length, 0);
      const inMelds = gameState.players.reduce((sum, p) => 
        sum + (p.melds || []).reduce((mSum, m) => 
          mSum + m.cards.filter(c => c.character === tingChar).length, 0), 0);
      const remaining = 4 - inHand - inDiscards - inMelds;
      totalRemaining += remaining;
      
      if (tingChar === '上' || tingChar === '福') {
        highValueTingCount++;
      }
    }
    
    score += totalRemaining * 30;
    score += highValueTingCount * 50;
    
    if (tingCount >= 6) {
      score += 300;
    } else if (tingCount >= 4) {
      score += 180;
    } else if (tingCount >= 3) {
      score += 120;
    } else if (tingCount >= 2) {
      score += 60;
    }
    
    const currentTingResult = checkTing({ hand, melds: player.melds || [] });
    if (currentTingResult.isTing && currentTingResult.tingCards) {
      const currentTingCount = currentTingResult.tingCards.length;
      if (tingCount > currentTingCount) {
        score += (tingCount - currentTingCount) * 100;
      }
    }
  }
  
  return score;
}

// 听牌预测 - 模拟出牌后能否听牌
function predictTingAfterDiscard(card, hand, player) {
  const tempHand = hand.filter(c => c.id !== card.id);
  const tempPlayer = { ...player, hand: tempHand, melds: player.melds || [] };
  
  const tingResult = checkTing(tempPlayer);
  
  return {
    canTing: tingResult.isTing,
    tingCount: tingResult.tingCards ? tingResult.tingCards.length : 0,
    tingCards: tingResult.tingCards || []
  };
}

function calculateJinZhangValue(card, hand, player) {
  let value = 0;
  
  const tempHand = hand.filter(c => c.id !== card.id);
  
  let usefulCards = 0;
  let totalRemaining = 0;
  
  const currentXiangTing = calculateXiangTingShu(hand, player.melds || []);
  
  for (const char of ALL_CHARACTERS) {
    const testCard = createCardByCharacter(char);
    if (!testCard) continue;
    
    const testHand = [...tempHand, testCard];
    const tempPlayer = { ...player, hand: testHand, melds: player.melds || [] };
    
    const tingResult = checkTing(tempPlayer);
    const huResult = checkHu(tempPlayer);
    const newXiangTing = calculateXiangTingShu(testHand, player.melds || []);
    
    if (tingResult.isTing || huResult.canHu) {
      const inHand = tempHand.filter(c => c.character === char).length;
      const inDiscards = gameState.players.reduce((sum, p) => 
        sum + p.discards.filter(c => c.character === char).length, 0);
      const remaining = 4 - inHand - inDiscards;
      
      if (remaining > 0) {
        usefulCards++;
        totalRemaining += remaining;
        
        if (huResult.canHu) {
          value += remaining * 15;
        } else if (tingResult.isTing) {
          value += remaining * 10;
        }
      }
    }
    
    if (newXiangTing < currentXiangTing) {
      const inHand = tempHand.filter(c => c.character === char).length;
      const inDiscards = gameState.players.reduce((sum, p) => 
        sum + p.discards.filter(c => c.character === char).length, 0);
      const remaining = 4 - inHand - inDiscards;
      
      if (remaining > 0) {
        value += remaining * 5;
      }
    }
  }
  
  value += usefulCards * 3;
  value += totalRemaining * 2;
  
  return value;
}

// 危险牌检查 - 检查出牌是否会被点炮
function checkDangerousCard(card, hand, player) {
  let dangerScore = 0;
  
  const opponents = gameState.players.filter((p, i) => i !== gameState.currentPlayerIndex);
  
  for (const opponent of opponents) {
    // 检查对手是否听牌
    const opponentWithMelds = { ...opponent, melds: opponent.melds || [] };
    const tingResult = checkTing(opponentWithMelds);
    if (tingResult.isTing && tingResult.tingCards) {
      // 如果对手听牌，检查这张牌是否在听牌范围内
      if (tingResult.tingCards.includes(card.character)) {
        // 这张牌会让对手胡牌，给予严重惩罚
        dangerScore -= 500; // 基础惩罚
        
        // 根据对手胡牌类型调整惩罚
        const huResult = checkHu(opponentWithMelds, card, true);
        if (huResult.canHu) {
          const multiplier = huResult.huType.multiplier.dianpao || 1;
          dangerScore -= multiplier * 50; // 根据胡牌倍数增加惩罚
          console.log(`危险: ${card.character} 会让${opponent.name}胡牌(${huResult.huType.name})`);
        }
      }
    }
    
    // 检查对手组合牌情况
    const opponentMelds = opponent.melds || [];
    for (const meld of opponentMelds) {
      if (meld.type === 'triplet' || meld.type === 'quartet') {
        const meldChar = meld.cards[0].character;
        // 如果对手有坎或招，且这张牌和坎/招同组，增加风险
        if (card.sentence === meld.cards[0].sentence) {
          dangerScore -= 30;
        }
      }
    }
    
    // 检查对手近期出牌模式
    const recentDiscards = opponent.discards.slice(-5);
    const sameSentenceDiscards = recentDiscards.filter(c => c.sentence === card.sentence);
    if (sameSentenceDiscards.length === 0) {
      // 对手近期没有出过同组的牌，可能正在凑这组
      dangerScore -= 20;
    }
  }
  
  return dangerScore;
}

// 安全牌分析 - 更精准判断哪张牌绝对安全
function analyzeCardSafety(card, hand, player) {
  let safetyScore = 0;
  
  const sameCount = hand.filter(c => c.character === card.character).length;
  const inDiscards = gameState.players.reduce((sum, p) => 
    sum + p.discards.filter(c => c.character === card.character).length, 0);
  const remaining = 4 - sameCount - inDiscards;
  
  if (remaining === 0) {
    safetyScore += 150;
    return safetyScore;
  }
  
  if (remaining === 1) {
    safetyScore += 80;
  }
  
  const opponents = gameState.players.filter((p, i) => i !== gameState.currentPlayerIndex);
  
  for (const opponent of opponents) {
    if (opponent.isTing) {
      const opponentDiscards = opponent.discards;
      const sameSentenceDiscards = opponentDiscards.filter(c => c.sentence === card.sentence);
      
      if (sameSentenceDiscards.length >= 2) {
        safetyScore += 30;
      }
      
      if (opponentDiscards.some(c => c.character === card.character)) {
        safetyScore += 50;
      }
      
      const sentenceCards = opponentDiscards.filter(c => c.sentence === card.sentence);
      const positions = new Set(sentenceCards.map(c => c.position));
      if (positions.has(card.position)) {
        safetyScore += 20;
      }
    }
  }
  
  const recentGlobalDiscards = gameState.players.flatMap(p => p.discards.slice(-3));
  if (recentGlobalDiscards.some(c => c.character === card.character)) {
    safetyScore += 25;
  }
  
  return safetyScore;
}

// 对手手牌预测 - 根据出牌历史推测对手手牌牌型
function predictOpponentHands(card) {
  let score = 0;
  
  const opponents = gameState.players.filter((p, i) => i !== gameState.currentPlayerIndex);
  
  for (const opponent of opponents) {
    const discards = opponent.discards;
    const melds = opponent.melds;
    
    const discardSentenceCounts = {};
    discards.forEach(c => {
      discardSentenceCounts[c.sentence] = (discardSentenceCounts[c.sentence] || 0) + 1;
    });
    
    if (discardSentenceCounts[card.sentence] >= 3) {
      score += 40;
    } else if (discardSentenceCounts[card.sentence] >= 2) {
      score += 20;
    }
    
    const meldSentences = new Set(melds.flatMap(m => m.cards.map(c => c.sentence)));
    if (meldSentences.has(card.sentence)) {
      score += 15;
    }
    
    const discardChars = discards.map(c => c.character);
    if (discardChars.includes(card.character)) {
      score += 30;
    }
    
    const sameCharDiscards = discards.filter(c => c.character === card.character).length;
    if (sameCharDiscards >= 2) {
      score += 50;
    }
    
    if (opponent.isTing) {
      const safeChars = new Set(discards.slice(-8).map(c => c.character));
      if (safeChars.has(card.character)) {
        score += 60;
      }
    }
  }
  
  return score;
}

function optimizeTingWidth(card, hand, player) {
  let score = 0;
  
  const tempHand = hand.filter(c => c.id !== card.id);
  const tempPlayer = { ...player, hand: tempHand };
  
  const tingResult = checkTing(tempPlayer);
  
  if (tingResult.isTing && tingResult.tingCards) {
    const tingCount = tingResult.tingCards.length;
    
    score += tingCount * 50;
    
    let totalRemaining = 0;
    let highValueTingCount = 0;
    
    for (const tingChar of tingResult.tingCards) {
      const inHand = tempHand.filter(c => c.character === tingChar).length;
      const inDiscards = gameState.players.reduce((sum, p) => 
        sum + p.discards.filter(c => c.character === tingChar).length, 0);
      const inMelds = gameState.players.reduce((sum, p) => 
        sum + (p.melds || []).reduce((mSum, m) => 
          mSum + m.cards.filter(c => c.character === tingChar).length, 0), 0);
      const remaining = 4 - inHand - inDiscards - inMelds;
      totalRemaining += remaining;
      
      if (tingChar === '上' || tingChar === '福') {
        highValueTingCount++;
      }
    }
    
    score += totalRemaining * 20;
    score += highValueTingCount * 30;
    
    if (tingCount >= 6) {
      score += 200;
    } else if (tingCount >= 4) {
      score += 120;
    } else if (tingCount >= 3) {
      score += 80;
    } else if (tingCount >= 2) {
      score += 40;
    }
    
    const currentTingResult = checkTing({ hand, melds: player.melds || [] });
    if (currentTingResult.isTing && currentTingResult.tingCards) {
      const currentTingCount = currentTingResult.tingCards.length;
      if (tingCount > currentTingCount) {
        score += (tingCount - currentTingCount) * 60;
      }
    }
  }
  
  return score;
}

// 旧函数保留兼容
function evaluateCard(card, hand) {
  return evaluateCardMedium(card, hand, {});
}

function discardCard(playerIndex, cardIndex) {
  if (gameState.isDealing) {
    console.log('发牌中，跳过出牌');
    return;
  }
  
  clearCaches();
  
  const player = gameState.players[playerIndex];
  const card = player.hand[cardIndex];
  
  console.log('出牌:', card.character);
  
  player.hand.splice(cardIndex, 1);
  player.discards.push(card);
  
  gameState.lastDiscardedCard = card;
  gameState.lastDiscardPlayerIndex = playerIndex;
  gameState.lastDrawnCard = null;
  gameState.lastDrawnPlayerIndex = -1;
  
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
  
  setTimeout(() => {
    checkResponses();
  }, 800);
}

function animateDiscardCard(playerIndex, card) {
  // 微信横屏模式下跳过动画，直接显示
  const isWechatLandscape = document.documentElement.classList.contains('wechat-landscape');
  if (isWechatLandscape) {
    showDiscardedCard(playerIndex, card);
    return;
  }
  
  const playerPos = getPlayerPosition(playerIndex);
  const startX = playerPos.x;
  const startY = playerPos.y;
  
  const centerPos = getCenterPosition();
  const targetX = centerPos.x;
  const targetY = centerPos.y;
  
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
  // 微信横屏模式下跳过动画，直接执行回调
  const isWechatLandscape = document.documentElement.classList.contains('wechat-landscape');
  if (isWechatLandscape) {
    if (callback) callback();
    return;
  }
  
  const centerPos = getCenterPosition();
  const discardX = centerPos.x;
  const discardY = centerPos.y;
  
  const actionButtons = document.getElementById('actionButtons');
  const actionRect = actionButtons ? actionButtons.getBoundingClientRect() : { left: window.innerWidth / 2 - 100, top: window.innerHeight - 100, width: 200, height: 44 };
  
  const meldCenterX = actionRect.left + actionRect.width / 2;
  const meldCenterY = actionRect.top - 30;
  
  const w = window.innerWidth;
  const h = window.innerHeight;
  const centerX = w / 2;
  const centerY = h / 2;
  
  let targetX, targetY;
  if (playerIndex === 0) {
    targetX = 10;
    targetY = centerY + 50;
  } else if (playerIndex === 1) {
    targetX = centerX - 100;
    targetY = h - 60;
  } else {
    targetX = w - 110;
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
  
  let callbackCalled = false;
  const safeCallback = () => {
    if (callbackCalled) return;
    callbackCalled = true;
    if (callback) callback();
  };
  
  setTimeout(() => {
    meldContainer.style.transition = 'all 0.5s ease-in-out';
    meldContainer.style.left = targetX + 'px';
    meldContainer.style.top = targetY + 'px';
  }, 900);
  
  setTimeout(() => {
    meldContainer.remove();
    safeCallback();
  }, 1500);
  
  setTimeout(() => {
    safeCallback();
  }, 3000);
}

function animateDrawCard(playerIndex, card, callback) {
  // 微信横屏模式下跳过动画，直接执行回调
  const isWechatLandscape = document.documentElement.classList.contains('wechat-landscape');
  if (isWechatLandscape) {
    if (callback) callback();
    return;
  }
  
  const deckPos = getDeckPosition();
  const startX = deckPos.x;
  const startY = deckPos.y;
  
  const playerPos = getPlayerPosition(playerIndex);
  const targetX = playerPos.x;
  const targetY = playerPos.y;
  
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
  
  let callbackCalled = false;
  const safeCallback = () => {
    if (callbackCalled) return;
    callbackCalled = true;
    if (callback) callback();
  };
  
  setTimeout(() => {
    flyingCard.style.transition = 'all 1s ease-out';
    flyingCard.style.left = targetX + 'px';
    flyingCard.style.top = targetY + 'px';
  }, 1000);
  
  setTimeout(() => {
    flyingCard.remove();
    safeCallback();
  }, 2050);
  
  setTimeout(() => {
    safeCallback();
  }, 3500);
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
      // AI玩家可以招，使用智能决策
      const player = gameState.players[zhaoResponses[0].playerIndex];
      if (shouldAIZhao(player, gameState.lastDiscardedCard)) {
        performZhao(zhaoResponses[0].playerIndex);
        return;
      } else {
        console.log('AI玩家决定不招，继续检查碰牌');
      }
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
      // AI玩家可以碰，使用智能决策
      const player = gameState.players[pengResponses[0].playerIndex];
      if (shouldAIPeng(player, gameState.lastDiscardedCard)) {
        performPeng(pengResponses[0].playerIndex);
        return;
      } else {
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
      // AI玩家可以吃，使用智能决策
      const player = gameState.players[chiResponses[0].playerIndex];
      if (shouldAIChi(player, gameState.lastDiscardedCard)) {
        performChi(chiResponses[0].playerIndex);
        return;
      } else {
        console.log('AI玩家决定不吃，进入下一玩家');
      }
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
    gameState.actionCancelled = false;
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
  return count >= 3;
}

function checkHu(player, extraCard = null, isDianPao = false) {
  console.log('=== checkHu 被调用 ===');
  console.log('玩家:', player.name, '胡牌:', extraCard?.character, 'isDianPao:', isDianPao);
  console.log('手牌:', player.hand.map(c => c.character).join(''));
  console.log('melds数量:', player.melds?.length || 0);
  
  const playerHand = player.hand || [];
  const playerMelds = player.melds || [];
  // hand 不包含 extraCard，extraCard 作为 huCard 参数传递给 calculateHuCount
  const hand = [...playerHand];
  const huCount = calculateHuCount(hand, playerMelds, extraCard, isDianPao);

  console.log('计算胡数:', huCount);
  
  // 检测胡牌类型时需要包含 extraCard
  const fullHand = extraCard ? [...playerHand, extraCard] : [...playerHand];
  const huType = detectHuType(fullHand, playerMelds, huCount);
  
  console.log('检测胡牌类型:', huType.type, huType.name);
  
  // 特殊胡牌类型不需要满足胡数条件
  const specialHuTypes = ['kuHu', 'qingKuHu', 'kuTaiHu', 'kuChongTaiHu', 'kuChongTaiKa', 'qingKuTaiKa', 'qingKuTaiHu', 'qingKuChongTaiHu', 'qingKuChongTaiKa', 'hongYuan3Jing', 'hongYuan4Jing', 'hongYuan5Jing', 'hongYuan6Jing', 'heiYuan', 'shiDui'];
  const isSpecialHu = specialHuTypes.includes(huType.type);
  
  const canHu = (isSpecialHu || huCount >= 11) && huType.type !== 'none';
  console.log('能否胡牌:', canHu, 'isSpecialHu:', isSpecialHu);
  
  return {
    canHu,
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
  hand = hand || [];
  melds = melds || [];
  
  console.log('====== detectHuType 开始 ======');
  console.log('手牌:', hand.map(c => c.character).join(''));
  console.log('melds:', melds.map(m => m.type).join(','));
  console.log('传入胡数:', huCount);
  
  const actualHuCount = huCount;
  const hasChi = melds.some(m => m.type === 'sequence');
  const hasPeng = melds.some(m => m.type === 'triplet');
  const hasZhao = melds.some(m => m.type === 'quartet');
  
  console.log('hasChi:', hasChi, 'hasPeng:', hasPeng, 'hasZhao:', hasZhao);
  
  const effectiveHasZhao = hasZhao && !isZhaoUsedInSentence(hand, melds);
  
  const counts = {};
  for (const card of hand) {
    counts[card.character] = (counts[card.character] || 0) + 1;
  }
  console.log('手牌字数统计:', JSON.stringify(counts));
  
  const allCards = [...hand, ...melds.flatMap(m => m.cards)];
  const shangCount = allCards.filter(c => c.character === '上').length;
  const fuCount = allCards.filter(c => c.character === '福').length;
  const shangFuCount = shangCount + fuCount;
  const hasShangFu = shangFuCount > 0;
  
  console.log('上数量:', shangCount, '福数量:', fuCount, 'hasShangFu:', hasShangFu);
  
  const hasShangDaRen = allCards.some(c => c.sentence === 1);
  const hasFuLuShou = allCards.some(c => c.sentence === 8);
  
  const isKuHu = checkKuHu(hand, melds, effectiveHasZhao);
  const isQingKuHu = checkQingKuHu(hand, melds, effectiveHasZhao);
  const isShiDui = checkShiDui(hand, melds);
  const isHeiYuan = checkHeiYuan(hand, melds, effectiveHasZhao);
  const hongYuanJing = checkHongYuan(hand, melds, effectiveHasZhao);
  const isQingHu = checkQingHu(hand, melds, actualHuCount);
  
  console.log('胡牌类型检测结果:');
  console.log('  isKuHu:', isKuHu);
  console.log('  isQingKuHu:', isQingKuHu);
  console.log('  isShiDui:', isShiDui);
  console.log('  isHeiYuan:', isHeiYuan);
  console.log('  hongYuanJing:', hongYuanJing);
  console.log('  isQingHu:', isQingHu);
  
  const qingKuChongTaiResult = checkQingKuChongTai(hand, melds);
  console.log('  qingKuChongTaiResult:', qingKuChongTaiResult);
  
  if (qingKuChongTaiResult === 'qingKuChongTaiKa') {
    console.log('>>> 返回: 清枯重台卡');
    return { type: 'qingKuChongTaiKa', name: '清枯重台卡', multiplier: { dianpao: 14, zimo: 15 } };
  }
  
  if (qingKuChongTaiResult === 'qingKuChongTaiHu') {
    console.log('>>> 返回: 清枯重台胡');
    return { type: 'qingKuChongTaiHu', name: '清枯重台胡', multiplier: { dianpao: 13, zimo: 14 } };
  }
  
  if (isQingKuHu && actualHuCount >= 23 && actualHuCount <= 32) {
    console.log('>>> 返回: 清枯台胡, 胡数:', actualHuCount);
    return { type: 'qingKuTaiHu', name: '清枯台胡', multiplier: { dianpao: 7, zimo: 8 } };
  }
  
  if (isKuHu && actualHuCount === 33) {
    console.log('>>> 返回: 枯重台卡, 胡数:', actualHuCount);
    return { type: 'kuChongTaiKa', name: '枯重台卡', multiplier: { dianpao: 12, zimo: 13 } };
  }
  
  if (isKuHu && actualHuCount >= 34) {
    console.log('>>> 返回: 枯重台胡, 胡数:', actualHuCount);
    return { type: 'kuChongTaiHu', name: '枯重台胡', multiplier: { dianpao: 11, zimo: 12 } };
  }
  
  if (isKuHu && actualHuCount >= 23 && actualHuCount <= 32) {
    console.log('>>> 返回: 枯台胡, 胡数:', actualHuCount);
    return { type: 'kuTaiHu', name: '枯台胡', multiplier: { dianpao: 6, zimo: 7 } };
  }
  
  if (isQingKuHu && actualHuCount === 22) {
    console.log('>>> 返回: 清枯台卡, 胡数:', actualHuCount);
    return { type: 'qingKuTaiKa', name: '清枯台卡', multiplier: { dianpao: 8, zimo: 9 } };
  }
  
  if (isQingKuHu) {
    console.log('>>> 返回: 清枯胡, 胡数:', actualHuCount);
    return { type: 'qingKuHu', name: '清枯胡', multiplier: { dianpao: 6, zimo: 7 } };
  }
  
  if (isKuHu) {
    console.log('>>> 返回: 枯胡, 胡数:', actualHuCount);
    return { type: 'kuHu', name: '枯胡', multiplier: { dianpao: 5, zimo: 6 } };
  }
  
  if (isShiDui) {
    console.log('>>> 返回: 十对');
    return { type: 'shiDui', name: '十对', multiplier: { dianpao: 10, zimo: 11 } };
  }
  
  if (hongYuanJing > 0) {
    console.log('>>> 返回: 红元', hongYuanJing, '精');
    return { type: `hongYuan${hongYuanJing}Jing`, name: `红元${hongYuanJing}精`, multiplier: { dianpao: hongYuanJing, zimo: hongYuanJing + 1 } };
  }
  
  if (isHeiYuan) {
    console.log('>>> 返回: 黑元');
    return { type: 'heiYuan', name: '黑元', multiplier: { dianpao: 4, zimo: 5 } };
  }
  
  // 检查清胡条件（除了胡数范围）
  const qingHuConditions = checkQingHuConditions(hand, melds);
  console.log('  qingHuConditions:', qingHuConditions);
  
  // 清卡胡：清胡条件（除了胡数范围）都满足 + 胡数正好11胡
  if (qingHuConditions && actualHuCount === 11) {
    console.log('>>> 返回: 清卡胡');
    return { type: 'qingKaHu', name: '清卡胡', multiplier: { dianpao: 2, zimo: 3 } };
  }
  
  // 清胡：清胡条件全部满足（包括胡数在11-21之间）
  if (isQingHu) {
    console.log('>>> 返回: 清胡');
    return { type: 'qingHu', name: '清胡', multiplier: { dianpao: 1, zimo: 2 } };
  }
  
  const meetsBasicCondition = checkBasicHuCondition(hand, melds);
  console.log('detectHuType - 胡数:', actualHuCount, '基本条件:', meetsBasicCondition, '手牌数:', hand.length);
  
  if (!meetsBasicCondition) {
    console.log('>>> 返回: 无 (不满足基本条件)');
    return { type: 'none', name: '无', multiplier: { dianpao: 0, zimo: 0 } };
  }
  
  // 添加胡数检查：如果胡数不足11胡，不能胡牌
  if (actualHuCount < 11) {
    console.log('>>> 返回: 无 (胡数不足)');
    return { type: 'none', name: '无', multiplier: { dianpao: 0, zimo: 0 } };
  }
  
  if (actualHuCount === 11) {
    console.log('>>> 返回: 卡胡');
    return { type: 'kaHu', name: '卡胡', multiplier: { dianpao: 1, zimo: 2 } };
  }
  if (actualHuCount >= 12 && actualHuCount <= 21) {
    console.log('>>> 返回: 普通胡, 胡数:', actualHuCount);
    return { type: 'puTongHu', name: '普通胡', multiplier: { dianpao: 0, zimo: 1 } };
  }
  if (actualHuCount === 22) {
    console.log('>>> 返回: 台卡, 胡数:', actualHuCount);
    return { type: 'taiKa', name: '台卡', multiplier: { dianpao: 2, zimo: 3 } };
  }
  if (actualHuCount >= 23 && actualHuCount <= 32) {
    console.log('>>> 返回: 台胡, 胡数:', actualHuCount);
    return { type: 'taiHu', name: '台胡', multiplier: { dianpao: 1, zimo: 2 } };
  }
  if (actualHuCount === 33) {
    console.log('>>> 返回: 重台卡, 胡数:', actualHuCount);
    return { type: 'chongTaiKa', name: '重台卡', multiplier: { dianpao: 7, zimo: 8 } };
  }
  if (actualHuCount >= 34) {
    console.log('>>> 返回: 重台胡, 胡数:', actualHuCount);
    return { type: 'chongTaiHu', name: '重台胡', multiplier: { dianpao: 6, zimo: 7 } };
  }
  
  console.log('>>> 返回: 无 (默认)');
  return { type: 'none', name: '无', multiplier: { dianpao: 0, zimo: 0 } };
}

function checkBasicHuCondition(hand, melds) {
  // 计算melds中的组合牌
  let meldSentenceCount = 0;
  let meldKanCount = 0;
  let meldZhaoCount = 0;
  
  for (const meld of melds) {
    if (meld.type === 'sequence') {
      meldSentenceCount++;
    } else if (meld.type === 'triplet') {
      meldKanCount++;
    } else if (meld.type === 'quartet') {
      meldZhaoCount++;
    }
  }
  
  const meldGroups = meldSentenceCount + meldKanCount + meldZhaoCount;
  
  // 计算melds中使用的牌数
  let meldCardsCount = 0;
  for (const meld of melds) {
    if (meld.type === 'quartet') {
      meldCardsCount += 4;
    } else {
      meldCardsCount += 3;
    }
  }
  
  // 胡牌条件：6个组合 + 1对/靠 = 20张牌
  // 需要的组合数 = 6 - melds中的组合数
  const neededGroups = 6 - meldGroups;
  
  // 手牌中需要组成 neededGroups 个组合 + 1对
  // 每个组合用3张牌，1对用2张牌
  const expectedCards = neededGroups * 3 + 2;
  
  console.log('checkBasicHuCondition - melds组合数:', meldGroups, '需要组合数:', neededGroups, '手牌数:', hand.length, '期望手牌数:', expectedCards);
  
  // 如果手牌数不等于期望数，无法胡牌
  // 但如果是听牌检测，手牌可能多一张（摸牌后）
  // 所以允许手牌数比期望数多1张
  if (hand.length !== expectedCards && hand.length !== expectedCards + 1) {
    return false;
  }
  
  // 如果手牌数比期望数多1张，需要先出一张牌再检查
  if (hand.length === expectedCards + 1) {
    // 尝试出掉每一张牌，检查剩余牌能否胡牌
    for (let i = 0; i < hand.length; i++) {
      const remainingHand = hand.filter((c, idx) => idx !== i);
      if (checkRemainingCards(remainingHand, neededGroups)) {
        return true;
      }
    }
    return false;
  }
  
  // 递归检查手牌是否可以组成需要的组合+1对
  return checkRemainingCards(hand, neededGroups);
}

// 检查剩余牌是否可以组成指定数量的组合+1对
function checkRemainingCards(cards, neededGroups) {
  // 基本情况：不需要组合，检查是否是1对、靠
  if (neededGroups === 0) {
    if (cards.length === 2) {
      const [card1, card2] = cards;
      // 对子：2张相同
      if (card1.character === card2.character) {
        return true;
      }
      // 靠：2张同句不同位置
      if (card1.sentence === card2.sentence && card1.position !== card2.position) {
        return true;
      }
    }
    return false;
  }
  
  // 计算需要的牌数
  const neededCards = neededGroups * 3 + 2;
  
  // 如果牌数不等于期望数，可能是因为有招（招用4张牌算1个组合）
  // 招会导致牌数多1张：招用4张牌，但只算1个组合（3张牌的价值）
  // 所以如果有招，牌数 = neededCards + 1
  if (cards.length !== neededCards && cards.length !== neededCards + 1) {
    return false;
  }
  
  // 计算每种牌的数量
  const counts = {};
  for (const card of cards) {
    counts[card.character] = (counts[card.character] || 0) + 1;
  }
  
  const usedIds = new Set();
  
  // 如果牌数比期望多1张，说明可能有招
  if (cards.length === neededCards + 1) {
    // 尝试找招（同字4张）
    for (const [char, count] of Object.entries(counts)) {
      if (count >= 4) {
        // 找到一个招
        const zhaoCards = cards.filter(c => c.character === char).slice(0, 4);
        zhaoCards.forEach(c => usedIds.add(c.id));
        const remaining = cards.filter(c => !usedIds.has(c.id));
        
        // 招用4张牌算1个组合，剩余牌数应该是 (neededGroups - 1) * 3 + 2
        if (checkRemainingCards(remaining, neededGroups - 1)) {
          return true;
        }
        
        // 回溯
        zhaoCards.forEach(c => usedIds.delete(c.id));
      }
    }
  }
  
  // 尝试找坎（同字3张）
  for (const [char, count] of Object.entries(counts)) {
    if (count >= 3) {
      // 找到一个坎
      const kanCards = cards.filter(c => c.character === char).slice(0, 3);
      kanCards.forEach(c => usedIds.add(c.id));
      const remaining = cards.filter(c => !usedIds.has(c.id));
      
      if (checkRemainingCards(remaining, neededGroups - 1)) {
        return true;
      }
      
      // 回溯
      kanCards.forEach(c => usedIds.delete(c.id));
    }
  }
  
  // 尝试找句（同组不同位置3张）
  for (let sentence = 1; sentence <= 8; sentence++) {
    const sentenceCards = cards.filter(c => c.sentence === sentence && !usedIds.has(c.id));
    
    // 需要有位置0、1、2各至少一张
    const pos0Cards = sentenceCards.filter(c => c.position === 0);
    const pos1Cards = sentenceCards.filter(c => c.position === 1);
    const pos2Cards = sentenceCards.filter(c => c.position === 2);
    
    if (pos0Cards.length > 0 && pos1Cards.length > 0 && pos2Cards.length > 0) {
      // 找到一个句
      usedIds.add(pos0Cards[0].id);
      usedIds.add(pos1Cards[0].id);
      usedIds.add(pos2Cards[0].id);
      const remaining = cards.filter(c => !usedIds.has(c.id));
      
      if (checkRemainingCards(remaining, neededGroups - 1)) {
        return true;
      }
      
      // 回溯
      usedIds.delete(pos0Cards[0].id);
      usedIds.delete(pos1Cards[0].id);
      usedIds.delete(pos2Cards[0].id);
    }
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
    if (count >= 4) {
      return false;
    }
  }
  
  let kanCount = 0;
  let duiCount = 0;
  let zhaoCount = 0;
  
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
    } else if (meld.type === 'quartet') {
      zhaoCount++;
    }
  }
  
  return (kanCount + zhaoCount) === 6 && duiCount === 1;
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
    if (count >= 4) {
      return false;
    }
  }
  
  let kanCount = 0;
  let duiCount = 0;
  let zhaoCount = 0;
  
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
    } else if (meld.type === 'quartet') {
      zhaoCount++;
    }
  }
  
  return (kanCount + zhaoCount) === 6 && duiCount === 1;
}

function checkShiDui(hand, melds) {
  melds = melds || [];
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
  
  // melds中的碰和招也算对子
  for (const meld of melds) {
    if (meld.type === 'triplet') {
      duiCount += 1; // 碰算1对
    } else if (meld.type === 'quartet') {
      duiCount += 2; // 招算2对
    }
  }
  
  return duiCount === 10;
}

function checkHeiYuan(hand, melds, effectiveHasZhao) {
  const hasPeng = melds.some(m => m.type === 'triplet');
  const hasZhao = melds.some(m => m.type === 'quartet');
  
  // 黑元不能有碰或有效招
  if (hasPeng || (hasZhao && effectiveHasZhao)) {
    return false;
  }
  
  // 黑元条件：6句 + 1靠（不能有上大人或福禄寿句子）
  const allCards = [...hand, ...melds.flatMap(m => m.cards)];
  
  // 不能有上大人或福禄寿句子
  const hasShangDaRen = allCards.some(c => c.sentence === 1);
  const hasFuLuShou = allCards.some(c => c.sentence === 8);
  
  if (hasShangDaRen || hasFuLuShou) {
    return false;
  }
  
  // 不能有上或福
  const shangCount = allCards.filter(c => c.character === '上').length;
  const fuCount = allCards.filter(c => c.character === '福').length;
  
  if (shangCount > 0 || fuCount > 0) {
    return false;
  }
  
  // 检查是否满足6句 + 1靠
  return checkSentencePattern(hand, melds);
}

function checkSentencePattern(hand, melds) {
  const cards = [...hand];
  const usedCardIds = new Set();
  
  // 计算melds中的句数
  let meldSentenceCount = 0;
  for (const meld of melds) {
    if (meld.type === 'sequence') {
      meldSentenceCount++;
    }
  }
  
  // 手牌中需要组成 (6 - meldSentenceCount) 个句 + 1靠
  const neededSentences = 6 - meldSentenceCount;
  
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
      }
    }
  }
  
  const remainingCards = cards.filter(c => !usedCardIds.has(c.id));
  
  // 计算手牌中组成的句数
  const handSentenceCount = (cards.length - remainingCards.length) / 3;
  
  // 检查是否满足需要的句数 + 1靠
  if (handSentenceCount === neededSentences && remainingCards.length === 2) {
    const [card1, card2] = remainingCards;
    
    // 靠：2张同句不同位置
    if (card1.sentence === card2.sentence && card1.position !== card2.position) {
      return true;
    }
  }
  
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
  
  let shangDaRenSentenceCount = 0;
  let fuLuShouSentenceCount = 0;
  let totalSentenceCount = 0;
  
  for (const meld of melds) {
    if (meld.type === 'sequence') {
      totalSentenceCount++;
      const sentence = meld.cards[0].sentence;
      if (sentence === 1) shangDaRenSentenceCount++;
      if (sentence === 8) fuLuShouSentenceCount++;
    }
  }
  
  const usedCardIds = new Set();
  
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
        totalSentenceCount++;
        
        if (sentence === 1) shangDaRenSentenceCount++;
        if (sentence === 8) fuLuShouSentenceCount++;
      }
    }
  }
  
  const totalSpecialSentenceCount = shangDaRenSentenceCount + fuLuShouSentenceCount;
  
  if (totalSpecialSentenceCount < 2) return 0;
  
  const remainingCards = hand.filter(c => !usedCardIds.has(c.id));
  
  if (remainingCards.length !== 2) return 0;
  
  if (totalSentenceCount !== 6) return 0;
  const [card1, card2] = remainingCards;
  const isHalfKao = card1.sentence === card2.sentence && 
                    card1.position !== card2.position &&
                    card1.character !== card2.character;
  if (!isHalfKao) return 0;
  
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
  
  foundGroup = true;
  while (foundGroup) {
    foundGroup = false;
    
    const counts = {};
    const indices = {};
    
    for (let i = 0; i < cards.length; i++) {
      if (usedIndices.has(i)) continue;
      const char = cards[i].character;
      if (!counts[char]) {
        counts[char] = 0;
        indices[char] = [];
      }
      counts[char]++;
      indices[char].push(i);
    }
    
    for (const [char, count] of Object.entries(counts)) {
      if (count >= 3) {
        for (let j = 0; j < 3; j++) {
          usedIndices.add(indices[char][j]);
        }
        foundGroup = true;
        break;
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

function calculatePotentialHuGain(card, hand, melds) {
  let potentialGain = 0;
  
  if (card.character === '上' || card.character === '福') {
    potentialGain += 4;
  }
  
  const sameCount = hand.filter(c => c.character === card.character).length;
  if (sameCount === 1) {
    potentialGain += 0;
  } else if (sameCount === 2) {
    if (card.character === '上' || card.character === '福') {
      potentialGain += 4;
    }
  } else if (sameCount === 3) {
    if (card.character === '上' || card.character === '福') {
      potentialGain += 8;
    } else {
      potentialGain += 3;
    }
  }
  
  const sentenceCards = hand.filter(c => c.sentence === card.sentence);
  const positions = new Set(sentenceCards.map(c => c.position));
  positions.add(card.position);
  
  if (positions.size === 3) {
    if (card.sentence === 1 || card.sentence === 8) {
      potentialGain += 4;
    }
  } else if (positions.size === 2) {
    const missingPositions = [0, 1, 2].filter(p => !positions.has(p));
    if (missingPositions.length === 1) {
      potentialGain += 2;
    }
  }
  
  return potentialGain;
}

function calculateHuCount(hand, melds, huCard = null, isDianPao = false) {
  hand = hand || [];
  melds = melds || [];
  let hu = 0;
  
  // 组合牌胡数计算
  for (const meld of melds) {
    hu += meld.huValue;
    // console.log(`组合牌(${meld.type}): ${meld.huValue}胡`);
  }
  
  // 手牌胡数计算
  // 先对手牌所有的卡牌进行编号
  const cards = [...hand];
  if (huCard) cards.push(huCard);
  
  const usedCardIds = new Set();
  
  // console.log('=== 手牌胡数计算过程 ===');
  // console.log('手牌:', cards.map(c => c.character).join(''));
  if (isDianPao && huCard) {
    // console.log('点炮牌:', huCard.character);
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
          // console.log(`精句(${pos0Cards[0].character}${pos1Cards[0].character}${pos2Cards[0].character}): 4胡`);
        } else {
          // console.log(`句(${pos0Cards[0].character}${pos1Cards[0].character}${pos2Cards[0].character}): 0胡`);
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
        // console.log(`精招(${char}${count}张): 16胡`);
      } else {
        hu += 6;
        // console.log(`招(${char}${count}张): 6胡`);
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
      } else {
        // 点炮胡牌时，如果坎包含点炮牌，算2胡（组合牌）
        // 否则算3胡（手牌坎）
        const kanCards = remainingAfterZhao.filter(c => c.character === char);
        const containsHuCard = isDianPao && huCard && huCard.character === char;
        if (containsHuCard) {
          hu += 2;
        } else {
          hu += 3;
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
        // console.log(`金对(${char}${count}张): 8胡`);
      } else {
        // console.log(`对(${char}${count}张): 0胡`);
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
          // console.log(`精靠(${sentenceCards.map(c => c.character).join('')}): 4胡`);
        } else if (isDaRen || isLuShou) {
          // 银靠：大人、禄寿
          // console.log(`银靠(${sentenceCards.map(c => c.character).join('')}): 0胡`);
        } else {
          // 靠：其他
          // console.log(`靠(${sentenceCards.map(c => c.character).join('')}): 0胡`);
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
      // console.log(`精单(${card.character}): 4胡`);
    } else {
      // console.log(`单(${card.character}): 0胡`);
    }
  }
  
  // console.log(`总胡数: ${hu}胡`);
  // console.log('==================');
  
  return hu;
}

function performChi(playerIndex) {
  if (gameState.isDealing) return;
  clearCaches();
  
  const player = gameState.players[playerIndex];
  const card = gameState.lastDiscardedCard;
  
  if (!card) {
    console.error('performChi: 没有可吃的牌');
    return;
  }
  console.log(`=== 【${player.name}】吃牌 ===`);
  console.log('吃牌前手牌数:', player.hand.length);
  console.log('吃牌:', card.character);
  
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
  
  for (const c of chiCards) {
    if (c !== card) {
      const idx = player.hand.findIndex(h => h.id === c.id);
      if (idx !== -1) player.hand.splice(idx, 1);
    }
  }
  
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
  removeLastDiscard();
  gameState.lastDiscardedCard = null;
  gameState.currentPlayerIndex = playerIndex;
  gameState.waitingForResponse = false;
  gameState.skipDraw = true;
  gameState.canChi = false;
  gameState.canPeng = false;
  gameState.canZhao = false;
  gameState.canHu = false;
  
  if (player.type === 'human') {
    gameState.isMyTurn = true;
  } else {
    gameState.isMyTurn = false;
  }
  
  animateMeldCards(playerIndex, chiCards, 'chi', () => {
    console.log('吃牌后手牌数:', player.hand.length);
    console.log('组合牌数量:', player.melds.length);
    
    if (playerIndex === 1) {
      const tingBadge = document.getElementById('tingBadge');
      const zimoBadge = document.getElementById('zimoBadge');
      tingBadge.classList.add('hidden');
      zimoBadge.classList.add('hidden');
    }
    
    updateUI();
    updateCurrentPlayerUI();
    startCountdown();
    
    if (playerIndex === 1) {
      const tingBadge = document.getElementById('tingBadge');
      const zimoBadge = document.getElementById('zimoBadge');
      tingBadge.classList.add('hidden');
      zimoBadge.classList.add('hidden');
    }
    
    if (player.type !== 'human') {
      setTimeout(() => processAITurn(), 800 + Math.random() * 500);
    }
  });
}

function performPeng(playerIndex) {
  if (gameState.isDealing) return;
  clearCaches();
  
  const player = gameState.players[playerIndex];
  const card = gameState.lastDiscardedCard;
  
  if (!card) {
    console.error('performPeng: 没有可碰的牌');
    return;
  }
  console.log('碰牌前手牌数:', player.hand.length);
  console.log('碰牌:', card.character);
  
  playButtonSound('碰', playerIndex);
  
  const matchingCards = player.hand.filter(c => c.character === card.character).slice(0, 2);
  const pengCards = [card, ...matchingCards];
  
  for (const c of matchingCards) {
    const idx = player.hand.findIndex(h => h.id === c.id);
    if (idx !== -1) player.hand.splice(idx, 1);
  }
  
  const isSpecial = card.character === '上' || card.character === '福';
  player.melds.push({
    type: 'triplet',
    cards: pengCards,
    source: 'peng',
    huValue: isSpecial ? 12 : 2
  });
  
  player.isTing = false;
  removeLastDiscard();
  gameState.lastDiscardedCard = null;
  gameState.currentPlayerIndex = playerIndex;
  gameState.waitingForResponse = false;
  gameState.skipDraw = true;
  gameState.canChi = false;
  gameState.canPeng = false;
  gameState.canZhao = false;
  gameState.canHu = false;
  
  if (player.type === 'human') {
    gameState.isMyTurn = true;
  } else {
    gameState.isMyTurn = false;
  }
  
  animateMeldCards(playerIndex, pengCards, 'peng', () => {
    console.log('碰牌后手牌数:', player.hand.length);
    
    if (playerIndex === 1) {
      const tingBadge = document.getElementById('tingBadge');
      const zimoBadge = document.getElementById('zimoBadge');
      tingBadge.classList.add('hidden');
      zimoBadge.classList.add('hidden');
    }
    
    updateUI();
    updateCurrentPlayerUI();
    startCountdown();
    
    if (playerIndex === 1) {
      const tingBadge = document.getElementById('tingBadge');
      const zimoBadge = document.getElementById('zimoBadge');
      if (tingBadge) tingBadge.classList.add('hidden');
      if (zimoBadge) zimoBadge.classList.add('hidden');
    }
    
    if (player.type !== 'human') {
      setTimeout(() => processAITurn(), 800 + Math.random() * 500);
    }
  });
}

function performZhao(playerIndex, char = null) {
  if (gameState.isDealing) return;
  clearCaches();
  
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
    
    for (const c of matchingCards) {
      const idx = player.hand.findIndex(h => h.id === c.id);
      if (idx !== -1) player.hand.splice(idx, 1);
    }
    
    removeLastDiscard();
    gameState.lastDiscardedCard = null;
    
    const isSpecial = zhaoCards[0].character === '上' || zhaoCards[0].character === '福';
    player.melds.push({
      type: 'quartet',
      cards: zhaoCards,
      source: 'zhao',
      huValue: isSpecial ? 16 : 6
    });
    
    player.isTing = false;
    gameState.currentPlayerIndex = playerIndex;
    gameState.waitingForResponse = false;
    gameState.skipDraw = true;
    gameState.canChi = false;
    gameState.canPeng = false;
    gameState.canZhao = false;
    gameState.canHu = false;
    
    if (player.type === 'human') {
      gameState.isMyTurn = true;
    } else {
      gameState.isMyTurn = false;
    }
    
    animateMeldCards(playerIndex, zhaoCards, 'zhao', () => {
      finishZhao(playerIndex, player, zhaoCards);
    });
    return;
  }
  
  finishZhao(playerIndex, player, zhaoCards);
}

function finishZhao(playerIndex, player, zhaoCards) {
  console.log('招牌后手牌数:', player.hand.length);
  
  const alreadyAdded = player.melds.some(m => m.source === 'zhao' && m.cards.length === zhaoCards.length && m.cards[0].id === zhaoCards[0].id);
  if (!alreadyAdded) {
    const isSpecial = zhaoCards[0].character === '上' || zhaoCards[0].character === '福';
    player.melds.push({
      type: 'quartet',
      cards: zhaoCards,
      source: 'zhao',
      huValue: isSpecial ? 16 : 6
    });
  }
  
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
    // 设置补牌动画状态，防止提前出牌
    gameState.isDrawing = true;
    const drawnCard = gameState.deck.pop();
    updateDeckStack();
    
    animateDrawCard(playerIndex, drawnCard, () => {
      player.hand.push(drawnCard);
      player.hand = sortHand(player.hand);
      gameState.lastDrawnCard = drawnCard;
      gameState.isDrawing = false; // 补牌动画完成
      updateUI();
      
      // 检查是否可以继续招（手牌中有4张相同的牌）
      const handCounts = {};
      for (const card of player.hand) {
        handCounts[card.character] = (handCounts[card.character] || 0) + 1;
      }
      
      let canContinueZhao = false;
      let zhaoChar = null;
      for (const [char, count] of Object.entries(handCounts)) {
        if (count === 4) {
          canContinueZhao = true;
          zhaoChar = char;
          break;
        }
      }
      
      console.log('招牌补牌后检查 - 手牌中有4张相同的牌:', canContinueZhao, zhaoChar ? '字:' + zhaoChar : '');
      
      if (canContinueZhao && zhaoChar) {
        // 可以继续招
        console.log('可以继续招:', zhaoChar);
        performZhao(playerIndex, zhaoChar);
        return;
      }
      
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
    
    // 流局处理在 moveToNextPlayer 中统一处理
    // 直接调用 moveToNextPlayer，它会检查牌堆并处理流局
    moveToNextPlayer();
  }
}

function handleHu(playerIndex, method) {
  if (gameState.isDealing) return;
  if (gameState.isHandlingHu) {
    console.log('handleHu: 已经在处理胡牌，跳过重复调用');
    return;
  }
  gameState.isHandlingHu = true;
  
  clearCaches();
  
  console.log('=== handleHu 被调用 ===');
  console.log('玩家索引:', playerIndex, '胡牌方式:', method);
  
  stopCountdown();
  
  gameState.isMyTurn = false;
  gameState.waitingForResponse = false;
  gameState.selectedCardIndex = -1;
  gameState.canHu = false;  // 重置胡牌标志，防止重新显示听牌徽章
  
  const tingBadge = document.getElementById('tingBadge');
  const zimoBadge = document.getElementById('zimoBadge');
  if (tingBadge) tingBadge.classList.add('hidden');
  if (zimoBadge) zimoBadge.classList.add('hidden');
  
  const player = gameState.players[playerIndex];
  
  const huCard = method === 'dianpao' ? gameState.lastDiscardedCard : null;
  const isDianPao = method === 'dianpao';
  const huResult = checkHu(player, huCard, isDianPao);
  
  console.log('胡牌类型:', huResult.huType.name, '胡数:', huResult.huCount);
  
  // 播放胡牌语音
  // AI玩家: 播放"胡"/"自摸" + 间隔一秒 + 胡牌类型
  // 人类玩家: 只播放胡牌类型（点击按钮时已经播放了"胡"/"自摸"）
  
  if (player.type === 'ai') {
    // AI玩家：播放"胡"/"自摸" + 间隔一秒 + 胡牌类型
    if (method === 'zimo') {
      playButtonSound('自摸', playerIndex);
      setTimeout(() => {
        speakText(huResult.huType.name, playerIndex);
      }, 1000);
    } else {
      playButtonSound('胡', playerIndex);
      setTimeout(() => {
        speakText(huResult.huType.name, playerIndex);
      }, 1000);
    }
  } else {
    // 人类玩家：延迟播放胡牌类型（因为点击按钮时刚播放了"胡"/"自摸"）
    setTimeout(() => {
      speakText(huResult.huType.name, playerIndex);
    }, 800);
  }
  
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
      console.error('handleHu: 无效的点炮玩家索引', gameState.lastDiscardPlayerIndex);
      // 仍然记录胡牌信息
      const roundInfo = {
        roundNumber: gameState.roundNumber,
        winner: player.name,
        winnerIndex: playerIndex,
        huType: huResult.huType.name,
        method: '点炮',
        multiplier: displayMultiplier,
        score: 0,
        piaoScores: gameState.players.map(p => p.piao),
        isLiuJu: false,
        scoreChanges: [0, 0, 0],
        error: '无效的点炮玩家索引'
      };
      gameState.roundHistory.push(roundInfo);
      return;
    }
    const dianPaoPlayer = gameState.players[gameState.lastDiscardPlayerIndex];
    if (!dianPaoPlayer) {
      console.error('handleHu: 找不到点炮玩家');
      // 仍然记录胡牌信息
      const roundInfo = {
        roundNumber: gameState.roundNumber,
        winner: player.name,
        winnerIndex: playerIndex,
        huType: huResult.huType.name,
        method: '点炮',
        multiplier: displayMultiplier,
        score: 0,
        piaoScores: gameState.players.map(p => p.piao),
        isLiuJu: false,
        scoreChanges: [0, 0, 0],
        error: '找不到点炮玩家'
      };
      gameState.roundHistory.push(roundInfo);
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
  
  console.log('记录本局结果: 第', roundInfo.roundNumber, '局, 赢家:', roundInfo.winner, '胡牌类型:', roundInfo.huType);
  console.log('roundHistory 当前长度:', gameState.roundHistory.length);
  
  gameState.roundHistory.push(roundInfo);
  
  console.log('roundHistory 新长度:', gameState.roundHistory.length);
  
  if (playerIndex !== gameState.dealerIndex) {
    gameState.dealerIndex = (gameState.dealerIndex + 1) % 3;
    console.log('庄家轮换，新庄家索引:', gameState.dealerIndex);
  } else {
    console.log('庄家胡牌，庄家不变');
  }
  
  // 先更新UI（但不更新分数显示），然后显示胡牌弹窗
  updateUI();
  
  // 显示胡牌弹窗，传入旧分数用于动画
  showHuMessage(player, huResult, methodName, huTypeName, score, dianPaoPlayer, method, huCard, displayMultiplier, loserScores, scoresBefore);
}

function showHuMessage(player, huResult, methodName, huTypeName, score, dianPaoPlayer, method, huCard, multiplier, loserScores, scoresBefore) {
  // 隐藏听牌徽章和自摸徽章
  const tingBadge = document.getElementById('tingBadge');
  const zimoBadge = document.getElementById('zimoBadge');
  if (tingBadge) tingBadge.classList.add('hidden');
  if (zimoBadge) zimoBadge.classList.add('hidden');
  
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
  
  const playedCardsEl = document.getElementById('playedCards');
  if (playedCardsEl) playedCardsEl.style.display = 'none';
  
  // 触发分数变化动画（在弹窗显示后）
  if (scoresBefore) {
    setTimeout(() => {
      for (let i = 0; i < gameState.players.length; i++) {
        const scoreDiff = gameState.players[i].score - scoresBefore[i];
        if (scoreDiff !== 0) {
          animateScoreChange(i, gameState.players[i].score, scoresBefore[i]);
        }
      }
    }, 500);
  }
  
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
    <div style="text-align: center; padding: 20px; position: relative;">
      <div id="huCloseBtn" style="position: absolute; top: 10px; right: 10px; width: 32px; height: 32px; cursor: pointer; display: flex; align-items: center; justify-content: center; background: rgba(255,255,255,0.2); border-radius: 50%; transition: background 0.2s;" onmouseover="this.style.background='rgba(255,255,255,0.4)'" onmouseout="this.style.background='rgba(255,255,255,0.2)'">
        <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="#fff" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
          <line x1="18" y1="6" x2="6" y2="18"></line>
          <line x1="6" y1="6" x2="18" y2="18"></line>
        </svg>
      </div>
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
    const newConfirmBtn = confirmBtn.cloneNode(true);
    confirmBtn.parentNode.replaceChild(newConfirmBtn, confirmBtn);
    newConfirmBtn.addEventListener('click', closeHuMessage);
  }
  
  const closeBtn = document.getElementById('huCloseBtn');
  if (closeBtn) {
    const newCloseBtn = closeBtn.cloneNode(true);
    closeBtn.parentNode.replaceChild(newCloseBtn, closeBtn);
    newCloseBtn.addEventListener('click', closeHuMessage);
  }
  
  // 添加滑动关闭功能
  const dealingText = overlay.querySelector('.dealing-text');
  if (dealingText) {
    // 移除之前的滑动事件监听器，防止重复添加
    if (dealingText._swipeHandler) {
      dealingText.removeEventListener('touchstart', dealingText._swipeHandler.touchstart);
      dealingText.removeEventListener('touchmove', dealingText._swipeHandler.touchmove);
      dealingText.removeEventListener('touchend', dealingText._swipeHandler.touchend);
      dealingText.removeEventListener('mousedown', dealingText._swipeHandler.mousedown);
      dealingText.removeEventListener('mousemove', dealingText._swipeHandler.mousemove);
      dealingText.removeEventListener('mouseup', dealingText._swipeHandler.mouseup);
      dealingText.removeEventListener('mouseleave', dealingText._swipeHandler.mouseleave);
    }
    setupSwipeToClose(dealingText, closeHuMessage);
  }
  
  // 测试模式下自动2秒后关闭胡牌弹窗
  if (gameState.testMode) {
    setTimeout(() => {
      if (overlay.style.display !== 'none') {
        closeHuMessage();
      }
    }, 2000);
  }
}

function closeHuMessage() {
  if (gameState.isClosingHuMessage) {
    console.log('closeHuMessage: 已经在关闭中，跳过');
    return;
  }
  gameState.isClosingHuMessage = true;
  console.log('closeHuMessage: 开始关闭');
  
  gameState.isHandlingHu = false;
  
  const overlay = document.getElementById('dealingOverlay');
  const mask = document.getElementById('dealingMask');
  
  if (overlay) {
    overlay.style.display = 'none';
    overlay.classList.add('hidden');
    const dealingText = overlay.querySelector('.dealing-text');
    if (dealingText) dealingText.innerHTML = '';
  }
  if (mask) {
    mask.style.display = 'none';
    mask.classList.add('hidden');
  }
  
  const playedCardsEl = document.getElementById('playedCards');
  if (playedCardsEl) playedCardsEl.style.display = '';
  
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
  
  updateHandCount('player1HandCount', 0);
  updateHandCount('myHandCount', 0);
  updateHandCount('player2HandCount', 0);
  
  // 更新分数显示（不需要动画，直接更新）
  const scoreIds = ['player1Score', 'myScore', 'player2Score'];
  for (let i = 0; i < 3; i++) {
    const scoreEl = document.getElementById(scoreIds[i]);
    if (scoreEl) scoreEl.textContent = gameState.players[i].score;
  }
  
  const huBadge = document.getElementById('myHuBadge');
  if (huBadge) huBadge.classList.add('hidden');
  
  updateHuBadgeDisplay();
  
  const tingBadge = document.getElementById('tingBadge');
  tingBadge.classList.add('hidden');
  
  console.log('当前局数:', gameState.roundNumber);
  
  if (gameState.roundNumber >= 8) {
    console.log('已满8局，显示结算页面');
    showSettlementPage();
    setTimeout(() => {
      gameState.isClosingHuMessage = false;
    }, 500);
    return;
  }
  
  console.log('准备调用 startRound()');
  startRound();
  
  setTimeout(() => {
    gameState.isClosingHuMessage = false;
    console.log('isClosingHuMessage 已重置');
  }, 1000);
}

function removeLastDiscard() {
  const discardPlayer = gameState.players[gameState.lastDiscardPlayerIndex];
  if (discardPlayer && discardPlayer.discards.length > 0) {
    discardPlayer.discards.pop();
  }
}

function moveToNextPlayer() {
  if (gameState.isDealing) return;
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
    
    // 防止重复处理流局
    if (gameState.isLiuJuHandled) {
      console.log('流局已处理，跳过');
      return;
    }
    gameState.isLiuJuHandled = true;
    
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
    
    // 播放"流局"音效，然后弹出流局页面
    playButtonSound('流局', gameState.currentPlayerIndex);
    setTimeout(() => {
      showMessage('流局', '牌堆已空，本局结束', true);
    }, 500);
    return;
  }
  
  startTurn();
}

function passAction() {
  stopCountdown();
  
  playButtonSound('过');
  
  // 保存当前可操作状态
  const canHu = gameState.canHu;
  const canZhao = gameState.canZhao;
  const canPeng = gameState.canPeng;
  const canChi = gameState.canChi;
  
  // 先隐藏所有按钮
  hideAllActionButtons();
  
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
      if (huResult.canHu) {
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

function hideAllActionButtons() {
  gameState.canPeng = false;
  gameState.canChi = false;
  gameState.canZhao = false;
  gameState.canHu = false;
  gameState.waitingForResponse = false;
  gameState.isMyTurn = false;
  gameState.actionCancelled = true;
  const container = document.getElementById('actionButtons');
  if (container) container.innerHTML = '';
}

function chiAction() {
  if (!gameState.canChi) return;
  stopCountdown();
  hideAllActionButtons();
  performChi(1);
}

function pengAction() {
  if (!gameState.canPeng) return;
  stopCountdown();
  hideAllActionButtons();
  performPeng(1);
}

function zhaoAction() {
  if (!gameState.canZhao) return;
  stopCountdown();
  hideAllActionButtons();
  performZhao(1);
}

function huAction() {
  if (!gameState.canHu) return;
  stopCountdown();
  hideAllActionButtons();
  // 隐藏听牌徽章
  const tingBadge = document.getElementById('tingBadge');
  if (tingBadge) tingBadge.classList.add('hidden');
  // 人类玩家点击"胡"按钮时播放"胡"音效
  playButtonSound('胡', 1);
  handleHu(1, 'dianpao');
}

function discardAction() {
  // 必须等待摸牌动画完成后才能出牌
  if (!gameState.isMyTurn || gameState.selectedCardIndex < 0 || gameState.isDrawing) {
    console.log('不能出牌: isMyTurn=', gameState.isMyTurn, 'selectedCardIndex=', gameState.selectedCardIndex, 'isDrawing=', gameState.isDrawing);
    return;
  }
  
  const me = gameState.players[1];
  
  const huResult = checkHu(me);
  
  if (huResult.canHu) {
    hideAllActionButtons();
    handleHu(1, 'zimo');
    return;
  }
  
  const selectedIndex = gameState.selectedCardIndex;
  gameState.selectedCardIndex = -1;
  hideAllActionButtons();
  
  discardCard(1, selectedIndex);
}

function selectCard(index) {
  // 必须等待摸牌动画完成后才能选择牌
  if (!gameState.isMyTurn || gameState.isDrawing) {
    console.log('不能选择牌: isMyTurn=', gameState.isMyTurn, 'isDrawing=', gameState.isDrawing);
    return;
  }
  
  gameState.selectedCardIndex = index;
  updateMyHand();
}

function updateActionButtons() {
  const container = document.getElementById('actionButtons');
  container.innerHTML = '';
  
  if (gameState.actionCancelled) {
    return;
  }
  
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
        hideAllActionButtons();
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
    // 吃/碰/招/胡/自摸 不在这里播放音效，让具体操作函数自己播放（使用正确的玩家声音类型）
    const actionButtons = ['吃', '碰', '招', '胡', '自摸'];
    if (!actionButtons.includes(text)) {
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

function animateScoreChange(playerIndex, newScore, oldScore) {
  const scoreIds = ['player1Score', 'myScore', 'player2Score'];
  const scoreEl = document.getElementById(scoreIds[playerIndex]);
  if (!scoreEl) return;
  
  // 确保 oldScore 和 newScore 是有效数字
  if (typeof oldScore !== 'number' || isNaN(oldScore)) {
    oldScore = parseInt(scoreEl.textContent) || 0;
  }
  if (typeof newScore !== 'number' || isNaN(newScore)) {
    newScore = oldScore;
  }
  
  const diff = newScore - oldScore;
  
  if (diff === 0) {
    scoreEl.textContent = newScore;
    return;
  }
  
  const avatarIds = ['player1Avatar', 'myAvatar', 'player2Avatar'];
  const avatarEl = document.getElementById(avatarIds[playerIndex]);
  
  // 先显示旧分数，然后动画过渡到新分数
  scoreEl.textContent = oldScore;
  
  // 强制重绘
  void scoreEl.offsetWidth;
  
  scoreEl.classList.add('score-changing');
  scoreEl.textContent = newScore;
  
  if (diff > 0) {
    scoreEl.classList.add('score-up');
    if (avatarEl) {
      avatarEl.classList.add('winner');
      setTimeout(() => avatarEl.classList.remove('winner'), 3000);
    }
  } else {
    scoreEl.classList.add('score-down');
    if (avatarEl) {
      avatarEl.classList.add('loser');
      setTimeout(() => avatarEl.classList.remove('loser'), 500);
    }
  }
  
  if (avatarEl) {
    avatarEl.classList.add('score-change');
    setTimeout(() => avatarEl.classList.remove('score-change'), 600);
  }
  
  const diffEl = document.createElement('span');
  diffEl.className = 'score-diff ' + (diff > 0 ? 'positive' : 'negative');
  diffEl.textContent = (diff > 0 ? '+' : '') + diff;
  
  if (avatarEl) {
    const existingDiff = avatarEl.querySelector('.score-diff');
    if (existingDiff) existingDiff.remove();
    
    avatarEl.style.position = 'relative';
    avatarEl.appendChild(diffEl);
    
    setTimeout(() => {
      diffEl.classList.add('fade-out');
      setTimeout(() => diffEl.remove(), 500);
    }, 1500);
  }
  
  setTimeout(() => {
    scoreEl.classList.remove('score-changing', 'score-up', 'score-down');
  }, 1000);
}

function updateUI() {
  updatePlayerArea(0, 'player1');
  updatePlayerArea(1, 'my');
  updatePlayerArea(2, 'player2');
  updateDeckStack();
}

function updateHandCount(elId, value) {
  const el = document.getElementById(elId);
  if (!el) return;
  const strVal = String(value);
  if (el.textContent === strVal) return;
  el.textContent = strVal;
  el.classList.add('pulse');
  setTimeout(() => el.classList.remove('pulse'), 150);
}

function updatePlayerArea(playerIndex, prefix) {
  const player = gameState.players[playerIndex];
  
  const handCountEl = document.getElementById(`${prefix}HandCount`);
  const scoreEl = document.getElementById(`${prefix}Score`);
  const meldsEl = document.getElementById(`${prefix}Melds`);
  const piaoEl = document.getElementById(`${prefix}Piao`);
  
  updateHandCount(`${prefix}HandCount`, player.hand.length);
  if (scoreEl && scoreEl.textContent !== String(player.score)) scoreEl.textContent = player.score;
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
    updateMyHand();
    
    const tingBadge = document.getElementById('tingBadge');
    const playerWithMelds = { ...player, melds: player.melds || [] };
    const tingResult = checkTing(playerWithMelds);
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
    huBadge.textContent = `${displayHuCount}胡`;
    huBadge.classList.remove('hidden');
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

let huCountCache = new Map();
let huTypeCache = new Map();
let tingCache = new Map();

function getCacheKey(hand, melds) {
  const handKey = hand.map(c => c.character).sort().join('');
  const meldKey = (melds || []).map(m => m.type + m.cards.map(c => c.character).join('')).join('|');
  return handKey + '|' + meldKey;
}

function clearCaches() {
  huCountCache.clear();
  huTypeCache.clear();
  tingCache.clear();
  invalidateRemainingCardsCache();
}

function checkTing(player) {
  const hand = [...(player.hand || [])];
  const melds = player.melds || [];
  
  const cacheKey = getCacheKey(hand, melds);
  if (tingCache.has(cacheKey)) {
    return tingCache.get(cacheKey);
  }
  
  const result = checkTingInternal(hand, melds);
  tingCache.set(cacheKey, result);
  return result;
}

function checkTingInternal(hand, melds) {
  const basicTing = checkBasicTingCondition(hand, melds);
  
  if (!basicTing.meets) {
    return { isTing: false, tingCards: [] };
  }
  
  let tingCards = [];
  
  if (basicTing.type === 'ninePairs') {
    const counts = {};
    for (const card of hand) {
      counts[card.character] = (counts[card.character] || 0) + 1;
    }
    for (const [char, count] of Object.entries(counts)) {
      if (count === 1) {
        tingCards.push(char);
      }
    }
    for (const [char, count] of Object.entries(counts)) {
      if (count === 3) {
        tingCards.push(char);
      }
    }
    
    return { isTing: tingCards.length > 0, tingCards: [...new Set(tingCards)] };
  }
  
  if (basicTing.type === 'sixGroupsOneSingle') {
    const singleCard = basicTing.singleCard;
    if (singleCard) {
      const sentence = singleCard.sentence;
      const sentenceChars = getSentenceCharacters(sentence);
      
      for (const char of sentenceChars) {
        const testCard = createCardByCharacter(char);
        if (!testCard) continue;
        
        if (testCard.position !== singleCard.position) {
          const testHandWithDraw = [...hand, testCard];
          const testHuCount = calculateHuCountCached(testHandWithDraw, melds);
          const huType = detectHuTypeCached(testHandWithDraw, melds, testHuCount);
          
          if (huType.type !== 'none') {
            const isSpecialHu = ['kuHu', 'qingKuHu', 'kuTaiHu', 'kuChongTaiHu', 'kuChongTaiKa', 'qingKuTaiKa', 'qingKuTaiHu', 'qingKuChongTaiHu', 'qingKuChongTaiKa', 'hongYuan3Jing', 'hongYuan4Jing', 'hongYuan5Jing', 'hongYuan6Jing', 'heiYuan', 'shiDui'].includes(huType.type);
            if (isSpecialHu || testHuCount >= 11) {
              tingCards.push(char);
            }
          }
        }
      }
      
      const testCard = createCardByCharacter(singleCard.character);
      if (testCard) {
        const testHandWithDraw = [...hand, testCard];
        const testHuCount = calculateHuCountCached(testHandWithDraw, melds);
        const huType = detectHuTypeCached(testHandWithDraw, melds, testHuCount);
        
        if (huType.type !== 'none' && (huType.type === 'shiDui' || testHuCount >= 11)) {
          tingCards.push(singleCard.character);
        }
      }
    }
    return { isTing: tingCards.length > 0, tingCards: [...new Set(tingCards)] };
  }
  
  if (basicTing.type === 'fiveGroupsTwoPairs') {
    const pairs = basicTing.pairs || [];
    const halfKaos = basicTing.halfKaos || [];
    
    const groupSet = new Set();
    for (const pair of pairs) {
      groupSet.add(pair.sentence);
    }
    for (let i = 0; i < halfKaos.length; i++) {
      if (halfKaos[i]) groupSet.add(halfKaos[i].sentence);
    }
    
    for (const sentence of groupSet) {
      const sentenceChars = getSentenceCharacters(sentence);
      
      for (const char of sentenceChars) {
        const testCard = createCardByCharacter(char);
        if (!testCard) continue;
        
        const testHandWithDraw = [...hand, testCard];
        const testHuCount = calculateHuCountCached(testHandWithDraw, melds);
        const huType = detectHuTypeCached(testHandWithDraw, melds, testHuCount);
        
        if (huType.type !== 'none') {
          const isSpecialHu = ['kuHu', 'qingKuHu', 'kuTaiHu', 'kuChongTaiHu', 'kuChongTaiKa', 'qingKuTaiKa', 'qingKuTaiHu', 'qingKuChongTaiHu', 'qingKuChongTaiKa', 'hongYuan3Jing', 'hongYuan4Jing', 'hongYuan5Jing', 'hongYuan6Jing', 'heiYuan', 'shiDui'].includes(huType.type);
          if (isSpecialHu || testHuCount >= 11) {
            tingCards.push(char);
          }
        }
      }
    }
    return { isTing: tingCards.length > 0, tingCards: [...new Set(tingCards)] };
  }
  
  return { isTing: false, tingCards: [] };
}

function getSentenceCharacters(sentence) {
  const sentenceMap = {
    1: ['上', '大', '人'],
    2: ['丘', '乙', '己'],
    3: ['化', '三', '千'],
    4: ['七', '十', '土'],
    5: ['尔', '小', '生'],
    6: ['八', '九', '子'],
    7: ['佳', '作', '亡'],
    8: ['福', '禄', '寿']
  };
  return sentenceMap[sentence] || [];
}

function calculateHuCountCached(hand, melds, huCard = null, isDianPao = false) {
  const cacheKey = getCacheKey(hand, melds) + '|' + (huCard ? huCard.character : '') + '|' + isDianPao;
  if (huCountCache.has(cacheKey)) {
    return huCountCache.get(cacheKey);
  }
  const result = calculateHuCount(hand, melds, huCard, isDianPao);
  huCountCache.set(cacheKey, result);
  return result;
}

function detectHuTypeCached(hand, melds, huCount) {
  const cacheKey = getCacheKey(hand, melds) + '|' + huCount;
  if (huTypeCache.has(cacheKey)) {
    return huTypeCache.get(cacheKey);
  }
  const result = detectHuType(hand, melds, huCount);
  huTypeCache.set(cacheKey, result);
  return result;
}

// 检查基本听牌条件
function checkBasicTingCondition(hand, melds) {
  console.log('=== checkBasicTingCondition ===');
  console.log('手牌:', hand.map(c => c.character).join(''));
  console.log('melds数量:', melds.length);
  
  let meldGroups = 0;
  for (const meld of melds) {
    meldGroups++;
  }
  
  const counts = {};
  for (const card of hand) {
    counts[card.character] = (counts[card.character] || 0) + 1;
  }
  
  let pairCount = 0;
  let singleCount = 0;
  let tripletCount = 0;
  let quartetCount = 0;
  
  for (const count of Object.values(counts)) {
    if (count === 2) pairCount++;
    else if (count === 3) tripletCount++;
    else if (count === 4) { quartetCount++; pairCount += 2; }
    else if (count === 1) singleCount++;
  }
  
  for (const meld of melds) {
    if (meld.type === 'triplet') { tripletCount++; pairCount++; }
    if (meld.type === 'quartet') { quartetCount++; pairCount += 2; }
  }
  
  console.log('条件a检查: 对数:', pairCount, '单张数:', singleCount, '坎数:', tripletCount, '招数:', quartetCount);
  
  if (pairCount >= 9 && singleCount <= 2) {
    let singleCard = null;
    for (const card of hand) {
      if (counts[card.character] === 1) {
        singleCard = card;
        break;
      }
    }
    console.log('满足条件a: 9对+单张, 单张:', singleCard?.character);
    return { meets: true, type: 'ninePairs', singleCard };
  }
  
  const handAnalysis = analyzeHandForTing(hand, melds);
  
  console.log('条件b检查: 总组合数:', handAnalysis.totalGroups, '单张数:', handAnalysis.singles.length);
  console.log('条件c检查: 对子数:', handAnalysis.pairs.length, '半靠数:', handAnalysis.halfKaos.length);
  
  if (handAnalysis.totalGroups === 6 && handAnalysis.singles.length === 1) {
    console.log('满足条件b: 6组合+1单, 单张:', handAnalysis.singles[0]?.character);
    return { meets: true, type: 'sixGroupsOneSingle', singleCard: handAnalysis.singles[0] };
  }
  
  if (handAnalysis.totalGroups === 5 && handAnalysis.pairs.length + Math.floor(handAnalysis.halfKaos.length / 2) >= 2) {
    console.log('满足条件c: 5组合+2对/半靠');
    return { meets: true, type: 'fiveGroupsTwoPairs', pairs: [...handAnalysis.pairs, ...handAnalysis.halfKaos], halfKaos: handAnalysis.halfKaos };
  }
  
  if (handAnalysis.totalGroups >= 6 && handAnalysis.pairs.length + Math.floor(handAnalysis.halfKaos.length / 2) >= 1) {
    console.log('满足条件c变体: 6组合+1对/半靠');
    return { meets: true, type: 'fiveGroupsTwoPairs', pairs: [...handAnalysis.pairs, ...handAnalysis.halfKaos], halfKaos: handAnalysis.halfKaos };
  }
  
  console.log('不满足任何基本听牌条件');
  return { meets: false };
}

// 分析手牌中的组合
function analyzeHandForTing(hand, melds) {
  let meldSentenceCount = 0;
  let meldKanCount = 0;
  let meldZhaoCount = 0;
  
  for (const meld of melds) {
    if (meld.type === 'sequence') meldSentenceCount++;
    else if (meld.type === 'triplet') meldKanCount++;
    else if (meld.type === 'quartet') meldZhaoCount++;
  }
  
  const allResults = [];
  
  function tryAnalysis(skipSentences = []) {
    const usedCardIds = new Set();
    let sentenceCount = meldSentenceCount;
    let kanCount = meldKanCount;
    let zhaoCount = meldZhaoCount;
    
    for (let sentence = 1; sentence <= 8; sentence++) {
      if (skipSentences.includes(sentence)) continue;
      const sentenceCards = hand.filter(c => c.sentence === sentence && !usedCardIds.has(c.id));
      const pos0 = sentenceCards.filter(c => c.position === 0);
      const pos1 = sentenceCards.filter(c => c.position === 1);
      const pos2 = sentenceCards.filter(c => c.position === 2);
      
      while (pos0.length > 0 && pos1.length > 0 && pos2.length > 0) {
        usedCardIds.add(pos0[0].id);
        usedCardIds.add(pos1[0].id);
        usedCardIds.add(pos2[0].id);
        pos0.shift();
        pos1.shift();
        pos2.shift();
        sentenceCount++;
      }
    }
    
    const remainingCards = hand.filter(c => !usedCardIds.has(c.id));
    const counts = {};
    for (const card of remainingCards) {
      counts[card.character] = (counts[card.character] || 0) + 1;
    }
    
    for (const [char, count] of Object.entries(counts)) {
      if (count >= 4) {
        zhaoCount++;
        const cards = remainingCards.filter(c => c.character === char);
        cards.forEach(c => usedCardIds.add(c.id));
      } else if (count === 3) {
        kanCount++;
        const cards = remainingCards.filter(c => c.character === char);
        cards.forEach(c => usedCardIds.add(c.id));
      }
    }
    
    const finalRemaining = hand.filter(c => !usedCardIds.has(c.id));
    const pairs = [];
    const halfKaos = [];
    const singles = [];
    
    const finalCounts = {};
    for (const card of finalRemaining) {
      finalCounts[card.character] = (finalCounts[card.character] || 0) + 1;
    }
    
    for (const [char, count] of Object.entries(finalCounts)) {
      if (count === 2) {
        const card = finalRemaining.find(c => c.character === char);
        pairs.push(card);
      } else if (count === 1) {
        const card = finalRemaining.find(c => c.character === char);
        singles.push(card);
      }
    }
    
    for (let sentence = 1; sentence <= 8; sentence++) {
      const sentenceCards = finalRemaining.filter(c => c.sentence === sentence && !pairs.some(p => p.character === c.character));
      if (sentenceCards.length === 2 && sentenceCards[0].position !== sentenceCards[1].position) {
        halfKaos.push(...sentenceCards);
      }
    }
    
    return {
      totalGroups: sentenceCount + kanCount + zhaoCount,
      pairs,
      halfKaos,
      singles
    };
  }
  
  allResults.push(tryAnalysis([]));
  
  for (let sentence = 1; sentence <= 8; sentence++) {
    const sentenceCards = hand.filter(c => c.sentence === sentence);
    const positions = new Set(sentenceCards.map(c => c.position));
    if (positions.size === 3) {
      const counts = {};
      for (const card of sentenceCards) {
        counts[card.character] = (counts[card.character] || 0) + 1;
      }
      let hasDuplicate = false;
      for (const count of Object.values(counts)) {
        if (count >= 2) {
          hasDuplicate = true;
          break;
        }
      }
      if (hasDuplicate) {
        allResults.push(tryAnalysis([sentence]));
      }
    }
  }
  
  let bestResult = null;
  
  for (const result of allResults) {
    if (result.totalGroups === 6 && result.singles.length === 1) {
      if (!bestResult || result.pairs.length + Math.floor(result.halfKaos.length / 2) > 
          bestResult.pairs.length + Math.floor(bestResult.halfKaos.length / 2)) {
        bestResult = result;
      }
    }
    if (result.totalGroups === 5 && result.pairs.length + result.halfKaos.length >= 2) {
      if (!bestResult || result.pairs.length + Math.floor(result.halfKaos.length / 2) > 
          bestResult.pairs.length + Math.floor(bestResult.halfKaos.length / 2)) {
        bestResult = result;
      }
    }
  }
  
  if (!bestResult) {
    bestResult = allResults[0];
    for (const result of allResults) {
      if (result.pairs.length + Math.floor(result.halfKaos.length / 2) > 
          bestResult.pairs.length + Math.floor(bestResult.halfKaos.length / 2)) {
        bestResult = result;
      }
    }
  }
  
  return bestResult;
}

function calculateXiangTingShu(hand, melds) {
  const tingResult = checkTing({ hand, melds: melds || [] });
  if (tingResult.isTing) {
    return 0;
  }
  
  const analysis = analyzeHandForTing(hand, melds || []);
  const totalGroups = analysis.totalGroups;
  
  const counts = {};
  for (const card of hand) {
    counts[card.character] = (counts[card.character] || 0) + 1;
  }
  
  let pairCount = 0;
  let singleCount = 0;
  let tripletCount = 0;
  let quartetCount = 0;
  
  for (const count of Object.values(counts)) {
    if (count === 2) pairCount++;
    else if (count === 3) tripletCount++;
    else if (count === 4) { quartetCount++; pairCount += 2; }
    else if (count === 1) singleCount++;
  }
  
  for (const meld of (melds || [])) {
    if (meld.type === 'triplet') { tripletCount++; pairCount++; }
    if (meld.type === 'quartet') { quartetCount++; pairCount += 2; }
  }
  
  if (pairCount >= 9 && singleCount <= 2) {
    if (singleCount === 0) return 0;
    if (singleCount === 1) return 1;
    return 2;
  }
  
  if (totalGroups >= 6) {
    if (analysis.singles.length === 1) return 1;
    if (analysis.pairs.length + analysis.halfKaos.length >= 2) return 1;
    if (analysis.pairs.length + Math.floor(analysis.halfKaos.length / 2) >= 1) return 2;
    return 2;
  }
  
  if (totalGroups === 5) {
    const pairsAndKaos = analysis.pairs.length + Math.floor(analysis.halfKaos.length / 2);
    if (pairsAndKaos >= 2) return 1;
    if (pairsAndKaos === 1) return 2;
    return 3;
  }
  
  if (totalGroups === 4) {
    const pairsAndKaos = analysis.pairs.length + Math.floor(analysis.halfKaos.length / 2);
    if (pairsAndKaos >= 3) return 2;
    if (pairsAndKaos >= 2) return 3;
    return 3;
  }
  
  if (totalGroups === 3) {
    return 4;
  }
  
  return Math.max(1, 6 - totalGroups);
}

function shouldAIChi(player, card) {
  if (gameSettings.difficulty === 'easy') {
    return Math.random() > 0.5;
  }
  
  const currentXiangTing = calculateXiangTingShu(player.hand, player.melds);
  const melds = player.melds || [];
  
  const tempHand = [...player.hand, card];
  const sentenceCards = tempHand.filter(c => c.sentence === card.sentence);
  const positions = new Set(sentenceCards.map(c => c.position));
  
  if (positions.size < 3) {
    return false;
  }
  
  const chiCards = [];
  for (let pos = 0; pos < 3; pos++) {
    if (pos !== card.position) {
      const c = sentenceCards.find(sc => sc.position === pos);
      if (c) chiCards.push(c);
    }
  }
  
  if (chiCards.length !== 2) {
    return false;
  }
  
  const afterChiHand = player.hand.filter(c => 
    c.id !== chiCards[0].id && c.id !== chiCards[1].id
  );
  const afterChiMelds = [...melds, {
    type: 'sequence',
    cards: [card, ...chiCards].sort((a, b) => a.position - b.position),
    huValue: (card.sentence === 1 || card.sentence === 8) ? 4 : 0
  }];
  
  const afterChiXiangTing = calculateXiangTingShu(afterChiHand, afterChiMelds);
  
  const afterChiTing = checkTing({ hand: afterChiHand, melds: afterChiMelds });
  if (afterChiTing.isTing) {
    return true;
  }
  
  if (afterChiXiangTing < currentXiangTing) {
    return true;
  }
  
  if (card.sentence === 1 || card.sentence === 8) {
    if (afterChiXiangTing <= currentXiangTing) {
      const shangFuInHand = player.hand.filter(c => c.character === '上' || c.character === '福').length;
      if (shangFuInHand >= 2) {
        return true;
      }
    }
  }
  
  const threshold = gameSettings.difficulty === 'medium' ? 2 : 3;
  if (afterChiXiangTing === currentXiangTing && currentXiangTing <= threshold) {
    return true;
  }
  
  if (gameSettings.difficulty === 'hard') {
    const beforeTingCards = findTingCards(player.hand, melds);
    const afterTingCards = findTingCards(afterChiHand, afterChiMelds);
    
    if (afterTingCards.length > beforeTingCards.length) {
      return true;
    }
    
    const beforeJinZhang = calculateTotalJinZhang(player.hand, melds);
    const afterJinZhang = calculateTotalJinZhang(afterChiHand, afterChiMelds);
    
    if (afterJinZhang > beforeJinZhang * 1.2) {
      return true;
    }
    
    const simulatedPlayer = { 
      ...player, 
      hand: afterChiHand, 
      melds: afterChiMelds 
    };
    const discardIndex = selectAIDiscardHard(simulatedPlayer);
    const willDiscardCard = afterChiHand[discardIndex];
    
    const allChiCharacters = [card.character, ...chiCards.map(c => c.character)];
    if (willDiscardCard && allChiCharacters.includes(willDiscardCard.character)) {
      return false;
    }
    
    if (willDiscardCard && willDiscardCard.sentence === card.sentence) {
      const sameCharInHand = afterChiHand.filter(c => c.character === willDiscardCard.character).length;
      if (sameCharInHand <= 1) {
        return false;
      }
    }
    
    const chiDiscardHand = afterChiHand.filter(c => c.id !== willDiscardCard.id);
    const chiDiscardXiangTing = calculateXiangTingShu(chiDiscardHand, afterChiMelds);
    
    let drawBetterCount = 0;
    for (const c of ALL_CHARACTERS) {
      const remaining = countRemainingCards(c);
      if (remaining <= 0) continue;
      const cardInfo = createCardByCharacter(c);
      const drawHand = [...player.hand, { ...cardInfo, id: -1 }];
      const drawXiangTing = calculateXiangTingShu(drawHand, melds);
      if (drawXiangTing <= chiDiscardXiangTing) {
        drawBetterCount += remaining;
      }
    }
    
    const totalRemaining = gameState.deck ? gameState.deck.length : 0;
    if (totalRemaining > 0 && drawBetterCount / totalRemaining > 0.4) {
      console.log('困难模式: 不吃牌，摸牌更优，摸牌更优比例:', (drawBetterCount / totalRemaining * 100).toFixed(1) + '%');
      return false;
    }
    
    const beforeHuType = predictBestHuTypeEnhanced(player.hand, melds);
    const afterHuType = predictBestHuTypeEnhanced(afterChiHand, afterChiMelds);
    
    if (afterHuType.score > beforeHuType.score * 1.3) {
      return true;
    }
    
    const hasSpecialSentence = card.sentence === 1 || card.sentence === 8;
    const shangFuCount = player.hand.filter(c => c.character === '上' || c.character === '福').length;
    
    if (hasSpecialSentence && shangFuCount >= 2 && afterChiXiangTing <= currentXiangTing) {
      const hasPengZhao = melds.some(m => m.type === 'triplet' || m.type === 'quartet');
      if (!hasPengZhao) {
        return true;
      }
    }
    
    const beforeSpecialPotential = evaluateSpecialHuPotential(player.hand, melds);
    const afterSpecialPotential = evaluateSpecialHuPotential(afterChiHand, afterChiMelds);
    
    if (afterSpecialPotential > beforeSpecialPotential * 1.2) {
      return true;
    }
    
    if (beforeSpecialPotential > 300 && afterSpecialPotential < beforeSpecialPotential * 0.8) {
      return false;
    }
    
    const beforeHuCount = calculateHuCount(player.hand, melds);
    const afterHuCount = calculateHuCount(afterChiHand, afterChiMelds);
    
    if (beforeHuCount < 11 && afterHuCount >= 11) {
      return true;
    }
    
    if (beforeHuCount >= 11 && afterHuCount < 11) {
      return false;
    }
    
    const opponents = gameState.players.filter((p, i) => i !== gameState.currentPlayerIndex);
    const anyOpponentTing = opponents.some(o => o.isTing);
    
    if (anyOpponentTing && afterChiXiangTing <= currentXiangTing) {
      if (afterTingCards.length >= beforeTingCards.length) {
        return true;
      }
    }
    
    const beforeExpectedValue = calculateExpectedValue(player.hand, melds);
    const afterExpectedValue = calculateExpectedValue(afterChiHand, afterChiMelds);
    
    if (afterExpectedValue > beforeExpectedValue * 1.3) {
      return true;
    }
    
    const phase = getGamePhase();
    if (phase === 'late' || phase === 'end') {
      if (afterChiXiangTing < currentXiangTing) {
        return true;
      }
      
      if (anyOpponentTing && afterChiXiangTing > currentXiangTing) {
        return false;
      }
    }
    
    if (phase === 'early') {
      if (afterHuType.score > beforeHuType.score * 1.5) {
        return true;
      }
    }
    
    const beforeWinProb = calculateWinProbability(player.hand, melds);
    const afterWinProb = calculateWinProbability(afterChiHand, afterChiMelds);
    
    if (afterWinProb > beforeWinProb * 1.2) {
      return true;
    }
    
    if (beforeWinProb > 0.5 && afterWinProb < beforeWinProb * 0.8) {
      return false;
    }
  }
  
  return false;
}

function calculateTotalJinZhang(hand, melds) {
  let totalJinZhang = 0;
  const currentXiangTing = calculateXiangTingShu(hand, melds);
  
  for (const char of ALL_CHARACTERS) {
    const remaining = countRemainingCards(char);
    if (remaining <= 0) continue;
    
    const testCard = createCardByCharacter(char);
    if (!testCard) continue;
    
    const testHand = [...hand, testCard];
    const newXiangTing = calculateXiangTingShu(testHand, melds);
    
    if (newXiangTing < currentXiangTing) {
      totalJinZhang += remaining * 2;
    } else if (newXiangTing === currentXiangTing) {
      totalJinZhang += remaining;
    }
  }
  
  return totalJinZhang;
}

function predictBestHuType(hand, melds) {
  let bestScore = 0;
  let bestHuType = null;
  
  for (const char of ALL_CHARACTERS) {
    const testCard = createCardByCharacter(char);
    if (!testCard) continue;
    
    const testHand = [...hand, testCard];
    const tempPlayer = { hand: testHand, melds: melds || [] };
    
    const huResult = checkHu(tempPlayer);
    if (huResult.canHu) {
      const multiplier = huResult.huType?.multiplier?.zimo || 1;
      const remaining = countRemainingCards(char);
      const huScore = multiplier * 50 + remaining * 10;
      
      if (huScore > bestScore) {
        bestScore = huScore;
        bestHuType = huResult.huType;
      }
    }
  }
  
  return { score: bestScore, huType: bestHuType };
}

function predictBestHuTypeEnhanced(hand, melds) {
  let bestScore = 0;
  let bestHuType = null;
  let bestTingCards = [];
  
  const huTypeWeights = {
    'kuChongTaiHu': 15,
    'kuChongTaiKa': 14,
    'qingKuChongTaiHu': 13,
    'qingKuChongTaiKa': 12,
    'kuTaiHu': 11,
    'qingKuTaiHu': 10,
    'qingKuTaiKa': 9,
    'kuHu': 8,
    'qingKuHu': 7,
    'shiDui': 12,
    'hongYuan6Jing': 11,
    'hongYuan5Jing': 10,
    'hongYuan4Jing': 9,
    'hongYuan3Jing': 8,
    'heiYuan': 7,
    'qingHu': 3,
    'qingKaHu': 2,
    'taiHu': 2,
    'taiKa': 2,
    'chongTaiHu': 5,
    'chongTaiKa': 4,
    'kaHu': 1,
    'puTongHu': 1
  };
  
  for (const char of ALL_CHARACTERS) {
    const testCard = createCardByCharacter(char);
    if (!testCard) continue;
    
    const testHand = [...hand, testCard];
    const tempPlayer = { hand: testHand, melds: melds || [] };
    
    const huResult = checkHu(tempPlayer);
    if (huResult.canHu) {
      const huType = huResult.huType?.type || 'puTongHu';
      const multiplier = huResult.huType?.multiplier?.zimo || 1;
      const remaining = countRemainingCards(char);
      
      const typeWeight = huTypeWeights[huType] || 1;
      const huScore = multiplier * 100 + remaining * 20 + typeWeight * 50;
      
      if (huScore > bestScore) {
        bestScore = huScore;
        bestHuType = huResult.huType;
        bestTingCards = [char];
      } else if (huScore === bestScore) {
        bestTingCards.push(char);
      }
    }
  }
  
  return { score: bestScore, huType: bestHuType, tingCards: bestTingCards };
}

function evaluateSpecialHuPotential(hand, melds) {
  let potential = 0;
  
  const hasPengZhao = (melds || []).some(m => m.type === 'triplet' || m.type === 'quartet');
  const hasNonSequenceMeld = (melds || []).some(m => m.type !== 'sequence');
  
  const shangCount = hand.filter(c => c.character === '上').length;
  const fuCount = hand.filter(c => c.character === '福').length;
  const shangFuTotal = shangCount + fuCount;
  
  if (!hasPengZhao && !hasNonSequenceMeld) {
    const sentenceGroups = {};
    hand.forEach(c => {
      if (!sentenceGroups[c.sentence]) {
        sentenceGroups[c.sentence] = { 0: 0, 1: 0, 2: 0 };
      }
      sentenceGroups[c.sentence][c.position]++;
    });
    
    const hasShangDaRen = sentenceGroups[1] && 
      sentenceGroups[1][0] > 0 && sentenceGroups[1][1] > 0 && sentenceGroups[1][2] > 0;
    const hasFuLuShou = sentenceGroups[8] && 
      sentenceGroups[8][0] > 0 && sentenceGroups[8][1] > 0 && sentenceGroups[8][2] > 0;
    
    if (hasShangDaRen || hasFuLuShou) {
      if (shangFuTotal >= 3 && shangFuTotal <= 6) {
        potential += shangFuTotal * 150;
        
        const sequenceCount = (melds || []).filter(m => m.type === 'sequence').length;
        let handSentenceCount = 0;
        for (let s = 1; s <= 8; s++) {
          if (sentenceGroups[s] && sentenceGroups[s][0] > 0 && 
              sentenceGroups[s][1] > 0 && sentenceGroups[s][2] > 0) {
            handSentenceCount++;
          }
        }
        
        if (sequenceCount + handSentenceCount >= 5) {
          potential += 300;
        }
      }
    }
  }
  
  const counts = {};
  hand.forEach(c => {
    counts[c.character] = (counts[c.character] || 0) + 1;
  });
  
  let pairCount = 0;
  let tripletCount = 0;
  let quartetCount = 0;
  
  for (const count of Object.values(counts)) {
    if (count === 2) pairCount++;
    else if (count === 3) tripletCount++;
    else if (count === 4) quartetCount++;
  }
  
  for (const meld of (melds || [])) {
    if (meld.type === 'triplet') tripletCount++;
    if (meld.type === 'quartet') quartetCount++;
  }
  
  const totalPairs = pairCount + tripletCount + quartetCount * 2;
  if (totalPairs >= 8) {
    potential += 200;
    if (totalPairs >= 9) {
      potential += 150;
    }
  }
  
  if (!hasPengZhao) {
    let sentenceCount = (melds || []).filter(m => m.type === 'sequence').length;
    const sentenceGroups = {};
    hand.forEach(c => {
      if (!sentenceGroups[c.sentence]) {
        sentenceGroups[c.sentence] = { 0: 0, 1: 0, 2: 0 };
      }
      sentenceGroups[c.sentence][c.position]++;
    });
    
    for (let s = 1; s <= 8; s++) {
      if (sentenceGroups[s] && sentenceGroups[s][0] > 0 && 
          sentenceGroups[s][1] > 0 && sentenceGroups[s][2] > 0) {
        sentenceCount++;
      }
    }
    
    if (sentenceCount >= 5 && shangFuTotal === 0) {
      potential += 100;
    }
  }
  
  return potential;
}

function shouldAIPeng(player, card) {
  if (gameSettings.difficulty === 'easy') {
    return Math.random() > 0.4;
  }
  
  const currentXiangTing = calculateXiangTingShu(player.hand, player.melds);
  const melds = player.melds || [];
  
  const sameCount = player.hand.filter(c => c.character === card.character).length;
  if (sameCount < 2) {
    return false;
  }
  
  let removed = 0;
  const afterPengHandCorrect = player.hand.filter(c => {
    if (c.character === card.character && removed < 2) {
      removed++;
      return false;
    }
    return true;
  });
  
  const isJingKan = card.character === '上' || card.character === '福';
  const afterPengMelds = [...melds, {
    type: 'triplet',
    cards: [card, card, card],
    huValue: isJingKan ? 12 : 3
  }];
  
  const afterPengXiangTing = calculateXiangTingShu(afterPengHandCorrect, afterPengMelds);
  
  const afterPengTing = checkTing({ hand: afterPengHandCorrect, melds: afterPengMelds });
  if (afterPengTing.isTing) {
    return true;
  }
  
  if (afterPengXiangTing < currentXiangTing) {
    return true;
  }
  
  if (isJingKan && afterPengXiangTing <= currentXiangTing + 1) {
    return true;
  }
  
  const threshold = gameSettings.difficulty === 'medium' ? 2 : 3;
  if (afterPengXiangTing === currentXiangTing && currentXiangTing <= threshold) {
    return true;
  }
  
  if (gameSettings.difficulty === 'hard') {
    const beforeHuCount = calculateHuCount(player.hand, melds);
    const afterHuCount = calculateHuCount(afterPengHandCorrect, afterPengMelds);
    
    if (afterHuCount >= 11 && beforeHuCount < 11) {
      return true;
    }
    
    if (isJingKan && currentXiangTing <= 3) {
      return true;
    }
    
    const beforeJinZhang = calculateTotalJinZhang(player.hand, melds);
    const afterJinZhang = calculateTotalJinZhang(afterPengHandCorrect, afterPengMelds);
    
    if (afterJinZhang > beforeJinZhang * 1.3) {
      return true;
    }
    
    const beforeTingCards = findTingCards(player.hand, melds);
    const afterTingCards = findTingCards(afterPengHandCorrect, afterPengMelds);
    
    if (afterTingCards.length > beforeTingCards.length) {
      return true;
    }
    
    const hasSpecialSentence = player.hand.some(c => 
      (c.sentence === 1 || c.sentence === 8) && c.character !== card.character);
    const shangFuCount = player.hand.filter(c => c.character === '上' || c.character === '福').length;
    
    if (hasSpecialSentence && shangFuCount >= 3 && !isJingKan) {
      const sentenceCount = melds.filter(m => m.type === 'sequence').length;
      if (sentenceCount >= 2) {
        return false;
      }
    }
    
    if (isJingKan && sameCount === 2) {
      const remaining = countRemainingCards(card.character);
      if (remaining === 0) {
        return true;
      }
    }
    
    const beforeSpecialPotential = evaluateSpecialHuPotential(player.hand, melds);
    const afterSpecialPotential = evaluateSpecialHuPotential(afterPengHandCorrect, afterPengMelds);
    
    if (beforeSpecialPotential > 400 && afterSpecialPotential < beforeSpecialPotential * 0.5) {
      return false;
    }
    
    const hasPengZhao = melds.some(m => m.type === 'triplet' || m.type === 'quartet');
    if (!hasPengZhao) {
      const sentenceGroups = {};
      player.hand.forEach(c => {
        if (!sentenceGroups[c.sentence]) {
          sentenceGroups[c.sentence] = { 0: 0, 1: 0, 2: 0 };
        }
        sentenceGroups[c.sentence][c.position]++;
      });
      
      const hasShangDaRen = sentenceGroups[1] && 
        sentenceGroups[1][0] > 0 && sentenceGroups[1][1] > 0 && sentenceGroups[1][2] > 0;
      const hasFuLuShou = sentenceGroups[8] && 
        sentenceGroups[8][0] > 0 && sentenceGroups[8][1] > 0 && sentenceGroups[8][2] > 0;
      
      if ((hasShangDaRen || hasFuLuShou) && shangFuCount >= 3 && shangFuCount <= 6) {
        return false;
      }
    }
    
    const beforeHuType = predictBestHuTypeEnhanced(player.hand, melds);
    const afterHuType = predictBestHuTypeEnhanced(afterPengHandCorrect, afterPengMelds);
    
    if (beforeHuType.score > afterHuType.score * 1.5 && beforeHuType.score > 500) {
      return false;
    }
    
    if (beforeHuCount >= 11 && afterHuCount < 11) {
      return false;
    }
    
    const opponents = gameState.players.filter((p, i) => i !== gameState.currentPlayerIndex);
    const anyOpponentTing = opponents.some(o => o.isTing);
    
    if (anyOpponentTing && afterPengXiangTing <= currentXiangTing) {
      if (afterTingCards.length > 0) {
        return true;
      }
    }
    
    const beforeExpectedValue = calculateExpectedValue(player.hand, melds);
    const afterExpectedValue = calculateExpectedValue(afterPengHandCorrect, afterPengMelds);
    
    if (afterExpectedValue > beforeExpectedValue * 1.3) {
      return true;
    }
    
    if (beforeExpectedValue > afterExpectedValue * 1.5 && beforeExpectedValue > 100) {
      return false;
    }
    
    const phase = getGamePhase();
    if (phase === 'late' || phase === 'end') {
      if (afterPengXiangTing < currentXiangTing) {
        return true;
      }
      
      if (anyOpponentTing && afterPengXiangTing > currentXiangTing) {
        return false;
      }
      
      if (isJingKan && afterPengXiangTing <= currentXiangTing) {
        return true;
      }
    }
    
    if (phase === 'early') {
      if (afterHuType.score > beforeHuType.score * 1.5) {
        return true;
      }
      
      if (!isJingKan && afterPengXiangTing > currentXiangTing) {
        return false;
      }
    }
    
    const beforeWinProb = calculateWinProbability(player.hand, melds);
    const afterWinProb = calculateWinProbability(afterPengHandCorrect, afterPengMelds);
    
    if (afterWinProb > beforeWinProb * 1.2) {
      return true;
    }
    
    if (beforeWinProb > 0.5 && afterWinProb < beforeWinProb * 0.8) {
      return false;
    }
    
    const dangerScore = calculateCardDangerScore(card, player);
    if (dangerScore > 500 && afterPengXiangTing >= currentXiangTing) {
      return false;
    }
    
    const simulatedPlayer = { 
      ...player, 
      hand: afterPengHandCorrect, 
      melds: afterPengMelds 
    };
    const discardIndex = selectAIDiscardHard(simulatedPlayer);
    const willDiscardCard = afterPengHandCorrect[discardIndex];
    
    if (willDiscardCard && willDiscardCard.character === card.character) {
      console.log('困难模式: 碰牌后会打出同字牌，不碰');
      return false;
    }
    
    const pengDiscardHand = afterPengHandCorrect.filter(c => c.id !== willDiscardCard.id);
    const pengDiscardXiangTing = calculateXiangTingShu(pengDiscardHand, afterPengMelds);
    
    let drawBetterCount = 0;
    for (const c of ALL_CHARACTERS) {
      const remaining = countRemainingCards(c);
      if (remaining <= 0) continue;
      const cardInfo = createCardByCharacter(c);
      const drawHand = [...player.hand, { ...cardInfo, id: -1 }];
      const drawXiangTing = calculateXiangTingShu(drawHand, melds);
      if (drawXiangTing <= pengDiscardXiangTing) {
        drawBetterCount += remaining;
      }
    }
    
    const totalRemaining = gameState.deck ? gameState.deck.length : 0;
    if (totalRemaining > 0 && drawBetterCount / totalRemaining > 0.5) {
      console.log('困难模式: 不碰牌，摸牌更优，摸牌更优比例:', (drawBetterCount / totalRemaining * 100).toFixed(1) + '%');
      return false;
    }
  }
  
  return false;
}

function shouldAIZhao(player, card) {
  console.log('=== AI招牌决策分析 ===');
  console.log('玩家:', player.name);
  console.log('招牌:', card.character);
  
  const sameCount = player.hand.filter(c => c.character === card.character).length;
  if (sameCount < 3) {
    console.log('手牌中同字不足3张，不能招');
    return false;
  }
  
  console.log('★★★ 可以招牌，必须招！★★★');
  return true;
}

function findTingCards(hand, melds) {
  const tingCards = [];
  
  for (const char of ALL_CHARACTERS) {
    const testCard = createCardByCharacter(char);
    if (!testCard) continue;
    
    const testHand = [...hand, testCard];
    const tingResult = checkTing({ hand: testHand, melds });
    
    if (tingResult.isTing) {
      tingCards.push(char);
    }
  }
  
  return tingCards;
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



function addHistory(playerName, cardChar) {
  const historyList = document.getElementById('historyList');
  if (!historyList) return;
  const item = document.createElement('div');
  item.className = 'history-item';
  item.innerHTML = `<span class="player-name">${playerName}</span>: <span class="card-char">${cardChar}</span>`;
  historyList.insertBefore(item, historyList.firstChild);
}

function showMessage(title, content, isLiuJu = false) {
  // 隐藏听牌徽章和自摸徽章
  const tingBadge = document.getElementById('tingBadge');
  const zimoBadge = document.getElementById('zimoBadge');
  if (tingBadge) tingBadge.classList.add('hidden');
  if (zimoBadge) zimoBadge.classList.add('hidden');
  
  document.getElementById('messageTitle').textContent = title;
  
  // 字符到拼音的映射
  const charToPinyin = {
    '上': 'shang', '大': 'da', '人': 'ren',
    '丘': 'qiu', '乙': 'yi', '己': 'ji',
    '化': 'hua', '三': 'san', '千': 'qian',
    '七': 'qi', '十': 'shi', '土': 'tu',
    '尔': 'er', '小': 'xiao', '生': 'sheng',
    '八': 'ba', '九': 'jiu', '子': 'zi',
    '佳': 'jia', '作': 'zuo', '亡': 'wang',
    '福': 'fu', '禄': 'lu', '寿': 'shou'
  };
  
  // 如果是流局，显示每个玩家的手牌
  if (isLiuJu) {
    let handsContent = '<div class="liuju-hands">';
    for (let i = 0; i < gameState.players.length; i++) {
      const player = gameState.players[i];
      handsContent += `<div class="liuju-player-hand">
        <div class="liuju-player-name">${player.name}</div>
        <div class="liuju-cards">`;
      
      // 显示手牌
      for (const card of player.hand) {
        const pinyin = charToPinyin[card.character] || card.character;
        const isJing = card.character === '上' || card.character === '福';
        handsContent += `<img src="images/s/${pinyin}.png" class="liuju-card-img ${isJing ? 'jing' : ''}" alt="${card.character}">`;
      }
      
      // 显示组合牌
      if (player.melds && player.melds.length > 0) {
        handsContent += '<div class="liuju-melds">';
        for (const meld of player.melds) {
          for (const card of meld.cards) {
            const pinyin = charToPinyin[card.character] || card.character;
            const isJing = card.character === '上' || card.character === '福';
            handsContent += `<img src="images/s/${pinyin}.png" class="liuju-card-img ${isJing ? 'jing' : ''}" alt="${card.character}">`;
          }
        }
        handsContent += '</div>';
      }
      
      handsContent += '</div></div>';
    }
    handsContent += '</div>';
    document.getElementById('messageContent').innerHTML = content + handsContent;
  } else {
    document.getElementById('messageContent').textContent = content;
  }
  
  const messageArea = document.getElementById('messageArea');
  messageArea.classList.add('show');
  messageArea.dataset.liuju = isLiuJu;
  
  // 移除之前的滑动事件监听器，防止重复添加
  if (messageArea._swipeHandler) {
    messageArea.removeEventListener('touchstart', messageArea._swipeHandler.touchstart);
    messageArea.removeEventListener('touchmove', messageArea._swipeHandler.touchmove);
    messageArea.removeEventListener('touchend', messageArea._swipeHandler.touchend);
    messageArea.removeEventListener('mousedown', messageArea._swipeHandler.mousedown);
    messageArea.removeEventListener('mousemove', messageArea._swipeHandler.mousemove);
    messageArea.removeEventListener('mouseup', messageArea._swipeHandler.mouseup);
    messageArea.removeEventListener('mouseleave', messageArea._swipeHandler.mouseleave);
  }
  
  // 添加滑动关闭功能
  setupSwipeToClose(messageArea, closeMessage);
  
  // 测试模式下自动2秒后关闭
  if (gameState.testMode) {
    setTimeout(() => {
      if (messageArea.classList.contains('show')) {
        closeMessage();
      }
    }, 2000);
  }
}

function closeMessage() {
  if (gameState.isClosingMessage) {
    console.log('closeMessage: 已经在关闭中，跳过');
    return;
  }
  gameState.isClosingMessage = true;
  console.log('closeMessage: 开始关闭');
  
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
  
  updateHuBadgeDisplay();
  
  console.log('closeMessage: isLiuJu =', isLiuJu, 'roundNumber =', gameState.roundNumber);
  
  if (isLiuJu) {
    
    if (gameState.roundNumber >= 8) {
      console.log('第8局流局结束，显示结算页面');
      showSettlementPage();
      setTimeout(() => {
        gameState.isClosingMessage = false;
      }, 500);
      return;
    }
    
    console.log('流局，开始下一局');
    startRound();
    
    setTimeout(() => {
      gameState.isClosingMessage = false;
      console.log('isClosingMessage 已重置');
    }, 1000);
    return;
  }
  
  gameState.isClosingMessage = false;
}

// 设置弹窗功能
function openSettings() {
  const popup = document.getElementById('settingsPopup');
  if (popup) {
    popup.classList.remove('hidden');
    const slider = document.getElementById('volumeSlider');
    const valueDisplay = document.getElementById('volumeValue');
    if (slider && valueDisplay) {
      slider.value = gameSettings.volume * 100;
      valueDisplay.textContent = Math.round(gameSettings.volume * 100) + '%';
    }
    // 设置难度单选按钮
    const difficultyRadios = document.querySelectorAll('input[name="difficulty"]');
    difficultyRadios.forEach(radio => {
      radio.checked = radio.value === gameSettings.difficulty;
    });
    const logCountEl = document.getElementById('logCount');
    if (logCountEl) {
      logCountEl.textContent = getLogCount();
    }
  }
}

function closeSettings() {
  const popup = document.getElementById('settingsPopup');
  if (popup) {
    popup.classList.add('hidden');
  }
}

function exitGame() {
  closeSettings();
  if (typeof FlutterBridge !== 'undefined' && FlutterBridge.postMessage) {
    FlutterBridge.postMessage('exit');
  } else if (typeof plus !== 'undefined' && plus.navigator) {
    plus.navigator.close();
  } else if (typeof uni !== 'undefined' && uni.navigateBack) {
    uni.navigateBack({ delta: 1 });
  } else if (typeof WeixinJSBridge !== 'undefined') {
    WeixinJSBridge.call('closeWindow');
  } else {
    window.close();
  }
}

function updateVolume(value) {
  gameSettings.volume = value / 100;
  const valueDisplay = document.getElementById('volumeValue');
  if (valueDisplay) {
    valueDisplay.textContent = Math.round(gameSettings.volume * 100) + '%';
  }
}

function updateDifficulty(value) {
  gameSettings.difficulty = value;
  localStorage.setItem('gameDifficulty', value);
  console.log('游戏难度设置为:', value);
}

function showSettlementPage() {
  console.log('====== showSettlementPage 被调用 ======');
  console.log('roundHistory 长度:', gameState.roundHistory.length);
  console.log('roundHistory 内容:', JSON.stringify(gameState.roundHistory));
  
  const settlementPage = document.getElementById('settlementPage');
  const settlementContent = document.getElementById('settlementContent');
  
  let html = '<div class="settlement-rounds">';
  
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
      
      let totalLoserScore = 0;
      if (round.scoreChanges) {
        for (let j = 0; j < gameState.players.length; j++) {
          if (j !== round.winnerIndex) {
            totalLoserScore += Math.abs(round.scoreChanges[j]);
          }
        }
      }
      
      const isScoreValid = round.score === totalLoserScore;
      const validIcon = isScoreValid ? '✓' : '✗';
      const validColor = isScoreValid ? '#4ecdc4' : '#ff6b6b';
      
      html += `<div class="score">得分: ${round.score}分 <span style="color: ${validColor}; font-size: 12px;">(${validIcon} 输家共${totalLoserScore}分)</span></div>`;
      
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
  
  const totalScores = gameState.players.map(p => p.score);
  const maxScore = Math.max(...totalScores);
  const winners = gameState.players.filter((p, i) => totalScores[i] === maxScore);
  
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
  
  // 添加滑动关闭功能
  setupSwipeToClose(settlementPage, closeSettlement);
}

function closeSettlement() {
  const settlementPage = document.getElementById('settlementPage');
  settlementPage.classList.remove('show');
  settlementPage.style.display = 'none';
  
  const messageArea = document.getElementById('messageArea');
  if (messageArea) {
    messageArea.classList.remove('show');
    messageArea.dataset.liuju = 'false';
  }
  
  const dealingOverlay = document.getElementById('dealingOverlay');
  const dealingMask = document.getElementById('dealingMask');
  if (dealingOverlay) {
    dealingOverlay.classList.add('hidden');
    dealingOverlay.style.display = 'none';
  }
  if (dealingMask) {
    dealingMask.classList.add('hidden');
    dealingMask.style.display = 'none';
  }
  
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
  gameState.isHandlingHu = false;
  gameState.isStartingRound = false;
  gameState.isLiuJuHandled = false;
  gameState.isClosingMessage = false;
  gameState.isClosingHuMessage = false;
  gameState.countdown = 0;
  gameState.dealerIndex = 0;
  gameState.canChi = false;
  gameState.canPeng = false;
  gameState.canZhao = false;
  gameState.canHu = false;
  gameState.skipDraw = false;
  gameState.isDrawing = false;
  gameState.gameStarted = false;
  
  if (gameState.countdownTimer) {
    clearInterval(gameState.countdownTimer);
    gameState.countdownTimer = null;
  }
  
  for (const player of gameState.players) {
    player.score = 0;
    player.piao = undefined;
    player.hand = [];
    player.melds = [];
    player.discards = [];
    player.isTing = false;
    player.tingCards = [];
  }
  
  updateUI();
  
  const startScreen = document.getElementById('startScreen');
  const gameContainer = document.querySelector('.game-container');
  
  startScreen.classList.remove('hidden');
  startScreen.style.display = '';
  startScreen.style.visibility = 'visible';
  
  gameContainer.style.display = 'none';
  
  document.getElementById('roundNum').textContent = '1/8';
  
  console.log('结算页面已关闭，游戏已重置');
}

document.addEventListener('DOMContentLoaded', () => {
  loadGameSettings();
  
  gameState.deck = createDeck();
  updateUI();
  
  initSwipeToClose();
  
  const myAvatar = document.getElementById('myAvatar');
  if (myAvatar) {
    myAvatar.style.cursor = 'pointer';
    myAvatar.addEventListener('click', openSettings);
  }
  
  updateTime();
  setInterval(updateTime, 1000);
});

function updateTime() {
  const now = new Date();
  const hours = String(now.getHours()).padStart(2, '0');
  const minutes = String(now.getMinutes()).padStart(2, '0');
  const seconds = String(now.getSeconds()).padStart(2, '0');
  const timeStr = `${hours}:${minutes}:${seconds}`;
  const timeEl = document.getElementById('currentTime');
  if (timeEl) {
    timeEl.textContent = timeStr;
  }
}

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
