# ⚡ 脚本索引

所有脚本遵循统一约定：`#!/bin/bash`、严格模式（`set -uo pipefail`）、
中文注释说明**为什么**、版本钉死、幂等可重复执行。

---

## 📁 分类

### `dev/` — 开发环境

| 脚本 | 用途 | 关键点 |
|------|------|--------|
| `node-setup.sh` | Node.js 环境安装 | 版本钉死，含 pnpm；不污染系统 Node |
| `python-setup.sh` | Python 环境安装 | 强制 venv/uv，规避 PEP 668 |

### `system/` — 系统运维

| 脚本 | 用途 | 退出码 |
|------|------|--------|
| `check-env.sh` | 系统健康检查：OS / CPU / 内存 / 磁盘 / 网络 / Docker | 0 正常 |
| `install-essentials.sh` | 常用开发工具一键安装 | 0 成功 |
| `update-all.sh` | 全量更新：系统包 + 语言生态 + 工具 | 0 成功 |
| `repo-guard.sh` | **入库守卫**：密钥 / 私钥 / 敏感文件 / 大文件 | 0 通过，1 拦截，2 不在仓库内 |

### `qq-bot/` — QQ Bot 网关

| 脚本 | 用途 |
|------|------|
| `gateway-health.sh` | 网关健康检查（进程、端口、日志尾部） |
| `restart-gateway.sh` | 网关重启（systemd user service） |

---

## 🔑 重点说明：repo-guard.sh

公开仓库的守卫。**本地与 GitHub Actions 共用这一份实现**
（CI 侧 `.github/workflows/repo-guard.yml` 只负责调用它），
因此不存在「本地过了 CI 却红」的情况。

```bash
bash scripts/system/repo-guard.sh            # 仓库内任意位置
bash scripts/system/repo-guard.sh --quiet    # 只输出结论
```

检查四项：

| # | 检查 | 拦截规则 |
|---|------|----------|
| 1 | 密钥特征 | `ghp_*`、`github_pat_*`、`sk-*`、`AKIA*`、`AIza*`、`xox[baprs]-*` |
| 2 | 私钥内容 | `BEGIN ... PRIVATE KEY` |
| 3 | 敏感文件被追踪 | `.env`、`.pem`、`.key`、`.p12`、`.pfx`、`id_rsa`、`id_ed25519`、`.git-credentials` |
| 4 | 超大文件 | 单文件 > 5MB |

排除 `.git/`、`.github/` 与脚本自身（内含正则字面量）。
误报可用 `git commit --no-verify` 跳过——但请不要习惯性使用它。

> **已知的严格性**：扫描是纯形态匹配，不判断熵。长度达标的**占位符**也会被拦——
> 实测中，文档示例里 `ghp_` 后跟 20 个相同字符就会命中。遇到这类误报，
> 正确做法是把占位符缩短到 20 字符以下（如 `ghp_...`），而不是用
> `--no-verify` 跳过。宁可误报，不可漏报。

---

## 🧩 新增脚本的规范

1. 按上表归类落位；不确定归属时看 [CONTRIBUTING.md](../CONTRIBUTING.md) 的目录表
2. 用 `check-env.sh` 的 banner 与颜色变量风格
3. 在**本文件**的表里加一行
4. 在顶层 [README.md](../README.md) 的脚本索引里加一行
5. `bash scripts/system/repo-guard.sh` 自查，然后提交
