# EDMAS Backend

This backend is now a terminal-first simulation pipeline:

1. Read a natural-language scene request from the terminal.
2. Call an OpenAI-compatible API to convert the request into `SimulationSpec` JSON.
3. Validate the JSON and create a simulation state.
4. Call the API again to generate doctor, nurse, patient, device, movement, and dialogue actions.
5. Convert the action plan into a Godot `DemoTimeline`.

There is no FastAPI/Swagger/web entry point in this backend.

## Run

```bash
cd backend
python -m app.cli.terminal_demo
```

The command prompts:

```text
请输入场景：
```

Example:

```text
车祸急诊流程，需要设备和医生资源调度
```

You can also pass the scene directly:

```bash
python -m app.cli.terminal_demo --intent "车祸急诊流程，需要设备和医生资源调度"
```

Direct JSON remains supported and skips the scene prompt:

```bash
python -m app.cli.terminal_demo --spec app/data/examples/stomach_pain.simulation.json
```

Save generated JSON:

```bash
python -m app.cli.terminal_demo --intent "模拟一个胃痛病人看病" --save-generated-spec runtime/stomach.generated.json
```

## Env

Copy `backend/.env.example` to `backend/.env`.

Required real API settings:

```env
EDMAS_INTENT_PROVIDER=openai
EDMAS_AGENT_PROVIDER=openai
OPENAI_API_KEY=your_api_key_here
OPENAI_BASE_URL=https://api.openai.com/v1
OPENAI_MODEL=gpt-4.1-mini
```

The local `.env` may also use `api_key`, `base_url`, and `model_name` aliases.

## Tests

Tests use deterministic providers and do not call the remote API.

```bash
cd backend
python -m pytest -q
```
