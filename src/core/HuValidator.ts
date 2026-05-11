import { Card, Meld, MeldType, MeldSource, NormalHuType, SpecialHuType, ComboHuType, HuResult, HuMethod, MULTIPLIER_TABLE } from '../types';
import { HuCalculator } from './HuCalculator';
import { countCards } from './Deck';

export class HuValidator {
  private calculator: HuCalculator;

  constructor() {
    this.calculator = new HuCalculator();
  }

  validateNormalHu(totalHu: number): NormalHuType | null {
    return this.calculator.determineNormalHuType(totalHu);
  }

  validateKuHu(handCards: Card[], melds: Meld[]): boolean {
    const hasChiSequence = melds.some(
      m => m.type === MeldType.SEQUENCE && m.source === MeldSource.CHI
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
    
    return tripletCount >= 1 && pairCount === 1 && singleCount === 0;
  }

  validateQingKuHu(handCards: Card[], melds: Meld[]): boolean {
    if (!this.validateKuHu(handCards, melds)) return false;
    
    const allCards = [...handCards, ...melds.flatMap(m => m.cards)];
    const colors = new Set(allCards.map(c => c.color));
    
    return colors.size === 1;
  }

  validateHeiYuan(handCards: Card[], melds: Meld[]): boolean {
    const hasPengOrZhao = melds.some(
      m => m.source === MeldSource.PENG || m.source === MeldSource.ZHAO
    );
    if (hasPengOrZhao) return false;

    const allCards = [...handCards, ...melds.flatMap(m => m.cards)];
    const forbiddenChars = ['上', '大', '人', '福', '禄', '寿'];
    const hasForbidden = allCards.some(c => forbiddenChars.includes(c.character));
    if (hasForbidden) return false;

    return this.checkSentencePattern(handCards, melds);
  }

  validateHongYuan(handCards: Card[], melds: Meld[]): SpecialHuType | null {
    const hasPengOrZhao = melds.some(
      m => m.source === MeldSource.PENG || m.source === MeldSource.ZHAO
    );
    if (hasPengOrZhao) return null;

    if (!this.checkSentencePattern(handCards, melds)) return null;

    const allCards = [...handCards, ...melds.flatMap(m => m.cards)];
    const shangFuCount = allCards.filter(
      c => c.character === '上' || c.character === '福'
    ).length;

    if (shangFuCount === 3) return SpecialHuType.HONG_YUAN_3;
    if (shangFuCount === 4) return SpecialHuType.HONG_YUAN_4;
    if (shangFuCount === 5) return SpecialHuType.HONG_YUAN_5;
    if (shangFuCount === 6) return SpecialHuType.HONG_YUAN_6;
    if (shangFuCount >= 7) return SpecialHuType.HONG_YUAN_7;

    return null;
  }

  validateTenPairs(handCards: Card[], melds: Meld[]): boolean {
    if (melds.length > 0) return false;

    const counts = countCards(handCards);
    let pairCount = 0;
    
    for (const count of Object.values(counts)) {
      if (count === 2) pairCount++;
      else if (count === 4) pairCount += 2;
      else if (count === 1 || count === 3) return false;
    }
    
    return pairCount === 10;
  }

  validateQingHu(handCards: Card[], melds: Meld[], huCount: number): boolean {
    if (huCount < 12 || huCount > 21) return false;

    const allCards = [...handCards, ...melds.flatMap(m => m.cards)];
    if (this.calculator.hasShangOrFu(allCards)) return false;

    if (this.calculator.hasShangDaRenHalfPair(allCards)) return false;
    if (this.calculator.hasFuLuShouHalfPair(allCards)) return false;

    return true;
  }

  validateQingKaHu(handCards: Card[], melds: Meld[], huCount: number): boolean {
    if (huCount !== 11) return false;

    const allCards = [...handCards, ...melds.flatMap(m => m.cards)];
    if (this.calculator.hasShangOrFu(allCards)) return false;

    if (this.calculator.hasShangDaRenHalfPair(allCards)) return false;
    if (this.calculator.hasFuLuShouHalfPair(allCards)) return false;

    return true;
  }

  private checkSentencePattern(handCards: Card[], melds: Meld[]): boolean {
    const chiMelds = melds.filter(m => m.source === MeldSource.CHI);
    const handCardCounts = countCards(handCards);
    
    let halfPairCount = 0;
    for (let sentence = 1; sentence <= 8; sentence++) {
      const sentenceCards = handCards.filter(c => c.sentence === sentence);
      if (sentenceCards.length === 2) {
        if (sentenceCards[0].character !== sentenceCards[1].character) {
          halfPairCount++;
        }
      } else if (sentenceCards.length !== 0 && sentenceCards.length !== 3) {
        return false;
      }
    }
    
    return halfPairCount === 1;
  }

  validateHu(handCards: Card[], melds: Meld[], method: HuMethod, discardedCard?: Card): HuResult {
    const huDetail = this.calculator.calculateTotalHu(handCards, melds);
    const result: HuResult = {
      canHu: false,
      method,
      dianPaoMultiplier: 0,
      ziMoMultiplier: 0,
      huCount: huDetail.totalHu
    };

    if (huDetail.totalHu < 11) {
      return result;
    }

    if (this.validateTenPairs(handCards, melds)) {
      result.canHu = true;
      result.specialType = SpecialHuType.TEN_PAIRS;
      const multipliers = MULTIPLIER_TABLE[SpecialHuType.TEN_PAIRS];
      result.dianPaoMultiplier = multipliers.dianPao;
      result.ziMoMultiplier = multipliers.ziMo;
      return result;
    }

    const hongYuanType = this.validateHongYuan(handCards, melds);
    if (hongYuanType) {
      result.canHu = true;
      result.specialType = hongYuanType;
      const multipliers = MULTIPLIER_TABLE[hongYuanType];
      result.dianPaoMultiplier = multipliers.dianPao;
      result.ziMoMultiplier = multipliers.ziMo;
      return result;
    }

    if (this.validateHeiYuan(handCards, melds)) {
      result.canHu = true;
      result.specialType = SpecialHuType.HEI_YUAN;
      const multipliers = MULTIPLIER_TABLE[SpecialHuType.HEI_YUAN];
      result.dianPaoMultiplier = multipliers.dianPao;
      result.ziMoMultiplier = multipliers.ziMo;
      return result;
    }

    if (this.validateQingKaHu(handCards, melds, huDetail.totalHu)) {
      result.canHu = true;
      result.comboType = ComboHuType.QING_KA_HU;
      const multipliers = MULTIPLIER_TABLE[ComboHuType.QING_KA_HU];
      result.dianPaoMultiplier = multipliers.dianPao;
      result.ziMoMultiplier = multipliers.ziMo;
      return result;
    }

    if (this.validateQingHu(handCards, melds, huDetail.totalHu)) {
      result.canHu = true;
      result.comboType = ComboHuType.QING_HU;
      const multipliers = MULTIPLIER_TABLE[ComboHuType.QING_HU];
      result.dianPaoMultiplier = multipliers.dianPao;
      result.ziMoMultiplier = multipliers.ziMo;
      return result;
    }

    if (this.validateKuHu(handCards, melds)) {
      result.canHu = true;
      result.specialType = SpecialHuType.KU_HU;
      const multipliers = MULTIPLIER_TABLE[SpecialHuType.KU_HU];
      result.dianPaoMultiplier = multipliers.dianPao;
      result.ziMoMultiplier = multipliers.ziMo;
      return result;
    }

    const normalType = this.validateNormalHu(huDetail.totalHu);
    if (normalType) {
      result.canHu = true;
      result.normalType = normalType;
      const multipliers = MULTIPLIER_TABLE[normalType];
      result.dianPaoMultiplier = multipliers.dianPao;
      result.ziMoMultiplier = multipliers.ziMo;
    }

    return result;
  }
}
