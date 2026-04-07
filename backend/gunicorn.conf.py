import multiprocessing
import os

bind = "0.0.0.0:8000"
workers = multiprocessing.cpu_count() * 2 + 1
threads = 4
loglevel = 'info'
errorlog = os.path.join('media', 'logs', 'gunicorn_error.log')
accesslog = os.path.join('media', 'logs', 'gunicorn_access.log')
timeout = 120 # Prevent CV timeouts natively
worker_class = 'gthread'
