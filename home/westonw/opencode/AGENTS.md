# OpenCode Configuration

OpenCode's global configuration is managed declaratively by Home Manager in
`~/nixos-config/home/westonw/opencode/default.nix`. Do not modify files under
`~/.config/opencode/` directly. Make configuration changes in the NixOS
configuration repository instead, then apply the Home Manager configuration.

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
