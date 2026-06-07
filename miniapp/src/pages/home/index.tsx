import React, { useState } from 'react';
import { View, Text, Image } from '@tarojs/components';
import Taro from '@tarojs/taro';
import styles from './index.module.scss';

const Home: React.FC = () => {
  const [baseScore, setBaseScore] = useState(5);
  const [multiplierBase, setMultiplierBase] = useState(2);
  const [difficulty, setDifficulty] = useState('hard');
  const [piaoEnabled, setPiaoEnabled] = useState(false);

  const baseScoreOptions = [5, 10, 20];
  const multiplierOptions = [2, 5, 10];
  const difficultyOptions = [
    { label: '简单', value: 'easy' },
    { label: '中等', value: 'medium' },
    { label: '困难', value: 'hard' },
  ];

  const handleStart = () => {
    Taro.navigateTo({
      url: `/pages/game/index?baseScore=${baseScore}&multiplierBase=${multiplierBase}&difficulty=${difficulty}&piaoEnabled=${piaoEnabled ? 1 : 0}`,
    });
  };

  return (
    <View className={styles.page}>
      {/* 装饰光晕 */}
      <View className={styles.glowTopRight} />
      <View className={styles.glowBottomLeft} />

      <View className={styles.content}>
        {/* 左侧品牌区 */}
        <View className={styles.brandArea}>
          {/* Logo */}
          <View className={styles.logoWrap}>
            <Text className={styles.logoText}>上大人</Text>
          </View>
          <Text className={styles.title}>上大人</Text>
          <Text className={styles.subtitle}>字 牌 游 戏</Text>
          {/* 装饰卡牌 - 上大人 */}
          <View className={styles.decoCards}>
            <View className={styles.decoCardRed}>
              <Text className={styles.decoCardTextRed}>上</Text>
            </View>
            <View className={styles.decoCardRed}>
              <Text className={styles.decoCardTextRed}>大</Text>
            </View>
            <View className={styles.decoCardRed}>
              <Text className={styles.decoCardTextRed}>人</Text>
            </View>
            <View className={styles.decoCardGap} />
            <View className={styles.decoCardGreen}>
              <Text className={styles.decoCardTextGreen}>福</Text>
            </View>
            <View className={styles.decoCardGreen}>
              <Text className={styles.decoCardTextGreen}>禄</Text>
            </View>
            <View className={styles.decoCardGreen}>
              <Text className={styles.decoCardTextGreen}>寿</Text>
            </View>
          </View>
        </View>

        {/* 分割线 */}
        <View className={styles.divider} />

        {/* 右侧设置区 */}
        <View className={styles.settingsArea}>
          {/* 底分 */}
          <View className={styles.settingRow}>
            <Text className={styles.settingLabel}>底分</Text>
            <View className={styles.segGroup}>
              {baseScoreOptions.map(v => (
                <View
                  key={v}
                  className={`${styles.segBtn} ${baseScore === v ? styles.segActive : ''}`}
                  onClick={() => setBaseScore(v)}
                >
                  <Text className={styles.segText}>{v}分</Text>
                </View>
              ))}
            </View>
          </View>

          {/* 倍数基数 */}
          <View className={styles.settingRow}>
            <Text className={styles.settingLabel}>倍数基数</Text>
            <View className={styles.segGroup}>
              {multiplierOptions.map(v => (
                <View
                  key={v}
                  className={`${styles.segBtn} ${multiplierBase === v ? styles.segActive : ''}`}
                  onClick={() => setMultiplierBase(v)}
                >
                  <Text className={styles.segText}>{v}分</Text>
                </View>
              ))}
            </View>
          </View>

          {/* 难度 */}
          <View className={styles.settingRow}>
            <Text className={styles.settingLabel}>难度</Text>
            <View className={styles.segGroup}>
              {difficultyOptions.map(opt => (
                <View
                  key={opt.value}
                  className={`${styles.segBtn} ${difficulty === opt.value ? styles.segActive : ''}`}
                  onClick={() => setDifficulty(opt.value)}
                >
                  <Text className={styles.segText}>{opt.label}</Text>
                </View>
              ))}
            </View>
          </View>

          {/* 飘分 */}
          <View className={styles.settingRow}>
            <Text className={styles.settingLabel}>飘分</Text>
            <View className={styles.segGroup}>
              <View
                className={`${styles.segBtn} ${!piaoEnabled ? styles.segActive : ''}`}
                onClick={() => setPiaoEnabled(false)}
              >
                <Text className={styles.segText}>关闭</Text>
              </View>
              <View
                className={`${styles.segBtn} ${piaoEnabled ? styles.segActive : ''}`}
                onClick={() => setPiaoEnabled(true)}
              >
                <Text className={styles.segText}>打开</Text>
              </View>
            </View>
          </View>

          {/* 开始按钮 */}
          <View className={styles.startBtn} onClick={handleStart}>
            <Text className={styles.startText}>开 始 游 戏</Text>
          </View>
        </View>
      </View>
    </View>
  );
};

export default Home;
