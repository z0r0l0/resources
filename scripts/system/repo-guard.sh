#!/bin/bash
# ============================================================================
# Repository Guard — 公开仓库的入库前守卫
# Managed by Hermes Agent
#
# 单一实现：本地与 GitHub Actions 共用这一份检查逻辑
# （CI 侧见 .github/workflows/repo-guard.yml，它只负责调用本脚本）
#
# 用法:
#   bash scripts/system/repo-guard.sh            # 从任何目录运行，守的是本脚本所在的仓库
#   bash scripts/system/repo-guard.sh --quiet    # 只输出结论，适合 CI
#   REPO_ROOT=<路径> bash .../repo-guard.sh      # 显式指定要检查的仓库
#
# 退出码: 0 = 全部通过, 1 = 有检查未通过, 2 = 脚本所在位置不在 git 仓库内
# ============================================================================

set -uo pipefail

QUIET=0
[ "${1:-}" = "--quiet" ] && QUIET=1

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

# 目标仓库 = 脚本自身所在的仓库，与当前工作目录无关。
# 用 cwd 判断会造成静默守错对象：从另一个仓库里运行本脚本时，
# 它会去守那个仓库，而使用者以为在守本仓库。
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="${REPO_ROOT:-$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel 2>/dev/null)}"
if [ -z "$ROOT" ]; then
    echo -e "${RED}✖ 脚本所在位置不在 git 仓库内: $SCRIPT_DIR${NC}"
    echo -e "${YELLOW}  提示: 用 REPO_ROOT=<路径> 显式指定要检查的仓库${NC}"
    exit 2
fi
cd "$ROOT" || exit 2

FAILED=0
pass() { [ "$QUIET" -eq 1 ] || echo -e "  ${GREEN}✅ $1${NC}"; }
fail() { echo -e "  ${RED}❌ $1${NC}"; FAILED=$((FAILED + 1)); }
head2() { [ "$QUIET" -eq 1 ] || echo -e "${GREEN}$1${NC}"; }

# 本脚本自身会包含下列正则字面量，故扫描时按文件名排除（等价于 .gitleaksignore）
SELF_EXCLUDE='--exclude=repo-guard.sh'
GIT_EXCLUDES=(--exclude-dir=.git --exclude-dir=.github "$SELF_EXCLUDE")

# 只匹配真实密钥形态，避免误报文档里的占位符
SECRET_PAT='ghp_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,}|sk-[A-Za-z0-9]{20,}|AKIA[0-9A-Z]{16}|AIza[0-9A-Za-z_-]{30,}|xox[baprs]-[A-Za-z0-9-]{10,}'

MAX_FILE_KB=5120   # 5 MB

# --- 1. 密钥特征 ------------------------------------------------------------
check_secrets() {
    head2 "🔑 密钥特征"
    local hits
    hits=$(grep -rInE "$SECRET_PAT" . "${GIT_EXCLUDES[@]}" 2>/dev/null)
    if [ -n "$hits" ]; then
        fail "发现疑似密钥特征，禁止入库"
        printf '%s\n' "$hits" | head -20 | sed 's/^/      /'
    else
        pass "未发现密钥特征"
    fi
}

# --- 2. 私钥内容 ------------------------------------------------------------
check_private_keys() {
    head2 "🔐 私钥内容"
    local hits
    hits=$(grep -rIn "${GIT_EXCLUDES[@]}" 'BEGIN [A-Z ]*PRIVATE KEY' . 2>/dev/null)
    if [ -n "$hits" ]; then
        fail "发现私钥内容，禁止入库"
        printf '%s\n' "$hits" | head -20 | sed 's/^/      /'
    else
        pass "未发现私钥内容"
    fi
}

# --- 3. 敏感文件是否被追踪 --------------------------------------------------
check_tracked_sensitive() {
    head2 "📄 敏感文件追踪"
    local hits
    hits=$(git ls-files | grep -Ev '^\.github/' \
        | grep -E '(^|/)\.env($|\.)|\.pem$|\.key$|\.p12$|\.pfx$|id_rsa|id_ed25519|\.git-credentials$')
    if [ -n "$hits" ]; then
        fail "敏感文件被纳入版本控制"
        printf '%s\n' "$hits" | sed 's/^/      /'
    else
        pass "无敏感文件被追踪"
    fi
}

# --- 4. 超大文件 ------------------------------------------------------------
check_large_files() {
    head2 "📦 文件体积"
    local hits
    hits=$(git ls-files -z | xargs -0 -r du -k 2>/dev/null \
        | awk -v lim="$MAX_FILE_KB" '$1 > lim {print "      " $2 " (" $1 " KB)"}')
    if [ -n "$hits" ]; then
        fail "存在 >$((MAX_FILE_KB / 1024))MB 文件，考虑改用 Git LFS"
        printf '%s\n' "$hits"
    else
        pass "无超大文件"
    fi
}

if [ "$QUIET" -eq 0 ]; then
    echo -e "${BLUE}═══════════════════════════════════════════${NC}"
    echo -e "${BLUE}  Repository Guard — $(basename "$ROOT")${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════${NC}"
    echo ""
fi

check_secrets
check_private_keys
check_tracked_sensitive
check_large_files

echo ""
if [ "$FAILED" -eq 0 ]; then
    echo -e "${GREEN}✅ 全部检查通过（4/4）${NC}"
    exit 0
fi
echo -e "${RED}✖ 有 $FAILED 项检查未通过，禁止提交${NC}"
[ "$QUIET" -eq 0 ] && echo -e "${YELLOW}  修复后再试；纯本地跳过：git commit --no-verify${NC}"
exit 1
