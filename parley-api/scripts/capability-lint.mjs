#!/usr/bin/env node
/**
 * capability-lint — the backend capability map is a graded artifact, not a note.
 *
 * The map is the routing table an agent reads before it adds an endpoint: for
 * one capability it names the call, the package that provides it, the layer the
 * code belongs in, the slice in this repo to copy, and the gotcha. Four of the
 * eleven scaffolders had one; neither backend did, so the knowledge that an
 * Express 4 error handler is identified by its *arity* — or that a Nest global
 * filter list is applied in reverse — lived only in whoever last debugged it.
 *
 * A routing table that has drifted is worse than none, because it sends
 * confident work at a call that moved, a package the project does not have, or
 * a file that no longer exists. So it is checked the same way source is.
 *
 * One script, two frameworks, for the same reason `api-lint` is one script: the
 * rules are the same rules, and a rule split per framework becomes two rules the
 * first time somebody fixes one of them.
 *
 * The rules:
 *
 *   K1  Every row has all six columns, filled in, with a real gotcha and a
 *       layer from this framework's vocabulary.
 *   K2  Every API the map names is a real symbol for this framework — the
 *       leading identifier has to be something the stack actually exposes.
 *   K3  Every package the map names is real, and a row that points at a
 *       reference slice ("wired") names one this project actually depends on.
 *       A row marked *(not wired…)* is exempt — that is the honest way to
 *       document a capability before building it.
 *   K4  Every repo path the map names exists.
 *   K5  Every capability the skill's description advertises has a row.
 *   K6  The core surface stays covered — no quietly deleting rows.
 *   K7  The reference sections and the dated source list are present, and the
 *       sources point at the vendor's own documentation.
 *   K8  The major versions the map is written against are the majors this
 *       project installs. Express 4 and Express 5 disagree about the single
 *       most consequential row in the map (a rejected promise reaching the
 *       error handler), so a map that has drifted a major is not stale — it is
 *       wrong.
 *
 * Run it with `npm run capability-lint` (part of `make check`).
 * Dependency-free: Node stdlib only. Exit 0 = clean, 1 = at least one violation.
 */

import { readFileSync, existsSync } from "node:fs";
import { join, dirname } from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = dirname(fileURLToPath(import.meta.url));
const projectRoot = join(__dirname, "..");

const PKG = join(projectRoot, "package.json");
if (!existsSync(PKG)) {
  console.error("capability-lint: no package.json — cannot tell which backend this is");
  process.exit(1);
}
const pkg = JSON.parse(readFileSync(PKG, "utf8"));
const deps = { ...(pkg.dependencies ?? {}), ...(pkg.devDependencies ?? {}) };

/**
 * Packages either backend may legitimately name. The point is the typo: a row
 * citing `@nestjs/comon` or `class-validators` reads perfectly well and sends
 * the next agent to install something that does not exist.
 */
const KNOWN_PACKAGES = new Set([
  "express", "cors", "helmet", "morgan", "winston", "winston-daily-rotate-file",
  "dotenv", "zod", "@prisma/client", "prisma", "supertest", "vitest",
  "@nestjs/common", "@nestjs/core", "@nestjs/platform-express", "@nestjs/swagger",
  "@nestjs/mapped-types", "class-validator", "class-transformer", "reflect-metadata",
  "rxjs", "swagger-ui-express", "better-auth", "inngest", "jest",
]);

const EXPRESS = {
  key: "express",
  label: "Express",
  article: "an",
  map: join(projectRoot, ".claude/skills/use-express-api/express-capabilities.md"),
  skill: join(projectRoot, ".claude/skills/use-express-api/SKILL.md"),
  skillName: "use-express-api",
  docsDomain: "expressjs.com",
  /**
   * Identifiers this stack actually exposes at the head of a call. Checked in
   * on purpose: the lint has to work offline, and a snapshot still catches the
   * typo it exists to catch.
   */
  symbols: new Set([
    "express", "app", "router", "req", "res", "next", "cors", "helmet", "morgan",
    "prisma", "z", "config", "logger", "stream", "betterAuth", "inngest",
    "asyncHandler", "AppError", "errorHandler", "notFoundHandler",
    "transformResponse", "correlationId", "validate", "Promise",
  ]),
  requiredSymbols: [
    "router", "asyncHandler", "AppError", "errorHandler", "transformResponse",
    "prisma", "z", "config", "cors",
  ],
  layers: new Set([
    "app", "route", "controller", "service", "middleware", "config", "types",
    "any", "—",
  ]),
  requiredSections: [
    "## The map",
    "## Where code runs",
    "## The error path",
    "## Sources",
  ],
  /** package -> the major the map must claim. A drift here is a wrong row. */
  versionPins: ["express", "@prisma/client", "zod"],
};

const NEST = {
  key: "nest",
  label: "NestJS",
  article: "a",
  map: join(projectRoot, ".claude/skills/use-nest-api/nest-capabilities.md"),
  skill: join(projectRoot, ".claude/skills/use-nest-api/SKILL.md"),
  skillName: "use-nest-api",
  docsDomain: "docs.nestjs.com",
  symbols: new Set([
    // Nest decorators and classes, written without the leading @.
    "Module", "Global", "Controller", "Injectable", "Get", "Post", "Patch",
    "Put", "Delete", "All", "Body", "Param", "Query", "Req", "Res", "Catch",
    "UseGuards", "Public", "CurrentUser", "CurrentSession", "Type",
    "ValidationPipe", "TransformInterceptor", "BetterAuthGuard", "APP_GUARD",
    "NestFactory", "SwaggerModule", "DocumentBuilder", "ApiTags", "ApiOperation",
    "ApiResponse", "ApiProperty", "HttpException", "BusinessException",
    "PrismaService", "LoggerService", "Reflector", "ExecutionContext",
    // Runtime values.
    "app", "prisma", "env", "auth", "inngest", "toNodeHandler", "IsString",
    "IsArray", "IsOptional", "IsEnum", "ValidateNested", "Promise",
    "trustedOrigins", "allowedOrigins", "isAllowedOrigin",
  ]),
  requiredSymbols: [
    "Module", "Controller", "ValidationPipe", "Catch", "APP_GUARD",
    "TransformInterceptor", "PrismaService", "env", "toNodeHandler",
  ],
  layers: new Set([
    "bootstrap", "module", "controller", "service", "guard", "filter",
    "interceptor", "pipe", "dto", "config", "any", "—",
  ]),
  requiredSections: [
    "## The map",
    "## Where code runs",
    "## The request pipeline",
    "## Sources",
  ],
  versionPins: ["@nestjs/core", "@prisma/client", "better-auth"],
};

const PROFILE = deps["@nestjs/core"] ? NEST : deps.express ? EXPRESS : null;
if (!PROFILE) {
  console.error("capability-lint: neither express nor @nestjs/core is a dependency — nothing to grade");
  process.exit(1);
}

const EXPECTED_HEADERS = [
  "Capability (what you want)",
  "API or symbol",
  "Package",
  "Layer",
  "Reference slice in this repo",
  "Gotcha",
];

// --- setup -------------------------------------------------------------------

const violations = [];
const fail = (rule, message) => violations.push({ rule, message });
const rel = (p) => p.replace(projectRoot + "/", "");

for (const f of [PROFILE.map, PROFILE.skill]) {
  if (!existsSync(f)) {
    console.error(`capability-lint: missing ${rel(f)}`);
    process.exit(1);
  }
}

const md = readFileSync(PROFILE.map, "utf8");
const skill = readFileSync(PROFILE.skill, "utf8");

/** Split a markdown table row into trimmed cells, dropping the edge pipes. */
function cells(line) {
  return line.trim().replace(/^\|/, "").replace(/\|$/, "").split("|").map((c) => c.trim());
}

/** Inline-code tokens inside one cell. */
function code(cell) {
  return [...cell.matchAll(/`([^`]+)`/g)].map((m) => m[1].trim());
}

/** A row whose reference slice says so is documented, not built. */
const isWired = (row) => !/\(not wired/i.test(row.slice);

// --- locate the table --------------------------------------------------------

const mapSection = md.split(/^## /m).find((s) => s.startsWith("The map"));
if (!mapSection) {
  console.error('capability-lint: no "## The map" section');
  process.exit(1);
}
const tableLines = mapSection.split("\n").filter((l) => l.trim().startsWith("|"));
const [headerLine, separatorLine, ...rowLines] = tableLines;

// --- K1: table shape ---------------------------------------------------------

const headers = cells(headerLine ?? "");
if (headers.join("|") !== EXPECTED_HEADERS.join("|")) {
  fail("K1", `table header changed — expected: ${EXPECTED_HEADERS.join(" | ")}`);
}
if (!/^\|[\s|:-]+\|$/.test((separatorLine ?? "").trim())) {
  fail("K1", "table is missing its header separator row");
}

const rows = [];
for (const line of rowLines) {
  const c = cells(line);
  const capability = c[0] ?? "(unnamed row)";
  if (c.length !== EXPECTED_HEADERS.length) {
    fail("K1", `"${capability}" has ${c.length} columns, expected ${EXPECTED_HEADERS.length}`);
    continue;
  }
  const empty = c.findIndex((cell) => cell === "");
  if (empty !== -1) fail("K1", `"${capability}" leaves "${EXPECTED_HEADERS[empty]}" empty`);
  if ((c[5] ?? "").length < 20) {
    fail("K1", `"${capability}" has no real gotcha (write the trap, not a label)`);
  }
  // The layer column is what makes the map actionable — "where does this code
  // go" is the question an agent gets wrong most often, and a free-text answer
  // is not an answer.
  const layer = (c[3] ?? "").replace(/`/g, "").trim();
  if (layer && !PROFILE.layers.has(layer)) {
    fail(
      "K1",
      `"${capability}" puts the code in "${layer}", which is not ${PROFILE.article} ${PROFILE.label} layer — ` +
        `use one of ${[...PROFILE.layers].join(", ")}`,
    );
  }
  rows.push({ capability, api: c[1], pkg: c[2], layer, slice: c[4], gotcha: c[5] });
}
if (rows.length === 0) fail("K1", "the map has no rows");

// --- K2: the APIs are real ---------------------------------------------------

const symbolsSeen = new Set();
for (const row of rows) {
  for (const token of code(row.api)) {
    // A cell often names a chain — `prisma.todo.findMany` — or a decorator.
    // The leading identifier is the claim; the rest is a method name this lint
    // has no business knowing.
    const m = /^@?([A-Za-z_$][\w$]*)/.exec(token);
    if (!m) continue;
    const symbol = m[1];
    symbolsSeen.add(symbol);
    if (!PROFILE.symbols.has(symbol)) {
      fail("K2", `"${row.capability}" names \`${symbol}\`, which is not ${PROFILE.article} ${PROFILE.label} symbol`);
    }
  }
}

// --- K3: packages are real, and a wired row's package is installed -----------

for (const row of rows) {
  const cell = row.pkg.replace(/\([^)]*\)/g, " ");
  // An em dash — written bare or in a code span — is a deliberate "this
  // project's own code, no package", which is different from a forgotten cell.
  if (/^\s*`?—`?\s*$/.test(cell)) continue;
  const tokens = code(cell);
  if (tokens.length === 0) {
    fail("K3", `"${row.capability}" names no package and is not marked "—"`);
    continue;
  }
  for (const t of tokens) {
    if (!KNOWN_PACKAGES.has(t)) {
      fail("K3", `"${row.capability}" names \`${t}\`, which is not a package this stack knows`);
    }
  }
  if (!isWired(row)) continue;
  if (!tokens.some((t) => t in deps)) {
    fail(
      "K3",
      `"${row.capability}" points at a reference slice but package.json depends on none of ` +
        `${tokens.map((t) => `\`${t}\``).join(", ")} — add the dependency, or mark the row "(not wired)"`,
    );
  }
}

// --- K4: every path resolves -------------------------------------------------

const PATH_RE = /`((?:src|scripts|docs|test|prisma|\.claude)\/[^`]+)`/g;
const pathRefs = new Set(); // a slice cited by three rows is one dead path, not three
for (const m of md.matchAll(PATH_RE)) {
  const ref = m[1].replace(/\/$/, "").replace(/\s*\([^)]*\)\s*$/, "");
  if (/[\s*<>{}$|]/.test(ref)) continue; // globs and <placeholders> describe files you create
  pathRefs.add(ref);
}
for (const ref of pathRefs) {
  if (!existsSync(join(projectRoot, ref))) fail("K4", `dead path reference: \`${ref}\``);
}

// --- K5: the skill's description is backed by rows ---------------------------

// The description is a YAML folded scalar, so unwrap it to one line first.
const advertised = (skill.match(/^description:[\s\S]*?(?=\n[a-z_]+:|\n---)/m)?.[0] ?? "").replace(/\s+/g, " ");
const listed = advertised.match(/capability \(([^)]+)\)/)?.[1];
if (!listed) {
  fail("K5", `${PROFILE.skillName}'s description no longer lists its capabilities in \`capability (a, b, c…)\` form`);
} else {
  const haystack = md.toLowerCase();
  for (const raw of listed.split(",")) {
    const keyword = raw.replace(/…/g, "").trim().toLowerCase();
    if (!keyword) continue;
    if (!haystack.includes(keyword)) {
      fail("K5", `the skill advertises "${keyword}" but the map has no row for it`);
    }
  }
}

// --- K6: core coverage -------------------------------------------------------

for (const symbol of PROFILE.requiredSymbols) {
  if (!symbolsSeen.has(symbol)) fail("K6", `no row covers \`${symbol}\``);
}

// --- K7: sections and sourcing -----------------------------------------------

for (const heading of PROFILE.requiredSections) {
  if (!md.includes(`\n${heading}\n`)) fail("K7", `missing section "${heading}"`);
}
if (!new RegExp(PROFILE.docsDomain.replace(/\./g, "\\.")).test(md.split("## Sources")[1] ?? "")) {
  fail("K7", `the Sources section names no ${PROFILE.docsDomain} page`);
}
if (!/\*\*\d{4}-\d{2}-\d{2}\*\*/.test(md)) {
  fail("K7", "the map does not record the date its sources were read");
}

// --- K8: the map is written against the majors this project installs ---------

/** `^4.19.2` / `~5.0.0` / `10.0.0` -> "4". A `*` range pins nothing. */
function major(range) {
  const m = /(\d+)\./.exec(String(range ?? ""));
  return m ? m[1] : null;
}

for (const name of PROFILE.versionPins) {
  const installed = major(deps[name]);
  if (installed === null) {
    fail("K8", `\`${name}\` is not a dependency, so the map cannot be written against it`);
    continue;
  }
  const claimed = new RegExp("`" + name.replace(/[/@]/g, "\\$&") + "`\\s*\\*\\*(\\d+)\\*\\*").exec(md)?.[1];
  if (!claimed) {
    fail("K8", `the map does not say which major of \`${name}\` it was written against`);
  } else if (claimed !== installed) {
    fail(
      "K8",
      `the map is written against \`${name}\` ${claimed} but package.json installs ${installed} — ` +
        `re-read the rows that depend on it rather than editing the number`,
    );
  }
}

// --- report ------------------------------------------------------------------

if (violations.length === 0) {
  const wired = rows.filter(isWired).length;
  console.log(
    `capability-lint: ${rows.length} capabilities mapped (${wired} wired, ${rows.length - wired} documented), ` +
      `${symbolsSeen.size} ${PROFILE.label} symbols, 0 violation(s)`,
  );
  process.exit(0);
}

console.error(`\ncapability-lint: ${violations.length} violation(s)\n`);
for (const v of violations) console.error(`  [${v.rule}] ${v.message}`);
console.error(`\nThe map is \`${rel(PROFILE.map)}\`.\n`);
process.exit(1);
