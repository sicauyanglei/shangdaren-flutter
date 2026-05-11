import { Deck, createFullDeck, countCards, createMeld } from '../core/Deck';
import { createCard } from '../core/Card';
import { CARD_DEFINITIONS, MeldType, MeldSource } from '../types';

describe('Deck', () => {
  let deck: Deck;

  beforeEach(() => {
    deck = new Deck();
  });

  describe('initialization', () => {
    it('should create 96 cards (24 unique * 4 copies)', () => {
      expect(deck.getRemainingCount()).toBe(96);
    });

    it('should have empty discarded cards initially', () => {
      expect(deck.getDiscardedCards()).toHaveLength(0);
    });
  });

  describe('draw', () => {
    it('should draw one card', () => {
      const card = deck.draw();
      expect(card).toBeDefined();
      expect(deck.getRemainingCount()).toBe(95);
    });

    it('should return undefined when deck is empty', () => {
      for (let i = 0; i < 96; i++) {
        deck.draw();
      }
      expect(deck.draw()).toBeUndefined();
    });
  });

  describe('drawMultiple', () => {
    it('should draw multiple cards', () => {
      const cards = deck.drawMultiple(5);
      expect(cards).toHaveLength(5);
      expect(deck.getRemainingCount()).toBe(91);
    });

    it('should not draw more than available', () => {
      const cards = deck.drawMultiple(100);
      expect(cards).toHaveLength(96);
      expect(deck.isEmpty()).toBe(true);
    });
  });

  describe('discard', () => {
    it('should add card to discarded pile', () => {
      const card = deck.draw()!;
      deck.discard(card);
      expect(deck.getDiscardedCards()).toHaveLength(1);
      expect(deck.getLastDiscardedCard()).toBe(card);
    });
  });

  describe('shuffle', () => {
    it('should randomize card order', () => {
      const deck1 = new Deck();
      const deck2 = new Deck();
      
      deck2.shuffle();
      
      const cards1 = deck1.drawMultiple(10);
      const cards2 = deck2.drawMultiple(10);
      
      const sameOrder = cards1.every((c, i) => c.character === cards2[i].character);
      expect(sameOrder).toBe(false);
    });
  });

  describe('reset', () => {
    it('should reset deck to initial state', () => {
      deck.drawMultiple(50);
      deck.reset();
      expect(deck.getRemainingCount()).toBe(96);
      expect(deck.getDiscardedCards()).toHaveLength(0);
    });
  });
});

describe('countCards', () => {
  it('should count cards correctly', () => {
    const shangDef = CARD_DEFINITIONS.find(d => d.character === '上')!;
    const daDef = CARD_DEFINITIONS.find(d => d.character === '大')!;
    const cards = [
      createCard(shangDef),
      createCard(shangDef),
      createCard(daDef)
    ];
    
    const counts = countCards(cards);
    expect(counts['上']).toBe(2);
    expect(counts['大']).toBe(1);
  });
});

describe('createMeld', () => {
  it('should create triplet with correct hu value for special cards', () => {
    const shangDef = CARD_DEFINITIONS.find(d => d.character === '上')!;
    const cards = [
      createCard(shangDef),
      createCard(shangDef),
      createCard(shangDef)
    ];
    
    const meld = createMeld(MeldType.TRIPLET, cards, MeldSource.HAND);
    expect(meld.type).toBe(MeldType.TRIPLET);
    expect(meld.huValue).toBe(12);
  });

  it('should create triplet with correct hu value for normal cards', () => {
    const daDef = CARD_DEFINITIONS.find(d => d.character === '大')!;
    const cards = [
      createCard(daDef),
      createCard(daDef),
      createCard(daDef)
    ];
    
    const meld = createMeld(MeldType.TRIPLET, cards, MeldSource.HAND);
    expect(meld.type).toBe(MeldType.TRIPLET);
    expect(meld.huValue).toBe(3);
  });

  it('should create quartet with correct hu value for special cards', () => {
    const shangDef = CARD_DEFINITIONS.find(d => d.character === '上')!;
    const cards = [
      createCard(shangDef),
      createCard(shangDef),
      createCard(shangDef),
      createCard(shangDef)
    ];
    
    const meld = createMeld(MeldType.QUARTET, cards, MeldSource.HAND);
    expect(meld.type).toBe(MeldType.QUARTET);
    expect(meld.huValue).toBe(16);
  });

  it('should create quartet with correct hu value for normal cards', () => {
    const daDef = CARD_DEFINITIONS.find(d => d.character === '大')!;
    const cards = [
      createCard(daDef),
      createCard(daDef),
      createCard(daDef),
      createCard(daDef)
    ];
    
    const meld = createMeld(MeldType.QUARTET, cards, MeldSource.HAND);
    expect(meld.type).toBe(MeldType.QUARTET);
    expect(meld.huValue).toBe(6);
  });

  it('should create pair with correct hu value for special cards', () => {
    const shangDef = CARD_DEFINITIONS.find(d => d.character === '上')!;
    const cards = [createCard(shangDef), createCard(shangDef)];
    
    const meld = createMeld(MeldType.PAIR, cards, MeldSource.HAND);
    expect(meld.type).toBe(MeldType.PAIR);
    expect(meld.huValue).toBe(8);
  });

  it('should create pair with correct hu value for normal cards', () => {
    const daDef = CARD_DEFINITIONS.find(d => d.character === '大')!;
    const cards = [createCard(daDef), createCard(daDef)];
    
    const meld = createMeld(MeldType.PAIR, cards, MeldSource.HAND);
    expect(meld.type).toBe(MeldType.PAIR);
    expect(meld.huValue).toBe(0);
  });
});
