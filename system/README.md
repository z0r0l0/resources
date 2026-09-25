# 🖥️ 主机配置

存放**主机层面**的配置与约定：Shell 环境、代理链路、WSL 设置、安全基线。
与 `scripts/` 的区别：这里的产出是**配置**，`scripts/` 里的是**可执行动作**。

---

## 📁 目录

| 目录 | 内容 | 关键文件 |
|------|------|----------|
| `wsl/` | WSL2 配置 | [`wsl.conf`](wsl/wsl.conf)（mirrored 网络）、[`resolv.conf`](wsl/resolv.conf)（DNS 钉死）、[README](wsl/README.md) |
| `shell/` | Shell 环境 | [`env.sh`](shell/env.sh)（环境变量）、[`.bash_aliases`](shell/.bash_aliases)、[`reference-aliases.txt`](shell/reference-aliases.txt) |
| `proxy/` | 代理配置 | [`proxy-setup.sh`](proxy/proxy-setup.sh) |
| `security/` | 安全与权限 | [README](security/README.md) —— 权限审计方法论 |

---

## ⚙️ 本机关键配置

| 项 | 值 | 理由 |
|----|-----|------|
| WSL 网络模式 | `mirrored` | Windows 宿主机即可用 `127.0.0.1` 访问，代理链路简单 |
| 代理 | Clash Verge Rev @ `127.0.0.1:7897` | 混合端口，HTTP/HTTPS 共用 |
| DNS | `119.29.29.29` / `114.114.114.114` / `8.8.8.8`，`generateResolvConf=false` | 国内 API 解析稳定，避免 WSL 覆盖 |
| 代理环境变量 | **按端口探测后动态导出** | 端口不通时导出无效代理会导致所有命令挂死 |

最后一条是踩过的坑：早期 `.bashrc` 把代理硬编码为固定地址，Clash 没启动时
shell 里全是失效代理，表现为「网络全挂」。现在改为探测到端口在监听才导出。

---

## 🔒 关于安全内容

主机专属的**权限审计结果**（账户、挂载、风险登记表）不在本公开仓库，
保存在私有仓库 `hermes-private`。

本仓库只放**方法论**：[`security/README.md`](security/README.md) ——
一套可复用的「测量一个账户在本机真实能做什么」的流程。
