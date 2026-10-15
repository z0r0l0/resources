# 🧩 Hermes 桌面插件 · 最小示例

> 一个能跑起来的最小插件：整页界面 + 左侧导航入口 + 自己的后端取数。
> 开发要点与踩坑见 [桌面插件开发指南](../../knowledge/hermes-desktop-plugin-guide.md)。

---

## 装到本机

```bash
ID=demo
mkdir -p ~/.hermes/desktop-plugins/$ID ~/.hermes/plugins/$ID/dashboard

cp plugin.js plugin.yaml manifest.json ~/.hermes/desktop-plugins/$ID/
cp dashboard/plugin_api.py            ~/.hermes/plugins/$ID/dashboard/

hermes plugins enable $ID      # 名字要和目录名一致
# 重启桌面端
```

> **四个名字必须一致**：目录名 / `manifest.json` 的 `name` / `plugin.yaml` 的 `name` / 路由前缀。
> 不一致的典型症状是"前端能打开，但一取数就 404"。

---

## 文件说明

| 文件 | 作用 |
|------|------|
| `plugin.js` | 界面。注册整页 + 导航项；演示错误边界、取数、二次确认的写操作 |
| `plugin.yaml` | 让 `hermes plugins` 认得它 |
| `manifest.json` | 声明启用了哪些能力（含后端 `api` 路径） |
| `dashboard/plugin_api.py` | 后端路由，挂到 `/api/plugins/<name>/` |

---

## 这个示例特意演示了什么

1. **每段一个错误边界**（`SectionBoundary`）
   区块崩了不该拖垮整页，而且边界会把异常**打印出来**。
   实战教训：辅助函数写在 `early return` 下面（`const` 的暂时性死区）导致整块崩，
   正因为有边界，面板上直接显示
   `这块出错了 — Cannot access 'renderSwitcher' before initialization`。
   没有它，你只看到"这块空白"，然后去查数据、查网络 —— 全是弯路。

2. **写操作二次确认**
   第一次点只是"上膛"，再点一次才真做。写操作永远值得多发一次确认。

3. **取数 / 失效刷新**
   `useQuery` 读、`useMutation` 写，成功后 `invalidateQueries` 让界面自己刷新。

4. **布局要点**
   - 宽屏容器保留 `flex-wrap`（否则区块不会换行，只会被无限压窄）
   - 区块用 `grow basis-[min(100%,22rem)]`，**不要用 `flex-1`**
     （`flex-1` 是 `flex: 1 1 0%` 的简写，会把 `flex-basis` 归零并覆盖 `basis-[...]`）
   - 列表项 `shrink-0`（flex 列的子项默认会被压缩，面板一窄长内容就溢出）

---

## 后端约定

- 读接口**不要有副作用**
- 写接口**参数校验要严**（宁可 400，不要静默用默认值让前端误以为成功）
- 写操作**限定范围**：只碰本插件自己的对象，不碰系统级对象（定时任务、看护器）
- **可逆优先**：能"暂停"就不要"删除"
