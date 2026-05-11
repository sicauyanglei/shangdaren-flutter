import { Card, Meld, MeldType, PlayerType, PlayerVoiceType, HuMethod, TingStatus } from '../types';
import { Player } from './Player';

export interface AIAction {
  type: 'discard' | 'chi' | 'peng' | 'zhao' | 'hu' | 'pass';
  card?: Card;
  cards?: Card[];
}

export class AIPlayer extends Player {
  private difficulty: 'easy' | 'normal' | 'hard';

  constructor(
    id: string,
    name: string,
    voiceType: PlayerVoiceType,
    difficulty: 'easy' | 'normal' | 'hard' = 'normal'
  ) {
    super(id, name, PlayerType.AI, voiceType);
    this.difficulty = difficulty;
  }

  selectDiscardCard(): Card {
    const handCards = this.getHandCards();
    if (handCards.length === 0) {
      throw new Error('No cards to discard');
    }

    const scoredCards = handCards.map(card => ({
      card,
      score: this.evaluateCard(card)
    }));

    scoredCards.sort((a, b) => a.score - b.score);

    return scoredCards[0].card;
  }

  private evaluateCard(card: Card): number {
    let score = 0;

    if (card.isSpecial) {
      score += 100;
    }

    const sameCharCount = this.handCards.filter(c => c.character === card.character).length;
    if (sameCharCount >= 2) {
      score += 50 * sameCharCount;
    }

    const sentenceCards = this.handCards.filter(c => c.sentence === card.sentence);
    if (sentenceCards.length >= 2) {
      score += 30;
    }

    score += card.baseHu * 10;

    if (this.difficulty === 'hard') {
      const tingStatus = this.getTingStatus();
      if (tingStatus?.isTing) {
        const isTingCard = tingStatus.tingCards.some(c => c.character === card.character);
        if (isTingCard) {
          score += 1000;
        }
      }
    }

    return score;
  }

  decideChi(card: Card): boolean {
    if (!this.canChi(card)) return false;

    if (this.difficulty === 'easy') {
      return Math.random() > 0.5;
    }

    const sentenceCards = this.handCards.filter(c => c.sentence === card.sentence);
    const wouldComplete = sentenceCards.length === 2;

    if (wouldComplete) {
      return true;
    }

    if (this.difficulty === 'hard') {
      const testHand = [...this.handCards];
      const sentenceCardsInHand = testHand.filter(c => c.sentence === card.sentence);
      if (sentenceCardsInHand.length >= 2) {
        return true;
      }
    }

    return this.difficulty === 'normal' ? Math.random() > 0.3 : true;
  }

  decidePeng(card: Card): boolean {
    if (!this.canPeng(card)) return false;

    if (card.isSpecial) {
      return true;
    }

    if (this.difficulty === 'easy') {
      return Math.random() > 0.5;
    }

    const sameCharCount = this.handCards.filter(c => c.character === card.character).length;
    if (sameCharCount >= 2) {
      return true;
    }

    return this.difficulty === 'hard';
  }

  decideZhao(card: Card): boolean {
    if (!this.canZhao(card)) return false;

    return true;
  }

  decideHu(huResult: { canHu: boolean; huCount: number }): boolean {
    return huResult.canHu;
  }

  respondToDiscard(
    card: Card,
    canChi: boolean,
    canPeng: boolean,
    canZhao: boolean,
    canHu: boolean,
    huResult?: { canHu: boolean; huCount: number }
  ): AIAction {
    if (canHu && huResult && this.decideHu(huResult)) {
      return { type: 'hu', card };
    }

    if (canZhao && this.decideZhao(card)) {
      return { type: 'zhao', card };
    }

    if (canPeng && this.decidePeng(card)) {
      return { type: 'peng', card };
    }

    if (canChi && this.decideChi(card)) {
      return { type: 'chi', card };
    }

    return { type: 'pass' };
  }

  getThinkDelay(): number {
    const baseDelay = this.difficulty === 'easy' ? 500 : 
                      this.difficulty === 'normal' ? 800 : 1000;
    return baseDelay + Math.random() * 500;
  }

  selectPiaoScore(): number {
    if (this.difficulty === 'easy') {
      return 0;
    }

    const huCount = this.getHuCount();
    
    if (huCount >= 20) {
      return 20;
    } else if (huCount >= 15) {
      return 10;
    } else if (huCount >= 10) {
      return 5;
    }
    
    return 0;
  }
}
