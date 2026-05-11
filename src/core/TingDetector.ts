import { Card, Meld, TingType, TingStatus, NormalHuType, SpecialHuType, ComboHuType, CARD_DEFINITIONS, createCardByCharacter } from '../types';
import { HuCalculator } from './HuCalculator';
import { HuValidator } from './HuValidator';
import { countCards } from './Deck';
import { createCard } from './Card';

export class TingDetector {
  private calculator: HuCalculator;
  private validator: HuValidator;

  constructor() {
    this.calculator = new HuCalculator();
    this.validator = new HuValidator();
  }

  detectTing(handCards: Card[], melds: Meld[]): TingStatus {
    const tingCards = this.findTingCards(handCards, melds);
    
    if (tingCards.length === 0) {
      return {
        isTing: false,
        tingType: null,
        tingCards: [],
        huCount: 0,
        huType: null
      };
    }

    const tingType = this.determineTingType(handCards, melds);
    const huDetail = this.calculator.calculateTotalHu(handCards, melds);
    const huType = this.determineHuType(handCards, melds, huDetail.totalHu);

    return {
      isTing: true,
      tingType,
      tingCards,
      huCount: huDetail.totalHu,
      huType
    };
  }

  private findTingCards(handCards: Card[], melds: Meld[]): Card[] {
    const tingCards: Card[] = [];
    
    for (const def of CARD_DEFINITIONS) {
      const testCard = createCard(def);
      const testHand = [...handCards, testCard];
      
      const huResult = this.validator.validateHu(testHand, melds, 'zi_mo' as any);
      if (huResult.canHu) {
        tingCards.push(testCard);
      }
    }

    return tingCards;
  }

  private determineTingType(handCards: Card[], melds: Meld[]): TingType {
    if (this.isTenPairsTing(handCards, melds)) {
      return TingType.TEN_PAIRS;
    }

    if (this.isHeiYuanTing(handCards, melds)) {
      return TingType.HEI_YUAN;
    }

    if (this.isHongYuanTing(handCards, melds)) {
      return TingType.HONG_YUAN;
    }

    if (this.isKuHuTing(handCards, melds)) {
      return TingType.KU_HU;
    }

    return TingType.OTHER;
  }

  private isTenPairsTing(handCards: Card[], melds: Meld[]): boolean {
    if (melds.length > 0) return false;

    const counts = countCards(handCards);
    let pairCount = 0;
    let singleCount = 0;

    for (const count of Object.values(counts)) {
      if (count === 2) pairCount++;
      else if (count === 4) pairCount += 2;
      else if (count === 1) singleCount++;
      else if (count === 3) return false;
    }

    return pairCount === 9 && singleCount === 2;
  }

  private isHeiYuanTing(handCards: Card[], melds: Meld[]): boolean {
    const hasPengOrZhao = melds.some(
      m => m.source === 'peng' || m.source === 'zhao'
    );
    if (hasPengOrZhao) return false;

    const allCards = [...handCards, ...melds.flatMap(m => m.cards)];
    const forbiddenChars = ['上', '大', '人', '福', '禄', '寿'];
    const hasForbidden = allCards.some(c => forbiddenChars.includes(c.character));
    if (hasForbidden) return false;

    return this.isSentencePatternTing(handCards, melds);
  }

  private isHongYuanTing(handCards: Card[], melds: Meld[]): boolean {
    const hasPengOrZhao = melds.some(
      m => m.source === 'peng' || m.source === 'zhao'
    );
    if (hasPengOrZhao) return false;

    if (!this.isSentencePatternTing(handCards, melds)) return false;

    const allCards = [...handCards, ...melds.flatMap(m => m.cards)];
    const shangFuCount = allCards.filter(
      c => c.character === '上' || c.character === '福'
    ).length;

    return shangFuCount >= 2 && shangFuCount <= 6;
  }

  private isKuHuTing(handCards: Card[], melds: Meld[]): boolean {
    const hasChiSequence = melds.some(
      m => m.type === 'sequence' && m.source === 'chi'
    );
    if (hasChiSequence) return false;

    const counts = countCards(handCards);
    const countValues = Object.values(counts);

    let tripletCount = 0;
    let pairCount = 0;
    let singleCount = 0;

    for (const count of countValues) {
      if (count === 3) tripletCount++;
      else if (count === 2) pairCount++;
      else if (count === 1) singleCount++;
      else if (count === 4) return false;
    }

    return tripletCount >= 1 && pairCount === 0 && singleCount === 2;
  }

  private isSentencePatternTing(handCards: Card[], melds: Meld[]): boolean {
    let halfPairCount = 0;
    let singleCount = 0;

    for (let sentence = 1; sentence <= 8; sentence++) {
      const sentenceCards = handCards.filter(c => c.sentence === sentence);
      if (sentenceCards.length === 2) {
        if (sentenceCards[0].character !== sentenceCards[1].character) {
          halfPairCount++;
        }
      } else if (sentenceCards.length === 1) {
        singleCount++;
      } else if (sentenceCards.length !== 0 && sentenceCards.length !== 3) {
        return false;
      }
    }

    return halfPairCount === 0 && singleCount === 1;
  }

  private determineHuType(
    handCards: Card[], 
    melds: Meld[], 
    huCount: number
  ): NormalHuType | SpecialHuType | ComboHuType | null {
    if (this.validator.validateTenPairs(handCards, melds)) {
      return SpecialHuType.TEN_PAIRS;
    }

    const hongYuanType = this.validator.validateHongYuan(handCards, melds);
    if (hongYuanType) return hongYuanType;

    if (this.validator.validateHeiYuan(handCards, melds)) {
      return SpecialHuType.HEI_YUAN;
    }

    if (this.validator.validateQingKaHu(handCards, melds, huCount)) {
      return ComboHuType.QING_KA_HU;
    }

    if (this.validator.validateQingHu(handCards, melds, huCount)) {
      return ComboHuType.QING_HU;
    }

    if (this.validator.validateKuHu(handCards, melds)) {
      return SpecialHuType.KU_HU;
    }

    return this.calculator.determineNormalHuType(huCount);
  }

  getTingCardsDisplay(tingCards: Card[]): string[] {
    return [...new Set(tingCards.map(c => c.character))];
  }

  getTingTypeDisplayName(tingType: TingType): string {
    const displayNames: Record<TingType, string> = {
      [TingType.TEN_PAIRS]: '十对听牌',
      [TingType.HEI_YUAN]: '黑元听牌',
      [TingType.HONG_YUAN]: '红元听牌',
      [TingType.KU_HU]: '枯胡听牌',
      [TingType.OTHER]: '普通听牌'
    };
    return displayNames[tingType];
  }
}
