# Backend (Deprecated)

Python LLM 后端已**废弃**。NPC FSM 已用 GDScript 重写，Godot 通过 `HTTPRequest` 直连 Gitee AI。

保留仅作参考。如需使用：

```bash
cd backend
pip install openai pydantic
python -m app.services.backend_server
```

但推荐直接运行 `project.godot` 按 F5，无需任何 Python 环境。
