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

// @ts-ignore - 通过SCSS $hand-card-w使用
const HAND_CARD_W = 65;  // 匹配 Flame handCardW=65.0
const HAND_CARD_H = 224;
const MELD_CARD_W = 34;
const MELD_CARD_H = 56;
const DECK_CARD_W = 160;
const DECK_CARD_H = 40;

const HAND_STACK_VISIBLE = 68;
const HAND_SENTENCE_GAP = 2;
// @ts-ignore - 通过SCSS $selected-offset-y使用
const SELECTED_OFFSET_Y = 28;  // 匹配 Flame selectedOffsetY=28.0
const AI_HAND_STACK_VISIBLE = 15;
const MELD_STACK_VISIBLE = 17;
const DISCARD_CARD_GAP = 1;
const MAX_DISCARD_PER_ROW = 8;
const LEFT_MAX_W = 340;
const RIGHT_MAX_W = 280;
const MELD_ROW_GAP = 0;
const MELD_TO_DISCARD_GAP = 1;
const AI_HAND_TO_MELD_GAP = 2;
const AI_HAND_TO_MELD_GAP_HU = 20;
const MELD_GROUP_GAP = 2;
const MAX_MELD_GROUPS_PER_ROW = 3;
// @ts-ignore - 通过SCSS $avatar-to-meld-gap使用
const AVATAR_TO_MELD_GAP = 6;  // 匹配 Flame avatarToMeldGap=6.0

// 胡牌时AI手牌显示参数（匹配Flame huAiHandCardW/H/StackVisible）
const HU_AI_HAND_CARD_W = 43.2;
const HU_AI_HAND_CARD_H = 179.2;
const HU_AI_HAND_STACK_VISIBLE = 35;
const HU_AI_HAND_SENTENCE_GAP = 0;

// 胡牌时组合牌显示参数
const HU_DISPLAY_CARD_W = 42;
const HU_DISPLAY_CARD_H = 68;
const HU_DISPLAY_STACK_VISIBLE = 20;
const HU_DISPLAY_GROUP_GAP = 2;

// Flame: 手牌startY = designHeight - totalH + 60 (手牌底部超出屏幕60px)
const HAND_BOTTOM_OVERHANG = 60;

// 胡牌面板分数飞动动画时长 (ms)
const SCORE_FLY_DURATION = 1500;

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
        // 匹配 Flame: charStack 按 card.position 排序
        const sortedCards = charMap.get(gc)!.sort((a, b) => a.position - b.position);
        stacks.push({ char: gc, cards: sortedCards });
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
// AI 手牌渲染 (牌背 - 正常游戏)
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
// AI 手牌渲染 (胡牌/流局时 - 明牌显示)
// 匹配Flame规则14: 宽度32.4px 高度134.4px, 同字叠放竖向可见偏移20px, 不同sentence组间距0px
// ============================================
const AIHandCardsHu: React.FC<{
  hand: Card[];
  leftToRight: boolean;
  maxWidth: number;
  highlightCardId?: number | null;
  highlightLabel?: string;
  highlightCard?: Card | null;
}> = ({ hand, leftToRight, highlightCardId, highlightLabel, highlightCard }) => {
  if (hand.length === 0) return null;

  // 匹配Flame: 如果高亮卡牌不在手牌中，添加进去并排序
  let cards = [...hand];
  if (highlightCard && highlightCardId != null && !cards.some(c => c.id === highlightCardId)) {
    cards.push(highlightCard);
    cards.sort((a, b) => {
      if (a.sentence !== b.sentence) return a.sentence - b.sentence;
      return a.position - b.position;
    });
  }

  // 按句分组 (匹配Flame _groupHandBySentenceForAI)
  const sentenceGroups = groupHandBySentence(cards);

  // 将高亮卡牌所在的stack移到句组最后（Y位置最大，视觉上在最下面）
  if (highlightCardId != null) {
    for (const sg of sentenceGroups) {
      const highlightIdx = sg.stacks.findIndex(s => s.cards.some(c => c.id === highlightCardId));
      if (highlightIdx >= 0 && highlightIdx < sg.stacks.length - 1) {
        const highlightStack = sg.stacks.splice(highlightIdx, 1)[0];
        sg.stacks.push(highlightStack);
      }
    }
  }

  const cw = HU_AI_HAND_CARD_W;
  const ch = HU_AI_HAND_CARD_H;
  const sv = HU_AI_HAND_STACK_VISIBLE;
  const gap = HU_AI_HAND_SENTENCE_GAP;

  // 计算最大高度
  const maxStacks = Math.max(...sentenceGroups.map(sg => sg.stacks.length), 1);
  const totalH = (maxStacks - 1) * sv + ch;
  const totalW = sentenceGroups.length * cw + (sentenceGroups.length - 1) * gap;

  return (
    <View style={{ position: 'relative', width: px2vw(totalW), height: px2vh(totalH) }}>
      {sentenceGroups.map((sg, sgIdx) => {
        const sgX = leftToRight ? sgIdx * (cw + gap) : totalW - (sgIdx + 1) * (cw + gap) + gap;
        return (
          <View key={sg.sentence} style={{ position: 'absolute', left: px2vw(sgX), top: 0, width: px2vw(cw) }}>
            {sg.stacks.map((stack, stackIdx) => {
              const isHighlight = highlightCardId != null && stack.cards.some(c => c.id === highlightCardId);
              // 高亮stack用最高zIndex，覆盖其他stack
              const stackZIndex = isHighlight ? sg.stacks.length + 10 : stackIdx + 1;
              // 所有stack正常层叠（marginTop=sv-ch），高亮stack的zIndex最高覆盖其他stack
              const marginTop = stackIdx === 0 ? 0 : px2vh(sv - ch);

              return (
                <View
                  key={stack.char}
                  style={{ position: 'relative', height: px2vh(ch), marginTop, zIndex: stackZIndex }}
                >
                  {stack.cards.map((card, cardIdx) => {
                    const colorClass = getCharColorClass(card.char);
                    const isCardHighlight = card.id === highlightCardId;
                    // 高亮卡牌zIndex最高，确保"炮"/"自摸"标签显示在最上面
                    const cardZIndex = isCardHighlight ? stack.cards.length + 1 : cardIdx + 1;
                    return (
                      <View
                        key={card.id}
                        className={styles.huAiHandCard}
                        style={{
                          position: 'absolute',
                          top: 0,
                          left: 0,
                          width: px2vw(cw),
                          height: px2vh(ch),
                          zIndex: cardZIndex,
                        }}
                      >
                        <Text className={`${styles.huAiHandCardChar} ${styles[`huAiHandCardChar${colorClass}`]}`}>
                          {card.char}
                        </Text>
                        {/* 点炮/自摸标签 */}
                        {isCardHighlight && highlightLabel && (
                          <Text className={styles.huCardLabel} style={{ zIndex: 100 }}>
                            {highlightLabel.split('').join('\n')}
                          </Text>
                        )}
                      </View>
                    );
                  })}
                  {/* 多张牌时显示数量角标 */}
                  {stack.cards.length > 1 && (
                    <View className={styles.huAiHandCountBadge}>
                      <Text className={styles.huAiHandCountBadgeText}>{stack.cards.length}</Text>
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
// 组合牌渲染
// ============================================
const MeldCards: React.FC<{
  melds: { type: string; cards: Card[]; isJing: boolean }[];
  rightAlign?: boolean;
  isHuDisplay?: boolean;
}> = ({ melds, rightAlign = false, isHuDisplay = false }) => {
  if (melds.length === 0) return null;

  const cw = isHuDisplay ? HU_DISPLAY_CARD_W : MELD_CARD_W;
  const ch = isHuDisplay ? HU_DISPLAY_CARD_H : MELD_CARD_H;
  const sv = isHuDisplay ? HU_DISPLAY_STACK_VISIBLE : MELD_STACK_VISIBLE;
  const groupGap = isHuDisplay ? HU_DISPLAY_GROUP_GAP : MELD_GROUP_GAP;

  // 按行分组，每行最多3组（匹配Flame MAX_MELD_GROUPS_PER_ROW=3）
  const rows: { type: string; cards: Card[]; isJing: boolean }[][] = [];
  let currentRow: { type: string; cards: Card[]; isJing: boolean }[] = [];
  for (const meld of melds) {
    currentRow.push(meld);
    if (currentRow.length >= MAX_MELD_GROUPS_PER_ROW) {
      rows.push(currentRow);
      currentRow = [];
    }
  }
  if (currentRow.length > 0) rows.push(currentRow);

  return (
    <View style={{ display: 'flex', flexDirection: 'column', gap: px2vh(MELD_ROW_GAP) }}>
      {rows.map((row, rowIdx) => {
        // Player2: 组合牌从右往左增长，行内组顺序反转
        const displayRow = rightAlign ? [...row].reverse() : row;
        const rowStyle: Record<string, string> = { display: 'flex', gap: px2vw(groupGap) };
        if (rightAlign) rowStyle.justifyContent = 'flex-end';

        return (
          <View key={rowIdx} style={rowStyle}>
            {displayRow.map((meld, meldIdx) => {
              const groupWidth = (meld.cards.length - 1) * sv + cw;
              const groupHeight = ch;

              // 句类型需要按position排序（红字在最左边）
              const sortedCards = meld.type === 'ju'
                ? [...meld.cards].sort((a, b) => a.position - b.position)
                : meld.cards;

              return (
                <View
                  key={meldIdx}
                  className={styles.meldGroup}
                  style={{
                    width: px2vw(groupWidth),
                    height: px2vh(groupHeight),
                  }}
                >
                  {sortedCards.map((card, cardIdx) => {
                    const colorClass = getCharColorClass(card.char);
                    return (
                      <View
                        key={card.id}
                        className={styles.meldCard}
                        style={{
                          left: px2vw(cardIdx * sv),
                          width: px2vw(cw),
                          height: px2vh(ch),
                        }}
                      >
                        <Text className={`${styles.meldCardChar} ${styles[`meldCardChar${colorClass}`]}`} style={{ fontSize: isHuDisplay ? px2vw(26) : undefined }}>
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
      {rows.map((row, rowIdx) => {
        // Player2: 弃牌从右往左排列，行内卡牌顺序反转
        const displayRow = rightAlign ? [...row].reverse() : row;
        return (
          <View key={rowIdx} style={{ display: 'flex', gap: px2vw(DISCARD_CARD_GAP), flexDirection: rightAlign ? 'row-reverse' : 'row' }}>
            {displayRow.map((card) => {
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
        );
      })}
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
  tingCards: Card[];
  hideTingBadge: boolean;
  newCardId: number | null;
  highlightCardId?: number | null;
  highlightLabel?: string;
}> = ({ hand, selectedCardId, onCardClick, onCardDoubleClick, isTing, tingCards, hideTingBadge, newCardId, highlightCardId, highlightLabel }) => {
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
                  {stack.cards.map((card, cardIdx) => {
                    const isCardHighlight = card.id === highlightCardId;
                    // 高亮卡牌zIndex最高，确保"炮"/"自摸"标签显示在最上面
                    const cardZIndex = isCardHighlight ? stack.cards.length + 1 : cardIdx + 1;
                    return (
                      <View
                        key={card.id}
                        className={`${styles.handCard} ${isSelected && card.id === selectedCardId ? styles.handCardSelected : ''}`}
                        style={{
                          top: px2vh(topOffset),
                          zIndex: cardZIndex,
                        }}
                      >
                        <Text className={`${styles.handCardChar} ${styles[`handCardChar${getCharColorClass(card.char)}`]}`}>
                          {card.char}
                        </Text>
                        {/* 点炮/自摸标签 */}
                        {isCardHighlight && highlightLabel && (
                          <Text className={styles.huCardLabelHuman} style={{ zIndex: 100 }}>
                            {highlightLabel.split('').join('\n')}
                          </Text>
                        )}
                      </View>
                    );
                  })}
                  {showCount && (
                    <View className={styles.handCardCountBadge} style={{ top: px2vh(topOffset + 2), fontSize: stack.cards.length >= 10 ? px2vw(20) : px2vw(28) }}>
                      <Text>{stack.cards.length}</Text>
                    </View>
                  )}
                  {isTing && !hideTingBadge && !showCount && tingCards.some(tc => tc.id === stack.cards[stack.cards.length - 1].id) && (
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
// 胡牌赢家徽章组件 (匹配Flame _renderPlayerHuBadges)
// ============================================
const HuBadges: React.FC<{
  badges: { text: string; isPrimary: boolean }[];
  position: 'player0' | 'player1' | 'player2';
}> = ({ badges, position }) => {
  if (badges.length === 0) return null;

  const badgeGap = 4;
  const padH = 10;
  const padV = 6;
  const fontSize = 18;
  const badgeH = fontSize + padV * 2;

  // 计算位置 (匹配Flame _renderPlayerHuBadges)
  let startX: number;
  let startY: number;
  const aiAvatarLeft = 9.6;
  const aiAvatarTop = 4.8;
  const aiAvatarH = 108;
  const myAvatarLeft = 10;
  const myAvatarBottom = 5;
  const avatarW = 250;
  const badgeGapFromAvatar = 10;

  if (position === 'player0') {
    // Player0 (AI左): 头像区域右边，与头像区域底部对齐
    startX = aiAvatarLeft + avatarW + badgeGapFromAvatar;
    startY = aiAvatarTop + aiAvatarH - badgeH;
  } else if (position === 'player1') {
    // Player1 (人类): 头像区域右边，与头像区域顶部对齐
    startX = myAvatarLeft + avatarW + badgeGapFromAvatar;
    startY = DH - myAvatarBottom - aiAvatarH;
  } else {
    // Player2 (AI右): 头像区域左边，与头像区域底部对齐
    // 需要计算总宽度来定位
    const totalW = badges.reduce((sum, b) => {
      // 估算宽度
      const textW = b.text.length * fontSize * 0.6 + padH * 2;
      return sum + textW;
    }, 0) + (badges.length - 1) * badgeGap;
    startX = DW - aiAvatarLeft - avatarW - totalW - badgeGapFromAvatar;
    startY = aiAvatarTop + aiAvatarH - badgeH;
  }

  return (
    <View style={{ position: 'absolute', left: px2vw(startX), top: px2vh(startY), display: 'flex', gap: px2vw(badgeGap), zIndex: 50 }}>
      {badges.map((badge, i) => {
        const isPrimary = badge.isPrimary;
        let bgGradient: string;
        let borderColor: string;
        let glowColor: string;

        if (isPrimary && badge.text === '自摸') {
          bgGradient = 'linear-gradient(135deg, #6a1b9a, #9c27b0)';
          borderColor = '#ffd700';
          glowColor = '#ce93d8';
        } else if (isPrimary && badge.text === '点炮') {
          bgGradient = 'linear-gradient(135deg, #e65100, #ff8f00)';
          borderColor = '#ffd700';
          glowColor = '#ffb74d';
        } else {
          bgGradient = 'linear-gradient(135deg, #c62828, #ef5350)';
          borderColor = '#ffd700';
          glowColor = '#ff6b6b';
        }

        return (
          <View
            key={i}
            className={styles.huBadge}
            style={{
              background: bgGradient,
              borderColor,
              boxShadow: `0 0 ${px2vw(8)} ${glowColor}80, 0 0 ${px2vw(3)} ${borderColor}66`,
            }}
          >
            <Text className={styles.huBadgeTextInner} style={{ fontSize: px2vw(fontSize), fontWeight: 900, color: '#fff', letterSpacing: px2vw(1) }}>
              {badge.text}
            </Text>
          </View>
        );
      })}
    </View>
  );
};

// ============================================
// 分数飞动动画组件
// ============================================
const ScoreFlyAnimation: React.FC<{
  scoreChanges: { playerId: number; change: number; isGain: boolean }[];
  onComplete: () => void;
}> = ({ scoreChanges, onComplete }) => {
  const [elapsed, setElapsed] = useState(0);
  const animRef = useRef<number | null>(null);
  const startTimeRef = useRef<number>(Date.now());

  useEffect(() => {
    const tick = () => {
      const now = Date.now();
      const dt = now - startTimeRef.current;
      setElapsed(dt);
      if (dt < SCORE_FLY_DURATION) {
        animRef.current = requestAnimationFrame(tick);
      } else {
        onComplete();
      }
    };
    animRef.current = requestAnimationFrame(tick);
    return () => {
      if (animRef.current != null) cancelAnimationFrame(animRef.current);
    };
  }, []);

  // 计算各玩家头像分数位置 (匹配Flame avatarScoreX/Y)
  const avatarPositions = [
    { x: 9.6 + 20 + 80 + 12 + 60 + 8 + 25, y: 4.8 + 14 + 24 + 4 },       // Player0 (AI左)
    { x: 10 + 20 + 80 + 12 + 60 + 8 + 25, y: DH - 5 - 14 - 24 - 4 - 20 }, // Player1 (人类)
    { x: DW - 9.6 - 20 - 60 - 8 - 25, y: 4.8 + 14 + 24 + 4 },              // Player2 (AI右)
  ];

  // 胡牌面板分数位置 (简化: 面板中央)
  const panelCenterX = DW / 2;
  const panelCenterY = 300;

  const t = Math.min(elapsed / SCORE_FLY_DURATION, 1);
  // easeInOutCubic
  const eased = t < 0.5 ? 4 * t * t * t : 1 - Math.pow(-2 * t + 2, 3) / 2;

  return (
    <View style={{ position: 'fixed', top: 0, left: 0, width: '100vw', height: '100vh', pointerEvents: 'none', zIndex: 300 }}>
      {scoreChanges.map((sc, idx) => {
        const fromX = panelCenterX;
        const fromY = panelCenterY;
        const toX = avatarPositions[sc.playerId].x;
        const toY = avatarPositions[sc.playerId].y;

        const curX = fromX + (toX - fromX) * eased;
        const curY = fromY + (toY - fromY) * eased;

        const text = sc.isGain ? `+${sc.change}` : `${sc.change}`;
        const color = sc.isGain ? '#ffd700' : '#ff6b6b';
        const fontSize = t >= 1 ? 20 : 36;
        const alpha = t >= 1 ? Math.max(0, 1 - (elapsed / SCORE_FLY_DURATION - 1) * 3) : 1;

        return (
          <Text
            key={idx}
            style={{
              position: 'absolute',
              left: px2vw(curX),
              top: px2vh(curY),
              fontSize: px2vw(fontSize),
              fontWeight: 'bold',
              color,
              opacity: alpha,
              textShadow: `0 0 ${px2vw(12)} ${color}99, 0 0 ${px2vw(4)} rgba(0,0,0,0.5)`,
              transform: 'translate(-50%, -50%)',
              whiteSpace: 'nowrap',
            }}
          >
            {text}
          </Text>
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
  const [scoreFlyPlayed, setScoreFlyPlayed] = useState(false);

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

  // 是否处于胡牌/流局显示状态
  const isHuDisplay = store.showHuResult || store.showLiujuResult;

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

  // 胡牌时确定高亮卡牌和标签
  const huResult = store.huResult;
  const isDianpao = huResult?.method === 'dianpao';
  const isZimo = huResult?.method === 'zimo';
  const huCardId = huResult?.huCard?.id;
  const huLabel = isDianpao ? '炮' : isZimo ? '自摸' : undefined;

  // 胡牌时赢家徽章数据
  const winnerBadges = useMemo(() => {
    if (!store.showHuResult || !huResult) return { player0: [], player1: [], player2: [] };
    const badges: { player0: { text: string; isPrimary: boolean }[]; player1: { text: string; isPrimary: boolean }[]; player2: { text: string; isPrimary: boolean }[] } = { player0: [], player1: [], player2: [] };
    const winnerId = huResult.winnerId;
    // 赢家徽章
    const winnerBadgesList: { text: string; isPrimary: boolean }[] = [];
    if (isZimo) winnerBadgesList.push({ text: '自摸', isPrimary: true });
    winnerBadgesList.push({ text: huResult.huType, isPrimary: false });

    if (winnerId === 1) badges.player0 = winnerBadgesList;
    else if (winnerId === 0) badges.player1 = winnerBadgesList;
    else badges.player2 = winnerBadgesList;

    // 点炮者徽章
    if (isDianpao && huResult.dianpaoPlayerId != null) {
      const dpBadges = [{ text: '点炮', isPrimary: true }];
      const dpId = huResult.dianpaoPlayerId;
      if (dpId === 1) badges.player0 = [...badges.player0, ...dpBadges];
      else if (dpId === 0) badges.player1 = [...badges.player1, ...dpBadges];
      else badges.player2 = [...badges.player2, ...dpBadges];
    }

    return badges;
  }, [store.showHuResult, huResult]);

  // 分数飞动动画数据
  const scoreFlyData = useMemo(() => {
    if (!store.showHuResult || !huResult) return [];
    return huResult.scoreChanges
      .map((change, idx) => ({ playerId: idx, change: Math.abs(change), isGain: change > 0 }))
      .filter(sc => sc.change > 0);
  }, [store.showHuResult, huResult]);

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
          showCountdown={store.currentPlayerIndex === 1 && !store.isMyTurn && !store.waitingForResponse && store.phase === 'playing' && store.countdown > 0}
        />
        <View className={styles.player0Hand}>
          {isHuDisplay ? (
            <AIHandCardsHu
              hand={aiPlayer1?.hand ?? []}
              leftToRight={true}
              maxWidth={LEFT_MAX_W}
              highlightCardId={isHuDisplay && huResult?.winnerId === 1 ? huCardId : null}
              highlightLabel={isHuDisplay && huResult?.winnerId === 1 ? huLabel : undefined}
              highlightCard={isHuDisplay && huResult?.winnerId === 1 ? huResult?.huCard : null}
            />
          ) : (
            <AIHandCards
              hand={aiPlayer1?.hand ?? []}
              leftToRight={true}
              maxWidth={LEFT_MAX_W}
            />
          )}
        </View>
        <View className={styles.player0Melds} style={{ marginTop: px2vh(isHuDisplay ? AI_HAND_TO_MELD_GAP_HU : AI_HAND_TO_MELD_GAP) }}>
          <MeldCards melds={aiPlayer1?.melds ?? []} isHuDisplay={isHuDisplay} />
        </View>
        <View className={styles.player0Discards}>
          <DiscardCards
            discards={aiPlayer1?.discards ?? []}
            lastDiscardId={store.lastDiscardPlayerId === 1 ? store.lastDiscard?.id ?? null : null}
          />
        </View>
        {/* Player0 赢家徽章 */}
        {winnerBadges.player0.length > 0 && (
          <HuBadges badges={winnerBadges.player0} position="player0" />
        )}
      </View>

      {/* ====== Player 2 区域 (AI 玩家2 - 右上) ====== */}
      <View className={styles.player2Area}>
        <PlayerInfo
          player={aiPlayer2}
          isDealer={aiPlayer2?.isDealer ?? false}
          isCurrentTurn={store.currentPlayerIndex === 2}
          countdown={store.countdown}
          showCountdown={store.currentPlayerIndex === 2 && !store.isMyTurn && !store.waitingForResponse && store.phase === 'playing' && store.countdown > 0}
        />
        <View className={styles.player2Hand}>
          {isHuDisplay ? (
            <AIHandCardsHu
              hand={aiPlayer2?.hand ?? []}
              leftToRight={false}
              maxWidth={RIGHT_MAX_W}
              highlightCardId={isHuDisplay && huResult?.winnerId === 2 ? huCardId : null}
              highlightLabel={isHuDisplay && huResult?.winnerId === 2 ? huLabel : undefined}
              highlightCard={isHuDisplay && huResult?.winnerId === 2 ? huResult?.huCard : null}
            />
          ) : (
            <AIHandCards
              hand={aiPlayer2?.hand ?? []}
              leftToRight={false}
              maxWidth={RIGHT_MAX_W}
            />
          )}
        </View>
        <View className={styles.player2Melds} style={{ marginTop: px2vh(isHuDisplay ? AI_HAND_TO_MELD_GAP_HU : AI_HAND_TO_MELD_GAP) }}>
          <MeldCards melds={aiPlayer2?.melds ?? []} rightAlign isHuDisplay={isHuDisplay} />
        </View>
        <View className={styles.player2Discards}>
          <DiscardCards
            discards={aiPlayer2?.discards ?? []}
            lastDiscardId={store.lastDiscardPlayerId === 2 ? store.lastDiscard?.id ?? null : null}
            rightAlign
          />
        </View>
        {/* Player2 赢家徽章 */}
        {winnerBadges.player2.length > 0 && (
          <HuBadges badges={winnerBadges.player2} position="player2" />
        )}
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

        {/* 最后出的牌 (横向) - 点炮胡牌显示时不显示中央出牌 (匹配Flame) */}
        {store.lastDiscard && !(isHuDisplay && isDianpao) && (
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
            <View className={styles.player1Melds} style={{ marginTop: px2vh(isHuDisplay ? AI_HAND_TO_MELD_GAP_HU : MELD_TO_DISCARD_GAP) }}>
              <MeldCards melds={humanPlayer?.melds ?? []} isHuDisplay={isHuDisplay} />
            </View>
            <View className={styles.player1InfoWrap}>
              <View className={styles.player1InfoRow}>
                <View style={{ position: 'relative' }}>
                  <PlayerInfo
                    player={humanPlayer}
                    isDealer={humanPlayer?.isDealer ?? false}
                    isCurrentTurn={store.currentPlayerIndex === 0}
                    countdown={store.countdown}
                    showCountdown={(store.isMyTurn || store.waitingForResponse) && store.countdown > 0}
                    onAvatarClick={handleAvatarClick}
                  />
                  {/* "胡"按钮徽章 - canHu && isDrawing 时显示，优先于huCount徽章 (匹配Flame) */}
                  {humanPlayer && store.canHu && store.isDrawing && (
                    <View className={styles.huBadgeWrap}>
                      <View className={styles.huBadge}>
                        <Text className={styles.huBadgeText}>胡</Text>
                      </View>
                    </View>
                  )}
                  {/* 胡数徽章 - 头像右上角，"胡"按钮不显示时才显示 */}
                  {humanPlayer && humanPlayer.huCount > 0 && !(store.canHu && store.isDrawing) && (
                    <View className={styles.huCountBadgeWrap}>
                      <HuCountBadge huCount={humanPlayer.huCount} />
                    </View>
                  )}
                </View>
                {/* 听牌徽章 - 在playerInfo旁边，不是里面 */}
                {humanPlayer?.isTing && !store.hideTingBadge && !isHuDisplay && (
                  <View className={styles.tingBadge}>
                    <Text>听</Text>
                  </View>
                )}
              </View>
            </View>
          </View>
        </View>

        {/* 手牌 (居中底部) - Flame: startY = designHeight - totalH + 60, 手牌底部超出屏幕60px */}
        <View className={styles.player1HandWrap}>
          <HumanHandCards
            hand={humanPlayer?.hand ?? []}
            selectedCardId={selectedCardId}
            onCardClick={handleCardClick}
            onCardDoubleClick={handleCardDoubleClick}
            isTing={humanPlayer?.isTing ?? false}
            tingCards={humanPlayer?.tingCards ?? []}
            hideTingBadge={store.hideTingBadge}
            newCardId={store.newCardId}
            highlightCardId={isHuDisplay && huResult?.winnerId === 0 ? huCardId : null}
            highlightLabel={isHuDisplay && huResult?.winnerId === 0 ? huLabel : undefined}
          />
        </View>
        {/* Player1 (人类) 赢家徽章 */}
        {winnerBadges.player1.length > 0 && (
          <HuBadges badges={winnerBadges.player1} position="player1" />
        )}
      </View>

      {/* ====== 操作按钮 (匹配 Flame game_overlay.dart L138-185) ====== */}
      {(() => {
        // 动态计算按钮位置: bottom = designHeight - handTopY + 2
        // Flame: handTopY = DH - totalH + 60 (手牌底部超出屏幕60px)
        const hand = humanPlayer?.hand ?? [];
        const msc = maxStackCount(hand);
        const totalH = msc === 0 ? HAND_CARD_H : (msc - 1) * HAND_STACK_VISIBLE + HAND_CARD_H;
        const handTopY = DH - totalH + HAND_BOTTOM_OVERHANG;
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
            winnerHand={store.huResult.winnerHand}
            winnerMelds={store.huResult.winnerMelds}
            huCard={store.huResult.huCard}
            loserHands={store.huResult.loserHands}
            onClose={store.closeHuResult}
          />
        </View>
      )}

      {/* ====== 分数飞动动画 (胡牌面板首次显示时执行一次) ====== */}
      {store.showHuResult && scoreFlyData.length > 0 && !scoreFlyPlayed && (
        <ScoreFlyAnimation
          scoreChanges={scoreFlyData}
          onComplete={() => setScoreFlyPlayed(true)}
        />
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
