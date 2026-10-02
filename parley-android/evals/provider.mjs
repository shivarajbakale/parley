// A promptfoo provider that runs one task as a real Claude Code agent inside a
// throwaway copy of this project, then grades the copy with the project's own
// commands.
//
// Why a custom provider rather than promptfoo's built-in Claude Agent SDK one:
// that provider shares one `working_dir` across every test, so the second task
// would start from the first task's edits. Here every (task, arm) pair gets a
// fresh copy with its own git baseline, which is also what lets the grader say
// exactly which files the agent touched.
//
// Two arms, set per provider in promptfooconfig.yaml:
//   harness  the copy keeps .claude/ (skills + hooks) and loads project settings
//   bare     .claude/ is deleted and no settings load — same code, same docs,
//            same gates, no Claude-specific harness
// The difference between the two scores is what the harness contributed.

import { execFileSync, spawnSync } from "node:child_process";
import { mkdtempSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { query } from "@anthropic-ai/claude-agent-sdk";

const PROJECT = resolve(dirname(fileURLToPath(import.meta.url)), "..");

// Build output and caches are machine state, and evals/ is this runner.
const COPY_EXCLUDES = ["build", ".git", "evals", "Pods", ".symlinks", "node_modules"];

function sh(cwd, command, timeoutMs) {
  const r = spawnSync("bash", ["-lc", command], {
    cwd,
    encoding: "utf8",
    timeout: timeoutMs,
    maxBuffer: 64 * 1024 * 1024,
  });
  const out = `${r.stdout ?? ""}${r.stderr ?? ""}`;
  const all = out.split("\n");
  return {
    command,
    code: r.status ?? (r.error ? 124 : 1),
    // `flutter test` marks a failing test with [E]; the tail alone is the
    // passing tests that ran after it, which names nothing.
    failures: [...new Set(all.filter((l) => l.includes("[E]")))].slice(0, 20),
    tail: all.slice(-25).join("\n"),
  };
}

// One command or glob per line. Lists would be expanded by promptfoo into a
// separate test per element, so tasks.yaml writes these as block strings.
const lines = (value) =>
  (Array.isArray(value) ? value : String(value ?? "").split("\n"))
    .map((l) => l.trim())
    .filter(Boolean);

function git(cwd, ...args) {
  return execFileSync("git", args, { cwd, encoding: "utf8" });
}

function workspace(arm, seed, seedBreaks) {
  const dir = mkdtempSync(join(tmpdir(), `harness-eval-${arm}-`));
  execFileSync("rsync", [
    "-a",
    ...COPY_EXCLUDES.flatMap((e) => ["--exclude", e]),
    `${PROJECT}/`,
    `${dir}/`,
  ]);
  if (arm === "bare") rmSync(join(dir, ".claude"), { recursive: true, force: true });

  git(dir, "init", "-q");
  git(dir, "add", "-A");
  git(dir, "-c", "user.name=eval", "-c", "user.email=eval@local", "commit", "-qm", "baseline");
  if (seed) {
    const s = sh(dir, seed, 120_000);
    if (s.code !== 0) throw new Error(`seed failed:\n${s.tail}`);
    // A seed that does not break the gate it is aimed at makes both arms pass
    // for free, and the eval measures nothing.
    if (seedBreaks) {
      const b = sh(dir, seedBreaks, 300_000);
      if (b.code === 0) throw new Error(`seed is vacuous: \`${seedBreaks}\` still passes`);
    }
    git(dir, "add", "-A");
    git(dir, "-c", "user.name=eval", "-c", "user.email=eval@local", "commit", "-qm", "seed", "--allow-empty");
  }
  return { dir, base: git(dir, "rev-parse", "HEAD").trim() };
}

export default class HarnessAgentProvider {
  constructor(options = {}) {
    this.config = options.config ?? {};
    this.label = options.label ?? `harness-agent:${this.config.arm ?? "harness"}`;
  }

  id() {
    return this.label;
  }

  async callApi(prompt, context) {
    const arm = this.config.arm ?? "harness";
    const vars = context?.vars ?? {};
    const started = Date.now();
    let dir;
    try {
      let base;
      ({ dir, base } = workspace(arm, vars.seed, vars.seedBreaks));

      const tools = [];
      let result = { subtype: "no_result" };
      let model;
      for await (const m of query({
        prompt,
        options: {
          cwd: dir,
          settingSources: arm === "harness" ? ["project"] : [],
          // The copy is disposable and nobody is there to answer a prompt.
          permissionMode: "bypassPermissions",
          allowDangerouslySkipPermissions: true,
          maxTurns: Number(this.config.maxTurns ?? 80),
          ...(this.config.model ? { model: this.config.model } : {}),
        },
      })) {
        if (m.type === "assistant") {
          for (const block of m.message?.content ?? []) {
            if (block.type === "tool_use") {
              tools.push(block.name === "Skill" ? `Skill:${block.input?.skill}` : block.name);
            }
          }
        }
        if (m.type === "system" && m.subtype === "init") model = m.model;
        if (m.type === "result") result = m;
      }

      // Commit whatever the agent left before grading. Gates that compare a
      // regenerated file against git (`ds-catalog-check`) read uncommitted
      // work as drift, and a real change reaches them committed.
      git(dir, "add", "-A");
      git(dir, "-c", "user.name=eval", "-c", "user.email=eval@local", "commit", "-qm", "agent", "--allow-empty");
      const changed = git(dir, "diff", "--name-only", base, "HEAD").split("\n").filter(Boolean);
      const diff = git(dir, "diff", base, "HEAD").slice(0, 60_000);

      // Grade the tree the agent left, with the project's own commands.
      const checks = lines(vars.checks).map((c) =>
        sh(dir, c, Number(this.config.checkTimeoutMs ?? 1_500_000)),
      );

      const metadata = {
        arm,
        task: vars.id,
        workspace: dir,
        agent: {
          model,
          subtype: result.subtype,
          turns: result.num_turns,
          costUsd: result.total_cost_usd,
          finalMessage: result.result,
        },
        tools,
        checks,
        changed,
        diff,
        scope: lines(vars.scope),
        seconds: Math.round((Date.now() - started) / 1000),
      };
      const passed = checks.filter((c) => c.code === 0).length;
      return {
        output: `${vars.id} [${arm}] checks ${passed}/${checks.length}, ${changed.length} files changed, ${result.num_turns ?? "?"} turns`,
        metadata,
        cost: result.total_cost_usd,
      };
    } catch (error) {
      return { error: `${vars.id} [${arm}]: ${error.message}` };
    } finally {
      if (dir && process.env.EVAL_KEEP !== "1") rmSync(dir, { recursive: true, force: true });
    }
  }
}
