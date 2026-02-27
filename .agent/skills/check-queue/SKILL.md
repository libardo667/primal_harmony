# Skill: check-queue

**When to use this skill:** When you need to know what to work on next, when resuming after a break, or when explicitly asked to "run the check queue" or "what should I do next?"

---

## Step 1 — Orient

Read in this order before doing anything:
1. `agents/AGENT_OVERVIEW.md` — confirm project structure
2. Run: `python3 agents/scripts/comms.py agents/COMMS_LOG.csv status`
3. Your task queue: `agents/tasks/[yourname]_tasks.md`

---

## Step 2 — Identify Your Task

Priority order:
1. `[!]` High Priority — do these first, always
2. `[ ]` Pending — available to start
3. `[~]` In Progress — resume if you were mid-task

Skip: `[x]` Done, `[B]` Blocked (unless block is resolved in comms log), `[?]` Needs Elder clarification

---

## Step 3 — Verify Dependencies

Every task lists its dependencies. For each dependency:
1. Run: `python3 agents/scripts/comms.py agents/COMMS_LOG.csv search "[dependency keyword]"`
2. If confirmed → proceed
3. If not confirmed → mark task `[B] Blocked`, log it with the specific missing dependency, move to next task

**Never assume a dependency is met without checking the log.**

---

## Step 4 — Godot Pre-Flight Check

Before writing any GDScript, verify:
- [ ] Is this better as a Resource, Node, or Autoload?
- [ ] Does a signal exist for this communication, or do I need to define one?
- [ ] Am I editing a file owned by another agent? (Log it first if yes)
- [ ] Will this require a new Autoload registration? (Flag to Elder if yes)
- [ ] Do I have the data schema from The Keeper before loading any JSON?

**Self-correction rule:** If you hit a GDScript type error, resolve it fully. Do not guess past it or leave it for later. Log it if unresolvable.

---

## Step 5 — Update and Report

On task completion:
1. Update task queue: `[ ]` → `[x]`
2. Log: `python3 agents/scripts/comms.py agents/COMMS_LOG.csv add "The [Role]" "Completed [Task]. [details]. Ready for The [Next Agent]."`
3. If your work unblocks another agent: name them explicitly in the log.

---

## Step 6 — Idle State

If all tasks are complete or blocked:
- Log: `python3 agents/scripts/comms.py agents/COMMS_LOG.csv add "The [Role]" "Queue clear / blocked on [specific thing]. Awaiting Elder direction."`
- Do not invent tasks without Elder approval
- Optional: Read design docs and flag any code-vs-doc inconsistencies to The Elder

---

## Task Status Codes

| Code | Meaning |
|---|---|
| `[ ]` | Pending |
| `[!]` | High Priority |
| `[~]` | In Progress |
| `[x]` | Done |
| `[B]` | Blocked — waiting on dependency |
| `[?]` | Needs Elder clarification |
