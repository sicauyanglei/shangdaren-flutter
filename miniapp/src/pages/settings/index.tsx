import React, { useState } from 'react';
import { View, Text } from '@tarojs/components';
import Taro from '@tarojs/taro';
import { useGameStore } from '../../store/gameStore';
import styles from './index.module.scss';

const Settings: React.FC = () => {
  const store = useGameStore();
  const [volume, setVolume] = useState(store.volume);
  const [difficulty, setDifficulty] = useState(store.difficulty);

  const handleClose = () => {
    Taro.navigateBack();
  };

  const handleExitGame = () => {
    Taro.navigateBack();
  };

  const handleVolumeChange = (e: any) => {
    const val = Number(e.target.value);
    setVolume(val);
    store.setVolume(val);
  };

  const handleDifficultyChange = (value: string) => {
    setDifficulty(value);
    store.setDifficulty(value);
  };

  return (
    <View className={styles.overlay}>
      <View className={styles.outerPanel}>
        <View className={styles.innerPanel}>
          {/* Header */}
          <View className={styles.headerWrap}>
            <View className={styles.header}>
              <Text className={styles.headerTitle}>系统设置</Text>
            </View>
            <View className={styles.closeBtn} onClick={handleClose}>
              <Text className={styles.closeIcon}>×</Text>
            </View>
          </View>

          {/* Volume Section */}
          <View className={styles.section}>
            <Text className={styles.sectionLabel}>音效大小</Text>
            <View className={styles.sliderRow}>
              <View className={styles.sliderTrack}>
                <View className={styles.sliderActive} style={{ width: `${volume}%` }} />
                <View
                  className={styles.sliderThumb}
                  style={{ left: `calc(${volume}% - 10px)` }}
                />
                <input
                  type="range"
                  min={0}
                  max={100}
                  value={volume}
                  className={styles.sliderInput}
                  onChange={handleVolumeChange}
                />
              </View>
              <Text className={styles.sliderValue}>{volume}%</Text>
            </View>
          </View>

          {/* Difficulty Section */}
          <View className={styles.section}>
            <Text className={styles.sectionLabel}>游戏难度</Text>
            <View className={styles.diffRow}>
              {[
                { label: '简单', value: 'easy' },
                { label: '中等', value: 'medium' },
                { label: '困难', value: 'hard' },
              ].map(opt => (
                <View
                  key={opt.value}
                  className={styles.radioItem}
                  onClick={() => handleDifficultyChange(opt.value)}
                >
                  <View className={styles.radioOuter}>
                    {difficulty === opt.value && <View className={styles.radioInner} />}
                  </View>
                  <Text className={styles.radioLabel}>{opt.label}</Text>
                </View>
              ))}
            </View>
          </View>

          {/* Divider + Exit Button */}
          <View className={styles.dividerSection}>
            <View className={styles.exitBtn} onClick={handleExitGame}>
              <Text className={styles.exitText}>退出游戏</Text>
            </View>
          </View>
        </View>
      </View>
    </View>
  );
};

export default Settings;
