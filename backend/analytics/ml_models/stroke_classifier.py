import os
import joblib
import numpy as np
from django.conf import settings

class StrokeClassifier:
    def __init__(self):
        self.model_path = os.path.join(settings.MEDIA_ROOT, 'models', 'stroke_classifier.pkl')
        self.model = None

    def load_model(self):
        if os.path.exists(self.model_path):
            self.model = joblib.load(self.model_path)
            return True
        return False

    def extract_features(self, imu_window):
        """
        imu_window: List of dictionaries mapping standard 50-batch lengths
        Requires specific parsing assuming exactly 50 samples evaluating 1 second.
        """
        if len(imu_window) == 0:
            return np.zeros(5)

        accel_mags = []
        angular_vels = []
        gyro_z_vals = []
        
        for sample in imu_window:
            # Recompute magnitudes natively over vectors
            a_mag = np.sqrt(sample['accelX']**2 + sample['accelY']**2 + sample['accelZ']**2)
            g_mag = np.sqrt(sample['gyroX']**2 + sample['gyroY']**2 + sample['gyroZ']**2)
            accel_mags.append(a_mag)
            angular_vels.append(g_mag)
            gyro_z_vals.append(sample['gyroZ'])
            
        accel_mags = np.array(accel_mags)
        angular_vels = np.array(angular_vels)
        
        peak_accel_mag = np.max(accel_mags)
        mean_accel_mag = np.mean(accel_mags)
        peak_angular_vel = np.max(angular_vels)
        wrist_rotation_range = np.max(gyro_z_vals) - np.min(gyro_z_vals)
        
        # FFT to find dominant frequency 
        fft_result = np.fft.fft(accel_mags)
        freqs = np.fft.fftfreq(len(accel_mags), d=1/50.0) # 50Hz assumed
        positive_freqs = freqs[freqs > 0]
        pos_fft_mags = np.abs(fft_result[freqs > 0])
        if len(pos_fft_mags) > 0:
            dominant_freq = positive_freqs[np.argmax(pos_fft_mags)]
        else:
            dominant_freq = 0.0

        return np.array([peak_accel_mag, mean_accel_mag, peak_angular_vel, dominant_freq, wrist_rotation_range])

    def predict(self, imu_window):
        if self.model is None:
            loaded = self.load_model()
            if not loaded:
                return 'unknown', 0.0

        features = self.extract_features(imu_window).reshape(1, -1)
        
        # Fallback bounding protecting against weak tensors that clearly aren't sports strokes
        if features[0][0] < 1.5: 
            return 'unknown', 0.99
            
        probabilities = self.model.predict_proba(features)[0]
        mapped_classes = self.model.classes_
        
        max_idx = np.argmax(probabilities)
        stroke_type = mapped_classes[max_idx]
        confidence = float(probabilities[max_idx])
        
        # Simple thresholding logic preventing hallucinated assumptions
        if confidence < 0.40:
            return 'unknown', confidence
            
        return stroke_type, confidence
