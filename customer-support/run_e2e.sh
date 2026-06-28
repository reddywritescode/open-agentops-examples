#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PYTHON_BIN="${PYTHON:-python3}"
OPEN_AGENTOPS=("$PYTHON_BIN" -m open_agentops.cli)

if [ "${1:-}" ]; then
  WORKDIR="$1"
  rm -rf "$WORKDIR"
  mkdir -p "$WORKDIR"
else
  WORKDIR="$(mktemp -d /tmp/open-agentops-customer-support.XXXXXX)"
fi

INIT_DIR="$WORKDIR/first-run-init"
PACKAGE_DIR="$WORKDIR/customer-repo"
ARTIFACT_DIR="$WORKDIR/artifacts"
SUMMARY="$WORKDIR/E2E_SUMMARY.md"

mkdir -p "$INIT_DIR" "$PACKAGE_DIR"
cp "$SCRIPT_DIR/agent.py" "$INIT_DIR/agent.py"

echo "== First-run init creates config and starter eval =="
"${OPEN_AGENTOPS[@]}" init "$INIT_DIR" --agent customer_support_agent --entrypoint agent:support_agent
test -f "$INIT_DIR/agentops.yml"
test -f "$INIT_DIR/evals/customer_support_agent.generated.yml"

echo "== Copy customer support package =="
cp -R "$SCRIPT_DIR"/. "$PACKAGE_DIR"/
rm -rf "$PACKAGE_DIR/.agentops" "$PACKAGE_DIR/artifacts"

cd "$PACKAGE_DIR"
git init -q
git config user.email "agentops@example.local"
git config user.name "Open AgentOps Example"
git add .
git commit -q -m "unsafe customer support agent"

mkdir -p .agentops/downstream-e2e

echo "== Scan and validate customer package =="
"${OPEN_AGENTOPS[@]}" scan .
"${OPEN_AGENTOPS[@]}" validate --config agentops.yml

echo "== Unsafe candidate must fail =="
set +e
"${OPEN_AGENTOPS[@]}" eval run --config agentops.yml > .agentops/downstream-e2e/unsafe-eval.log 2>&1
UNSAFE_EVAL_STATUS=$?
"${OPEN_AGENTOPS[@]}" gate --config agentops.yml > .agentops/downstream-e2e/unsafe-gate.log 2>&1
UNSAFE_GATE_STATUS=$?
set -e

if [ "$UNSAFE_EVAL_STATUS" -eq 0 ]; then
  echo "Expected unsafe eval to fail, but it passed" >&2
  cat .agentops/downstream-e2e/unsafe-eval.log >&2
  exit 1
fi

if [ "$UNSAFE_GATE_STATUS" -eq 0 ]; then
  echo "Expected unsafe gate to fail, but it passed" >&2
  cat .agentops/downstream-e2e/unsafe-gate.log >&2
  exit 1
fi

cat .agentops/downstream-e2e/unsafe-gate.log

echo "== Apply safe patch =="
git apply --check patches/safe-mutation-guard.patch
git apply patches/safe-mutation-guard.patch
git diff -- agent.py > .agentops/downstream-e2e/applied-safe.patch

echo "== Patched candidate must pass =="
"${OPEN_AGENTOPS[@]}" eval run --config agentops.yml
"${OPEN_AGENTOPS[@]}" gate --config agentops.yml
"${OPEN_AGENTOPS[@]}" baseline save --config agentops.yml --name main

echo "== Re-run patched candidate and compare baseline =="
"${OPEN_AGENTOPS[@]}" eval run --config agentops.yml
"${OPEN_AGENTOPS[@]}" gate --config agentops.yml
"${OPEN_AGENTOPS[@]}" baseline compare --config agentops.yml --name main --fail-on-regression

echo "== Export artifacts =="
rm -rf "$ARTIFACT_DIR"
"${OPEN_AGENTOPS[@]}" export --config agentops.yml --output "$ARTIFACT_DIR"
find "$ARTIFACT_DIR" -maxdepth 1 -type f -print | sort

cat > "$SUMMARY" <<EOF
# Customer Support Open AgentOps E2E

- Workdir: \`$WORKDIR\`
- First-run init: PASS
- Unsafe eval status: \`$UNSAFE_EVAL_STATUS\`
- Unsafe gate status: \`$UNSAFE_GATE_STATUS\`
- Safe patch: PASS
- Baseline compare: PASS
- Artifacts: \`$ARTIFACT_DIR\`

Key files:

- \`$PACKAGE_DIR/.agentops/downstream-e2e/unsafe-eval.log\`
- \`$PACKAGE_DIR/.agentops/downstream-e2e/unsafe-gate.log\`
- \`$PACKAGE_DIR/.agentops/downstream-e2e/applied-safe.patch\`
- \`$ARTIFACT_DIR/report.md\`
- \`$ARTIFACT_DIR/report.html\`
- \`$ARTIFACT_DIR/junit.xml\`
- \`$ARTIFACT_DIR/run.json\`
- \`$ARTIFACT_DIR/metrics.json\`
- \`$ARTIFACT_DIR/trace.jsonl\`
EOF

echo "== Summary =="
cat "$SUMMARY"
