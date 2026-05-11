# 更新日志

## 2025-03-22

### 新功能

#### 吃/碰/招牌动画效果
- 新增 `animateMeldCards` 函数，实现吃/碰/招牌时的动画效果
- 动画分为三个阶段：
  1. 所有牌移动到中心汇合
  2. 在中心显示组合效果
  3. 组合牌移动到组合牌区域
- 总动画时间约1.5秒

### Bug修复

#### 空值检查缺失修复
1. **performZhao函数** - 添加了 `gameState.lastDiscardedCard` 为 null 的检查
2. **handleHu函数** - 添加了 `gameState.lastDiscardPlayerIndex` 有效性和 `dianPaoPlayer` 存在性检查
3. **showHuMessage函数** - 添加了 `overlay` 和 `mask` 元素存在性检查
4. **closeHuMessage函数** - 添加了所有DOM元素的存在性检查
5. **performChi函数** - 添加了 `find` 返回值的空值检查
6. **selectAIDiscard函数** - 添加了手牌为空的检查
7. **continueAITurn函数** - 添加了无效牌索引的检查

#### 逻辑错误修复
1. **determineHuType函数** - 修复参数数量不匹配问题，添加第三个可选参数 `huCount`
2. **Math.min空数组问题** - 添加了数组长度检查，空数组返回默认值0
3. **胡牌标签显示问题** - 修改为使用 `c.id === displayHuCard.id` 精确匹配
4. **checkResponses函数** - 修复AI玩家决定不碰时继续检查吃牌的逻辑
5. **dianPaoPlayer变量未定义** - 修复自摸时 `dianPaoPlayer` 变量未定义的问题
6. **detectHuType函数** - 修复 `actualHuCount` 变量未定义的问题
7. **胡数不足检查** - 添加胡数不足11胡时返回 `{ type: 'none' }` 的检查
8. **打出的牌重复显示** - 添加检查避免重复添加相同的牌

### 规则更新

#### 胡数计算规则重写
按照新规则重新设计 `calculateHuCount` 函数：

| 组合名称 | 解释 | 胡数 |
|---------|------|------|
| 靠 | 2张字，同属于8组中任意一组，不含上/福 | 0胡 |
| 银靠 | 2张字，必须是大人、禄寿 | 0胡 |
| 精靠 | 2张字，同属于组1/组8，含有上/福 | 4胡 |
| 单 | 除了上/福外的一张字 | 0胡 |
| 精单 | 上/福 | 4胡 |
| 坎 | 除了上上上/福福福外3张相同字 | 组合牌中2胡，手牌中3胡 |
| 精坎 | 上上上/福福福 | 12胡 |
| 招 | 除了上上上上/福福福福外4张相同的字 | 6胡 |
| 精招 | 上上上上/福福福福 | 16胡 |
| 句 | 3张字，除了组1、组8的其它组 | 0胡 |
| 精句 | 3张字，组1/组8 | 4胡 |
| 对 | 除了上上/福福外的2张一样的字 | 0胡 |
| 金对 | 上上/福福 | 8胡 |

#### 吃牌huValue更新
- 精句（组1/组8含上/福）：4胡
- 句（其他组）：0胡

### UI/布局优化

#### 手机端布局优化
1. 限制玩家1的组合牌和打出的牌的最大高度
2. 确保我的组合牌和打出的牌有足够的空间显示
3. 修改 `.player-left` 和 `.player-right` 的 `gap` 为 1px
4. 修改 `.player-row` 和 `.player-row-my` 的 `gap` 为 0
5. 添加手机端横向模式下的响应式样式

#### 自摸徽章和听牌徽章
- 当显示自摸徽章时，隐藏听牌徽章

#### 第8局结算页面
- 修复第8局结束后不显示结算页面的问题

### 其他修改

#### 操作超时时间
- 恢复30秒出牌倒计时（测试时曾改为1秒）

#### 流局规则
- 流局时庄家保持不变

---

## 文件修改清单

### game.js
- `calculateHuCount` - 完全重写胡数计算逻辑
- `determineHuType` - 修复参数问题，添加胡数检查
- `detectHuType` - 修复变量未定义问题
- `performChi` - 添加动画效果和空值检查
- `performPeng` - 添加动画效果
- `performZhao` - 添加动画效果和空值检查
- `handleHu` - 添加空值检查，修复变量未定义问题
- `showHuMessage` - 添加DOM元素空值检查
- `closeHuMessage` - 添加DOM元素空值检查，添加第8局结算检查
- `checkResponses` - 修复AI玩家碰牌逻辑
- `selectAIDiscard` - 添加手牌为空检查
- `continueAITurn` - 添加无效牌索引检查
- `animateMeldCards` - 新增函数，实现吃/碰/招牌动画
- `finishZhao` - 新增函数，完成招牌逻辑
- `showDiscardedCard` - 添加重复添加检查
- `updateTingBadge` - 修改自摸徽章和听牌徽章显示逻辑
- `startCountdown` - 恢复30秒倒计时

### index.html
- `.player-left` - 修改gap为1px，添加max-height和overflow
- `.player-right` - 修改gap为1px，添加max-height和overflow
- `.player-row` - 修改gap为0
- `.player-row-my` - 修改gap为0
- `.player-melds-side` - 添加max-height和overflow
- `.player-discard` - 添加max-height和overflow
- `.my-discard-side` - 修改max-width和max-height
- `.my-melds-side` - 添加完整样式
- 手机端横向模式响应式样式 - 添加多项优化
