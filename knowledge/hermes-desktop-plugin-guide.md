# 🧩 Hermes Agent 桌面插件开发指南

> 给 Hermes 桌面端（Electron）写一个自定义面板：左侧导航入口 + 整页界面 + 单页后端。
> 全部来自一次实战（写了一个叫「维尼」的运维面板：记忆条目编辑、技能启停、日程周视图）。

---

## 一、一个插件由什么构成

```
~/.hermes/
├── desktop-plugins/<id>/          # 前端（被桌面端加载）
│   ├── plugin.yaml                # 让 `hermes plugins` 认得它
│   ├── manifest.json              # 声明启用了哪些能力（含后端 api）
│   └── plugin.js                  # 界面：注册页面 / 导航项 / 侧栏面板
└── plugins/<id>/dashboard/        # 后端（可选）
    └── plugin_api.py              # FastAPI 路由，挂到 /api/plugins/<id>/
```

四个名字必须**互相对齐**，否则表现为"前端能打开但一取数就 404"：

- 目录名 == `manifest.json` 的 `name` == `plugin.yaml` 的 `name`（`plugins.enabled` 按名字匹配）
- 前端调 `rest('/xxx')` 时，实际请求的是 `/api/plugins/<name>/xxx`

写完自检一遍这四条，比看日志快。

---

## 二、插件主体的形状

```javascript
import { jsx, jsxs } from 'react/jsx-runtime'
import { Component, useEffect, useState } from 'react'
import { Button, host, Input, ROUTES_AREA, SIDEBAR_NAV_AREA, useMutation, useQuery, useValue }
  from '@hermes/plugin-sdk'

const ID = 'myplugin'
const ROUTE = '/myplugin'

export default {
  id: ID,
  name: '我的面板',
  register(ctx) {
    let rest = null
    ctx.registerMany([
      // 1) 整页界面
      { id: 'page', area: ROUTES_AREA, data: { path: ROUTE }, render: () => jsx(MyPage, {}) },
      // 2) 左侧导航入口
      { id: 'nav',  area: SIDEBAR_NAV_AREA, data: { path: ROUTE, label: '我的', codicon: 'pulse' } },
    ])
    rest = ctx.rest          // 后端句柄，组件里用它取数
  }
}
```

要点：

- **只能 import SDK + react**，不要碰宿主内部模块（升级即碎）。
- 用 `jsx()/jsxs()` 函数式写法，**不要写裸 JSX**（插件以 `.js` 分发，不经 JSX 编译）。
- 主题色只用 CSS 变量（`text-(--ui-text-secondary)`、`border-(--ui-border)` …），
  硬编码颜色在深/浅色主题下必翻车。

---

## 三、必须做：每段一个错误边界

**这是整套设计里回报最高的一条。** 把每个功能区块包进自己的错误边界：

```javascript
class SectionBoundary extends Component {
  constructor(p) { super(p); this.state = { err: null } }
  static getDerivedStateFromError(err) { return { err } }
  componentDidCatch(err) { console.error('[myplugin] section crashed', err) }
  render() {
    if (this.state.err) {
      return jsxs('div', {}, [
        jsx('div', { children: '这块出错了' }),
        jsx('div', { children: String(this.state.err?.message || this.state.err) })
      ])
    }
    return this.props.children
  }
}
```

为什么值：一次我把辅助函数的声明写在了 `early return` **下面**（`const` 的暂时性死区），
整个区块崩掉。**因为有了边界，面板上直接打印出**：

```
「提醒」这块出错了 — Cannot access 'renderSwitcher' before initialization
```

一眼定位。如果没有它，表现只是"这块空白"，你会去查数据、查网络、查后端 —— 全是弯路。

配套约定：**一个区块 = 一个组件**。区块内部崩了不该拖垮整页。

---

## 四、踩过的坑（每条都真实发生过）

### 1. `const` 的暂时性死区

```javascript
// ❌ 崩：Cannot access 'renderSwitcher' before initialization
if (view === 'week') return renderSwitcher()
const renderSwitcher = () => ...

// ✅ 所有辅助 const 声明在 early return **之前**
const renderSwitcher = () => ...
if (view === 'week') return renderSwitcher()
```

### 2. Hooks 必须在所有 early return 之前

React 规则。写多个 query/mutation 的区块尤其容易犯：一旦某个 return 排在 hook 前面，
渲染次数一变就报 "Rendered fewer hooks than expected"。可以把这条做成静态检查。

### 3. `flex-1` 会覆盖 `flex-basis`

**简写属性和具体属性不要混用**：

```jsx
// ❌ flex-1 == flex: 1 1 0% —— 把 flex-basis 归零，覆盖掉后面的 basis-[...]
className="flex-1 basis-[min(100%,22rem)]"
// ✅ grow 只设 flex-grow，不碰 basis
className="grow basis-[min(100%,22rem)]"
```

症状很隐蔽：区块宽度塌成**内容宽**，内容少时看不出来，一多就文字互相覆盖。
`font` / `background` 等简写同理。

### 4. flex 列的子项会被压缩

纵向 `flex-col` 里，子项默认 `flex-shrink:1`。面板一窄（侧栏 ~340px），长内容会被压扁、
文字溢出到相邻块上。列表项记得 `shrink-0`。

### 5. 别放"看起来像按钮的纯文字标签"

切换条 `视图　整篇　逐条` 里，"视图"只是灰色说明文字。用户点了没反应，报"**视图打不开**"。
同排、同字重、同间距 → 一定会被当成控件。**要么视觉上明确不是控件，要么删掉**。

### 6. 数据可能是"看起来对但结构不同"

后端返回的动态字段，用之前先归一化：`Array.isArray(x) ? x : []`。
`?.` 只防 `null/undefined`，挡不住类型不符。

### 7. 只改 `.usage.json`，不要动技能目录

做"归档/恢复技能"这类功能时，写状态到遥测文件（可逆），而不是移动/删除文件。
**可逆是这类操作最重要的性质。**

---

## 五、怎么验证

### 静态审计（每次改完都跑）

自己写一个小脚本检查最容易犯的错，比人工 review 可靠：

- import 只允许 SDK / react
- `jsx()/jsxs()` 里的标识符都已定义（能识别 `class` 声明）
- 没有裸 JSX 语法
- 没有硬编码颜色
- hooks 是否都在 early return 之前

### 实机交互（用 CDP 驱动）

桌面端是 Electron，开个调试端口就能用 Chrome DevTools Protocol 驱动：

```bash
WEINI_DEBUG_PORT=39344 ./launch.sh          # 仅监听 127.0.0.1
curl -s --noproxy '*' http://127.0.0.1:39344/json/version
```

**协议细节（踩过）**：React 的合成事件不认 `el.click()`，要发**完整的指针事件序列**：

```javascript
const r = el.getBoundingClientRect()
const o = { bubbles: true, cancelable: true, clientX: r.left + r.width/2, clientY: r.top + r.height/2 }
el.dispatchEvent(new PointerEvent('pointerdown', o))
el.dispatchEvent(new MouseEvent('mousedown', o))
el.dispatchEvent(new PointerEvent('pointerup',   { ...o, buttons: 0 }))
el.dispatchEvent(new MouseEvent('mouseup',       { ...o, buttons: 0 }))
el.dispatchEvent(new MouseEvent('click',         { ...o, buttons: 0 }))
```

**受控输入框**要用原生 setter 才能触发 React 的 onChange：

```javascript
const setter = Object.getOwnPropertyDescriptor(window.HTMLInputElement.prototype, 'value').set
setter.call(input, '新值'); input.dispatchEvent(new Event('input', { bubbles: true }))
```

### 量几何，不要靠肉眼猜

排查布局问题时，直接读渲染结果：

```javascript
getComputedStyle(el).flexBasis        // 看实际生效值，而不是你写了什么
el.getBoundingClientRect()            // 实际宽高位置
el.scrollHeight > el.clientHeight     // 是否被压扁/裁切
```

### 反向对照（证明断言不是恒真）

把"正确的写法"人为改回"错误的"，断言必须报错；然后还原。绿不代表有效，**能红才算有效**。

---

## 六、安全边界：面板只能碰自己的东西

面板做的事往往带写操作。**给每一类写操作划清范围**，并在后端强制：

- 只允许操作带**本面板专有前缀**的对象（例如提醒任务名前缀 `提醒 · `）
- 真正的系统级周期任务（日报、看护）一律拒绝从面板改/停/删 —— 否则一次误点就让看护停摆
- 断言里要包含"**被拒之后对象仍然原样**"，防止"先改坏再报错"

另外，把"暂停"和"删除"分开：暂停只是 `enabled=False`，对象仍在列表里、随时可恢复。

---

## 七、交付前清单

- [ ] 四个名字对齐（目录 / manifest / plugin.yaml / 路由前缀）
- [ ] 每个区块有独立错误边界
- [ ] 没有裸 JSX、没有硬编码颜色、hooks 都在 return 之前
- [ ] 辅助 `const` 都在 early return 之前（TDZ）
- [ ] 简写属性没有和具体属性混用（`flex-1` + `basis-*`）
- [ ] 列表项 `shrink-0`
- [ ] 没有"看着像按钮的纯文字"
- [ ] 写操作有范围限制 + 后端强制
- [ ] 静态审计过一遍
- [ ] CDP 实机点一遍（含写操作的真实往返）
- [ ] 破坏性断言做过反向对照
