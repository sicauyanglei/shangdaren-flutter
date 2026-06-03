export interface Game {
  id: string;
  date: string;
  players: { id: number; name: string; finalScore: number }[];
  winnerId: number;
  totalRounds: number;
}
