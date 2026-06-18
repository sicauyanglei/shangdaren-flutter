// 精确分析场景 - 修正对/靠提取逻辑
const groups = {
  1: ['上', '大', '人'], 2: ['丘', '乙', '己'], 3: ['化', '三', '千'],
  4: ['七', '十', '土'], 5: ['尔', '小', '生'], 6: ['八', '九', '子'],
  7: ['佳', '作', '亡'], 8: ['福', '禄', '寿'],
};

function getCharInfo(ch) {
  for (const [g, chars] of Object.entries(groups)) {
    const idx = chars.indexOf(ch);
    if (idx >= 0) return { sentence: parseInt(g), position: idx + 1 };
  }
  return null;
}
function isJing(ch) { return ch === '上' || ch === '福'; }
function isYin(ch) { return ['大', '人', '禄', '寿'].includes(ch); }

// 精确提取句（递归，同组3个不同position）
function extractJuAll(remaining) {
  const aSet = [];
  let changed = true;
  while (changed) {
    changed = false;
    const bySentence = {};
    for (const ch of remaining) {
      const info = getCharInfo(ch);
      if (!info) continue;
      if (!bySentence[info.sentence]) bySentence[info.sentence] = {};
      if (!bySentence[info.sentence][info.position]) bySentence[info.sentence][info.position] = 0;
      bySentence[info.sentence][info.position]++;
    }
    for (const [s, positions] of Object.entries(bySentence)) {
      const posKeys = Object.keys(positions).map(Number).sort();
      if (posKeys.length >= 3) {
        const juChars = posKeys.slice(0, 3).map(p => groups[s][p - 1]);
        aSet.push({ chars: juChars, sentence: parseInt(s), isJing: juChars.some(c => isJing(c)) });
        for (const ch of juChars) {
          const idx = remaining.indexOf(ch);
          if (idx >= 0) remaining.splice(idx, 1);
        }
        changed = true;
        break;
      }
    }
  }
  return aSet;
}

// 提取坎（同字3张）
function extractKanAll(remaining) {
  const cSet = [];
  let changed = true;
  while (changed) {
    changed = false;
    const byChar = {};
    for (const ch of remaining) byChar[ch] = (byChar[ch] || 0) + 1;
    for (const [ch, count] of Object.entries(byChar)) {
      if (count >= 3) {
        cSet.push({ char: ch, isJing: isJing(ch) });
        for (let i = 0; i < 3; i++) {
          const idx = remaining.indexOf(ch);
          if (idx >= 0) remaining.splice(idx, 1);
        }
        changed = true;
        break;
      }
    }
  }
  return cSet;
}

// 提取对/靠（先对后靠，递归）
function extractDuiAndKaoAll(remaining) {
  const dSet = [];
  let changed = true;
  while (changed) {
    changed = false;
    // 先找对
    const byChar = {};
    for (const ch of remaining) byChar[ch] = (byChar[ch] || 0) + 1;
    for (const [ch, count] of Object.entries(byChar)) {
      if (count >= 2) {
        dSet.push({ type: 'dui', char: ch, isJing: isJing(ch) });
        for (let i = 0; i < 2; i++) {
          const idx = remaining.indexOf(ch);
          if (idx >= 0) remaining.splice(idx, 1);
        }
        changed = true;
        break;
      }
    }
    if (changed) continue;
    // 再找靠（同组不同2张）
    const bySentence = {};
    for (const ch of remaining) {
      const info = getCharInfo(ch);
      if (!info) continue;
      if (!bySentence[info.sentence]) bySentence[info.sentence] = [];
      if (!bySentence[info.sentence].includes(ch)) bySentence[info.sentence].push(ch);
    }
    for (const [s, chars] of Object.entries(bySentence)) {
      if (chars.length >= 2) {
        const c1 = chars[0], c2 = chars[1];
        dSet.push({ type: 'kao', chars: [c1, c2], isJing: isJing(c1) || isJing(c2) });
        const idx1 = remaining.indexOf(c1);
        if (idx1 >= 0) remaining.splice(idx1, 1);
        const idx2 = remaining.indexOf(c2);
        if (idx2 >= 0) remaining.splice(idx2, 1);
        changed = true;
        break;
      }
    }
  }
  return dSet;
}

function fullExtract(hand) {
  const remaining = [...hand];
  const aSet = extractJuAll(remaining);
  const cSet = extractKanAll(remaining);
  const dSet = extractDuiAndKaoAll(remaining);
  const eSet = [...remaining];
  return { aSet, cSet, dSet, eSet };
}

function singleHu(ch) {
  if (isJing(ch)) return 4;
  return 0;
}

function calcHandHu(hand, melds) {
  const { aSet, cSet, dSet, eSet } = fullExtract(hand);
  let hu = 0;
  for (const ju of aSet) hu += ju.isJing ? 4 : 0;
  for (const kan of cSet) hu += kan.isJing ? 12 : 3;
  for (const d of dSet) {
    if (d.type === 'dui') hu += d.isJing ? 8 : 0;
    else hu += d.isJing ? 4 : 0;
  }
  for (const ch of eSet) hu += singleHu(ch);

  // 附加胡数
  // a. D中普对对应字在A中有且只有1张 → +3
  for (const d of dSet) {
    if (d.type === 'dui' && !d.isJing) {
      const count = aSet.reduce((sum, ju) => sum + ju.chars.filter(c => c === d.char).length, 0);
      if (count === 1) hu += 3;
    }
  }
  // b. D中普靠对应字在A中有且只有2张 → +6
  for (const d of dSet) {
    if (d.type === 'kao' && !d.isJing) {
      for (const ch of d.chars) {
        const count = aSet.reduce((sum, ju) => sum + ju.chars.filter(c => c === ch).length, 0);
        if (count === 2) { hu += 6; break; }
      }
    }
  }
  // c. E中普单对应字在A中有且只有2张 → +3
  for (const ch of eSet) {
    if (!isJing(ch)) {
      const count = aSet.reduce((sum, ju) => sum + ju.chars.filter(c => c === ch).length, 0);
      if (count === 2) hu += 3;
    }
  }
  // d. A中3句相同：精句+6，普句+9
  const juBySentence = {};
  for (const ju of aSet) {
    const key = ju.sentence;
    juBySentence[key] = (juBySentence[key] || 0) + 1;
  }
  for (const [s, count] of Object.entries(juBySentence)) {
    if (count === 3) {
      const isJingJu = groups[s].some(c => isJing(c));
      hu += isJingJu ? 6 : 9;
    }
  }

  return { hu, aSet, cSet, dSet, eSet };
}

function calcMeldHu(melds) {
  let hu = 0;
  for (const m of melds) {
    if (m.type === 'kan') hu += m.isJing ? 12 : 2;
    else if (m.type === 'ju') hu += m.isJing ? 4 : 0;
    else if (m.type === 'zhao') hu += m.isJing ? 16 : 6;
  }
  return hu;
}

function calcTotalHu(hand, melds) {
  const meldHu = calcMeldHu(melds);
  const handResult = calcHandHu(hand, melds);
  return { total: meldHu + handResult.hu, meldHu, handHu: handResult.hu, ...handResult };
}

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
  if (eSet.length === 1 && dSet.length === 0) dist = 0;
  else if (dSet.length === 2 && eSet.length === 0) dist = 0;
  if (dist < 0) dist = 0;
  if (dist > 10) dist = 10;
  return dist;
}

function analyze(name, handStr, meldsArr) {
  console.log('='.repeat(80));
  console.log(`${name}`);
  console.log('='.repeat(80));
  const hand = handStr.split('');
  console.log(`手牌: ${handStr} (${hand.length}张)`);
  console.log(`组合牌: ${meldsArr.map(m => m.type === 'kan' ? m.char+m.char+m.char : '').join(',')}`);

  const result = calcTotalHu(hand, meldsArr);
  console.log(`\n--- 手牌结构 ---`);
  console.log(`A集(句): [${result.aSet.map(j => j.chars.join('')).join(', ')}]`);
  console.log(`C集(坎): [${result.cSet.map(k => k.char).join(', ')}]`);
  console.log(`D集(对/靠): [${result.dSet.map(d => d.type === 'dui' ? d.char+d.char : d.chars.join('')).join(', ')}]`);
  console.log(`E集(单): [${result.eSet.join(', ')}]`);
  console.log(`组合牌胡数: ${result.meldHu}, 手牌胡数: ${result.handHu}, 总胡数: ${result.total}`);
  console.log(`听牌距离: ${distanceToTing(hand, meldsArr)}`);

  console.log(`\n--- 出各牌后对比 ---`);
  const uniqueChars = [...new Set(hand)];
  const results = [];
  for (const ch of uniqueChars) {
    const testHand = [...hand];
    const idx = testHand.indexOf(ch);
    testHand.splice(idx, 1);
    const r = calcTotalHu(testHand, meldsArr);
    const dist = distanceToTing(testHand, meldsArr);
    const huLoss = result.total - r.total;
    results.push({ ch, hu: r.total, dist, huLoss, dSet: r.dSet, eSet: r.eSet });
  }
  results.sort((a, b) => a.huLoss - b.huLoss || a.dist - b.dist);
  for (const r of results) {
    const dStr = r.dSet.map(d => d.type === 'dui' ? d.char+d.char : d.chars.join('')).join(',');
    const eStr = r.eSet.join('');
    console.log(`出"${r.ch}": 胡数=${r.hu}(损失${r.huLoss}), 距离=${r.dist}, D=[${dStr}], E=[${eStr}]`);
  }
  console.log('');
}

// 场景2
analyze('场景2: 为什么出"福"', '乙己己化三千七十土小生生八九福福寿',
  [{ type: 'kan', char: '佳', isJing: false }]);

// 场景1
analyze('场景1: 为什么出"十"', '大乙己己化三千七十十土小生生八佳佳福福', []);
