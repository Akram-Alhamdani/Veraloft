from .base import *

DEBUG = True

ALLOWED_HOSTS = ["*"]

DATABASES = {"default": env.db_url("DATABASE_URL")}
