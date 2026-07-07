"""
NPC Finite State Machine — drives simulation step by step.

Each NPC has its own FSM instance. The engine:
1. Checks which NPCs are ready to decide
2. Calls the appropriate LLM model based on scenario
3. Returns an action for Godot to execute
4. Waits for Godot to report completion
"""

import json, time, urllib.request, ssl
from concurrent.futures import ThreadPoolExecutor, as_completed
from typing import Optional

_llm_pool = ThreadPoolExecutor(max_workers=12)

# ── API config (key rotation) ──
GITEE_KEYS = [
    "HOHGSAMMVSBLXBHT2DMVMXQOEBP0VZSRJBXFW7S2",
    "WCWPXT8ENFDYTCZ0F8OBZRFBMVMU9CDJVFVU4R1T",
]
GITEE_BASE = "https://ai.gitee.com/api/v1"
_key_idx = 0

MODEL_FAST = "DeepSeek-V4-Flash"
MODEL_MEDICAL = "HealthGPT-L14"
MODEL_DIALOGUE = "DeepSeek-V4-Flash"

STATE_IDLE = "idle"
STATE_DECIDING = "deciding"
STATE_MOVING = "moving"
STATE_SPEAKING = "speaking"
STATE_WAITING = "waiting"


def _llm_call(model: str, prompt: str, max_tokens: int = 512, temperature: float = 0.3) -> dict:
    """Call Gitee AI API with automatic key rotation."""
    global _key_idx
    url = GITEE_BASE + "/chat/completions"
    payload = json.dumps({
        "model": model,
        "messages": [{"role": "user", "content": prompt}],
        "temperature": temperature,
        "max_tokens": max_tokens,
    }).encode()

    # Try each key in rotation
    for _ in range(len(GITEE_KEYS)):
        key = GITEE_KEYS[_key_idx % len(GITEE_KEYS)]
        _key_idx = (_key_idx + 1) % len(GITEE_KEYS)
        req = urllib.request.Request(url, data=payload, method="POST")
        req.add_header("Content-Type", "application/json")
        req.add_header("Authorization", "Bearer " + key)
        try:
            ctx = ssl.create_default_context()
            resp = urllib.request.urlopen(req, timeout=60, context=ctx)
            data = json.loads(resp.read())
            text = data["choices"][0]["message"]["content"]
            tokens = data["usage"]["total_tokens"]
            return {"text": text, "tokens": tokens}
        except Exception as e:
            continue
    raise RuntimeError("All Gitee AI keys failed")


class NPCFsm:
    """Single NPC's finite state machine."""

    def __init__(self, npc_id: str, display_name: str, role: str,
                 knowledge: list, priority: int = 1):
        self.npc_id = npc_id
        self.display_name = display_name
        self.role = role
        self.knowledge = knowledge
        self.priority = priority
        self.state = STATE_IDLE
        self.position = {"x": 0, "y": 0}
        self.memory = []
        self.pending_action = None

    def decide(self, prompt: str, model: str = MODEL_FAST) -> Optional[dict]:
        """LLM decides the next action. Runs in thread pool."""
        self.state = STATE_DECIDING
        try:
            result = _llm_call(model, prompt, max_tokens=512)
            action = self._parse_action(result["text"])
            action["think"] = result["text"]
            return action
        except Exception as e:
            print(f"[NPC:{self.npc_id}] LLM error: {e}")
            self.state = STATE_IDLE
            return None

    def execute(self, action: dict) -> None:
        atype = action.get("type", "")
        if atype == "speak":
            self.state = STATE_SPEAKING
        elif atype == "move_to":
            self.state = STATE_MOVING
            self.position = action.get("position", self.position)
        elif atype == "wait":
            self.state = STATE_WAITING
        if atype == "speak":
            self.memory.append({
                "role": self.display_name,
                "dialogue": action.get("dialogue", ""),
                "think": action.get("think", ""),
            })

    def complete(self) -> None:
        self.state = STATE_IDLE

    def build_routing_prompt(self, ctx: dict) -> str:
        return f"""你是一名医院{self.display_name}。当前场景：
- 你的状态：{self.state}
- 你的位置：{self.position}
- 患者信息：{json.dumps(ctx.get('patients', {}), ensure_ascii=False)}
- 你的专业技能：{[k.get('condition','') for k in self.knowledge]}

请输出你的下一步行动，仅JSON格式：
{{
  "type": "speak|move_to|wait|use_device",
  "target": "目标NPC ID或location ID",
  "utterances": ["短句1", "短句2"],
  "position": {{"x": 数字, "y": 数字}},
  "duration": 数字（秒）
}}

注意：
- utterances 里**每条不超过15个字**，一条只问一个问题
- 如果需要问多个问题，就拆成多条 utterances
- 例如：["哪里痛？", "多久了？", "发烧吗？"]
- 严禁一条 utterance 包含多个问题或一大段话"""

    def build_dialogue_prompt(self, ctx: dict) -> str:
        patient = ctx.get("current_patient", {})
        history = self.memory[-6:] if len(self.memory) > 6 else self.memory
        player_input = ctx.get("player_input", "")
        return f"""你是一名医院{self.display_name}，正在与患者对话。

你的角色知识：
{json.dumps(self.knowledge, ensure_ascii=False)}

对话历史：
{json.dumps(history, ensure_ascii=False)}

患者信息：{json.dumps(patient, ensure_ascii=False)}

{"患者刚才说：" + player_input if player_input else ""}

请输出：
{{
  "think": "你的推理（RAG检索结果、临床表现分析、决策依据）",
  "utterances": ["一句话回复，不超过50字"]
}}

注意：utterances里每条不超过15个字，一条只说一件事。"""

    def _parse_action(self, llm_text: str) -> dict:
        text = llm_text.strip()
        if "```" in text:
            text = text.split("```")[1]
            if text.startswith("json"):
                text = text[4:]
        text = text.strip()
        try:
            result = json.loads(text)
            # Convert single dialogue to utterances
            if "dialogue" in result and "utterances" not in result:
                if isinstance(result["dialogue"], str):
                    result["utterances"] = [result["dialogue"]]
            return result
        except json.JSONDecodeError:
            return {"type": "speak", "utterances": [text], "think": llm_text}


class SimulationEngine:
    """Manages all NPC FSMs. All LLM calls run CONCURRENTLY."""

    def __init__(self):
        self.npcs: dict[str, NPCFsm] = {}
        self.current_patient = {}
        self.conversations = {}

    def add_npc(self, fsm: NPCFsm) -> None:
        self.npcs[fsm.npc_id] = fsm

    def tick(self) -> list[dict]:
        """All idle NPCs decide their next action IN PARALLEL via thread pool."""
        futures = {}
        for npc_id, fsm in self.npcs.items():
            if fsm.state == STATE_IDLE:
                ctx = self._build_context(npc_id)
                prompt = fsm.build_routing_prompt(ctx)
                model = MODEL_MEDICAL if fsm.role in ("doctor", "nurse") else MODEL_FAST
                fut = _llm_pool.submit(fsm.decide, prompt, model)
                futures[fut] = npc_id

        actions = []
        for fut in as_completed(futures):
            npc_id = futures[fut]
            try:
                action = fut.result()
                if action:
                    action["npc_id"] = npc_id
                    actions.append(action)
                else:
                    self.npcs[npc_id].state = STATE_IDLE
            except Exception as e:
                print(f"[NPC:{npc_id}] Error: {e}")
                self.npcs[npc_id].state = STATE_IDLE
        return actions

    def report_complete(self, npc_id: str) -> None:
        fsm = self.npcs.get(npc_id)
        if fsm:
            fsm.complete()

    def _build_context(self, npc_id: str) -> dict:
        return {
            "patients": {"current": self.current_patient},
            "conversation_with": self._get_partner(npc_id),
            "current_patient": self.current_patient,
        }

    def _get_partner(self, npc_id: str) -> Optional[str]:
        for a, b in self.conversations.values():
            if a == npc_id:
                return b
            if b == npc_id:
                return a
        return None
