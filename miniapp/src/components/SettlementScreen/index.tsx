import React, { useMemo } from 'react';
import { View, Text } from '@tarojs/components';
import { Player, RoundResult } from '../../types/player';
import styles from './index.module.scss';

export interface SettlementScreenProps {
  players: Player[];
  roundResults: RoundResult[];
  onClose: () => void;
}

const SettlementScreen: React.FC<SettlementScreenProps> = ({
  players,
  roundResults,
  onClose,
}) => {
  // 计算总结算分数和赢家
  const { totalScores, maxScore, winners } = useMemo(() => {
    const scores = players.map(p => p.score);
    const max = scores.length > 0 ? Math.max(...scores) : 0;
    const winnerNames = players
      .filter((_, i) => scores[i] === max)
      .map(p => p.name);
    return { totalScores: scores, maxScore: max, winners: winnerNames };
  }, [players]);

  // 渲染总结算区域
  const renderTotalScores = () => (
    <View className={styles.totalScores}>
      <Text className={styles.totalScoresTitle}>总结算</Text>
      <View className={styles.scoreCards}>
        {players.map((player, index) => {
          const score = totalScores[index];
          const isWinner = score === maxScore;
          return (
            <View
              key={player.id}
              className={`${styles.scoreCard} ${isWinner ? styles.scoreCardWinner : styles.scoreCardLoser}`}
            >
              <Text className={styles.scoreCardName}>{player.name}</Text>
              <Text
                className={`${styles.scoreCardValue} ${isWinner ? styles.scoreCardValueWinner : styles.scoreCardValueLoser}`}
              >
                {score >= 0 ? '+' : ''}{score}分
              </Text>
            </View>
          );
        })}
      </View>
      <Text className={styles.winnerText}>赢家: {winners.join(', ')}</Text>
    </View>
  );

  // 渲染单局结果内容
  const renderRoundContent = (round: RoundResult) => {
    const scoreChanges = round.scoreChanges;
    const piaoScores = round.piaoScores;

    return (
      <View className={styles.roundContent}>
        <View className={styles.roundRow}>
          <Text className={styles.roundLabel}>赢家: </Text>
          <Text className={styles.roundValueTeal}>{round.winner}</Text>
        </View>
        <Text className={styles.roundValueRed}>
          {round.huType} {round.method}
        </Text>
        <View className={styles.roundRow}>
          <Text className={styles.roundLabel}>倍数: </Text>
          <Text className={styles.roundValueTeal}>{round.multiplier}倍</Text>
        </View>
        <Text className={styles.roundValueGold}>
          得分: {round.score}分
        </Text>
        {scoreChanges && scoreChanges.length > 0 && (
          <View className={styles.scoreChangesWrap}>
            {players.map((player, j) => {
              if (j === round.winnerIndex) return null;
              const change = scoreChanges.length > j ? scoreChanges[j] : 0;
              if (change === 0) return null;
              return (
                <Text key={player.id} className={styles.scoreChangeItem}>
                  {player.name}输: {Math.abs(change)}分
                </Text>
              );
            })}
          </View>
        )}
        {piaoScores && piaoScores.length > 0 && (
          <Text className={styles.piaoText}>
            飘分: {players.map((p, i) => `${p.name}(${piaoScores.length > i ? piaoScores[i] : 0})`).join(' ')}
          </Text>
        )}
      </View>
    );
  };

  // 渲染局结果列表
  const renderRoundResults = () => (
    <View className={styles.roundResults}>
      {roundResults.map(round => (
        <View key={round.roundNumber} className={styles.roundItem}>
          <Text className={styles.roundTitle}>
            第{round.roundNumber}局{round.isLiuju ? ' 流局' : ''}
          </Text>
          {round.isLiuju ? (
            <Text className={styles.liujuText}>流局</Text>
          ) : (
            renderRoundContent(round)
          )}
        </View>
      ))}
    </View>
  );

  return (
    <View className={styles.overlay}>
      <View className={styles.panel}>
        <Text className={styles.title}>游戏结算</Text>
        <View className={styles.scrollArea}>
          {renderTotalScores()}
          {renderRoundResults()}
        </View>
        <View className={styles.footer}>
          <View className={styles.confirmBtn} onClick={onClose}>
            <Text className={styles.confirmBtnText}>确认</Text>
          </View>
        </View>
      </View>
    </View>
  );
};

export default SettlementScreen;
