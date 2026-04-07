import os
import joblib
import onnx
from skl2onnx import convert_sklearn
from skl2onnx.common.data_types import FloatTensorType
from django.core.management.base import BaseCommand
from django.conf import settings

class Command(BaseCommand):
    help = 'Exports the strictly mapped sklearn models strictly into ONNX binaries explicitly for edge computing layers.'

    def handle(self, *args, **options):
        # We need to trace both stroke_classifier and fusion_scorer locally 
        model_dir = os.path.join(settings.MEDIA_ROOT, 'models')
        
        # 1. Stroke Classifier (5 float bounds native extraction)
        sc_path = os.path.join(model_dir, 'stroke_classifier.pkl')
        sc_onnx_path = os.path.join(model_dir, 'stroke_classifier.onnx')
        
        if os.path.exists(sc_path):
            sc_model = joblib.load(sc_path)
            # Define shape: [None, 5 features]
            initial_type = [('float_input', FloatTensorType([None, 5]))]
            onx = convert_sklearn(sc_model, initial_types=initial_type)
            with open(sc_onnx_path, "wb") as f:
                f.write(onx.SerializeToString())
            self.stdout.write(self.style.SUCCESS(f'Successfully built StrokeClassifier ONNX dynamically at {sc_onnx_path}'))
            
        # 2. Fusion Scorer (6 float bounds natively)
        fs_path = os.path.join(model_dir, 'fusion_scorer.pkl')
        fs_onnx_path = os.path.join(model_dir, 'fusion_scorer.onnx')
        
        if os.path.exists(fs_path):
            fs_model = joblib.load(fs_path)
            initial_type = [('float_input', FloatTensorType([None, 6]))]
            onx = convert_sklearn(fs_model, initial_types=initial_type)
            with open(fs_onnx_path, "wb") as f:
                f.write(onx.SerializeToString())
            self.stdout.write(self.style.SUCCESS(f'Successfully exported FusionScorer ONNX layers effectively at {fs_onnx_path}'))
