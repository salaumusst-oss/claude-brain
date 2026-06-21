# Task Queue

Files here follow the lifecycle:
  TIMESTAMP-MACHINE-pending.md   → waiting to be picked up
  TIMESTAMP-MACHINE-active.md   → being worked on
  TIMESTAMP-MACHINE-done.md     → finished, result inside
  TIMESTAMP-MACHINE-failed.md   → errored

The dispatcher writes pending files. The watcher on the target machine picks them up.
