# 🏗️ ZRL Resources

> **由 Hermes Agent 自动维护的个人资源库**
> 整合系统配置、脚本工具、知识库和项目模板，一站式管理开发环境。

---

## 📂 目录结构

```
resources/
├── system/           # 🖥️ 系统配置（WSL、Shell、代理）
├── hermes/           # 🤖 Hermes Agent 配置与技能
├── scripts/          # ⚡ 实用脚本集合
│   ├── system/       #   系统管理
│   ├── dev/          #   开发环境
│   └── qq-bot/       #   QQ Bot 运维
├── knowledge/        # 📚 知识库与指南
├── tools/            # 🔧 一键安装工具
├── templates/        # 📋 项目模板（Python/Node/Docker）
└── git-config/       # 🐙 Git 配置与模板
```

---

## 🚀 快速开始

```bash
# 克隆本库
git clone https://github.com/z0r0l0/resources.git ~/resources

# 一键安装开发环境
bash ~/resources/tools/one-click-setup.sh

# 查看系统健康状态
bash ~/resources/scripts/system/check-env.sh
```

---

## 📖 分类说明

| 目录 | 说明 | 谁用 |
|------|------|------|
| `system/` | WSL 配置、Shell 环境、代理设置 | 新机部署时参考 |
| `hermes/` | Hermes Agent 配置、自定义技能 | AI 助手与我共享 |
| `scripts/` | 日常运维、开发辅助脚本 | 终端直接运行 |
| `knowledge/` | 技术文档、排错指南 | 查阅/学习 |
| `templates/` | 项目脚手架，开箱即用 | 新项目启动 |
| `tools/` | 环境初始化、一键安装 | 新系统配置 |

---

## 🔄 维护策略

- **自动同步：** Hermes Agent 定时检查更新
- **手动更新：** `git pull && bash scripts/system/update-all.sh`
- **问题反馈：** 直接通过 QQ 告诉我

---

> **保持简洁，聚焦实用，持续进化。**
