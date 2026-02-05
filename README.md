# FastAPI Dev Container Starter

A production-ready starter template demonstrating how to use the **same Dockerfile** for both local development (with VSCode Dev Containers) and production deployment (with Docker Compose).

## Why This Template Exists

Most projects end up with separate Dockerfiles for development and production, leading to:
- Configuration drift between environments
- "Works on my machine" problems
- Duplicated maintenance effort
- Different dependency versions across environments

This template solves these problems using **multi-stage Docker builds** with a single source of truth.

## Quick Start

### Prerequisites

- [Docker Desktop](https://www.docker.com/products/docker-desktop)
- [Visual Studio Code](https://code.visualstudio.com/)
- [Dev Containers extension](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers)

### Using the Dev Container

1. Clone this repository
2. Open the folder in VSCode
3. When prompted, click **"Reopen in Container"** (or press `F1` → "Dev Containers: Reopen in Container")
4. Wait for the container to build (first time takes a few minutes)
5. Once inside the container, start the FastAPI server:
   - Press `Ctrl+Shift+P` → "Tasks: Run Task" → "Run FastAPI Dev Server"
   - Or manually run: `uv run fastapi dev app/main.py --host 0.0.0.0`
6. Open your browser to `http://localhost:8000`

### Running in Production Mode

```bash
# Build and run with Docker Compose
docker-compose up --build

# Or build and run manually
docker build -t fastapi-app --target production .
docker run -p 8000:8000 fastapi-app
```

## Project Structure

```
.
├── .devcontainer/
│   └── devcontainer.json          # Dev container configuration
├── .vscode/
│   └── tasks.json                 # VSCode tasks for running the app
├── app/
│   ├── __init__.py
│   ├── main.py                    # FastAPI application entry point
│   ├── api/                       # API routes
│   └── models/                    # Data models
├── tests/
│   └── test_main.py               # Test files
├── Dockerfile                      # Single Dockerfile for dev AND prod
├── docker-compose.yml             # Production deployment config
├── pyproject.toml                 # Project dependencies (uv)
├── uv.lock                        # Locked dependencies
└── README.md
```

## The Magic: How It Works

### Multi-Stage Dockerfile

The `Dockerfile` contains three stages:

```dockerfile
FROM python:3.12-slim AS base        # ← Common foundation
FROM base AS development             # ← Dev-specific setup
FROM base AS production              # ← Prod-specific setup
```

**Key insight:** Docker only builds the stages it needs based on the `target` parameter.

#### Base Stage
- Installs `uv` for fast Python package management
- Copies dependency files (`pyproject.toml`, `uv.lock`)
- Shared by both dev and prod, maximizing layer cache reuse

#### Development Stage
- Installs ALL dependencies including dev tools (`uv sync`)
- Installs system tools like `git` and `curl`
- Does NOT copy source code (mounted as volume instead)
- Runs FastAPI in development mode with auto-reload

#### Production Stage
- Installs ONLY production dependencies (`uv sync --no-dev`)
- Copies application code into the image
- Runs as non-root user for security
- Uses production-grade server settings

### Target Selection

Different tools point to different stages:

**Dev Container** (`.devcontainer/devcontainer.json`):
```json
{
  "build": {
    "target": "development"  // ← Uses development stage
  }
}
```

**Docker Compose** (`docker-compose.yml`):
```yaml
services:
  api:
    build:
      target: production      // ← Uses production stage
```

When you build with a specific target, Docker:
1. Analyzes the dependency graph
2. Builds only the required stages
3. Skips unnecessary stages entirely

**Result:** No wasted build time, no bloated production images.

### Volume Mounting in Development

The dev container mounts your local source code:

```json
{
  "mounts": [
    "source=${localWorkspaceFolder},target=/app,type=bind"
  ]
}
```

**Why this matters:**
- Changes to your code are immediately visible in the container
- No need to rebuild the image for every code change
- FastAPI's auto-reload works perfectly
- Your local files and container stay in sync

**In production:** Code is COPIED into the image (immutable, reproducible)

### VSCode Tasks for Developer Ergonomics

The `.vscode/tasks.json` file defines a task to run the FastAPI server:

```json
{
  "label": "Run FastAPI Dev Server",
  "command": "uv run fastapi dev app/main.py --host 0.0.0.0"
}
```

**Benefits:**
- One-click server start from the Command Palette
- Consistent command across team members
- Logs visible in a dedicated terminal
- Easy to stop/restart with Ctrl+C

**Alternative:** You can uncomment the `postStartCommand` in `devcontainer.json` to auto-start the server when the container opens (see file for details).

## Why This Approach?

### Single Source of Truth
- One Dockerfile to maintain
- Dependency versions guaranteed to match
- Changes propagate to both environments automatically

### Optimized for Each Environment
- **Dev:** Fast feedback loop, debugging tools, volume mounts
- **Prod:** Minimal image size, security hardening, immutable code

### Developer Experience
- No Docker knowledge required to get started
- Consistent environment across the team
- Works on any OS (Windows, Mac, Linux)

### Production Ready
- Security: non-root user, minimal attack surface
- Performance: only production dependencies
- Reproducibility: locked dependencies, immutable images

## Common Workflows

### Adding a New Dependency

```bash
# Inside the dev container
uv add fastapi-users

# Rebuild the container to install it
# Press F1 → "Dev Containers: Rebuild Container"
```

The `uv.lock` file is automatically updated and will be used in production builds.

### Running Tests

```bash
# Inside the dev container
uv run pytest
```

### Debugging

The dev container includes Python debugging support. Use VSCode's debugger (F5) with breakpoints as usual.

### Deploying to Production

```bash
# Build the production image
docker build -t myregistry/fastapi-app:v1.0 --target production .

# Push to registry
docker push myregistry/fastapi-app:v1.0

# Deploy (example with docker-compose)
docker-compose up -d
```

## Pre-commit Hooks

This template includes a pre-commit configuration (see `.pre-commit-config.yaml`) to catch issues early and keep the project consistent. Pre-commit hooks run automatically on each commit (after you install them with `pre-commit install`) and will either fix problems for you or block the commit with a clear message.

At a high level, pre-commit hooks help you:
- Enforce consistent formatting and linting before code is committed
- Keep your dependency lock file in sync with `pyproject.toml`
- Prevent accidental commits of secrets or other sensitive information

### Configured Hooks

The following hooks are currently configured:

- **sync-with-uv** (from `tsvikas/sync-with-uv`)
  - Ensures that your `uv.lock` file is synchronized with `pyproject.toml` whenever you change dependencies.
  - Helps prevent situations where production builds use stale dependency information.

- **ruff-check** (from `astral-sh/ruff-pre-commit`)
  - Runs the Ruff linter against your Python code.
  - Uses `--fix` to automatically apply safe fixes where possible.
  - Extends selection with `I` to enforce import sorting and organization.
  - Fails the commit if style or lint violations remain after automatic fixes.

- **ruff-format** (from `astral-sh/ruff-pre-commit`)
  - Formats your Python code with Ruff's formatter to keep a consistent style across the codebase.
  - Reduces noise in pull requests by standardizing formatting automatically.

- **gitleaks** (from `gitleaks/gitleaks`)
  - Scans staged changes for secrets (API keys, tokens, passwords, etc.) before they are committed.
  - Blocks commits that appear to contain sensitive values, helping you avoid leaking secrets to Git history or remote repositories.

### Using Pre-commit Locally

To enable these hooks in your local environment:

1. Install `pre-commit` (globally or in your environment), for example:
   - `uv tool install pre-commit` **or** `pip install pre-commit`
2. From the repository root, run:
   - `pre-commit install`
3. (Optional) Run all hooks against the entire repo once:
   - `pre-commit run --all-files`

After installation, the hooks will run automatically on `git commit`. If a hook fails, fix the reported issues (or let the hook apply fixes), then re-stage your changes and try committing again.

## Customization

### Using a Different Python Version

Change the base image in `Dockerfile`:
```dockerfile
FROM python:3.11-slim AS base
```

### Adding Environment Variables

**Development:** Add to `devcontainer.json`:
```json
{
  "containerEnv": {
    "DEBUG": "true"
  }
}
```

**Production:** Add to `docker-compose.yml`:
```yaml
services:
  api:
    environment:
      - DEBUG=false
      - DATABASE_URL=postgresql://...
```

### Installing Additional System Packages

**Development only:** Modify the `development` stage in `Dockerfile`

**Both environments:** Modify the `base` stage in `Dockerfile`

### Auto-Starting the Server

Uncomment the line in `.devcontainer/devcontainer.json`:
```json
"postStartCommand": "uv run fastapi dev app/main.py --host 0.0.0.0"
```

**Trade-off:** Server starts automatically, but runs in background (harder to see logs/stop).

## Troubleshooting

### Port 8000 already in use

Another process is using port 8000. Either:
- Stop the other process
- Change the port in `devcontainer.json` and `docker-compose.yml`

### Container won't start

Try rebuilding from scratch:
```bash
# Remove all containers and images
docker-compose down -v
docker system prune -a

# Rebuild in VSCode
F1 → "Dev Containers: Rebuild Container Without Cache"
```

### Changes not reflecting in the browser

1. Check if auto-reload is working (should see "Detected file change" in logs)
2. Hard refresh the browser (Ctrl+Shift+R)
3. Verify the file is being mounted correctly (check paths in `devcontainer.json`)

## Best Practices

1. **Keep the base stage minimal** - Only include what both environments need
2. **Lock your dependencies** - Commit `uv.lock` to version control
3. **Test production builds locally** - Run `docker-compose up` before deploying
4. **Use `.dockerignore`** - Exclude unnecessary files from build context
5. **Keep dev and prod in sync** - Regularly test production builds during development

## Further Reading

- [Dev Containers Documentation](https://code.visualstudio.com/docs/devcontainers/containers)
- [Docker Multi-Stage Builds](https://docs.docker.com/build/building/multi-stage/)
- [uv Documentation](https://docs.astral.sh/uv/)
- [FastAPI Documentation](https://fastapi.tiangolo.com/)

## Contributing

This is a starter template. Feel free to adapt it to your team's needs! Suggestions for improvements are welcome.

## License

MIT License - use this however you like!