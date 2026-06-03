import React from 'react';
import { View, Text } from '@tarojs/components';
import styles from './index.module.scss';

interface ActionButtonsProps {
  canChi: boolean;
  canPeng: boolean;
  canZhao: boolean;
  canHu: boolean;
  canZimo: boolean;
  onChi: () => void;
  onPeng: () => void;
  onZhao: () => void;
  onHu: () => void;
  onZimo: () => void;
  onPass: () => void;
}

const ActionButtons: React.FC<ActionButtonsProps> = ({
  canChi, canPeng, canZhao, canHu, canZimo,
  onChi, onPeng, onZhao, onHu, onZimo, onPass,
}) => {
  const hasAnyAction = canChi || canPeng || canZhao || canHu || canZimo;
  if (!hasAnyAction) return null;

  return (
    <View className={styles.container}>
      {canZimo && (
        <View className={`${styles.btn} ${styles.btnZimo}`} onClick={onZimo}>
          <Text className={styles.btnTextZimo}>自摸</Text>
        </View>
      )}
      {canHu && (
        <View className={`${styles.btn} ${styles.btnHu}`} onClick={onHu}>
          <Text className={styles.btnTextHu}>胡</Text>
        </View>
      )}
      {canZhao && (
        <View className={`${styles.btn} ${styles.btnZhao}`} onClick={onZhao}>
          <Text className={styles.btnText}>招</Text>
        </View>
      )}
      {canPeng && (
        <View className={`${styles.btn} ${styles.btnPeng}`} onClick={onPeng}>
          <Text className={styles.btnText}>碰</Text>
        </View>
      )}
      {canChi && (
        <View className={`${styles.btn} ${styles.btnChi}`} onClick={onChi}>
          <Text className={styles.btnText}>吃</Text>
        </View>
      )}
      <View className={`${styles.btn} ${styles.btnPass}`} onClick={onPass}>
        <Text className={styles.btnText}>过</Text>
      </View>
    </View>
  );
};

export default ActionButtons;
