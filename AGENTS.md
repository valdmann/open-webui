# AGENTS.md

Open WebUI is a self-hosted AI chat interface. This repository is my **private fork**, kept closely tracking upstream.

NOTE: This document is still work-in-progress, consequently very much incomplete.

## Layout

- `src/` — SvelteKit frontend (Svelte 5, TypeScript, Tailwind 4, Vite)
- `backend/` — FastAPI backend (`backend/open_webui/`); dev loop via
  `backend/dev.sh`, production via `backend/start.sh`
- `pyproject.toml` + `uv.lock` — Python dependencies are managed with **uv**
- `test/` — backend (pytest) and frontend (vitest) tests

## Commands

| Task | Command |
|---|---|
| Install frontend deps | `pnpm install` |
| Dev server | `pnpm dev` |
| Production build | `pnpm build` |
| Type check / lint frontend | `pnpm check` / `pnpm lint` |
| Add Python dependency | `uv add <pkg>` |

## Package manager: pnpm, not npm

This fork uses pnpm while upstream uses npm. The only intentional divergence
from upstream is two added files: `pnpm-lock.yaml` and `pnpm-workspace.yaml`.
