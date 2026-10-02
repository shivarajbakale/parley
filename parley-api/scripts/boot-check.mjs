#!/usr/bin/env node
/**
 * boot-check — start the *built* server against a throwaway database and see
 * whether it actually runs.
 *
 * Every other gate in `make check` reads source. Type-check reads types, lint
 * reads style, the unit tests import modules and call them directly. None of
 * them start the process, so none of them can catch the class of defect where
 * every module is individually correct and the assembled application does not
 * boot: a provider named two different things in two files, a middleware
 * registered in the wrong order, a missing environment variable that only the
 * bootstrap path reads, a Prisma client generated against a different schema.
 *
 * The reason no backend in this repo had one until now was the database. A gate
 * that needs a running Postgres needs Docker, and a gate that needs Docker gets
 * skipped in exactly the environments where nobody notices it was skipped. With
 * a file-backed database there is nothing to install: this creates a database in
 * a temp directory, boots against it, and deletes it.
 *
 * It is deliberately shallow and deliberately last. It does not test behaviour —
 * that is what the test suite is for. It answers the one question nothing else
 * asks: does the thing we are about to hand someone start, serve, and stop.
 *
 *   npm run boot-check
 */
import { spawn, execFileSync } from "node:child_process";
import fs from "node:fs";
import net from "node:net";
import os from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");

/**
 * Each backend assembles itself differently, so the probe has to know which one
 * it is looking at. Detected from the repo rather than configured, so a
 * scaffolded project needs no extra wiring.
 */
const PROFILES = {
  nestjs: {
    key: "nestjs",
    label: "NestJS",
    marker: "nest-cli.json",
    entry: "dist/main.js",
    // Nest's global prefix, set in src/main.ts.
    prefix: "/api",
    // The auth guard is global and applies by default. A route that answers 200
    // without a session means the guard is not wired, which is the kind of thing
    // that passes every unit test.
    guarded: "/todos",
    // Better Auth refuses any auth route whose Origin is not on its own
    // `trustedOrigins` list, and that list is configured separately from the
    // CORS allowlist. When the two disagree the failure is invisible until a
    // real browser tries to sign in: the preflight passes, every ordinary route
    // works, and the auth routes alone answer 403 INVALID_ORIGIN. Only a
    // production-mode boot can catch it — Better Auth disables the check when
    // NODE_ENV is `test`, which is what the e2e suite runs under.
    signUp: { path: "/auth/sign-up/email", origin: "http://localhost:5173" },
  },
  express: {
    key: "express",
    label: "Express",
    marker: "src/server.ts",
    entry: "dist/server.js",
    // Mounted in src/app.ts.
    prefix: "/api",
    guarded: null,
    signUp: null,
  },
};

function detectProfile(root = ROOT) {
  for (const profile of Object.values(PROFILES)) {
    if (fs.existsSync(path.join(root, profile.marker))) return profile;
  }
  return PROFILES.express;
}

const PROFILE = detectProfile();

// How long a server gets to start listening, and how long it gets to honour
// SIGTERM. Both are generous by default because a cold start on a loaded CI box
// is legitimately slow, and both are overridable because this script's own test
// suite has to reach the timeout deliberately and cannot spend 25 seconds doing
// it.
const START_TIMEOUT_MS = Number(process.env.BOOT_CHECK_TIMEOUT_MS ?? 25_000);
const STOP_TIMEOUT_MS = Number(process.env.BOOT_CHECK_STOP_MS ?? 8_000);

const failures = [];
const fail = (what, detail) => failures.push({ what, detail });

/** A port the OS just told us is free. `listen` is asynchronous, so the address
 *  is not readable until it fires — reading it synchronously returns null. */
function freePort() {
  return new Promise((resolve, reject) => {
    const srv = net.createServer();
    srv.once("error", reject);
    srv.listen(0, "127.0.0.1", () => {
      const { port } = srv.address();
      srv.close(() => resolve(port));
    });
  });
}

const entry = path.join(ROOT, PROFILE.entry);
if (!fs.existsSync(entry)) {
  console.error(
    `boot-check: ${PROFILE.entry} is missing — run \`npm run build\` first. ` +
      `This gate boots the built artifact on purpose; booting the sources would test a different program from the one that ships.`,
  );
  process.exit(1);
}

const workDir = fs.mkdtempSync(path.join(os.tmpdir(), "boot-check-"));
const dbFile = path.join(workDir, "boot.db");
const databaseUrl = `file:${dbFile}`;
const port = await freePort();
const base = `http://127.0.0.1:${port}${PROFILE.prefix}`;

let child = null;

const env = {
  ...process.env,
  NODE_ENV: "production",
  PORT: String(port),
  DATABASE_URL: databaseUrl,
  // A boot that silently accepted the shipped development secret would prove
  // nothing about a real deployment, but refusing to boot without one would
  // make this gate need configuration. A throwaway value keeps it hermetic.
  BETTER_AUTH_SECRET: process.env.BETTER_AUTH_SECRET ?? "boot-check-throwaway-secret",
  BETTER_AUTH_URL: `http://127.0.0.1:${port}`,
};

async function main() {
  // 1. A schema in a temp file. Nothing is shared with the developer's own
  //    database, so this is safe to run at any time and leaves nothing behind.
  //    A project with no Prisma schema has no schema to push; the boot probes
  //    below are still worth running, so this step is skipped rather than fatal.
  if (!fs.existsSync(path.join(ROOT, "prisma/schema.prisma"))) {
    console.log("boot-check: no prisma/schema.prisma — booting without a database");
  } else try {
    execFileSync("npx", ["prisma", "db", "push", "--skip-generate", "--accept-data-loss"], {
      cwd: ROOT,
      env,
      stdio: "pipe",
    });
  } catch (err) {
    const out = `${err.stdout ?? ""}${err.stderr ?? ""}`.trim();
    fail("create the schema", `\`prisma db push\` failed against a fresh database:\n${indent(out)}`);
    return;
  }

  // 2. Boot the built artifact.
  child = spawn(process.execPath, [entry], { cwd: ROOT, env, stdio: ["ignore", "pipe", "pipe"] });
  let stdout = "";
  let stderr = "";
  let exited = null;
  child.stdout.on("data", (d) => (stdout += d));
  child.stderr.on("data", (d) => (stderr += d));
  child.on("exit", (code, signal) => (exited = { code, signal }));

  const healthy = await waitFor(`${base}/health`, START_TIMEOUT_MS, () => exited);
  if (exited) {
    fail(
      "start",
      `the process exited during startup (code ${exited.code}, signal ${exited.signal}) instead of listening.\n` +
        indent(lastLines(stderr || stdout, 20)),
    );
    return;
  }
  if (!healthy) {
    fail("start", `no response from ${base}/health within ${Math.round(START_TIMEOUT_MS / 1000)}s. Last output:\n${indent(lastLines(stderr || stdout, 20))}`);
    return;
  }

  // 3. Health answers, and answers with a body rather than an empty 200.
  if (healthy.status !== 200) {
    fail("serve health", `GET ${base}/health returned ${healthy.status}, expected 200`);
  } else if (!healthy.json) {
    fail("serve health", `GET ${base}/health returned a non-JSON body: ${truncate(healthy.body)}`);
  }

  // 4. An unknown route is a 404 with a JSON body — not a 500, and not a stack
  //    trace. A leaked stack tells an attacker the framework, the file layout
  //    and often the absolute path of the deploy.
  const missing = await get(`${base}/__boot_check_no_such_route__`);
  if (!missing) {
    fail("handle an unknown route", "no response at all");
  } else {
    if (missing.status !== 404) {
      fail("handle an unknown route", `expected 404, got ${missing.status}: ${truncate(missing.body)}`);
    }
    if (looksLikeStackTrace(missing.body)) {
      fail(
        "handle an unknown route",
        `the 404 body contains a stack trace, which leaks the file layout to any caller:\n${indent(truncate(missing.body))}`,
      );
    }
  }

  // 5. Where auth is global, an unauthenticated request must be refused. A 200
  //    here means the guard is registered but not applied.
  if (PROFILE.guarded) {
    const guarded = await get(`${base}${PROFILE.guarded}`);
    if (!guarded) {
      fail("refuse an unauthenticated request", "no response at all");
    } else if (guarded.status !== 401) {
      fail(
        "refuse an unauthenticated request",
        `GET ${base}${PROFILE.guarded} returned ${guarded.status} with no session, expected 401. ` +
          `The global auth guard is not protecting this route.`,
      );
    }
  }

  // 5b. An auth route must accept the browser origin CORS already accepts. See
  //     the note on PROFILE.signUp: this is the one check that has to happen
  //     against a production-mode boot, so it lives here rather than in the e2e
  //     suite, which runs where the check is switched off.
  if (PROFILE.signUp) {
    const origin = PROFILE.signUp.origin;
    const signUp = await post(
      `${base}${PROFILE.signUp.path}`,
      { "Content-Type": "application/json", Origin: origin },
      JSON.stringify({
        email: `boot-check-${process.pid}-${Date.now()}@example.invalid`,
        password: "boot-check-throwaway-password",
        name: "boot-check",
      }),
    );
    if (!signUp) {
      fail("accept a sign-up from the frontend origin", "no response at all");
    } else if (signUp.status === 403) {
      fail(
        "accept a sign-up from the frontend origin",
        `POST ${base}${PROFILE.signUp.path} with \`Origin: ${origin}\` returned 403: ${truncate(signUp.body)}\n` +
          `That origin passes CORS, so a browser gets a clean preflight and this refusal — the two allowlists disagree. ` +
          `Both must come from the one list in src/config/origins.ts.`,
      );
    } else if (signUp.status !== 200) {
      fail(
        "accept a sign-up from the frontend origin",
        `POST ${base}${PROFILE.signUp.path} with \`Origin: ${origin}\` returned ${signUp.status}, expected 200: ${truncate(signUp.body)}`,
      );
    }
  }

  // 6. Nothing crashed while we were talking to it.
  const fatal = stderr
    .split("\n")
    .filter((l) => /UnhandledPromiseRejection|Uncaught|FATAL|ERR_UNHANDLED/i.test(l));
  if (fatal.length) {
    fail("run without crashing", `the process logged a fatal error while serving:\n${indent(fatal.slice(0, 5).join("\n"))}`);
  }

  // 7. It stops when asked. A server that ignores SIGTERM is one a deploy has to
  //    kill, which drops in-flight requests on every release.
  const stopped = await stop(child);
  if (!stopped) {
    fail("shut down", "the process ignored SIGTERM and had to be killed. Its graceful-shutdown handler is not working.");
  }
  child = null;
}

// ------------------------------------------------------------------ helpers --
async function get(url) {
  try {
    const res = await fetch(url, { redirect: "manual" });
    const body = await res.text();
    let json = null;
    try {
      json = JSON.parse(body);
    } catch {
      json = null;
    }
    return { status: res.status, body, json };
  } catch {
    return null;
  }
}

async function post(url, headers, body) {
  try {
    const res = await fetch(url, { method: "POST", headers, body, redirect: "manual" });
    const text = await res.text();
    return { status: res.status, body: text };
  } catch {
    return null;
  }
}

async function waitFor(url, timeoutMs, exitedFn) {
  const deadline = Date.now() + timeoutMs;
  while (Date.now() < deadline) {
    if (exitedFn()) return null;
    const res = await get(url);
    if (res) return res;
    await new Promise((r) => setTimeout(r, 250));
  }
  return null;
}

function stop(proc) {
  return new Promise((resolve) => {
    if (proc.exitCode !== null) return resolve(true);
    const kill = setTimeout(() => {
      proc.kill("SIGKILL");
      resolve(false);
    }, STOP_TIMEOUT_MS);
    proc.once("exit", () => {
      clearTimeout(kill);
      resolve(true);
    });
    proc.kill("SIGTERM");
  });
}

// A stack frame, or an absolute path from this machine, in a response body.
const looksLikeStackTrace = (body) => /\n\s+at\s+\S+|\/(?:home|Users|app|var)\/\S+:\d+/.test(body ?? "");
const truncate = (s, n = 400) => (s && s.length > n ? `${s.slice(0, n)}…` : (s ?? ""));
const indent = (s) => (s ?? "").split("\n").map((l) => `    ${l}`).join("\n");
const lastLines = (s, n) => (s ?? "").trimEnd().split("\n").slice(-n).join("\n");

// ------------------------------------------------------------------- report --
try {
  await main();
} catch (err) {
  fail("run the probe", err?.stack ?? String(err));
} finally {
  if (child) await stop(child);
  fs.rmSync(workDir, { recursive: true, force: true });
}

if (failures.length === 0) {
  console.log(
    `boot-check: the built ${PROFILE.label} server started, served ${PROFILE.prefix}/health, ` +
      `refused an unknown route cleanly${PROFILE.guarded ? " and an unauthenticated one" : ""}, and shut down. 0 failures`,
  );
  process.exit(0);
}

console.error(`\nboot-check: the built ${PROFILE.label} server failed to ${failures.length === 1 ? "" : `${failures.length} things: `}\n`);
for (const f of failures) console.error(`  ✗ ${f.what}\n${f.detail}\n`);
process.exit(1);
