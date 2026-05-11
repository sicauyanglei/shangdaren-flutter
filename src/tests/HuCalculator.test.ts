import { HuCalculator } from '../core/HuCalculator';
import { createCard } from '../core/Card';
import { CARD_DEFINITIONS, CardColor } from '../types';

describe('HuCalculator', () => {
  let calculator: HuCalculator;

  beforeEach(() => {
    calculator = new HuCalculator();
  });

  describe('calculateBaseHu', () => {
    it('should return 4 for cards containing 上', () => {
      const shangDef = CARD_DEFINITIONS.find(d => d.character === '上')!;
      const daDef = CARD_DEFINITIONS.find(d => d.character === '大')!;
      const cards = [createCard(shangDef), createCard(daDef)];
      expect(calculator.calculateBaseHu(cards)).toBe(4);
    });

    it('should return 4 for cards containing 福', () => {
      const fuDef = CARD_DEFINITIONS.find(d => d.character === '福')!;
      const luDef = CARD_DEFINITIONS.find(d => d.character === '禄')!;
      const cards = [createCard(fuDef), createCard(luDef)];
      expect(calculator.calculateBaseHu(cards)).toBe(4);
    });

    it('should return 8 for cards containing both 上 and 福', () => {
      const shangDef = CARD_DEFINITIONS.find(d => d.character === '上')!;
      const fuDef = CARD_DEFINITIONS.find(d => d.character === '福')!;
      const cards = [createCard(shangDef), createCard(fuDef)];
      expect(calculator.calculateBaseHu(cards)).toBe(8);
    });

    it('should return 0 for cards without 上 or 福', () => {
      const daDef = CARD_DEFINITIONS.find(d => d.character === '大')!;
      const renDef = CARD_DEFINITIONS.find(d => d.character === '人')!;
      const cards = [createCard(daDef), createCard(renDef)];
      expect(calculator.calculateBaseHu(cards)).toBe(0);
    });
  });

  describe('calculatePairHu', () => {
    it('should return 8 for 上上 pair', () => {
      const shangDef = CARD_DEFINITIONS.find(d => d.character === '上')!;
      const cards = [createCard(shangDef), createCard(shangDef)];
      expect(calculator.calculatePairHu(cards)).toBe(8);
    });

    it('should return 8 for 福福 pair', () => {
      const fuDef = CARD_DEFINITIONS.find(d => d.character === '福')!;
      const cards = [createCard(fuDef), createCard(fuDef)];
      expect(calculator.calculatePairHu(cards)).toBe(8);
    });

    it('should return 0 for normal pair', () => {
      const daDef = CARD_DEFINITIONS.find(d => d.character === '大')!;
      const cards = [createCard(daDef), createCard(daDef)];
      expect(calculator.calculatePairHu(cards)).toBe(0);
    });
  });

  describe('calculateHalfPairHu', () => {
    it('should return 4 for half pair containing 上', () => {
      const shangDef = CARD_DEFINITIONS.find(d => d.character === '上')!;
      const daDef = CARD_DEFINITIONS.find(d => d.character === '大')!;
      const cards = [createCard(shangDef), createCard(daDef)];
      expect(calculator.calculateHalfPairHu(cards)).toBe(4);
    });

    it('should return 4 for half pair containing 福', () => {
      const fuDef = CARD_DEFINITIONS.find(d => d.character === '福')!;
      const luDef = CARD_DEFINITIONS.find(d => d.character === '禄')!;
      const cards = [createCard(fuDef), createCard(luDef)];
      expect(calculator.calculateHalfPairHu(cards)).toBe(4);
    });

    it('should return 0 for normal half pair', () => {
      const daDef = CARD_DEFINITIONS.find(d => d.character === '大')!;
      const renDef = CARD_DEFINITIONS.find(d => d.character === '人')!;
      const cards = [createCard(daDef), createCard(renDef)];
      expect(calculator.calculateHalfPairHu(cards)).toBe(0);
    });
  });

  describe('determineNormalHuType', () => {
    it('should return null for hu count less than 11', () => {
      expect(calculator.determineNormalHuType(10)).toBeNull();
    });

    it('should return KA_HU for 11 hu', () => {
      expect(calculator.determineNormalHuType(11)).toBe('ka_hu');
    });

    it('should return NORMAL_HU for 12-21 hu', () => {
      expect(calculator.determineNormalHuType(15)).toBe('normal_hu');
      expect(calculator.determineNormalHuType(21)).toBe('normal_hu');
    });

    it('should return TAI_KA for 22 hu', () => {
      expect(calculator.determineNormalHuType(22)).toBe('tai_ka');
    });

    it('should return TAI_HU for 23-32 hu', () => {
      expect(calculator.determineNormalHuType(25)).toBe('tai_hu');
      expect(calculator.determineNormalHuType(32)).toBe('tai_hu');
    });

    it('should return ZHONG_TAI_KA for 33 hu', () => {
      expect(calculator.determineNormalHuType(33)).toBe('zhong_tai_ka');
    });

    it('should return ZHONG_TAI_HU for 34+ hu', () => {
      expect(calculator.determineNormalHuType(34)).toBe('zhong_tai_hu');
      expect(calculator.determineNormalHuType(50)).toBe('zhong_tai_hu');
    });
  });
});
