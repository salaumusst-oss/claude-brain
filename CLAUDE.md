# Claude Brain — Instructions

This repo is the shared brain for Claude Code instances across machines.

## Memory
All memory files live in `memory/`. When saving memories, write them here instead of the local Claude memory directory.

## Syncing
After every session, run the sync script:
- Windows: `powershell -File C:\Users\musst\claude-brain\sync.ps1`
- Mac/Linux: `~/claude-brain/sync.sh`

The Stop hook in settings.json runs this automatically when Claude Code stops.

## Switching machines
1. Run sync on current machine
2. On new machine: `cd ~/claude-brain && git pull`
3. Check `handoff/current.md` for context left by the other instance

## Two instances collaborating
- Write subtask results to `inbox/TIMESTAMP-MACHINENAME.md`
- Sync so the other instance can pull and read it
- Delete inbox files after reading
