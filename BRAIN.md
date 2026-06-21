# Claude Brain

Shared memory and coordination system for Claude Code instances across machines.

## Structure

```
claude-brain/
├── memory/       ← shared memory files (synced across all instances)
├── handoff/      ← current.md = active task handoff between instances
├── inbox/        ← messages between instances (delete after reading)
├── sync.ps1      ← Windows sync script
└── sync.sh       ← Mac/Linux sync script
```

## Setup (each machine)

1. Clone this repo: `git clone https://github.com/salaumusst-oss/claude-brain.git ~/claude-brain`
2. Add to your project's CLAUDE.md:
   ```
   # Shared Brain
   Memory location: ~/claude-brain/memory/
   Handoff location: ~/claude-brain/handoff/current.md
   Run ~/claude-brain/sync.ps1 (Windows) or ~/claude-brain/sync.sh (Mac) to sync.
   ```

## Daily use

### Switching machines
1. On current machine: run sync script + write a handoff in `handoff/current.md`
2. On new machine: run sync script → read handoff → continue

### Two instances working together
- **Instance A** takes one subtask, writes results to `inbox/TIMESTAMP-A.md`, syncs
- **Instance B** pulls, reads inbox, handles its subtask, merges both results
- Delete inbox messages after reading

### Sync
```powershell
# Windows
C:\Users\musst\claude-brain\sync.ps1

# Mac/Linux
~/claude-brain/sync.sh
```

## Handoff format (handoff/current.md)

```markdown
---
from: PC
to: Laptop
timestamp: 2026-06-21 14:30
status: active
---

# Current Handoff

## Task
What we're building

## Context
Key details the next instance needs

## Files touched
- path/to/file.ts

## Next steps
- [ ] Step 1
- [ ] Step 2
```
