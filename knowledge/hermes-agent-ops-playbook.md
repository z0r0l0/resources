# 🤖 Hermes Agent 无人值守运维手册

> 让 Hermes 在**机器重启、无人登录**的情况下自己回来找你。
> 全部内容来自一台 WSL2 主机上的实战：踩过的坑、验证过的判据、以及「怎么证明它真的在工作」。

---

## 一、为什么需要这本手册

Hermes Agent 可以做很多事，但**前提是它得活着**。真实事故往往不是功能 bug，而是：

- Windows 半夜自动更新重启 → WSL 没被拉起 → 网关不在 → 你问它话没人答
- 网关进程活着，但 QQ 通道悄悄断了 → 界面上一切正常，消息却发不出去（**静默失联**）
- 进程被 OOM 杀掉 → 内存看护自己也被杀了 → 无人自愈

这类问题的共同点是：**出事时没有人在看**。所以手册的核心不是"怎么配"，而是
**"怎么让故障自己喊出声"**。

---

## 二、开机自启：三根柱子

开机后 Hermes 能不能自己回来，取决于**三个独立环节**，任一失效都不行：

| # | 环节 | 载体 | 失效症状 |
|---|------|------|----------|
| 1 | Windows 重启后 **WSL 被自动拉起** | Windows 计划任务 / 启动项 | WSL 根本没起来，后面都谈不上 |
| 2 | 用户级 systemd 在**无登录会话**时也启动 | `loginctl enable-linger <user>` | 没有登录会话 → user 单元不跑 → 网关不启 |
| 3 | 网关服务**随 systemd 自启**并连上通道 | `hermes-gateway.service`（enabled） | 服务起了但通道没连上 → 消息发不出 |

### 判据：开机报平安

与其盯着三个环节分别看，不如让机器**主动发一条消息**。在任何通道（QQ / Telegram / …）里
收到这条，就说明三根柱子都立着：

```
【开机报平安】
WSL 启动时间: 2026-10-15 17:35:04（已运行 7 minutes）
网关服务: 已就绪（自动启动成功）  PID=12345
QQ 通道: connected
看护器: timer active
```

关键设计：**"该来的没来"本身就是信号**。你不需要每天确认它工作，只需要在"应该收到却没收到"时警觉。

三条工程细节，缺一条就会变成噪音而不是信号：

1. **节流**（如 30 分钟一条）。WSL 可能被反复拉起（你随手开个终端就会），没节流会刷屏，
   还会白白消耗通道的主动消息配额。
2. **等网关就绪再发**，不是立刻发。开机瞬间网关往往还没连上，立刻发会得到"通道未连接"的假警报。
   做法：轮询 `systemctl --user is-active`，最多等几分钟。
3. **发送前清掉代理变量**（`unset http_proxy https_proxy all_proxy ...`）。本机代理若残留在
   环境里，会掐断到消息通道的连接 —— 这是最隐蔽的一种失败。

---

## 三、看护器：分工要清楚，别互相抢

| 故障形态 | 谁来处理 | 为什么 |
|----------|----------|--------|
| 进程**死了** | 服务自身的 `Restart=always` | systemd 原生能力，最可靠，不要另写一套 |
| 进程**活着但通道哑了** | 独立看护器（定时自检） | systemd 只看进程在不在，看不出"活着但不干活" |
| **内存吃紧**（有过 OOM 史） | 内存看护 timer | OOM 会连坐杀掉看护进程，所以要独立且轻量 |

### 看护器的实现要点

- 用 **oneshot service + timer**，不要写成常驻守护进程。常驻进程自己也会死，
  而 oneshot 每次由 systemd 拉起，本身就是一次"复活"。
- 看护器要**极轻**：`Nice=10`、不加载重依赖。它的唯一职责是判断 + 触发自愈。
- **不要抢 systemd 的活**：进程真死了不该由看护器重启（会和 `Restart=always` 打架），
  它只管"进程活着但通道哑了"这一种情况。

### ⚠️ 坑：oneshot 单元显示 `static` 是**正常**的

看护器和报平安本体的 `is-enabled` 会显示 `static`，`is-active` 显示 `inactive`。
第一眼很容易判断成"根本没在跑"，**其实是正常的** —— 它们是 oneshot，由各自的
`.timer` 按点拉起，跑完就退出：

```bash
# 正确的检查姿势：看 timer，而不是看本体 service
systemctl --user list-timers --all | grep -E 'watchdog|boot-notify'
# NEXT 列有值 = 在调度；LAST 列有值 = 刚跑过
systemctl --user show hermes-gateway-watchdog.service -p Type --value   # → oneshot
```

**只看单元状态会漏掉一种致命情况**：单元执行"成功"（退出码 0），但里面的 `hermes send`
失败了 —— 也就是**哑火**。所以验收必须去**日志里核对真的发出去了**：

```bash
# 单元成功 ≠ 消息发出。核对本次开机之后是否真有成功记录
journalctl --user -u hermes-boot-notify.service --since "$(uptime -s)"
grep '已发送' ~/.hermes/logs/boot-notify.log
```

---

## 四、诊断：卡顿/挂起怎么抓现场

### 事件循环卡顿

Hermes 后端是 asyncio。当事件循环被阻塞时，最有效的证据是**在卡顿当下 dump 全部线程栈**：

```python
# 要点：用 sys._current_frames() + traceback.format_stack()
# 不要用 faulthandler.dump_traceback(file=StringIO())
#   —— faulthandler 走文件描述符层，传 StringIO 会抛 io.UnsupportedOperation: fileno，
#      若被 except 吞掉就变成"有工具但永远没输出"
for tid, frame in sys._current_frames().items():
    stack = "".join(traceback.format_stack(frame))
    # 连同线程名一起打出来，否则分不清是谁在占 GIL
```

拿到栈后**怎么读**：

- 若某个线程停在**业务代码**里 → 它就是元凶（谁占着 GIL）
- 若**所有线程都停在等队列**（`queue.get`、`waiter.acquire`、`_worker`）→
  **不是 GIL 压力**，而是别的阻塞（同步 I/O、DNS、socket 超时），或者进程被外部挂起

### ⚠️ 坑：别把"重启期抖动"当成"GIL 泄漏"

实测踩过：日志里出现 `event loop stalled 85.1s` 很吓人，但线程栈显示**所有线程都在等队列**，
且时间戳正好对上"我 kill 桌面版"的那一刻。这是**关闭/启动期的正常抖动**，不是泄漏。

判断口诀：**卡顿时长 + 线程栈 + 发生时刻**三者一起看。只看时长会误诊。

---

## 五、排查方法论（比任何命令都重要）

### 先问清"哪个 X"

真实案例：用户报"**视图打不开**"。第一反应去查数据加载、渲染、面板尺寸 —— 全是弯路。
追问一句才明白："整篇和逐条可以打开，**视图**打不开"。

真相是：切换条长这样 `视图　整篇　逐条`，其中"整篇/逐条"是按钮，而"**视图**"只是一行灰色
**说明文字**。用户点它当然没反应 —— 但在外观上无法分辨。

**教训**：
- 报障时先问"具体是哪个元素、点什么、期望什么、实际什么"，比任何日志都快。
- **UI 上不要放"看起来像按钮的纯文字标签"**。同一行、同字重、同间距 → 用户一定会去点。
  要么让它视觉上明显不是控件，要么干脆删掉。

### 用一次实验锁定根因，别猜

案例：宽屏下每个区块宽度只有 **59px**（文字互相覆盖）。与其读代码推演，不如直接量：

```javascript
// 1) 量 computed style，看到 flexBasis 是 "0%" 而不是期望的 min(100%,22rem)
getComputedStyle(el).flexBasis
// 2) 注入一条 CSS 验证假设：如果把 basis 改对，宽度是否恢复？
style.textContent = ".row > div { flex-basis: min(100%, 22rem) !important; }"
// → 宽度立刻从 59 变成 393 ⇒ 根因确认
```

根因：`flex-1` 是 `flex: 1 1 0%` 的**简写**，会把 `flex-basis` 归零，**反过来覆盖**紧随其后的
`basis-[...]`。修法：用 `grow`（只设 flex-grow）代替 `flex-1`。

**通用教训**：写 CSS 时，**简写属性和具体属性不要混用**（`flex` / `font` / `background` 都是重灾区）。

### 反向对照：证明断言不是恒真

写验证时最容易自欺 —— 断言永远是绿的，其实什么都没检查。做法：**故意把正确的写法改回错误的，
断言必须报错**；然后确认文件已还原。

```bash
# 示例：验证"Card 不得用 flex-1 覆盖 basis"
python3 - "$FILE" <<'PY'
p.write_text(bak.replace("grow basis-[", "flex-1 basis-["))   # 人为破坏
rc = subprocess.run(["grep", "-qF", "flex-1 basis-[", str(p)]).returncode
sys.exit(0 if rc == 0 else 1)                                   # 必须能检出
finally: p.write_text(bak)                                      # 一定要还原
PY
```

---

## 六、验证的分层：别把"单元成功"当"事情办成"

本手册反复出现同一个主题：**每一层都要验到"真的发生了"**。

| 层级 | 容易犯的错 | 应该验什么 |
|------|------------|-----------|
| 单元状态 | 看到 `static`/`inactive` 就断定没跑 | 看 timer 的 NEXT/LAST；确认 Type=oneshot |
| 单元执行 | 退出码 0 就以为成功 | 去日志里找"已发送" |
| 代码改动 | 语法通过就以为功能对 | 实机交互点一遍，量真实的几何/返回值 |
| 断言本身 | 绿了就以为有效 | 反向对照：破坏正确写法，断言必须红 |

---

## 七、附：本机实际使用的单元清单

| 单元 | 类型 | 职责 |
|------|------|------|
| `hermes-gateway.service` | 常驻 | 消息网关（`Restart=always`） |
| `hermes-gateway-watchdog.service` + `.timer` | oneshot + 5min | 静默失联自愈 |
| `hermes-memory-guard.service` + `.timer` | oneshot + 3min | 内存水位告警 |
| `hermes-boot-notify.service` + `.timer` | oneshot + OnBootSec=2min | 开机报平安（三根柱子的判据） |
| `fcitx5.service` | 常驻 | 中文输入（WSLg 下需 `--disable wayland,waylandim`） |

> `<user>` 处的 linger 开启方式：`sudo loginctl enable-linger <user>`
