import 'dart:math' as math;
import 'dart:ui';
import 'package:flame/components.dart';
import '../core/atlas_loader.dart';
import '../core/object_pool.dart';
import '../models/card.dart';

class CardRender extends PositionComponent {
  static Image? atlasImage;
  static AtlasLoader? atlasLoader;
  static const double cardWidth = 56.0;
  static const double cardHeight = 224.0;

  static final pool = ObjectPool<CardRender>(
    () => CardRender(),
    (cr) => cr.reset(),
  );

  Card? card;
  bool isSelected = false;
  bool isLastDiscard = false;
  bool showTingBadge = false;
  bool isMeldCard = false;
  int meldGroupId = -1;
  double cardOpacity = 1.0;
  bool faceUp = true;
  double pulseTimer = 0.0;
  bool isNewDrawn = false;
  bool showNewBadge = false;
  double newBadgeTimer = 0.0;

  CardRender() : super(size: Vector2(cardWidth, cardHeight));

  void setup(
    Card card, {
    double x = 0,
    double y = 0,
    double scaleX = 1.0,
    double scaleY = 1.0,
    double angle = 0,
    bool faceUp = true,
  }) {
    this.card = card;
    position.setValues(x, y);
    scale.setValues(scaleX, scaleY);
    this.angle = angle;
    this.faceUp = faceUp;
    isSelected = false;
    isLastDiscard = false;
    showTingBadge = false;
    isMeldCard = false;
    cardOpacity = 1.0;
    pulseTimer = 0.0;
    isNewDrawn = false;
    showNewBadge = false;
    newBadgeTimer = 0.0;
  }

  void reset() {
    card = null;
    position.setValues(0, 0);
    scale.setValues(1, 1);
    angle = 0;
    isSelected = false;
    isLastDiscard = false;
    showTingBadge = false;
    isMeldCard = false;
    meldGroupId = -1;
    cardOpacity = 1.0;
    faceUp = true;
    pulseTimer = 0.0;
    isNewDrawn = false;
    showNewBadge = false;
    newBadgeTimer = 0.0;
  }

  @override
  void update(double dt) {
    if (isLastDiscard) {
      pulseTimer += dt;
    } else {
      pulseTimer = 0.0;
    }
    if (showNewBadge) {
      newBadgeTimer += dt;
    }
  }

  static int _cardColorGroup(String char) {
    if (char == '上' || char == '大' || char == '人') return 0; // 红色
    if (char == '化' ||
        char == '三' ||
        char == '千' ||
        char == '七' ||
        char == '十' ||
        char == '土')
      return 1; // 绿色
    return 2; // 黑色
  }

  /// 获取卡牌颜色组的边框色
  static Color _cardBorderColor(String char) {
    final group = _cardColorGroup(char);
    switch (group) {
      case 0:
        return const Color(0xFFFF4444); // 红色边框
      case 1:
        return const Color(0xFF33BB33); // 绿色边框
      default:
        return const Color(0xFF666666); // 黑色边框
    }
  }

  @override
  void render(Canvas canvas) {
    if (card == null || atlasImage == null || atlasLoader == null) return;
    canvas.save();

    // 选中效果：上移
    if (isSelected) {
      canvas.translate(0, -20);
    }

    final paint = Paint()
      ..color = Color.fromRGBO(255, 255, 255, cardOpacity)
      ..filterQuality = FilterQuality.high;

    if (faceUp) {
      final info = atlasLoader!.getSpriteByChar(card!.character);
      if (info != null) {
        canvas.drawImageRect(
          atlasImage!,
          Rect.fromLTWH(
            info.srcX.toDouble(),
            info.srcY.toDouble(),
            info.srcW.toDouble(),
            info.srcH.toDouble(),
          ),
          Rect.fromLTWH(0, 0, width, height),
          paint,
        );
      }
      // 绘制颜色边框区分红/绿/黑
      final borderColor = _cardBorderColor(card!.character);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(0, 0, width, height),
          const Radius.circular(3),
        ),
        Paint()
          ..color = borderColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5,
      );
    } else {
      final info = atlasLoader!.getSprite('back');
      if (info != null) {
        canvas.drawImageRect(
          atlasImage!,
          Rect.fromLTWH(
            info.srcX.toDouble(),
            info.srcY.toDouble(),
            info.srcW.toDouble(),
            info.srcH.toDouble(),
          ),
          Rect.fromLTWH(0, 0, width, height),
          paint,
        );
      } else {
        paint.color = Color.fromRGBO(0, 100, 0, cardOpacity);
        canvas.drawRect(Rect.fromLTWH(0, 0, width, height), paint);
        paint
          ..color = Color.fromRGBO(0, 60, 0, cardOpacity)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2;
        canvas.drawRect(Rect.fromLTWH(2, 2, width - 4, height - 4), paint);
      }
    }

    if (showTingBadge) {
      canvas.drawCircle(
        Offset(width - 8, 8),
        6,
        Paint()..color = const Color(0xFFFF4444),
      );
    }

    canvas.restore();
  }
}
