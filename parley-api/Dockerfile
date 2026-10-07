# syntax=docker/dockerfile:1
# Parley API: Mastra on Express, built for the ts-deploy node on the Mac mini.
# The app runs from source through tsx (there is no build step), so tsx, a dev
# dependency, has to be installed in the image.
FROM node:22-slim
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci && npm cache clean --force
COPY tsconfig.json ./
COPY src ./src
ENV NODE_ENV=production PORT=3100 HOST=0.0.0.0
EXPOSE 3100
CMD ["node_modules/.bin/tsx", "src/index.ts"]
