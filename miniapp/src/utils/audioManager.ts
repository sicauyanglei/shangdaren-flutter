/**
 * 音效管理器 - 匹配 Flame 版本 AudioManager
 * 使用微信小游戏 InnerAudioContext API
 */

// 音效文件映射（匹配Flame的_audioFileMap）
const AUDIO_FILE_MAP: Record<string, string> = {
  '吃': 'chi',
  '碰': 'peng',
  '招': 'zhao',
  '胡': 'hu',
  '自摸': 'zimo',
  '出牌': 'chupai',
  '过': 'guo',
  '快点吧': 'kuaidianba',
  '流局': 'liuju',
  '上': 'shang',
  '大': 'da',
  '人': 'ren',
  '丘': 'qiu',
  '乙': 'yi',
  '己': 'ji',
  '化': 'hua',
  '三': 'san',
  '千': 'qian',
  '七': 'qi',
  '十': 'shi',
  '土': 'tu',
  '尔': 'er',
  '小': 'xiao',
  '生': 'sheng',
  '八': 'ba',
  '九': 'jiu',
  '子': 'zi',
  '佳': 'jia',
  '作': 'zuo',
  '亡': 'wang',
  '福': 'fu',
  '禄': 'lu',
  '寿': 'shou',
  '枯胡': 'kuhu',
  '清枯胡': 'qingkuhu',
  '枯台胡': 'kutaihu',
  '枯重台卡': 'kuchongtaika',
  '枯重台胡': 'kuchongtaihu',
  '清枯台卡': 'qingkutaika',
  '清枯台胡': 'qingkutaihu',
  '清枯重台卡': 'qingkuchongtaika',
  '清枯重台胡': 'qingkuchongtaihu',
  '十对': 'shidui',
  '黑元': 'heiyuan',
  '红元': 'hongyuan',
  '红元3精': 'hongyuan3jing',
  '红元4精': 'hongyuan4jing',
  '红元5精': 'hongyuan5jing',
  '红元6精': 'hongyuan6jing',
  '清胡': 'qinghu',
  '清卡胡': 'qingkahu',
  '卡胡': 'kahu',
  '普通胡': 'putonghu',
  '台卡': 'taika',
  '台胡': 'taihu',
  '重台卡': 'chongtaika',
  '重台胡': 'chongtaihu',
};

class AudioManager {
  private static instance: AudioManager;
  private voiceType: string = 'male';
  private volume: number = 1.0;
  private audioPool: Map<string, any> = new Map();
  private delayedAudio: any = null;

  private constructor() {}

  static getInstance(): AudioManager {
    if (!AudioManager.instance) {
      AudioManager.instance = new AudioManager();
    }
    return AudioManager.instance;
  }

  setVoiceType(type: string) {
    this.voiceType = type;
  }

  setVolume(volume: number) {
    this.volume = Math.max(0, Math.min(1, volume));
  }

  private getAudioContext(_key: string): any {
    // 微信小游戏环境使用 Taro.createInnerAudioContext
    try {
      // @ts-ignore
      if (typeof wx !== 'undefined' && wx.createInnerAudioContext) {
        // @ts-ignore
        const ctx = wx.createInnerAudioContext();
        return ctx;
      }
    } catch (_) {}
    return null;
  }

  private getAudioPath(text: string): string | null {
    const fileName = AUDIO_FILE_MAP[text];
    if (!fileName) return null;
    return `audio/${this.voiceType}/${fileName}.mp3`;
  }

  play(text: string, volumeMultiplier: number = 1.0) {
    const path = this.getAudioPath(text);
    if (!path) return;

    const ctx = this.getAudioContext(text);
    if (!ctx) return;

    ctx.src = path;
    ctx.volume = Math.max(0, Math.min(1, this.volume * volumeMultiplier));
    ctx.onError(() => {
      // 静默处理错误
    });
    ctx.play();

    // 播放完成后释放
    ctx.onEnded(() => {
      ctx.destroy();
    });

    // 替换同类型音效
    const existing = this.audioPool.get(text);
    if (existing) {
      try { existing.destroy(); } catch (_) {}
    }
    this.audioPool.set(text, ctx);
  }

  playDelayed(text: string, delayMs: number = 1000, volumeMultiplier: number = 1.0) {
    // 清除之前的延迟播放
    if (this.delayedAudio) {
      try { this.delayedAudio.destroy(); } catch (_) {}
    }

    setTimeout(() => {
      this.play(text, volumeMultiplier);
    }, delayMs);
  }

  playDiscard(character: string) {
    this.play(character);
  }

  playChi() {
    this.play('吃');
  }

  playPeng() {
    this.play('碰');
  }

  playZhao() {
    this.play('招');
  }

  playHu() {
    this.play('胡', 1.5);
  }

  playZimo() {
    this.play('自摸', 1.5);
  }

  playGuo() {
    this.play('过');
  }

  playLiuju() {
    this.play('流局');
  }

  playHurry() {
    this.play('快点吧');
  }

  playHuType(huTypeName: string, delayMs: number = 1000) {
    this.playDelayed(huTypeName, delayMs, 1.5);
  }

  stop() {
    for (const [, ctx] of this.audioPool) {
      try { ctx.stop(); ctx.destroy(); } catch (_) {}
    }
    this.audioPool.clear();
    if (this.delayedAudio) {
      try { this.delayedAudio.stop(); this.delayedAudio.destroy(); } catch (_) {}
      this.delayedAudio = null;
    }
  }
}

export const audioManager = AudioManager.getInstance();
export default audioManager;
