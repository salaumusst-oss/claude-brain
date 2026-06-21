# Claude Brain — AI Instructions

You are connected to a shared brain system. Two Claude Code instances (PC + Laptop) share this repo.
Read this at the start of every session.

## Your identity this session
- Machine: check `app/config.json` → `machineName`
- Brain dir: `C:\Users\musst\claude-brain` (Windows) or `~/claude-brain` (Mac)

## First thing every session
1. Run sync: `powershell -File sync.ps1` (Windows) or `bash sync.sh` (Mac)
2. Read `handoff/current.md` — if status is `active` and `to` matches this machine, pick up from there
3. Check `inbox/` for any messages from the other instance

## Last thing every session
1. If switching machines: write a handoff to `handoff/current.md` (use the template)
2. Sync runs automatically via the Stop hook

## Memory
- All persistent memory lives in `memory/` — treat this as the source of truth
- When saving a new memory, write it to `memory/filename.md` (not to ~/.claude/projects/.../memory/)
- Update `memory/MEMORY.md` index whenever you add a file

## Two-instance collaboration
When working with the other instance simultaneously:
- Write your subtask result to `inbox/TIMESTAMP-MACHINENAME.md`
- Call sync so the other instance can pull it
- After the other instance pushes its result, pull and merge both outputs
- Delete inbox messages after reading

## Handoff format
```
---
from: MACHINENAME
to: OTHERMACHINE
timestamp: YYYY-MM-DD HH:MM
status: active | idle
---

# Current Handoff

## Task
What we're building

## Context
Key details

## Files touched
- path/to/file

## Next steps
- [ ] step 1
- [ ] step 2
```

## Collaboration split patterns
- **Research + Build**: Instance A researches/gathers info → posts to inbox → Instance B implements
- **Frontend + Backend**: Each handles its layer → merge
- **Draft + Review**: Instance A writes → Instance B critiques and improves
- **Parallel exploration**: Both explore different approaches → compare in inbox → pick best

## Sync command
- Windows: `powershell -NonInteractive -File C:\Users\musst\claude-brain\sync.ps1 "reason"`
- Mac: `bash ~/claude-brain/sync.sh "reason"`
