import { Card, Meld, MeldType, MeldSource, CARD_DEFINITIONS } from '../types';
import { createCard } from './Card';

export class Deck {
  private cards: Card[] = [];
  private discardedCards: Card[] = [];

  constructor() {
    this.initialize();
  }

  private initialize(): void {
    this.cards = [];
    this.discardedCards = [];
    
    for (const definition of CARD_DEFINITIONS) {
      for (let i = 0; i < 4; i++) {
        this.cards.push(createCard(definition));
      }
    }
  }

  shuffle(): void {
    for (let i = this.cards.length - 1; i > 0; i--) {
      const j = Math.floor(Math.random() * (i + 1));
      [this.cards[i], this.cards[j]] = [this.cards[j], this.cards[i]];
    }
  }

  draw(): Card | undefined {
    return this.cards.pop();
  }

  drawMultiple(count: number): Card[] {
    const drawn: Card[] = [];
    for (let i = 0; i < count && this.cards.length > 0; i++) {
      const card = this.cards.pop();
      if (card) drawn.push(card);
    }
    return drawn;
  }

  discard(card: Card): void {
    this.discardedCards.push(card);
  }

  getRemainingCount(): number {
    return this.cards.length;
  }

  getDiscardedCards(): Card[] {
    return [...this.discardedCards];
  }

  getLastDiscardedCard(): Card | undefined {
    return this.discardedCards[this.discardedCards.length - 1];
  }

  isEmpty(): boolean {
    return this.cards.length === 0;
  }

  reset(): void {
    this.initialize();
  }
}

export function createFullDeck(): Deck {
  const deck = new Deck();
  deck.shuffle();
  return deck;
}

export function countCards(cards: Card[]): Record<string, number> {
  return cards.reduce((acc, card) => {
    acc[card.character] = (acc[card.character] || 0) + 1;
    return acc;
  }, {} as Record<string, number>);
}

export function findCardsByCharacter(cards: Card[], character: string): Card[] {
  return cards.filter(c => c.character === character);
}

export function findCardsBySentence(cards: Card[], sentence: number): Card[] {
  return cards.filter(c => c.sentence === sentence);
}

export function createMeld(type: MeldType, cards: Card[], source: MeldSource): Meld {
  let huValue = 0;
  const isSpecial = cards[0]?.isSpecial || false;
  
  switch (type) {
    case MeldType.PAIR:
      huValue = isSpecial ? 8 : 0;
      break;
    case MeldType.TRIPLET:
      if (source === MeldSource.HAND) {
        huValue = isSpecial ? 12 : 3;
      } else if (source === MeldSource.PENG) {
        huValue = isSpecial ? 12 : 2;
      }
      break;
    case MeldType.QUARTET:
      huValue = isSpecial ? 16 : 6;
      break;
    case MeldType.SEQUENCE:
      huValue = 0;
      break;
  }
  
  return { type, cards, source, huValue };
}
