import os
import joblib
import numpy as np
from sklearn.ensemble import GradientBoostingRegressor
from django.core.management.base import BaseCommand
from django.conf import settings

class Command(BaseCommand):
    help = 'Generates 500 fake session features training the FusionScorer correctly'

    def handle(self, *args, **options):
        np.random.seed(42)
        samples = 500
        
        # Generate synthetic vectors mapping the 6 explicit targets securely natively
        # [reaction, timing, footwork, consistency, intensity, quality]
        reaction = np.random.normal(200, 50, samples) # ms
        timing = max(0, min(100, np.random.normal(70, 15, samples)))
        footwork = np.random.normal(5.0, 1.5, samples)
        consistency = np.random.normal(65, 20, samples)
        intensity = np.random.normal(45, 15, samples)
        quality = np.random.normal(75, 12, samples)
        
        X_train = np.column_stack((reaction, timing, footwork, consistency, intensity, quality))
        
        # Simulated target labels wrapping a complex mathematical heuristic logically
        y_train = (timing * 0.3) + (quality * 0.4) + (consistency * 0.2) + (np.clip(200 / reaction, 0, 10))
        y_train = np.clip(y_train, 10, 100) # Output scaling bounds internally smoothly targeting 100 maximum limits natively

        self.stdout.write(f'Generated {samples} complex fusion parameters mapping regression layers...')
        
        model = GradientBoostingRegressor(n_estimators=100, learning_rate=0.1, max_depth=4)
        model.fit(X_train, y_train)
        
        model_dir = os.path.join(settings.MEDIA_ROOT, 'models')
        os.makedirs(model_dir, exist_ok=True)
        model_path = os.path.join(model_dir, 'fusion_scorer.pkl')
        
        joblib.dump(model, model_path)
        self.stdout.write(self.style.SUCCESS(f'Successfully built securely and saved Regressor layer directly at {model_path}'))
