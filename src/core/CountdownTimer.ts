export interface CountdownConfig {
  duration: number;
  onTick?: (remainingTime: number) => void;
  onWarning?: (remainingTime: number) => void;
  onTimeout?: () => void;
}

export class CountdownTimer {
  private config: CountdownConfig;
  private timer: NodeJS.Timeout | null;
  private remainingTime: number;
  private isRunning: boolean;

  constructor(config: CountdownConfig) {
    this.config = config;
    this.timer = null;
    this.remainingTime = config.duration;
    this.isRunning = false;
  }

  start(): void {
    if (this.isRunning) return;
    
    this.isRunning = true;
    this.remainingTime = this.config.duration;
    
    this.timer = setInterval(() => {
      this.remainingTime--;
      
      if (this.config.onTick) {
        this.config.onTick(this.remainingTime);
      }
      
      if (this.remainingTime <= 5 && this.config.onWarning) {
        this.config.onWarning(this.remainingTime);
      }
      
      if (this.remainingTime <= 0) {
        this.stop();
        if (this.config.onTimeout) {
          this.config.onTimeout();
        }
      }
    }, 1000);
  }

  stop(): void {
    if (this.timer) {
      clearInterval(this.timer);
      this.timer = null;
    }
    this.isRunning = false;
  }

  reset(): void {
    this.stop();
    this.remainingTime = this.config.duration;
  }

  getRemainingTime(): number {
    return this.remainingTime;
  }

  isCurrentlyRunning(): boolean {
    return this.isRunning;
  }

  setDuration(duration: number): void {
    this.config.duration = duration;
    if (!this.isRunning) {
      this.remainingTime = duration;
    }
  }
}
