# Claude Brain — AI Instructions

You are connected to a shared brain system. Two Claude Code instances (PC + MacBook) share this repo.
Read this every session start.

## Your identity
- Machine: read `app/config.json` → `machineName`
- Brain dir: `C:\Users\musst\claude-brain` (Windows) or `~/claude-brain` (Mac)

## Session start checklist
1. Run: `git -C C:\Users\musst\claude-brain pull`
2. Read `handoff/current.md` — if status is `active` and `to` matches this machine, continue that task
3. Check `inbox/` for messages
4. Check `tasks/` for any `*-MACHINENAME-pending.md` files (shouldn't happen if watcher is running)

## When the user gives you a task

### Step 1 — Check if other machine is online
```powershell
powershell -File C:\Users\musst\claude-brain\scripts\check-online.ps1
```
Returns `online:MACHINENAME` or `offline`.

### Step 2A — Other machine is ONLINE → Split mode
```powershell
powershell -File C:\Users\musst\claude-brain\scripts\dispatch.ps1 -Task "the task" -ContextFiles "relevant files"
```
The dispatch script returns your local instructions. Follow them.
- You handle: implementation, UI, assembly
- Remote handles: research, planning, backend/data

When your local half is done, merge:
```powershell
powershell -File C:\Users\musst\claude-brain\scripts\merge-results.ps1 -TaskId "ID" -LocalResult "your output here"
```

### Step 2B — Other machine is OFFLINE → Solo mode
Handle everything yourself. Write result to:
`C:\Users\musst\claude-brain\inbox\TIMESTAMP-MACHINENAME-result.md`
Then sync.

## Memory
- All memory lives in `memory/` — write new memory files there
- Update `memory/MEMORY.md` index when adding files

## Sync command
```powershell
powershell -NonInteractive -File C:\Users\musst\claude-brain\sync.ps1 "reason"
```

## Collaboration split patterns
| Pattern | Local does | Remote does |
|---|---|---|
| Research + Build | Build/implement | Research, gather info |
| Frontend + Backend | Frontend/UI | Backend/API/data |
| Draft + Review | Draft | Review and improve |
| Parallel explore | Approach A | Approach B |

## Important rules
- ALWAYS check if other machine is online before starting a complex task
- NEVER wait idle for remote — start your half immediately, merge when remote finishes
- If remote times out (5 min), deliver local result and note remote was unavailable
- Write all task outputs to the tasks/ directory so both machines can see them
