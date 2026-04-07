import os
import joblib
import numpy as np
from django.conf import settings

class FusionScorer:
    def __init__(self):
        self.model_path = os.path.join(settings.MEDIA_ROOT, 'models', 'fusion_scorer.pkl')
        self.model = None

    def load_model(self):
        if os.path.exists(self.model_path):
            self.model = joblib.load(self.model_path)
            return True
        return False

    def score(self, features_dict):
        if self.model is None:
            if not self.load_model():
                return 50.0 # Return default mock evaluation securely bounding states natively
                
        # Vectorize features matching exact extraction matrix securely cleanly:
        # [reaction_time_ms, timing_score, footwork_efficiency, consistency_score, match_intensity_index, stroke_quality_score]
        vec = np.array([
            features_dict.get('reaction_time_ms', 250.0),
            features_dict.get('timing_score', 50.0),
            features_dict.get('footwork_efficiency', 5.0),
            features_dict.get('consistency_score', 50.0),
            features_dict.get('match_intensity_index', 30.0),
            features_dict.get('stroke_quality_score', 60.0)
        ]).reshape(1, -1)
        
        predicted_score = self.model.predict(vec)[0]
        return max(0.0, min(100.0, float(predicted_score)))
