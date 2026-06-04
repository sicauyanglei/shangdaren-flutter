import React, { useMemo } from 'react';
import { View, Text } from '@tarojs/components';
import styles from './index.module.scss';

interface HuPanelProps {
  winnerName: string;
  method: string;
  huType: string;
  huCount: number;
  multiplier: number;
  scoreChanges: { name: string; change: number; label: string }[];
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

const HuPanel: React.FC<HuPanelProps> = ({
  winnerName, method, huType, huCount, multiplier, scoreChanges, onClose,
}) => {
  // 构建玩家条目排列（匹配 Flame 版本的 arrangedEntries 逻辑）
  const arrangedEntries = useMemo(() => {
    const winnerEntry: PanoEntry = {
      name: winnerName,
      score: `+${Math.abs(scoreChanges.find(sc => sc.change > 0)?.change || 0)}`,
      label: '赢家',
      isWinner: true,
    };

    const losers: PanoEntry[] = [];
    if (method === '点炮') {
      const dianpaoSc = scoreChanges.find(sc => sc.change < 0);
      if (dianpaoSc) {
        losers.push({
          name: dianpaoSc.name,
          score: `${dianpaoSc.change}`,
          label: '点炮',
          isWinner: false,
        });
      }
    } else {
      // 自摸：每个输家单独显示
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

  // 底部标签数据
  const tags = useMemo(() => {
    const huTypeColor = getHuTypeColor(huType);
    const result: { text: string; color: string; bgColor: string }[] = [];

    // 方法标签
    result.push({
      text: method,
      color: '#ffffff',
      bgColor: 'rgba(255,255,255,0.1)',
    });

    // 胡型标签
    result.push({
      text: huType,
      color: huTypeColor,
      bgColor: huTypeColor + '33',
    });

    // 胡数标签
    result.push({
      text: `${huCount}胡`,
      color: '#ffd700',
      bgColor: 'rgba(255,215,0,0.2)',
    });

    // 倍数标签
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
