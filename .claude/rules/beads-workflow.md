---
paths: [".beads/**"]
---
# Beads in StrapLog

Adapted from the Proofbound monorepo rule. Solo, single-machine, **embedded Dolt, no Dolt remote** (by decision).

- `bd` writes to embedded Dolt at `.beads/embeddeddolt/` (gitignored, local). `.beads/issues.jsonl` is git-tracked and is the only durable copy; commit it with the code.
- `export.auto` and `export.git-add` in `.beads/config.yaml` must stay `true`, or writes never reach the JSONL.
- Every write prints "no Dolt remote configured … repair: bd dolt remote add …". Expected; **do not add a remote**.
- Deletes don't auto-export: `bd delete <id> --force && bd export -o .beads/issues.jsonl`.
- Never `bd edit` (interactive). Never delete `.beads/embeddeddolt/`. Don't run `bd doctor`'s `--server` fix.
- Health check: `bd dolt status` says embedded; `bd stats` total equals unique ids in the JSONL.
- **Never commit or push** as part of a bead close; stage and wait for Rik's "commit".
- Phase beads are children of the `[epic] StrapLog v1` epic; the bead is the context handoff, so `bd note` what the next phase must know.
