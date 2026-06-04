import React from 'react';
import { View, Text } from '@tarojs/components';
import { mockGameRecords } from '../../data/mockRecords';
import styles from './index.module.scss';

const Records: React.FC = () => {
  const records = mockGameRecords;

  const totalGames = records.length;
  const wins = records.filter(r => r.winnerId === 0).length;
  const winRate = totalGames > 0 ? Math.round((wins / totalGames) * 100) : 0;

  return (
    <View className={styles.page}>
      <View className={styles.content}>
      <View className={styles.header}>
        <Text className={styles.headerTitle}>战绩</Text>
      </View>

      {/* 统计概览 */}
      <View className={styles.statsCard}>
        <View className={styles.statItem}>
          <Text className={styles.statValue}>{totalGames}</Text>
          <Text className={styles.statLabel}>总场次</Text>
        </View>
        <View className={styles.statDivider} />
        <View className={styles.statItem}>
          <Text className={styles.statValue}>{wins}</Text>
          <Text className={styles.statLabel}>胜场</Text>
        </View>
        <View className={styles.statDivider} />
        <View className={styles.statItem}>
          <Text className={styles.statValueGold}>{winRate}%</Text>
          <Text className={styles.statLabel}>胜率</Text>
        </View>
      </View>

      {/* 战绩列表 */}
      <View className={styles.list}>
        {records.map(record => {
          const myScore = record.players.find(p => p.id === 0)?.finalScore || 0;
          const isWin = record.winnerId === 0;
          return (
            <View key={record.id} className={`${styles.recordCard} ${isWin ? styles.win : styles.lose}`}>
              <View className={styles.recordHeader}>
                <Text className={styles.recordDate}>{record.date}</Text>
                <Text className={`${styles.recordResult} ${isWin ? styles.resultWin : styles.resultLose}`}>
                  {isWin ? '胜' : '负'}
                </Text>
              </View>
              <View className={styles.recordScores}>
                {record.players.map(p => (
                  <View key={p.id} className={styles.scoreItem}>
                    <Text className={styles.scoreName}>{p.name}</Text>
                    <Text className={`${styles.scoreValue} ${p.finalScore > 0 ? styles.positive : styles.negative}`}>
                      {p.finalScore > 0 ? '+' : ''}{p.finalScore}
                    </Text>
                  </View>
                ))}
              </View>
            </View>
          );
        })}
      </View>
      </View>
    </View>
  );
};

export default Records;
