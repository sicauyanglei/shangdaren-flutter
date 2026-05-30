# Flutter+Flame 与 WebView 视觉效果差异完整报告

生成时间: 2026-05-25
项目: 上大人字牌游戏
Flutter分支: feature/frame/webgl

---

## 差异总览

| # | 差异项 | WebView | Flame | 优先级 |
|---|--------|---------|-------|--------|
| 1 | 卡牌背景色 | CSS渐变区分红/绿/黑 | 仅精灵图，无背景 | P0 |
| 2 | 手牌堆叠重叠度 | ~130px (margin-bottom:-8.1rem) | 38.4px | P0 |
| 3 | 选牌效果 | translateY(-20px) scale(1.1) + 金色阴影 | 仅 translateY(-20px) + 边框 | P0 |
| 4 | 最后出牌高亮 | 脉冲动画 scale(1↔1.1) + 光晕 | 简单blink闪烁 | P1 |
| 5 | 摸牌标签 | 显示"摸"字金色标签 | 无 | P0 |
| 6 | 发牌动画 | 3阶段(deck→center旋转90°→hand) | 2阶段(deck→center停1s→hand) | P1 |
| 7 | 拖拽出牌 | 支持 drag-and-drop | 不支持 | P2 |
| 8 | 胜负特效 | winner光晕/loser抖动/score浮动 | 无 | P2 |
| 9 | 飘分弹窗 | DOM弹窗 | Flutter Widget | 保持Flutter |
| 10 | 玩家计时器 | 圆形进度环+倒计时 | Flutter Widget | 保持Flutter |
| 11 | 手牌数量角标 | card-count badge | 已实现 ✓ | - |
| 12 | 听牌badge位置 | 独立DOM元素在手牌右侧 | 绘制在卡牌右上角 | P2 |

---

## 详细差异说明

---

### 1. 卡牌背景色 [P0]

**WebView** (`index.html` 行 1714-1730):
```css
.card.red   { background: linear-gradient(145deg, #cc0000, #990000); border-color: #ff4444; }
.card.green { background: linear-gradient(145deg, #228822, #116611); border-color: #33bb33; }
.card.black { background: linear-gradient(145deg, #444, #222); border: 2px solid #666; }
```

**Flame** (`card_render.dart` 行 81-129):
- 只调用 `canvas.drawImageRect()` 绘制精灵图
- 无背景矩形，无颜色区分

**修复方案**: 在 `card_render.dart` 的 `render()` 方法中，`canvas.drawImageRect` 之前绘制渐变背景矩形

```dart
// 在 render() 方法 faceUp 分支中，绘制背景色
void _drawCardBackground(Canvas canvas, String character) {
  Color startColor, endColor, borderColor;
  if (character == '上' || character == '大' || character == '人') {
    // 红色
    startColor = const Color(0xFFCC0000);
    endColor = const Color(0xFF990000);
    borderColor = const Color(0xFFFF4444);
  } else if (character == '化' || character == '三' || character == '千' ||
             character == '七' || character == '十' || character == '土') {
    // 绿色
    startColor = const Color(0xFF228822);
    endColor = const Color(0xFF116611);
    borderColor = const Color(0xFF33BB33);
  } else {
    // 黑色
    startColor = const Color(0xFF444444);
    endColor = const Color(0xFF222222);
    borderColor = const Color(0xFF666666);
  }
  final rect = Rect.fromLTWH(0, 0, width, height);
  final gradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [startColor, endColor],
  );
  canvas.drawRect(rect, Paint()..shader = gradient.createShader(rect));
  canvas.drawRect(rect.deflate(1.5), Paint()
    ..color = borderColor
    ..style = PaintingStyle.stroke
    ..strokeWidth = 3);
}
```

**涉及文件**: `lib/game/render/card_render.dart`

---

### 2. 手牌堆叠重叠度 [P0]

**WebView** (`index.html` 行 1602-1619):
```css
.card-stack {
  width: 2.5rem;          /* 40px */
  height: 10.5rem;        /* 168px */
  margin-bottom: -8.1rem; /* 重叠约130px */
}
```

**Flame** (`game_board.dart` 行 24):
```dart
static const double handStackVisible = 38.4;
```

**差异分析**:
- WebView: 每列堆叠占用 2.5rem - 8.1rem = 2.4rem ≈ 38.4px (与Flame接近)
- 但 WebView 的 `.card-stack` 是垂直堆叠的容器，实际每张卡几乎完全重叠
- WebView 视觉上每列只有底部一张卡可见，堆叠3D效果明显

**修复方案**: 在 `game_board.dart` 中调整 `_layoutPlayer1Hand()` 的重叠计算

```dart
// 将 handStackVisible 从 38.4 改为更小的值实现更密堆叠
// 或者改变布局逻辑：按 sentence 分组，每组垂直堆叠
static const double handStackVisible = 24.0;  // 更密的堆叠
```

**注意**: WebView 的堆叠是按"句"分组，每句内部堆叠。当前 Flame 实现是按 position 堆叠。需要确认是按句堆叠还是按字堆叠。

**涉及文件**: `lib/game/render/game_board.dart` 行 249-285

---

### 3. 选牌效果 [P0]

**WebView** (`index.html` 行 1679-1683):
```css
.card.selected {
  transform: translateY(-20px) scale(1.1);
  box-shadow: 0 15px 30px rgba(255,215,0,0.9);
  border-color: #ffd700 !important;
}
```

**Flame** (`card_render.dart` 行 131-140):
```dart
if (isSelected) {
  canvas.drawRect(
    Rect.fromLTWH(1, 1, width - 2, height - 2),
    Paint()
      ..color = const Color(0xFFFFD700)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0,
  );
}
```

**缺失**:
1. `scale(1.1)` - 需要放大1.1倍
2. `box-shadow` - 金色阴影效果
3. 边框已实现，但样式不同

**修复方案**: 在 `CardRender.render()` 中实现完整选中效果

```dart
@override
void render(Canvas canvas) {
  if (card == null || atlasImage == null || atlasLoader == null) return;
  if (isLastDiscard && !_blinkVisible) return;

  canvas.save();

  // 选中时应用 scale 和 translate
  double drawX = 0, drawY = 0, drawScale = 1.0;
  if (isSelected) {
    drawY = -20;
    drawScale = 1.1;
    canvas.translate(drawX, drawY);
    canvas.scale(drawScale, drawScale);
  }

  // 绘制背景（如果实现了背景色）
  if (faceUp && card != null) {
    _drawCardBackground(canvas, card!.character);
  }

  // ... 绘制卡牌精灵图 ...

  // 选中时绘制金色阴影和边框
  if (isSelected) {
    // 绘制 box-shadow 效果（金色阴影向四周扩散）
    final shadowPaint = Paint()
      ..color = const Color(0xFFFFD700).withOpacity(0.6)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawRect(
      Rect.fromLTWH(-4, -4, width + 8, height + 8),
      shadowPaint,
    );
    // 绘制金色边框
    canvas.drawRect(
      Rect.fromLTWH(1, 1, width - 2, height - 2),
      Paint()
        ..color = const Color(0xFFFFD700)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0,
    );
  }

  canvas.restore();
}
```

**涉及文件**: `lib/game/render/card_render.dart`

---

### 4. 最后出牌高亮 [P1]

**WebView** (`index.html` 行 1694-1707):
```css
.last-discard {
  border: 2px solid #ffd700 !important;
  box-shadow: 0 0 8px rgba(255,215,0,0.8), 0 0 16px rgba(255,215,0,0.4) !important;
  animation: last-discard-pulse 1.5s infinite ease-in-out;
}
@keyframes last-discard-pulse {
  0%, 100% { transform: scale(1); box-shadow: 0 0 8px rgba(255,215,0,0.8), 0 0 16px rgba(255,215,0,0.4); }
  50% { transform: scale(1.1); box-shadow: 0 0 12px rgba(255,215,0,1), 0 0 24px rgba(255,215,0,0.6); }
}
```

**Flame** (`card_render.dart` 行 68-78):
```dart
if (isLastDiscard) {
  _blinkTimer += dt;
  if (_blinkTimer >= 0.5) {
    _blinkTimer -= 0.5;
    _blinkVisible = !_blinkVisible;
  }
}
```

**差异**:
- WebView: 脉冲动画 scale 1.0 ↔ 1.1 + 光晕变化，周期1.5s
- Flame: 简单的 0.5s blink 切换可见性

**修复方案**: 在 `card_render.dart` 中实现正弦波脉冲动画

```dart
// 成员变量
double _pulseTimer = 0.0;
static const double _pulseDuration = 1.5;

@Override
void update(double dt) {
  if (isLastDiscard) {
    _pulseTimer += dt;
    if (_pulseTimer >= _pulseDuration) {
      _pulseTimer -= _pulseDuration;
    }
  } else {
    _pulseTimer = 0.0;
    _blinkVisible = true;
  }
}

// 在 render() 中绘制高亮效果
if (isLastDiscard) {
  // 使用 sin 函数实现平滑脉冲
  final pulse = (math.sin(_pulseTimer / _pulseDuration * math.pi * 2) + 1) / 2; // 0~1
  final scale = 1.0 + pulse * 0.1; // 1.0 ~ 1.1
  final shadowAlpha = 0.4 + pulse * 0.4; // 0.4 ~ 0.8

  canvas.save();
  canvas.translate(width / 2, height / 2);
  canvas.scale(scale, scale);
  canvas.translate(-width / 2, -height / 2);

  // 绘制光晕
  final glowPaint = Paint()
    ..color = Color.fromRGBO(255, 215, 0, shadowAlpha)
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
  canvas.drawRect(
    Rect.fromLTWH(-3, -3, width + 6, height + 6),
    glowPaint,
  );

  // 绘制金色边框
  canvas.drawRect(
    Rect.fromLTWH(1, 1, width - 2, height - 2),
    Paint()
      ..color = const Color(0xFFFFD700)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0,
  );

  canvas.restore();
}
```

**涉及文件**: `lib/game/render/card_render.dart`

---

### 5. 摸牌标签 [P0]

**WebView** (`game.js` 行 5501-5515):
```javascript
if (playerIndex === 1) {
  // 为玩家1的摸牌显示"摸"标签
  const moLabel = document.createElement('div');
  moLabel.textContent = '摸';
  moLabel.style.position = 'absolute';
  moLabel.style.top = '50%';
  moLabel.style.left = '50%';
  moLabel.style.transform = 'translate(-50%, -50%)';
  moLabel.style.fontSize = '20px';
  moLabel.style.fontWeight = 'bold';
  moLabel.style.color = '#ffd700';
  moLabel.style.textShadow = '0 0 10px rgba(255,215,0,0.8), 0 0 20px rgba(255,0,0,0.6)';
  moLabel.style.background = 'rgba(0,0,0,0.7)';
  moLabel.style.padding = '5px 10px';
  moLabel.style.borderRadius = '8px';
  moLabel.style.border = '2px solid #ffd700';
  moLabel.style.zIndex = '10000';
  flyingCard.appendChild(moLabel);
}
```

**Flame**: 无此标签

**修复方案**: 在 `animation_system.dart` 的 `drawCardAnim()` 中添加"摸"标签渲染

```dart
// 在 DrawCardAnimation 中添加标签相关参数
class DrawCardAnimation {
  final FlyingCard stage1;
  final FlyingCard stage2;
  final bool showMoLabel;  // 新增
  // ...
}

// 在 render() 中绘制标签
void render(Canvas canvas, Image atlasImage, AtlasLoader atlasLoader) {
  // ... 绘制卡牌 ...
  if (showMoLabel && _stage == 1) {
    _renderMoLabel(canvas);
  }
}

void _renderMoLabel(Canvas canvas) {
  final textPainter = TextPainter(
    text: TextSpan(
      text: '摸',
      style: TextStyle(
        color: const Color(0xFFFFD700),
        fontSize: 20,
        fontWeight: FontWeight.bold,
        shadows: [
          Shadow(color: const Color(0xFFFFD700).withOpacity(0.8), blurRadius: 10),
          Shadow(color: const Color(0xFFFF0000).withOpacity(0.6), blurRadius: 20),
        ],
      ),
    ),
    textDirection: TextDirection.ltr,
  );
  textPainter.layout();
  // 在卡牌中心位置绘制
  canvas.save();
  canvas.translate(stage1.x + 20, stage1.y + 84); // 假设卡牌宽40高168
  // 绘制背景框
  canvas.drawRect(
    Rect.fromLTWH(-25, -15, 50, 30),
    Paint()..color = const Color(0xBB000000),
  );
  canvas.drawRect(
    Rect.fromLTWH(-25, -15, 50, 30),
    Paint()
      ..color = const Color(0xFFFFD700)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2,
  );
  textPainter.paint(canvas, Offset(-textPainter.width / 2, -textPainter.height / 2));
  canvas.restore();
}
```

**涉及文件**: `lib/game/render/animation_system.dart`

---

### 6. 发牌动画 [P1]

**WebView** (`game.js` 行 5450-5587):
- Stage 1 (0-500ms): deck → center, rotate 90°
- Stage 2 (500-1000ms): 暂停在 center
- Stage 3 (1000-1500ms): center → hand, rotate -90° (回到0°)
- 总时长: ~1500ms

**Flame** (`animation_system.dart` 行 125-172):
```dart
class DrawCardAnimation {
  // Stage 0: stage1 飞向 center (0.5s)
  // Stage 1: 等待 1.0s
  // Stage 2: stage2 飞向 hand (0.5s)
}
```

**缺失**:
1. 90度旋转动画
2. 暂停阶段的视觉表现

**修复方案**: 在 `DrawCardAnimation` 中添加 rotation 参数

```dart
class DrawCardAnimation {
  // 修改 FlyingCard 添加 rotation
  // stage1: rotation = 90° (deck → center 旋转90°)
  // stage2: rotation = 0° (center → hand 旋转回0°)

  // 同时在 wait 阶段绘制卡牌在 center 位置（带旋转）
}

// 修改 drawCardAnim()
DrawCardAnimation drawCardAnim({
  // ...
  double rotation = 0,  // 新增
}) {
  final stage1 = FlyingCard(
    // ...
    rotation: 90 * math.pi / 180,  // 90度
  );
  final stage2 = FlyingCard(
    // ...
    rotation: 0,
  );
}
```

**涉及文件**: `lib/game/render/animation_system.dart`

---

### 7. 拖拽出牌 [P2]

**WebView** (`game.js` 行 2557-2632):
- `startDrag()` - 创建悬浮卡牌 + "出"标签
- `moveDrag()` - 跟随触摸/鼠标
- `endDrag()` - 拖出区域外则出牌

**Flame**: 不支持

**修复方案**: 需要在 Flame 中实现手势检测

```dart
// 在 CardRender 中添加拖拽支持
class CardRender extends PositionComponent with HasGameRef, Draggable {
  // 重写 onDragStart, onDragUpdate, onDragEnd
  // 或者在 GameOverlay 中处理手势
}

// 更简单的方案：在 Flutter 层处理拖拽
// 在 game_overlay.dart 或 main.dart 中使用 GestureDetector
```

**涉及文件**: `lib/game/render/card_render.dart`, `lib/game/ui/game_overlay.dart`

---

### 8. 胜负特效 [P2]

**WebView** (`game.js` 行 8240-8293):
- `winner`: 金色光晕 `box-shadow: 0 0 15px rgba(255,215,0,0.7)`
- `loser`: 抖动动画 `animation: shake 0.5s`
- `score-diff`: 浮动分数文字 `+100` / `-50` 渐隐

**Flame**: 无此效果

**修复方案**: 在 `AnimationSystem` 中添加特效组件

```dart
class FloatingText {
  String text;
  double x, y;
  double opacity;
  Color color;
  // update() 中 y += 速度, opacity -= 衰减
}

class AvatarEffect {
  enum EffectType { winnerGlow, loserShake }
  // update() 中处理动画
}

// 在 shangdaren_game.dart 中调用
void showWinnerEffect(int playerIndex) {
  _animationSystem!.addEffect(AvatarEffect(playerIndex, .winnerGlow));
}

void showScoreFloat(int playerIndex, int diff) {
  _animationSystem!.addFloatingText(
    text: (diff > 0 ? '+' : '') + '$diff',
    x: playerX, y: playerY,
    color: diff > 0 ? Colors.green : Colors.red,
  );
}
```

**涉及文件**: `lib/game/render/animation_system.dart`, `lib/game/shangdaren_game.dart`

---

### 9. 飘分弹窗 [保持Flutter]

Flutter Widget 实现更优，无需修改。

---

### 10. 玩家计时器 [保持Flutter]

Flutter Widget 实现更优，无需修改。现有 `GameOverlay` 已实现倒计时功能。

---

### 11. 手牌数量角标 [已实现 ✓]

`game_board.dart` 行 714-741 已实现数量角标。

---

### 12. 听牌Badge位置 [P2]

**WebView** (`index.html` 行 1479-1491):
```css
.ting-badge {
  position: absolute;
  top: 0;
  right: -50px;  /* 在手牌区域外 */
}
```

**Flame** (`game_board.dart` 行 706-711):
```dart
if (cr.showTingBadge) {
  canvas.drawCircle(
    Offset(handCardW - 8, 8),  // 在卡牌右上角
    6,
    Paint()..color = const Color(0xFFFF4444),
  );
}
```

**差异**: WebView 是独立元素定位在手牌右侧；Flame 是在卡牌角上绘制圆点

**修复方案**: 保持当前实现或调整为独立元素风格（取决于UI需求）

---

## 修复优先级建议

### Phase 1 (立即修复)
| # | 差异项 | 文件 | 工作量 |
|---|--------|------|--------|
| 1 | 卡牌背景色 | card_render.dart | 2h |
| 5 | 摸牌标签 | animation_system.dart | 1h |
| 3 | 选牌效果 | card_render.dart | 2h |

### Phase 2 (下一迭代)
| # | 差异项 | 文件 | 工作量 |
|---|--------|------|--------|
| 4 | 最后出牌高亮脉冲 | card_render.dart | 2h |
| 6 | 发牌动画旋转 | animation_system.dart | 3h |
| 2 | 手牌堆叠重叠度 | game_board.dart | 2h |

### Phase 3 (后续优化)
| # | 差异项 | 文件 | 工作量 |
|---|--------|------|--------|
| 8 | 胜负特效 | animation_system.dart | 4h |
| 7 | 拖拽出牌 | game_overlay.dart | 6h |
| 12 | 听牌Badge位置 | game_board.dart | 1h |

---

## WebView 相关文件索引

| 文件 | 关键行 | 用途 |
|------|--------|------|
| `assets/html/index.html` | 1602-1730 | CSS样式定义 |
| `assets/html/game.js` | 5450-5635 | 动画JS代码 |
| `assets/html/game.js` | 8079-8090 | 选牌JS代码 |
| `assets/html/game.js` | 8240-8293 | 胜负特效JS代码 |

## Flame 相关文件索引

| 文件 | 关键行 | 用途 |
|------|--------|------|
| `lib/game/render/card_render.dart` | 82-151 | 卡牌渲染 |
| `lib/game/render/game_board.dart` | 249-285 | 手牌布局 |
| `lib/game/render/animation_system.dart` | 125-280 | 动画系统 |
| `lib/game/shangdaren_game.dart` | 157-256 | 动画触发 |

---

## 附录：卡牌颜色分类

```javascript
// WebView 中的卡牌颜色分类 (game.js)
const RED_CARDS = ['上', '大', '人'];
const GREEN_CARDS = ['化', '三', '千', '七', '十', '土'];
// 其他为黑色
```

```dart
// Flame 中应使用的颜色 (card_render.dart)
const _redCards = ['上', '大', '人'];
const _greenCards = ['化', '三', '千', '七', '十', '土'];
```