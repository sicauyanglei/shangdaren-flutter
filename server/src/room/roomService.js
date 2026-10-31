/**
 * 房间 HTTP 查询服务（默认端口 8081）
 * 提供牌桌列表 / 详情只读查询；加入、离开、准备等操作
 * 需要推送能力，统一走 WebSocket（端口 8080）执行。
 */
const http = require('http');

class RoomService {
  /**
   * @param {import('./roomManager').RoomManager} roomManager
   * @param {number} port
   * @param {import('http').Server} [sharedServer] 云端单端口模式：复用外部
   *   http server（与 WebSocket 共端口），此时不自行 listen
   */
  constructor(roomManager, port = 8081, sharedServer) {
    this.roomManager = roomManager;
    this.port = port;
    if (sharedServer) {
      this.server = sharedServer;
      sharedServer.on('request', (req, res) => this._handle(req, res));
    } else {
      this.server = http.createServer((req, res) => this._handle(req, res));
      this.server.listen(port);
    }
  }

  _json(res, status, body) {
    res.writeHead(status, {
      'Content-Type': 'application/json; charset=utf-8',
      'Access-Control-Allow-Origin': '*',
    });
    res.end(JSON.stringify(body));
  }

  _handle(req, res) {
    const url = new URL(req.url, `http://${req.headers.host || 'localhost'}`);
    const path = url.pathname;

    if (req.method === 'GET' && path === '/api/rooms') {
      return this._json(res, 200, {
        success: true,
        rooms: this.roomManager.getAllRooms(),
      });
    }

    let m = path.match(/^\/api\/rooms\/(\d+)$/);
    if (req.method === 'GET' && m) {
      const room = this.roomManager.getRoom(Number(m[1]));
      if (!room) return this._json(res, 404, { success: false, message: '房间不存在' });
      return this._json(res, 200, { success: true, room: this.roomManager.publicRoom(room) });
    }

    m = path.match(/^\/api\/rooms\/(\d+)\/(join|leave|ready)$/);
    if (req.method === 'POST' && m) {
      return this._json(res, 501, {
        success: false,
        message: '房间操作需要实时推送，请通过 WebSocket 连接（端口 8080）执行',
      });
    }

    this._json(res, 404, { success: false, message: '接口不存在' });
  }
}

module.exports = { RoomService };
