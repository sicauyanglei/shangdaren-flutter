---
name: "multiplayer-room"
description: "Manages multi-table game rooms: 100 tables, 3 players each, ready status tracking, auto-start when all ready. Invoke when implementing/updating multiplayer room system."
---

# Multiplayer Room Management

管理100张牌桌的多人游戏系统，每桌3人，支持玩家准备状态和自动开始游戏。

## 核心数据结构

### Room（房间/牌桌）

```typescript
interface Room {
  id: number;           // 牌桌ID (1-100)
  players: Player[];    // 当前玩家列表（最多3人）
  status: 'waiting' | 'ready' | 'playing';
  createdAt: number;
}

interface Player {
  id: string;
  name: string;
  ready: boolean;      // 是否已准备
  seatIndex: number;   // 座位号 (0, 1, 2)
}
```

## 核心逻辑

### 1. 加入牌桌

- 玩家选择牌桌ID (1-100)
- 如果牌桌人数 < 3，则加入该牌桌
- 如果牌桌已满（3人），拒绝加入
- 如果牌桌正在游戏中，拒绝加入

### 2. 准备状态

- 玩家点击"准备"按钮切换准备状态
- 已准备玩家显示特殊标识
- 玩家可以取消准备

### 3. 开始游戏条件

**当满足以下条件时，自动开始游戏：**
- 牌桌有 exactly 3 名玩家
- 3 名玩家都已准备（ready === true）
- 牌桌状态从 'ready' 变为 'playing'

### 4. 离开牌桌

- 游戏中不可离开
- 等待中可离开
- 离开后更新牌桌状态和玩家列表

## 文件位置

```
src/
├── room/
│   ├── roomManager.ts    # 牌桌管理器（核心）
│   ├── roomService.ts    # 牌桌服务（HTTP接口）
│   ├── roomtypes.ts      # 类型定义
│   └── roomsocket.ts     # 牌桌WebSocket处理
```

## API 设计

### HTTP API

| 方法 | 路径 | 描述 |
|------|------|------|
| GET | /api/rooms | 获取所有牌桌列表及状态 |
| GET | /api/rooms/:id | 获取指定牌桌详情 |
| POST | /api/rooms/:id/join | 加入牌桌 |
| POST | /api/rooms/:id/leave | 离开牌桌 |
| POST | /api/rooms/:id/ready | 切换准备状态 |

### WebSocket 事件

| 事件名 | 方向 | 描述 |
|--------|------|------|
| room:update | Server→Client | 牌桌状态更新 |
| room:player:joined | Server→Client | 玩家加入 |
| room:player:left | Server→Client | 玩家离开 |
| room:player:ready | Server→Client | 玩家准备状态变化 |
| room:game:start | Server→Client | 游戏开始 |
| room:join | Client→Server | 请求加入牌桌 |
| room:leave | Client→Server | 请求离开牌桌 |
| room:ready | Client→Server | 切换准备状态 |

## 实现要点

### RoomManager 核心方法

```typescript
class RoomManager {
  private rooms: Map<number, Room>;

  createRoom(id: number): Room;
  getRoom(id: number): Room | undefined;
  getAllRooms(): Room[];
  joinRoom(roomId: number, player: Player): { success: boolean; message: string };
  leaveRoom(roomId: number, playerId: string): { success: boolean; message: string };
  toggleReady(roomId: number, playerId: string): { success: boolean; ready: boolean };
  checkAndStartGame(roomId: number): boolean; // 返回是否成功开始游戏
  removePlayerFromRoom(playerId: string): void;
}
```

### 自动开始游戏检测

```typescript
checkAndStartGame(roomId: number): boolean {
  const room = this.rooms.get(roomId);
  if (!room) return false;

  // 必须正好3人
  if (room.players.length !== 3) return false;

  // 必须所有人都准备好
  const allReady = room.players.every(p => p.ready);
  if (!allReady) return false;

  // 开始游戏
  room.status = 'playing';
  this.emit('room:game:start', { roomId, players: room.players });
  return true;
}
```

## 数据库模型（可选）

如果使用数据库持久化：

```sql
CREATE TABLE rooms (
  id INT PRIMARY KEY,
  status ENUM('waiting', 'ready', 'playing') DEFAULT 'waiting',
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE room_players (
  room_id INT,
  player_id VARCHAR(64),
  player_name VARCHAR(64),
  ready BOOLEAN DEFAULT FALSE,
  seat_index INT,
  joined_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (room_id, player_id)
);
```

## 前端集成

### 牌桌列表页面

- 显示100个牌桌的缩略信息
- 每个牌桌显示：ID、人数(0/3, 1/3, 2/3, 3/3)、状态（等待中/已开局）
- 点击牌桌进入牌桌详情页

### 牌桌详情页

- 显示牌桌内3个座位
- 每个座位显示：玩家名称、准备状态
- 准备按钮（等待状态时可见）
- 开始游戏提示（3人全准备后自动开始）
