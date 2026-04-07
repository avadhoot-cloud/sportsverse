from django.apps import AppConfig

class FusionConfig(AppConfig):
    default_auto_field = 'django.db.models.BigAutoField'
    name = 'fusion'

    def ready(self):
        # Implicitly load signals safely mapping execution limits dynamically
        import fusion.signals
