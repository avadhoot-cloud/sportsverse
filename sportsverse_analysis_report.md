# TennisIQ Technical Analysis Report

This document provides a comprehensive technical breakdown of the existing TennisIQ application architecture, including backend logic, frontend mechanics, machine learning pipelines, and critical areas for improvement.

---

## 1. System Architecture Overview

The system operates on a client-server architecture utilizing a **Flutter** mobile application for the frontend and a **Django / Django REST Framework (DRF)** application for the backend. 

### Core Interactions:
- **Mobile Client:** Handles local video capture, Bluetooth Low Energy (BLE) payloads (currently stubbed logic), and data visualization. 
- **API Layer:** The Django backend exposes endpoints to upload video data asynchronously and log IMU (Inertial Measurement Unit) smartwatch telemetry.
- **ML Pipeline:** Deep learning models and classical computer vision heuristics run iteratively within the backend's Python environment to translate pixel tracking and accelerometer sequences into structured match analytics.

---

## 2. Frontend Analysis

### Frameworks & Ecosystem
- **Framework:** Flutter
- **State Management:** Riverpod (`flutter_riverpod`)
- **Routing:** GoRouter (`go_router`)
- **Networking:** Dio
- **Charting/Visualizations:** FL Chart (`fl_chart`)

### Frontend Interactions
- **Video Handlers:** Video uploads utilize `file_picker`, directly wrapping multipart requests via Dio's `FormData`. Uploads report real-time chunk progress accurately back to the UI state.
- **Workflow State:** After an upload is confirmed, the router forwards to a video processing screen which effectively functions as an active polling loop against the backend until processing concludes.

### Hardcoded & Static Configurations
The most critical frontend anomaly lies within `SessionDetailScreen`:
- **Completely Decoupled Presentation:** Despite hitting real backend logic during uploads, the UI never retrieves the results. The `SessionDetailScreen` is **100% hardcoded**. 
- **Mocked Stats:** Metrics like `142 Strokes`, `1.2 km Distance`, and distribution arrays (e.g., Forehands 65, Backhands 42) are written statically into the charts.
- **Mocked AI Insights:** The generative tips (e.g., *"Your forehand consistency is dropping..."*) are permanently embedded string variables.

---

## 3. Backend Analysis

### Core Framework
- **Framework:** Django with Django Rest Framework (DRF)
- **Primary Apps:** `sessions_log` (handles domain models) and `analytics` (handles the analysis engines and algorithms).

### Hardcoded Logic & Assumptions
- **Strokes Categorization:** Every stroke detected by the video analyzer is statically labeled as `'forehand'` with an arbitrary confidence of `0.85`.
- **Metrics Assumptions:** Key insights are completely stubbed on the server side: 
  - `avg_reaction_time_ms` defaults to `250.0`
  - `shot_accuracy_pct` defaults to `75.0`
  - `unforced_errors` defaults to `2`
- **Distance Calculus:** Total Court Distance relies heavily on a pseudo-calibration assumption (`0.015m per pixel`) rather than true 3D camera projection logic.

---

## 4. Machine Learning & Video Processing

The ML mechanics operate purely inside `analytics/video_analyzer.py` and are initiated on a background thread.

### Frameworks & Models Used
- **Ultralytics YOLO (yolov8n):** nano-version utilized for base `[0] 'person'` bounding box detection tracking the player.
- **MediaPipe Pose (`mp.solutions.pose`):** Used on top of the YOLO bounding box crop to extract localized XYZ landmarks (skeletal mapping).
- **OpenCV (`cv2`):** Handles video stream parsing, bounding, sub-sampling, grayscale frame transformations, frame differences, and background subtraction. OpenCV `HoughCircles` is mapped specifically to detect fast-moving ball trajectories.
- **SciPy:** Uses Euclidean distances for velocity mappings.

### Inference Pipeline step-by-step
1. Scale dimensions to 720p widths dynamically to conserve compute.
2. Calculate background diff via grayscale comparison between the current and previous frame. Extract standard Hough Circles. 
3. Perform YOLOv8 inference for player bounding boxes. 
4. Crop to player -> perform MediaPipe skeleton analysis. 
5. Track specific delta movements on Landmark `[16]` (Right Wrist).

---

## 5. Data Flow & Pipeline

1. **Input:** Mobile sends `multipart/form-data` chunks to `/api/video/upload/`.
2. **Preprocessing:** Django caches this to a temporary local media path.
3. **Execution Initialization:** View instantiates an asynchronous `threading.Thread` bounding the local Python scope to invoke the `MatchAnalyzer`.
4. **Analysis Iteration:** The system runs the ML pipeline loops arrayed above, sequentially appending metrics per frame.
5. **Post-Processing (Logic Heuristics):** Processes raw arrays of distances -> distills them via distance deltas logic to isolate 'swing' peaks. 
6. **Storage:** Saves arrays directly to PostgreSQL/SQLite via `StrokeEvent` and `VideoMetrics` Object Relational Mappings (ORM).
7. **Delivery:** Frontend polls `video_status` -> Backend returns completion dict -> Frontend pushes static UI.

---

## 6. Feature & Parameter Extraction

### Real/Calculated Values
- **`total_dist_px` (Court Movement):** Calculated legitimately using cumulative Euclidean deltas between frame-by-frame YOLO bounding box centers.
- **Stroke Timestamp events:** Calculated using rapid Euclidean shifts in the `Landmark[16]` Right Wrist coordinates over a 3-frame delay bounds metric (speed peaks).

### Approximations & Weak Heuristics
- **Stroke Registration Trigger:** Simply looking for acceleration peaks (`accel > 50`) creates massive noise thresholds. Waving, celebrating, or wiping a face can trigger a "stroke" metric.
- **Debounce Tracking:** Employs a crude `1000ms` timestamp block to stop multiple triggers from the same trajectory.
- **Fake Metrics Formats:** Unforced errors, and accuracy are explicitly hardcoded for database persistence.

---

## 7. Error Handling & Edge Cases

### Current Error Handling
- The backend wraps video analysis in a standard `try/except` block, logging exceptions cleanly into the global in-memory tracking dictionary `_processing_queue` under `'status': 'error'`.
- If YOLO drops a detection on a frame, the analyzer seamlessly falls back to the `prev_bbox` variable securely skipping pose calculations gracefully. 

### Critical Weaknesses
- **State Volatility:** Bounding an async loop memory state variable (`_processing_queue`) in a Python dict means if the WSGI/Django web worker restarts, all executing queues evaporate resulting in zombie jobs.
- **Missing Occlusion Safeguarding:** If the right wrist `[16]` drops visibility score below zero, raw NoneTypes are loosely appended to arrays.
- **Device Limitations:** Low FPS inputs instantly corrupt the acceleration time heuristics because velocity logic loops are strictly delta-frame bounds-dependent.

---

## 8. Performance & Bottlenecks

### Bottlenecks Identified
1. **Thread Blocking:** Running intensive deep learning models inside Python standard threads natively within Django ties up server resources. Global Interpreter Lock (GIL) dependencies might delay other incoming API endpoints.
2. **GPU Availability:** Instantiating new YOLO objects consecutively on generic CPU-based servers will experience latency averaging around 5-10 minutes per standard 30-sec match clip.
3. **Memory Leaks:** Bounding global singletons for IMU processes `_classifier` without strict garbage collection bounds.

---

## 9. Code Quality & Maintainability

### Anti-Patterns
1. Using generic Python `threading.Thread` inside Django views over proper message broker arrays.
2. In-memory `Dictionary` tracking variables for request payloads.
3. Extreme tight-coupling of UI structure inside `session_detail_screen.dart` requiring an entire code rewrite to merge active DB fetches.
4. Redundant manual ML instantiation loops bound per-request. 

---

## 10. Improvement Recommendations

### Architecture Refactoring
- **Adopt Message Brokers:** Transition the `video_upload` endpoint away from `threading.Thread`. Implement **Celery + Redis** (or RabbitMQ) to manage asynchronous task load securely.
- **Adopt WebSockets:** Migrate frontend polling away from looped GET requests to Django Channels (WebSockets) for passive state listening.

### Machine Learning
- **Replace Stroke Classification Heuristics:** Replace simple spatial velocity assumptions with a true lightweight ML model (e.g., 1D-CNN or LSTM mapped to pose coordinates) that can genuinely distinguish a Forehand from a Backhand. 
- **Persist Model Contexts:** Pre-load the YOLOv8 and MediaPipe dependencies in memory on application boot globally on a dedicated ML worker to eliminate instantiation latencies.

### Frontend Scalability
- **Rip out Hardcoded UI:** Update the `SessionDetailScreen` `Riverpod` Provider states to actively execute `dio.client.get('/sessions/{id}')` mapping UI charts to real serialized data structures. 

### Processing Optimization
- Move tracking heuristics away from native python lists toward highly optimized `numpy.array()` logic for wrist arrays before batch-processing to rapidly decrease CPU block wait times.
