# CLI — synapse

## Prerequisites

| Dependency | Minimum | Required |
|------------|---------|----------|
| Python | 3.11 | Yes |
| Node.js | 20.9.0 | Yes |
| npm | bundled with Node | Yes |
| ollama | any | No (local models only) |

Warnings are printed at startup if versions are below the minimums. Missing `ollama` is a non-fatal warning — cloud API models (Anthropic, OpenAI, Gemini) still work.

## Installation

The recommended way to install is via the setup script, which handles all prerequisites (Python, Node.js, PostgreSQL, etc.):

```bash
# macOS / Linux
curl -sSL https://raw.githubusercontent.com/Chrisl154/synapse-ai-cpm/master/setup.sh | bash

# Windows (PowerShell)
irm https://raw.githubusercontent.com/Chrisl154/synapse-ai-cpm/master/setup.ps1 | iex
```

> **After install:** Open a new terminal (or run `source ~/.bashrc` / `source ~/.zshrc`) so the `synapse` command is available in your PATH.

For development or manual installs:

```bash
# editable install (recommended for development)
python -m pip install -e .

# or install normally
python -m pip install .
```

Run the interactive setup wizard before first start to configure API keys and settings:

```bash
python setup.py
# or after install:
synapse setup
```

### PostgreSQL (Code Indexing)

PostgreSQL is required for the **Code Repository Indexing** feature (semantic search across your codebases). The setup script will prompt you to install it automatically. You can also install it manually and then re-run `synapse setup` to configure it.

## Environment variables

| Variable | Default | Description |
|----------|---------|-------------|
| `SYNAPSE_DATA_DIR` | `~/.synapse/data` | Path to data directory |
| `SYNAPSE_BACKEND_PORT` | `8765` | Backend API server port |
| `SYNAPSE_FRONTEND_PORT` | `3000` | Frontend web UI port |
| `SYNAPSE_PROFILING` | `false` | Enable performance profiling (set by `--profile`) |

Values in a `.env` file at the project root are loaded automatically (variables already in the environment are not overridden).

## Commands

```bash
# start as background daemon (default) — terminal stays free, browser opens
synapse start

# start in foreground and stream logs to the terminal
synapse start --foreground

# start but don't open the browser
synapse start --no-browser

# start on custom ports
synapse start --backend-port 8080 --frontend-port 4000

# start with performance profiling enabled
synapse start --profile

# stop processes (reads pidfiles)
synapse stop

# show status
synapse status

# view recent log output (last 50 lines from both services)
synapse logs

# stream logs live — Ctrl+C to exit
synapse logs --follow

# show only backend or frontend logs
synapse logs backend
synapse logs frontend

# show the last 200 lines and follow
synapse logs -n 200 --follow

# restart (background daemon by default)
synapse restart

# restart in foreground on custom ports
synapse restart --foreground --backend-port 8080 --frontend-port 4000

# run interactive setup wizard (configure API keys and settings)
synapse setup

# pull latest code and rebuild everything
synapse upgrade

# uninstall Synapse AI (removes all files, executable, and PATH entries)
synapse uninstall

# uninstall but keep data directory (~/.synapse)
synapse uninstall --keep-data
```

If you prefer running without installing:

```bash
python -m synapse start
```

## Command reference

### `start`

Starts the backend and frontend as a **background daemon** by default. Waits for both to be ready, opens the browser, then returns control to the terminal. PIDs are written to the data directory so `synapse stop` can find them later. Logs are written to `~/.synapse/data/backend.log` and `frontend.log`.

Use `--foreground` to stream logs directly in the terminal instead (useful for debugging). `Ctrl+C` in foreground mode shuts down both processes cleanly.

| Flag | Default | Description |
|------|---------|-------------|
| `--foreground`, `-f` | off | Run in foreground and stream logs to the terminal |
| `--no-browser` | off | Do not open a browser on start |
| `--backend-port PORT` | `8765` | Port for the backend API server (overrides `SYNAPSE_BACKEND_PORT`) |
| `--frontend-port PORT` | `3000` | Port for the frontend web UI (overrides `SYNAPSE_FRONTEND_PORT`) |
| `--profile` | off | Enable performance profiling (`SYNAPSE_PROFILING=true`) |

### `stop`

Reads PID files and terminates both processes. Sends `SIGTERM` first, then `SIGKILL` if the process does not exit within 5 seconds. On Windows uses `taskkill /F /T` to kill the full process tree.

### `status`

Prints whether the backend and frontend processes are running or have a stale PID.

### `logs`

Shows recent log output from the backend and/or frontend. Logs are only written when Synapse is running in daemon mode (the default).

| Flag | Default | Description |
|------|---------|-------------|
| `service` | `all` | Which logs to show: `all`, `backend`, or `frontend` |
| `--follow`, `-f` | off | Stream output continuously (like `tail -f`). Ctrl+C to exit. |
| `--lines N`, `-n N` | `50` | Number of recent lines to show |

**Log file locations:**
- Backend: `~/.synapse/data/backend.log`
- Frontend: `~/.synapse/data/frontend.log`

### `restart`

Equivalent to `stop` followed by `start`. Runs as a background daemon by default.

| Flag | Default | Description |
|------|---------|-------------|
| `--foreground`, `-f` | off | Run in foreground after restart |
| `--backend-port PORT` | `8765` | Port for the backend API server |
| `--frontend-port PORT` | `3000` | Port for the frontend web UI |

### `setup`

Runs the interactive setup wizard. Prompts for API keys and settings and writes them to the project `.env` file.

### `upgrade`

Pulls the latest code and rebuilds everything in place:

1. Stops running services
2. `git pull --ff-only` in the project root
3. Recreates the backend virtual environment (`backend/venv`) and reinstalls requirements
4. Reinstalls the `synapse-ai` package in editable mode
5. Runs `npm install` and `npm run build` in the frontend directory

```bash
synapse upgrade
```

### `uninstall`

Permanently removes Synapse AI. Prompts for confirmation before proceeding.

You can also uninstall via curl (useful if the `synapse` command is not available):

```bash
curl -sSL https://raw.githubusercontent.com/Chrisl154/synapse-ai-cpm/master/uninstall.sh | bash
```

Steps performed:
1. Stops running services
2. Removes startup registration (systemd user service on Linux, LaunchAgent on macOS, Registry run key on Windows)
3. Removes the data directory (`~/.synapse/data`) and Synapse home (`~/.synapse`) — skipped with `--keep-data`
4. Removes the installation directory (project root), including `backend/venv` and `frontend/node_modules`
5. Runs `pip uninstall -y synapse-ai` to remove the package and console script; falls back to deleting the `synapse` executable directly if found on `PATH`; on Windows also removes `synapse.exe` / `synapse-script.py` from the Python Scripts directory
6. Cleans `PATH` additions from `~/.bashrc`, `~/.zshrc`, `~/.bash_profile`, `~/.profile` (Unix) or the user `Environment` registry key (Windows)

| Flag | Default | Description |
|------|---------|-------------|
| `--keep-data` | off | Preserve `~/.synapse` data directory when uninstalling |

## PID files

PID files are written to the data directory:

- `~/.synapse/data/backend.pid`
- `~/.synapse/data/frontend.pid`

## Profiling

The `profile` subcommand queries and controls backend performance profiling. Requires the backend to be running with `--profile`.

```bash
# show per-endpoint latency table (avg, p50, p95, p99, max)
synapse profile stats

# clear collected timing stats
synapse profile reset

# start CPU profiling
synapse profile cpu-start

# print CPU profile report (text or HTML)
synapse profile cpu-report
synapse profile cpu-report --output report.html

# start memory profiling
synapse profile memory-start

# snapshot current memory allocations (top 20 by default)
synapse profile memory-snapshot
synapse profile memory-snapshot --limit 50

# record a py-spy flame graph (requires: pip install py-spy)
synapse profile spy
synapse profile spy --output profile.svg --duration 60
```

### `profile` flags

| Flag | Default | Description |
|------|---------|-------------|
| `--output FILE`, `-o` | — | Output file (`cpu-report`: `.html`, `spy`: `.svg`) |
| `--limit N` | `20` | Top allocations to show (`memory-snapshot`) |
| `--duration SECS` | `30` | Recording duration in seconds (`spy`) |

## Example quick flow

```bash
# install and run in background
python -m pip install -e .
synapse setup
synapse start --detach
synapse status
# when finished
synapse stop
```

## Extensibility

The CLI is extensible — future commands (migrations, backup, logs) can be added to `synapse.cli`.
