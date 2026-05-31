import 'dart:ui';
import 'dart:math';
import 'package:flame/components.dart';
import 'package:flutter/painting.dart';
import '../core/atlas_loader.dart';
import '../models/card.dart';

class FlyingCard {
  final Card card;
  final bool faceUp;
  double x;
  double y;
  double fromX;
  double fromY;
  double toX;
  double toY;
  double scaleX;
  double scaleY;
  double rotation;
  double duration;
  double elapsed;
  double opacity;
  final double? destW;
  final double? destH;
  void Function()? onComplete;

  static const double handCardW = 56.0;
  static const double handCardH = 224.0;
  static const double deckCardW = 160.0;
  static const double deckCardH = 40.0;

  FlyingCard({
    required this.card,
    this.faceUp = true,
    this.x = 0,
    this.y = 0,
    this.fromX = 0,
    this.fromY = 0,
    this.toX = 0,
    this.toY = 0,
    this.scaleX = 1.0,
    this.scaleY = 1.0,
    this.rotation = 0,
    this.duration = 0.3,
    this.elapsed = 0,
    this.opacity = 1.0,
    this.destW,
    this.destH,
    this.onComplete,
  });

  bool update(double dt) {
    elapsed += dt;
    final t = min(elapsed / duration, 1.0);
    final eased = _easeInOutCubic(t);
    x = fromX + (toX - fromX) * eased;
    y = fromY + (toY - fromY) * eased;
    if (t >= 1.0) {
      onComplete?.call();
      return true;
    }
    return false;
  }

  void render(Canvas canvas, Image atlasImage, AtlasLoader atlasLoader) {
    final SpriteInfo? info;
    if (faceUp) {
      info = atlasLoader.getSpriteByChar(card.character);
    } else {
      info = atlasLoader.getSprite('back');
    }
    if (info == null) return;

    final paint = Paint()
      ..color = Color.fromRGBO(255, 255, 255, opacity)
      ..filterQuality = FilterQuality.high;

    canvas.save();
    canvas.translate(x, y);
    if (rotation != 0) canvas.rotate(rotation);

    if (faceUp && info.rotated) {
      final destH = handCardH * scaleY;
      final destW = handCardW * scaleX;
      canvas.rotate(-pi / 2);
      canvas.translate(-destH, 0);
      canvas.drawImageRect(
        atlasImage,
        Rect.fromLTWH(
          info.srcX.toDouble(),
          info.srcY.toDouble(),
          info.srcW.toDouble(),
          info.srcH.toDouble(),
        ),
        Rect.fromLTWH(0, 0, destH, destW),
        paint,
      );
    } else if (!faceUp) {
      final dw = destW ?? (deckCardW * scaleX);
      final dh = destH ?? (deckCardH * scaleY);
      canvas.drawImageRect(
        atlasImage,
        Rect.fromLTWH(
          info.srcX.toDouble(),
          info.srcY.toDouble(),
          info.srcW.toDouble(),
          info.srcH.toDouble(),
        ),
        Rect.fromLTWH(0, 0, dw, dh),
        paint,
      );
    } else {
      final destW = handCardW * scaleX;
      final destH = handCardH * scaleY;
      canvas.drawImageRect(
        atlasImage,
        Rect.fromLTWH(
          info.srcX.toDouble(),
          info.srcY.toDouble(),
          info.srcW.toDouble(),
          info.srcH.toDouble(),
        ),
        Rect.fromLTWH(0, 0, destW, destH),
        paint,
      );
    }

    canvas.restore();
  }
}

class DrawCardAnimation {
  final FlyingCard stage1;
  final FlyingCard stage2;
  final bool showMoLabel;
  int _stage = 0;
  double _waitElapsed = 0;
  static const double waitDuration = 1.0;

  DrawCardAnimation({
    required FlyingCard stage1,
    required FlyingCard stage2,
    this.showMoLabel = false,
  }) : stage1 = stage1,
       stage2 = stage2;

  bool update(double dt) {
    switch (_stage) {
      case 0:
        if (stage1.update(dt)) {
          _stage = 1;
          _waitElapsed = 0;
        }
        return false;
      case 1:
        _waitElapsed += dt;
        if (_waitElapsed >= waitDuration) {
          _stage = 2;
          stage2.x = stage1.toX;
          stage2.y = stage1.toY;
        }
        return false;
      case 2:
        return stage2.update(dt);
      default:
        return true;
    }
  }

  void render(Canvas canvas, Image atlasImage, AtlasLoader atlasLoader) {
    switch (_stage) {
      case 0:
        stage1.render(canvas, atlasImage, atlasLoader);
        break;
      case 1:
        stage1.render(canvas, atlasImage, atlasLoader);
        if (showMoLabel) {
          _renderMoLabel(
            canvas,
            stage1.x,
            stage1.y,
            FlyingCard.handCardW,
            FlyingCard.handCardH,
          );
        }
        break;
      case 2:
        stage2.render(canvas, atlasImage, atlasLoader);
        if (showMoLabel) {
          _renderMoLabel(
            canvas,
            stage2.x,
            stage2.y,
            FlyingCard.handCardW * stage2.scaleX,
            FlyingCard.handCardH * stage2.scaleY,
          );
        }
        break;
    }
  }

  void _renderMoLabel(
    Canvas canvas,
    double cardX,
    double cardY,
    double cardW,
    double cardH,
  ) {
    const fontSize = 20.0;
    final tp = TextPainter(
      text: TextSpan(
        text: '摸',
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
          color: const Color(0xFFffd700),
          shadows: const [
            Shadow(color: Color(0xCCffd700), blurRadius: 10),
            Shadow(color: Color(0x99ff0000), blurRadius: 20),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    tp.layout();

    final labelW = tp.width + 20;
    final labelH = tp.height + 10;
    final cx = cardX + cardW / 2;
    final cy = cardY + cardH / 2;

    canvas.save();
    final bgPaint = Paint()..color = const Color(0xB3000000);
    final bgRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(cx, cy), width: labelW, height: labelH),
      const Radius.circular(8),
    );
    canvas.drawRRect(bgRect, bgPaint);

    final borderPaint = Paint()
      ..color = const Color(0xFFffd700)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawRRect(bgRect, borderPaint);

    tp.paint(canvas, Offset(cx - tp.width / 2, cy - tp.height / 2));
    canvas.restore();
  }
}

class MeldAnimation {
  final List<FlyingCard> cards;
  double _fadeElapsed = 0;
  static const double fadeDuration = 0.3;
  static const double flyDuration = 0.4;
  static const double showDuration = 0.45;
  static const double toMeldDuration = 0.3;
  static const double toMeldStagger = 0.08;
  bool _flyComplete = false;
  bool _showComplete = false;
  bool _toMeldStarted = false;
  int _toMeldIndex = 0;
  double _toMeldTimer = 0;
  bool _toMeldComplete = false;
  double _opacity = 1.0;
  final double _centerX;
  final double _centerY;
  final List<Offset> _meldPositions;
  final List<double> _meldScales;
  void Function()? onComplete;

  MeldAnimation({
    required this.cards,
    required double centerX,
    required double centerY,
    List<Offset>? meldPositions,
    List<double>? meldScales,
    this.onComplete,
  }) : _centerX = centerX,
       _centerY = centerY,
       _meldPositions = meldPositions ?? [],
       _meldScales = meldScales ?? [];

  bool update(double dt) {
    if (!_flyComplete) {
      bool allDone = true;
      for (final card in cards) {
        if (!card.update(dt)) {
          allDone = false;
        }
      }
      if (allDone) {
        _flyComplete = true;
        _fadeElapsed = 0;
      }
      return false;
    }

    if (!_showComplete) {
      _fadeElapsed += dt;
      if (_fadeElapsed >= showDuration) {
        _showComplete = true;
        _fadeElapsed = 0;
        if (_meldPositions.isNotEmpty) {
          _toMeldStarted = true;
          _toMeldTimer = 0;
          _toMeldIndex = 0;
          _startMeldFly(0);
        }
      }
      return false;
    }

    if (_toMeldStarted && !_toMeldComplete) {
      _toMeldTimer += dt;
      if (_toMeldIndex < cards.length - 1 && _toMeldTimer >= toMeldStagger) {
        _toMeldTimer -= toMeldStagger;
        _toMeldIndex++;
        _startMeldFly(_toMeldIndex);
      }
      bool allDone = true;
      for (final card in cards) {
        if (!card.update(dt)) {
          allDone = false;
        }
      }
      if (allDone) {
        _toMeldComplete = true;
        _toMeldStarted = false;
      }
      return false;
    }

    if (_toMeldComplete) {
      onComplete?.call();
      return true;
    }

    _fadeElapsed += dt;
    final t = (_fadeElapsed / fadeDuration).clamp(0.0, 1.0);
    _opacity = 1.0 - t;
    if (t >= 1.0) {
      onComplete?.call();
      return true;
    }
    return false;
  }

  void _startMeldFly(int index) {
    if (index >= _meldPositions.length || index >= _meldScales.length) return;
    final card = cards[index];
    card.fromX = card.x;
    card.fromY = card.y;
    card.toX = _meldPositions[index].dx;
    card.toY = _meldPositions[index].dy;
    card.scaleX = _meldScales[index];
    card.scaleY = _meldScales[index];
    card.elapsed = 0;
    card.duration = toMeldDuration;
  }

  void render(Canvas canvas, Image atlasImage, AtlasLoader atlasLoader) {
    if (_opacity <= 0 && !_toMeldStarted) return;
    for (int i = 0; i < cards.length; i++) {
      final card = cards[i];
      final savedOpacity = card.opacity;
      if (!_toMeldStarted) {
        card.opacity = card.opacity * _opacity;
      }
      card.render(canvas, atlasImage, atlasLoader);
      card.opacity = savedOpacity;

      if (i == 0 && !_flyComplete) {
        final cardW = FlyingCard.handCardW * card.scaleX;
        final cardH = FlyingCard.handCardH * card.scaleY;
        final borderPaint = Paint()
          ..color = const Color(0xFFFFD700)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3;
        final rrect = RRect.fromRectAndRadius(
          Rect.fromLTWH(card.x, card.y, cardW, cardH),
          const Radius.circular(6),
        );
        canvas.drawRRect(rrect, borderPaint);

        final glowPaint = Paint()
          ..color = const Color(0xFFFFD700).withValues(alpha: 0.5)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(card.x - 3, card.y - 3, cardW + 6, cardH + 6),
            const Radius.circular(9),
          ),
          glowPaint,
        );
      }
    }
  }
}

class AnimationSystem extends Component {
  Image? atlasImage;
  AtlasLoader? atlasLoader;

  final List<FlyingCard> _flyingCards = [];
  final List<DrawCardAnimation> _drawAnims = [];
  final List<MeldAnimation> _meldAnims = [];
  final List<ScoreChangeAnimation> _scoreChangeAnims = [];

  FlyingCard flyCard({
    required Card card,
    required double fromX,
    required double fromY,
    required double toX,
    required double toY,
    bool faceUp = true,
    double scaleX = 1.0,
    double scaleY = 1.0,
    double rotation = 0,
    double duration = 0.3,
    void Function()? onComplete,
  }) {
    final fc = FlyingCard(
      card: card,
      faceUp: faceUp,
      fromX: fromX,
      fromY: fromY,
      toX: toX,
      toY: toY,
      x: fromX,
      y: fromY,
      scaleX: scaleX,
      scaleY: scaleY,
      rotation: rotation,
      duration: duration,
      onComplete: onComplete,
    );
    _flyingCards.add(fc);
    return fc;
  }

  DrawCardAnimation drawCardAnim({
    required Card card,
    required double deckX,
    required double deckY,
    required double centerX,
    required double centerY,
    required double handX,
    required double handY,
    bool faceUp = true,
    double handScale = 1.0,
    bool showMoLabel = false,
    double? handDestW,
    double? handDestH,
    void Function()? onComplete,
  }) {
    final stage1 = FlyingCard(
      card: card,
      faceUp: false,
      fromX: deckX,
      fromY: deckY,
      toX: centerX,
      toY: centerY,
      duration: 0.5,
    );
    final stage2 = FlyingCard(
      card: card,
      faceUp: faceUp,
      fromX: centerX,
      fromY: centerY,
      toX: handX,
      toY: handY,
      scaleX: handScale,
      scaleY: handScale,
      duration: 0.5,
      destW: handDestW,
      destH: handDestH,
      onComplete: onComplete,
    );
    final anim = DrawCardAnimation(
      stage1: stage1,
      stage2: stage2,
      showMoLabel: showMoLabel,
    );
    _drawAnims.add(anim);
    return anim;
  }

  void clearAll() {
    _flyingCards.clear();
    _drawAnims.clear();
    _meldAnims.clear();
  }

  MeldAnimation meldAnim({
    required List<Card> cards,
    required int playerId,
    required String meldType,
    required double centerX,
    required double centerY,
    required double discardX,
    required double discardY,
    double playerHandX = 0,
    double playerHandY = 0,
    List<Offset>? meldPositions,
    List<double>? meldScales,
    void Function()? onComplete,
  }) {
    final meldCenterY = centerY * 0.64;
    final meldScale = 0.5;
    final meldCardW = FlyingCard.handCardW * meldScale;
    final meldCardH = FlyingCard.handCardH * meldScale;
    final gap = 2.0;
    final totalW = cards.length * meldCardW + (cards.length - 1) * gap;
    final startX = centerX - totalW / 2;

    final flyingCards = <FlyingCard>[];
    for (int i = 0; i < cards.length; i++) {
      final card = cards[i];
      double fromX, fromY;
      if (i == 0) {
        fromX = discardX;
        fromY = discardY;
      } else {
        fromX = playerHandX;
        fromY = playerHandY;
      }

      final toX = startX + i * (meldCardW + gap);
      final toY = meldCenterY;

      flyingCards.add(
        FlyingCard(
          card: card,
          faceUp: true,
          fromX: fromX,
          fromY: fromY,
          toX: toX,
          toY: toY,
          x: fromX,
          y: fromY,
          scaleX: meldScale,
          scaleY: meldScale,
          duration: 0.4,
        ),
      );
    }

    final anim = MeldAnimation(
      cards: flyingCards,
      centerX: centerX,
      centerY: meldCenterY,
      meldPositions: meldPositions,
      meldScales: meldScales,
      onComplete: onComplete,
    );
    _meldAnims.add(anim);
    return anim;
  }

  ScoreChangeAnimation scoreChangeAnim({
    required List<Map<String, dynamic>> scoreChanges,
    required List<Offset> fromPositions,
    required List<Offset> targetPositions,
    void Function(int index)? onArrive,
    void Function()? onComplete,
  }) {
    final scores = <FlyingScore>[];
    for (
      int i = 0;
      i < scoreChanges.length &&
          i < fromPositions.length &&
          i < targetPositions.length;
      i++
    ) {
      final change = scoreChanges[i];
      final idx = i;
      scores.add(
        FlyingScore(
          scoreChange: change['score'] as int,
          isGain: change['isGain'] as bool,
          fromX: fromPositions[i].dx,
          fromY: fromPositions[i].dy,
          toX: targetPositions[i].dx,
          toY: targetPositions[i].dy,
          duration: 2.0,
          onArrive: () => onArrive?.call(idx),
        ),
      );
    }

    final anim = ScoreChangeAnimation(scores: scores, onComplete: onComplete);
    _scoreChangeAnims.add(anim);
    return anim;
  }

  @override
  void update(double dt) {
    for (int i = _flyingCards.length - 1; i >= 0; i--) {
      if (_flyingCards[i].update(dt)) {
        _flyingCards.removeAt(i);
      }
    }
    for (int i = _drawAnims.length - 1; i >= 0; i--) {
      if (_drawAnims[i].update(dt)) {
        _drawAnims.removeAt(i);
      }
    }
    for (int i = _meldAnims.length - 1; i >= 0; i--) {
      if (_meldAnims[i].update(dt)) {
        _meldAnims.removeAt(i);
      }
    }
    for (int i = _scoreChangeAnims.length - 1; i >= 0; i--) {
      if (_scoreChangeAnims[i].update(dt)) {
        _scoreChangeAnims.removeAt(i);
      }
    }
  }

  @override
  void render(Canvas canvas) {
    for (final sa in _scoreChangeAnims) {
      sa.render(canvas);
    }
    if (atlasImage == null || atlasLoader == null) return;
    for (final fc in _flyingCards) {
      fc.render(canvas, atlasImage!, atlasLoader!);
    }
    for (final da in _drawAnims) {
      da.render(canvas, atlasImage!, atlasLoader!);
    }
    for (final ma in _meldAnims) {
      ma.render(canvas, atlasImage!, atlasLoader!);
    }
  }
}

double _easeOutCubic(double t) {
  return 1 - pow(1 - t, 3).toDouble();
}

double _easeInOutCubic(double t) {
  return t < 0.5 ? 4 * t * t * t : 1 - pow(-2 * t + 2, 3) / 2;
}

class FlyingScore {
  final int scoreChange;
  final bool isGain;
  double x;
  double y;
  double fromX;
  double fromY;
  double toX;
  double toY;
  double duration;
  double elapsed;
  void Function()? onComplete;
  void Function()? onArrive;
  bool _arrived = false;
  double _arriveElapsed = 0;
  static const double arriveDuration = 1.2;

  static const double flyFontSize = 36.0;
  static const double arriveFontSize = 20.0;

  FlyingScore({
    required this.scoreChange,
    required this.isGain,
    this.x = 0,
    this.y = 0,
    this.fromX = 0,
    this.fromY = 0,
    this.toX = 0,
    this.toY = 0,
    this.duration = 0.6,
    this.elapsed = 0,
    this.onComplete,
    this.onArrive,
  });

  bool update(double dt) {
    if (_arrived) {
      _arriveElapsed += dt;
      if (_arriveElapsed >= arriveDuration) {
        onComplete?.call();
        return true;
      }
      return false;
    }

    elapsed += dt;
    final t = min(elapsed / duration, 1.0);
    final eased = _easeInOutCubic(t);
    x = fromX + (toX - fromX) * eased;
    y = fromY + (toY - fromY) * eased;
    if (t >= 1.0) {
      _arrived = true;
      onArrive?.call();
    }
    return false;
  }

  void render(Canvas canvas) {
    if (_arrived) {
      final at = _arriveElapsed / arriveDuration;
      double alpha = 1.0;
      if (at > 0.7) {
        alpha = 1.0 - (at - 0.7) / 0.3;
      }
      final text = isGain ? '+$scoreChange' : '-$scoreChange';
      final color = isGain ? const Color(0xFFffd700) : const Color(0xFFff6b6b);
      final tp = TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(
            fontSize: arriveFontSize,
            fontWeight: FontWeight.bold,
            color: color.withValues(alpha: alpha),
            shadows: [
              Shadow(
                color: const Color(0x88000000).withValues(alpha: alpha),
                blurRadius: 4,
              ),
            ],
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      tp.layout();
      canvas.save();
      canvas.translate(x - tp.width / 2, y - tp.height);
      tp.paint(canvas, Offset.zero);
      canvas.restore();
      return;
    }

    final text = isGain ? '+$scoreChange' : '-$scoreChange';
    final color = isGain ? const Color(0xFFffd700) : const Color(0xFFff6b6b);

    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: flyFontSize,
          fontWeight: FontWeight.bold,
          color: color,
          shadows: [
            Shadow(color: color.withValues(alpha: 0.6), blurRadius: 12),
            Shadow(color: color.withValues(alpha: 0.3), blurRadius: 24),
            Shadow(color: const Color(0x88000000), blurRadius: 4),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    tp.layout();

    canvas.save();
    canvas.translate(x - tp.width / 2, y - tp.height / 2);
    tp.paint(canvas, Offset.zero);
    canvas.restore();
  }
}

class ScoreChangeAnimation {
  final List<FlyingScore> scores;
  bool _allComplete = false;
  void Function()? onComplete;

  ScoreChangeAnimation({required this.scores, this.onComplete});

  bool update(double dt) {
    if (_allComplete) return true;

    bool allDone = true;
    for (final score in scores) {
      if (!score.update(dt)) {
        allDone = false;
      }
    }

    if (allDone) {
      _allComplete = true;
      onComplete?.call();
      return true;
    }

    return false;
  }

  void render(Canvas canvas) {
    for (final score in scores) {
      score.render(canvas);
    }
  }
}
