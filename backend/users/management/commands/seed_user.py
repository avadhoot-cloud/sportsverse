from django.core.management.base import BaseCommand
from django.contrib.auth import get_user_model

User = get_user_model()

class Command(BaseCommand):
    help = 'Seeds the database with a test user'

    def handle(self, *args, **options):
        if User.objects.filter(username='testplayer').exists():
            self.stdout.write(self.style.WARNING('Test user already exists!'))
            return

        user = User.objects.create_user(
            username='testplayer',
            email='testplayer@tennisiq.com',
            password='testpassword123',
            first_name='Test',
            last_name='Player',
            dominant_hand='right',
            skill_level='intermediate'
        )
        self.stdout.write(self.style.SUCCESS(f'Successfully created user: {user.username}'))
