#!/usr/bin/env python3
"""仓库工具自测 —— 规范验证命令。

    python3 tests/verify-tooling.py

覆盖两类内容：

  A. 仓库自带检查（可移植，CI 与本机都跑）
     · repo-guard.sh 的行为：干净树放行；四类污染各自拦截；与 cwd 无关；
       不误守其它仓库；REPO_ROOT 覆盖；非仓库内退出码 2
     · .github 下工作流与配置的结构与安全属性

  B. 本机私有内容（仅当 ~/hermes-private 存在时执行，CI 中自动跳过）
     · 备份脚本的幂等性与计数正确性
     · 私有仓库 .gitignore 的凭据拦截效果

退出码: 0 = 全部通过（允许 B 类跳过）, 1 = 有失败。
性质: 行为断言，不是覆盖率套件。宁可断言少而准。
"""
import os
import pathlib
import re
import shutil
import subprocess
import sys
import tempfile

REPO = pathlib.Path(__file__).resolve().parent.parent
GUARD = REPO / "scripts/system/repo-guard.sh"
PRIVATE = pathlib.Path(os.environ.get("HERMES_PRIVATE", pathlib.Path.home() / "hermes-private"))

results, skipped = [], []


def ck(name, cond, detail=""):
    results.append(bool(cond))
    print(f"{'PASS' if cond else 'FAIL'}  {name}" + (f"   <- {detail}" if detail and not cond else ""))


def skip(name, why):
    skipped.append(name)
    print(f"SKIP  {name}   ({why})")


def run(cmd, cwd=None, env=None, timeout=180):
    return subprocess.run(cmd, cwd=cwd, env=env, capture_output=True, text=True, timeout=timeout)


def u8(v):
    """凭据形态用拼接构造，避免本文件自身被 repo-guard 命中。"""
    return "ghp_" + v


TOKEN = u8("A1b2C3d4E5f6G7h8I9j0K1l2M3n4O5p6Q7r8")
PRIVKEY = "-----BEGIN OPENSSH " + "PRIVATE KEY-----\nx\n-----END OPENSSH PRIVATE KEY-----"
FIXTURES = [("密钥特征", {"leak.txt": f"t={TOKEN}\n"}, 0),
            ("私钥内容", {"k.txt": PRIVKEY}, 0),
            ("敏感文件被追踪", {".env": "S=1\n"}, 0),
            ("超大文件", {"a.txt": "x\n"}, 6)]

tmpdirs = []


def tmp():
    d = pathlib.Path(tempfile.mkdtemp(prefix="hermes-verify-"))
    tmpdirs.append(d)
    return d


def make_repo(files=None, big_mb=0, with_guard=True):
    d = tmp()
    run(["git", "init", "-q"], cwd=d)
    if with_guard:
        dest = d / "scripts/system"
        dest.mkdir(parents=True)
        shutil.copy(GUARD, dest / "repo-guard.sh")
    for rel, content in (files or {}).items():
        p = d / rel
        p.parent.mkdir(parents=True, exist_ok=True)
        p.write_text(content)
    if big_mb:
        (d / "big.bin").write_bytes(b"\0" * (big_mb * 1024 * 1024))
    run(["git", "add", "-Af", "."], cwd=d)
    return d


def guard_in(d, *args, cwd=None):
    return run(["bash", str(pathlib.Path(d) / "scripts/system/repo-guard.sh"), *args], cwd=cwd or d)


# ── A1. 守卫行为 ────────────────────────────────────────────────────────────
print("── 守卫（repo-guard.sh） ──")
ck("语法可解析", run(["bash", "-n", str(GUARD)]).returncode == 0)

clean = make_repo({"README.md": "hello\n"})
r = guard_in(clean)
ck("干净树放行", r.returncode == 0, f"rc={r.returncode}")
ck("干净树报告 4/4", "4/4" in r.stdout)

outside = tmp()   # 刻意不在任何仓库内
r = guard_in(clean, "--quiet", cwd=outside)
ck("与工作目录无关（外部 cwd 仍正确）", r.returncode == 0, f"rc={r.returncode}")

for label, files, big in FIXTURES:
    d = make_repo(files, big_mb=big)
    ck(f"拦截：{label}", guard_in(d, "--quiet").returncode == 1)
    ck(f"拦截：{label}（外部 cwd 同样生效）", guard_in(d, cwd=outside).returncode == 1)

r = guard_in(clean, "--quiet", cwd=outside)
ck("--quiet 抑制横幅", "Repository Guard —" not in guard_in(clean, "--quiet", cwd=outside).stdout)

lone = tmp()
(lone / "s").mkdir()
shutil.copy(GUARD, lone / "s/repo-guard.sh")
ck("脚本不在仓库内 → 退出码 2",
   run(["bash", str(lone / "s/repo-guard.sh")], cwd=lone).returncode == 2)

# 不误守其它仓库：站在另一个仓库里调用本仓库的守卫，目标仍应是本仓库
other = make_repo({"README.md": "other\n"})
r = run(["bash", str(GUARD)], cwd=other)
ck("不静默守错对象", f"Repository Guard — {REPO.name}" in r.stdout, r.stdout[:200])
ck("外部仓库存在时仍守本仓库且放行", r.returncode == 0, f"rc={r.returncode}")

# 排除项：模式串只出现在 .github 或被排除的文件名里 → 不误报
d = make_repo({".github/workflows/x.yml": f"# {TOKEN}\n# {PRIVKEY}\n"})
ck("排除 .github/（不自触发）", guard_in(d, "--quiet").returncode == 0)
d = make_repo({"vendor/repo-guard.sh": f"# {TOKEN}\n"})
ck("排除同名脚本文件", guard_in(d, "--quiet").returncode == 0)


# ── A2. .github 结构 ────────────────────────────────────────────────────────
print("\n── .github 配置 ──")
try:
    import yaml
except ImportError:
    yaml = None

if yaml is None:
    skip(".github 结构校验", "缺少 pyyaml")
else:
    wf = yaml.safe_load((REPO / ".github/workflows/repo-guard.yml").read_text())
    name = wf.get("name")
    trig = wf.get(True) or wf.get("on")
    ck("工作流有名字", bool(name), str(name))
    ck("工作流在 push / PR / 手动时触发",
       set(trig or {}) >= {"push", "pull_request", "workflow_dispatch"}, str(trig))
    ck("工作流权限收敛为只读", wf.get("permissions", {}).get("contents") == "read")

    steps = [s for job in wf["jobs"].values() for s in job.get("steps", [])]
    uses = [str(s.get("uses", "")) for s in steps]
    ck("工作流签出代码且版本已钉", any("checkout@v" in u for u in uses), str(uses))
    scripts_run = " ".join(str(s.get("run", "")) for s in steps)
    ck("工作流委派给单一实现", "scripts/system/repo-guard.sh" in scripts_run)
    ck("工作流未内联扫描逻辑", "grep" not in scripts_run, scripts_run[:120])

    dd = yaml.safe_load((REPO / ".github/dependabot.yml").read_text())
    ck("dependabot 监听 github-actions",
       dd["updates"][0]["package-ecosystem"] == "github-actions")
    ck("dependabot 周期为每周", dd["updates"][0]["schedule"]["interval"] == "weekly")

    ic = yaml.safe_load((REPO / ".github/ISSUE_TEMPLATE/config.yml").read_text())
    ck("允许开空白 Issue", ic.get("blank_issues_enabled") is True)

    # Issue 模板需要 YAML 前言块；PR 模板不需要（它是正文格式）
    for f in ["ISSUE_TEMPLATE/bug_report.md", "ISSUE_TEMPLATE/feature_request.md"]:
        p = REPO / ".github" / f
        ck(f"Issue 模板含前言块：{f}",
           p.is_file() and p.read_text().lstrip().startswith("---"))
    p = REPO / ".github/PULL_REQUEST_TEMPLATE.md"
    ck("PR 模板存在且非空", p.is_file() and len(p.read_text().strip()) > 50)

# ── A3. 凭据审计脚本 ────────────────────────────────────────────────────────
print("\n── 凭据审计脚本 ──")
VT = REPO / "scripts/system/verify-github-token.sh"
ck("语法可解析", run(["bash", "-n", str(VT)]).returncode == 0)
empty_cfg = tmp()
r = run(["bash", str(VT)], env={**os.environ, "GH_CONFIG_DIR": str(empty_cfg)})
ck("无凭据时以退出码 2 干净失败（不误报通过）", r.returncode == 2, f"rc={r.returncode}")

# ── B. 本机私有内容（CI 中跳过） ────────────────────────────────────────────
print("\n── 私有内容（本机专属） ──")
B = PRIVATE / "scripts/backup.sh"
if not B.is_file():
    skip("备份脚本与私有仓库检查", f"未找到 {B}")
else:
    # 幂等性要看「紧接的第二次运行」：第一次可能合法地同步真实漂移
    # （技能与记忆在会话之间会被改动），拿第一次断言必然周期性误报。
    r1 = run(["bash", str(B)])
    ck("备份运行退出 0", r1.returncode == 0, f"rc={r1.returncode}")
    before = run(["git", "-C", str(PRIVATE), "rev-parse", "HEAD"]).stdout.strip()
    r2 = run(["bash", str(B)])
    ck("紧接重跑，无变化则不提交", "无需提交" in r2.stdout, r2.stdout[-160:])
    ck("无变化时 HEAD 不变",
       before == run(["git", "-C", str(PRIVATE), "rev-parse", "HEAD"]).stdout.strip())

    fx = tmp()
    (fx / "memories").mkdir()
    (fx / "skills/a").mkdir(parents=True)
    (fx / "memories/MEMORY.md").write_text("m\n")
    (fx / "memories/USER.md").write_text("u\n")
    (fx / "skills/a/SKILL.md").write_text("s\n")
    r = run(["bash", str(B), "--dry-run"], env={**os.environ, "HERMES_HOME": str(fx)})
    m = re.search(r"记忆: (\d+) 处差异", r.stdout)
    ck("计数精确（无差一）", bool(m) and m.group(1) == "2",
       f"报 {m.group(1) if m else '?'}，应为 2")

    def ignored(p):
        return run(["git", "-C", str(PRIVATE), "check-ignore", "-q", p]).returncode == 0

    for pat in [".env", "x.pem", "id_rsa", "id_ed25519", ".git-credentials",
                "__pycache__/a.pyc", "a.log"]:
        ck(f"私有仓库忽略 {pat}", ignored(pat))
    ck("私有仓库不误伤 README.md", not ignored("README.md"))

    tracked = run(["git", "-C", str(PRIVATE), "ls-files"]).stdout.splitlines()
    junk = [f for f in tracked if re.search(r"__pycache__|\.lock$|\.pyc$|\.curator_backups", f)]
    ck("私有仓库无运行时产物被追踪", not junk, ", ".join(junk[:5]))

WRAP = pathlib.Path.home() / ".hermes/scripts/hermes-backup.sh"
if WRAP.is_file():
    ck("cron wrapper 语法正确", run(["bash", "-n", str(WRAP)]).returncode == 0)
    fake = tmp()
    r = run(["bash", str(WRAP)], env={**os.environ, "HOME": str(fake)})
    ck("wrapper 在私有仓库缺失时退出 1", r.returncode == 1, f"rc={r.returncode}")
    ck("wrapper 给出可执行的修复提示", "git clone" in r.stdout)

# ── 汇总 ────────────────────────────────────────────────────────────────────
for d in tmpdirs:
    shutil.rmtree(d, ignore_errors=True)

passed, total = sum(results), len(results)
print()
if skipped:
    print(f"跳过 {len(skipped)} 项：{', '.join(skipped)}")
print(f"{passed}/{total} 项断言通过")
if passed != total:
    sys.exit(1)
print("✅ 全部通过")
