# Simulator Development

## Model Behaviour

YOLO26X-seg produces garbage results on simulator — it is skipped; only `yolov8x-oiv7` runs on sim.

## Fixture Injection

Camera/AR features use fixture injection on simulator:
- Barcode: `Scanning/Barcode/DebugBarcodeFixtures.swift`
- Plate: `Scanning/Plate/DebugPlateFixtures.swift`

Test fixtures live in `norrish-agents/fixtures/` — these are **not** bundled in the app target.

## Environment Variables

| Variable | Effect |
|---|---|
| `BACKEND_DEBUG=1` | Log backend requests |
| `FIXTURE_PATH` / `FIXTURE_INDEX` | External fixture injection |
| `NORRISH_SCREENSHOT_MODE=1` / `NORRISH_SCREENSHOT_ROUTE` | Screenshot testing |
| `PERSONA_NAME` | Persona for test scenarios |
