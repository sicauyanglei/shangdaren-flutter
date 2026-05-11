import {
  Card,
  Meld,
  GameState,
  HuMethod,
  HuResult,
  TingStatus,
  PiaoScore,
  RoundSettlement,
  PlayerVoiceType,
  MeldSource
} from '../types';
import { ScoringSystem } from './ScoringSystem';
import { Deck, createFullDeck } from './Deck';
import { Player } from './Player';
import { AIPlayer } from './AIPlayer';

export interface GameConfig {
  baseScore: number;
  multiplierBase: number;
  countdownDuration: number;
  roundsPerSession: number;
}

export interface GameEvent {
  type: string;
  data: any;
}

export type GameEventListener = (event: GameEvent) => void;

export class GameEngine {
  private deck: Deck;
  private players: Player[];
  private currentPlayerIndex: number;
  private dealerIndex: number;
  private roundNumber: number;
  private sessionNumber: number;
  private state: GameState;
  private lastDiscardedCard: Card | null;
  private lastDiscardPlayerIndex: number;
  private scoringSystem: ScoringSystem;
  private config: GameConfig;
  private listeners: GameEventListener[];
  private countdownTimer: NodeJS.Timeout | null;
  private remainingTime: number;
  private roundSettlement: RoundSettlement | null;

  constructor(config?: Partial<GameConfig>) {
    this.config = {
      baseScore: config?.baseScore ?? 10,
      multiplierBase: config?.multiplierBase ?? 10,
      countdownDuration: config?.countdownDuration ?? 30,
      roundsPerSession: config?.roundsPerSession ?? 8
    };
    
    this.deck = new Deck();
    this.players = [];
    this.currentPlayerIndex = 0;
    this.dealerIndex = 0;
    this.roundNumber = 0;
    this.sessionNumber = 1;
    this.state = GameState.WAITING;
    this.lastDiscardedCard = null;
    this.lastDiscardPlayerIndex = -1;
    this.scoringSystem = new ScoringSystem();
    this.listeners = [];
    this.countdownTimer = null;
    this.remainingTime = 0;
    this.roundSettlement = null;
  }

  initializePlayers(): void {
    this.players = [
      new AIPlayer('player1', '玩家1', PlayerVoiceType.MALE, 'normal'),
      new Player('me', '我', 'human' as any, PlayerVoiceType.FEMALE),
      new AIPlayer('player2', '玩家2', PlayerVoiceType.CHILD, 'normal')
    ];
  }

  addEventListener(listener: GameEventListener): void {
    this.listeners.push(listener);
  }

  removeEventListener(listener: GameEventListener): void {
    const index = this.listeners.indexOf(listener);
    if (index !== -1) {
      this.listeners.splice(index, 1);
    }
  }

  private emit(event: GameEvent): void {
    this.listeners.forEach(listener => listener(event));
  }

  getState(): GameState {
    return this.state;
  }

  getRoundNumber(): number {
    return this.roundNumber;
  }

  getSessionNumber(): number {
    return this.sessionNumber;
  }

  getCurrentPlayer(): Player {
    return this.players[this.currentPlayerIndex];
  }

  getCurrentPlayerIndex(): number {
    return this.currentPlayerIndex;
  }

  getPlayers(): Player[] {
    return [...this.players];
  }

  getPlayerById(id: string): Player | undefined {
    return this.players.find(p => p.id === id);
  }

  getLastDiscardedCard(): Card | null {
    return this.lastDiscardedCard;
  }

  getRemainingTime(): number {
    return this.remainingTime;
  }

  getDeckRemainingCount(): number {
    return this.deck.getRemainingCount();
  }

  startSession(): void {
    this.sessionNumber++;
    this.roundNumber = 0;
    
    for (const player of this.players) {
      player.resetSessionScore();
    }
    
    this.emit({ type: 'session_started', data: { sessionNumber: this.sessionNumber } });
    this.startRound();
  }

  startRound(): void {
    this.roundNumber++;
    this.state = GameState.SETTING_PIAO;
    
    for (const player of this.players) {
      player.reset();
    }
    
    this.deck.reset();
    this.deck.shuffle();
    this.lastDiscardedCard = null;
    this.lastDiscardPlayerIndex = -1;
    this.roundSettlement = null;
    
    this.emit({ type: 'round_started', data: { roundNumber: this.roundNumber } });
  }

  setPiao(playerId: string, piaoScore: PiaoScore): void {
    const player = this.getPlayerById(playerId);
    if (player) {
      player.setPiaoScore(piaoScore);
      this.emit({ type: 'piao_set', data: { playerId, piaoScore } });
    }
  }

  dealCards(): void {
    this.state = GameState.DEALING;
    
    const dealer = this.players[this.dealerIndex];
    const otherPlayers = this.players.filter((_, i) => i !== this.dealerIndex);
    
    for (const player of otherPlayers) {
      const cards = this.deck.drawMultiple(17);
      player.receiveCards(cards);
    }
    
    const dealerCards = this.deck.drawMultiple(16);
    dealer.receiveCards(dealerCards);
    
    this.currentPlayerIndex = this.dealerIndex;
    
    this.emit({ type: 'cards_dealt', data: { 
      dealerIndex: this.dealerIndex,
      cardCounts: this.players.map(p => p.getHandCount())
    }});
    
    this.startPlayerTurn();
  }

  private startPlayerTurn(): void {
    this.state = GameState.PLAYER_TURN;
    const currentPlayer = this.getCurrentPlayer();
    
    if (currentPlayer.type === 'human') {
      this.startCountdown();
    } else {
      this.processAITurn();
    }
    
    this.emit({ type: 'turn_started', data: { 
      playerId: currentPlayer.id,
      playerIndex: this.currentPlayerIndex
    }});
  }

  private startCountdown(): void {
    this.stopCountdown();
    this.remainingTime = this.config.countdownDuration;
    
    this.emit({ type: 'countdown_started', data: { duration: this.remainingTime } });
    
    this.countdownTimer = setInterval(() => {
      this.remainingTime--;
      this.emit({ type: 'countdown_tick', data: { remainingTime: this.remainingTime } });
      
      if (this.remainingTime <= 5) {
        this.emit({ type: 'countdown_warning', data: { remainingTime: this.remainingTime } });
      }
      
      if (this.remainingTime <= 0) {
        this.handleTimeout();
      }
    }, 1000);
  }

  private stopCountdown(): void {
    if (this.countdownTimer) {
      clearInterval(this.countdownTimer);
      this.countdownTimer = null;
    }
    this.emit({ type: 'countdown_stopped', data: {} });
  }

  private handleTimeout(): void {
    this.stopCountdown();
    const currentPlayer = this.getCurrentPlayer();
    
    this.emit({ type: 'timeout', data: { playerId: currentPlayer.id } });
    
    if (this.lastDiscardedCard) {
      const huResult = currentPlayer.checkHu(HuMethod.DIAN_PAO, this.lastDiscardedCard);
      if (huResult.canHu) {
        this.handleHu(currentPlayer.id, HuMethod.DIAN_PAO);
        return;
      }
    }
    
    if (this.deck.getRemainingCount() > 0) {
      const drawnCard = this.deck.draw();
      if (drawnCard) {
        currentPlayer.drawCard(drawnCard);
        this.emit({ type: 'card_drawn', data: { playerId: currentPlayer.id, card: drawnCard } });
      }
    }
    
    const handCards = currentPlayer.getHandCards();
    if (handCards.length > 0) {
      this.discardCard(currentPlayer.id, handCards[0]);
    }
  }

  private processAITurn(): void {
    const aiPlayer = this.getCurrentPlayer() as AIPlayer;
    const delay = aiPlayer.getThinkDelay();
    
    setTimeout(() => {
      if (this.deck.getRemainingCount() > 0) {
        const drawnCard = this.deck.draw();
        if (drawnCard) {
          aiPlayer.drawCard(drawnCard);
          this.emit({ type: 'card_drawn', data: { playerId: aiPlayer.id, card: drawnCard } });
        }
      }
      
      const huResult = aiPlayer.checkHu(HuMethod.ZI_MO);
      if (huResult.canHu) {
        this.handleHu(aiPlayer.id, HuMethod.ZI_MO);
        return;
      }
      
      aiPlayer.updateTingStatus();
      
      const cardToDiscard = aiPlayer.selectDiscardCard();
      this.discardCard(aiPlayer.id, cardToDiscard);
    }, delay);
  }

  discardCard(playerId: string, card: Card): void {
    const player = this.getPlayerById(playerId);
    if (!player || player.id !== this.getCurrentPlayer().id) {
      return;
    }
    
    this.stopCountdown();
    
    const record = player.discardCard(card, this.roundNumber);
    this.lastDiscardedCard = card;
    this.lastDiscardPlayerIndex = this.currentPlayerIndex;
    
    this.emit({ type: 'card_discarded', data: { 
      playerId, 
      card,
      discardIndex: player.getDiscardHistory().length - 1
    }});
    
    this.state = GameState.WAITING_RESPONSE;
    this.checkResponses();
  }

  private checkResponses(): void {
    if (!this.lastDiscardedCard) return;
    
    const responses: { playerIndex: number; canHu: boolean; canZhao: boolean; canPeng: boolean; canChi: boolean }[] = [];
    
    for (let i = 0; i < this.players.length; i++) {
      if (i === this.lastDiscardPlayerIndex) continue;
      
      const player = this.players[i];
      const canHu = player.checkHu(HuMethod.DIAN_PAO, this.lastDiscardedCard!).canHu;
      const canZhao = player.canZhao(this.lastDiscardedCard!);
      const canPeng = player.canPeng(this.lastDiscardedCard!);
      const canChi = i === (this.lastDiscardPlayerIndex + 1) % this.players.length && 
                     player.canChi(this.lastDiscardedCard!);
      
      responses.push({ playerIndex: i, canHu, canZhao, canPeng, canChi });
    }
    
    const huResponse = responses.find(r => r.canHu);
    if (huResponse) {
      const player = this.players[huResponse.playerIndex];
      if (player.type === 'human') {
        this.emit({ type: 'hu_opportunity', data: { playerId: player.id, card: this.lastDiscardedCard } });
      } else {
        this.handleHu(player.id, HuMethod.DIAN_PAO);
      }
      return;
    }
    
    const zhaoResponse = responses.find(r => r.canZhao);
    if (zhaoResponse) {
      const player = this.players[zhaoResponse.playerIndex];
      if (player.type === 'human') {
        this.emit({ type: 'zhao_opportunity', data: { playerId: player.id, card: this.lastDiscardedCard } });
      } else {
        this.handleZhao(player.id);
      }
      return;
    }
    
    const pengResponse = responses.find(r => r.canPeng);
    if (pengResponse) {
      const player = this.players[pengResponse.playerIndex];
      if (player.type === 'human') {
        this.emit({ type: 'peng_opportunity', data: { playerId: player.id, card: this.lastDiscardedCard } });
      } else {
        const aiPlayer = player as AIPlayer;
        if (aiPlayer.decidePeng(this.lastDiscardedCard!)) {
          this.handlePeng(player.id);
          return;
        }
      }
    }
    
    const chiResponse = responses.find(r => r.canChi);
    if (chiResponse) {
      const player = this.players[chiResponse.playerIndex];
      if (player.type === 'human') {
        this.emit({ type: 'chi_opportunity', data: { playerId: player.id, card: this.lastDiscardedCard } });
      } else {
        const aiPlayer = player as AIPlayer;
        if (aiPlayer.decideChi(this.lastDiscardedCard!)) {
          this.handleChi(player.id);
          return;
        }
      }
    }
    
    this.emit({ type: 'response_check_complete', data: { responses } });
    
    setTimeout(() => {
      this.moveToNextPlayer();
    }, 500);
  }

  handleChi(playerId: string): void {
    const player = this.getPlayerById(playerId);
    if (!player || !this.lastDiscardedCard) return;
    
    const meld = player.performChi(this.lastDiscardedCard, this.players[this.lastDiscardPlayerIndex].id);
    if (meld) {
      const discardPlayer = this.players[this.lastDiscardPlayerIndex];
      const discardHistory = discardPlayer.getDiscardHistory();
      const lastIndex = discardHistory.length - 1;
      discardPlayer.markDiscardTaken(lastIndex, playerId, 'chi');
      discardPlayer.removeDiscardRecord(lastIndex);
      
      this.emit({ type: 'chi_performed', data: { 
        playerId, 
        meld,
        meldDisplay: {
          displayText: meld.cards.map((c: Card) => c.character).join(''),
          huValue: meld.huValue
        }
      }});
      
      this.currentPlayerIndex = this.players.indexOf(player);
      this.lastDiscardedCard = null;
      this.startPlayerTurn();
    }
  }

  handlePeng(playerId: string): void {
    const player = this.getPlayerById(playerId);
    if (!player || !this.lastDiscardedCard) return;
    
    const meld = player.performPeng(this.lastDiscardedCard, this.players[this.lastDiscardPlayerIndex].id);
    if (meld) {
      const discardPlayer = this.players[this.lastDiscardPlayerIndex];
      const discardHistory = discardPlayer.getDiscardHistory();
      const lastIndex = discardHistory.length - 1;
      discardPlayer.markDiscardTaken(lastIndex, playerId, 'peng');
      discardPlayer.removeDiscardRecord(lastIndex);
      
      this.emit({ type: 'peng_performed', data: { 
        playerId, 
        meld,
        meldDisplay: {
          displayText: meld.cards.map((c: Card) => c.character).join(''),
          huValue: meld.huValue
        }
      }});
      
      this.currentPlayerIndex = this.players.indexOf(player);
      this.lastDiscardedCard = null;
      this.startPlayerTurn();
    }
  }

  handleZhao(playerId: string): void {
    const player = this.getPlayerById(playerId);
    if (!player || !this.lastDiscardedCard) return;
    
    const meld = player.performZhao(this.lastDiscardedCard, this.players[this.lastDiscardPlayerIndex].id);
    if (meld) {
      const discardPlayer = this.players[this.lastDiscardPlayerIndex];
      const discardHistory = discardPlayer.getDiscardHistory();
      const lastIndex = discardHistory.length - 1;
      discardPlayer.markDiscardTaken(lastIndex, playerId, 'zhao');
      discardPlayer.removeDiscardRecord(lastIndex);
      
      this.emit({ type: 'zhao_performed', data: { 
        playerId, 
        meld,
        meldDisplay: {
          displayText: meld.cards.map((c: Card) => c.character).join(''),
          huValue: meld.huValue
        }
      }});
      
      this.currentPlayerIndex = this.players.indexOf(player);
      this.lastDiscardedCard = null;
      
      if (this.deck.getRemainingCount() > 0) {
        const drawnCard = this.deck.draw();
        if (drawnCard) {
          player.drawCard(drawnCard);
          this.emit({ type: 'card_drawn_after_zhao', data: { playerId, card: drawnCard } });
        }
      }
      
      this.startPlayerTurn();
    }
  }

  handleHu(playerId: string, method: HuMethod): void {
    const player = this.getPlayerById(playerId);
    if (!player) return;
    
    this.stopCountdown();
    this.state = GameState.ROUND_END;
    
    let huResult: HuResult;
    if (method === HuMethod.DIAN_PAO && this.lastDiscardedCard) {
      huResult = player.checkHu(method, this.lastDiscardedCard);
    } else {
      huResult = player.checkHu(method);
    }
    
    if (!huResult.canHu) return;
    
    const loserIds = this.players
      .filter(p => p.id !== playerId)
      .map(p => p.id);
    
    this.roundSettlement = this.scoringSystem.calculateRoundSettlement(
      playerId,
      loserIds,
      huResult,
      player.getPiaoScore()
    );
    
    const winnerIndex = this.players.indexOf(player);
    for (const payment of this.roundSettlement.payments) {
      const loser = this.getPlayerById(payment.playerId);
      if (loser) {
        loser.addScore(-payment.payment);
      }
    }
    player.addScore(this.roundSettlement.winnerScore);
    
    if (method === HuMethod.DIAN_PAO && this.lastDiscardedCard) {
      const discardPlayer = this.players[this.lastDiscardPlayerIndex];
      const discardHistory = discardPlayer.getDiscardHistory();
      const lastIndex = discardHistory.length - 1;
      discardPlayer.markDiscardTaken(lastIndex, playerId, 'hu');
    }
    
    this.emit({ type: 'hu_performed', data: {
      playerId,
      method,
      huResult,
      settlement: this.roundSettlement,
      huTypeDisplay: this.scoringSystem.getHuTypeDisplayName(huResult),
      methodDisplay: this.scoringSystem.getMethodDisplayName(method)
    }});
    
    this.emit({ type: 'round_ended', data: { settlement: this.roundSettlement } });
    
    if (this.roundNumber >= this.config.roundsPerSession) {
      this.state = GameState.SESSION_END;
      this.emit({ type: 'session_ended', data: { 
        finalScores: this.players.map(p => ({ id: p.id, name: p.name, score: p.getScore() }))
      }});
    }
  }

  passResponse(playerId: string): void {
    this.emit({ type: 'pass_response', data: { playerId } });
    
    const allPassed = true;
    if (allPassed) {
      this.moveToNextPlayer();
    }
  }

  private moveToNextPlayer(): void {
    this.currentPlayerIndex = (this.currentPlayerIndex + 1) % this.players.length;
    this.lastDiscardedCard = null;
    
    if (this.deck.isEmpty()) {
      this.state = GameState.ROUND_END;
      this.emit({ type: 'round_draw', data: { reason: 'deck_empty' } });
      return;
    }
    
    this.startPlayerTurn();
  }

  getRoundSettlement(): RoundSettlement | null {
    return this.roundSettlement;
  }

  nextRound(): void {
    this.dealerIndex = (this.dealerIndex + 1) % this.players.length;
    this.startRound();
  }

  getGameSummary(): { 
    sessionNumber: number;
    roundNumber: number;
    players: { id: string; name: string; score: number }[];
  } {
    return {
      sessionNumber: this.sessionNumber,
      roundNumber: this.roundNumber,
      players: this.players.map(p => ({
        id: p.id,
        name: p.name,
        score: p.getScore()
      }))
    };
  }
}
