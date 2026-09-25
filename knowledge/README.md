# 📚 ZRL Knowledge Base

> WSL + Hermes Agent + QQ Bot 全栈开发环境知识库。
> 每条结论都来自实际踩坑，不是抄文档。

---

## 📖 文档列表

| 文档 | 说明 |
|------|------|
| [`wsl-ultimate-guide.md`](wsl-ultimate-guide.md) | WSL2 环境搭建、配置、排错大全 |
| [`network-proxy-setup.md`](network-proxy-setup.md) | Clash Verge Rev + WSL 代理链路与 DNS |
| [`hermes-agent-guide.md`](hermes-agent-guide.md) | Hermes Agent 安装、配置、记忆与技能体系 |
| [`qq-bot-deployment.md`](qq-bot-deployment.md) | QQ Bot 网关部署与运维（含踩坑） |
| [`k8s-observability-guide.md`](k8s-observability-guide.md) | 轻量级 K8s 可观测性平台运维手册 |

> 索引与实际文件保持一致。新增文档请同时更新本表与顶层
> [README.md](../README.md) 的文档索引。

---

## 🔍 快速索引

### WSL 要点

- DNS 手动管理（静态 `resolv.conf`，`generateResolvConf=false`）
- 网络模式 `mirrored`：Windows 宿主机即 `127.0.0.1`
- 通过 `/mnt/c/` 访问 Windows 文件系统
- 系统盘迁移、systemd 启用

### Hermes 要点

- 模型与供应商配置在 `~/.hermes/config.yaml`
- 密钥与渠道配置在 `~/.hermes/.env`（**不进版本库**）
- 技能系统：`~/.hermes/skills/<分类>/<名称>/SKILL.md`
- 长期记忆：`~/.hermes/memories/`（有字符上限，需定期整理）
- 定时任务：`~/.hermes/cron/`

### QQ Bot 要点

- 凭据在 `~/.hermes/.env`：`QQ_APP_ID` / `QQ_CLIENT_SECRET`
- 网关以 **systemd user service** 常驻
- **home channel 必须写在 `.env` 里**（`QQBOT_HOME_CHANNEL`），
  写进 `config.yaml` 会被静默忽略
- `no_proxy` 需放行 `*.qq.com`，否则网关连不上 QQ 服务器

详见 [`qq-bot-deployment.md`](qq-bot-deployment.md)。

### 代理要点

- Clash Verge Rev → 混合端口 `7897`
- 代理变量**按端口探测后导出**，不硬编码（端口不通时导出会让所有命令挂死）
- apt 走内网镜像时需显式清空代理变量
- 出网域名可达性可能不均衡，排查看 [`network-proxy-setup.md`](network-proxy-setup.md)
