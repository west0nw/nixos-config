import crypto from "node:crypto";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";

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
  const startAuthorizations = new Set();
  const failedSessions = new Set();
  const recoveryTimer = setTimeout(async () => {
    try {
      refreshStore();
      const response = await client.session.status({ query: { directory } });
      if (response?.error !== undefined) return;
      for (const [sessionID, goal] of Object.entries(store.sessions)) {
        if (goal.status !== "active") continue;
        const status = response?.data?.[sessionID];
        if (status !== undefined && status.type !== "idle") continue;
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
    return [
      `Continue the active goal. Automatic continuation ${goal.turn}/${goal.maxTurns}.`,
      "Make new progress; do not repeat the previous response.",
      "If the previous turn requested user input in prose, call goal_pause now instead of asking again.",
    ].join(" ");
  }

  function activeGoalSystemPrompt(goal) {
    return [
      "A persistent goal loop is active for this session.",
      "",
      "Objective:",
      goal.objective,
      "",
      "Continue until the objective is completely and verifiably finished, the user cancels or redirects it, or a safety limit pauses the loop.",
      "Do not declare completion only in prose. Call goal_complete with a summary and concrete verification evidence.",
      "When progress requires the user to choose, clarify, or confirm something, call the built-in question tool; never ask in commentary or ordinary response text.",
      "Call goal_pause before explaining a blocker that requires user action outside answering the question tool.",
      "Commentary is only for short progress updates. Never put a final answer or decision prompt there, and never repeat commentary in the final response.",
    ].join("\n");
  }

  function evaluateIdle(sessionID) {
    refreshStore();
    const goal = goalFor(sessionID);
    if (goal === undefined || goal.status !== "active") return undefined;

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

  return {
    "chat.message": async (input, output) => {
      refreshStore();
      const goal = goalFor(input.sessionID);

      const context = {
        agent: input.agent,
        model: input.model,
        variant: input.variant,
      };
      const internal = consumeInternalPrompt(input.sessionID);
      if (internal) {
        if (goal !== undefined) putGoal(input.sessionID, { ...goal, context });
        return;
      }

      if (hasExplicitGoalWord(output?.parts)) startAuthorizations.add(input.sessionID);
      else startAuthorizations.delete(input.sessionID);

      if (goal === undefined) return;
      clearTimer(input.sessionID);
      failedSessions.delete(input.sessionID);
      if (goal.status === "paused" && goal.stopReason === "blocked") {
        putGoal(input.sessionID, {
          ...goal,
          status: "active",
          pauseReason: undefined,
          stopReason: undefined,
          promptFailures: 0,
          toolCallsThisTurn: 0,
          context,
        });
        await toast("Goal resumed after your reply.", "success");
      } else if (goal.status === "active") {
        putGoal(input.sessionID, { ...goal, promptFailures: 0, context });
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
        clearTimer(sessionID);
        refreshStore();
        const goal = goalFor(sessionID);
        if (goal === undefined || goal.status !== "active") return;
        const promptFailures = goal.promptFailures + 1;
        const message = formatEventError(event.properties?.error);
        putGoal(sessionID, { ...goal, promptFailures, lastError: message });
        if (promptFailures >= MAX_PROMPT_FAILURES) {
          failedSessions.delete(sessionID);
          pauseGoal(
            sessionID,
            `Continuation failed ${promptFailures} times. Last error: ${message}`,
            "prompt-failures",
          );
          await toast("Goal paused after repeated session errors.", "error");
        } else {
          failedSessions.add(sessionID);
          await toast(`Goal continuation failed; retry ${promptFailures}/${MAX_PROMPT_FAILURES}.`, "warning");
        }
        return;
      }
      if (event?.type !== "session.status" || event.properties?.status?.type !== "idle") return;
      const sessionID = event.properties.sessionID;
      const retry = failedSessions.delete(sessionID);
      if (!retry) {
        refreshStore();
        const goal = goalFor(sessionID);
        if (goal?.status === "active" && goal.promptFailures > 0) {
          putGoal(sessionID, { ...goal, promptFailures: 0, lastError: undefined });
        }
      }
      queueContinuation(sessionID, retry ? "session-error-retry" : "idle");
    },

    tool: {
      goal_start: {
        description: [
          "Start a bounded persistent goal loop for this session and begin working on it immediately.",
          "Use only when the user's current message explicitly asks to start a goal and contains the standalone word 'goal'.",
          "Choose limits proportionate to the work. Calling this replaces any existing session goal.",
        ].join(" "),
        args: {
          objective: {
            type: "string",
            description: "A specific, outcome-focused objective including required verification.",
          },
          max_turns: {
            type: "integer",
            minimum: 1,
            maximum: 200,
            description: "Maximum automatic continuation turns. Choose intelligently from 1 to 200.",
          },
          max_minutes: {
            type: "integer",
            minimum: 1,
            maximum: 1440,
            description: "Maximum elapsed runtime in minutes. Choose intelligently from 1 to 1440.",
          },
        },
        execute: async (args, context) => {
          if (!startAuthorizations.has(context.sessionID)) {
            return "Goal not started: the current user message must explicitly ask to start a goal and contain the word 'goal'.";
          }
          const objective = typeof args.objective === "string" ? args.objective.trim() : "";
          if (objective.length === 0) return "Goal not started: objective must not be empty.";
          if (!Number.isInteger(args.max_turns) || args.max_turns < 1 || args.max_turns > 200) {
            return "Goal not started: max_turns must be an integer from 1 to 200.";
          }
          if (!Number.isInteger(args.max_minutes) || args.max_minutes < 1 || args.max_minutes > 1440) {
            return "Goal not started: max_minutes must be an integer from 1 to 1440.";
          }

          startAuthorizations.delete(context.sessionID);
          refreshStore();
          const previous = goalFor(context.sessionID);
          clearTimer(context.sessionID);
          const now = Date.now();
          putGoal(context.sessionID, {
            id: crypto.randomUUID(),
            objective,
            status: "active",
            turn: 0,
            maxTurns: args.max_turns,
            maxMinutes: args.max_minutes,
            startedAt: now,
            updatedAt: now,
            toolCallsThisTurn: 0,
            promptFailures: 0,
          });
          await toast(previous === undefined ? "Goal started." : "Previous goal replaced.", "success");
          return `Goal started with limits of ${args.max_turns} continuations and ${args.max_minutes} minutes. Begin working on this objective now: ${objective}`;
        },
      },

      goal_status: {
        description: "Read the persistent goal status for this session when the user asks about it.",
        args: {},
        execute: async (_args, context) => {
          refreshStore();
          const goal = goalFor(context.sessionID);
          if (goal === undefined) return "No goal exists for this session.";
          return formatGoal(goal);
        },
      },

      goal_resume: {
        description: "Resume this session's paused persistent goal and continue working on it immediately.",
        args: {},
        execute: async (_args, context) => {
          refreshStore();
          const goal = goalFor(context.sessionID);
          if (goal === undefined || goal.status !== "paused") return "No paused goal can be resumed.";
          putGoal(context.sessionID, {
            ...goal,
            status: "active",
            pauseReason: undefined,
            stopReason: undefined,
            promptFailures: 0,
            toolCallsThisTurn: 0,
          });
          await toast("Goal resumed.", "success");
          return `Goal resumed. Continue working on this objective now: ${goal.objective}`;
        },
      },

      goal_cancel: {
        description: "Cancel this session's active or paused persistent goal when the user asks to stop it.",
        args: {
          reason: {
            type: "string",
            description: "Concise reason the goal is being cancelled.",
          },
        },
        execute: async (args, context) => {
          refreshStore();
          const goal = goalFor(context.sessionID);
          if (goal === undefined || goal.status === "completed" || goal.status === "cancelled") {
            return "No open goal can be cancelled.";
          }
          clearTimer(context.sessionID);
          putGoal(context.sessionID, {
            ...goal,
            status: "cancelled",
            pauseReason: args.reason,
            stopReason: "user",
          });
          await toast("Goal cancelled.", "success");
          return `Goal cancelled: ${args.reason}`;
        },
      },

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

          const summary = typeof args.summary === "string" ? args.summary.trim() : "";
          const verification = typeof args.verification === "string" ? args.verification.trim() : "";
          if (summary.length === 0 || verification.length === 0) {
            return "Goal completion rejected: summary and verification must both be non-empty.";
          }

          clearTimer(context.sessionID);
          putGoal(context.sessionID, {
            ...goal,
            status: "completed",
            completedAt: Date.now(),
            completionSummary: summary,
            verification,
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
      startAuthorizations.clear();
      failedSessions.clear();
    },
  };
};

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

function formatGoal(goal) {
  const elapsedMinutes = Math.floor((Date.now() - goal.startedAt) / 60000);
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

function hasExplicitGoalWord(parts) {
  return (
    Array.isArray(parts) &&
    parts.some((part) => part?.type === "text" && part.synthetic !== true && /\bgoal\b/i.test(part.text ?? ""))
  );
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
