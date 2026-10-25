/**
 * 上大人字牌联机服务器入口
 * - HTTP 8081：房间列表 / 详情查询
 * - WebSocket 8080：房间操作（加入/离开/准备）+ 3 人真人对战同步
 */
const { RoomManager } = require('./src/room/roomManager');
const { RoomService } = require('./src/room/roomService');
const { RoomSocketServer } = require('./src/room/roomsocket');

const HTTP_PORT = Number(process.env.HTTP_PORT || 8081);
const WS_PORT = Number(process.env.WS_PORT || 8080);

const roomManager = new RoomManager();
new RoomService(roomManager, HTTP_PORT);
new RoomSocketServer(roomManager, WS_PORT);

console.log('[shangdaren-server] 上大人联机服务器已启动');
console.log(`[shangdaren-server] 房间查询 HTTP  :${HTTP_PORT}  (GET /api/rooms)`);
console.log(`[shangdaren-server] 对战同步 WS    :${WS_PORT}`);
