import assert from "node:assert/strict";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { pathToFileURL } from "node:url";

const source = process.argv[2];
const tmp = fs.mkdtempSync(path.join(os.tmpdir(), "opencode-goal-test-"));
const modulePath = path.join(tmp, "goal.mjs");
fs.copyFileSync(source, modulePath);
process.env.XDG_DATA_HOME = path.join(tmp, "data");

const hooks = new Map();
const tools = new Map();
const synthetic = [];
const events = [];
let wake;
let aborted = false;

const ctx = {
  location: { directory: tmp, project: { canonical: tmp } },
  session: {
    hook: async (name, callback) => hooks.set(name, callback),
    synthetic: async (input) => synthetic.push(input),
    get: async () => ({}),
  },
  tool: {
    transform: async (callback) => callback({ add: (tool) => tools.set(tool.name, tool) }),
  },
  event: {
    subscribe: ({ signal }) => {
      signal.addEventListener("abort", () => {
        aborted = true;
        wake?.({ done: true });
      });
      return {
        [Symbol.asyncIterator]() { return this; },
        next() {
          if (events.length) return Promise.resolve({ value: events.shift(), done: false });
          if (aborted) return Promise.resolve({ done: true });
          return new Promise((resolve) => { wake = resolve; });
        },
      };
    },
  },
};

function emit(event) {
  if (wake) {
    const resolve = wake;
    wake = undefined;
    resolve({ value: event, done: false });
  } else events.push(event);
}

const plugin = (await import(pathToFileURL(modulePath))).default;
const cleanup = await plugin.setup(ctx);

try {
  assert.equal(plugin.id, "goal-loop");
  assert.deepEqual([...tools.keys()].sort(), [
    "goal_cancel", "goal_complete", "goal_pause", "goal_resume", "goal_start", "goal_status",
  ]);

  const sessionID = "ses_test";
  const context = { sessionID };
  const start = tools.get("goal_start");
  const args = { objective: "Finish and verify task", max_turns: 2, max_minutes: 5 };
  assert.match((await start.execute(args, context)).content, /not started/);

  hooks.get("prompt")({ sessionID, prompt: { text: "Start a persistent goal for this task" } });
  assert.match((await start.execute(args, context)).content, /Goal started/);

  const system = [];
  hooks.get("context")({ sessionID, system });
  assert.match(system[0].text, /Finish and verify task/);

  emit({ type: "session.status", data: { sessionID, status: { type: "idle" } } });
  await new Promise((resolve) => setTimeout(resolve, 1200));
  assert.equal(synthetic.length, 1);
  assert.equal(synthetic[0].metadata.source, "goal-loop");

  const pause = tools.get("goal_pause");
  assert.match((await pause.execute({ reason: "Need a choice" }, context)).content, /paused/);
  assert.match((await tools.get("goal_status").execute({}, context)).content, /Status: paused/);
  hooks.get("prompt")({ sessionID, prompt: { text: "I chose option A" } });
  assert.match((await tools.get("goal_status").execute({}, context)).content, /Status: active/);
  assert.match((await tools.get("goal_complete").execute({
    summary: "Task finished", verification: "Checked the output",
  }, context)).content, /marked complete/);
  assert.match((await tools.get("goal_status").execute({}, context)).content, /Status: completed/);
} finally {
  cleanup();
  fs.rmSync(tmp, { recursive: true, force: true });
}
