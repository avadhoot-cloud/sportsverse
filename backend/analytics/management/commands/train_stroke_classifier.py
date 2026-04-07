import os
import joblib
import numpy as np
from sklearn.ensemble import RandomForestClassifier
from django.core.management.base import BaseCommand
from django.conf import settings

class Command(BaseCommand):
    help = 'Generates 200 synthetic gaussian samples and trains the StrokeClassifier natively.'

    def handle(self, *args, **options):
        # 1. Synthetic Parameters - Features: peak_accel, mean_accel, peak_angular, freq, wrist_rot
        stroke_profiles = {
            'forehand': {'mu': [4.5, 2.0, 15.0, 3.0, 180.0], 'std': [0.5, 0.2, 2.0, 0.5, 20.0]},
            'backhand': {'mu': [3.8, 1.8, 18.0, 2.5, 250.0], 'std': [0.5, 0.2, 2.0, 0.5, 30.0]},
            'serve':    {'mu': [8.0, 3.5, 25.0, 1.5, 100.0], 'std': [1.0, 0.4, 3.0, 0.3, 15.0]},
            'volley':   {'mu': [2.5, 1.5, 8.0,  5.0, 45.0],  'std': [0.4, 0.2, 1.0, 0.8, 10.0]}
        }
        
        samples_per_class = 200
        X_train = []
        y_train = []
        
        for label, profile in stroke_profiles.items():
            mu = np.array(profile['mu'])
            std = np.array(profile['std'])
            for _ in range(samples_per_class):
                # Generates simulated specific bounds wrapping standard deviations dynamically
                synthetic_feature = np.random.normal(mu, std)
                X_train.append(synthetic_feature)
                y_train.append(label)
                
        X_train = np.array(X_train)
        y_train = np.array(y_train)
        
        self.stdout.write(f'Generated {len(X_train)} mapped features! Training...')

        # 2. Train Random Forest securely
        model = RandomForestClassifier(n_estimators=100, max_depth=6, random_state=42)
        model.fit(X_train, y_train)
        
        # 3. Export binaries directly
        model_dir = os.path.join(settings.MEDIA_ROOT, 'models')
        os.makedirs(model_dir, exist_ok=True)
        model_path = os.path.join(model_dir, 'stroke_classifier.pkl')
        
        joblib.dump(model, model_path)
        
        self.stdout.write(self.style.SUCCESS(f'Successfully built and saved model to {model_path}'))
