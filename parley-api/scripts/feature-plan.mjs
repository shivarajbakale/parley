#!/usr/bin/env node
/**
 * feature-plan.mjs — validate a feature-plan.json and render it to FEATURE-PLAN.md.
 *
 * Why this exists
 * ---------------
 * `add-endpoint`, `add-resource`, `add-webhook` and friends start writing files
 * at step two. That makes the first reviewable artifact a diff, by which point
 * the argument is expensive: the route exists, the schema exists, the migration
 * exists, and discovering that the contract was wrong means redoing all three.
 *
 * This renders the review artifact first, and renders it DETERMINISTICALLY —
 * every table and frame is built from the plan's own nodes, never free-drawn, so
 * the document cannot disagree with what gets built.
 *
 * The profile (which surface kinds are legal, what a permission is called, where
 * it is declared) is detected from the repo this runs in, so one script serves
 * every scaffolder that has no screens to wireframe.
 *
 * Usage
 * -----
 *   node scripts/feature-plan.mjs <plan.json>                  # print
 *   node scripts/feature-plan.mjs <plan.json> -o FEATURE-PLAN.md
 *   node scripts/feature-plan.mjs <plan.json> --check          # validate only
 *
 * Dependency-free (Node built-ins only) and idempotent.
 */

import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const PROJECT_ROOT = path.join(__dirname, "..");

// --- profiles ----------------------------------------------------------------

/**
 * Everything repo-specific. `kinds` is the vocabulary a plan may use; each entry
 * says whether that kind draws a screen and what the reviewer needs to see.
 */
const PROFILES = {
  "framer-plugin": {
    key: "framer-plugin",
    product: "a Framer plugin",
    // framer.json is the file Framer itself reads, and nothing else in this
    // repository family ships one — so its presence is the whole detection.
    marker: "framer.json",
    kinds: {
      mode: { ui: true, note: "a launch context declared in framer.json — the plugin window a user sees there" },
      recipe: { ui: false, note: "one job the plugin does end to end, under src/recipes" },
      "cms-sync": { ui: false, note: "a managed-collection sync: fields, mapping, and the write" },
      source: { ui: false, note: "an external data source behind fetchRecords()" },
    },
    // A plugin's real permission surface is the mode list: a plugin can only be
    // launched in a mode it declares, so an undeclared mode is a feature nobody
    // can reach.
    permissionWord: "plugin mode",
    permissionFile: "framer.json",
    capabilityMap: null,
    verification: ["npm run typecheck", "npm run lint", "npm run manifest-lint", "npm run plan-lint", "npm test"],
  },
  "framer-component": {
    key: "framer-component",
    product: "a Framer code-component library",
    marker: "src/framer-shim.ts",
    kinds: {
      component: { ui: true, note: "a code component — one file, one default export, pasted into Framer's editor" },
      control: { ui: false, note: "a property control added to an existing component" },
      shim: { ui: false, note: "an addition to src/framer-shim.ts, standing in for the editor's `framer` module" },
    },
    // Property controls are what a designer is allowed to change. A prop with
    // no control is a prop only a developer can set.
    permissionWord: "property control",
    permissionFile: "src/components/index.ts",
    capabilityMap: null,
    verification: ["npm run typecheck", "npm run lint", "npm run component-lint", "npm run plan-lint", "npm test"],
  },
  shopify: {
    key: "shopify",
    product: "an embedded Shopify app",
    marker: "shopify.app.toml",
    kinds: {
      "admin-page": { ui: true, note: "embedded in Shopify admin, inside App Bridge — Polaris only" },
      "api-route": { ui: false, note: "a Next.js route handler under app/api" },
      webhook: { ui: false, note: "a Shopify topic delivered to /api/webhooks" },
      job: { ui: false, note: "an Inngest function, retried on failure" },
      agent: { ui: false, note: "a Mastra agent or tool" },
    },
    permissionWord: "Shopify access scope",
    permissionFile: "shopify.app.toml",
    capabilityMap: path.join(PROJECT_ROOT, ".claude/skills/use-shopify-api/shopify-capabilities.md"),
    // The six page shapes the admin itself uses. An admin-page surface declares
    // one, and plan-lint P5 holds this list and the document to each other.
    archetypes: ["index", "detail", "form", "settings", "wizard", "dashboard"],
    archetypeDoc: "docs/principles/polaris-archetypes.md",
    verification: ["npm run type-check", "npm run lint", "npm run plan-lint", "npm run capability-lint", "npm run doc-links"],
  },
  nestjs: {
    key: "nestjs",
    product: "a NestJS service",
    marker: "nest-cli.json",
    kinds: {
      endpoint: { ui: false, note: "a controller route" },
      resource: { ui: false, note: "a module: controller, service, entity, DTOs" },
      job: { ui: false, note: "a scheduled or queued task" },
    },
    permissionWord: "auth guard",
    permissionFile: "src/",
    capabilityMap: null,
    verification: ["npm run type-check", "npm run lint", "npm run plan-lint", "npm run test"],
  },
  express: {
    key: "express",
    product: "an Express service",
    // NestJS ships a Prisma schema too, so this marker only means Express when
    // nest-cli.json is absent. Detection that depends on object order is
    // detection that breaks the day someone reorders the object.
    marker: "prisma/schema.prisma",
    excludes: ["nest-cli.json"],
    kinds: {
      endpoint: { ui: false, note: "a route handler plus its zod schema" },
      resource: { ui: false, note: "a router, service, and Prisma model" },
      job: { ui: false, note: "a scheduled or queued task" },
    },
    permissionWord: "auth middleware",
    permissionFile: "src/",
    capabilityMap: null,
    verification: ["npm run type-check", "npm run lint", "npm run plan-lint", "npm run test"],
  },
  astro: {
    key: "astro",
    product: "an Astro marketing site",
    marker: "astro.config.mjs",
    kinds: {
      page: { ui: true, note: "a route under src/pages — indexed, shared, and judged on first paint" },
      section: { ui: true, note: "a composable block a page assembles" },
      collection: { ui: false, note: "a content collection plus its schema" },
      endpoint: { ui: false, note: "an Astro endpoint (form post, feed, redirect)" },
    },
    permissionWord: "content schema",
    permissionFile: "src/content.config.ts",
    capabilityMap: null,
    verification: ["npm run build", "npm run check", "npm run plan-lint"],
  },
  ts: {
    key: "ts",
    product: "a TypeScript library",
    // The fallback profile: a plain library is the case with no distinguishing
    // marker, so it is identified by the absence of the others rather than by a
    // file that may or may not exist.
    marker: null,
    kinds: {
      module: { ui: false, note: "an exported module — part of the public surface" },
      internal: { ui: false, note: "internal, not exported from the entry point" },
    },
    permissionWord: "export",
    permissionFile: "src/index.ts",
    capabilityMap: null,
    verification: ["npm run type-check", "npm run lint", "npm run plan-lint", "npm run test"],
  },
};

export function detectProfile(root = PROJECT_ROOT) {
  for (const profile of Object.values(PROFILES)) {
    if (!profile.marker) continue;
    if (!fs.existsSync(path.join(root, profile.marker))) continue;
    if ((profile.excludes ?? []).some((f) => fs.existsSync(path.join(root, f)))) continue;
    return profile;
  }
  return PROFILES.ts;
}

export const PROFILE = detectProfile();
export const KINDS = Object.keys(PROFILE.kinds);
/** The page shapes a UI surface may declare. Empty where the stack has none. */
export const ARCHETYPES = PROFILE.archetypes ?? [];
export const ARCHETYPE_DOC = PROFILE.archetypeDoc ?? null;

/** Every surface a user waits on owes all four. Missing one is a bug, not a shortcut. */
const REQUIRED_STATES = ["loading", "empty", "error", "success"];

// --- capability map ----------------------------------------------------------

export function readCapabilityMap(file = PROFILE.capabilityMap) {
  if (!file || !fs.existsSync(file)) return null;
  const rows = fs
    .readFileSync(file, "utf8")
    .split("\n")
    .filter((l) => l.trim().startsWith("|"))
    .map((l) => l.trim().replace(/^\|/, "").replace(/\|$/, "").split("|").map((c) => c.trim()));
  const capabilities = new Map();
  for (const cells of rows) {
    if (cells.length !== 6) continue;
    if (cells[0].startsWith("Capability") || /^-+$/.test(cells[0])) continue;
    capabilities.set(cells[0].toLowerCase(), { capability: cells[0], api: cells[1], permission: cells[2] });
  }
  return capabilities.size ? capabilities : null;
}

// --- validation --------------------------------------------------------------

export function validateFeaturePlan(plan, { capabilityMap = readCapabilityMap() } = {}) {
  const e = [];
  const need = (cond, msg) => { if (!cond) e.push(msg); };

  need(plan && typeof plan === "object", "plan must be an object");
  if (!plan || typeof plan !== "object") return e;

  const f = plan.feature;
  need(f && typeof f === "object", "feature: required object");
  if (f) {
    need(typeof f.id === "string" && /^[a-z][a-z0-9-]*$/.test(f.id),
      "feature.id: required kebab-case string");
    need(typeof f.title === "string" && f.title.length > 0, "feature.title: required");
    need(typeof f.problem === "string" && f.problem.length > 0,
      "feature.problem: required — a plan with no problem statement cannot be reviewed");
  }

  need(Array.isArray(plan.surfaces) && plan.surfaces.length > 0,
    "surfaces: at least one required");

  for (const [i, s] of (plan.surfaces ?? []).entries()) {
    const at = `surfaces[${i}]`;
    need(typeof s.id === "string", `${at}.id: required`);
    need(typeof s.name === "string", `${at}.name: required`);
    need(KINDS.includes(s.kind),
      `${at}.kind: must be one of ${KINDS.join(" | ")} (got ${JSON.stringify(s.kind)}) — the kind decides what the reviewer is being shown`);

    const spec = PROFILE.kinds[s.kind];
    if (!spec) continue;

    if (spec.ui) {
      need(Array.isArray(s.panels) && s.panels.length > 0,
        `${at}.panels: at least one required — a screen with no panels cannot be drawn`);
      for (const st of REQUIRED_STATES) {
        need(s.states && typeof s.states[st] === "string" && s.states[st].length > 0,
          `${at}.states.${st}: required — every screen that waits on data renders all four states`);
      }
    } else {
      need(!s.panels?.length,
        `${at}: a ${s.kind} draws nothing — drop panels[] and describe its contract instead`);
      need(typeof s.entrypoint === "string" && s.entrypoint.length > 0,
        `${at}.entrypoint: required — name the file or handler this becomes`);
    }
  }

  for (const [i, ep] of (plan.endpoints ?? []).entries()) {
    const at = `endpoints[${i}]`;
    need(/^(GET|POST|PUT|PATCH|DELETE)$/.test(ep.method ?? ""),
      `${at}.method: required — one of GET, POST, PUT, PATCH, DELETE`);
    need(typeof ep.path === "string" && ep.path.startsWith("/"), `${at}.path: required, absolute`);
    need(typeof ep.purpose === "string" && ep.purpose.length > 0, `${at}.purpose: required`);
    need(typeof ep.auth === "string" && ep.auth.length > 0,
      `${at}.auth: required — say who may call this, including "public" if that is the decision`);
  }

  for (const [i, w] of (plan.webhooks ?? []).entries()) {
    const at = `webhooks[${i}]`;
    need(typeof w.topic === "string" && w.topic.length > 0, `${at}.topic: required`);
    need(typeof w.handler === "string" && w.handler.length > 0, `${at}.handler: required`);
    // Every webhook platform worth the name delivers at least once, which means
    // duplicates are normal traffic, not an edge case.
    need(w.idempotent === true,
      `${at}.idempotent: must be true — webhooks are delivered at least once, so the handler has to survive the same event twice. Say what makes it safe in .idempotencyNote.`);
    need(typeof w.idempotencyNote === "string" && w.idempotencyNote.length > 0,
      `${at}.idempotencyNote: required — what key or state makes a repeat delivery a no-op`);
  }

  for (const [i, j] of (plan.jobs ?? []).entries()) {
    const at = `jobs[${i}]`;
    need(typeof j.name === "string" && j.name.length > 0, `${at}.name: required`);
    need(typeof j.trigger === "string" && j.trigger.length > 0,
      `${at}.trigger: required — an event name or a schedule`);
    need(typeof j.onFailure === "string" && j.onFailure.length > 0,
      `${at}.onFailure: required — a retried job that fails forever is an outage nobody is paged for`);
  }

  for (const [i, en] of (plan.entities ?? []).entries()) {
    const at = `entities[${i}]`;
    need(typeof en.name === "string" && en.name.length > 0, `${at}.name: required`);
    need(Array.isArray(en.fields) && en.fields.length > 0,
      `${at}.fields: at least one — an entity with no fields is a name, not a model`);
  }

  for (const [i, c] of (plan.components ?? []).entries()) {
    const at = `components[${i}]`;
    need(typeof c.control === "string", `${at}.control: required`);
    need(typeof c.why === "string" && c.why.length > 0,
      `${at}.why: required — an unjustified choice is the thing this plan exists to surface`);
  }

  if (capabilityMap) {
    for (const [i, c] of (plan.capabilities ?? []).entries()) {
      need(c && typeof c.capability === "string" && capabilityMap.has(c.capability.toLowerCase()),
        `capabilities[${i}].capability: no row in the capability map for ${JSON.stringify(c?.capability)} — add the row (and its ${PROFILE.permissionWord}) before promising the capability`);
    }
  }

  return e;
}

// --- ascii primitives --------------------------------------------------------

const FRAME_W = 76;

function pad(s, n) {
  const t = String(s ?? "");
  if (t.length > n) return n <= 1 ? t.slice(0, n) : t.slice(0, n - 1) + "…";
  return t + " ".repeat(n - t.length);
}

function centre(s, n) {
  const t = String(s ?? "");
  if (t.length >= n) return pad(t, n);
  const left = Math.floor((n - t.length) / 2);
  return " ".repeat(left) + t + " ".repeat(n - t.length - left);
}

const rule = (n) => "─".repeat(n);

function boxOf(w, rows) {
  const inner = w - 2;
  const out = ["┌" + rule(inner) + "┐"];
  for (const r of rows) {
    if (r === "---") out.push("├" + rule(inner) + "┤");
    else out.push("│" + pad(r, inner) + "│");
  }
  out.push("└" + rule(inner) + "┘");
  return out;
}

function hjoin(blocks, gap = 1) {
  const widths = blocks.map((b) => Math.max(...b.map((l) => l.length), 0));
  const height = Math.max(...blocks.map((b) => b.length));
  const spacer = " ".repeat(gap);
  const out = [];
  for (let i = 0; i < height; i++) {
    out.push(blocks.map((b, j) => pad(b[i] ?? "", widths[j])).join(spacer).replace(/\s+$/, ""));
  }
  return out;
}

function wrap(text, n) {
  const words = String(text).split(/\s+/);
  const lines = [];
  let line = "";
  for (const word of words) {
    if ((line + " " + word).trim().length > n) { lines.push(line.trim()); line = word; }
    else line = (line + " " + word).trim();
  }
  if (line) lines.push(line);
  return lines;
}

function columnize(rows, width) {
  if (!rows.length) return [];
  const cells = rows.map((r) => (Array.isArray(r) ? r : [r]).map(String));
  const cols = Math.max(...cells.map((c) => c.length));
  const w = [];
  for (let c = 0; c < cols; c++) w.push(Math.max(...cells.map((r) => (r[c] ?? "").length)));
  return cells.map((r) => {
    const parts = r.map((v, c) => (c === cols - 1 && cols > 1 ? String(v).padStart(w[c]) : pad(v, w[c])));
    return pad(parts.join("  "), width);
  });
}

function panelBox(panel, w) {
  const inner = w - 2;
  const rows = [];
  if (panel.title) {
    const badge = panel.badge ? String(panel.badge) : "";
    rows.push(" " + pad(badge ? pad(panel.title, inner - 3 - badge.length) + badge : panel.title, inner - 1));
    if (panel.rows?.length || panel.fields?.length) rows.push(" " + rule(inner - 2) + " ");
  }
  if (panel.rows?.length) for (const l of columnize(panel.rows, inner - 2)) rows.push(" " + l + " ");
  if (panel.fields?.length) {
    for (const f of panel.fields) {
      rows.push(" " + pad(f.label, inner - 2) + " ");
      rows.push(" " + pad(`[ ${pad(f.placeholder ?? "", Math.max(0, inner - 8))}]`, inner - 2) + " ");
    }
  }
  if (panel.body) for (const l of wrap(panel.body, inner - 2)) rows.push(" " + pad(l, inner - 2) + " ");
  if (panel.actions?.length) {
    rows.push(" " + rule(inner - 2) + " ");
    rows.push(" " + pad(panel.actions.map((a) => `[ ${a} ]`).join(" "), inner - 2) + " ");
  }
  return boxOf(w, rows);
}

// --- frames ------------------------------------------------------------------

/** A screen, inside whatever chrome the host imposes. */
function screenFrame(surface) {
  const inner = FRAME_W - 2;
  const rows = [];
  rows.push(
    PROFILE.key === "shopify"
      ? " ⌂ Shopify admin  ▸ Apps  ▸ " + pad(surface.name, inner - 33) + "  ⋯ "
      : " " + pad(surface.name, inner - 2) + " ",
  );
  rows.push("---");
  if (surface.primaryAction) {
    rows.push(" " + pad(surface.name, inner - 24) + pad(`[ ${surface.primaryAction} ]`, 22) + " ");
    rows.push("");
  }
  for (const p of surface.panels) {
    for (const l of panelBox(p, inner - 2)) rows.push(" " + pad(l, inner - 2) + " ");
    rows.push("");
  }
  while (rows.length && rows[rows.length - 1] === "") rows.pop();
  return boxOf(FRAME_W, rows);
}

/** A contract with no screen: what triggers it, what it becomes, what it touches. */
function contractFrame(surface) {
  const spec = PROFILE.kinds[surface.kind];
  const lines = [];
  lines.push(`  ${surface.trigger ?? "caller"}`);
  lines.push("        │");
  lines.push(`        └──▶  ${surface.entrypoint}`);
  if (surface.calls?.length) {
    for (const c of surface.calls) {
      lines.push("                  │");
      lines.push(`                  └──▶  ${c}`);
    }
  }
  lines.push("");
  lines.push(`  ${spec.note}`);
  return boxOf(FRAME_W, lines.map((l) => pad(l, FRAME_W - 2)));
}

function statesGrid(surface) {
  const w = 22;
  const bodies = [
    ["▓▓▓▓▓▓▓▓▓▓▓▓", "▓▓▓▓▓▓  ▓▓▓▓", "▓▓▓▓▓▓▓▓▓▓▓▓"],
    [...wrap(surface.states.empty, w - 4), ...(surface.primaryAction ? ["", `[ ${surface.primaryAction} ]`] : [])],
    ["⚠", ...wrap(surface.states.error, w - 4), "", "[ Try again ]"],
  ];
  const tall = Math.max(...bodies.map((b) => b.length));
  const notes = ["skeleton, not spinner", "one CTA", "retry, never a stack"];
  const labels = ["loading", "empty", "error"];
  return hjoin(
    bodies.map((body, i) => {
      const rows = [...body, ...Array(tall - body.length).fill("")].map((l) => " " + pad(l, w - 3));
      return [centre(labels[i], w), ...boxOf(w, rows), centre(notes[i], w)];
    }),
    3,
  );
}

// --- markdown ----------------------------------------------------------------

const fence = (lines) => "```\n" + lines.join("\n").replace(/[ \t]+$/gm, "") + "\n```";

function renderSurface(s) {
  const spec = PROFILE.kinds[s.kind];
  const out = [];
  out.push(`### ${s.name}`);
  out.push("");
  out.push(`Kind: \`${s.kind}\` — ${spec.note}`);
  if (spec.ui && s.archetype) { out.push(""); out.push(`Archetype: \`${s.archetype}\``); }
  if (s.purpose) { out.push(""); out.push(s.purpose); }
  out.push("");
  out.push(fence(spec.ui ? screenFrame(s) : contractFrame(s)));
  out.push("");
  if (spec.ui) {
    out.push("**States**");
    out.push("");
    out.push(fence(statesGrid(s)));
    out.push("");
    out.push(`Success: ${s.states.success}`);
    out.push("");
  } else {
    out.push(`Becomes: \`${s.entrypoint}\``);
    out.push("");
  }
  return out;
}

function table(title, headers, rows, preamble = []) {
  if (!rows.length) return [];
  return [
    `## ${title}`,
    "",
    ...preamble,
    ...(preamble.length ? [""] : []),
    `| ${headers.join(" | ")} |`,
    `| ${headers.map(() => "---").join(" | ")} |`,
    ...rows,
    "",
  ];
}

function renderEndpoints(plan) {
  return table(
    "Endpoints",
    ["Endpoint", "Purpose", "Auth"],
    (plan.endpoints ?? []).map((e) => `| \`${e.method} ${e.path}\` | ${e.purpose} | ${e.auth} |`),
    ["`auth` is required on every row, including `public` — an endpoint whose",
     "audience nobody decided is an endpoint everyone can call."],
  );
}

function renderWebhooks(plan) {
  return table(
    "Webhooks",
    ["Topic", "Handler", "What makes a repeat delivery safe"],
    (plan.webhooks ?? []).map((w) => `| \`${w.topic}\` | \`${w.handler}\` | ${w.idempotencyNote} |`),
    ["Delivery is at least once. Every handler here has to survive the same",
     "event arriving twice, and the third column is how."],
  );
}

function renderJobs(plan) {
  return table(
    "Background work",
    ["Job", "Trigger", "When it fails"],
    (plan.jobs ?? []).map((j) => `| \`${j.name}\` | ${j.trigger} | ${j.onFailure} |`),
  );
}

function renderEntities(plan) {
  if (!plan.entities?.length) return [];
  const out = ["## Data model", ""];
  const boxes = plan.entities.map((en) =>
    panelBox({ title: en.name, rows: en.fields.map((f) => (typeof f === "string" ? [f] : [f.name, f.type ?? ""])) }, 30),
  );
  for (let i = 0; i < boxes.length; i += 2) out.push(...hjoin(boxes.slice(i, i + 2), 3));
  return [out[0], out[1], fence(out.slice(2)), ""];
}

function renderCapabilities(plan) {
  if (!plan.capabilities?.length) return [];
  return table(
    "Host capabilities",
    ["Capability", "Note"],
    plan.capabilities.map((c) => `| ${c.capability} | ${c.note ?? "—"} |`),
    [`Each row matches the capability map, which names the API, the ${PROFILE.permissionWord}`,
     `to declare in \`${PROFILE.permissionFile}\`, and the gotcha. A capability with no row fails`,
     "validation — a plan cannot promise something nobody has decided how to build."],
  );
}

function renderComponents(plan) {
  return table(
    "Choices",
    ["Where", "Choice", "Why this one", "Not"],
    (plan.components ?? []).map(
      (c) => `| ${c.surface ?? "—"} | \`${c.control}\` | ${c.why} | ${c.rejected ? `\`${c.rejected}\`` : "—"} |`,
    ),
  );
}

function renderBlastRadius(plan) {
  const b = plan.blastRadius;
  if (!b) return [];
  const lines = [];
  if (b.new?.length) {
    lines.push(`new (${b.new.length})`);
    b.new.forEach((f, i) => lines.push(`  ${i === b.new.length - 1 ? "└──" : "├──"} ${f}`));
  }
  if (b.changed?.length) {
    if (lines.length) lines.push("");
    lines.push(`changed (${b.changed.length})`);
    b.changed.forEach((f, i) => lines.push(`  ${i === b.changed.length - 1 ? "└──" : "├──"} ${f}`));
  }
  return lines.length ? ["## Blast radius", "", fence(lines), ""] : [];
}

function renderVerification(plan) {
  const steps = plan.verification?.length ? plan.verification : PROFILE.verification;
  return ["## Verification plan", "", ...steps.map((s) => `- [ ] \`${s}\``), "- [ ] `verify` — run it against a real environment, not only the test suite", ""];
}

export function renderFeaturePlanMarkdown(plan, opts = {}) {
  const errors = validateFeaturePlan(plan, opts);
  if (errors.length) {
    throw new Error("Invalid feature plan:\n" + errors.map((e) => "  - " + e).join("\n"));
  }
  const f = plan.feature;
  const out = [];
  out.push("<!-- feature-plan:v1 — generated, do not hand-edit.");
  out.push(`     Regenerate with: node scripts/feature-plan.mjs ${f.id}.feature-plan.json -o FEATURE-PLAN.md -->`);
  out.push("");
  out.push(`# ${f.title}`);
  out.push("");
  const kinds = [...new Set(plan.surfaces.map((s) => s.kind))];
  out.push(`\`${f.id}\` · ${PROFILE.product} · ${plan.surfaces.length} surface${plan.surfaces.length === 1 ? "" : "s"} · ${kinds.join(", ")}`);
  out.push("");
  out.push("## Problem");
  out.push("");
  out.push(f.problem);
  out.push("");
  if (f.nonGoals?.length) {
    out.push("## Not in this feature");
    out.push("");
    for (const n of f.nonGoals) out.push(`- ${n}`);
    out.push("");
  }
  out.push("## Surfaces");
  out.push("");
  for (const s of plan.surfaces) out.push(...renderSurface(s));
  out.push(...renderEndpoints(plan));
  out.push(...renderWebhooks(plan));
  out.push(...renderJobs(plan));
  out.push(...renderEntities(plan));
  out.push(...renderCapabilities(plan));
  out.push(...renderComponents(plan));
  out.push(...renderBlastRadius(plan));
  out.push(...renderVerification(plan));
  out.push("---");
  out.push("");
  out.push("Approve this before any file is written. Every table and frame above is");
  out.push("rendered from this feature's plan JSON, so the document and the build cannot");
  out.push("drift — and the fields the validator insists on (auth on every endpoint,");
  out.push("idempotency on every webhook, a failure path on every job) are the ones that");
  out.push("are expensive to discover in production.");
  out.push("");
  return out.join("\n");
}

// --- cli ---------------------------------------------------------------------

const invokedDirectly =
  process.argv[1] && path.resolve(process.argv[1]).endsWith("feature-plan.mjs");

if (invokedDirectly) {
  const args = process.argv.slice(2);
  const file = args.find((a) => !a.startsWith("-"));
  if (!file) {
    console.error("usage: node scripts/feature-plan.mjs <plan.json> [-o FEATURE-PLAN.md] [--check]");
    process.exit(2);
  }
  const plan = JSON.parse(fs.readFileSync(file, "utf8"));
  const errors = validateFeaturePlan(plan);
  if (errors.length) {
    console.error(`feature-plan: ${errors.length} problem(s) in ${file}`);
    for (const e of errors) console.error("  - " + e);
    process.exit(1);
  }
  if (args.includes("--check")) {
    console.log(`feature-plan: ${file} is valid (${plan.surfaces.length} surfaces)`);
    process.exit(0);
  }
  const md = renderFeaturePlanMarkdown(plan);
  const oIndex = args.indexOf("-o");
  if (oIndex !== -1 && args[oIndex + 1]) {
    fs.writeFileSync(args[oIndex + 1], md);
    console.log(`feature-plan: ${plan.surfaces.length} surfaces → ${args[oIndex + 1]}`);
  } else {
    process.stdout.write(md);
  }
}
