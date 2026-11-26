#!/usr/bin/env bash
# Mở Cloudflare Quick Tunnel tới backend trên máy này và ghi địa chỉ vào Config/Local.xcconfig
# để app trên iPhone gọi được API qua HTTPS. Giữ cửa sổ này mở; Ctrl+C để tắt tunnel.
#
#   scripts/tunnel.sh            # backend ở cổng 8081
#   scripts/tunnel.sh 8080       # cổng khác
set -euo pipefail

PORT="${1:-8081}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LOCAL_CONFIG="$ROOT/Config/Local.xcconfig"

if ! command -v cloudflared >/dev/null 2>&1; then
  echo "❌ Chưa có cloudflared. Cài bằng:  brew install cloudflared"
  exit 1
fi

if ! curl -s -o /dev/null -m 3 "http://localhost:$PORT"; then
  echo "⚠️  Chưa thấy backend ở http://localhost:$PORT — nhớ bật backend, tunnel vẫn sẽ mở."
fi

LOG="$(mktemp)"
cloudflared tunnel --no-autoupdate --url "http://localhost:$PORT" >"$LOG" 2>&1 &
TUNNEL_PID=$!
cleanup() {
  kill "$TUNNEL_PID" 2>/dev/null || true
  rm -f "$LOG"
}
trap cleanup EXIT INT TERM

echo "⏳ Đang mở tunnel tới localhost:$PORT…"
URL=""
for _ in $(seq 1 60); do
  URL="$(grep -Eo 'https://[a-z0-9-]+\.trycloudflare\.com' "$LOG" | head -n 1 || true)"
  [ -n "$URL" ] && break
  if ! kill -0 "$TUNNEL_PID" 2>/dev/null; then break; fi
  sleep 1
done

if [ -z "$URL" ]; then
  echo "❌ Không lấy được địa chỉ tunnel. Log của cloudflared:"
  cat "$LOG"
  exit 1
fi

# xcconfig coi "//" là chú thích → viết "https:/$()/…".
ESCAPED="$(printf '%s' "$URL" | sed 's#//#/$()/#')"
{
  echo "// Tạo bởi scripts/tunnel.sh lúc $(date '+%H:%M %d/%m/%Y'). Không commit file này."
  echo "API_BASE_URL = $ESCAPED/api"
} >"$LOCAL_CONFIG"

cat <<MSG

✅ Tunnel đã mở:  $URL  →  http://localhost:$PORT
   Đã ghi API_BASE_URL = $URL/api vào Config/Local.xcconfig

👉 Bước tiếp: trong Xcode chọn iPhone của bạn, scheme "BankingApp", bấm ⌘R để build lại.
   Console in "⚙️ AppConfig — API thật: $URL/api" là đúng.
   Thử nhanh trên Safari của iPhone: $URL/api/v1/hsk/levels  (trả 401 là tunnel đã thông).

   Giữ cửa sổ này mở. Ctrl+C để tắt. Mỗi lần chạy lại địa chỉ sẽ đổi → build lại app.
MSG

wait "$TUNNEL_PID"
