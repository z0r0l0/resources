# ⚙️ Hermes 无人值守：systemd user 单元模板

> 配套脚本在 `scripts/hermes/`。这三组单元构成"机器重启后自己回来 + 出事自己喊"的最小体系。
> 把 `<user>` 换成你的用户名；脚本路径按实际放置位置调整。

---

## 前置：无登录会话也要能跑

```bash
sudo loginctl enable-linger <user>          # 关键：否则没有登录会话时 user 单元不会启动
loginctl show-user <user> | grep Linger     # → Linger=yes
```

---

## 1. 网关服务（常驻）

`~/.config/systemd/user/hermes-gateway.service`

```ini
[Unit]
Description=Hermes Agent 消息网关
After=network-online.target

[Service]
Type=simple
# 进程真死了由 systemd 救 —— 这类故障不要自己再写一套
Restart=always
RestartSec=5
# 代理残留会掐断到消息通道的连接；按需保持为空或指向你的代理
Environment=no_proxy=127.0.0.1,localhost
ExecStart=%h/.local/bin/hermes gateway run

[Install]
WantedBy=default.target
```

---

## 2. 网关看护（静默失联自愈，每 5 分钟）

`~/.config/systemd/user/hermes-gateway-watchdog.service`

```ini
[Unit]
Description=Hermes 网关看护（检测静默失联并自愈）
After=hermes-gateway.service
StartLimitIntervalSec=600
StartLimitBurst=5

[Service]
Type=oneshot
ExecStart=%h/.hermes/bin/gateway-watchdog.sh
Nice=10
```

`~/.config/systemd/user/hermes-gateway-watchdog.timer`

```ini
[Unit]
Description=每 5 分钟拉起网关看护

[Timer]
OnBootSec=3min
OnUnitActiveSec=5min
AccuracySec=30s

[Install]
WantedBy=timers.target
```

> **注意**：这个 `.service` 的 `is-enabled` 会显示 `static`、`is-active` 显示 `inactive`。
> **这是正常的** —— 它是 oneshot，由 timer 按点拉起，跑完即退。
> 检查是否在跑，要看 **timer 的 NEXT/LAST**：
> `systemctl --user list-timers --all | grep watchdog`

---

## 3. 内存看护（每 3 分钟）

有过 OOM 史就值得加。OOM 会连坐杀掉别的进程，所以要**独立且极轻**。

`~/.config/systemd/user/hermes-memory-guard.service`

```ini
[Unit]
Description=内存水位看护（超阈值告警）
StartLimitIntervalSec=600
StartLimitBurst=5

[Service]
Type=oneshot
ExecStart=%h/.hermes/bin/memory-guard.sh
Nice=10
```

`~/.config/systemd/user/hermes-memory-guard.timer`

```ini
[Unit]
Description=每 3 分钟检查内存水位

[Timer]
OnBootSec=2min
OnUnitActiveSec=3min
AccuracySec=30s

[Install]
WantedBy=timers.target
```

---

## 4. 开机报平安（自启验收判据，一次性）

`~/.config/systemd/user/hermes-boot-notify.service`

```ini
[Unit]
Description=启动后报告 Hermes 是否自动恢复
# 网关没起来也要能跑：本单元只依赖用户级 systemd，不要求网关先就绪
After=default.target
StartLimitIntervalSec=600
StartLimitBurst=5

[Service]
Type=oneshot
ExecStart=%h/.hermes/bin/boot-notify.sh
Nice=10
```

`~/.config/systemd/user/hermes-boot-notify.timer`

```ini
[Unit]
Description=开机 2 分钟后报平安

[Timer]
OnBootSec=2min
Persistent=true

[Install]
WantedBy=timers.target
```

---

## 启用与验收

```bash
systemctl --user daemon-reload
systemctl --user enable --now \
    hermes-gateway.service \
    hermes-gateway-watchdog.timer \
    hermes-memory-guard.timer \
    hermes-boot-notify.timer

# 看 timer 是否在调度（NEXT 列有值 = 在跑）
systemctl --user list-timers --all | grep hermes
```

### ⚠️ 验收要看"真的做了"，不是"单元成功"

单元 `Result=success`、退出码 0，**不代表消息发出去了**（`hermes send` 可能失败）。
正确做法是核对日志里的**事实**：

```bash
# 本次开机之后是否真有成功记录？
journalctl --user -u hermes-boot-notify.service --since "$(uptime -s)"
grep '已发送' ~/.hermes/logs/boot-notify.log
```

**冷启动的真正验收**（只有你能做）：重启机器、**不要登录**，
看是否收到那条"开机报平安"。收到 = 三根柱子（WSL 自拉起 / linger / 网关自启）都立着。
