import React, { useState, useEffect, useRef, useCallback } from 'react';
import { View, Text } from '@tarojs/components';
import styles from './index.module.scss';

interface RoundInfoProps {
  roundNumber: number;
  dealerName: string;
  showHuDisplay?: boolean;
  isLastRound?: boolean;
  onNextRound?: () => void;
  onShowSettlement?: () => void;
}

const RoundInfo: React.FC<RoundInfoProps> = ({
  roundNumber,
  dealerName,
  showHuDisplay = false,
  isLastRound = false,
  onNextRound,
  onShowSettlement,
}) => {
  const [countdown, setCountdown] = useState(60);
  const timerRef = useRef<ReturnType<typeof setInterval> | null>(null);
  const prevShowHuDisplay = useRef(showHuDisplay);

  const stopCountdown = useCallback(() => {
    if (timerRef.current !== null) {
      clearInterval(timerRef.current);
      timerRef.current = null;
    }
    setCountdown(60);
  }, []);

  const onAutoNext = useCallback(() => {
    stopCountdown();
    if (isLastRound) {
      onShowSettlement?.();
    } else {
      onNextRound?.();
    }
  }, [isLastRound, onNextRound, onShowSettlement, stopCountdown]);

  const startCountdown = useCallback(() => {
    setCountdown(60);
    if (timerRef.current !== null) {
      clearInterval(timerRef.current);
    }
    timerRef.current = setInterval(() => {
      setCountdown(prev => {
        if (prev <= 1) {
          if (timerRef.current !== null) {
            clearInterval(timerRef.current);
            timerRef.current = null;
          }
          // 延迟执行回调避免在setState中调用
          setTimeout(() => onAutoNext(), 0);
          return 0;
        }
        return prev - 1;
      });
    }, 1000);
  }, [onAutoNext]);

  useEffect(() => {
    if (showHuDisplay && !prevShowHuDisplay.current) {
      startCountdown();
    } else if (!showHuDisplay && prevShowHuDisplay.current) {
      stopCountdown();
    }
    prevShowHuDisplay.current = showHuDisplay;
  }, [showHuDisplay, startCountdown, stopCountdown]);

  useEffect(() => {
    return () => {
      if (timerRef.current !== null) {
        clearInterval(timerRef.current);
      }
    };
  }, []);

  const handleTap = useCallback(() => {
    onAutoNext();
  }, [onAutoNext]);

  const progress = roundNumber / 8;

  if (showHuDisplay) {
    const label = isLastRound ? `结算(${countdown}秒)` : `下一局(${countdown}秒)`;

    return (
      <View className={styles.huContainer} onClick={handleTap}>
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
