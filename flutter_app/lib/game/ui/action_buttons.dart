import 'package:flutter/material.dart';

enum GameButtonType { hu, chi, peng, zhao, pass, zimo, ting }

class GameArtButton extends StatefulWidget {
  final String label;
  final GameButtonType type;
  final VoidCallback? onTap;

  const GameArtButton({
    super.key,
    required this.label,
    required this.type,
    this.onTap,
  });

  @override
  State<GameArtButton> createState() => _GameArtButtonState();
}

class _GameArtButtonState extends State<GameArtButton>
    with SingleTickerProviderStateMixin {
  bool _pressed = false;
  late AnimationController _glowController;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
  }

  _ButtonStyle get _style {
    switch (widget.type) {
      case GameButtonType.hu:
        return _ButtonStyle(
          bgColors: const [Color(0xFFc0392b), Color(0xFFe74c3c)],
          borderColor: const Color(0xFFffd700),
          innerBorderColor: const Color(0xFFFF8A80),
          textColor: const Color(0xFFFFFFFF),
          shadowColor: const Color(0xFFc0392b),
          glowColor: const Color(0xFFff6b6b),
        );
      case GameButtonType.chi:
        return _ButtonStyle(
          bgColors: const [Color(0xFF1a6b3c), Color(0xFF27ae60)],
          borderColor: const Color(0xFFffd700),
          innerBorderColor: const Color(0xFF81C784),
          textColor: const Color(0xFFFFFFFF),
          shadowColor: const Color(0xFF1a6b3c),
          glowColor: const Color(0xFF4ecdc4),
        );
      case GameButtonType.peng:
        return _ButtonStyle(
          bgColors: const [Color(0xFF1a5c6b), Color(0xFF2980b9)],
          borderColor: const Color(0xFFffd700),
          innerBorderColor: const Color(0xFF64B5F6),
          textColor: const Color(0xFFFFFFFF),
          shadowColor: const Color(0xFF1a5c6b),
          glowColor: const Color(0xFF64B5F6),
        );
      case GameButtonType.zhao:
        return _ButtonStyle(
          bgColors: const [Color(0xFFb8860b), Color(0xFFdaa520)],
          borderColor: const Color(0xFFFFF8E1),
          innerBorderColor: const Color(0xFFFFD54F),
          textColor: const Color(0xFF3E2723),
          shadowColor: const Color(0xFFb8860b),
          glowColor: const Color(0xFFffd700),
        );
      case GameButtonType.pass:
        return _ButtonStyle(
          bgColors: const [Color(0xFF37474F), Color(0xFF546E7A)],
          borderColor: const Color(0xFF90A4AE),
          innerBorderColor: const Color(0xFF78909C),
          textColor: const Color(0xFFCFD8DC),
          shadowColor: const Color(0xFF263238),
          glowColor: null,
        );
      case GameButtonType.zimo:
        return _ButtonStyle(
          bgColors: const [Color(0xFFb71c1c), Color(0xFFe53935)],
          borderColor: const Color(0xFFffd700),
          innerBorderColor: const Color(0xFFFF8A80),
          textColor: const Color(0xFFFFFFFF),
          shadowColor: const Color(0xFFb71c1c),
          glowColor: const Color(0xFFff6b6b),
        );
      case GameButtonType.ting:
        return _ButtonStyle(
          bgColors: const [Color(0xFFc62828), Color(0xFFef5350)],
          borderColor: const Color(0xFFffd700),
          innerBorderColor: const Color(0xFFFF8A80),
          textColor: const Color(0xFFFFFFFF),
          shadowColor: const Color(0xFFc62828),
          glowColor: const Color(0xFFff6b6b),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final style = _style;
    final isSmall = widget.type == GameButtonType.ting;

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap?.call();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.93 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: AnimatedBuilder(
          animation: _glowController,
          builder: (context, child) {
            final glowValue = style.glowColor != null
                ? 0.3 + 0.3 * _glowController.value
                : 0.0;

            return Container(
              constraints: BoxConstraints(
                minHeight: isSmall ? 48 : 72,
                minWidth: isSmall ? 48 : 130,
              ),
              padding: EdgeInsets.symmetric(
                horizontal: isSmall ? 16 : 36,
                vertical: isSmall ? 10 : 18,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: style.bgColors,
                  begin: Alignment(-0.6, -0.6),
                  end: Alignment(0.6, 0.6),
                ),
                borderRadius: BorderRadius.circular(isSmall ? 12 : 16),
                border: Border.all(color: style.borderColor, width: 2.5),
                boxShadow: [
                  BoxShadow(
                    color: style.shadowColor.withOpacity(0.5),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                  if (style.glowColor != null)
                    BoxShadow(
                      color: style.glowColor!.withOpacity(glowValue),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                ],
              ),
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: isSmall ? 4 : 8,
                  vertical: isSmall ? 2 : 4,
                ),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: style.innerBorderColor.withOpacity(0.4),
                    width: 1,
                  ),
                  borderRadius: BorderRadius.circular(isSmall ? 8 : 10),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Text(
                      widget.label,
                      style: TextStyle(
                        fontSize: isSmall ? 26 : 32,
                        fontWeight: FontWeight.w900,
                        color: Colors.black.withOpacity(0.3),
                        letterSpacing: 2,
                      ),
                    ),
                    Text(
                      widget.label,
                      style: TextStyle(
                        fontSize: isSmall ? 26 : 32,
                        fontWeight: FontWeight.w900,
                        foreground: Paint()
                          ..shader =
                              LinearGradient(
                                colors: [
                                  style.textColor,
                                  style.textColor.withOpacity(0.85),
                                ],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              ).createShader(
                                Rect.fromLTWH(
                                  0,
                                  0,
                                  isSmall ? 48.0 : 130.0,
                                  isSmall ? 48.0 : 72.0,
                                ),
                              ),
                        shadows: [
                          Shadow(
                            color: style.borderColor.withOpacity(0.6),
                            blurRadius: 4,
                          ),
                        ],
                        letterSpacing: 2,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ButtonStyle {
  final List<Color> bgColors;
  final Color borderColor;
  final Color innerBorderColor;
  final Color textColor;
  final Color shadowColor;
  final Color? glowColor;

  const _ButtonStyle({
    required this.bgColors,
    required this.borderColor,
    required this.innerBorderColor,
    required this.textColor,
    required this.shadowColor,
    this.glowColor,
  });
}

class ActionButtons extends StatelessWidget {
  final bool canChi;
  final bool canPeng;
  final bool canZhao;
  final bool canHu;
  final VoidCallback? onChi;
  final VoidCallback? onPeng;
  final VoidCallback? onZhao;
  final VoidCallback? onHu;
  final VoidCallback? onPass;

  const ActionButtons({
    super.key,
    this.canChi = false,
    this.canPeng = false,
    this.canZhao = false,
    this.canHu = false,
    this.onChi,
    this.onPeng,
    this.onZhao,
    this.onHu,
    this.onPass,
  });

  bool get _hasAnyAction => canChi || canPeng || canZhao || canHu;

  @override
  Widget build(BuildContext context) {
    if (!_hasAnyAction) return const SizedBox.shrink();

    return Wrap(
      spacing: 18,
      runSpacing: 0,
      alignment: WrapAlignment.center,
      children: [
        if (canHu)
          GameArtButton(label: '胡', type: GameButtonType.hu, onTap: onHu),
        if (canChi && !canHu)
          GameArtButton(label: '吃', type: GameButtonType.chi, onTap: onChi),
        if (canPeng && !canHu)
          GameArtButton(label: '碰', type: GameButtonType.peng, onTap: onPeng),
        if (canZhao && !canHu)
          GameArtButton(label: '招', type: GameButtonType.zhao, onTap: onZhao),
        if (_hasAnyAction && !canHu)
          GameArtButton(label: '过', type: GameButtonType.pass, onTap: onPass),
      ],
    );
  }
}
