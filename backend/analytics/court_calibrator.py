import cv2
import numpy as np

class CourtCalibrator:
    # ITF Standard Tennis Court (23.77m x 10.97m)
    # Using centimeters for precision (2377 x 1097)
    COURT_TEMPLATE_CM = np.float32([
        [0, 0],         # Far-left corner
        [1097, 0],      # Far-right corner
        [1097, 2377],   # Near-right corner
        [0, 2377],      # Near-left corner
    ])

    def __init__(self):
        super().__init__()

    def detect_court_corners(self, frame) -> np.ndarray:
        # 1. Image preprocessing
        gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)
        blur = cv2.GaussianBlur(gray, (5, 5), 0)
        _, thresh = cv2.threshold(blur, 200, 255, cv2.THRESH_BINARY)
        
        edges = cv2.Canny(thresh, 50, 150)
        lines = cv2.HoughLinesP(edges, 1, np.pi / 180, 100, minLineLength=100, maxLineGap=20)
        
        if lines is None:
            return None
            
        horizontals = []
        verticals = []
        
        # 2. Segregate by angle
        for line in lines:
            x1, y1, x2, y2 = line[0]
            angle = np.abs(np.arctan2(y2 - y1, x2 - x1) * 180.0 / np.pi)
            if angle < 20 or angle > 160:
                horizontals.append((x1, y1, x2, y2))
            elif 70 < angle < 110:
                verticals.append((x1, y1, x2, y2))
                
        # To get exactly 4 intersections, we need exactly 2 dominant horizontals and 2 dominant verticals.
        # This is a rigorous clustering implementation. 
        def get_dominant_lines(line_list, is_horizontal):
            if len(line_list) < 2: return []
            
            # Sort by Y if horizontal, X if vertical
            sort_idx = 1 if is_horizontal else 0
            line_list.sort(key=lambda l: l[sort_idx])
            
            # Simple clustering
            clusters = []
            curr = [line_list[0]]
            for l in line_list[1:]:
                # If distance within 50px, group them
                if abs(l[sort_idx] - curr[-1][sort_idx]) < 50:
                    curr.append(l)
                else:
                    clusters.append(curr)
                    curr = [l]
            clusters.append(curr)
            
            # Return top 2 longest clusters (or just first/last)
            if len(clusters) < 2: return []
            
            # Extreme boundaries (top/bottom or left/right lines)
            l1 = np.mean(clusters[0], axis=0)
            l2 = np.mean(clusters[-1], axis=0)
            return [l1, l2]
            
        dom_h = get_dominant_lines(horizontals, True)
        dom_v = get_dominant_lines(verticals, False)
        
        if len(dom_h) != 2 or len(dom_v) != 2:
            return None
            
        corners = []
        # Calculate intersections
        for h in dom_h:
            for v in dom_v:
                # Line 1
                x1, y1, x2, y2 = h
                # Line 2
                x3, y3, x4, y4 = v
                
                denom = (x1 - x2)*(y3 - y4) - (y1 - y2)*(x3 - x4)
                if denom != 0:
                    px = ((x1*y2 - y1*x2)*(x3 - x4) - (x1 - x2)*(x3*y4 - y3*x4)) / denom
                    py = ((x1*y2 - y1*x2)*(y3 - y4) - (y1 - y2)*(x3*y4 - y3*x4)) / denom
                    corners.append((px, py))
                    
        if len(corners) != 4:
            return None
            
        # Sort corners: TL, TR, BR, BL
        center_x = np.mean([c[0] for c in corners])
        center_y = np.mean([c[1] for c in corners])
        
        ordered = np.zeros((4, 2), dtype=np.float32)
        for c in corners:
            if c[0] < center_x and c[1] < center_y: ordered[0] = c
            elif c[0] > center_x and c[1] < center_y: ordered[1] = c
            elif c[0] > center_x and c[1] > center_y: ordered[2] = c
            else: ordered[3] = c
            
        return ordered

    def compute_homography(self, frame) -> np.ndarray:
        corners_px = self.detect_court_corners(frame)
        if corners_px is None or len(corners_px) < 4:
            return None
        
        H, _ = cv2.findHomography(corners_px, self.COURT_TEMPLATE_CM)
        return H

    def pixels_to_meters(self, pixel_point, H) -> tuple:
        if H is None:
            return None
            
        pt = np.array([[[pixel_point[0], pixel_point[1]]]], dtype=np.float32)
        court_pt = cv2.perspectiveTransform(pt, H)
        court_x_cm, court_y_cm = court_pt[0][0]
        
        return (court_x_cm / 100.0, court_y_cm / 100.0)

    def classify_player_zone(self, court_point_cm) -> dict:
        if court_point_cm is None:
            return {"zone": "NA"}
            
        court_x, court_y = court_point_cm
        side = 'left' if court_x < 548 else 'right'
        
        depth = 'net_zone'
        if court_y > 1900:
            depth = 'near_baseline'
        elif court_y > 1188:
            depth = 'near_service'
            
        half = 'near_side' if court_y > 1188 else 'far_side'
        
        return {
            'side': side,
            'depth': depth,
            'court_half': half,
            'coordinates_cm': (court_x, court_y)
        }
