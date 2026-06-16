import 'package:flutter/material.dart';

class ReplayControls extends StatefulWidget {
  final bool isPaused;
  final double speed;
  final double progress;
  final int currentIndex;
  final int totalActions;
  final int viewingPlayer;
  final List<int> playerDelays; // 3个玩家的操作延迟(ms)
  final VoidCallback? onTogglePause;
  final VoidCallback? onStepForward;
  final ValueChanged<double>? onSpeedChanged;
  final ValueChanged<int>? onViewingPlayerChanged;
  final void Function(int playerIndex, int delayMs)? onPlayerDelayChanged;
  final VoidCallback? onExit;

  const ReplayControls({
    super.key,
    this.isPaused = true,
    this.speed = 1.0,
    this.progress = 0.0,
    this.currentIndex = 0,
    this.totalActions = 0,
    this.viewingPlayer = 1,
    this.playerDelays = const [1000, 1000, 1000],
    this.onTogglePause,
    this.onStepForward,
    this.onSpeedChanged,
    this.onViewingPlayerChanged,
    this.onPlayerDelayChanged,
    this.onExit,
  });

  @override
  State<ReplayControls> createState() => _ReplayControlsState();
}

class _ReplayControlsState extends State<ReplayControls> {
  static const _speedOptions = [0.5, 1.0, 2.0, 4.0];
  static const _playerNames = ['玩家1', '我', '玩家2'];
  bool _showSettings = false;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black.withOpacity(0.8),
              Colors.black.withOpacity(0.4),
              Colors.transparent,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // 顶部行：回放标识 + 视角切换 + 设置 + 退出按钮
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4ecdc4).withOpacity(0.3),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF4ecdc4), width: 1),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.replay, size: 16, color: Color(0xFF4ecdc4)),
                        SizedBox(width: 4),
                        Text(
                          '回放',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF4ecdc4),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  // 视角切换
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: List.generate(3, (i) {
                        final isSelected = widget.viewingPlayer == i;
                        return GestureDetector(
                          onTap: () => widget.onViewingPlayerChanged?.call(i),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? const Color(0xFFffd700).withOpacity(0.3)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              _playerNames[i],
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                color: isSelected
                                    ? const Color(0xFFffd700)
                                    : Colors.white54,
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // 操作时间设置按钮
                  GestureDetector(
                    onTap: () => setState(() => _showSettings = !_showSettings),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: _showSettings
                            ? const Color(0xFFffd700).withOpacity(0.3)
                            : Colors.white.withOpacity(0.1),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _showSettings
                              ? const Color(0xFFffd700)
                              : Colors.white24,
                          width: 1,
                        ),
                      ),
                      child: Icon(
                        Icons.timer,
                        size: 18,
                        color: _showSettings
                            ? const Color(0xFFffd700)
                            : Colors.white70,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  // 退出按钮
                  GestureDetector(
                    onTap: widget.onExit,
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: const Color(0xFFff6b6b).withOpacity(0.3),
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFFff6b6b), width: 1),
                      ),
                      child: const Icon(
                        Icons.close,
                        size: 18,
                        color: Color(0xFFff6b6b),
                      ),
                    ),
                  ),
                ],
              ),
              // 操作时间设置面板
              if (_showSettings) ...[
                const SizedBox(height: 8),
                _buildDelaySettings(),
              ],
              const SizedBox(height: 8),
              // 进度条
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: SizedBox(
                        height: 4,
                        child: Stack(
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                            FractionallySizedBox(
                              widthFactor: widget.progress.clamp(0.0, 1.0),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: const Color(0xFF4ecdc4),
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${widget.currentIndex}/${widget.totalActions}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Colors.white54,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              // 控制按钮行
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // 播放/暂停
                  GestureDetector(
                    onTap: widget.onTogglePause,
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: const Color(0xFF4ecdc4).withOpacity(0.2),
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFF4ecdc4), width: 1.5),
                      ),
                      child: Icon(
                        widget.isPaused ? Icons.play_arrow : Icons.pause,
                        size: 28,
                        color: const Color(0xFF4ecdc4),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  // 单步前进
                  GestureDetector(
                    onTap: widget.onStepForward,
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white24, width: 1),
                      ),
                      child: const Icon(
                        Icons.skip_next,
                        size: 22,
                        color: Colors.white70,
                      ),
                    ),
                  ),
                  const SizedBox(width: 20),
                  // 速度选择
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: _speedOptions.map((s) {
                        final isSelected = (widget.speed - s).abs() < 0.01;
                        return GestureDetector(
                          onTap: () => widget.onSpeedChanged?.call(s),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? const Color(0xFFffd700).withOpacity(0.3)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '${s}x',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                color: isSelected
                                    ? const Color(0xFFffd700)
                                    : Colors.white54,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDelaySettings() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.5),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withOpacity(0.15), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '操作时间设置',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Color(0xFFffd700),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: List.generate(3, (i) {
              return Expanded(
                child: _buildDelaySlider(i),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildDelaySlider(int playerIndex) {
    final delay = widget.playerDelays.length > playerIndex
        ? widget.playerDelays[playerIndex]
        : 1000;
    final delaySec = (delay / 1000.0).toStringAsFixed(1);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Column(
        children: [
          Text(
            _playerNames[playerIndex],
            style: const TextStyle(
              fontSize: 11,
              color: Colors.white70,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${delaySec}s',
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF4ecdc4),
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(
            height: 20,
            child: SliderTheme(
              data: SliderThemeData(
                activeTrackColor: const Color(0xFF4ecdc4),
                inactiveTrackColor: Colors.white24,
                thumbColor: const Color(0xFF4ecdc4),
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                trackHeight: 2,
                overlayRadius: 0,
              ),
              child: Slider(
                value: delay.toDouble(),
                min: 200,
                max: 5000,
                divisions: 48,
                onChanged: (v) {
                  widget.onPlayerDelayChanged?.call(playerIndex, v.round());
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
