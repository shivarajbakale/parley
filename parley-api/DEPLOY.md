# Deploy

Ship this API to a self-hosted box (Mac mini / VPS) as a Docker container.

## What's here

| File                      | Purpose                                                        |
| ------------------------- | ------------------------------------------------------------- |
| `Dockerfile`              | Multi-stage production image (build → lean runtime).          |
| `.dockerignore`           | Keeps the build context small.                                |
| `docker-entrypoint.sh`    | Syncs the DB schema (`prisma db push`) on boot, then starts.  |
| `docker-compose.prod.yml` | Runs the app; persists the SQLite DB in the `app-data` volume.|
| `scripts/deploy.sh`       | One-command SSH deploy (`npm run deploy`).                     |

## Run it locally (container)

```bash
npm run docker:up      # docker compose -f docker-compose.prod.yml up -d --build
curl localhost:3000/api/health
npm run docker:down
```

## Deploy to your box

Prerequisites on the remote: Docker (with `docker compose`) and your SSH key.

```bash
DEPLOY_HOST=you@mini npm run deploy
```

That ships the source, builds the image **on the remote** (so a Mac mini's arm64
build just works), and starts it with `docker-compose.prod.yml`.

- **Secrets/env:** `.env` is intentionally not synced. Set production values once
  on the remote (e.g. `apps/<name>/.env`) or export them in the shell compose
  reads. Defaults (port `3000`, SQLite at `/data/prod.db`) work out of the box.
- **Data:** the SQLite database lives in the `app-data` Docker volume and
  survives redeploys.
- **Logs:** `ssh you@mini 'cd apps/<name> && docker compose -f docker-compose.prod.yml logs -f'`

## Alternative: prebuilt image via a registry

If you'd rather build once and push (multi-host, CI):

```bash
docker build -t registry.example.com/<name>:latest .
docker push registry.example.com/<name>:latest
# on the remote: docker compose pulls the image instead of `build: .`
```

## Moving off SQLite

For real production, switch `prisma/schema.prisma` `provider` to `postgresql`,
point `DATABASE_URL` at a Postgres instance, add a `postgres` service to
`docker-compose.prod.yml`, and change the entrypoint to `prisma migrate deploy`.
