# ED-MAS Godot 地图协议 v1

> 文件名：`map_propocal.md`  
> 项目：参赛版多智能体模拟医院 MAS / ED-MAS Godot 前端地图系统  
> 用途：定义三张医院地图的功能定位、分区命名、Godot Marker 绑定、跨地图切换方式、推荐演示路径与前端实现边界。  
> 当前版本：v1.0  
> 语言：中文  

---

## 0. 一句话定义

ED-MAS Godot 地图不是传统 RPG 场景，而是**多智能体医院流程状态机的可视化界面**。三张地图分别对应急诊接入、检查诊断、转归下游三个流程层。患者位置由后端 `location` 字段驱动，Godot 只负责地图切换、Marker 移动和 UI 展示。

核心链路：

```text
后端状态机 / Agent 决策
→ API 返回 patient.location / patient.state
→ Godot 判断 location 属于哪张地图
→ Godot 找到对应 Marker2D
→ PatientSprite 移动到 Marker
→ 跨地图时通过电梯 / fade transition 切换地图
```

---

## 1. 项目总目标

当前项目是一个面向比赛 Demo 的多智能体模拟医院系统。后端负责患者流程推进，Godot 前端负责用像素风医院地图展示患者在不同科室之间的移动和状态变化。

### 1.1 后端负责什么

后端负责：

```text
1. 患者状态机
2. 急诊分诊 triage
3. 医生问诊 doctor consultation
4. Lab / Imaging 检查医嘱
5. 检查结果返回
6. 转归决策 disposition
7. ICU / Ward / ED Boarding / Discharge 资源分配
8. Demo A / B / C 回放
9. /api/godot/snapshot
10. /api/godot/step
11. /api/godot/demo/load
```

### 1.2 Godot 前端负责什么

Godot 前端负责：

```text
1. 显示三张医院地图
2. 显示患者 sprite
3. 根据后端 location 移动患者
4. 根据后端 state 更新 UI 面板
5. 展示事件日志、模型调用日志、患者信息卡片
6. 支持 Demo A / B / C 的可视化演示
```

Godot 不负责：

```text
1. 不决定患者下一站
2. 不做医学诊断
3. 不执行真实临床规则
4. 不做复杂门交互
5. 不做复杂 RPG 寻路
6. 不自己写死 demo trace
```

---

## 2. 当前阶段的地图生成目标

当前阶段的工作重点是生成和稳定三张 Godot 可用的地图背景图。地图需要具备明确功能分区，并为后续 Marker2D 放置和患者移动预留空间。

### 2.1 三张地图是比赛刚需

三张地图是当前参赛版 MAS Demo 的必要前端资产：

```text
Map 1：急诊核心接入区 / ED Core Map
Map 2：检查诊断区 / Diagnostics Map
Map 3：转归与下游资源区 / Downstream Map
```

它们可以被理解为三个具体场景，也可以暂时表现为不同楼层。跨地图移动可以用电梯作为视觉表达。

### 2.2 电梯逻辑当前状态

当前对电梯的定义是：

```text
电梯 = 跨地图切换视觉点
```

第一版可以暂时不做真实电梯交互。实现上有两种方案：

#### 方案 A：直接切图

```text
后端 location 发生跨地图变化
→ 当前地图 fade out
→ 目标地图 fade in
→ 患者出现在目标 Marker
```

#### 方案 B：先走到电梯，再切图

```text
后端 location 发生跨地图变化
→ 患者先移动到当前地图 Elevator Marker
→ fade out
→ 切换到目标地图
→ 患者出现在目标地图 Elevator Marker 或目标科室 Marker
```

当前建议：**先采用方案 A，后续如时间允许再加入方案 B。**

---

## 3. 统一地图交互原则

### 3.1 科室入口原则

科室入口不设计为可交互门。

```text
不做 Door.gd
不做 open_door()
不做 close_door()
不做门碰撞
不做门动画
不要求玩家点击门
```

科室入口应尽量表现为：

```text
开放式门洞
墙体缺口
连续地砖
无门扇
无阻挡感
```

原因：当前项目要展示的是**后端状态驱动的患者流转**，不是医院 RPG 的空间交互。

### 3.2 跨地图入口原则

跨地图入口统一表现为电梯或楼层切换点。

```text
电梯只负责视觉语义
电梯不负责临床逻辑
电梯不决定患者去哪
电梯不做复杂交互
```

### 3.3 移动原则

患者移动采用 Marker-to-Marker 的简化方案：

```text
后端 location
→ LOCATION_TO_MAP
→ LOCATION_TO_MARKER
→ PatientSprite.move_to(marker_position)
```

第一版不使用复杂 `NavigationAgent2D`，不做碰撞避障。

---

## 4. 三张地图总体关系

```text
Map 1：ED Core Map
急诊入口 → 分诊 → 候诊 → 医生问诊 → 抢救 / 去检查 / 去转归

Map 2：Diagnostics Map
检查等待 → Lab / Imaging → 结果复核 → 回医生 / 去转归

Map 3：Downstream Map
转归决策 → ICU / Ward / ED Boarding / Discharge
```

三张地图不需要完全等同于真实医院楼层，更准确地说是三个流程层：

```text
流程层 1：急诊接入层
流程层 2：检查诊断层
流程层 3：转归下游层
```

---

# 5. Map 1：急诊核心接入区

## 5.1 基本定义

```text
地图文件名：map1_v1.png
地图 ID：MAP_ED_CORE
中文名：急诊核心接入区
英文名：ED Core Map
推荐理解：医院一层 / 急诊前线流程层
```

## 5.2 主要功能

Map 1 负责患者进入急诊后的前线流程：

```text
ED_ENTRANCE
→ TRIAGE
→ WAITING_AREA
→ DOCTOR
→ ED_RESUS / LAB / IMAGING / DISPOSITION
```

---

## 5.3 Map 1 分区定义

### 5.3.1 ED Entrance / 急诊入口

```text
位置：底部中央入口区域
中文名：急诊入口
英文名：ED Entrance
推荐 Marker：Marker_ED_Entrance
后端 location：ED_ENTRANCE
```

功能：

```text
1. 患者生成点
2. Demo 起点
3. User Mode 患者进入点
4. 急诊流程第一站
```

推荐场景：

```text
患者从急诊入口出现，进入分诊台。
```

推荐 UI / 对话：

```text
Patient arrived at ED.
患者已到达急诊入口。
```

---

### 5.3.2 Triage Desk / 分诊台

```text
位置：地图中央接待台 / 分诊台
中文名：分诊台
英文名：Triage Desk
推荐 Marker：Marker_Triage
后端 location：TRIAGE
```

功能：

```text
1. 完成初步分诊
2. 评估患者优先级
3. 给出 triage level
4. 决定患者进入候诊、医生区或抢救区
```

推荐状态：

```text
TRIAGE_WAITING
TRIAGE_PROCESSING
TRIAGE_DONE
```

推荐场景：

```text
患者移动到分诊台，右侧 UI 显示 triage_level。
```

推荐 UI / 对话：

```text
Triage completed: Level 2.
分诊完成：L2，高优先级。
```

---

### 5.3.3 Waiting Area / 候诊区

```text
位置：左下候诊椅区域
中文名：候诊区
英文名：Waiting Area
推荐 Marker：Marker_Waiting
后端 location：WAITING_AREA
```

功能：

```text
1. 普通患者等待医生首次接触
2. 展示排队队列
3. 展示急诊拥堵
4. 支持多患者可视化
```

推荐状态：

```text
WAITING_FOR_DOCTOR
```

推荐场景：

```text
多个患者 sprite 可排在候诊区，显示等待人数。
```

推荐 UI / 对话：

```text
Waiting for doctor first contact.
患者正在等待医生首次接触。
```

---

### 5.3.4 Doctor Consultation / 医生问诊区

```text
位置：右侧医生桌、电脑、诊疗床区域
中文名：医生问诊区
英文名：Doctor Consultation
推荐 Marker：Marker_Doctor
后端 location：DOCTOR
```

功能：

```text
1. 医生首次接触患者
2. User Mode 医患对话
3. 医生 Agent 根据症状生成追问
4. 决定是否 order_lab / order_imaging
5. 生成初步转归建议
```

推荐状态：

```text
DOCTOR_FIRST_CONTACT
CONSULTATION_ACTIVE
ORDER_PENDING
```

推荐场景：

```text
患者进入医生区，打开 DialoguePanel，医生 Agent 回复。
```

推荐 UI / 对话：

```text
Doctor: Can you describe your symptoms?
医生：请描述一下你现在最主要的不适。
```

---

### 5.3.5 ED Resuscitation Bay / 急诊抢救区

```text
位置：左上抢救床、监护仪区域
中文名：急诊抢救区
英文名：ED Resuscitation Bay
推荐 Marker：Marker_ED_Resus
后端 location：ED_RESUS
```

功能：

```text
1. 高危患者快速处理
2. 表示 L1 / L2 患者优先进入抢救流程
3. 展示急诊内部 critical care
4. 不等同于 ICU
```

推荐状态：

```text
ED_RESUSCITATION
CRITICAL_FIRST_CONTACT
```

推荐场景：

```text
高危患者从分诊后直接进入抢救区，跳过普通候诊。
```

推荐 UI / 对话：

```text
Critical route activated.
高危路径已触发，患者进入急诊抢救区。
```

---

### 5.3.6 Elevator / 电梯

```text
位置：顶部中央
中文名：电梯
英文名：Elevator
推荐 Marker：Marker_Elevator_ED
后端 location：ELEVATOR_ED，可选
```

功能：

```text
1. 跨地图切换点
2. 可以通往 Map 2 检查诊断区
3. 可以通往 Map 3 转归下游区
4. 第一版不做真实交互，只作为切图视觉表达
```

推荐场景：

```text
医生问诊后，若后端返回 LAB / IMAGING / DISPOSITION，则前端可切换地图。
```

推荐 UI / 对话：

```text
Moving to diagnostics floor.
患者前往检查诊断区。
```

---

# 6. Map 2：检查诊断区

## 6.1 基本定义

```text
地图文件名：map2_v3.png
地图 ID：MAP_DIAGNOSTICS
中文名：检查诊断区
英文名：Diagnostics Map
推荐理解：医院二层 / 检查诊断流程层
```

## 6.2 主要功能

Map 2 承接医生在 Map 1 中下达的检查医嘱，包括 Lab 检验、Imaging 影像检查、检查等待和结果复核。

主要流程：

```text
DIAGNOSTIC_WAITING
→ LAB / IMAGING
→ RESULT_REVIEW
→ DOCTOR 或 DISPOSITION
```

---

## 6.3 Map 2 分区定义

### 6.3.1 Clinical Lab / 检验科

```text
位置：左上实验台、显微镜、试管、电脑区域
中文名：检验科
英文名：Clinical Lab
推荐 Marker：Marker_Lab
后端 location：LAB
```

功能：

```text
1. 承接 order_lab
2. 模拟 CBC、troponin、CRP 等检验流程
3. 展示检验等待、处理中、结果完成
```

推荐状态：

```text
LAB_WAITING
LAB_PROCESSING
LAB_RESULT_READY
```

推荐场景：

```text
患者进入 Lab 后，EventTimeline 显示 lab order processing。
```

推荐 UI / 对话：

```text
Lab test is being processed.
检验项目处理中。
```

---

### 6.3.2 Imaging / 影像科

```text
位置：右上 MRI / CT 扫描仪区域
中文名：影像科
英文名：Imaging
推荐 Marker：Marker_Imaging
后端 location：IMAGING
```

功能：

```text
1. 承接 order_imaging
2. 表示 CT / MRI 等影像检查
3. 展示影像等待、扫描、结果返回
```

推荐状态：

```text
IMAGING_WAITING
IMAGING_PROCESSING
IMAGING_RESULT_READY
```

推荐场景：

```text
患者进入 Imaging 后，UI 显示 imaging order / scanning / result ready。
```

推荐 UI / 对话：

```text
Imaging scan in progress.
影像检查进行中。
```

重要边界：

```text
Map 2 已经承担 Imaging 功能，因此 Map 3 不再承担 MRI / CT 检查功能。
如果 Map 3 中出现类似 MRI / CT 的区域，应改为 Ward 或其他下游资源功能，避免重复。
```

---

### 6.3.3 Diagnostic Waiting / 检查等待区

```text
位置：左下候诊椅区域
中文名：检查等待区
英文名：Diagnostic Waiting
推荐 Marker：Marker_Diagnostic_Waiting
后端 location：DIAGNOSTIC_WAITING
```

功能：

```text
1. 患者等待 Lab 或 Imaging
2. 展示检查区队列
3. 作为 Lab / Imaging 前的缓冲区
```

推荐状态：

```text
DIAGNOSTIC_WAITING
LAB_WAITING
IMAGING_WAITING
```

推荐场景：

```text
患者先进入等待区，再进入 Lab 或 Imaging。
```

推荐 UI / 对话：

```text
Waiting for diagnostic service.
患者正在等待检查。
```

---

### 6.3.4 Result Review Desk / 结果复核区

```text
位置：右下办公桌、电脑、文件柜区域
中文名：结果复核区
英文名：Result Review Desk
推荐 Marker：Marker_Result_Review
后端 location：RESULT_REVIEW
```

功能：

```text
1. 检查结果返回后的复核节点
2. 可用于展示 lab_result / imaging_result
3. 作为进入转归前的中间节点
```

推荐状态：

```text
RESULT_REVIEW
RESULT_READY
```

推荐场景：

```text
患者检查完成后进入结果复核区，系统读取结果。
```

推荐 UI / 对话：

```text
Results are ready for review.
检查结果已返回，等待复核。
```

---

### 6.3.5 Elevator / 电梯

```text
位置：顶部中央
中文名：电梯
英文名：Elevator
推荐 Marker：Marker_Elevator_Diagnostics
后端 location：ELEVATOR_DIAGNOSTICS，可选
```

功能：

```text
1. 跨地图切换点
2. 可返回 Map 1
3. 可进入 Map 3
4. 具体方向由后端下一步 location 决定
```

推荐跳转逻辑：

```text
如果后端下一步 location 是 DOCTOR，则切回 Map 1。
如果后端下一步 location 是 DISPOSITION / ICU / WARD / ED_BOARDING / DISCHARGE，则切到 Map 3。
如果不做真实走电梯，则直接 fade transition 到目标地图。
```

推荐 UI / 对话：

```text
Moving to disposition floor.
患者前往转归决策区。
```

---

# 7. Map 3：转归与下游资源区

## 7.1 基本定义

```text
地图文件名：map3_v1.png
地图 ID：MAP_DOWNSTREAM
中文名：转归与下游资源区
英文名：Downstream Map
推荐理解：医院三层 / 转归与住院资源层
```

## 7.2 主要功能

Map 3 负责患者完成急诊评估、医生问诊、Lab 和 Imaging 后的下游流程：

```text
DISPOSITION
→ ICU / WARD / ED_BOARDING / DISCHARGE
```

Map 3 不承担 Lab 或 Imaging 的检查功能。

---

## 7.3 Map 3 分区定义

### 7.3.1 ICU / 重症监护区

```text
位置：左上监护床、监护仪、输液架、氧气设备区域
中文名：重症监护区
英文名：ICU
推荐 Marker：Marker_ICU
后端 location：ICU
```

功能：

```text
1. 危重患者最终去向
2. 展示 ICU admission
3. 体现 ICU capacity
4. 区分于 Map 1 中的 ED Resus
```

推荐状态：

```text
ICU_TRANSFERRED
ICU_ADMITTED
```

推荐场景：

```text
Demo C 中，高危患者最终进入 ICU。
```

推荐 UI / 对话：

```text
Patient transferred to ICU.
患者已转入 ICU。
```

---

### 7.3.2 Ward / 普通住院区

```text
位置：右上多张普通病床、床头柜、药柜区域
中文名：普通住院区
英文名：General Ward
推荐 Marker：Marker_Ward
后端 location：WARD
```

功能：

```text
1. 普通住院患者终点
2. 用于中等风险或需要住院观察患者
3. 展示普通床位资源
4. 不再放 MRI / CT，避免和 Map 2 Imaging 重复
```

推荐状态：

```text
WARD_ADMITTED
```

推荐场景：

```text
Demo B 中，患者完成检查和转归后进入普通病房。
```

推荐 UI / 对话：

```text
Patient admitted to general ward.
患者已收入普通病房。
```

---

### 7.3.3 Disposition Hub / 转归决策中心

```text
位置：中央护士站 / 调度台 / 大屏区域
中文名：转归决策中心
英文名：Disposition Hub
推荐 Marker：Marker_Disposition
后端 location：DISPOSITION
```

功能：

```text
1. 汇总医生评估、Lab、Imaging 结果
2. 决定患者进入 ICU、Ward、ED Boarding 或 Discharge
3. 展示 EDAdapter 和床位资源联动
4. 是 Map 3 的核心决策节点
```

推荐状态：

```text
DISPOSITION_PENDING
TRANSFER_DECISION
AWAITING_BED
```

推荐场景：

```text
患者进入转归中心后，系统根据资源和病情决定最终去向。
```

推荐 UI / 对话：

```text
Disposition decision pending.
正在进行转归决策。
```

---

### 7.3.4 ED Boarding / 留观等待区

```text
位置：左下观察床、候诊椅区域
中文名：留观等待区
英文名：ED Boarding / Observation Area
推荐 Marker：Marker_ED_Boarding
后端 location：ED_BOARDING
```

功能：

```text
1. 当 ICU 或 Ward 暂无床位时，患者进入 ED Boarding
2. 展示下游资源不足对急诊系统的反向压力
3. 可作为压力测试展示点
4. 表示患者未能立即进入下游床位
```

推荐状态：

```text
ED_BOARDING
AWAITING_ICU_BED
AWAITING_WARD_BED
```

推荐场景：

```text
当 ICU / Ward capacity 不足时，患者不能立即转入病房，而是进入留观等待区。
```

推荐 UI / 对话：

```text
No downstream bed available. Patient is boarding.
下游床位不足，患者进入留观等待。
```

---

### 7.3.5 Discharge / 出院区

```text
位置：右下或底部出口区域，取决于最终地图版本
中文名：出院区
英文名：Discharge Area
推荐 Marker：Marker_Discharge
后端 location：DISCHARGE
```

功能：

```text
1. 稳定轻症患者最终离院
2. Demo A 的终点
3. 表示患者从医院流程中结束
```

推荐状态：

```text
DISCHARGED
```

推荐场景：

```text
患者完成评估和检查后，最终出院。
```

推荐 UI / 对话：

```text
Patient discharged.
患者已出院。
```

当前说明：

```text
如果当前图片版本暂时移除了出院门，则仍应在 Godot 中保留 Marker_Discharge。
Marker_Discharge 可以暂时放在右下出院/办公区附近，后续地图视觉版本稳定后再移动到明确出院出口。
```

---

### 7.3.6 Elevator / 电梯

```text
位置：顶部中央
中文名：电梯
英文名：Elevator
推荐 Marker：Marker_Elevator_Downstream
后端 location：ELEVATOR_DOWNSTREAM，可选
```

功能：

```text
1. 跨地图连接点
2. 可返回 Map 2 或 Map 1
3. 可作为进入 Map 3 的初始出现点
4. 第一版不做真实电梯按钮
```

推荐跳转逻辑：

```text
从 Map 2 完成结果复核后，进入 Map 3 的电梯区域。
患者随后移动到 Disposition Hub。
如果后端直接返回 ICU / WARD / DISCHARGE，也可直接切图并移动到目标 Marker。
```

推荐 UI / 对话：

```text
Arrived at downstream care floor.
患者已到达转归与住院资源层。
```

---

# 8. LOCATION_TO_MAP 协议

```python
LOCATION_TO_MAP = {
    "ED_ENTRANCE": "MAP_ED_CORE",
    "TRIAGE": "MAP_ED_CORE",
    "WAITING_AREA": "MAP_ED_CORE",
    "DOCTOR": "MAP_ED_CORE",
    "ED_RESUS": "MAP_ED_CORE",

    "LAB": "MAP_DIAGNOSTICS",
    "IMAGING": "MAP_DIAGNOSTICS",
    "DIAGNOSTIC_WAITING": "MAP_DIAGNOSTICS",
    "RESULT_REVIEW": "MAP_DIAGNOSTICS",

    "DISPOSITION": "MAP_DOWNSTREAM",
    "ICU": "MAP_DOWNSTREAM",
    "WARD": "MAP_DOWNSTREAM",
    "ED_BOARDING": "MAP_DOWNSTREAM",
    "DISCHARGE": "MAP_DOWNSTREAM"
}
```

---

# 9. LOCATION_TO_MARKER 协议

```python
LOCATION_TO_MARKER = {
    "ED_ENTRANCE": "Marker_ED_Entrance",
    "TRIAGE": "Marker_Triage",
    "WAITING_AREA": "Marker_Waiting",
    "DOCTOR": "Marker_Doctor",
    "ED_RESUS": "Marker_ED_Resus",

    "LAB": "Marker_Lab",
    "IMAGING": "Marker_Imaging",
    "DIAGNOSTIC_WAITING": "Marker_Diagnostic_Waiting",
    "RESULT_REVIEW": "Marker_Result_Review",

    "DISPOSITION": "Marker_Disposition",
    "ICU": "Marker_ICU",
    "WARD": "Marker_Ward",
    "ED_BOARDING": "Marker_ED_Boarding",
    "DISCHARGE": "Marker_Discharge",

    "ELEVATOR_ED": "Marker_Elevator_ED",
    "ELEVATOR_DIAGNOSTICS": "Marker_Elevator_Diagnostics",
    "ELEVATOR_DOWNSTREAM": "Marker_Elevator_Downstream"
}
```

---

# 10. 电梯切换协议

## 10.1 电梯用途

电梯用于表示患者从一个流程层进入另一个流程层。

电梯不承担以下功能：

```text
1. 不负责临床判断
2. 不决定患者目标科室
3. 不需要开关门动画
4. 不需要按钮交互
5. 不需要复杂楼层系统
```

## 10.2 第一版实现

```text
1. 后端返回新的 location。
2. Godot 判断新 location 属于另一张 map。
3. 当前 map fade out。
4. 目标 map fade in。
5. 患者出现在目标 map 的对应 Marker。
```

## 10.3 推荐切换规则

### Map 1 → Map 2

触发条件：

```text
后端 location 变成 LAB / IMAGING / DIAGNOSTIC_WAITING / RESULT_REVIEW
```

行为：

```text
切换到 MAP_DIAGNOSTICS
```

### Map 2 → Map 3

触发条件：

```text
后端 location 变成 DISPOSITION / ICU / WARD / ED_BOARDING / DISCHARGE
```

行为：

```text
切换到 MAP_DOWNSTREAM
```

### Map 2 → Map 1

触发条件：

```text
检查完成后需要回医生区复核，后端 location 变成 DOCTOR
```

行为：

```text
切换到 MAP_ED_CORE
```

### Map 3 → Map 1 或 Map 2

第一版暂时不强制实现。除非 Demo 需要，否则 Map 3 可作为终点流程地图。

---

# 11. 推荐 Demo 路径

## 11.1 Demo A：轻症出院路径

```text
ED_ENTRANCE
→ TRIAGE
→ WAITING_AREA
→ DOCTOR
→ LAB
→ RESULT_REVIEW
→ DISPOSITION
→ DISCHARGE
```

展示重点：

```text
1. 普通患者完成分诊、问诊、检验后出院
2. 证明 Map 1 → Map 2 → Map 3 的完整跨图闭环
3. 最终终点为 Discharge
```

---

## 11.2 Demo B：住院路径

```text
ED_ENTRANCE
→ TRIAGE
→ WAITING_AREA
→ DOCTOR
→ LAB
→ IMAGING
→ RESULT_REVIEW
→ DISPOSITION
→ WARD
```

展示重点：

```text
1. 检验和影像结果共同进入转归决策
2. 患者最终进入普通住院区
3. Map 3 右上 Ward 与 Map 2 Imaging 不重复
```

---

## 11.3 Demo C：危重 ICU 路径

```text
ED_ENTRANCE
→ TRIAGE
→ ED_RESUS
→ DOCTOR
→ IMAGING
→ DISPOSITION
→ ICU
```

展示重点：

```text
1. 高危患者跳过普通候诊
2. ED Resus 与 ICU 是两个不同阶段
3. ICU 是最终下游资源，不是急诊抢救区
```

---

## 11.4 Demo D：床位不足 Boarding 路径，可选

```text
ED_ENTRANCE
→ TRIAGE
→ DOCTOR
→ LAB / IMAGING
→ DISPOSITION
→ ED_BOARDING
```

展示重点：

```text
1. ICU 或 Ward 无床位时，患者进入留观等待
2. 展示下游资源紧张导致急诊拥堵
3. 适合压力测试展示
```

---

# 12. Godot 前端实现要求

## 12.1 必须实现

### HospitalMapManager

功能：

```text
1. 管理三张地图显示与隐藏
2. 根据 location 切换 map
3. 管理 fade transition
```

### PatientManager

功能：

```text
1. 根据 snapshot 创建 / 更新患者
2. 根据 location 找 Marker
3. 调用 PatientSprite.move_to()
```

### APIClient

必须支持：

```text
GET  /api/godot/snapshot
POST /api/godot/step
POST /api/godot/demo/load
GET  /api/godot/events/recent
GET  /api/godot/model_calls/recent
POST /api/godot/user_turn
```

### Marker2D

每个后端 location 对应一个 Godot Marker2D。

### Fade Transition

跨地图时执行淡入淡出。

---

## 12.2 不需要实现

第一版不需要实现：

```text
1. Door.gd
2. 开门动画
3. 电梯按钮
4. 复杂寻路
5. NPC 自动巡逻
6. Godot 自己决定患者下一步去哪里
7. 医学规则前端判断
```

---

# 13. 地图设计边界

```text
1. 三张地图是功能流程图，不需要完全符合真实医院建筑平面。
2. 电梯可以暂时作为跨图切换符号，不需要真实楼层逻辑。
3. 科室门尽量开放，减少前端碰撞和路径规划复杂度。
4. Map 2 已经承担 Imaging 功能，因此 Map 3 不再承担 MRI / CT 检查功能。
5. Map 3 的右上角定义为 Ward / 普通住院区。
6. Map 3 的左上角定义为 ICU / 重症监护区。
7. Map 3 的左下角定义为 ED Boarding / 留观等待区。
8. Map 3 的中央定义为 Disposition Hub / 转归决策中心。
9. Map 3 的 Discharge 可以根据最终地图版本决定是否显示，但后端和 Godot 中仍建议保留 Marker_Discharge。
10. 所有医学状态由后端决定，地图只负责可视化。
```

---

# 14. Codex / Godot 接入时的检查清单

```text
[ ] 三张地图图片已放入 assets/maps/
[ ] map1_v1.png 存在
[ ] map2_v3.png 存在
[ ] map3_v1.png 存在
[ ] HospitalMapManager.gd 已定义 LOCATION_TO_MAP
[ ] HospitalMapManager.gd 已定义 LOCATION_TO_MARKER
[ ] 三张地图都有对应 Sprite2D / TextureRect 节点
[ ] 每个 location 都有 Marker2D
[ ] PatientSprite 能够 move_to(marker)
[ ] APIClient 能够 get_snapshot
[ ] APIClient 能够 post_step
[ ] Demo A 最终到 DISCHARGE
[ ] Demo B 最终到 WARD
[ ] Demo C 最终到 ICU
[ ] 跨地图时不会 crash
[ ] 后端 disconnected 时有错误提示
[ ] 不存在 Door.gd 依赖
[ ] 不存在必须开门才能移动的逻辑
```

---

# 15. 最终工程原则

```text
地图不是用来模拟真实医院建筑，而是用来让评委看清楚：
患者从急诊入口进入系统后，如何经过分诊、候诊、医生问诊、检查诊断和最终转归。

地图中的每个房间本质上是一个后端状态节点的视觉锚点。
Godot 的任务是把后端状态变化变成可见的空间运动。
```

