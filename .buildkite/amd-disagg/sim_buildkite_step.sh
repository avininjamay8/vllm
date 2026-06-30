#!/bin/bash
# Simulate a Buildkite step locally: load a step's env: block and run its
# commands: from the repo root, exactly as the agent would. Usage:
#   bash sim_buildkite_step.sh <step-key>
set -uo pipefail
STEP_KEY="${1:?usage: sim_buildkite_step.sh <step-key>}"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PIPELINE="$REPO_ROOT/.buildkite/amd-disagg/pipeline.disagg.yaml"

echo "[sim] repo=$REPO_ROOT step=$STEP_KEY"

# Export the step's env: block (KEY=VALUE lines emitted by the parser).
while IFS= read -r line; do
  [ -z "$line" ] && continue
  echo "[sim] env: $line"
  export "$line"
done < <(python3 - "$PIPELINE" "$STEP_KEY" <<'PY'
import sys, yaml
pipeline, key = sys.argv[1], sys.argv[2]
steps = yaml.safe_load(open(pipeline))["steps"]
step = next(s for s in steps if s.get("key") == key)
for k, v in (step.get("env", {}) or {}).items():
    print(f"{k}={v}")
PY
)

# Run the step's commands: from repo root.
cd "$REPO_ROOT"
python3 - "$PIPELINE" "$STEP_KEY" <<'PY' > /tmp/_bk_cmds.sh
import sys, yaml
pipeline, key = sys.argv[1], sys.argv[2]
steps = yaml.safe_load(open(pipeline))["steps"]
step = next(s for s in steps if s.get("key") == key)
for c in step.get("commands", []):
    print(c)
PY
echo "[sim] running commands:"; cat /tmp/_bk_cmds.sh
bash /tmp/_bk_cmds.sh
rc=$?
echo "[sim] step rc=$rc"
exit $rc
