# 对话系统问题记录

## 问题1: 对话框上下移动/叠加向上
**原因**: `DialogueManager._process` 每帧调用 `bubble.follow_screen_position(cx, screen_pos.y)`，NPC移动时bubble跟着上下。多个bubble通过`set_offset_y(-active_count * 70)`错开，每帧active_count变化导致offset跳变。
**修复**: bubble分配时设一次offset，_process只更新xy跟随NPC，不重算offset。NPC不动时bubble不动。

## 问题2: 超过3行仍然全部渲染
**原因**: `_label.fit_content = true` 让label无限撑高，ScrollContainer虽然设了size=MAX_CONTENT_HEIGHT但label的fit_content覆盖了它。`_reflow`里`content_h = minf(row_size.y, MAX_CONTENT_HEIGHT)`但row_size是HBox的minimum_size，不是实际渲染高度。
**修复**: `fit_content = false`。Label固定高度=MAX_CONTENT_HEIGHT。ScrollContainer固定高度=MAX_CONTENT_HEIGHT。内容超出由ScrollContainer裁剪，`scroll_following=true`自动滚到底。每帧`_process`里强制`scroll_vertical = sb.max_value`。

## 问题3: 有的对话框没有icon
**原因**: `_start_utterance`里设`_icon.text = "🗣"`，但如果think为空直接跳到utterance时，icon还是`_build_ui`里的初始值`"🤔"`没被更新。think阶段结束清空text时icon也没同步。
**修复**: `show_entry`开头统一设icon。think阶段=🤔，utterance阶段=🗣。每次`_start_utterance`都设icon。

## 问题4: 有的对话框只有icon没有文字
**原因**: think→utterance切换时`_label.text = ""`清空了文字，但typewriter还没开始打字，这一帧只显示icon。如果typewriter延迟启动就会看到只有icon。
**修复**: 清空文字和启动typewriter之间不能有await。`_end_think_phase`里清空后立刻调`_start_utterance`，typewriter立刻开始。

## 问题5: 文本居中困难
**原因**: RichTextLabel的文本对齐需要用BBCode `<center>` 或设`horizontal_alignment`。当前没设。
**修复**: 不需要插件。`_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT`（左对齐，对话气泡标准）。如果需要居中用`HORIZONTAL_ALIGNMENT_CENTER`。

## 问题6: NPC寻路还是直线移动
**原因**: `_nav_step`用`global_position += new_vel * delta`直接移动。NavigationAgent2D返回的路径是绕墙的，但NPC不做物理碰撞，如果NavigationRegion2D没正确bake（make_polygons_from_outlines已废弃），路径可能就是直线。
**验证**: 检查MapSystem是否用了正确的bake方法。之前改成了`NavigationServer2D.bake_from_source_geometry_data`但可能没正确设outline。
**修复**: 确认NavigationRegion2D正确bake。MapSystem `_build_nav_region_from_collision`需要用`add_traversable_outline`+`bake_from_source_geometry_data`。如果navmesh没bake成功，NPC走直线。

## 问题7: NPC被其他NPC卡住
**原因**: `_separate_from_npcs`用35px半径推开，但如果两个NPC在完全相同位置(dist=0)，push方向是随机的可能推到墙上。而且wander模式下NPC移动后没检查是否穿墙。
**修复**: NPC不做wander（已禁用）。只在被指令时walk_to（NavigationAgent2D绕墙）。`_separate_from_npcs`的推力方向应该是两个NPC之间的方向，不是随机。

## 问题8: think和utterance同时显示
**原因**: 之前版本的bug已修。当前`_end_think_phase`清空`_label.text = ""`后才进utterance。但如果`_seq`不匹配（新的show_entry打断了旧流程），旧流程可能没被正确中断。
**验证**: `_end_think_phase`有`if my_seq != _seq`检查。`_start_utterance`也有。应该没问题。

## 问题9: scrollbar仍然可见
**原因**: 设了`sb.visible = false`和`sb.modulate = Color(0,0,0,0)`和StyleBoxEmpty，但ScrollContainer的`vertical_scroll_mode = SCROLL_MODE_DISABLED`之后不应该有scrollbar。可能是在`_reflow`里重新获取了scrollbar但没隐藏。
**修复**: `_build_ui`里不设`SCROLL_MODE_AUTO`。只设`SCROLL_MODE_DISABLED`。删除`_reflow`里的scrollbar获取代码。如果需要自动滚动，用`_scroll.scroll_vertical = _scroll.get_v_scroll_bar().max_value`在_process里设。

---

# 第二轮 playtest 发现的问题 (2026-07-09)

## 问题10: 对话框超3行仍未修复 ( reopened )
**症状**: 用户报告超3行文字仍然没有被正确裁剪/滚动。
**根因**: `dialogue_bubble.gd:235` `_reflow()` 用 `row.get_combined_minimum_size().y` 测高度——对 `fit_content=true` 的 RichTextLabel，这个值不可靠（需要至少一帧才能让布局刷新，且 HBoxContainer 的 combined minimum size 来自子节点的 minimum size，不是实际渲染高度）。
**之前两次失败的修复**:
1. `fit_content=false` + 固定54px → 1行内容也占54px空白
2. `fit_content=true` + `get_combined_minimum_size()` → 测量值不可靠，3行限制失效
**新修复**: 用 `_label.get_content_height()`（RichTextLabel 的实际渲染高度 API）。`SCROLL_MODE_AUTO` 启用滚动（>3行时滚到底显示最后3行）。scrollbar 通过 `sb.visible=false + modulate=transparent` 隐藏。`_scroll.clip_contents=true` 防御性裁剪。`_process` 每帧 `scroll_vertical = sb.max_value` 自动滚到底。
**状态**: fixed (commit a74d039)

## 问题11: 第二个护士只在第一轮被使用
**症状**: 5个患者，nurse_001 处理了 patient_001/003/004/005，nurse_002 只处理了 patient_002。日志显示后续患者全部 queue 到 staff_nurse_001。
**根因 (3层)**:
1. `scheduler.gd:56` fallback `find_by_role("nurse")` 返回 `matches[0]`（永远是 nurse_001，按注册顺序）
2. `session.gd:45-52` `try_activate()` 对**捕获的特定 resource** 调 `request()`。患者绑到 nurse_001 后即使 nurse_002 空闲也解不开。
3. `scheduler.gd:88-98` `_on_resource_state_changed` 重试同一个绑定 resource，不重新扫描池。
**修复**:
1. `resource_registry.gd:find_by_role` 改为返回**队列最短**的同类 resource（负载均衡）
2. `session.try_activate` 重绑逻辑：如果绑定 resource 忙且存在空闲同类 resource，swap 到空闲的（先 cancel 旧的 queue 位置）
3. `session.gd` 增加 `required_role` 字段（从第一个 resource 推导），让重绑成为可能
**状态**: fixed (commit a74d039)

## 问题12: 绿色患者 (patient_003) 一直卡住
**症状**: patient_003 + doctor_001 进行了 10+ 轮 LLM 来回，session 一直不结束。最后勉强结束。
**根因 (4层)**:
1. `prompt_context.gd:91, 108` doctor prompt 把 `"conversation_done":false` 当格式示例，**没有说明何时翻成 true**
2. `session.gd:206-213` 安全计时器用 `start_turn == _turn_id` 检查——每轮 LLM 调用都让 turn_id 自增，所以计时器永远不触发
3. `interaction_session.gd` 没有最大轮数限制
4. `prompt_context.gd:62-77` 患者 prompt 没有 `conversation_done` 字段——患者无法主动结束对话（设计上由医生决定，但应该明确）
**修复**:
1. doctor + triage_nurse prompt 加显式说明：决定处置方案后设 `conversation_done=true`；最多8轮必须结束
2. `interaction_session._after_display` 加 `MAX_TURNS=8` 硬上限→强制结束，next_role 按当前 goal 决定（triage→doctor，doctor→discharge）
3. `session._start_safety_timer` 改用 wall-clock 自激活起经过的时间（`Time.get_ticks_msec()`），不再用 turn_id 比较。`SAFETY_TIMEOUT` 15s → 30s
**状态**: fixed (commit a74d039)

## 问题13: 结构化输出空 utterances ("utter 1/1: 0 chars")
**症状**: 日志大量 `[Bubble] utter 1/1: 0 chars`，LLM 返回了 `{"utterances": [""]}` 或 `{"responses": [{"utterances": [""]}]}`，气泡显示空内容。
**根因 (3层)**:
1. `npc_fsm.gd:111-119` `_parse_action` JSON 解析成功后直接返回，**不验证 utterance 内容**——空字符串原样通过
2. `session.gd:162-171` `_collect_utterances` 用 `str(utt)` append，空串不被过滤
3. `session.gd:149` `if utterances.is_empty()` 只检查数组长度，`[""]` 不是空数组所以 bypass
**修复**:
1. `npc_fsm._parse_action` 解析后遍历 `responses[].utterances` 和 `utterances`，过滤空/whitespace。如果全空，返回 `["..."]`。新增 `_filter_utterances()` helper
2. `session._collect_utterances` 同样的过滤作为防御
**状态**: fixed (commit a74d039)
