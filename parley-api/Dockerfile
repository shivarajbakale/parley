# syntax=docker/dockerfile:1
# Production image for self-hosted deploy (Mac mini / VPS). Multi-stage:
# build with the full toolchain, then run a lean image. See DEPLOY.md.

# ---- builder ----
FROM node:20-slim AS builder
WORKDIR /app
# Prisma needs openssl at generate/runtime.
RUN apt-get update -y && apt-get install -y openssl && rm -rf /var/lib/apt/lists/*
# Copy manifests + prisma schema first so `npm ci` (which runs `prisma generate`
# via postinstall) has the schema, and so this layer caches across code changes.
COPY package*.json ./
COPY prisma ./prisma
# `npm install` works with or without a committed lockfile; for fully
# reproducible builds, commit package-lock.json (npm install will honor it).
RUN npm install --no-audit --no-fund
COPY . .
RUN npm run build

# ---- runner ----
FROM node:20-slim AS runner
WORKDIR /app
ENV NODE_ENV=production
ENV PORT=3000
# SQLite database lives on a mounted volume so it survives redeploys.
ENV DATABASE_URL="file:/data/prod.db"
RUN apt-get update -y && apt-get install -y openssl && rm -rf /var/lib/apt/lists/*
# Bring the built app + installed deps (incl. the prisma CLI used at boot).
COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/dist ./dist
COPY --from=builder /app/prisma ./prisma
COPY --from=builder /app/package.json ./package.json
COPY docker-entrypoint.sh ./docker-entrypoint.sh
RUN chmod +x docker-entrypoint.sh && mkdir -p /data
EXPOSE 3000
VOLUME ["/data"]
HEALTHCHECK --interval=30s --timeout=3s --start-period=15s --retries=3 \
  CMD node -e "fetch('http://127.0.0.1:'+(process.env.PORT||3000)+'/api/health').then(r=>process.exit(r.ok?0:1)).catch(()=>process.exit(1))"
ENTRYPOINT ["./docker-entrypoint.sh"]
CMD ["node", "dist/server.js"]
