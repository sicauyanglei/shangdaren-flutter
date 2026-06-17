import 'dart:ui';
import 'package:flutter/material.dart';

class SettingsScreen extends StatefulWidget {
  final int initialVolume;
  final String initialDifficulty;
  final bool initialTickEnabled;
  final bool initialRecordingEnabled;
  final bool initialAutoHostingEnabled;
  final String initialAutoHostingStrategy;
  final bool initialAiStrategyTestEnabled;
  final ValueChanged<int>? onVolumeChanged;
  final ValueChanged<String>? onDifficultyChanged;
  final ValueChanged<bool>? onTickEnabledChanged;
  final ValueChanged<bool>? onRecordingEnabledChanged;
  final ValueChanged<bool>? onAutoHostingEnabledChanged;
  final ValueChanged<String>? onAutoHostingStrategyChanged;
  final ValueChanged<bool>? onAiStrategyTestEnabledChanged;
  final VoidCallback? onExitGame;
  final VoidCallback? onClose;

  const SettingsScreen({
    super.key,
    this.initialVolume = 100,
    this.initialDifficulty = 'hard',
    this.initialTickEnabled = true,
    this.initialRecordingEnabled = true,
    this.initialAutoHostingEnabled = false,
    this.initialAutoHostingStrategy = 'ai',
    this.initialAiStrategyTestEnabled = true,
    this.onVolumeChanged,
    this.onDifficultyChanged,
    this.onTickEnabledChanged,
    this.onRecordingEnabledChanged,
    this.onAutoHostingEnabledChanged,
    this.onAutoHostingStrategyChanged,
    this.onAiStrategyTestEnabledChanged,
    this.onExitGame,
    this.onClose,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late int _volume;
  late String _difficulty;
  late bool _tickEnabled;
  late bool _recordingEnabled;
  late bool _autoHostingEnabled;
  late String _autoHostingStrategy;
  late bool _aiStrategyTestEnabled;
  bool _featureExpanded = false;

  @override
  void initState() {
    super.initState();
    _volume = widget.initialVolume;
    _difficulty = widget.initialDifficulty;
    _tickEnabled = widget.initialTickEnabled;
    _recordingEnabled = widget.initialRecordingEnabled;
    _autoHostingEnabled = widget.initialAutoHostingEnabled;
    _autoHostingStrategy = widget.initialAutoHostingStrategy;
    _aiStrategyTestEnabled = widget.initialAiStrategyTestEnabled;
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final screenH = mq.size.height;
    final screenW = mq.size.width;
    final panelW = screenW < 400 ? screenW * 0.92 : 400.0;
    final compact = screenH < 420;

    return Container(
      color: Colors.black54,
      child: Center(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              width: panelW,
              constraints: BoxConstraints(
                maxWidth: panelW,
                maxHeight: screenH * 0.92,
              ),
              decoration: BoxDecoration(
                color: const Color(0xFF14141e).withOpacity(0.75),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withOpacity(0.08)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.6),
                    blurRadius: 60,
                  ),
                ],
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header
                    Container(
                      padding: EdgeInsets.fromLTRB(
                        24,
                        compact ? 12 : 20,
                        12,
                        compact ? 10 : 16,
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            const Color(0xFFffd700).withOpacity(0.08),
                            const Color(0xFFff6464).withOpacity(0.05),
                          ],
                        ),
                        border: Border(
                          bottom: BorderSide(
                            color: Colors.white.withOpacity(0.06),
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Center(
                              child: ShaderMask(
                                shaderCallback: (bounds) =>
                                    const LinearGradient(
                                      colors: [
                                        Color(0xFFffd700),
                                        Color(0xFFffaa00),
                                      ],
                                    ).createShader(bounds),
                                child: Text(
                                  '系统设置',
                                  style: TextStyle(
                                    fontSize: compact ? 16 : 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          GestureDetector(
                            onTap: widget.onClose,
                            child: Container(
                              width: compact ? 36 : 48,
                              height: compact ? 36 : 48,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  begin: Alignment(-0.7, -0.7),
                                  end: Alignment(0.7, 0.7),
                                  colors: [
                                    Color(0xFFff6b6b),
                                    Color(0xFFee5a24),
                                  ],
                                ),
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(
                                      0xFFff6b6b,
                                    ).withOpacity(0.4),
                                    blurRadius: 15,
                                  ),
                                ],
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                '×',
                                style: TextStyle(
                                  fontSize: compact ? 20 : 28,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Volume Section
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.fromLTRB(
                        24,
                        compact ? 8 : 12,
                        24,
                        compact ? 8 : 12,
                      ),
                      decoration: BoxDecoration(
                        border: Border(
                          top: BorderSide(
                            color: Colors.white.withOpacity(0.04),
                          ),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                _volume == 0
                                    ? '🔇'
                                    : (_volume <= 30 ? '🔉' : '🔊'),
                                style: const TextStyle(fontSize: 16),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '音效大小',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.white.withOpacity(0.5),
                                  letterSpacing: 2,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: SliderTheme(
                                  data: SliderThemeData(
                                    activeTrackColor: const Color(0xFFffd700),
                                    inactiveTrackColor: Colors.white
                                        .withOpacity(0.1),
                                    thumbColor: const Color(0xFFffd700),
                                    thumbShape: RoundSliderThumbShape(
                                      enabledThumbRadius: compact ? 7 : 10,
                                    ),
                                    overlayShape: RoundSliderOverlayShape(
                                      overlayRadius: compact ? 14 : 20,
                                    ),
                                    trackHeight: compact ? 4 : 6,
                                  ),
                                  child: Slider(
                                    value: _volume.toDouble(),
                                    min: 0,
                                    max: 100,
                                    onChanged: (value) {
                                      setState(() => _volume = value.toInt());
                                      widget.onVolumeChanged?.call(_volume);
                                    },
                                  ),
                                ),
                              ),
                              const SizedBox(width: 14),
                              SizedBox(
                                width: 50,
                                child: Text(
                                  '$_volume%',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    color: Color(0xFFffd700),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // 功能开关（可折叠）
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        border: Border(
                          top: BorderSide(
                            color: Colors.white.withOpacity(0.04),
                          ),
                        ),
                      ),
                      child: Column(
                        children: [
                          // 折叠头部
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                _featureExpanded = !_featureExpanded;
                              });
                            },
                            behavior: HitTestBehavior.opaque,
                            child: Container(
                              width: double.infinity,
                              padding: EdgeInsets.fromLTRB(
                                24,
                                compact ? 10 : 14,
                                24,
                                compact ? 10 : 14,
                              ),
                              child: Row(
                                children: [
                                  const Text(
                                    '🔧',
                                    style: TextStyle(fontSize: 16),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '功能开关',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.white.withOpacity(0.5),
                                      letterSpacing: 2,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const Spacer(),
                                  // 展开/收起按钮
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.06),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      _featureExpanded ? '隐藏' : '详情',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.white.withOpacity(0.5),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  // 收缩小图标
                                  AnimatedRotation(
                                    turns: _featureExpanded ? 0.25 : 0,
                                    duration: const Duration(milliseconds: 200),
                                    child: Icon(
                                      Icons.chevron_right,
                                      size: 18,
                                      color: Colors.white.withOpacity(0.4),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          // 展开内容
                          AnimatedCrossFade(
                            duration: const Duration(milliseconds: 200),
                            crossFadeState: _featureExpanded
                                ? CrossFadeState.showSecond
                                : CrossFadeState.showFirst,
                            firstChild: const SizedBox.shrink(),
                            secondChild: Container(
                              width: double.infinity,
                              padding: EdgeInsets.fromLTRB(
                                24,
                                compact ? 6 : 10,
                                24,
                                compact ? 6 : 10,
                              ),
                              decoration: BoxDecoration(
                                border: Border(
                                  top: BorderSide(
                                    color: Colors.white.withOpacity(0.02),
                                  ),
                                ),
                              ),
                              child: Column(
                                children: [
                                  // 倒计时跑秒
                                  Row(
                                    children: [
                                      Text(
                                        _tickEnabled ? '⏱️' : '🔕',
                                        style: const TextStyle(fontSize: 16),
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              '倒计时跑秒',
                                              style: TextStyle(
                                                fontSize: 13,
                                                color: Colors.white.withOpacity(
                                                  0.5,
                                                ),
                                                letterSpacing: 2,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              _tickEnabled
                                                  ? '时间紧迫时播放跑秒提示音'
                                                  : '已关闭跑秒提示音',
                                              style: TextStyle(
                                                fontSize: 10,
                                                color: Colors.white.withOpacity(
                                                  0.3,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      _buildToggle(_tickEnabled, (v) {
                                        setState(() => _tickEnabled = v);
                                        widget.onTickEnabledChanged?.call(v);
                                      }),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  // 游戏录制
                                  Row(
                                    children: [
                                      Text(
                                        _recordingEnabled ? '🎬' : '📹',
                                        style: const TextStyle(fontSize: 16),
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              '游戏录制',
                                              style: TextStyle(
                                                fontSize: 13,
                                                color: Colors.white.withOpacity(
                                                  0.5,
                                                ),
                                                letterSpacing: 2,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              _recordingEnabled
                                                  ? '录制游戏过程到视频'
                                                  : '已关闭录制',
                                              style: TextStyle(
                                                fontSize: 10,
                                                color: Colors.white.withOpacity(
                                                  0.3,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      _buildToggle(_recordingEnabled, (v) {
                                        setState(() => _recordingEnabled = v);
                                        widget.onRecordingEnabledChanged?.call(
                                          v,
                                        );
                                      }),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  // 倒计时托管
                                  Row(
                                    children: [
                                      Text(
                                        _autoHostingEnabled ? '🤖' : '💤',
                                        style: const TextStyle(fontSize: 16),
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              '倒计时托管',
                                              style: TextStyle(
                                                fontSize: 13,
                                                color: Colors.white.withOpacity(
                                                  0.5,
                                                ),
                                                letterSpacing: 2,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              _autoHostingEnabled
                                                  ? '连续3次超时自动托管'
                                                  : '已关闭自动托管',
                                              style: TextStyle(
                                                fontSize: 10,
                                                color: Colors.white.withOpacity(
                                                  0.3,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      _buildToggle(_autoHostingEnabled, (v) {
                                        setState(() => _autoHostingEnabled = v);
                                        widget.onAutoHostingEnabledChanged
                                            ?.call(v);
                                      }),
                                    ],
                                  ),
                                  // 托管策略选择（仅在开启倒计时时显示）
                                  AnimatedCrossFade(
                                    duration: const Duration(milliseconds: 200),
                                    crossFadeState: _autoHostingEnabled
                                        ? CrossFadeState.showSecond
                                        : CrossFadeState.showFirst,
                                    firstChild: const SizedBox.shrink(),
                                    secondChild: Padding(
                                      padding: const EdgeInsets.only(
                                        left: 22,
                                        top: 8,
                                      ),
                                      child: Row(
                                        children: [
                                          Text(
                                            '🧠',
                                            style: const TextStyle(
                                              fontSize: 14,
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            '托管策略',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.white.withOpacity(
                                                0.4,
                                              ),
                                              letterSpacing: 1,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          // AI托管策略
                                          _StrategyChip(
                                            label: 'AI托管策略',
                                            value: 'ai',
                                            groupValue: _autoHostingStrategy,
                                            compact: compact,
                                            onChanged: (value) {
                                              setState(
                                                () => _autoHostingStrategy =
                                                    value,
                                              );
                                              widget
                                                  .onAutoHostingStrategyChanged
                                                  ?.call(value);
                                            },
                                          ),
                                          const SizedBox(width: 8),
                                          // 非AI托管
                                          _StrategyChip(
                                            label: '非AI托管',
                                            value: 'simple',
                                            groupValue: _autoHostingStrategy,
                                            compact: compact,
                                            onChanged: (value) {
                                              setState(
                                                () => _autoHostingStrategy =
                                                    value,
                                              );
                                              widget
                                                  .onAutoHostingStrategyChanged
                                                  ?.call(value);
                                            },
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  // AI策略测试
                                  Row(
                                    children: [
                                      Text(
                                        _aiStrategyTestEnabled ? '🧪' : '🧫',
                                        style: const TextStyle(fontSize: 16),
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'AI策略测试',
                                              style: TextStyle(
                                                fontSize: 13,
                                                color: Colors.white.withOpacity(
                                                  0.5,
                                                ),
                                                letterSpacing: 2,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              _aiStrategyTestEnabled
                                                  ? '启用AI策略测试功能'
                                                  : '已关闭AI策略测试',
                                              style: TextStyle(
                                                fontSize: 10,
                                                color: Colors.white.withOpacity(
                                                  0.3,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      _buildToggle(_aiStrategyTestEnabled, (v) {
                                        setState(
                                          () => _aiStrategyTestEnabled = v,
                                        );
                                        widget.onAiStrategyTestEnabledChanged
                                            ?.call(v);
                                      }),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Difficulty Section
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.fromLTRB(
                        24,
                        compact ? 12 : 20,
                        24,
                        compact ? 12 : 20,
                      ),
                      decoration: BoxDecoration(
                        border: Border(
                          top: BorderSide(
                            color: Colors.white.withOpacity(0.04),
                          ),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Text('⚔️', style: TextStyle(fontSize: 16)),
                              const SizedBox(width: 8),
                              Text(
                                '游戏难度',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.white.withOpacity(0.5),
                                  letterSpacing: 2,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              _DifficultyCard(
                                icon: '🌱',
                                label: '简单',
                                desc: compact ? null : '新手入门',
                                value: 'easy',
                                groupValue: _difficulty,
                                color: const Color(0xFF2ecc71),
                                compact: compact,
                                onChanged: (value) {
                                  setState(() => _difficulty = value);
                                  widget.onDifficultyChanged?.call(value);
                                },
                              ),
                              const SizedBox(width: 10),
                              _DifficultyCard(
                                icon: '⚡',
                                label: '中等',
                                desc: compact ? null : '进阶挑战',
                                value: 'medium',
                                groupValue: _difficulty,
                                color: const Color(0xFFf1c40f),
                                compact: compact,
                                onChanged: (value) {
                                  setState(() => _difficulty = value);
                                  widget.onDifficultyChanged?.call(value);
                                },
                              ),
                              const SizedBox(width: 10),
                              _DifficultyCard(
                                icon: '🔥',
                                label: '困难',
                                desc: compact ? null : '高手对决',
                                value: 'hard',
                                groupValue: _difficulty,
                                color: const Color(0xFFe74c3c),
                                compact: compact,
                                onChanged: (value) {
                                  setState(() => _difficulty = value);
                                  widget.onDifficultyChanged?.call(value);
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // Exit Button
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                        24,
                        4,
                        24,
                        compact ? 16 : 24,
                      ),
                      child: Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment(-0.7, -0.7),
                            end: Alignment(0.7, 0.7),
                            colors: [Color(0xFFe74c3c), Color(0xFFc0392b)],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFe74c3c).withOpacity(0.3),
                              blurRadius: 15,
                            ),
                          ],
                        ),
                        child: ElevatedButton(
                          onPressed: widget.onExitGame,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            minimumSize: Size(
                              double.infinity,
                              compact ? 36 : 44,
                            ),
                            padding: EdgeInsets.symmetric(
                              vertical: compact ? 8 : 12,
                            ),
                          ),
                          child: const Text(
                            '退出游戏',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 2,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ), // Column
              ), // SingleChildScrollView
            ), // Container
          ), // BackdropFilter
        ), // ClipRRect
      ), // Center
    ); // return
  }

  Widget _buildToggle(bool value, ValueChanged<bool> onChanged) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: 48,
        height: 26,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(13),
          color: value
              ? const Color(0xFFffd700)
              : Colors.white.withOpacity(0.15),
          boxShadow: value
              ? [
                  BoxShadow(
                    color: const Color(0xFFffd700).withOpacity(0.3),
                    blurRadius: 10,
                  ),
                ]
              : null,
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 300),
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 22,
            height: 22,
            margin: const EdgeInsets.symmetric(horizontal: 2),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 4),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DifficultyCard extends StatelessWidget {
  final String icon;
  final String label;
  final String? desc;
  final String value;
  final String groupValue;
  final Color color;
  final bool compact;
  final ValueChanged<String> onChanged;

  const _DifficultyCard({
    required this.icon,
    required this.label,
    this.desc,
    required this.value,
    required this.groupValue,
    required this.color,
    this.compact = false,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = value == groupValue;
    return Expanded(
      child: GestureDetector(
        onTap: () => onChanged(value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: EdgeInsets.symmetric(
            vertical: compact ? 8 : 14,
            horizontal: 8,
          ),
          decoration: BoxDecoration(
            color: color.withOpacity(isActive ? 0.2 : 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: color.withOpacity(isActive ? 1.0 : 0.3),
              width: 2,
            ),
            boxShadow: isActive
                ? [BoxShadow(color: color.withOpacity(0.2), blurRadius: 25)]
                : null,
          ),
          child: Stack(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(icon, style: TextStyle(fontSize: compact ? 16 : 20)),
                  const SizedBox(width: 6),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: compact ? 12 : 14,
                          fontWeight: FontWeight.w600,
                          color: isActive ? Colors.white : Colors.white70,
                        ),
                      ),
                      if (desc != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          desc!,
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.white.withOpacity(0.4),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
              if (isActive)
                Positioned(
                  top: 0,
                  right: 0,
                  child: Container(
                    width: compact ? 14 : 18,
                    height: compact ? 14 : 18,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '✓',
                      style: TextStyle(
                        fontSize: compact ? 8 : 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 托管策略选择芯片
class _StrategyChip extends StatelessWidget {
  final String label;
  final String value;
  final String groupValue;
  final bool compact;
  final ValueChanged<String> onChanged;

  const _StrategyChip({
    required this.label,
    required this.value,
    required this.groupValue,
    this.compact = false,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = value == groupValue;
    const color = Color(0xFFFF9800);
    return GestureDetector(
      onTap: () => onChanged(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(
          vertical: compact ? 5 : 7,
          horizontal: compact ? 8 : 10,
        ),
        decoration: BoxDecoration(
          color: color.withOpacity(isActive ? 0.25 : 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: color.withOpacity(isActive ? 0.9 : 0.25),
            width: 1.5,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: compact ? 10 : 11,
            fontWeight: FontWeight.w600,
            color: isActive ? Colors.white : Colors.white.withOpacity(0.5),
          ),
        ),
      ),
    );
  }
}
