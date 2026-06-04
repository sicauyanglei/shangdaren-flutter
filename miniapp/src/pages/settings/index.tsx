import React, { useState } from 'react';
import { View, Text, Slider } from '@tarojs/components';
import styles from './index.module.scss';

const Settings: React.FC = () => {
  const [volume, setVolume] = useState(80);
  const [difficulty, setDifficulty] = useState('hard');

  const difficultyOptions = [
    { label: '简单', value: 'easy', desc: 'AI较保守，适合新手' },
    { label: '中等', value: 'medium', desc: 'AI平衡攻防' },
    { label: '困难', value: 'hard', desc: 'AI激进，追求胡牌' },
  ];

  return (
    <View className={styles.page}>
      <View className={styles.content}>
      <View className={styles.header}>
        <Text className={styles.headerTitle}>系统设置</Text>
      </View>

      <View className={styles.card}>
        {/* 音效 */}
        <View className={styles.section}>
          <Text className={styles.sectionTitle}>音效大小</Text>
          <View className={styles.sliderRow}>
            <Slider
              value={volume}
              min={0}
              max={100}
              activeColor='#ffd700'
              backgroundColor='rgba(255,255,255,0.2)'
              blockSize={20}
              onInput={e => setVolume(e.detail.value)}
            />
            <Text className={styles.sliderValue}>{volume}%</Text>
          </View>
        </View>

        {/* 难度 */}
        <View className={styles.section}>
          <Text className={styles.sectionTitle}>AI难度</Text>
          <View className={styles.diffGroup}>
            {difficultyOptions.map(opt => (
              <View
                key={opt.value}
                className={`${styles.diffCard} ${difficulty === opt.value ? styles.diffActive : ''}`}
                onClick={() => setDifficulty(opt.value)}
              >
                <Text className={styles.diffLabel}>{opt.label}</Text>
                <Text className={styles.diffDesc}>{opt.desc}</Text>
              </View>
            ))}
          </View>
        </View>
      </View>

      {/* 游戏规则 */}
      <View className={styles.card}>
        <View className={styles.section}>
          <Text className={styles.sectionTitle}>游戏规则</Text>
          <Text className={styles.ruleText}>
            上大人字牌，3人对战，逆时针出牌。8局制，庄家流转。
            操作优先级：胡 &gt; 招 &gt; 碰 &gt; 吃。胡数≥11可胡牌。
          </Text>
        </View>
      </View>
      </View>
    </View>
  );
};

export default Settings;
