#!/usr/bin/env node
/**
 * api-lint — the backend's layering rules become a gate instead of prose.
 *
 * `docs/CONSTRAINTS.md` is the best-argued document in this project and until
 * now nothing enforced a line of it. A layering rule that lives only in prose
 * is a rule that holds until the first hurried afternoon: the controller that
 * reaches straight into Prisma still compiles, the service that reads
 * `process.env` still passes its tests, and the handler that hand-builds a
 * second response envelope produces a body a client reaches through
 * `data.data`. Every one of those is invisible to `tsc`, to eslint, and to a
 * test suite that only asserts on the fields it happens to name.
 *
 * This is the move `ui-lint` made for screens, applied to a backend. Rules:
 *
 *   A1  a controller never reaches the database directly
 *   A2  no raw `process.env` outside the typed env module
 *   A3  every mutating route names a validator
 *   A4  every route declares its auth intent
 *   A5  a handler does not build the response envelope
 *   A6  no raw error and no stack trace reaches a client
 *
 * The rules are one set, written once, applied through whichever framework the
 * project actually uses — Express routers and controllers, or Nest decorators
 * and DTOs. The rule is the constraint; the framework is a detail of how it is
 * spelled. A6's exemption list is the point of the rule rather than a hole in
 * it: exactly one layer is allowed to see a stack trace, and it is not the one
 * holding the socket.
 *
 *   node scripts/api-lint.mjs
 */
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");

const violations = [];
const notes = [];
const fail = (rule, file, line, message) =>
  violations.push({ rule, where: line ? `${file}:${line}` : file, message });

const read = (rel) => {
  const p = path.join(ROOT, rel);
  return fs.existsSync(p) ? fs.readFileSync(p, "utf8") : null;
};

const lineOf = (text, index) => text.slice(0, index).split("\n").length;

/** Every file under `dir`, repo-relative, depth-first. */
function walk(dir, out = []) {
  const abs = path.join(ROOT, dir);
  if (!fs.existsSync(abs)) return out;
  for (const entry of fs.readdirSync(abs, { withFileTypes: true })) {
    const rel = path.posix.join(dir, entry.name);
    if (entry.isDirectory()) walk(rel, out);
    else out.push(rel);
  }
  return out;
}

/**
 * The balanced `{ … }` starting at `open`. Returns the inner text and the index
 * just past the closing brace, or null when the braces never close.
 */
function balanced(text, open) {
  let depth = 0;
  for (let i = open; i < text.length; i++) {
    if (text[i] === "{") depth++;
    else if (text[i] === "}") {
      depth--;
      if (depth === 0) return { inner: text.slice(open + 1, i), end: i + 1 };
    }
  }
  return null;
}

/**
 * The keys of an object literal, ignoring everything nested inside it. Nested
 * regions are blanked rather than parsed, so `{ meta: { data: 1 } }` reports
 * `meta` and not `data` — which is the whole distinction A5 turns on.
 */
function topLevelKeys(inner) {
  let depth = 0;
  let flat = "";
  for (const ch of inner) {
    if ("{[(".includes(ch)) depth++;
    if (depth === 0) flat += ch;
    else flat += " ";
    if ("}])".includes(ch)) depth--;
  }
  const keys = [];
  for (const m of flat.matchAll(/(^|[,{])\s*(['"`]?)([A-Za-z_$][\w$]*)\2\s*:/g)) {
    keys.push(m[3]);
  }
  return keys;
}

/** Object literals passed to any of `calls`, e.g. `res.json({ … })`. */
function literalArguments(text, pattern) {
  const found = [];
  for (const m of text.matchAll(pattern)) {
    const after = m.index + m[0].length;
    const brace = /^\s*\{/.exec(text.slice(after));
    if (!brace) continue;
    const open = after + brace[0].length - 1;
    const block = balanced(text, open);
    if (block) found.push({ index: m.index, keys: topLevelKeys(block.inner) });
  }
  return found;
}

// --------------------------------------------------------------- context ----
const pkgRaw = read("package.json");
if (!pkgRaw) {
  console.error("api-lint: no package.json — run this from the project root");
  process.exit(1);
}
const pkg = JSON.parse(pkgRaw);
const deps = { ...pkg.dependencies, ...pkg.devDependencies };

const framework = deps["@nestjs/core"] ? "nest" : deps.express ? "express" : null;
if (!framework) {
  console.log("api-lint: no Express or Nest dependency — nothing to check");
  process.exit(0);
}

const ENV_MODULE = "src/config/env.ts";

const sources = walk("src").filter(
  (f) => f.endsWith(".ts") && !f.endsWith(".d.ts") && !/\.(spec|test)\.ts$/.test(f),
);

const controllers =
  framework === "nest"
    ? sources.filter((f) => f.endsWith(".controller.ts"))
    : sources.filter((f) => f.startsWith("src/controllers/"));

const services =
  framework === "nest"
    ? sources.filter((f) => f.endsWith(".service.ts") && !f.includes("/common/"))
    : sources.filter((f) => f.startsWith("src/services/"));

// The one layer allowed to see a stack trace, and the one allowed to own the
// envelope. Everything else in `src/` is a caller.
const errorOwner = (f) =>
  framework === "nest"
    ? f.includes("/common/filters/") ||
      f.includes("/common/interceptors/") ||
      f.includes("/common/services/") ||
      f.includes("/common/exceptions/")
    : f.startsWith("src/middleware/") || f === "src/utils/logger.ts";

const body = new Map(sources.map((f) => [f, read(f) ?? ""]));

// ------------------------------------------------------------------- A1 ----
// A controller that queries the database has swallowed the service layer, and
// the next caller that needs the same query writes it a second time.
const DB_HANDLES =
  framework === "nest"
    ? [/\bPrismaService\b/, /\bthis\.prisma\b/, /\bPrismaClient\b/]
    : [/\bprisma\s*\./, /\bPrismaClient\b/, /from ['"][^'"]*config\/database['"]/];

for (const file of controllers) {
  const text = body.get(file);
  const hits = DB_HANDLES.map((p) => p.exec(text)).filter(Boolean);
  if (hits.length === 0) continue;
  // The earliest reference, so the reported line is where a reader starts
  // rather than wherever the rule list happened to match first.
  const m = hits.sort((a, b) => a.index - b.index)[0];
  fail(
    "A1",
    file,
    lineOf(text, m.index),
    `a controller reaches the database directly (\`${m[0].trim()}\`). ` +
      `Queries belong in a service, or the next caller that needs this one writes it again.`,
  );
}

// ------------------------------------------------------------------- A2 ----
// One typed module reads the environment; everything else reads the module. A
// second reader is a variable that is required in one file, optional in
// another, and absent from `.env.example`.
for (const file of sources) {
  if (file === ENV_MODULE) continue;
  const text = body.get(file);
  const m = /\bprocess\.env\b/.exec(text);
  if (!m) continue;
  fail(
    "A2",
    file,
    lineOf(text, m.index),
    `reads \`process.env\` directly. Add the variable to ${ENV_MODULE} (typed, with its default) ` +
      `and read it from there — a second reader is a variable nothing validates and nothing documents.`,
  );
}
if (!body.has(ENV_MODULE)) {
  fail(
    "A2",
    ENV_MODULE,
    null,
    `no typed env module. Every environment variable is then read where it is used, ` +
      `with a different default each time and no list of what the project needs to run.`,
  );
}

// ------------------------------------------------------------------- A3 ----
// A write that is not validated is a write that trusts the client.
if (framework === "express") {
  const routeFiles = sources.filter((f) => f.startsWith("src/routes/"));
  for (const file of routeFiles) {
    const text = body.get(file);
    // Which controller each imported handler came from, so a route can be
    // followed to the function it actually runs.
    const handlerSource = new Map();
    for (const m of text.matchAll(/import\s*\{([^}]*)\}\s*from\s*['"]([^'"]+)['"]/g)) {
      const from = m[2];
      if (!from.includes("controller")) continue;
      const rel = path.posix.normalize(path.posix.join(path.posix.dirname(file), `${from}.ts`));
      for (const name of m[1].split(",").map((s) => s.trim().split(/\s+as\s+/).pop()).filter(Boolean)) {
        handlerSource.set(name, rel);
      }
    }
    for (const m of text.matchAll(/router\.(post|put|patch)\s*\(([^;]*?)\)\s*;/gs)) {
      const args = m[2];
      if (/\bvalidate\s*\(/.test(args)) continue;
      const names = [...args.matchAll(/([A-Za-z_$][\w$]*)\s*(?:,|$)/g)].map((x) => x[1]);
      const handler = names[names.length - 1];
      const source = handlerSource.get(handler);
      // A route whose handler never touches the body has nothing to validate:
      // `router.patch('/:id/toggle', toggle)` is a state flip, not a write of
      // client data. Follow the handler rather than guessing from the verb.
      const handlerBody = source ? body.get(source) : null;
      if (handlerBody) {
        const start = new RegExp(`export\\s+const\\s+${handler}\\b`).exec(handlerBody);
        if (start) {
          const next = /export\s+const\s/g;
          next.lastIndex = start.index + start[0].length;
          const stop = next.exec(handlerBody);
          const fn = handlerBody.slice(start.index, stop ? stop.index : handlerBody.length);
          if (!/\breq\.body\b/.test(fn)) continue;
        }
      }
      const route = /['"]([^'"]*)['"]/.exec(args)?.[1] ?? "?";
      fail(
        "A3",
        file,
        lineOf(text, m.index),
        `${m[1].toUpperCase()} ${route} reads \`req.body\` and names no \`validate(schema)\`. ` +
          `The handler then receives whatever the client sent, and the first bad field fails in Prisma.`,
      );
    }
  }
}

if (framework === "nest") {
  // The global ValidationPipe only validates what the DTO declares; a `@Body()`
  // typed as `any` or as an undecorated class walks straight through it.
  const dtoFiles = sources.filter((f) => /\/dto\//.test(f) || f.endsWith(".dto.ts"));
  const validated = new Set();
  for (const file of dtoFiles) {
    const text = body.get(file);
    if (!/from ['"]class-validator['"]/.test(text)) continue;
    for (const m of text.matchAll(/export\s+class\s+([A-Za-z_$][\w$]*)/g)) validated.add(m[1]);
  }
  for (const file of controllers) {
    const text = body.get(file);
    for (const m of text.matchAll(/@(Post|Put|Patch)\s*\([^)]*\)([\s\S]{0,600}?)\)\s*[:{]/g)) {
      const signature = m[2];
      const arg = /@Body\s*\(\s*\)\s*[A-Za-z_$][\w$]*\s*:\s*([^,)]+)/.exec(signature);
      if (!arg) continue; // no body read, nothing to validate
      const declared = arg[1].trim();
      const named = [...declared.matchAll(/([A-Za-z_$][\w$]*)/g)].map((x) => x[1]);
      if (named.some((n) => validated.has(n))) continue;
      fail(
        "A3",
        file,
        lineOf(text, m.index),
        `@${m[1]} takes @Body() typed \`${declared}\`, which is not a class-validator DTO. ` +
          `ValidationPipe validates only what a DTO declares, so this body is accepted unchecked.`,
      );
    }
  }
}

// ------------------------------------------------------------------- A4 ----
// Auth is the one property where "not mentioned" and "not required" look the
// same in the source and differ completely in production.
if (framework === "nest") {
  const guarded = sources.some(
    (f) => f.endsWith(".module.ts") && /\bAPP_GUARD\b/.test(body.get(f)),
  );
  if (!guarded) {
    for (const file of controllers) {
      const text = body.get(file);
      if (/@UseGuards\s*\(/.test(text) || /@Public\s*\(\s*\)/.test(text)) continue;
      fail(
        "A4",
        file,
        null,
        `no global guard is registered (no APP_GUARD provider) and this controller declares neither ` +
          `@UseGuards nor @Public. Every route in it is open, and nothing in the file says so.`,
      );
    }
    for (const file of controllers) {
      const text = body.get(file);
      const m = /@Public\s*\(\s*\)/.exec(text);
      if (!m) continue;
      fail(
        "A4",
        file,
        lineOf(text, m.index),
        `@Public() opts out of a guard that is not registered — no APP_GUARD provider exists. ` +
          `The decorator reads as "deliberately open" while every other route is open too.`,
      );
    }
  } else {
    notes.push("auth is on by default (an APP_GUARD provider is registered); @Public() is the opt-out");
  }
}

if (framework === "express") {
  const authLayer = sources.find(
    (f) =>
      (f.startsWith("src/middleware/") && /auth/i.test(path.basename(f))) ||
      /export\s+const\s+(requireAuth|authenticate|authGuard)\b/.test(body.get(f) ?? ""),
  );
  const constraints = read("docs/CONSTRAINTS.md");
  const declaredAuthFree =
    constraints && /##\s*Auth\b/i.test(constraints) && /ships no auth|no authentication layer/i.test(constraints);

  if (authLayer) {
    for (const file of sources.filter((f) => f.startsWith("src/routes/"))) {
      const text = body.get(file);
      if (/requireAuth|authenticate|authGuard/.test(text)) continue;
      fail(
        "A4",
        file,
        null,
        `the project ships an auth layer (${authLayer}) and this route file names it nowhere. ` +
          `Whether these routes are deliberately open or were simply forgotten is not readable from the source.`,
      );
    }
  } else if (!declaredAuthFree) {
    fail(
      "A4",
      "docs/CONSTRAINTS.md",
      null,
      `the project has no auth layer and does not say so. Add an "## Auth" section stating that it ` +
        `ships no auth — otherwise a reader cannot tell a deliberate choice from a missing file.`,
    );
  } else {
    notes.push("no auth layer, declared as deliberate in docs/CONSTRAINTS.md");
  }
}

// ------------------------------------------------------------------- A5 ----
// One layer owns the envelope. A handler that builds a second one produces a
// body the client reaches through `data.data`, and only for some routes.
const ENVELOPE_KEYS = ["data", "meta"];
for (const file of controllers) {
  if (errorOwner(file)) continue;
  const text = body.get(file);
  const literals =
    framework === "nest"
      ? literalArguments(text, /\breturn\b/g)
      : literalArguments(text, /\bres\.(?:[A-Za-z_$][\w$]*\s*\([^()]*\)\s*\.)*(?:json|send)\s*\(/g);
  for (const lit of literals) {
    const clash = lit.keys.filter((k) => ENVELOPE_KEYS.includes(k));
    if (clash.length === 0) continue;
    fail(
      "A5",
      file,
      lineOf(text, lit.index),
      `a handler builds a response envelope of its own (key \`${clash[0]}\`). ` +
        (framework === "nest"
          ? `TransformInterceptor already wraps every response, so this ships as \`data.${clash[0]}\`.`
          : `transformResponse already wraps every response, so this ships as \`data.${clash[0]}\`.`),
    );
  }
}

// ------------------------------------------------------------------- A6 ----
// A stack trace in a response tells an attacker the file layout, the framework
// version and the query that failed.
for (const file of [...controllers, ...services]) {
  if (errorOwner(file)) continue;
  const text = body.get(file);
  const stack = /\.stack\b/.exec(text);
  if (stack) {
    fail(
      "A6",
      file,
      lineOf(text, stack.index),
      `references \`.stack\` outside the error layer. A stack trace names the file layout, the ` +
        `framework version and the failing query; only the error handler decides what a client sees.`,
    );
  }
  if (framework === "express") {
    for (const m of text.matchAll(/catch\s*\(\s*([A-Za-z_$][\w$]*)\s*(?::[^)]*)?\)\s*\{/g)) {
      const block = balanced(text, text.indexOf("{", m.index + m[0].length - 1));
      if (!block) continue;
      if (!/\bres\.(status|json|send)\s*\(/.test(block.inner)) continue;
      fail(
        "A6",
        file,
        lineOf(text, m.index),
        `a catch block writes the response itself. Let the error propagate — \`asyncHandler\` hands it ` +
          `to the one handler that knows which errors are safe to render.`,
      );
    }
  }
}

// --------------------------------------------------------------- report -----
for (const note of notes) console.log(`api-lint: ${note}`);
if (violations.length === 0) {
  console.log(
    `api-lint: ${framework} API layering holds — ${controllers.length} controller(s), ` +
      `${services.length} service(s), 0 violations`,
  );
  process.exit(0);
}
console.error(`\napi-lint: ${violations.length} violation(s)\n`);
for (const v of violations) console.error(`  [${v.rule}] ${v.where}\n        ${v.message}\n`);
process.exit(1);
