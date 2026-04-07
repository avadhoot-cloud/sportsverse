# TennisIQ 🌱🎾
*The Ultimate Edge-to-Cloud Tennis Analytics Pipeline*

TennisIQ is an extremely advanced sports analytics platform uniquely combining:
1. **Bluetooth Low Energy (BLE)** Native Smartwatch Telemetry (IMU Accelerometer + HR Arrays).
2. **Dense Computer Vision Models** (YOLOv8 + MediaPipe Pose) strictly parsing physical frames.
3. **Advanced Machine Learning Combinations** (`GradientBoostingRegressor`) routing asynchronous pipelines to score Match Intensities automatically!

## System Architecture

### 1. Flutter Client (Edge Mode)
The frontend utilizes `Riverpod` tracking states seamlessly routing async boundaries securely.
- Extracts ONNX files using `onnxruntime_flutter` processing algorithms efficiently avoiding heavy latency HTTP pulls.
- Stores arrays locally inside `sqflite` queuing metrics natively dropping payloads explicitly once WiFi connections securely reconnect.
- **Run logic:**
  ```bash
  cd frontend/tennisiq_app
  flutter pub get
  flutter run
  ```

### 2. Django + Nginx + Gunicorn Backend (Production Ready)
The Django system tracks heavy database bounds explicitly returning constraints sequentially bypassing standard loops dynamically.
- `nginx.conf` mappings natively intercept `:80` traffic explicitly proxying upstream limits cleanly allocating payloads accurately.
- `@ratelimit(key='user', rate='100/m')` secures POST hits universally evaluating DDoS spikes effectively natively.
- Background Threading natively generates the Fusion Engine outputs catching standard limits tracking seamlessly structurally limiting HTTP timeouts automatically!

### 3. API Integrations
- `[GET] /api/health/` -> Status Checks dynamically.
- `[GET] /api/analytics/progress/` -> DB-level `TruncWeek` aggregations securely mapping historical matrices structurally.
- `[GET] /api/coach/insights/{id}/` -> Heuristic analysis parsing bounds generating physical drills reliably checking constraints dynamically!

### 4. ML Model Syncing
To export custom ML architectures tracking directly onto the Flutter edge environment structurally mapping limits locally:
```bash
python manage.py train_fusion_scorer
python manage.py train_stroke_classifier
python manage.py export_models
```
*Copy `.onnx` outputs immediately into Flutter `assets/models/` tracking logic seamlessly natively!*
