from dataclasses import dataclass
import cv2
from .court_calibrator import CourtCalibrator

@dataclass
class ValidationResult:
    accepted: bool
    court_visible: bool
    fps: float
    estimated_height: str
    estimated_distance: str
    angle_valid: bool
    alerts: list[str]
    overlay_guide: bool

class CameraValidator:
    def __init__(self):
        self.calibrator = CourtCalibrator()

    def validate(self, video_path: str) -> ValidationResult:
        alerts = []
        cap = cv2.VideoCapture(video_path)
        if not cap.isOpened():
            return ValidationResult(False, False, 0.0, 'unknown', 'unknown', False, ["Could not open video file."], False)

        fps = cap.get(cv2.CAP_PROP_FPS)
        
        # 1. FPS Check
        if fps < 25:
            alerts.append(f"Video FPS too low. Detected {fps:.1f}fps. Minimum 25fps required for accurate stroke detection.")

        # 2. Sample frames to verify Court visibility
        valid_corners = False
        vanishing_y_px = 0
        total_frames_checked = 0
        height_px = 0
        
        for _ in range(30):
            ret, frame = cap.read()
            if not ret:
                break
                
            if height_px == 0:
                height_px = frame.shape[0]
                
            corners = self.calibrator.detect_court_corners(frame)
            if corners is not None and len(corners) == 4:
                valid_corners = True
                
                # Estimate horizon check (vanishing point Y based on sidelines)
                # corners format from calibrator: [top-left, top-right, bottom-right, bottom-left]
                tl, tr, br, bl = corners
                
                # Simple vanishing line intersection approximation
                # Line 1: (tl, bl), Line 2: (tr, br)
                x1, y1 = tl
                x2, y2 = bl
                x3, y3 = tr
                x4, y4 = br
                
                denom = (x1 - x2) * (y3 - y4) - (y1 - y2) * (x3 - x4)
                if denom != 0:
                    px = ((x1 * y2 - y1 * x2) * (x3 - x4) - (x1 - x2) * (x3 * y4 - y3 * x4)) / denom
                    py = ((x1 * y2 - y1 * x2) * (y3 - y4) - (y1 - y2) * (x3 * y4 - y3 * x4)) / denom
                    vanishing_y_px = py
                
                break # We found a valid frame
            
            total_frames_checked += 1

        cap.release()

        # 3. Validation Logic
        if not valid_corners:
            alerts.append("Court lines unclear — ensure full court is visible.")
            
        angle_valid = True
        estimated_height = 'optimal'
        
        if valid_corners and height_px > 0:
            if vanishing_y_px < height_px * 0.2:
                alerts.append("Camera angle too low — tilt upward slightly.")
                angle_valid = False
                estimated_height = 'too_low'

        accepted = len(alerts) == 0

        return ValidationResult(
            accepted=accepted,
            court_visible=valid_corners,
            fps=fps,
            estimated_height=estimated_height,
            estimated_distance='optimal',
            angle_valid=angle_valid,
            alerts=alerts,
            overlay_guide=not accepted
        )
