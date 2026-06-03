import React from 'react';
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

const HuPanel: React.FC<HuPanelProps> = ({
  winnerName, method, huType, huCount, multiplier, scoreChanges, onClose,
}) => {
  return (
    <View className={styles.overlay} onClick={onClose}>
      <View className={styles.panel} onClick={e => e.stopPropagation()}>
        <View className={styles.closeBtn} onClick={onClose}>
          <Text className={styles.closeText}>✕</Text>
        </View>

        <Text className={styles.title}>{winnerName} 胡牌!</Text>

        <View className={styles.playersRow}>
          {scoreChanges.map((sc, idx) => (
            <View key={idx} className={`${styles.playerCard} ${sc.change > 0 ? styles.winner : styles.loser}`}>
              <Text className={styles.playerName}>{sc.name}</Text>
              <Text className={styles.playerScore}>{sc.change > 0 ? '+' : ''}{sc.change}</Text>
              <Text className={styles.playerLabel}>{sc.label}</Text>
              {idx < scoreChanges.length - 1 && <Text className={styles.arrow}>→</Text>}
            </View>
          ))}
        </View>

        <View className={styles.tagsRow}>
          <View className={styles.tag}>
            <Text className={styles.tagText}>{method}</Text>
          </View>
          <View className={styles.tag}>
            <Text className={styles.tagText}>{huType}</Text>
          </View>
          <View className={styles.tag}>
            <Text className={styles.tagTextGold}>{huCount}胡</Text>
          </View>
          <View className={styles.tag}>
            <Text className={styles.tagTextRed}>{multiplier}倍</Text>
          </View>
        </View>
      </View>
    </View>
  );
};

export default HuPanel;
