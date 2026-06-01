import 'dart:ui';
import 'package:flame/camera.dart';
import 'package:flame/extensions.dart';
import 'package:flame/src/effects/provider_interfaces.dart';
import 'package:shangdaren_game/game/core/game_logger.dart';

class StretchViewport extends Viewport implements ReadOnlyScaleProvider {
  StretchViewport({required this.resolution});

  final Vector2 resolution;

  Rect _clipRect = Rect.zero;

  @override
  Vector2 get virtualSize => resolution;

  @override
  Vector2 get scale => transform.scale;

  @override
  void onLoad() {
    final canvasSize = findGame()!.canvasSize;
    _handleResize(canvasSize);
  }

  @override
  void onGameResize(Vector2 size) {
    _handleResize(size);
  }

  void _handleResize(Vector2 canvasSize) {
    position.setZero();
    _clipRect = Rect.fromLTRB(0, 0, canvasSize.x, canvasSize.y);
    _updateTransformScale(canvasSize);
  }

  void _updateTransformScale(Vector2 canvasSize) {
    final scaleX = canvasSize.x / resolution.x;
    final scaleY = canvasSize.y / resolution.y;
    transform.scale = Vector2(scaleX, scaleY);
    camera.viewfinder.visibleRect = null;

    GameLogger.i(
      "Viewport",
      "Stretch: canvas=${canvasSize.x}x${canvasSize.y}, resolution=${resolution.x}x${resolution.y}, scale=($scaleX,$scaleY)",
    );
  }

  @override
  void onViewportResize() {
    final canvasSize = findGame()!.canvasSize;
    _updateTransformScale(canvasSize);
  }

  @override
  void clip(Canvas canvas) {
    canvas.clipRect(_clipRect, doAntiAlias: false);
  }

  @override
  bool containsLocalPoint(Vector2 point) {
    final x = point.x;
    final y = point.y;
    return x >= 0 && x <= virtualSize.x && y >= 0 && y <= virtualSize.y;
  }

  @override
  Vector2 globalToLocal(Vector2 point, {Vector2? output}) {
    final viewportPoint = super.globalToLocal(point, output: output);
    return transform.globalToLocal(viewportPoint, output: output);
  }

  @override
  Vector2 localToGlobal(Vector2 point, {Vector2? output}) {
    final viewportPoint = transform.localToGlobal(point, output: output);
    return super.localToGlobal(viewportPoint, output: output);
  }

  @override
  void transformCanvas(Canvas canvas) {
    final canvasSize = findGame()!.canvasSize;
    final s = transform.scale;

    canvas.save();
    canvas.scale(s.x, s.y);

    GameLogger.d("Canvas", "transformCanvas: scale=(${s.x},${s.y})");
  }

  @override
  Vector2 get size => findGame()!.canvasSize;
}
