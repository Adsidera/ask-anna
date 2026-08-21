# Deploy — VPS Hetzner (Ubuntu 24.04)

Reference notes for the spec's "Deploy (VPS Hetzner)" section. These are
templates to adapt, not a script to run blindly.

1. **Provisioning**: Ubuntu 24.04 on a Hetzner CPX31/CPX41 (Nuremberg or
   Falkenstein).

2. **System packages**:
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

3. **Ruby**: install via rbenv/asdf matching `.ruby-version`, then
   `bundle install --deployment` (or without `--deployment` if you're not
   vendoring gems).

4. **Ollama**:
   ```
   curl -fsSL https://ollama.com/install.sh | sh
   ollama pull qwen3:0.6b
   ollama pull nomic-embed-text   # or whatever EMBEDDING_MODEL is set to
   ```

5. **App config**: copy `.env.example` to `/var/www/ask-anna/shared/.env`
   and fill in production values (`RAILS_MASTER_KEY` via
   `config/master.key`, `ASK_ANNA_DATABASE_PASSWORD`, `REDIS_URL`,
   `ALLOWED_ORIGINS` for the widget's real origin(s), etc).

6. **Database**:
   ```
   RAILS_ENV=production bin/rails db:create db:migrate
   RAILS_ENV=production bin/rails db:seed   # only for the first smoke test
   ```

7. **systemd services**: copy `deploy/systemd/ask-anna-puma.service` and
   `deploy/systemd/ask-anna-sidekiq.service` to `/etc/systemd/system/`,
   adjust `User`/paths, then:
   ```
   sudo systemctl daemon-reload
   sudo systemctl enable --now ask-anna-puma ask-anna-sidekiq
   ```

8. **Cloudflare Tunnel** (no inbound port forwarding):
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

9. **Widget**: on the personal site (or Substack, via an embedded HTML
   block), add:
   ```html
   <script src="https://ask.yourdomain.com/widget.js" data-api-base="https://ask.yourdomain.com" defer></script>
   ```
   Set `ALLOWED_ORIGINS` on the server to the site's real origin(s) so CORS
   allows the cross-origin `POST /ask` calls.
