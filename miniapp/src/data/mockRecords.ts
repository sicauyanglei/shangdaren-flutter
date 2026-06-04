import { GameRecord, RoundRecord } from '../types/settlement';

export const mockGameRecords: GameRecord[] = [
  {
    id: '1',
    date: '2026-06-01',
    players: [
      { id: 0, name: '我', finalScore: 120 },
      { id: 1, name: '玩家1', finalScore: -30 },
      { id: 2, name: '玩家2', finalScore: -90 },
    ],
    winnerId: 0,
    rounds: [
      { roundNumber: 1, winnerId: 0, winnerName: '我', method: '自摸', huType: '普通胡', huCount: 14, scoreChanges: [{ playerId: 0, playerName: '我', change: 60 }, { playerId: 1, playerName: '玩家1', change: -30 }, { playerId: 2, playerName: '玩家2', change: -30 }] },
      { roundNumber: 2, winnerId: 1, winnerName: '玩家1', method: '点炮', huType: '十对', huCount: 22, scoreChanges: [{ playerId: 0, playerName: '我', change: -40 }, { playerId: 1, playerName: '玩家1', change: 40 }, { playerId: 2, playerName: '玩家2', change: 0 }] },
    ],
    totalRounds: 8,
  },
  {
    id: '2',
    date: '2026-05-30',
    players: [
      { id: 0, name: '我', finalScore: -50 },
      { id: 1, name: '玩家1', finalScore: 80 },
      { id: 2, name: '玩家2', finalScore: -30 },
    ],
    winnerId: 1,
    rounds: [
      { roundNumber: 1, winnerId: 1, winnerName: '玩家1', method: '自摸', huType: '红元', huCount: 28, scoreChanges: [{ playerId: 0, playerName: '我', change: -35 }, { playerId: 1, playerName: '玩家1', change: 80 }, { playerId: 2, playerName: '玩家2', change: -45 }] },
    ],
    totalRounds: 8,
  },
  {
    id: '3',
    date: '2026-05-28',
    players: [
      { id: 0, name: '我', finalScore: 200 },
      { id: 1, name: '玩家1', finalScore: -100 },
      { id: 2, name: '玩家2', finalScore: -100 },
    ],
    winnerId: 0,
    rounds: [
      { roundNumber: 1, winnerId: 0, winnerName: '我', method: '自摸', huType: '清枯重台', huCount: 36, scoreChanges: [{ playerId: 0, playerName: '我', change: 200 }, { playerId: 1, playerName: '玩家1', change: -100 }, { playerId: 2, playerName: '玩家2', change: -100 }] },
    ],
    totalRounds: 8,
  },
];
