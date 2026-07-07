# Mock Mode Report

## Purpose

- Allow the Godot client to demonstrate patient appearance, movement, and map switching without a running ED-MAS backend.

## Mode differences

- `real API mode`
  - Uses `scripts/edmas/api_client.gd`
  - Requests `http://127.0.0.1:8000/api/godot/*`
- `mock mode`
  - Uses `scripts/edmas/mock/mock_demo_provider.gd`
  - No backend dependency
  - Returns local mock snapshots for `demo_A`, `demo_B`, `demo_C`

## Current limitation

- Mock mode is a first-pass runtime harness.
- It is not RAG, not NPC automation, and not wall/pathfinding.

