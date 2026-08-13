import crypto from "node:crypto";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";

const DEFAULT_MAX_TURNS = 50;
const DEFAULT_MAX_MINUTES = 120;
const MAX_NO_PROGRESS_TURNS = 3;
const MAX_PROMPT_FAILURES = 3;
const CONTINUATION_DELAY_MS = 1000;
const INTERNAL_PROMPT_TTL_MS = 30000;

export default async function goalPlugin({ client, directory, worktree }) {
  const projectRoot = worktree || directory;
  const statePath = goalStatePath(projectRoot);
  let store = loadStore(statePath, projectRoot);
  const timers = new Map();
  const sending = new Set();
  const internalPrompts = new Map();
  const recoveryTimer = setTimeout(async () => {
    try {
      refreshStore();
      const response = await client.session.status({ query: { directory } });
      if (response?.error !== undefined) return;
      for (const [sessionID, goal] of Object.entries(store.sessions)) {
        if (goal.status !== "active") continue;
        if (response?.data?.[sessionID]?.type !== "idle") continue;
        queueContinuation(sessionID, "startup-recovery");
      }
    } catch (error) {
      console.error(`[goal] Startup recovery failed: ${errorMessage(error)}`);
    }
  }, 2000);

  function refreshStore() {
    store = loadStore(statePath, projectRoot);
  }

  function save() {
    saveStore(statePath, store);
  }

  function goalFor(sessionID) {
    return store.sessions[sessionID];
  }

  function putGoal(sessionID, goal) {
    store.sessions[sessionID] = { ...goal, updatedAt: Date.now() };
    store.updatedAt = Date.now();
    save();
    return store.sessions[sessionID];
  }

  function clearTimer(sessionID) {
    const timer = timers.get(sessionID);
    if (timer !== undefined) clearTimeout(timer);
    timers.delete(sessionID);
  }

  function markInternalPrompt(sessionID) {
    const current = internalPrompts.get(sessionID);
    internalPrompts.set(sessionID, {
      count: (current?.count ?? 0) + 1,
      expiresAt: Date.now() + INTERNAL_PROMPT_TTL_MS,
    });
  }

  function consumeInternalPrompt(sessionID) {
    const current = internalPrompts.get(sessionID);
    if (current === undefined) return false;
    if (current.expiresAt < Date.now()) {
      internalPrompts.delete(sessionID);
      return false;
    }
    if (current.count <= 1) internalPrompts.delete(sessionID);
    else internalPrompts.set(sessionID, { ...current, count: current.count - 1 });
    return true;
  }

  function discardInternalPrompt(sessionID) {
    const current = internalPrompts.get(sessionID);
    if (current === undefined) return;
    if (current.count <= 1) internalPrompts.delete(sessionID);
    else internalPrompts.set(sessionID, { ...current, count: current.count - 1 });
  }

  async function toast(message, variant = "info") {
    try {
      await client.tui.showToast({
        body: { title: "Goal", message, variant, duration: 5000 },
      });
    } catch {
      // Toast support varies by client; command behavior does not depend on it.
    }
  }

  function pauseGoal(sessionID, reason, stopReason) {
    refreshStore();
    const goal = goalFor(sessionID);
    if (goal === undefined || goal.status !== "active") return undefined;
    clearTimer(sessionID);
    return putGoal(sessionID, {
      ...goal,
      status: "paused",
      pauseReason: reason,
      stopReason,
    });
  }

  function continuationPrompt(goal) {
    return `Continue the active goal. Automatic continuation ${goal.turn}/${goal.maxTurns}.`;
  }

  function activeGoalSystemPrompt(goal) {
    return [
      "A persistent goal loop is active for this session.",
      "",
      "Objective:",
      goal.objective,
      "",
      "Continue until the objective is completely and verifiably finished, the user interrupts, or a safety limit pauses the loop.",
      "Do not declare completion only in prose. Call goal_complete with a summary and concrete verification evidence.",
      "Call goal_pause when a real blocker requires user action.",
      "Goal management commands override these continuation instructions for their command turn.",
    ].join("\n");
  }

  function evaluateIdle(sessionID) {
    refreshStore();
    let goal = goalFor(sessionID);
    if (goal === undefined || goal.status !== "active") return undefined;

    if (goal.lastEvaluatedTurn !== goal.turn) {
      const noProgressTurns = goal.toolCallsThisTurn > 0 ? 0 : goal.noProgressTurns + 1;
      goal = putGoal(sessionID, {
        ...goal,
        lastEvaluatedTurn: goal.turn,
        noProgressTurns,
      });
    }

    if (goal.noProgressTurns >= MAX_NO_PROGRESS_TURNS) {
      return pauseGoal(
        sessionID,
        `No tool-backed progress was detected for ${goal.noProgressTurns} consecutive turns.`,
        "no-progress",
      );
    }
    if (goal.turn >= goal.maxTurns) {
      return pauseGoal(sessionID, `Maximum continuation turns reached (${goal.maxTurns}).`, "turn-limit");
    }
    if (Date.now() - goal.startedAt >= goal.maxMinutes * 60 * 1000) {
      return pauseGoal(sessionID, `Maximum runtime reached (${goal.maxMinutes} minutes).`, "time-limit");
    }
    if (goal.promptFailures >= MAX_PROMPT_FAILURES) {
      return pauseGoal(
        sessionID,
        `Maximum continuation prompt failures reached (${MAX_PROMPT_FAILURES}).`,
        "prompt-failures",
      );
    }
    return goal;
  }

  function queueContinuation(sessionID, reason) {
    if (timers.has(sessionID) || sending.has(sessionID)) return;
    const goal = evaluateIdle(sessionID);
    if (goal === undefined || goal.status !== "active") return;

    const timer = setTimeout(async () => {
      timers.delete(sessionID);
      refreshStore();
      const current = goalFor(sessionID);
      if (current === undefined || current.status !== "active" || sending.has(sessionID)) return;

      sending.add(sessionID);
      const next = putGoal(sessionID, {
        ...current,
        turn: current.turn + 1,
        toolCallsThisTurn: 0,
        lastContinuationReason: reason,
        lastContinuationAt: Date.now(),
      });
      markInternalPrompt(sessionID);

      let retry = false;
      try {
        const body = {
          parts: [{ type: "text", text: continuationPrompt(next), synthetic: true }],
        };
        if (next.context?.agent) body.agent = next.context.agent;
        if (next.context?.model) body.model = next.context.model;
        if (next.context?.variant) body.variant = next.context.variant;

        const response = await client.session.promptAsync({
          path: { id: sessionID },
          query: { directory },
          body,
        });
        if (response?.error !== undefined) throw new Error(JSON.stringify(response.error));
      } catch (error) {
        discardInternalPrompt(sessionID);
        refreshStore();
        const failed = goalFor(sessionID);
        if (failed !== undefined && failed.status === "active") {
          const promptFailures = failed.promptFailures + 1;
          putGoal(sessionID, {
            ...failed,
            promptFailures,
            lastError: errorMessage(error),
          });
          retry = promptFailures < MAX_PROMPT_FAILURES;
          if (!retry) {
            pauseGoal(
              sessionID,
              `Continuation prompt failed ${promptFailures} times: ${errorMessage(error)}`,
              "prompt-failures",
            );
            await toast("Goal paused after repeated continuation failures.", "error");
          }
        }
      } finally {
        sending.delete(sessionID);
      }

      if (retry) queueContinuation(sessionID, "prompt-retry");
    }, CONTINUATION_DELAY_MS);

    timers.set(sessionID, timer);
  }

  async function handleCommand(input, output) {
    const owned = new Set(["goal", "goal-resume"]);
    if (!owned.has(input.command)) return;

    refreshStore();
    const current = goalFor(input.sessionID);
    let text;

    if (input.command === "goal") {
      const parsed = parseGoalArguments(input.arguments);
      if (parsed.error !== undefined) {
        await toast(`Goal not started: ${parsed.error}`, "error");
        throw new Error(`[goal] ${parsed.error}`);
      }
      clearTimer(input.sessionID);
      const now = Date.now();
      const goal = putGoal(input.sessionID, {
        id: crypto.randomUUID(),
        objective: parsed.objective,
        status: "active",
        turn: 0,
        maxTurns: parsed.maxTurns,
        maxMinutes: parsed.maxMinutes,
        startedAt: now,
        updatedAt: now,
        lastEvaluatedTurn: -1,
        toolCallsThisTurn: 0,
        noProgressTurns: 0,
        promptFailures: 0,
      });
      text = goal.objective;
      await toast(current === undefined ? "Goal started." : "Previous goal replaced.", "success");
    } else {
      if (current === undefined || current.status !== "paused") {
        await toast("There is no paused goal to resume.", "warning");
        throw new Error("[goal] There is no paused goal to resume.");
      }
      const resumed = putGoal(input.sessionID, {
        ...current,
        status: "active",
        pauseReason: undefined,
        stopReason: undefined,
        noProgressTurns: 0,
        promptFailures: 0,
        toolCallsThisTurn: 0,
        lastEvaluatedTurn: current.turn - 1,
      });
      text = "Continue the active goal.";
      await toast("Goal resumed.", "success");
    }

    markInternalPrompt(input.sessionID);
    replaceCommandText(output.parts, text);
  }

  return {
    config: async (config) => {
      config.command ??= {};
      config.command.goal = {
        description: "Start a persistent goal loop",
        agent: "build",
        template: "$ARGUMENTS",
      };
      // Desktop server commands always become model turns. Only expose commands
      // whose purpose is to start or resume model work.
      config.command["goal-resume"] = {
        description: "Resume the paused goal",
        agent: "build",
        template: "$ARGUMENTS",
      };
    },

    "command.execute.before": handleCommand,

    "chat.message": async (input) => {
      refreshStore();
      const goal = goalFor(input.sessionID);
      if (goal === undefined) return;

      const context = {
        agent: input.agent,
        model: input.model,
        variant: input.variant,
      };
      const internal = consumeInternalPrompt(input.sessionID);
      if (internal) {
        putGoal(input.sessionID, { ...goal, context });
        return;
      }
      if (goal.status === "active") {
        pauseGoal(input.sessionID, "A user message interrupted the automatic loop.", "user");
        await toast("Goal paused because you sent a message.", "warning");
      }
    },

    "experimental.chat.system.transform": async (input, output) => {
      if (input.sessionID === undefined) return;
      refreshStore();
      const goal = goalFor(input.sessionID);
      if (goal?.status === "active") output.system.push(activeGoalSystemPrompt(goal));
    },

    "tool.execute.after": async (input) => {
      refreshStore();
      const goal = goalFor(input.sessionID);
      if (goal === undefined || goal.status !== "active") return;
      putGoal(input.sessionID, {
        ...goal,
        toolCallsThisTurn: goal.toolCallsThisTurn + 1,
      });
    },

    event: async ({ event }) => {
      if (event?.type === "session.error") {
        const sessionID = event.properties?.sessionID;
        if (sessionID === undefined) return;
        const paused = pauseGoal(sessionID, `Session error: ${formatEventError(event.properties?.error)}`, "error");
        if (paused !== undefined) await toast("Goal paused after a session error.", "error");
        return;
      }
      if (event?.type !== "session.status" || event.properties?.status?.type !== "idle") return;
      queueContinuation(event.properties.sessionID, "idle");
    },

    tool: {
      goal_complete: {
        description: "Mark the active persistent goal complete after fully finishing and verifying its objective.",
        args: {
          summary: {
            type: "string",
            description: "Concise summary of the completed work.",
          },
          verification: {
            type: "string",
            description: "Concrete tests, checks, or evidence proving the objective is complete.",
          },
        },
        execute: async (args, context) => {
          refreshStore();
          const goal = goalFor(context.sessionID);
          if (goal === undefined || goal.status !== "active") return "No active goal can be completed.";

          try {
            const response = await client.session.todo({
              path: { id: context.sessionID },
              query: { directory },
            });
            if (response?.error !== undefined) return "Goal completion rejected: could not verify the session todo list.";
            const unfinished = (response?.data ?? []).filter(
              (todo) => todo.status === "pending" || todo.status === "in_progress",
            );
            if (unfinished.length > 0) {
              return `Goal completion rejected: ${unfinished.length} session todo item(s) remain unfinished.`;
            }
          } catch (error) {
            return `Goal completion rejected: todo verification failed: ${errorMessage(error)}`;
          }

          clearTimer(context.sessionID);
          putGoal(context.sessionID, {
            ...goal,
            status: "completed",
            completedAt: Date.now(),
            completionSummary: args.summary,
            verification: args.verification,
            stopReason: "completed",
          });
          await toast("Goal completed.", "success");
          return "Goal marked complete. Report the completion summary and verification to the user.";
        },
      },

      goal_pause: {
        description: "Pause the active persistent goal when a real blocker requires user action.",
        args: {
          reason: {
            type: "string",
            description: "The concrete blocker and the user action required to continue.",
          },
        },
        execute: async (args, context) => {
          const paused = pauseGoal(context.sessionID, args.reason, "blocked");
          if (paused === undefined) return "No active goal can be paused.";
          await toast("Goal paused for a blocker.", "warning");
          return "Goal paused. Explain the blocker and required next action to the user.";
        },
      },
    },

    dispose: async () => {
      clearTimeout(recoveryTimer);
      for (const timer of timers.values()) clearTimeout(timer);
      timers.clear();
      sending.clear();
      internalPrompts.clear();
    },
  };
};

function parseGoalArguments(raw) {
  let objective = raw.trim();
  let maxTurns = DEFAULT_MAX_TURNS;
  let maxMinutes = DEFAULT_MAX_MINUTES;

  const turnMatch = objective.match(/(?:^|\s)--max-turns\s+(\d+)(?=\s|$)/);
  if (turnMatch !== null) {
    maxTurns = Number(turnMatch[1]);
    objective = objective.replace(turnMatch[0], " ").trim();
  }
  const minuteMatch = objective.match(/(?:^|\s)--max-minutes\s+(\d+)(?=\s|$)/);
  if (minuteMatch !== null) {
    maxMinutes = Number(minuteMatch[1]);
    objective = objective.replace(minuteMatch[0], " ").trim();
  }

  objective = objective.replace(/\s+/g, " ");
  if (objective.length === 0) return { error: "Provide an objective after /goal." };
  if (!Number.isInteger(maxTurns) || maxTurns < 1 || maxTurns > 200) {
    return { error: "--max-turns must be between 1 and 200." };
  }
  if (!Number.isInteger(maxMinutes) || maxMinutes < 1 || maxMinutes > 1440) {
    return { error: "--max-minutes must be between 1 and 1440." };
  }
  return { objective, maxTurns, maxMinutes };
}

function replaceCommandText(parts, text) {
  const part = parts.find((item) => item.type === "text");
  if (part !== undefined) part.text = text;
  else parts.push({ type: "text", text });
}

function goalStatePath(projectRoot) {
  const dataHome = process.env.XDG_DATA_HOME || path.join(os.homedir(), ".local", "share");
  const projectHash = crypto.createHash("sha256").update(path.resolve(projectRoot)).digest("hex").slice(0, 24);
  return path.join(dataHome, "opencode", "goal-loop", `${projectHash}.json`);
}

function emptyStore(projectRoot) {
  return {
    version: 1,
    projectRoot: path.resolve(projectRoot),
    sessions: {},
    updatedAt: Date.now(),
  };
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

function formatEventError(error) {
  if (error === undefined) return "unknown error";
  if (typeof error === "string") return error;
  if (typeof error?.data?.message === "string") return error.data.message;
  if (typeof error?.message === "string") return error.message;
  if (typeof error?.name === "string") return error.name;
  return JSON.stringify(error);
}

function errorMessage(error) {
  if (error instanceof Error) return error.message;
  return String(error);
}
