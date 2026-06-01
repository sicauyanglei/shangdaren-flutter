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
        child: Container(
          width: 320,
          constraints: const BoxConstraints(maxWidth: 320),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.85),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            width: 280,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment(-0.7, -0.7),
                end: Alignment(0.7, 0.7),
                colors: [Color(0xFF2d2d2d), Color(0xFF1a1a1a)],
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 40),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      padding: const EdgeInsets.only(bottom: 14.4, top: 16),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: Colors.white.withOpacity(0.2),
                          ),
                        ),
                      ),
                      child: const Center(
                        child: Text(
                          '系统设置',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 4,
                      right: -16,
                      child: GestureDetector(
                        onTap: widget.onClose,
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: const Color(0xFFff6b6b),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.3),
                                blurRadius: 8,
                              ),
                            ],
                          ),
                          alignment: Alignment.center,
                          child: const Text(
                            '×',
                            style: TextStyle(fontSize: 32, color: Colors.white),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '音效大小',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),
                    const SizedBox(height: 9.6),
                    Row(
                      children: [
                        Expanded(
                          child: SliderTheme(
                            data: SliderThemeData(
                              activeTrackColor: const Color(0xFFffd700),
                              inactiveTrackColor: Colors.white.withOpacity(0.3),
                              thumbColor: const Color(0xFFffd700),
                              thumbShape: const RoundSliderThumbShape(
                                enabledThumbRadius: 10,
                              ),
                              overlayShape: const RoundSliderOverlayShape(
                                overlayRadius: 20,
                              ),
                              trackHeight: 8,
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
                        const SizedBox(width: 14.4),
                        SizedBox(
                          width: 50,
                          child: Text(
                            '$_volume%',
                            style: const TextStyle(
                              fontSize: 16,
                              color: Color(0xFFffd700),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '游戏难度',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),
                    const SizedBox(height: 9.6),
                    Row(
                      children: [
                        _DifficultyRadio(
                          label: '简单',
                          value: 'easy',
                          groupValue: _difficulty,
                          onChanged: (value) {
                            setState(() => _difficulty = value);
                            widget.onDifficultyChanged?.call(value);
                          },
                        ),
                        const SizedBox(width: 15),
                        _DifficultyRadio(
                          label: '中等',
                          value: 'medium',
                          groupValue: _difficulty,
                          onChanged: (value) {
                            setState(() => _difficulty = value);
                            widget.onDifficultyChanged?.call(value);
                          },
                        ),
                        const SizedBox(width: 15),
                        _DifficultyRadio(
                          label: '困难',
                          value: 'hard',
                          groupValue: _difficulty,
                          onChanged: (value) {
                            setState(() => _difficulty = value);
                            widget.onDifficultyChanged?.call(value);
                          },
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.only(top: 20),
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(color: Colors.white.withOpacity(0.15)),
                    ),
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment(-0.7, -0.7),
                          end: Alignment(0.7, 0.7),
                          colors: [Color(0xFFe74c3c), Color(0xFFc0392b)],
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ElevatedButton(
                        onPressed: widget.onExitGame,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 11.2),
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
    );
  }
}

class _DifficultyRadio extends StatelessWidget {
  final String label;
  final String value;
  final String groupValue;
  final ValueChanged<String> onChanged;

  const _DifficultyRadio({
    required this.label,
    required this.value,
    required this.groupValue,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(value),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: Radio<String>(
              value: value,
              groupValue: groupValue,
              onChanged: (v) {
                if (v != null) onChanged(v);
              },
              activeColor: const Color(0xFFffd700),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(color: Colors.white, fontSize: 14),
          ),
        ],
      ),
    );
  }
}
