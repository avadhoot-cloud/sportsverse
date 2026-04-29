# TennisIQ — Master Technical Analysis & Implementation Roadmap
*Grounded analysis based on README.md, progress_track.md, and sportsverse_analysis_report.md*

---

## STAGE 1: Current System Deep Analysis

### 1.1 Frontend (Flutter) — Implementation Status

| Component | Status | Notes |
|---|---|---|
| Riverpod state management | ✅ Implemented | Async providers wired to upload flow |
| GoRouter navigation | ✅ Implemented | Routes to processing screen post-upload |
| Dio multipart video upload | ✅ Implemented | Chunk-progress reported back to UI |
| Upload polling loop | ✅ Implemented | Polls `/api/video/upload/` until completion |
| `SessionDetailScreen` data binding | ❌ Missing | 100% hardcoded — never calls backend |
| FL Chart visualizations | ⚠️ Partial | Charts render but on static data only |
| `SyncOverlay` audio-visual pings | ✅ Implemented | Per progress_track §13 |
| Fusion Intelligence tab (LineChart) | ✅ Implemented | Per progress_track §13 — but fed by mocked data |
| `onnxruntime_flutter` edge inference | ✅ Implemented | Per progress_track §15 |
| `sqflite` offline queue | ✅ Implemented | Per progress_track §15 |
| `LocalDbHelper` | ✅ Implemented | Per progress_track §15 |
| Global exception handler | ✅ Implemented | Per progress_track §15 |
| BLE smartwatch telemetry | ⚠️ Stubbed | Report §2 states BLE payloads are "currently stubbed logic" |
| Real-time coach insights display | ❌ Missing | Currently hardcoded strings |

**Hardcoded values confirmed in `SessionDetailScreen`:**
- `142 Strokes` (static integer)
- `1.2 km Distance` (static string)
- `Forehands: 65`, `Backhands: 42` (static distribution arrays)
- AI coaching tips (permanently embedded string variables, e.g., *"Your forehand consistency is dropping..."*)

---

### 1.2 Backend (Django/DRF) — Implementation Status

| Component | Status | Notes |
|---|---|---|
| Django + DRF REST layer | ✅ Implemented | `sessions_log` + `analytics` apps |
| Gunicorn multi-core config | ✅ Implemented | `gunicorn.conf.py` per §15 |
| Nginx upstream proxy | ✅ Implemented | `nginx.conf` per §15 |
| `django-ratelimit` `@100/m` | ✅ Implemented | POST DDoS protection |
| Background `threading.Thread` for ML | ✅ Implemented | But architecturally fragile |
| `_processing_queue` in-memory dict | ⚠️ Fragile | Volatile on worker restart = zombie jobs |
| `StrokeEvent` / `VideoMetrics` ORM | ✅ Implemented | Saves to PostgreSQL/SQLite |
| `/api/health/` | ✅ Implemented | Status checks |
| `/api/analytics/progress/` | ✅ Implemented | `TruncWeek` DB aggregation |
| `/api/analytics/summary/` | ✅ Implemented | Per §14 |
| `/api/coach/insights/{session_id}/` | ✅ Implemented | Heuristic coaching endpoint |
| `/api/video/upload/` | ✅ Implemented | Multipart async |
| Celery/Redis task queue | ❌ Missing | Using raw threading instead |
| Django Channels WebSockets | ❌ Missing | Using polling instead |

**Hardcoded values confirmed in backend:**
- Every stroke statically labeled `'forehand'`, confidence = `0.85`
- `avg_reaction_time_ms` hardcoded to `250.0`
- `shot_accuracy_pct` hardcoded to `75.0`
- `unforced_errors` hardcoded to `2`
- Court distance calibration: `0.015m per pixel` (pseudo-calibration, not true 3D projection)

---

### 1.3 ML Pipeline — Implementation Status

| Model/Library | Purpose | Status |
|---|---|---|
| YOLOv8n (`ultralytics`) | Player bounding box detection | ✅ Active |
| MediaPipe Pose | XYZ skeleton landmark extraction (33 landmarks) | ✅ Active |
| OpenCV (`cv2`) | Frame parsing, grayscale diff, HoughCircles ball detection, sub-sampling | ✅ Active |
| SciPy | Euclidean velocity mappings | ✅ Active |
| `GradientBoostingRegressor` | Match Intensity scoring (Fusion Engine) | ✅ Trained via management command |
| Stroke classifier | `train_stroke_classifier` management command | ✅ Trained |
| `skl2onnx` export | Convert Pickles → `.onnx` for Flutter edge | ✅ Implemented |
| `onnxruntime_flutter` | On-device inference | ✅ Implemented |
| True stroke classification (Forehand/Backhand/Serve) | Actual shot-type ML | ❌ Missing — all forced to 'forehand' |
| Ball spin/trajectory estimation | Physics model | ❌ Missing |
| 1D-CNN or LSTM for wrist kinematics | Sequence-based stroke recognition | ❌ Missing |

**Current Inference Pipeline (Confirmed):**
```
Video input (mobile multipart)
  → Scale to 720p width
  → Grayscale frame diff → HoughCircles (ball proxy)
  → YOLOv8n → player bounding box
  → Crop to bounding box → MediaPipe Pose (33 landmarks)
  → Track Landmark[16] (Right Wrist) delta movements
  → Euclidean velocity peaks → stroke detection trigger (accel > 50)
  → 1000ms debounce block
  → Save StrokeEvent + VideoMetrics to DB
  → Frontend polls → returns static UI (BROKEN LINK)
```

---

### 1.4 Error Handling — Current vs Gaps

| Scenario | Current Handling | Gap |
|---|---|---|
| General ML exception | try/except → `_processing_queue['status'] = 'error'` | Memory-only; lost on restart |
| YOLO frame dropout | Falls back to `prev_bbox` | ✅ Handled |
| Wrist `Landmark[16]` NoneType | Raw `None` appended to arrays | ❌ Not sanitized — crashes downstream numpy ops |
| Worker restart during job | All queues evaporate | ❌ No persistent job state |
| Low FPS input | Velocity heuristics silently corrupted | ❌ No FPS floor validation |
| BLE payload missing | No fallback defined (stubbed) | ❌ Unknown failure mode |
| Camera angle/quality | No validation at all | ❌ Entirely missing |
| Occlusion (multi-player frame) | No handling | ❌ Entirely missing |

---

## STAGE 2: Market Benchmarking

### 2.1 SwingVision

**Parameters Calculated:**
- Ball speed (km/h) per shot, measured via optical flow between frames
- Shot placement map (exact ball bounce coordinates via homography)
- Spin estimation (topspin/slice/flat) using ball trajectory curvature + rotation via high-speed frame differencing
- Shot type classification (Forehand/Backhand/Serve/Volley/Overhead) via CNN on pose + ball trajectory
- Rally length and shot count per rally
- In/Out detection (line-call accuracy)
- First/Second serve % and placement zones
- Unforced errors (real detection, not hardcoded)
- Player movement heatmap

**Computation Approach:**
- 60fps+ iPhone camera as primary sensor; higher FPS = reliable ball tracking
- Homography matrix to project court pixel coordinates → real-world meters (proper 3D calibration, not `0.015m/pixel`)
- Dedicated on-device CoreML models for ball detection (custom fine-tuned, not HoughCircles)
- Pose estimation for stroke classification
- Court line detection (Hough line transform + perspective transform) for calibration

**Error Handling:**
- Camera setup validation enforced before recording begins (distance, angle, height checks)
- Ball tracking confidence scoring — low confidence frames are dropped, not hallucinated
- Occlusion recovery via Kalman filter prediction
- Frame-rate floor: refuses to process sub-30fps clips

**Gaps vs TennisIQ:**
- Ball speed: TennisIQ lacks this entirely
- Shot placement: TennisIQ has no homography
- Spin: TennisIQ has no spin model
- In/Out: TennisIQ has no court boundary logic
- Real stroke classification: TennisIQ hardcodes 'forehand'

---

### 2.2 PlaySight SmartCourt

**Parameters Calculated:**
- Multi-camera 3D ball trajectory reconstruction
- True spin rate (RPM) via dedicated high-speed cameras
- Player positional tracking (X/Y court coordinates at all times)
- Shot power index derived from ball deceleration curve
- Service box targeting zones with heat accumulation
- Real-time biomechanical efficiency scoring
- Opponent response time and positioning analytics

**Computation Approach:**
- Fixed multi-camera array (4–8 cameras) with known extrinsic calibration matrices
- Stereo triangulation for 3D ball localization
- Dedicated GPU server for real-time inference (not mobile)
- Deep learning tracking models (proprietary)
- PostgreSQL time-series analytics backend

**Error Handling:**
- Hardware-level redundancy (multiple cameras; one failure = others compensate)
- Confidence-weighted 3D reconstruction — drops frames below threshold
- Manual calibration validation before session starts
- Separate ball-loss detection state vs occlusion state

**Gaps vs TennisIQ:**
- Multi-camera 3D: TennisIQ is single-camera monocular only
- True spin RPM: Impossible without high-speed hardware
- Fixed court calibration: TennisIQ uses pseudo-pixel calibration

---

### 2.3 Hawk-Eye

**Parameters Calculated:**
- Ball tracking to millimeter precision (ITF certified)
- Ball bounce prediction (probabilistic cone visualization)
- Full 3D trajectory reconstruction for every shot
- Service speed radar equivalent
- Player tracking (speed, distance covered per point/game/set)
- Shot pattern analysis per match

**Computation Approach:**
- 10+ synchronized high-speed cameras (minimum 340fps)
- Stereo photogrammetry with sub-centimeter calibration
- Kalman filter + physics-based flight models (drag, Magnus force for spin)
- Proprietary DNN for ball re-identification after occlusion

**Error Handling:**
- ITF-mandated < 2.6mm average error or system is disqualified from use
- Mandatory court calibration sequence before every match
- Explicit "tracking lost" state displayed to operators
- Ball re-ID across camera cut-outs

**Note:** Hawk-Eye is broadcast-grade hardware infrastructure, not directly replicable in mobile. However, its architectural patterns (Kalman filtering, explicit tracking-lost states, calibration-first design) are implementable at the software level.

---

## STAGE 3: Gap Analysis & Required Modifications

### 3.1 Critical Gaps Table

| Gap | Severity | Current State | Required Fix |
|---|---|---|---|
| `SessionDetailScreen` hardcoded | 🔴 HIGH | Static mock data displayed | Wire Riverpod provider to `GET /sessions/{id}` |
| Stroke classification broken | 🔴 HIGH | All strokes = 'forehand'/0.85 | Train real CNN/LSTM classifier |
| `avg_reaction_time_ms` hardcoded | 🔴 HIGH | Always 250.0 | Compute from ball-to-movement delta |
| `shot_accuracy_pct` hardcoded | 🔴 HIGH | Always 75.0 | Compute from in/out detection |
| `unforced_errors` hardcoded | 🔴 HIGH | Always 2 | Compute from shot outcome classification |
| No camera validation | 🔴 HIGH | Any video accepted | Implement Stage 5 system |
| `_processing_queue` volatile | 🔴 HIGH | Lost on restart | Migrate to Celery + Redis or DB-persisted state |
| Wrist NoneType not sanitized | 🔴 HIGH | Raw None in arrays | Add visibility score threshold filter |
| Ball tracking (HoughCircles) too noisy | 🟡 MEDIUM | Many false positives | Fine-tune or replace with dedicated ball detector |
| Court homography missing | 🟡 MEDIUM | Pixel pseudo-calibration | Implement court line detection + perspective transform |
| BLE telemetry stubbed | 🟡 MEDIUM | Not functional | Implement actual BLE Bluetooth stack |
| No Kalman filter on tracking | 🟡 MEDIUM | Raw noisy position data | Add Kalman smoothing on bounding box + wrist positions |
| Stroke debounce crude (1000ms flat) | 🟡 MEDIUM | Many missed/double strokes | Replace with adaptive peak detection |
| Polling instead of WebSockets | 🟡 MEDIUM | Inefficient, adds latency | Implement Django Channels |
| numpy arrays not used in ML | 🟡 MEDIUM | Native Python lists | Migrate to numpy throughout analytics pipeline |
| No FPS floor validation | 🟡 MEDIUM | Silent data corruption | Reject or warn on < 30fps input |
| Ball speed calculation missing | 🟡 MEDIUM | Not calculated | Implement via pixel displacement + homography scale |
| No player court position logic | 🟡 MEDIUM | Not implemented | Implement Stage 6 |
| Match Intensity on edge (ONNX) | 🟢 LOW | Implemented | Validate accuracy vs server model |
| Serve vs Rally differentiation | 🟢 LOW | Not separated | Separate serve events from rally strokes |

---

## STAGE 4: Parameter Classification Table

| Parameter | Video-Only | Wearable-Only | Fusion (Video+Sensor) | How Calculated | Current Status |
|---|---|---|---|---|---|
| **Stroke count** | ✅ | ✅ | ✅ | Wrist Landmark[16] velocity peaks (accel > 50) | ⚠️ Noisy — crude threshold |
| **Stroke type** (FH/BH/Serve) | ✅ | ⚠️ Approximate | ✅ Best | CNN on pose sequence OR IMU pattern matching | ❌ Hardcoded 'forehand' |
| **Stroke confidence** | ✅ | ❌ | ✅ | Model softmax output | ❌ Hardcoded 0.85 |
| **Court movement distance (px)** | ✅ | ❌ | ✅ | Cumulative Euclidean delta on YOLO bbox centers | ✅ Calculated (real value) |
| **Court movement distance (m)** | ✅ (with homography) | ❌ | ✅ | Pixel → meter via homography matrix | ❌ Pseudo `0.015m/px` |
| **Player speed (m/s)** | ✅ (with homography) | ❌ | ✅ | Distance delta / time delta | ❌ Not computed |
| **Ball speed (km/h)** | ✅ (60fps+) | ❌ | ✅ | Ball pixel displacement × homography scale / frame time | ❌ Missing entirely |
| **Shot placement (in/out)** | ✅ | ❌ | ✅ | Ball landing coordinate vs court boundary polygon | ❌ Missing entirely |
| **Unforced error rate** | ✅ | ❌ | ✅ | Count of out/net shots where opponent wasn't at fault | ❌ Hardcoded `2` |
| **Shot accuracy %** | ✅ | ❌ | ✅ | In-bounds shots / total shots | ❌ Hardcoded `75.0` |
| **Reaction time** | ✅ (approximate) | ✅ | ✅ Best | Time delta between opponent-side ball bounce → player first-frame movement | ❌ Hardcoded `250.0ms` |
| **Heart rate** | ❌ | ✅ | ✅ | BLE IMU HR sensor direct reading | ❌ BLE stubbed |
| **Acceleration (IMU)** | ❌ | ✅ | ✅ | Accelerometer XYZ magnitude from wearable | ❌ BLE stubbed |
| **Match Intensity score** | ⚠️ | ✅ | ✅ Best | GradientBoostingRegressor on fused features | ✅ Implemented (ONNX edge) |
| **Stroke tempo (strokes/min)** | ✅ | ✅ | ✅ | Stroke timestamp array → rate calculation | ⚠️ Calculable but not exposed |
| **Dominant hand activity** | ❌ | ✅ | ✅ | IMU asymmetry between left/right wrist sensors | ❌ Missing |
| **Court position (side/zone)** | ✅ | ❌ | ✅ | Homography + court line detection | ❌ Missing — Stage 6 target |
| **Rally length** | ✅ | ❌ | ✅ | Consecutive stroke count between serve and point end | ❌ Missing |
| **Fatigue index** | ❌ | ✅ | ✅ Best | HR trend + movement speed decay over time | ❌ Missing |
| **Swing speed** | ❌ | ✅ Best | ✅ | Wrist angular velocity from IMU gyroscope | ❌ BLE stubbed |
| **Ball spin type** | ✅ (high fps only) | ❌ | ✅ | Trajectory curvature deviation from flat-flight physics | ❌ Missing |
| **Serve speed** | ✅ | ❌ | ✅ | Ball pixel velocity post-serve contact | ❌ Missing |

---

## STAGE 5: Camera Validation & Input Quality Control

### 5.1 Validation Parameters & Acceptable Ranges

```
Camera height:         1.8m – 3.5m above ground (above net level)
Distance from baseline: 8m – 20m behind far baseline (full court visible)
Horizontal angle:       ±15° from perpendicular to baseline
Vertical tilt:          -15° to -35° downward tilt (court visible, not sky-heavy)
Minimum FPS:            30fps (25fps absolute floor, log warning at < 60fps)
Minimum resolution:     720p (1080p recommended)
Court coverage:         Both service boxes + at least one baseline must be visible
```

### 5.2 Detection Logic — Pre-Processing Validation

**Step 1 — Frame Sampling**
Sample first 90 frames (3 seconds at 30fps) before accepting the full video for processing.

**Step 2 — Court Line Detection**
```python
def validate_court_visibility(frame):
    gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)
    edges = cv2.Canny(gray, 50, 150, apertureSize=3)
    lines = cv2.HoughLinesP(edges, 1, np.pi/180, threshold=100,
                             minLineLength=100, maxLineGap=10)
    
    horizontal_lines = [l for l in lines if abs(l[0][1] - l[0][3]) < 10]
    vertical_lines   = [l for l in lines if abs(l[0][0] - l[0][2]) < 10]
    
    # Require minimum 4 horizontal + 2 vertical court lines
    return len(horizontal_lines) >= 4 and len(vertical_lines) >= 2
```

**Step 3 — Court Coverage Ratio**
Compute bounding polygon of detected court lines. Court polygon should cover 40–85% of frame area.
- < 40%: Camera too far back or too high → Alert: *"Move camera closer to court"*
- > 85%: Camera too close → Alert: *"Camera too close — full court not visible"*

**Step 4 — Horizon Line Check**
Detect vanishing point of court lines. If vanishing point Y-coordinate < 20% from top of frame, camera is angled too low.
Alert: *"Camera angle too low — tilt upward slightly"*

**Step 5 — FPS Validation**
```python
fps = cap.get(cv2.CAP_PROP_FPS)
if fps < 25:
    return ValidationResult(
        accepted=False,
        reason="Video FPS too low",
        detail=f"Detected {fps:.1f}fps. Minimum 30fps required for accurate stroke detection."
    )
```

### 5.3 Validation Result Model

```python
@dataclass
class ValidationResult:
    accepted: bool
    court_visible: bool
    fps: float
    estimated_height: str       # 'too_low' | 'optimal' | 'too_high'
    estimated_distance: str     # 'too_close' | 'optimal' | 'too_far'
    angle_valid: bool
    alerts: list[str]           # Human-readable guidance
    overlay_guide: bool         # Whether to show visual setup guide in app
```

### 5.4 Frontend Real-Time Feedback Design

**Pre-recording validation screen in Flutter:**
- Live camera feed with overlaid court polygon target (dashed guide lines showing ideal court coverage)
- Color-coded status badges:
  - 🔴 Red = invalid (list of specific alerts)
  - 🟡 Yellow = borderline (warnings)
  - 🟢 Green = "Court detected — ready to record"
- Alert examples surfaced to user:
  - *"Camera too low — raise above net height"*
  - *"Full court not visible — step back 3–5 meters"*
  - *"Tilt camera slightly downward"*
  - *"Low light — ensure good lighting for accurate tracking"*
- "Begin Analysis" button disabled until green state achieved

---

## STAGE 6: Court Position Detection

### 6.1 Approach — Homography-Based Court Mapping

**Step 1: Court Template Definition**
Define a canonical 2D court template with known real-world dimensions (ITF standard: 23.77m × 10.97m doubles).

```python
COURT_TEMPLATE = np.float32([
    [0,    0   ],  # Far-left corner (far baseline)
    [1097, 0   ],  # Far-right corner
    [1097, 2377],  # Near-right corner (near baseline)
    [0,    2377],  # Near-left corner
])
# Units in cm for precision
```

**Step 2: Court Corner Detection in Frame**
Use Hough line detection → find intersections of baseline + sideline pairs → extract 4 court corners in pixel space.

```python
def detect_court_corners(frame):
    edges = cv2.Canny(gray, 50, 150)
    lines = cv2.HoughLinesP(edges, ...)
    # Group into horizontal/vertical families
    # Find intersection points
    corners_px = find_quadrilateral_corners(lines)
    return corners_px  # 4 x (x, y) pixel coordinates
```

**Step 3: Compute Homography Matrix**
```python
H, mask = cv2.findHomography(corners_px, COURT_TEMPLATE)
```

**Step 4: Map Player to Court Coordinates**
```python
def get_player_court_position(bbox_center_px, H):
    pt = np.array([[bbox_center_px]], dtype=np.float32)
    court_pt = cv2.perspectiveTransform(pt, H)
    court_x, court_y = court_pt[0][0]
    return court_x, court_y  # In cm on standard court template
```

**Step 5: Zone Classification**
```python
def classify_court_zone(court_x, court_y):
    side = 'left' if court_x < 548 else 'right'          # Centerline at 548cm
    depth = 'near_baseline' if court_y > 1900 else \
            'near_service' if court_y > 1188 else \
            'net_zone'
    half = 'near_side' if court_y > 1188 else 'far_side'  # Net at 1188cm
    return {
        'side': side,           # 'left' | 'right'
        'depth': depth,         # 'near_baseline' | 'near_service' | 'net_zone'
        'court_half': half,     # 'near_side' | 'far_side'
        'coordinates_cm': (court_x, court_y)
    }
```

### 6.2 Edge Cases & Failure Handling

| Edge Case | Handling Strategy |
|---|---|
| Court corners partially occluded | Use minimum 3 detected corners + RANSAC homography estimation |
| No court lines detected | Set position = `"NA"`, flag frame as invalid, do not append to position array |
| Player outside court boundary | Clamp to court boundary + log as "out of court" event |
| Camera angle too oblique | Reject — homography becomes numerically unstable beyond ±30° off-axis |
| Multiple players in frame | Track player with largest bounding box area; log multi-player warning |
| Line detection confidence < threshold | Fall back to last known valid homography matrix for up to 30 frames |

---

## STAGE 7: Data Integrity Rules

### 7.1 Current Violations (Confirmed from Codebase)

**Backend violations:**
```python
# ❌ VIOLATION 1 — stroke_type
stroke.type = 'forehand'         # Hardcoded — must be model-predicted
stroke.confidence = 0.85         # Hardcoded — must be model softmax output

# ❌ VIOLATION 2 — metrics defaults
metrics.avg_reaction_time_ms = 250.0   # Hardcoded
metrics.shot_accuracy_pct    = 75.0    # Hardcoded
metrics.unforced_errors      = 2       # Hardcoded

# ❌ VIOLATION 3 — distance calibration
dist_m = dist_px * 0.015         # Pseudo-calibration — must use homography
```

**Frontend violations:**
```dart
// ❌ VIOLATION 4 — SessionDetailScreen
final strokeCount = 142;                    // Static
final distanceKm  = '1.2 km';             // Static
final forehands   = 65;                    // Static
final backhands   = 42;                    // Static
final insight     = "Your forehand...";    // Static string
```

### 7.2 Integrity Enforcement Rules

**Rule 1 — No synthetic defaults in computed fields**
```python
# ✅ CORRECT
def get_reaction_time(ball_bounce_frame, player_move_frame, fps):
    if ball_bounce_frame is None or player_move_frame is None:
        return None   # → serialized as "NA" in API response
    return round((player_move_frame - ball_bounce_frame) / fps * 1000, 1)
```

**Rule 2 — Serializer must output "NA" for missing computed values**
```python
class VideoMetricsSerializer(serializers.ModelSerializer):
    def to_representation(self, instance):
        data = super().to_representation(instance)
        for field in COMPUTED_FIELDS:
            if data[field] is None:
                data[field] = "NA"
        return data
```

**Rule 3 — Frontend must respect "NA" strings**
```dart
// ✅ CORRECT
Text(session.strokeCount != null
    ? session.strokeCount.toString()
    : 'N/A')
```

**Rule 4 — Stroke type must come from model inference**
```python
# ✅ CORRECT
stroke_type, confidence = stroke_classifier.predict(pose_sequence)
# confidence below 0.5 → return ("unknown", confidence)
```

**Rule 5 — All computed fields must be traceable to their source**
Add `computation_method` metadata field to API response:
```json
{
  "shot_accuracy_pct": 68.3,
  "shot_accuracy_method": "in_out_detection_homography"
}
```

---

## STAGE 8: Accuracy & Precision Improvements

### 8.1 Stroke Detection Improvement

**Current problem:** Raw `accel > 50` threshold on Landmark[16] — extremely noisy.

**Fix A — Adaptive Peak Detection (Short-term)**
```python
from scipy.signal import find_peaks

wrist_velocities = np.array(wrist_velocity_series)
# Smooth first
smoothed = np.convolve(wrist_velocities, np.ones(5)/5, mode='same')
# Find peaks with minimum prominence
peaks, props = find_peaks(smoothed, prominence=30, distance=15)
# 'distance=15' at 30fps = 500ms minimum between strokes (replaces crude 1000ms block)
```

**Fix B — LSTM Sequence Classifier (Medium-term)**
Replace velocity peak detection with a lightweight 1D-LSTM trained on 30-frame windows of MediaPipe landmarks (particularly landmarks 11–16: shoulder, elbow, wrist chain):
```
Input:  30 frames × 6 landmarks × 3 coords (XYZ) = 30×18 tensor
Output: [forehand, backhand, serve, volley, non-stroke] + confidence
```
Training data: Collect labeled clips or use public tennis pose datasets (e.g., TTNet dataset).

---

### 8.2 Ball Tracking Improvement

**Current problem:** HoughCircles is designed for static circles, not fast-moving tennis balls. Generates massive false positives on court markings.

**Fix — Dedicated Ball Detector**
Options in order of feasibility:
1. **TrackNet** (open-source, purpose-built for tennis ball tracking at 30fps) — drop-in Python model
2. **Fine-tuned YOLOv8n** on tennis ball dataset (Roboflow has public tennis datasets)
3. Background subtraction (MOG2) → contour filtering by area + circularity ratio as baseline improvement

```python
# Quick improvement to existing HoughCircles:
backSub = cv2.createBackgroundSubtractorMOG2(history=50, varThreshold=40)
fg_mask = backSub.apply(frame)
# Apply HoughCircles only on fg_mask, not full frame
# → Eliminates static court marking false positives
```

---

### 8.3 Position Tracking Stability

**Current problem:** Raw YOLO bounding box positions are jittery frame-to-frame.

**Fix — Kalman Filter on Bounding Box**
```python
from filterpy.kalman import KalmanFilter

kf = KalmanFilter(dim_x=4, dim_z=2)
# State: [x, y, vx, vy]
# Measurement: [x, y] (bounding box center)
kf.F = np.array([[1,0,1,0],[0,1,0,1],[0,0,1,0],[0,0,0,1]])  # Constant velocity
kf.H = np.array([[1,0,0,0],[0,1,0,0]])
# ... set Q, R matrices based on expected noise

# Per frame:
kf.predict()
if detection_available:
    kf.update(measurement)
smoothed_position = kf.x[:2]
```

---

### 8.4 Processing Pipeline Optimization

| Optimization | Expected Gain | Implementation |
|---|---|---|
| Pre-load YOLO + MediaPipe on app boot (not per-request) | 80% latency reduction | Django `AppConfig.ready()` → global singletons |
| Migrate Python lists → `numpy.array` in tracking loops | 3–5× speed gain | `np.array(wrist_series)` before batch computation |
| Sub-sample frames (process every 2nd frame at 60fps) | 50% CPU reduction | `if frame_idx % 2 == 0: process()` |
| Celery + Redis for async ML jobs | Eliminates GIL blocking | Replace `threading.Thread` |
| Vectorized Euclidean distances | 10× speed gain | `np.linalg.norm(positions[1:] - positions[:-1], axis=1)` |

---

## FINAL DELIVERABLE A: Detailed Change Plan (Implementation Roadmap)

### Phase 1 — Critical Integrity Fixes (Week 1–2)
**Goal: Eliminate all hardcoded values. Nothing fake leaves the backend.**

1. Remove all hardcoded metric defaults. Replace with `None` → serialized as `"NA"`.
2. Fix `SessionDetailScreen`: wire Riverpod `SessionDetailProvider` to `GET /api/sessions/{id}/` using Dio. Map each field from API response to chart widget.
3. Sanitize Landmark[16] NoneType: add `if landmark.visibility > 0.5` guard before appending to wrist array.
4. Persist job state to DB: create `ProcessingJob` model with fields `session_id`, `status`, `created_at`, `updated_at`. Replace `_processing_queue` dict with DB queries.
5. Add FPS floor validation at video upload entry point — reject with 400 + clear message if FPS < 25.

### Phase 2 — Court Calibration & Camera Validation (Week 3–4)
**Goal: Only valid, calibrated input is processed.**

6. Implement `validate_court_visibility()` as described in Stage 5.
7. Implement `detect_court_corners()` + `cv2.findHomography()` for real pixel-to-meter conversion (replace `0.015m/px`).
8. Implement `classify_court_zone()` player position logic.
9. Add pre-recording validation screen in Flutter with live court detection overlay and green/yellow/red status.
10. Replace court distance calculation to use homography-based real-world coordinates.

### Phase 3 — ML Model Replacement (Week 5–7)
**Goal: Real stroke classification. No more 'forehand' + 0.85.**

11. Collect or source labeled tennis stroke dataset (minimum 500 clips per stroke type).
12. Train 1D-LSTM on 30-frame MediaPipe pose windows (landmarks 11–16) for [forehand, backhand, serve, volley, non-stroke].
13. Replace velocity-peak stroke detection with LSTM inference output.
14. Integrate `TrackNet` or fine-tuned YOLOv8n for ball tracking (replace HoughCircles).
15. Implement ball speed calculation: `speed_kmh = (ball_displacement_px × homography_scale) / frame_time × 3.6`
16. Export new stroke classifier to ONNX via `skl2onnx` / `torch.onnx.export`. Deploy to Flutter assets.
17. Add Kalman filter on YOLO bounding box positions.
18. Replace stroke debounce with SciPy `find_peaks` (prominence + distance parameters).

### Phase 4 — Architecture & Infrastructure (Week 8–10)
**Goal: Production reliability and real-time UX.**

19. Install Celery + Redis. Migrate `threading.Thread` ML jobs to Celery tasks.
20. Add Django Channels WebSocket endpoint for live processing status.
21. Replace Flutter polling loop with WebSocket listener using `web_socket_channel`.
22. Implement BLE telemetry stack: connect Flutter BLE layer to actual smartwatch SDK (e.g., WearOS/watchOS companion).
23. Pre-load YOLO + MediaPipe globals in `AppConfig.ready()`.
24. Migrate all Python list operations in analytics pipeline to numpy arrays.
25. Implement `shot_accuracy_pct` computation from real in/out detection using court boundary polygon.
26. Implement `unforced_errors` computation from shot outcome classifier.

### Phase 5 — Advanced Analytics (Week 11–14)
**Goal: Approach SwingVision-level parameter coverage.**

27. Implement rally length tracking (consecutive strokes between serve and point end).
28. Implement serve detection as a separate stroke class with dedicated serve analytics (speed, placement zone).
29. Implement player movement heatmap (accumulate homography-mapped court positions per session).
30. Implement stroke tempo (strokes/minute) time-series, expose on Fusion Intelligence chart.
31. Implement fatigue index model (HR trend + movement speed decay) once BLE is live.

---

## FINAL DELIVERABLE B: Production-Ready Prompt for Antigravity

---

```
### ANTIGRAVITY IMPLEMENTATION BRIEF — TennisIQ
### Version: 1.0 | Priority: Critical → Medium → Low

---

## PROJECT CONTEXT

TennisIQ is a Flutter + Django sports analytics app.
- Frontend: Flutter (Riverpod, GoRouter, Dio, FL Chart, onnxruntime_flutter, sqflite)
- Backend: Django DRF + Gunicorn + Nginx + PostgreSQL
- ML: YOLOv8n + MediaPipe Pose + OpenCV + SciPy + GradientBoostingRegressor
- Edge: Models exported via skl2onnx to .onnx, run in Flutter via onnxruntime_flutter

---

## CRITICAL CONSTRAINTS

1. NEVER return hardcoded values for any computed metric.
2. If a value cannot be computed → return `null` (Python) / `None` (Dart); serialize as `"NA"` in API responses.
3. ALL stroke type labels must come from ML model inference — never static strings.
4. ALL confidence scores must come from model softmax output — never static floats.
5. Court distance metrics MUST use homography-based calibration — never `0.015m/pixel`.
6. Do NOT break existing endpoints — all changes must be backward compatible or versioned.
7. All DB migrations must be reversible.

---

## TASK 1: Fix SessionDetailScreen (CRITICAL)

File: `frontend/tennisiq_app/lib/screens/session_detail_screen.dart`

CURRENT STATE: All data (strokes, distance, charts, AI insights) is hardcoded.

REQUIRED CHANGES:
- Create `SessionDetailProvider` in Riverpod that calls `GET /api/sessions/{session_id}/`
- Map API response fields to all existing chart widgets and stat displays
- For any field where API returns `"NA"`, display "N/A" in the UI
- Do NOT remove any existing UI widget — only replace data source
- Add loading state (skeleton loader) and error state (retry button)

API RESPONSE CONTRACT (backend must match):
```json
{
  "session_id": "string",
  "stroke_count": integer | "NA",
  "distance_m": float | "NA",
  "stroke_distribution": {
    "forehand": integer | "NA",
    "backhand": integer | "NA",
    "serve": integer | "NA",
    "volley": integer | "NA",
    "unknown": integer | "NA"
  },
  "shot_accuracy_pct": float | "NA",
  "avg_reaction_time_ms": float | "NA",
  "unforced_errors": integer | "NA",
  "match_intensity_score": float | "NA",
  "coaching_insights": [string] | []
}
```

---

## TASK 2: Remove All Backend Hardcoded Values (CRITICAL)

File: `analytics/video_analyzer.py` and related model-saving code

REQUIRED CHANGES:
- Remove: `stroke.type = 'forehand'`  → Replace with: `stroke.type = stroke_classifier.predict(pose_window)`
- Remove: `stroke.confidence = 0.85`  → Replace with: model softmax output float
- Remove: `metrics.avg_reaction_time_ms = 250.0`  → Replace with: `None` until real computation implemented
- Remove: `metrics.shot_accuracy_pct = 75.0`  → Replace with: `None` until real computation implemented  
- Remove: `metrics.unforced_errors = 2`  → Replace with: `None` until real computation implemented
- Remove: `dist_m = dist_px * 0.015`  → Replace with homography-based calculation (see Task 3)

Update `VideoMetricsSerializer` to convert `None` values → `"NA"` strings in output.

---

## TASK 3: Implement Homography-Based Court Calibration (HIGH)

File: Create `analytics/court_calibrator.py`

REQUIRED:
```python
class CourtCalibrator:
    COURT_TEMPLATE_CM = np.float32([...])  # ITF standard 2377×1097cm

    def detect_court_corners(self, frame) -> np.ndarray | None:
        # Use Canny + HoughLinesP
        # Return 4 corner points in pixel space
        # Return None if < 4 corners found with confidence

    def compute_homography(self, frame) -> np.ndarray | None:
        # Call detect_court_corners
        # Call cv2.findHomography(corners_px, COURT_TEMPLATE_CM)
        # Return H matrix or None

    def pixels_to_meters(self, pixel_point, H) -> tuple[float, float] | None:
        # Apply perspective transform
        # Return (x_cm, y_cm) tuple

    def classify_player_zone(self, court_point_cm) -> dict:
        # Return {side, depth, court_half, coordinates_cm}
        # Return {"zone": "NA"} if court_point is None
```

Integrate into `MatchAnalyzer`: compute H matrix once per video (use first 30 stable frames). Store H matrix in `VideoMetrics` as JSON field. Use for all distance calculations.

---

## TASK 4: Fix Wrist Landmark NoneType Bug (CRITICAL)

File: `analytics/video_analyzer.py`

CURRENT STATE: Raw `None` appended to wrist velocity arrays when landmark visibility is low.

REQUIRED FIX:
```python
# Before appending landmark data:
RIGHT_WRIST = 16
landmark = results.pose_landmarks.landmark[RIGHT_WRIST]
if landmark.visibility < 0.5:
    continue  # Skip frame — do NOT append None
wrist_positions.append((landmark.x, landmark.y, landmark.z))
```

---

## TASK 5: Replace _processing_queue Dict with DB Model (CRITICAL)

REQUIRED:
- Create Django model `ProcessingJob`:
  ```
  session_id (FK)
  status: CharField choices=['pending','processing','completed','error']
  error_message: TextField(null=True)
  created_at, updated_at: auto timestamps
  ```
- All writes to `_processing_queue` → replace with `ProcessingJob.objects.update_or_create()`
- All reads from `_processing_queue` → replace with `ProcessingJob.objects.get(session_id=id)`
- Generate and run DB migration

---

## TASK 6: Implement Camera Validation System (HIGH)

File: Create `analytics/camera_validator.py`

REQUIRED — `CameraValidator.validate(video_path) -> ValidationResult`:
```python
@dataclass
class ValidationResult:
    accepted: bool
    fps: float
    court_visible: bool
    alerts: list[str]   # Human-readable strings e.g. "Camera too low"

def validate(video_path) -> ValidationResult:
    # 1. Check FPS >= 25 (reject below 25, warn below 30)
    # 2. Sample first 90 frames
    # 3. Run court line detection (Canny + HoughLinesP)
    # 4. Count horizontal/vertical court lines
    # 5. Check court polygon coverage ratio (40–85% of frame)
    # 6. Check vanishing point Y position (angle check)
    # Return ValidationResult
```

Integrate at `/api/video/upload/` entry point: if `ValidationResult.accepted == False`, return HTTP 422 with `alerts` list. Do not start ML processing.

Flutter: Display `ValidationResult.alerts` in pre-upload screen as warning cards.

---

## TASK 7: Improve Stroke Detection Accuracy (HIGH)

File: `analytics/video_analyzer.py`

CURRENT STATE: `if accel > 50: register_stroke()` — too noisy.

REQUIRED:
```python
from scipy.signal import find_peaks
import numpy as np

# After collecting wrist_velocities list:
velocities = np.array(wrist_velocities)
smoothed = np.convolve(velocities, np.ones(5)/5, mode='same')
peaks, _ = find_peaks(smoothed, prominence=30, distance=int(fps * 0.5))
# peaks contains frame indices of stroke events
# Replace the accel > 50 + 1000ms debounce block with this
```

Remove the crude `1000ms` flat debounce. The `distance` parameter in `find_peaks` provides adaptive debounce based on actual FPS.

---

## TASK 8: Persist ML Models as Globals on Boot (MEDIUM)

File: `analytics/apps.py`

REQUIRED:
```python
class AnalyticsConfig(AppConfig):
    def ready(self):
        from analytics.ml_models import ModelRegistry
        ModelRegistry.load_all()  # Loads YOLO, MediaPipe, stroke classifier once
```

Create `analytics/ml_models.py`:
```python
class ModelRegistry:
    _yolo = None
    _pose = None
    _stroke_classifier = None

    @classmethod
    def load_all(cls):
        cls._yolo = YOLO('yolov8n.pt')
        cls._pose = mp.solutions.pose.Pose(...)
        cls._stroke_classifier = load_onnx_model('stroke_classifier.onnx')
```

Replace per-request model instantiation throughout `video_analyzer.py` with `ModelRegistry._yolo`, etc.

---

## TASK 9: Migrate to Celery + Redis (MEDIUM)

REQUIRED:
- Add to requirements: `celery`, `redis`, `django-celery-results`
- Create `tennisiq/celery.py` with standard Celery app setup
- Create `analytics/tasks.py`:
  ```python
  @shared_task(bind=True)
  def analyze_video_task(self, session_id, video_path):
      # Move all MatchAnalyzer logic here
      # Update ProcessingJob status via DB (not _processing_queue)
  ```
- In `/api/video/upload/` view: replace `threading.Thread(target=...).start()` with `analyze_video_task.delay(session_id, video_path)`
- Add `CELERY_BROKER_URL = 'redis://localhost:6379/0'` to settings

---

## TASK 10: Replace Polling with WebSocket (MEDIUM)

REQUIRED:
- Add `channels` and `channels_redis` to requirements
- Create Django Channels consumer for processing status
- In Flutter: replace polling `Timer.periodic` with `WebSocketChannel` connection
- On Celery task completion: send WebSocket message to session-specific channel group
- Flutter consumer updates UI state on message receipt

---

## TASK 11: Migrate Analytics to NumPy (MEDIUM)

File: `analytics/video_analyzer.py`

For every Python list accumulating numeric data:
- `wrist_positions = []` → after collection: `wrist_positions = np.array(wrist_positions)`
- `bbox_centers = []` → after collection: `bbox_centers = np.array(bbox_centers)`
- All distance calculations: `np.linalg.norm(positions[1:] - positions[:-1], axis=1).sum()`
- All velocity calculations: vectorized numpy operations, not Python loops

---

## OUTPUT REQUIREMENTS

For each task completed:
1. Show the exact file(s) modified
2. Show before/after code diff for all changes
3. Confirm no hardcoded values remain in modified files
4. Confirm all new computed fields return `None`/`"NA"` when data unavailable
5. For any DB model changes: include full migration file

Do not skip any task. Do not combine tasks silently. Complete in the order listed above.
Priority order: Tasks 1–5 must complete before Tasks 6–11 begin.
```

---

*End of TennisIQ Master Analysis Report*
*Generated from: README.md, progress_track.md, sportsverse_analysis_report.md*
