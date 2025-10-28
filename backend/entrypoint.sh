#!/bin/sh
set -e

# -----------------------------
# Function: Wait for PostgreSQL
# -----------------------------
wait_for_db() {
    echo "[$SERVICE] Checking PostgreSQL at $POSTGRES_HOST:$POSTGRES_PORT..."
    until nc -z "$POSTGRES_HOST" "$POSTGRES_PORT" >/dev/null 2>&1; do
        sleep 1
    done
    echo "[$SERVICE] PostgreSQL is reachable."
}

# -----------------------------
# Function: Wait for Redis (optional, backend only)
# -----------------------------
wait_for_redis() {
    echo "[$SERVICE] Checking Redis at $REDIS_HOST:$REDIS_PORT..."
    until nc -z "$REDIS_HOST" "$REDIS_PORT" >/dev/null 2>&1; do
        sleep 1
    done
    echo "[$SERVICE] Redis is reachable."
}

# -----------------------------
# Function: Wait for migrations (for Celery)
# -----------------------------
wait_for_migrations() {
    echo "[$SERVICE] Checking if migrations are applied..."
    until python - <<EOF >/dev/null 2>&1
    import django
    django.setup()
    from django.db import connection
    with connection.cursor() as cursor:
        cursor.execute("SELECT 1 FROM django_migrations LIMIT 1")
EOF
    do
        sleep 1
    done
    echo "[$SERVICE] Migrations applied. Ready to start."
}

# -----------------------------
# Main flow
# -----------------------------
# Ensure required environment variables
: "${POSTGRES_HOST:?Need to set POSTGRES_HOST}"
: "${POSTGRES_PORT:?Need to set POSTGRES_PORT}"

wait_for_db

case "$SERVICE" in
    backend)
        # Optional Redis check for caching
        : "${REDIS_HOST:?Need to set REDIS_HOST}"
        : "${REDIS_PORT:?Need to set REDIS_PORT}"
        wait_for_redis

        # Run Django migrations
        echo "[$SERVICE] Running Django migrations..."
        python manage.py migrate --noinput
        ;;
    celery-worker|celery-beat)
        wait_for_migrations
        echo "Starting Celery ($SERVICE)..."
        ;;
    *)
        echo "No specific service actions required for $SERVICE"
        ;;
esac

# Execute the command passed to the container
exec "$@"
