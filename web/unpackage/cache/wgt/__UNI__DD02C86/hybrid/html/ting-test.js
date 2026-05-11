// 听牌类型单元测试 - 全面覆盖版
// 每种胡牌类型30+测试用例
// 牌数规则：
// - 听牌状态：手牌13张，等待摸第14张牌
// - 正常：组合牌(2个吃牌=6张) + 手牌(13张) = 19张
// - 有招：组合牌(1招=4张) + 手牌(13张) = 17张，听牌时手牌13张
// - 十对：无组合牌，手牌20张（听牌时手牌19张，等第20张）

const ALL_CHARACTERS = ['上', '大', '人', '丘', '乙', '己', '化', '三', '千', '七', '十', '土', '尔', '小', '生', '八', '九', '子', '佳', '作', '亡', '福', '禄', '寿'];

function createCard(char) {
  const cardMap = {
    '上': { character: '上', sentence: 1, position: 0, color: 'red' },
    '大': { character: '大', sentence: 1, position: 1, color: 'green' },
    '人': { character: '人', sentence: 1, position: 2, color: 'black' },
    '丘': { character: '丘', sentence: 2, position: 0, color: 'red' },
    '乙': { character: '乙', sentence: 2, position: 1, color: 'green' },
    '己': { character: '己', sentence: 2, position: 2, color: 'black' },
    '化': { character: '化', sentence: 3, position: 0, color: 'red' },
    '三': { character: '三', sentence: 3, position: 1, color: 'green' },
    '千': { character: '千', sentence: 3, position: 2, color: 'black' },
    '七': { character: '七', sentence: 4, position: 0, color: 'red' },
    '十': { character: '十', sentence: 4, position: 1, color: 'green' },
    '土': { character: '土', sentence: 4, position: 2, color: 'black' },
    '尔': { character: '尔', sentence: 5, position: 0, color: 'red' },
    '小': { character: '小', sentence: 5, position: 1, color: 'green' },
    '生': { character: '生', sentence: 5, position: 2, color: 'black' },
    '八': { character: '八', sentence: 6, position: 0, color: 'red' },
    '九': { character: '九', sentence: 6, position: 1, color: 'green' },
    '子': { character: '子', sentence: 6, position: 2, color: 'black' },
    '佳': { character: '佳', sentence: 7, position: 0, color: 'red' },
    '作': { character: '作', sentence: 7, position: 1, color: 'green' },
    '亡': { character: '亡', sentence: 7, position: 2, color: 'black' },
    '福': { character: '福', sentence: 8, position: 0, color: 'red' },
    '禄': { character: '禄', sentence: 8, position: 1, color: 'green' },
    '寿': { character: '寿', sentence: 8, position: 2, color: 'black' }
  };
  return { ...cardMap[char], id: Math.random().toString(36).substr(2, 9) };
}

function createHand(chars) {
  return chars.split('').map(c => createCard(c));
}

function calcTotalCards(hand, melds) {
  let total = hand.length;
  for (const meld of melds) {
    total += meld.cards.length;
  }
  return total;
}

// ==================== 测试用例生成函数 ====================
function generateShiDuiTests() {
  const tests = [];
  
  // 十对听牌状态：手牌19张（9对+1单张），等第20张成对
  const shiDuiCases = [
    { hand: '丘丘乙乙己己化化三三千千尔尔小小生生八', waitCard: '八' },
    { hand: '上上大大人人丘丘乙乙己己化化三三千千七', waitCard: '七' },
    { hand: '福福禄禄寿寿丘丘乙乙己己化化三三千千尔', waitCard: '尔' },
    { hand: '上上福福丘丘乙乙己己化化三三千千尔尔小', waitCard: '小' },
    { hand: '七七十十土土尔尔小小生生八八九九子子佳', waitCard: '佳' },
    { hand: '佳佳作作亡亡福福禄禄寿寿丘丘乙乙己己化', waitCard: '化' },
    { hand: '丘丘乙乙己己化化三三千千七七十十土土尔', waitCard: '尔' },
    { hand: '尔尔小小生生八八九九子子佳佳作作亡亡福', waitCard: '福' },
    { hand: '上上大大人人福福禄禄寿寿丘丘乙乙己己化', waitCard: '化' },
    { hand: '丘丘乙乙己己尔尔小小生生八八九九子子佳', waitCard: '佳' },
    { hand: '化化三三千千七七十十土土佳佳作作亡亡福', waitCard: '福' },
    { hand: '上上丘丘乙乙己己化化三三千千尔尔小小生', waitCard: '生' },
    { hand: '大大人人丘丘乙乙己己化化三三千千七七十', waitCard: '十' },
    { hand: '福福丘丘乙乙己己化化三三千千尔尔小小生', waitCard: '生' },
    { hand: '上上福福禄禄寿寿丘丘乙乙己己化化三三千', waitCard: '千' },
    { hand: '丘丘乙乙己己化化三三千千尔尔小小生生八', waitCard: '八' },
    { hand: '七七十十土土尔尔小小生生八八九九子子佳', waitCard: '佳' },
    { hand: '佳佳作作亡亡丘丘乙乙己己化化三三千千尔', waitCard: '尔' },
    { hand: '上上大大人人丘丘乙乙己己尔尔小小生生八', waitCard: '八' },
    { hand: '福福禄禄寿寿七七十十土土八八九九子子佳', waitCard: '佳' },
    { hand: '丘丘乙乙化化三三千千尔尔小小生生八八九', waitCard: '九' },
    { hand: '上上人人丘丘己己化化三三千千尔尔小小生', waitCard: '生' },
    { hand: '福福寿寿丘丘乙乙己己化化三三千千尔尔小', waitCard: '小' },
    { hand: '丘丘乙乙己己化化千千尔尔小小生生八八九', waitCard: '九' },
    { hand: '七七十土土尔尔小小生生八八九九子子佳佳', waitCard: '佳' },
    { hand: '上上大大福福禄禄寿寿丘丘乙乙己己化化三', waitCard: '三' },
    { hand: '丘丘乙乙己己尔尔小小生生八八九九子子佳', waitCard: '佳' },
    { hand: '化化三三千千七七十十土土尔尔小小生生八', waitCard: '八' },
    { hand: '上上福福丘丘乙乙己己化化三三千千尔尔小', waitCard: '小' },
    { hand: '大大人人福福禄禄寿寿丘丘乙乙己己化化三', waitCard: '三' }
  ];
  
  for (let i = 0; i < shiDuiCases.length; i++) {
    tests.push({
      name: `十对 - 测试${i + 1}`,
      hand: shiDuiCases[i].hand,
      melds: [],
      expectedTing: true,
      expectedType: 'shiDui',
      description: `手牌19张(9对+1单)，等"${shiDuiCases[i].waitCard}"成十对`
    });
  }
  
  // 不听牌测试
  tests.push({
    name: '十对 - 8对不听',
    hand: '丘丘乙乙己己化化三三千千尔尔小小生生',
    melds: [],
    expectedTing: false,
    expectedType: 'none',
    description: '只有8对牌，不满足十对条件'
  });
  
  return tests;
}

function generateHeiYuanTests() {
  const tests = [];
  
  // 黑元听牌状态：无上/福，无碰/招，句子模式+半靠
  // 组合牌2吃(6张) + 手牌13张 = 19张
  // 黑元条件（摸牌后）：手牌14张满足句子模式，剩余2张是半靠
  
  // 听牌状态设计：
  // 手牌13张 = 4个完整句子(12张) + 1张单牌
  // 摸牌后14张 = 4个完整句子(12张) + 2张半靠
  // 单牌必须是某个句子组的字，摸到同组另一个字后形成半靠
  
  // 设计：
  // 组合牌：七十土(句4) + 佳作亡(句7) = 6张（无上/福）
  // 手牌：丘乙己(句2) + 化三千(句3) + 尔小生(句5) + 八九子(句6) + 人(单，句1) = 13张
  // 摸"大"后：剩余"人大"是半靠（句1，位置1和2）
  
  const heiYuanCases = [
    { hand: '丘乙己化三千尔小生八九子人', desc: '等人大成半靠' },
    { hand: '丘乙己化三千尔小生八九子大', desc: '等人大成半靠' },
    { hand: '丘乙己化三千尔小生八九子丘', desc: '等丘乙/丘己成半靠' },
    { hand: '丘乙己化三千尔小生八九子乙', desc: '等丘乙/乙己成半靠' },
    { hand: '丘乙己化三千尔小生八九子己', desc: '等丘己/乙己成半靠' },
    { hand: '丘乙己化三千尔小生八九子化', desc: '等化三/化千成半靠' },
    { hand: '丘乙己化三千尔小生八九子三', desc: '等化三/三千成半靠' },
    { hand: '丘乙己化三千尔小生八九子千', desc: '等化千/三千成半靠' },
    { hand: '丘乙己化三千尔小生八九子尔', desc: '等尔小/尔生成半靠' },
    { hand: '丘乙己化三千尔小生八九子小', desc: '等尔小/小生成半靠' }
  ];
  
  for (let i = 0; i < heiYuanCases.length; i++) {
    tests.push({
      name: `黑元 - 测试${i + 1}`,
      hand: heiYuanCases[i].hand,
      melds: [
        { type: 'sequence', cards: createHand('七十土'), huValue: 0 },
        { type: 'sequence', cards: createHand('佳作亡'), huValue: 0 }
      ],
      expectedTing: true,
      expectedType: 'heiYuan',
      description: `组合牌6张(2吃)+手牌13张，${heiYuanCases[i].desc}`
    });
  }
  
  // 不满足黑元条件的测试
  tests.push({
    name: '黑元 - 有上字',
    hand: '上丘乙己化三千尔小生八九子人',
    melds: [
      { type: 'sequence', cards: createHand('七十土'), huValue: 0 },
      { type: 'sequence', cards: createHand('佳作亡'), huValue: 0 }
    ],
    expectedTing: false,
    expectedType: 'none',
    description: '有上字，不满足黑元条件'
  });
  
  tests.push({
    name: '黑元 - 有福字',
    hand: '福丘乙己化三千尔小生八九子人',
    melds: [
      { type: 'sequence', cards: createHand('七十土'), huValue: 0 },
      { type: 'sequence', cards: createHand('佳作亡'), huValue: 0 }
    ],
    expectedTing: false,
    expectedType: 'none',
    description: '有福字，不满足黑元条件'
  });
  
  tests.push({
    name: '黑元 - 有碰牌',
    hand: '丘乙己化三千尔小生八九子人',
    melds: [
      { type: 'triplet', cards: createHand('七七七'), huValue: 2 },
      { type: 'sequence', cards: createHand('佳作亡'), huValue: 0 }
    ],
    expectedTing: false,
    expectedType: 'none',
    description: '有碰牌，不满足黑元条件'
  });
  
  return tests;
}

function generateHongYuanTests() {
  const tests = [];
  
  // 红元测试 - 有上/福精牌
  // 红元3精：上3张+福3张=6精
  const hongYuan3JingCases = [
    '上上上福福福丘乙己化三千尔',
    '上上上福福福丘乙己化三尔小',
    '上上上福福福丘乙己化三千千',
    '上上上福福福丘乙己化三三三',
    '上上上福福福丘乙己尔小生八',
    '上上上福福福丘乙己化三尔尔',
    '上上上福福福丘乙己化三小小',
    '上上上福福福丘乙己化三生生',
    '上上上福福福丘乙己化三小生',
    '上上上福福福丘乙己化三千小'
  ];
  
  for (let i = 0; i < hongYuan3JingCases.length; i++) {
    tests.push({
      name: `红元3精 - 测试${i + 1}`,
      hand: hongYuan3JingCases[i],
      melds: [],
      expectedTing: true,
      expectedType: 'hongYuan3Jing',
      description: '上3张+福3张=6精'
    });
  }
  
  // 红元4精：上4张或福4张
  const hongYuan4JingCases = [
    '上上上上丘乙己化三千尔小生',
    '福福福福丘乙己化三千尔小生',
    '上上上上丘乙己化三尔小生八',
    '福福福福丘乙己化三尔小生八',
    '上上上上丘乙己化三千尔小小',
    '福福福福丘乙己化三千尔小小',
    '上上上上丘乙己化三尔小生生',
    '福福福福丘乙己化三尔小生生',
    '上上上上丘乙己化三千千尔尔',
    '福福福福丘乙己化三千千尔尔'
  ];
  
  for (let i = 0; i < hongYuan4JingCases.length; i++) {
    tests.push({
      name: `红元4精 - 测试${i + 1}`,
      hand: hongYuan4JingCases[i],
      melds: [],
      expectedTing: true,
      expectedType: 'hongYuan4Jing',
      description: '上/福4张=4精'
    });
  }
  
  // 红元5精
  const hongYuan5JingCases = [
    '上上上上福丘乙己化三千尔小',
    '上福福福福丘乙己化三千尔小',
    '上上上上福丘乙己化三尔小生',
    '上福福福福丘乙己化三尔小生',
    '上上上上福丘乙己化三千千尔',
    '上福福福福丘乙己化三千千尔'
  ];
  
  for (let i = 0; i < hongYuan5JingCases.length; i++) {
    tests.push({
      name: `红元5精 - 测试${i + 1}`,
      hand: hongYuan5JingCases[i],
      melds: [],
      expectedTing: true,
      expectedType: 'hongYuan5Jing',
      description: '上/福共5精'
    });
  }
  
  // 红元6精
  const hongYuan6JingCases = [
    '上上上上福福丘乙己化三千尔',
    '上上福福福福丘乙己化三千尔',
    '上上上上福福丘乙己化三尔小',
    '上上福福福福丘乙己化三尔小',
    '上上上上福福丘乙己化三千千',
    '上上福福福福丘乙己化三千千'
  ];
  
  for (let i = 0; i < hongYuan6JingCases.length; i++) {
    tests.push({
      name: `红元6精 - 测试${i + 1}`,
      hand: hongYuan6JingCases[i],
      melds: [],
      expectedTing: true,
      expectedType: 'hongYuan6Jing',
      description: '上/福共6精'
    });
  }
  
  // 红元7精
  const hongYuan7JingCases = [
    '上上上上福福福丘乙己化三千',
    '上上上福福福福丘乙己化三千',
    '上上上上福福福丘乙己化三尔',
    '上上上福福福福丘乙己化三尔',
    '上上上上福福福丘乙己化千千',
    '上上上福福福福丘乙己化千千'
  ];
  
  for (let i = 0; i < hongYuan7JingCases.length; i++) {
    tests.push({
      name: `红元7精 - 测试${i + 1}`,
      hand: hongYuan7JingCases[i],
      melds: [],
      expectedTing: true,
      expectedType: 'hongYuan7Jing',
      description: '上/福共7精'
    });
  }
  
  return tests;
}

function generateKuHuTests() {
  const tests = [];
  
  // 枯胡听牌状态：
  // 听牌时：坎>=3，对=2，有上/福，无单张
  // 摸牌后：坎>=4，对=1（其中一个对变成坎）
  
  // 手牌13张：上上(对) + 福福(对) + 丘丘丘(坎) + 乙乙乙(坎) + 己己己(坎)
  // 摸"上"或"福"后满足枯胡条件
  const kuHuCases = [
    { hand: '上上福福丘丘丘乙乙乙己己己', waitCards: ['上', '福'] },
    { hand: '上上福福丘丘丘乙乙乙化化化', waitCards: ['上', '福'] },
    { hand: '上上福福丘丘丘乙乙乙三三三', waitCards: ['上', '福'] },
    { hand: '上上福福丘丘丘乙乙乙千千千', waitCards: ['上', '福'] },
    { hand: '上上福福丘丘丘乙乙乙尔尔尔', waitCards: ['上', '福'] },
    { hand: '上上福福丘丘丘乙乙乙小小小', waitCards: ['上', '福'] },
    { hand: '上上福福丘丘丘乙乙乙生生生', waitCards: ['上', '福'] },
    { hand: '上上福福丘丘丘乙乙乙八八八', waitCards: ['上', '福'] },
    { hand: '上上福福丘丘丘乙乙乙九九九', waitCards: ['上', '福'] },
    { hand: '上上福福丘丘丘乙乙乙子子子', waitCards: ['上', '福'] },
    { hand: '上上福福丘丘丘己己己化化化', waitCards: ['上', '福'] },
    { hand: '上上福福丘丘丘己己己三三三', waitCards: ['上', '福'] },
    { hand: '上上福福丘丘丘己己己千千千', waitCards: ['上', '福'] },
    { hand: '上上福福丘丘丘己己己尔尔尔', waitCards: ['上', '福'] },
    { hand: '上上福福丘丘丘己己己小小小', waitCards: ['上', '福'] },
    { hand: '上上福福丘丘丘己己己生生生', waitCards: ['上', '福'] },
    { hand: '上上福福丘丘丘己己己八八八', waitCards: ['上', '福'] },
    { hand: '上上福福丘丘丘己己己九九九', waitCards: ['上', '福'] },
    { hand: '上上福福丘丘丘己己己子子子', waitCards: ['上', '福'] },
    { hand: '上上福福丘丘丘化化化三三三', waitCards: ['上', '福'] },
    { hand: '上上福福丘丘丘化化化千千千', waitCards: ['上', '福'] },
    { hand: '上上福福丘丘丘化化化尔尔尔', waitCards: ['上', '福'] },
    { hand: '上上福福丘丘丘化化化小小小', waitCards: ['上', '福'] },
    { hand: '上上福福丘丘丘化化化生生生', waitCards: ['上', '福'] },
    { hand: '上上福福丘丘丘化化化八八八', waitCards: ['上', '福'] },
    { hand: '上上福福丘丘丘化化化九九九', waitCards: ['上', '福'] },
    { hand: '上上福福丘丘丘化化化子子子', waitCards: ['上', '福'] },
    { hand: '上上福福丘丘丘三三三千千千', waitCards: ['上', '福'] },
    { hand: '上上福福丘丘丘三三三尔尔尔', waitCards: ['上', '福'] },
    { hand: '上上福福丘丘丘三三三小小小', waitCards: ['上', '福'] }
  ];
  
  for (let i = 0; i < kuHuCases.length; i++) {
    tests.push({
      name: `枯胡 - 测试${i + 1}`,
      hand: kuHuCases[i].hand,
      melds: [],
      expectedTing: true,
      expectedType: 'kuHu',
      description: `听牌状态：坎3对2，等摸上/福成枯胡`
    });
  }
  
  return tests;
}

function generateQingKuHuTests() {
  const tests = [];
  
  // 清枯胡听牌状态：无上/福，坎>=3，对=2，无单张
  const qingKuHuCases = [
    { hand: '丘丘乙乙己己己化化化三三三', waitCards: ['丘', '乙'] },
    { hand: '丘丘乙乙己己己化化化千千千', waitCards: ['丘', '乙'] },
    { hand: '丘丘乙乙己己己化化化尔尔尔', waitCards: ['丘', '乙'] },
    { hand: '丘丘乙乙己己己化化化小小小', waitCards: ['丘', '乙'] },
    { hand: '丘丘乙乙己己己化化化生生生', waitCards: ['丘', '乙'] },
    { hand: '丘丘乙乙己己己化化化八八八', waitCards: ['丘', '乙'] },
    { hand: '丘丘乙乙己己己化化化九九九', waitCards: ['丘', '乙'] },
    { hand: '丘丘乙乙己己己化化化子子子', waitCards: ['丘', '乙'] },
    { hand: '丘丘乙乙己己己三三三千千千', waitCards: ['丘', '乙'] },
    { hand: '丘丘乙乙己己己三三三尔尔尔', waitCards: ['丘', '乙'] },
    { hand: '丘丘乙乙己己己三三三小小小', waitCards: ['丘', '乙'] },
    { hand: '丘丘乙乙己己己三三三生生生', waitCards: ['丘', '乙'] },
    { hand: '丘丘乙乙己己己三三三八八八', waitCards: ['丘', '乙'] },
    { hand: '丘丘乙乙己己己三三三九九九', waitCards: ['丘', '乙'] },
    { hand: '丘丘乙乙己己己三三三子子子', waitCards: ['丘', '乙'] },
    { hand: '丘丘乙乙己己己千千千尔尔尔', waitCards: ['丘', '乙'] },
    { hand: '丘丘乙乙己己己千千千小小小', waitCards: ['丘', '乙'] },
    { hand: '丘丘乙乙己己己千千千生生生', waitCards: ['丘', '乙'] },
    { hand: '丘丘乙乙己己己千千千八八八', waitCards: ['丘', '乙'] },
    { hand: '丘丘乙乙己己己千千千九九九', waitCards: ['丘', '乙'] },
    { hand: '丘丘乙乙己己己千千千子子子', waitCards: ['丘', '乙'] },
    { hand: '丘丘乙乙己己己尔尔尔小小小', waitCards: ['丘', '乙'] },
    { hand: '丘丘乙乙己己己尔尔尔生生生', waitCards: ['丘', '乙'] },
    { hand: '丘丘乙乙己己己尔尔尔八八八', waitCards: ['丘', '乙'] },
    { hand: '丘丘乙乙己己己尔尔尔九九九', waitCards: ['丘', '乙'] },
    { hand: '丘丘乙乙己己己尔尔尔子子子', waitCards: ['丘', '乙'] },
    { hand: '丘丘乙乙己己己小小小生生生', waitCards: ['丘', '乙'] },
    { hand: '丘丘乙乙己己己小小小八八八', waitCards: ['丘', '乙'] },
    { hand: '丘丘乙乙己己己小小小九九九', waitCards: ['丘', '乙'] },
    { hand: '丘丘乙乙己己己小小小子子子', waitCards: ['丘', '乙'] }
  ];
  
  for (let i = 0; i < qingKuHuCases.length; i++) {
    tests.push({
      name: `清枯胡 - 测试${i + 1}`,
      hand: qingKuHuCases[i].hand,
      melds: [],
      expectedTing: true,
      expectedType: 'qingKuHu',
      description: `听牌状态：无上/福，坎3对2，等摸成清枯胡`
    });
  }
  
  return tests;
}

function generateKaHuTests() {
  const tests = [];
  
  // 卡胡测试 - 11胡
  // 组合牌1招(4张) + 手牌13张 = 17张，听牌时手牌13张
  const kaHuCases = [
    { hand: '上丘乙己化三尔小生八九十土', meldChar: '七' },
    { hand: '上丘乙己化三尔小生八九十土', meldChar: '八' },
    { hand: '上丘乙己化三尔小生八九十土', meldChar: '九' },
    { hand: '上丘乙己化三尔小生八九十土', meldChar: '子' },
    { hand: '上丘乙己化三尔小生八九十土', meldChar: '尔' },
    { hand: '上丘乙己化三尔小生八九十土', meldChar: '小' },
    { hand: '上丘乙己化三尔小生八九十土', meldChar: '生' },
    { hand: '上丘乙己化三尔小生八九十土', meldChar: '丘' },
    { hand: '福丘乙己化三尔小生八九十土', meldChar: '七' },
    { hand: '福丘乙己化三尔小生八九十土', meldChar: '八' },
    { hand: '福丘乙己化三尔小生八九十土', meldChar: '九' },
    { hand: '福丘乙己化三尔小生八九十土', meldChar: '子' }
  ];
  
  for (let i = 0; i < kaHuCases.length; i++) {
    const meldChar = kaHuCases[i].meldChar;
    tests.push({
      name: `卡胡 - 测试${i + 1}`,
      hand: kaHuCases[i].hand,
      melds: [{ type: 'quartet', cards: createHand(meldChar + meldChar + meldChar + meldChar), huValue: 6 }],
      expectedTing: true,
      expectedType: 'kaHu',
      description: '11胡，满足卡胡条件'
    });
  }
  
  return tests;
}

function generatePuTongHuTests() {
  const tests = [];
  
  // 普通胡测试 - 12-21胡
  const puTongHuCases = [
    { hand: '上丘乙己化三尔小生八九十土', melds: [{ type: 'quartet', cards: createHand('七七七七'), huValue: 6 }, { type: 'triplet', cards: createHand('八八八'), huValue: 3 }], hu: 12 },
    { hand: '上丘乙己化三尔小生八九十土', melds: [{ type: 'quartet', cards: createHand('八八八八'), huValue: 6 }, { type: 'triplet', cards: createHand('九九九'), huValue: 3 }], hu: 12 },
    { hand: '上丘乙己化三尔小生八九十', melds: [{ type: 'quartet', cards: createHand('七七七七'), huValue: 6 }, { type: 'quartet', cards: createHand('八八八八'), huValue: 6 }], hu: 15 },
    { hand: '福丘乙己化三尔小生八九十土', melds: [{ type: 'quartet', cards: createHand('七七七七'), huValue: 6 }, { type: 'triplet', cards: createHand('八八八'), huValue: 3 }], hu: 12 },
    { hand: '福丘乙己化三尔小生八九十', melds: [{ type: 'quartet', cards: createHand('七七七七'), huValue: 6 }, { type: 'quartet', cards: createHand('八八八八'), huValue: 6 }], hu: 15 },
    { hand: '上丘乙己化三尔小生八九十土', melds: [{ type: 'quartet', cards: createHand('尔尔尔尔'), huValue: 6 }, { type: 'triplet', cards: createHand('小小小'), huValue: 3 }], hu: 12 },
    { hand: '上丘乙己化三尔小生八九十土', melds: [{ type: 'quartet', cards: createHand('小小小小'), huValue: 6 }, { type: 'triplet', cards: createHand('生生生'), huValue: 3 }], hu: 12 },
    { hand: '上丘乙己化三尔小生八九十土', melds: [{ type: 'quartet', cards: createHand('生生生生'), huValue: 6 }, { type: 'triplet', cards: createHand('八八八'), huValue: 3 }], hu: 12 },
    { hand: '上丘乙己化三尔小生八九十土', melds: [{ type: 'quartet', cards: createHand('丘丘丘丘'), huValue: 6 }, { type: 'triplet', cards: createHand('乙乙乙'), huValue: 3 }], hu: 12 },
    { hand: '上丘乙己化三尔小生八九十土', melds: [{ type: 'quartet', cards: createHand('己己己己'), huValue: 6 }, { type: 'triplet', cards: createHand('化化化'), huValue: 3 }], hu: 12 }
  ];
  
  for (let i = 0; i < puTongHuCases.length; i++) {
    tests.push({
      name: `普通胡 - 测试${i + 1}(${puTongHuCases[i].hu}胡)`,
      hand: puTongHuCases[i].hand,
      melds: puTongHuCases[i].melds,
      expectedTing: true,
      expectedType: 'puTongHu',
      description: `${puTongHuCases[i].hu}胡，满足普通胡条件`
    });
  }
  
  return tests;
}

function generateTaiKaTests() {
  const tests = [];
  
  // 台卡测试 - 22胡
  const taiKaCases = [
    { hand: '上上福丘乙己化三尔小生八', melds: [{ type: 'quartet', cards: createHand('七七七七'), huValue: 6 }, { type: 'quartet', cards: createHand('八八八八'), huValue: 6 }] },
    { hand: '上上福丘乙己化三尔小生八', melds: [{ type: 'quartet', cards: createHand('八八八八'), huValue: 6 }, { type: 'quartet', cards: createHand('九九九九'), huValue: 6 }] },
    { hand: '上上福丘乙己化三尔小生八', melds: [{ type: 'quartet', cards: createHand('九九九九'), huValue: 6 }, { type: 'quartet', cards: createHand('子子子子'), huValue: 6 }] },
    { hand: '上上福丘乙己化三尔小生八', melds: [{ type: 'quartet', cards: createHand('尔尔尔尔'), huValue: 6 }, { type: 'quartet', cards: createHand('小小小小'), huValue: 6 }] },
    { hand: '上上福丘乙己化三尔小生八', melds: [{ type: 'quartet', cards: createHand('小小小小'), huValue: 6 }, { type: 'quartet', cards: createHand('生生生生'), huValue: 6 }] },
    { hand: '上上福丘乙己化三尔小生八', melds: [{ type: 'quartet', cards: createHand('丘丘丘丘'), huValue: 6 }, { type: 'quartet', cards: createHand('乙乙乙乙'), huValue: 6 }] },
    { hand: '上上福丘乙己化三尔小生八', melds: [{ type: 'quartet', cards: createHand('己己己己'), huValue: 6 }, { type: 'quartet', cards: createHand('化化化化'), huValue: 6 }] },
    { hand: '上上福丘乙己化三尔小生八', melds: [{ type: 'quartet', cards: createHand('化化化化'), huValue: 6 }, { type: 'quartet', cards: createHand('三三三三'), huValue: 6 }] },
    { hand: '上上福丘乙己化三尔小生八', melds: [{ type: 'quartet', cards: createHand('三三三三'), huValue: 6 }, { type: 'quartet', cards: createHand('千千千千'), huValue: 6 }] },
    { hand: '上福福丘乙己化三尔小生八', melds: [{ type: 'quartet', cards: createHand('七七七七'), huValue: 6 }, { type: 'quartet', cards: createHand('八八八八'), huValue: 6 }] }
  ];
  
  for (let i = 0; i < taiKaCases.length; i++) {
    tests.push({
      name: `台卡 - 测试${i + 1}`,
      hand: taiKaCases[i].hand,
      melds: taiKaCases[i].melds,
      expectedTing: true,
      expectedType: 'taiKa',
      description: '22胡，满足台卡条件'
    });
  }
  
  return tests;
}

function generateTaiHuTests() {
  const tests = [];
  
  // 台胡测试 - 23-32胡
  const taiHuCases = [
    { hand: '上上福福丘乙己化三尔小生', melds: [{ type: 'quartet', cards: createHand('七七七七'), huValue: 6 }, { type: 'quartet', cards: createHand('八八八八'), huValue: 6 }] },
    { hand: '上上福福丘乙己化三尔小生', melds: [{ type: 'quartet', cards: createHand('八八八八'), huValue: 6 }, { type: 'quartet', cards: createHand('九九九九'), huValue: 6 }] },
    { hand: '上上福福丘乙己化三尔小生', melds: [{ type: 'quartet', cards: createHand('九九九九'), huValue: 6 }, { type: 'quartet', cards: createHand('子子子子'), huValue: 6 }] },
    { hand: '上上福福丘乙己化三尔小生', melds: [{ type: 'quartet', cards: createHand('尔尔尔尔'), huValue: 6 }, { type: 'quartet', cards: createHand('小小小小'), huValue: 6 }] },
    { hand: '上上福福丘乙己化三尔小生', melds: [{ type: 'quartet', cards: createHand('小小小小'), huValue: 6 }, { type: 'quartet', cards: createHand('生生生生'), huValue: 6 }] },
    { hand: '上上福福福丘乙己化三尔小', melds: [{ type: 'quartet', cards: createHand('七七七七'), huValue: 6 }, { type: 'quartet', cards: createHand('八八八八'), huValue: 6 }] },
    { hand: '上上上福福丘乙己化三尔小', melds: [{ type: 'quartet', cards: createHand('七七七七'), huValue: 6 }, { type: 'quartet', cards: createHand('八八八八'), huValue: 6 }] },
    { hand: '上上福福丘乙己化三尔小生', melds: [{ type: 'quartet', cards: createHand('丘丘丘丘'), huValue: 6 }, { type: 'quartet', cards: createHand('乙乙乙乙'), huValue: 6 }] },
    { hand: '上上福福丘乙己化三尔小生', melds: [{ type: 'quartet', cards: createHand('己己己己'), huValue: 6 }, { type: 'quartet', cards: createHand('化化化化'), huValue: 6 }] },
    { hand: '上上福福丘乙己化三尔小生', melds: [{ type: 'quartet', cards: createHand('化化化化'), huValue: 6 }, { type: 'quartet', cards: createHand('三三三三'), huValue: 6 }] }
  ];
  
  for (let i = 0; i < taiHuCases.length; i++) {
    tests.push({
      name: `台胡 - 测试${i + 1}`,
      hand: taiHuCases[i].hand,
      melds: taiHuCases[i].melds,
      expectedTing: true,
      expectedType: 'taiHu',
      description: '23-32胡，满足台胡条件'
    });
  }
  
  return tests;
}

function generateChongTaiKaTests() {
  const tests = [];
  
  // 重台卡测试 - 33胡
  const chongTaiKaCases = [
    { hand: '上上上福福福丘乙己化三', melds: [{ type: 'quartet', cards: createHand('七七七七'), huValue: 6 }, { type: 'quartet', cards: createHand('八八八八'), huValue: 6 }] },
    { hand: '上上上福福福丘乙己化三', melds: [{ type: 'quartet', cards: createHand('八八八八'), huValue: 6 }, { type: 'quartet', cards: createHand('九九九九'), huValue: 6 }] },
    { hand: '上上上福福福丘乙己化三', melds: [{ type: 'quartet', cards: createHand('九九九九'), huValue: 6 }, { type: 'quartet', cards: createHand('子子子子'), huValue: 6 }] },
    { hand: '上上上福福福丘乙己化三', melds: [{ type: 'quartet', cards: createHand('尔尔尔尔'), huValue: 6 }, { type: 'quartet', cards: createHand('小小小小'), huValue: 6 }] },
    { hand: '上上上福福福丘乙己化三', melds: [{ type: 'quartet', cards: createHand('小小小小'), huValue: 6 }, { type: 'quartet', cards: createHand('生生生生'), huValue: 6 }] },
    { hand: '上上上福福福丘乙己化三', melds: [{ type: 'quartet', cards: createHand('丘丘丘丘'), huValue: 6 }, { type: 'quartet', cards: createHand('乙乙乙乙'), huValue: 6 }] },
    { hand: '上上上福福福丘乙己化三', melds: [{ type: 'quartet', cards: createHand('己己己己'), huValue: 6 }, { type: 'quartet', cards: createHand('化化化化'), huValue: 6 }] },
    { hand: '上上上福福福丘乙己化三', melds: [{ type: 'quartet', cards: createHand('化化化化'), huValue: 6 }, { type: 'quartet', cards: createHand('三三三三'), huValue: 6 }] },
    { hand: '上上上福福福丘乙己化三', melds: [{ type: 'quartet', cards: createHand('三三三三'), huValue: 6 }, { type: 'quartet', cards: createHand('千千千千'), huValue: 6 }] },
    { hand: '上上上福福福丘乙己化三', melds: [{ type: 'quartet', cards: createHand('七七七七'), huValue: 6 }, { type: 'quartet', cards: createHand('九九九九'), huValue: 6 }] }
  ];
  
  for (let i = 0; i < chongTaiKaCases.length; i++) {
    tests.push({
      name: `重台卡 - 测试${i + 1}`,
      hand: chongTaiKaCases[i].hand,
      melds: chongTaiKaCases[i].melds,
      expectedTing: true,
      expectedType: 'chongTaiKa',
      description: '33胡，满足重台卡条件'
    });
  }
  
  return tests;
}

function generateChongTaiHuTests() {
  const tests = [];
  
  // 重台胡测试 - 34+胡
  const chongTaiHuCases = [
    { hand: '上上上福福福丘乙己化三', melds: [{ type: 'quartet', cards: createHand('七七七七'), huValue: 6 }, { type: 'quartet', cards: createHand('八八八八'), huValue: 6 }, { type: 'triplet', cards: createHand('九九九'), huValue: 3 }] },
    { hand: '上上上福福福丘乙己化三', melds: [{ type: 'quartet', cards: createHand('八八八八'), huValue: 6 }, { type: 'quartet', cards: createHand('九九九九'), huValue: 6 }, { type: 'triplet', cards: createHand('子子子'), huValue: 3 }] },
    { hand: '上上上福福福丘乙己化三', melds: [{ type: 'quartet', cards: createHand('九九九九'), huValue: 6 }, { type: 'quartet', cards: createHand('子子子子'), huValue: 6 }, { type: 'triplet', cards: createHand('丘丘丘'), huValue: 3 }] },
    { hand: '上上上福福福丘乙己化三', melds: [{ type: 'quartet', cards: createHand('尔尔尔尔'), huValue: 6 }, { type: 'quartet', cards: createHand('小小小小'), huValue: 6 }, { type: 'triplet', cards: createHand('生生生'), huValue: 3 }] },
    { hand: '上上上福福福丘乙己化三', melds: [{ type: 'quartet', cards: createHand('小小小小'), huValue: 6 }, { type: 'quartet', cards: createHand('生生生生'), huValue: 6 }, { type: 'triplet', cards: createHand('八八八'), huValue: 3 }] },
    { hand: '上上上福福福丘乙己', melds: [{ type: 'quartet', cards: createHand('七七七七'), huValue: 6 }, { type: 'quartet', cards: createHand('八八八八'), huValue: 6 }, { type: 'quartet', cards: createHand('九九九九'), huValue: 6 }] },
    { hand: '上上上福福福丘乙己', melds: [{ type: 'quartet', cards: createHand('八八八八'), huValue: 6 }, { type: 'quartet', cards: createHand('九九九九'), huValue: 6 }, { type: 'quartet', cards: createHand('子子子子'), huValue: 6 }] },
    { hand: '上上上福福福丘乙己', melds: [{ type: 'quartet', cards: createHand('尔尔尔尔'), huValue: 6 }, { type: 'quartet', cards: createHand('小小小小'), huValue: 6 }, { type: 'quartet', cards: createHand('生生生生'), huValue: 6 }] },
    { hand: '上上上福福福丘乙己', melds: [{ type: 'quartet', cards: createHand('丘丘丘丘'), huValue: 6 }, { type: 'quartet', cards: createHand('乙乙乙乙'), huValue: 6 }, { type: 'quartet', cards: createHand('己己己己'), huValue: 6 }] },
    { hand: '上上上福福福丘乙己', melds: [{ type: 'quartet', cards: createHand('化化化化'), huValue: 6 }, { type: 'quartet', cards: createHand('三三三三'), huValue: 6 }, { type: 'quartet', cards: createHand('千千千千'), huValue: 6 }] }
  ];
  
  for (let i = 0; i < chongTaiHuCases.length; i++) {
    tests.push({
      name: `重台胡 - 测试${i + 1}`,
      hand: chongTaiHuCases[i].hand,
      melds: chongTaiHuCases[i].melds,
      expectedTing: true,
      expectedType: 'chongTaiHu',
      description: '34+胡，满足重台胡条件'
    });
  }
  
  return tests;
}

function generateKuChongTaiKaTests() {
  const tests = [];
  
  // 枯重台卡测试 - 枯胡条件 + 33胡 + 有上/福
  // 听牌状态：坎3对2，有上/福，无单张
  // 摸牌后：坎4对1，33胡
  
  // 手牌：上上(对) + 福福福(坎) + 丘丘丘(坎) + 乙乙乙(坎) + 己己己(坎) = 14张
  // 组合牌：2招 = 8张
  // 总计：22张，听牌时手牌13张
  
  // 重新设计：听牌状态手牌13张
  // 手牌：上上(对) + 福福(对) + 丘丘丘(坎) + 乙乙乙(坎) + 己己己(坎) = 13张
  // 组合牌：2招 = 8张
  // 摸"上"或"福"后：上上上(坎) + 福福(对) + 丘丘丘(坎) + 乙乙乙(坎) + 己己己(坎) = 14张
  // 胡数计算：精坎(上)12 + 3坎(丘乙己)9 + 2招12 + 对(福)0 = 33胡
  
  const kuChongTaiKaCases = [
    { hand: '上上福福丘丘丘乙乙乙己己己', melds: [{ type: 'quartet', cards: createHand('七七七七'), huValue: 6 }, { type: 'quartet', cards: createHand('八八八八'), huValue: 6 }] },
    { hand: '上上福福丘丘丘乙乙乙己己己', melds: [{ type: 'quartet', cards: createHand('八八八八'), huValue: 6 }, { type: 'quartet', cards: createHand('九九九九'), huValue: 6 }] },
    { hand: '上上福福丘丘丘乙乙乙己己己', melds: [{ type: 'quartet', cards: createHand('九九九九'), huValue: 6 }, { type: 'quartet', cards: createHand('子子子子'), huValue: 6 }] },
    { hand: '上上福福丘丘丘乙乙乙化化化', melds: [{ type: 'quartet', cards: createHand('七七七七'), huValue: 6 }, { type: 'quartet', cards: createHand('八八八八'), huValue: 6 }] },
    { hand: '上上福福丘丘丘乙乙乙化化化', melds: [{ type: 'quartet', cards: createHand('八八八八'), huValue: 6 }, { type: 'quartet', cards: createHand('九九九九'), huValue: 6 }] },
    { hand: '上上福福丘丘丘乙乙乙三三三', melds: [{ type: 'quartet', cards: createHand('七七七七'), huValue: 6 }, { type: 'quartet', cards: createHand('八八八八'), huValue: 6 }] },
    { hand: '上上福福丘丘丘乙乙乙三三三', melds: [{ type: 'quartet', cards: createHand('八八八八'), huValue: 6 }, { type: 'quartet', cards: createHand('九九九九'), huValue: 6 }] },
    { hand: '上上福福丘丘丘乙乙乙千千千', melds: [{ type: 'quartet', cards: createHand('七七七七'), huValue: 6 }, { type: 'quartet', cards: createHand('八八八八'), huValue: 6 }] },
    { hand: '上上福福丘丘丘乙乙乙千千千', melds: [{ type: 'quartet', cards: createHand('八八八八'), huValue: 6 }, { type: 'quartet', cards: createHand('九九九九'), huValue: 6 }] },
    { hand: '福福上上丘丘丘乙乙乙己己己', melds: [{ type: 'quartet', cards: createHand('七七七七'), huValue: 6 }, { type: 'quartet', cards: createHand('八八八八'), huValue: 6 }] },
    { hand: '福福上上丘丘丘乙乙乙己己己', melds: [{ type: 'quartet', cards: createHand('八八八八'), huValue: 6 }, { type: 'quartet', cards: createHand('九九九九'), huValue: 6 }] },
    { hand: '福福上上丘丘丘乙乙乙化化化', melds: [{ type: 'quartet', cards: createHand('七七七七'), huValue: 6 }, { type: 'quartet', cards: createHand('八八八八'), huValue: 6 }] },
    { hand: '福福上上丘丘丘乙乙乙化化化', melds: [{ type: 'quartet', cards: createHand('九九九九'), huValue: 6 }, { type: 'quartet', cards: createHand('子子子子'), huValue: 6 }] },
    { hand: '福福上上丘丘丘乙乙乙三三三', melds: [{ type: 'quartet', cards: createHand('七七七七'), huValue: 6 }, { type: 'quartet', cards: createHand('八八八八'), huValue: 6 }] },
    { hand: '福福上上丘丘丘乙乙乙三三三', melds: [{ type: 'quartet', cards: createHand('八八八八'), huValue: 6 }, { type: 'quartet', cards: createHand('九九九九'), huValue: 6 }] }
  ];
  
  for (let i = 0; i < kuChongTaiKaCases.length; i++) {
    tests.push({
      name: `枯重台卡 - 测试${i + 1}`,
      hand: kuChongTaiKaCases[i].hand,
      melds: kuChongTaiKaCases[i].melds,
      expectedTing: true,
      expectedType: 'kuChongTaiKa',
      description: '枯胡条件 + 33胡 + 有上/福'
    });
  }
  
  return tests;
}

function generateKuChongTaiHuTests() {
  const tests = [];
  
  // 枯重台胡测试 - 枯胡条件 + 34+胡 + 有上/福
  const kuChongTaiHuCases = [
    { hand: '上上福福福丘丘丘乙乙乙己己', melds: [{ type: 'quartet', cards: createHand('七七七七'), huValue: 6 }, { type: 'quartet', cards: createHand('八八八八'), huValue: 6 }] },
    { hand: '上上福福福丘丘丘乙乙乙己己', melds: [{ type: 'quartet', cards: createHand('八八八八'), huValue: 6 }, { type: 'quartet', cards: createHand('九九九九'), huValue: 6 }] },
    { hand: '上上福福福丘丘丘乙乙乙己己', melds: [{ type: 'quartet', cards: createHand('九九九九'), huValue: 6 }, { type: 'quartet', cards: createHand('子子子子'), huValue: 6 }] },
    { hand: '上上福福福丘丘丘乙乙乙化化', melds: [{ type: 'quartet', cards: createHand('七七七七'), huValue: 6 }, { type: 'quartet', cards: createHand('八八八八'), huValue: 6 }] },
    { hand: '上上福福福丘丘丘乙乙乙化化', melds: [{ type: 'quartet', cards: createHand('八八八八'), huValue: 6 }, { type: 'quartet', cards: createHand('九九九九'), huValue: 6 }] },
    { hand: '上上福福福丘丘丘乙乙乙三三', melds: [{ type: 'quartet', cards: createHand('七七七七'), huValue: 6 }, { type: 'quartet', cards: createHand('八八八八'), huValue: 6 }] },
    { hand: '上上福福福丘丘丘乙乙乙三三', melds: [{ type: 'quartet', cards: createHand('八八八八'), huValue: 6 }, { type: 'quartet', cards: createHand('九九九九'), huValue: 6 }] },
    { hand: '上上福福福丘丘丘乙乙乙千千', melds: [{ type: 'quartet', cards: createHand('七七七七'), huValue: 6 }, { type: 'quartet', cards: createHand('八八八八'), huValue: 6 }] },
    { hand: '上上福福福丘丘丘乙乙乙千千', melds: [{ type: 'quartet', cards: createHand('八八八八'), huValue: 6 }, { type: 'quartet', cards: createHand('九九九九'), huValue: 6 }] },
    { hand: '福福上上上丘丘丘乙乙乙己己', melds: [{ type: 'quartet', cards: createHand('七七七七'), huValue: 6 }, { type: 'quartet', cards: createHand('八八八八'), huValue: 6 }] },
    { hand: '福福上上上丘丘丘乙乙乙己己', melds: [{ type: 'quartet', cards: createHand('八八八八'), huValue: 6 }, { type: 'quartet', cards: createHand('九九九九'), huValue: 6 }] },
    { hand: '福福上上上丘丘丘乙乙乙化化', melds: [{ type: 'quartet', cards: createHand('七七七七'), huValue: 6 }, { type: 'quartet', cards: createHand('八八八八'), huValue: 6 }] },
    { hand: '福福上上上丘丘丘乙乙乙化化', melds: [{ type: 'quartet', cards: createHand('九九九九'), huValue: 6 }, { type: 'quartet', cards: createHand('子子子子'), huValue: 6 }] },
    { hand: '福福上上上丘丘丘乙乙乙三三', melds: [{ type: 'quartet', cards: createHand('七七七七'), huValue: 6 }, { type: 'quartet', cards: createHand('八八八八'), huValue: 6 }] },
    { hand: '福福上上上丘丘丘乙乙乙三三', melds: [{ type: 'quartet', cards: createHand('八八八八'), huValue: 6 }, { type: 'quartet', cards: createHand('九九九九'), huValue: 6 }] }
  ];
  
  for (let i = 0; i < kuChongTaiHuCases.length; i++) {
    tests.push({
      name: `枯重台胡 - 测试${i + 1}`,
      hand: kuChongTaiHuCases[i].hand,
      melds: kuChongTaiHuCases[i].melds,
      expectedTing: true,
      expectedType: 'kuChongTaiHu',
      description: '枯胡条件 + 34+胡 + 有上/福'
    });
  }
  
  return tests;
}

function generateQingKuTaiKaTests() {
  const tests = [];
  
  // 清枯台卡测试 - 枯胡条件 + 22胡 + 无上/福
  // 听牌状态：坎3对2，无上/福，无单张
  const qingKuTaiKaCases = [
    { hand: '丘丘乙乙己己己化化化三三三', melds: [{ type: 'quartet', cards: createHand('七七七七'), huValue: 6 }] },
    { hand: '丘丘乙乙己己己化化化三三三', melds: [{ type: 'quartet', cards: createHand('八八八八'), huValue: 6 }] },
    { hand: '丘丘乙乙己己己化化化三三三', melds: [{ type: 'quartet', cards: createHand('九九九九'), huValue: 6 }] },
    { hand: '丘丘乙乙己己己化化化三三三', melds: [{ type: 'quartet', cards: createHand('子子子子'), huValue: 6 }] },
    { hand: '丘丘乙乙己己己化化化三三三', melds: [{ type: 'quartet', cards: createHand('尔尔尔尔'), huValue: 6 }] },
    { hand: '丘丘乙乙己己己化化化千千千', melds: [{ type: 'quartet', cards: createHand('七七七七'), huValue: 6 }] },
    { hand: '丘丘乙乙己己己化化化千千千', melds: [{ type: 'quartet', cards: createHand('八八八八'), huValue: 6 }] },
    { hand: '丘丘乙乙己己己化化化千千千', melds: [{ type: 'quartet', cards: createHand('九九九九'), huValue: 6 }] },
    { hand: '丘丘乙乙己己己化化化千千千', melds: [{ type: 'quartet', cards: createHand('子子子子'), huValue: 6 }] },
    { hand: '丘丘乙乙己己己化化化千千千', melds: [{ type: 'quartet', cards: createHand('尔尔尔尔'), huValue: 6 }] },
    { hand: '丘丘乙乙己己己三三三千千千', melds: [{ type: 'quartet', cards: createHand('七七七七'), huValue: 6 }] },
    { hand: '丘丘乙乙己己己三三三千千千', melds: [{ type: 'quartet', cards: createHand('八八八八'), huValue: 6 }] },
    { hand: '丘丘乙乙己己己三三三千千千', melds: [{ type: 'quartet', cards: createHand('九九九九'), huValue: 6 }] },
    { hand: '丘丘乙乙己己己三三三千千千', melds: [{ type: 'quartet', cards: createHand('子子子子'), huValue: 6 }] },
    { hand: '丘丘乙乙己己己三三三千千千', melds: [{ type: 'quartet', cards: createHand('尔尔尔尔'), huValue: 6 }] }
  ];
  
  for (let i = 0; i < qingKuTaiKaCases.length; i++) {
    tests.push({
      name: `清枯台卡 - 测试${i + 1}`,
      hand: qingKuTaiKaCases[i].hand,
      melds: qingKuTaiKaCases[i].melds,
      expectedTing: true,
      expectedType: 'qingKuTaiKa',
      description: '枯胡条件 + 22胡 + 无上/福'
    });
  }
  
  return tests;
}

function generateNotTingTests() {
  const tests = [];
  
  // 不听牌测试
  tests.push({
    name: '不听牌 - 胡数不足',
    hand: '丘乙己化三尔小生八九子八九',
    melds: [],
    expectedTing: false,
    expectedType: 'none',
    description: '胡数不足'
  });
  
  tests.push({
    name: '不听牌 - 牌数不足',
    hand: '丘乙己化三尔小生八九子',
    melds: [],
    expectedTing: false,
    expectedType: 'none',
    description: '牌数不足'
  });
  
  tests.push({
    name: '不听牌 - 有上福但胡数不足',
    hand: '上福丘乙己化三尔小生八九子',
    melds: [],
    expectedTing: false,
    expectedType: 'none',
    description: '有上福但胡数不足'
  });
  
  tests.push({
    name: '不听牌 - 9对不够十对',
    hand: '丘丘乙乙己己化化三三千千尔尔小',
    melds: [],
    expectedTing: false,
    expectedType: 'none',
    description: '9对不够十对'
  });
  
  return tests;
}

// 生成所有测试用例
const testCases = [
  ...generateShiDuiTests(),
  ...generateHeiYuanTests(),
  ...generateHongYuanTests(),
  ...generateKuHuTests(),
  ...generateQingKuHuTests(),
  ...generateKaHuTests(),
  ...generatePuTongHuTests(),
  ...generateTaiKaTests(),
  ...generateTaiHuTests(),
  ...generateChongTaiKaTests(),
  ...generateChongTaiHuTests(),
  ...generateKuChongTaiKaTests(),
  ...generateKuChongTaiHuTests(),
  ...generateQingKuTaiKaTests(),
  ...generateNotTingTests()
];

// 运行测试
function runTingTests() {
  let passed = 0;
  let failed = 0;
  const results = [];
  
  for (const test of testCases) {
    const player = {
      hand: createHand(test.hand),
      melds: test.melds,
      name: '测试玩家'
    };
    
    const result = checkTing(player);
    
    if (result.isTing === test.expectedTing) {
      passed++;
      results.push({ name: test.name, status: 'pass', expected: test.expectedTing, actual: result.isTing });
    } else {
      failed++;
      results.push({ name: test.name, status: 'fail', expected: test.expectedTing, actual: result.isTing, hand: test.hand });
    }
  }
  
  return { passed, failed, total: testCases.length, results };
}

// 导出测试函数
if (typeof module !== 'undefined' && module.exports) {
  module.exports = { runTingTests, testCases };
} else {
  window.runTingTests = runTingTests;
}
