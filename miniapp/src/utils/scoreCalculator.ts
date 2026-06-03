import { HuMethod } from '../types/player';

// 分数计算
// 点炮公式：底分 + B × 倍数基数 + 飘分(己+赢家)
// 自摸公式(赢家)：2 × (底分 + (B+1) × 倍数基数) + 飘分(己×2 + 他家)
// 自摸公式(输家)：底分 + (B+1) × 倍数基数 + 飘分(己+赢家)

export function calculateScoreChanges(
  method: HuMethod,
  baseScore: number,
  multiplierBase: number,
  multiplier: number, // B值
  piaoValues: number[], // 3个玩家的飘分值
  winnerIndex: number,
  dianpaoIndex?: number
): number[] {
  const changes = [0, 0, 0];

  if (method === 'dianpao' && dianpaoIndex !== undefined) {
    // 点炮
    const loserPiao = piaoValues[dianpaoIndex];
    const winnerPiao = piaoValues[winnerIndex];
    const loserScore = baseScore + multiplier * multiplierBase + loserPiao + winnerPiao;
    const winnerScore = baseScore + multiplier * multiplierBase + winnerPiao + loserPiao;

    changes[dianpaoIndex] = -loserScore;
    changes[winnerIndex] = winnerScore;
  } else {
    // 自摸
    const winnerPiao = piaoValues[winnerIndex];
    const winnerTotal = 2 * (baseScore + (multiplier + 1) * multiplierBase) + winnerPiao * 2;

    let loserSum = 0;
    for (let i = 0; i < 3; i++) {
      if (i === winnerIndex) continue;
      const loserPiao = piaoValues[i];
      const loserScore = baseScore + (multiplier + 1) * multiplierBase + loserPiao + winnerPiao;
      changes[i] = -loserScore;
      loserSum += loserScore;
    }
    changes[winnerIndex] = winnerPiao * 2 + loserSum;
  }

  return changes;
}

// 获取胡牌类型倍数
export function getHuMultiplier(huType: string): number {
  const multipliers: Record<string, number> = {
    '普通胡': 1,
    '十对': 2,
    '黑元': 3,
    '红元': 4,
    '枯胡': 2,
    '清枯胡': 3,
    '清枯重台': 4,
  };
  return multipliers[huType] || 1;
}
