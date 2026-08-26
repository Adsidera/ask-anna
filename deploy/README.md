# Deploy — VPS Hetzner (Ubuntu 24.04)

Reference notes for the spec's "Deploy (VPS Hetzner)" section. These are
templates to adapt, not a script to run blindly.

Two ways to run the app on the VPS: **Docker** (steps below — one `docker
compose up`, no native Postgres/Redis/Ruby install) or the **native**
systemd-based install (see "Alternative: native install" at the bottom,
using `deploy/systemd/`). Pick one; don't mix them on the same box.

1. **Provisioning**: Ubuntu 24.04 on a Hetzner CPX31/CPX41 (Nuremberg or
   Falkenstein).

2. **Docker**:
   ```
   curl -fsSL https://get.docker.com | sh
   sudo usermod -aG docker $USER   # log out/in for this to take effect
   ```

3. **App config**: clone the repo, copy `.env.example` to `.env` and fill
   in production values: `RAILS_MASTER_KEY` (from `config/master.key`),
   `ASK_ANNA_DATABASE_PASSWORD` (new value — used by both the `db`
   container and the app's `DATABASE_URL`, see `compose.yaml`),
   `ALLOWED_ORIGINS` for the widget's real origin(s), etc. `REDIS_URL` and
   `OLLAMA_URL` in `.env` are overridden by `compose.yaml` to point at the
   `redis`/`ollama` containers, so leave those as the local-dev defaults.

4. **Build and start**:
   ```
   docker compose up -d --build
   docker compose exec ollama ollama pull qwen3:0.6b        # skip if GENERATION_PROVIDER != ollama
   docker compose exec ollama ollama pull nomic-embed-text  # or whatever EMBEDDING_MODEL is set to
   ```
   `db:prepare` (create + migrate) runs automatically on `web` container
   start via `bin/docker-entrypoint`. For the first smoke test only:
   ```
   docker compose exec web bin/rails db:seed
   ```
   Puma listens on `localhost:3000` on the host (see `ports:` in
   `compose.yaml`) — same target the Cloudflare Tunnel below points at.

5. **Cloudflare Tunnel** (no inbound port forwarding):
   ```
   curl -fsSL https://pkg.cloudflare.com/cloudflared-ascii.gpg -o /usr/share/keyrings/cloudflare-main.gpg
   # ...follow https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/get-started/

   cloudflared tunnel login
   cloudflared tunnel create ask-anna
   cloudflared tunnel route dns ask-anna ask.yourdomain.com
   ```
   `~/.cloudflared/config.yml`:
   ```yaml
   tunnel: ask-anna
   credentials-file: /root/.cloudflared/<tunnel-id>.json
   ingress:
     - hostname: ask.yourdomain.com
       service: http://localhost:3000
     - service: http_status:404
   ```
   Then `sudo cloudflared service install` to run it as its own systemd
   service.

6. **Widget**: on the personal site (or Substack, via an embedded HTML
   block), add:
   ```html
   <script src="https://ask.yourdomain.com/widget.js" data-api-base="https://ask.yourdomain.com" defer></script>
   ```
   Set `ALLOWED_ORIGINS` on the server to the site's real origin(s) so CORS
   allows the cross-origin `POST /ask` calls.

7. **Updates**: `git pull`, then `docker compose up -d --build` — rebuilds
   only what changed and restarts `web`/`worker` with zero manual steps
   (migrations still run automatically via `bin/docker-entrypoint`).

## Alternative: native install (no Docker)

Same provisioning (step 1 above), then instead of steps 2-4:

1. **System packages**:
   ```
   sudo apt update
   sudo apt install -y postgresql postgresql-contrib redis-server git build-essential libpq-dev
   ```
   Install pgvector (not in Ubuntu's default apt repo for all versions —
   either build from source per https://github.com/pgvector/pgvector or use
   the PGDG apt repo), then in `psql`:
   ```sql
   CREATE EXTENSION IF NOT EXISTS vector;
   ```
   (the app's own migration also runs `enable_extension "vector"`, this is
   just to confirm the extension is installable on the server first).

2. **Ruby**: install via rbenv/asdf matching `.ruby-version`, then
   `bundle install --deployment` (or without `--deployment` if you're not
   vendoring gems).

3. **Ollama**:
   ```
   curl -fsSL https://ollama.com/install.sh | sh
   ollama pull qwen3:0.6b
   ollama pull nomic-embed-text   # or whatever EMBEDDING_MODEL is set to
   ```

4. **App config**: copy `.env.example` to `/var/www/ask-anna/shared/.env`
   and fill in production values (`RAILS_MASTER_KEY` via
   `config/master.key`, `ASK_ANNA_DATABASE_PASSWORD`, `REDIS_URL`,
   `ALLOWED_ORIGINS` for the widget's real origin(s), etc).

5. **Database**:
   ```
   RAILS_ENV=production bin/rails db:create db:migrate
   RAILS_ENV=production bin/rails db:seed   # only for the first smoke test
   ```

6. **systemd services**: copy `deploy/systemd/ask-anna-puma.service` and
   `deploy/systemd/ask-anna-sidekiq.service` to `/etc/systemd/system/`,
   adjust `User`/paths, then:
   ```
   sudo systemctl daemon-reload
   sudo systemctl enable --now ask-anna-puma ask-anna-sidekiq
   ```

Then continue with the Cloudflare Tunnel and Widget steps above — those
are the same either way.
