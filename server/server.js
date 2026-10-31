/**
 * 上大人字牌联机服务器入口
 *
 * 两种运行模式：
 * 1. 本地双端口（默认）：HTTP 8081 房间查询 + WS 8080 对战同步
 * 2. 云端单端口：设置 PORT 环境变量（如 Render/Railway 平台自动注入），
 *    HTTP 查询与 WS 对战同步共用同一端口，适配云平台只暴露一个端口的限制
 */
const http = require('http');
const { RoomManager } = require('./src/room/roomManager');
const { RoomService } = require('./src/room/roomService');
const { RoomSocketServer } = require('./src/room/roomsocket');

const CLOUD_PORT = Number(process.env.PORT || 0);

const roomManager = new RoomManager();

if (CLOUD_PORT > 0) {
  // 云端单端口模式：先建 http server 挂 HTTP 查询，再让 WS 复用其 upgrade
  const sharedServer = http.createServer();
  sharedServer.listen(CLOUD_PORT);
  new RoomService(roomManager, CLOUD_PORT, sharedServer);
  new RoomSocketServer(roomManager, CLOUD_PORT, sharedServer);
  console.log(`[shangdaren-server] 云端单端口模式   :${CLOUD_PORT}  (HTTP 查询 + WS 对战同步)`);
} else {
  const HTTP_PORT = Number(process.env.HTTP_PORT || 8081);
  const WS_PORT = Number(process.env.WS_PORT || 8080);
  new RoomService(roomManager, HTTP_PORT);
  new RoomSocketServer(roomManager, WS_PORT);
  console.log(`[shangdaren-server] 房间查询 HTTP  :${HTTP_PORT}  (GET /api/rooms)`);
  console.log(`[shangdaren-server] 对战同步 WS    :${WS_PORT}`);
}

console.log('[shangdaren-server] 上大人联机服务器已启动');
