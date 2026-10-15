#!/usr/bin/env bash
# =============================================================================
# 开机报平安 (boot notify) —— 通用版
#
# 用途：机器每次启动后，往你配置的消息通道发一条"我还活着"。
#   它是**三根柱子**的验收判据（任一失效，这条消息就不会到）：
#     1) Windows/宿主重启后，WSL（或本机）是否被自动拉起
#     2) linger 是否让用户级 systemd 在没有登录会话时也起来了
#     3) Hermes 网关是否随 systemd 自启并连上通道
#   —— 而「该来的没来」正是你要的信号。
#
# 设计要点（每一条都是踩出来的）：
#   · 节流：WSL 可能被反复拉起（随手开终端就会），没节流会刷屏 + 白耗通道配额
#   · 等网关就绪再发：开机瞬间网关常未连上，立刻发会得到假警报
#   · 发送前清代理：残留的 http_proxy 会掐断到通道的连接（最隐蔽的失败）
#
# 安装：放到 ~/.hermes/bin/，配 shebang 可执行；配套 unit 见 templates/systemd/
#   hermes-boot-notify.service  (Type=oneshot, ExecStart=本脚本)
#   hermes-boot-notify.timer    (OnBootSec=2min, Persistent=true)
#
# 交付定义（重要）：单元执行成功 ≠ 消息发出去了。`.timer`/`.service` 显示成功时，
#   请核对本脚本的日志里是否真有 "已发送" —— 这才是"事情办成了"。
# =============================================================================
set -uo pipefail

# ── 可调参数 ────────────────────────────────────────────────────────────────
THROTTLE="${BOOT_NOTIFY_THROTTLE:-1800}"   # 秒；30 分钟内只发一条
WAIT_FOR_GATEWAY="${BOOT_NOTIFY_WAIT:-24}" # 最多等 24 × 10s = 4 分钟
TARGET="${BOOT_NOTIFY_TARGET:-}"           # 发送目标，如 qqbot / telegram；留空用默认 home channel
HERMES_BIN="${HERMES_BIN:-$HOME/.local/bin/hermes}"
GATEWAY_UNIT="${GATEWAY_UNIT:-hermes-gateway}"
CHANNEL="${CHANNEL:-qqbot}"                # 用于从 gateway_state.json 读通道状态

LOG_DIR="$HOME/.hermes/logs"
LOG="$LOG_DIR/boot-notify.log"
STAMP="$LOG_DIR/.boot-notify-last"

mkdir -p "$LOG_DIR"
log() { printf '%s [boot-notify] %s\n' "$(date '+%F %T')" "$*" >> "$LOG"; }

# 日志轮转（保留尾部）
if [ -f "$LOG" ] && [ "$(stat -c %s "$LOG" 2>/dev/null || echo 0)" -gt 262144 ]; then
    tail -n 200 "$LOG" > "$LOG.tmp" 2>/dev/null && mv "$LOG.tmp" "$LOG"
fi

# ── 节流 ────────────────────────────────────────────────────────────────────
NOW="$(date +%s)"
if [ -f "$STAMP" ]; then
    LAST="$(cat "$STAMP" 2>/dev/null || echo 0)"
    case "$LAST" in ''|*[!0-9]*) LAST=0 ;; esac
    if [ $(( NOW - LAST )) -lt "$THROTTLE" ]; then
        log "跳过：$((${THROTTLE} - (NOW - LAST))) 秒前刚发过（节流窗口内）"
        exit 0
    fi
fi

# ── 等网关起来 ──────────────────────────────────────────────────────────────
ready=0
for _ in $(seq 1 "$WAIT_FOR_GATEWAY"); do
    if systemctl --user is-active --quiet "$GATEWAY_UNIT" 2>/dev/null; then ready=1; break; fi
    sleep 10
done

PID="$(systemctl --user show -p MainPID --value "$GATEWAY_UNIT" 2>/dev/null || echo 0)"
# 从网关状态文件里读通道状态（字段名按你的 Hermes 版本调整）
CH="$(python3 - "$HOME/.hermes/gateway_state.json" "$CHANNEL" <<'PY' 2>/dev/null
import json, sys
try:
    print(json.load(open(sys.argv[1])).get("platforms", {}).get(sys.argv[2], {}).get("state", "?"))
except Exception:
    print("状态文件不可读")
PY
)"
BOOT="$(uptime -s 2>/dev/null || echo '?')"
UP="$(uptime -p 2>/dev/null | sed 's/^up //' || echo '?')"

MSG="$LOG_DIR/boot-notify-msg.txt"
{
    printf '【开机报平安】\n\n'
    printf '启动时间: %s（已运行 %s）\n' "$BOOT" "$UP"
    printf '网关服务: %s  PID=%s\n' \
        "$([ "$ready" = 1 ] && echo '已就绪（自动启动成功）' || echo '★ 4 分钟内未就绪 —— 需要人工看')" "$PID"
    printf '通道状态: %s\n\n' "$CH"
    printf '这条消息的角色：「机器重启且无人登录时，我还能不能自己回来」的判据。\n'
    printf '每次开机只发一条，节流窗口内不会重复。\n'
} > "$MSG"

# ── 清代理后发送（不清会掐断到通道的连接）───────────────────────────────────
unset http_proxy https_proxy all_proxy HTTP_PROXY HTTPS_PROXY ALL_PROXY
if [ -x "$HERMES_BIN" ]; then
    send_args=(send)
    [ -n "$TARGET" ] && send_args+=(--to "$TARGET")
    send_args+=(-f "$MSG")
    if "$HERMES_BIN" "${send_args[@]}" >>"$LOG" 2>&1; then
        echo "$NOW" > "$STAMP"
        log "已发送开机报平安（网关 ready=$ready）"
    else
        log "★ 发送失败（看上面 hermes send 的输出）"
    fi
else
    log "★ 找不到 $HERMES_BIN，无法发送"
fi
rm -f "$MSG"
exit 0
