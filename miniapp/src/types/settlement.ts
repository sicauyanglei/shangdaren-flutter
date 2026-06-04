export interface RoundRecord {
  roundNumber: number;
  winnerId: number;
  winnerName: string;
  method: string;
  huType: string;
  huCount: number;
  scoreChanges: { playerId: number; playerName: string; change: number }[];
}

export interface GameRecord {
  id: string;
  date: string;
  players: { id: number; name: string; finalScore: number }[];
  rounds: RoundRecord[];
  winnerId: number;
}
