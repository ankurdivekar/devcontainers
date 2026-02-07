# Base stage with common dependencies
FROM python:3.12-slim AS base

# Install uv
COPY --from=ghcr.io/astral-sh/uv:latest /uv /usr/local/bin/uv

# Set working directory
WORKDIR /app

# Copy dependency files
COPY pyproject.toml uv.lock ./

# Development stage
FROM base AS development

# Install all dependencies including dev dependencies
RUN uv sync

# Install additional dev tools
RUN apt-get update && apt-get install -y git curl && rm -rf /var/lib/apt/lists/*

# Don't copy source code - it will be mounted as a volume
CMD ["uv", "run", "fastapi", "dev", "app/main.py", "--host", "0.0.0.0"]

# Production stage
FROM base AS production

# Create non-root user and ensure ownership of the project directory
RUN useradd -m -u 1000 appuser && chown -R appuser:appuser /app

# Run dependency installation and the app as non-root
USER appuser

# Store the project environment under the user's home directory
ENV UV_PROJECT_ENVIRONMENT=/home/appuser/.venv

# Install only production dependencies into the user-owned environment
RUN uv sync --no-dev

# Copy application code
COPY ./app ./app

# Run with production server
CMD ["uv", "run", "fastapi", "run", "app/main.py", "--host", "0.0.0.0"]