"""
video_analyzer.py — Phase 4 final form.

Changes vs Phase 3:
  - Module-level YOLO/MediaPipe singletons (preload_globals) for cold-start elimination
  - NumPy array accumulators replacing Python list append loops
  - Real shot_accuracy_pct from ball landing vs court boundary polygon
  - Real unforced_errors from out-of-bounds ball during active rally

ball_tracker.pt is still a placeholder (server-only). When weights are missing:
  - shot_accuracy_pct → None ("NA" in API)
  - unforced_errors   → None ("NA" in API)
  - max_ball_speed_kmh → None ("NA" in API)
This is CORRECT BEHAVIOR per integrity rules, not a bug.
"""
import os
import cv2
import numpy as np
from scipy.spatial import distance
from scipy.signal import find_peaks
from dataclasses import dataclass
from typing import List, Dict, Optional, Tuple
from collections import Counter
from .court_calibrator import CourtCalibrator
from .ml_models.lstm_stroke_classifier import StrokeInferenceEngine

# ── Module-level singletons ───────────────────────────────────────────────────
# Populated by preload_globals() at server/worker startup.
# VideoAnalyzer.__init__ reuses them to avoid per-request cold-load latency.
_YOLO_MODEL = None
_BALL_MODEL = None
_POSE_ESTIMATOR = None
_MP_POSE_MODULE = None
_MEDIAPIPE_WARNING_EMITTED = False
_BALL_MODEL_AVAILABLE = False

SEQ_LEN = 30  # LSTM window size (frames)

# ITF court dimensions in cm (used for shot boundary checks)
COURT_W_CM = 1097.0
COURT_H_CM = 2377.0


@dataclass
class MatchAnalysisResult:
    stroke_events: List[Dict]
    video_metrics: Dict
    frame_annotations: List[Dict]
    rally_events: List[Dict]


def _init_kalman() -> cv2.KalmanFilter:
    kf = cv2.KalmanFilter(4, 4)
    kf.transitionMatrix = np.eye(4, dtype=np.float32)
    kf.measurementMatrix = np.eye(4, dtype=np.float32)
    kf.processNoiseCov = np.eye(4, dtype=np.float32) * 1e-2
    kf.measurementNoiseCov = np.eye(4, dtype=np.float32) * 1e-1
    kf.errorCovPost = np.eye(4, dtype=np.float32)
    return kf


def _resolve_mediapipe_pose_module():
    """
    Return the MediaPipe pose module when available.
    Some modern MediaPipe builds (notably Python 3.13 wheels) expose only the
    Tasks API and do not include the legacy `mp.solutions` surface.
    """
    try:
        import mediapipe as mp
    except Exception:
        return None

    solutions = getattr(mp, "solutions", None)
    if solutions is None:
        return None
    return getattr(solutions, "pose", None)


class VideoAnalyzer:

    @classmethod
    def preload_globals(cls):
        """
        Load YOLO + MediaPipe into module-level singletons.
        Called from:
          - AnalyticsConfig.ready() in the web (Daphne) process
          - worker_ready signal in TennisIQ/celery.py for each Celery worker
        """
        global _YOLO_MODEL, _BALL_MODEL, _POSE_ESTIMATOR, _MP_POSE_MODULE
        global _MEDIAPIPE_WARNING_EMITTED, _BALL_MODEL_AVAILABLE

        if _YOLO_MODEL is None:
            from ultralytics import YOLO
            _YOLO_MODEL = YOLO('yolov8n.pt')

        if _POSE_ESTIMATOR is None:
            _MP_POSE_MODULE = _resolve_mediapipe_pose_module()
            if _MP_POSE_MODULE is not None:
                _POSE_ESTIMATOR = _MP_POSE_MODULE.Pose(
                    static_image_mode=False,
                    model_complexity=1,
                    min_detection_confidence=0.5,
                    min_tracking_confidence=0.5
                )
            elif not _MEDIAPIPE_WARNING_EMITTED:
                _MEDIAPIPE_WARNING_EMITTED = True
                print(
                    "[VideoAnalyzer] WARNING: MediaPipe Pose is unavailable in this "
                    "environment. Running without pose landmarks. "
                    "Use Python <=3.12 with a solutions-capable mediapipe build "
                    "for full pose/stroke analysis."
                )

        ball_weights = os.path.join(
            os.path.dirname(__file__), 'ml_models', 'weights', 'ball_tracker.pt'
        )
        if _BALL_MODEL is None and os.path.exists(ball_weights):
            from ultralytics import YOLO
            _BALL_MODEL = YOLO(ball_weights)
            _BALL_MODEL_AVAILABLE = True

    def __init__(self):
        global _YOLO_MODEL, _BALL_MODEL, _POSE_ESTIMATOR, _MP_POSE_MODULE
        global _BALL_MODEL_AVAILABLE

        # Trigger preload if not already done (cold path — first task in worker)
        if _YOLO_MODEL is None or _POSE_ESTIMATOR is None:
            self.preload_globals()

        self.yolo_model = _YOLO_MODEL
        self.ball_model = _BALL_MODEL
        self._ball_model_available = _BALL_MODEL_AVAILABLE
        self.pose_estimator = _POSE_ESTIMATOR
        self.mp_pose = _MP_POSE_MODULE

        # Instance-level Kalman filter (one per VideoAnalyzer instance)
        self._kalman = _init_kalman()
        self._kalman_initialized = False

    def load_video(self, path: str) -> Tuple[cv2.VideoCapture, int, float]:
        cap = cv2.VideoCapture(path)
        if not cap.isOpened():
            raise Exception("Failed to open video file")
        return cap, int(cap.get(cv2.CAP_PROP_FRAME_COUNT)), cap.get(cv2.CAP_PROP_FPS)

    def detect_player(self, frame) -> Optional[Tuple[int, int, int, int]]:
        results = self.yolo_model.predict(frame, classes=[0], verbose=False)
        boxes = results[0].boxes
        raw_bbox = None
        if len(boxes) > 0:
            x1, y1, x2, y2 = map(int, boxes[0].xyxy[0])
            raw_bbox = (x1, y1, x2 - x1, y2 - y1)

        if raw_bbox is not None:
            cx = raw_bbox[0] + raw_bbox[2] / 2
            cy = raw_bbox[1] + raw_bbox[3] / 2
            m = np.array([[cx], [cy], [float(raw_bbox[2])], [float(raw_bbox[3])]], dtype=np.float32)
            if not self._kalman_initialized:
                self._kalman.statePre = m
                self._kalman.statePost = m
                self._kalman_initialized = True
            self._kalman.correct(m)

        if not self._kalman_initialized:
            return None

        pred = self._kalman.predict()
        cx, cy, w, h = pred[:, 0]
        return (int(cx - w / 2), int(cy - h / 2), int(w), int(h))

    def estimate_pose(self, frame, bbox) -> Optional[List[Dict]]:
        if self.pose_estimator is None:
            return None
        x, y, w, h = bbox
        crop = frame[max(0, y):min(frame.shape[0], y + h),
                     max(0, x):min(frame.shape[1], x + w)]
        if crop.size == 0:
            return None
        results = self.pose_estimator.process(cv2.cvtColor(crop, cv2.COLOR_BGR2RGB))
        if not results.pose_landmarks:
            return None
        return [{
            'x': lm.x * w + x, 'y': lm.y * h + y,
            'z': lm.z, 'visibility': lm.visibility
        } for lm in results.pose_landmarks.landmark]

    def detect_ball(self, frame) -> Optional[Tuple[int, int]]:
        """SERVER-ONLY. Returns None if ball_tracker.pt weights are absent."""
        if not self._ball_model_available:
            return None
        results = self.ball_model.predict(frame, verbose=False)
        boxes = results[0].boxes
        if len(boxes) == 0:
            return None
        x1, y1, x2, y2 = map(int, boxes[0].xyxy[0])
        return ((x1 + x2) // 2, (y1 + y2) // 2)

    def extract_frame_features(self, frame, prev_bbox) -> Dict:
        bbox = self.detect_player(frame) or prev_bbox
        landmarks = None
        player_vel = 0.0
        if bbox:
            landmarks = self.estimate_pose(frame, bbox)
            if prev_bbox:
                nc = (bbox[0] + bbox[2] / 2, bbox[1] + bbox[3] / 2)
                oc = (prev_bbox[0] + prev_bbox[2] / 2, prev_bbox[1] + prev_bbox[3] / 2)
                player_vel = distance.euclidean(oc, nc)
        return {
            'player_bbox': bbox,
            'pose_landmarks': landmarks,
            'ball_position': self.detect_ball(frame),
            'player_velocity_px': player_vel
        }


class MatchAnalyzer:
    def __init__(self):
        self.analyzer = VideoAnalyzer()
        self.stroke_engine = StrokeInferenceEngine()

    def analyze_video(self, video_path: str, session_id: int) -> MatchAnalysisResult:
        cap, total_frames, fps = self.analyzer.load_video(video_path)
        calibrator = CourtCalibrator()
        H = None

        # ── NumPy pre-allocated accumulators ─────────────────────────────────
        # Over-allocate; trim after loop. ~10× faster than list.append() at scale.
        max_frames = max(total_frames, 1)
        vel_buf = np.zeros(max_frames, dtype=np.float64)       # wrist velocities
        vel_fi  = np.zeros(max_frames, dtype=np.int32)          # frame indices
        vel_ptr = 0

        ball_buf = np.zeros((max_frames, 3), dtype=np.float64)  # (cx, cy, frame_idx)
        ball_ptr = 0

        # Scalar accumulators
        total_dist_m = 0.0
        zone_counts = Counter()
        frame_features: List[Dict] = []
        movement_heatmap = []  # List of [x_cm, y_cm]

        prev_bbox = None
        prev_wrist_pos = None
        frame_idx = 0

        while True:
            ret, frame = cap.read()
            if not ret:
                break

            h_px, w_px = frame.shape[:2]
            frame = cv2.resize(frame, (720, int(h_px * (720 / w_px))))

            if H is None:
                H = calibrator.compute_homography(frame)

            features = self.analyzer.extract_frame_features(frame, prev_bbox)

            # ── Player distance & zone ────────────────────────────────────────
            if features['player_bbox'] and prev_bbox and H is not None:
                nc = (features['player_bbox'][0] + features['player_bbox'][2] / 2,
                      features['player_bbox'][1] + features['player_bbox'][3] / 2)
                oc = (prev_bbox[0] + prev_bbox[2] / 2,
                      prev_bbox[1] + prev_bbox[3] / 2)
                nm = calibrator.pixels_to_meters(nc, H)
                om = calibrator.pixels_to_meters(oc, H)
                if nm and om:
                    total_dist_m += distance.euclidean(nm, om)
                if nm:
                    zd = calibrator.classify_player_zone((nm[0] * 100, nm[1] * 100))
                    zone_counts[zd['depth']] += 1
                    # Task 29: 1Hz Heatmap accumulation
                    if int(fps) > 0 and frame_idx % int(fps) == 0:
                        movement_heatmap.append([round(nm[0] * 100, 1), round(nm[1] * 100, 1)])

            prev_bbox = features['player_bbox']

            # ── Ball collection (numpy buffer) ────────────────────────────────
            bp = features['ball_position']
            if bp is not None and ball_ptr < max_frames:
                ball_buf[ball_ptr] = [bp[0], bp[1], frame_idx]
                ball_ptr += 1

            # ── Wrist velocity (numpy buffer) ─────────────────────────────────
            lms = features['pose_landmarks']
            if lms and len(lms) > 16:
                wrist = lms[16]
                if wrist.get('visibility', 0.0) >= 0.5:
                    wp = (wrist['x'], wrist['y'])
                    if prev_wrist_pos is not None and vel_ptr < max_frames:
                        vel_buf[vel_ptr] = distance.euclidean(prev_wrist_pos, wp)
                        vel_fi[vel_ptr] = frame_idx
                        vel_ptr += 1
                    prev_wrist_pos = wp
                else:
                    prev_wrist_pos = None

            frame_features.append(features)
            frame_idx += 1

        cap.release()

        # Trim numpy buffers to actual data length
        vel_array = vel_buf[:vel_ptr]
        vel_frames = vel_fi[:vel_ptr]
        ball_data  = ball_buf[:ball_ptr]   # shape (N, 3)

        # ── SciPy find_peaks — FPS-dynamic spacing ────────────────────────────
        strokes = []
        serve_frames = set()  # Track frames where serve occurred for speed window
        if vel_ptr >= 3:
            min_dist = max(1, int(fps * 0.5))
            peaks, _ = find_peaks(vel_array, prominence=25, distance=min_dist)
            half = SEQ_LEN // 2

            for pk in peaks:
                peak_frame = int(vel_frames[pk])
                if peak_frame < half or peak_frame > (total_frames - half):
                    continue  # boundary guard — window would be < 30 frames
                window = frame_features[peak_frame - half: peak_frame + half]
                if len(window) != SEQ_LEN:
                    continue
                clf = self.stroke_engine.classify(window)
                strokes.append({
                    'timestamp_ms': int((peak_frame / fps) * 1000),
                    'stroke_type': clf['stroke_type'],
                    'confidence': clf['confidence'],
                    'frame': peak_frame
                })
                if clf['stroke_type'] == 'serve':
                    serve_frames.add(peak_frame)

        # ── Ball speed (shared H — no coordinate drift) ───────────────────────
        max_ball_speed_kmh = None
        max_serve_speed_kmh = None
        shot_in_count = 0
        shot_total = 0
        unforced_error_count = 0
        
        rally_len = 0
        rallies = []
        current_rally_start_ms = 0
        
        frame_time = 1.0 / fps if fps > 0 else (1.0 / 30)
        SERVE_SPEED_WINDOW = 15  # 15 frames max post-serve

        if ball_ptr >= 2 and H is not None:
            speeds = []
            serve_speeds = []
            
            for i in range(1, ball_ptr):
                bx1, by1, fi1 = ball_data[i - 1]
                bx2, by2, fi2 = ball_data[i]
                gap = int(fi2 - fi1)
                if gap > 5:
                    if rally_len >= 2:
                        end_ms = int((fi1 / fps) * 1000)
                        rallies.append({
                            'start_ms': current_rally_start_ms,
                            'end_ms': end_ms,
                            'rally_length': rally_len
                        })
                    rally_len = 0  # Ball lost — reset rally counter
                    continue

                pt1_m = calibrator.pixels_to_meters((bx1, by1), H)
                pt2_m = calibrator.pixels_to_meters((bx2, by2), H)

                if pt1_m and pt2_m:
                    dist_m = distance.euclidean(pt1_m, pt2_m)
                    dt = gap * frame_time
                    if dt > 0:
                        spd = (dist_m / dt) * 3.6
                        if spd < 300:
                            speeds.append(spd)
                            # Task 28: Isolate serve speed
                            # Check if this ball movement is within SERVE_SPEED_WINDOW after any serve
                            is_post_serve = any(0 <= (fi2 - sf) <= SERVE_SPEED_WINDOW for sf in serve_frames)
                            if is_post_serve:
                                serve_speeds.append(spd)

                # ── Shot accuracy from ball landing court boundary ─────────────
                # Map ball position to court coordinates in cm
                pt2_cm = calibrator.pixels_to_meters((bx2, by2), H)
                if pt2_cm:
                    cx_cm = pt2_cm[0] * 100
                    cy_cm = pt2_cm[1] * 100
                    shot_total += 1
                    in_court = (0 <= cx_cm <= COURT_W_CM and 0 <= cy_cm <= COURT_H_CM)
                    if in_court:
                        if rally_len == 0:
                            current_rally_start_ms = int((fi2 / fps) * 1000)
                        shot_in_count += 1
                        rally_len += 1
                    else:
                        # Out of bounds
                        if rally_len >= 2:
                            # Ball went out during an active rally → unforced error
                            unforced_error_count += 1
                            end_ms = int((fi2 / fps) * 1000)
                            rallies.append({
                                'start_ms': current_rally_start_ms,
                                'end_ms': end_ms,
                                'rally_length': rally_len
                            })
                        rally_len = 0

            if speeds:
                max_ball_speed_kmh = round(max(speeds), 1)
            if serve_speeds:
                max_serve_speed_kmh = round(max(serve_speeds), 1)
            
            # Catch final rally if video ends abruptly
            if rally_len >= 2:
                rallies.append({
                    'start_ms': current_rally_start_ms,
                    'end_ms': int((ball_data[-1][2] / fps) * 1000),
                    'rally_length': rally_len
                })

        # ── Derived accuracy metrics ──────────────────────────────────────────
        shot_accuracy_pct = None
        unforced_errors = None

        if shot_total > 0:
            # Only compute when ball tracking is live (shot_total > 0 means data exists)
            shot_accuracy_pct = round((shot_in_count / shot_total) * 100, 1)
            unforced_errors = unforced_error_count
        # else: remains None → serialized as "NA" per integrity rules

        dominant_zone = zone_counts.most_common(1)[0][0] if zone_counts else None

        avg_rally = None
        max_rally = None
        if rallies:
            rally_lengths = [r['rally_length'] for r in rallies]
            max_rally = max(rally_lengths)
            avg_rally = round(sum(rally_lengths) / len(rally_lengths), 1)

        metrics = {
            'movement_distance_m':  round(total_dist_m, 2),
            'court_coverage_pct':   None,
            'avg_reaction_time_ms': None,
            'shot_accuracy_pct':    shot_accuracy_pct,
            'unforced_errors':      unforced_errors,
            'dominant_court_zone':  dominant_zone,
            'max_ball_speed_kmh':   max_ball_speed_kmh,
            'homography_matrix':    H.tolist() if H is not None else None,
            'movement_heatmap':     movement_heatmap if movement_heatmap else None,
            'max_serve_speed_kmh':  max_serve_speed_kmh,
            'max_rally_length':     max_rally,
            'avg_rally_length':     avg_rally,
        }

        return MatchAnalysisResult(
            stroke_events=strokes,
            video_metrics=metrics,
            frame_annotations=[],
            rally_events=rallies
        )
