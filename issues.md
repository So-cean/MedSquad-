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
