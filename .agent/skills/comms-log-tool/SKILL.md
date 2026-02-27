---
name: comms-log-tool
description: >
  Read, write, query, and validate the COMMS_LOG.csv used by multi-agent Godot
  projects (or any multi-agent workflow with a shared CSV communication log).
  Use this skill whenever an agent needs to check project status, read recent
  log entries, find what another agent said, add a new entry, or troubleshoot
  communication gaps. Trigger on: "check the comms log," "what's the project
  status," "log this," "what did the Mechanic/Shaper/etc say," "read COMMS_LOG,"
  "write to the log," "search the log for," checking handoff status between agents,
  understanding what work has been done, or any reference to COMMS_LOG.csv or
  COMMS_LOG.md. Also trigger when an agent is about to write an ad-hoc Python or
  PowerShell script to read a CSV — this tool already does it correctly. This
  skill is essential for multi-agent coordination and should be one of the first
  things consulted when an agent activates.
---

# Comms Log Tool

## The Problem This Solves

In multi-agent Godot projects, agents communicate through a shared CSV log
(`agents/COMMS_LOG.csv`). The log grows large quickly — hundreds of entries with
messages averaging 800+ characters. This makes it too long for `view_file` to
display usefully, so agents write throwaway Python or PowerShell scripts to
read the last few entries. These ad-hoc scripts:

- Handle CSV quoting inconsistently (messages contain commas, newlines, quotes)
- Don't handle encoding issues (the log often has mixed encodings)
- Produce messy unformatted output that's hard to parse
- Get rewritten from scratch by every agent, wasting context window and time
- Lead agents to re-check project state repeatedly because they don't trust the output

This skill provides a single, tested CLI tool that replaces all ad-hoc scripts.

## Quick Reference

The tool is at `scripts/comms.py`. Every command follows the same pattern:

```bash
python3 comms.py <logfile> <command> [args...]
```

### Commands At A Glance

| Command | What it does | When to use it |
|---------|-------------|----------------|
| `recent [N]` | Last N entries, messages truncated to one line | First thing on activation — quick orientation |
| `full [N]` | Last N entries, complete messages | When you need the actual detail of recent work |
| `status` | Most recent entry from each role | "Where is everyone? What's the project state?" |
| `role <name> [N]` | Last N entries from one role | "What has The Mechanic done?" |
| `search <keyword>` | Keyword search across all messages | "Did anyone mention collision_layer?" |
| `since <timestamp>` | All entries after a date/time | "What happened since yesterday?" |
| `add <role> <message>` | Append a new entry | Logging your own work |
| `count` | Statistics breakdown | How big is the log? Who's most active? |
| `phases` | Extract phase transition mentions | Project timeline overview |
| `validate` | Check for CSV formatting issues | Debugging log corruption |

### Examples

```bash
# Activate and orient — what happened recently?
python3 comms.py agents/COMMS_LOG.csv recent

# Get the full picture — where is each agent?
python3 comms.py agents/COMMS_LOG.csv status

# What did the Mechanic say about signals?
python3 comms.py agents/COMMS_LOG.csv search "signal"

# Read The Shaper's last 3 entries in full
python3 comms.py agents/COMMS_LOG.csv role shaper 3

# What's happened since this morning?
python3 comms.py agents/COMMS_LOG.csv since "2026-02-25"

# Log your completed work
python3 comms.py agents/COMMS_LOG.csv add "The Mechanic" "Fixed collision_layer on all warp Area2Ds. Layer 2 for warps, layer 4 for encounters."

# See the last 10 entries in full detail
python3 comms.py agents/COMMS_LOG.csv full 10
```

## Agent Activation Protocol

When an agent activates, it should run these commands in order:

### Step 1: Orient (5 seconds)

```bash
python3 comms.py agents/COMMS_LOG.csv status
```

This gives you the most recent entry from every role — a snapshot of where the
whole project stands. Read the entries for roles you depend on or that depend on you.

### Step 2: Catch up (10 seconds)

```bash
python3 comms.py agents/COMMS_LOG.csv recent 10
```

Skim the last 10 entries for anything that affects your work. Look for:
- Handoff messages directed at your role ("→ The Mechanic: ...")
- Blocker reports from other agents
- Convention decisions you need to follow

### Step 3: Search for your contracts (as needed)

If you're about to work on something that touches another agent's domain,
search for their conventions:

```bash
python3 comms.py agents/COMMS_LOG.csv search "collision_layer"
python3 comms.py agents/COMMS_LOG.csv search "WarpDetector"
python3 comms.py agents/COMMS_LOG.csv search "zone_id"
```

### Step 4: Do your work

### Step 5: Log your results

```bash
python3 comms.py agents/COMMS_LOG.csv add "The Mechanic" "Phase 6: Delivered BattleUI. Signals: battle_started, battle_ended. → The Weaver: hook dialogue triggers to battle_ended."
```

Good log entries include:
- What you delivered (file paths, node names)
- What interfaces you created (signal names, metadata keys, collision layers)
- What you need from other agents (explicit handoffs with "→ Role:")
- What conventions you established that others must follow

## Role Name Fuzzy Matching

The `role` and `add` commands accept fuzzy role names. You don't need to type
the full "The Mechanic" — just "mechanic" works:

```bash
python3 comms.py log.csv role mechanic     # matches "The Mechanic"
python3 comms.py log.csv role elder 3      # matches "The Elder"
python3 comms.py log.csv add keeper "..."  # writes as "The Keeper"
```

Valid roles: The Elder, The Mechanic, The Keeper, The Artisan, The Shaper, The Weaver.

## What The Tool Handles For You

Things you no longer need to write ad-hoc scripts for:

- **Encoding:** Tries utf-8-sig, utf-8, cp1252, latin-1, then falls back to
  replacement characters. The real COMMS_LOG has encoding issues — this handles them.
- **CSV quoting:** Messages contain commas, newlines, and quotes. Python's csv
  module handles this correctly; hand-rolled split-on-comma does not.
- **Overflow columns:** If a message has unescaped commas that create extra CSV
  columns, the tool rejoins them back into the message field.
- **Timestamp normalization:** Some entries have bracket-wrapped timestamps like
  `[2026-02-25 07:01]`. The tool strips brackets for display and parsing.
- **Truncation:** The `recent` command truncates messages to ~200 chars so you
  can scan 10-20 entries at a glance. Use `full` when you need the detail.

## CSV Format Reference

The log uses a 3-column CSV:

```
Timestamp,Role,Message
2026-02-24 07:41,The Elder,"PHASE 1 ACTIVATED. Delegating tasks..."
```

- **Timestamp:** `YYYY-MM-DD HH:MM` format (24-hour). The tool also accepts
  `YYYY-MM-DD HH:MM:SS` and bare `YYYY-MM-DD`.
- **Role:** One of the six Circle roles.
- **Message:** Free-text, quoted if it contains commas or newlines. Can be
  arbitrarily long (current max is ~2700 chars).

The `add` command writes properly-quoted entries that won't corrupt the CSV.

## Troubleshooting

**"The log seems corrupted"** — Run `validate` to check for issues:
```bash
python3 comms.py agents/COMMS_LOG.csv validate
```

**"I can't find an entry I know exists"** — The `search` command is
case-insensitive and searches the full message text. Try shorter keywords.

**"Timestamps are out of order"** — This is normal in multi-agent workflows.
Agents work in parallel and log at different times. The `validate` command
flags these but they're not bugs — they're a feature of concurrent work.

**"The message got cut off in `recent`"** — Use `full` instead of `recent`
to see complete messages. Or use `role <name>` to see a specific agent's
entries in full.