# 会话修改记录

## 1. 徽章位置修复

**文件：** `flutter_app/lib/game/render/game_board.dart` — `_renderPlayerHuBadges`

**问题：** Player0(玩家1)的徽章 startY 使用 `720 - 114 - badgeH`，这是人类玩家头像区域顶部，但玩家1头像在左上角(y≈4.8)，导致徽章显示在屏幕底部。

**修复：** 重新计算各玩家头像区域位置，使用精确坐标：
- Player0：`startX = 9.6 + avatarW + 10`，`startY = 4.8 + 108 - badgeH`（头像右边，底部对齐）
- Player1：`startX = 10 + avatarW + 10`，`startY = 720 - 5 - 108`（头像右边，顶部对齐）
- Player2：`startX = 1280 - 9.6 - avatarW - totalW - 10`，`startY = 4.8 + 108 - badgeH`（头像左边，底部对齐）

## 2. 徽章文字居中

**文件：** `flutter_app/lib/game/render/game_board.dart` — `_renderPlayerHuBadges`

**问题：** 徽章文字垂直方向偏上。

**修复：** `startY + padV` → `startY + (badgeH - tp.height) / 2`

## 3. 听牌判断增加胡数检查

**文件：** `flutter_app/lib/game/logic/ting_checker.dart` — `_canHu`

**问题：** `_canHu` 只检查手牌结构条件（D集/E集），不检查总胡数是否≥11。导致胡数不够的牌型被误判为听牌。

**修复：** `_canHu` 增加 `melds` 参数，结构条件通过后调用 `HuCalculator.canHu(hand, melds)` 检查胡数和特殊胡牌类型。

## 4. HuCalculator.canHu 新增方法

**文件：** `flutter_app/lib/game/logic/hu_calculator.dart`

**新增：** `canHu(List<Card> hand, List<Meld> melds)` 静态方法，判断逻辑：
1. 总胡数 ≥ 11 → 可以胡
2. 满足特殊胡牌类型（十对、黑元、红元、枯胡、清枯胡、清枯重台）→ 也可以胡

## 5. 自摸/点炮判断统一使用 HuCalculator.canHu

**文件：** `flutter_app/lib/game/logic/game_controller.dart`

**问题：** `_canZimo` 和 `_canHuWith` 只检查 `eSet.isEmpty && dSet.isEmpty` 和 `dSet.length == 1 && eSet.isEmpty`，缺少十对等特殊胡牌类型的检查。

**修复：** 简化为直接调用 `HuCalculator.canHu(hand, melds)`。

## 6. 靠提取修复（pos0+pos2遗漏）

**文件：** `flutter_app/lib/game/logic/hu_calculator.dart` — `extractDuiAndKao`

**问题：** 提取靠时只匹配相邻position（pos0+pos1 或 pos1+pos2），遗漏了 pos0+pos2 的情况。如佳(pos0)和亡(pos2)同在组7、不同字，应该组成靠但被跳过。

**修复：** 将靠的匹配从只检查相邻position改为检查所有不同position的组合，符合"同组不同2张"的规则定义。

## 7. 头像区域宽度统一

**文件：** `flutter_app/lib/game/ui/game_overlay.dart`

**问题：** `_AIPlayerInfo` 和 `_MyPlayerInfo` 的 Container 宽度随文字内容变化，导致三个玩家头像区域大小不一致。

**修复：** 两者都添加 `constraints: BoxConstraints(minWidth: 250)`，统一最小宽度。

**文件：** `flutter_app/lib/game/render/game_board.dart`

**配套修改：** 徽章位置计算中的 `avatarW` 从 220 更新为 250。

## 8. 分数计算修复

**文件：** `flutter_app/lib/game/logic/score_calculator.dart`

**问题：** 用 `totalHu ~/ 10` 计算倍数，台胡(23-32胡)算出 baseMultiplier=2，点炮分数=9。但按规则台胡点炮倍数 B=1，应该是7。

**修复：** 改用 `HuTypeResult` 的 `dianpao`/`zimo` 倍数替代 `totalHu ~/ 10`。自摸公式中 `(baseMultiplier + 1)` 修正为 `baseMultiplier`（zimo值已包含+1）。

**文件：** `flutter_app/lib/game/logic/game_controller.dart`

**配套修改：** `_handleHu` 中调用 `ScoreCalculator.calculateScores` 时传入 `huTypeResult`。

## 9. HuCalculator.canHu 增加结构检查优先

**文件：** `flutter_app/lib/game/logic/hu_calculator.dart`

**问题：** `canHu` 只检查胡数≥11和特殊胡牌类型，不检查结构条件。手牌"三千生生生佳作亡禄寿" + "佳"胡数21≥11但结构为D=2/E=1，不应胡牌却显示了胡按钮。

**修复：** 在 `canHu` 方法开头增加 `_checkStructural` 检查，结构不满足直接返回false。`_checkStructural` 检查：D=0/E=0, D=0/E=1, D=1/E=0, 或10+对。

## 10. 自摸按钮显示修复

**文件：** `flutter_app/lib/game/ui/game_overlay.dart`, `flutter_app/lib/game/logic/game_controller.dart`

**问题：** 摸牌后满足自摸条件时，显示的是"胡"按钮而不是"自摸"按钮。

**修复：** 新增 `isZimoOpportunity` 标志区分自摸和点炮场景。摸牌完成后设置 `isZimoOpportunity = true`，UI层根据此标志显示"自摸"按钮而非"胡"按钮。

## 11. 自摸不要求isTing

**文件：** `flutter_app/lib/game/logic/game_controller.dart`

**问题：** `_canZimo` 和 `_handleHu` 中自摸也要求 `player.isTing`，但自摸时摸到的牌本身可以完成胡牌结构（D=1/E=0），不一定满足听牌结构（D=0/E=1或D=2/E=0）。

**修复：** `_canZimo` 不再检查 `player.isTing`；`_handleHu` 中自摸时不检查 `isTing`，点炮时仍需检查。

## 12. 操作按钮互斥规则

**文件：** `flutter_app/lib/game/ui/action_buttons.dart`, `flutter_app/lib/game/ui/game_overlay.dart`

**问题：** 显示"胡"/"自摸"按钮时，还同时显示"吃""碰""招""过"按钮。

**修复：** `canHu` 为true时，只显示"胡"按钮，隐藏其他所有按钮；自摸场景在overlay层单独显示"自摸"按钮，不显示"过"按钮。

## 13. 胡牌面板自摸输家分数单独显示

**文件：** `flutter_app/lib/game/render/game_board.dart` — `_renderHuResult`

**问题：** 自摸时所有输家分数合并显示。

**修复：** 自摸时遍历所有输家，每个输家单独显示"玩家名: 分数"。

## 14. 分数飞动动画修复

**文件：** `flutter_app/lib/game/shangdaren_game.dart`, `flutter_app/lib/game/render/animation_system.dart`

**问题：** 点击胡牌面板时分数动画重复执行；所有玩家显示相同分数。

**修复：** 新增 `_scoreAnimPlayed` 标志，动画只在面板首次显示时执行一次；使用 `huResultScoreChanges` 获取各玩家实际分数变化；飞动时长从0.8秒改为1.5秒。

## 15. 胡牌面板AI手牌与组合牌间隔

**文件：** `flutter_app/lib/game/render/game_board.dart`

**问题：** 胡牌面板显示时，AI玩家手牌与组合牌区域间隔太小（2px），看不清。

**修复：** 新增 `aiHandToMeldGapHu = 20.0` 常量，`showHuDisplay` 为true时使用20px间隔，否则使用原来的2px。

## 16. 设置页面关闭按钮被遮挡

**文件：** `flutter_app/lib/game/ui/settings_screen.dart`

**问题：** 关闭按钮使用 `Positioned(right: -16)` 定位，Stack默认 `clipBehavior: Clip.hardEdge` 裁剪超出边界的内容，导致按钮右侧被遮挡。

**修复：** Stack添加 `clipBehavior: Clip.none`，允许关闭按钮超出边界完整显示。

## 17. 操作优先级修复：人类玩家胡牌优先于AI玩家吃牌

**文件：** `flutter_app/lib/game/logic/game_controller.dart` — `_processResponses`, `respondPass`

**问题：** 玩家2出牌后，人类玩家可以胡，玩家1可以吃。`_processResponses`在遍历优先级时，发现人类可以胡后加入humanResponses继续遍历，但到chi时直接执行了AI的吃牌并return，导致人类玩家的胡牌被跳过。

**修复：**
1. `_processResponses`中，当`humanResponses`非空时（人类有高优先级操作），AI的低优先级操作不立即执行，而是保存到`deferredAI`待处理列表
2. 新增`_pendingAIResponses`、`_pendingResponseCard`、`_pendingResponseDiscardPlayerId`字段保存待处理的AI操作
3. 新增`_processAIResponses`方法，人类玩家过牌后按优先级处理AI的待处理操作
4. 新增`_clearPendingAIResponses`辅助方法，人类玩家执行操作时清除待处理AI响应
5. `respondPass`中，如果有待处理的AI操作，调用`_processAIResponses`而非直接`_nextTurn`

## 18. 胡牌面板显示时点炮/自摸卡牌位置调整

**文件：** `flutter_app/lib/game/render/game_board.dart` — `_renderHandCards`, `_renderAIHandFaceUp`

**问题：** 胡牌面板显示时，"炮"/"自摸"标签可能被手牌层叠遮挡。人类玩家手牌中同组卡牌完全重叠，后渲染的覆盖先渲染的；AI玩家手牌中高亮组内胡牌卡牌可能在其他牌下方。

**修复：**
1. 人类玩家：`_renderHandCards`中当`showHuDisplay && huWinnerIndex == 1`时，对`_player1Hand`排序，将胡牌卡牌放到同sentence组的最后位置，确保它最后渲染（显示在最上面）
2. AI玩家：`_renderAIHandFaceUp`中高亮组重新排序，将胡牌卡牌移动到组内索引0的位置（最左边），层叠时不被遮挡

## 19. 人类玩家手牌宽度调整

**文件：** `flutter_app/lib/game/render/game_board.dart`

**修改：** 人类玩家手牌宽度从 56px 改为 60px

## 20. 胡牌/流局时AI玩家手牌参数

**文件：** `flutter_app/lib/game/render/game_board.dart`

**新增常量：**
- `huAiHandCardW = 50.0` 宽度
- `huAiHandCardH = 224.0` 高度
- `huAiHandStackVisible = 50.0` 同字叠放竖向偏移
- `huAiHandSentenceGap = 0.0` 不同sentence组水平间距

**修改：** 新增 `_renderAIHand` 方法统一处理胡牌/流局时AI手牌显示，使用新参数渲染正面手牌；正常游戏状态保持原来的牌背显示

## 21. 胡牌卡牌标签样式修改

**文件：** `flutter_app/lib/game/render/game_board.dart` — `_drawHuCardLabel`

**修改：** 参考H5版本样式，"炮"/"自摸"标签统一使用白色文字（16px加粗），无背景，添加红色发光效果（text-shadow: `0 0 10px #ff0000, 0 0 20px #ff0000`）
