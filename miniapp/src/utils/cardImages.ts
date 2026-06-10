// ============================================
// 卡牌图片映射工具
// 使用 require() 引入图片，Taro 编译器在构建时解析路径
// 禁止运行时动态拼接路径
// ============================================

// 拼音映射
const CHAR_TO_PINYIN: Record<string, string> = {
  '上': 'shang', '大': 'da', '人': 'ren', '丘': 'qiu', '乙': 'yi',
  '己': 'ji', '化': 'hua', '三': 'san', '千': 'qian', '七': 'qi',
  '十': 'shi', '土': 'tu', '尔': 'er', '小': 'xiao', '生': 'sheng',
  '八': 'ba', '九': 'jiu', '子': 'zi', '佳': 'jia', '作': 'zuo',
  '亡': 'wang', '福': 'fu', '禄': 'lu', '寿': 'shou',
};

// ============================================
// 竖版卡牌 (cards/) - 人类手牌 / AI胡牌手牌
// 尺寸 145×610 (窄高)
// ============================================
const VERTICAL_CARDS: Record<string, string> = {
  'shang': require('@/assets/cards/shang.png'),
  'da': require('@/assets/cards/da.png'),
  'ren': require('@/assets/cards/ren.png'),
  'qiu': require('@/assets/cards/qiu.png'),
  'yi': require('@/assets/cards/yi.png'),
  'ji': require('@/assets/cards/ji.png'),
  'hua': require('@/assets/cards/hua.png'),
  'san': require('@/assets/cards/san.png'),
  'qian': require('@/assets/cards/qian.png'),
  'qi': require('@/assets/cards/qi.png'),
  'shi': require('@/assets/cards/shi.png'),
  'tu': require('@/assets/cards/tu.png'),
  'er': require('@/assets/cards/er.png'),
  'xiao': require('@/assets/cards/xiao.png'),
  'sheng': require('@/assets/cards/sheng.png'),
  'ba': require('@/assets/cards/ba.png'),
  'jiu': require('@/assets/cards/jiu.png'),
  'zi': require('@/assets/cards/zi.png'),
  'jia': require('@/assets/cards/jia.png'),
  'zuo': require('@/assets/cards/zuo.png'),
  'wang': require('@/assets/cards/wang.png'),
  'fu': require('@/assets/cards/fu.png'),
  'lu': require('@/assets/cards/lu.png'),
  'shou': require('@/assets/cards/shou.png'),
};

// ============================================
// 横版卡牌 (cards/v/) - 中央出牌区
// 尺寸 610×145 (宽矮)
// ============================================
const HORIZONTAL_CARDS: Record<string, string> = {
  'shang': require('@/assets/cards/v/shang.png'),
  'da': require('@/assets/cards/v/da.png'),
  'ren': require('@/assets/cards/v/ren.png'),
  'qiu': require('@/assets/cards/v/qiu.png'),
  'yi': require('@/assets/cards/v/yi.png'),
  'ji': require('@/assets/cards/v/ji.png'),
  'hua': require('@/assets/cards/v/hua.png'),
  'san': require('@/assets/cards/v/san.png'),
  'qian': require('@/assets/cards/v/qian.png'),
  'qi': require('@/assets/cards/v/qi.png'),
  'shi': require('@/assets/cards/v/shi.png'),
  'tu': require('@/assets/cards/v/tu.png'),
  'er': require('@/assets/cards/v/er.png'),
  'xiao': require('@/assets/cards/v/xiao.png'),
  'sheng': require('@/assets/cards/v/sheng.png'),
  'ba': require('@/assets/cards/v/ba.png'),
  'jiu': require('@/assets/cards/v/jiu.png'),
  'zi': require('@/assets/cards/v/zi.png'),
  'jia': require('@/assets/cards/v/jia.png'),
  'zuo': require('@/assets/cards/v/zuo.png'),
  'wang': require('@/assets/cards/v/wang.png'),
  'fu': require('@/assets/cards/v/fu.png'),
  'lu': require('@/assets/cards/v/lu.png'),
  'shou': require('@/assets/cards/v/shou.png'),
};

// ============================================
// 小版卡牌 (cards/s/) - 弃牌区 / 组合牌区
// ============================================
const SMALL_CARDS: Record<string, string> = {
  'shang': require('@/assets/cards/s/shang.png'),
  'da': require('@/assets/cards/s/da.png'),
  'ren': require('@/assets/cards/s/ren.png'),
  'qiu': require('@/assets/cards/s/qiu.png'),
  'yi': require('@/assets/cards/s/yi.png'),
  'ji': require('@/assets/cards/s/ji.png'),
  'hua': require('@/assets/cards/s/hua.png'),
  'san': require('@/assets/cards/s/san.png'),
  'qian': require('@/assets/cards/s/qian.png'),
  'qi': require('@/assets/cards/s/qi.png'),
  'shi': require('@/assets/cards/s/shi.png'),
  'tu': require('@/assets/cards/s/tu.png'),
  'er': require('@/assets/cards/s/er.png'),
  'xiao': require('@/assets/cards/s/xiao.png'),
  'sheng': require('@/assets/cards/s/sheng.png'),
  'ba': require('@/assets/cards/s/ba.png'),
  'jiu': require('@/assets/cards/s/jiu.png'),
  'zi': require('@/assets/cards/s/zi.png'),
  'jia': require('@/assets/cards/s/jia.png'),
  'zuo': require('@/assets/cards/s/zuo.png'),
  'wang': require('@/assets/cards/s/wang.png'),
  'fu': require('@/assets/cards/s/fu.png'),
  'lu': require('@/assets/cards/s/lu.png'),
  'shou': require('@/assets/cards/s/shou.png'),
};

// 牌背 / 组合牌框
const CARD_BACK = require('@/assets/cards/back.png');       // 横版牌背 (中央出牌区)
const CARD_BACK_V = require('@/assets/cards/v/back.png');   // 竖版牌背 (AI手牌)
const MELD_CARD = require('@/assets/cards/mcard.png');

// 卡牌图片类型
export type CardImageType = 'vertical' | 'horizontal' | 'small';

// 获取卡牌图片路径
export function getCardImagePath(char: string, type: CardImageType = 'vertical'): string {
  const pinyin = CHAR_TO_PINYIN[char];
  if (!pinyin) return '';

  switch (type) {
    case 'vertical':
      // 人类手牌 / AI胡牌手牌 - cards/ 目录 (竖版 145×610)
      return VERTICAL_CARDS[pinyin] || '';
    case 'horizontal':
      // 中央出牌区 - cards/v/ 目录 (横版 610×145)
      return HORIZONTAL_CARDS[pinyin] || '';
    case 'small':
      // 弃牌/组合牌 - cards/s/ 目录
      return SMALL_CARDS[pinyin] || '';
  }
}

// 牌背图片路径
export function getCardBackPath(type: 'vertical' | 'horizontal' = 'vertical'): string {
  return type === 'vertical' ? CARD_BACK_V : CARD_BACK;
}

// 组合牌框图片路径
export function getMeldCardPath(): string {
  return MELD_CARD;
}

// 获取拼音
export function getCharPinyin(char: string): string {
  return CHAR_TO_PINYIN[char] || '';
}
