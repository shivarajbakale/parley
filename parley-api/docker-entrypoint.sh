#!/bin/sh
set -e
# Sync the SQLite schema on boot. Starter default; once you add real migrations,
# switch this to `npx prisma migrate deploy`.
npx prisma db push --skip-generate
exec "$@"
