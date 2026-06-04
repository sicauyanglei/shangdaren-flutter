import { HuMethod } from '../types/player';

// ============================================================
// 胡牌类型结果（匹配Flame的HuTypeResult）
// ============================================================

export interface HuTypeResult {
  type: string;     // 胡牌类型标识
  name: string;     // 胡牌类型中文名
  dianpao: number;  // 点炮倍数
  zimo: number;     // 自摸倍数
}

// ============================================================
// 分数计算（匹配Flame的ScoreCalculator）
// ============================================================

// 点炮输家: 底分 + B × 倍数基数 + 飘分(己+赢家)
// 点炮赢家: 底分 + B × 倍数基数 + 飘分(己+点炮者)
// 自摸赢家: 2 × (底分 + (B+1) × 倍数基数) + 飘分(己×2 + 他家)
// 自摸输家: 底分 + (B+1) × 倍数基数 + 飘分(己+赢家)

/**
 * 计算分数变化（匹配Flame的ScoreCalculator.calculateScores）
 * @param method 胡牌方式
 * @param baseScore 底分
 * @param multiplierBase 倍数基数
 * @param huTypeResult 胡牌类型结果（包含dianpao/zimo倍数）
 * @param piaoValues 3个玩家的飘分值
 * @param winnerIndex 赢家索引
 * @param dianpaoIndex 点炮者索引（点炮时必填）
 */
export function calculateScoreChanges(
  method: HuMethod,
  baseScore: number,
  multiplierBase: number,
  huTypeResult: HuTypeResult,
  piaoValues: number[],
  winnerIndex: number,
  dianpaoIndex?: number,
): number[] {
  const changes = [0, 0, 0];
  const isZimo = method === 'zimo';
  const baseMultiplier = isZimo ? huTypeResult.zimo : huTypeResult.dianpao;

  if (isZimo) {
    // 自摸
    const winnerPiao = piaoValues[winnerIndex];

    let loserSum = 0;
    for (let i = 0; i < 3; i++) {
      if (i === winnerIndex) continue;
      const loserPiao = piaoValues[i];
      // 输家: 底分 + (B+1) × 倍数基数 + 飘分(己+赢家)
      const loserScore = baseScore + baseMultiplier * multiplierBase + loserPiao + winnerPiao;
      changes[i] = -loserScore;
      loserSum += loserScore;
    }
    changes[winnerIndex] = winnerPiao * 2 + loserSum;
  } else {
    // 点炮
    if (dianpaoIndex === undefined) return changes;
    const dianpaoPiao = piaoValues[dianpaoIndex];
    const winnerPiao = piaoValues[winnerIndex];

    // 点炮输家: 底分 + B × 倍数基数 + 飘分(己+赢家)
    const loserScore = baseScore + baseMultiplier * multiplierBase + dianpaoPiao + winnerPiao;
    // 点炮赢家: 底分 + B × 倍数基数 + 飘分(己+点炮者)
    const winnerScore = baseScore + baseMultiplier * multiplierBase + winnerPiao + dianpaoPiao;

    changes[dianpaoIndex] = -loserScore;
    changes[winnerIndex] = winnerScore;
  }

  return changes;
}

// ============================================================
// 胡牌类型颜色（匹配Flame的_getHuTypeColor）
// ============================================================

/**
 * 获取胡牌类型对应的颜色
 * @param huTypeName 胡牌类型中文名
 */
export function getHuTypeColor(huTypeName: string): string {
  switch (huTypeName) {
    case '清枯重台卡':
    case '清枯重台胡':
      return '#ff2d2d';
    case '枯重台卡':
    case '枯重台胡':
    case '清枯台胡':
    case '清枯台卡':
      return '#e040fb';
    case '十对':
      return '#ff9800';
    case '枯台胡':
    case '清枯胡':
    case '枯胡':
    case '重台卡':
    case '重台胡':
      return '#ff6b6b';
    case '红元精':
    case '红元2精':
    case '红元3精':
    case '红元4精':
    case '黑元':
      return '#ab47bc';
    case '清卡胡':
    case '清胡':
    case '卡胡':
      return '#4ecdc4';
    case '台卡':
    case '台胡':
      return '#42a5f5';
    default:
      return '#4ecdc4';
  }
}
