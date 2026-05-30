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
  double _pulseTimer = 0.0;

  CardRender() : super(size: Vector2(cardWidth, cardHeight));

  double get pulseScale {
    if (!isLastDiscard) return 1.0;
    final t = (_pulseTimer % 1.5) / 1.5;
    return 1.0 + 0.1 * (0.5 - 0.5 * (1.0 - (2 * t - 1).abs()));
  }

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
    _pulseTimer = 0.0;
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
    _pulseTimer = 0.0;
  }

  @override
  void update(double dt) {
    if (isLastDiscard) {
      _pulseTimer += dt;
    } else {
      _pulseTimer = 0.0;
    }
  }

  @override
  void render(Canvas canvas) {
    if (card == null || atlasImage == null || atlasLoader == null) return;
    canvas.save();
    if (isSelected) canvas.translate(0, -20);

    if (isLastDiscard) {
      canvas.scale(pulseScale, pulseScale);
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

    if (isLastDiscard) {
      final borderPaint = Paint()
        ..color = const Color(0xFFFFD700)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(0, 0, width, height),
          const Radius.circular(3),
        ),
        borderPaint,
      );
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
