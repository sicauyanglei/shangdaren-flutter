# AI策略改进计划

## 当前架构

- **简单模式** `ai_strategy_simple.dart`：基于简单规则的贪心策略
- **困难模式** `ai_strategy_hard.dart`：包含深度评估、2步前瞻、防守意识的综合策略

---

## 一、出牌策略（selectDiscard）

### 当前实现

- 听牌后出牌 `_selectDiscardWhenTing`：选择听牌面最宽的出牌
- 非听牌出牌 `_selectDiscardOptimized`：先尝试找听牌出牌，再做综合评估
- 2步前瞻 `_twoStepLookahead`：考虑出牌后摸到各种牌的距离改善

### 改进项

#### 1. `extractDuiAndKao` 贪心提取顺序不优 ⭐⭐⭐

**文件**: `hu_calculator.dart:202-257`

**问题**: 先提取对再提取靠，可能导致次优结果。例如手牌有 `丘丘 乙己` 时，先提取"丘丘"为对，剩余"乙己"为靠；但如果提取"丘乙"为靠、"丘己"为靠，可能距离更短。

**方案**: 在 `_distanceToTingNormal` 中尝试多种提取顺序，选择距离最小的。或至少在提取靠时考虑"对+靠"vs"2个靠"的方案比较。

#### 2. `_distanceToTing` 没有考虑十对和普通胡的交叉情况 ⭐⭐

**文件**: `ai_strategy_hard.dart:993-998`

**问题**: 取十对距离和普通距离的最小值，但出牌评估时只用了单一方向。当十对距离=3、普通距离=2时，应优先走普通方向，但出牌选择可能破坏了十对方向。

**方案**: 出牌评估时，对两种方向分别评估，取综合最优。

#### 3. 2步前瞻的权重和阈值偏保守 ⭐⭐

**文件**: `ai_strategy_hard.dart:449-523`

**问题**: `prob < 0.01` 的阈值过滤掉了低概率但高价值的进张；听牌奖励 `prob * 1000` 相对于其他分数可能不够突出。

**方案**: 降低或取消概率阈值，对高距离改善的进张给予更多奖励。

#### 4. 缺少"进张效率"概念 ⭐⭐

**问题**: 当前评估只看"距离"和"概率"，没有考虑**进张数**。方案A听1张牌距离=0（已听牌）进张=2，方案B距离=1但有6张进张可以听牌，方案B的期望听牌时间可能更短。

**方案**: 在出牌评估中加入"期望听牌步数"的计算：`距离 / 平均每步进张概率`。

---

## 二、吃牌策略（shouldChi）

### 当前实现

**文件**: `ai_strategy_hard.dart:1166-1203`

- 困难模式特殊规则：手牌有完整一句且每个字只有1张时不吃
- 评估吃牌收益：计算距离改善、听牌可能性、胡数、进张概率

### 改进项

#### 5. 吃牌消耗成本评估不够精确 ⭐⭐

**文件**: `ai_strategy_hard.dart:187-203`

**问题**: `consumptionCost` 只检查了"该字是否有同组伙伴"加了30分惩罚，没有区分伙伴是"对"还是"靠"，也没有考虑伙伴的进张情况。

**方案**: 精确评估被消耗牌的价值。如果被消耗的牌参与了靠组合且该靠的进张还很多，消耗成本更高；如果靠的进张已经没了，消耗成本较低。

#### 6. 吃牌后没有评估出牌选择 ⭐⭐⭐

**问题**: 吃牌后需要出一张牌，但 `_evaluateChiBenefit` 只评估了吃牌后的手牌质量，没有考虑出牌后的最优结果。

**方案**: 在吃牌评估中，模拟吃牌后选择最优出牌，再评估结果手牌质量。

#### 7. 吃牌判断缺少"进张损失"分析 ⭐⭐

**问题**: 吃牌消耗了2张手牌，可能导致某些组合的进张数减少。例如手牌有 `丘乙 己己`，上家出"己"，吃"丘乙己"后消耗了"丘乙"，手牌只剩"己己"。如果不吃，"丘乙"作为靠还有2张"己"的进张。

**方案**: 计算吃牌前后各组合的进张数变化，进张损失大的不吃。

---

## 三、碰牌策略（shouldPeng）

### 当前实现

**文件**: `ai_strategy_hard.dart:1206-1334`

### 改进项

#### 8. 碰牌后距离不变时的判断逻辑过于简单 ⭐⭐

**文件**: `ai_strategy_hard.dart:1252-1277`

**问题**: 距离不变时只检查了胡数是否>0和该字同组是否有伙伴，没有考虑碰牌后手牌减少导致灵活性降低。

**方案**: 碰牌后距离不变时，比较碰牌前后的"期望听牌步数"（距离/进张概率），只有期望步数减少才碰。

#### 9. 碰牌没有考虑"碰后出牌"的最优选择 ⭐⭐⭐

**问题**: 碰牌后需要出一张牌，但当前没有模拟最优出牌。

**方案**: 碰牌评估中模拟最优出牌后再评估手牌质量。

#### 10. 碰牌没有考虑对出牌顺序的影响 ⭐

**问题**: 碰牌会改变出牌顺序（碰牌者接下来出牌），可能对AI有利或不利。

**方案**: 碰牌后出牌顺序变化，如果下家是听牌的对手，碰牌可能让他多摸一轮，应该避免。

---

## 四、招牌策略（shouldZhao）

### 当前实现

**文件**: `ai_strategy_hard.dart:1337-1404`

### 改进项

#### 11. 招的判断过于宽松 ⭐⭐

**问题**: 4张同字时，只要招后距离不增加太多（+1以内）或胡数不减少就招。但4张同字如果不招，可以组成1个坎+1张单牌，某些情况下更有价值（单牌可以参与靠组合）。

**方案**: 比较"招"vs"坎+单牌"两种方案的听牌距离和进张概率，选择更优方案。

#### 12. 招牌后没有考虑出牌损失 ⭐

**问题**: 招后需要出一张牌，但当前评估没有考虑出牌的最优选择和损失。

**方案**: 招牌评估中模拟最优出牌后再评估。

---

## 五、防守策略

### 当前实现

**文件**: `ai_strategy_hard.dart:672-767`

### 改进项

#### 13. 防守评估过于粗糙 ⭐⭐

**问题**: 当前防守只考虑了对方是否听牌、出的牌是否和对方面子同组、是否是精牌/阴牌。没有考虑对方具体可能听什么牌、弃牌中的安全牌、筋牌理论。

**方案**: 实现更精细的"读牌"系统：
1. 通过对方弃牌推断对方不要的组
2. 通过对方面子推断对方在收集的组
3. 计算每张出牌的"点炮概率"，而不仅仅是危险分

#### 14. 自己听牌时防守系数0.2过于激进 ⭐

**文件**: `ai_strategy_hard.dart:757`

**问题**: 自己听牌时 `danger *= 0.2`，几乎不考虑防守。但对方也是大牌时，点炮的损失可能远大于自己胡牌的收益。

**方案**: 根据自己胡牌的倍数和对方可能的胡牌倍数动态调整防守系数。对方面子很大（多个招/精坎）时，即使自己听牌也应增加防守。

---

## 六、系统性改进

#### 15. 缺少"手牌效率"的全局优化/路线选择机制 ⭐⭐⭐

**问题**: 当前AI的决策是"局部最优"的——每步选择当前最好的操作。但上大人字牌需要全局规划：早期应该收集哪些组？是否应该放弃某些组集中力量？十对路线vs普通路线何时切换？

**方案**: 增加"路线选择"机制：
1. 发牌后评估手牌，确定主攻方向（普通胡/十对/枯胡等）
2. 每次决策时优先选择符合主攻方向的方案
3. 当主攻方向不可行时，及时切换

#### 16. 没有利用"牌河"信息推断其他玩家手牌 ⭐

**问题**: 当前AI只用了 `visibleCount` 来计算剩余牌数，没有分析其他玩家的弃牌模式来推断他们的手牌。

**方案**: 增加"牌河分析"模块，推断其他玩家可能的手牌范围，用于更精确的防守评估和出牌选择。

#### 17. 碰/吃后出牌是否使用 `selectDiscard` 需确认 ⭐

**问题**: 碰/吃后AI直接出牌，可能没有经过完整的 `selectDiscard` 评估。

**方案**: 确认碰/吃后的出牌流程，确保使用最优出牌策略。

#### 18. 缺少"终局策略" ⭐

**问题**: 牌堆剩余较少时（<10张），AI应该更积极地防守、更珍惜每次摸牌机会、考虑流局可能性。

**方案**: 增加终局策略模块：
- 牌堆<10时更积极防守
- 考虑流局时庄家不变的规则影响
- 评估是否应该主动流局

---

## 七、数据结构优化

### 现状分析

当前AI策略在 `selectDiscard` 一次调用中，`List<Card>.from` 被调用 **19次**，`Player()` 构造被调用 **7次**，`_distanceToTing` 被调用 **48次**（含内部递归），`extractJu/extractKan/extractDuiAndKao` 被反复执行。手牌最多21张，每次出牌评估遍历所有手牌×所有可用牌，时间复杂度极高。

### 改进项

#### 19. 用位向量/整数编码替代 `List<Card>` 做手牌表示 ⭐⭐⭐

**问题**: 当前手牌用 `List<Card>` 表示，每次模拟出牌需要 `List<Card>.from(hand)` 复制整个列表（O(n)），`remove` 操作也是 O(n)。在2步前瞻中，对每张手牌×每张可用牌都要复制列表，总计约 `21 × 24 = 504` 次列表复制。

**方案**: 用 `Map<String, int>`（字→张数）表示手牌，出牌/摸牌只需修改计数器，O(1)操作：
```dart
// 之前: List<Card>.from(hand) + testHand.remove(card)  → O(n)
// 之后: Map<String, int>.from(charCount) + charCount[ch]--  → O(1)
```
手牌最多24种字×4张=96张，用 `Map<String, int>` 只有最多24个entry，复制和修改都极快。

#### 20. `extractJu/extractKan/extractDuiAndKao` 用计数器直接计算，不创建Meld对象 ⭐⭐⭐

**问题**: 当前提取流程：
1. `List<Card>.from(hand)` 复制列表
2. 遍历构建 `bySentence/byChar` 分组Map
3. 创建 `Meld` 对象（含 `List<Card>` 子列表）
4. `remaining.remove(c)` 逐个移除（O(n)×牌数）

整个流程 O(n²)，且产生大量临时对象给GC压力。`_distanceToTing` 内部调用一次完整提取，`_evaluateHandPotentialAndDistance` 又调用一次，`TingChecker.checkTing` 再调用一次——**同一个手牌状态被提取3-4次**。

**方案**: 基于 `Map<String, int>` 计数器直接计算距离，不创建中间对象：
```dart
int _distanceToTingFast(Map<String, int> charCount, List<Meld> melds) {
  // 直接从计数器计算句数、对数、靠数
  // 句：某组3种字都>=1 → 消耗1张每种
  // 坎/招：某字>=3/4
  // 对：某字>=2
  // 靠：某组2种不同字各>=1
  // 全程只操作计数器，无对象创建
}
```
预计可将 `_distanceToTing` 从 O(n²) 降到 O(24)（24种字）。

#### 21. `remaining.remove(card)` 是 O(n) 操作，改用Set或索引 ⭐⭐

**问题**: `hu_calculator.dart` 中 `extractJu/extractKan/extractDuiAndKao` 都使用 `remaining.remove(c)` 从列表中移除元素，这是 O(n) 操作。提取一副手牌（约21张）最多需要移除约18张，总复杂度 O(n²)。

**方案**: 
- 方案A：改用 `Set<Card>` 存储 remaining，remove 变 O(1)
- 方案B：用标记数组 `List<bool> used` 标记已使用的牌，不实际移除
- 方案C（推荐）：用 `Map<String, int>` 计数器，直接减计数

#### 22. `extractJu` 等方法用递归重新扫描整个列表 ⭐⭐

**问题**: `extractJu` 每提取一个句就递归调用自身重新扫描整个列表（`hu_calculator.dart:140`），`extractKan` 和 `extractDuiAndKao` 同理。手牌最多可能有6-7个句，意味着6-7次完整扫描。

**方案**: 改为循环而非递归，一次扫描提取所有同类型的组合：
```dart
static void extractJu(List<Card> remaining, List<Meld> out) {
  // 先统计 bySentence + byPos
  // 循环提取所有可能的句，不需要递归
  while (true) {
    bool found = false;
    for (var s = 1; s <= 8; s++) { ... }
    if (!found) break;
  }
}
```
或者用计数器方案直接一次计算所有句数。

---

## 八、缓存优化

### 改进项

#### 23. `_distanceToTing` 结果缓存（Memoization） ⭐⭐⭐

**问题**: `_distanceToTing` 在一次 `selectDiscard` 调用中被调用极多次：
- `_selectDiscardOptimized` 第一阶段：对每张手牌调用1次（~21次）
- `_evaluateDiscardComprehensive`：对每张手牌调用1次（~21次）
- `_evaluateHandPotentialAndDistance` 内部又隐含1次
- `_twoStepLookahead`：对每张手牌×每张可用牌调用1次（~21×24=504次）
- `_evaluateDanger`：1次
- `shouldChi/shouldPeng/shouldZhao`：各2-3次

**总计一次出牌决策约调用 `_distanceToTing` 550+ 次**，每次都做完整的提取+计算。

**方案**: 以手牌的哈希为key缓存距离结果：
```dart
final _distanceCache = <int, int>{};

int _distanceToTingCached(Map<String, int> charCount, List<Meld> melds) {
  final key = charCount.hashCode ^ melds.length.hashCode;
  return _distanceCache.putIfAbsent(key, () => _distanceToTingFast(charCount, melds));
}
```
注意：缓存需要在每次AI决策开始时清空，避免跨决策使用过期数据。

#### 24. `TingChecker.checkTing` 结果缓存 ⭐⭐⭐

**问题**: `TingChecker.checkTing` 是最昂贵的操作之一（内部调用 `_checkBasicTing` + `_checkHuTypeTing`，后者对每种听牌候选都调用 `_canHu`），但在 `_selectDiscardOptimized` 和 `_evaluateDiscardComprehensive` 中对同一个 `testPlayer` 可能被调用多次。

**方案**: 在 `AIStrategyHard` 中维护一个听牌结果缓存，以手牌哈希为key：
```dart
final _tingCache = <int, TingResult>{};
```
同样在每次决策开始时清空。

#### 25. `_buildVisibleCharCount` 重复构建 ⭐⭐

**问题**: `_buildVisibleCharCount` 在 `shouldChi`、`_selectDiscardWhenTing`、`_selectDiscardOptimized`、`_evaluateDanger` 中各自调用一次，每次都从 `GameState.publicCardCount` + 手牌重新构建Map。

**方案**: 在 `AIStrategyHard` 中缓存 `visibleCount`，在每次AI决策周期开始时计算一次：
```dart
Map<String, int>? _cachedVisibleCount;
int? _cachedTotalUnknown;

void _initCache(Player player, GameState state) {
  _cachedVisibleCount = _buildVisibleCharCount(player, state);
  _cachedTotalUnknown = _totalUnknownCards(player, state);
}
```

#### 26. `_isPartOfKan` / `_isPartOfZhao` 重复计算 ⭐

**问题**: `_isPartOfKan(card, hand)` 每次遍历整个手牌统计同字数量，在 `_selectDiscardWhenTing` 和 `_evaluateDiscardComprehensive` 中对每张手牌都调用一次。

**方案**: 预计算 `Map<String, int> charCount`，然后直接查表：
```dart
final charCount = _buildCharCount(hand);
bool isPartOfKan(String ch) => (charCount[ch] ?? 0) >= 3;
bool isPartOfZhao(String ch) => (charCount[ch] ?? 0) >= 4;
```

#### 27. `_evaluateHuScore` 重复计算 ⭐

**问题**: `_evaluateHuScore(testPlayer)` 调用 `HuCalculator.calculateTotalHu(player)`，内部又做一次完整的 `extractJu/extractZhao/extractKan/extractDuiAndKao`。但 `_evaluateDiscardComprehensive` 中已经调用过 `_evaluateHandPotentialAndDistance` 做了同样的提取。

**方案**: 让 `_evaluateHandPotentialAndDistance` 同时返回胡数，避免重复提取：
```dart
(double potential, int distance, int huScore) _evaluateHandPotentialAndDistance(...)
```

---

## 九、算法优化

### 改进项

#### 28. 2步前瞻剪枝：跳过不可能改善的进张 ⭐⭐⭐

**问题**: `_twoStepLookahead` 对每张手牌遍历所有24种可用字，对每种字都模拟摸牌+计算距离。总计 `21 × 24 = 504` 次 `_distanceToTing` 调用。但很多进张是不可能改善距离的（如同组没有手牌的孤张）。

**方案**: 
- 只考虑手牌中已有同组牌的字（`handGroups.contains(sentence)` 已有此逻辑，但阈值 `prob < 0.01` 过滤不够）
- 增加更激进的剪枝：如果某字剩余0张直接跳过（已有），如果距离已经=0（已听牌）直接返回高分
- 对同组多张手牌的情况，只评估一次该组的进张，而非对每张手牌都评估

#### 29. `_selectDiscardOptimized` 第一阶段和综合评估阶段重复计算 ⭐⭐

**问题**: `_selectDiscardOptimized` 先遍历所有手牌检查听牌（第一阶段，~21次 `TingChecker.checkTing`），然后又遍历所有手牌做综合评估（第二阶段，~21次 `_evaluateDiscardComprehensive`）。两个阶段对同一个 `testHand` 都做了 `List<Card>.from` + `Player()` 构造。

**方案**: 合并两个阶段，一次遍历同时检查听牌和综合评估：
```dart
for (final card in hand) {
  final testHand = ...; // 只构造一次
  final testPlayer = ...; // 只构造一次
  final tingResult = TingChecker.checkTing(testPlayer);
  if (tingResult.isTing) {
    // 听牌评分
  } else {
    // 综合评估
  }
}
```

#### 30. `_evaluateDanger` 中 `_distanceToTing` 调用可复用 ⭐

**问题**: `_evaluateDanger` 第761行调用 `_distanceToTing(List<Card>.from(player.hand), player.melds)` 计算自己的距离，但这个值在外层 `_evaluateDiscardComprehensive` 中已经计算过了。

**方案**: 将 `myDist` 作为参数传入 `_evaluateDanger`，避免重复计算。

#### 31. `TingChecker._checkHuTypeTing` 中 `_canHu` 调用优化 ⭐⭐

**问题**: `_findTingCardsForNinePairs` 对每种可能听牌的字都调用 `_canHu`，而 `_canHu` 内部又做完整的 `extractJu/extractKan/extractDuiAndKao`。对十对听牌，可能需要检查12+种字，每种都做一次完整提取。

**方案**: 十对听牌的胡型判断可以简化——十对只需要检查对数是否>=10，不需要完整的结构检查。对 `_findTingCardsForSingleWait` 和 `_findTingCardsForPairWait`，可以缓存提取结果。

#### 32. `HuCalculator.extractJu` 递归改循环 ⭐

**问题**: `extractJu` 每找到一个句就递归调用自身重新扫描（`hu_calculator.dart:140`），递归深度可达6-7层。

**方案**: 改为 while 循环，在循环内持续提取直到无法再提取：
```dart
static void extractJu(List<Card> remaining, List<Meld> out) {
  bool found = true;
  while (found) {
    found = false;
    // 构建索引，尝试提取一个句
    // 如果找到，found = true，继续循环
  }
}
```

#### 33. 预计算手牌分组索引 ⭐⭐

**问题**: `extractJu`、`_evaluateHandPotentialAndDistance`、`_evaluateDiscardComprehensive` 等多处代码都需要按 `sentence`/`character` 分组手牌，每次都重新遍历手牌构建Map。

**方案**: 在 `selectDiscard` 入口处预计算分组索引，后续所有评估函数共享：
```dart
class HandIndex {
  final Map<int, List<Card>> bySentence;  // 句号→牌列表
  final Map<String, List<Card>> byChar;   // 字→牌列表
  final Map<String, int> charCount;       // 字→张数
  final Map<int, Set<String>> groupCharSet; // 句号→字集合
}
```

---

## 改进优先级排序

| 优先级 | 编号 | 改进项 | 预期收益 | 实现难度 |
|-------|------|--------|---------|---------|
| P0 | 6/9 | 碰/吃后模拟最优出牌再评估 | 高 | 中 |
| P0 | 1 | 优化 `extractDuiAndKao` 提取顺序 | 高 | 中 |
| P0 | 15 | 路线选择机制 | 高 | 高 |
| P0 | 19 | 用计数器Map替代List<Card>做手牌表示 | 高(速度5-10x) | 中 |
| P0 | 20 | 提取方法用计数器直接计算，不创建Meld | 高(速度5-10x) | 中 |
| P0 | 23 | `_distanceToTing` 结果缓存 | 高(减少550+次→~30次) | 低 |
| P0 | 24 | `TingChecker.checkTing` 结果缓存 | 高(减少重复计算) | 低 |
| P1 | 4 | 加入"期望听牌步数" | 中高 | 低 |
| P1 | 13 | 精细防守/读牌系统 | 中高 | 高 |
| P1 | 5/7 | 吃牌进张损失分析 | 中 | 中 |
| P1 | 11 | 招vs坎+单牌方案比较 | 中 | 低 |
| P1 | 28 | 2步前瞻剪枝 | 中(减少504→~100次) | 低 |
| P1 | 29 | 合并出牌评估的两个阶段 | 中(减少一半构造) | 低 |
| P1 | 27 | `_evaluateHuScore` 复用提取结果 | 中 | 低 |
| P1 | 33 | 预计算手牌分组索引 | 中 | 低 |
| P2 | 2 | 十对/普通胡交叉评估 | 中 | 中 |
| P2 | 3 | 2步前瞻权重和阈值优化 | 中 | 低 |
| P2 | 8 | 碰牌距离不变时精确判断 | 中 | 低 |
| P2 | 14 | 动态防守系数 | 中 | 低 |
| P2 | 12 | 招牌后出牌损失评估 | 低 | 低 |
| P2 | 10 | 碰牌对出牌顺序的影响 | 低 | 中 |
| P2 | 21 | `remaining.remove` 改用Set/索引 | 中(速度2-3x) | 低 |
| P2 | 22 | 递归改循环 | 低 | 低 |
| P2 | 25 | `_buildVisibleCharCount` 缓存 | 低 | 低 |
| P2 | 26 | `_isPartOfKan/Zhao` 预计算 | 低 | 低 |
| P2 | 30 | `_evaluateDanger` 复用myDist | 低 | 低 |
| P2 | 31 | `TingChecker._canHu` 优化 | 中 | 中 |
| P2 | 32 | `extractJu` 递归改循环 | 低 | 低 |
| P3 | 16 | 牌河分析推断手牌 | 中 | 高 |
| P3 | 17 | 确认碰/吃后出牌流程 | 低 | 低 |
| P3 | 18 | 终局策略 | 低 | 低 |

---

## 性能优化预期效果

### 当前瓶颈量化

| 操作 | 单次耗时估计 | 单次决策调用次数 | 总耗时占比 |
|------|------------|----------------|-----------|
| `List<Card>.from` 复制 | ~1μs | 19次 | 5% |
| `Player()` 构造 | ~2μs | 7次 | 3% |
| `_distanceToTing` (含提取) | ~50μs | 550+次 | 70% |
| `TingChecker.checkTing` | ~100μs | 21+次 | 15% |
| `_evaluateHuScore` | ~40μs | 21+次 | 5% |
| 其他 | - | - | 2% |

### 优化后预期

| 优化措施 | 预期加速 |
|---------|---------|
| 计数器Map替代List (19/20) | _distanceToTing 从50μs→5μs (10x) |
| 距离缓存 (23) | 550次→30次实际计算 (18x减少) |
| 听牌缓存 (24) | 21次→5次实际计算 (4x减少) |
| 前瞻剪枝 (28) | 504次→100次 (5x减少) |
| 阶段合并 (29) | 构造次数减半 |
| **综合预期** | **整体加速 20-50x** |
