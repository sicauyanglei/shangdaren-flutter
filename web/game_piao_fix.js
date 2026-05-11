let piaoCountdown = 10;
let piaoCountdownTimer = null;
let currentPiaoPlayerIndex = 0;
let piaoSettingStarted = false;

function showPiaoScreen() {
  currentPiaoPlayerIndex = gameState.dealerIndex;
  piaoSettingStarted = false;
  showPlayerPiaoScreen();
}

function showPlayerPiaoScreen() {
  const player = gameState.players[currentPiaoPlayerIndex];
  
  const piaoSetting = document.getElementById('piaoSetting');
  const piaoSettingTitle = document.getElementById('piaoSettingTitle');
  const piaoSettingOptions = document.getElementById('piaoSettingOptions');
  
  piaoSetting.classList.remove('hidden');
  piaoSettingTitle.textContent = `${player.name} 飘分设置中...`;
  piaoSettingOptions.style.display = 'none';
  
  if (player.type === 'ai') {
    setTimeout(() => {
      const piao = Math.random() > 0.7 ? 5 : 0;
      player.piao = piao;
      moveToNextPiaoPlayer();
    }, 1000);
  } else {
    piaoSettingOptions.style.display = 'block';
    piaoCountdown = 10;
    updatePiaoCountdown();
    piaoCountdownTimer = setInterval(() => {
      piaoCountdown--;
      updatePiaoCountdown();
      if (piaoCountdown <= 0) {
        clearInterval(piaoCountdownTimer);
        setPiao(0);
      }
    }, 1000);
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
  
  gameState.players[currentPiaoPlayerIndex].piao = piao;
  document.getElementById('piaoSetting').classList.add('hidden');
  moveToNextPiaoPlayer();
}

function moveToNextPiaoPlayer() {
  currentPiaoPlayerIndex = (currentPiaoPlayerIndex + 1) % 3;
  
  if (currentPiaoPlayerIndex === gameState.dealerIndex) {
    document.getElementById('piaoSetting').classList.add('hidden');
    startDealingAnimation();
  } else {
    showPlayerPiaoScreen();
  }
}
