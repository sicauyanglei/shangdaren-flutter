import React, { useEffect, useState, useMemo } from 'react';
import { View, Text } from '@tarojs/components';
import Taro, { useRouter } from '@tarojs/taro';
import { useGameStore } from '../../store/gameStore';
import ActionButtons from '../../components/ActionButtons';
import RoundInfo from '../../components/RoundInfo';
import HuPanel from '../../components/HuPanel';
import { Card, CardChar, getCardGroup, CARD_GROUPS, RED_CHARS, GREEN_CHARS } from '../../types/card';
import { Player } from '../../types/player';
import styles from './index.module.scss';

// ============================================
// 设计常量 (匹配 Flame 版本 1280x720)
// ============================================
const DW = 1280;
const DH = 720;

const px2vw = (px: number) => (px / DW * 100) + 'vw';
const px2vh = (px: number) => (px / DH * 100) + 'vh';

const HAND_CARD_H = 224;
const MELD_CARD_W = 34;
const MELD_CARD_H = 56;

const HAND_STACK_VISIBLE = 68;
const HAND_SENTENCE_GAP = 2;
const AI_HAND_STACK_VISIBLE = 15;
const MELD_STACK_VISIBLE = 17;
const DISCARD_CARD_GAP = 1;
const MAX_DISCARD_PER_ROW = 8;
const LEFT_MAX_W = 340;
const RIGHT_MAX_W = 280;

// ============================================
// 手牌按句分组
// ============================================
interface CharStack {
  char: CardChar;
  cards: Card[];
}

interface SentenceGroup {
  sentence: number;
  stacks: CharStack[];
}

function groupHandBySentence(hand: Card[]): SentenceGroup[] {
  const sentenceMap = new Map<number, Map<string, Card[]>>();

  for (const card of hand) {
    const sentence = getCardGroup(card.char);
    if (!sentenceMap.has(sentence)) {
      sentenceMap.set(sentence, new Map());
    }
    const charMap = sentenceMap.get(sentence)!;
    if (!charMap.has(card.char)) {
      charMap.set(card.char, []);
    }
    charMap.get(card.char)!.push(card);
  }

  const groups: SentenceGroup[] = [];
  const sortedSentences = [...sentenceMap.keys()].sort((a, b) => a - b);

  for (const sentence of sortedSentences) {
    const charMap = sentenceMap.get(sentence)!;
    const groupChars = CARD_GROUPS[sentence];
    const stacks: CharStack[] = [];

    for (const gc of groupChars) {
      if (charMap.has(gc)) {
        stacks.push({ char: gc, cards: charMap.get(gc)! });
      }
    }

    groups.push({ sentence, stacks });
  }

  return groups;
}

// ============================================
// 获取卡牌颜色类名
// ============================================
function getCharColorClass(char: CardChar): string {
  if (RED_CHARS.includes(char)) return 'Red';
  if (GREEN_CHARS.includes(char)) return 'Green';
  return 'Black';
}

// ============================================
// 玩家信息组件
// ============================================
const PlayerInfo: React.FC<{
  player?: Player;
  isDealer: boolean;
  isCurrentTurn: boolean;
}> = ({ player, isDealer, isCurrentTurn }) => {
  if (!player) return null;

  return (
    <View className={styles.playerInfo}>
      <View className={styles.avatarWrap}>
        <View className={`${styles.avatar} ${isDealer ? styles.avatarDealer : styles.avatarNonDealer}`}>
          <Text>{isDealer ? '👑' : '👨‍🌾'}</Text>
        </View>
        <View className={styles.roleBadge}>
          <View className={`${styles.roleBadgeInner} ${isDealer ? styles.roleDealer : styles.roleNonDealer}`}>
            <Text>{isDealer ? '庄家' : '闲家'}</Text>
          </View>
        </View>
      </View>
      <View className={styles.playerDetail}>
        <View className={styles.playerNameRow}>
          <Text className={`${styles.playerName} ${isCurrentTurn ? styles.playerNameActive : ''}`}>
            {player.name}
          </Text>
          {player.piaoValue > 0 && (
            <View className={styles.piaoBadge}>
              <Text>飘{player.piaoValue}</Text>
            </View>
          )}
        </View>
        <View className={styles.playerStatsRow}>
          <View className={styles.handCountBadge}>
            <Text>{player.hand.length}张</Text>
          </View>
          <Text className={styles.playerScore}>{player.score}分</Text>
        </View>
      </View>
    </View>
  );
};

// ============================================
// AI 手牌渲染 (牌背)
// ============================================
const AIHandCards: React.FC<{
  hand: Card[];
  leftToRight: boolean;
  maxWidth: number;
}> = ({ hand, leftToRight, maxWidth }) => {
  if (hand.length === 0) return null;

  const totalWidth = (hand.length - 1) * AI_HAND_STACK_VISIBLE + MELD_CARD_W;
  const step = totalWidth <= maxWidth
    ? AI_HAND_STACK_VISIBLE
    : (maxWidth - MELD_CARD_W) / Math.max(hand.length - 1, 1);

  const containerWidth = Math.min(totalWidth, maxWidth);
  const containerHeight = MELD_CARD_H;

  return (
    <View style={{ position: 'relative', width: px2vw(containerWidth), height: px2vh(containerHeight) }}>
      {hand.map((_, i) => {
        const offset = leftToRight ? i * step : containerWidth - MELD_CARD_W - i * step;
        return (
          <View
            key={i}
            className={styles.aiCardBack}
            style={{ left: px2vw(offset) }}
          >
            <View className={styles.aiCardBackInner} />
          </View>
        );
      })}
    </View>
  );
};

// ============================================
// 组合牌渲染
// ============================================
const MeldCards: React.FC<{
  melds: { type: string; cards: Card[]; isJing: boolean }[];
  rightAlign?: boolean;
}> = ({ melds, rightAlign = false }) => {
  if (melds.length === 0) return null;

  const containerStyle: Record<string, string> = { display: 'flex', flexWrap: 'wrap', gap: px2vw(2) };
  if (rightAlign) containerStyle.justifyContent = 'flex-end';

  return (
    <View style={containerStyle}>
      {melds.map((meld, meldIdx) => {
        const groupWidth = (meld.cards.length - 1) * MELD_STACK_VISIBLE + MELD_CARD_W;
        const groupHeight = MELD_CARD_H;

        return (
          <View
            key={meldIdx}
            className={styles.meldGroup}
            style={{
              width: px2vw(groupWidth),
              height: px2vh(groupHeight),
            }}
          >
            {meld.cards.map((card, cardIdx) => {
              const colorClass = getCharColorClass(card.char);
              return (
                <View
                  key={card.id}
                  className={styles.meldCard}
                  style={{ left: px2vw(cardIdx * MELD_STACK_VISIBLE) }}
                >
                  <Text className={`${styles.meldCardChar} ${styles[`meldCardChar${colorClass}`]}`}>
                    {card.char}
                  </Text>
                </View>
              );
            })}
          </View>
        );
      })}
    </View>
  );
};

// ============================================
// 弃牌渲染
// ============================================
const DiscardCards: React.FC<{
  discards: Card[];
  lastDiscardId: number | null;
  rightAlign?: boolean;
}> = ({ discards, lastDiscardId, rightAlign = false }) => {
  if (discards.length === 0) return null;

  // 按行分组
  const rows: Card[][] = [];
  for (let i = 0; i < discards.length; i += MAX_DISCARD_PER_ROW) {
    rows.push(discards.slice(i, i + MAX_DISCARD_PER_ROW));
  }

  const containerStyle: Record<string, string> = {
    display: 'flex',
    flexDirection: 'column',
    gap: px2vh(0),
  };
  if (rightAlign) containerStyle.alignItems = 'flex-end';

  return (
    <View style={containerStyle}>
      {rows.map((row, rowIdx) => (
        <View key={rowIdx} style={{ display: 'flex', gap: px2vw(DISCARD_CARD_GAP) }}>
          {row.map((card) => {
            const colorClass = getCharColorClass(card.char);
            const isLast = card.id === lastDiscardId;
            return (
              <View
                key={card.id}
                className={`${styles.discardCard} ${isLast ? styles.discardCardLast : ''}`}
              >
                <Text className={`${styles.discardCardChar} ${styles[`discardCardChar${colorClass}`]}`}>
                  {card.char}
                </Text>
              </View>
            );
          })}
        </View>
      ))}
    </View>
  );
};

// ============================================
// 人类手牌渲染
// ============================================
const HumanHandCards: React.FC<{
  hand: Card[];
  selectedCardId: number | null;
  onCardClick: (cardId: number) => void;
  isTing: boolean;
}> = ({ hand, selectedCardId, onCardClick, isTing }) => {
  const sentenceGroups = useMemo(() => groupHandBySentence(hand), [hand]);

  if (sentenceGroups.length === 0) return null;

  // 计算最大堆叠数
  const maxStacks = Math.max(...sentenceGroups.map(sg => sg.stacks.length), 1);
  const totalH = (maxStacks - 1) * HAND_STACK_VISIBLE + HAND_CARD_H;

  return (
    <View className={styles.player1Hand} style={{ height: px2vh(totalH) }}>
      {sentenceGroups.map((sg, sgIdx) => {
        const sgHeight = (sg.stacks.length - 1) * HAND_STACK_VISIBLE + HAND_CARD_H;
        return (
          <View
            key={sg.sentence}
            className={styles.handSentenceGroup}
            style={{
              height: px2vh(sgHeight),
              marginRight: sgIdx < sentenceGroups.length - 1 ? px2vw(HAND_SENTENCE_GAP) : 0,
            }}
          >
            {sg.stacks.map((stack, stackIdx) => {
              const topOffset = stackIdx * HAND_STACK_VISIBLE;
              const isSelected = stack.cards.some(c => c.id === selectedCardId);
              const showCount = stack.cards.length > 1;

              return (
                <View
                  key={stack.char}
                  className={styles.handCardStack}
                  style={{ height: px2vh(HAND_CARD_H) }}
                  onClick={() => onCardClick(stack.cards[stack.cards.length - 1].id)}
                >
                  {stack.cards.map((card, cardIdx) => (
                    <View
                      key={card.id}
                      className={`${styles.handCard} ${isSelected && card.id === selectedCardId ? styles.handCardSelected : ''}`}
                      style={{
                        top: px2vh(topOffset),
                        zIndex: cardIdx + 1,
                      }}
                    >
                      <Text className={`${styles.handCardChar} ${styles[`handCardChar${getCharColorClass(card.char)}`]}`}>
                        {card.char}
                      </Text>
                    </View>
                  ))}
                  {showCount && (
                    <View className={styles.handCardCountBadge} style={{ top: px2vh(topOffset + 2) }}>
                      <Text>{stack.cards.length}</Text>
                    </View>
                  )}
                  {isTing && !showCount && (
                    <View className={styles.handCardTingBadge} style={{ top: px2vh(topOffset + 2) }} />
                  )}
                </View>
              );
            })}
          </View>
        );
      })}
    </View>
  );
};

// ============================================
// 主游戏组件
// ============================================
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

  // 玩家映射: miniapp store -> Flame 布局
  // store.players[0] = "我" (human) -> Flame player1 (bottom)
  // store.players[1] = "玩家1" (AI) -> Flame player0 (top-left)
  // store.players[2] = "玩家2" (AI) -> Flame player2 (top-right)
  const humanPlayer = store.players[0];
  const aiPlayer1 = store.players[1]; // 玩家1 - 左上
  const aiPlayer2 = store.players[2]; // 玩家2 - 右上

  const isMyTurn = store.currentPlayerIndex === 0 && store.phase === 'playing';

  const handleCardClick = (cardId: number) => {
    if (!isMyTurn) return;
    setSelectedCardId(cardId === selectedCardId ? null : cardId);
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

  // ============================================
  // 飘分阶段
  // ============================================
  if (store.isPiaoPhase) {
    const piaoPlayer = store.players[store.piaoCurrentPlayerIndex];
    return (
      <View className={styles.page}>
        <View className={styles.piaoPopup}>
          <View className={styles.piaoPanel}>
            <Text className={styles.piaoTitle}>选择飘分</Text>
            <Text className={styles.piaoPlayerName}>{piaoPlayer?.name}</Text>
            <Text className={styles.piaoSubtitle}>请选择本局飘分</Text>
            <View className={styles.piaoOptions}>
              {[
                { value: 0, label: '0', cls: styles.piaoBtn0 },
                { value: 5, label: '5', cls: styles.piaoBtn5 },
                { value: 10, label: '10', cls: styles.piaoBtn10 },
                { value: 20, label: '20', cls: styles.piaoBtn20 },
              ].map(({ value, label, cls }) => (
                <View
                  key={value}
                  className={`${styles.piaoBtn} ${cls}`}
                  onClick={() => store.setPiao(value)}
                >
                  <Text className={styles.piaoBtnText}>{value === 0 ? '不飘' : label}</Text>
                </View>
              ))}
            </View>
          </View>
        </View>
      </View>
    );
  }

  // ============================================
  // 主游戏界面
  // ============================================
  return (
    <View className={styles.page}>
      {/* 返回按钮 */}
      <View className={styles.backBtn} onClick={handleBack}>
        <Text className={styles.backBtnText}>←</Text>
      </View>

      {/* ====== Player 0 区域 (AI 玩家1 - 左上) ====== */}
      <View className={styles.player0Area}>
        <PlayerInfo
          player={aiPlayer1}
          isDealer={aiPlayer1?.isDealer ?? false}
          isCurrentTurn={store.currentPlayerIndex === 1}
        />
        <View className={styles.player0Hand}>
          <AIHandCards
            hand={aiPlayer1?.hand ?? []}
            leftToRight={true}
            maxWidth={LEFT_MAX_W}
          />
        </View>
        <View className={styles.player0Melds}>
          <MeldCards melds={aiPlayer1?.melds ?? []} />
        </View>
        <View className={styles.player0Discards}>
          <DiscardCards
            discards={aiPlayer1?.discards ?? []}
            lastDiscardId={store.lastDiscardPlayerId === 1 ? store.lastDiscard?.id ?? null : null}
          />
        </View>
      </View>

      {/* ====== Player 2 区域 (AI 玩家2 - 右上) ====== */}
      <View className={styles.player2Area}>
        <PlayerInfo
          player={aiPlayer2}
          isDealer={aiPlayer2?.isDealer ?? false}
          isCurrentTurn={store.currentPlayerIndex === 2}
        />
        <View className={styles.player2Hand}>
          <AIHandCards
            hand={aiPlayer2?.hand ?? []}
            leftToRight={false}
            maxWidth={RIGHT_MAX_W}
          />
        </View>
        <View className={styles.player2Melds}>
          <MeldCards melds={aiPlayer2?.melds ?? []} rightAlign />
        </View>
        <View className={styles.player2Discards}>
          <DiscardCards
            discards={aiPlayer2?.discards ?? []}
            lastDiscardId={store.lastDiscardPlayerId === 2 ? store.lastDiscard?.id ?? null : null}
            rightAlign
          />
        </View>
      </View>

      {/* ====== 中央区域 (牌堆 + 出牌) ====== */}
      <View className={styles.centerArea}>
        {/* 牌堆 */}
        {store.deck.length > 0 && (
          <View className={styles.deckStack}>
            {Array.from({ length: Math.min(Math.ceil(store.deck.length / 10), 10) }, (_, i) => (
              <View
                key={i}
                className={styles.deckCardLayer}
                style={{
                  left: px2vw(i * 2),
                  top: px2vh(i * 0.5),
                  opacity: 0.4 + (i / 10) * 0.6,
                  zIndex: i,
                }}
              />
            ))}
            <Text className={styles.deckCount}>{store.deck.length}</Text>
          </View>
        )}

        {/* 最后出的牌 (横向) */}
        {store.lastDiscard && (
          <View className={styles.playedCard}>
            <Text className={`${styles.playedCardChar} ${styles[`playedCardChar${getCharColorClass(store.lastDiscard.char)}`]}`}>
              {store.lastDiscard.char}
            </Text>
          </View>
        )}
      </View>

      {/* ====== Player 1 区域 (人类 我 - 底部) ====== */}
      <View className={styles.player1Area}>
        {/* 上方: 弃牌 + 组合牌 + 头像 (左侧) */}
        <View className={styles.player1TopRow}>
          <View className={styles.player1LeftCol}>
            <View className={styles.player1Discards}>
              <DiscardCards
                discards={humanPlayer?.discards ?? []}
                lastDiscardId={store.lastDiscardPlayerId === 0 ? store.lastDiscard?.id ?? null : null}
              />
            </View>
            <View className={styles.player1Melds}>
              <MeldCards melds={humanPlayer?.melds ?? []} />
            </View>
            <View className={styles.player1InfoWrap}>
              <View style={{ display: 'flex', alignItems: 'flex-start' }}>
                <PlayerInfo
                  player={humanPlayer}
                  isDealer={humanPlayer?.isDealer ?? false}
                  isCurrentTurn={store.currentPlayerIndex === 0}
                />
                {humanPlayer?.isTing && (
                  <View className={styles.tingBadge}>
                    <Text>听</Text>
                  </View>
                )}
              </View>
            </View>
          </View>
        </View>

        {/* 手牌 (居中底部) */}
        <View className={styles.player1HandWrap}>
          <HumanHandCards
            hand={humanPlayer?.hand ?? []}
            selectedCardId={selectedCardId}
            onCardClick={handleCardClick}
            isTing={humanPlayer?.isTing ?? false}
          />
        </View>
      </View>

      {/* ====== 操作按钮 ====== */}
      <View className={styles.actionButtonsArea}>
        {isMyTurn && selectedCardId !== null && (
          <View
            style={{
              padding: `0 ${px2vw(16)}`,
              height: px2vh(48),
              background: 'linear-gradient(135deg, #ffd700, #ff8c00)',
              borderRadius: px2vw(24),
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              boxShadow: `0 0 ${px2vw(12)} rgba(255, 215, 0, 0.4)`,
              marginBottom: px2vh(8),
            }}
            onClick={handleDiscard}
          >
            <Text style={{ fontSize: px2vw(24), fontWeight: 'bold', color: '#1a0a00' }}>出牌</Text>
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
      </View>

      {/* ====== 回合信息 (右下角) ====== */}
      <View className={styles.roundInfoArea}>
        <RoundInfo
          roundNumber={store.roundNumber}
          dealerName={store.players[store.dealerIndex]?.name || ''}
          showHuDisplay={store.showHuResult || store.showLiujuResult}
          isLastRound={store.roundNumber >= 8}
          countdown={0}
          onNextRound={() => store.nextRound()}
          onShowSettlement={() => store.nextRound()}
        />
      </View>

      {/* ====== 胡牌面板 ====== */}
      {store.showHuResult && store.huResult && (
        <View className={styles.huPanelOverlay}>
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
        </View>
      )}
    </View>
  );
};

export default Game;
