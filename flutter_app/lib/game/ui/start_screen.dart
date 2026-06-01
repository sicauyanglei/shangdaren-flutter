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

    final scale = (screenW / 1280).clamp(0.5, 2.0);

    final isWide = screenW >= 1024;
    final isMedium = screenW >= 768 && screenH >= 500;

    double logoWidth, outerGap, gridRowGap, gridColGap;
    double labelFontSize, btnFontSize, btnPadH, btnPadV, btnMinH;
    double startFont, startPadH, startPadV, startMinH;
    double sectionGap, btnGap, borderRadius;

    if (isWide) {
      logoWidth = 180;
      outerGap = 48;
      gridRowGap = 19.2;
      gridColGap = 40;
      labelFontSize = 19.2;
      btnFontSize = 17.6;
      btnPadH = 22.4;
      btnPadV = 11.2;
      btnMinH = 52;
      startFont = 22.4;
      startPadH = 48;
      startPadV = 16;
      startMinH = 60;
      sectionGap = 4.8;
      btnGap = 8;
      borderRadius = 15;
    } else if (isMedium) {
      logoWidth = 150;
      outerGap = 48;
      gridRowGap = 16;
      gridColGap = 32;
      labelFontSize = 17.6;
      btnFontSize = 16;
      btnPadH = 19.2;
      btnPadV = 9.6;
      btnMinH = 48;
      startFont = 22.4;
      startPadH = 48;
      startPadV = 16;
      startMinH = 60;
      sectionGap = 4.8;
      btnGap = 8;
      borderRadius = 15;
    } else {
      logoWidth = 150;
      outerGap = 48;
      gridRowGap = 16;
      gridColGap = 32;
      labelFontSize = 17.6;
      btnFontSize = 16;
      btnPadH = 19.2;
      btnPadV = 9.6;
      btnMinH = 48;
      startFont = 22.4;
      startPadH = 48;
      startPadV = 16;
      startMinH = 60;
      sectionGap = 4.8;
      btnGap = 8;
      borderRadius = 15;
    }

    return Material(
      color: Colors.transparent,
      child: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.center,
            radius: 0.7,
            colors: [Color(0xFF1a5c2e), Color(0xFF0d3d1a), Color(0xFF062810)],
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Transform.scale(
              scale: scale,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(borderRadius),
                    child: Container(
                      width: logoWidth,
                      height: logoWidth,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(borderRadius),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 20,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Image.asset(
                        'assets/images/logo1024.png',
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  SizedBox(width: outerGap),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildOptionSection(
                                '底分:',
                                _baseScoreOptions
                                    .map(
                                      (v) => _buildOptionButton(
                                        '$v分',
                                        _baseScore == v,
                                        () => setState(() => _baseScore = v),
                                        btnFontSize,
                                        btnPadH,
                                        btnPadV,
                                        btnMinH,
                                      ),
                                    )
                                    .toList(),
                                labelFontSize,
                                sectionGap,
                                btnGap,
                              ),
                              SizedBox(height: gridRowGap),
                              _buildOptionSection(
                                '游戏难度:',
                                _difficultyOptions.entries
                                    .map(
                                      (e) => _buildOptionButton(
                                        e.value,
                                        _difficulty == e.key,
                                        () =>
                                            setState(() => _difficulty = e.key),
                                        btnFontSize,
                                        btnPadH,
                                        btnPadV,
                                        btnMinH,
                                      ),
                                    )
                                    .toList(),
                                labelFontSize,
                                sectionGap,
                                btnGap,
                              ),
                            ],
                          ),
                          SizedBox(width: gridColGap),
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildOptionSection(
                                '倍数基数分:',
                                _multiplierBaseOptions
                                    .map(
                                      (v) => _buildOptionButton(
                                        '$v分',
                                        _multiplierBase == v,
                                        () =>
                                            setState(() => _multiplierBase = v),
                                        btnFontSize,
                                        btnPadH,
                                        btnPadV,
                                        btnMinH,
                                      ),
                                    )
                                    .toList(),
                                labelFontSize,
                                sectionGap,
                                btnGap,
                              ),
                              SizedBox(height: gridRowGap),
                              _buildOptionSection(
                                '飘分设置:',
                                [
                                  _buildOptionButton(
                                    '关闭',
                                    !_piaoEnabled,
                                    () => setState(() => _piaoEnabled = false),
                                    btnFontSize,
                                    btnPadH,
                                    btnPadV,
                                    btnMinH,
                                  ),
                                  _buildOptionButton(
                                    '打开',
                                    _piaoEnabled,
                                    () => setState(() => _piaoEnabled = true),
                                    btnFontSize,
                                    btnPadH,
                                    btnPadV,
                                    btnMinH,
                                  ),
                                ],
                                labelFontSize,
                                sectionGap,
                                btnGap,
                              ),
                            ],
                          ),
                        ],
                      ),
                      SizedBox(height: 13),
                      SizedBox(height: 40),
                      GestureDetector(
                        onTap: _onStartGame,
                        child: Container(
                          constraints: BoxConstraints(
                            minWidth: 160,
                            minHeight: startMinH,
                          ),
                          padding: EdgeInsets.symmetric(
                            horizontal: startPadH,
                            vertical: startPadV,
                          ),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              begin: Alignment(-0.3, -1),
                              end: Alignment(0.3, 1),
                              colors: [Color(0xFF4ecdc4), Color(0xFF3db8b0)],
                            ),
                            borderRadius: BorderRadius.circular(25),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.3),
                                blurRadius: 10,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Text(
                            '开始游戏',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: startFont,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOptionSection(
    String label,
    List<Widget> buttons,
    double labelFontSize,
    double sectionGap,
    double btnGap,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: labelFontSize,
            color: Colors.white.withOpacity(0.9),
          ),
        ),
        SizedBox(height: sectionGap),
        Wrap(spacing: btnGap, runSpacing: btnGap, children: buttons),
      ],
    );
  }

  Widget _buildOptionButton(
    String label,
    bool selected,
    VoidCallback onTap,
    double fontSize,
    double padH,
    double padV,
    double minH,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        constraints: BoxConstraints(
          minHeight: minH,
          minWidth: 60 * fontSize / 17.6,
        ),
        padding: EdgeInsets.symmetric(horizontal: padH, vertical: padV),
        decoration: BoxDecoration(
          gradient: selected
              ? const LinearGradient(
                  begin: Alignment(-0.3, -1),
                  end: Alignment(0.3, 1),
                  colors: [Color(0xFF4ecdc4), Color(0xFF3db8b0)],
                )
              : null,
          color: selected ? null : Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(6 * fontSize / 17.6),
          border: Border.all(
            color: selected
                ? const Color(0xFF4ecdc4)
                : Colors.white.withOpacity(0.3),
            width: 2 * fontSize / 17.6,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
