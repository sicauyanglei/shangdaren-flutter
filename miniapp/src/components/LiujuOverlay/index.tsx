import React, { useMemo } from 'react';
import { View, Text } from '@tarojs/components';
import { Player } from '../../types/player';
import { Card, CardChar, getCardGroup } from '../../types/card';
import styles from './index.module.scss';

interface LiujuOverlayProps {
  players: Player[];
  onClose: () => void;
}

// 精字判断（上/福）
const isJingChar = (char: CardChar): boolean => char === '上' || char === '福';

// 判断卡牌是否使用红色样式（精字 或 组1/组8）
const isRedCard = (card: Card): boolean => {
  if (isJingChar(card.char)) return true;
  const group = getCardGroup(card.char);
  return group === 0 || group === 7;
};

// 按组号和位置排序手牌
const sortCards = (cards: Card[]): Card[] => {
  return [...cards].sort((a, b) => {
    const ga = getCardGroup(a.char);
    const gb = getCardGroup(b.char);
    if (ga !== gb) return ga - gb;
    // 同组内按位置排序（组内索引）
    const groupChars = ['上', '大', '人', '丘', '乙', '己', '化', '三', '千', '七', '十', '土', '尔', '小', '生', '八', '九', '子', '佳', '作', '亡', '福', '禄', '寿'];
    return groupChars.indexOf(a.char) - groupChars.indexOf(b.char);
  });
};

// 渲染小卡牌
const SmallCard: React.FC<{ card: Card }> = ({ card }) => {
  const red = isRedCard(card);
  return (
    <View className={`${styles.smallCard} ${red ? styles.smallCardRed : styles.smallCardGreen}`}>
      <Text className={styles.smallCardText}>{card.char}</Text>
    </View>
  );
};

const LiujuOverlay: React.FC<LiujuOverlayProps> = ({ players, onClose }) => {
  // 排序后的手牌和组合牌
  const playerData = useMemo(() => {
    return players.map(player => ({
      player,
      sortedHand: sortCards(player.hand),
      sortedMeldCards: player.melds.flatMap(meld => sortCards(meld.cards)),
    }));
  }, [players]);

  return (
    <>
      {/* 背景遮罩 */}
      <View className={styles.backdrop} onClick={onClose} />

      {/* 主面板 */}
      <View className={styles.overlay}>
        <View className={styles.panel} onClick={e => e.stopPropagation()}>
          {/* 标题区域 */}
          <View className={styles.titleArea}>
            <Text className={styles.title}>流局</Text>
            <View className={styles.closeBtn} onClick={onClose}>
              <Text className={styles.closeIcon}>✕</Text>
            </View>
          </View>

          {/* 副标题 */}
          <Text className={styles.subtitle}>牌堆已空，本局结束</Text>

          {/* 备注 */}
          <Text className={styles.note}>庄家不变，继续坐庄</Text>

          {/* 玩家手牌展示 */}
          <View className={styles.playersContainer}>
            {playerData.map(({ player, sortedHand, sortedMeldCards }) => (
              <View className={styles.playerRow} key={player.id}>
                <Text className={styles.playerName}>{player.name}</Text>
                <View className={styles.cardsRow}>
                  {/* 手牌 */}
                  <View className={styles.handCards}>
                    {sortedHand.map(card => (
                      <SmallCard key={card.id} card={card} />
                    ))}
                  </View>

                  {/* 组合牌 */}
                  {sortedMeldCards.length > 0 && (
                    <View className={styles.meldSection}>
                      {sortedMeldCards.map(card => (
                        <SmallCard key={card.id} card={card} />
                      ))}
                    </View>
                  )}
                </View>
              </View>
            ))}
          </View>

          {/* 确定按钮 */}
          <View className={styles.confirmBtn} onClick={onClose}>
            <Text>确定</Text>
          </View>
        </View>
      </View>
    </>
  );
};

export default LiujuOverlay;
