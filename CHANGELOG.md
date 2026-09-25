# 📝 变更记录

本文件记录本资源库的所有重要变更。
格式遵循 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.1.0/)，
版本号遵循 [语义化版本](https://semver.org/lang/zh-CN/)。

---

## [1.4.0] - 2026-09-25

### 新增
- `scripts/system/verify-github-token.sh` — **凭据权限审计**：识别凭据类型（classic /
  fine-grained），标出危险 scope（`admin:public_key`、`workflow` 等）并说明后果，
  再按能力做只读探测。凭据经 600 权限的 curl 配置文件传递，不出现在命令行参数中
- 规范验证命令新增该脚本的断言（语法 + 无凭据时干净失败）

---

## [1.3.0] - 2026-09-25

### 新增
- `tests/verify-tooling.py` — **规范验证命令**：46 项行为断言，校验守卫自身与
  `.github` 配置。可移植（CI 中自动跳过本机私有部分的检查）
- CI 在守卫之后追加运行工具自测

### 修复
- `repo-guard.sh` 的目标仓库改由**脚本自身位置**决定，此前用工作目录判断：
  从另一个仓库里运行本脚本时会去守那个仓库，使用者却以为在守本仓库 ——
  一个会给出错误安全感的静默缺陷。新增 `REPO_ROOT` 显式覆盖

---

## [1.2.0] - 2026-09-25

### 新增
- `LICENSE` — MIT 许可，此前为「保留所有权利」状态
- `SECURITY.md` — 安全约定与漏洞报告方式
- `CONTRIBUTING.md` — 文件规范、提交规范、提交前检查
- `CHANGELOG.md` — 本文件
- `scripts/system/repo-guard.sh` — 入库守卫，**本地与 CI 共用同一份实现**
- `scripts/README.md`、`system/README.md` — 补齐缺失的目录索引
- `system/security/README.md` — 权限审计方法论（通用，不含主机信息）
- `.github/dependabot.yml` — Actions 依赖每周自动检查
- `.github/ISSUE_TEMPLATE/`、`.github/PULL_REQUEST_TEMPLATE.md`

### 变更
- `README.md` 重构：CI 徽章、完整目录树、可点击索引、安全约定、许可说明
- `.github/workflows/repo-guard.yml` 瘦身为「调用 `repo-guard.sh`」，消除两处规则漂移的可能
- 主机专属的权限审计基线移出公开仓库，改由同名私有仓库承载

### 安全
- 隐去公开 README 中的 QQ AppID（AppID 非密钥，但公开无收益）
- 关闭未使用的 Wiki 功能
- 开启「合并后自动删除分支」
- main 分支保护：禁止强推、禁止删除

---

## [1.1.0] - 2026-09-25

### 新增
- `system/security/permission-baseline.md` — 首次建立主机权限审计基线
- `system/security/permission-baseline.md` v1.1 — 修正 `/mnt/c` 盘根结论

### 修复
- 盘根与用户目录的写入权限结论此前被混为一谈：`C:\` 盘根实为只读（Windows 系统盘 ACL），
  而 `C:\Users\<user>` 及子目录可写。二者已拆分为独立条目。
- 复核命令改为同时探测盘根与用户目录

### 安全
- 新增 `.github/workflows/repo-guard.yml` — 推送时扫描密钥特征、私钥内容、敏感文件与大文件

---

## [1.0.0] - 2026-07-20

### 新增
- 初始化资源库：`system/`（WSL、Shell、代理）、`hermes/`（Agent 配置）、
  `scripts/`（系统与开发脚本）、`knowledge/`（技术文档）、
  `templates/`（Python/Node/Docker 模板）、`tools/`（一键安装）、`git-config/`
