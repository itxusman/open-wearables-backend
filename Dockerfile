FROM themomentum/open-wearables-backend:latest

USER root

# Install redis-server inside the container
RUN apt-get update && apt-get install -y --no-install-recommends redis-server && rm -rf /var/lib/apt/lists/*

# Create full startup script with Redis + Celery worker + FastAPI
RUN echo '#!/bin/bash\n\
set -e\n\
echo "Starting local Redis daemon..."\n\
redis-server --daemonize yes\n\
until redis-cli ping >/dev/null 2>&1; do sleep 0.2; done\n\
echo "Redis is ready!"\n\
uv run alembic upgrade head || true\n\
uv run python scripts/init_device_priorities.py || true\n\
uv run python scripts/init_provider_priorities.py || true\n\
uv run python scripts/init/seed_admin.py || true\n\
uv run python scripts/init/seed_series_types.py || true\n\
echo "Starting Celery worker in background..."\n\
uv run celery -A app.main:celery_app worker --loglevel=info --pool=threads -Q default,sdk_sync,garmin_sync,webhook_sync,xml_sync -n worker@localhost &\n\
echo "Starting FastAPI application..."\n\
exec uv run fastapi run app/main.py --host 0.0.0.0 --port "${PORT:-8000}"\n\
' > /start.sh && chmod +x /start.sh

CMD ["bash", "/start.sh"]
