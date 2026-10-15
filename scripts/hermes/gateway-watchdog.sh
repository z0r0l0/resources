#!/usr/bin/env bash
# =============================================================================
# Hermes 网关看护器 (gateway watchdog) —— 通用版
#
# 解决的问题：systemd 的 Restart=always 只能救「进程死了」。
#             它救不了两种**静默失联**：
#               a) 进程活着、日志安静，但长连接已断（适配器放弃重连）
#               b) 出网断了（WiFi/路由器/宽带切换）—— 此时重启网关毫无意义，
#                  只会变成每 5 分钟一次的无效重启循环
#
# 判据与顺序：
#   0. 先探出网。DNS 解析不到或 TCP 连不上服务端 → 判定「网络层问题」，
#      记录一次后直接退出，不累计 strike、不重启（这是主机的锅，不是网关的锅）。
#      网络恢复后网关会自己重连；若没重连上，下一轮第 1-3 项会接住。
#   1. 服务是否 active
#   2. gateway_state.json 里目标平台 state 是否为 connected
#   3. 进程是否持有到 :443 的 ESTAB 长连接（优先 psutil，失败退回 ss）
#   连续 N 次异常才动手重启，避免网络抖动导致误重启。
#   防抖：一小时内已重启 M 次仍未恢复 → 判为主机层故障，停止自愈并记 ESCALATION，
#         避免把网关反复掐死（重启会打断长连接）。
#
# 由 <service>.timer 每 5 分钟拉起（oneshot）。输出追加到 ~/.hermes/logs/gateway-watchdog.log
#
# 环境变量可覆盖：SVC / PLATFORM / PROBE_HOST / MAX_STRIKES / MAX_RESTARTS_PER_HOUR
# =============================================================================
set -uo pipefail

SVC="${SVC:-hermes-gateway.service}"
PLATFORM="${PLATFORM:-qqbot}"              # gateway_state.json 里的平台键名
PROBE_HOST="${PROBE_HOST:-api.sgroup.qq.com}"   # 用来探出网的目标（你的平台服务端）
STATE_FILE="${STATE_FILE:-$HOME/.hermes/gateway_state.json}"
LOG_DIR="${LOG_DIR:-$HOME/.hermes/logs}"
LOG="$LOG_DIR/gateway-watchdog.log"
STRIKE_FILE="$LOG_DIR/.gateway-watchdog-strikes"
NETSTATE_FILE="$LOG_DIR/.gateway-watchdog-net"
HIST_FILE="$LOG_DIR/.gateway-watchdog-restarts"
ESCALATION_FILE="$LOG_DIR/.gateway-watchdog-escalated"
MAX_STRIKES="${MAX_STRIKES:-2}"
MAX_RESTARTS_PER_HOUR="${MAX_RESTARTS_PER_HOUR:-3}"
LOG_MAX_BYTES="${LOG_MAX_BYTES:-524288}"

mkdir -p "$LOG_DIR"
log() { printf '%s [watchdog] %s\n' "$(date '+%F %T')" "$*" >> "$LOG"; }

if [ -f "$LOG" ] && [ "$(stat -c %s "$LOG" 2>/dev/null || echo 0)" -gt "$LOG_MAX_BYTES" ]; then
    tail -n 500 "$LOG" > "$LOG.tmp" 2>/dev/null && mv "$LOG.tmp" "$LOG"
fi

reason=""
add_reason() { reason="${reason}${reason:+; }$1"; }

# ---- 检查 0：出网（DNS + 到服务端的 TCP）-----------------------------------
# 网络断了就别怪网关。只在状态翻转时写日志，避免每 5 分钟刷屏。
if getent hosts "$PROBE_HOST" >/dev/null 2>&1 \
   && timeout 5 curl -s -o /dev/null --noproxy '*' --max-time 5 "https://$PROBE_HOST/" 2>/dev/null; then
    [ "$(cat "$NETSTATE_FILE" 2>/dev/null)" = "down" ] && log "网络已恢复，继续正常判据"
    echo up > "$NETSTATE_FILE"
else
    if [ "$(cat "$NETSTATE_FILE" 2>/dev/null)" != "down" ]; then
        log "网络层不可达（DNS 或 $PROBE_HOST:443 失败）—— 判为主机侧问题，暂停自愈；网络恢复后自动继续"
        echo down > "$NETSTATE_FILE"
    fi
    exit 0
fi

# ---- 检查 1：服务是否 active -----------------------------------------------
if ! systemctl --user is-active --quiet "$SVC" 2>/dev/null; then
    add_reason "service=inactive"
fi

PID="$(systemctl --user show -p MainPID --value "$SVC" 2>/dev/null || echo 0)"

# ---- 检查 2：平台通道状态 --------------------------------------------------
if [ -f "$STATE_FILE" ]; then
    plat_state="$(python3 - "$STATE_FILE" "$PLATFORM" <<'PY' 2>/dev/null
import json, sys
try:
    p = json.load(open(sys.argv[1])).get("platforms", {}).get(sys.argv[2], {})
    print(f"{p.get('state','?')}|{(p.get('error_message') or '')[:80]}")
except Exception:
    print("unreadable|")
PY
)"
    case "$plat_state" in
        connected\|*) : ;;
        *) add_reason "${PLATFORM}_state=${plat_state%%|*}" ;;
    esac
else
    add_reason "state_file_missing"
fi

# ---- 检查 3：到 :443 的 ESTAB 长连接（双实现，互为兜底）--------------------
if [ "${PID:-0}" != "0" ] && [ -n "${PID:-}" ]; then
    VENV_PY="$HOME/.hermes/hermes-agent/venv/bin/python"
    [ -x "$VENV_PY" ] || VENV_PY="python3"

    estab="$("$VENV_PY" - "$PID" <<'PY' 2>/dev/null
import sys
try:
    import psutil
    p = psutil.Process(int(sys.argv[1]))
    n = sum(1 for c in p.net_connections(kind="tcp")
            if c.status == "ESTABLISHED" and c.raddr and c.raddr.port == 443)
    print(n)
except Exception:
    print(-1)
PY
)"

    if [ "${estab:--1}" = "-1" ]; then
        # psutil 不可用 → 退回 ss。**不要用固定列号**（带 -p 时 Peer 是第 5 列，
        # 容易数错并误判断线 —— v1 就栽在这里，触发了两次无谓重启）。
        # 改为整行内找以 :443 结尾的字段。
        mine="$(ss -tnp 2>/dev/null | awk -v p="pid=$PID" \
                 '$0 ~ p {for(i=1;i<=NF;i++) if ($i ~ /:443$/) {n++; break}} END{print n+0}')"
        any443="$(ss -tn 2>/dev/null | awk '$1=="ESTAB" && $5 ~ /:443$/ {n++} END{print n+0}')"
        if [ "${mine:-0}" -eq 0 ] && [ "${any443:-0}" -gt 0 ]; then
            # 有别的进程占着 :443，但没法归因到本进程 → 判为**判据不可用**，而不是异常
            log "socket probe inconclusive (mine=0 any443=${any443}) —— 本次跳过该判据"
        else
            [ "${mine:-0}" -eq 0 ] && add_reason "no_estab_443_socket"
        fi
    else
        [ "${estab:-0}" -eq 0 ] && add_reason "no_estab_443_socket"
    fi
else
    add_reason "no_mainpid"
fi

# ---- 健康：清空累计，安静退出 ----------------------------------------------
if [ -z "$reason" ]; then
    [ -f "$STRIKE_FILE" ] && echo 0 > "$STRIKE_FILE"
    exit 0
fi

strikes=$(( $(cat "$STRIKE_FILE" 2>/dev/null || echo 0) + 1 ))
echo "$strikes" > "$STRIKE_FILE"

if [ "$strikes" -lt "$MAX_STRIKES" ]; then
    log "unhealthy x${strikes} (${reason}) —— 未达阈值(${MAX_STRIKES})，暂不重启"
    exit 0
fi

# ---- 防抖：一小时内重启几次了？---------------------------------------------
NOW="$(date +%s)"
[ -f "$HIST_FILE" ] || : > "$HIST_FILE"
awk -v now="$NOW" 'now - $1 < 3600' "$HIST_FILE" > "$HIST_FILE.tmp" 2>/dev/null && mv "$HIST_FILE.tmp" "$HIST_FILE"
# 用 awk 数行数，不用 grep -c：grep -c 无匹配时打印 0 却返回 1，
# 若写成 `$(grep -c . f || echo 0)` 会得到 "0\n0"，后续整数比较直接报错。
RECENT="$(awk 'END{print NR+0}' "$HIST_FILE" 2>/dev/null)"; RECENT="${RECENT:-0}"

if [ "$RECENT" -ge "$MAX_RESTARTS_PER_HOUR" ]; then
    if [ "$(cat "$ESCALATION_FILE" 2>/dev/null)" != "$(date +%Y%m%d%H)" ]; then
        log "ESCALATION：一小时内已重启 ${RECENT} 次仍未恢复（${reason}）—— 停止自愈，疑似主机/网络层故障，需人工介入"
        date +%Y%m%d%H > "$ESCALATION_FILE"
    fi
    echo 0 > "$STRIKE_FILE"
    exit 0
fi

log "UNHEALTHY x${strikes} (${reason}) -> 重启 $SVC"
echo "$NOW" >> "$HIST_FILE"
systemctl --user restart "$SVC" >>"$LOG" 2>&1
sleep 20
if systemctl --user is-active --quiet "$SVC"; then
    log "RESTARTED ok (新 PID $(systemctl --user show -p MainPID --value "$SVC"))"
else
    log "RESTART_FAILED —— 需人工介入"
fi
echo 0 > "$STRIKE_FILE"
exit 0
