import { Card, Meld, MeldType, MeldSource, NormalHuType, SpecialHuType, ComboHuType, HuResult, HuMethod } from '../types';
import { countCards } from '../core/Deck';

export interface HuDetail {
  baseHu: number;
  pairHu: number;
  halfPairHu: number;
  tripletHu: number;
  quartetHu: number;
  totalHu: number;
}

export class HuCalculator {
  calculateBaseHu(cards: Card[]): number {
    const hasShang = cards.some(c => c.character === '上');
    const hasFu = cards.some(c => c.character === '福');
    let hu = 0;
    if (hasShang) hu += 4;
    if (hasFu) hu += 4;
    return hu;
  }

  calculatePairHu(cards: Card[]): number {
    const counts = countCards(cards);
    let hu = 0;
    
    for (const [char, count] of Object.entries(counts)) {
      if (count === 2) {
        if (char === '上' || char === '福') {
          hu += 8;
        }
      }
    }
    
    return hu;
  }

  calculateHalfPairHu(cards: Card[]): number {
    let hu = 0;
    
    for (let sentence = 1; sentence <= 8; sentence++) {
      const sentenceCards = cards.filter(c => c.sentence === sentence);
      if (sentenceCards.length === 2) {
        if (sentenceCards[0].character !== sentenceCards[1].character) {
          const hasShangOrFu = sentenceCards.some(c => 
            c.character === '上' || c.character === '福'
          );
          if (hasShangOrFu) {
            hu += 4;
          }
        }
      }
    }
    
    return hu;
  }

  calculateTripletHu(melds: Meld[]): number {
    return melds
      .filter(m => m.type === MeldType.TRIPLET)
      .reduce((sum, m) => sum + m.huValue, 0);
  }

  calculateQuartetHu(melds: Meld[]): number {
    return melds
      .filter(m => m.type === MeldType.QUARTET)
      .reduce((sum, m) => sum + m.huValue, 0);
  }

  calculateTotalHu(handCards: Card[], melds: Meld[]): HuDetail {
    const baseHu = this.calculateBaseHu(handCards);
    const pairHu = this.calculatePairHu(handCards);
    const halfPairHu = this.calculateHalfPairHu(handCards);
    const tripletHu = this.calculateTripletHu(melds);
    const quartetHu = this.calculateQuartetHu(melds);
    
    const totalHu = baseHu + pairHu + halfPairHu + tripletHu + quartetHu;
    
    return {
      baseHu,
      pairHu,
      halfPairHu,
      tripletHu,
      quartetHu,
      totalHu
    };
  }

  determineNormalHuType(huCount: number): NormalHuType | null {
    if (huCount < 11) return null;
    if (huCount === 11) return NormalHuType.KA_HU;
    if (huCount >= 12 && huCount <= 21) return NormalHuType.NORMAL_HU;
    if (huCount === 22) return NormalHuType.TAI_KA;
    if (huCount >= 23 && huCount <= 32) return NormalHuType.TAI_HU;
    if (huCount === 33) return NormalHuType.ZHONG_TAI_KA;
    return NormalHuType.ZHONG_TAI_HU;
  }

  hasShangOrFu(cards: Card[]): boolean {
    return cards.some(c => c.character === '上' || c.character === '福');
  }

  hasShangDaRenHalfPair(cards: Card[]): boolean {
    const sentenceCards = cards.filter(c => c.sentence === 1);
    return sentenceCards.length === 2 && 
           sentenceCards[0].character !== sentenceCards[1].character;
  }

  hasFuLuShouHalfPair(cards: Card[]): boolean {
    const sentenceCards = cards.filter(c => c.sentence === 8);
    return sentenceCards.length === 2 && 
           sentenceCards[0].character !== sentenceCards[1].character;
  }
}
