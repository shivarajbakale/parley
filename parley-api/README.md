# Parley Api

Parley sync API

Generated with [create-express-app](https://www.npmjs.com/package/create-express-app).

## Run

```bash
npm install
cp .env.example .env   # if not already created
npm run dev
```

The server starts on http://localhost:3000 — check `GET /api/health`.

## What's inside

- Express 4 + TypeScript (strict)
- Layered architecture: routes → controllers → services
- Zod request validation middleware
- Winston logging with correlation IDs and sensitive-data redaction
- Consistent `{ data, meta }` response envelope
- Global error handling via a custom `ApiError`
- Helmet + CORS security defaults

## Scripts

```bash
npm run dev          # hot-reload dev server (ts-node-dev)
npm run build        # compile TypeScript to dist/
npm start            # run the compiled build
npm run lint         # ESLint
npm run type-check   # type-check without emitting
```

## Identifiers

- npm package: `parley-api`

See `ARCHITECTURE.md` for the layout and the request flow, `AGENTS.md` for
the working contract.
