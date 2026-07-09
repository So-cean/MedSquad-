# MedSquad 角色设定文档

> 基于 3 层楼场景房间 + 现有 11 种 NPC 素材 + 玩家角色。每个角色包含身份、视觉素材、所在房间、对话能力、行为模式。

---

## 一、角色总览

| # | 角色 | 显示名 | 颜色语义 | 楼层 | 房间 | LLM 对话 | 帧目录 |
|---|---|---|---|---|---|---|---|
| 0 | 玩家医生 | 医生白 | 白大褂 | F1 | 全图游走 | ❌ 仅观察 | `assets/doctor_frames/` |
| 1 | 分诊护士 | 李分诊/王分诊 | 白 | F1 | TRIAGE 分诊台 | ✅ triage_nurse | `assets/nurse_frames/` |
| 2 | 急救护士 | 急救护士 | 蓝 | F1 | ED_RESUS 抢救室 | ❌ 注册为 nurse | `assets/nurse_blue_frames/` |
| 3 | 急诊医生红 | 急诊医生红 | 红 | F1 | ED_RESUS 抢救室 | ✅ doctor | `assets/doctor_red_frames/` |
| 4 | 急诊医生绿 | 急诊医生绿 | 绿 | F1 | DOCTOR 诊室 | ✅ doctor | `assets/doctor_green_frames/` |
| 5 | 手术医生 | 手术医生 | 绿手术服 | F2 | 手术/诊室区 | ✅ doctor | `assets/scrubs_green_frames/` |
| 6 | 检验科护士 | 检验科护士 | 蓝手术服 | F2 | LAB 检验科 | ❌ 注册为 nurse | `assets/scrubs_blue_frames/` |
| 7 | 检验员蓝 | 检验员蓝 | 蓝 | F2 | LAB 检验科 | ❌ 无 prompt | `assets/labrad_blue_frames/` |
| 8 | 住院护士 | 住院护士 | 绿 | F3 | WARD 病房 | ❌ 注册为 nurse | `assets/nurse_green_frames/` |
| 9 | 质控员灰 | 质控员灰 | 灰 | F3 | DISCHARGE_ADMIN 出院处 | ❌ 无 prompt | `assets/qa_gray_frames/` |
| 10 | 患者绿 | 患者 | 绿衣 | F1 | spawn@入口→排队→诊室 | ✅ patient | `assets/patient_green_frames/` |
| 11 | 患者蓝 | 患者 | 蓝衣 | F1 | spawn@入口→排队→诊室 | ✅ patient | `assets/patient_blue_frames/` |

**统计**：1 玩家 + 4 护士 + 3 医生 + 2 辅助岗 + 2 患者外观 = 12 个角色实体类型

**LLM 对话能力**：5 种有 prompt（分诊护士/急诊医生红/急诊医生绿/手术医生/患者），其余暂为静态或仅注册角色。

---

## 二、玩家角色

### 医生白（玩家操控）

| 属性 | 值 |
|---|---|
| 身份 | 玩家操控的医生角色（白大褂） |
| 显示名 | 医生白（不显示在 hover 卡，因为玩家就是自己） |
| 楼层 | F1 ED Core，全图可游走 |
| 帧目录 | `assets/doctor_frames/`（预切好的 32×32 PNG） |
| 帧格式 | 特殊：不使用 8 方向表，用独立帧 down_idle + down_walk_a/b/c + up_walk_a/b + side_idle + side_walk_r/l |
| 源素材 | `character/doctor.png` (128×128 3×3 含 8px padding) + `character/doctor walk.png` + `character/doctor white idle.png` (32×32 正面 idle) |
| 脚本 | `scripts/player.gd` (extends CharacterBody2D) |
| 移动 | WASD 键盘 / 虚拟摇杆（移动端） |
| 相机 | Camera2D zoom 0.6，鼠标滚轮缩放，中键拖拽 |
| 碰撞 | layer=2, mask=3（与墙+其他角色碰撞） |
| 对话 | 不参与 LLM 对话流程，是观察者 |
| 交互 | 走近 NPC 50px 内触发 InteractionZone，显示"按 E" |

**设计意图**：玩家是院内的"游走观察者"，可以走到任何对话现场看气泡、hover 任何 NPC 查状态，但不直接参与 NPC 之间的自主对话。后续策划可定义玩家介入方式。

---

## 三、护士角色（4 种）

### 1. 分诊护士（Nurse White）

| 属性 | 值 |
|---|---|
| 身份 | 急诊分诊台护士，患者入院第一道关 |
| 颜色 | 白色护士服 |
| 显示名 | 李分诊 / 王分诊（ScenarioConfig 默认 2 个，按注册顺序命名） |
| 楼层 | F1 ED Core |
| 房间 | TRIAGE 分诊台 (830, 470) |
| 帧目录 | `assets/nurse_frames/` |
| 源素材 | `character/nurse white.png` (32×32 正面 idle) + `character/nurse white idle 8dir.png` (96×96) + `character/nurse white walk 8dir.png` (96×96) |
| 帧格式 | 8 方向 idle+walk，idle_down 用独立正面帧 |
| walk_flip | `[]`（普通 idle→walk_a 两帧循环） |
| 脚本 | `map_npc.gd` + @export |
| LLM 角色 | `triage_nurse` ✅ |
| Prompt 要点 | 不能读隐藏病例；开放式问诊；3-5 轮决定 next_step（doctor/discharge）；症状严重→ED_RESUS，轻症→DOCTOR 或出院 |
| 行为 | 默认静止站分诊台；被 Scheduler 派给患者时面对面接诊；最多 8 轮对话；结束即释放给下一个排队患者 |
| 资源注册 | `staff_nurse_001` / `staff_nurse_002`，role=nurse，ResourceRegistry 排队调度 |

### 2. 急救护士（Nurse Blue）

| 属性 | 值 |
|---|---|
| 身份 | 抢救室急救护士，处理危重患者 |
| 颜色 | 蓝色护士服 |
| 显示名 | 急救护士 |
| 楼层 | F1 ED Core |
| 房间 | ED_RESUS 抢救室 (340, 200) |
| 帧目录 | `assets/nurse_blue_frames/` |
| 源素材 | `character/nurse blue.png` + `character/nurse blue idle 8dir.png` + `character/nurse blue walk 8dir.png` |
| 帧格式 | 8 方向 idle+walk，同分诊护士 |
| walk_flip | `[]` |
| 脚本 | `map_npc.gd` + @export |
| LLM 角色 | 注册为 `nurse`，但 **无独立 prompt**（PromptContext 未实现 emergency_nurse） |
| 行为 | 静态站位，Floor_ED_Core 场景里出现在抢救室；目前不参与对话流程 |
| 备注 | 策划可设计：危重患者送抢救室后由急救护士先行处置（接氧、监护），再等医生 |

### 3. 住院护士（Nurse Green）

| 属性 | 值 |
|---|---|
| 身份 | 病房住院护士，负责转归/留观/出院环节 |
| 颜色 | 绿色护士服 |
| 显示名 | 住院护士 |
| 楼层 | F3 Downstream |
| 房间 | WARD 病房区附近 (800, 550) |
| 帧目录 | `assets/nurse_green_frames/` |
| 源素材 | `character/nurse green.png` + `character/nurse green idle 8dir.png` + `character/nurse green walk 8dir.png` |
| 帧格式 | 8 方向 idle+walk，idle/walk 不同姿态 |
| walk_flip | `[]` |
| 脚本 | `map_npc.gd` + @export |
| LLM 角色 | 注册为 `nurse`，**无独立 prompt** |
| 行为 | 静态站位在病房区；F3 当前不在主 playtest 场景，切楼层才可见 |

### 4. 检验科护士（Scrubs Blue）

| 属性 | 值 |
|---|---|
| 身份 | 检验科护士，负责抽血/样本处理/报告 |
| 颜色 | 蓝色手术服 |
| 显示名 | 检验科护士 |
| 楼层 | F2 Diagnostics |
| 房间 | LAB 检验科 (720, 550) |
| 帧目录 | `assets/scrubs_blue_frames/` |
| 源素材 | `character/scrubs blue.png` + `character/scrubs blue idle 8dir.png` + `character/scrubs blue walk 8dir.png` |
| 帧格式 | 8 方向 idle+walk |
| walk_flip | `[]` |
| 脚本 | `map_npc.gd` + @export |
| LLM 角色 | 注册为 `nurse`，**无独立 prompt** |
| 行为 | 静态站位在检验科；F2 当前不在主 playtest 场景 |

---

## 四、医生角色（3 种）

### 1. 急诊医生红（Doctor Red）

| 属性 | 值 |
|---|---|
| 身份 | 抢救室急诊医生，处理危重/红色病例 |
| 颜色 | 红色（紧急/抢救语义） |
| 显示名 | 急诊医生红 |
| 楼层 | F1 ED Core |
| 房间 | ED_RESUS 抢救室 (440, 220)，在急救护士(340,200)右侧 |
| 帧目录 | `assets/doctor_red_frames/` |
| 源素材 | `character/doctor red.png` + `character/doctor red idle 8dir.png` + `character/doctor red walk 8dir.png` |
| 帧格式 | 8 方向 idle+walk |
| walk_flip | `[]` |
| 脚本 | `map_npc.gd` + @export |
| LLM 角色 | `doctor` ✅ |
| Prompt 要点 | 不能读隐藏病例；根据口述+分诊记录决策；3-5 轮完成；orders 白名单 ct_scan/lab_test/ecg；可下 discharge |
| 行为 | 静态站位抢救室；DialogueTest.tscn 里已放置，主 playtest 可见 |
| 备注 | 红色 = 抢救/最高优先级，符合急诊分诊色彩语义（红黄绿黑四级） |

### 2. 急诊医生绿（Doctor Green）

| 属性 | 值 |
|---|---|
| 身份 | 诊室急诊医生，处理普通急诊病例 |
| 颜色 | 绿色（普通/可等待语义） |
| 显示名 | 急诊医生绿 |
| 楼层 | F1 ED Core |
| 房间 | DOCTOR 诊室 (1230, 500)，在原有张医生(1330,500)左侧 |
| 帧目录 | `assets/doctor_green_frames/` |
| 源素材 | `character/doctor green.png` + `character/doctor green idle 8dir.png` + `character/doctor green walk 8dir.png` |
| 帧格式 | 8 方向 idle+walk |
| walk_flip | `[]` |
| 脚本 | `map_npc.gd` + @export |
| LLM 角色 | `doctor` ✅ |
| 行为 | 静态站位诊室；DialogueTest.tscn 里已放置，主 playtest 可见 |
| 备注 | 注意与"手术医生(scrubs_green)"区分：手术医生在 F2，绿色手术服；急诊医生绿在 F1，绿色医生服 |

### 3. 手术医生（Scrubs Green）

| 属性 | 值 |
|---|---|
| 身份 | 手术/外科医生，F2 诊室区接诊 |
| 颜色 | 绿色手术服 |
| 显示名 | 手术医生 |
| 楼层 | F2 Diagnostics |
| 房间 | 诊室区 (800, 450) |
| 帧目录 | `assets/scrubs_green_frames/` |
| 源素材 | `character/scrubs green.png` + `character/scrubs green idle 8dir.png` + `character/scrubs green walk 8dir.png` |
| 帧格式 | 8 方向 idle+walk |
| walk_flip | `[]` |
| 脚本 | `map_npc.gd` + @export |
| LLM 角色 | `doctor` ✅（与急诊医生共用 prompt） |
| 行为 | 静态站位 F2 诊室；F2 当前不在主 playtest 场景 |
| 备注 | ScenarioConfig.DOCTOR_FRAMES 默认用 scrubs_green_frames，运行时 spawn 的 doctor_001/002 用这个外观 |

---

## 五、辅助岗角色（2 种，无 LLM prompt）

### 1. 检验员蓝（Labrad Blue）

| 属性 | 值 |
|---|---|
| 身份 | 检验科技术员，操作化验仪/出报告 |
| 颜色 | 蓝色（与检验科护士同色系，区分身份用"检验员"而非"护士"） |
| 显示名 | 检验员蓝 |
| 楼层 | F2 Diagnostics |
| 房间 | LAB 检验科 (620, 550)，在检验科护士(720,550)左侧 |
| 帧目录 | `assets/labrad_blue_frames/` |
| 源素材 | `character/labrad blue.png` + `character/labrad blue idle 8dir.png` + `character/labrad blue walk 8dir.png` |
| 帧格式 | 8 方向 idle+walk |
| walk_flip | `[]` |
| 脚本 | `map_npc.gd` + @export |
| LLM 角色 | `technician` ❌（PromptContext 未实现 technician prompt） |
| 行为 | 纯静态站位；不参与对话；目前是环境 NPC |
| 策划待定 | 是否给 technician 写 prompt？抽血时说什么？出报告时通知谁？ |

### 2. 质控员灰（QA Gray）

| 属性 | 值 |
|---|---|
| 身份 | 医疗质控员，抽审病例/出院质量/流程合规 |
| 颜色 | 灰色（中立/监督语义） |
| 显示名 | 质控员灰 |
| 楼层 | F3 Downstream |
| 房间 | DISCHARGE_ADMIN 出院管理处 (900, 550)，在住院护士(800,550)右侧 |
| 帧目录 | `assets/qa_gray_frames/` |
| 源素材 | `character/qa gray.png` + `character/qa gray idle 8dir.png` + `character/qa gray walk 8dir.png` |
| 帧格式 | 8 方向 idle+walk |
| walk_flip | `[]` |
| 脚本 | `map_npc.gd` + @export |
| LLM 角色 | `qa` ❌（PromptContext 未实现 qa prompt） |
| 行为 | 纯静态站位；不参与对话；目前是环境 NPC |
| 策划待定 | QA 是不是要主动找医护谈话？抽审比例？发现问题如何干预？ |

---

## 六、患者角色（2 种外观）

### 1. 患者绿（Patient Green）

| 属性 | 值 |
|---|---|
| 身份 | 急诊患者（绿色便服） |
| 颜色 | 绿色便服 |
| 显示名 | 患者（统一名，用 npc_id 区分 patient_001/002/...） |
| 楼层 | F1 ED Core，spawn @ ED_ENTRANCE (830, 800) |
| 帧目录 | `assets/patient_green_frames/` |
| 源素材 | `character/patient green.png` + `character/patient green idle 8dir.png` + `character/patient green walk 8dir.png` |
| 帧格式 | 8 方向 idle+walk，**特殊：up/down 方向用 walk_a→walk_b 交替**（两腿前后迈步），其他方向用 idle→walk_a |
| walk_flip | `["up", "down"]` |
| 脚本 | `map_npc.gd` + @export |
| LLM 角色 | `patient` ✅ |
| Prompt 要点 | 大白话描述症状，不背医学术语；只回答被问的问题；第一次开口主动描述主诉+持续时间；后续被问什么答什么 |
| 行为 | spawn 在入口→被 Scheduler 派去排队（TRIAGE 附近 50px 间距）→被护士接诊面对面→分诊完 walk_to 诊室/抢救室→被医生接诊→出院 walk_to ED_ENTRANCE→消失 |
| 状态机 | ARRIVED → WAITING → GOING_TO_ROOM → BEING_EXAMINED → DISCHARGED |
| 隐藏病例 | ScenarioConfig.patient_pool 预设 5 个：头痛/腹痛/胸痛/外伤/发热，每个有主诉+症状+持续时间。**只对患者自己的 LLM prompt 可见，医护看不到** |

### 2. 患者蓝（Patient Blue）

| 属性 | 值 |
|---|---|
| 身份 | 急诊患者（蓝色便服），与患者绿仅外观不同 |
| 颜色 | 蓝色便服 |
| 显示名 | 患者 |
| 楼层 | F1 ED Core，spawn @ ED_ENTRANCE |
| 帧目录 | `assets/patient_blue_frames/` |
| 源素材 | `character/patient blue.png` + `character/patient blue idle 8dir.png` + `character/patient blue walk 8dir.png` |
| 帧格式 | 同患者绿，up/down 用 walk_a→walk_b |
| walk_flip | `["up", "down"]` |
| 脚本 | `map_npc.gd` + @export |
| LLM 角色 | `patient` ✅ |
| 行为 | 同患者绿 |
| 备注 | 两种患者外观纯视觉区分，行为/流程/prompt 完全相同。可批量 spawn 不同外观的患者增加视觉多样性 |

---

## 七、角色-房间映射矩阵

### F1 ED Core（急诊核心接入区）— 主 playtest 场景

| 房间/位置 | 坐标 | 驻守角色 | 流经角色 |
|---|---|---|---|
| ED_ENTRANCE 入口 | (830, 800) | — | 患者 spawn + 出院走这里 |
| TRIAGE 分诊台 | (830, 470) | 分诊护士×2 (830+930,470) | 所有患者排队经过 |
| WAITING_AREA 候诊区 | (340, 590) | — | 排队溢出的患者 |
| DOCTOR 诊室 | (1330, 500) | 急诊医生绿 (1230,500) + 张医生(运行时 spawn @1330,500) | 分诊后轻症/中症患者 |
| ED_RESUS 抢救室 | (340, 200) | 急救护士 (340,200) + 急诊医生红 (440,220) + 赵医生(运行时 spawn @340,200) | 分诊后危重症患者 |
| ELEVATOR_ED 电梯 | (840, 120) | — | 切楼层用（未接玩家交互） |

### F2 Diagnostics（检查诊断区）— 切楼层可见

| 房间/位置 | 坐标 | 驻守角色 | 流经角色 |
|---|---|---|---|
| LAB 检验科 | (350, 270) [HospitalMapData] / (220, 240) [Floor marker] | 检验科护士 (720,550) + 检验员蓝 (620,550) | 待设计的检查流程患者 |
| IMAGING 影像 | (1280, 250) | — | 待设计的 CT/影像检查患者 |
| DIAGNOSTIC_WAITING 候检 | (290, 680) | — | 待设计的候检患者 |
| RESULT_REVIEW 报告审阅 | (1290, 680) | — | 待设计 |
| 诊室区 | (800, 450) | 手术医生 (800,450) | — |
| ELEVATOR_DIAGNOSTICS | (840, 120) | — | 切楼层用 |

### F3 Downstream（转归下游区）— 切楼层可见

| 房间/位置 | 坐标 | 驻守角色 | 流经角色 |
|---|---|---|---|
| ICU 重症监护 | (340, 230) | — | 待设计的危重转归患者 |
| WARD 病房 | (1290, 260) | 住院护士 (800,550) [Floor scene] | 待设计的住院患者 |
| DISPOSITION 处置 | (830, 550) | — | 待设计 |
| ED_BOARDING 留观 | (340, 700) | — | 待设计 |
| DISCHARGE 出院口 | (830, 825) | — | 待设计的出院患者 |
| DISCHARGE_ADMIN 出院管理 | (1270, 770) | 质控员灰 (900,550) [Floor scene] | 待设计 |
| ELEVATOR_DOWNSTREAM | (840, 120) | — | 切楼层用 |

> **注**：Floor 场景的 Marker 坐标与 HospitalMapData 的命名位置坐标有出入（Floor scene 是早期手动放的，HospitalMapData 是运行时寻路用的）。策划设计流程时以 HospitalMapData 坐标为准。

---

## 八、素材清单

### 角色源素材（`character/` 目录）

| 源 PNG | 尺寸 | 用途 |
|---|---|---|
| `doctor.png` | 128×128 | 玩家医生源表（3×3 含 8px padding） |
| `doctor walk.png` | — | 玩家医生走帧源 |
| `doctor white idle.png` | 32×32 | 玩家医生正面 idle |
| `nurse white.png` + `nurse white {idle,walk} 8dir.png` | 32 + 96×96×2 | 分诊护士 |
| `nurse blue.png` + `nurse blue {idle,walk} 8dir.png` | 32 + 96×96×2 | 急救护士 |
| `nurse green.png` + `nurse green {idle,walk} 8dir.png` | 32 + 96×96×2 | 住院护士 |
| `scrubs green.png` + `scrubs green {idle,walk} 8dir.png` | 32 + 96×96×2 | 手术医生 |
| `scrubs blue.png` + `scrubs blue {idle,walk} 8dir.png` | 32 + 96×96×2 | 检验科护士 |
| `doctor red.png` + `doctor red {idle,walk} 8dir.png` | 32 + 96×96×2 | 急诊医生红 |
| `doctor green.png` + `doctor green {idle,walk} 8dir.png` | 32 + 96×96×2 | 急诊医生绿 |
| `labrad blue.png` + `labrad blue {idle,walk} 8dir.png` | 32 + 96×96×2 | 检验员蓝 |
| `qa gray.png` + `qa gray {idle,walk} 8dir.png` | 32 + 96×96×2 | 质控员灰 |
| `patient green.png` + `patient green {idle,walk} 8dir.png` | 32 + 96×96×2 | 患者绿 |
| `patient blue.png` + `patient blue {idle,walk} 8dir.png` | 32 + 96×96×2 | 患者蓝 |

### 切片帧目录（`assets/` 目录）

每个 NPC 帧目录 16 个 PNG（除玩家特殊）：
- `idle_down.png` — 来自独立 32×32 源（正面 idle 高质量帧）
- `idle_up.png` / `idle_up_left.png` / `idle_up_right.png` / `idle_left.png` / `idle_right.png` / `idle_down_left.png` / `idle_down_right.png` — 7 个从 96×96 idle 表切片（跳过 center 和 down）
- `walk_{方向}_a.png` × 8 — 从 96×96 walk 表切片（全部 8 方向）

患者额外有 `walk_up_b.png` + `walk_down_b.png`（用于 up/down 翻转两帧交替）。

切片脚本：`tools/slice_npc_sheets.py`（可复用于未来新 NPC）。

### 网格映射（96×96 8 方向表 → 32×32 帧）

```
[up_left] [up]        [up_right]      ← 行0 = 背面/上方视角
[left]    [空]        [right]         ← 行1 = 侧面
[down_left] [down]    [down_right]    ← 行2 = 正面/下方视角
```

`idle_down.png` 不从表切，用独立 32×32 源（正面 idle 帧质量更好）。

---

## 九、角色行为通用规则

### 移动
- **默认静止**：所有 NPC `can_wander=false`，不自由移动
- **被指令时移动**：`walk_to(location)` / `walk_to_pos(pos)` 用 NavigationAgent2D 绕墙寻路
- **软碰撞**：NPC 之间 35px 半径软推开，不依赖物理体
- **面对面**：`approach_and_face(target, offset)` 走近后自动转向对方
- **delta**：`_physics_process` 用 `get_physics_process_delta_time()`，协程里用 `Time.get_ticks_msec()`

### 对话
- **回合制**：医护说一句 → 患者回一句 → 循环
- **医护先开口**：开放式问诊（"您好，哪里不舒服？"）
- **think + utterance 双阶段**：先显示蓝色内心独白（可选），清空后显示黑色说出口的话
- **打字机**：0.06 秒/字
- **气泡**：1-3 行自适应，超 3 行滚到底，无滚动条，跟随 NPC 头顶
- **最大轮数**：8 轮强制结束
- **超时**：30 秒无进展强制 discharge
- **空 utterance 过滤**：LLM 返回空串自动替换 "..."

### 记忆
- **per-NPC JSON**：`user://npc_memories/{node_name}/nodes.json`
- **按伙伴检索**：`get_context_for_partner(partner_id, count)` 只取和特定对象的对话
- **跨 NPC 路由**：A 说话 → 同时写入 A 和 B 的记忆；B 回应 → 同时写入 B 和 A 的记忆
- **持久化**：磁盘存储，但 NPC spawn 时 `clear()` 重置

### 状态机（患者）
```
ARRIVED (刚到) → WAITING (排队等护士) → GOING_TO_ROOM (走去诊室)
  → BEING_EXAMINED (被接诊) → DISCHARGED (出院)
```

### 资源调度
- **ResourceRegistry** 注册护士/医生为 `staff_{npc_id}`，role=nurse/doctor
- **FIFO 排队** + **最短队列负载均衡**：新患者优先分给空闲护士，全忙时分给队列最短的
- **重绑机制**：绑定 nurse 忙且另一护士空闲时，自动 swap
- **设备/房间**：已注册 6 个静态资源（room_triage/resus/doctor + device_ct/lab/ecg），但未接入流程

---

## 十、扩展建议（待策划）

### 缺失 prompt 的角色
- **急救护士**（nurse_blue）：抢救室处置 prompt？还是共用 triage_nurse？
- **住院护士**（nurse_green）：病房交接/出院指导 prompt？
- **检验科护士**（scrubs_blue）：抽血/出报告 prompt？
- **检验员蓝**（labrad_blue）：technician 角色 prompt
- **质控员灰**（qa_gray）：qa 角色 prompt

### 缺失流程环节
- **检查环节**：分诊→检查（CT/lab）→回诊室看结果→处置。需要 InteractionSession 支持 device 资源
- **转归环节**：处置→ICU/病房/留观/出院。需要 F3 流程接入
- **多往返**：患者检查完回诊室，医生看结果再决定

### 角色关系（Smallville 风格）
- 医护同事关系（影响协作语气？）
- 患者之间交流（候诊区闲聊？）
- 师徒关系（实习医生跟诊？）

### 日程/换班
- 早班/夜班 NPC 轮换
- 交接班时记忆传递？

---

## 附：角色色彩语义参考（急诊分诊四级）

| 级别 | 颜色 | 含义 | 对应角色 |
|---|---|---|---|
| 1 级 | 红 | 危重/抢救 | 急诊医生红、急救护士（蓝）、ED_RESUS 抢救室 |
| 2 级 | 黄 | 急诊/优先 | （暂无黄色角色，可后续加） |
| 3 级 | 绿 | 急症/可等待 | 急诊医生绿、手术医生、住院护士、患者绿 |
| 4 级 | 黑/灰 | 普通可出院 | 质控员灰 |
| — | 白 | 分诊/中立 | 分诊护士、玩家医生 |
| — | 蓝 | 检验/辅助 | 检验科护士、检验员蓝、患者蓝 |

> 当前角色色彩并非严格按四级分诊分配，但有意识地用红=抢救、绿=普通、灰=监督、白=分诊的语义。策划可据此设计新角色的色彩归属。
