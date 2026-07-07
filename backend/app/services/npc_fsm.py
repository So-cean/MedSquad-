"""
NPC Finite State Machine — drives simulation step by step.

Each NPC has its own FSM instance. The engine:
1. Checks which NPCs are ready to decide
2. Calls the appropriate LLM model based on scenario
3. Returns an action for Godot to execute
4. Waits for Godot to report completion
"""

import json, time, urllib.request, ssl
from typing import Optional

# ── API config ──
GITEE_KEY = "HOHGSAMMVSBLXBHT2DMVMXQOEBP0VZSRJBXFW7S2"
GITEE_BASE = "https://ai.gitee.com/api/v1"

# Model routing
MODEL_FAST = "DeepSeek-V4-Flash"        # 极速决策
MODEL_MEDICAL = "HealthGPT-L14"          # 医学分诊
MODEL_DIALOGUE = "DeepSeek-V4-Flash"     # 对话生成(含think)

# ── FSM states ──
STATE_IDLE = "idle"
STATE_DECIDING = "deciding"    # waiting for LLM
STATE_MOVING = "moving"        # executing move
STATE_SPEAKING = "speaking"    # executing speak
STATE_WAITING = "waiting"      # waiting for response


def _llm_call(model: str, prompt: str, max_tokens: int = 512, temperature: float = 0.3) -> dict:
    """Call Gitee AI API. Returns parsed JSON."""
    url = GITEE_BASE + "/chat/completions"
    payload = json.dumps({
        "model": model,
        "messages": [{"role": "user", "content": prompt}],
        "temperature": temperature,
        "max_tokens": max_tokens,
    }).encode()

    req = urllib.request.Request(url, data=payload, method="POST")
    req.add_header("Content-Type", "application/json")
    req.add_header("Authorization", "Bearer " + GITEE_KEY)

    ctx = ssl.create_default_context()
    resp = urllib.request.urlopen(req, timeout=60, context=ctx)
    data = json.loads(resp.read())
    text = data["choices"][0]["message"]["content"]
    tokens = data["usage"]["total_tokens"]
    return {"text": text, "tokens": tokens}


class NPCFsm:
    """Single NPC's finite state machine."""

    def __init__(self, npc_id: str, display_name: str, role: str,
                 knowledge: list, priority: int = 1):
        self.npc_id = npc_id
        self.display_name = display_name
        self.role = role  # nurse, doctor, patient
        self.knowledge = knowledge
        self.priority = priority
        self.state = STATE_IDLE
        self.position = {"x": 0, "y": 0}
        self.memory = []  # dialogue history
        self.action_queue = []
        self.pending_action = None

    def decide(self, scene_context: dict) -> Optional[dict]:
        """LLM decides the next action. Returns action dict or None."""
        if self.state != STATE_IDLE:
            return None

        self.state = STATE_DECIDING
        model, prompt = self._build_prompt(scene_context)
        try:
            result = _llm_call(model, prompt, max_tokens=512)
            action = self._parse_action(result["text"])
            action["think"] = result["text"]  # store full response as think
            return action
        except Exception as e:
            print(f"[NPC:{self.npc_id}] LLM error: {e}")
            self.state = STATE_IDLE
            return None

    def execute(self, action: dict) -> None:
        """Receive action from Godot completion."""
        self.action_queue.append(action)
        atype = action.get("type", "")
        if atype == "speak":
            self.state = STATE_SPEAKING
        elif atype == "move_to":
            self.state = STATE_MOVING
            self.position = action.get("position", self.position)
        elif atype == "wait":
            self.state = STATE_WAITING
        # Record to memory
        if atype == "speak":
            self.memory.append({
                "role": self.display_name,
                "dialogue": action.get("dialogue", ""),
                "think": action.get("think", ""),
                "target": action.get("target", ""),
            })

    def complete(self) -> None:
        """Godot reports action done. Return to IDLE."""
        self.state = STATE_IDLE

    # ── prompt builder ──

    def _build_prompt(self, ctx: dict) -> tuple:
        """Returns (model_name, prompt_string)."""
        intent = ctx.get("intent", "routing")  # routing | medical | dialogue

        if intent == "medical":
            return MODEL_MEDICAL, self._prompt_medical(ctx)
        elif intent == "dialogue":
            return MODEL_DIALOGUE, self._prompt_dialogue(ctx)
        else:
            return MODEL_FAST, self._prompt_routing(ctx)

    def _prompt_routing(self, ctx: dict) -> str:
        """Fast routing decision — what to do next."""
        return f"""你是一名医院{self.display_name}。当前场景：
- 你的状态：{self.state}
- 你的位置：{self.position}
- 患者信息：{json.dumps(ctx.get('patients', {}), ensure_ascii=False)}
- 你正在对话的对象：{ctx.get('conversation_with', '无')}
- 你的专业技能：{[k.get('condition','') for k in self.knowledge]}

请输出你的下一步行动，仅JSON格式，不要其他内容：
{{
  "type": "speak|move_to|wait|use_device",
  "target": "目标NPC ID或location ID",
  "dialogue": "你要说的话（如果是speak）",
  "position": {{"x": 数字, "y": 数字}}（如果是move_to）,
  "duration": 数字（秒）
}}"""

    def _prompt_medical(self, ctx: dict) -> str:
        """Medical triage/decision."""
        patient = ctx.get("current_patient", {})
        return f"""你是一名急诊{self.display_name}。患者信息：
- 主诉：{patient.get('chief_complaint', '未知')}
- 症状：{patient.get('symptoms', [])}
- 生命体征：{json.dumps(patient.get('vitals', {}), ensure_ascii=False)}

请输出JSON格式的分诊建议：
{{
  "triage_level": 1-5,
  "diagnosis": "初步诊断",
  "suggested_checks": ["检查1", "检查2"],
  "action": "建议行动",
  "think": "你的推理过程"
}}"""

    def _prompt_dialogue(self, ctx: dict) -> str:
        """Dialogue generation with think (background knowledge)."""
        patient = ctx.get("current_patient", {})
        history = self.memory[-6:] if len(self.memory) > 6 else self.memory
        return f"""你是一名医院{self.display_name}，正在与患者对话。

你的角色知识：
{json.dumps(self.knowledge, ensure_ascii=False)}

对话历史：
{json.dumps(history, ensure_ascii=False)}

患者信息：
- 主诉：{patient.get('chief_complaint', '未知')}
- 当前状态：{patient.get('state', '等待中')}

请输出：
{{
  "think": "你的推理（RAG检索结果、临床表现分析、决策依据）",
  "dialogue": "你对患者说的话"
}}"""

    def _parse_action(self, llm_text: str) -> dict:
        """Parse LLM output to action dict. Handles JSON wrapped in markdown."""
        text = llm_text.strip()
        # Strip markdown code fences
        if "```" in text:
            text = text.split("```")[1]
            if text.startswith("json"):
                text = text[4:]
        text = text.strip()
        try:
            return json.loads(text)
        except json.JSONDecodeError:
            return {"type": "speak", "dialogue": text, "think": llm_text}


# ── Simulation Engine ──

class SimulationEngine:
    """Manages all NPC FSMs and drives the simulation."""

    def __init__(self):
        self.npcs: dict[str, NPCFsm] = {}
        self.global_time: float = 0.0
        self.current_patient = {}
        self.conversations = {}  # pair_id -> [npc_a_id, npc_b_id]

    def add_npc(self, fsm: NPCFsm) -> None:
        self.npcs[fsm.npc_id] = fsm

    def tick(self) -> list[dict]:
        """Check all NPCs. Return list of actions ready for Godot."""
        actions = []
        for npc_id, fsm in self.npcs.items():
            if fsm.state == STATE_IDLE:
                ctx = self._build_context(npc_id)
                action = fsm.decide(ctx)
                if action:
                    action["npc_id"] = npc_id
                    actions.append(action)
        return actions

    def report_complete(self, npc_id: str) -> None:
        """Godot reports action done."""
        fsm = self.npcs.get(npc_id)
        if fsm:
            fsm.complete()

    def _build_context(self, npc_id: str) -> dict:
        fsm = self.npcs.get(npc_id)
        return {
            "intent": "routing",
            "patients": {"current": self.current_patient},
            "conversation_with": self._get_conversation_partner(npc_id),
            "current_patient": self.current_patient,
        }

    def _get_conversation_partner(self, npc_id: str) -> Optional[str]:
        for pair_id, (a, b) in self.conversations.items():
            if a == npc_id:
                return b
            if b == npc_id:
                return a
        return None
