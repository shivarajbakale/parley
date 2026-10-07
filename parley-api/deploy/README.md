# Deploying parley-api

The app runs as its own Tailscale node on the Mac mini, built there by
the `ts-deploy` CLI.

| Command | Result |
| --- | --- |
| `npm run deploy` | private: `https://parley-api.taile506df.ts.net`, tailnet devices only |
| `npm run deploy:public` | the same URL on the public internet (asks you to type `publish`) |
| `npm run deploy:status` | every node on the host |
| `npm run deploy:logs` | follow this node's logs |
| `npm run deploy:down` | stop and remove the node |
| `npm run tunnel` | your *local* dev server on a public URL until Ctrl-C |

From GitHub: **Actions → deploy → Run workflow**, pick `mini` or `public`.
Secrets it needs are listed at the top of `.github/workflows/deploy.yml`.

## Files

- `deploy/config.env` — node name, port, health paths, excludes. Edit this.
- `compose.ts-deploy.yml` — the services as they run on the node. Edit this.
- `deploy/deploy.sh`, `deploy/funnel.sh`, `.github/workflows/deploy.yml` — generic,
  managed by create-rocketship's deploy-kit. Upgrade by re-running the installer
  with `--force`, not by hand.
- `.ts-deploy.*` — generated on every deploy and holds the expanded `.env`.
  Gitignored; never commit it.

## One-time setup

1. On the mini: Tailscale up, OrbStack or Docker running, `ts-deploy` installed,
   auth key in `~/.config/ts-deploy/authkey`, Remote Login on.
2. On the laptop: `ts-deploy host set <user@mini>` and `ts-deploy host doctor`.
3. Tailnet admin: enable **HTTPS Certificates**. For public deploys, also give the
   node the `funnel` attribute in the policy file.

## Rules that bite

- Services share one network namespace: call each other at `127.0.0.1:<port>`.
- Every URL in `.env` that says localhost needs an override in the compose file.
- The deploy ships your working tree, so it refuses uncommitted changes.
- `deploy` after `deploy:public` makes the node private again.
- Renaming `NODE_NAME` creates a new node; `deploy:down` the old one first.
