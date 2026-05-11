import { 
  HuResult, 
  HuMethod, 
  NormalHuType, 
  SpecialHuType, 
  ComboHuType,
  PiaoScore,
  BaseScore,
  MultiplierBase,
  RoundSettlement,
  MULTIPLIER_TABLE
} from '../types';

export interface ScoreResult {
  baseScore: number;
  multiplier: number;
  piaoScore: number;
  totalScore: number;
  winnerPayment: number;
  loserPayments: number[];
}

export class ScoringSystem {
  private baseScore: BaseScore;
  private multiplierBase: MultiplierBase;

  constructor(baseScore: BaseScore = BaseScore.TEN, multiplierBase: MultiplierBase = MultiplierBase.TEN) {
    this.baseScore = baseScore;
    this.multiplierBase = multiplierBase;
  }

  calculateMultiplier(huResult: HuResult): number {
    if (!huResult.canHu) return 0;

    const huType = huResult.normalType || huResult.specialType || huResult.comboType;
    if (!huType) return 0;

    const multipliers = MULTIPLIER_TABLE[huType];
    if (!multipliers) return 0;

    return huResult.method === HuMethod.ZI_MO 
      ? multipliers.ziMo 
      : multipliers.dianPao;
  }

  calculateScore(
    huResult: HuResult,
    piaoScore: PiaoScore = PiaoScore.NONE
  ): ScoreResult {
    if (!huResult.canHu) {
      return {
        baseScore: 0,
        multiplier: 0,
        piaoScore: 0,
        totalScore: 0,
        winnerPayment: 0,
        loserPayments: [0, 0]
      };
    }

    const multiplier = this.calculateMultiplier(huResult);
    const baseScoreValue = this.baseScore;
    const multiplierValue = multiplier * this.multiplierBase;
    
    let totalScore = baseScoreValue + multiplierValue + piaoScore;
    
    if (huResult.method === HuMethod.ZI_MO) {
      totalScore *= 2;
    }

    return {
      baseScore: baseScoreValue,
      multiplier,
      piaoScore,
      totalScore,
      winnerPayment: totalScore,
      loserPayments: huResult.method === HuMethod.ZI_MO 
        ? [totalScore, totalScore] 
        : [totalScore, 0]
    };
  }

  calculateRoundSettlement(
    winnerId: string,
    loserIds: string[],
    huResult: HuResult,
    piaoScore: PiaoScore = PiaoScore.NONE
  ): RoundSettlement {
    const scoreResult = this.calculateScore(huResult, piaoScore);
    
    const payments = loserIds.map(loserId => ({
      playerId: loserId,
      payment: huResult.method === HuMethod.ZI_MO 
        ? scoreResult.totalScore 
        : (loserId === loserIds[0] ? scoreResult.totalScore : 0)
    }));

    return {
      winnerId,
      huType: this.getHuTypeName(huResult),
      huMethod: huResult.method,
      huCount: huResult.huCount,
      multiplier: scoreResult.multiplier,
      payments,
      winnerScore: scoreResult.totalScore * (huResult.method === HuMethod.ZI_MO ? 2 : 1)
    };
  }

  private getHuTypeName(huResult: HuResult): string {
    if (huResult.specialType) return huResult.specialType;
    if (huResult.comboType) return huResult.comboType;
    if (huResult.normalType) return huResult.normalType;
    return 'unknown';
  }

  getHuTypeDisplayName(huResult: HuResult): string {
    const displayNames: Record<string, string> = {
      [NormalHuType.NORMAL_HU]: '普通胡',
      [NormalHuType.KA_HU]: '卡胡',
      [NormalHuType.TAI_KA]: '台卡',
      [NormalHuType.TAI_HU]: '台胡',
      [NormalHuType.ZHONG_TAI_KA]: '重台卡',
      [NormalHuType.ZHONG_TAI_HU]: '重台胡',
      [SpecialHuType.KU_HU]: '枯胡',
      [SpecialHuType.QING_KU_HU]: '清枯',
      [SpecialHuType.QING_KU_TAI_KA]: '清枯台卡',
      [SpecialHuType.HEI_YUAN]: '黑元',
      [SpecialHuType.HONG_YUAN_3]: '红元3精',
      [SpecialHuType.HONG_YUAN_4]: '红元4精',
      [SpecialHuType.HONG_YUAN_5]: '红元5精',
      [SpecialHuType.HONG_YUAN_6]: '红元6精',
      [SpecialHuType.HONG_YUAN_7]: '红元7精',
      [SpecialHuType.TEN_PAIRS]: '十对',
      [ComboHuType.QING_HU]: '清胡',
      [ComboHuType.QING_KA_HU]: '清卡胡',
      [ComboHuType.KU_ZHONG_TAI_KA]: '枯重台卡'
    };

    const huType = huResult.normalType || huResult.specialType || huResult.comboType;
    return huType ? displayNames[huType] || huType : '未知';
  }

  getMethodDisplayName(method: HuMethod): string {
    return method === HuMethod.ZI_MO ? '自摸' : '点炮';
  }
}
