# 🏗️ ZRL Resources

> **个人资源库 —— 系统配置、脚本、知识库、项目模板。由 Hermes Agent 维护。**
> 在 WSL 上从零搭建一套可复用的开发环境，把踩过的坑固化成能重复执行的东西。

[![repo-guard](https://github.com/z0r0l0/resources/actions/workflows/repo-guard.yml/badge.svg)](https://github.com/z0r0l0/resources/actions/workflows/repo-guard.yml)
[![license](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)
[![last commit](https://img.shields.io/github/last-commit/z0r0l0/resources)](https://github.com/z0r0l0/resources/commits/main)

---

## 🚀 快速开始

```bash
# 克隆
git clone https://github.com/z0r0l0/resources.git ~/resources

# 一键安装开发环境（Node / Python / Docker / 常用工具）
bash ~/resources/tools/one-click-setup.sh

# 查看系统健康状态
bash ~/resources/scripts/system/check-env.sh

# 提交前自查（与 CI 同一份实现）
bash ~/resources/scripts/system/repo-guard.sh

# 规范验证命令：校验守卫自身与 .github 配置的行为
python3 ~/resources/tests/verify-tooling.py
```

---

## 📂 目录结构

```
resources/
├── system/                    # 🖥️ 主机配置
│   ├── proxy/                 #   代理配置（WSL + Clash Verge Rev）
│   ├── security/              #   安全约定与权限审计方法论
│   ├── shell/                 #   Shell 环境（env.sh / 别名）
│   └── wsl/                   #   WSL 配置（wsl.conf / resolv.conf）
├── scripts/                   # ⚡ 可执行脚本
│   ├── dev/                   #   Node / Python 环境安装
│   ├── qq-bot/                #   QQ Bot 网关运维
│   └── system/                #   系统检查、安装、更新、仓库守卫
├── knowledge/                 # 📚 技术文档与排错指南
├── hermes/                    # 🤖 Hermes Agent 配置与人格
├── templates/                 # 📋 项目模板（Python / Node / Docker）
├── tools/                     # 🔧 一键安装与环境初始化
├── git-config/                # 🐙 Git 配置与别名
└── .github/                   # ⚙️ CI 工作流与模板
```

---

## 📖 文档索引

| 文档 | 内容 |
|------|------|
| [WSL2 环境搭建终极指南](knowledge/wsl-ultimate-guide.md) | WSL 初始配置、系统盘迁移、网络模式、代理 |
| [网络与代理配置指南](knowledge/network-proxy-setup.md) | Clash Verge Rev 与 WSL 的代理链路、DNS 处理 |
| [Hermes Agent 使用指南](knowledge/hermes-agent-guide.md) | 安装、配置、记忆与技能体系 |
| [K8s 可观测性平台](knowledge/k8s-observability-guide.md) | 轻量级监控栈运维手册（版本钉死、values 驱动） |
| [安全约定](SECURITY.md) | 什么绝不入库、文档脱敏规范、问题上报 |
| [权限审计方法论](system/security/README.md) | 如何测量一个账户在主机上的真实权限边界 |
| [贡献指南](CONTRIBUTING.md) | 文件规范、提交规范、提交前检查 |
| [变更记录](CHANGELOG.md) | 版本历史 |

---

## ⚡ 脚本索引

### 开发环境

| 脚本 | 用途 |
|------|------|
| [`scripts/dev/node-setup.sh`](scripts/dev/node-setup.sh) | Node.js 环境安装（版本钉死） |
| [`scripts/dev/python-setup.sh`](scripts/dev/python-setup.sh) | Python 环境安装（venv + uv） |

### 系统运维

| 脚本 | 用途 |
|------|------|
| [`scripts/system/check-env.sh`](scripts/system/check-env.sh) | 系统健康检查（CPU/内存/磁盘/网络/Docker） |
| [`scripts/system/install-essentials.sh`](scripts/system/install-essentials.sh) | 常用开发工具一键安装 |
| [`scripts/system/update-all.sh`](scripts/system/update-all.sh) | 全量更新（系统 + 语言生态 + 工具） |
| [`scripts/system/repo-guard.sh`](scripts/system/repo-guard.sh) | **入库守卫**：密钥、私钥、敏感文件、大文件 |

### QQ Bot 网关

| 脚本 | 用途 |
|------|------|
| [`scripts/qq-bot/gateway-health.sh`](scripts/qq-bot/gateway-health.sh) | 网关健康检查 |
| [`scripts/qq-bot/restart-gateway.sh`](scripts/qq-bot/restart-gateway.sh) | 网关重启 |

### 配置脚本

| 脚本 | 用途 |
|------|------|
| [`system/proxy/proxy-setup.sh`](system/proxy/proxy-setup.sh) | WSL 代理配置（按端口探测，不硬编码） |
| [`system/shell/env.sh`](system/shell/env.sh) | Shell 环境变量（在 `.bashrc` 中 source） |
| [`tools/one-click-setup.sh`](tools/one-click-setup.sh) | 新机一键初始化 |

---

## 🔒 安全约定

本仓库**公开**，因此：

- **守卫 CI**：每次推送自动扫描密钥特征、私钥内容、敏感文件、大文件，不通过即失败
- **主机专属信息不入库**：账户名、盘符、风险登记表等只在私有仓库 `hermes-private`
- **脱敏标准**：「陌生人读到这行，能否据此定位或攻击我的机器？」

详见 [SECURITY.md](SECURITY.md)。提交前请先跑守卫：

```bash
bash scripts/system/repo-guard.sh
```

---

## 🔄 维护方式

由 Hermes Agent 维护。说一句话即可，例如：

- 「更新 K8s 文档」→ 修改 `knowledge/` 下对应文档并提交
- 「加一个 Rust 环境安装脚本」→ 落到 `scripts/dev/`，同步索引
- 「检查仓库有没有泄露东西」→ 跑守卫 + 历史扫描

**版本管理**：目录结构、新增脚本、安全相关变更 → 同步更新 `CHANGELOG.md` 与顶层目录树。

---

## 📄 许可

[MIT](LICENSE) —— 自由使用，不担保生产适用性。
