#!/data/data/com.termux/files/usr/bin/bash
# 上大人服务器 Termux 一键安装（安卓手机当游戏服务器，只需运行一次）
set -e

REPO="https://github.com/sicauyanglei/shangdaren-flutter.git"
BRANCH="feature/sdr/mutilVersion"
DIR="$HOME/shangdaren-server"

echo "==> [1/4] 安装 Node.js / git / curl ..."
pkg update -y >/dev/null 2>&1 || true
pkg install -y nodejs git curl

echo "==> [2/4] 获取服务器代码 ..."
if [ -d "$DIR" ]; then
  cd "$DIR"
  git fetch origin "$BRANCH" -q
  git checkout -q "$BRANCH" 2>/dev/null || git checkout -q -b "$BRANCH" "origin/$BRANCH"
  git reset --hard -q "origin/$BRANCH"
else
  git clone --depth 1 -b "$BRANCH" "$REPO" "$DIR"
fi

echo "==> [3/4] 安装依赖 ..."
cd "$DIR/server"
npm install --no-audit --no-fund

echo "==> [4/4] 下载 cloudflared 穿透客户端（无需注册） ..."
mkdir -p "$HOME/bin"
curl -sL -o "$HOME/bin/cloudflared" \
  "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-arm64"
chmod +x "$HOME/bin/cloudflared"

echo ""
echo "✅ 安装完成！以后每次启动服务器只需运行："
echo "   bash ~/shangdaren-server/server/termux-start.sh"
