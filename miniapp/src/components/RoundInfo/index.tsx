import React from 'react';
import { View, Text } from '@tarojs/components';
import styles from './index.module.scss';

interface RoundInfoProps {
  roundNumber: number;
  dealerName: string;
  showHuDisplay?: boolean;
  isLastRound?: boolean;
  countdown?: number;
  onNextRound?: () => void;
  onShowSettlement?: () => void;
}

const RoundInfo: React.FC<RoundInfoProps> = ({
  roundNumber,
  dealerName,
  showHuDisplay = false,
  isLastRound = false,
  countdown = 0,
  onNextRound,
  onShowSettlement,
}) => {
  const progress = roundNumber / 8;

  if (showHuDisplay) {
    const label = isLastRound ? `结算(${countdown}秒)` : `下一局(${countdown}秒)`;
    const handleClick = isLastRound ? onShowSettlement : onNextRound;

    return (
      <View className={styles.huContainer} onClick={handleClick}>
        <Text className={styles.huText}>{label}</Text>
      </View>
    );
  }

  return (
    <View className={styles.container}>
      <View className={styles.dealerBadge}>
        <Text className={styles.dealerText}>{dealerName || '庄'}</Text>
      </View>
      <View className={styles.info}>
        <Text className={styles.roundText}>第{roundNumber}局</Text>
        <View className={styles.progressTrack}>
          <View className={styles.progressFill} style={{ width: `${progress * 100}%` }} />
        </View>
      </View>
    </View>
  );
};

export default RoundInfo;
