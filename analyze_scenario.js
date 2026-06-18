// 场景分析：为什么AI出特定的牌
// 分析两个场景的AI出牌决策

// 牌组定义
const groups = {
  1: ['上', '大', '人'],
  2: ['丘', '乙', '己'],
  3: ['化', '三', '千'],
  4: ['七', '十', '土'],
  5: ['尔', '小', '生'],
  6: ['八', '九', '子'],
  7: ['佳', '作', '亡'],
  8: ['福', '禄', '寿'],
};

// 获取字的组号和position
function getCharInfo(ch) {
  for (const [g, chars] of Object.entries(groups)) {
    const idx = chars.indexOf(ch);
    if (idx >= 0) return { sentence: parseInt(g), position: idx + 1 };
  }
  return null;
}

// 精牌判断（上、福）
function isJing(ch) { return ch === '上' || ch === '福'; }
// 银牌判断（大、人、禄、寿）
function isYin(ch) { return ['大', '人', '禄', '寿'].includes(ch); }

// 提取句（同组不同3张）
function extractJu(remaining) {
  const bySentence = {};
  for (const ch of remaining) {
    const info = getCharInfo(ch);
    if (!info) continue;
    if (!bySentence[info.sentence]) bySentence[info.sentence] = {};
    if (!bySentence[info.sentence][info.position]) bySentence[info.sentence][info.position] = 0;
    bySentence[info.sentence][info.position]++;
  }
  const aSet = [];
  for (const [s, positions] of Object.entries(bySentence)) {
    const posKeys = Object.keys(positions).map(Number).sort();
    if (posKeys.length >= 3) {
      const juChars = posKeys.slice(0, 3).map(p => {
        const ch = groups[s][p - 1];
        return ch;
      });
      aSet.push({ chars: juChars, sentence: parseInt(s), isJing: juChars.some(c => isJing(c)) });
      // 从remaining移除
      for (const ch of juChars) {
        const idx = remaining.indexOf(ch);
        if (idx >= 0) remaining.splice(idx, 1);
      }
    }
  }
  return aSet;
}

// 提取坎（同字3张）
function extractKan(remaining) {
  const byChar = {};
  for (const ch of remaining) {
    byChar[ch] = (byChar[ch] || 0) + 1;
  }
  const cSet = [];
  for (const [ch, count] of Object.entries(byChar)) {
    if (count >= 3) {
      cSet.push({ char: ch, isJing: isJing(ch) });
      // 移除3张
      for (let i = 0; i < 3; i++) {
        const idx = remaining.indexOf(ch);
        if (idx >= 0) remaining.splice(idx, 1);
      }
    }
  }
  return cSet;
}

// 提取对/靠（先对后靠）
function extractDuiAndKao(remaining) {
  const byChar = {};
  for (const ch of remaining) {
    byChar[ch] = (byChar[ch] || 0) + 1;
  }
  const dSet = [];
  // 先提取对
  for (const [ch, count] of Object.entries(byChar)) {
    if (count >= 2) {
      dSet.push({ type: 'dui', char: ch, isJing: isJing(ch) });
      for (let i = 0; i < 2; i++) {
        const idx = remaining.indexOf(ch);
        if (idx >= 0) remaining.splice(idx, 1);
      }
      return { dSet, remaining }; // 递归处理
    }
  }
  // 再提取靠（同组不同2张，不含上/福组合的靠可以含上/福）
  const bySentence = {};
  for (const ch of remaining) {
    const info = getCharInfo(ch);
    if (!info) continue;
    if (!bySentence[info.sentence]) bySentence[info.sentence] = {};
    bySentence[info.sentence][ch] = info.position;
  }
  for (const [s, chars] of Object.entries(bySentence)) {
    const charKeys = Object.keys(chars);
    if (charKeys.length >= 2) {
      const c1 = charKeys[0];
      const c2 = charKeys[1];
      dSet.push({ type: 'kao', chars: [c1, c2], isJing: isJing(c1) || isJing(c2) });
      const idx1 = remaining.indexOf(c1);
      if (idx1 >= 0) remaining.splice(idx1, 1);
      const idx2 = remaining.indexOf(c2);
      if (idx2 >= 0) remaining.splice(idx2, 1);
      return { dSet, remaining };
    }
  }
  return { dSet, remaining };
}

// 完整提取
function fullExtract(hand) {
  const remaining = [...hand];
  const aSet = [];
  const cSet = [];
  let dSet = [];

  // 反复提取句
  let prevLen = -1;
  while (remaining.length !== prevLen) {
    prevLen = remaining.length;
    const ju = extractJu(remaining);
    if (ju.length > 0) aSet.push(...ju);
  }

  // 反复提取坎
  prevLen = -1;
  while (remaining.length !== prevLen) {
    prevLen = remaining.length;
    const kan = extractKan(remaining);
    if (kan.length > 0) cSet.push(...kan);
  }

  // 反复提取对/靠
  prevLen = -1;
  while (remaining.length !== prevLen) {
    prevLen = remaining.length;
    const result = extractDuiAndKao(remaining);
    if (result.dSet.length > 0) {
      dSet.push(...result.dSet);
      remaining.length = 0;
      remaining.push(...result.remaining);
    }
  }

  const eSet = [...remaining];
  return { aSet, cSet, dSet, eSet };
}

// 计算单张胡数
function singleHu(ch) {
  if (isJing(ch)) return 4;
  if (isYin(ch)) return 0;
  return 0;
}

// 计算手牌胡数
function calcHandHu(hand) {
  const { aSet, cSet, dSet, eSet } = fullExtract(hand);
  let hu = 0;
  // A集句：普句0，精句4
  for (const ju of aSet) {
    hu += ju.isJing ? 4 : 0;
  }
  // C集坎：普坎3，精坎12
  for (const kan of cSet) {
    hu += kan.isJing ? 12 : 3;
  }
  // D集对/靠
  for (const d of dSet) {
    if (d.type === 'dui') {
      if (d.isJing) hu += 8; // 金对
      else hu += 0; // 普对/银对
    } else { // kao
      if (d.isJing) hu += 4; // 精靠
      else hu += 0; // 普靠/银靠
    }
  }
  // E集单
  for (const ch of eSet) {
    hu += singleHu(ch);
  }
  return { hu, aSet, cSet, dSet, eSet };
}

// 组合牌胡数
function calcMeldHu(melds) {
  let hu = 0;
  for (const m of melds) {
    if (m.type === 'kan') hu += m.isJing ? 12 : 2; // 组合牌区普坎=2
    else if (m.type === 'ju') hu += m.isJing ? 4 : 0;
    else if (m.type === 'zhao') hu += m.isJing ? 16 : 6;
  }
  return hu;
}

// 计算总胡数
function calcTotalHu(hand, melds) {
  const meldHu = calcMeldHu(melds);
  const handResult = calcHandHu(hand);
  return meldHu + handResult.hu;
}

// 计算听牌距离（简化版）
function distanceToTing(hand, melds) {
  const { aSet, cSet, dSet, eSet } = fullExtract(hand);
  let totalMelds = aSet.length + cSet.length;
  for (const m of melds) {
    if (m.type === 'ju' || m.type === 'kan' || m.type === 'zhao') totalMelds++;
  }
  let neededMelds = 6 - totalMelds;
  if (neededMelds < 0) neededMelds = 0;
  let usefulDuiKao = dSet.length;
  let dist = neededMelds * 2 - usefulDuiKao;
  if (neededMelds > 0 && dist < neededMelds) dist = neededMelds;
  // 听牌条件
  if (eSet.length === 1 && dSet.length === 0) dist = 0;
  else if (dSet.length === 2 && eSet.length === 0) dist = 0;
  if (dist < 0) dist = 0;
  if (dist > 10) dist = 10;
  return dist;
}

console.log('='.repeat(80));
console.log('场景2分析：为什么出"福"');
console.log('='.repeat(80));

// 场景2
const melds2 = [{ type: 'kan', char: '佳', isJing: false }]; // 佳佳佳坎
const hand2 = '乙己己化三千七十土小生生八九福福寿'.split('');

console.log('\n手牌:', hand2.join(''), `(${hand2.length}张)`);
console.log('组合牌: 佳佳佳(坎)');

const handResult2 = calcHandHu(hand2);
const meldHu2 = calcMeldHu(melds2);
const totalHu2 = meldHu2 + handResult2.hu;

console.log('\n--- 手牌结构分析 ---');
console.log('A集(句):', handResult2.aSet.map(j => j.chars.join('')));
console.log('C集(坎):', handResult2.cSet.map(k => k.char));
console.log('D集(对/靠):', handResult2.dSet.map(d => d.type === 'dui' ? d.char+d.char : d.chars.join('')));
console.log('E集(单):', handResult2.eSet);
console.log(`组合牌胡数: ${meldHu2}, 手牌胡数: ${handResult2.hu}, 总胡数: ${totalHu2}`);
console.log(`听牌距离: ${distanceToTing(hand2, melds2)}`);

// 模拟出每张牌后的胡数变化
console.log('\n--- 出各牌后的胡数对比 ---');
const uniqueChars = [...new Set(hand2)];
const results = [];
for (const ch of uniqueChars) {
  const testHand = [...hand2];
  const idx = testHand.indexOf(ch);
  testHand.splice(idx, 1);
  const hu = calcTotalHu(testHand, melds2);
  const dist = distanceToTing(testHand, melds2);
  const huLoss = totalHu2 - hu;
  results.push({ ch, hu, dist, huLoss });
  console.log(`出"${ch}": 总胡数=${hu}(损失${huLoss}), 听牌距离=${dist}`);
}

// 按胡数损失排序
console.log('\n--- 按胡数损失排序 ---');
results.sort((a, b) => a.huLoss - b.huLoss);
for (const r of results) {
  console.log(`出"${r.ch}": 胡数损失=${r.huLoss}, 听牌距离=${r.dist}`);
}

console.log('\n' + '='.repeat(80));
console.log('场景1分析：为什么出"十"');
console.log('='.repeat(80));

// 场景1
const melds1 = []; // 无组合牌
const hand1 = '大乙己己化三千七十十土小生生八佳佳福福'.split('');

console.log('\n手牌:', hand1.join(''), `(${hand1.length}张)`);
console.log('组合牌: 无');

const handResult1 = calcHandHu(hand1);
const totalHu1 = handResult1.hu;

console.log('\n--- 手牌结构分析 ---');
console.log('A集(句):', handResult1.aSet.map(j => j.chars.join('')));
console.log('C集(坎):', handResult1.cSet.map(k => k.char));
console.log('D集(对/靠):', handResult1.dSet.map(d => d.type === 'dui' ? d.char+d.char : d.chars.join('')));
console.log('E集(单):', handResult1.eSet);
console.log(`手牌胡数: ${totalHu1}`);
console.log(`听牌距离: ${distanceToTing(hand1, melds1)}`);

// 模拟出每张牌后的胡数变化
console.log('\n--- 出各牌后的胡数对比 ---');
const uniqueChars1 = [...new Set(hand1)];
const results1 = [];
for (const ch of uniqueChars1) {
  const testHand = [...hand1];
  const idx = testHand.indexOf(ch);
  testHand.splice(idx, 1);
  const hu = calcTotalHu(testHand, melds1);
  const dist = distanceToTing(testHand, melds1);
  const huLoss = totalHu1 - hu;
  results1.push({ ch, hu, dist, huLoss });
  console.log(`出"${ch}": 总胡数=${hu}(损失${huLoss}), 听牌距离=${dist}`);
}

console.log('\n--- 按胡数损失排序 ---');
results1.sort((a, b) => a.huLoss - b.huLoss);
for (const r of results1) {
  console.log(`出"${r.ch}": 胡数损失=${r.huLoss}, 听牌距离=${r.dist}`);
}
