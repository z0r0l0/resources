"""Hermes 桌面插件 · 最小后端示例。

挂载点：桌面端会把这个文件里的 `router` 挂到 `/api/plugins/<插件目录名>/`。
所以前端 `rest('/overview')` 实际请求的是 `/api/plugins/demo/overview`。

四个名字必须对齐，否则表现为「前端能打开但一取数就 404」：
    目录名  ==  manifest.json 的 name  ==  plugin.yaml 的 name  ==  路由前缀
"""
from __future__ import annotations

from typing import Any, Dict

from fastapi import APIRouter, HTTPException

router = APIRouter()

# 演示用状态（真实插件请从 Hermes 的 state / 文件读，不要用进程内全局变量持久化）
_STATE: Dict[str, int] = {"count": 0}


@router.get("/overview")
async def overview() -> Dict[str, Any]:
    """读接口：读操作不要有副作用。"""
    return {"count": _STATE["count"], "ok": True}


@router.post("/bump")
async def bump(body: Dict[str, Any] | None = None) -> Dict[str, Any]:
    """写接口：注意三点。

    1. **参数校验**：宁可 400 也不要静默用默认值（静默会让前端以为成功）。
    2. **范围限制**：真实插件里，写操作只能碰"本面板自己的东西"，
       不能碰系统级对象（定时任务、看护器），否则一次误点就能让看护停摆。
    3. **可逆优先**：能"暂停"就不要"删除"。
    """
    body = body or {}
    by = body.get("by", 1)
    if not isinstance(by, int):
        raise HTTPException(status_code=400, detail=f"by 得是整数，收到 {by!r}")

    _STATE["count"] += by
    return {"count": _STATE["count"], "ok": True, "by": by}
