# 对话会话设计 V1

## 目标

在 room1 的本地对白基线上，增加一个局部互动会话层：

- 动态生成一个病人
- 让护士先问诊
- 让病人给出主诉
- 让医生接手
- 允许玩家靠近后按 `patient / nurse / doctor` 介入

## 会话阶段

- `CREATED`
- `ACTIVE`
- `WAITING_RESPONSE`
- `PLAYER_INTERVENTION`
- `COMPLETED`
- `FAILED`

## 病人状态

- `ARRIVED`
- `WAITING_FOR_TRIAGE`
- `BEING_TRIAGED`
- `GOING_TO_DOCTOR`
- `GOING_TO_RESUS`
- `BEING_EXAMINED`
- `DISCHARGED`

## 输入来源

- 先用 `PatientCasePool` 的 mock case
- 不接真实 LLM
- 不接后端

## 玩家介入

当玩家接近当前会话组时，显示局部按钮：

- `Patient`
- `Nurse`
- `Doctor`
- `Advance`

玩家只影响当前会话，不接管其他 NPC。

## 结果输出

每个会话结束时输出本地结果，例如：

- 已转交医生进一步判断
- 已优先送入急救链路
- 已完成分诊，等待医生接手

