import React from 'react';
import { View, Text } from '@tarojs/components';
import styles from './index.module.scss';

const Mine: React.FC = () => {
  const stats = [
    { label: '总场次', value: '12' },
    { label: '胜场', value: '7' },
    { label: '胜率', value: '58%' },
    { label: '最高胡数', value: '36' },
  ];

  const achievements = [
    { name: '初出茅庐', desc: '完成第一局游戏', unlocked: true },
    { name: '小试牛刀', desc: '累计胜利5场', unlocked: true },
    { name: '字牌高手', desc: '累计胜利20场', unlocked: false },
    { name: '清枯重台', desc: '胡牌类型清枯重台', unlocked: false },
    { name: '十对大王', desc: '胡牌类型十对', unlocked: true },
  ];

  return (
    <View className={styles.page}>
      <View className={styles.header}>
        <Text className={styles.headerTitle}>我的</Text>
      </View>

      {/* 个人信息 */}
      <View className={styles.profileCard}>
        <View className={styles.avatar}>
          <Text className={styles.avatarText}>我</Text>
        </View>
        <View className={styles.profileInfo}>
          <Text className={styles.profileName}>字牌玩家</Text>
          <Text className={styles.profileLevel}>Lv.5</Text>
        </View>
      </View>

      {/* 统计数据 */}
      <View className={styles.statsGrid}>
        {stats.map(stat => (
          <View key={stat.label} className={styles.statCard}>
            <Text className={styles.statValue}>{stat.value}</Text>
            <Text className={styles.statLabel}>{stat.label}</Text>
          </View>
        ))}
      </View>

      {/* 成就 */}
      <View className={styles.section}>
        <Text className={styles.sectionTitle}>游戏成就</Text>
        <View className={styles.achievementList}>
          {achievements.map(ach => (
            <View
              key={ach.name}
              className={`${styles.achievementCard} ${ach.unlocked ? styles.unlocked : styles.locked}`}
            >
              <View className={styles.achIcon}>
                <Text className={styles.achIconText}>{ach.unlocked ? '★' : '☆'}</Text>
              </View>
              <View className={styles.achInfo}>
                <Text className={styles.achName}>{ach.name}</Text>
                <Text className={styles.achDesc}>{ach.desc}</Text>
              </View>
            </View>
          ))}
        </View>
      </View>

      {/* 关于 */}
      <View className={styles.aboutCard}>
        <Text className={styles.aboutText}>上大人字牌 v1.0.0</Text>
        <Text className={styles.aboutDesc}>传统字牌 · 智慧博弈</Text>
      </View>
    </View>
  );
};

export default Mine;
