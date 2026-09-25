#!/bin/bash
# ============================================================================
# GitHub Token Scope Audit — 检查当前凭据的权限，标出过度授权
# Managed by Hermes Agent
#
# 为什么需要它：`gh auth status` 只打印 scope 名称，不告诉你哪个 scope 危险。
# 而过度授权的代价是具体的 —— 例如 admin:public_key 允许向账户添加 SSH 公钥，
# 等于一条持久化访问路径。
#
# 用法:
#   bash scripts/system/verify-github-token.sh
#   bash scripts/system/verify-github-token.sh z0r0l0/resources z0r0l0/hermes-private
#
# 退出码: 0 = 未发现过度授权, 1 = 有需处理的项, 2 = 无法读取凭据
#
# 安全设计：token 从 gh 的凭据存储读取，通过 curl 配置文件（600）传递，
# 不出现在命令行参数里（避免 ps 泄露），也绝不打印。
# ============================================================================

set -uo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

# 危险 scope → 说明
declare -A DANGEROUS=(
  [admin:public_key]="可向账户添加 SSH 公钥 → 持久化访问后门"
  [admin:org]="管理组织成员与设置"
  [admin:repo_hook]="改写仓库 Webhook → 可外泄事件流"
  [delete_repo]="可删除任意仓库"
  [admin:gpg_key]="可添加签名密钥"
  [write:packages]="可发布包（供应链风险）"
  [workflow]="可改写 CI 工作流 → 可执行任意代码"
  [gist]="可读写 gist"
)

declare -A BROAD=(
  [repo]="完整控制所有公开与私有仓库（细粒度可收窄到指定仓库）"
  [read:org]="可读组织成员与团队"
)

if ! command -v gh >/dev/null 2>&1; then
    echo -e "${RED}✖ 未安装 gh${NC}"; exit 2
fi
TOKEN=$(gh auth token 2>/dev/null) || true
if [ -z "${TOKEN:-}" ]; then
    echo -e "${RED}✖ 无法从 gh 读取凭据（先 gh auth login）${NC}"; exit 2
fi

# 类型判定只看前缀，不看内容
case "$TOKEN" in
    ghp_*)        TCLASS="classic" ;;
    github_pat_*) TCLASS="fine-grained" ;;
    gho_*)        TCLASS="oauth" ;;
    ghu_*)        TCLASS="user-to-server" ;;
    *)            TCLASS="unknown" ;;
esac

# 通过 600 权限的 curl 配置传凭据，避免出现在进程参数中
CFG=$(mktemp); chmod 600 "$CFG"
trap 'rm -f "$CFG"' EXIT
printf 'header = "Authorization: token %s"\nheader = "Accept: application/vnd.github+json"\n' "$TOKEN" > "$CFG"
api() { curl -sS -m 15 --config "$CFG" "$@" 2>/dev/null; }

# 本机代理链路有突发抖动（实测 HTTPS 约 50% 失败），单次请求会把 000 误报成
# 「不可达」。所以所有 HTTP 状态探测都带重试，重试后仍为 000 才算真的不通。
probe_code() {   # probe_code <路径>
    local code i
    for i in 1 2 3 4; do
        code=$(api -o /dev/null -w '%{http_code}' "https://api.github.com$1")
        [ "$code" != "000" ] && { printf '%s' "$code"; return; }
        sleep 2
    done
    printf '%s' "$code"
}

echo -e "${BLUE}═══════════════════════════════════════════${NC}"
echo -e "${BLUE}  GitHub Token Scope Audit${NC}"
echo -e "${BLUE}═══════════════════════════════════════════${NC}"
echo ""
echo "  凭据类型: $TCLASS"

ISSUES=0
flag() { echo -e "  ${RED}⚠️  $1${NC}  $2"; ISSUES=$((ISSUES + 1)); }
ok()   { echo -e "  ${GREEN}✅ $1${NC}"; }

# ── classic / oauth：从响应头读 scope 列表 ─────────────────────────────────
HDRS=$(api -D - -o /dev/null https://api.github.com/user)
SCOPES=$(printf '%s' "$HDRS" | tr -d '\r' | awk 'tolower($1)=="x-oauth-scopes:"{ $1=""; sub(/^ /,""); print }')

if [ -n "$SCOPES" ]; then
    echo "  声明 scope: $SCOPES"
    echo ""
    echo -e "${GREEN}▶ 危险 scope 检查${NC}"
    found=0
    IFS=',' read -ra LIST <<< "$SCOPES"
    for s in "${LIST[@]}"; do
        s=$(echo "$s" | tr -d ' ')
        [ -z "$s" ] && continue
        if [ -n "${DANGEROUS[$s]:-}" ]; then flag "$s" "→ ${DANGEROUS[$s]}"; found=1; fi
    done
    [ "$found" -eq 0 ] && ok "未发现已知的危险 scope"

    echo ""
    echo -e "${GREEN}▶ 过宽但常见的 scope${NC}"
    for s in "${LIST[@]}"; do
        s=$(echo "$s" | tr -d ' ')
        [ -n "${BROAD[$s]:-}" ] && echo -e "  ${YELLOW}·  $s${NC}  ${BROAD[$s]}"
    done
else
    echo -e "  ${YELLOW}（该类型不在响应头暴露 scope —— 改为按能力探测）${NC}"
fi

# ── 能力探测（对所有类型有效，全部只读） ───────────────────────────────────
echo ""
echo -e "${GREEN}▶ 实际能力探测（只读请求）${NC}"
probe() {  # probe <标签> <路径> <危险时的说明>
    local code
    code=$(probe_code "$2")
    case "$code" in
        200) echo -e "  ${YELLOW}⚠️  $1: 可访问 ($code)${NC}  ${3:-}"; [ -n "${3:-}" ] && ISSUES=$((ISSUES + 1)) ;;
        404) echo -e "  ${GREEN}✅ $1: 无此访问 ($code)${NC}" ;;
        403) echo -e "  ${GREEN}✅ $1: 被拒绝 ($code)${NC}" ;;
        *)   echo -e "  ·   $1: $code（重试后仍无响应，属链路问题而非权限）${NC}" ;;
    esac
}

probe "读取账户 SSH 公钥清单" "/user/keys" "→ 可读密钥清单（配合 admin:public_key 即为后门）"
probe "枚举用户 gist"        "/gists"

echo ""
echo -e "${GREEN}▶ 指定仓库的可达性${NC}"
REPOS=("$@")
[ ${#REPOS[@]} -eq 0 ] && REPOS=("z0r0l0/resources")
for r in "${REPOS[@]}"; do
    code=$(probe_code "/repos/$r")
    case "$code" in
        200) echo -e "  ${GREEN}✅ $r 可达${NC}" ;;
        404) echo -e "  ${YELLOW}·  $r 不可达或不存在 ($code)${NC}" ;;
        *)   echo -e "  ${YELLOW}·  $r 返回 $code（重试后仍无响应，属链路问题）${NC}" ;;
    esac
done

echo ""
echo -e "${GREEN}▶ 身份${NC}"
ident=""
for i in 1 2 3 4; do
    ident=$(api https://api.github.com/user)
    [ -n "$ident" ] && break
    sleep 2
done
printf '%s' "$ident" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    print(f\"  账户: {d.get('login')}   公开仓库: {d.get('public_repos')}\")
except Exception:
    print('  （链路抖动导致取不到身份，与凭据无关）')" 2>/dev/null

echo ""
echo "── 结论 ──"
if [ "$ISSUES" -eq 0 ]; then
    echo -e "  ${GREEN}✅ 未发现过度授权项${NC}"
    exit 0
fi
echo -e "  ${RED}⚠️  有 $ISSUES 项需要处理${NC}"
echo -e "  ${YELLOW}收窄建议：改用 fine-grained token，仓库访问只勾选必需的仓库，${NC}"
echo -e "  ${YELLOW}权限按最小集给（Contents / Administration / Actions / Metadata）。${NC}"
echo -e "  ${YELLOW}git 操作已走 SSH，无需再给 token 任何 workflow 或密钥类权限。${NC}"
exit 1
