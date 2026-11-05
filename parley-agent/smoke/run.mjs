/**
 * End-to-end proof of the Parley <-> parley-agent contract with no keys and
 * no network: boots `mastra dev` with a mock model and the fixture notes
 * server, then drives every route and asserts every event shape Parley's
 * client decodes (runId, integer seq, step/approval/completed/failed).
 *
 * Usage: node smoke/run.mjs   (from the project root, after npm install)
 */
import { spawn } from 'node:child_process';
import { writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const DIR = dirname(dirname(fileURLToPath(import.meta.url)));
// SMOKE_PORT moves the boots off 4111 when another server holds it.
const PORT = process.env.SMOKE_PORT ?? '4111';
const BASE = `http://localhost:${PORT}`;

// The stdio spawn's working directory is the bundler's, not the project
// root, so the smoke config carries an absolute fixture path. Real
// configs should do the same (or use a PATH-resolved command).
writeFileSync(
  join(DIR, 'mcp-servers.smoke.json'),
  JSON.stringify({ 'parley-smoke': { command: 'node', args: [join(DIR, 'smoke', 'fixture-mcp.mjs')] } })
);
let failures = 0;

function check(name, cond, extra = '') {
  console.log(`${cond ? 'PASS' : 'FAIL'}  ${name}${cond || !extra ? '' : ` — ${extra}`}`);
  if (!cond) failures += 1;
}

async function waitForHealth(timeoutMs = 90000) {
  const start = Date.now();
  for (;;) {
    try {
      const res = await fetch(`${BASE}/parley/health`);
      if (res.ok) return await res.json();
    } catch {}
    if (Date.now() - start > timeoutMs) throw new Error('server never answered /parley/health');
    await new Promise(r => setTimeout(r, 1000));
  }
}

function boot(model, serversFile = `${DIR}/mcp-servers.smoke.json`) {
  const env = { ...process.env, PARLEY_MODEL: model };
  // An explicit null boots with no servers file at all: the default chain
  // (mcp-servers.json, then the shipped example) decides.
  if (serversFile !== null) env.PARLEY_MCP_SERVERS_FILE = serversFile;
  else delete env.PARLEY_MCP_SERVERS_FILE;
  env.PORT = PORT;
  delete env.PARLEY_SERVER_URL;
  const child = spawn(`${DIR}/node_modules/.bin/mastra`, ['dev'], {
    cwd: DIR,
    env,
    stdio: ['ignore', 'pipe', 'pipe'],
  });
  let logged = '';
  child.stderr.on('data', c => {
    logged += String(c);
  });
  return { child, logs: () => logged };
}

async function stop(child) {
  child.kill('SIGTERM');
  const dead = await Promise.race([
    new Promise(r => child.on('exit', () => r(true))),
    new Promise(r => setTimeout(() => r(false), 8000)),
  ]);
  if (!dead) child.kill('SIGKILL');
}

/** Collect SSE events until `done(event)` or timeout; returns all seen. */
async function collectSSE(runId, done, timeoutMs = 30000) {
  const res = await fetch(`${BASE}/parley/runs/${runId}/events`, {
    headers: { Accept: 'text/event-stream' },
  });
  if (!res.ok || !res.body) return { status: res.status, events: [] };
  const events = [];
  const reader = res.body.getReader();
  const decoder = new TextDecoder();
  let buffer = '';
  let type = '';
  let data = [];
  const deadline = Date.now() + timeoutMs;
  try {
    for (;;) {
      if (Date.now() > deadline) break;
      const { done: ended, value } = await reader.read();
      if (ended) break;
      buffer += decoder.decode(value, { stream: true });
      let end;
      while ((end = buffer.indexOf('\n')) !== -1) {
        const line = buffer.slice(0, end);
        buffer = buffer.slice(end + 1);
        if (line === '') {
          if (type || data.length) {
            const text = data.join('\n');
            let body = null;
            try {
              body = JSON.parse(text);
            } catch {}
            events.push({ event: type || 'message', body });
            if (done({ event: type || 'message', body })) {
              await reader.cancel().catch(() => {});
              return { status: 200, events };
            }
          }
          type = '';
          data = [];
        } else if (line.startsWith(':')) {
          // heartbeat
        } else if (line.startsWith('event:')) {
          type = line.slice(6).trim();
        } else if (line.startsWith('data:')) {
          data.push(line.slice(5).trimStart());
        }
      }
    }
  } finally {
    await reader.cancel().catch(() => {});
  }
  return { status: 200, events };
}

function validEnvelope(e, runId) {
  return (
    e.body &&
    e.body.runId === runId &&
    Number.isInteger(e.body.seq) &&
    e.body.seq >= 1
  );
}

async function scenarioRead() {
  console.log('--- mock:read (free read, no approval) ---');
  const { child, logs } = boot('mock:read');
  try {
    const health = await waitForHealth();
    check('health online', health.online === true, JSON.stringify(health));
    check(
      'health lists the fixture server with 2 tools',
      Array.isArray(health.mcpServers) &&
        health.mcpServers.length === 1 &&
        health.mcpServers[0].name === 'parley-smoke' &&
        health.mcpServers[0].tools === 2,
      JSON.stringify(health.mcpServers)
    );

    const started = await fetch(`${BASE}/parley/run`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ transcript: 'what are my notes' }),
    });
    check('POST /run 200', started.ok);
    const { runId } = await started.json();
    check('runId is a string', typeof runId === 'string' && runId.length > 8);

    const status = await (await fetch(`${BASE}/parley/runs/${runId}`)).json();
    check('status shape', typeof status.status === 'string' && typeof status.lastStep === 'string', JSON.stringify(status));

    const { events } = await collectSSE(
      runId,
      e => e.event === 'completed' || e.event === 'failed'
    );
    const kinds = events.map(e => e.event);
    check('streamed step then completed', kinds.includes('step') && kinds[kinds.length - 1] === 'completed', kinds.join(','));
    check('every event carries runId + seq', events.every(e => validEnvelope(e, runId)));
    check(
      'seqs increase',
      events.map(e => e.body.seq).every((seq, i, all) => i === 0 || seq > all[i - 1])
    );
    const step = events.find(e => e.event === 'step');
    check('step names the tool', typeof step?.body.text === 'string' && /list notes/i.test(step.body.text), JSON.stringify(step?.body));
    const done = events.find(e => e.event === 'completed');
    check('completed answers in one line', done?.body.text === 'You have 2 notes: buy milk, call Ada.', JSON.stringify(done?.body));
    check('no approval was requested', !kinds.includes('approval_requested'), kinds.join(','));

    const after = await (await fetch(`${BASE}/parley/runs/${runId}`)).json();
    check('terminal status is done', after.status === 'done', JSON.stringify(after));

    const approveDead = await fetch(`${BASE}/parley/runs/${runId}/approve`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ approved: true }),
    });
    check('approve on a finished run is 404', approveDead.status === 404);
    const cancelDead = await fetch(`${BASE}/parley/runs/${runId}`, { method: 'DELETE' });
    check('delete on a finished run is 200', cancelDead.ok);
  } finally {
    await stop(child);
    if (failures) console.log(logs().slice(-2000));
  }
}

async function scenarioWriteApprove() {
  console.log('--- mock:write + approve (suspend, resume, completed) ---');
  const { child, logs } = boot('mock:write');
  try {
    await waitForHealth();
    const started = await fetch(`${BASE}/parley/run`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ transcript: 'delete note n1' }),
    });
    const { runId } = await started.json();

    // Hold the SSE open; approve mid-stream like the pill does.
    const res = await fetch(`${BASE}/parley/runs/${runId}/events`, {
      headers: { Accept: 'text/event-stream' },
    });
    check('SSE opens 200', res.ok);
    const events = [];
    const reader = res.body.getReader();
    const decoder = new TextDecoder();
    let buffer = '';
    let type = '';
    let data = [];
    let approved = false;
    const deadline = Date.now() + 30000;
    let terminal = null;
    while (Date.now() < deadline && !terminal) {
      const { done: ended, value } = await reader.read();
      if (ended) break;
      buffer += decoder.decode(value, { stream: true });
      let end;
      while ((end = buffer.indexOf('\n')) !== -1 && !terminal) {
        const line = buffer.slice(0, end);
        buffer = buffer.slice(end + 1);
        if (line !== '') {
          if (line.startsWith('event:')) type = line.slice(6).trim();
          else if (line.startsWith('data:')) data.push(line.slice(5).trimStart());
          continue;
        }
        if (!type && !data.length) continue;
        let body = null;
        try {
          body = JSON.parse(data.join('\n'));
        } catch {}
        const e = { event: type || 'message', body };
        type = '';
        data = [];
        events.push(e);
        if (e.event === 'approval_requested' && !approved) {
          approved = true;
          const answer = await fetch(`${BASE}/parley/runs/${runId}/approve`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ approved: true }),
          });
          check('approve mid-run is 200', answer.ok);
        }
        if (e.event === 'completed' || e.event === 'failed') terminal = e;
      }
    }
    await reader.cancel().catch(() => {});

    const kinds = events.map(e => e.event);
    check(
      'streamed step, approval, completed',
      kinds.includes('step') && kinds.includes('approval_requested') && terminal?.event === 'completed',
      kinds.join(',')
    );
    check('every event carries runId + seq', events.every(e => validEnvelope(e, runId)));
    const asked = events.find(e => e.event === 'approval_requested');
    check('approval names the tool', asked?.body.tool === 'parley-smoke_delete_note', JSON.stringify(asked?.body));
    check('approval has a callId', typeof asked?.body.callId === 'string' && asked.body.callId.length > 0);
    check('approval summarizes first', typeof asked?.body.summary === 'string' && /delete/i.test(asked.body.summary), JSON.stringify(asked?.body.summary));
    check('approval echoes the transcript', asked?.body.transcript === 'delete note n1');
    check('completed after approve', terminal?.body.text === 'Done — deleted note n1.', JSON.stringify(terminal?.body));
  } finally {
    await stop(child);
    if (failures) console.log(logs().slice(-2000));
  }
}

async function scenarioWriteDecline() {
  console.log('--- mock:write + decline (Skipped step, run continues) ---');
  const { child, logs } = boot('mock:write');
  try {
    await waitForHealth();
    const started = await fetch(`${BASE}/parley/run`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ transcript: 'delete note n1' }),
    });
    const { runId } = await started.json();
    const { events } = await collectSSE(runId, e => e.event === 'approval_requested');
    check('suspends for approval', events.some(e => e.event === 'approval_requested'));
    const answer = await fetch(`${BASE}/parley/runs/${runId}/approve`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ approved: false }),
    });
    check('decline is 200', answer.ok);
    const rest = await collectSSE(
      runId,
      e => e.event === 'completed' || e.event === 'failed'
    );
    const texts = rest.events.filter(e => e.event === 'step').map(e => e.body.text);
    check('decline emits the Skipped step', texts.includes('Skipped — continuing…'), texts.join(' | '));
    check(
      'run completes after decline',
      rest.events.some(e => e.event === 'completed'),
      rest.events.map(e => e.event).join(',')
    );
  } finally {
    await stop(child);
    if (failures) console.log(logs().slice(-2000));
  }
}

async function scenarioCancelSuspended() {
  console.log('--- DELETE on a suspended run (kills it, never 404s) ---');
  const { child, logs } = boot('mock:write');
  try {
    await waitForHealth();
    const started = await fetch(`${BASE}/parley/run`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ transcript: 'delete note n1' }),
    });
    const { runId } = await started.json();
    await collectSSE(runId, e => e.event === 'approval_requested');
    const del = await fetch(`${BASE}/parley/runs/${runId}`, { method: 'DELETE' });
    check('delete on a suspended run is 200', del.ok);
    const after = await (await fetch(`${BASE}/parley/runs/${runId}`)).json();
    check('status is cancelled', after.status === 'cancelled', JSON.stringify(after));
    const late = await fetch(`${BASE}/parley/runs/${runId}/approve`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ approved: true }),
    });
    check('approve after cancel is 404', late.status === 404);
  } finally {
    await stop(child);
    if (failures) console.log(logs().slice(-2000));
  }
}

async function scenarioNotes() {
  console.log('--- mock:notes on the shipped dummy (read, approval, completed) ---');
  // The example file itself, by absolute path: its relative script arg
  // still exercises root resolution, whatever the user configured.
  const { child, logs } = boot('mock:notes', `${DIR}/mcp-servers.example.json`);
  try {
    const health = await waitForHealth();
    check(
      'dummy notes server lists 3 tools',
      Array.isArray(health.mcpServers) &&
        health.mcpServers.length === 1 &&
        health.mcpServers[0].name === 'notes' &&
        health.mcpServers[0].tools === 3,
      JSON.stringify(health.mcpServers)
    );
    const started = await fetch(`${BASE}/parley/run`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ transcript: 'read my notes, then delete the first' }),
    });
    const { runId } = await started.json();
    const { events } = await collectSSE(runId, e => e.event === 'approval_requested');
    const kinds = events.map(e => e.event);
    check(
      'free read streams a step first',
      kinds.includes('step') && events.find(e => e.event === 'step')?.body.text === 'Using List notes…',
      kinds.join(',')
    );
    const asked = events.find(e => e.event === 'approval_requested');
    check('write suspends for approval', !!asked, kinds.join(','));
    check('approval names the dummy tool', asked?.body.tool === 'notes_delete_note');
    const answer = await fetch(`${BASE}/parley/runs/${runId}/approve`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ approved: true }),
    });
    check('approve is 200', answer.ok);
    const rest = await collectSSE(runId, e => e.event === 'completed' || e.event === 'failed');
    check(
      'run completes after approve',
      rest.events.some(e => e.event === 'completed'),
      rest.events.map(e => e.event).join(',')
    );
    const done = rest.events.find(e => e.event === 'completed');
    check('completed text arrives', done?.body.text === 'Done — deleted note n1, one left.');
  } finally {
    await stop(child);
    if (failures) console.log(logs().slice(-2000));
  }
}

async function scenarioGone() {
  console.log('--- unknown runs (404s) ---');
  const { child, logs } = boot('mock:plain');
  try {
    await waitForHealth();
    const status = await fetch(`${BASE}/parley/runs/does-not-exist`);
    check('status on unknown run is 404', status.status === 404);
    const events = await fetch(`${BASE}/parley/runs/does-not-exist/events`);
    check('events on unknown run is 404', events.status === 404);
    const approve = await fetch(`${BASE}/parley/runs/does-not-exist/approve`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ approved: true }),
    });
    check('approve on unknown run is 404', approve.status === 404);
    const del = await fetch(`${BASE}/parley/runs/does-not-exist`, { method: 'DELETE' });
    check('delete on unknown run is 200', del.ok);
    const empty = await fetch(`${BASE}/parley/run`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ transcript: '   ' }),
    });
    check('empty transcript is 400', empty.status === 400);
  } finally {
    await stop(child);
    if (failures) console.log(logs().slice(-2000));
  }
}

await scenarioRead();
await scenarioWriteApprove();
await scenarioWriteDecline();
await scenarioCancelSuspended();
await scenarioNotes();
await scenarioGone();
console.log(failures === 0 ? '\nSMOKE: all green' : `\nSMOKE: ${failures} failure(s)`);
process.exit(failures === 0 ? 0 : 1);
