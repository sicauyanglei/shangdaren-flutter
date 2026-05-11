import { ScoringSystem } from '../core/ScoringSystem';
import { HuResult, HuMethod, NormalHuType, SpecialHuType, ComboHuType, BaseScore, MultiplierBase, PiaoScore } from '../types';

describe('ScoringSystem', () => {
  let scoringSystem: ScoringSystem;

  beforeEach(() => {
    scoringSystem = new ScoringSystem(BaseScore.TEN, MultiplierBase.TEN);
  });

  describe('calculateMultiplier', () => {
    it('should return 0 for non-hu result', () => {
      const huResult: HuResult = {
        canHu: false,
        method: HuMethod.ZI_MO,
        dianPaoMultiplier: 0,
        ziMoMultiplier: 0,
        huCount: 10
      };
      expect(scoringSystem.calculateMultiplier(huResult)).toBe(0);
    });

    it('should return correct multiplier for KA_HU (dian pao)', () => {
      const huResult: HuResult = {
        canHu: true,
        method: HuMethod.DIAN_PAO,
        normalType: NormalHuType.KA_HU,
        dianPaoMultiplier: 1,
        ziMoMultiplier: 2,
        huCount: 11
      };
      expect(scoringSystem.calculateMultiplier(huResult)).toBe(1);
    });

    it('should return correct multiplier for KA_HU (zi mo)', () => {
      const huResult: HuResult = {
        canHu: true,
        method: HuMethod.ZI_MO,
        normalType: NormalHuType.KA_HU,
        dianPaoMultiplier: 1,
        ziMoMultiplier: 2,
        huCount: 11
      };
      expect(scoringSystem.calculateMultiplier(huResult)).toBe(2);
    });

    it('should return correct multiplier for TEN_PAIRS', () => {
      const huResult: HuResult = {
        canHu: true,
        method: HuMethod.DIAN_PAO,
        specialType: SpecialHuType.TEN_PAIRS,
        dianPaoMultiplier: 10,
        ziMoMultiplier: 11,
        huCount: 20
      };
      expect(scoringSystem.calculateMultiplier(huResult)).toBe(10);
    });
  });

  describe('calculateScore', () => {
    it('should return zero score for non-hu result', () => {
      const huResult: HuResult = {
        canHu: false,
        method: HuMethod.ZI_MO,
        dianPaoMultiplier: 0,
        ziMoMultiplier: 0,
        huCount: 10
      };
      const result = scoringSystem.calculateScore(huResult);
      expect(result.totalScore).toBe(0);
    });

    it('should calculate score for KA_HU (dian pao)', () => {
      const huResult: HuResult = {
        canHu: true,
        method: HuMethod.DIAN_PAO,
        normalType: NormalHuType.KA_HU,
        dianPaoMultiplier: 1,
        ziMoMultiplier: 2,
        huCount: 11
      };
      const result = scoringSystem.calculateScore(huResult);
      expect(result.baseScore).toBe(10);
      expect(result.multiplier).toBe(1);
      expect(result.totalScore).toBe(10 + 10);
    });

    it('should calculate score for KA_HU (zi mo)', () => {
      const huResult: HuResult = {
        canHu: true,
        method: HuMethod.ZI_MO,
        normalType: NormalHuType.KA_HU,
        dianPaoMultiplier: 1,
        ziMoMultiplier: 2,
        huCount: 11
      };
      const result = scoringSystem.calculateScore(huResult);
      expect(result.baseScore).toBe(10);
      expect(result.multiplier).toBe(2);
      expect(result.totalScore).toBe((10 + 20) * 2);
    });

    it('should include piao score', () => {
      const huResult: HuResult = {
        canHu: true,
        method: HuMethod.DIAN_PAO,
        normalType: NormalHuType.KA_HU,
        dianPaoMultiplier: 1,
        ziMoMultiplier: 2,
        huCount: 11
      };
      const result = scoringSystem.calculateScore(huResult, PiaoScore.TEN);
      expect(result.piaoScore).toBe(10);
      expect(result.totalScore).toBe(10 + 10 + 10);
    });
  });

  describe('getHuTypeDisplayName', () => {
    it('should return correct display name for KA_HU', () => {
      const huResult: HuResult = {
        canHu: true,
        method: HuMethod.DIAN_PAO,
        normalType: NormalHuType.KA_HU,
        dianPaoMultiplier: 1,
        ziMoMultiplier: 2,
        huCount: 11
      };
      expect(scoringSystem.getHuTypeDisplayName(huResult)).toBe('卡胡');
    });

    it('should return correct display name for TEN_PAIRS', () => {
      const huResult: HuResult = {
        canHu: true,
        method: HuMethod.DIAN_PAO,
        specialType: SpecialHuType.TEN_PAIRS,
        dianPaoMultiplier: 10,
        ziMoMultiplier: 11,
        huCount: 20
      };
      expect(scoringSystem.getHuTypeDisplayName(huResult)).toBe('十对');
    });

    it('should return correct display name for QING_HU', () => {
      const huResult: HuResult = {
        canHu: true,
        method: HuMethod.DIAN_PAO,
        comboType: ComboHuType.QING_HU,
        dianPaoMultiplier: 1,
        ziMoMultiplier: 2,
        huCount: 15
      };
      expect(scoringSystem.getHuTypeDisplayName(huResult)).toBe('清胡');
    });
  });

  describe('getMethodDisplayName', () => {
    it('should return 自摸 for ZI_MO', () => {
      expect(scoringSystem.getMethodDisplayName(HuMethod.ZI_MO)).toBe('自摸');
    });

    it('should return 点炮 for DIAN_PAO', () => {
      expect(scoringSystem.getMethodDisplayName(HuMethod.DIAN_PAO)).toBe('点炮');
    });
  });
});
