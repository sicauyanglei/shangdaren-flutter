import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../network/game_sync_manager.dart';

/// 联机大厅：连接服务器 → 房间列表 → 加入房间 → 准备 → 3人准备后自动开局
class LobbyScreen extends StatefulWidget {
  final GameSyncManager sync;
  final VoidCallback? onClose;
  final VoidCallback? onGameStarting;

  const LobbyScreen({
    super.key,
    required this.sync,
    this.onClose,
    this.onGameStarting,
  });

  @override
  State<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends State<LobbyScreen> implements LobbyDelegate {
  static const _prefsUrlKey = 'online_server_url';
  static const _defaultUrl = 'ws://192.168.1.100:8080';

  final _urlController = TextEditingController(text: _defaultUrl);
  final _nameController = TextEditingController();
  final _roomInputController = TextEditingController();

  bool _connecting = false;
  List<OnlineRoomInfo> _rooms = const [];
  OnlineRoomInfo? _currentRoom;
  int? _mySeat;
  String _statusMessage = '';

  GameSyncManager get _sync => widget.sync;
  bool get _connected => _sync.isConnected;

  @override
  void initState() {
    super.initState();
    _sync.lobby = this;
    _nameController.text = _sync.playerName;
    _mySeat = _sync.mySeat;
    _loadSavedUrl();
    if (_connected) {
      _sync.requestRoomList();
    }
  }

  @override
  void dispose() {
    _sync.lobby = null;
    _urlController.dispose();
    _nameController.dispose();
    _roomInputController.dispose();
    super.dispose();
  }

  Future<void> _loadSavedUrl() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_prefsUrlKey);
      if (!mounted || saved == null || saved.isEmpty) return;
      setState(() => _urlController.text = saved);
    } catch (_) {}
  }

  /* ------------------------- 大厅委托事件 ------------------------- */

  @override
  void onRoomList(List<OnlineRoomInfo> rooms) {
    if (!mounted) return;
    setState(() {
      _rooms = rooms;
      final roomId = _sync.roomId;
      if (roomId == null) {
        _currentRoom = null;
      } else {
        for (final r in rooms) {
          if (r.id == roomId) {
            _currentRoom = r;
            break;
          }
        }
      }
    });
  }

  @override
  void onRoomJoined(OnlineRoomInfo room, int mySeat) {
    if (!mounted) return;
    setState(() {
      _currentRoom = room;
      _mySeat = mySeat;
      _statusMessage = '';
    });
  }

  @override
  void onRoomJoinFailed(String message) {
    if (!mounted) return;
    setState(() => _statusMessage = message);
  }

  @override
  void onRoomLeft() {
    if (!mounted) return;
    setState(() {
      _currentRoom = null;
      _mySeat = null;
    });
  }

  @override
  void onRoomUpdated(OnlineRoomInfo room) {
    if (!mounted) return;
    setState(() {
      if (_sync.inRoom && room.id == _sync.roomId) {
        _currentRoom = room;
      }
    });
  }

  @override
  void onGameStarting(int dealerSeat) {
    // 3人全部准备，对局即将开始（由宿主 State 切换到对局界面）
    widget.onGameStarting?.call();
  }

  @override
  void onConnectionClosed(String reason) {
    if (!mounted) return;
    setState(() {
      _connecting = false;
      _currentRoom = null;
      _mySeat = null;
      _statusMessage = '与服务器断开：$reason';
    });
  }

  @override
  void onServerError(String message) {
    if (!mounted) return;
    setState(() => _statusMessage = message);
  }

  /* ------------------------- 操作 ------------------------- */

  Future<void> _connect() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) {
      setState(() => _statusMessage = '请输入服务器地址');
      return;
    }
    setState(() {
      _connecting = true;
      _statusMessage = '';
    });
    try {
      await _sync.connect(url, _nameController.text);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsUrlKey, url);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _connecting = false;
        _statusMessage = '连接失败：$e';
      });
      return;
    }
    if (mounted) setState(() => _connecting = false);
  }

  /// 优先加入有玩家且未满的房间，否则进入房间1
  void _quickJoin() {
    OnlineRoomInfo? target;
    for (final r in _rooms) {
      if (r.status == 'waiting' && r.playerCount > 0 && r.playerCount < 3) {
        target = r;
        break;
      }
    }
    _sync.joinRoom(target?.id ?? 1);
  }

  void _joinInputRoom() {
    final id = int.tryParse(_roomInputController.text.trim());
    if (id == null || id < 1 || id > 100) {
      setState(() => _statusMessage = '请输入 1-100 的房间号');
      return;
    }
    _sync.joinRoom(id);
  }

  void _leaveRoom() => _sync.leaveRoom();

  Future<void> _close() async {
    await _sync.disconnect();
    widget.onClose?.call();
  }

  bool get _myReady {
    final room = _currentRoom;
    final seat = _mySeat;
    if (room == null || seat == null) return false;
    for (final p in room.players) {
      if (p.seat == seat) return p.ready;
    }
    return false;
  }

  /* ------------------------- UI ------------------------- */

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final screenW = mq.size.width;
    final screenH = mq.size.height;

    final titleFontSize = screenH * 0.055;
    final fontSize = screenH * 0.032;

    return Material(
      color: Colors.transparent,
      child: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(-0.3, 0.0),
            radius: 0.8,
            colors: [Color(0xFF1a5c2e), Color(0xFF0d2818), Color(0xFF040f08)],
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: Stack(
          children: [
            // 顶栏：返回 / 标题 / 连接状态
            Positioned(
              top: screenH * 0.035,
              left: screenW * 0.025,
              right: screenW * 0.025,
              child: Row(
                children: [
                  SizedBox(
                    width: screenW * 0.22,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: _buildBackButton(fontSize, screenH * 0.075),
                    ),
                  ),
                  Expanded(
                    child: Center(
                      child: Text(
                        '联 机 对 战',
                        style: TextStyle(
                          fontSize: titleFontSize,
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFFFFD700),
                          shadows: [
                            Shadow(
                              color: const Color(0xFFFFD700).withOpacity(0.4),
                              blurRadius: 20,
                            ),
                            const Shadow(
                              color: Colors.black54,
                              blurRadius: 4,
                              offset: Offset(0, 2),
                            ),
                          ],
                          letterSpacing: titleFontSize * 0.18,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: screenW * 0.22,
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: _buildConnChip(fontSize * 0.85, screenH * 0.05),
                    ),
                  ),
                ],
              ),
            ),
            // 主内容
            Positioned.fill(
              top: screenH * 0.14,
              child: _connected
                  ? (_sync.inRoom
                        ? _buildRoomPanel(screenW, screenH)
                        : _buildLobbyPanel(screenW, screenH))
                  : _buildConnectPanel(screenW, screenH),
            ),
            // 状态消息
            if (_statusMessage.isNotEmpty)
              Positioned(
                bottom: screenH * 0.035,
                left: screenW * 0.1,
                right: screenW * 0.1,
                child: Text(
                  _statusMessage,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: fontSize * 0.95,
                    color: const Color(0xFFFF8888),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBackButton(double fontSize, double btnH) {
    return GestureDetector(
      onTap: _close,
      child: Container(
        height: btnH,
        padding: EdgeInsets.symmetric(horizontal: fontSize * 0.9),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(btnH * 0.3),
          border: Border.all(color: Colors.white.withOpacity(0.15), width: 1),
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.arrow_back, color: Colors.white70, size: fontSize * 1.2),
            SizedBox(width: fontSize * 0.4),
            Text(
              '返回',
              style: TextStyle(
                fontSize: fontSize,
                color: Colors.white70,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConnChip(double fontSize, double h) {
    final connected = _connected;
    return Container(
      height: h,
      padding: EdgeInsets.symmetric(horizontal: fontSize * 0.8),
      decoration: BoxDecoration(
        color: connected
            ? const Color(0xFF4ecdc4).withOpacity(0.12)
            : Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(h * 0.5),
        border: Border.all(
          color: connected
              ? const Color(0xFF4ecdc4).withOpacity(0.5)
              : Colors.white.withOpacity(0.15),
          width: 1,
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        connected ? '已连接' : (_connecting ? '连接中...' : '未连接'),
        style: TextStyle(
          fontSize: fontSize,
          color: connected ? const Color(0xFF4ecdc4) : Colors.white54,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  /* --------- 未连接：连接表单 --------- */

  Widget _buildConnectPanel(double screenW, double screenH) {
    final fontSize = screenH * 0.032;
    final btnH = screenH * 0.09;
    final fieldH = screenH * 0.085;

    return Center(
      child: Container(
        width: screenW * 0.52,
        padding: EdgeInsets.all(screenH * 0.045),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.03),
          borderRadius: BorderRadius.circular(screenH * 0.03),
          border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '连接到服务器，与另外2名真人玩家同桌对战',
              style: TextStyle(fontSize: fontSize * 0.9, color: Colors.white60),
            ),
            SizedBox(height: screenH * 0.035),
            _buildInput('服务器地址', _urlController, fontSize, fieldH),
            SizedBox(height: screenH * 0.025),
            _buildInput('昵称（留空自动分配）', _nameController, fontSize, fieldH),
            SizedBox(height: screenH * 0.04),
            Center(
              child: GestureDetector(
                onTap: _connecting ? null : _connect,
                child: Container(
                  width: screenW * 0.24,
                  height: btnH,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment(-0.3, -1),
                      end: Alignment(0.3, 1),
                      colors: [Color(0xFFffd700), Color(0xFFff8c00)],
                    ),
                    borderRadius: BorderRadius.circular(btnH * 0.35),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFFD700).withOpacity(0.3),
                        blurRadius: 20,
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    _connecting ? '连接中...' : '连 接',
                    style: TextStyle(
                      fontSize: fontSize * 1.15,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFF1a0a00),
                      letterSpacing: fontSize * 0.3,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInput(
    String label,
    TextEditingController controller,
    double fontSize,
    double fieldH,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: fontSize * 0.85,
            color: Colors.white.withOpacity(0.45),
          ),
        ),
        SizedBox(height: fieldH * 0.18),
        SizedBox(
          height: fieldH,
          child: TextField(
            controller: controller,
            style: TextStyle(color: Colors.white, fontSize: fontSize),
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white.withOpacity(0.06),
              contentPadding: EdgeInsets.symmetric(
                horizontal: fontSize * 0.7,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(fieldH * 0.25),
                borderSide: BorderSide(
                  color: Colors.white.withOpacity(0.15),
                  width: 1,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(fieldH * 0.25),
                borderSide: const BorderSide(
                  color: Color(0xFF4ecdc4),
                  width: 1.5,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /* --------- 已连接未入房：房间列表 + 加入 --------- */

  Widget _buildLobbyPanel(double screenW, double screenH) {
    final fontSize = screenH * 0.032;
    final btnH = screenH * 0.08;
    final occupied = _rooms.where((r) => r.playerCount > 0).toList();

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: screenW * 0.03,
        vertical: screenH * 0.01,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 房间列表
          Expanded(
            child: Container(
              margin: EdgeInsets.only(right: screenW * 0.015),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.03),
                borderRadius: BorderRadius.circular(screenH * 0.02),
                border: Border.all(
                  color: Colors.white.withOpacity(0.1),
                  width: 1,
                ),
              ),
              child: Column(
                children: [
                  Padding(
                    padding: EdgeInsets.all(screenH * 0.018),
                    child: Row(
                      children: [
                        Text(
                          '房间列表（${occupied.length}个房间有人）',
                          style: TextStyle(
                            fontSize: fontSize,
                            color: Colors.white70,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        GestureDetector(
                          onTap: () => _sync.requestRoomList(),
                          child: Container(
                            height: btnH * 0.75,
                            padding: EdgeInsets.symmetric(
                              horizontal: fontSize * 0.7,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF4ecdc4).withOpacity(0.12),
                              borderRadius: BorderRadius.circular(
                                btnH * 0.3,
                              ),
                              border: Border.all(
                                color: const Color(0xFF4ecdc4).withOpacity(0.4),
                                width: 1,
                              ),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              '刷新',
                              style: TextStyle(
                                fontSize: fontSize * 0.85,
                                color: const Color(0xFF4ecdc4),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: occupied.isEmpty
                        ? Center(
                            child: Text(
                              '暂无其他玩家在线\n可快速加入或输入房间号等待好友',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: fontSize,
                                color: Colors.white38,
                                height: 1.6,
                              ),
                            ),
                          )
                        : ListView.builder(
                            padding: EdgeInsets.only(
                              bottom: screenH * 0.015,
                              left: screenH * 0.015,
                              right: screenH * 0.015,
                            ),
                            itemCount: occupied.length,
                            itemBuilder: (context, index) {
                              return _buildRoomRow(
                                occupied[index],
                                fontSize,
                                screenH * 0.09,
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
          // 右侧加入面板
          SizedBox(
            width: screenW * 0.28,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.03),
                borderRadius: BorderRadius.circular(screenH * 0.02),
                border: Border.all(
                  color: Colors.white.withOpacity(0.1),
                  width: 1,
                ),
              ),
              padding: EdgeInsets.all(screenH * 0.025),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  GestureDetector(
                    onTap: _quickJoin,
                    child: Container(
                      width: double.infinity,
                      height: btnH,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment(-0.3, -1),
                          end: Alignment(0.3, 1),
                          colors: [Color(0xFFffd700), Color(0xFFff8c00)],
                        ),
                        borderRadius: BorderRadius.circular(btnH * 0.35),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFFD700).withOpacity(0.25),
                            blurRadius: 16,
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '快 速 加 入',
                        style: TextStyle(
                          fontSize: fontSize * 1.1,
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFF1a0a00),
                          letterSpacing: fontSize * 0.2,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: screenH * 0.035),
                  _buildInput(
                    '房间号（1-100）',
                    _roomInputController,
                    fontSize,
                    screenH * 0.075,
                  ),
                  SizedBox(height: screenH * 0.02),
                  GestureDetector(
                    onTap: _joinInputRoom,
                    child: Container(
                      width: double.infinity,
                      height: btnH * 0.85,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment(-0.3, -1),
                          end: Alignment(0.3, 1),
                          colors: [Color(0xFF4ecdc4), Color(0xFF3db8b0)],
                        ),
                        borderRadius: BorderRadius.circular(btnH * 0.35),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '加入指定房间',
                        style: TextStyle(
                          fontSize: fontSize,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: screenH * 0.04),
                  Text(
                    '每个房间3个座位，3名玩家全部准备后自动开始对局',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: fontSize * 0.8,
                      color: Colors.white38,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoomRow(OnlineRoomInfo room, double fontSize, double rowH) {
    final joinable = room.status == 'waiting' && room.playerCount < 3;
    return GestureDetector(
      onTap: joinable ? () => _sync.joinRoom(room.id) : null,
      child: Container(
        height: rowH,
        margin: EdgeInsets.only(bottom: rowH * 0.15),
        decoration: BoxDecoration(
          color: joinable
              ? Colors.white.withOpacity(0.04)
              : Colors.white.withOpacity(0.015),
          borderRadius: BorderRadius.circular(rowH * 0.25),
          border: Border.all(
            color: joinable
                ? const Color(0xFF4ecdc4).withOpacity(0.35)
                : Colors.white.withOpacity(0.08),
            width: 1,
          ),
        ),
        padding: EdgeInsets.symmetric(horizontal: fontSize * 0.8),
        child: Row(
          children: [
            Text(
              '房间 ${room.id}',
              style: TextStyle(
                fontSize: fontSize,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Spacer(),
            Text(
              '${room.playerCount}/3人',
              style: TextStyle(fontSize: fontSize * 0.9, color: Colors.white60),
            ),
            SizedBox(width: fontSize * 0.9),
            Text(
              room.status == 'playing'
                  ? '对局中'
                  : (room.playerCount >= 3 ? '已满' : '等待中'),
              style: TextStyle(
                fontSize: fontSize * 0.85,
                color: room.status == 'playing'
                    ? const Color(0xFFFF8888)
                    : (room.playerCount >= 3
                          ? Colors.white30
                          : const Color(0xFF4ecdc4)),
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /* --------- 房间内：座位/准备/离开 --------- */

  Widget _buildRoomPanel(double screenW, double screenH) {
    final fontSize = screenH * 0.032;
    final btnH = screenH * 0.09;
    final seatW = screenW * 0.17;
    final seatH = screenH * 0.34;
    final roomId = _currentRoom?.id ?? _sync.roomId ?? 0;
    final readyCount = _currentRoom?.players.where((p) => p.ready).length ?? 0;

    return Center(
      child: Container(
        width: screenW * 0.66,
        padding: EdgeInsets.all(screenH * 0.04),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.03),
          borderRadius: BorderRadius.circular(screenH * 0.03),
          border: Border.all(
            color: const Color(0xFFFFD700).withOpacity(0.25),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFFD700).withOpacity(0.08),
              blurRadius: 30,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '房 间 $roomId',
              style: TextStyle(
                fontSize: fontSize * 1.5,
                fontWeight: FontWeight.w900,
                color: const Color(0xFFFFD700),
                letterSpacing: fontSize * 0.2,
              ),
            ),
            SizedBox(height: screenH * 0.015),
            Text(
              '已准备 $readyCount/3，全员准备后自动开始',
              style: TextStyle(fontSize: fontSize * 0.85, color: Colors.white54),
            ),
            SizedBox(height: screenH * 0.035),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildSeatCard(0, seatW, seatH, fontSize),
                SizedBox(width: screenW * 0.015),
                _buildSeatCard(1, seatW, seatH, fontSize),
                SizedBox(width: screenW * 0.015),
                _buildSeatCard(2, seatW, seatH, fontSize),
              ],
            ),
            SizedBox(height: screenH * 0.045),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                GestureDetector(
                  onTap: () => _sync.toggleReady(),
                  child: Container(
                    width: screenW * 0.2,
                    height: btnH,
                    decoration: BoxDecoration(
                      gradient: _myReady
                          ? null
                          : const LinearGradient(
                              begin: Alignment(-0.3, -1),
                              end: Alignment(0.3, 1),
                              colors: [Color(0xFFffd700), Color(0xFFff8c00)],
                            ),
                      color: _myReady
                          ? Colors.white.withOpacity(0.06)
                          : null,
                      borderRadius: BorderRadius.circular(btnH * 0.35),
                      border: _myReady
                          ? Border.all(
                              color: const Color(0xFF4ecdc4).withOpacity(0.5),
                              width: 1.5,
                            )
                          : null,
                      boxShadow: _myReady
                          ? null
                          : [
                              BoxShadow(
                                color: const Color(
                                  0xFFFFD700,
                                ).withOpacity(0.25),
                                blurRadius: 16,
                              ),
                            ],
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      _myReady ? '取消准备' : '准 备',
                      style: TextStyle(
                        fontSize: fontSize * 1.15,
                        fontWeight: FontWeight.w900,
                        color: _myReady
                            ? const Color(0xFF4ecdc4)
                            : const Color(0xFF1a0a00),
                        letterSpacing: fontSize * 0.2,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: screenW * 0.03),
                GestureDetector(
                  onTap: _leaveRoom,
                  child: Container(
                    width: screenW * 0.16,
                    height: btnH,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.04),
                      borderRadius: BorderRadius.circular(btnH * 0.35),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.2),
                        width: 1,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '离开房间',
                      style: TextStyle(
                        fontSize: fontSize,
                        fontWeight: FontWeight.bold,
                        color: Colors.white70,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSeatCard(int seat, double w, double h, double fontSize) {
    final room = _currentRoom;
    OnlinePlayerInfo? info;
    for (final p in room?.players ?? const <OnlinePlayerInfo>[]) {
      if (p.seat == seat) {
        info = p;
        break;
      }
    }
    final isMe = seat == _mySeat;
    final name = info?.name ?? '等待加入';
    final ready = info?.ready ?? false;

    return Container(
      width: w,
      height: h,
      decoration: BoxDecoration(
        color: isMe
            ? const Color(0xFF4ecdc4).withOpacity(0.1)
            : Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(h * 0.1),
        border: Border.all(
          color: isMe
              ? const Color(0xFF4ecdc4).withOpacity(0.55)
              : Colors.white.withOpacity(0.1),
          width: 1.5,
        ),
      ),
      padding: EdgeInsets.all(h * 0.06),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '座位 ${seat + 1}${isMe ? '（我）' : ''}',
            style: TextStyle(
              fontSize: fontSize * 0.8,
              color: isMe ? const Color(0xFF4ecdc4) : Colors.white38,
            ),
          ),
          SizedBox(height: h * 0.08),
          Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: fontSize * 1.05,
              fontWeight: FontWeight.bold,
              color: info != null ? Colors.white : Colors.white30,
            ),
          ),
          SizedBox(height: h * 0.1),
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: fontSize * 0.6,
              vertical: fontSize * 0.16,
            ),
            decoration: BoxDecoration(
              color: ready
                  ? const Color(0xFF4ecdc4).withOpacity(0.18)
                  : Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(fontSize),
              border: Border.all(
                color: ready
                    ? const Color(0xFF4ecdc4).withOpacity(0.5)
                    : Colors.white.withOpacity(0.12),
                width: 1,
              ),
            ),
            child: Text(
              info == null ? '空位' : (ready ? '已准备' : '未准备'),
              style: TextStyle(
                fontSize: fontSize * 0.78,
                color: ready
                    ? const Color(0xFF4ecdc4)
                    : Colors.white54,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
