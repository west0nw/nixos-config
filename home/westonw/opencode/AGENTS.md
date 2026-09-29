# OpenCode Configuration

OpenCode's global configuration is managed declaratively by Home Manager in
`~/nixos-config/home/westonw/opencode/default.nix`. Do not modify files under
`~/.config/opencode/` directly. Make configuration changes in the NixOS
configuration repository instead, then apply the Home Manager configuration.

# Subagent model and reasoning selection

When using a subagent, choose the correct model and reasoning effort for the
job. Use only these models, ranked from greatest to least intelligence:

1. **GPT-6 Astra** — `openai/gpt-6-astra`
2. **GPT-6.1 Sol** — `openai/gpt-6.1-sol`
3. **GPT-6 Luna** — `openai/gpt-6-luna`

Available reasoning efforts, from highest to lowest, are **Max**, **Xhigh**,
**High**, **Medium**, and **Low**. Select the model and effort explicitly when
launching a subagent, using `provider/model#variant` with a lowercase variant
(for example, `openai/gpt-6.1-sol#high`). Use the models tool to confirm the
available model IDs and variants.

Aim for maximum correctness with minimum usage. Choose a smarter model when
the task requires figuring out a lot independently, is open-ended, or requires
good taste. Choose higher reasoning effort when the task requires more
thoroughness or is longer. Use Max very rarely, only when the task absolutely
calls for it.

Always use Astra for tasks requiring 3D design, 3D understanding, or 3D
reasoning. Astra is wiser than Sol, and Sol is wiser than Luna. Sol is about as
generally intelligent as Astra; Luna is much less generally intelligent than
either. Use these distinctions when deciding which model fits the task.

For cost planning, Astra costs about 6 times as much as Sol, and Sol costs
about 10 times as much as Luna. Treat each increase in reasoning effort as
roughly doubling the cost. Use the least expensive model and effort that can
reliably achieve the required correctness.

# Version control

Commit completed changes. When working in a version-controlled project,
validate the task and create a commit before the final response unless
the user says not to commit. Follow the project's version-control
instructions and commit only the current task's changes. Never
include unrelated or pre-existing work.

# Persistent goals

Call `goal_start` only when the user's current message explicitly asks to start
a persistent goal and contains the standalone word `goal`. Never infer goal
intent from an ordinary task, requests for autonomous work, or phrases such as
"keep going." When explicitly requested, write a concrete objective with
verification criteria, choose the smallest reasonable `max_turns` and
`max_minutes` budgets, then begin working immediately. Use the other
`goal_*` tools to pause for genuine blockers, resume, cancel, or complete
an existing goal as needed. A reply to a blocker automatically resumes
the paused goal.

# Questions and response channels

Use the built-in `question` tool whenever work cannot proceed until the user
chooses, clarifies, or confirms something. Do not hand-format the same choices
in commentary or the final response when the tool is available. If user action
outside answering a question is required, use the appropriate blocking or pause
mechanism before explaining the required action.

Commentary is only for short progress updates while work is continuing. Never
put a final answer or a user decision prompt in commentary, and never restate
commentary in the final response. Emit each user-facing answer or question once.

# Response language

Avoid overly-technical and terse language that is hard to parse and understand.
Use simple language. Don't be afraid to explain complex concepts and break
things down. Find a balance between concise and understandable responses.
