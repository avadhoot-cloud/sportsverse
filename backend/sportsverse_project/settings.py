"""
Django settings for sportsverse_project project.

Uses python-decouple for secrets management.
Copy backend/.env.example → backend/.env and fill in your values.
"""

from pathlib import Path
import os
from decouple import config, Csv
from dotenv import load_dotenv
load_dotenv()
GEMINI_API_KEY = os.getenv("AIzaSyA7hxWp9DN98bP2wqrrK6tmD78k5ootw6w")
# Build paths inside the project like this: BASE_DIR / 'subdir'.
BASE_DIR = Path(__file__).resolve().parent.parent

# ─── Security ─────────────────────────────────────────────────────────────────
SECRET_KEY = config('SECRET_KEY')
DEBUG = config('DEBUG', default=False, cast=bool)
ALLOWED_HOSTS = config('ALLOWED_HOSTS', default='127.0.0.1,localhost,10.75.234.107', cast=Csv())

# ─── Application definition ───────────────────────────────────────────────────
INSTALLED_APPS = [
    "django.contrib.admin",
    "django.contrib.auth",
    "django.contrib.contenttypes",
    "django.contrib.sessions",
    "django.contrib.messages",
    "django.contrib.staticfiles",
    'rest_framework',
    'rest_framework.authtoken',
    'accounts',
    'api',
    'corsheaders',
    'academy_contents',
    'django_extensions',
    'organizations',
    'communications',
    'payments',
    'content',
    'academy_reports',
    'coaches',
    'ratings',
    'django_q',
]

MIDDLEWARE = [
    "django.middleware.security.SecurityMiddleware",
    "django.contrib.sessions.middleware.SessionMiddleware",
    'corsheaders.middleware.CorsMiddleware',         # Must be before CommonMiddleware
    "django.middleware.common.CommonMiddleware",
    "django.middleware.csrf.CsrfViewMiddleware",
    "django.contrib.auth.middleware.AuthenticationMiddleware",
    "django.contrib.messages.middleware.MessageMiddleware",
    "django.middleware.clickjacking.XFrameOptionsMiddleware",
]

ROOT_URLCONF = "sportsverse_project.urls"

TEMPLATES = [
    {
        "BACKEND": "django.template.backends.django.DjangoTemplates",
        "DIRS": [],
        "APP_DIRS": True,
        "OPTIONS": {
            "context_processors": [
                "django.template.context_processors.request",
                "django.contrib.auth.context_processors.auth",
                "django.contrib.messages.context_processors.messages",
            ],
        },
    },
]

WSGI_APPLICATION = "sportsverse_project.wsgi.application"

# ─── CORS ─────────────────────────────────────────────────────────────────────
# For Flutter mobile development, you may need to allow all origins locally.
# In production set CORS_ALLOWED_ORIGINS in .env instead.
_cors_origins = config('CORS_ALLOWED_ORIGINS', default='', cast=Csv())
if DEBUG:
    # In Debug mode, if origins are not explicitly provided, allow all.
    # If they ARE provided (like localhost or specific IPs), use them.
    if not _cors_origins:
        CORS_ALLOW_ALL_ORIGINS = True
    else:
        CORS_ALLOWED_ORIGINS = _cors_origins
else:
    CORS_ALLOWED_ORIGINS = _cors_origins


# ─── Database ─────────────────────────────────────────────────────────────────
DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.mysql',
        'NAME':     config('DB_NAME', default='sportsverse_db'),
        'USER':     config('DB_USER', default='root'),
        'PASSWORD': config('DB_PASSWORD', default=''),
        'HOST':     config('DB_HOST', default='localhost'),
        'PORT':     config('DB_PORT', default='3306'),
    }
}

# ─── Password validation ──────────────────────────────────────────────────────
AUTH_PASSWORD_VALIDATORS = [
    {"NAME": "django.contrib.auth.password_validation.UserAttributeSimilarityValidator"},
    {"NAME": "django.contrib.auth.password_validation.MinimumLengthValidator"},
    {"NAME": "django.contrib.auth.password_validation.CommonPasswordValidator"},
    {"NAME": "django.contrib.auth.password_validation.NumericPasswordValidator"},
]

# ─── Internationalisation ─────────────────────────────────────────────────────
LANGUAGE_CODE = "en-us"
TIME_ZONE = "Asia/Kolkata"
USE_I18N = True
USE_TZ = True

# ─── Static & Media ───────────────────────────────────────────────────────────
STATIC_URL = "static/"
STATIC_ROOT = os.path.join(BASE_DIR, 'staticfiles')

MEDIA_URL = '/media/'
MEDIA_ROOT = os.path.join(BASE_DIR, 'media')

DEFAULT_AUTO_FIELD = 'django.db.models.BigAutoField'

# ─── Custom User Model ────────────────────────────────────────────────────────
AUTH_USER_MODEL = 'accounts.CustomUser'

# ─── Django REST Framework ────────────────────────────────────────────────────
REST_FRAMEWORK = {
    'DEFAULT_AUTHENTICATION_CLASSES': [
        'rest_framework.authentication.TokenAuthentication',
        'rest_framework_simplejwt.authentication.JWTAuthentication',

    ],
    'DEFAULT_PERMISSION_CLASSES': [
        'rest_framework.permissions.IsAuthenticated',
    ],
    
}

# ─── Django-Q (background task queue) ───────────────────────────────────
Q_CLUSTER = {
    'name': 'sportsverse',
    'workers': 2,
    'recycle': 500,
    'timeout': 60,            # seconds before task is killed
    'retry':   120,           # retry failed tasks after N seconds
    'queue_limit': 50,
    'bulk': 10,
    'orm': 'default',         # use MySQL as broker — no Redis required
    'sync': config('Q_SYNC', default=False, cast=bool),  # True in tests
    'max_attempts': 3,
}

# ─── Logging ──────────────────────────────────────────────────────────────────
LOGGING = {
    'version': 1,
    'disable_existing_loggers': False,
    'formatters': {
        'verbose': {
            'format': '[{levelname}] {asctime} {name} — {message}',
            'style': '{',
        },
        'simple': {
            'format': '[{levelname}] {message}',
            'style': '{',
        },
    },
    'handlers': {
        'console': {
            'class': 'logging.StreamHandler',
            'formatter': 'verbose',
        },
    },
    'loggers': {
        # Django core
        'django': {
            'handlers': ['console'],
            'level': 'WARNING',
            'propagate': False,
        },
        # Application loggers
        'accounts': {
            'handlers': ['console'],
            'level': 'DEBUG' if DEBUG else 'INFO',
            'propagate': False,
        },
        'organizations': {
            'handlers': ['console'],
            'level': 'DEBUG' if DEBUG else 'INFO',
            'propagate': False,
        },
        'coaches': {
            'handlers': ['console'],
            'level': 'DEBUG' if DEBUG else 'INFO',
            'propagate': False,
        },
        'payments': {
            'handlers': ['console'],
            'level': 'DEBUG' if DEBUG else 'INFO',
            'propagate': False,
        },
        'ratings': {
            'handlers': ['console'],
            'level': 'DEBUG' if DEBUG else 'INFO',
            'propagate': False,
        },
    },
}
