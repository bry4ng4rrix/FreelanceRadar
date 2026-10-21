# Image unique du backend : API (uvicorn), worker et Beat (Celery), migrations (Alembic).
# La commande lancée est choisie par docker-compose.yml.

FROM ghcr.io/astral-sh/uv:0.13.0 AS uv

FROM python:3.12.15-slim-bookworm

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    UV_COMPILE_BYTECODE=1 \
    UV_LINK_MODE=copy \
    UV_PYTHON_DOWNLOADS=never \
    PATH="/app/.venv/bin:$PATH"

WORKDIR /app

# Dépendances d'abord (couche mise en cache tant que pyproject.toml / uv.lock ne changent pas).
COPY --from=uv /uv /usr/local/bin/uv
COPY pyproject.toml uv.lock .python-version ./
RUN uv sync --frozen --no-dev --no-install-project

# Code de l'application (sans les tests : voir .dockerignore).
COPY alembic.ini ./
COPY migrations ./migrations
COPY app ./app
COPY data ./data

# Utilisateur non privilégié.
RUN useradd --system --uid 10001 --no-create-home --shell /usr/sbin/nologin app
USER app

EXPOSE 8000

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
