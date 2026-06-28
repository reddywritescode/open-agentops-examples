# Open AgentOps Examples

Runnable examples for [Open AgentOps](https://github.com/reddywritescode/open-agentops).

This repo is intentionally separate from the product repo. It shows how a normal agent project adds:

- `agentops.yml`
- eval YAML
- a CI workflow
- exported reports and traces

## Examples

| Example | What it demonstrates |
|---|---|
| `customer-support/` | Unsafe agent fails, safe patch passes, baseline compare and artifacts work |

## Run Locally

Install Open AgentOps from the product repo:

```bash
python -m pip install "git+https://github.com/reddywritescode/open-agentops.git"
```

Run the customer support example:

```bash
bash customer-support/run_e2e.sh /tmp/open-agentops-customer-support-example
```

The script creates a temporary copy, proves the unsafe agent fails, applies a safe patch, proves the patched agent passes, saves a baseline, compares it, and exports artifacts.
