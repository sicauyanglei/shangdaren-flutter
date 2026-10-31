#!/data/data/com.termux/files/usr/bin/bash
# 上大人服务器一键启动：本地 Node 服务 + 免费公网穿透（trycloudflare，无需注册）
set -e
cd "$(dirname "$0")"

# 防止息屏后被安卓系统冻结后台
command -v termux-wake-lock >/dev/null 2>&1 && termux-wake-lock

# 清理旧进程，避免端口占用
pkill -f "node server.js" 2>/dev/null || true
pkill -f "cloudflared tunnel" 2>/dev/null || true
sleep 1

export PORT=8080
echo "==> 启动游戏服务器（本地端口 8080）..."
nohup node server.js > "$HOME/server.log" 2>&1 &
sleep 2

if curl -s http://localhost:8080/api/rooms >/dev/null 2>&1; then
  echo "✓ 本地服务器已启动"
else
  echo "⚠ 服务器未响应，最近日志："
  tail -5 "$HOME/server.log" || true
  exit 1
fi

echo "==> 启动公网穿透隧道（首次约 30 秒，请等待地址出现）..."
echo "    保持本窗口开启，退到手机桌面不影响；别划掉 Termux"
printed=""
"$HOME/bin/cloudflared" tunnel --url http://localhost:8080 2>&1 \
  | grep --line-buffered -oE "https://[a-z0-9-]+\.trycloudflare\.com" \
  | while read -r url; do
      if [ -z "$printed" ]; then
        printed=1
        echo ""
        echo "=============================================="
        echo "✅ 服务器已上线！"
        echo ""
        echo "   三台手机【联机大厅】的服务器地址填："
        echo "   wss://${url#https://}"
        echo ""
        echo "   · 手机只需能上网，无需同一 Wi-Fi"
        echo "   · 地址重启后会变，重跑本脚本换新地址"
        echo "=============================================="
      fi
    done
