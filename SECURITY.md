# Security policy

## Reporting a vulnerability

Please do not open a public issue. Report it privately through GitHub's
**Report a vulnerability** button on the [Security tab](https://github.com/shivarajbakale/parley/security),
with the steps to reproduce and the version or commit you tested.

Fixes land on `main`; there are no
maintained release branches yet.

## What is in scope

- The macOS app and its engine (`macos/`, `engine/`)
- The server (`parley-api/`) and the agent (`parley-agent/`)
- The Android app (`parley-android/`)

## How Parley is meant to be deployed

`parley-api` holds your provider keys. It is designed to listen on loopback or
inside a private network such as a Tailscale tailnet, never on the public
internet: anyone who can reach it can use and replace the keys. Reports that
depend on exposing it publicly are still welcome, but that setup is not
supported.
