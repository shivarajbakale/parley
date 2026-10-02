#!/usr/bin/env node
/**
 * db-lint — the database default is a checked artifact, not a convention.
 *
 * A backend names its database in more than one place. Prisma reads
 * `prisma/schema.prisma`; the runtime reads `DATABASE_URL`; and an auth library
 * with its own adapter is told the provider a third time, in code. Nothing
 * makes those agree. When they disagree nothing fails at build time — Prisma
 * emits SQL for one database and the process talks to another, and the first
 * symptom is a request failing in production.
 *
 * Rules:
 *   DB1  the Prisma datasource names the expected provider
 *   DB2  DATABASE_URL in .env.example matches that provider
 *   DB3  every provider named in application code agrees with the schema
 *   DB4  the schema uses no construct the provider cannot store
 *   DB5  a file-backed database is gitignored
 *   DB6  the hand-written mirror of an auth library's schema still matches it
 *
 * DB6 exists because of a real defect: better-auth was declared `^1.2.7`,
 * resolved to 1.7.2, and 1.7 added an `issuer` column to `account`. Sign-up
 * died with `Unknown argument \`issuer\`` in every generated project, on Postgres
 * as much as on SQLite, and it was invisible on a re-run because the failing
 * seed had already created the user. The library declares its own expectations
 * at run time, so the mirror can be checked rather than trusted.
 *
 *   node scripts/db-lint.mjs
 */
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const EXPECTED_PROVIDER = "sqlite";

// Providers a datasource or an adapter can name. Used to tell "this string is a
// database provider" from "this string happens to be called provider".
const PROVIDERS = [
  "sqlite",
  "postgresql",
  "postgres",
  "mysql",
  "sqlserver",
  "mongodb",
  "cockroachdb",
];

const violations = [];
const notes = [];
const fail = (rule, message) => violations.push({ rule, message });

const read = (rel) => {
  const p = path.join(ROOT, rel);
  return fs.existsSync(p) ? fs.readFileSync(p, "utf8") : null;
};

// ---------------------------------------------------------------- schema ----
const SCHEMA_REL = "prisma/schema.prisma";
const schema = read(SCHEMA_REL);

if (!schema) {
  notes.push(`no ${SCHEMA_REL} — this project has no Prisma database, so DB1/DB3–DB6 do not apply`);
} else {
  // DB1 --------------------------------------------------------------------
  const datasource = schema.match(/datasource\s+\w+\s*\{([^}]*)\}/);
  const declared = datasource?.[1].match(/provider\s*=\s*"([^"]+)"/)?.[1];
  if (!declared) {
    fail("DB1", `${SCHEMA_REL}: no datasource provider found`);
  } else if (declared !== EXPECTED_PROVIDER) {
    fail(
      "DB1",
      `${SCHEMA_REL}: datasource provider is "${declared}", expected "${EXPECTED_PROVIDER}". ` +
        `If the move is deliberate, change DATABASE_URL, every provider named in code, and this rule's EXPECTED_PROVIDER together.`,
    );
  }

  // DB4 --------------------------------------------------------------------
  // SQLite has no enums, no scalar lists, no Json column type and no native
  // type attributes. Prisma accepts all four in a schema file and fails at
  // `db push`, so the whole point is to say so before then.
  if (EXPECTED_PROVIDER === "sqlite") {
    const body = schema.replace(/\/\/[^\n]*/g, "");
    const unsupported = [
      [/^\s*enum\s+(\w+)\s*\{/m, (m) => `an enum (\`${m[1]}\`) — SQLite has none; use a String with a check in the application`],
      [/^\s*(\w+)\s+(\w+)\[\]\s*$/m, (m) => `a scalar list (\`${m[1]} ${m[2]}[]\`) — SQLite cannot store one; use a delimited String or a join table`],
      [/^\s*(\w+)\s+Json\b/m, (m) => `a Json column (\`${m[1]}\`) — SQLite has no JSON type in Prisma; use String`],
      [/@db\.(\w+)/, (m) => `a native type attribute (\`@db.${m[1]}\`) — those are provider-specific and SQLite accepts none`],
    ];
    for (const [re, describe] of unsupported) {
      const m = body.match(re);
      // A relation field (`todos Todo[]`) is a list too, and is perfectly legal.
      if (m && re.source.includes("\\[\\]")) {
        const type = m[2];
        const isModel = new RegExp(`^\\s*model\\s+${type}\\b`, "m").test(body);
        if (isModel) continue;
      }
      if (m) fail("DB4", `${SCHEMA_REL} declares ${describe(m)}`);
    }
  }
}

// ------------------------------------------------------------ .env.example ---
const ENV_REL = ".env.example";
const env = read(ENV_REL);
if (!env) {
  fail("DB2", `${ENV_REL} is missing — a project whose database is configured by env owes an example of it`);
} else {
  const line = env.match(/^\s*DATABASE_URL[ \t]*=[ \t]*(.+)$/m)?.[1]?.trim();
  if (!line) {
    if (schema) fail("DB2", `${ENV_REL}: no DATABASE_URL — Prisma cannot start without it`);
  } else {
    const value = line.replace(/^["']|["']$/g, "");
    const wantsFile = EXPECTED_PROVIDER === "sqlite";
    const isFile = value.startsWith("file:");
    if (wantsFile && !isFile) {
      fail(
        "DB2",
        `${ENV_REL}: DATABASE_URL is "${value}", but the schema's provider is "${EXPECTED_PROVIDER}", which needs a file: URL. ` +
          `Prisma rejects the mismatch at run time, not at build time.`,
      );
    }
    if (!wantsFile && isFile) {
      fail("DB2", `${ENV_REL}: DATABASE_URL is a file: URL but the provider is "${EXPECTED_PROVIDER}"`);
    }

    // DB5 ------------------------------------------------------------------
    if (isFile) {
      const gitignore = read(".gitignore") ?? "";
      const covered = /(^|\n)\s*[^#\n]*\*\.db\s*(\n|$)/.test(gitignore) || /(^|\n)\s*[^#\n]*\.db\s*(\n|$)/.test(gitignore);
      if (!covered) {
        fail(
          "DB5",
          `.gitignore does not cover the SQLite database file. A committed dev.db ships one developer's data — and their password hashes — to everyone who clones.`,
        );
      }
    }
  }
}

// ------------------------------------------------------- providers in code ---
// DB3 -----------------------------------------------------------------------
if (schema) {
  const srcDir = path.join(ROOT, "src");
  const walk = (dir) => {
    if (!fs.existsSync(dir)) return [];
    return fs.readdirSync(dir, { withFileTypes: true }).flatMap((e) => {
      const full = path.join(dir, e.name);
      if (e.isDirectory()) return e.name === "node_modules" ? [] : walk(full);
      return /\.(ts|js|mjs)$/.test(e.name) ? [full] : [];
    });
  };
  for (const file of walk(srcDir)) {
    const text = fs.readFileSync(file, "utf8");
    // `provider: "postgresql"` — an adapter being told the database a second time.
    for (const m of text.matchAll(/provider\s*:\s*["']([^"']+)["']/g)) {
      if (!PROVIDERS.includes(m[1])) continue;
      if (m[1] === EXPECTED_PROVIDER) continue;
      const line = text.slice(0, m.index).split("\n").length;
      fail(
        "DB3",
        `${path.relative(ROOT, file)}:${line}: names provider "${m[1]}" while ${SCHEMA_REL} names "${EXPECTED_PROVIDER}". ` +
          `Both declarations are real; when they disagree the failure appears on the first request, not at build time.`,
      );
    }
  }
}

// --------------------------------------------- auth schema mirror (DB6) ------
if (schema) {
  const pkg = JSON.parse(read("package.json") ?? "{}");
  const deps = { ...(pkg.dependencies ?? {}), ...(pkg.devDependencies ?? {}) };
  if (!deps["better-auth"]) {
    notes.push("better-auth is not a dependency — DB6 (auth schema mirror) does not apply");
  } else {
    let getAuthTables = null;
    try {
      const entry = path.join(ROOT, "node_modules", "better-auth", "dist", "db", "index.mjs");
      const mod = fs.existsSync(entry)
        ? await import(pathToFileURL(entry).href)
        : await import("better-auth/db");
      getAuthTables = mod.getAuthTables;
    } catch {
      notes.push("better-auth is declared but not installed — DB6 skipped (run `npm install` to check it)");
    }
    if (getAuthTables) {
      // Prisma model → the table it maps to, and the columns it declares.
      const models = new Map();
      for (const m of schema.matchAll(/model\s+(\w+)\s*\{([\s\S]*?)\n\}/g)) {
        const [, name, body] = m;
        const table = body.match(/@@map\("([^"]+)"\)/)?.[1] ?? name;
        const fields = new Set();
        for (const line of body.split("\n")) {
          const f = line.match(/^\s*(\w+)\s+\w+/);
          if (!f || /^\s*@@/.test(line)) continue;
          fields.add(line.match(/@map\("([^"]+)"\)/)?.[1] ?? f[1]);
        }
        models.set(table, { name, fields });
      }

      const tables = getAuthTables({});
      for (const [key, table] of Object.entries(tables)) {
        const tableName = table.modelName ?? key;
        const model = models.get(tableName);
        if (!model) {
          fail("DB6", `better-auth expects a table "${tableName}" and ${SCHEMA_REL} declares no model mapped to it`);
          continue;
        }
        for (const [fieldKey, field] of Object.entries(table.fields ?? {})) {
          const column = field?.fieldName ?? fieldKey;
          if (!model.fields.has(column)) {
            fail(
              "DB6",
              `better-auth ${deps["better-auth"]} writes "${column}" to "${tableName}", and model ${model.name} has no such field. ` +
                `Prisma rejects the write at run time with \`Unknown argument \\\`${column}\\\`\` on the first request that touches it.`,
            );
          }
        }
      }
    }
  }
}

// ------------------------------------------------------------------ report ---
for (const note of notes) console.log(`db-lint: ${note}`);
if (violations.length === 0) {
  console.log(`db-lint: database default is consistent (${EXPECTED_PROVIDER}), 0 violations`);
  process.exit(0);
}
console.error(`\ndb-lint: ${violations.length} violation(s)\n`);
for (const v of violations) console.error(`  [${v.rule}] ${v.message}\n`);
process.exit(1);
