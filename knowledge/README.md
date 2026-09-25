# 📚 ZRL Knowledge Base

> WSL + Hermes Agent + QQ Bot 全栈开发环境知识库

---

## 📖 文档列表

| 文档 | 说明 |
|------|------|
| `wsl-ultimate-guide.md` | WSL2 环境搭建、配置、排错大全 |
| `hermes-agent-guide.md` | Hermes Agent 使用技巧与技能开发 |
| `qq-bot-deployment.md` | QQ Bot 网关部署与运维 |
| `network-proxy-setup.md` | Clash Verge Rev + WSL 代理配置 |

## 快速索引

### WSL 要点
- DNS 手动管理（静态 resolv.conf）
- systemd 已启用
- 通过 `/mnt/c/` 访问 Windows 文件系统

### Hermes 要点
- 默认模型：deepseek-v4-flash
- 网关：QQ Bot
- 技能系统：`SKILL.md` 格式
- 定时任务：cron 系统

### QQ Bot 要点
- APP_ID：已隐去（见本机 `~/.hermes` 配置；AppID 非密钥，但无需公开）
- 消息通过 QQ 频道收发
- 支持 Markdown 和媒体文件发送

### 代理要点
- Clash Verge Rev → 端口 7897
- 输入 `proxy-on` 启用
- apt 镜像：阿里云 mirrors.aliyun.com
