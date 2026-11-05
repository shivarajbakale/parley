# Deploying parley-api

The app runs as its own Tailscale node on the Mac mini, built there by
the `ts-deploy` CLI.

| Command | Result |
| --- | --- |
| `npm run deploy` | private: `https://parley-api.<your-tailnet>.ts.net`, tailnet devices only |
| `npm run deploy:status` | every node on the host |
| `npm run deploy:logs` | follow this node's logs |
| `npm run deploy:down` | stop and remove the node |

Deploys are manual and private. Nothing in CI deploys, and there is no public
deploy: `/api/providers` spends (and `/api/providers/keys` replaces) your
provider keys, so the tailnet is the only gate.

Put your tailnet name in `deploy/config.local.env` (gitignored):
`TAILNET=<your-tailnet>.ts.net`. It is only used to print the URL.

## Files

- `deploy/config.env` — node name, port, health paths, excludes. Edit this.
- `deploy/config.local.env` — your tailnet name. Gitignored.
- `compose.ts-deploy.yml` — the services as they run on the node. Edit this.
- `deploy/deploy.sh` — generic, from create-rocketship's deploy-kit.
- `.ts-deploy.*` — generated on every deploy and holds the expanded `.env`.
  Gitignored; never commit it.

## One-time setup

1. On the mini: Tailscale up, OrbStack or Docker running, `ts-deploy` installed,
   auth key in `~/.config/ts-deploy/authkey`, Remote Login on.
2. On the laptop: `ts-deploy host set <user@mini>` and `ts-deploy host doctor`.
3. Tailnet admin: enable **HTTPS Certificates**.

## Rules that bite

- Services share one network namespace: call each other at `127.0.0.1:<port>`.
- Every URL in `.env` that says localhost needs an override in the compose file.
- The deploy ships your working tree, so it refuses uncommitted changes.
- `deploy` after `deploy:public` makes the node private again.
- Renaming `NODE_NAME` creates a new node; `deploy:down` the old one first.
