import { 
  Card, 
  Meld, 
  MeldType, 
  MeldSource, 
  PlayerType, 
  PlayerVoiceType,
  TingStatus,
  PiaoScore,
  HuResult,
  HuMethod
} from '../types';
import { HuCalculator } from './HuCalculator';
import { HuValidator } from './HuValidator';
import { TingDetector } from './TingDetector';
import { countCards, createMeld } from './Deck';

export interface DiscardRecord {
  card: Card;
  round: number;
  takenBy?: string;
  action?: 'chi' | 'peng' | 'zhao' | 'hu';
}

export interface MeldDisplay {
  meld: Meld;
  displayText: string;
  huValue: number;
}

export class Player {
  id: string;
  name: string;
  type: PlayerType;
  voiceType: PlayerVoiceType;
  
  protected handCards: Card[] = [];
  protected melds: Meld[] = [];
  protected discardHistory: DiscardRecord[] = [];
  protected piaoScore: PiaoScore = PiaoScore.NONE;
  protected score: number = 0;
  protected roundScore: number = 0;
  
  protected tingStatus: TingStatus | null = null;
  
  protected calculator: HuCalculator;
  protected validator: HuValidator;
  protected tingDetector: TingDetector;

  constructor(
    id: string,
    name: string,
    type: PlayerType,
    voiceType: PlayerVoiceType
  ) {
    this.id = id;
    this.name = name;
    this.type = type;
    this.voiceType = voiceType;
    this.calculator = new HuCalculator();
    this.validator = new HuValidator();
    this.tingDetector = new TingDetector();
  }

  getHandCards(): Card[] {
    return [...this.handCards];
  }

  getMelds(): Meld[] {
    return [...this.melds];
  }

  getMeldDisplays(): MeldDisplay[] {
    return this.melds.map(meld => ({
      meld,
      displayText: meld.cards.map(c => c.character).join(''),
      huValue: meld.huValue
    }));
  }

  getDiscardHistory(): DiscardRecord[] {
    return [...this.discardHistory];
  }

  getPiaoScore(): PiaoScore {
    return this.piaoScore;
  }

  setPiaoScore(score: PiaoScore): void {
    this.piaoScore = score;
  }

  getScore(): number {
    return this.score;
  }

  getRoundScore(): number {
    return this.roundScore;
  }

  addScore(points: number): void {
    this.score += points;
    this.roundScore += points;
  }

  resetRoundScore(): void {
    this.roundScore = 0;
  }

  resetSessionScore(): void {
    this.score = 0;
    this.roundScore = 0;
  }

  getHandCount(): number {
    return this.handCards.length;
  }

  receiveCards(cards: Card[]): void {
    this.handCards.push(...cards);
    this.sortHandCards();
  }

  drawCard(card: Card): void {
    this.handCards.push(card);
  }

  protected sortHandCards(): void {
    this.handCards.sort((a, b) => {
      if (a.sentence !== b.sentence) return a.sentence - b.sentence;
      return a.position - b.position;
    });
  }

  discardCard(card: Card, round: number): DiscardRecord {
    const index = this.handCards.findIndex(c => c.id === card.id);
    if (index === -1) {
      throw new Error(`Card ${card.character} not found in hand`);
    }
    
    this.handCards.splice(index, 1);
    
    const record: DiscardRecord = {
      card,
      round
    };
    this.discardHistory.push(record);
    
    return record;
  }

  markDiscardTaken(discardIndex: number, playerId: string, action: 'chi' | 'peng' | 'zhao' | 'hu'): void {
    if (discardIndex >= 0 && discardIndex < this.discardHistory.length) {
      this.discardHistory[discardIndex].takenBy = playerId;
      this.discardHistory[discardIndex].action = action;
    }
  }

  removeDiscardRecord(index: number): void {
    if (index >= 0 && index < this.discardHistory.length) {
      this.discardHistory.splice(index, 1);
    }
  }

  canChi(card: Card): boolean {
    const sentenceCards = this.handCards.filter(c => c.sentence === card.sentence);
    if (sentenceCards.length < 2) return false;

    const positions = new Set(sentenceCards.map(c => c.position));
    const cardPosition = card.position;

    if (cardPosition === 0) {
      return positions.has(1) && positions.has(2);
    } else if (cardPosition === 1) {
      return (positions.has(0) && positions.has(2)) || 
             (positions.has(0) && positions.has(2));
    } else if (cardPosition === 2) {
      return positions.has(0) && positions.has(1);
    }

    return false;
  }

  canPeng(card: Card): boolean {
    const count = this.handCards.filter(c => c.character === card.character).length;
    return count >= 2;
  }

  canZhao(card: Card): boolean {
    const count = this.handCards.filter(c => c.character === card.character).length;
    return count === 3;
  }

  performChi(card: Card, sourcePlayerId: string): Meld | null {
    if (!this.canChi(card)) return null;

    const sentenceCards = this.handCards.filter(c => c.sentence === card.sentence);
    const positions = sentenceCards.map(c => c.position);
    
    let chiCards: Card[] = [];
    
    if (card.position === 0) {
      const card1 = sentenceCards.find(c => c.position === 1);
      const card2 = sentenceCards.find(c => c.position === 2);
      if (card1 && card2) chiCards = [card, card1, card2];
    } else if (card.position === 1) {
      const card0 = sentenceCards.find(c => c.position === 0);
      const card2 = sentenceCards.find(c => c.position === 2);
      if (card0 && card2) chiCards = [card0, card, card2];
    } else if (card.position === 2) {
      const card0 = sentenceCards.find(c => c.position === 0);
      const card1 = sentenceCards.find(c => c.position === 1);
      if (card0 && card1) chiCards = [card0, card1, card];
    }

    if (chiCards.length !== 3) return null;

    for (const c of chiCards) {
      if (c.id !== card.id) {
        const index = this.handCards.findIndex(h => h.id === c.id);
        if (index !== -1) this.handCards.splice(index, 1);
      }
    }

    const meld = createMeld(MeldType.SEQUENCE, chiCards, MeldSource.CHI);
    this.melds.push(meld);
    
    return meld;
  }

  performPeng(card: Card, sourcePlayerId: string): Meld | null {
    if (!this.canPeng(card)) return null;

    const matchingCards = this.handCards.filter(c => c.character === card.character);
    const pengCards = [card, matchingCards[0], matchingCards[1]];
    
    for (let i = 0; i < 2; i++) {
      const index = this.handCards.findIndex(c => c.id === matchingCards[i].id);
      if (index !== -1) this.handCards.splice(index, 1);
    }

    const meld = createMeld(MeldType.TRIPLET, pengCards, MeldSource.PENG);
    this.melds.push(meld);
    
    return meld;
  }

  performZhao(card: Card, sourcePlayerId: string): Meld | null {
    if (!this.canZhao(card)) return null;

    const matchingCards = this.handCards.filter(c => c.character === card.character);
    const zhaoCards = [card, ...matchingCards];
    
    for (const c of matchingCards) {
      const index = this.handCards.findIndex(h => h.id === c.id);
      if (index !== -1) this.handCards.splice(index, 1);
    }

    const meld = createMeld(MeldType.QUARTET, zhaoCards, MeldSource.ZHAO);
    this.melds.push(meld);
    
    return meld;
  }

  checkHu(method: HuMethod, discardedCard?: Card): HuResult {
    let testHand = [...this.handCards];
    if (discardedCard && method === HuMethod.DIAN_PAO) {
      testHand.push(discardedCard);
    }
    
    return this.validator.validateHu(testHand, this.melds, method, discardedCard);
  }

  updateTingStatus(): TingStatus {
    this.tingStatus = this.tingDetector.detectTing(this.handCards, this.melds);
    return this.tingStatus;
  }

  getTingStatus(): TingStatus | null {
    return this.tingStatus;
  }

  isTing(): boolean {
    return this.tingStatus?.isTing ?? false;
  }

  getHuCount(): number {
    const detail = this.calculator.calculateTotalHu(this.handCards, this.melds);
    return detail.totalHu;
  }

  getHuDetail() {
    return this.calculator.calculateTotalHu(this.handCards, this.melds);
  }

  reset(): void {
    this.handCards = [];
    this.melds = [];
    this.discardHistory = [];
    this.piaoScore = PiaoScore.NONE;
    this.tingStatus = null;
    this.roundScore = 0;
  }

  hasHandTriplet(character: string): boolean {
    const count = this.handCards.filter(c => c.character === character).length;
    return count >= 3;
  }

  hasHandQuartet(character: string): boolean {
    const count = this.handCards.filter(c => c.character === character).length;
    return count === 4;
  }

  createHandMeld(character: string, type: MeldType): Meld | null {
    const matchingCards = this.handCards.filter(c => c.character === character);
    
    if (type === MeldType.TRIPLET && matchingCards.length >= 3) {
      const cards = matchingCards.slice(0, 3);
      for (const c of cards) {
        const index = this.handCards.findIndex(h => h.id === c.id);
        if (index !== -1) this.handCards.splice(index, 1);
      }
      const meld = createMeld(MeldType.TRIPLET, cards, MeldSource.HAND);
      this.melds.push(meld);
      return meld;
    }
    
    if (type === MeldType.QUARTET && matchingCards.length === 4) {
      for (const c of matchingCards) {
        const index = this.handCards.findIndex(h => h.id === c.id);
        if (index !== -1) this.handCards.splice(index, 1);
      }
      const meld = createMeld(MeldType.QUARTET, matchingCards, MeldSource.HAND);
      this.melds.push(meld);
      return meld;
    }
    
    return null;
  }
}
