import crypto from "node:crypto";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";

const MAX_FAILURES = 3;
const CONTINUATION_DELAY_MS = 1000;

// A plain V2 plugin object keeps the CLI and Desktop sidecar independent of npm installs.
export default {
  id: "goal-loop",
  async setup(ctx) {
    const projectRoot = ctx.location.project.canonical || ctx.location.directory;
    const statePath = goalStatePath(projectRoot);
    let store = loadStore(statePath, projectRoot);
    const timers = new Map();
    const sending = new Set();
    const startAuthorizations = new Set();
    const controller = new AbortController();

    function refresh() {
      store = loadStore(statePath, projectRoot);
    }

    function goalFor(sessionID) {
      refresh();
      return store.sessions[sessionID];
    }

    function putGoal(sessionID, goal) {
      refresh();
      store.sessions[sessionID] = { ...goal, updatedAt: Date.now() };
      store.updatedAt = Date.now();
      saveStore(statePath, store);
      return store.sessions[sessionID];
    }

    function clearTimer(sessionID) {
      const timer = timers.get(sessionID);
      if (timer !== undefined) clearTimeout(timer);
      timers.delete(sessionID);
    }

    function pause(sessionID, reason, stopReason) {
      const goal = goalFor(sessionID);
      if (goal?.status !== "active") return false;
      clearTimer(sessionID);
      putGoal(sessionID, { ...goal, status: "paused", pauseReason: reason, stopReason });
      return true;
    }

    function queueContinuation(sessionID, reason) {
      if (timers.has(sessionID) || sending.has(sessionID)) return;
      const goal = goalFor(sessionID);
      if (goal?.status !== "active") return;
      if (goal.turn >= goal.maxTurns) {
        pause(sessionID, `Maximum continuation turns reached (${goal.maxTurns}).`, "turn-limit");
        return;
      }
      if (Date.now() - goal.startedAt >= goal.maxMinutes * 60_000) {
        pause(sessionID, `Maximum runtime reached (${goal.maxMinutes} minutes).`, "time-limit");
        return;
      }
      if (goal.promptFailures >= MAX_FAILURES) {
        pause(sessionID, `Continuation failed ${MAX_FAILURES} times.`, "prompt-failures");
        return;
      }

      timers.set(sessionID, setTimeout(async () => {
        timers.delete(sessionID);
        const current = goalFor(sessionID);
        if (current?.status !== "active" || sending.has(sessionID)) return;
        sending.add(sessionID);
        const next = putGoal(sessionID, {
          ...current,
          turn: current.turn + 1,
          lastContinuationReason: reason,
          lastContinuationAt: Date.now(),
        });
        let retry = false;
        try {
          await ctx.session.synthetic({
            sessionID,
            text: `Continue the active goal. Automatic continuation ${next.turn}/${next.maxTurns}. Make new progress; do not repeat the previous response. If user input is required, call goal_pause instead of asking again.`,
            description: "Automatic goal continuation",
            metadata: { source: "goal-loop" },
            delivery: "queue",
          });
        } catch (error) {
          const failed = goalFor(sessionID);
          if (failed?.status === "active") {
            const promptFailures = failed.promptFailures + 1;
            putGoal(sessionID, { ...failed, promptFailures, lastError: errorMessage(error) });
            if (promptFailures >= MAX_FAILURES) {
              pause(sessionID, `Continuation failed ${promptFailures} times: ${errorMessage(error)}`, "prompt-failures");
            } else retry = true;
          }
        } finally {
          sending.delete(sessionID);
        }
        if (retry) queueContinuation(sessionID, "prompt-retry");
      }, CONTINUATION_DELAY_MS));
    }

    await ctx.session.hook("prompt", (event) => {
      const sessionID = event.sessionID;
      clearTimer(sessionID);
      if (/\bgoal\b/i.test(event.prompt.text)) startAuthorizations.add(sessionID);
      else startAuthorizations.delete(sessionID);

      const goal = goalFor(sessionID);
      if (goal?.status === "paused" && goal.stopReason === "blocked") {
        putGoal(sessionID, {
          ...goal,
          status: "active",
          pauseReason: undefined,
          stopReason: undefined,
          promptFailures: 0,
        });
      }
    });

    await ctx.session.hook("context", (event) => {
      const goal = goalFor(event.sessionID);
      if (goal?.status !== "active") return;
      event.system.push({
        type: "text",
        text: [
          "A persistent goal loop is active for this session.",
          `Objective: ${goal.objective}`,
          "Continue until it is completely and verifiably finished, cancelled, or paused by a safety limit.",
          "Call goal_complete with concrete verification evidence before reporting completion.",
          "Call the built-in question tool for a blocking choice. Call goal_pause for user action outside that tool.",
          "Use commentary only for progress updates. Do not repeat a question after automatic continuation.",
        ].join("\n"),
      });
    });

    const objectInput = (properties = {}, required = []) => ({
      type: "object",
      properties,
      required,
      additionalProperties: false,
    });
    const stringInput = (description) => ({ type: "string", description });
    const integerInput = (minimum, maximum) => ({ type: "integer", minimum, maximum });
    const addTool = (editor, name, description, input, execute) => editor.add({
      name,
      description,
      input,
      execute: async (args, context) => ({ content: await execute(args, context.sessionID) }),
    });

    await ctx.tool.transform((editor) => {
      addTool(editor, "goal_start",
        "Start a bounded persistent goal only when the current user message explicitly asks to start a goal and contains the standalone word goal.",
        objectInput({
          objective: stringInput("Specific objective with verification criteria"),
          max_turns: integerInput(1, 200),
          max_minutes: integerInput(1, 1440),
        }, ["objective", "max_turns", "max_minutes"]),
        async (args, sessionID) => {
          if (!startAuthorizations.has(sessionID)) {
            return "Goal not started: the current user message must explicitly ask to start a goal and contain the word goal.";
          }
          const objective = args.objective?.trim();
          if (!objective) return "Goal not started: objective must not be empty.";
          startAuthorizations.delete(sessionID);
          clearTimer(sessionID);
          const now = Date.now();
          putGoal(sessionID, {
            id: crypto.randomUUID(), objective, status: "active", turn: 0,
            maxTurns: args.max_turns, maxMinutes: args.max_minutes,
            startedAt: now, updatedAt: now, promptFailures: 0,
          });
          return `Goal started with limits of ${args.max_turns} continuations and ${args.max_minutes} minutes. Begin working now: ${objective}`;
        });

      addTool(editor, "goal_status", "Read this session's persistent goal status when asked.",
        objectInput(), async (_args, sessionID) => {
          const goal = goalFor(sessionID);
          return goal ? formatGoal(goal) : "No goal exists for this session.";
        });

      addTool(editor, "goal_resume", "Resume this session's paused goal when asked.",
        objectInput(), async (_args, sessionID) => {
          const goal = goalFor(sessionID);
          if (goal?.status !== "paused") return "No paused goal can be resumed.";
          putGoal(sessionID, {
            ...goal, status: "active", pauseReason: undefined,
            stopReason: undefined, promptFailures: 0,
          });
          return `Goal resumed. Continue working now: ${goal.objective}`;
        });

      addTool(editor, "goal_cancel", "Cancel this session's open goal when the user asks to stop it.",
        objectInput({ reason: stringInput("Reason for cancellation") }, ["reason"]),
        async (args, sessionID) => {
          const goal = goalFor(sessionID);
          if (!goal || goal.status === "completed" || goal.status === "cancelled") {
            return "No open goal can be cancelled.";
          }
          clearTimer(sessionID);
          putGoal(sessionID, {
            ...goal, status: "cancelled", pauseReason: args.reason, stopReason: "user",
          });
          return `Goal cancelled: ${args.reason}`;
        });

      addTool(editor, "goal_complete", "Complete the active goal only after verifying the full objective.",
        objectInput({
          summary: stringInput("Concise summary of completed work"),
          verification: stringInput("Concrete tests, checks, or other completion evidence"),
        }, ["summary", "verification"]),
        async (args, sessionID) => {
          const goal = goalFor(sessionID);
          if (goal?.status !== "active") return "No active goal can be completed.";
          const summary = args.summary?.trim();
          const verification = args.verification?.trim();
          if (!summary || !verification) {
            return "Goal completion rejected: summary and verification must both be non-empty.";
          }
          clearTimer(sessionID);
          putGoal(sessionID, {
            ...goal, status: "completed", completedAt: Date.now(),
            completionSummary: summary, verification, stopReason: "completed",
          });
          return "Goal marked complete. Report the summary and verification to the user.";
        });

      addTool(editor, "goal_pause", "Pause the active goal for a real blocker requiring user action.",
        objectInput({ reason: stringInput("Blocker and required user action") }, ["reason"]),
        async (args, sessionID) => pause(sessionID, args.reason, "blocked")
          ? "Goal paused. Explain the blocker and required next action."
          : "No active goal can be paused.");
    });

    void (async () => {
      try {
        for await (const event of ctx.event.subscribe({ signal: controller.signal })) {
          const sessionID = event.data?.sessionID;
          if (!sessionID) continue;
          if (event.type === "session.execution.interrupted" && event.data.reason === "user") {
            pause(sessionID, "Stopped by user.", "user");
          } else if (event.type === "session.execution.failed") {
            const goal = goalFor(sessionID);
            if (goal?.status === "active") {
              const promptFailures = goal.promptFailures + 1;
              putGoal(sessionID, {
                ...goal, promptFailures, lastError: errorMessage(event.data.error),
              });
            }
          } else if (event.type === "session.execution.succeeded") {
            const goal = goalFor(sessionID);
            if (goal?.status === "active" && goal.promptFailures > 0) {
              putGoal(sessionID, { ...goal, promptFailures: 0, lastError: undefined });
            }
          } else if (event.type === "session.status" && event.data.status.type === "idle") {
            queueContinuation(sessionID, "idle");
          }
        }
      } catch (error) {
        if (!controller.signal.aborted) console.error(`[goal] Event stream failed: ${errorMessage(error)}`);
      }
    })();

    const recoveryTimer = setTimeout(async () => {
      refresh();
      for (const [sessionID, goal] of Object.entries(store.sessions)) {
        if (goal.status !== "active") continue;
        try {
          await ctx.session.get({ sessionID });
          queueContinuation(sessionID, "startup-recovery");
        } catch (error) {
          console.error(`[goal] Could not recover session ${sessionID}: ${errorMessage(error)}`);
        }
      }
    }, 2000);

    return () => {
      controller.abort();
      clearTimeout(recoveryTimer);
      for (const timer of timers.values()) clearTimeout(timer);
      timers.clear();
    };
  },
};

function goalStatePath(projectRoot) {
  const dataHome = process.env.XDG_DATA_HOME || path.join(os.homedir(), ".local", "share");
  const projectHash = crypto.createHash("sha256").update(path.resolve(projectRoot)).digest("hex").slice(0, 24);
  return path.join(dataHome, "opencode", "goal-loop", `${projectHash}.json`);
}

function emptyStore(projectRoot) {
  return { version: 1, projectRoot: path.resolve(projectRoot), sessions: {}, updatedAt: Date.now() };
}

function loadStore(statePath, projectRoot) {
  try {
    const value = JSON.parse(fs.readFileSync(statePath, "utf8"));
    if (value?.version !== 1 || typeof value.sessions !== "object" || value.sessions === null) {
      return emptyStore(projectRoot);
    }
    return value;
  } catch (error) {
    if (error?.code === "ENOENT") return emptyStore(projectRoot);
    console.error(`[goal] Could not load ${statePath}: ${errorMessage(error)}`);
    return emptyStore(projectRoot);
  }
}

function saveStore(statePath, store) {
  fs.mkdirSync(path.dirname(statePath), { recursive: true, mode: 0o700 });
  const temporary = `${statePath}.${process.pid}.${Date.now()}.tmp`;
  fs.writeFileSync(temporary, `${JSON.stringify(store, null, 2)}\n`, { mode: 0o600 });
  fs.renameSync(temporary, statePath);
  fs.chmodSync(statePath, 0o600);
}

function formatGoal(goal) {
  const elapsedMinutes = Math.floor((Date.now() - goal.startedAt) / 60_000);
  const lines = [
    `Status: ${goal.status}`,
    `Objective: ${goal.objective}`,
    `Automatic continuations: ${goal.turn}/${goal.maxTurns}`,
    `Runtime: ${elapsedMinutes}/${goal.maxMinutes} minutes`,
  ];
  if (goal.pauseReason !== undefined) lines.push(`Reason: ${goal.pauseReason}`);
  if (goal.completionSummary !== undefined) lines.push(`Completion: ${goal.completionSummary}`);
  if (goal.verification !== undefined) lines.push(`Verification: ${goal.verification}`);
  return lines.join("\n");
}

function errorMessage(error) {
  if (error instanceof Error) return error.message;
  if (typeof error?.message === "string") return error.message;
  return typeof error === "string" ? error : JSON.stringify(error);
}
