# 🤖 Hermes Agent 配置

> Hermes Agent — 由 Nous Research 开发的开源 AI 助手框架

## 当前配置

| 配置项 | 值 |
|--------|-----|
| **模型** | deepseek-v4-flash |
| **供应商** | DeepSeek |
| **Base URL** | https://api.deepseek.com/v1 |
| **最大轮次** | 150 |
| **推理力度** | medium |
| **网关** | QQ Bot (APP_ID=1905239104) |

## 目录说明

```yaml
~/.hermes/
├── config.yaml          # 主配置文件
├── SOUL.md              # 灵魂/人格设定
├── .env                 # 环境变量
├── skills/              # 自定义技能（SKILL.md）
├── cron/                # 定时任务
├── cache/               # 缓存数据
└── audio_cache/         # 音频缓存
```

## 常用命令

```bash
# 状态检查
systemctl --user status hermes-gateway

# 日志查看
journalctl --user -u hermes-gateway -n 50 -f

# 重启
systemctl --user restart hermes-gateway

# 配置文件编辑
nano ~/.hermes/config.yaml
```
