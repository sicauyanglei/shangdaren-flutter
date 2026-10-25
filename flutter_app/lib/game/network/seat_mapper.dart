/// 座位映射工具：服务器座位号 <-> 本地视角索引
///
/// 本地视角约定（与单机版一致）：
/// - players[1] 恒为"我"
/// - players[0] 为逆时针行动顺序中我的上家（在我之前行动）
/// - players[2] 为我的下家（在我之后行动）
///
/// 服务器座位 0/1/2 按逆时针行动顺序编号（与 dealer.js 发牌顺序一致）。
class SeatMapper {
  /// 我在服务器上的座位号
  final int mySeat;

  const SeatMapper(this.mySeat);

  /// 服务器座位号 → 本地视角索引
  ///
  /// 我自己(seat==mySeat) → 1；我下家 → 2；我上家 → 0
  int toLocal(int serverSeat) {
    final diff = ((serverSeat - mySeat) % 3 + 3) % 3;
    return (diff + 1) % 3;
  }

  /// 本地视角索引 → 服务器座位号
  ///
  /// 1 → 我；2 → 我下家；0 → 我上家
  int toServer(int localIndex) {
    return ((mySeat + localIndex - 1) % 3 + 3) % 3;
  }

  /// 服务器座位列表是否包含我
  bool isMe(int serverSeat) => serverSeat == mySeat;
}
