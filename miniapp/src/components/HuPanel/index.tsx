import React, { useMemo } from 'react';
import { View, Text } from '@tarojs/components';
import type { Card } from '../../types/card';
import type { Meld } from '../../types/player';
import styles from './index.module.scss';

interface HuPanelProps {
  winnerName: string;
  method: string;
  huType: string;
  huCount: number;
  multiplier: number;
  scoreChanges: { name: string; change: number; label: string }[];
  winnerHand?: Card[];
  winnerMelds?: Meld[];
  huCard?: Card;
  loserHands?: { name: string; hand: Card[]; score: number }[];
  onClose: () => void;
}

// 胡牌类型对应颜色（匹配 Flame 版本 _getHuTypeColor）
const getHuTypeColor = (huTypeName: string): string => {
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
};

// 获取卡牌颜色样式（匹配Flame的card color逻辑）
const getCharColor = (char: string): string => {
  const redChars = ['上', '丘', '化', '七', '尔', '八', '佳', '福'];
  const greenChars = ['大', '乙', '三', '十', '小', '九', '作', '禄'];
  if (redChars.includes(char)) return '#cc0000';
  if (greenChars.includes(char)) return '#1b8c1b';
  return '#222222';
};

interface PanoEntry {
  name: string;
  score: string;
  label: string;
  isWinner: boolean;
}

interface PanoArrangeItem {
  entry: PanoEntry;
  showArrow: boolean;
}

// 赢家手牌展示（匹配Flutter的_buildHandDisplay）
const HandDisplay: React.FC<{ hand: Card[]; huCard?: Card; method: string }> = ({ hand, huCard, method }) => {
  const groups = useMemo(() => {
    const sorted = [...hand].sort((a, b) => {
      if (a.sentence !== b.sentence) return a.sentence - b.sentence;
      return a.position - b.position;
    });

    // 按sentence分组，再按position分组
    const sentenceGroups = new Map<number, Map<number, Card[]>>();
    for (const card of sorted) {
      if (!sentenceGroups.has(card.sentence)) {
        sentenceGroups.set(card.sentence, new Map());
      }
      const posMap = sentenceGroups.get(card.sentence)!;
      if (!posMap.has(card.position)) {
        posMap.set(card.position, []);
      }
      posMap.get(card.position)!.push(card);
    }

    // 胡牌卡牌移到同组最后位置（匹配Flutter逻辑）
    if (huCard && sentenceGroups.has(huCard.sentence)) {
      const group = sentenceGroups.get(huCard.sentence)!;
      if (group.has(huCard.position)) {
        const cards = group.get(huCard.position)!;
        const huIdx = cards.findIndex(c => c.id === huCard.id);
        if (huIdx >= 0) {
          cards.splice(huIdx, 1);
          cards.push(huCard);
          // 重排position顺序，胡牌卡牌所在position排最后
          const newPositions = new Map<number, Card[]>();
          let posIdx = 0;
          for (const [pos, posCards] of group) {
            if (pos === huCard.position) continue;
            if (posCards && posCards.length > 0) {
              newPositions.set(posIdx, [...posCards]);
              posIdx++;
            }
          }
          newPositions.set(posIdx, cards);
          sentenceGroups.set(huCard.sentence, newPositions);
        }
      }
    }

    return sentenceGroups;
  }, [hand, huCard, method]);

  return (
    <View className={styles.handContainer}>
      {Array.from<[number, Map<number, Card[]>]>(groups.entries()).map(([sentence, positions]) => (
        <View key={sentence} className={styles.handGroup}>
          {Array.from<[number, Card[]]>(positions.entries()).map(([posIdx, cards]) => {
            const card = cards[0];
            const count = cards.length;
            const isHuCard = huCard != null && cards.some(c => c.id === huCard.id);

            return (
              <View
                key={posIdx}
                className={styles.handCardWrapper}
                style={{ marginTop: posIdx === 0 ? 0 : -140 }}
              >
                <View className={styles.handCard} style={{ color: getCharColor(card.char) }}>
                  <Text className={styles.handCardChar}>{card.char}</Text>
                </View>
                {isHuCard && (
                  <View className={styles.huCardLabel}>
                    <Text className={styles.huCardLabelText}>
                      {method === '自摸' ? '自摸' : '炮'}
                    </Text>
                  </View>
                )}
                {count > 1 && (
                  <View className={styles.cardCountBadge}>
                    <Text className={styles.cardCountText}>{count}</Text>
                  </View>
                )}
              </View>
            );
          })}
        </View>
      ))}
    </View>
  );
};

// 赢家组合牌展示（匹配Flutter的_buildMeldsDisplay）
const MeldsDisplay: React.FC<{ melds: Meld[] }> = ({ melds }) => {
  if (!melds || melds.length === 0) return null;

  return (
    <View className={styles.meldsContainer}>
      {melds.map((meld, idx) => {
        const sortedCards = [...meld.cards].sort((a, b) => a.position - b.position);
        return (
          <View key={idx} className={styles.meldGroup}>
            {sortedCards.map((card, cIdx) => (
              <View key={cIdx} className={styles.meldCard} style={{ color: getCharColor(card.char) }}>
                <Text className={styles.meldCardChar}>{card.char}</Text>
              </View>
            ))}
          </View>
        );
      })}
    </View>
  );
};

// 输家手牌展示（匹配Flutter的_buildLosersDisplay）
const LosersDisplay: React.FC<{ losers: { name: string; hand: Card[]; score: number }[] }> = ({ losers }) => {
  if (!losers || losers.length === 0) return null;

  return (
    <View className={styles.losersRow}>
      {losers.map((loser, idx) => (
        <View key={idx} className={styles.loserCard}>
          <Text className={styles.loserName}>{loser.name}</Text>
          <View className={styles.loserHandRow}>
            {loser.hand.sort((a, b) => {
              if (a.sentence !== b.sentence) return a.sentence - b.sentence;
              return a.position - b.position;
            }).map((card, cIdx) => (
              <View key={cIdx} className={styles.loserHandCard} style={{ color: getCharColor(card.char) }}>
                <Text className={styles.loserHandChar}>{card.char}</Text>
              </View>
            ))}
          </View>
          <Text className={styles.loserScore}>-{loser.score}</Text>
        </View>
      ))}
    </View>
  );
};

const HuPanel: React.FC<HuPanelProps> = ({
  winnerName, method, huType, huCount, multiplier, scoreChanges,
  winnerHand, winnerMelds, huCard, loserHands, onClose,
}) => {
  // 构建玩家条目排列（匹配 Flame 版本的 arrangedEntries 逻辑）
  const arrangedEntries = useMemo(() => {
    const winnerScore = Math.abs(scoreChanges.find(sc => sc.change > 0)?.change || 0);

    const winnerEntry: PanoEntry = {
      name: winnerName,
      score: `+${winnerScore}`,
      label: '赢家',
      isWinner: true,
    };

    const losers: PanoEntry[] = [];
    if (method === '点炮') {
      const dianpaoSc = scoreChanges.find(sc => sc.change < 0);
      if (dianpaoSc) {
        losers.push({
          name: dianpaoSc.name,
          score: `-${winnerScore}`,
          label: '点炮',
          isWinner: false,
        });
      }
    } else {
      scoreChanges.forEach(sc => {
        if (sc.change < 0) {
          losers.push({
            name: sc.name,
            score: `${sc.change}`,
            label: '输家',
            isWinner: false,
          });
        }
      });
    }

    const items: PanoArrangeItem[] = [];
    if (method === '自摸' && losers.length === 2) {
      items.push({ entry: losers[0], showArrow: true });
      items.push({ entry: winnerEntry, showArrow: true });
      items.push({ entry: losers[1], showArrow: false });
    } else if (losers.length > 0) {
      items.push({ entry: losers[0], showArrow: true });
      items.push({ entry: winnerEntry, showArrow: false });
    } else {
      items.push({ entry: winnerEntry, showArrow: false });
    }

    return items;
  }, [winnerName, method, scoreChanges]);

  // 底部标签数据（匹配 Flame 版本 tags 逻辑）
  const tags = useMemo(() => {
    const huTypeColor = getHuTypeColor(huType);
    const result: { text: string; color: string; bgColor: string }[] = [];

    result.push({
      text: method,
      color: '#ffffff',
      bgColor: 'rgba(255,255,255,0.1)',
    });

    result.push({
      text: huType,
      color: huTypeColor,
      bgColor: huTypeColor + '33',
    });

    result.push({
      text: `${huCount}胡`,
      color: '#ffd700',
      bgColor: 'rgba(255,215,0,0.2)',
    });

    result.push({
      text: `${multiplier}倍`,
      color: '#ff6b6b',
      bgColor: 'rgba(255,107,107,0.2)',
    });

    return result;
  }, [method, huType, huCount, multiplier]);

  return (
    <View className={styles.overlay} onClick={onClose}>
      <View className={styles.panel} onClick={e => e.stopPropagation()}>
        {/* 关闭按钮 */}
        <View className={styles.closeBtn} onClick={onClose}>
          <Text className={styles.closeText}>✕</Text>
        </View>

        {/* 标题 */}
        <Text className={styles.title}>{winnerName} 胡牌!</Text>

        {/* 玩家条目行 */}
        <View className={styles.panoRow}>
          {arrangedEntries.map((item, idx) => (
            <React.Fragment key={idx}>
              <View className={`${styles.panoCard} ${item.entry.isWinner ? styles.winnerCard : styles.loserCard}`}>
                <Text className={`${styles.panoName} ${item.entry.isWinner ? styles.panoNameWinner : styles.panoNameLoser}`}>
                  {item.entry.name}
                </Text>
                <Text className={`${styles.panoScore} ${item.entry.isWinner ? styles.panoScoreWinner : styles.panoScoreLoser}`}>
                  {item.entry.score}
                </Text>
                <Text className={`${styles.panoLabel} ${item.entry.isWinner ? styles.panoLabelWinner : styles.panoLabelLoser}`}>
                  {item.entry.label}
                </Text>
              </View>
              {item.showArrow && idx < arrangedEntries.length - 1 && (
                <Text className={styles.panoArrow}>→</Text>
              )}
            </React.Fragment>
          ))}
        </View>

        {/* 赢家手牌展示（匹配Flutter的_buildHandDisplay） */}
        {winnerHand && winnerHand.length > 0 && (
          <View className={styles.sectionContainer}>
            <Text className={styles.sectionTitle}>赢家手牌</Text>
            <HandDisplay hand={winnerHand} huCard={huCard} method={method} />
          </View>
        )}

        {/* 赢家组合牌展示（匹配Flutter的_buildMeldsDisplay） */}
        {winnerMelds && winnerMelds.length > 0 && (
          <View className={styles.sectionContainer}>
            <Text className={styles.sectionTitle}>组合牌</Text>
            <MeldsDisplay melds={winnerMelds} />
          </View>
        )}

        {/* 输家手牌展示（匹配Flutter的_buildLosersDisplay） */}
        {loserHands && loserHands.length > 0 && (
          <View className={styles.sectionContainer}>
            <LosersDisplay losers={loserHands} />
          </View>
        )}

        {/* 分隔线 */}
        <View className={styles.divider} />

        {/* 底部标签行 */}
        <View className={styles.tagsRow}>
          {tags.map((tag, idx) => (
            <View
              key={idx}
              className={styles.tag}
              style={{
                backgroundColor: tag.bgColor,
                borderColor: tag.color + '66',
              }}
            >
              <Text className={styles.tagText} style={{ color: tag.color }}>
                {tag.text}
              </Text>
            </View>
          ))}
        </View>
      </View>
    </View>
  );
};

export default HuPanel;
