# 🤖 QQ Bot 网关部署与运维

> 在 WSL2 上把 Hermes Agent 接到 QQ，并以 systemd user service 常驻。
> 本文记录实际跑通的配置与踩过的坑。

---

## 架构

```
QQ 用户 ──► QQ 开放平台 ──► Hermes 网关（WSL2，systemd user service）
                                    │
                                    ├─ 模型 API（经代理出网）
                                    └─ 本地工具（terminal / file / browser...）
```

网关是一个**常驻进程**，不是按需拉起的。它以 systemd user service 方式运行，
因此不依赖登录的 shell，且能设置失败自动重启。

---

## 1. 凭据配置

凭据**只放** `~/.hermes/.env`，权限 600：

```bash
# 文件权限必须是 600 —— 其它用户不可读
chmod 600 ~/.hermes/.env
```

需要的关键键：

| 键 | 用途 |
|----|------|
| `QQ_APP_ID` | 机器人应用 ID |
| `QQ_CLIENT_SECRET` | 应用密钥（**真正的敏感值**） |
| `QQBOT_HOME_CHANNEL` | 默认投递目标（见下方坑） |
| `QQ_ALLOWED_USERS` | 允许交互的用户白名单 |

---

## 2. 三个必踩的坑

### 坑 1：home channel 写在 `config.yaml` 里无效

`hermes send --to qqbot:<OPENID>` 的解析函数里没有 qqbot 分支，
home channel 是**从环境变量读的**（`QQBOT_HOME_CHANNEL`）。

写在 `config.yaml` 顶层不会报错，会被**静默忽略**，表现为
「No home channel set」。正确做法：写进 `.env`。

### 坑 2：代理会把网关自己掐死

网关要连 QQ 服务器，而代理的目的是给模型 API 出网。若把全局代理变量
导出给网关进程，连 QQ 的请求也会绕进代理，直接连不上。

解决：`no_proxy` 必须放行 `*.qq.com` 以及私网段。

### 坑 3：发消息时残留的代理变量

从 CLI 手动触发发送时，shell 里若残留无效代理，请求会失败。
排错时先 `env | grep -i proxy` 看一遍。

---

## 3. 运维命令

```bash
# 状态
systemctl --user status hermes-gateway.service

# 重启
systemctl --user restart hermes-gateway.service

# 跟随日志
journalctl --user -u hermes-gateway.service -f

# 健康检查（本仓库脚本）
bash ~/resources/scripts/qq-bot/gateway-health.sh
```

查看服务实际继承的环境变量（排 no_proxy 问题时很有用）：

```bash
systemctl --user show hermes-gateway.service -p Environment
tr '\0' '\n' < /proc/$(systemctl --user show -p MainPID --value hermes-gateway.service)/environ \
  | grep -iE 'proxy|qqbot'
```

---

## 4. 排查顺序

出现「机器人不回复」时，按这个顺序查，别跳步：

| # | 检查 | 命令 |
|---|------|------|
| 1 | 服务在跑吗 | `systemctl --user is-active hermes-gateway` |
| 2 | 日志有报错吗 | `journalctl --user -u hermes-gateway -n 50` |
| 3 | 凭据还在吗 | 确认 `.env` 里 `QQ_APP_ID` / `QQ_CLIENT_SECRET` 存在（**不打印值**） |
| 4 | 代理干扰吗 | 检查 `no_proxy` 是否含 `*.qq.com` |
| 5 | 白名单拦了吗 | 确认你的 OpenID 在 `QQ_ALLOWED_USERS` 里 |
| 6 | 模型 API 通吗 | 单独测一次模型调用，区分「网关问题」与「模型问题」 |

第 6 步最容易被跳过：机器人不回，可能网关没事，是模型 API 欠费或不可达。

---

## 5. 安全

- `QQ_CLIENT_SECRET` 泄露 = 别人可以冒充你的机器人
- `.env` 永不进版本库（本仓库的守卫也拦 `.env`）
- AppID 本身不是密钥，但公开无收益，文档里一律隐去
- 权限审计时**只记录键名，不记录值**，方法见
  [../system/security/README.md](../system/security/README.md)
