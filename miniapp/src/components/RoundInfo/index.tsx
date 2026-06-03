import React from 'react';
import { View, Text } from '@tarojs/components';
import styles from './index.module.scss';

interface RoundInfoProps {
  roundNumber: number;
  dealerName: string;
}

const RoundInfo: React.FC<RoundInfoProps> = ({ roundNumber, dealerName }) => {
  const progress = roundNumber / 8;

  return (
    <View className={styles.container}>
      <View className={styles.dealerBadge}>
        <Text className={styles.dealerText}>{dealerName}</Text>
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
