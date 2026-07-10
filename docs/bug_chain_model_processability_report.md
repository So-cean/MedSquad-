# ED-MAS / MedSquad- 显示重复问题诊断与模型流程评估

## 1. 范围说明

本报告只针对当前本地 `MedSquad-` Godot 客户端仓库的显示重复、请求串台、状态回滚和对话循环问题进行诊断与说明，不修改后端业务逻辑，不引入新的 RAG / LLM / NPC 自动训练链路。

当前仓库路径：

`D:\projects\BME1325Spring2026\BME1325_Group_One_Repo\week13\MedSquad-`

## 2. 现象总结

当前“显示还是会重复”的问题，实际来自三层链路，而不是单一 bug。

### 2.1 请求层重复

文件：

- `scripts/edmas/api_client.gd`

问题：

- 旧实现使用单个 `_pending_endpoint` 保存请求来源。
- 当多个请求连续发出时，后到的请求会覆盖前一个 endpoint。
- 结果是响应有机会被错误地分发到错误的 UI 更新路径，表现成“串台”或“显示顺序不对”。

修复：

- 改为串行请求队列。
- 每个请求都有自己的 `request_id`。
- 回包完成后再处理下一个请求。

### 2.2 状态层重复

文件：

- `scripts/edmas/patient_manager.gd`

问题：

- 旧实现偏向“只增不删”。
- 当 snapshot 切换到新 demo 或 reset 时，旧患者节点可能还留在场景里。
- 这会让用户看到重复患者、重复残影，或者以为同一个病人被重复加载。

修复：

- 用 `patient_sprites` 和 `patient_states` 显式维护患者生命周期。
- 每次 snapshot 到来后，清理本次不再存在的患者。
- 如果位置和状态没有变化，就不重复触发移动。

### 2.3 对话层重复

文件：

- `scripts/dialogue/mock_dialogue_system.gd`

问题：

- 原逻辑在 flow 结束后会自动重启随机 flow。
- 这会导致对话持续循环，形成“重复显示”的视觉效果。

修复：

- 新增 `auto_restart_flows` 开关。
- 默认不自动重启 flow。
- flow 结束后保持停止，等待手动触发。

## 3. 模型完备性评估

这里的“模型完备性”不是指真实临床系统，而是指这个项目作为一个可运行的互动 demo，是否具备完整的输入-状态-输出闭环。

### 3.1 输入侧

目前已经具备：

- Demo 加载
- snapshot 拉取
- step 推进
- reset 重置
- user_turn 入口

评价：

- 输入侧是“可用的”，但还不是“临床完全体”。
- 目前更像是一个流程演示器，而不是包含全部医嘱、设备调度和床位控制的完整系统。

### 3.2 状态侧

目前已经具备：

- patient_id
- location
- state
- backend_status
- active_patient_id
- patient_sprites
- patient_states

评价：

- 状态侧已经从“单一变量”升级成“可追踪状态集合”。
- 但仍然缺少更细粒度的临床状态，例如设备 orders、床位调度、碰撞避让和多患者并发策略。

### 3.3 输出侧

目前已经具备：

- 地图显示
- 患者 sprite
- 状态标签
- 对话显示

评价：

- 输出侧已经可以构成一个可观察闭环。
- 但输出还主要是“状态可视化”，不是完整临床决策结果的最终呈现。

### 3.4 完备性结论

当前项目属于：

- **可运行的流程化 demo**
- **部分完整的状态机可视化系统**
- **不是完整临床 multi-agent 仿真体**

## 4. 流程性评估

这里的“流程性”指数据从 API 到 UI，再到患者和对话呈现的链路是否清晰、稳定、可回放。

### 4.1 当前流程链

1. `api_client.gd` 发送请求
2. 后端返回 `snapshot`
3. `main_edmas.gd` 接收 snapshot
4. `patient_manager.gd` 创建 / 更新 / 清理患者
5. `hospital_map_manager.gd` 切换地图
6. `patient_sprite.gd` 执行移动
7. `dialogue_manager.gd` / `mock_dialogue_system.gd` 更新对话
8. UI 标签显示当前状态

### 4.2 之前的流程问题

- 请求层没有串行保护，响应可能错位。
- 状态层没有清理旧患者，导致残留重复。
- 对话层自动循环，导致视觉重复。

### 4.3 当前流程性结论

修复后，流程已经更接近：

- **输入 -> 请求队列 -> snapshot -> 状态更新 -> 可视化输出**

这意味着项目更适合后续接真实 API，而不是继续在 UI 层堆补丁。

## 5. 本次修复内容

### 5.1 请求层

- `scripts/edmas/api_client.gd`
- 改为串行请求队列
- 每个请求带序号日志
- 避免 endpoint 覆盖

### 5.2 患者层

- `scripts/edmas/patient_manager.gd`
- 新增患者字典和状态字典
- snapshot 切换时清理 stale patient
- 相同位置不重复触发移动

### 5.3 对话层

- `scripts/dialogue/mock_dialogue_system.gd`
- 默认关闭自动重启 flow
- 避免对话无限循环造成重复显示

### 5.4 UI 层

- `scripts/edmas/main_edmas.gd`
- 增加 active patient 的解析逻辑
- 避免 UI 一直显示已过期的第一个患者

## 6. 测试结果

本地验证结果：

- `python -m pytest tests\\godot -q`
- 结果：`13 passed`

补充静态验证：

- `python -m pytest tests\\godot\\test_request_order_stabilization.py -q`
- 结果：`2 passed`

## 7. 当前仍然缺失的能力

这些不是这次要修的重点，但它们决定了系统还不是“完整临床模型”：

- 设备 orders 的正式调度
- 多患者并发下的碰撞避免
- 更精细的队列优先级
- 真实后端联通后的时序一致性检查
- 更完整的临床路径闭环

## 8. 结论

当前项目已经不是“随便能点一下的 demo”，而是一个具备明确流程链路的可运行可视化系统。

但它仍然不是完整临床仿真模型。

它最准确的定位是：

**流程可运行，状态可追踪，视觉可回放，但临床完备性仍在补齐中。**

