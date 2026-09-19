# AGENTS.md

Open WebUI is a self-hosted AI chat interface. This repository is my **private fork**.

NOTE: This document is still work-in-progress, consequently very much incomplete.

## Layout

- `src/` — SvelteKit frontend (Svelte 5, TypeScript, Tailwind 4, Vite)
- `backend/` — FastAPI backend (`backend/open_webui/`); dev loop via
  `backend/dev.sh`
- `pyproject.toml` + `uv.lock` — Python dependencies are managed with **uv**
- `test/` — backend (pytest) and frontend (vitest) tests

## Commands

| Task | Command |
|---|---|
| Install frontend deps | `pnpm install` |
| Dev server | `pnpm dev` |
| Production build | `pnpm build` |
| Add Python dependency | `uv add <pkg>` |

Note: Don't bother with `pnpm check` or `pnpm list`. They report ~8k pre-existing errors from the wizard's upstream.

## Production deployment

On this machine, the production instance is a user-level systemd service running this checkout directly (uvicorn serves both API and the built SPA; `backend/start.sh` is the upstream container entry point and is not used):

- Unit: `~/.config/systemd/user/open-webui.service` — restart it after
  `pnpm build` / `uv sync` to pick up changes
- Data: `~/.local/share/open-webui/` (`DATA_DIR`; migrated from the former
  podman container's volume)
- Listens on port 3002
- Migrations run automatically at boot (`run_migrations()` in
  `backend/open_webui/config.py`). This fork carries a fork-specific migration
  (`a4f8c2e19b07`, the chat-search FTS index) anchored to a production
  alembic position; after pulling upstream's new migrations the alembic
  chain will fork into two heads and the anchor must be re-joined.

## Package manager: pnpm, not npm

This fork uses pnpm while upstream uses npm. `pnpm-lock.yaml` was generated from `package-lock.json` by `pnpm`, which is kept so upstream merges stay clean.
