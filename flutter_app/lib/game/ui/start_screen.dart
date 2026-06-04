import 'package:flutter/material.dart';

class StartScreen extends StatefulWidget {
  final void Function(
    int baseScore,
    int multiplierBase,
    String difficulty,
    bool piaoEnabled,
  )?
  onStartGame;
  final VoidCallback? onExit;

  const StartScreen({super.key, this.onStartGame, this.onExit});

  @override
  State<StartScreen> createState() => _StartScreenState();
}

class _StartScreenState extends State<StartScreen> {
  int _baseScore = 5;
  int _multiplierBase = 2;
  String _difficulty = 'hard';
  bool _piaoEnabled = false;

  static const _baseScoreOptions = [5, 10, 20];
  static const _multiplierBaseOptions = [2, 5, 10];
  static const _difficultyOptions = {
    'easy': '简单',
    'medium': '中等',
    'hard': '困难',
  };

  void _onStartGame() {
    widget.onStartGame?.call(
      _baseScore,
      _multiplierBase,
      _difficulty,
      _piaoEnabled,
    );
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final screenW = mq.size.width;
    final screenH = mq.size.height;

    // Scale factor based on screen size
    final scale = (screenW / 720).clamp(0.5, 2.5);

    // Responsive sizing
    final logoSize = screenH * 0.24;
    final titleFontSize = screenH * 0.065;
    final subtitleFontSize = screenH * 0.028;
    final labelFontSize = screenH * 0.036;
    final segFontSize = screenH * 0.038;
    final startFontSize = screenH * 0.05;
    final segBtnH = screenH * 0.075;
    final startBtnH = screenH * 0.1;
    final leftWidth = screenW * 0.25;
    final settingGap = screenH * 0.03;
    final segGap = screenW * 0.012;
    final decoCardW = screenW * 0.028;
    final decoCardH = screenH * 0.09;

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
            // Decorative glow circles
            Positioned(
              top: -screenH * 0.2,
              right: -screenW * 0.1,
              child: Container(
                width: screenW * 0.3,
                height: screenW * 0.3,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFFFFD700).withOpacity(0.04),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: -screenH * 0.15,
              left: screenW * 0.3,
              child: Container(
                width: screenW * 0.25,
                height: screenW * 0.25,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFF4ecdc4).withOpacity(0.03),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            // Main content
            Center(
              child: Row(
                children: [
                  // === Left brand area ===
                  SizedBox(
                    width: leftWidth,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Logo
                        Container(
                          width: logoSize,
                          height: logoSize,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(logoSize * 0.22),
                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [Color(0xFF2a1a0a), Color(0xFF1a0a00)],
                            ),
                            border: Border.all(
                              color: const Color(0xFFFFD700).withOpacity(0.4),
                              width: 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFFFD700).withOpacity(0.2),
                                blurRadius: 30,
                              ),
                              BoxShadow(
                                color: Colors.black.withOpacity(0.5),
                                blurRadius: 16,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius:
                                BorderRadius.circular(logoSize * 0.22),
                            child: Image.asset(
                              'assets/images/logo1024.png',
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        SizedBox(height: screenH * 0.03),
                        // Title
                        Text(
                          '上大人',
                          style: TextStyle(
                            fontSize: titleFontSize,
                            fontWeight: FontWeight.w900,
                            color: const Color(0xFFFFD700),
                            shadows: [
                              Shadow(
                                color:
                                    const Color(0xFFFFD700).withOpacity(0.4),
                                blurRadius: 20,
                              ),
                              const Shadow(
                                color: Colors.black54,
                                blurRadius: 4,
                                offset: Offset(0, 2),
                              ),
                            ],
                            letterSpacing: titleFontSize * 0.25,
                          ),
                        ),
                        SizedBox(height: screenH * 0.005),
                        // Subtitle
                        Text(
                          '字 牌 游 戏',
                          style: TextStyle(
                            fontSize: subtitleFontSize,
                            color: const Color(0xFFFFD700).withOpacity(0.35),
                            letterSpacing: subtitleFontSize * 0.4,
                          ),
                        ),
                        SizedBox(height: screenH * 0.025),
                        // Decorative cards
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _buildDecoCard('上', true, decoCardW, decoCardH),
                            _buildDecoCard('大', true, decoCardW, decoCardH),
                            _buildDecoCard('人', true, decoCardW, decoCardH),
                            SizedBox(width: decoCardW * 0.3),
                            _buildDecoCard('福', false, decoCardW, decoCardH),
                            _buildDecoCard('禄', false, decoCardW, decoCardH),
                            _buildDecoCard('寿', false, decoCardW, decoCardH),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // === Vertical divider ===
                  Container(
                    width: 1,
                    height: screenH * 0.65,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          const Color(0xFFFFD700).withOpacity(0.2),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                  SizedBox(width: screenW * 0.035),
                  // === Right settings area ===
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Settings list
                        _buildSegSetting(
                          '底分',
                          _baseScoreOptions
                              .map((v) => _SegOption(
                                    label: '$v分',
                                    selected: _baseScore == v,
                                    onTap: () =>
                                        setState(() => _baseScore = v),
                                  ))
                              .toList(),
                          labelFontSize,
                          segFontSize,
                          segBtnH,
                          segGap,
                          settingGap,
                        ),
                        _buildSegSetting(
                          '倍数基数',
                          _multiplierBaseOptions
                              .map((v) => _SegOption(
                                    label: '$v分',
                                    selected: _multiplierBase == v,
                                    onTap: () => setState(
                                        () => _multiplierBase = v),
                                  ))
                              .toList(),
                          labelFontSize,
                          segFontSize,
                          segBtnH,
                          segGap,
                          settingGap,
                        ),
                        _buildSegSetting(
                          '难度',
                          _difficultyOptions.entries
                              .map((e) => _SegOption(
                                    label: e.value,
                                    selected: _difficulty == e.key,
                                    onTap: () => setState(
                                        () => _difficulty = e.key),
                                  ))
                              .toList(),
                          labelFontSize,
                          segFontSize,
                          segBtnH,
                          segGap,
                          settingGap,
                        ),
                        _buildSegSetting(
                          '飘分',
                          [
                            _SegOption(
                              label: '关闭',
                              selected: !_piaoEnabled,
                              onTap: () =>
                                  setState(() => _piaoEnabled = false),
                            ),
                            _SegOption(
                              label: '打开',
                              selected: _piaoEnabled,
                              onTap: () =>
                                  setState(() => _piaoEnabled = true),
                            ),
                          ],
                          labelFontSize,
                          segFontSize,
                          segBtnH,
                          segGap,
                          settingGap,
                        ),
                        SizedBox(height: screenH * 0.04),
                        // Start button
                        GestureDetector(
                          onTap: _onStartGame,
                          child: Container(
                            width: screenW * 0.4,
                            height: startBtnH,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                begin: Alignment(-0.3, -1),
                                end: Alignment(0.3, 1),
                                colors: [Color(0xFFffd700), Color(0xFFff8c00)],
                              ),
                              borderRadius: BorderRadius.circular(startBtnH * 0.35),
                              boxShadow: [
                                BoxShadow(
                                  color:
                                      const Color(0xFFFFD700).withOpacity(0.3),
                                  blurRadius: 25,
                                ),
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.3),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              '开 始 游 戏',
                              style: TextStyle(
                                fontSize: startFontSize,
                                fontWeight: FontWeight.w900,
                                color: const Color(0xFF1a0a00),
                                letterSpacing: startFontSize * 0.3,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: screenW * 0.04),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDecoCard(String char, bool isRed, double w, double h) {
    return Container(
      width: w,
      height: h,
      margin: EdgeInsets.only(right: w * 0.1),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(3),
        color: isRed
            ? const Color(0xFFFF4444).withOpacity(0.08)
            : const Color(0xFF44FF44).withOpacity(0.08),
        border: Border.all(
          color: Colors.white.withOpacity(0.08),
          width: 1,
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        char,
        style: TextStyle(
          fontSize: h * 0.35,
          fontWeight: FontWeight.w900,
          color: isRed ? const Color(0xFFFF4444) : const Color(0xFF44FF44),
        ),
      ),
    );
  }

  Widget _buildSegSetting(
    String label,
    List<_SegOption> options,
    double labelFontSize,
    double segFontSize,
    double segBtnH,
    double segGap,
    double settingGap,
  ) {
    return Padding(
      padding: EdgeInsets.only(bottom: settingGap),
      child: Row(
        children: [
          SizedBox(
            width: labelFontSize * 4.5,
            child: Text(
              label,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: labelFontSize,
                color: Colors.white.withOpacity(0.45),
              ),
            ),
          ),
          SizedBox(width: segGap * 1.5),
          Expanded(
            child: Row(
              children: options.map((opt) {
                return Padding(
                  padding: EdgeInsets.only(right: segGap),
                  child: GestureDetector(
                    onTap: opt.onTap,
                    child: Container(
                      height: segBtnH,
                      decoration: BoxDecoration(
                        gradient: opt.selected
                            ? const LinearGradient(
                                begin: Alignment(-0.3, -1),
                                end: Alignment(0.3, 1),
                                colors: [
                                  Color(0xFF4ecdc4),
                                  Color(0xFF3db8b0)
                                ],
                              )
                            : null,
                        color: opt.selected
                            ? null
                            : Colors.white.withOpacity(0.03),
                        borderRadius: BorderRadius.circular(segBtnH * 0.25),
                        border: Border.all(
                          color: opt.selected
                              ? const Color(0xFF4ecdc4).withOpacity(0.5)
                              : Colors.white.withOpacity(0.1),
                          width: 1.5,
                        ),
                        boxShadow: opt.selected
                            ? [
                                BoxShadow(
                                  color: const Color(0xFF4ecdc4)
                                      .withOpacity(0.2),
                                  blurRadius: 12,
                                ),
                              ]
                            : null,
                      ),
                      alignment: Alignment.center,
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                            horizontal: segFontSize * 0.8),
                        child: Text(
                          opt.label,
                          style: TextStyle(
                            fontSize: segFontSize,
                            fontWeight: FontWeight.bold,
                            color: opt.selected
                                ? Colors.white
                                : Colors.white.withOpacity(0.45),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _SegOption {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  _SegOption({
    required this.label,
    required this.selected,
    required this.onTap,
  });
}
