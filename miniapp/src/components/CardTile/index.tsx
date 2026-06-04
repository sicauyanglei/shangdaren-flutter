import React from 'react';
import { View, Text, Image } from '@tarojs/components';
import { Card } from '../../types/card';
import styles from './index.module.scss';

// 字符到拼音的映射
const CHAR_PINYIN_MAP: Record<string, string> = {
  '上': 'shang', '大': 'da', '人': 'ren', '丘': 'qiu', '乙': 'yi', '己': 'ji',
  '化': 'hua', '三': 'san', '千': 'qian', '七': 'qi', '十': 'shi', '土': 'tu',
  '尔': 'er', '小': 'xiao', '生': 'sheng', '八': 'ba', '九': 'jiu', '子': 'zi',
  '佳': 'jia', '作': 'zuo', '亡': 'wang', '福': 'fu', '禄': 'lu', '寿': 'shou',
};

export type CardTileSize = 'hand' | 'small' | 'meld' | 'horizontal' | 'back';

interface CardTileProps {
  card: Card;
  size?: CardTileSize;
  selected?: boolean;
  showLabel?: string;
  onClick?: () => void;
  stackCount?: number;
  isLastDiscard?: boolean;
}

// 根据尺寸获取卡牌图片路径
function getCardImageUrl(char: string, size: CardTileSize): string {
  const pinyin = CHAR_PINYIN_MAP[char] || char;
  switch (size) {
    case 'hand':
      return `../../assets/images/${pinyin}.png`;
    case 'small':
    case 'meld':
      return `../../assets/images/s/${pinyin}.png`;
    case 'horizontal':
      return `../../assets/images/v/${pinyin}.png`;
    case 'back':
      return `../../assets/images/back.png`;
    default:
      return `../../assets/images/s/${pinyin}.png`;
  }
}

const CardTile: React.FC<CardTileProps> = ({
  card,
  size = 'meld',
  selected = false,
  showLabel,
  onClick,
  stackCount,
  isLastDiscard = false,
}) => {
  const isBack = size === 'back';

  const sizeClass = styles[size] || styles.meld;

  return (
    <View
      className={[
        styles.cardTile,
        sizeClass,
        selected ? styles.selected : '',
        isLastDiscard ? styles.lastDiscard : '',
      ].filter(Boolean).join(' ')}
      onClick={onClick}
    >
      <Image
        className={styles.cardImage}
        src={isBack ? getCardImageUrl('', 'back') : getCardImageUrl(card.char, size)}
        mode='aspectFit'
      />
      {/* 叠放计数徽章 */}
      {stackCount != null && stackCount > 1 && (
        <View className={styles.countBadge}>
          <Text className={styles.countText}>{stackCount}</Text>
        </View>
      )}
      {/* 炮/自摸 标签 */}
      {showLabel && (
        <Text className={styles.label}>{showLabel}</Text>
      )}
    </View>
  );
};

export default CardTile;
