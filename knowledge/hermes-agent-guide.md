# 🤖 Hermes Agent 使用指南

## 什么是 Hermes Agent？

Hermes Agent 是 Nous Research 开发的开源 AI 助手框架，支持：
- 多工具调用（文件、终端、浏览器、代码执行）
- 多种网关（CLI、QQ Bot、Telegram、Discord 等）
- 技能系统（SKILL.md 专业知识包）
- 定时任务（Cron）
- 子代理委派（并行任务）
- 跨会话记忆

## 技能开发

技能（Skill）是 Hermes 的专业知识包，放在 `~/.hermes/skills/` 下。

### SKILL.md 格式
```yaml
---
name: my-skill
description: 技能描述
---
# 正文

## 步骤
1. 具体操作
2. 命令示例

## 注意事项
- 常见坑
```

### 内置工具

| 工具 | 用途 |
|------|------|
| `terminal` | 执行 Shell 命令 |
| `read_file` / `write_file` / `patch` | 文件操作 |
| `search_files` | 搜索文件和内容 |
| `web_search` / `web_extract` / `browser_*` | 网络操作 |
| `execute_code` | 运行 Python 脚本 |
| `delegate_task` | 委派子任务 |
| `cronjob` | 定时任务管理 |
| `memory` / `session_search` | 记忆与历史 |
| `skill_manage` | 技能管理 |

## 配置说明

```yaml
model:
  default: deepseek-v4-flash
  provider: deepseek
  base_url: https://api.deepseek.com/v1

agent:
  max_turns: 150
  reasoning_effort: medium
```
