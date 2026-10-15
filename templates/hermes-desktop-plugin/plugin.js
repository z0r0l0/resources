// =============================================================================
// Hermes 桌面插件 · 最小可运行示例
//
// 演示四件事：
//   1) 注册一个整页界面 + 一个左侧导航入口
//   2) 从自己的后端取数（useQuery）
//   3) 带写操作 + 二次确认（useMutation）
//   4) 每段独立错误边界（**最重要的一条**：区块崩了不该拖垮整页，
//      而且边界会把异常打印出来，否则你只能看到"这块空白"）
//
// 只能用 @hermes/plugin-sdk 与 react —— 不要 import 宿主内部模块。
// 用 jsx()/jsxs() 函数式写法，不要写裸 JSX（插件以 .js 分发，不经 JSX 编译）。
// =============================================================================
import { jsx, jsxs } from 'react/jsx-runtime'
import { Component, useState } from 'react'
import {
  Button,
  Card,          // 若 SDK 未导出，可自行实现（见文末 Notes）
  host,
  queryClient,
  ROUTES_AREA,
  SIDEBAR_NAV_AREA,
  useMutation,
  useQuery
} from '@hermes/plugin-sdk'

const ID = 'demo'
const ROUTE = '/demo'

// ---------------------------------------------------------------------------
// 每段一个错误边界
// ---------------------------------------------------------------------------
class SectionBoundary extends Component {
  constructor(props) {
    super(props)
    this.state = { err: null }
  }
  static getDerivedStateFromError(err) { return { err } }
  componentDidCatch(err) { console.error(`[${ID}] 区块崩溃`, err) }
  render() {
    if (this.state.err) {
      return jsxs('div', {
        className: 'flex flex-col gap-0.5 rounded border border-(--ui-border) p-3',
        children: [
          jsx('div', { className: 'text-xs text-(--ui-red)', children: '这块出错了' }),
          jsx('div', {
            className: 'text-[0.625rem] text-(--ui-text-quaternary)',
            children: String(this.state.err?.message ?? this.state.err)
          })
        ]
      })
    }
    return this.props.children
  }
}

/** 给整块的便捷包装：标题 + 边界 */
function Section({ title, children }) {
  return jsxs('div', {
    className: 'flex min-w-0 grow basis-[min(100%,22rem)] flex-col gap-2 rounded border border-(--ui-border) p-3',
    children: [
      jsx('div', { className: 'text-xs text-(--ui-text-secondary)', children: title }),
      jsx(SectionBoundary, { children })
    ]
  })
}

// ---------------------------------------------------------------------------
// 区块：读 + 写（带二次确认）
// ---------------------------------------------------------------------------
function DemoSection({ rest }) {
  const [armed, setArmed] = useState(false)

  const { data, isLoading } = useQuery({
    queryKey: [ID, 'overview'],
    queryFn: () => rest('/overview'),
    staleTime: 15_000
  })

  const bump = useMutation({
    mutationFn: () => rest('/bump', { method: 'POST', body: { by: 1 } }),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: [ID, 'overview'] })
      host.notify({ kind: 'success', message: '已 +1' })
      setArmed(false)
    },
    onError: err => host.notify({ kind: 'error', message: `失败：${err?.message ?? err}` })
  })

  if (isLoading) {
    return jsx('div', { className: 'text-xs text-(--ui-text-quaternary)', children: '读取中…' })
  }

  return jsxs('div', { className: 'flex flex-col gap-2', children: [
    jsx('div', {
      className: 'text-[0.6875rem] text-(--ui-text-secondary)',
      children: `当前计数：${data?.count ?? '?'}`
    }),
    // 写操作一律二次确认：第一次点只是"上膛"，再点一次才真做
    jsx(Button, {
      size: 'sm',
      variant: 'outline',
      disabled: bump.isPending,
      className: armed ? 'border-(--ui-red)' : undefined,
      onClick: () => {
        if (!armed) { setArmed(true); return }
        bump.mutate()
      },
      children: armed ? '确认 +1？' : '+1'
    })
  ]})
}

// ---------------------------------------------------------------------------
// 整页
// ---------------------------------------------------------------------------
function DemoPage({ rest }) {
  return jsxs('div', {
    className: 'flex h-full w-full flex-col gap-3 overflow-auto p-5',
    children: [
      jsx('div', { className: 'text-sm text-(--ui-text-secondary)', children: '演示面板' }),
      jsxs('div', {
        // 宽屏容器必须保留 flex-wrap，否则区块不会换行、只会被无限压窄
        className: 'flex flex-wrap items-start gap-3',
        children: [
          jsx(Section, { title: '计数', children: jsx(DemoSection, { rest }) })
        ]
      })
    ]
  })
}

// ---------------------------------------------------------------------------
// 注册
// ---------------------------------------------------------------------------
export default {
  id: ID,
  name: '演示面板',
  register(ctx) {
    // 后端句柄：所有 rest('/x') 实际请求 /api/plugins/<ID>/x
    const rest = ctx.rest
    ctx.registerMany([
      // 整页界面
      { id: 'page', area: ROUTES_AREA, data: { path: ROUTE }, render: () => jsx(DemoPage, { rest }) },
      // 左侧导航入口
      { id: 'nav', area: SIDEBAR_NAV_AREA, data: { path: ROUTE, label: '演示', codicon: 'pulse' } }
    ])
  }
}

// =============================================================================
// Notes
//
// · Card / Button / Input 等组件的可用性随 SDK 版本变化，以你的版本为准；
//   缺什么就用普通元素 + 主题变量（如 text-(--ui-text-secondary)）自己拼。
// · 不要硬编码颜色：只用 CSS 变量，否则深浅色主题必翻车。
// · 列表项记得 shrink-0：flex 列的子项默认会被压缩，面板一窄长内容就溢出到下一块。
// · 辅助 const 一律声明在 early return **之前**，否则会撞 const 的暂时性死区
//   （"Cannot access 'x' before initialization"）。
// =============================================================================
