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
        <View className={`${styles.btn} ${styles.btnProminent} ${styles.btnZimo}`} onClick={onZimo}>
          <View className={`${styles.btnInner} ${styles.btnInnerZimo}`}>
            <Text className={`${styles.btnText} ${styles.btnTextProminent}`}>自摸</Text>
          </View>
        </View>
      )}
      {canHu && (
        <View className={`${styles.btn} ${styles.btnProminent} ${styles.btnHu}`} onClick={onHu}>
          <View className={`${styles.btnInner} ${styles.btnInnerHu}`}>
            <Text className={`${styles.btnText} ${styles.btnTextProminent}`}>胡</Text>
          </View>
        </View>
      )}
      {canChi && (
        <View className={`${styles.btn} ${styles.btnChi}`} onClick={onChi}>
          <View className={`${styles.btnInner} ${styles.btnInnerChi}`}>
            <Text className={styles.btnText}>吃</Text>
          </View>
        </View>
      )}
      {canPeng && (
        <View className={`${styles.btn} ${styles.btnPeng}`} onClick={onPeng}>
          <View className={`${styles.btnInner} ${styles.btnInnerPeng}`}>
            <Text className={styles.btnText}>碰</Text>
          </View>
        </View>
      )}
      {canZhao && (
        <View className={`${styles.btn} ${styles.btnZhao}`} onClick={onZhao}>
          <View className={`${styles.btnInner} ${styles.btnInnerZhao}`}>
            <Text className={`${styles.btnText} ${styles.btnTextZhao}`}>招</Text>
          </View>
        </View>
      )}
      <View className={`${styles.btn} ${styles.btnPass}`} onClick={onPass}>
        <View className={`${styles.btnInner} ${styles.btnInnerPass}`}>
          <Text className={`${styles.btnText} ${styles.btnTextPass}`}>过</Text>
        </View>
      </View>
    </View>
  );
};

export default ActionButtons;
