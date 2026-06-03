import React from 'react';
import { View, Text, Image } from '@tarojs/components';
import { Card, RED_CHARS, GREEN_CHARS } from '../../types/card';
import styles from './index.module.scss';

interface CardTileProps {
  card: Card;
  size?: 'sm' | 'md' | 'lg';
  selected?: boolean;
  showLabel?: string;
  onClick?: () => void;
}

// 获取卡片图片URL
function getCardImageUrl(char: string, size: 'sm' | 'md' | 'lg'): string {
  const charMap: Record<string, string> = {
    '上': 'shang', '大': 'da', '人': 'ren', '丘': 'qiu', '乙': 'yi', '己': 'ji',
    '化': 'hua', '三': 'san', '千': 'qian', '七': 'qi', '十': 'shi', '土': 'tu',
    '尔': 'er', '小': 'xiao', '生': 'sheng', '八': 'ba', '九': 'jiu', '子': 'zi',
    '佳': 'jia', '作': 'zuo', '亡': 'wang', '福': 'fu', '禄': 'lu', '寿': 'shou',
  };
  const suffix = charMap[char] || char;
  const folder = size === 'sm' ? 's' : 'v';
  return `../../assets/images/${folder}/${suffix}.png`;
}

const CardTile: React.FC<CardTileProps> = ({ card, size = 'md', selected = false, showLabel, onClick }) => {
  const colorClass = RED_CHARS.includes(card.char) ? styles.red
    : GREEN_CHARS.includes(card.char) ? styles.green
    : styles.black;

  const sizeClass = size === 'sm' ? styles.sm : size === 'lg' ? styles.lg : styles.md;

  return (
    <View
      className={`${styles.cardTile} ${colorClass} ${sizeClass} ${selected ? styles.selected : ''}`}
      onClick={onClick}
    >
      <Image
        className={styles.cardImage}
        src={getCardImageUrl(card.char, size)}
        mode='aspectFit'
        fadeIn
      />
      {showLabel && (
        <Text className={styles.label}>{showLabel}</Text>
      )}
    </View>
  );
};

export default CardTile;
