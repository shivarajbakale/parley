import { describe, it, expect, beforeAll, afterAll } from "vitest";
import { spawnSync } from "node:child_process";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";

/**
 * plan-lint runs against a project root, so these tests build throwaway project
 * roots rather than mutating this one. Each sandbox gets a real copy of the two
 * scripts, so what runs here is the script that ships.
 */
const here = path.dirname(fileURLToPath(import.meta.url));
const scriptsDir = path.join(here, "..");
const fixturesDir = path.join(scriptsDir, "__fixtures__");

const fixturePlanFile = fs
  .readdirSync(fixturesDir)
  .find((f) => f.endsWith(".feature-plan.json"));

let sandboxRoot: string;

function makeSandbox(name: string): string {
  const dir = path.join(sandboxRoot, name);
  fs.mkdirSync(path.join(dir, "scripts"), { recursive: true });
  for (const f of ["plan-lint.mjs", "feature-plan.mjs"]) {
    fs.copyFileSync(path.join(scriptsDir, f), path.join(dir, "scripts", f));
  }
  fs.writeFileSync(
    path.join(dir, "feature_list.json"),
    JSON.stringify({ features: [] }, null, 2),
  );
  return dir;
}

function run(dir: string) {
  const r = spawnSync(process.execPath, ["scripts/plan-lint.mjs"], {
    cwd: dir,
    encoding: "utf8",
  });
  return { code: r.status, out: `${r.stdout}${r.stderr}` };
}

function plan(): Record<string, unknown> {
  return JSON.parse(fs.readFileSync(path.join(fixturesDir, fixturePlanFile!), "utf8"));
}

function writePlan(dir: string, data: unknown, name = "sandbox.feature-plan.json") {
  fs.writeFileSync(path.join(dir, name), JSON.stringify(data, null, 2));
  return name;
}

function render(dir: string, file: string) {
  const r = spawnSync(
    process.execPath,
    ["scripts/feature-plan.mjs", file, "-o", "FEATURE-PLAN.md"],
    { cwd: dir, encoding: "utf8" },
  );
  expect(r.status, `render failed: ${r.stderr}`).toBe(0);
}

function register(dir: string, id: string) {
  fs.writeFileSync(
    path.join(dir, "feature_list.json"),
    JSON.stringify({ features: [{ id, status: "in_progress", title: id }] }, null, 2),
  );
}

beforeAll(() => {
  sandboxRoot = fs.mkdtempSync(path.join(os.tmpdir(), "plan-lint-"));
});

afterAll(() => {
  fs.rmSync(sandboxRoot, { recursive: true, force: true });
});

describe("plan-lint", () => {
  it("passes a project with no plans — the gate is inert until someone plans", () => {
    const dir = makeSandbox("empty");
    const { code, out } = run(dir);
    expect(code, out).toBe(0);
    expect(out).toContain("no feature plans to check");
  });

  it("passes a valid, registered, in-sync plan", () => {
    const dir = makeSandbox("green");
    const p = plan();
    const file = writePlan(dir, p);
    render(dir, file);
    register(dir, (p.feature as { id: string }).id);
    const { code, out } = run(dir);
    expect(code, out).toBe(0);
    expect(out).toContain("FEATURE-PLAN.md in sync");
  });

  it("P1 — rejects a plan the renderer would refuse to draw", () => {
    const dir = makeSandbox("p1");
    const p = plan();
    (p.components as { why: string }[])[0].why = "";
    writePlan(dir, p);
    register(dir, (p.feature as { id: string }).id);
    const { code, out } = run(dir);
    expect(code, out).toBe(1);
    expect(out).toContain("[P1]");
    expect(out).toContain("why");
  });

  it("P2 — catches a hand-edited FEATURE-PLAN.md, which the skill forbids", () => {
    const dir = makeSandbox("p2");
    const p = plan();
    const file = writePlan(dir, p);
    render(dir, file);
    register(dir, (p.feature as { id: string }).id);
    fs.appendFileSync(path.join(dir, "FEATURE-PLAN.md"), "\nquietly edited by hand\n");
    const { code, out } = run(dir);
    expect(code, out).toBe(1);
    expect(out).toContain("[P2]");
  });

  it("P3 — rejects a rendered plan with no source JSON", () => {
    const dir = makeSandbox("p3");
    fs.writeFileSync(path.join(dir, "FEATURE-PLAN.md"), "# written by hand\n");
    const { code, out } = run(dir);
    expect(code, out).toBe(1);
    expect(out).toContain("[P3]");
  });

  it("does not also report P3 when the source JSON exists but is invalid", () => {
    const dir = makeSandbox("p1-only");
    const p = plan();
    const file = writePlan(dir, p);
    render(dir, file);
    (p.components as { why: string }[])[0].why = "";
    writePlan(dir, p, file);
    const { code, out } = run(dir);
    expect(code, out).toBe(1);
    expect(out).toContain("[P1]");
    expect(out).not.toContain("[P3]");
  });

  it("P4 — rejects a plan for a feature nobody registered", () => {
    const dir = makeSandbox("p4");
    const p = plan();
    const file = writePlan(dir, p);
    render(dir, file);
    const { code, out } = run(dir);
    expect(code, out).toBe(1);
    expect(out).toContain("[P4]");
    expect(out).toContain("feature_list.json");
  });
});
