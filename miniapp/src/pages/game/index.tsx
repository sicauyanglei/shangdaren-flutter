import React, { useEffect, useState, useMemo, useRef, useCallback } from 'react';
import { View, Text } from '@tarojs/components';
import Taro, { useRouter } from '@tarojs/taro';
import { useGameStore } from '../../store/gameStore';
import ActionButtons from '../../components/ActionButtons';
import RoundInfo from '../../components/RoundInfo';
import HuPanel from '../../components/HuPanel';
import SettlementScreen from '../../components/SettlementScreen';
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
const DECK_CARD_W = 160;
const DECK_CARD_H = 40;

const HAND_STACK_VISIBLE = 52;
const HAND_SENTENCE_GAP = 2;
const AI_HAND_STACK_VISIBLE = 15;
const MELD_STACK_VISIBLE = 17;
const DISCARD_CARD_GAP = 1;
const MAX_DISCARD_PER_ROW = 8;
const LEFT_MAX_W = 340;
const RIGHT_MAX_W = 280;

// 牌堆层数计算 (匹配 Flame _getDeckLayerCount)
function getDeckLayerCount(count: number): number {
  if (count >= 60) return 10;
  if (count >= 50) return 8;
  if (count >= 40) return 7;
  if (count >= 30) return 6;
  if (count >= 20) return 5;
  if (count >= 10) return 4;
  if (count >= 5) return 3;
  if (count > 0) return 2;
  return 0;
}

// 手牌最大堆叠数计算 (匹配 Flame _maxStackCount)
function maxStackCount(hand: Card[]): number {
  const sentenceGroups = groupHandBySentence(hand);
  if (sentenceGroups.length === 0) return 0;
  return Math.max(...sentenceGroups.map(sg => sg.stacks.length), 0);
}

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
// 倒计时组件 (匹配 Flame _CountdownTimer 铃铛形状)
// ============================================
const CountdownTimer: React.FC<{
  countdown: number;
  isWarning: boolean;
}> = ({ countdown, isWarning }) => {
  const ringColor = isWarning ? '#CCff5050' : '#99ffd700';
  const bellColor = isWarning ? '#CCff5050' : '#99ffd700';

  return (
    <View className={styles.countdownTimer} style={{ width: px2vw(36), height: px2vh(42) }}>
      {/* 铃铛顶部 */}
      <View
        className={styles.countdownBellTop}
        style={{
          width: px2vw(10),
          height: px2vh(6),
          background: bellColor,
          borderRadius: `${px2vw(2)} ${px2vw(2)} 0 0`,
        }}
      />
      {/* 铃铛环 */}
      <View
        className={styles.countdownRing}
        style={{
          width: px2vw(32),
          height: px2vw(32),
          border: `2px solid ${ringColor}`,
          borderRadius: '50%',
        }}
      />
      {/* 铃铛主体 (内圆) */}
      <View
        className={`${styles.countdownBody} ${isWarning ? styles.countdownWarning : styles.countdownNormal}`}
      >
        <Text className={`${styles.countdownNumber} ${isWarning ? styles.countdownNumberWarning : ''}`}>
          {countdown}
        </Text>
      </View>
    </View>
  );
};

// ============================================
// 胡数徽章 (匹配 Flame _MyPlayerInfo huCount badge)
// ============================================
const HuCountBadge: React.FC<{
  huCount: number;
}> = ({ huCount }) => {
  if (huCount <= 0) return null;
  return (
    <View className={styles.huCountBadge}>
      <Text className={styles.huCountBadgeText}>{huCount}胡</Text>
    </View>
  );
};

// ============================================
// 玩家信息组件
// ============================================
const PlayerInfo: React.FC<{
  player?: Player;
  isDealer: boolean;
  isCurrentTurn: boolean;
  countdown?: number;
  showCountdown?: boolean;
  onAvatarClick?: () => void;
  animatingScore?: number | null;
}> = ({ player, isDealer, isCurrentTurn, countdown = 14, showCountdown = false, onAvatarClick, animatingScore }) => {
  if (!player) return null;

  const isWarning = countdown <= 5;

  return (
    <View className={styles.playerInfo}>
      <View className={styles.avatarWrap}>
        <View
          className={`${styles.avatar} ${isDealer ? styles.avatarDealer : styles.avatarNonDealer}`}
          onClick={onAvatarClick}
        >
          <Text>{isDealer ? '👑' : '👨‍🌾'}</Text>
        </View>
        {/* 倒计时 */}
        {showCountdown && (
          <View className={styles.countdownTimerWrap}>
            <CountdownTimer countdown={countdown} isWarning={isWarning} />
          </View>
        )}
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
          <Text className={`${styles.playerScore} ${animatingScore != null ? styles.playerScoreHighlight : ''}`}>
            {animatingScore != null ? animatingScore : player.score}分
          </Text>
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
  onCardDoubleClick: (cardId: number) => void;
  isTing: boolean;
  hideTingBadge: boolean;
  newCardId: number | null;
}> = ({ hand, selectedCardId, onCardClick, onCardDoubleClick, isTing, hideTingBadge, newCardId }) => {
  const sentenceGroups = useMemo(() => groupHandBySentence(hand), [hand]);
  const lastClickRef = useRef<{ cardId: number; time: number } | null>(null);

  const handleClick = useCallback((cardId: number) => {
    const now = Date.now();
    if (lastClickRef.current && lastClickRef.current.cardId === cardId && now - lastClickRef.current.time < 300) {
      // 双击 -> 直接出牌
      onCardDoubleClick(cardId);
      lastClickRef.current = null;
    } else {
      // 单击 -> 选中
      onCardClick(cardId);
      lastClickRef.current = { cardId, time: now };
    }
  }, [onCardClick, onCardDoubleClick]);

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
              const isNewCard = newCardId !== null && stack.cards.some(c => c.id === newCardId);

              return (
                <View
                  key={stack.char}
                  className={styles.handCardStack}
                  style={{ height: px2vh(HAND_CARD_H) }}
                  onClick={() => handleClick(stack.cards[stack.cards.length - 1].id)}
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
                  {isTing && !hideTingBadge && !showCount && (
                    <View className={styles.handCardTingBadge} style={{ top: px2vh(topOffset + 2) }} />
                  )}
                  {/* 新牌标记 */}
                  {isNewCard && (
                    <View className={styles.newCardMarker} style={{ top: px2vh(topOffset) }}>
                      <Text className={styles.newCardMarkerText}>新</Text>
                    </View>
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
// 招牌选择弹窗 (匹配 Flame _ZhaoSelectionPopup)
// ============================================
const ZhaoSelectionPopup: React.FC<{
  candidates: string[];
  onSelect: (char: string) => void;
}> = ({ candidates, onSelect }) => {
  if (candidates.length === 0) return null;

  const jingChars = ['上', '福'];

  return (
    <View className={styles.zhaoPopup}>
      <View className={styles.zhaoPanel}>
        <Text className={styles.zhaoTitle}>选择招的字</Text>
        <Text className={styles.zhaoSubtitle}>请选择要招的字牌</Text>
        <View className={styles.zhaoOptions}>
          {candidates.map((char) => {
            const isJing = jingChars.includes(char);
            return (
              <View
                key={char}
                className={`${styles.zhaoCharBtn} ${isJing ? styles.zhaoCharBtnJing : styles.zhaoCharBtnNormal}`}
                onClick={() => onSelect(char)}
              >
                <Text className={`${styles.zhaoCharBtnText} ${isJing ? styles.zhaoCharBtnTextJing : ''}`}>
                  {char}
                </Text>
              </View>
            );
          })}
        </View>
      </View>
    </View>
  );
};

// ============================================
// 流局面板 (匹配 Flame LiujuOverlay)
// ============================================
const LiujuPanel: React.FC<{
  players: Player[];
  onClose: () => void;
}> = ({ players, onClose }) => {
  return (
    <View className={styles.liujuOverlay}>
      <View className={styles.liujuPanel}>
        <Text className={styles.liujuTitle}>流局</Text>
        <Text className={styles.liujuSubtitle}>牌堆已空，本局结束</Text>
        <Text className={styles.liujuNote}>庄家不变，继续坐庄</Text>

        {/* 玩家手牌展示 */}
        <View className={styles.liujuPlayers}>
          {players.map((player) => (
            <View key={player.id} className={styles.liujuPlayerRow}>
              <Text className={styles.liujuPlayerName}>{player.name}</Text>
              <View className={styles.liujuPlayerHand}>
                {player.hand.map((card) => {
                  const colorClass = getCharColorClass(card.char);
                  return (
                    <View key={card.id} className={styles.liujuCard}>
                      <Text className={`${styles.liujuCardChar} ${styles[`liujuCardChar${colorClass}`]}`}>
                        {card.char}
                      </Text>
                    </View>
                  );
                })}
              </View>
            </View>
          ))}
        </View>

        <View className={styles.liujuCloseBtn} onClick={onClose}>
          <Text className={styles.liujuCloseBtnText}>确定</Text>
        </View>
      </View>
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

  const isMyTurn = store.isMyTurn && store.phase === 'playing';

  // 人类玩家有待处理操作时显示倒计时
  const humanHasPendingActions = store.canChi || store.canPeng || store.canZhao || store.canHu || store.canZimo;

  const handleCardClick = (cardId: number) => {
    if (!isMyTurn) return;
    setSelectedCardId(cardId === selectedCardId ? null : cardId);
  };

  const handleCardDoubleClick = (cardId: number) => {
    if (!isMyTurn) return;
    store.discardCard(cardId);
    setSelectedCardId(null);
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

  const handleAvatarClick = () => {
    Taro.navigateTo({ url: '/pages/settings/index' });
  };

  // ============================================
  // 飘分阶段 - 只有人类玩家轮次才显示选择弹窗
  // ============================================
  const isHumanPiaoTurn = store.isPiaoPhase && store.players[store.piaoCurrentPlayerIndex]?.type === 'human';
  if (isHumanPiaoTurn) {
    return (
      <View className={styles.page}>
        <View className={styles.piaoPopup}>
          <View className={styles.piaoPanel}>
            <Text className={styles.piaoTitle}>选择飘分</Text>
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
          countdown={store.countdown}
          showCountdown={store.currentPlayerIndex === 1 && store.phase === 'playing'}
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
          countdown={store.countdown}
          showCountdown={store.currentPlayerIndex === 2 && store.phase === 'playing'}
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
        {/* 牌堆 (匹配 Flame _renderDeck + _renderDeckIndicator) */}
        {store.deck.length > 0 && (() => {
          const layerCount = getDeckLayerCount(store.deck.length);
          const deckScale = 0.5;
          const deckW = DECK_CARD_W * deckScale;
          const deckH = DECK_CARD_H * deckScale;
          return (
            <View
              className={styles.deckStack}
              style={{
                width: px2vw(deckW + (layerCount - 1) * 4 * deckScale),
                height: px2vh(deckH + (layerCount - 1) * 1 * deckScale),
              }}
            >
              {Array.from({ length: layerCount }, (_, i) => (
                <View
                  key={i}
                  className={styles.deckCardLayer}
                  style={{
                    width: px2vw(deckW),
                    height: px2vh(deckH),
                    left: px2vw(i * 4 * deckScale),
                    top: px2vh(i * 1 * deckScale),
                    opacity: 0.4 + (i / layerCount) * 0.6,
                    zIndex: i,
                  }}
                />
              ))}
              <Text className={styles.deckCount}>{store.deck.length}</Text>
            </View>
          );
        })()}

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
              <View className={styles.player1InfoRow}>
                <View style={{ position: 'relative' }}>
                  <PlayerInfo
                    player={humanPlayer}
                    isDealer={humanPlayer?.isDealer ?? false}
                    isCurrentTurn={store.currentPlayerIndex === 0}
                    countdown={store.countdown}
                    showCountdown={humanHasPendingActions}
                    onAvatarClick={handleAvatarClick}
                  />
                  {/* "胡"按钮徽章 - canHu && isDrawing 时显示，优先于huCount徽章 */}
                  {humanPlayer && store.canHu && store.newCardId !== null && (
                    <View className={styles.huBadgeWrap}>
                      <View className={styles.huBadge}>
                        <Text className={styles.huBadgeText}>胡</Text>
                      </View>
                    </View>
                  )}
                  {/* 胡数徽章 - 头像右上角，"胡"按钮不显示时才显示 */}
                  {humanPlayer && humanPlayer.huCount > 0 && !(store.canHu && store.newCardId !== null) && (
                    <View className={styles.huCountBadgeWrap}>
                      <HuCountBadge huCount={humanPlayer.huCount} />
                    </View>
                  )}
                </View>
                {/* 听牌徽章 - 在playerInfo旁边，不是里面 */}
                {humanPlayer?.isTing && !store.hideTingBadge && (
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
            onCardDoubleClick={handleCardDoubleClick}
            isTing={humanPlayer?.isTing ?? false}
            hideTingBadge={store.hideTingBadge}
            newCardId={store.newCardId}
          />
        </View>
      </View>

      {/* ====== 操作按钮 (匹配 Flame game_overlay.dart L138-185) ====== */}
      {(() => {
        // 动态计算按钮位置: bottom = designHeight - handTopY + 2
        const hand = humanPlayer?.hand ?? [];
        const msc = maxStackCount(hand);
        const totalH = msc === 0 ? HAND_CARD_H : (msc - 1) * HAND_STACK_VISIBLE + HAND_CARD_H;
        const handTopY = DH - totalH - 10;
        const btnBottom = DH - handTopY + 2;
        return (
          <View className={styles.actionButtonsArea} style={{ bottom: px2vh(btnBottom) }}>
            {isMyTurn && selectedCardId !== null && !store.isDrawing && !store.canChi && !store.canPeng && !store.canZhao && !store.canHu && !store.canZimo && (
              <View
                className={styles.discardBtn}
                onClick={handleDiscard}
              >
                <Text className={styles.discardBtnText}>出牌</Text>
              </View>
            )}
            <ActionButtons
              canChi={store.canChi}
              canPeng={store.canPeng}
              canZhao={store.canZhao}
              canHu={store.canHu && !store.isZimoOpportunity}
              canZimo={store.canHu && store.isZimoOpportunity}
              onChi={() => store.doAction({ playerId: 0, action: 'chi' })}
              onPeng={() => store.doAction({ playerId: 0, action: 'peng' })}
              onZhao={() => store.doAction({ playerId: 0, action: 'zhao' })}
              onHu={() => store.doAction({ playerId: 0, action: 'hu' })}
              onZimo={() => store.doAction({ playerId: 0, action: 'zimo' })}
              onPass={() => store.passAction()}
            />
          </View>
        );
      })()}

      {/* ====== 回合信息 (右下角) ====== */}
      <View className={styles.roundInfoArea}>
        <RoundInfo
          roundNumber={store.roundNumber}
          dealerName={store.players[store.dealerIndex]?.name || ''}
          showHuDisplay={store.showHuResult || store.showLiujuResult}
          isLastRound={store.roundNumber >= 8}
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

      {/* ====== 流局面板 ====== */}
      {store.showLiujuResult && (
        <LiujuPanel
          players={store.players}
          onClose={store.closeLiujuResult}
        />
      )}

      {/* ====== 招牌选择弹窗 ====== */}
      {store.showZhaoSelection && store.zhaoCandidates.length > 0 && (
        <ZhaoSelectionPopup
          candidates={store.zhaoCandidates}
          onSelect={store.selectZhaoCharacter}
        />
      )}

      {/* ====== 总结算界面 ====== */}
      {store.phase === 'settlement' && (
        <SettlementScreen
          players={store.players}
          roundResults={store.roundResults}
          onClose={() => {
            Taro.navigateBack();
          }}
        />
      )}
    </View>
  );
};

export default Game;
