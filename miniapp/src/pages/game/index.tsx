import React, { useEffect, useState } from 'react';
import { View, Text } from '@tarojs/components';
import Taro, { useRouter } from '@tarojs/taro';
import { useGameStore } from '../../store/gameStore';
import CardTile from '../../components/CardTile';
import ActionButtons from '../../components/ActionButtons';
import RoundInfo from '../../components/RoundInfo';
import HuPanel from '../../components/HuPanel';
import styles from './index.module.scss';

const Game: React.FC = () => {
  const router = useRouter();
  const store = useGameStore();

  const baseScore = Number(router.params.baseScore || 10);
  const multiplierBase = Number(router.params.multiplierBase || 5);
  const difficulty = router.params.difficulty || 'hard';
  const piaoEnabled = router.params.piaoEnabled === '1';

  const [selectedCardId, setSelectedCardId] = useState<number | null>(null);

  useEffect(() => {
    store.startGame(baseScore, multiplierBase, difficulty, piaoEnabled);
  }, []);

  const currentPlayer = store.players[store.currentPlayerIndex];
  const isMyTurn = store.currentPlayerIndex === 0 && store.phase === 'playing';
  const humanPlayer = store.players[0];

  const handleCardClick = (cardId: number) => {
    if (!isMyTurn) return;
    setSelectedCardId(cardId);
  };

  const handleDiscard = () => {
    if (selectedCardId !== null) {
      store.discardCard(selectedCardId);
      setSelectedCardId(null);
    }
  };

  const handleBack = () => {
    Taro.navigateBack();
  };

  // 飘分阶段
  if (store.isPiaoPhase) {
    return (
      <View className={styles.page}>
        <View className={styles.piaoPanel}>
          <Text className={styles.piaoTitle}>飘分设置</Text>
          <Text className={styles.piaoPlayer}>{store.players[store.piaoCurrentPlayerIndex]?.name}</Text>
          <View className={styles.piaoOptions}>
            {[0, 5, 10, 20].map(v => (
              <View
                key={v}
                className={styles.piaoBtn}
                onClick={() => store.setPiao(v)}
              >
                <Text className={styles.piaoBtnText}>{v === 0 ? '不飘' : `${v}分`}</Text>
              </View>
            ))}
          </View>
        </View>
      </View>
    );
  }

  return (
    <View className={styles.page}>
      {/* 顶部信息栏 */}
      <View className={styles.topBar}>
        <View className={styles.backBtn} onClick={handleBack}>
          <Text className={styles.backText}>←</Text>
        </View>
        <RoundInfo
          roundNumber={store.roundNumber}
          dealerName={store.players[store.dealerIndex]?.name || ''}
        />
      </View>

      {/* 牌桌区域 */}
      <View className={styles.table}>
        {/* 玩家1（左上） */}
        <View className={styles.playerArea1}>
          <View className={styles.avatarArea}>
            <View className={styles.avatar}>
              <Text className={styles.avatarText}>1</Text>
            </View>
            <Text className={styles.playerName}>{store.players[1]?.name}</Text>
            <Text className={styles.playerScore}>{store.players[1]?.score}</Text>
          </View>
          <View className={styles.aiMelds}>
            {store.players[1]?.melds.map((meld, idx) => (
              <View key={idx} className={styles.meldGroup}>
                {meld.cards.map(c => <CardTile key={c.id} card={c} size='sm' />)}
              </View>
            ))}
          </View>
          <View className={styles.aiDiscards}>
            {store.players[1]?.discards.map(c => <CardTile key={c.id} card={c} size='sm' />)}
          </View>
        </View>

        {/* 玩家2（右上） */}
        <View className={styles.playerArea2}>
          <View className={styles.avatarArea}>
            <View className={styles.avatar}>
              <Text className={styles.avatarText}>2</Text>
            </View>
            <Text className={styles.playerName}>{store.players[2]?.name}</Text>
            <Text className={styles.playerScore}>{store.players[2]?.score}</Text>
          </View>
          <View className={styles.aiMelds}>
            {store.players[2]?.melds.map((meld, idx) => (
              <View key={idx} className={styles.meldGroup}>
                {meld.cards.map(c => <CardTile key={c.id} card={c} size='sm' />)}
              </View>
            ))}
          </View>
          <View className={styles.aiDiscards}>
            {store.players[2]?.discards.map(c => <CardTile key={c.id} card={c} size='sm' />)}
          </View>
        </View>

        {/* 中央牌堆 */}
        <View className={styles.deckArea}>
          <Text className={styles.deckCount}>剩余 {store.deck.length} 张</Text>
        </View>

        {/* 人类玩家区域 */}
        <View className={styles.myArea}>
          {/* 组合牌 */}
          <View className={styles.myMelds}>
            {humanPlayer?.melds.map((meld, idx) => (
              <View key={idx} className={styles.meldGroup}>
                {meld.cards.map(c => <CardTile key={c.id} card={c} size='md' />)}
              </View>
            ))}
          </View>

          {/* 手牌 */}
          <View className={styles.myHand}>
            {humanPlayer?.hand.map(card => (
              <CardTile
                key={card.id}
                card={card}
                size='lg'
                selected={selectedCardId === card.id}
                onClick={() => handleCardClick(card.id)}
              />
            ))}
          </View>

          {/* 弃牌区 */}
          <View className={styles.myDiscards}>
            {humanPlayer?.discards.map(c => <CardTile key={c.id} card={c} size='sm' />)}
          </View>
        </View>
      </View>

      {/* 操作按钮 */}
      {isMyTurn && selectedCardId !== null && (
        <View className={styles.discardBtn} onClick={handleDiscard}>
          <Text className={styles.discardBtnText}>出牌</Text>
        </View>
      )}

      <ActionButtons
        canChi={false}
        canPeng={false}
        canZhao={false}
        canHu={false}
        canZimo={false}
        onChi={() => {}}
        onPeng={() => {}}
        onZhao={() => {}}
        onHu={() => {}}
        onZimo={() => {}}
        onPass={() => {}}
      />

      {/* 胡牌面板 */}
      {store.showHuResult && store.huResult && (
        <HuPanel
          winnerName={store.players[store.huResult.winnerId]?.name || ''}
          method={store.huResult.method === 'dianpao' ? '点炮' : '自摸'}
          huType={store.huResult.huType}
          huCount={store.huResult.huCount}
          multiplier={store.huResult.multiplier}
          scoreChanges={store.huResult.scoreChanges.map((change, idx) => ({
            name: store.players[idx]?.name || '',
            change,
            label: idx === store.huResult!.winnerId ? '赢家' : '输家',
          }))}
          onClose={store.closeHuResult}
        />
      )}
    </View>
  );
};

export default Game;
