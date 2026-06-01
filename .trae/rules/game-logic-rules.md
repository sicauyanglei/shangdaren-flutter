1. 听牌判断规则
   - 基本听牌条件只分析手牌，不分析组合牌
   - 听牌胡型条件中，_canHu必须同时检查结构条件和胡数条件
   - 胡数条件：总胡数≥11 或 满足特殊胡牌类型（十对、黑元、红元、枯胡、清枯胡、清枯重台）
   - 自摸判断(_canZimo)和点炮判断(_canHuWith)统一使用HuCalculator.canHu，不要单独实现结构检查
   - HuCalculator.canHu必须先检查结构条件(_checkStructural)，结构不满足直接返回false，不能只靠胡数判断
2. 靠(半靠)提取规则
   - 靠的定义是"同组不同2张(不含上/福)"，不要求position相邻
   - pos0+pos1、pos1+pos2、pos0+pos2 都是合法的靠组合
   - extractDuiAndKao中提取靠时，必须遍历所有不同position的组合，不能只检查相邻position
3. 分数计算规则
   - 分数计算使用HuTypeResult的dianpao/zimo倍数，不用totalHu ~/ 10
   - 点炮公式：底分 + B × 倍数基数 + 飘分(己+赢家)
   - 自摸公式：2 × (底分 + B × 倍数基数) + 飘分(己×2 + 他家)
   - zimo值已包含+1偏移，公式中不需要再+1
4. 头像区域统一宽度
   - 三个玩家头像区域Container最小宽度统一为250px
   - 徽章位置计算中的avatarW使用250
5. 徽章文字居中
   - 徽章文字水平和垂直都居中显示
   - 垂直居中：startY + (badgeH - tp.height) / 2
6. 自摸胡牌不要求isTing
   - 自摸判断(_canZimo)不需要检查player.isTing，因为摸到的牌本身可以完成胡牌结构
   - 点炮判断(_canHuWith)仍需要isTing前提
   - _handleHu中：自摸时不检查isTing，点炮时仍需检查isTing
7. 操作按钮互斥规则
   - 显示"胡"按钮时，隐藏"吃""碰""招""过"按钮
   - 显示"自摸"按钮时，隐藏"吃""碰""招""过"按钮
   - 自摸按钮和胡按钮不会同时显示
8. 胡牌面板分数显示
   - 自摸时每个输家单独显示分数，不合并
   - 点炮时显示点炮者分数
