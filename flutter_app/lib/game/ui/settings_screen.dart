import 'dart:ui';
import 'package:flutter/material.dart';

class SettingsScreen extends StatefulWidget {
  final int initialVolume;
  final String initialDifficulty;
  final ValueChanged<int>? onVolumeChanged;
  final ValueChanged<String>? onDifficultyChanged;
  final VoidCallback? onExitGame;
  final VoidCallback? onClose;

  const SettingsScreen({
    super.key,
    this.initialVolume = 100,
    this.initialDifficulty = 'hard',
    this.onVolumeChanged,
    this.onDifficultyChanged,
    this.onExitGame,
    this.onClose,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late int _volume;
  late String _difficulty;

  @override
  void initState() {
    super.initState();
    _volume = widget.initialVolume;
    _difficulty = widget.initialDifficulty;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black54,
      child: Center(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              width: 340,
              constraints: const BoxConstraints(maxWidth: 340),
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
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.fromLTRB(24, 20, 12, 16),
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
                              shaderCallback: (bounds) => const LinearGradient(
                                colors: [Color(0xFFffd700), Color(0xFFffaa00)],
                              ).createShader(bounds),
                              child: const Text(
                                '系统设置',
                                style: TextStyle(
                                  fontSize: 20,
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
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                begin: Alignment(-0.7, -0.7),
                                end: Alignment(0.7, 0.7),
                                colors: [Color(0xFFff6b6b), Color(0xFFee5a24)],
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
                            child: const Text(
                              '×',
                              style: TextStyle(
                                fontSize: 28,
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
                    padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(color: Colors.white.withOpacity(0.04)),
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
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: SliderTheme(
                                data: SliderThemeData(
                                  activeTrackColor: const Color(0xFFffd700),
                                  inactiveTrackColor: Colors.white.withOpacity(
                                    0.1,
                                  ),
                                  thumbColor: const Color(0xFFffd700),
                                  thumbShape: const RoundSliderThumbShape(
                                    enabledThumbRadius: 10,
                                  ),
                                  overlayShape: const RoundSliderOverlayShape(
                                    overlayRadius: 20,
                                  ),
                                  trackHeight: 6,
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
                  // Difficulty Section
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(color: Colors.white.withOpacity(0.04)),
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
                              desc: '新手入门',
                              value: 'easy',
                              groupValue: _difficulty,
                              color: const Color(0xFF2ecc71),
                              onChanged: (value) {
                                setState(() => _difficulty = value);
                                widget.onDifficultyChanged?.call(value);
                              },
                            ),
                            const SizedBox(width: 10),
                            _DifficultyCard(
                              icon: '⚡',
                              label: '中等',
                              desc: '进阶挑战',
                              value: 'medium',
                              groupValue: _difficulty,
                              color: const Color(0xFFf1c40f),
                              onChanged: (value) {
                                setState(() => _difficulty = value);
                                widget.onDifficultyChanged?.call(value);
                              },
                            ),
                            const SizedBox(width: 10),
                            _DifficultyCard(
                              icon: '🔥',
                              label: '困难',
                              desc: '高手对决',
                              value: 'hard',
                              groupValue: _difficulty,
                              color: const Color(0xFFe74c3c),
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
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                    child: SizedBox(
                      width: double.infinity,
                      height: 46,
                      child: Container(
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
                            padding: const EdgeInsets.symmetric(vertical: 12),
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
                  ),
                ],
              ),
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
  final String desc;
  final String value;
  final String groupValue;
  final Color color;
  final ValueChanged<String> onChanged;

  const _DifficultyCard({
    required this.icon,
    required this.label,
    required this.desc,
    required this.value,
    required this.groupValue,
    required this.color,
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
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
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
              Column(
                children: [
                  Text(icon, style: const TextStyle(fontSize: 24)),
                  const SizedBox(height: 6),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isActive ? Colors.white : Colors.white70,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    desc,
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.white.withOpacity(0.4),
                    ),
                  ),
                ],
              ),
              if (isActive)
                Positioned(
                  top: 0,
                  right: 0,
                  child: Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: const Text(
                      '✓',
                      style: TextStyle(
                        fontSize: 10,
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
