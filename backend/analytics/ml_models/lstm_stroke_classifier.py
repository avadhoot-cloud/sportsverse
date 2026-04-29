"""
1D-LSTM Stroke Classifier
=========================
Architecture: 2-layer LSTM over 30-frame MediaPipe landmark windows.
Input shape:  (batch=1, seq=30, features=18)
              6 landmarks × (x, y, z) — landmarks 11-16 (shoulders → wrists)
Output:       5-class softmax → [forehand, backhand, serve, volley, unknown]

Training: Export trained weights via:
    torch.onnx.export(model, dummy, "stroke_lstm.onnx", ...)
    Place stroke_lstm.onnx in:
        backend/analytics/ml_models/weights/stroke_lstm.onnx

Edge note: ball speed is SERVER-ONLY (computed from ball_tracker.pt on Django).
           The Flutter ONNX pipeline only loads stroke_lstm.onnx for on-device
           stroke inference. Ball speed will return null/"NA" in offline sessions.
"""

import os
import numpy as np

# Labels in model output order
STROKE_LABELS = ['forehand', 'backhand', 'serve', 'volley', 'unknown']

# Landmark indices 11-16 (L/R shoulder, L/R elbow, L/R wrist)
LANDMARK_INDICES = [11, 12, 13, 14, 15, 16]
SEQ_LEN = 30
FEATURES = len(LANDMARK_INDICES) * 3  # x, y, z per landmark = 18


class StrokeInferenceEngine:
    """
    Wraps ONNX runtime inference for the trained StrokeLSTM model.
    Falls back gracefully if onnxruntime is unavailable or weights missing.
    """

    def __init__(self):
        weights_path = os.path.join(
            os.path.dirname(__file__), 'weights', 'stroke_lstm.onnx'
        )
        self._session = None
        self._available = False

        if not os.path.exists(weights_path):
            print(
                f"[StrokeInferenceEngine] WARNING: ONNX weights not found at "
                f"{weights_path}. Stroke classification will return 'unknown'."
            )
            return

        try:
            import onnxruntime as ort
            self._session = ort.InferenceSession(weights_path)
            self._available = True
            print("[StrokeInferenceEngine] ONNX model loaded successfully.")
        except ImportError:
            print(
                "[StrokeInferenceEngine] WARNING: onnxruntime not installed. "
                "Run: pip install onnxruntime"
            )

    @property
    def available(self) -> bool:
        return self._available

    def classify(self, window_frames: list) -> dict:
        """
        Classifies a 30-frame landmark window.

        Args:
            window_frames: list of frame_features dicts. Each must contain
                           'pose_landmarks' → list of 33 landmark dicts with
                           keys 'x', 'y', 'z'.
        Returns:
            {'stroke_type': str, 'confidence': float}
        """
        if not self._available or len(window_frames) != SEQ_LEN:
            return {'stroke_type': 'unknown', 'confidence': 0.0}

        matrix = self._build_matrix(window_frames)
        if matrix is None:
            return {'stroke_type': 'unknown', 'confidence': 0.0}

        # ONNX inference — input: (1, 30, 18) float32
        input_name = self._session.get_inputs()[0].name
        logits = self._session.run(
            None, {input_name: matrix.astype(np.float32)}
        )[0]  # shape (1, 5)

        probs = self._softmax(logits[0])
        idx = int(np.argmax(probs))
        return {
            'stroke_type': STROKE_LABELS[idx],
            'confidence': float(round(probs[idx], 4))
        }

    def _build_matrix(self, window_frames: list) -> np.ndarray:
        """
        Returns (1, 30, 18) float32 tensor from 30 frame-feature dicts.
        Returns None if any frame lacks valid landmarks.
        """
        seq = []
        for f in window_frames:
            landmarks = f.get('pose_landmarks')
            if landmarks is None or len(landmarks) < 17:
                # Pad the frame with zeros rather than failing the whole window
                seq.append(np.zeros(FEATURES, dtype=np.float32))
                continue

            row = []
            for idx in LANDMARK_INDICES:
                lm = landmarks[idx]
                row.extend([lm.get('x', 0.0), lm.get('y', 0.0), lm.get('z', 0.0)])

            seq.append(np.array(row, dtype=np.float32))

        arr = np.stack(seq, axis=0)          # (30, 18)
        return arr[np.newaxis, :, :]          # (1, 30, 18)

    @staticmethod
    def _softmax(logits: np.ndarray) -> np.ndarray:
        exp = np.exp(logits - np.max(logits))
        return exp / exp.sum()


class StrokeLSTMArchitecture:
    """
    PyTorch model definition — used for training only.
    After training, export to ONNX via:

        import torch
        from analytics.ml_models.lstm_stroke_classifier import StrokeLSTMArchitecture
        model = StrokeLSTMArchitecture()
        model.load_state_dict(torch.load('stroke_lstm.pt'))
        model.eval()
        dummy = torch.zeros(1, 30, 18)
        torch.onnx.export(
            model, dummy, 'stroke_lstm.onnx',
            input_names=['input'], output_names=['logits'],
            dynamic_axes={'input': {0: 'batch'}}
        )
    """

    @staticmethod
    def build():
        """Returns an nn.Module ready for training."""
        try:
            import torch.nn as nn

            class _Model(nn.Module):
                def __init__(self):
                    super().__init__()
                    self.lstm = nn.LSTM(
                        input_size=FEATURES,
                        hidden_size=128,
                        num_layers=2,
                        batch_first=True,
                        dropout=0.3
                    )
                    self.classifier = nn.Sequential(
                        nn.Linear(128, 64),
                        nn.ReLU(),
                        nn.Dropout(0.3),
                        nn.Linear(64, len(STROKE_LABELS))
                    )

                def forward(self, x):
                    # x: (batch, seq=30, features=18)
                    out, _ = self.lstm(x)
                    last = out[:, -1, :]   # Take final timestep
                    return self.classifier(last)

            return _Model()
        except ImportError:
            raise RuntimeError(
                "PyTorch is required for training. "
                "Install via: pip install torch"
            )
