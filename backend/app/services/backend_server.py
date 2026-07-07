"""
Lightweight HTTP server for Godot → Backend communication.

Endpoints:
  POST /api/sim/init       — Initialize simulation with NPCs
  POST /api/sim/tick        — Get next batch of NPC actions
  POST /api/sim/complete   — Report action complete
  GET  /api/sim/status      — Get current simulation state
"""

import json, http.server, urllib.parse
from typing import Any

from app.services.npc_fsm import SimulationEngine, NPCFsm, _llm_call, MODEL_DIALOGUE

engine = SimulationEngine()
INIT_DATA = {}


class SimHandler(http.server.BaseHTTPRequestHandler):
    def log_message(self, format, *args):
        print(f"[API] {args[0]} {args[1]} {args[2]}")

    def _send(self, data: dict, code: int = 200):
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type")
        self.end_headers()
        self.wfile.write(json.dumps(data, ensure_ascii=False).encode())

    def do_OPTIONS(self):
        self._send({})

    def do_POST(self):
        path = urllib.parse.urlparse(self.path).path
        length = int(self.headers.get("Content-Length", 0))
        body = json.loads(self.rfile.read(length)) if length > 0 else {}

        if path == "/api/sim/init":
            self._handle_init(body)
        elif path == "/api/sim/tick":
            self._handle_tick()
        elif path == "/api/sim/complete":
            self._handle_complete(body)
        elif path == "/api/sim/talk":
            self._handle_talk(body)
        elif path == "/api/shutdown":
            self._send({"ok": True})
            # Stop the server after responding
            import threading
            threading.Thread(target=lambda: (__import__('time').sleep(0.1), __import__('os')._exit(0))).start()
        else:
            self._send({"error": "not_found"}, 404)

    def do_GET(self):
        path = urllib.parse.urlparse(self.path).path
        if path == "/api/sim/status":
            self._send({
                "npcs": {k: {"state": v.state, "pos": v.position}
                         for k, v in engine.npcs.items()},
            })
        else:
            self._send({"error": "not_found"}, 404)

    # ── handlers ──

    def _handle_init(self, body: dict):
        global INIT_DATA
        INIT_DATA = body
        npcs_data = body.get("npcs", [])

        for n in npcs_data:
            fsm = NPCFsm(
                npc_id=n["id"],
                display_name=n.get("display_name", n["id"]),
                role=n.get("role", "nurse"),
                knowledge=n.get("knowledge", []),
                priority=n.get("priority", 1),
            )
            fsm.position = n.get("position", {"x": 600, "y": 480})
            engine.add_npc(fsm)

        engine.current_patient = body.get("current_patient", {})
        print(f"[Init] {len(npcs_data)} NPCs loaded")
        self._send({"ok": True, "npc_count": len(npcs_data)})

    def _handle_tick(self):
        actions = engine.tick()
        self._send({
            "actions": actions,
            "npc_states": {k: v.state for k, v in engine.npcs.items()},
        })

    def _handle_complete(self, body: dict):
        npc_id = body.get("npc_id", "")
        engine.report_complete(npc_id)
        self._send({"ok": True})

    def _handle_talk(self, body: dict):
        """Player presses E → NPC responds via LLM."""
        npc_id = body.get("npc_id", "")
        player_text = body.get("dialogue", "")
        fsm = engine.npcs.get(npc_id)
        if not fsm:
            self._send({"error": "npc_not_found"}, 404)
            return
        # Build dialogue prompt with player input
        ctx = engine._build_context(npc_id)
        ctx["player_input"] = player_text
        prompt = fsm.build_dialogue_prompt(ctx)
        try:
            result = _llm_call(MODEL_DIALOGUE, prompt, max_tokens=512)
            action = fsm._parse_action(result["text"])
            action["npc_id"] = npc_id
            action["think"] = result["text"]
            fsm.memory.append({
                "role": "player",
                "dialogue": player_text,
                "think": "",
            })
            self._send({"actions": [action]})
        except Exception as e:
            self._send({"error": str(e)}, 500)


def run_server(host: str = "127.0.0.1", port: int = 8651):
    server = http.server.HTTPServer((host, port), SimHandler)
    print(f"[Backend] Running on http://{host}:{port}")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\n[Backend] Shutting down")
        server.server_close()


if __name__ == "__main__":
    run_server()
